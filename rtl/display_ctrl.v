//============================================================================
// 文件名  : display_ctrl.v
// 功能    : 8 位数码管动态扫描、模式/数值选择、2 Hz 闪烁、LED 指示
// 显示    : d[7:6]=模式，d[5:0]=6 位数值；d[5]、d[3] 带小数点
//============================================================================
module display_ctrl(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1khz,
    input  wire        tick_2hz,

    input  wire [1:0]  mode,
    input  wire        setting,
    input  wire [2:0]  cursor,

    input  wire [23:0] time_bcd,
    input  wire [23:0] edit_bcd,
    input  wire [23:0] alarm_bcd,
    input  wire [23:0] alarm_edit_bcd,
    input  wire [7:0]  sw_min_bcd,
    input  wire [7:0]  sw_sec_bcd,
    input  wire [7:0]  sw_cs_bcd,
    input  wire        sw_running,
    input  wire [23:0] cd_remain_bcd,
    input  wire [23:0] cd_edit_bcd,
    input  wire        cd_running,
    input  wire        cd_paused,
    input  wire        cd_expired,
    input  wire        alarm_en,

    output reg  [7:0]  seg_n,
    output reg  [7:0]  dig_n,
    output wire [3:0]  led_n
);

    localparam [1:0] MODE_CL = 2'b00;
    localparam [1:0] MODE_AL = 2'b01;
    localparam [1:0] MODE_ST = 2'b10;
    localparam [1:0] MODE_CD = 2'b11;

    // 字符码：A=A，B=C，C=d，D=L，E=S，F=t
    localparam [3:0] CHAR_A = 4'hA;
    localparam [3:0] CHAR_C = 4'hB;
    localparam [3:0] CHAR_d = 4'hC;
    localparam [3:0] CHAR_L = 4'hD;
    localparam [3:0] CHAR_S = 4'hE;
    localparam [3:0] CHAR_t = 4'hF;

    reg [31:0] disp;        // 8 个 nibble，disp[3:0] 是最右边的数码 1
    reg        label_blink;
    reg        blink2;
    reg [2:0]  scan_idx;
    reg        hb_div;
    reg        heartbeat;

    wire [3:0] cur_digit;
    wire       cur_dp;
    wire       cur_blank;
    wire [7:0] seg_cur;
    wire       led4_on;

    //------------------------------------------------------------------------
    // 当前扫描位的字符、小数点、消隐
    //------------------------------------------------------------------------
    assign cur_digit = disp[(scan_idx * 4) +: 4];
    assign cur_dp    = (scan_idx == 3'd4) || (scan_idx == 3'd2);

    assign cur_blank = ((scan_idx >= 3'd6) && label_blink && (!blink2)) ||
                       (setting && (scan_idx == (3'd5 - cursor)) && (!blink2));

    seg_decode u_seg_decode (
        .bcd(cur_digit),
        .dp(cur_dp),
        .blank(cur_blank),
        .seg_n(seg_cur)
    );

    //------------------------------------------------------------------------
    // 模式标识闪烁条件
    //------------------------------------------------------------------------
    always @(*) begin
        case (mode)
            MODE_CL: label_blink = setting;
            MODE_AL: label_blink = setting;
            MODE_ST: label_blink = 1'b0;
            MODE_CD: label_blink = setting | cd_running | cd_paused | cd_expired;
            default: label_blink = 1'b0;
        endcase
    end

    //------------------------------------------------------------------------
    // 组合出 8 个 nibble
    //------------------------------------------------------------------------
    always @(*) begin
        disp = 32'h00000000;

        case (mode)
            MODE_CL: begin
                disp[31:28] = CHAR_C;
                disp[27:24] = CHAR_L;
            end
            MODE_AL: begin
                disp[31:28] = CHAR_A;
                disp[27:24] = CHAR_L;
            end
            MODE_ST: begin
                disp[31:28] = CHAR_S;
                disp[27:24] = CHAR_t;
            end
            MODE_CD: begin
                disp[31:28] = CHAR_C;
                disp[27:24] = CHAR_d;
            end
            default: begin
                disp[31:28] = CHAR_C;
                disp[27:24] = CHAR_L;
            end
        endcase

        case (mode)
            MODE_CL: begin
                if (setting) begin
                    disp[23:20] = edit_bcd[23:20];
                    disp[19:16] = edit_bcd[19:16];
                    disp[15:12] = edit_bcd[15:12];
                    disp[11:8]  = edit_bcd[11:8];
                    disp[7:4]   = edit_bcd[7:4];
                    disp[3:0]   = edit_bcd[3:0];
                end
                else begin
                    disp[23:20] = time_bcd[23:20];
                    disp[19:16] = time_bcd[19:16];
                    disp[15:12] = time_bcd[15:12];
                    disp[11:8]  = time_bcd[11:8];
                    disp[7:4]   = time_bcd[7:4];
                    disp[3:0]   = time_bcd[3:0];
                end
            end

            MODE_AL: begin
                if (setting) begin
                    disp[23:20] = alarm_edit_bcd[23:20];
                    disp[19:16] = alarm_edit_bcd[19:16];
                    disp[15:12] = alarm_edit_bcd[15:12];
                    disp[11:8]  = alarm_edit_bcd[11:8];
                    disp[7:4]   = alarm_edit_bcd[7:4];
                    disp[3:0]   = alarm_edit_bcd[3:0];
                end
                else begin
                    disp[23:20] = alarm_bcd[23:20];
                    disp[19:16] = alarm_bcd[19:16];
                    disp[15:12] = alarm_bcd[15:12];
                    disp[11:8]  = alarm_bcd[11:8];
                    disp[7:4]   = alarm_bcd[7:4];
                    disp[3:0]   = alarm_bcd[3:0];
                end
            end

            MODE_ST: begin
                disp[23:16] = sw_min_bcd;
                disp[15:8]  = sw_sec_bcd;
                disp[7:0]   = sw_cs_bcd;
            end

            MODE_CD: begin
                if (setting) begin
                    disp[23:20] = cd_edit_bcd[23:20];
                    disp[19:16] = cd_edit_bcd[19:16];
                    disp[15:12] = cd_edit_bcd[15:12];
                    disp[11:8]  = cd_edit_bcd[11:8];
                    disp[7:4]   = cd_edit_bcd[7:4];
                    disp[3:0]   = cd_edit_bcd[3:0];
                end
                else begin
                    disp[23:20] = cd_remain_bcd[23:20];
                    disp[19:16] = cd_remain_bcd[19:16];
                    disp[15:12] = cd_remain_bcd[15:12];
                    disp[11:8]  = cd_remain_bcd[11:8];
                    disp[7:4]   = cd_remain_bcd[7:4];
                    disp[3:0]   = cd_remain_bcd[3:0];
                end
            end

            default: begin
                disp[23:0] = 24'h000000;
            end
        endcase
    end

    //------------------------------------------------------------------------
    // 扫描与 LED
    //------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            scan_idx <= 3'd0;
            seg_n    <= 8'hFF;
            dig_n    <= 8'hFF;
            blink2   <= 1'b0;
            hb_div   <= 1'b0;
            heartbeat<= 1'b0; // 低有效：led_n[0]=1，复位时 LED1 灭
        end
        else begin
            if (tick_2hz) begin
                blink2 <= ~blink2;

                // tick_2hz 每 250 ms 一次，再二分频得到 1 Hz 心跳
                hb_div <= ~hb_div;
                if (hb_div)
                    heartbeat <= ~heartbeat;
            end

            if (tick_1khz) begin
                seg_n    <= seg_cur;
                dig_n    <= ~(8'b00000001 << scan_idx);
                scan_idx <= scan_idx + 1'b1;
            end
        end
    end

    // LED1 1 Hz 心跳；LED2 闹钟开关；LED3 秒表运行；LED4 倒计时后台/到期
    assign led4_on = cd_running | (cd_expired & blink2);
    assign led_n   = {~led4_on, ~sw_running, ~alarm_en, ~heartbeat};

endmodule

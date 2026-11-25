//============================================================================
// 文件名  : display_ctrl.v
// 功能    : 8 位数码管动态扫描、模式/数值选择、2 Hz 闪烁、LED 指示
// 显示    : d[7:6]=模式，d[5:0]=6 位数值；d[5]、d[3] 带小数点
//============================================================================
module display_ctrl(
    input  wire        clk, // 系统时钟 50 MHz
    input  wire        rst_n, // 系统复位，低有效
    input  wire        tick_1khz, // 1 kHz 使能：每 1 ms 一个脉冲，用于动态扫描
    input  wire        tick_2hz, // 2 Hz 使能：每 250 ms 一个脉冲，用于闪烁
    // 端口分组：模式与设置状态
    input  wire [1:0]  mode, // 当前模式：00=CL 时钟，01=AL 闹钟，10=St 秒表，11=Cd 倒计时
    input  wire        setting, // 1=正在设置，0=正常显示
    input  wire [2:0]  cursor, // 设置光标：0=最右数值位，5=最左数值位
    // 端口分组：各路显示数据
    input  wire [23:0] time_bcd, // 当前时间 BCD：{时,分,秒}
    input  wire [23:0] edit_bcd, // 时间设置中的编辑值
    input  wire [23:0] alarm_bcd, // 闹钟设定值
    input  wire [23:0] alarm_edit_bcd, // 闹钟设置中的编辑值
    input  wire [7:0]  sw_min_bcd, // 秒表分钟 BCD
    input  wire [7:0]  sw_sec_bcd, // 秒表秒 BCD
    input  wire [7:0]  sw_cs_bcd, // 秒表百分秒 BCD
    input  wire        sw_running, // 秒表运行标志
    input  wire [23:0] cd_remain_bcd, // 倒计时剩余值 BCD
    input  wire [23:0] cd_edit_bcd, // 倒计时设置中的编辑值
    input  wire        cd_running, // 倒计时运行中
    input  wire        cd_paused, // 倒计时已暂停
    input  wire        cd_expired, // 倒计时到期
    input  wire        alarm_en, // 闹钟开关：1=开
    // 端口分组：显示输出
    output reg  [7:0]  seg_n, // 七段段选，低有效（0 点亮）
    output reg  [7:0]  dig_n, // 8 位数码管位选，低有效 one-hot
    output wire [3:0]  led_n // LED1~LED4，低有效
);
    // 模式编码，与 key_ctrl 输出一致
    localparam [1:0] MODE_CL = 2'b00; // 时钟模式
    localparam [1:0] MODE_AL = 2'b01; // 闹钟模式
    localparam [1:0] MODE_ST = 2'b10; // 秒表模式
    localparam [1:0] MODE_CD = 2'b11; // 倒计时模式

    // 字符码：A=A，B=C，C=d，D=L，E=S，F=t
    localparam [3:0] CHAR_A = 4'hA; // 字符 A
    localparam [3:0] CHAR_C = 4'hB; // 字符 C
    localparam [3:0] CHAR_d = 4'hC; // 字符 d
    localparam [3:0] CHAR_L = 4'hD; // 字符 L
    localparam [3:0] CHAR_S = 4'hE; // 字符 S
    localparam [3:0] CHAR_t = 4'hF; // 字符 t
    // 内部寄存器
    reg [31:0] disp;        // 8 个 nibble，disp[3:0] 是最右边的数码 1
    reg        label_blink; // 模式标识：设置中快闪（2 Hz）
    reg        label_slow;  // 模式标识：Cd 运行/暂停/到期慢闪（1 Hz）
    reg        blink2;      // 2 Hz 方波：设置中闪烁、光标闪烁
    reg        blink_slow;  // 1 Hz 方波：Cd 状态慢闪
    reg [1:0]  slow_div;    // 由 tick_2hz 再二分频，得到 1 Hz
    reg [2:0]  scan_idx; // 扫描位 0~7：0 是最右位数码 1，7 是最左边数码 8
    reg        hb_div; // 心跳分频计数器
    reg        heartbeat; // 1 Hz 心跳标志，驱动 LED1

    wire [3:0] cur_digit; // 当前扫描位的 4 位字符码
    wire       cur_dp; // 当前位是否点亮小数点
    wire       cur_blank; // 当前位是否消隐
    wire [7:0] seg_cur; // 当前位的段码
    wire       led4_on; // LED4 点亮条件

    //------------------------------------------------------------------------
    // 当前扫描位的字符、小数点、消隐
    //------------------------------------------------------------------------
    assign cur_digit = disp[(scan_idx * 4) +: 4]; // 按 scan_idx 从 disp 中切出 4 位
    assign cur_dp    = (scan_idx == 3'd4) || (scan_idx == 3'd2); // 小数点固定在数码 5（scan_idx=4）和数码 3（scan_idx=2）

    // 设置中：模式标识和光标都按 2 Hz 快闪（区分"我在设置"）
    // Cd 运行/暂停/到期：模式标识按 1 Hz 慢闪（只是状态提示，不该闪得让人烦）
    assign cur_blank = ((scan_idx >= 3'd6) && // 标识闪烁或光标闪烁时，当前位消隐
                        ((label_blink && (!blink2)) || (label_slow && (!blink_slow)))) || // 标识消隐：快闪取反 blink2，慢闪取反 blink_slow
                       (setting && (scan_idx == (3'd5 - cursor)) && (!blink2)); // 设置中光标所在位按 2 Hz 闪烁

    seg_decode u_seg_decode ( // 段码译码：字符码 + 小数点 + 消隐 → 8 位段选
        .bcd(cur_digit), // 当前位字符码
        .dp(cur_dp), // 小数点使能
        .blank(cur_blank), // 消隐使能
        .seg_n(seg_cur) // 低有效段码输出
    );

    //------------------------------------------------------------------------
    // 模式标识闪烁条件
    //------------------------------------------------------------------------
    always @(*) begin // 组合逻辑：只决定两个模式标识的闪烁方式
        case (mode) // 按模式选择
            MODE_CL: begin // CL：设置中标识快闪
                label_blink = setting;      // 设置中：2 Hz
                label_slow  = 1'b0; // 非设置时常亮
            end
            MODE_AL: begin // AL：设置中快闪；闹钟打开时慢闪
                label_blink = setting; // 设置中 2 Hz 快闪
                label_slow  = (!setting) & alarm_en;   // 闹钟开关打开 → AL 慢闪确认
            end
            MODE_ST: begin // St：秒表模式标识不闪
                label_blink = 1'b0;         // 秒表不闪
                label_slow  = 1'b0; // 不使用慢闪
            end
            MODE_CD: begin // Cd：设置中快闪；运行/暂停/到期慢闪
                label_blink = setting;                                // 设置中：2 Hz 快闪
                label_slow  = (!setting) & (cd_running | cd_paused | cd_expired); // 运行/暂停/到期：1 Hz 慢闪
            end
            default: begin // 非法模式
                label_blink = 1'b0; // 不闪
                label_slow  = 1'b0; // 不闪
            end
        endcase
    end

    //------------------------------------------------------------------------
    // 组合出 8 个 nibble
    //------------------------------------------------------------------------
    always @(*) begin // 组合逻辑：根据 mode 与 setting 生成 disp
        disp = 32'h00000000; // 默认全 0
        // 先清 0，再按模式逐段填充 disp
        case (mode) // 第一步：两个模式标识字符
            MODE_CL: begin // CL
                disp[31:28] = CHAR_C; // 数码 8：C
                disp[27:24] = CHAR_L; // 数码 7：L
            end
            MODE_AL: begin // AL
                disp[31:28] = CHAR_A; // 数码 8：A
                disp[27:24] = CHAR_L; // 数码 7：L
            end
            MODE_ST: begin // St
                disp[31:28] = CHAR_S; // 数码 8：S
                disp[27:24] = CHAR_t; // 数码 7：t
            end
            MODE_CD: begin // Cd
                disp[31:28] = CHAR_C; // 数码 8：C
                disp[27:24] = CHAR_d; // 数码 7：d
            end
            default: begin // 非法模式按 CL 显示
                disp[31:28] = CHAR_C; // 数码 8：C
                disp[27:24] = CHAR_L; // 数码 7：L
            end
        endcase

        case (mode) // 第二步：6 位数值
            MODE_CL: begin // 时钟：设置中显示编辑值，否则显示当前时间
                if (setting) begin // 设置中
                    disp[23:20] = edit_bcd[23:20]; // 时十位
                    disp[19:16] = edit_bcd[19:16]; // 时个位
                    disp[15:12] = edit_bcd[15:12]; // 分十位
                    disp[11:8]  = edit_bcd[11:8]; // 分个位
                    disp[7:4]   = edit_bcd[7:4]; // 秒十位
                    disp[3:0]   = edit_bcd[3:0]; // 秒个位
                end
                else begin // 非设置：显示当前走时
                    disp[23:20] = time_bcd[23:20];
                    disp[19:16] = time_bcd[19:16];
                    disp[15:12] = time_bcd[15:12];
                    disp[11:8]  = time_bcd[11:8];
                    disp[7:4]   = time_bcd[7:4];
                    disp[3:0]   = time_bcd[3:0];
                end
            end
            // 闹钟模式：设置中显示编辑值，否则显示设定值
            MODE_AL: begin // 闹钟：设置中显示编辑值
                if (setting) begin // 设置中
                    disp[23:20] = alarm_edit_bcd[23:20]; // 时十位
                    disp[19:16] = alarm_edit_bcd[19:16]; // 时个位
                    disp[15:12] = alarm_edit_bcd[15:12]; // 分十位
                    disp[11:8]  = alarm_edit_bcd[11:8]; // 分个位
                    disp[7:4]   = alarm_edit_bcd[7:4]; // 秒十位
                    disp[3:0]   = alarm_edit_bcd[3:0]; // 秒个位
                end
                else begin // 非设置：显示闹钟设定值
                    disp[23:20] = alarm_bcd[23:20];
                    disp[19:16] = alarm_bcd[19:16];
                    disp[15:12] = alarm_bcd[15:12];
                    disp[11:8]  = alarm_bcd[11:8];
                    disp[7:4]   = alarm_bcd[7:4];
                    disp[3:0]   = alarm_bcd[3:0];
                end
            end

            MODE_ST: begin // 秒表：6 位数值 = 分钟 + 秒 + 百分秒
                disp[23:16] = sw_min_bcd; // 分钟（两位）
                disp[15:8]  = sw_sec_bcd; // 秒（两位）
                disp[7:0]   = sw_cs_bcd; // 百分秒（两位）
            end

            MODE_CD: begin // 倒计时：设置中显示编辑值
                if (setting) begin // 设置中
                    disp[23:20] = cd_edit_bcd[23:20]; // 时十位
                    disp[19:16] = cd_edit_bcd[19:16]; // 时个位
                    disp[15:12] = cd_edit_bcd[15:12]; // 分十位
                    disp[11:8]  = cd_edit_bcd[11:8]; // 分个位
                    disp[7:4]   = cd_edit_bcd[7:4]; // 秒十位
                    disp[3:0]   = cd_edit_bcd[3:0]; // 秒个位
                end
                else begin // 非设置：显示剩余时间
                    disp[23:20] = cd_remain_bcd[23:20];
                    disp[19:16] = cd_remain_bcd[19:16];
                    disp[15:12] = cd_remain_bcd[15:12];
                    disp[11:8]  = cd_remain_bcd[11:8];
                    disp[7:4]   = cd_remain_bcd[7:4];
                    disp[3:0]   = cd_remain_bcd[3:0];
                end
            end

            default: begin // 非法模式：数值位清零
                disp[23:0] = 24'h000000; // 清空 6 位数值
            end
        endcase
    end

    //------------------------------------------------------------------------
    // 扫描与 LED
    //------------------------------------------------------------------------
    always @(posedge clk) begin // 同步时序：扫描、位选、闪烁、心跳
        if (!rst_n) begin // 复位
            scan_idx <= 3'd0; // 扫描位归零
            seg_n    <= 8'hFF; // 段选全灭
            dig_n    <= 8'hFF; // 位选全灭（低有效，全 1 即全关）
            blink2   <= 1'b0; // 快闪清零
            blink_slow <= 1'b0; // 慢闪清零
            slow_div <= 2'd0; // 慢闪分频清零
            hb_div   <= 1'b0; // 心跳分频清零
            heartbeat<= 1'b0; // 低有效：led_n[0]=1，复位时 LED1 灭
        end
        else begin
            if (tick_2hz) begin // 每 250 ms
                blink2 <= ~blink2; // 2 Hz 方波翻转

                // 慢闪：每 2 个 tick_2hz（500 ms）翻转一次 → 1 Hz
                slow_div <= slow_div + 1'b1; // 2 位计数器加一
                if (slow_div[0]) // 最低位为 1 时翻转
                    blink_slow <= ~blink_slow; // 得到 1 Hz 慢闪

                // tick_2hz 每 250 ms 一次，再二分频得到 1 Hz 心跳
                hb_div <= ~hb_div; // 心跳分频计数翻转
                if (hb_div) // 高电平期间翻转 heartbeat
                    heartbeat <= ~heartbeat; // heartbeat 每 500 ms 变化一次
            end

            if (tick_1khz) begin // 每 1 ms 扫描一位
                seg_n    <= seg_cur; // 输出当前位段码
                dig_n    <= ~(8'b00000001 << scan_idx); // 低有效 one-hot 位选：仅当前位为 0
                scan_idx <= scan_idx + 1'b1; // 扫描位加一，0→7 循环，8 ms 一圈
            end
        end
    end

    // LED1 1 Hz 心跳；LED2 闹钟开关；LED3 秒表运行；LED4 倒计时后台/到期
    assign led4_on = cd_running | (cd_expired & blink2); // 倒计时运行常亮；到期时随 2 Hz 闪烁
    assign led_n   = {~led4_on, ~sw_running, ~alarm_en, ~heartbeat}; // 拼成低有效 LED 输出：{~LED4,~LED3,~LED2,~LED1}

endmodule // 模块结束

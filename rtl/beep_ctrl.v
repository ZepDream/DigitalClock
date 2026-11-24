//============================================================================
// 文件名  : beep_ctrl.v
// 功能    : 闹钟/倒计时的蜂鸣器节奏
// 说明    : 闹钟 3 下 x 2 组；倒计时 2 下 x 1 组；任意键可提前静音。
//           输出 beep_en 只控制“响/不响”，2.7 kHz 方波由 buzzer_tone 产生。
//============================================================================
module beep_ctrl(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1khz,     // 1 ms
    input  wire alarm_trigger,
    input  wire cd_expire,
    input  wire silence,
    output wire beep_en
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_ON   = 2'd1;
    localparam [1:0] ST_OFF  = 2'd2;
    localparam [1:0] ST_GAP  = 2'd3;

    localparam integer ALARM_ON_MS  = 150;
    localparam integer ALARM_OFF_MS = 150;
    localparam integer ALARM_GAP_MS = 600;
    localparam integer CD_ON_MS     = 200;
    localparam integer CD_OFF_MS    = 200;

    reg [1:0]  state;
    reg        is_alarm;
    reg [2:0]  beep_cnt;
    reg [15:0] timer;

    assign beep_en = (state == ST_ON);

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (silence) begin
            state    <= ST_IDLE;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (alarm_trigger) begin
            // 闹钟优先；如果正在响倒计时，也立即切换到闹钟
            state    <= ST_ON;
            is_alarm <= 1'b1;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (cd_expire && (state == ST_IDLE)) begin
            state    <= ST_ON;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (tick_1khz) begin
            case (state)
                ST_IDLE: begin
                    // 等待触发
                end

                ST_ON: begin
                    if (timer == ((is_alarm ? ALARM_ON_MS : CD_ON_MS) - 1)) begin
                        state <= ST_OFF;
                        timer <= 16'd0;
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                ST_OFF: begin
                    if (timer == ((is_alarm ? ALARM_OFF_MS : CD_OFF_MS) - 1)) begin
                        timer <= 16'd0;

                        if (is_alarm) begin
                            if (beep_cnt == 3'd2) begin
                                state <= ST_GAP;       // 第一组 3 下结束
                            end
                            else if (beep_cnt == 3'd5) begin
                                state <= ST_IDLE;      // 第二组 3 下结束
                            end
                            else begin
                                beep_cnt <= beep_cnt + 1'b1;
                                state    <= ST_ON;
                            end
                        end
                        else begin
                            if (beep_cnt == 3'd1)
                                state <= ST_IDLE;      // 倒计时 2 下结束
                            else begin
                                beep_cnt <= beep_cnt + 1'b1;
                                state    <= ST_ON;
                            end
                        end
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                ST_GAP: begin
                    if (timer == (ALARM_GAP_MS - 1)) begin
                        timer    <= 16'd0;
                        beep_cnt <= 3'd3;              // 第二组从第 4 下开始
                        state    <= ST_ON;
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

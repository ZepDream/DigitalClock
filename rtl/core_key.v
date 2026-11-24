//============================================================================
// 文件名  : core_key.v
// 功能    : 核心板独立按键的消抖、按下脉冲和长按连发
// 说明    : 按键低有效；K1 不使用连发，K2/K3 使用 0.5 s 后 10 Hz 连发。
//============================================================================
module core_key #(
    parameter integer DEBOUNCE_MS     = 20,
    parameter integer REPEAT_DELAY_MS = 500,
    parameter integer REPEAT_RATE_MS  = 100,
    parameter integer REPEAT_EN       = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1khz,
    input  wire key_n,
    output reg  press
);

    reg [1:0] sync0;
    reg [1:0] sync1;
    reg       level;       // 1=松开，0=按下
    reg [4:0] db_cnt;      // 20 ms 消抖
    reg [8:0] hold_cnt;    // 0.5 s 连发延时
    reg [6:0] rep_cnt;     // 100 ms 连发间隔
    reg       repeating;

    always @(posedge clk) begin
        sync0 <= {sync0[0], key_n};
        sync1 <= sync0;

        if (!rst_n) begin
            level     <= 1'b1;
            db_cnt    <= 5'd0;
            hold_cnt  <= 9'd0;
            rep_cnt   <= 7'd0;
            repeating <= 1'b0;
            press     <= 1'b0;
        end
        else begin
            press <= 1'b0;

            if (tick_1khz) begin
                if (sync1[1] != level) begin
                    // 输入与当前稳定值不同，等 20 ms
                    if (db_cnt == DEBOUNCE_MS - 1) begin
                        level     <= sync1[1];
                        db_cnt    <= 5'd0;
                        hold_cnt  <= 9'd0;
                        rep_cnt   <= 7'd0;
                        repeating <= 1'b0;
                        if (sync1[1] == 1'b0)
                            press <= 1'b1;  // 刚按下
                    end
                    else begin
                        db_cnt <= db_cnt + 1'b1;
                    end
                end
                else begin
                    db_cnt <= 5'd0;

                    if ((level == 1'b0) && (REPEAT_EN != 0)) begin
                        if (!repeating) begin
                            if (hold_cnt == REPEAT_DELAY_MS - 1) begin
                                repeating <= 1'b1;
                                hold_cnt  <= 9'd0;
                                rep_cnt   <= 7'd0;
                                press     <= 1'b1;
                            end
                            else begin
                                hold_cnt <= hold_cnt + 1'b1;
                            end
                        end
                        else begin
                            if (rep_cnt == REPEAT_RATE_MS - 1) begin
                                rep_cnt <= 7'd0;
                                press   <= 1'b1;
                            end
                            else begin
                                rep_cnt <= rep_cnt + 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule

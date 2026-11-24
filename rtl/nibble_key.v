//============================================================================
// 文件名  : nibble_key.v
// 功能    : 模式 9 的单路 4 位按键检测
// 原理    : 底板 CPLD 每按一次让 nibble 加 1，FPGA 只检测“值变化”。
//           先两级同步，再连续 20 ms 保持不变，才认为是一次有效按下。
//============================================================================
module nibble_key #(
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_1khz,   // 1 ms 使能
    input  wire [3:0] nibble_in,
    output reg        press        // 单周期脉冲
);

    reg [3:0] sync0;
    reg [3:0] sync1;
    reg [3:0] prev;       // 上一次已经确认的值
    reg [3:0] candidate;  // 正在确认的新值
    reg [4:0] cnt;        // 0 ~ 19
    reg       initialized;

    always @(posedge clk) begin
        sync0 <= nibble_in;
        sync1 <= sync0;

        if (!rst_n) begin
            prev        <= 4'd0;
            candidate   <= 4'd0;
            cnt         <= 5'd0;
            initialized <= 1'b0;
            press       <= 1'b0;
        end
        else begin
            press <= 1'b0;

            if (tick_1khz) begin
                if (!initialized) begin
                    // 上电后先把当前值锁存为基准，避免误报一次按键
                    prev        <= sync1;
                    candidate   <= sync1;
                    cnt         <= 5'd0;
                    initialized <= 1'b1;
                end
                else if (sync1 != candidate) begin
                    // 输入还在变，重新计时
                    candidate <= sync1;
                    cnt       <= 5'd0;
                end
                else if (candidate != prev) begin
                    if (cnt == DEBOUNCE_MS - 1) begin
                        prev  <= candidate;
                        press <= 1'b1;
                        cnt   <= 5'd0;
                    end
                    else begin
                        cnt <= cnt + 1'b1;
                    end
                end
                else begin
                    cnt <= 5'd0;
                end
            end
        end
    end

endmodule

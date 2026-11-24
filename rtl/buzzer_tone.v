//============================================================================
// 文件名  : buzzer_tone.v
// 功能    : 产生约 2.7 kHz 方波，驱动板载无源蜂鸣器
// 说明    : 蜂鸣器经 PNP 三极管驱动，FPGA 输出低电平时导通发声。
//============================================================================
module buzzer_tone #(
    parameter integer SIM_FAST = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire beep_en,
    output wire buzzer
);

    // 50 MHz / (2 * 2700) ≈ 9259
    localparam integer TONE_DIV = (SIM_FAST != 0) ? 4 : 9259;

    reg [13:0] cnt;
    reg        tone;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt  <= 14'd0;
            tone <= 1'b0;
        end
        else if (!beep_en) begin
            cnt  <= 14'd0;
            tone <= 1'b0;
        end
        else if (cnt == TONE_DIV - 1) begin
            cnt  <= 14'd0;
            tone <= ~tone;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end

    // 低有效：beep_en=1 且 tone=1 时输出低，蜂鸣器响
    assign buzzer = ~(beep_en & tone);

endmodule

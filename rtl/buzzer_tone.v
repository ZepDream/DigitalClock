//============================================================================
// 文件名  : buzzer_tone.v
// 功能    : 产生约 2.7 kHz 方波，驱动板载无源蜂鸣器
// 说明    : 蜂鸣器经 PNP 三极管驱动，FPGA 输出低电平时导通发声。
//============================================================================
module buzzer_tone #(
    parameter integer SIM_FAST = 0 // 仿真加速：非 0 时把分频比改为 4，缩短仿真时间
)(
    input  wire clk, // 50 MHz 系统时钟
    input  wire rst_n, // 异步复位，低有效
    input  wire beep_en, // 响使能，来自 beep_ctrl
    output wire buzzer // 低电平响的驱动输出，接 PNP 三极管
);

    // 50 MHz / (2 * 2700) ≈ 9259，约 185 us 翻转一次 tone，即 2.7 kHz
    localparam integer TONE_DIV = (SIM_FAST != 0) ? 4 : 9259; // 分频常数；SIM_FAST 时取 4，仅为缩短仿真

    reg [13:0] cnt; // 分频计数器 0 ~ TONE_DIV-1，14 位足够表示 9259
    reg        tone; // 方波电平，每半个周期翻转一次

    always @(posedge clk) begin // 方波产生：50 MHz 上升沿计数，复位/静音时归零
        if (!rst_n) begin
            cnt  <= 14'd0;
            tone <= 1'b0;
        end
        else if (!beep_en) begin // 不响时把计数和相位都清零，下次从完整半周期开始
            cnt  <= 14'd0;
            tone <= 1'b0;
        end
        else if (cnt == TONE_DIV - 1) begin // 计满半个周期后翻转 tone 并重新计数
            cnt  <= 14'd0;
            tone <= ~tone;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end

    // 低有效：beep_en=1 且 tone=1 时输出低，蜂鸣器响
    assign buzzer = ~(beep_en & tone); // tone=0 或静音时输出恒高，PNP 截止

endmodule

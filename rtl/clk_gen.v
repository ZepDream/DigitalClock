//============================================================================
// 文件名  : clk_gen.v
// 功能    : 由 50 MHz 时钟产生 1 Hz、100 Hz、1 kHz、2 Hz 的单周期使能
// 说明    : 不产生分频时钟，所有逻辑仍然使用 50 MHz，避免门控时钟。
//============================================================================
module clk_gen #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer SIM_FAST = 0
)(
    input  wire clk,
    input  wire rst_n,
    output reg  tick_1hz,
    output reg  tick_100hz,
    output reg  tick_1khz,
    output reg  tick_2hz
);

    // SIM_FAST=1 时使用很短的计数终值，只用于仿真加速。
    localparam integer DIV_1HZ   = (SIM_FAST != 0) ? 1000 : CLK_FREQ;
    localparam integer DIV_100HZ = (SIM_FAST != 0) ? 8    : (CLK_FREQ / 100);
    localparam integer DIV_1KHZ  = (SIM_FAST != 0) ? 4    : (CLK_FREQ / 1000);
    localparam integer DIV_2HZ   = (SIM_FAST != 0) ? 250  : (CLK_FREQ / 4);

    reg [25:0] cnt_1hz;
    reg [25:0] cnt_100hz;
    reg [25:0] cnt_1khz;
    reg [25:0] cnt_2hz;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_1hz   <= 26'd0;
            cnt_100hz <= 26'd0;
            cnt_1khz  <= 26'd0;
            cnt_2hz   <= 26'd0;
            tick_1hz   <= 1'b0;
            tick_100hz <= 1'b0;
            tick_1khz  <= 1'b0;
            tick_2hz   <= 1'b0;
        end
        else begin
            // 1 Hz：每 1 秒一个时钟周期宽度的脉冲
            if (cnt_1hz == DIV_1HZ - 1) begin
                cnt_1hz  <= 26'd0;
                tick_1hz <= 1'b1;
            end
            else begin
                cnt_1hz  <= cnt_1hz + 1'b1;
                tick_1hz <= 1'b0;
            end

            // 100 Hz：每 10 ms 一个脉冲，给秒表用
            if (cnt_100hz == DIV_100HZ - 1) begin
                cnt_100hz  <= 26'd0;
                tick_100hz <= 1'b1;
            end
            else begin
                cnt_100hz  <= cnt_100hz + 1'b1;
                tick_100hz <= 1'b0;
            end

            // 1 kHz：每 1 ms 一个脉冲，给扫描、消抖、蜂鸣器节奏用
            if (cnt_1khz == DIV_1KHZ - 1) begin
                cnt_1khz  <= 26'd0;
                tick_1khz <= 1'b1;
            end
            else begin
                cnt_1khz  <= cnt_1khz + 1'b1;
                tick_1khz <= 1'b0;
            end

            // 2 Hz 闪烁：每 250 ms 一个脉冲，显示模块每来一次翻转一次
            if (cnt_2hz == DIV_2HZ - 1) begin
                cnt_2hz  <= 26'd0;
                tick_2hz <= 1'b1;
            end
            else begin
                cnt_2hz  <= cnt_2hz + 1'b1;
                tick_2hz <= 1'b0;
            end
        end
    end

endmodule

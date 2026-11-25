//============================================================================
// 文件名  : clk_gen.v
// 功能    : 由 50 MHz 时钟产生 1 Hz、100 Hz、1 kHz、2 Hz 的单周期使能
// 说明    : 不产生分频时钟，所有逻辑仍然使用 50 MHz，避免门控时钟。（tick 只宽一个 clk 周期，下游一律写成 if (tick_xxx) 做单拍动作）
//============================================================================
module clk_gen #(
    parameter integer CLK_FREQ = 50_000_000,  // 输入时钟频率，默认 50 MHz 与板载晶振一致，换板只改这里
    parameter integer SIM_FAST = 0            // 置 1 时四个分频终值都换成极小值，只供仿真缩短等待，上板必须为 0
)(
    input  wire clk,                          // 系统唯一时钟，所有寄存器都在此上升沿更新
    input  wire rst_n,                        // 同步复位，低有效；低电平期间计数器与四个 tick 全部为 0
    output reg  tick_1hz,                     // 1 Hz 单周期使能，每 1 s 高一个 clk，给秒计数/走时逻辑
    output reg  tick_100hz,                   // 100 Hz 单周期使能，每 10 ms 高一个 clk，给秒表的 0.01 s 位
    output reg  tick_1khz,                    // 1 kHz 单周期使能，每 1 ms 高一个 clk，给扫描、消抖、蜂鸣器节奏
    output reg  tick_2hz                      // 2 Hz 单周期使能，每 250 ms 高一个 clk，给闪烁标志翻转
);

    // SIM_FAST=1 时使用很短的计数终值，只用于仿真加速。（上板必须为 0，否则 tick 频率全错）
    localparam integer DIV_1HZ   = (SIM_FAST != 0) ? 1000 : CLK_FREQ;  // 计 0~DIV_1HZ-1 共 50_000_000 拍 = 1 s
    localparam integer DIV_100HZ = (SIM_FAST != 0) ? 8    : (CLK_FREQ / 100);  // 计 0~DIV_100HZ-1 共 500_000 拍 = 10 ms
    localparam integer DIV_1KHZ  = (SIM_FAST != 0) ? 4    : (CLK_FREQ / 1000);  // 计 0~DIV_1KHZ-1 共 50_000 拍 = 1 ms，是消抖计数的唯一时基
    localparam integer DIV_2HZ   = (SIM_FAST != 0) ? 250  : (CLK_FREQ / 4);  // 计 0~DIV_2HZ-1 共 12_500_000 拍 = 250 ms，显示每拍翻转一次

    reg [25:0] cnt_1hz;                       // 1 Hz 计数器：0~DIV_1HZ-1，每 clk +1；只在本块写，也只在本块比较
    reg [25:0] cnt_100hz;                     // 100 Hz 计数器：0~DIV_100HZ-1，计满归零并拉高一拍 tick_100hz
    reg [25:0] cnt_1khz;                      // 1 kHz 计数器：0~DIV_1KHZ-1，1 ms 一个周期，计满归零
    reg [25:0] cnt_2hz;                       // 2 Hz 计数器：0~DIV_2HZ-1，250 ms 一个周期，计满归零

    always @(posedge clk) begin               // 唯一时序块：四个计数器各自独立计数，互不干扰
        if (!rst_n) begin                     // 同步复位优先：复位后计数器与四个 tick 全为 0，不会误触发下游
            cnt_1hz   <= 26'd0;
            cnt_100hz <= 26'd0;
            cnt_1khz  <= 26'd0;
            cnt_2hz   <= 26'd0;
            tick_1hz   <= 1'b0;               // tick 一并清零，保证复位释放后的头一个周期不是高电平
            tick_100hz <= 1'b0;
            tick_1khz  <= 1'b0;
            tick_2hz   <= 1'b0;
        end
        else begin
            // 1 Hz：每 1 秒一个时钟周期宽度的脉冲，cnt 从 0 数到 DIV_1HZ-1 再归零
            if (cnt_1hz == DIV_1HZ - 1) begin  // 用 DIV-1 比较，是因为从 0 开始计、正好 DIV 个状态
                cnt_1hz  <= 26'd0;
                tick_1hz <= 1'b1;             // 只在这一拍为 1，下一拍由下面的 else 清掉
            end
            else begin
                cnt_1hz  <= cnt_1hz + 1'b1;   // 非终值拍继续计数
                tick_1hz <= 1'b0;             // 强制拉低，确保 tick 宽度恰好一个 clk，它不是时钟
            end

            // 100 Hz：每 10 ms 一个脉冲，给秒表用，即每 500_000 个 clk 一拍
            if (cnt_100hz == DIV_100HZ - 1) begin  // 计满 10 ms 才发一个使能
                cnt_100hz  <= 26'd0;
                tick_100hz <= 1'b1;
            end
            else begin
                cnt_100hz  <= cnt_100hz + 1'b1;
                tick_100hz <= 1'b0;
            end

            // 1 kHz：每 1 ms 一个脉冲，给扫描、消抖、蜂鸣器节奏用，同时是按键消抖计数的时基
            if (cnt_1khz == DIV_1KHZ - 1) begin  // nibble_key/core_key 的消抖计数只在 tick_1khz 为 1 的拍前进一步
                cnt_1khz  <= 26'd0;
                tick_1khz <= 1'b1;
            end
            else begin
                cnt_1khz  <= cnt_1khz + 1'b1;
                tick_1khz <= 1'b0;
            end

            // 2 Hz 闪烁：每 250 ms 一个脉冲，显示模块每来一次翻转一次（翻转两次才构成完整 2 Hz 周期）
            if (cnt_2hz == DIV_2HZ - 1) begin  // 计满半周期就翻转一次
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

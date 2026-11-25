//============================================================================
// 文件名  : core_key.v
// 功能    : 核心板独立按键的消抖、按下脉冲和长按连发
// 说明    : 按键低有效；K1 不使用连发，K2/K3 使用 0.5 s 后 10 Hz 连发。（REPEAT_EN 由 key_input 例化时按 K1~K4 分别取值）
//============================================================================
module core_key #(
    parameter integer DEBOUNCE_MS     = 20,   // 消抖时间（ms）：输入与 level 不同并连续保持这么久才改判
    parameter integer REPEAT_DELAY_MS = 500,  // 长按后开始连发的等待时间（ms）：按住 0.5 s 才连发
    parameter integer REPEAT_RATE_MS  = 100,  // 连发间隔（ms）：连发阶段每 100 ms 发一个 press
    parameter integer REPEAT_EN       = 0     // 0=不连发（只发一次按下脉冲），1=使能连发；K2/K3 为 1，K1/K4 为 0
)(
    input  wire clk,                          // 系统 50 MHz 时钟，所有寄存器都在此上升沿更新
    input  wire rst_n,                        // 同步复位，低有效
    input  wire tick_1khz,                    // 1 ms 使能，来自 clk_gen；消抖与连发计数都以它为时基
    input  wire key_n,                        // 核心板按键输入，低有效：0=按下，1=松开
    output reg  press                         // 按下事件：单周期脉冲；连发阶段每 100 ms 再补一个
);

    reg [1:0] sync0;                          // 2 位移位同步的第一级：{sync0[0],key_n} 使 [0] 是最新采样、[1] 是上一拍
    reg [1:0] sync1;                          // 第二级同步：[1] 才是滞后两拍、可供状态机使用的稳定样本
    reg       level;       // 1=松开，0=按下，只有 db_cnt 计满时才允许更新，代表消抖后的状态
    reg [4:0] db_cnt;      // 20 ms 消抖，0~19：与 level 不符已持续的毫秒数，计满 DEBOUNCE_MS 就改判 level
    reg [8:0] hold_cnt;    // 0.5 s 连发延时，按下已持续的毫秒数，只在还没进入连发时累加
    reg [6:0] rep_cnt;     // 100 ms 连发间隔，连发阶段两次 press 之间的毫秒数
    reg       repeating;                      // 0=还没进入连发，1=已进入连发；进入后由 rep_cnt 每 100 ms 发一个 press

    always @(posedge clk) begin               // 唯一时序块：同步、20 ms 消抖、0.5 s 延时、100 ms 连发都在这里
        sync0 <= {sync0[0], key_n};           // 同步移位不受复位影响，复位期间也持续采 key_n
        sync1 <= sync0;

        if (!rst_n) begin                     // 复位：level 回 1（松开），三个计数器清零，repeating 清 0，press 拉低
            level     <= 1'b1;
            db_cnt    <= 5'd0;
            hold_cnt  <= 9'd0;
            rep_cnt   <= 7'd0;
            repeating <= 1'b0;
            press     <= 1'b0;
        end
        else begin
            press <= 1'b0;                    // 默认每拍清 0，所以每个 press 都只有一拍宽

            if (tick_1khz) begin              // 每 1 ms 走一步，计数器单位就是毫秒
                if (sync1[1] != level) begin  // 输入电平与当前稳定值不一致，先当抖动处理，开始计时
                    // 输入与当前稳定值不同，等 20 ms
                    if (db_cnt == DEBOUNCE_MS - 1) begin  // 不一致已持续 20 ms：认定电平真的变了，同时把连发状态全部复位
                        level     <= sync1[1];
                        db_cnt    <= 5'd0;
                        hold_cnt  <= 9'd0;
                        rep_cnt   <= 7'd0;
                        repeating <= 1'b0;
                        if (sync1[1] == 1'b0)  // 只在新电平是低（按下）时才发 press，松开不产生事件
                            press <= 1'b1;  // 刚按下，这是整个按键序列的第一个脉冲
                    end
                    else begin
                        db_cnt <= db_cnt + 1'b1;  // 还没到 20 ms，继续等；中途再抖会被清零
                    end
                end
                else begin                    // 输入与 level 一致：已经稳定，消抖计时清零
                    db_cnt <= 5'd0;

                    if ((level == 1'b0) && (REPEAT_EN != 0)) begin  // 只有按住且本键允许连发才计数；REPEAT_EN 是参数，综合时被常量折叠
                        if (!repeating) begin  // 还没进入连发：先等满 REPEAT_DELAY_MS 的按住时间
                            if (hold_cnt == REPEAT_DELAY_MS - 1) begin  // 按住满 0.5 s：置连发标志，并立刻补发第一个连发脉冲
                                repeating <= 1'b1;
                                hold_cnt  <= 9'd0;
                                rep_cnt   <= 7'd0;
                                press     <= 1'b1;
                            end
                            else begin
                                hold_cnt <= hold_cnt + 1'b1;  // 没到 0.5 s 继续累加
                            end
                        end
                        else begin
                            if (rep_cnt == REPEAT_RATE_MS - 1) begin  // 连发阶段每满 100 ms 再发一个 press
                                rep_cnt <= 7'd0;  // 清零重新计时，形成 10 Hz 连发
                                press   <= 1'b1;
                            end
                            else begin
                                rep_cnt <= rep_cnt + 1'b1;  // 没到 100 ms 继续等
                            end
                        end
                    end
                end
            end
        end
    end

endmodule

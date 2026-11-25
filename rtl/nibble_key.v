//============================================================================
// 文件名  : nibble_key.v
// 功能    : 模式 9 的单路 4 位按键检测
// 原理    : 底板 CPLD 每按一次让 nibble 加 1，FPGA 只检测“值变化”。
//           先两级同步，再连续 20 ms 保持不变，才认为是一次有效按下。（被 key_input 例化 8 次，键 1~8；每路只输出一个单周期 press）
//============================================================================
module nibble_key #(
    parameter integer DEBOUNCE_MS = 20        // 稳定时间门限（ms），靠 tick_1khz 计数；20 ms 足够滤掉机械与 CPLD 抖动
)(
    input  wire       clk,                    // 系统 50 MHz 时钟，所有寄存器都在此上升沿更新
    input  wire       rst_n,                  // 同步复位，低有效；只有同步级在复位期间仍持续跟随输入
    input  wire       tick_1khz,   // 1 ms 使能，来自 clk_gen，只有它为 1 的拍才推进一步状态机
    input  wire [3:0] nibble_in,              // 底板 4 位按键计数器的当前值：按一次 +1；异步输入，必须先同步
    output reg        press        // 单周期脉冲，确认到新值时高一个 clk，可直接当按键事件给顶层
);

    reg [3:0] sync0;                          // 第一级同步：直接采异步的 nibble_in，把亚稳态挡在这一级
    reg [3:0] sync1;                          // 第二级同步：后续逻辑只读 sync1，不再碰异步输入
    reg [3:0] prev;       // 上一次已经确认的值，也就是当前稳定值，只有它变了才可能产生 press
    reg [3:0] candidate;  // 正在确认的新值，输入一变就重新装载它并把 cnt 清 0
    reg [4:0] cnt;        // 0 ~ 19，candidate 连续不变的毫秒数，计到 DEBOUNCE_MS-1 才确认
    reg       initialized;                    // 0=还没锁存上电基准，1=已初始化；上电先锁一次基准，避免误报按键

    always @(posedge clk) begin               // 唯一时序块：两级同步 + 20 ms 稳定判定都在 50 MHz 域内完成
        sync0 <= nibble_in;                   // 同步级不受复位影响，复位期间也持续采样
        sync1 <= sync0;

        if (!rst_n) begin                     // 复位：状态机回初始值，press 拉低，initialized 清 0 等重新锁基准
            prev        <= 4'd0;
            candidate   <= 4'd0;
            cnt         <= 5'd0;
            initialized <= 1'b0;
            press       <= 1'b0;
        end
        else begin
            press <= 1'b0;                    // 默认每拍清 0，只有下面确认到新值时才重新拉高一拍，保证单周期

            if (tick_1khz) begin              // 每毫秒只走一步，20 拍正好 20 ms
                if (!initialized) begin       // 上电第一拍只锁基准、不做判定，所以初始化本身不会产生 press
                    // 上电后先把当前值锁存为基准，避免误报一次按键
                    prev        <= sync1;
                    candidate   <= sync1;
                    cnt         <= 5'd0;
                    initialized <= 1'b1;
                end
                else if (sync1 != candidate) begin  // 输入还在变：重新装载候选值并清零计时，抖动期间永远计不满
                    // 输入还在变，重新计时
                    candidate <= sync1;
                    cnt       <= 5'd0;
                end
                else if (candidate != prev) begin  // 输入已稳定且与旧值不同：才开始（或继续）计这 20 ms
                    if (cnt == DEBOUNCE_MS - 1) begin  // 连续稳定满 20 ms 才认账，此时才更新 prev 并发出一个 press
                        prev  <= candidate;
                        press <= 1'b1;        // 确认有效按下，单周期脉冲，下游可直接当事件用
                        cnt   <= 5'd0;
                    end
                    else begin
                        cnt <= cnt + 1'b1;    // 还没满 20 ms，继续等
                    end
                end
                else begin                    // 值与 prev 相同，说明没变化，计时器保持 0，不产生 press
                    cnt <= 5'd0;              // 清零，等下一次变化重新计时
                end
            end
        end
    end

endmodule

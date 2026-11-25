//============================================================================
// 文件名  : key_ctrl.v
// 功能    : 模式/设置状态机，把按键脉冲翻译成各模块的动作
// 说明    : key_press[0]~[7] 对应键 1~8；core_press[0]~[3] 对应 K1~K4。
//           K1 只做全局复位，本模块不处理 core_press[0]。
//============================================================================
module key_ctrl(
    input  wire       clk, // 50 MHz 系统时钟，本模块所有寄存器在其上升沿更新
    input  wire       rst_n, // 低有效同步复位（同步于 clk），复位回 CL 并清全部脉冲
    input  wire [7:0] key_press, // 按键单周期脉冲，[0]~[7] 对应键 1~8，高有效；由按键消抖模块写入
    input  wire [3:0] core_press, // 核心板按键脉冲，[0]~[3] 对应 K1~K4；K1 已做全局复位，本模块只用 [1]~[3]
    input  wire       cd_running, // 倒计时运行标志，1=运行中；用于禁止运行中进入设置
    input  wire       cd_expired, // 倒计时到期标志，1=已到期；用于禁止到期后再次进入设置
    // 状态输出：当前模式、是否在设置、编辑光标位置
    output reg  [1:0] mode, // 当前模式，00=CL 时钟 / 01=AL 闹钟 / 10=St 秒表 / 11=Cd 倒计时；本模块唯一写者
    output reg        setting, // 设置态标志，1=正在编辑且光标有效；键 7/K4 置位，确认或键 8 清除
    output reg  [2:0] cursor, // 编辑光标 0~5：时十/时个/分十/分个/秒十/秒个；送 bcd_digit_adj 选位
    // 单周期动作脉冲：默认 0，事件拍置 1，下游模块据此只做一次动作
    output reg        edit_load, // 进入设置：把当前正式值装载到编辑缓冲
    output reg        edit_commit, // 确认设置：把编辑缓冲写回正式值
    output reg        digit_inc, // 光标位加 1，只影响 cursor 选中位
    output reg        digit_dec, // 光标位减 1，只影响 cursor 选中位
    // 闹钟、秒表、倒计时的动作脉冲与静音脉冲
    output reg        alarm_en_toggle, // 翻转闹钟使能，AL 模式下键 1 触发
    output reg        sw_start_pause, // 秒表启动/暂停，St 模式下键 1 触发
    output reg        sw_clear, // 秒表清零，St 模式下键 2 触发
    output reg        cd_start_pause, // 倒计时启动/暂停，Cd 模式下键 1 触发
    output reg        cd_reset, // 倒计时恢复设定值，Cd 模式且未运行时键 2 触发
    output reg        beep_silence // 蜂鸣静音，任意按键当拍有效
);
    // 模式编码：两位二进制，数值顺序即按键切换顺序
    localparam [1:0] MODE_CL = 2'b00; // CL 时钟模式
    localparam [1:0] MODE_AL = 2'b01; // AL 闹钟模式
    localparam [1:0] MODE_ST = 2'b10; // St 秒表模式
    localparam [1:0] MODE_CD = 2'b11; // Cd 倒计时模式
    // 进入/确认请求：键 7 与 K4 逻辑或
    wire enter_req; // 键 7 或 K4 的进入/确认请求，组合或，避免两处重复判断
    assign enter_req = key_press[6] | core_press[3]; // 键 7 或 K4；K4 与键 7 等价
    // 模式循环函数：CL→AL→St→Cd→CL，纯组合，不能有时序
    // 下一个模式：CL -> AL -> St -> Cd -> CL
    function [1:0] next_mode; // 输入当前模式，返回键 8 切换后的下一个模式
        input [1:0] m; // m：当前 mode[1:0]
        begin
            case (m)
                MODE_CL: next_mode = MODE_AL; // CL 之后是 AL
                MODE_AL: next_mode = MODE_ST; // AL 之后是 St
                MODE_ST: next_mode = MODE_CD; // St 之后是 Cd
                MODE_CD: next_mode = MODE_CL; // Cd 之后回到 CL
                default: next_mode = MODE_CL; // 非法编码兜底回 CL，保证状态机可恢复
            endcase
        end
    endfunction
    // 状态机时序主体：clk 上升沿更新，低有效同步复位
    always @(posedge clk) begin // 模式、光标和全部动作脉冲统一在 clk 上升沿更新；用 <= 让各寄存器并行更新
        if (!rst_n) begin // 同步复位：仅在 clk 上升沿生效
            mode           <= MODE_CL; // 复位模式为 CL
            setting        <= 1'b0; // 复位退出设置态
            cursor         <= 3'd0; // 复位光标到时的十位
            // 复位时动作脉冲全为 0：上电不会误启动秒表/倒计时或误触发闹钟
            edit_load      <= 1'b0; // 进入设置脉冲复位
            edit_commit    <= 1'b0;
            digit_inc      <= 1'b0;
            digit_dec      <= 1'b0;
            // 闹钟/秒表/倒计时脉冲同样复位为 0
            alarm_en_toggle <= 1'b0; // 闹钟开关翻转脉冲复位
            sw_start_pause  <= 1'b0;
            sw_clear        <= 1'b0;
            cd_start_pause  <= 1'b0;
            cd_reset        <= 1'b0;
            beep_silence    <= 1'b0;
        end
        else begin // 复位撤销后：先默认清零，再按事件置位
            // 默认每周期清零，需要时置一个时钟周期的脉冲；因此下面各分支只负责把对应位置 1
            edit_load       <= 1'b0;
            edit_commit     <= 1'b0;
            digit_inc       <= 1'b0;
            digit_dec       <= 1'b0;
            // 先全部默认清零，保证任何动作最多只持续一个时钟周期
            alarm_en_toggle <= 1'b0; // 闹钟开关翻转脉冲默认清零
            sw_start_pause  <= 1'b0;
            sw_clear        <= 1'b0;
            cd_start_pause  <= 1'b0;
            cd_reset        <= 1'b0;
            // beep_silence 例外：由按键组合电平直接产生，不是事件脉冲
            // 任意按键都可以提前静音
            beep_silence <= (|key_press) | (|core_press); // 任意键（含 K1 复位键）按下即静音
            // 优先级：键 8 > 键 7/K4 > 设置态按键 > 正常态按键
            //----------------------------------------------------------------
            // 键 8：优先处理。设置中先取消，再切模式。
            //----------------------------------------------------------------
            if (key_press[7]) begin // 键 8 最高优先级：设置态先取消，正常态则切到下一个模式
                setting <= 1'b0; // 取消设置
                cursor  <= 3'd0; // 光标归零
                mode    <= next_mode(mode); // 切到下一个模式
            end
            // 高优先级分支用 else if 串联，保证同一拍只执行一个动作
            //----------------------------------------------------------------
            // 键 7 / K4：进入设置或确认退出
            //----------------------------------------------------------------
            else if (enter_req) begin // 键 7/K4 次高优先级：设置态=确认退出，正常态=进入设置
                if (setting) begin // 设置态下再按进入键表示确认
                    edit_commit <= 1'b1; // 发出确认单拍脉冲，写回正式值
                    setting     <= 1'b0; // 退出设置
                    cursor      <= 3'd0; // 光标归零
                end
                else if ((mode == MODE_CL) || // CL/AL 随时可设置；Cd 只在未运行且未到期时可设置；St 不提供设置
                         (mode == MODE_AL) ||
                         ((mode == MODE_CD) && (!cd_running) && (!cd_expired))) begin
                    edit_load <= 1'b1; // 装载当前正式值到编辑缓冲
                    setting   <= 1'b1; // 进入设置态
                    cursor    <= 3'd0; // 光标从时十位开始
                end
            end
            // 光标 0~5 依次对应时十/时个/分十/分个/秒十/秒个
            //----------------------------------------------------------------
            // 设置状态：光标移动、加、减
            //----------------------------------------------------------------
            else if (setting) begin // 设置态按键：光标移动优先于加/减，避免同拍多动作
                if (key_press[3]) begin // 键 4 左移光标
                    // 键 4：光标左移，0~5 循环；0 再减回绕到 5
                    if (cursor == 3'd0) // 已在最左则回绕到 5
                        cursor <= 3'd5;
                    else
                        cursor <= cursor - 1'b1;
                end
                else if (key_press[2]) begin // 键 3 右移光标
                    // 键 3：光标右移，0~5 循环；5 再加回绕到 0
                    if (cursor == 3'd5) // 已在最右则回绕到 0
                        cursor <= 3'd0;
                    else
                        cursor <= cursor + 1'b1;
                end
                else if (key_press[1] | core_press[1]) begin // 键 2 或 K2 加 1
                    // 键 2 或 K2：加 1；只发单拍脉冲，实际加减由 bcd_digit_adj 完成
                    digit_inc <= 1'b1;
                end
                else if (key_press[0] | core_press[2]) begin // 键 1 或 K3 减 1
                    // 键 1 或 K3：减 1；K3 与键 1 等价
                    digit_dec <= 1'b1;
                end
            end
            // 正常态：按 mode 分发，AL/St/Cd 的键 1、键 2 含义各不相同
            //----------------------------------------------------------------
            // 正常显示状态：各模式自己的按键
            //----------------------------------------------------------------
            else begin
                case (mode) // 按当前模式分发按键；同拍只响应一个分支
                    MODE_CL: begin // CL 模式没有专属功能键
                        // 键 1~6 无操作；只能按键 7 进设置或键 8 切模式
                    end

                    MODE_AL: begin // AL 模式：键 1 开关闹钟
                        if (key_press[0]) // 键 1 翻转闹钟使能
                            alarm_en_toggle <= 1'b1;
                    end

                    MODE_ST: begin // St 模式：键 1 启停、键 2 清零
                        if (key_press[0]) // 键 1 启动/暂停
                            sw_start_pause <= 1'b1;
                        else if (key_press[1]) // 键 2 清零；与启停互斥，同拍优先启停
                            sw_clear <= 1'b1;
                    end

                    MODE_CD: begin // Cd 模式：键 1 启停、键 2 恢复设定值
                        // 键 1：启动/暂停（和秒表一致，键 1 恒定表示"运行/暂停"）
                        if (key_press[0])
                            cd_start_pause <= 1'b1;
                        // 键 2：恢复设定值（未运行时）。原来键 6 的"复位"与键 2 的
                        //       "清零"合并成一个键；需要 00:00:00 就到设置里把六位改成 0
                        else if (key_press[1] && (!cd_running)) // 键 2 且未运行才恢复设定值，运行中忽略
                            cd_reset <= 1'b1; // 恢复设定值，不是清零
                    end

                    default: begin // 两位模式已穷举，default 仅作兜底
                        // 保持；不产生任何动作
                    end
                endcase
            end
        end
    end

endmodule

//============================================================================
// 文件名  : digital_clock_top.v
// 功能    : 电子时钟顶层
// 平台    : 杭州康芯 KX-MS65 + KX-10CL006/10，Quartus 17.1
// 说明    : 模式 9 显示 + 模式 9 按键 + 核心板 K1~K4
//============================================================================
module digital_clock_top #( // 顶层：时钟 + 闹钟 + 秒表 + 倒计时 + 显示
    parameter integer CLK_FREQ = 50_000_000, // 输入时钟频率，默认 50 MHz
    parameter integer SIM_FAST = 0 // 仿真加速：非 0 时把复位/消抖计数上限缩到 4
)(
    input  wire        clk50,        // M15, 50 MHz
    input  wire [15:0] pi_in,        // 模式 9：键 1~4
    input  wire [15:0] pio_in,       // 模式 9：键 5~8
    input  wire [3:0]  key_core_n,   // K1~K4，低有效
    output wire [7:0]  seg_n,        // 段选，低有效
    output wire [7:0]  dig_n,        // 位选，低有效
    output wire        buzzer,       // 蜂鸣器，低有效
    output wire [3:0]  led_n         // LED1~4，低有效
);

    //------------------------------------------------------------------------
    // 上电复位 + K1 手动复位
    //------------------------------------------------------------------------
    localparam integer POR_DIV = (SIM_FAST != 0) ? 4 : 1_000_000; // 20 ms @50MHz
    localparam integer K1_DIV  = (SIM_FAST != 0) ? 4 : 1_000_000; // K1 消抖计数上限，同样约 20 ms
    // 20 位计数器足以覆盖 1_000_000 个 50 MHz 周期
    reg [19:0] por_cnt  = 20'd0; // 上电复位计数器
    reg        por_done = 1'b0; // 1=上电复位完成
    // 上电复位：计满 POR_DIV 后 por_done 置 1 并保持
    always @(posedge clk50) begin // 50 MHz 同步计数
        if (!por_done) begin // 复位未完成时一直计数
            if (por_cnt == POR_DIV - 1) begin // 计到上限
                por_cnt  <= 20'd0; // 计数器回零
                por_done <= 1'b1; // 置复位完成标志
            end
            else begin // 未到上限
                por_cnt <= por_cnt + 1'b1; // 继续加一
            end
        end
    end
    // K1 同步与消抖寄存器
    reg [1:0]  k1_sync = 2'b11; // K1 两级同步寄存器，初值 11（松开）
    reg [19:0] k1_cnt  = 20'd0; // 消抖计数器
    reg        k1_db   = 1'b0;      // 1=松开，0=按下
    // K1 消抖：输入与稳定值不同时计数，连续 20 ms 一致才更新
    always @(posedge clk50) begin // 同步 + 消抖
        k1_sync <= {k1_sync[0], key_core_n[0]}; // 两级移位同步，消除亚稳态
        // 上电复位期间强制 K1 为松开
        if (!por_done) begin // 上电复位期间
            k1_cnt <= 20'd0; // 清计数
            k1_db  <= 1'b0; // K1 视为松开
        end
        else if (k1_sync[1] != k1_db) begin // 输入电平与稳定值不同，开始计时
            if (k1_cnt == K1_DIV - 1) begin // 连续一致达到 20 ms
                k1_db  <= k1_sync[1]; // 接受新电平
                k1_cnt <= 20'd0; // 清计数
            end
            else begin // 尚未稳定
                k1_cnt <= k1_cnt + 1'b1; // 继续计时
            end
        end
        else begin // 输入与稳定值相同
            k1_cnt <= 20'd0; // 计数清零
        end
    end
    // 系统复位 = 上电复位完成 且 K1 未按下
    wire sys_rst_n = por_done & k1_db; // 低有效：por_done=1 且 k1_db=1 时释放复位

    //------------------------------------------------------------------------
    // 模块之间的连线
    //------------------------------------------------------------------------
    wire tick_1hz; // 1 Hz：走时/倒计时
    wire tick_100hz; // 100 Hz：秒表 10 ms
    wire tick_1khz; // 1 kHz：扫描与按键采样
    wire tick_2hz; // 2 Hz：闪烁
    // 按键事件
    wire [7:0] key_press; // 8 个按键的按下事件
    wire [3:0] core_press; // K1~K4 的按下事件
    // 模式与设置
    wire [1:0] mode; // 当前模式
    wire       setting; // 设置中
    wire [2:0] cursor; // 设置光标
    // 编辑命令
    wire edit_load; // 装载编辑值
    wire edit_commit; // 提交编辑值
    wire digit_inc; // 当前位加一
    wire digit_dec; // 当前位减一
    // 功能控制命令
    wire alarm_en_toggle; // 闹钟开关翻转
    wire sw_start_pause; // 秒表启动/暂停
    wire sw_clear; // 秒表清零
    wire cd_start_pause; // 倒计时启动/暂停
    wire cd_reset; // 倒计时复位
    wire beep_silence; // 静音
    // 时钟与闹钟数据
    wire [23:0] time_bcd; // 当前时间 BCD
    wire [23:0] time_edit_bcd; // 时间编辑值
    wire [23:0] alarm_bcd; // 闹钟设定值
    wire [23:0] alarm_edit_bcd; // 闹钟编辑值
    wire        alarm_en; // 闹钟开关
    wire        alarm_trigger; // 闹钟到点脉冲
    // 秒表数据
    wire [7:0] sw_min_bcd; // 秒表分钟
    wire [7:0] sw_sec_bcd; // 秒表秒
    wire [7:0] sw_cs_bcd; // 秒表百分秒
    wire       sw_running; // 秒表运行中
    // 倒计时数据
    wire [23:0] cd_preset_bcd; // 倒计时预置值
    wire [23:0] cd_remain_bcd; // 倒计时剩余值
    wire [23:0] cd_edit_bcd; // 倒计时编辑值
    wire        cd_running; // 运行中
    wire        cd_paused; // 暂停
    wire        cd_expired; // 到期
    wire        cd_expire_pulse; // 到期单脉冲
    // 提示音
    wire beep_en; // 提示音节奏使能

    //------------------------------------------------------------------------
    // 分频器
    //------------------------------------------------------------------------
    clk_gen #( // 例化时基分频器
        .CLK_FREQ(CLK_FREQ), // 传入 50 MHz
        .SIM_FAST(SIM_FAST) // 传入仿真加速开关
    ) u_clk_gen ( // 例化名 u_clk_gen
        .clk(clk50), // 50 MHz 输入
        .rst_n(sys_rst_n), // 系统复位
        .tick_1hz(tick_1hz), // 1 Hz 使能
        .tick_100hz(tick_100hz), // 100 Hz 使能
        .tick_1khz(tick_1khz), // 1 kHz 使能
        .tick_2hz(tick_2hz) // 2 Hz 使能
    );

    //------------------------------------------------------------------------
    // 按键输入
    //------------------------------------------------------------------------
    key_input u_key_input ( // 例化名 u_key_input
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz), // 1 ms 采样一次，用于消抖
        .pi_in(pi_in), // 模式 9：键 1~4
        .pio_in(pio_in), // 模式 9：键 5~8
        .key_core_n(key_core_n), // 核心板 K1~K4
        .key_press(key_press), // 8 键按下事件
        .core_press(core_press) // K1~K4 按下事件
    );

    //------------------------------------------------------------------------
    // 模式/设置状态机
    //------------------------------------------------------------------------
    key_ctrl u_key_ctrl ( // 例化名 u_key_ctrl
        .clk(clk50),
        .rst_n(sys_rst_n),
        .key_press(key_press),
        .core_press(core_press),
        .cd_running(cd_running), // 倒计时运行中（限制某些按键）
        .cd_expired(cd_expired), // 倒计时到期状态
        .mode(mode), // 模式输出
        .setting(setting), // 设置状态输出
        .cursor(cursor), // 光标输出
        .edit_load(edit_load), // 装载编辑值
        .edit_commit(edit_commit), // 提交编辑值
        .digit_inc(digit_inc), // 加一
        .digit_dec(digit_dec), // 减一
        .alarm_en_toggle(alarm_en_toggle), // 闹钟开关
        .sw_start_pause(sw_start_pause), // 秒表启停
        .sw_clear(sw_clear), // 秒表清零
        .cd_start_pause(cd_start_pause), // 倒计时启停
        .cd_reset(cd_reset), // 倒计时复位
        .beep_silence(beep_silence) // 静音
    );

    //------------------------------------------------------------------------
    // 时钟
    //------------------------------------------------------------------------
    time_counter u_time_counter ( // 例化名 u_time_counter
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1hz(tick_1hz),
        .mode(mode), // 仅在 CL 模式走时
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .time_bcd(time_bcd), // 当前时间输出
        .edit_bcd(time_edit_bcd) // 编辑值输出
    );

    //------------------------------------------------------------------------
    // 闹钟
    //------------------------------------------------------------------------
    alarm_ctrl u_alarm_ctrl ( // 例化名 u_alarm_ctrl
        .clk(clk50),
        .rst_n(sys_rst_n),
        .mode(mode),
        .time_bcd(time_bcd), // 当前时间，用于到点比较
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .alarm_en_toggle(alarm_en_toggle), // 闹钟开关翻转
        .alarm_bcd(alarm_bcd),
        .alarm_edit_bcd(alarm_edit_bcd),
        .alarm_en(alarm_en), // 闹钟开关状态
        .alarm_trigger(alarm_trigger) // 到点脉冲
    );

    //------------------------------------------------------------------------
    // 秒表
    //------------------------------------------------------------------------
    stopwatch u_stopwatch ( // 例化名 u_stopwatch
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_100hz(tick_100hz), // 10 ms 时基
        .start_pause(sw_start_pause),
        .clear(sw_clear),
        .min_bcd(sw_min_bcd), // 分钟
        .sec_bcd(sw_sec_bcd), // 秒
        .cs_bcd(sw_cs_bcd), // 百分秒
        .running(sw_running) // 运行标志
    );

    //------------------------------------------------------------------------
    // 倒计时
    //------------------------------------------------------------------------
    countdown u_countdown ( // 例化名 u_countdown
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1hz(tick_1hz), // 1 Hz 递减
        .mode(mode),
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .start_pause(cd_start_pause), // 启动/暂停
        .reset(cd_reset), // 复位
        .preset_bcd(cd_preset_bcd),
        .remain_bcd(cd_remain_bcd),
        .edit_bcd(cd_edit_bcd),
        .running(cd_running), // 运行中
        .paused(cd_paused), // 暂停
        .expired(cd_expired), // 到期
        .expire_pulse(cd_expire_pulse) // 到期单脉冲
    );

    //------------------------------------------------------------------------
    // 提示音节奏 + 2.7 kHz 方波
    //------------------------------------------------------------------------
    beep_ctrl u_beep_ctrl ( // 例化名 u_beep_ctrl
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz), // 1 ms 节奏
        .alarm_trigger(alarm_trigger), // 闹钟到点
        .cd_expire(cd_expire_pulse), // 倒计时到期
        .silence(beep_silence), // 静音
        .beep_en(beep_en) // 节奏使能
    );
    // 蜂鸣器方波：SIM_FAST 下同样缩短分频
    buzzer_tone #( // 例化名 u_buzzer_tone
        .SIM_FAST(SIM_FAST) // 仿真加速
    ) u_buzzer_tone (
        .clk(clk50), // 50 MHz
        .rst_n(sys_rst_n),
        .beep_en(beep_en), // 节奏使能
        .buzzer(buzzer) // 低有效蜂鸣器输出
    );

    //------------------------------------------------------------------------
    // 显示
    //------------------------------------------------------------------------
    display_ctrl u_display_ctrl ( // 例化名 u_display_ctrl
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz), // 1 ms 扫描
        .tick_2hz(tick_2hz), // 2 Hz 闪烁
        .mode(mode), // 模式
        .setting(setting), // 设置中
        .cursor(cursor), // 光标
        .time_bcd(time_bcd), // 当前时间
        .edit_bcd(time_edit_bcd), // 时间编辑值
        .alarm_bcd(alarm_bcd), // 闹钟设定值
        .alarm_edit_bcd(alarm_edit_bcd), // 闹钟编辑值
        .sw_min_bcd(sw_min_bcd), // 秒表分钟
        .sw_sec_bcd(sw_sec_bcd), // 秒表秒
        .sw_cs_bcd(sw_cs_bcd), // 秒表百分秒
        .sw_running(sw_running), // 秒表运行
        .cd_remain_bcd(cd_remain_bcd), // 倒计时剩余
        .cd_edit_bcd(cd_edit_bcd), // 倒计时编辑值
        .cd_running(cd_running), // 运行中
        .cd_paused(cd_paused), // 暂停
        .cd_expired(cd_expired), // 到期
        .alarm_en(alarm_en), // 闹钟开关
        .seg_n(seg_n), // 段选输出
        .dig_n(dig_n), // 位选输出
        .led_n(led_n) // LED 输出
    );
    // 所有子模块例化完毕
endmodule // 模块结束

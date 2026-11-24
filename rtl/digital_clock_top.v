//============================================================================
// 文件名  : digital_clock_top.v
// 功能    : 电子时钟顶层
// 平台    : 杭州康芯 KX-MS65 + KX-10CL006/10，Quartus 17.1
// 说明    : 模式 9 显示 + 模式 9 按键 + 核心板 K1~K4
//============================================================================
module digital_clock_top #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer SIM_FAST = 0
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
    localparam integer K1_DIV  = (SIM_FAST != 0) ? 4 : 1_000_000;

    reg [19:0] por_cnt  = 20'd0;
    reg        por_done = 1'b0;

    always @(posedge clk50) begin
        if (!por_done) begin
            if (por_cnt == POR_DIV - 1) begin
                por_cnt  <= 20'd0;
                por_done <= 1'b1;
            end
            else begin
                por_cnt <= por_cnt + 1'b1;
            end
        end
    end

    reg [1:0]  k1_sync = 2'b11;
    reg [19:0] k1_cnt  = 20'd0;
    reg        k1_db   = 1'b0;      // 1=松开，0=按下

    always @(posedge clk50) begin
        k1_sync <= {k1_sync[0], key_core_n[0]};

        if (!por_done) begin
            k1_cnt <= 20'd0;
            k1_db  <= 1'b0;
        end
        else if (k1_sync[1] != k1_db) begin
            if (k1_cnt == K1_DIV - 1) begin
                k1_db  <= k1_sync[1];
                k1_cnt <= 20'd0;
            end
            else begin
                k1_cnt <= k1_cnt + 1'b1;
            end
        end
        else begin
            k1_cnt <= 20'd0;
        end
    end

    wire sys_rst_n = por_done & k1_db;

    //------------------------------------------------------------------------
    // 模块之间的连线
    //------------------------------------------------------------------------
    wire tick_1hz;
    wire tick_100hz;
    wire tick_1khz;
    wire tick_2hz;

    wire [7:0] key_press;
    wire [3:0] core_press;

    wire [1:0] mode;
    wire       setting;
    wire [2:0] cursor;

    wire edit_load;
    wire edit_commit;
    wire digit_inc;
    wire digit_dec;

    wire alarm_en_toggle;
    wire sw_start_pause;
    wire sw_clear;
    wire cd_start_pause;
    wire cd_reset;
    wire cd_clear;
    wire beep_silence;

    wire [23:0] time_bcd;
    wire [23:0] time_edit_bcd;
    wire [23:0] alarm_bcd;
    wire [23:0] alarm_edit_bcd;
    wire        alarm_en;
    wire        alarm_trigger;

    wire [7:0] sw_min_bcd;
    wire [7:0] sw_sec_bcd;
    wire [7:0] sw_cs_bcd;
    wire       sw_running;

    wire [23:0] cd_preset_bcd;
    wire [23:0] cd_remain_bcd;
    wire [23:0] cd_edit_bcd;
    wire        cd_running;
    wire        cd_paused;
    wire        cd_expired;
    wire        cd_expire_pulse;

    wire beep_en;

    //------------------------------------------------------------------------
    // 分频器
    //------------------------------------------------------------------------
    clk_gen #(
        .CLK_FREQ(CLK_FREQ),
        .SIM_FAST(SIM_FAST)
    ) u_clk_gen (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1hz(tick_1hz),
        .tick_100hz(tick_100hz),
        .tick_1khz(tick_1khz),
        .tick_2hz(tick_2hz)
    );

    //------------------------------------------------------------------------
    // 按键输入
    //------------------------------------------------------------------------
    key_input u_key_input (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz),
        .pi_in(pi_in),
        .pio_in(pio_in),
        .key_core_n(key_core_n),
        .key_press(key_press),
        .core_press(core_press)
    );

    //------------------------------------------------------------------------
    // 模式/设置状态机
    //------------------------------------------------------------------------
    key_ctrl u_key_ctrl (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .key_press(key_press),
        .core_press(core_press),
        .cd_running(cd_running),
        .cd_expired(cd_expired),
        .mode(mode),
        .setting(setting),
        .cursor(cursor),
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .alarm_en_toggle(alarm_en_toggle),
        .sw_start_pause(sw_start_pause),
        .sw_clear(sw_clear),
        .cd_start_pause(cd_start_pause),
        .cd_reset(cd_reset),
        .cd_clear(cd_clear),
        .beep_silence(beep_silence)
    );

    //------------------------------------------------------------------------
    // 时钟
    //------------------------------------------------------------------------
    time_counter u_time_counter (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1hz(tick_1hz),
        .mode(mode),
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .time_bcd(time_bcd),
        .edit_bcd(time_edit_bcd)
    );

    //------------------------------------------------------------------------
    // 闹钟
    //------------------------------------------------------------------------
    alarm_ctrl u_alarm_ctrl (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .mode(mode),
        .time_bcd(time_bcd),
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .alarm_en_toggle(alarm_en_toggle),
        .alarm_bcd(alarm_bcd),
        .alarm_edit_bcd(alarm_edit_bcd),
        .alarm_en(alarm_en),
        .alarm_trigger(alarm_trigger)
    );

    //------------------------------------------------------------------------
    // 秒表
    //------------------------------------------------------------------------
    stopwatch u_stopwatch (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_100hz(tick_100hz),
        .start_pause(sw_start_pause),
        .clear(sw_clear),
        .min_bcd(sw_min_bcd),
        .sec_bcd(sw_sec_bcd),
        .cs_bcd(sw_cs_bcd),
        .running(sw_running)
    );

    //------------------------------------------------------------------------
    // 倒计时
    //------------------------------------------------------------------------
    countdown u_countdown (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1hz(tick_1hz),
        .mode(mode),
        .edit_load(edit_load),
        .edit_commit(edit_commit),
        .digit_inc(digit_inc),
        .digit_dec(digit_dec),
        .cursor(cursor),
        .start_pause(cd_start_pause),
        .reset(cd_reset),
        .clear(cd_clear),
        .preset_bcd(cd_preset_bcd),
        .remain_bcd(cd_remain_bcd),
        .edit_bcd(cd_edit_bcd),
        .running(cd_running),
        .paused(cd_paused),
        .expired(cd_expired),
        .expire_pulse(cd_expire_pulse)
    );

    //------------------------------------------------------------------------
    // 提示音节奏 + 2.7 kHz 方波
    //------------------------------------------------------------------------
    beep_ctrl u_beep_ctrl (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz),
        .alarm_trigger(alarm_trigger),
        .cd_expire(cd_expire_pulse),
        .silence(beep_silence),
        .beep_en(beep_en)
    );

    buzzer_tone #(
        .SIM_FAST(SIM_FAST)
    ) u_buzzer_tone (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .beep_en(beep_en),
        .buzzer(buzzer)
    );

    //------------------------------------------------------------------------
    // 显示
    //------------------------------------------------------------------------
    display_ctrl u_display_ctrl (
        .clk(clk50),
        .rst_n(sys_rst_n),
        .tick_1khz(tick_1khz),
        .tick_2hz(tick_2hz),
        .mode(mode),
        .setting(setting),
        .cursor(cursor),
        .time_bcd(time_bcd),
        .edit_bcd(time_edit_bcd),
        .alarm_bcd(alarm_bcd),
        .alarm_edit_bcd(alarm_edit_bcd),
        .sw_min_bcd(sw_min_bcd),
        .sw_sec_bcd(sw_sec_bcd),
        .sw_cs_bcd(sw_cs_bcd),
        .sw_running(sw_running),
        .cd_remain_bcd(cd_remain_bcd),
        .cd_edit_bcd(cd_edit_bcd),
        .cd_running(cd_running),
        .cd_paused(cd_paused),
        .cd_expired(cd_expired),
        .alarm_en(alarm_en),
        .seg_n(seg_n),
        .dig_n(dig_n),
        .led_n(led_n)
    );

endmodule

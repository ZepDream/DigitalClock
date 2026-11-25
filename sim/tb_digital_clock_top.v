//============================================================================
// 文件名  : tb_digital_clock_top.v
// 功能    : 电子时钟顶层自检 testbench
// 说明    : SIM_FAST=1，把 1 秒缩短到 1000 个 50 MHz 周期，便于快速仿真。
//           通过层次化赋值直接预置时间/闹钟/倒计时，缩短测试时间。
//============================================================================
`timescale 1ns/1ps // 时间单位 1 ns，精度 1 ps

module tb_digital_clock_top; // 自检 testbench，无端口
    // 信号声明
    reg         clk50; // 50 MHz 系统时钟
    reg  [15:0] pi_in; // 模式 9 键 1~4
    reg  [15:0] pio_in; // 模式 9 键 5~8
    reg  [3:0]  key_core_n; // 核心板 K1~K4

    wire [7:0]  seg_n; // 段选观测
    wire [7:0]  dig_n; // 位选观测
    wire        buzzer; // 蜂鸣器观测
    wire [3:0]  led_n; // LED 观测

    integer errors; // 错误计数，最终为 0 表示全部通过
    integer beep_count; // 蜂鸣器起振次数
    integer core2_count; // K2 自动连发次数
    reg [23:0] sw_hold; // 秒表暂停值快照
    reg [23:0] cd_hold; // 倒计时暂停值快照

    //------------------------------------------------------------------------
    // DUT
    //------------------------------------------------------------------------
    digital_clock_top #( // 例化 DUT，SIM_FAST=1 让 1 秒 ≈ 1000 个 50 MHz 周期
        .CLK_FREQ(50_000_000), // 50 MHz
        .SIM_FAST(1) // 仿真加速
    ) dut ( // 例化名 dut，便于层次化访问内部信号
        .clk50(clk50), // 时钟
        .pi_in(pi_in), // 键 1~4
        .pio_in(pio_in), // 键 5~8
        .key_core_n(key_core_n), // K1~K4
        .seg_n(seg_n), // 段选
        .dig_n(dig_n), // 位选
        .buzzer(buzzer), // 蜂鸣器
        .led_n(led_n) // LED
    );

    // 50 MHz，周期 20 ns
    always #10 clk50 = ~clk50; // 产生 50 MHz 时钟

    // 统计蜂鸣器“响”的次数
    always @(posedge dut.beep_en) // beep_en 上升沿计数
        beep_count = beep_count + 1; // 计数值加一

    // 统计 K2 连发次数
    always @(posedge dut.u_key_input.core_press[1]) // 层次化引用 core_press[1]
        core2_count = core2_count + 1; // 计数值加一

    //------------------------------------------------------------------------
    // 基本任务
    //------------------------------------------------------------------------
    task wait_clk(input integer n); // 等待 n 个 50 MHz 周期
        begin
            repeat (n) @(posedge clk50); // 数 n 个上升沿
        end
    endtask

    task wait_1hz(input integer n); // 等待 n 个 1 Hz tick
        begin
            repeat (n) @(posedge dut.tick_1hz); // 等 n 次 1 Hz 使能
            @(posedge clk50); // tick 是使能，模块在下一个时钟沿才更新
            #1; // 再等 1 ns，让组合逻辑稳定
        end
    endtask

    task wait_100hz(input integer n); // 等待 n 个 100 Hz tick（10 ms）
        begin
            repeat (n) @(posedge dut.tick_100hz); // 等 n 次 100 Hz 使能
            @(posedge clk50); // 再等一拍，让模块完成更新
            #1; // 等 1 ns 稳定
        end
    endtask

    task check32(input [255:0] name, input [31:0] actual, input [31:0] expected); // 比较 32 位值
        begin
            if (actual !== expected) begin // 用 !== 精确比较，X/Z 也能发现
                $display("ERROR [%0s] at %0t: got %h, expected %h", name, $time, actual, expected); // 出错时打印实际值与期望值
                errors = errors + 1; // 错误计数加一
            end
            else begin
                $display("PASS  [%0s] = %h", name, actual); // 通过时打印 PASS
            end
        end
    endtask

    task check1(input [255:0] name, input actual, input expected); // 比较 1 位或短向量
        begin
            if (actual !== expected) begin
                $display("ERROR [%0s] at %0t: got %b, expected %b", name, $time, actual, expected); // 出错打印
                errors = errors + 1; // 错误计数加一
            end
            else begin
                $display("PASS  [%0s] = %b", name, actual); // 通过打印
            end
        end
    endtask

    // 按一次模式 9 的键：对应 nibble 加 1，保持足够长时间让 20 ms 消抖通过
    task press_key(input integer k); // 按下模式 9 的第 k 个键
        begin
            case (k) // 按 k 修改对应 nibble，模拟一次按下
                1: pi_in[3:0]   = pi_in[3:0]   + 1'b1; // 键 1：pi_in[3:0] 加一
                2: pi_in[7:4]   = pi_in[7:4]   + 1'b1; // 键 2
                3: pi_in[11:8]  = pi_in[11:8]  + 1'b1; // 键 3
                4: pi_in[15:12] = pi_in[15:12] + 1'b1; // 键 4
                5: pio_in[3:0]  = pio_in[3:0]  + 1'b1; // 键 5：pio_in[3:0] 加一
                6: pio_in[7:4]  = pio_in[7:4]  + 1'b1; // 键 6
                7: pio_in[11:8] = pio_in[11:8] + 1'b1; // 键 7
                8: pio_in[15:12]= pio_in[15:12]+ 1'b1; // 键 8
                default: ; // 非法键号忽略
            endcase
            wait_clk(180); // 180 个周期 = 45 个 1 ms tick，足够 20 ms 消抖
        end
    endtask

    task press_core(input integer k, input integer hold_cycles); // 按下核心板第 k 个键，保持 hold_cycles 个周期
        begin
            key_core_n[k-1] = 1'b0; // 低有效，置 0 表示按下
            wait_clk(hold_cycles); // 保持按下
            key_core_n[k-1] = 1'b1; // 松开
            wait_clk(180); // 等待消抖恢复
        end
    endtask

    task reset_dut; // 通过 K1 复位 DUT
        begin
            key_core_n[0] = 1'b0; // K1 拉低（按下）
            wait_clk(120); // 保持
            key_core_n[0] = 1'b1; // 松开
            wait_clk(260); // 等待复位释放并稳定
        end
    endtask

    // 在 1 Hz 边沿之后预置时间，下一次 tick 就会从该值开始加
    task set_time_at_tick(input [23:0] v); // 在 tick 边沿后预置时间
        begin
            @(posedge dut.tick_1hz); // 对齐 1 Hz 边沿
            @(negedge clk50); // 在时钟低电平写入，避免竞争
            dut.u_time_counter.time_reg = v; // 层次化赋值
        end
    endtask

    task set_alarm(input [23:0] v); // 预置闹钟设定值
        begin
            @(negedge clk50); // 时钟低电平写入
            dut.u_alarm_ctrl.alarm_reg = v; // 写 alarm_reg
        end
    endtask

    task set_alarm_en(input v); // 预置闹钟开关
        begin
            @(negedge clk50); // 时钟低电平写入
            dut.u_alarm_ctrl.en_reg = v; // 写 en_reg
        end
    endtask

    task set_countdown(input [23:0] preset, input [23:0] remain); // 预置倒计时：预置值、剩余值，并清运行/暂停/到期
        begin
            @(negedge clk50); // 时钟低电平写入
            dut.u_countdown.preset_reg = preset; // 写预置值
            dut.u_countdown.remain_reg = remain; // 写剩余值
            dut.u_countdown.run_reg    = 1'b0; // 清运行
            dut.u_countdown.paused_reg = 1'b0; // 清暂停
            dut.u_countdown.expired_reg= 1'b0; // 清到期
        end
    endtask

    task set_stopwatch_max; // 把秒表预置到 99:59.99 并启动
        begin
            @(negedge clk50); // 时钟低电平写入
            dut.u_stopwatch.min_reg = 8'h99; // 分钟 99
            dut.u_stopwatch.sec_reg = 8'h59; // 秒 59
            dut.u_stopwatch.cs_reg  = 8'h99; // 百分秒 99
            dut.u_stopwatch.run_reg = 1'b1; // 启动
        end
    endtask

    task check_dig_onehot; // 检查 dig_n 是否为低有效 one-hot
        integer i; // 循环变量
        integer low_cnt; // 低电平位数统计
        begin
            low_cnt = 0; // 统计清零
            for (i = 0; i < 8; i = i + 1) // 遍历 8 位
                if (dig_n[i] == 1'b0) // 统计低电平位数
                    low_cnt = low_cnt + 1; // 累加

            if (low_cnt != 1) begin // 低电平位数不为 1 说明扫描异常
                $display("ERROR [dig_onehot] at %0t: dig_n=%b, low count=%0d", $time, dig_n, low_cnt); // 打印错误
                errors = errors + 1; // 错误计数加一
            end
        end
    endtask

    //------------------------------------------------------------------------
    // 主流程
    //------------------------------------------------------------------------
    initial begin // 主激励进程
        clk50     = 1'b0; // 时钟初值
        pi_in     = 16'h0000; // 按键输入清零
        pio_in    = 16'h0000; // 按键输入清零
        key_core_n= 4'b1111; // K1~K4 全部松开
        errors    = 0; // 错误计数清零
        beep_count= 0; // 蜂鸣计数清零
        core2_count = 0; // 连发计数清零

        $dumpfile("tb.vcd"); // VCD 文件名
        $dumpvars(0, tb_digital_clock_top); // 转储所有层次

        $display("============================================================"); // 测试标题，字符串不可修改
        $display(" TEST 1 : reset defaults");
        $display("============================================================");
        wait_clk(320); // 等上电复位完成
        check32("mode=CL",        {30'd0, dut.mode}, 32'd0); // 模式应为 CL
        check1 ("setting=0",      dut.setting, 1'b0); // 不在设置状态
        check32("time=00:00:00",  dut.time_bcd, 24'h000000); // 时间为 00:00:00
        check1 ("alarm_en=0",     dut.alarm_en, 1'b0); // 闹钟默认关闭
        check32("alarm=00:00:00", dut.alarm_bcd, 24'h000000); // 闹钟默认 00:00:00
        check32("sw=00:00.00",    {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h000000); // 秒表默认清零
        check32("cd=00:05:00",    dut.cd_remain_bcd, 24'h000500); // 倒计时默认 00:05:00
        check1 ("led all off",    led_n, 4'b1111); // LED 全灭（低有效，全 1）

        $display("============================================================");
        $display(" TEST 2 : 1 Hz tick and rollover"); // TEST 2：1 Hz 走时与进位
        $display("============================================================");
        set_time_at_tick(24'h000059); // 预置 00:00:59
        wait_clk(1);
        #1;
        check32("00:00:59 -> 00:01:00", dut.time_bcd, 24'h000100); // 59 秒进位到 1 分

        set_time_at_tick(24'h235959); // 预置 23:59:59
        wait_clk(1);
        #1;
        check32("23:59:59 -> 00:00:00", dut.time_bcd, 24'h000000); // 跨天回到 00:00:00

        $display("============================================================");
        $display(" TEST 3 : mode 9 key and mode switch"); // TEST 3：按键 8 轮换模式
        $display("============================================================");
        reset_dut();
        press_key(8); // 按第 8 键
        check32("key8 -> AL", {30'd0, dut.mode}, 32'd1); // CL→AL
        press_key(8);
        check32("key8 -> St", {30'd0, dut.mode}, 32'd2); // AL→St
        press_key(8);
        check32("key8 -> Cd", {30'd0, dut.mode}, 32'd3); // St→Cd
        press_key(8);
        check32("key8 -> CL", {30'd0, dut.mode}, 32'd0); // Cd→CL

        $display("============================================================");
        $display(" TEST 4 : CL setting, freeze, commit, cancel"); // TEST 4：CL 设置流程
        $display("============================================================");
        reset_dut(); // 复位
        press_key(7); // 键 7 进入设置
        check1 ("CL enter setting", dut.setting, 1'b1); // 设置标志
        check32("cursor=0", {29'd0, dut.cursor}, 32'd0); // 光标 0
        check32("edit=00:00:00", dut.u_time_counter.edit_reg, 24'h000000); // 编辑值初始 0

        wait_1hz(1); // 等 1 秒
        check32("edit frozen after 1 s", dut.u_time_counter.edit_reg, 24'h000000); // 设置中编辑值冻结
        check32("live time advanced", dut.time_bcd, 24'h000001); // 后台走时仍前进

        press_key(2); // 键 2 加一
        press_key(2); // 再按一次
        check32("hour tens +2 -> 20:00:00", dut.u_time_counter.edit_reg, 24'h200000); // 时十位 +2 → 20:00:00

        press_key(3); // 键 3 光标右移
        check32("cursor right -> 1", {29'd0, dut.cursor}, 32'd1); // 光标变为 1
        press_key(2); // 键 2 加一
        check32("hour ones +1 -> 21:00:00", dut.u_time_counter.edit_reg, 24'h210000); // 21:00:00

        press_key(7); // 键 7 提交
        check1 ("CL commit exits setting", dut.setting, 1'b0); // 退出设置
        check32("time committed 21:00:00", dut.time_bcd, 24'h210000); // 提交后时间生效

        press_key(7); // 再次进入设置
        press_key(3); // 光标移到时的个位
        press_key(2); // 键 2 加一
        check32("edit 22:00:00 before cancel", dut.u_time_counter.edit_reg, 24'h220000); // 取消前编辑值 22:00:00
        press_key(8); // 按第 8 键切模式
        check1 ("key8 cancels setting", dut.setting, 1'b0); // 设置被取消
        check32("key8 -> AL", {30'd0, dut.mode}, 32'd1); // 同时切到 AL
        check32("time not changed by cancel", {dut.time_bcd[23:8], 8'h00}, 24'h210000); // 取消不改变已提交时间

        $display("============================================================");
        $display(" TEST 5 : AL alarm switch and 3x2 beep"); // TEST 5：闹钟开关与提示音
        $display("============================================================");
        reset_dut(); // 复位
        press_key(8); // AL
        set_alarm(24'h000003); // 先设一个非零闹钟，避免在 00:00:00 误触发
        press_key(1); // 键 1 打开闹钟
        check1("alarm on", dut.alarm_en, 1'b1); // alarm_en=1
        wait_clk(5); // 等组合逻辑稳定
        check1("LED2 on", led_n[1], 1'b0); // LED2 点亮
        check1("AL label slow-blink when alarm on", dut.u_display_ctrl.label_slow, 1'b1); // AL 标识慢闪
        press_key(1); // 键 1 关闭
        check1("alarm off", dut.alarm_en, 1'b0); // 关闭
        check1("AL label steady when alarm off", dut.u_display_ctrl.label_slow, 1'b0); // 标识不闪
        press_key(1); // 再次打开
        check1("alarm on again", dut.alarm_en, 1'b1); // 重新打开

        set_alarm(24'h000003); // 设定 00:00:03
        set_alarm_en(1'b1); // 确保开关打开
        set_time_at_tick(24'h000002); // 预置 00:00:02
        beep_count = 0; // 清蜂鸣计数
        wait_clk(5);          // 时间 2 -> 3，alarm_trigger/beep_en 随其后
        #1; // 等 1 ns
        check1("alarm trigger pulse seen", (beep_count > 0), 1'b1); // 观察到触发
        wait_clk(12000);      // 2.4 s 的 3 下 x 2 组（SIM_FAST）
        check32("alarm beep count = 6", beep_count, 6); // 蜂鸣次数 6
        wait_clk(2000);       // 不应再次触发
        check32("alarm still 6 (one shot)", beep_count, 6); // 确认只触发一次

        $display("============================================================");
        $display(" TEST 6 : stopwatch start/pause/clear/max/background"); // TEST 6：秒表
        $display("============================================================");
        reset_dut(); // 复位
        press_key(8); // 切 AL
        press_key(8); // St
        press_key(1); // start
        check1("stopwatch running", dut.sw_running, 1'b1); // 运行中
        wait_100hz(5); // 等 50 ms
        check1("stopwatch cs advanced", (dut.sw_cs_bcd != 8'h00), 1'b1); // 百分秒前进
        press_key(1); // pause
        check1("stopwatch paused", dut.sw_running, 1'b0); // 暂停后 running=0
        sw_hold = {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}; // 记录暂停值
        wait_clk(300); // 等待
        check32("stopwatch hold", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, sw_hold); // 暂停保持
        press_key(2); // clear
        check32("stopwatch clear", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h000000); // 清零为 0

        // 后台运行：启动后切到 Cd，数值应继续增加
        press_key(1); // 重新启动
        press_key(8); // St -> Cd
        wait_100hz(10); // 等 100 ms
        check1("stopwatch runs in background", dut.sw_running, 1'b1); // 后台仍在运行

        // 最大值自动停止
        set_stopwatch_max(); // 预置 99:59.99
        wait_100hz(1); // 等一个 tick
        check1("stopwatch stops at max", dut.sw_running, 1'b0); // 到最大值停止
        check32("stopwatch max value", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h995999); // 最大值为 99:59.99

        $display("============================================================");
        $display(" TEST 7 : countdown set/start/expire/reset/0/pause"); // TEST 7：倒计时
        $display("============================================================");
        reset_dut(); // 复位
        press_key(8); // 切 AL
        press_key(8); // AL→St
        press_key(8); // Cd
        check32("Cd default 00:05:00", dut.cd_remain_bcd, 24'h000500); // 默认 5 分钟
        check1("Cd idle solid", dut.u_display_ctrl.label_blink, 1'b0); // 空闲标识不闪

        set_countdown(24'h000003, 24'h000003); // 预置 3 秒
        beep_count = 0; // 清计数
        press_key(1); // 启动
        check1("Cd running", dut.cd_running, 1'b1); // 运行中
        wait_1hz(3); // 等 3 秒
        check1("Cd expired", dut.cd_expired, 1'b1); // 到期
        check32("Cd remain 0", dut.cd_remain_bcd, 24'h000000); // 剩余 0
        wait_clk(4000); // 等待提示
        check32("Cd beep count = 2", beep_count, 2); // 提示 2 次

        press_key(2); // 键 2 复位
        check1("Cd reset clears expired", dut.cd_expired, 1'b0); // 清除到期
        check32("Cd reset to preset", dut.cd_remain_bcd, 24'h000003); // 恢复预置值

        // 清零键已取消：直接把剩余值置 0，验证"0 启动无效"
        set_countdown(24'h000000, 24'h000000); // 预置 0
        beep_count = 0; // 清计数
        press_key(1); // 尝试启动
        check1("Cd 0 start invalid", dut.cd_running, 1'b0); // 0 秒不能启动
        wait_clk(500); // 等待
        check32("Cd 0 start no beep", beep_count, 0); // 不应响

        // 运行中 key7 不应进入设置
        set_countdown(24'h000003, 24'h000003); // 重新预置 3 秒
        press_key(1); // 启动
        wait_1hz(1); // 等 1 秒
        check1("Cd running before key7", dut.cd_running, 1'b1); // 运行中
        press_key(7); // 按键 7
        check1("Cd key7 no op while running", dut.setting, 1'b0); // 运行中不能进设置

        // 暂停保持
        press_key(1); // 暂停
        check1("Cd paused", dut.cd_paused, 1'b1); // 暂停标志
        cd_hold = dut.cd_remain_bcd; // 记录剩余值
        wait_1hz(1); // 等 1 秒
        check32("Cd paused hold", dut.cd_remain_bcd, cd_hold); // 暂停保持

        // 未运行可进入设置
        press_key(7); // 进设置
        check1("Cd enter setting", dut.setting, 1'b1); // 设置成功
        press_key(2); // 时十位 +1 -> 10:00:03
        press_key(2); // 时十位再 +1 -> 20:00:03
        check32("Cd edit 20:00:03", dut.u_countdown.edit_reg, 24'h200003); // 编辑值 20:00:03
        press_key(7); // 提交
        check1("Cd commit exits setting", dut.setting, 1'b0); // 退出设置
        check32("Cd preset committed", dut.cd_preset_bcd, 24'h200003); // 预置值已提交
        check32("Cd remain committed", dut.cd_remain_bcd, 24'h200003); // 剩余值同步

        $display("============================================================");
        $display(" TEST 8 : K2 auto repeat and K1 reset"); // TEST 8：K2 连发与 K1 复位
        $display("============================================================");
        reset_dut(); // 复位
        press_key(7); // CL setting
        core2_count = 0; // 清计数
        key_core_n[1] = 1'b0; // 按下 K2
        wait_clk(2600); // 保持跨过连发间隔
        key_core_n[1] = 1'b1; // 松开
        wait_clk(180); // 等消抖
        check1("K2 auto repeat >= 2", (core2_count >= 2), 1'b1); // 至少 2 次

        set_time_at_tick(24'h123456); // 预置非零时间
        press_core(1, 120); // K1 按 120 周期
        check32("K1 reset time 0", dut.time_bcd, 24'h000000); // 复位后归 0
        check1 ("K1 reset mode CL", (dut.mode == 2'b00), 1'b1); // 模式回到 CL

        $display("============================================================");
        $display(" TEST 9 : display scan, labels, one-hot"); // TEST 9：显示扫描与标识
        $display("============================================================");
        reset_dut(); // 复位
        repeat (8) begin // 连续观察 8 个扫描位
            @(posedge dut.tick_1khz); // 等 1 ms
            #1; // 等 1 ns
            check_dig_onehot(); // 检查 one-hot
        end

        check32("CL label C", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000B); // CL 标识 C
        check32("CL label L", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000D); // CL 标识 L

        press_key(8); // 切 AL
        check32("AL label A", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000A); // AL 标识 A
        check32("AL label L", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000D); // AL 标识 L

        press_key(8); // 切 St
        check32("St label S", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000E); // St 标识 S
        check32("St label t", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000F); // St 标识 t

        press_key(8); // 切 Cd
        check32("Cd label C", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000B); // Cd 标识 C
        check32("Cd label d", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000C); // Cd 标识 d

        $display("============================================================");
        $display(" TEST 10 : setting carry / borrow"); // TEST 10：设置时的段内进位与借位
        $display("============================================================");
        reset_dut(); // 复位
        press_key(7); // 进 CL 设置，光标在时十位（cursor=0）
        press_key(3); press_key(3); press_key(3); // 键 3 三次：光标移到分个位（cursor=3）

        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h005959; // 白盒预置 00:59:59
        press_key(2); // 分个位 +1
        check32("min 59 +1 -> 00, hour unchanged", dut.u_time_counter.edit_reg, 24'h000059); // 满 60 归零、不进时

        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h000959; // 00:09:59
        press_key(2); // 分个位 9 +1
        check32("min 09 +1 -> 10", dut.u_time_counter.edit_reg, 24'h001059); // 满 10 向分十位进 1

        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h000059; // 00:00:59
        press_key(1); // 分个位 -1
        check32("min 00 -1 -> 59", dut.u_time_counter.edit_reg, 24'h005959); // 减法借位

        press_key(4); press_key(4); // 键 4 两次：光标移回时个位（cursor=1）
        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h235959; // 23:59:59
        press_key(2); // 时个位 +1
        check32("hour 23 +1 -> 00", dut.u_time_counter.edit_reg, 24'h005959); // 满 24 归零

        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h095959; // 09:59:59
        press_key(2); // 时个位 9 +1
        check32("hour 09 +1 -> 10", dut.u_time_counter.edit_reg, 24'h105959); // 满 10 向时十位进 1

        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h005959; // 00:59:59
        press_key(1); // 时个位 -1
        check32("hour 00 -1 -> 23", dut.u_time_counter.edit_reg, 24'h235959); // 减法借位

        press_key(3); // 键 3：光标移到分十位（cursor=2）
        @(negedge clk50); dut.u_time_counter.edit_reg = 24'h005959; // 00:59:59
        press_key(2); // 分十位 5 +1
        check32("min tens 5 +1 -> 0, ones kept", dut.u_time_counter.edit_reg, 24'h000959); // 十位只在本段循环

        $display("============================================================");
        if (errors == 0) // 无错误则全部通过
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== TEST FAILED : %0d ERRORS ====", errors); // 否则打印错误数
        $display("============================================================");
        $finish; // 结束仿真
    end

endmodule // 模块结束

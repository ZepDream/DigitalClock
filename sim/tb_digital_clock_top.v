//============================================================================
// 文件名  : tb_digital_clock_top.v
// 功能    : 电子时钟顶层自检 testbench
// 说明    : SIM_FAST=1，把 1 秒缩短到 1000 个 50 MHz 周期，便于快速仿真。
//           通过层次化赋值直接预置时间/闹钟/倒计时，缩短测试时间。
//============================================================================
`timescale 1ns/1ps

module tb_digital_clock_top;

    reg         clk50;
    reg  [15:0] pi_in;
    reg  [15:0] pio_in;
    reg  [3:0]  key_core_n;

    wire [7:0]  seg_n;
    wire [7:0]  dig_n;
    wire        buzzer;
    wire [3:0]  led_n;

    integer errors;
    integer beep_count;
    integer core2_count;
    reg [23:0] sw_hold;
    reg [23:0] cd_hold;

    //------------------------------------------------------------------------
    // DUT
    //------------------------------------------------------------------------
    digital_clock_top #(
        .CLK_FREQ(50_000_000),
        .SIM_FAST(1)
    ) dut (
        .clk50(clk50),
        .pi_in(pi_in),
        .pio_in(pio_in),
        .key_core_n(key_core_n),
        .seg_n(seg_n),
        .dig_n(dig_n),
        .buzzer(buzzer),
        .led_n(led_n)
    );

    // 50 MHz，周期 20 ns
    always #10 clk50 = ~clk50;

    // 统计蜂鸣器“响”的次数
    always @(posedge dut.beep_en)
        beep_count = beep_count + 1;

    // 统计 K2 连发次数
    always @(posedge dut.u_key_input.core_press[1])
        core2_count = core2_count + 1;

    //------------------------------------------------------------------------
    // 基本任务
    //------------------------------------------------------------------------
    task wait_clk(input integer n);
        begin
            repeat (n) @(posedge clk50);
        end
    endtask

    task wait_1hz(input integer n);
        begin
            repeat (n) @(posedge dut.tick_1hz);
            @(posedge clk50); // tick 是使能，模块在下一个时钟沿才更新
            #1;
        end
    endtask

    task wait_100hz(input integer n);
        begin
            repeat (n) @(posedge dut.tick_100hz);
            @(posedge clk50);
            #1;
        end
    endtask

    task check32(input [255:0] name, input [31:0] actual, input [31:0] expected);
        begin
            if (actual !== expected) begin
                $display("ERROR [%0s] at %0t: got %h, expected %h", name, $time, actual, expected);
                errors = errors + 1;
            end
            else begin
                $display("PASS  [%0s] = %h", name, actual);
            end
        end
    endtask

    task check1(input [255:0] name, input actual, input expected);
        begin
            if (actual !== expected) begin
                $display("ERROR [%0s] at %0t: got %b, expected %b", name, $time, actual, expected);
                errors = errors + 1;
            end
            else begin
                $display("PASS  [%0s] = %b", name, actual);
            end
        end
    endtask

    // 按一次模式 9 的键：对应 nibble 加 1，保持足够长时间让 20 ms 消抖通过
    task press_key(input integer k);
        begin
            case (k)
                1: pi_in[3:0]   = pi_in[3:0]   + 1'b1;
                2: pi_in[7:4]   = pi_in[7:4]   + 1'b1;
                3: pi_in[11:8]  = pi_in[11:8]  + 1'b1;
                4: pi_in[15:12] = pi_in[15:12] + 1'b1;
                5: pio_in[3:0]  = pio_in[3:0]  + 1'b1;
                6: pio_in[7:4]  = pio_in[7:4]  + 1'b1;
                7: pio_in[11:8] = pio_in[11:8] + 1'b1;
                8: pio_in[15:12]= pio_in[15:12]+ 1'b1;
                default: ;
            endcase
            wait_clk(180); // 180 个周期 = 45 个 1 ms tick，足够 20 ms 消抖
        end
    endtask

    task press_core(input integer k, input integer hold_cycles);
        begin
            key_core_n[k-1] = 1'b0;
            wait_clk(hold_cycles);
            key_core_n[k-1] = 1'b1;
            wait_clk(180);
        end
    endtask

    task reset_dut;
        begin
            key_core_n[0] = 1'b0;
            wait_clk(120);
            key_core_n[0] = 1'b1;
            wait_clk(260);
        end
    endtask

    // 在 1 Hz 边沿之后预置时间，下一次 tick 就会从该值开始加
    task set_time_at_tick(input [23:0] v);
        begin
            @(posedge dut.tick_1hz);
            @(negedge clk50);
            dut.u_time_counter.time_reg = v;
        end
    endtask

    task set_alarm(input [23:0] v);
        begin
            @(negedge clk50);
            dut.u_alarm_ctrl.alarm_reg = v;
        end
    endtask

    task set_alarm_en(input v);
        begin
            @(negedge clk50);
            dut.u_alarm_ctrl.en_reg = v;
        end
    endtask

    task set_countdown(input [23:0] preset, input [23:0] remain);
        begin
            @(negedge clk50);
            dut.u_countdown.preset_reg = preset;
            dut.u_countdown.remain_reg = remain;
            dut.u_countdown.run_reg    = 1'b0;
            dut.u_countdown.paused_reg = 1'b0;
            dut.u_countdown.expired_reg= 1'b0;
        end
    endtask

    task set_stopwatch_max;
        begin
            @(negedge clk50);
            dut.u_stopwatch.min_reg = 8'h99;
            dut.u_stopwatch.sec_reg = 8'h59;
            dut.u_stopwatch.cs_reg  = 8'h99;
            dut.u_stopwatch.run_reg = 1'b1;
        end
    endtask

    task check_dig_onehot;
        integer i;
        integer low_cnt;
        begin
            low_cnt = 0;
            for (i = 0; i < 8; i = i + 1)
                if (dig_n[i] == 1'b0)
                    low_cnt = low_cnt + 1;

            if (low_cnt != 1) begin
                $display("ERROR [dig_onehot] at %0t: dig_n=%b, low count=%0d", $time, dig_n, low_cnt);
                errors = errors + 1;
            end
        end
    endtask

    //------------------------------------------------------------------------
    // 主流程
    //------------------------------------------------------------------------
    initial begin
        clk50     = 1'b0;
        pi_in     = 16'h0000;
        pio_in    = 16'h0000;
        key_core_n= 4'b1111;
        errors    = 0;
        beep_count= 0;
        core2_count = 0;

        $dumpfile("tb.vcd");
        $dumpvars(0, tb_digital_clock_top);

        $display("============================================================");
        $display(" TEST 1 : reset defaults");
        $display("============================================================");
        wait_clk(320);
        check32("mode=CL",        {30'd0, dut.mode}, 32'd0);
        check1 ("setting=0",      dut.setting, 1'b0);
        check32("time=00:00:00",  dut.time_bcd, 24'h000000);
        check1 ("alarm_en=0",     dut.alarm_en, 1'b0);
        check32("alarm=00:00:00", dut.alarm_bcd, 24'h000000);
        check32("sw=00:00.00",    {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h000000);
        check32("cd=00:05:00",    dut.cd_remain_bcd, 24'h000500);
        check1 ("led all off",    led_n, 4'b1111);

        $display("============================================================");
        $display(" TEST 2 : 1 Hz tick and rollover");
        $display("============================================================");
        set_time_at_tick(24'h000059);
        wait_clk(1);
        #1;
        check32("00:00:59 -> 00:01:00", dut.time_bcd, 24'h000100);

        set_time_at_tick(24'h235959);
        wait_clk(1);
        #1;
        check32("23:59:59 -> 00:00:00", dut.time_bcd, 24'h000000);

        $display("============================================================");
        $display(" TEST 3 : mode 9 key and mode switch");
        $display("============================================================");
        reset_dut();
        press_key(8);
        check32("key8 -> AL", {30'd0, dut.mode}, 32'd1);
        press_key(8);
        check32("key8 -> St", {30'd0, dut.mode}, 32'd2);
        press_key(8);
        check32("key8 -> Cd", {30'd0, dut.mode}, 32'd3);
        press_key(8);
        check32("key8 -> CL", {30'd0, dut.mode}, 32'd0);

        $display("============================================================");
        $display(" TEST 4 : CL setting, freeze, commit, cancel");
        $display("============================================================");
        reset_dut();
        press_key(7);
        check1 ("CL enter setting", dut.setting, 1'b1);
        check32("cursor=0", {29'd0, dut.cursor}, 32'd0);
        check32("edit=00:00:00", dut.u_time_counter.edit_reg, 24'h000000);

        wait_1hz(1);
        check32("edit frozen after 1 s", dut.u_time_counter.edit_reg, 24'h000000);
        check32("live time advanced", dut.time_bcd, 24'h000001);

        press_key(2);
        press_key(2);
        check32("hour tens +2 -> 20:00:00", dut.u_time_counter.edit_reg, 24'h200000);

        press_key(3);
        check32("cursor right -> 1", {29'd0, dut.cursor}, 32'd1);
        press_key(2);
        check32("hour ones +1 -> 21:00:00", dut.u_time_counter.edit_reg, 24'h210000);

        press_key(7);
        check1 ("CL commit exits setting", dut.setting, 1'b0);
        check32("time committed 21:00:00", dut.time_bcd, 24'h210000);

        press_key(7);
        press_key(3); // 光标移到时的个位
        press_key(2);
        check32("edit 22:00:00 before cancel", dut.u_time_counter.edit_reg, 24'h220000);
        press_key(8);
        check1 ("key8 cancels setting", dut.setting, 1'b0);
        check32("key8 -> AL", {30'd0, dut.mode}, 32'd1);
        check32("time not changed by cancel", {dut.time_bcd[23:8], 8'h00}, 24'h210000);

        $display("============================================================");
        $display(" TEST 5 : AL alarm switch and 3x2 beep");
        $display("============================================================");
        reset_dut();
        press_key(8); // AL
        set_alarm(24'h000003); // 先设一个非零闹钟，避免在 00:00:00 误触发
        press_key(1);
        check1("alarm on", dut.alarm_en, 1'b1);
        wait_clk(5);
        check1("LED2 on", led_n[1], 1'b0);
        press_key(1);
        check1("alarm off", dut.alarm_en, 1'b0);
        press_key(1);
        check1("alarm on again", dut.alarm_en, 1'b1);

        set_alarm(24'h000003);
        set_alarm_en(1'b1);
        set_time_at_tick(24'h000002);
        beep_count = 0;
        wait_clk(5);          // 时间 2 -> 3，alarm_trigger/beep_en 随其后
        #1;
        check1("alarm trigger pulse seen", (beep_count > 0), 1'b1);
        wait_clk(12000);      // 2.4 s 的 3 下 x 2 组（SIM_FAST）
        check32("alarm beep count = 6", beep_count, 6);
        wait_clk(2000);       // 不应再次触发
        check32("alarm still 6 (one shot)", beep_count, 6);

        $display("============================================================");
        $display(" TEST 6 : stopwatch start/pause/clear/max/background");
        $display("============================================================");
        reset_dut();
        press_key(8);
        press_key(8); // St
        press_key(1); // start
        check1("stopwatch running", dut.sw_running, 1'b1);
        wait_100hz(5);
        check1("stopwatch cs advanced", (dut.sw_cs_bcd != 8'h00), 1'b1);
        press_key(1); // pause
        check1("stopwatch paused", dut.sw_running, 1'b0);
        sw_hold = {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd};
        wait_clk(300);
        check32("stopwatch hold", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, sw_hold);
        press_key(2); // clear
        check32("stopwatch clear", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h000000);

        // 后台运行：启动后切到 Cd，数值应继续增加
        press_key(1);
        press_key(8); // St -> Cd
        wait_100hz(10);
        check1("stopwatch runs in background", dut.sw_running, 1'b1);

        // 最大值自动停止
        set_stopwatch_max();
        wait_100hz(1);
        check1("stopwatch stops at max", dut.sw_running, 1'b0);
        check32("stopwatch max value", {dut.sw_min_bcd, dut.sw_sec_bcd, dut.sw_cs_bcd}, 24'h995999);

        $display("============================================================");
        $display(" TEST 7 : countdown set/start/expire/reset/clear/0/pause");
        $display("============================================================");
        reset_dut();
        press_key(8);
        press_key(8);
        press_key(8); // Cd
        check32("Cd default 00:05:00", dut.cd_remain_bcd, 24'h000500);
        check1("Cd idle solid", dut.u_display_ctrl.label_blink, 1'b0);

        set_countdown(24'h000003, 24'h000003);
        beep_count = 0;
        press_key(5);
        check1("Cd running", dut.cd_running, 1'b1);
        wait_1hz(3);
        check1("Cd expired", dut.cd_expired, 1'b1);
        check32("Cd remain 0", dut.cd_remain_bcd, 24'h000000);
        wait_clk(4000);
        check32("Cd beep count = 2", beep_count, 2);

        press_key(6);
        check1("Cd reset clears expired", dut.cd_expired, 1'b0);
        check32("Cd reset to preset", dut.cd_remain_bcd, 24'h000003);

        press_key(2);
        check32("Cd clear to 0", dut.cd_remain_bcd, 24'h000000);
        beep_count = 0;
        press_key(5);
        check1("Cd 0 start invalid", dut.cd_running, 1'b0);
        wait_clk(500);
        check32("Cd 0 start no beep", beep_count, 0);

        // 运行中 key7 不应进入设置
        set_countdown(24'h000003, 24'h000003);
        press_key(5);
        wait_1hz(1);
        check1("Cd running before key7", dut.cd_running, 1'b1);
        press_key(7);
        check1("Cd key7 no op while running", dut.setting, 1'b0);

        // 暂停保持
        press_key(5);
        check1("Cd paused", dut.cd_paused, 1'b1);
        cd_hold = dut.cd_remain_bcd;
        wait_1hz(1);
        check32("Cd paused hold", dut.cd_remain_bcd, cd_hold);

        // 未运行可进入设置
        press_key(7);
        check1("Cd enter setting", dut.setting, 1'b1);
        press_key(2); // 时十位 +1 -> 10:00:03
        press_key(2); // 时十位再 +1 -> 20:00:03
        check32("Cd edit 20:00:03", dut.u_countdown.edit_reg, 24'h200003);
        press_key(7);
        check1("Cd commit exits setting", dut.setting, 1'b0);
        check32("Cd preset committed", dut.cd_preset_bcd, 24'h200003);
        check32("Cd remain committed", dut.cd_remain_bcd, 24'h200003);

        $display("============================================================");
        $display(" TEST 8 : K2 auto repeat and K1 reset");
        $display("============================================================");
        reset_dut();
        press_key(7); // CL setting
        core2_count = 0;
        key_core_n[1] = 1'b0;
        wait_clk(2600);
        key_core_n[1] = 1'b1;
        wait_clk(180);
        check1("K2 auto repeat >= 2", (core2_count >= 2), 1'b1);

        set_time_at_tick(24'h123456);
        press_core(1, 120);
        check32("K1 reset time 0", dut.time_bcd, 24'h000000);
        check1 ("K1 reset mode CL", (dut.mode == 2'b00), 1'b1);

        $display("============================================================");
        $display(" TEST 9 : display scan, labels, one-hot");
        $display("============================================================");
        reset_dut();
        repeat (8) begin
            @(posedge dut.tick_1khz);
            #1;
            check_dig_onehot();
        end

        check32("CL label C", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000B);
        check32("CL label L", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000D);

        press_key(8);
        check32("AL label A", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000A);
        check32("AL label L", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000D);

        press_key(8);
        check32("St label S", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000E);
        check32("St label t", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000F);

        press_key(8);
        check32("Cd label C", {28'd0, dut.u_display_ctrl.disp[31:28]}, 32'h0000000B);
        check32("Cd label d", {28'd0, dut.u_display_ctrl.disp[27:24]}, 32'h0000000C);

        $display("============================================================");
        if (errors == 0)
            $display("==== ALL TESTS PASSED ====");
        else
            $display("==== TEST FAILED : %0d ERRORS ====", errors);
        $display("============================================================");
        $finish;
    end

endmodule

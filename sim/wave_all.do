# 在 ModelSim 中执行：do wave_all.do
# 作用：把常用信号分组加入波形窗口

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider "Clock / Reset"
add wave -radix binary  /tb_digital_clock_top/clk50
add wave -radix binary  /tb_digital_clock_top/dut/sys_rst_n
add wave -radix binary  /tb_digital_clock_top/dut/tick_1hz
add wave -radix binary  /tb_digital_clock_top/dut/tick_100hz
add wave -radix binary  /tb_digital_clock_top/dut/tick_1khz
add wave -radix binary  /tb_digital_clock_top/dut/tick_2hz

add wave -divider "Mode 9 keys"
add wave -radix hex     /tb_digital_clock_top/pi_in
add wave -radix hex     /tb_digital_clock_top/pio_in
add wave -radix binary  /tb_digital_clock_top/dut/key_press
add wave -radix binary  /tb_digital_clock_top/key_core_n
add wave -radix binary  /tb_digital_clock_top/dut/core_press

add wave -divider "Mode / Setting"
add wave -radix unsigned /tb_digital_clock_top/dut/mode
add wave -radix binary   /tb_digital_clock_top/dut/setting
add wave -radix unsigned /tb_digital_clock_top/dut/cursor

add wave -divider "Time / Alarm"
add wave -radix hex /tb_digital_clock_top/dut/time_bcd
add wave -radix hex /tb_digital_clock_top/dut/time_edit_bcd
add wave -radix hex /tb_digital_clock_top/dut/alarm_bcd
add wave -radix hex /tb_digital_clock_top/dut/alarm_edit_bcd
add wave -radix binary /tb_digital_clock_top/dut/alarm_en
add wave -radix binary /tb_digital_clock_top/dut/alarm_trigger

add wave -divider "Stopwatch / Countdown"
add wave -radix hex /tb_digital_clock_top/dut/sw_min_bcd
add wave -radix hex /tb_digital_clock_top/dut/sw_sec_bcd
add wave -radix hex /tb_digital_clock_top/dut/sw_cs_bcd
add wave -radix binary /tb_digital_clock_top/dut/sw_running
add wave -radix hex /tb_digital_clock_top/dut/cd_preset_bcd
add wave -radix hex /tb_digital_clock_top/dut/cd_remain_bcd
add wave -radix binary /tb_digital_clock_top/dut/cd_running
add wave -radix binary /tb_digital_clock_top/dut/cd_paused
add wave -radix binary /tb_digital_clock_top/dut/cd_expired
add wave -radix binary /tb_digital_clock_top/dut/cd_expire_pulse

add wave -divider "Display / Buzzer"
add wave -radix hex /tb_digital_clock_top/seg_n
add wave -radix hex /tb_digital_clock_top/dig_n
add wave -radix binary /tb_digital_clock_top/dut/beep_en
add wave -radix binary /tb_digital_clock_top/buzzer
add wave -radix binary /tb_digital_clock_top/led_n
add wave -radix unsigned /tb_digital_clock_top/beep_count

configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -timelineunits ns

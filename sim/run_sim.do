# 在 ModelSim 的 Transcript 中执行：do run_sim.do
# 作用：编译 -> 加载 testbench -> 加波形 -> 运行到 $finish

do compile.do
vsim work.tb_digital_clock_top
do wave_all.do
run -all

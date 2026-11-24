# 在 ModelSim 的 Transcript 中执行：do compile.do
# 作用：重新建立 work 库并编译全部 RTL 和 testbench

if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

foreach f [glob ../rtl/*.v] {
    vlog $f
}
vlog ./tb_digital_clock_top.v

# 50 MHz system clock
create_clock -name clk50 -period 20.000 [get_ports {clk50}]
derive_clock_uncertainty

# PI/PIO and core keys are asynchronous inputs from the experiment box.
set_false_path -from [get_ports {pi_in[*]}]  -to [all_registers]
set_false_path -from [get_ports {pio_in[*]}] -to [all_registers]
set_false_path -from [get_ports {key_core_n[*]}] -to [all_registers]

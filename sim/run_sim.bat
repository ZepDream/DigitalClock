@echo off
setlocal
set MS_PATH=C:\ZZJ\APP\intelFPGA\17.1\modelsim_ase\win32aloem
set PATH=%MS_PATH%;C:\Windows\SysWOW64;C:\Windows\System32;C:\Windows
set MODELSIM=C:\ZZJ\APP\intelFPGA\17.1\modelsim_ase\modelsim.ini

cd /d %~dp0

if exist work rmdir /s /q work
vlib work
vmap work work

for %%f in (..\rtl\*.v) do vlog "%%f"
vlog tb_digital_clock_top.v

vsim -c -do "run -all; quit -f" work.tb_digital_clock_top

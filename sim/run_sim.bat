@echo off
setlocal
cd /d "%~dp0"

rem ============================================================
rem Locate ModelSim-ASE (vsim.exe), without hard-coding one PC's path.
rem
rem Search order:
rem   1. MODELSIM_BIN, if you set it;
rem   2. vsim.exe already on PATH;
rem   3. %QUARTUS_ROOTDIR%\..\modelsim_ase\win32aloem;
rem   4. common Intel FPGA / Altera install roots.
rem
rem If auto-detection fails, set the folder once in this window:
rem   set MODELSIM_BIN=G:\APP\Quartus\17.1\modelsim_ase\win32aloem
rem ============================================================
if defined MODELSIM_BIN set "PATH=%MODELSIM_BIN%;%PATH%"

where vsim.exe >nul 2>nul
if not errorlevel 1 goto modelsim_ready

if defined QUARTUS_ROOTDIR if exist "%QUARTUS_ROOTDIR%\..\modelsim_ase\win32aloem\vsim.exe" set "PATH=%QUARTUS_ROOTDIR%\..\modelsim_ase\win32aloem;%PATH%"

if exist "C:\intelFPGA\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=C:\intelFPGA\17.1\modelsim_ase\win32aloem;%PATH%"
if exist "C:\altera\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=C:\altera\17.1\modelsim_ase\win32aloem;%PATH%"
if exist "C:\intelFPGA_lite\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=C:\intelFPGA_lite\17.1\modelsim_ase\win32aloem;%PATH%"
if exist "D:\intelFPGA\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=D:\intelFPGA\17.1\modelsim_ase\win32aloem;%PATH%"
if exist "D:\altera\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=D:\altera\17.1\modelsim_ase\win32aloem;%PATH%"
if exist "%ProgramFiles%\intelFPGA\17.1\modelsim_ase\win32aloem\vsim.exe" set "PATH=%ProgramFiles%\intelFPGA\17.1\modelsim_ase\win32aloem;%PATH%"

where vsim.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] vsim.exe not found.
    echo.
    echo Set MODELSIM_BIN to the win32aloem folder of your ModelSim-ASE, e.g.:
    echo     set MODELSIM_BIN=C:\intelFPGA\17.1\modelsim_ase\win32aloem
    echo Then run sim\run_sim.bat again.
    exit /b 1
)

:modelsim_ready
if exist work rmdir /s /q work
vlib work
if errorlevel 1 exit /b 1
vmap work work

for %%f in (..\rtl\*.v) do vlog "%%f"
if errorlevel 1 exit /b 1
vlog tb_digital_clock_top.v
if errorlevel 1 exit /b 1

vsim -c -do "run -all; quit -f" work.tb_digital_clock_top
exit /b %errorlevel%

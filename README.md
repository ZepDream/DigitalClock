# 基于 KX-MS65 实验箱的电子时钟

## 1. 功能

- 24 小时时钟 `HH:MM:SS`，可调时、分、秒
- 闹钟 `HH:MM:SS`，可开关，LED2 指示；到点响 3 下 × 2 组
- 秒表 `MM:SS:CC`，10 ms 分辨率，启动/暂停/清零，最大 99:59.99
- 倒计时 `HH:MM:SS`，启动/暂停/复位/清零；到 0 响 2 下 × 1 组
- 8 位动态数码管：模式标识 + 6 位数值
- 模式 9 键 1～8 + 核心板 K1～K4
- 上电复位 + K1 手动复位
- 不做断电保存

## 2. 目录

```text
DigitalClock/
  DigitalClock.qpf           Quartus 工程
  DigitalClock.qsf           器件、文件、引脚、I/O 标准
  DigitalClock.sdc           50 MHz 时钟约束
  rtl/                       RTL 源码（15 个模块）
  sim/                       testbench、ModelSim 脚本、VCD 波形渲染脚本
  constraints/               引脚 CSV
  images/                    仿真波形 PNG
  docs/                      总体基线、配置、五份说明书大纲、对照表
  output_files/              Quartus 编译输出（.sof、报告）
```

### 模块

| 模块 | 作用 |
|---|---|
| `digital_clock_top` | 顶层：连接、复位、引脚 |
| `clk_gen` | 50 MHz → 1 Hz / 100 Hz / 1 kHz / 2 Hz tick |
| `nibble_key` | 单路模式 9 按键：同步 + 20 ms 消抖 + 变化检测 |
| `core_key` | 核心键消抖、按下脉冲、K2/K3 连发 |
| `key_input` | 8 路 nibble + 4 路核心键 |
| `key_ctrl` | 模式/设置状态机、光标、按键动作译码 |
| `bcd_digit_adj` | 24 位 BCD 按位加/减 |
| `time_counter` | 正式时钟 + 编辑缓冲 |
| `alarm_ctrl` | 闹钟设置、开关、比较、单次触发 |
| `stopwatch` | 秒表 10 ms BCD 计数 |
| `countdown` | 倒计时设定/剩余/启动/暂停/复位/清零 |
| `beep_ctrl` | 3 下×2 组、2 下×1 组、优先级、静音 |
| `buzzer_tone` | 2.7 kHz 低有效方波 |
| `display_ctrl` | 8 位扫描、模式选择、闪烁、LED |
| `seg_decode` | 七段译码 |

### 说明书

- [系统架构说明书](docs/03_architecture_manual.md)
- [分频器说明书](docs/02_divider_manual.md)
- [按键操作说明书](docs/01_key_manual.md)
- [仿真操作流程说明书](docs/04_simulation_manual.md)
- [最终方案](docs/05_final_plan.md)
- [总体设计基线](docs/00_design_baseline.md)
- [需求对照表](docs/00_traceability_matrix.md)

## 3. Quartus 编译

1. 打开 Quartus Prime Standard 17.1。
2. `File -> Open Project`，选择 `DigitalClock.qpf`。
3. 确认 Device 为 `10CL006YU256C8G`；若核心板是 010，改为 `10CL010YU256C8G`，引脚不变。
4. `Processing -> Start Compilation`。
5. 生成文件：`output_files/DigitalClock.sof`。
6. 用 USB-Blaster 下载 `.sof` 到 FPGA。

当前编译结果：

- 0 errors，1 warning（AN447 3.3 V 接口提示，实验箱为 3.3 V 电平，属正常提示）
- 1,584 / 6,272 LE（25%）
- 680 registers
- 58 / 177 user I/O（33%）
- 0 PLL / 0 RAM / 0 DSP
- 50 MHz setup slack 9.256 ns，hold slack 0.452 ns

## 4. ModelSim 仿真

### 方式一：Windows 批处理

```bat
sim\run_sim.bat
```

### 方式二：ModelSim GUI

在 `sim` 目录打开 ModelSim，Transcript 中执行：

```tcl
do run_sim.do
```

或分步：

```tcl
do compile.do
vsim work.tb_digital_clock_top
do wave_all.do
run -all
```

当前结果：

```text
==== ALL TESTS PASSED ====
74 PASS, 0 ERROR
```

## 5. 波形图片

`images/` 下已生成：

| 文件 | 内容 |
|---|---|
| `wave_time.png` | 1 Hz tick、00:00:59→00:01:00 |
| `wave_rollover.png` | 23:59:59→00:00:00 |
| `wave_key.png` | 模式 9 nibble 变化、20 ms 消抖、编辑值变化 |
| `wave_cl_set.png` | CL 设置、光标、确认/取消 |
| `wave_alarm.png` | 闹钟 3 下×2 组 |
| `wave_countdown.png` | 倒计时到 0、2 下×1 组 |
| `wave_display.png` | 8 位数码管动态扫描 |
| `wave_buzzer.png` | 蜂鸣器 2.7 kHz 方波 |

## 6. 引脚

完整引脚表：

- `constraints/pin_assignments.csv`
- `DigitalClock.qsf`
- `docs/00_board_config.md`

关键引脚：

| 信号 | 引脚 |
|---|---|
| 50 MHz | `M15` |
| K1/K2/K3/K4 | `P9/N9/M10/P11` |
| 蜂鸣器 | `T13` |
| 段选 `g..dp` | `C2,D1,B3,A3,B5,A5,B7,B6` |
| 位选 数码8..1 | `L4,R1,N1,P2,K1,L2,G1,J2` |
| 模式 9 按键 | `PI[15:0]`、`PIO[15:0]` |

## 7. 上板步骤

1. 实验箱上电，模式选择到 **No.9**。
2. 下载 `DigitalClock.sof`。
3. 按 K1 复位。
4. 默认显示 `CL 00:00:00`，LED1 1 Hz 心跳。
5. 键 8 切换 `CL -> AL -> St -> Cd -> CL`。
6. 键 7 / K4 进入或确认设置；键 4/3 移光标；键 2/1 或 K2/K3 加减。
7. 键 8 在设置中取消并跳下一个模式。

## 8. 说明

- 模式 9 的 8 个按键是 4 位计数器，FPGA 只能检测变化，不能清零。
- 倒计时剩余为 0 时启动无效，不会响；只有 1→0 才触发提示音。
- LED1 为 1 Hz 心跳；LED2 闹钟开关；LED3 秒表后台；LED4 倒计时后台/到期闪烁。
- 上板照片需要实验箱实物补拍，文档中已留位置。
- 未经上板实测的项：蜂鸣器实际频率、按键抖动特性、3.3 V 接口波形。

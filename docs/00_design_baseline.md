# 电子时钟总体设计基线

> 版本：v1.1（已实现）  
> 作用：后续《按键操作说明书》《分频器说明书》《系统架构说明书》《仿真操作流程说明书》《最终方案》和 RTL 代码的唯一依据。  
> 原则：先定接口和行为，再写代码和正文；同一张表只维护一次。

---

## 1. 需求与验收标准

| 编号 | 需求 | 验收标准 |
|---|---|---|
| R1 | 时钟 | 24 小时制 `HH:MM:SS`，可调时、分、秒，正常走秒 |
| R2 | 闹钟 | `HH:MM:SS` 可设，可开关，LED2 指示；到点响 3 下×2 组 |
| R3 | 秒表 | `MM:SS:CC`，10 ms 分辨率，启动/暂停/清零，最大 99:59.99 |
| R4 | 倒计时 | `HH:MM:SS` 可设，启动/暂停/复位/清零；到 0 响 2 下×1 组；0 启动不响 |
| R5 | 显示 | 8 位动态扫描数码管，模式标识 + 6 位数值，设置时选中位 2 Hz 闪烁 |
| R6 | 按键 | 模式 9 键 1～8 + 核心板 K1～K4；消抖；不依赖核心板完成主要功能 |
| R7 | 模式切换 | CL/AL/St/Cd 循环；设置中按 8 取消并跳转；St/Cd 后台继续计时 |
| R8 | 复位 | 上电复位 + K1 手动复位；复位后回默认值 |
| R9 | 断电保存 | 不做；断电后所有数据丢失 |
| R10 | 工具链 | Quartus Prime Standard 17.1 + ModelSim-ASE 17.1，可编译、可仿真、可下载 |
| R11 | 文档 | 五份说明书面向初学者，代码中文注释，图表齐全，不臃肿 |

### 1.1 默认值

| 项目 | 默认值 |
|---|---|
| 时钟 | `00:00:00` |
| 闹钟 | `00:00:00`，关闭 |
| 秒表 | `00:00.00`，停止 |
| 倒计时设定值/剩余值 | `00:05:00` |
| 当前模式 | CL |
| 光标 | 时的十位 |

---

## 2. 系统总框图

```text
                    ┌─────────────────────────────┐
                    │        digital_clock_top     │
                    │                             │
 50 MHz ───────────►│ clk_gen                     │
 M15                │  ├─ tick_1hz                │
                    │  ├─ tick_100hz              │
                    │  ├─ tick_1khz               │
                    │  └─ tick_2hz                │
                    │                             │
 PI[15:0] ─────────►│ key_input                   │
 PIO[15:0] ────────►│  ├─ 8 路 nibble 变化检测     │
 K1~K4 ────────────►│  └─ 核心键消抖/连发          │
                    │        │ key_press[7:0]     │
                    │        ▼                    │
                    │ key_ctrl                    │
                    │  ├─ 模式 FSM                │
                    │  ├─ 设置 FSM/光标            │
                    │  └─ 按键动作译码             │
                    │        │                    │
                    │        ├──────────────┐     │
                    │        ▼              ▼     │
                    │ time_counter     alarm_ctrl │
                    │ stopwatch        countdown  │
                    │        │              │     │
                    │        └──────┬───────┘     │
                    │               ▼             │
                    │ display_ctrl ──► seg_n/dig_n│
                    │               │             │
                    │               └─► LED1~4    │
                    │                             │
                    │ beep_ctrl ──► buzzer_tone ──┼──► T13
                    └─────────────────────────────┘
```

### 2.1 设计原则

1. **单时钟域**：全部逻辑用 50 MHz，分频只产生单周期使能 `tick_*`，不产生门控时钟。
2. **同步复位**：所有时序逻辑用 `posedge clk`，低有效同步复位 `rst_n`。
3. **BCD 计数**：时、分、秒、秒表都用 BCD，显示和按位调整直观，避免二进制转 BCD 的额外逻辑。
4. **编辑缓冲**：设置时改“编辑值”，确认后才写回正式值；取消不生效。
5. **输出低有效**：段选、位选、LED、蜂鸣器都按实验箱实际电路低有效处理。

---

## 3. 工作模式与状态机

### 3.1 模式编码

| 模式 | 编码 | 显示标识 | 说明 |
|---|---|---|---|
| CL | `2'b00` | `CL` | 时钟 |
| AL | `2'b01` | `AL` | 闹钟 |
| St | `2'b10` | `St` | 秒表 |
| Cd | `2'b11` | `Cd` | 倒计时 |

### 3.2 主状态机

```text
        key8            key8            key8            key8
  CL ─────────► AL ─────────► St ─────────► Cd ─────────► CL
   ▲                                                  │
   └──────────────────────────────────────────────────┘
```

- 正常显示时，key8 切换到下一个模式。
- 设置状态下，key8 **取消设置**并切换到下一个模式。
- St 切走时秒表继续后台运行。
- Cd 切走时倒计时继续后台运行。
- CL/AL 切走时正式时钟始终在后台运行。

### 3.3 设置子状态

```text
  IDLE ──(key7/K4)──► SET ──(key7/K4)──► IDLE（确认）
   ▲                   │
   └──(key8，取消)─────┘
```

- `setting = 0`：正常显示。
- `setting = 1`：设置状态，`cursor` 选择当前位。
- `cursor`：CL/AL/Cd 均为 0～5，对应时的十位、时的个位、分的十位、分的个位、秒的十位、秒的个位。
- key4 左移，key3 右移，0～5 循环。
- key2 或 K2：选中位 +1；key1 或 K3：选中位 −1。

### 3.4 进入设置的条件

| 模式 | 条件 |
|---|---|
| CL | 任何时候 |
| AL | 任何时候 |
| St | 不允许 |
| Cd | `!cd_running && !cd_expired` |

### 3.5 设置时的数据规则

| 模式 | 编辑对象 | 设置时是否走秒 | 确认 | 取消 |
|---|---|---|---|---|
| CL | 时钟编辑值 | 否，冻结 | 写入正式时钟 | 丢弃，正式时钟不受影响 |
| AL | 闹钟编辑值 | 否 | 写入闹钟时间 | 丢弃 |
| Cd | 倒计时设定值 | 否 | 写入设定值和剩余值，停止倒计时 | 丢弃，保持原值 |

> 正式时钟在 CL 设置期间仍然后台走秒；显示的是冻结的编辑值。

---

## 4. 按键定义

### 4.1 模式 9 按键的硬件事实

模式 9 的 8 个键是 8 个 4 位十六进制计数器：

- 每按一次，对应 nibble 加 1；
- 16 次后回绕；
- `PI/PIO` 由底板 CPLD 驱动，FPGA 只能读，不能清零；
- FPGA 检测 nibble 变化，一次变化产生一个单周期按键脉冲；
- 上电/复位后先把当前 nibble 锁存为 `prev`，避免误判；
- 不依赖按住连发；连发由核心板 K2/K3 完成。

### 4.2 模式 9 键与 nibble

| 物理键 | nibble | FPGA 引脚（bit3～bit0） |
|---|---|---|
| 键 1 | `PI[3:0]` | `N8, M8, P6, L7` |
| 键 2 | `PI[7:4]` | `T4, R5, K8, R3` |
| 键 3 | `PI[11:8]` | `T8, R9, T6, R7` |
| 键 4 | `PI[15:12]` | `T12, R13, T10, R11` |
| 键 5 | `PIO[3:0]` | `N2, P1, L6, N5` |
| 键 6 | `PIO[7:4]` | `A4, B1, G2, K2` |
| 键 7 | `PIO[11:8]` | `L1, J6, L3, P3` |
| 键 8 | `PIO[15:12]` | `B4, C3, D3, J1` |

### 4.3 完整按键表

| 键 | CL | AL | St | Cd |
|---|---|---|---|---|
| 8 | 转 AL；设置中取消转 AL | 转 St；设置中取消转 St | 转 Cd | 转 CL；设置中取消转 CL |
| 7 | 进入/确认设置 | 进入/确认设置 | — | 未运行且未到期：进入/确认设置；运行/到期：— |
| 6 | — | — | — | 未运行：复位到设定值；运行：— |
| 5 | — | — | — | 启动/暂停 |
| 4 | 设置：光标左移 | 设置：光标左移 | — | 设置：光标左移 |
| 3 | 设置：光标右移 | 设置：光标右移 | — | 设置：光标右移 |
| 2 | 设置：+1 | 设置：+1 | 清零并暂停 | 未运行：清零到 0；设置：+1 |
| 1 | 设置：−1 | 正常：闹钟开关；设置：−1 | 启动/暂停 | 设置：−1 |

### 4.4 核心板按键

| 键 | FPGA 引脚 | 作用 |
|---|---|---|
| K1 | `P9` | 全局手动复位，低有效 |
| K2 | `N9` | 设置时 +1；按住 0.5 s 后 10 Hz 连加 |
| K3 | `M10` | 设置时 −1；按住 0.5 s 后 10 Hz 连减 |
| K4 | `P11` | 进入/确认设置，和 key7 等效 |

### 4.5 按键边沿情况

- CL/AL 设置中 key8：取消并跳下一个模式。
- Cd 运行中 key8：跳 CL，倒计时继续后台运行。
- St 中 key8：跳 Cd，秒表继续后台运行。
- Cd 到 0 后 key5 启动无效，key6 复位后可再次启动。
- Cd 清零到 0 后 key5 启动无效，不会响。
- 任意按键可以提前静音蜂鸣器。

---

## 5. 显示定义

### 5.1 八位数码管布局

```text
数码8 数码7 | 数码6 数码5 | 数码4 数码3 | 数码2 数码1
 模式  模式 |   数值1    |   数值2    |   数值3
```

- `d[7]` = 数码 8（最左），`d[0]` = 数码 1（最右）。
- 模式标识占 `d[7:6]`，数值占 `d[5:0]`。

### 5.2 各模式显示

| 模式 | `d[7:6]` | `d[5:0]` | 小数点 |
|---|---|---|---|
| CL | `CL` | `HHMMSS` | `d[4]`、`d[2]` |
| AL | `AL` | `HHMMSS` | `d[4]`、`d[2]` |
| St | `St` | `MMSSCC` | `d[4]`、`d[2]` |
| Cd | `Cd` | `HHMMSS` | `d[4]`、`d[2]` |

### 5.3 闪烁规则

| 状态 | 模式标识 | 选中位 |
|---|---|---|
| CL 正常 | 常亮 | — |
| CL 设置 | 2 Hz 闪烁 | 2 Hz 闪烁 |
| AL 正常 | 常亮 | — |
| AL 设置 | 2 Hz 闪烁 | 2 Hz 闪烁 |
| St | 常亮 | — |
| Cd 未启动、未到期、非设置 | 常亮 | — |
| Cd 运行/暂停/到期/设置 | 2 Hz 闪烁 | 设置时选中位闪烁 |

- 2 Hz 闪烁：每 250 ms 翻转一次。
- 模式标识闪烁时，两个字符同时亮/灭。
- 选中位闪烁时，只灭该位，其他位正常显示。

### 5.4 扫描

- 1 kHz 扫描，每位 1 ms，8 位一帧 8 ms（125 Hz）。
- 位选低有效，同一时刻只选通一位。
- 段选低有效，段码按 `{g,f,e,d,c,b,a,dp}`。
- 扫描计数 0～7，`dig_n = ~(1 << scan_idx)`。
- 段码和位选都寄存输出，避免组合毛刺。

### 5.5 字符集

至少支持：

```text
0 1 2 3 4 5 6 7 8 9
A C d L S t
空白
```

段码表在《分频器说明书》/《系统架构说明书》中给出，代码中集中在 `seg_decode.v`。

### 5.6 LED 指示

| LED | 功能 | 有效电平 |
|---|---|---|
| LED1 | 1 Hz 心跳（亮 0.5 s、灭 0.5 s） | 低有效 |
| LED2 | 闹钟开关：亮=开，灭=关 | 低有效 |
| LED3 | 秒表后台运行指示 | 低有效 |
| LED4 | 倒计时后台运行时常亮；到期 2 Hz 闪烁 | 低有效 |

---

## 6. 数据格式与计数规则

### 6.1 BCD 格式

时、分、秒各用两个 4 位 BCD 数字：

```text
time_bcd[23:0] = {hh_t[3:0], hh_o[3:0], mm_t[3:0], mm_o[3:0], ss_t[3:0], ss_o[3:0]}
```

- `hh_t`：时的十位，0～2；
- `hh_o`：时的个位，0～9，但 `hh_t == 2` 时 0～3；
- `mm_t/ss_t`：0～5；
- `mm_o/ss_o`：0～9。

### 6.2 时钟

- 每个 `tick_1hz` 加 1 秒。
- 秒 59→00，分加 1；分 59→00，时加 1；时 23→00，回 00。
- 设置时编辑值冻结，正式时钟继续走。
- 确认时 `time_bcd <= edit_bcd`；取消不变。

### 6.3 闹钟

- `alarm_bcd[23:0]` 精确到秒。
- 每个 `tick_1hz` 比较 `time_bcd == alarm_bcd`。
- 条件：`alarm_en && (time_bcd == alarm_bcd)`。
- 用 `match_d` 做相等上升沿检测，同一秒只产生一个 `alarm_trigger` 脉冲。
- 时间不再相等时 `match_d` 自动清零，下一天同一秒可以再次触发。
- 设置时编辑值冻结；确认写入；取消不变。
- AL 正常显示时 key1 切换 `alarm_en`，LED2 指示。

### 6.4 秒表

- `tick_100hz` 为 10 ms。
- BCD 三个字节：`min 00～99`、`sec 00～59`、`cs 00～99`。
- key1 启动/暂停；key2 清零并暂停。
- 到 `99:59.99` 自动停止。
- 切换到其他模式后继续后台运行，LED3 指示。

### 6.5 倒计时

- `cd_preset_bcd[23:0]`：设定值，最大 `23:59:59`。
- `cd_remain_bcd[23:0]`：剩余值。
- `tick_1hz` 减 1 秒；到 `00:00:00` 时停止、置 `expired`、发 `expire_pulse`。
- key5 启动/暂停；key6 未运行时复位到设定值；key2 未运行时清零到 0。
- 0 启动无效，只有从 1 减到 0 才触发提示音。
- 切换到其他模式后继续后台运行，LED4 指示。

### 6.6 按位加减规则

- 只改选中位，不向相邻位进位。
- 时十位：0～2；到 2 再加回 0，到 0 再减回 2。
- 时个位：时十位为 2 时 0～3，否则 0～9；到边界回绕。
- 分/秒十位：0～5；到边界回绕。
- 分/秒个位：0～9；到边界回绕。
- 例：`23` 的个位再 +1 回到 `20`，不向十位进位。

---

## 7. 模块划分与接口

| 模块 | 文件 | 主要输入 | 主要输出 | 功能 |
|---|---|---|---|---|
| `digital_clock_top` | `rtl/digital_clock_top.v` | 时钟、PI/PIO、K1～K4 | 段选、位选、蜂鸣器、LED | 顶层连接 |
| `clk_gen` | `rtl/clk_gen.v` | `clk50`, `rst_n` | `tick_1hz`, `tick_100hz`, `tick_1khz`, `tick_2hz` | 时基使能 |
| `nibble_key` | `rtl/nibble_key.v` | `clk`, `rst_n`, `tick_1khz`, `nibble_in` | `press` | 单路模式 9 按键检测 |
| `core_key` | `rtl/core_key.v` | `clk`, `rst_n`, `tick_1khz`, `key_n` | `press` | 核心键消抖/连发 |
| `key_input` | `rtl/key_input.v` | `clk`, `rst_n`, `pi_in`, `pio_in`, `key_core_n`, `tick_1khz` | `key_press[7:0]`, `core_press[3:0]` | 8 路 nibble + 4 路核心键 |
| `key_ctrl` | `rtl/key_ctrl.v` | `key_press`, `core_press`, 状态反馈 | 模式、设置、光标、各动作脉冲 | 按键逻辑 |
| `bcd_digit_adj` | `rtl/bcd_digit_adj.v` | `bcd_in`, `cursor`, `inc` | `bcd_out` | 24 位 BCD 按位加减 |
| `time_counter` | `rtl/time_counter.v` | `tick_1hz`, `mode`, `edit_*`, `digit_*`, `cursor` | `time_bcd`, `edit_bcd` | 时钟与编辑缓冲 |
| `alarm_ctrl` | `rtl/alarm_ctrl.v` | `mode`, `time_bcd`, 编辑动作 | `alarm_bcd`, `alarm_edit_bcd`, `alarm_en`, `alarm_trigger` | 闹钟 |
| `stopwatch` | `rtl/stopwatch.v` | `tick_100hz`, `start_pause`, `clear` | `min_bcd`, `sec_bcd`, `cs_bcd`, `running` | 秒表 |
| `countdown` | `rtl/countdown.v` | `tick_1hz`, `mode`, 编辑/启动/复位/清零 | `preset_bcd`, `remain_bcd`, `edit_bcd`, `running`, `paused`, `expired`, `expire_pulse` | 倒计时 |
| `beep_ctrl` | `rtl/beep_ctrl.v` | `tick_1khz`（1 ms）, `alarm_trigger`, `cd_expire`, `silence` | `beep_en` | 提示音节奏 |
| `buzzer_tone` | `rtl/buzzer_tone.v` | `clk`, `beep_en` | `buzzer` | 2.7 kHz 方波 |
| `display_ctrl` | `rtl/display_ctrl.v` | 各模式数据、闪烁 | `seg_n`, `dig_n`, `led_n` | 显示选择与扫描 |
| `seg_decode` | `rtl/seg_decode.v` | BCD、dp、blank | `seg_n[7:0]` | 七段译码 |

### 7.1 关键内部信号

| 信号 | 位宽 | 说明 |
|---|---|---|
| `key_press` | 8 | key1～key8 的单周期脉冲 |
| `core_press` | 4 | K1～K4 的单周期脉冲 |
| `mode` | 2 | CL/AL/St/Cd |
| `setting` | 1 | 设置状态 |
| `cursor` | 3 | 0～5 |
| `edit_load/commit` | 1 | 编辑缓冲控制 |
| `digit_inc/dec` | 1 | 选中位加减 |
| `alarm_trigger` | 1 | 闹钟到点单周期脉冲 |
| `cd_expire_pulse` | 1 | 倒计时到 0 单周期脉冲 |
| `beep_en` | 1 | 蜂鸣器使能 |
| `blink2` | 1 | 2 Hz 闪烁方波 |

---

## 8. 时钟与复位

### 8.1 时钟

- 输入：`clk50`，50 MHz，引脚 `M15`。
- 不使用 PLL。
- `clk_gen` 产生单周期使能：
  - `tick_1hz`：50,000,000 周期；
  - `tick_100hz`：500,000 周期；
  - `tick_1khz`：50,000 周期；
  - `tick_2hz`：每 250 ms 翻转。
- 所有时序逻辑用 `clk50`，不使用 `tick_*` 当时钟。

### 8.2 复位

- 上电复位：内部计数器约 20 ms，产生 `por_done`。
- K1 手动复位：低有效，20 ms 消抖。
- `rst_n = por_done && !k1_pressed`。
- 所有时序逻辑同步复位：`always @(posedge clk) if (!rst_n) ...`。
- K1 复位不会清零动态配置板的 nibble；`key_input` 重新锁存当前 nibble。

### 8.3 仿真加速

- 顶层参数 `SIM_FAST`：
  - 0：真实分频，用于综合/上板；
  - 1：短分频，用于仿真。
- 仿真时 `SIM_FAST=1`，1 Hz tick 只用几十个周期，秒表/倒计时可以在毫秒级仿真时间内跑完。
- 综合时 `SIM_FAST=0`，必须重新全编译。

---

## 9. 参数与命名约定

| 参数/后缀 | 说明 |
|---|---|
| `CLK_FREQ` | 50,000,000 |
| `SIM_FAST` | 0=真实，1=仿真加速 |
| `TONE_DIV` | 2.7 kHz 方波翻转计数，默认 9,259 |
| `_n` | 低有效信号，如 `seg_n`、`dig_n`、`led_n` |
| `_bcd` | BCD 编码 |
| `tick_*` | 单周期使能，不是时钟 |
| `edit_*` | 编辑缓冲相关 |
| `alarm_*` | 闹钟相关 |
| `cd_*` | 倒计时相关 |
| `sw_*` | 秒表相关 |

### 9.1 状态编码

```text
MODE_CL = 2'b00
MODE_AL = 2'b01
MODE_ST = 2'b10
MODE_CD = 2'b11
```

---

## 10. 引脚总表（58 个 I/O）

### 10.1 时钟、核心按键、蜂鸣器、LED

| 信号 | 位 | FPGA 引脚 | 说明 |
|---|---|---|---|
| `clk50` | — | `M15` | 50 MHz |
| `key_core_n` | 0 | `P9` | K1 复位 |
| `key_core_n` | 1 | `N9` | K2 + |
| `key_core_n` | 2 | `M10` | K3 − |
| `key_core_n` | 3 | `P11` | K4 进入/确认 |
| `buzzer` | — | `T13` | 低有效 |
| `led_n` | 0 | `T15` | LED1 |
| `led_n` | 1 | `M9` | LED2 |
| `led_n` | 2 | `L9` | LED3 |
| `led_n` | 3 | `T14` | LED4 |

### 10.2 数码管段选

| 信号 | 位 | 模式 9 | FPGA 引脚 |
|---|---|---|---|
| `seg_n` | 7 | `PO[7]`/g | `C2` |
| `seg_n` | 6 | `PO[6]`/f | `D1` |
| `seg_n` | 5 | `PO[5]`/e | `B3` |
| `seg_n` | 4 | `PO[4]`/d | `A3` |
| `seg_n` | 3 | `PO[3]`/c | `B5` |
| `seg_n` | 2 | `PO[2]`/b | `A5` |
| `seg_n` | 1 | `PO[1]`/a | `B7` |
| `seg_n` | 0 | `PO[0]`/dp | `B6` |

### 10.3 数码管位选

| 信号 | 位 | 模式 9 | FPGA 引脚 | 数码管 |
|---|---|---|---|---|
| `dig_n` | 0 | `PO[8]` | `J2` | 数码 1 |
| `dig_n` | 1 | `PO[9]` | `G1` | 数码 2 |
| `dig_n` | 2 | `PO[10]` | `L2` | 数码 3 |
| `dig_n` | 3 | `PO[11]` | `K1` | 数码 4 |
| `dig_n` | 4 | `PO[12]` | `P2` | 数码 5 |
| `dig_n` | 5 | `PO[13]` | `N1` | 数码 6 |
| `dig_n` | 6 | `PO[14]` | `R1` | 数码 7 |
| `dig_n` | 7 | `PO[15]` | `L4` | 数码 8 |

### 10.4 模式 9 按键输入

| 信号 | 位 | 对应键 | FPGA 引脚 |
|---|---|---|---|
| `pi_in` | 15..12 | 键 4 | `T12, R13, T10, R11` |
| `pi_in` | 11..8 | 键 3 | `T8, R9, T6, R7` |
| `pi_in` | 7..4 | 键 2 | `T4, R5, K8, R3` |
| `pi_in` | 3..0 | 键 1 | `N8, M8, P6, L7` |
| `pio_in` | 15..12 | 键 8 | `B4, C3, D3, J1` |
| `pio_in` | 11..8 | 键 7 | `L1, J6, L3, P3` |
| `pio_in` | 7..4 | 键 6 | `A4, B1, G2, K2` |
| `pio_in` | 3..0 | 键 5 | `N2, P1, L6, N5` |

---

## 11. 测试计划

| 用例 | 场景 | 预期 |
|---|---|---|
| TB_RESET | 上电/ K1 复位 | CL、00:00:00、闹钟关、秒表 0、倒计时 00:05:00 |
| TB_TICK | 1 Hz 走秒 | 59→00 进位；23:59:59→00:00:00 |
| TB_KEY | 每个 nibble 变化 | 一次变化一个脉冲；20 ms 消抖；16 次回绕 |
| TB_CL_SET | CL 设置 | 编辑值冻结；光标移动；加减范围；确认写入；取消丢弃 |
| TB_AL_SET | AL 设置 | 6 位可调；key1 开关；确认/取消 |
| TB_ALARM | 闹钟到点 | 精确到秒触发一次；3 下×2 组 |
| TB_ST | 秒表 | 启动/暂停/清零；10 ms；99:59.99 停止 |
| TB_CD | 倒计时 | 设置/启动/暂停/复位/清零；0 启动不响；到 0 响 2 下×1 组 |
| TB_MODE | 模式切换 | CL→AL→St→Cd→CL；设置中取消；后台计时 |
| TB_DISPLAY | 显示扫描 | 8 位轮流选通；段码正确；模式标识/闪烁/小数点 |
| TB_BEEP | 提示音 | 闹钟 3×2；倒计时 2×1；任意键静音；闹钟优先 |

### 11.1 仿真通过标准

- 所有用例无 X/不定态。
- 关键波形与预期一致。
- 资源占用在 10CL006 范围内。
- Quartus 全编译通过，时序满足 50 MHz。

### 11.2 已实现结果（2026-11-22）

| 项目 | 结果 |
|---|---|
| ModelSim 编译 | 0 errors, 0 warnings |
| 自检 testbench | 9 组用例，74 个 PASS，0 ERROR，`ALL TESTS PASSED` |
| Quartus Analysis & Synthesis | 0 errors, 0 warnings |
| Quartus Fitter | 0 errors, 1 warning（AN447 3.3 V 接口提示，属实验箱 3.3 V 电平正常提示） |
| 逻辑单元 | 1,584 / 6,272（25%） |
| 寄存器 | 680 |
| 用户 I/O | 58 / 177（33%） |
| PLL / RAM / DSP | 0 / 0 / 0 |
| 50 MHz setup slack | 9.256 ns（Slow 1200mV 85°C） |
| 50 MHz hold slack | 0.452 ns（Slow 1200mV 85°C） |
| 最小脉宽 slack | 9.687 ns（Slow 1200mV 85°C） |

> 说明：1,584 LE 比最初 800～1,200 的估算高，原因是 8 路 nibble 按键、32 位 PI/PIO 输入、6 位 BCD 编辑和显示选择都做成了可读性较好的独立逻辑；仍只占 10CL006 的 25%，资源充足。

---

## 12. 文件结构

```text
DigitalClock/
  DigitalClock.qpf
  DigitalClock.qsf
  DigitalClock.sdc
  rtl/
    digital_clock_top.v
    clk_gen.v
    nibble_key.v
    core_key.v
    key_input.v
    key_ctrl.v
    bcd_digit_adj.v
    time_counter.v
    alarm_ctrl.v
    stopwatch.v
    countdown.v
    beep_ctrl.v
    buzzer_tone.v
    display_ctrl.v
    seg_decode.v
  sim/
    tb_digital_clock_top.v
    compile.do
    run_sim.do
    run_sim.bat
    wave_all.do
    render_wave.py
  constraints/
    pin_assignments.csv
  docs/
    00_design_baseline.md
    00_board_config.md
    00_document_plan.md
    00_document_outlines.md
    00_traceability_matrix.md
    01_key_manual.md
    02_divider_manual.md
    03_architecture_manual.md
    04_simulation_manual.md
    05_final_plan.md
  images/
    wave_time.png
    wave_rollover.png
    wave_key.png
    wave_cl_set.png
    wave_alarm.png
    wave_countdown.png
    wave_display.png
    wave_buzzer.png
```

---

## 13. 风险与限制

| 风险/限制 | 说明 | 应对 |
|---|---|---|
| 模式 9 按键不能清零 | FPGA 只能读 PI/PIO | 用 `prev` 影子寄存器，只检测变化 |
| 按住不一定连发 | 手册未保证 | 核心板 K2/K3 做连发 |
| 断电不保存 | FPGA 是 SRAM | 文档写明；如需保存加 RTC/EEPROM |
| 无实物照片 | 开发环境没有实验箱 | 文档留拍摄位置和说明，用户补拍 |
| 倒计时最大 23:59:59 | 与时钟格式一致 | 文档写明 |
| 闹钟一天一次 | 用相等沿检测，`match_d` 防止同一秒重复触发 | 时间离开相等状态后自然复位 |
| 蜂鸣器有源/无源 | 板载为无源 | 必须用 2.7 kHz 方波，不能只给直流 |

---

## 14. 本基线确认后不再随意改动的部分

1. 58 个引脚分配。
2. 模式 9 的 nibble 与按键对应关系。
3. 按键总表（含 Cd 键 2 清零、键 6 复位、键 7 进入/确认）。
4. 显示布局与闪烁规则。
5. 模块划分与文件名。
6. 仿真加速参数 `SIM_FAST`。
7. 不做断电保存。

> 如需改以上内容，先改本基线，再同步改代码和五份说明书。

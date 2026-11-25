# 需求—模块—测试—文档对照表

> 版本：v1.1（已实现）  
> 对应基线：`docs/00_design_baseline.md` v1.1  
> 作用：确认每条需求都有“实现模块、验证用例、文档落点”；后续改功能时按本表检查，避免代码、仿真、说明书三处不一致。

---

## 0. 怎么用这张表

| 想查什么 | 看哪一节 |
|---|---|
| 某条需求由谁实现、怎么测、写在哪 | §1 总表 |
| 某个功能的具体行为 | §2 行为细化 |
| 某个按键在某个模式下做什么 | §3 按键动作 |
| 某个 testbench 覆盖什么 | §4 测试用例 |
| 某份说明书覆盖什么 | §5 文档覆盖 |
| 某个代码文件负责什么 | §6 代码覆盖 |
| 还有什么没做完 | §7 未关闭项 |
| 改功能时怎么同步 | §8 变更检查清单 |

---

## 1. 需求总表

| 需求 | 验收要点 | 主模块 | 关键信号 | 测试用例 | 文档落点 |
|---|---|---|---|---|---|
| R1 时钟 | 24 小时 `HH:MM:SS`；可调；正常走秒 | `time_counter` | `time_bcd`, `edit_bcd`, `tick_1hz` | TB_TICK, TB_CL_SET | D3 §5.1；D1 §5.1/§6；D4 §7.2；D5 §6.3 |
| R2 闹钟 | `HH:MM:SS` 可设、可开关、LED2；到点 3 下×2 组 | `alarm_ctrl`, `beep_ctrl`, `buzzer_tone` | `alarm_bcd`, `alarm_en`, `alarm_trigger`, `beep_en` | TB_AL_SET, TB_ALARM, TB_BEEP | D3 §5.2/§6.5；D1 §5.2；D4 §7.5；D5 §6.4 |
| R3 秒表 | `MM:SS:CC`；10 ms；启动/暂停/清零；99:59.99 停 | `stopwatch` | `min_bcd`, `sec_bcd`, `cs_bcd`, `running` | TB_ST | D3 §5.3；D1 §5.3；D4 §7.6；D5 §6.5 |
| R4 倒计时 | `HH:MM:SS`；启动/暂停/复位/清零；到 0 响 2 下×1 组；0 启动不响 | `countdown`, `beep_ctrl` | `preset_bcd`, `remain_bcd`, `expired`, `expire_pulse` | TB_CD, TB_BEEP | D3 §5.4/§6.5；D1 §5.4；D4 §7.7；D5 §6.6 |
| R5 显示 | 8 位动态扫描；模式标识 + 6 位数值；选中位 2 Hz 闪烁 | `display_ctrl`, `seg_decode` | `seg_n`, `dig_n`, `blink2` | TB_DISPLAY | D3 §5.5；D4 §7.8；D5 §3.2 |
| R6 按键 | 模式 9 键 1～8 + 核心 K1～K4；消抖；主功能不依赖核心键 | `key_input`, `key_ctrl` | `key_press`, `core_press`, `mode`, `setting`, `cursor` | TB_KEY, TB_MODE | D1 §2～§6；D3 §6.4；D4 §7.3 |
| R7 模式切换 | CL/AL/St/Cd 循环；设置中按 8 取消并跳转；St/Cd 后台继续 | `key_ctrl` | `mode`, `setting` | TB_MODE | D1 §5.5；D3 §6.1；D4 §7.4；D5 §6.1 |
| R8 复位 | 上电复位 + K1 手动复位；回默认值 | `digital_clock_top`, `clk_gen` | `rst_n`, `por_done`, `k1_pressed` | TB_RESET | D1 §4.3；D3 §4.3～4.4；D4 §7.1；D5 §6.2 |
| R9 断电保存 | 不做；断电后数据丢失 | 无（负需求） | — | 文档检查 | D3 §10.4；D5 §9.3 |
| R10 工具链 | Quartus 17.1 + ModelSim-ASE 17.1；可编译/仿真/下载 | 工程文件 | `.qpf`, `.qsf`, `.sdc` | 全编译 + 全部 TB | D5 §5；D4 §2～§5 |
| R11 文档 | 五份说明书；中文注释；图表齐全；不臃肿 | `docs/` | — | 评审 | D0～D5 |

> 文档代号：D0=总体基线，D1=按键操作，D2=分频器，D3=系统架构，D4=仿真流程，D5=最终方案。

---

## 2. 行为细化

### 2.1 时钟（R1）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| CLK-01 | 每秒加 1 | `tick_1hz` | `time_counter` 秒个位 +1 | TB_TICK | D3 §5.1 |
| CLK-02 | 秒 59→00，分 +1 | `ss_t==5 && ss_o==9` | 秒清零、分加 1 | TB_TICK | D3 §5.1 |
| CLK-03 | 分 59→00，时 +1 | `mm_t==5 && mm_o==9` | 分清零、时加 1 | TB_TICK | D3 §5.1 |
| CLK-04 | 23:59:59→00:00:00 | `hh_t==2 && hh_o==3` | 全清零 | TB_TICK | D3 §5.1 |
| CLK-05 | 设置时编辑值冻结 | `setting==1` | `edit_bcd` 不随 `tick_1hz` 变 | TB_CL_SET | D3 §3.5 |
| CLK-06 | 确认写入正式值 | key7/K4 确认 | `time_bcd <= edit_bcd` | TB_CL_SET | D1 §5.3 |
| CLK-07 | 取消丢弃 | key8 取消 | `edit_bcd` 丢弃，`time_bcd` 不变 | TB_CL_SET | D1 §5.3 |
| CLK-08 | 正式时钟后台走 | `setting==1` | `time_bcd` 仍按 `tick_1hz` 加 1 | TB_CL_SET | D3 §3.5 |

### 2.2 闹钟（R2）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| AL-01 | 6 位可设到秒 | 设置态 | `alarm_bcd` 6 位 BCD | TB_AL_SET | D1 §5.3 |
| AL-02 | 开关与 LED2 | AL 正常，key1 | `alarm_en` 翻转；LED2=亮/灭 | TB_AL_SET | D1 §5.3 |
| AL-03 | 相等比较 | 每个 `tick_1hz` | `time_bcd == alarm_bcd` | TB_ALARM | D3 §5.2 |
| AL-04 | 单次触发 | 相等且 `alarm_en` 且未触发 | 用 `match_d` 检测上升沿，产生一个 `alarm_trigger`；时间不再相等时自动复位 | TB_ALARM | D3 §5.2 |
| AL-05 | 3 下×2 组 | `alarm_trigger` | 150 ms 响/150 ms 停；组间 600 ms | TB_BEEP | D3 §6.5；D2 §5 |
| AL-06 | 任意键静音 | 任意 `key_press`/`core_press` | `beep_en` 清零 | TB_BEEP | D3 §6.5 |
| AL-07 | 设置冻结/确认/取消 | 设置态 | 同 CLK-05～07 | TB_AL_SET | D1 §5.3 |
| AL-08 | 闹钟优先 | 闹钟与倒计时同时触发 | 闹钟序列先播 | TB_BEEP | D3 §6.5 |

### 2.3 秒表（R3）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| ST-01 | 10 ms 加 1 | `tick_100hz` 且运行 | `cs_bcd` +1 | TB_ST | D3 §5.3 |
| ST-02 | 启动/暂停 | St 模式 key1 | `running` 翻转 | TB_ST | D1 §5.3 |
| ST-03 | 清零并暂停 | St 模式 key2 | 分/秒/厘秒清零，`running=0` | TB_ST | D1 §5.3 |
| ST-04 | 99:59.99 自动停 | 到最大值 | `running=0` | TB_ST | D3 §5.3 |
| ST-05 | 后台运行 | 切出 St | `running` 保持，LED3 指示 | TB_MODE | D1 §5.3 |
| ST-06 | 切模式不清零 | key8 | 计数值保持 | TB_MODE | D1 §5.5 |

### 2.4 倒计时（R4）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| CD-01 | 6 位可设，最大 23:59:59 | 设置态 | `preset_bcd` 6 位 BCD | TB_CD | D1 §5.4 |
| CD-02 | 启动/暂停 | Cd 未到期且剩余≠0，key1 | `running` 翻转 | TB_CD | D1 §5.4 |
| CD-03 | 恢复设定值 | 未运行，key2 | `remain_bcd <= preset_bcd` | TB_CD | D1 §5.4 |
| CD-04 | 清零到 0 | 已取消（需要 0 就在设置里改） | — | — | D1 §5.4 |
| CD-05 | 0 启动无效 | `remain_bcd==0`，key1 | 不启动、不响 | TB_CD | D1 §5.4 |
| CD-06 | 每秒减 1 | `tick_1hz` 且运行 | `remain_bcd` 减 1 | TB_CD | D3 §5.4 |
| CD-07 | 1→0 触发 | 减到 0 | `expired=1`，`expire_pulse` 单周期 | TB_CD | D3 §5.4 |
| CD-08 | 2 下×1 组 | `expire_pulse` | 200 ms 响/200 ms 停，仅一组 | TB_BEEP | D3 §6.5；D2 §5 |
| CD-09 | 后台运行 | 切出 Cd | `running` 保持，LED4 指示 | TB_MODE | D1 §5.4 |
| CD-10 | 进入设置条件 | `!running && !expired`，key7/K4 | 进入/确认 | TB_CD | D1 §5.4 |
| CD-11 | 到期后恢复 | 到期后 key2 | 复位并清 `expired`，可再启动 | TB_CD | D1 §5.4 |
| CD-12 | 设置冻结/确认/取消 | 设置态 | 设定值/剩余值规则按基线 | TB_CD | D1 §5.4 |

### 2.5 显示（R5）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| DP-01 | 8 位轮流选通 | 1 kHz | `scan_idx` 0～7；`dig_n=~(1<<idx)` | TB_DISPLAY | D3 §5.5 |
| DP-02 | 布局 | 所有模式 | `d[7:6]` 模式；`d[5:0]` 数值 | TB_DISPLAY | D5 §3.2 |
| DP-03 | 小数点 | CL/AL/Cd；St | `d[4]`、`d[2]` | TB_DISPLAY | D5 §3.2 |
| DP-04 | 模式标识 | CL/AL/St/Cd | `C L`、`A L`、`S t`、`C d` | TB_DISPLAY | D3 §5.5 |
| DP-05 | 选中位 2 Hz 闪烁 | 设置态 | `blink2` 与 `cursor` 比较 | TB_DISPLAY | D1 §5.4 |
| DP-06 | 模式标识闪烁 | 设置/运行/暂停/到期 | `blink2` 控制 `d[7:6]` | TB_DISPLAY | D1 §5.4 |
| DP-07 | 空白 | 无效位 | 段码全 1（灭） | TB_DISPLAY | D3 §5.5 |
| DP-08 | 低有效 | 全部 | 段选/位选取反输出 | TB_DISPLAY | D2 §2.3 |
| DP-09 | 段码字符集 | 0～9、A/C/d/L/S/t、空白 | `seg_decode` | TB_DISPLAY | D3 §5.5 |

### 2.6 按键（R6）

| 编号 | 行为 | 条件 | 实现 | 测试 | 文档 |
|---|---|---|---|---|---|
| KEY-01 | 两级同步 | 所有 PI/PIO | 两个 `clk50` 触发器 | TB_KEY | D1 §3.1 |
| KEY-02 | 20 ms 消抖 | nibble 变化 | 稳定 20 ms（1,000,000 个 50 MHz 周期，或 20 个 1 ms tick） | TB_KEY | D1 §3.2 |
| KEY-03 | 上电锁存 `prev` | 复位释放 | `prev <= synced` | TB_KEY | D1 §3.3 |
| KEY-04 | 一次变化一个脉冲 | 稳定后仍不同 | 单周期 `key_press` | TB_KEY | D1 §3.4 |
| KEY-05 | 16 次回绕 | 0000→…→1111→0000 | 只比较不等，不比较大小 | TB_KEY | D1 §3.5 |
| KEY-06 | 核心键连发 | K2/K3 按住 0.5 s | 10 Hz 重复脉冲 | TB_KEY | D1 §4.4 |
| KEY-07 | K1 复位 | 任意时刻 | 20 ms 消抖后 `rst_n=0` | TB_RESET | D1 §4.3 |
| KEY-08 | FPGA 不能清零 nibble | 硬件事实 | 只读 PI/PIO，不驱动 | 文档检查 | D1 §2.3 |
| KEY-09 | 任意键静音 | 提示音期间 | `beep_en` 清零 | TB_BEEP | D3 §6.5 |

---

## 3. 按键动作对照

> 这张表是 `key_ctrl` 的“行为清单”，也是按键说明书的总表。实现时一个动作对应一个单周期脉冲。

| 输入 | 模式/条件 | 动作 | 目标模块 | 测试 | 文档 |
|---|---|---|---|---|---|
| key8 | CL 正常 | 转 AL | `key_ctrl` | TB_MODE | D1 §5.5 |
| key8 | CL 设置 | 取消，转 AL | `key_ctrl` | TB_CL_SET | D1 §5.3 |
| key8 | AL 正常 | 转 St | `key_ctrl` | TB_MODE | D1 §5.5 |
| key8 | AL 设置 | 取消，转 St | `key_ctrl` | TB_AL_SET | D1 §5.3 |
| key8 | St | 转 Cd；秒表后台继续 | `key_ctrl`, `stopwatch` | TB_MODE | D1 §5.3 |
| key8 | Cd | 转 CL；倒计时后台继续 | `key_ctrl`, `countdown` | TB_MODE | D1 §5.4 |
| key8 | Cd 设置 | 取消，转 CL | `key_ctrl` | TB_CD | D1 §5.4 |
| key7 | CL | 进入/确认设置 | `time_counter` | TB_CL_SET | D1 §5.3 |
| key7 | AL | 进入/确认设置 | `alarm_ctrl` | TB_AL_SET | D1 §5.3 |
| key7 | Cd `!running && !expired` | 进入/确认设置 | `countdown` | TB_CD | D1 §5.4 |
| key7 | Cd 运行/到期 | 无操作 | — | TB_CD | D1 §5.4 |
| key2 | Cd 未运行 | 恢复设定值，清 `expired` | `countdown` | TB_CD | D1 §5.4 |
| key2 | Cd 运行 | 无操作 | — | TB_CD | D1 §5.4 |
| key1 | Cd 未到期且剩余≠0 | 启动/暂停 | `countdown` | TB_CD | D1 §5.4 |
| key1 | Cd 到期或剩余=0 | 无操作 | — | TB_CD | D1 §5.4 |
| key4 | 设置态 | 光标左移，0～5 循环 | `key_ctrl` | TB_CL_SET | D1 §5.3 |
| key3 | 设置态 | 光标右移，0～5 循环 | `key_ctrl` | TB_CL_SET | D1 §5.3 |
| key2 | 设置态 | 选中位 +1（按范围回绕） | `time_counter`/`alarm_ctrl`/`countdown` | TB_CL_SET | D1 §5.3 |
| key2 | St | 清零并暂停 | `stopwatch` | TB_ST | D1 §5.3 |
| key6 | 全部模式 | 无操作（复位已并入键 2） | — | — | D1 §5.4 |
| key2 | CL/AL 正常 | 无操作 | — | TB_CL_SET | D1 §5.3 |
| key1 | 设置态 | 选中位 −1（按范围回绕） | `time_counter`/`alarm_ctrl`/`countdown` | TB_CL_SET | D1 §5.3 |
| key1 | AL 正常 | 闹钟开关，LED2 指示 | `alarm_ctrl` | TB_AL_SET | D1 §5.3 |
| key1 | St | 启动/暂停 | `stopwatch` | TB_ST | D1 §5.3 |
| key1 | CL/Cd 正常 | 无操作 | — | TB_CL_SET | D1 §5.3 |
| K1 | 任意 | 全局复位 | `digital_clock_top` | TB_RESET | D1 §4.3 |
| K2 | 设置态 | +1；按住 0.5 s 后 10 Hz 连加 | `key_input`, `key_ctrl` | TB_KEY | D1 §4.4 |
| K3 | 设置态 | −1；按住 0.5 s 后 10 Hz 连减 | `key_input`, `key_ctrl` | TB_KEY | D1 §4.4 |
| K4 | CL/AL；Cd `!running && !expired` | 进入/确认设置，等同 key7 | `key_ctrl` | TB_CL_SET | D1 §4.4 |
| 任意键 | 提示音期间 | 静音 | `beep_ctrl` | TB_BEEP | D3 §6.5 |

---

## 4. 测试用例覆盖

| 用例 | 覆盖需求 | 主要激励 | 通过标准 | 文档 |
|---|---|---|---|---|
| TB_RESET | R1, R2, R3, R4, R8, R9 | 上电；按 K1；释放 | CL；`00:00:00`；闹钟关；秒表 0；倒计时 `00:05:00` | D4 §7.1 |
| TB_TICK | R1 | 强制 `tick_1hz`；从 00:00:59、23:59:59 开始 | 进位正确；日回绕正确；无 X | D4 §7.2 |
| TB_KEY | R6 | 逐次改变 8 个 nibble；抖动；16 次回绕；K2/K3 长按 | 一次变化一个脉冲；20 ms 消抖；回绕不丢键；连发 10 Hz | D4 §7.3 |
| TB_CL_SET | R1, R5, R6, R7 | key7 进入；key4/3 移光标；key2/1 加减；key7 确认；key8 取消 | 编辑值冻结；范围回绕；确认写入；取消丢弃 | D4 §7.4 |
| TB_AL_SET | R2, R6 | 设置 `00:00:05`；key1 开关；确认/取消 | 6 位可调；LED2 正确；确认/取消正确 | D4 §7.5 |
| TB_ALARM | R2 | 闹钟设为 1 s 后；使能；等待触发；按键静音 | 只触发一次；3 下×2 组；任意键停 | D4 §7.5 |
| TB_ST | R3 | 启动；等 10 ms；暂停；清零；跑到 99:59.99 | 10 ms 精度；暂停保持；清零；自动停 | D4 §7.6 |
| TB_CD | R4 | 设 00:00:03；启动；暂停；复位；清零；0 启动；跑到 0 | 各动作正确；0 启动不响；到 0 响 2 下×1 组 | D4 §7.7 |
| TB_MODE | R7 | CL→AL→St→Cd→CL；设置中按 8；St/Cd 切走 | 循环正确；取消正确；后台计时 | D4 §7.4 |
| TB_DISPLAY | R5 | 扫描 8 位；各模式；设置闪烁；小数点 | 8 位轮流；段码正确；闪烁 2 Hz；小数点正确 | D4 §7.8 |
| TB_BEEP | R2, R4 | 触发闹钟；触发倒计时；同时触发；按键静音 | 3×2；2×1；闹钟优先；静音 | D4 §7.9 |

### 4.1 覆盖说明

- R9 是负需求，不需要 testbench，靠文档和代码检查确认“没有断电保存逻辑”。
- R11 是文档需求，靠评审五份说明书确认。
- R10 靠“全编译通过 + 全部 TB 通过 + 下载成功”确认。

---

## 5. 文档覆盖

| 文档 | 核心章节 | 覆盖需求 | 主要代码 | 主要测试 |
|---|---|---|---|---|
| D0 总体基线 | 全文 | R1～R11 | 全部接口 | 全部 TB |
| D1 按键操作 | §2～§6 | R6, R1, R2, R3, R4, R7 | `key_input`, `key_ctrl`, 顶层按键例化 | TB_KEY, TB_MODE, TB_CL_SET |
| D2 分频器 | §3～§5 | R1, R2, R4, R10 | `clk_gen`, `buzzer_tone` | TB_TICK, TB_BEEP |
| D3 系统架构 | §2～§8 | R1～R8 | 顶层 + 全部模块 | 全部 TB |
| D4 仿真流程 | §2～§9 | R1～R8, R10 | testbench、`.do` | 全部 TB |
| D5 最终方案 | §2～§8 | R1～R11 | 全部 | 全部 TB + 上板 |

---

## 6. 代码覆盖

| 文件 | 覆盖需求 | 关键内容 | 主要测试 | 文档 |
|---|---|---|---|---|
| `rtl/digital_clock_top.v` | R1～R8 | 例化、复位、引脚连接 | 全部 | D3 §8 |
| `rtl/clk_gen.v` | R1, R2, R4, R5 | 1 Hz/100 Hz/1 kHz/2 Hz tick；`SIM_FAST` | TB_TICK, TB_DISPLAY | D2 §4 |
| `rtl/nibble_key.v` | R6 | 单路 4 位 nibble 同步、20 ms 消抖、变化检测 | TB_KEY | D1 §6 |
| `rtl/core_key.v` | R6 | 核心键消抖、按下脉冲、K2/K3 连发 | TB_KEY | D1 §4/§6 |
| `rtl/key_input.v` | R6 | 8 路 nibble + 4 路核心键 | TB_KEY | D1 §6 |
| `rtl/key_ctrl.v` | R6, R7 | 模式 FSM、设置 FSM、光标、动作译码 | TB_MODE, TB_CL_SET | D1 §6；D3 §6 |
| `rtl/bcd_digit_adj.v` | R1, R2, R4 | 24 位 BCD 按位加减、段内进位/借位 | TB_CL_SET, TB_CD | D1 §5.5 |
| `rtl/time_counter.v` | R1 | BCD 走秒、进位、编辑缓冲 | TB_TICK, TB_CL_SET | D3 §5.1 |
| `rtl/alarm_ctrl.v` | R2 | BCD 设置、比较、单次触发、开关 | TB_AL_SET, TB_ALARM | D3 §5.2 |
| `rtl/stopwatch.v` | R3 | 10 ms BCD、启动/暂停/清零/自动停 | TB_ST | D3 §5.3 |
| `rtl/countdown.v` | R4 | 设定/剩余、启动/暂停/复位/清零、到期 | TB_CD | D3 §5.4 |
| `rtl/beep_ctrl.v` | R2, R4 | 3×2、2×1、优先级、静音 | TB_BEEP | D3 §6.5 |
| `rtl/buzzer_tone.v` | R2, R4 | 2.7 kHz 方波、低有效 | TB_BEEP | D2 §5 |
| `rtl/display_ctrl.v` | R5 | 8 位扫描、模式选择、闪烁、小数点、LED1 心跳 | TB_DISPLAY | D3 §5.5 |
| `rtl/seg_decode.v` | R5 | 七段译码、字符集 | TB_DISPLAY | D3 §5.5 |
| `sim/tb_digital_clock_top.v` | R1～R8 | 10 组用例、82 个 PASS 的自检 testbench | 全部 | D4 §7 |
| `sim/compile.do` | R10 | 建库、编译 RTL/testbench | 全部 | D4 §5 |
| `sim/run_sim.do` | R10 | 编译、加载、加波形、运行 | 全部 | D4 §5 |
| `sim/run_sim.bat` | R10 | Windows 一键批处理仿真 | 全部 | D4 §5 |
| `sim/wave_all.do` | R10 | 分组加波形 | 全部 | D4 §6 |

---

## 7. 覆盖统计与未关闭项

### 7.1 统计

| 项目 | 数量 | 说明 |
|---|---|---|
| 需求 | 11 | R1～R11 全部有落点 |
| 功能行为 | 6 组 52 条 | CLK 8、AL 8、ST 6、CD 12、DP 9、KEY 9（含跨需求重叠） |
| 测试用例 | 10 组 / 82 个检查 | testbench 输出 82 个 PASS、0 ERROR |
| RTL 模块 | 15 个 | 见 §6 |
| 仿真/脚本 | 5 个 | testbench + compile/run/wave/bat |
| 说明书 | 5 份 + 基线 | D0～D5 |

### 7.2 实测结果

| 项目 | 结果 |
|---|---|
| ModelSim 编译 | 0 errors, 0 warnings |
| 自检 testbench | `ALL TESTS PASSED`，82 PASS / 0 ERROR |
| Quartus 全编译 | 0 errors，1 warning（AN447 3.3 V 接口提示） |
| 逻辑单元 | 1,584 / 6,272（25%） |
| 寄存器 | 680 |
| 用户 I/O | 58 / 177（33%） |
| 50 MHz setup slack | 9.256 ns（Slow 1200mV 85°C） |
| 50 MHz hold slack | 0.452 ns（Slow 1200mV 85°C） |

### 7.3 未关闭项

| 编号 | 事项 | 影响 | 计划 |
|---|---|---|---|
| O1 | RTL 代码已完成 | 已通过 ModelSim 编译和 Quartus 综合/布局布线 | 完成 |
| O2 | testbench 已完成 | 10 组用例全部通过 | 完成 |
| O3 | Quartus 工程已完成 | 已生成 `.sof`、资源/时序报告 | 完成 |
| O4 | 上板照片未拍 | D5 的图 7-2 只能留占位 | 用户上板后补拍 |
| O5 | 蜂鸣器实际频率未测 | 2.7 kHz 是设计值，需实测确认 | 上板用示波器/逻辑分析仪测 `T13` |
| O6 | 按键抖动特性未实测 | 20 ms 是保守值，需上板验证 | 上板按 1/10/100 次观察丢键/重键 |
| O7 | LED1 功能已分配 | 已实现 1 Hz 心跳 | 完成 |
| O8 | 倒计时到期后 key2 恢复、key1 再启动 | TB_CD 已覆盖 | 完成 |

> O1～O3、O7、O8 已完成；O4～O6 需要实验箱实物才能关闭。

---

## 8. 变更检查清单

改任何功能时，按顺序做：

1. **先改基线** `docs/00_design_baseline.md`，写清改哪条需求/行为。
2. **改本表**对应的需求行、行为行、按键行、测试行。
3. **改 RTL**，保持模块接口和信号名不变；若必须改接口，同步改顶层和 D3 §8。
4. **改 testbench**，先让旧用例失败，再改预期，确保不是“改测试迁就代码”。
5. **重跑全部 TB**，更新 D4 的波形截图和关键点分析。
6. **重跑 Quartus 全编译**，更新资源/时序报告和 D5 §7。
7. **同步五份说明书**，特别是 D1 按键表、D3 框图、D5 演示脚本。
8. **记录版本**：基线版本、本表版本、代码日期。

### 8.1 不允许的变更方式

- 只改代码不改基线：下次写文档会对不上。
- 只改文档不改测试：无法证明功能真的对。
- 改引脚只改 `.qsf` 不改表：上板会接错。
- 改蜂鸣器节奏只改 `beep_ctrl` 不改 D2/D3：文档和实测不一致。

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成教程用“界面示意图”和两张流程图（Quartus 17.1 / 顶层数据流）。
注意：这些是按真实界面布局重绘的示意图，不是屏幕截图；
真实截图见 shot_quartus_main.png / shot_modelsim_bp.png。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from make_figures import (f, text, canvas, arrow, box, elbow, wire_label,
                          C_CLK, C_KEY, C_CTL, C_DAT, C_OUT, INK, GRAY, LINE, BG, OUT)

MONO = 'C:/Windows/Fonts/consola.ttf'
MONO_B = 'C:/Windows/Fonts/msgothic.ttc'
WIN_BG = '#F3F3F3'
WIN_LINE = '#9E9E9E'
FIELD = '#FFFFFF'


def has_cjk(s):
    return any('\u4e00' <= ch <= '\u9fff' for ch in s)


def mono(size, bold=False):
    from PIL import ImageFont
    return ImageFont.truetype(MONO_B if bold else MONO, size)


def ui_dialog(w, h, title, badge='界面示意（按 Quartus 17.1 布局重绘）'):
    img, d = canvas(w, h + 34, '#FFFFFF')
    d.rectangle([0, 0, w - 1, h + 33], fill=WIN_BG, outline=WIN_LINE, width=2)
    d.rectangle([2, 2, w - 3, 32], fill='#FFFFFF')
    d.line([2, 32, w - 3, 32], fill='#D0D0D0', width=1)
    d.rectangle([12, 10, 26, 26], fill='#2E6FD9')
    d.text((34, 9), title, font=f(16, True), fill='#1A1A1A')
    for i, s in enumerate(['—', '□', '✕']):
        d.text((w - 34 - i * 34, 8), s, font=f(15), fill='#555')
    if badge:
        tw = d.textlength(badge, font=f(13))
        d.rounded_rectangle([w - tw - 130, h - 2, w - 12, h + 24], radius=10,
                            fill='#FFF3E0', outline='#EF6C00', width=1)
        d.text((w - tw - 120, h + 2), badge, font=f(13), fill='#EF6C00')
    return img, d


def ui_text(d, xy, s, size=15, bold=False, fill=INK):
    d.text(xy, s, font=f(size, bold), fill=fill)


def ui_field(d, x, y, w, h=26, s='', combo=False, arrow_down=True):
    d.rectangle([x, y, x + w, y + h], fill=FIELD, outline='#8C8C8C', width=1)
    if s:
        d.text((x + 6, y + 5), s, font=f(14), fill=INK)
    if combo:
        d.rectangle([x + w - 22, y + 1, x + w - 1, y + h - 1], fill='#EDEDED', outline='#8C8C8C', width=1)
        d.polygon([(x + w - 16, y + h / 2 - 3), (x + w - 6, y + h / 2 - 3), (x + w - 11, y + h / 2 + 3)],
                  fill='#444')


def ui_btn(d, x, y, w, h, s, primary=False, disabled=False):
    fill = '#2E6FD9' if primary else '#E1E1E1'
    fg = '#FFFFFF' if primary else ('#9E9E9E' if disabled else '#222')
    d.rounded_rectangle([x, y, x + w, y + h], radius=4, fill=fill,
                        outline='#1E4FA8' if primary else '#ADADAD', width=1)
    d.text((x + w / 2, y + h / 2), s, font=f(14), fill=fg, anchor='mm')


def ui_check(d, x, y, s, on=True):
    d.rectangle([x, y, x + 14, y + 14], fill='#FFFFFF', outline='#7A7A7A', width=1)
    if on:
        d.line([x + 3, y + 7, x + 6, y + 10], fill='#1E5FCC', width=2)
        d.line([x + 6, y + 10, x + 11, y + 4], fill='#1E5FCC', width=2)
    d.text((x + 22, y - 1), s, font=f(14), fill=INK)


def ui_tabs(d, x, y, w, items, active=0):
    d.line([x, y + 30, x + w, y + 30], fill='#C8C8C8', width=1)
    cx = x
    for i, s in enumerate(items):
        tw = d.textlength(s, font=f(14)) + 28
        if i == active:
            d.rectangle([cx, y, cx + tw, y + 30], fill='#FFFFFF', outline='#C8C8C8', width=1)
            d.line([cx + 1, y + 30, cx + tw - 1, y + 30], fill='#FFFFFF', width=2)
        d.text((cx + 14, y + 7), s, font=f(14), fill=INK)
        cx += tw


# ===================================================== 图：C 与 Verilog 对照
def fig_c_vs_verilog():
    W, H = 1660, 700
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 同一个“功能”在 C 和 Verilog 里的两种写法', 25, True, anchor='ma')

    # C 侧
    d.rounded_rectangle([50, 90, 770, 620], radius=10, fill='#F5F9FF', outline='#1565C0', width=2)
    text(d, (70, 102), 'C：一段“从上往下执行”的程序', 19, True, fill='#1565C0')
    clines = [
        '// 每秒调用一次：秒 +1，满 60 进位到分',
        'void tick_1s(Time *t) {',
        '    t->sec = t->sec + 1;',
        '    if (t->sec == 60) {',
        '        t->sec = 0;',
        '        t->min = t->min + 1;',
        '    }',
        '}',
    ]
    for i, s in enumerate(clines):
        d.text((72, 150 + i * 32), s, font=(f(16) if has_cjk(s) else mono(16)), fill='#1A1A1A')
    text(d, (70, 470), 'CPU 一条一条执行这些语句；函数调用时', 16, fill=GRAY)
    text(d, (70, 496), '把参数压栈、执行、再返回。', 16, fill=GRAY)
    text(d, (70, 522), '同一时刻只有一件事在发生。', 16, fill=GRAY)
    text(d, (70, 566), '改一个变量，下一步立刻看到新值（顺序、阻塞）。', 16, fill='#1565C0')

    # Verilog 侧
    d.rounded_rectangle([920, 90, 1620, 620], radius=10, fill='#F4FBF4', outline='#2E7D32', width=2)
    text(d, (940, 102), 'Verilog：一块“一直通电工作”的电路', 19, True, fill='#2E7D32')
    vlines = [
        'module sec_cnt (',
        '    input  wire       clk,',
        '    input  wire       tick_1hz,',
        '    output reg  [7:0] sec_reg',
        ');',
        '    always @(posedge clk) begin',
        '        if (!rst_n)      sec_reg <= 8\'h00;',
        '        else if (tick_1hz) begin',
        '            if (sec_reg == 8\'h59)',
        '                sec_reg <= 8\'h00;   // 进位',
        '            else',
        '                sec_reg <= sec_reg + 1\'b1;',
        '        end',
        '    end',
        'endmodule',
    ]
    for i, s in enumerate(vlines):
        d.text((942, 150 + i * 28), s, font=(f(15) if has_cjk(s) else mono(15)), fill='#1A1A1A')
    text(d, (940, 574), '没有“执行顺序”：触发器每个时钟沿同时采样，输出立刻接到下一级。', 15, fill=GRAY)
    text(d, (940, 598), '这段代码综合出来就是 8 个 D 触发器 + 一个比较器，一直在工作。', 15, fill=GRAY)

    # 映射箭头
    pairs = [('函数', 'module 模块', 168),
             ('形参 / 返回值', 'input / output 端口', 243),
             ('函数调用', '例化（放一块芯片）', 318),
             ('局部变量', 'reg 寄存器', 393),
             ('没有“主程序”', 'always 块 + 时钟', 468)]
    for (a, b, y) in pairs:
        text(d, (800, y), a, 15, True, fill='#EF6C00', anchor='ra')
        arrow(d, (810, y + 10), (910, y + 10), color='#EF6C00', width=2, head=9)
        text(d, (800, y + 22), b, 13, fill='#EF6C00', anchor='ra')
    img.save(os.path.join(OUT, 'fig_c_vs_verilog.png'))
    print('fig_c_vs_verilog.png')


# ===================================================== 图：Quartus 编译流程
def fig_quartus_flow():
    W, H = 1700, 720
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 Quartus 全编译的 4 个阶段：从 .v 源码到能下载的 .sof', 25, True, anchor='ma')

    stages = [
        ('① Analysis & Synthesis', '分析与综合', '把 Verilog 翻译成\n门级电路（LE + 连线）', C_CLK),
        ('② Fitter', '适配（布局布线）', '把电路分配到\n具体 LE 和引脚上', C_DAT),
        ('③ Assembler', '装配', '生成烧进 FPGA 的\n.sof 比特流文件', C_CTL),
        ('④ TimeQuest', '时序分析', '检查 50 MHz 下\nsetup/hold 是否满足', C_KEY),
    ]
    x = 60
    for (en, cn, desc, c) in stages:
        d.rounded_rectangle([x, 110, x + 380, 320], radius=12, fill=c[0], outline=c[1], width=3)
        d.text((x + 190, 140), en, font=f(21, True), fill=INK, anchor='mm')
        d.text((x + 190, 172), cn, font=f(19), fill=c[1], anchor='mm')
        for i, line in enumerate(desc.split('\n')):
            d.text((x + 190, 215 + i * 30), line, font=f(18), fill=GRAY, anchor='mm')
        if x < 1250:
            arrow(d, (x + 384, 215), (x + 424, 215), color=LINE, width=4, head=14)
        x += 424

    # 输出物
    outs = [('DigitalClock.map.rpt', '资源占用、综合警告'),
            ('DigitalClock.fit.rpt', '引脚分配、布线结果'),
            ('DigitalClock.sof', '下载到板子的文件'),
            ('DigitalClock.sta.rpt', 'slack（时序余量）')]
    x = 60
    for (fn, desc) in outs:
        d.rounded_rectangle([x, 400, x + 380, 500], radius=8, fill='#FFFFFF', outline='#90A4AE', width=2)
        d.text((x + 190, 428), fn, font=mono(17), fill='#0D47A1', anchor='mm')
        d.text((x + 190, 468), desc, font=f(16), fill=GRAY, anchor='mm')
        d.line([x + 190, 322, x + 190, 396], fill='#90A4AE', width=2)
        x += 424

    text(d, (60, 550), '只做仿真时可以只跑到 ①（Analysis & Synthesis）：ModelSim 要的是“行为级代码”，不需要 .sof。',
         19, fill=GRAY)
    text(d, (60, 588), '上板必须 ①→②→③，否则没有 .sof；④ 是“体检报告”，不改代码，只告诉你跑 50 MHz 稳不稳。',
         19, fill=GRAY)
    text(d, (60, 626), '工具栏上的 ▶ 一键跑完 ①~④（Start Compilation），大约 30 s~2 min，取决于电脑。',
         19, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_quartus_flow.png'))
    print('fig_quartus_flow.png')


# ===================================================== 图：CL 设置数据流
def fig_cl_setting_flow():
    W, H = 1700, 620
    img, d = canvas(W, H)
    text(d, (W / 2, 22), '图 例：在 CL 设置里按一下 K2，让“小时”加 1，信号是怎么一路走过去的', 24, True, anchor='ma')

    steps = [
        ('你按下 K2', 'key_core_n[1] 由 1 变 0\n（低有效）', C_KEY, ''),
        ('core_key', '20 ms 消抖后\n产生一个 press 脉冲', C_KEY, 'core_press[1]'),
        ('key_ctrl', 'setting=1 时\n把按键翻译成 digit_inc', C_CTL, 'digit_inc'),
        ('bcd_digit_adj', 'edit_reg 的\ncursor 那一位 +1', C_DAT, 'edit_bcd'),
        ('time_counter', 'edit_reg 更新\n（正式时间不动）', C_DAT, 'edit_bcd'),
        ('display_ctrl', 'setting=1 时\n显示 edit_bcd', C_OUT, 'disp'),
        ('seg_decode', '数字查表\n→ 七段码', C_OUT, 'seg_n / dig_n'),
        ('数码管', '看到 时十位\n多 1', C_OUT, ''),
    ]
    n = len(steps)
    bw, gap = 178, 20
    x0 = 48
    y0 = 130
    for i, (title, desc, c, sig) in enumerate(steps):
        x = x0 + i * (bw + gap)
        d.rounded_rectangle([x, y0, x + bw, y0 + 168], radius=10, fill=c[0], outline=c[1], width=2)
        d.text((x + bw / 2, y0 + 28), title, font=f(17, True), fill=INK, anchor='mm')
        for j, line in enumerate(desc.split('\n')):
            d.text((x + bw / 2, y0 + 66 + j * 24), line, font=f(14), fill=GRAY, anchor='mm')
        if sig:
            d.text((x + bw / 2, y0 + 142), '← ' + sig, font=f(12), fill='#00695C', anchor='mm')
        if i < n - 1:
            arrow(d, (x + bw + 2, y0 + 84), (x + bw + gap - 2, y0 + 84), color=LINE, width=3, head=11)

    # 时间轴（每个箭头 1 个 clk）
    y = 350
    d.line([x0, y, x0 + n * (bw + gap) - gap, y], fill='#90A4AE', width=2)
    text(d, (x0, y + 12), '每走一步只花 0~1 个时钟周期（20 ns），整条链加起来远小于 1 ms，人眼看到的是“立刻变化”。',
         18, fill=GRAY)
    text(d, (x0, y + 48), '注意两点：① setting=1 时 display_ctrl 选的是 edit_bcd 而不是 time_bcd；',
         18, fill=GRAY)
    text(d, (x0, y + 78), '② 只有按“确认”时，time_counter 才会把 edit_reg 写回 time_reg，按“键 8 取消”则丢弃。',
         18, fill=GRAY)
    text(d, (x0, y + 130), '这也是为什么设置的时候，秒还在后台走：time_reg 一直在按 tick_1hz 加 1，只是屏幕上没显示它。',
         18, fill='#C62828')
    img.save(os.path.join(OUT, 'fig_cl_setting_flow.png'))
    print('fig_cl_setting_flow.png')


# ===================================================== UI：新建工程向导
def ui_new_project_wizard():
    W, H = 1000, 600
    img, d = ui_dialog(W, H, 'New Project Wizard')
    # 左侧步骤
    d.rectangle([16, 46, 300, H - 60], fill='#FFFFFF', outline='#D0D0D0', width=1)
    text(d, (30, 56), '步骤', 15, True, fill=GRAY)
    steps = ['1. Introduction', '2. Project Configuration', '3. EDA Tool Settings',
             '4. Summary']
    for i, s in enumerate(steps):
        y = 86 + i * 34
        if i == 1:
            d.rectangle([20, y - 4, 296, y + 26], fill='#DDEEFF', outline='#7FB2E5', width=1)
        d.text((32, y + 2), s, font=f(15, i == 1), fill='#1A1A1A')

    ui_text(d, (330, 52), 'What is the working directory for this project?', 15)
    ui_field(d, 330, 76, 620, 28, r'D:\eda\DigitalClock')
    ui_btn(d, 960, 78, 28, 24, '...', False)
    ui_text(d, (330, 120), 'What is the name of this project?', 15)
    ui_field(d, 330, 144, 300, 28, 'DigitalClock')
    ui_text(d, (330, 190), 'What is the name of the top-level design entity for this project?', 15)
    ui_field(d, 330, 214, 300, 28, 'digital_clock_top')
    ui_text(d, (330, 254), '（必须和 .v 文件里 module 后面的名字完全一样，否则报 “Top-level design entity is undefined”）',
            13, fill=GRAY)

    ui_text(d, (330, 300), '选择工程类型：', 15, True)
    d.rectangle([330, 326, 640, 388], fill='#FFFFFF', outline='#D0D0D0', width=1)
    d.text((344, 336), 'Empty project（空工程，自己加文件）', font=f(14), fill='#1A1A1A')
    d.text((344, 360), 'Project template（按模板建，本教程不用）', font=f(14), fill=GRAY)

    # 标注
    anns = [(300, 90, '① 工程放哪个文件夹：\n一个工程一个文件夹，\n路径不要有中文和空格'),
            (300, 158, '② 工程名：建议和顶层模块同名'),
            (300, 228, '③ 顶层模块名：digital_clock_top')]
    for (x, y, s) in anns:
        d.rounded_rectangle([x - 296, y - 14, x - 20, y + 56], radius=8, fill='#FFF3E0', outline='#EF6C00', width=1)
        d.text((x - 288, y - 8), s, font=f(12), fill='#BF5B00')
    ui_btn(d, 640, H - 34, 90, 28, '< Back', False, True)
    ui_btn(d, 740, H - 34, 90, 28, 'Next >', True)
    ui_btn(d, 840, H - 34, 90, 28, 'Cancel')
    img.save(os.path.join(OUT, 'ui_new_project_wizard.png'))
    print('ui_new_project_wizard.png')


# ===================================================== UI：选器件
def ui_device_select():
    W, H = 1000, 560
    img, d = ui_dialog(W, H, 'New Project Wizard - Device')
    ui_text(d, (24, 48), 'Which device family do you want to use?', 15)
    ui_field(d, 24, 72, 320, 28, 'Cyclone 10 LP', combo=True)

    ui_text(d, (24, 116), 'Which device do you want to target?', 15)
    d.rectangle([24, 140, 24 + 560, 330], fill='#FFFFFF', outline='#8C8C8C', width=1)
    d.rectangle([24, 140, 24 + 560, 164], fill='#EDEDED')
    for i, (s, x) in enumerate([('Device', 36), ('Package', 300), ('Pin', 430), ('Speed', 520)]):
        d.text((x, 146), s, font=f(14, True), fill='#333')
    rows = [('10CL006YU256C8G', 'U', '256', '8', True),
            ('10CL010YU256C8G', 'U', '256', '8', False),
            ('10CL016YU256C8G', 'U', '256', '8', False),
            ('10CL025YU256C8G', 'U', '256', '8', False),
            ('10CL040YU484C8G', 'U', '484', '8', False)]
    for i, (dev, pk, pin, sp, hi) in enumerate(rows):
        y = 172 + i * 28
        if hi:
            d.rectangle([25, y - 3, 24 + 559, y + 22], fill='#DDEEFF')
        d.text((36, y), dev, font=mono(15), fill='#1A1A1A')
        d.text((300, y), pk, font=mono(15), fill='#1A1A1A')
        d.text((430, y), pin, font=mono(15), fill='#1A1A1A')
        d.text((520, y), sp, font=mono(15), fill='#1A1A1A')

    # 过滤条件
    ui_text(d, (620, 116), '过滤器', 15, True)
    labels = [('Package', 'Any'), ('Pin count', 'Any'), ('Core speed grade', 'Any')]
    for i, (a, b) in enumerate(labels):
        y = 144 + i * 62
        ui_text(d, (620, y), a, 13, fill=GRAY)
        ui_field(d, 620, y + 20, 200, 26, b, combo=True)

    d.rectangle([24, 348, 584, 420], fill='#FFFDE7', outline='#F9A825', width=2)
    d.text((36, 356), '核心板若是 10CL010，就选 10CL010YU256C8G：封装引脚完全一样，不用改引脚约束。',
           font=f(14), fill='#8D6E00')
    d.text((36, 382), '两个型号的 LE 数不同（6272 / 10320），资源报告里的百分比会变。', font=f(14), fill='#8D6E00')

    ui_btn(d, 640, H - 34, 90, 28, '< Back', False, True)
    ui_btn(d, 740, H - 34, 90, 28, 'Next >', True)
    ui_btn(d, 840, H - 34, 90, 28, 'Cancel')
    img.save(os.path.join(OUT, 'ui_device_select.png'))
    print('ui_device_select.png')


# ===================================================== UI：编译报告
def ui_compile_report():
    W, H = 1060, 620
    img, d = ui_dialog(W, H, 'Compilation Report - DigitalClock')
    # 左侧树
    d.rectangle([14, 44, 330, H - 16], fill='#FFFFFF', outline='#D0D0D0', width=1)
    tree = [('Compilation Report', 0, False), ('Flow Summary', 1, True),
            ('Flow Settings', 1, False), ('Flow Non-Default Global Settings', 1, False),
            ('Flow Elapsed Time', 1, False), ('Flow Log', 1, False),
            ('Analysis & Synthesis', 0, False), ('Summary', 1, False),
            ('Source Files Read', 1, False), ('Warning Messages', 1, False),
            ('Fitter', 0, False), ('Placement', 1, False), ('Resource Section', 1, False),
            ('Assembler', 0, False), ('TimeQuest Timing Analyzer', 0, False),
            ('Slow 1200mV 85C Model', 1, False)]
    for i, (s, lvl, hi) in enumerate(tree):
        y = 54 + i * 30
        if hi:
            d.rectangle([16, y - 4, 328, y + 22], fill='#DDEEFF')
        d.text((28 + lvl * 16, y), ('▾ ' if lvl == 0 else '') + s, font=f(14, lvl == 0), fill='#1A1A1A')

    # 右侧表格
    ui_text(d, (352, 50), 'Flow Summary（这张表是每次编译后第一个该看的地方）', 17, True)
    rows = [('Flow Status', 'Successful - Wed Nov 25 09:00:00 2026'),
            ('Quartus Prime Version', '17.1.0 Build 590 10/25/2017 SJ Standard Edition'),
            ('Revision Name', 'DigitalClock'),
            ('Top-level Entity Name', 'digital_clock_top'),
            ('Family', 'Cyclone 10 LP'),
            ('Device', '10CL006YU256C8G'),
            ('Total logic elements', '1,584 / 6,272 ( 25 % )'),
            ('Total registers', '680'),
            ('Total pins', '58 / 177 ( 33 % )'),
            ('Total virtual pins', '0'),
            ('Total memory bits', '0 / 276,480 ( 0 % )'),
            ('Embedded Multiplier 9-bit', '0 / 30 ( 0 % )'),
            ('Total PLLs', '0 / 2 ( 0 % )')]
    y = 82
    d.rectangle([352, y, 1010, y + 28], fill='#E8E8E8', outline='#B0B0B0', width=1)
    d.text((360, y + 6), '项目', font=f(14, True), fill='#333')
    d.text((620, y + 6), '数值', font=f(14, True), fill='#333')
    y += 28
    for (k, v) in rows:
        d.rectangle([352, y, 1010, y + 26], fill='#FFFFFF', outline='#DCDCDC', width=1)
        d.rectangle([352, y, 620, y + 26], fill='#F7F7F7', outline='#DCDCDC', width=1)
        d.text((360, y + 5), k, font=f(13), fill='#1A1A1A')
        d.text((628, y + 5), v, font=f(13), fill='#1A1A1A')
        y += 26

    d.text((352, y + 14), '怎么看：① 先看 Flow Status 是否 Successful；② 看 Total logic elements 是否 < 100%（超了要简化代码）；',
           font=f(13), fill='#2E7D32')
    d.text((352, y + 38), '③ 看 Total pins 里未分配的引脚有没有变成 0；④ 时序看 TimeQuest 的 slack 是否为正。',
           font=f(13), fill='#2E7D32')
    img.save(os.path.join(OUT, 'ui_compile_report.png'))
    print('ui_compile_report.png')


# ===================================================== UI：Pin Planner
def ui_pin_planner():
    W, H = 1100, 560
    img, d = ui_dialog(W, H, 'Pin Planner - DigitalClock')
    ui_text(d, (16, 46), 'Filter:', 14)
    ui_field(d, 60, 42, 220, 26, 'All Pins', combo=True)
    ui_text(d, (300, 46), '在 Location 一列双击 / 输入引脚号，按回车生效，不用点保存。', 13, fill=GRAY)

    cols = [('Node Name', 16, 250), ('Direction', 266, 90), ('Location', 356, 110),
            ('I/O Bank', 466, 80), ('VREF Group', 546, 100), ('Fitter Location', 646, 150)]
    y = 82
    d.rectangle([16, y, 1084, y + 28], fill='#E8E8E8', outline='#A0A0A0', width=1)
    for (s, x, w) in cols:
        d.rectangle([x, y, x + w, y + 28], outline='#B8B8B8', width=1)
        d.text((x + 6, y + 6), s, font=f(13, True), fill='#333')
    y += 28
    rows = [('clk50', 'Input', 'M15', 2, 'B2_N0', 'M15'),
            ('key_core_n[0]', 'Input', 'P9', 4, 'B4_N0', 'P9'),
            ('key_core_n[1]', 'Input', 'N9', 4, 'B4_N0', 'N9'),
            ('seg_n[7]', 'Output', 'C2', 8, 'B8_N0', 'C2'),
            ('seg_n[0]', 'Output', 'B6', 8, 'B8_N0', 'B6'),
            ('dig_n[0]', 'Output', 'J2', 3, 'B3_N0', 'J2'),
            ('dig_n[7]', 'Output', 'L4', 1, 'B1_N0', 'L4'),
            ('buzzer', 'Output', 'T13', 7, 'B7_N0', 'T13'),
            ('led_n[0]', 'Output', 'T15', 7, 'B7_N0', 'T15'),
            ('pi_in[15]', 'Input', 'T12', 7, 'B7_N0', 'T12'),
            ('pi_in[0]', 'Input', 'L7', 1, 'B1_N0', 'L7'),
            ('pio_in[15]', 'Input', 'B4', 8, 'B8_N0', 'B4'),
            ('pio_in[0]', 'Input', 'N5', 3, 'B3_N0', 'N5')]
    for i, (n, dr, loc, bank, vref, fit) in enumerate(rows):
        yy = y + i * 26
        fill = '#FFFFFF' if i % 2 == 0 else '#FAFAFA'
        d.rectangle([16, yy, 1084, yy + 26], fill=fill, outline='#E0E0E0', width=1)
        vals = [(n, 16, 250, True), (dr, 266, 90, False), (loc, 356, 110, True),
                ('B' + str(bank), 466, 80, False), (vref, 546, 100, False), (fit, 646, 150, False)]
        for (s, x, w, bold) in vals:
            d.text((x + 6, yy + 5), str(s), font=mono(14) if bold else f(13),
                   fill='#0D47A1' if bold else '#333')
    d.rounded_rectangle([700, 420, 1084, 500], radius=8, fill='#FFF3E0', outline='#EF6C00', width=1)
    d.text((712, 428), '① 只填 Location，别的列不要手改；', font=f(13), fill='#BF5B00')
    d.text((712, 452), '② 未用引脚保持 “As input tri-stated”；', font=f(13), fill='#BF5B00')
    d.text((712, 476), '③ 改完关窗口即生效，重新全编译。', font=f(13), fill='#BF5B00')
    img.save(os.path.join(OUT, 'ui_pin_planner.png'))
    print('ui_pin_planner.png')


# ===================================================== UI：Programmer
def ui_programmer():
    W, H = 900, 520
    img, d = ui_dialog(W, H, 'Programmer - DigitalClock')
    ui_btn(d, 16, 46, 130, 28, 'Hardware Setup...', False)
    d.rectangle([160, 46, 470, 74], fill='#FFFFFF', outline='#8C8C8C', width=1)
    d.text((168, 52), 'USB-Blaster [USB-0]', font=f(14), fill='#1A1A1A')
    ui_text(d, (490, 52), 'Mode:', 14)
    ui_field(d, 536, 46, 120, 26, 'JTAG', combo=True)

    # 文件表
    d.rectangle([16, 96, 884, 300], fill='#FFFFFF', outline='#8C8C8C', width=1)
    d.rectangle([16, 96, 884, 122], fill='#EDEDED')
    heads = [('File', 24), ('Device', 330), ('Checksum', 470), ('Usercode', 590), ('Program', 700), ('Verify', 780)]
    for (s, x) in heads:
        d.text((x, 100), s, font=f(13, True), fill='#333')
    d.rectangle([17, 123, 883, 152], fill='#DDEEFF')
    d.text((24, 128), 'output_files/DigitalClock.sof', font=mono(14), fill='#1A1A1A')
    d.text((330, 128), '10CL006YU256', font=f(13), fill='#333')
    d.text((470, 128), '00ABCDEF', font=mono(13), fill='#333')
    d.text((590, 128), 'FFFFFFFF', font=mono(13), fill='#333')
    d.rectangle([706, 130, 720, 144], fill='#FFFFFF', outline='#7A7A7A', width=1)
    d.line([709, 137, 712, 141], fill='#1E5FCC', width=2)
    d.line([712, 141, 718, 133], fill='#1E5FCC', width=2)
    d.rectangle([786, 130, 800, 144], fill='#FFFFFF', outline='#7A7A7A', width=1)

    ui_check(d, 24, 316, 'Program/Configure', True)
    ui_check(d, 190, 316, 'Verify', False)
    ui_check(d, 300, 316, 'Blank-Check', False)
    ui_btn(d, 24, 356, 110, 30, 'Add File...', False)
    ui_btn(d, 146, 356, 110, 30, 'Change File...', False)
    ui_btn(d, 268, 356, 110, 30, 'Remove', False)
    ui_btn(d, 740, 356, 130, 34, 'Start', True)

    # 进度
    ui_text(d, (24, 410), 'Progress:', 14)
    d.rectangle([110, 406, 740, 430], fill='#FFFFFF', outline='#8C8C8C', width=1)
    d.rectangle([112, 408, 736, 428], fill='#2E7D32')
    d.text((418, 412), '100% (Successful)', font=f(13), fill='#FFFFFF', anchor='ma')
    ui_text(d, (24, 444), '下载耗时通常 1~3 秒；成功后板子立刻按新逻辑运行，断电再上电会丢（.sof 只存在 SRAM 里）。',
            13, fill=GRAY)
    img.save(os.path.join(OUT, 'ui_programmer.png'))
    print('ui_programmer.png')


if __name__ == '__main__':
    fig_c_vs_verilog()
    fig_quartus_flow()
    fig_cl_setting_flow()
    ui_new_project_wizard()
    ui_device_select()
    ui_compile_report()
    ui_pin_planner()
    ui_programmer()
    print('done ->', OUT)



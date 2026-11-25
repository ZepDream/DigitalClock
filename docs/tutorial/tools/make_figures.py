#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成教程用原理图 / 框图 / 时序图（只用 Pillow，不依赖 matplotlib）。

输出目录：docs/tutorial/images/
用法：python docs/tutorial/tools/make_figures.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', 'images'))
os.makedirs(OUT, exist_ok=True)

FONT = 'C:/Windows/Fonts/msyh.ttc'
FONT_B = 'C:/Windows/Fonts/msyhbd.ttc'

# 调色板：一类功能一个颜色
C_CLK = ('#E3F2FD', '#1565C0')
C_KEY = ('#FFF3E0', '#EF6C00')
C_CTL = ('#F3E5F5', '#6A1B9A')
C_DAT = ('#E8F5E9', '#2E7D32')
C_OUT = ('#ECEFF1', '#455A64')
INK = '#1A1A1A'
GRAY = '#8A8A8A'
LINE = '#37474F'
BG = '#FFFFFF'


def f(size, bold=False):
    return ImageFont.truetype(FONT_B if bold else FONT, size)


def canvas(w, h, bg=BG):
    img = Image.new('RGB', (w, h), bg)
    return img, ImageDraw.Draw(img)


def text(d, xy, s, size=22, bold=False, fill=INK, anchor='la'):
    d.text(xy, s, font=f(size, bold), fill=fill, anchor=anchor)


def box(d, x0, y0, x1, y1, s='', fill='#FFFFFF', outline=LINE, r=8,
        size=22, bold=False, width=2, sub='', sub_size=16, text_fill=INK):
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill,
                        outline=outline, width=width)
    cx = (x0 + x1) / 2
    if s and sub:
        d.text((cx, y0 + (y1 - y0) * 0.34), s, font=f(size, bold),
               fill=text_fill, anchor='mm')
        d.text((cx, y0 + (y1 - y0) * 0.72), sub, font=f(sub_size),
               fill=GRAY, anchor='mm')
    elif s:
        d.text((cx, (y0 + y1) / 2), s, font=f(size, bold), fill=text_fill, anchor='mm')


def arrow(d, p0, p1, color=LINE, width=3, head=12, dash=False):
    import math
    (x0, y0), (x1, y1) = p0, p1
    ang = math.atan2(y1 - y0, x1 - x0)
    bx, by = x1 - head * 0.9 * math.cos(ang), y1 - head * 0.9 * math.sin(ang)
    if dash:
        n = 16
        for i in range(n):
            if i % 2:
                continue
            d.line([x0 + (bx - x0) * i / n, y0 + (by - y0) * i / n,
                    x0 + (bx - x0) * (i + 1) / n, y0 + (by - y0) * (i + 1) / n],
                   fill=color, width=width)
    else:
        d.line([x0, y0, bx, by], fill=color, width=width)
    p = [(x1, y1),
         (x1 - head * math.cos(ang - 0.42), y1 - head * math.sin(ang - 0.42)),
         (x1 - head * math.cos(ang + 0.42), y1 - head * math.sin(ang + 0.42))]
    d.polygon(p, fill=color)


def elbow(d, pts, color=LINE, width=3, head=12):
    for i in range(len(pts) - 2):
        d.line([pts[i], pts[i + 1]], fill=color, width=width)
    arrow(d, pts[-2], pts[-1], color=color, width=width, head=head)


def wire_label(d, xy, s, size=16, fill='#00695C', anchor='la', bg=True):
    lines = s.split('\n')
    tw = max(d.textlength(ln, font=f(size)) for ln in lines)
    h = size + 6
    x, y = xy
    if anchor == 'ma':
        x -= tw / 2
    elif anchor == 'ra':
        x -= tw
    if bg:
        d.rectangle([x - 3, y - 2, x + tw + 3, y + h * len(lines) - 2], fill=BG)
    for i, ln in enumerate(lines):
        d.text((x, y + i * h), ln, font=f(size), fill=fill, anchor='la')


# ---------------------------------------------------------------- 时序图工具
def bits_row(d, x0, x1, y, h, spans, color='#1565C0'):
    """spans = [(f0, f1, 0|1), ...]，f 为 0~1 的比例。"""
    w = x1 - x0
    y_lo = y + h
    prev = None
    for (a, b, v) in spans:
        xa, xb = x0 + a * w, x0 + b * w
        yy = y if v else y_lo
        if prev is not None and prev != yy:
            d.line([xa, prev, xa, yy], fill=color, width=3)
        d.line([xa, yy, xb, yy], fill=color, width=3)
        prev = yy


def bus_row(d, x0, x1, y, h, spans, color='#6A1B9A', size=17):
    """spans = [(f0, f1, '0000'), ...]"""
    w = x1 - x0
    for (a, b, s) in spans:
        xa, xb = x0 + a * w, x0 + b * w
        d.line([xa, y, xb, y], fill=color, width=2)
        d.line([xa, y + h, xb, y + h], fill=color, width=2)
        for xx in (xa, xb):
            d.line([xx, y, xx, y + h], fill=color, width=2)
        d.text(((xa + xb) / 2, y + h / 2), s, font=f(size), fill=color, anchor='mm')


def time_axis(d, x0, x1, y, t0, t1, unit, step, size=16):
    d.line([x0, y, x1, y], fill=GRAY, width=2)
    n = int(round((t1 - t0) / step))
    for i in range(n + 1):
        t = t0 + i * step
        x = x0 + (t - t0) / (t1 - t0) * (x1 - x0)
        d.line([x, y, x, y + 8], fill=GRAY, width=2)
        d.text((x, y + 12), f'{t:g}', font=f(size), fill=GRAY, anchor='ma')
    d.text((x1 + 12, y - 6), unit, font=f(size), fill=GRAY)


def sig_label(d, x, y, s, size=19, fill=INK):
    d.text((x, y), s, font=f(size), fill=fill, anchor='rm')


# =============================================================== 图 1 系统框图
def fig_system():
    W, H = 1700, 1010
    img, d = canvas(W, H)
    text(d, (W / 2, 28), '图 电子时钟系统总框图（全系统只用 50 MHz 一个时钟）', 26, True, anchor='ma')

    # ---- A 列：外部输入
    box(d, 40, 120, 290, 200, '50 MHz 晶振', fill=C_CLK[0], outline=C_CLK[1],
        sub='clk50（引脚 M15）', size=21, bold=True)
    box(d, 40, 250, 290, 340, '上电复位 + K1', fill=C_CLK[0], outline=C_CLK[1],
        sub='20 ms 延时 + 消抖', size=21, bold=True)
    box(d, 40, 400, 290, 490, '核心板 K1~K4', fill=C_KEY[0], outline=C_KEY[1],
        sub='key_core_n[3:0]（低有效）', size=20, bold=True)
    box(d, 40, 540, 290, 660, '模式 9 键 1~8', fill=C_KEY[0], outline=C_KEY[1],
        sub='PI[15:0] → 键1~4\nPIO[15:0] → 键5~8', size=20, bold=True)

    # ---- B 列：分频 / 按键
    box(d, 360, 110, 620, 220, 'clk_gen', fill=C_CLK[0], outline=C_CLK[1],
        sub='50 MHz → 4 个 tick 使能', size=23, bold=True)
    box(d, 360, 390, 620, 500, 'key_input', fill=C_KEY[0], outline=C_KEY[1],
        sub='同步 + 20 ms 消抖 + 变化检测', size=22, bold=True)
    box(d, 360, 540, 620, 650, 'key_ctrl', fill=C_CTL[0], outline=C_CTL[1],
        sub='模式状态机 / 设置状态机', size=23, bold=True)

    # ---- C 列：数据通路
    items = [('time_counter', '正式时钟 + 编辑缓冲'), ('alarm_ctrl', '闹钟设置 / 比较 / 触发'),
             ('stopwatch', '秒表 10 ms 分辨率'), ('countdown', '倒计时 HH:MM:SS')]
    dy = [110, 250, 390, 530]
    for (name, sub), y0 in zip(items, dy):
        box(d, 700, y0, 1030, y0 + 110, name, fill=C_DAT[0], outline=C_DAT[1],
            size=22, bold=True, sub=sub)

    # ---- D 列：显示与声音
    box(d, 1105, 110, 1400, 350, 'display_ctrl', fill=C_OUT[0], outline=C_OUT[1],
        size=23, bold=True)
    text(d, (1252, 172), '8 位扫描 / 模式标识 / 2 Hz 闪烁', 15, fill=GRAY, anchor='ma')
    box(d, 1120, 250, 1385, 335, 'seg_decode', fill='#FFFFFF', outline=C_OUT[1],
        size=19, sub='4 位字符码 → 七段码', sub_size=14)
    box(d, 1150, 400, 1400, 510, 'beep_ctrl', fill=C_OUT[0], outline=C_OUT[1],
        size=23, bold=True, sub='3 下×2 组 / 2 下×1 组', sub_size=15)
    box(d, 1150, 700, 1400, 810, 'buzzer_tone', fill=C_OUT[0], outline=C_OUT[1],
        size=23, bold=True, sub='2.7 kHz 方波（低有效）', sub_size=15)

    # ---- E 列：板上器件
    box(d, 1465, 120, 1660, 200, '8 位数码管', fill='#FFFFFF', outline=C_OUT[1], size=20, bold=True)
    box(d, 1465, 250, 1660, 320, 'LED1~4', fill='#FFFFFF', outline=C_OUT[1], size=20, bold=True)
    box(d, 1465, 730, 1660, 800, '蜂鸣器 T13', fill='#FFFFFF', outline=C_OUT[1], size=20, bold=True)

    # ---- 连线：输入 → 处理
    arrow(d, (290, 160), (355, 160), color=C_CLK[1])
    elbow(d, [(290, 295), (325, 295), (325, 690)], color=C_CLK[1], width=2, head=1)
    wire_label(d, (330, 700), 'sys_rst_n 送到所有模块（图中省略连线）', 15, '#1565C0')
    arrow(d, (290, 445), (355, 445), color=C_KEY[1])
    arrow(d, (290, 600), (355, 600), color=C_KEY[1])
    arrow(d, (490, 500), (490, 535), color=C_KEY[1])
    wire_label(d, (500, 505), 'key_press[7:0]\ncore_press[3:0]', 14)

    # ---- tick 分发：clk_gen 上方走一条“使能总线”
    elbow(d, [(620, 165), (680, 165), (680, 80), (1030, 80)],
          color=C_CLK[1], width=3, head=1)
    for y0 in dy:
        arrow(d, (745, 80), (745, y0 - 3), color=C_CLK[1], width=2, head=9)
    wire_label(d, (800, 84), 'tick_1hz / tick_100hz / tick_1khz / tick_2hz（宽 1 个时钟周期的使能）',
               15, '#1565C0')

    # ---- 控制线：key_ctrl → 4 个数据模块
    elbow(d, [(620, 595), (660, 595), (660, 170), (695, 170)],
          color=C_CTL[1], width=3, head=10)
    for y in [305, 445, 585]:
        arrow(d, (660, y), (695, y), color=C_CTL[1], width=3)
    wire_label(d, (360, 692),
               '控制线（紫）：mode / setting / cursor\n'
               'edit_load / edit_commit / digit_inc / digit_dec / 各模块动作脉冲',
               15, '#6A1B9A')

    # ---- 数据 → 显示
    d.line([1030, 165, 1060, 165], fill=C_DAT[1], width=3)
    for y in [305, 445, 585]:
        d.line([1030, y, 1060, y], fill=C_DAT[1], width=3)
    d.line([1060, 165, 1060, 585], fill=C_DAT[1], width=3)
    arrow(d, (1060, 200), (1100, 200), color=C_DAT[1])
    wire_label(d, (700, 658), '绿线：各模块的 BCD 数值 / 运行标志', 14, '#2E7D32')

    # ---- 显示 → 数码管 / LED
    arrow(d, (1400, 150), (1460, 150), color=C_OUT[1])
    wire_label(d, (1404, 122), 'seg_n[7:0]', 15)
    arrow(d, (1400, 285), (1460, 285), color=C_OUT[1])
    wire_label(d, (1404, 257), 'led_n[3:0]', 15)

    # ---- 数据 → 蜂鸣器
    elbow(d, [(1060, 585), (1100, 585), (1100, 455), (1145, 455)],
          color='#C62828', width=3, head=10)
    wire_label(d, (1035, 665), 'alarm_trigger / cd_expire_pulse', 13, '#C62828')
    arrow(d, (1275, 510), (1275, 695), color=C_OUT[1])
    wire_label(d, (1285, 590), 'beep_en', 14)
    arrow(d, (1400, 755), (1460, 755), color=C_OUT[1])
    wire_label(d, (1404, 727), 'buzzer', 15)

    # ---- 图例
    legend = [(C_CLK, '时钟/复位'), (C_KEY, '按键'), (C_CTL, '控制'),
              (C_DAT, '数据通路'), (C_OUT, '显示/声音')]
    x = 60
    for c, s in legend:
        d.rounded_rectangle([x, 890, x + 34, 924], radius=6, fill=c[0], outline=c[1], width=2)
        text(d, (x + 44, 898), s, 19)
        x += 44 + int(d.textlength(s, font=f(19))) + 54
    text(d, (60, 940), '读图方法：先看 A 列输入从哪来 → B 列怎么处理 → C 列算出数值 → D 列怎么显示/发声。',
         19, fill=GRAY)
    text(d, (60, 972), '每个模块的 rst_n 都接 sys_rst_n；每个模块的时钟都接 clk50，没有任何模块拿 tick 当时钟。',
         19, fill=GRAY)

    img.save(os.path.join(OUT, 'fig_system_block.png'))
    print('fig_system_block.png')


# ========================================================== 图 2 模块层次树
def fig_tree():
    W, H = 1700, 830
    img, d = canvas(W, H)
    text(d, (W / 2, 28), '图 模块层次：谁例化了谁（小字为实例个数）', 26, True, anchor='ma')

    box(d, 650, 90, 1050, 170, 'digital_clock_top（顶层）', fill=C_CTL[0], outline=C_CTL[1],
        size=24, bold=True)

    lvl2 = [('clk_gen', C_CLK), ('key_input', C_KEY), ('key_ctrl', C_CTL),
            ('time_counter', C_DAT), ('alarm_ctrl', C_DAT), ('stopwatch', C_DAT),
            ('countdown', C_DAT), ('beep_ctrl', C_OUT), ('buzzer_tone', C_OUT),
            ('display_ctrl', C_OUT)]
    n = len(lvl2)
    margin, gap = 50, 8
    bw = (W - 2 * margin - gap * (n - 1)) / n
    y = 300
    xs = []
    for i in range(n):
        x0 = margin + i * (bw + gap)
        xs.append((x0 + bw / 2, x0, x0 + bw))
    d.line([850, 170, 850, 240], fill=GRAY, width=2)
    d.line([xs[0][0], 240, xs[-1][0], 240], fill=GRAY, width=2)
    for i in range(n):
        d.line([xs[i][0], 240, xs[i][0], y], fill=GRAY, width=2)

    for i, (name, c) in enumerate(lvl2):
        cx, x0, x1 = xs[i]
        box(d, x0, y, x1, y + 90, name, fill=c[0], outline=c[1], size=16, bold=True)

    lvl3 = {'key_input': [('nibble_key', '8 个')],
            'time_counter': [('bcd_digit_adj', '2 个')],
            'alarm_ctrl': [('bcd_digit_adj', '2 个')],
            'countdown': [('bcd_digit_adj', '2 个')],
            'display_ctrl': [('seg_decode', '1 个')]}
    for i, (name, c) in enumerate(lvl2):
        if name not in lvl3:
            continue
        cx, x0, x1 = xs[i]
        d.line([cx, y + 90, cx, 480], fill=GRAY, width=2)
        cy = 480
        for j, (sub, cnt) in enumerate(lvl3[name]):
            bw2 = 150
            sx0 = cx - bw2 / 2
            box(d, sx0, cy, sx0 + bw2, cy + 80, sub, fill='#FFFFFF', outline=c[1],
                size=15, sub='实例 ' + cnt, sub_size=14)
            cy += 100

    text(d, (50, 700), '顶层只做三件事：声明引脚、把线连起来、例化子模块，它自己不写业务逻辑。',
         22, fill=GRAY)
    text(d, (50, 740), '例化 = 在“图纸”上放一个芯片，再把它的引脚用 wire 连起来；作用相当于 C 语言里调用一个函数。',
         22, fill=GRAY)
    text(d, (50, 780), '同一个模块可以例化多次（nibble_key 用了 8 次），每次用不同的实例名，就像同一个函数被调用 8 次。',
         22, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_module_tree.png'))
    print('fig_module_tree.png')


# ============================================================ 图 3 tick 时序
def fig_tick():
    W, H = 1700, 780
    img, d = canvas(W, H)
    text(d, (W / 2, 26), '图 50 MHz 与 4 个单周期使能（tick）的关系', 26, True, anchor='ma')

    x0, x1 = 250, 1450

    # clk50 方波
    y, h = 100, 44
    n = 40
    w = (x1 - x0) / n
    sig_label(d, x0 - 15, y + h / 2, 'clk50（50 MHz）', size=19)
    for i in range(n):
        xa = x0 + i * w
        d.line([xa, y + h, xa + w / 2, y + h], fill='#1565C0', width=2)
        d.line([xa + w / 2, y, xa + w, y], fill='#1565C0', width=2)
        d.line([xa + w / 2, y, xa + w / 2, y + h], fill='#1565C0', width=2)
        d.line([xa, y + h, xa, y], fill='#1565C0', width=2)

    rows = [
        ('tick_1khz（每 1 ms）', 190, [(0.06 + k * 0.25, 0.0625 + k * 0.25) for k in range(4)]),
        ('tick_100hz（每 10 ms）', 300, [(0.06, 0.0625), (0.56, 0.5625)]),
        ('tick_2hz（每 250 ms）', 410, [(0.28, 0.2825)]),
        ('tick_1hz（每 1 s）', 520, [(0.52, 0.5225)]),
    ]
    for name, yy, pulses in rows:
        hh = 40
        sig_label(d, x0 - 15, yy + hh / 2, name, size=19)
        d.line([x0, yy + hh, x1, yy + hh], fill='#90A4AE', width=2)
        for (a, b) in pulses:
            xa, xb = x0 + a * (x1 - x0), x0 + b * (x1 - x0)
            d.rectangle([xa, yy, xb, yy + hh], fill='#2E7D32')
        d.text((x1 + 12, yy + hh / 2), '宽 1 个时钟周期', font=f(14), fill=GRAY, anchor='lm')

    # 放大示意
    d.rectangle([x0 + 0.20 * (x1 - x0), 175, x0 + 0.26 * (x1 - x0), 245],
                outline='#C62828', width=2)
    d.line([x0 + 0.26 * (x1 - x0), 210, x0 + 0.33 * (x1 - x0), 210], fill='#C62828', width=2)
    text(d, (x0 + 0.34 * (x1 - x0), 196), '放大后：高电平只有 20 ns，', 17, fill='#C62828')
    text(d, (x0 + 0.34 * (x1 - x0), 220), '然后立刻回到 0', 17, fill='#C62828')

    text(d, (60, 630), '要点：tick 不是时钟。所有 always 仍然写 @(posedge clk50)，只在 if (tick_1hz) 里做每秒一次的动作。',
         21, fill=GRAY)
    text(d, (60, 670), '为什么不直接拿 1 Hz 当时钟？因为那会引入“门控/分频时钟”，时序分析变复杂，还多一个时钟域。',
         21, fill=GRAY)
    text(d, (60, 710), '计数器终值：1 Hz → 50 000 000；100 Hz → 500 000；1 kHz → 50 000；2 Hz → 12 500 000。',
         21, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_tick_timing.png'))
    print('fig_tick_timing.png')


# =========================================================== 图 4 按键消抖
def fig_key_debounce():
    W, H = 1700, 780
    img, d = canvas(W, H)
    text(d, (W / 2, 26), '图 模式 9 按键：抖动 → 连续 20 ms 不变 → press 输出一个脉冲', 25, True, anchor='ma')

    x0, x1 = 260, 1640
    r1, r2, r3, r4 = 170, 310, 450, 580
    sig_label(d, x0 - 15, r1 + 20, 'nibble_in[3:0]', size=19)
    sig_label(d, x0 - 15, r2 + 20, 'sync1（同步后）', size=19)
    sig_label(d, x0 - 15, r3 + 20, 'prev（已确认）', size=19)
    sig_label(d, x0 - 15, r4 + 20, 'press（输出脉冲）', size=19)

    bus_row(d, x0, x1, r1, 40, [(0, 0.16, '0000'), (0.16, 0.21, '0001'),
                                (0.21, 0.245, '0000'), (0.245, 0.30, '0001'),
                                (0.30, 1.0, '0001')], color='#EF6C00')
    bits_row(d, x0, x1, r2, 40, [(0, 0.16, 0), (0.16, 0.21, 1), (0.21, 0.245, 0),
                                 (0.245, 1.0, 1)], color='#EF6C00')
    bits_row(d, x0, x1, r3, 40, [(0, 0.52, 0), (0.52, 1.0, 1)], color='#2E7D32')
    bits_row(d, x0, x1, r4, 40, [(0, 0.52, 0), (0.52, 0.525, 1), (0.525, 1, 0)], color='#C62828')

    # 抖动区间标注（放在第一行上方）
    a, b = 0.16, 0.30
    xa, xb = x0 + a * (x1 - x0), x0 + b * (x1 - x0)
    d.line([xa, 130, xb, 130], fill='#C62828', width=3)
    d.line([xa, 130, xa, 150], fill='#C62828', width=2)
    d.line([xb, 130, xb, 150], fill='#C62828', width=2)
    text(d, ((xa + xb) / 2, 100), '这段值在变，计数器反复清零', 17, fill='#C62828', anchor='ma')

    # 稳定区间标注（放在第一行与第二行之间）
    a, b = 0.30, 0.52
    xa, xb = x0 + a * (x1 - x0), x0 + b * (x1 - x0)
    d.line([xa, 235, xb, 235], fill='#2E7D32', width=3)
    d.line([xa, 235, xa, 255], fill='#2E7D32', width=2)
    d.line([xb, 235, xb, 225], fill='#2E7D32', width=2)
    text(d, ((xa + xb) / 2, 242), '连续 20 ms 都是 0001 → 认定一次有效按下', 17, fill='#2E7D32', anchor='ma')

    # press 标注
    xp = x0 + 0.52 * (x1 - x0)
    d.line([xp, r4 + 45, xp, 660], fill='#C62828', width=2)
    text(d, (xp + 12, 700), 'press 只高 1 个时钟周期（20 ns），下游看到一次“按下”事件', 18, fill='#C62828')

    text(d, (60, 740), '为什么必须消抖：机械按键一次按下会产生几十次跳变，不消抖就会“按 1 次加好几下”。',
         20, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_key_debounce.png'))
    print('fig_key_debounce.png')


# =========================================================== 图 5 数码管扫描
def fig_scan():
    W, H = 1700, 780
    img, d = canvas(W, H)
    text(d, (W / 2, 26), '图 8 位数码管动态扫描：每 1 ms 只亮一位，8 ms 扫描一圈', 25, True, anchor='ma')

    x0, x1 = 260, 1600
    y, h = 110, 60
    step = (x1 - x0) / 8
    names = ['数码8', '数码7', '数码6', '数码5', '数码4', '数码3', '数码2', '数码1']
    chars = ['"C"', '"L"', '十时', '个时', '十分', '个分', '十秒', '个秒']

    for i in range(8):
        xa = x0 + i * step
        d.rectangle([xa + 3, y, xa + step - 6, y + h], fill='#E8F5E9', outline='#2E7D32', width=2)
        d.text((xa + 3 + (step - 9) / 2, y + h / 2), names[i], font=f(17), fill='#2E7D32', anchor='mm')
        d.text((xa + 3 + (step - 9) / 2, y + h + 30), f'dig_n[{7 - i}]=0', font=f(15), fill=INK, anchor='mm')
        d.text((xa + 3 + (step - 9) / 2, y + h + 54), '其余 7 位 = 1', font=f(14), fill=GRAY, anchor='mm')
    sig_label(d, x0 - 15, y + 30, '这一位亮', size=19)
    sig_label(d, x0 - 15, y + h + 30, '位选（低有效）', size=17)

    y2 = 400
    sig_label(d, x0 - 15, y2 + 25, 'seg_n[7:0]', size=19)
    for i in range(8):
        xa = x0 + i * step
        d.rectangle([xa + 3, y2, xa + step - 6, y2 + 50], fill='#FFF3E0', outline='#EF6C00', width=2)
        d.text((xa + 3 + (step - 9) / 2, y2 + 25), chars[i], font=f(16), fill='#EF6C00', anchor='mm')

    time_axis(d, x0, x1, 540, 0, 8, 'ms', 1)

    sig_label(d, x0 - 15, 660, 'scan_idx', size=19)
    for i in range(8):
        xa = x0 + i * step
        d.text((xa + 3 + (step - 9) / 2, 660), f'{i}', font=f(20), bold=True, fill='#6A1B9A', anchor='mm')

    text(d, (60, 715), '人眼有视觉暂留：8 位轮流亮、每 1 ms 换一位，看起来就是 8 位同时亮。', 20, fill=GRAY)
    text(d, (60, 748), '扫描由 tick_1khz 驱动，所以扫描频率永远是 1 kHz，和数码管内容完全无关。', 20, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_scan_timing.png'))
    print('fig_scan_timing.png')


# ========================================================== 图 6 显示布局
def fig_display_layout():
    W, H = 1520, 800
    img, d = canvas(W, H)
    text(d, (W / 2, 26), '图 8 位数码管的显示布局与 disp / 位选 / 光标的对应关系', 25, True, anchor='ma')

    x0 = 70
    dw, dh, gap = 150, 170, 16
    names = ['数码8', '数码7', '数码6', '数码5', '数码4', '数码3', '数码2', '数码1']
    chars = ['C', 'L', '0', '0', '0', '0', '0', '0']
    dps = [False, False, False, True, False, True, False, False]
    for i in range(8):
        xa = x0 + i * (dw + gap)
        d.rounded_rectangle([xa, 90, xa + dw, 90 + dh], radius=10, fill='#FAFAFA',
                            outline='#455A64', width=3)
        d.text((xa + dw / 2, 150), chars[i], font=f(72, True), fill='#E53935', anchor='mm')
        if dps[i]:
            d.ellipse([xa + dw - 36, 200, xa + dw - 14, 222], fill='#E53935')
        text(d, (xa + dw / 2, 272), names[i], 18, bold=True, anchor='ma')
        text(d, (xa + dw / 2, 298), f'disp[{(7 - i) * 4 + 3}:{(7 - i) * 4}]', 14, fill=GRAY, anchor='ma')
        text(d, (xa + dw / 2, 320), f'dig_n[{7 - i}]', 14, fill='#1565C0', anchor='ma')

    rows = [('CL 时钟', 'C   L   时十  时个  分十  分个  秒十  秒个', '#2E7D32'),
            ('AL 闹钟', 'A   L   时十  时个  分十  分个  秒十  秒个', '#EF6C00'),
            ('St 秒表', 'S   t   分十  分个  秒十  秒个  厘十  厘个', '#6A1B9A'),
            ('Cd 倒计时', 'C   d   时十  时个  分十  分个  秒十  秒个', '#1565C0')]
    y = 375
    for (name, s, c) in rows:
        d.rectangle([x0, y, x0 + 26, y + 32], fill=c)
        text(d, (x0 + 36, y + 4), name, 19, bold=True, fill=c)
        text(d, (x0 + 170, y + 4), s, 19)
        y += 45

    text(d, (x0, 585), '设置时光标 cursor 与数码位的对应（键 3 右移 / 键 4 左移，0~5 循环）：', 19, bold=True)
    cur = ['cursor=0 → 数码6（时十）', 'cursor=1 → 数码5（时个）', 'cursor=2 → 数码4（分十）',
           'cursor=3 → 数码3（分个）', 'cursor=4 → 数码2（秒十）', 'cursor=5 → 数码1（秒个）']
    for i, s in enumerate(cur):
        text(d, (x0 + 40 + (i % 3) * 460, 625 + (i // 3) * 34), s, 17)
    text(d, (x0, 725), '被选中的那一位在闪烁的“灭”相里不亮，就成了光标；这样不用额外的光标引脚。', 17, fill=GRAY)
    text(d, (x0, 755), '小数点：数码5（disp[19]）和数码3（disp[11]）固定带点，用来分隔 时:分:秒 和 分:秒:厘秒。', 17, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_display_layout.png'))
    print('fig_display_layout.png')


# ========================================================== 图 7 模式状态机
def fig_mode_fsm():
    W, H = 1440, 800
    img, d = canvas(W, H)
    text(d, (W / 2, 26), '图 4 个模式的切换关系（键 8 每按一次换一个模式）', 25, True, anchor='ma')

    boxes = [('CL 时钟', '显示 HH:MM:SS', 300, 140, C_DAT),
             ('AL 闹钟', '显示 HH:MM:SS', 870, 140, C_KEY),
             ('Cd 倒计时', '显示 HH:MM:SS', 870, 450, C_CLK),
             ('St 秒表', '显示 MM:SS:CC', 300, 450, C_CTL)]
    for (s, sub, x, y, c) in boxes:
        box(d, x, y, x + 280, y + 130, s, fill=c[0], outline=c[1], size=24, bold=True,
            sub=sub, sub_size=17)

    arrow(d, (585, 205), (865, 205), color=LINE)
    text(d, (725, 175), '键8', 20, bold=True, anchor='ma')
    arrow(d, (1010, 275), (1010, 445), color=LINE)
    text(d, (1022, 355), '键8', 20, bold=True)
    arrow(d, (865, 515), (585, 515), color=LINE)
    text(d, (725, 485), '键8', 20, bold=True, anchor='ma')
    arrow(d, (440, 445), (440, 275), color=LINE)
    text(d, (452, 355), '键8', 20, bold=True)

    y = 660
    text(d, (90, y - 44), '每个模式内部还有“正常显示”和“设置”两个子状态：', 20, bold=True)
    box(d, 90, y, 380, y + 66, '正常显示', fill='#FFFFFF', outline=LINE, size=21)
    box(d, 620, y, 910, y + 66, '设置（被选中的位闪烁）', fill='#FFFDE7', outline='#F9A825', size=19)
    arrow(d, (382, y + 22), (616, y + 22), color=LINE)
    text(d, (495, y - 20), '键7 或 K4：进入设置', 16, anchor='ma')
    arrow(d, (616, y + 48), (382, y + 48), color=LINE)
    text(d, (495, y + 74), '键7/K4：确认写回；键8：取消', 16, anchor='ma')
    text(d, (960, y + 10), 'CL / AL / Cd 可以进入设置；\nSt 秒表没有设置，只有启动/暂停/清零。', 17, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_mode_fsm.png'))
    print('fig_mode_fsm.png')


# ========================================================== 图 8 七段码
def fig_seg():
    W, H = 1240, 660
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 七段数码管的段名、seg_n 位序与对应关系', 25, True, anchor='ma')

    cx, cy = 250, 350
    w, h, t = 140, 220, 28
    col = '#E53935'
    d.rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy - h / 2 + t], fill=col)
    d.rectangle([cx + w / 2 - t, cy - h / 2, cx + w / 2, cy], fill=col)
    d.rectangle([cx + w / 2 - t, cy, cx + w / 2, cy + h / 2], fill=col)
    d.rectangle([cx - w / 2, cy + h / 2 - t, cx + w / 2, cy + h / 2], fill=col)
    d.rectangle([cx - w / 2, cy, cx - w / 2 + t, cy + h / 2], fill=col)
    d.rectangle([cx - w / 2, cy - h / 2, cx - w / 2 + t, cy], fill=col)
    d.rectangle([cx - w / 2, cy - t / 2, cx + w / 2, cy + t / 2], fill=col)
    d.ellipse([cx + w / 2 + 34, cy + h / 2 - 40, cx + w / 2 + 64, cy + h / 2 - 10], fill=col)
    text(d, (cx, cy - h / 2 - 42), 'a', 26, bold=True, anchor='ma')
    text(d, (cx + w / 2 + 22, cy - h / 4), 'b', 26, bold=True)
    text(d, (cx + w / 2 + 22, cy + h / 4), 'c', 26, bold=True)
    text(d, (cx, cy + h / 2 + 16), 'd', 26, bold=True, anchor='ma')
    text(d, (cx - w / 2 - 44, cy + h / 4), 'e', 26, bold=True)
    text(d, (cx - w / 2 - 44, cy - h / 4), 'f', 26, bold=True)
    text(d, (cx - w / 2 - 44, cy - 14), 'g', 26, bold=True)
    text(d, (cx + w / 2 + 74, cy + h / 2 - 44), 'dp', 22, bold=True)

    x = 600
    text(d, (x, 90), 'seg_n[7:0] 的位序（高位在左）：', 21, bold=True)
    bits = [('seg_n[7]', 'g'), ('seg_n[6]', 'f'), ('seg_n[5]', 'e'), ('seg_n[4]', 'd'),
            ('seg_n[3]', 'c'), ('seg_n[2]', 'b'), ('seg_n[1]', 'a'), ('seg_n[0]', 'dp')]
    for i, (b, s) in enumerate(bits):
        y = 140 + i * 42
        d.rounded_rectangle([x, y, x + 150, y + 34], radius=6, fill='#ECEFF1',
                            outline='#455A64', width=2)
        d.text((x + 75, y + 17), b, font=f(17, True), fill=INK, anchor='mm')
        d.text((x + 168, y + 17), f'→ 段 {s}', font=f(17), fill='#1565C0', anchor='lm')

    text(d, (x, 490), '低有效：写 0 点亮，写 1 熄灭。', 20, bold=True, fill='#C62828')
    text(d, (x, 522), '例：显示 “0” → a,b,c,d,e,f 亮、g 灭、dp 灭', 17)
    text(d, (x, 550), "→ seg_n = 1000_0001 = 8'h81（见 seg_decode.v）", 17, fill='#2E7D32')

    text(d, (60, 540), '为什么低有效？', 19, bold=True)
    text(d, (60, 568), '实验箱数码管共阳接法，', 16, fill=GRAY)
    text(d, (60, 592), '段选引脚拉低才导通发光。', 16, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_seg_map.png'))
    print('fig_seg_map.png')


# ========================================================== 图 9 仿真流程
def fig_sim_flow():
    W, H = 1440, 940
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 ModelSim 仿真的 6 步流程（每一步对应一条命令）', 25, True, anchor='ma')

    steps = [
        ('① 写 RTL 与 testbench', 'rtl/*.v + sim/tb_digital_clock_top.v', C_DAT, '#2E7D32'),
        ('② 建库 vlib work', '在当前目录创建 work 库', C_CLK, '#1565C0'),
        ('③ 编译 vlog', 'vlog ../rtl/*.v  →  vlog tb_digital_clock_top.v', C_CLK, '#1565C0'),
        ('④ 加载 vsim', 'vsim work.tb_digital_clock_top', C_CTL, '#6A1B9A'),
        ('⑤ 加波形 + 运行', 'add wave ...  →  run -all', C_CTL, '#6A1B9A'),
        ('⑥ 看波形 / 看 PASS', '缩放、量周期、数 Transcript 里的 PASS 和 ERROR', C_OUT, '#455A64'),
    ]
    y = 90
    for i, (t1, t2, c, col) in enumerate(steps):
        box(d, 300, y, 1080, y + 90, t1, fill=c[0], outline=c[1], size=23, bold=True,
            sub=t2, sub_size=17)
        if i < len(steps) - 1:
            arrow(d, (690, y + 92), (690, y + 120), color=LINE, width=3)
        y += 120

    # 失败回路
    d.line([1080, 660, 1180, 660], fill='#C62828', width=3)
    d.line([1180, 660, 1180, 135], fill='#C62828', width=3)
    arrow(d, (1180, 135), (1085, 135), color='#C62828')
    d.text((1196, 380), '出现 ERROR？', font=f(20, True), fill='#C62828')
    d.text((1196, 412), '回 ① 改代码，', font=f(17), fill='#C62828')
    d.text((1196, 438), '再 ②③④⑤', font=f(17), fill='#C62828')

    text(d, (60, 830), '注意：vlib / vlog / vsim 都必须在 sim 目录下执行；work 库删掉后要重新 vlib + vlog。', 19, fill=GRAY)
    text(d, (60, 866), '一键脚本：sim/run_sim.bat（命令行）或 ModelSim 里 do run_sim.do（图形界面）。', 19, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_sim_flow.png'))
    print('fig_sim_flow.png')


# ========================================================== 图 10 蜂鸣器节奏
def fig_beep():
    W, H = 1560, 600
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 闹钟提示音：3 下 + 停 0.6 s + 3 下（每下 150 ms 响 / 150 ms 停）', 23, True, anchor='ma')

    x0, x1 = 250, 1450
    y, h = 130, 70
    total = 2400.0
    sig_label(d, x0 - 15, y + h / 2, 'beep_en', size=21)

    spans = [(0, 400, 0)]
    t = 0
    for k in range(3):
        spans += [(t, t + 150, 1), (t + 150, t + 300, 0)]
        t += 300
    spans += [(t, t + 600, 0)]
    t += 600
    for k in range(3):
        spans += [(t, t + 150, 1), (t + 150, t + 300, 0)]
        t += 300
    spans += [(t, total, 0)]

    prev = None
    for (a, b, v) in spans:
        xa, xb = x0 + a / total * (x1 - x0), x0 + b / total * (x1 - x0)
        yy = y if v else y + h
        if prev is not None and prev != yy:
            d.line([xa, prev, xa, yy], fill='#2E7D32', width=4)
        d.line([xa, yy, xb, yy], fill='#2E7D32', width=4)
        prev = yy

    for k in range(3):
        xa = x0 + (k * 300 + 75) / total * (x1 - x0)
        d.text((xa, y - 24), f'第{k + 1}下', font=f(17), fill='#2E7D32', anchor='ma')
    for k in range(3):
        xa = x0 + (1500 + k * 300 + 75) / total * (x1 - x0)
        d.text((xa, y - 24), f'第{k + 4}下', font=f(17), fill='#2E7D32', anchor='ma')
    d.text((x0 + 1200 / total * (x1 - x0), y + h + 42), '停 600 ms，换第二组', font=f(17),
           fill='#EF6C00', anchor='ma')

    time_axis(d, x0, x1, 330, 0, 2400, 'ms', 300)
    text(d, (60, 470), '倒计时到 0 时只有 2 下 × 1 组（200 ms 响 / 200 ms 停），节奏参数在 beep_ctrl.v 里。',
         19, fill=GRAY)
    text(d, (60, 506), 'beep_en 只表示“响不响”；真正 2.7 kHz 的方波由 buzzer_tone 产生，两者分开写才方便调试。',
         19, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_beep_timing.png'))
    print('fig_beep_timing.png')


# ========================================================== 图 11 BCD 进位链
def fig_bcd():
    W, H = 1560, 520
    img, d = canvas(W, H)
    text(d, (W / 2, 24), '图 24 位 BCD 时间 = 6 个 4 位十进制数，进位从秒个位往时十位走', 23, True, anchor='ma')

    names = [('时十', 'ht', '0~2'), ('时个', 'ho', '0~9'), ('分十', 'mt', '0~5'),
             ('分个', 'mo', '0~9'), ('秒十', 'st', '0~5'), ('秒个', 'so', '0~9')]
    x, y = 100, 110
    for i, (cn, en, rng) in enumerate(names):
        d.rounded_rectangle([x, y, x + 170, y + 150], radius=10, fill=C_DAT[0],
                            outline=C_DAT[1], width=3)
        d.text((x + 85, y + 40), cn, font=f(26, True), fill=INK, anchor='mm')
        d.text((x + 85, y + 78), en, font=f(20), fill='#2E7D32', anchor='mm')
        d.text((x + 85, y + 112), rng, font=f(18), fill=GRAY, anchor='mm')
        d.text((x + 85, y + 176), f'[{23 - i * 4}:{20 - i * 4}]', font=f(16), fill=GRAY, anchor='mm')
        if i < 5:
            arrow(d, (x + 172, y + 75), (x + 198, y + 75), color='#EF6C00', width=3, head=9)
            d.text((x + 185, y + 46), '进位', font=f(14), fill='#EF6C00', anchor='ma')
        x += 200

    text(d, (100, 330), '秒个位 9→0 时向秒十位进位；秒十位 5→0 向分个位进位；……时十位到 2、时个位到 3 之后 23:59:59 → 00:00:00。',
         18, fill=GRAY)
    text(d, (100, 368), '每个 nibble 只存 0~9 的 BCD 值，所以显示时不用做“二进制转十进制”，直接一位对一位送数码管。',
         18, fill=GRAY)
    text(d, (100, 406), '代价：加减法要写成“每一位单独判断、单独回绕”，代码比二进制长，但显示和调试更直观。',
         18, fill=GRAY)
    text(d, (100, 444), '这也是 time_counter.v 里 inc_time()、countdown.v 里 dec_time() 那么长的原因。',
         18, fill=GRAY)
    img.save(os.path.join(OUT, 'fig_bcd_chain.png'))
    print('fig_bcd_chain.png')


if __name__ == '__main__':
    fig_system()
    fig_tree()
    fig_tick()
    fig_key_debounce()
    fig_scan()
    fig_display_layout()
    fig_mode_fsm()
    fig_seg()
    fig_sim_flow()
    fig_beep()
    fig_bcd()
    print('done ->', OUT)




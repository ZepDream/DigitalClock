#!/usr/bin/env python3
"""Parse the ModelSim VCD and render simple waveform PNGs with Pillow."""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont

VCD = os.path.join(os.path.dirname(__file__), 'tb.vcd')


def parse_vcd(path):
    scopes = []
    # path -> {'width': n, 'bits': {idx: id}} or {'width': 1, 'id': id}
    signals = {}
    id_to_signal = {}

    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if line.startswith('$scope'):
                # $scope module name $end
                parts = line.split()
                scopes.append(parts[2])
            elif line.startswith('$upscope'):
                if scopes:
                    scopes.pop()
            elif line.startswith('$var'):
                # $var wire 1 ! clk $end
                parts = line.split()
                if len(parts) < 5:
                    continue
                width = int(parts[2])
                ident = parts[3]
                name = parts[4]
                if len(parts) > 5 and parts[5].startswith('['):
                    name = parts[4] + ' ' + parts[5]
                full = '.'.join(scopes + [name])
                m = re.match(r'^(.*?)\s*\[(\d+)\]$', name)
                m2 = re.match(r'^(.*?)\s*\[(\d+):(\d+)\]$', name)
                if m:
                    base = m.group(1)
                    idx = int(m.group(2))
                    full_base = '.'.join(scopes + [base])
                    sig = signals.setdefault(full_base, {'width': width, 'bits': {}})
                    sig['bits'][idx] = ident
                    id_to_signal.setdefault(ident, []).append(full_base)
                elif m2:
                    base = m2.group(1)
                    full_base = '.'.join(scopes + [base])
                    signals[full_base] = {'width': width, 'id': ident}
                    id_to_signal.setdefault(ident, []).append(full_base)
                else:
                    signals[full] = {'width': width, 'id': ident}
                    id_to_signal.setdefault(ident, []).append(full)
            elif line.startswith('$enddefinitions'):
                break

    # remove incomplete bus entries (if any)
    for k in list(signals):
        s = signals[k]
        if 'bits' in s and not s['bits']:
            del signals[k]

    # value changes
    values = {}
    changes = {k: [] for k in signals}
    t = 0
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        started = False
        for line in f:
            line = line.strip()
            if not started:
                if line.startswith('$enddefinitions'):
                    started = True
                continue
            if not line:
                continue
            if line.startswith('#'):
                t = int(line[1:])
            elif line.startswith('$'):
                continue
            elif line[0] in '01xXzZ':
                val = line[0]
                ident = line[1:]
                values[ident] = val
                for full in id_to_signal.get(ident, []):
                    sig = signals[full]
                    if 'bits' in sig:
                        bits = sig['bits']
                        # reconstruct, MSB first by index
                        maxidx = max(bits)
                        v = 0
                        unknown = False
                        for i in range(maxidx + 1):
                            b = values.get(bits.get(i, ''), 'x')
                            if b in 'xXzZ':
                                unknown = True
                            elif b == '1':
                                v |= (1 << i)
                        if not changes[full] or changes[full][-1][1] != (None if unknown else v):
                            if changes[full] and changes[full][-1][0] == t:
                                changes[full][-1] = (t, None if unknown else v, maxidx + 1)
                            else:
                                changes[full].append((t, None if unknown else v, maxidx + 1))
                    else:
                        if not changes[full] or changes[full][-1][1] != val:
                            if changes[full] and changes[full][-1][0] == t:
                                changes[full][-1] = (t, val, 1)
                            else:
                                changes[full].append((t, val, 1))
            elif line[0] in 'bB':
                parts = line.split()
                if len(parts) < 2:
                    continue
                bits = parts[0][1:]
                ident = parts[1]
                val = None if any(c in 'xXzZ' for c in bits) else int(bits, 2)
                for full in id_to_signal.get(ident, []):
                    sig = signals[full]
                    if 'bits' in sig:
                        continue
                    if not changes[full] or changes[full][-1][1] != val:
                        if changes[full] and changes[full][-1][0] == t:
                            changes[full][-1] = (t, val, len(bits))
                        else:
                            changes[full].append((t, val, len(bits)))
            elif line[0] in 'rR':
                continue
    return signals, changes


def signal_events(changes, path):
    return changes.get(path, [])


def find_edge(events, level='1'):
    for t, v, w in events:
        if v == level:
            return t
    return None


def choose_window(events, t_center, before, after):
    return max(0, t_center - before), t_center + after


def draw_wave(out_png, title, items, t0, t1, time_unit='us'):
    W, H = 1900, 110 + 56 * len(items)
    left, right, top = 330, 40, 70
    row_h = 56
    img = Image.new('RGB', (W, H), 'white')
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 18)
        font_b = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 22)
        font_s = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
    except Exception:
        font = ImageFont.load_default()
        font_b = font
        font_s = font

    d.text((20, 15), title, fill='black', font=font_b)
    d.text((left, 45), 'time (us)', fill='#444444', font=font_s)
    plot_w = W - left - right

    def x_of(t):
        return left + int((t - t0) * plot_w / max(1, (t1 - t0)))

    # grid，时间单位 us
    span_us = (t1 - t0) / 1_000_000.0
    step_us = 1.0
    for s in [0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100]:
        if span_us / s <= 12:
            step_us = s
            break
    step_ps = int(step_us * 1_000_000)
    t = (t0 // step_ps) * step_ps
    while t <= t1:
        x = x_of(t)
        d.line([(x, top - 10), (x, H - 35)], fill='#eeeeee')
        d.text((x - 20, H - 28), f'{t/1_000_000.0:.1f}', fill='#555555', font=font_s)
        t += step_ps

    # horizontal separators
    for i in range(len(items)):
        y = top + i * row_h
        d.line([(20, y + row_h - 1), (W - 20, y + row_h - 1)], fill='#dddddd')

    for i, (path, label, radix) in enumerate(items):
        y = top + i * row_h
        d.text((20, y + 14), label, fill='black', font=font)
        ev = changes.get(path, [])
        # value before t0
        cur = None
        for tt, vv, ww in ev:
            if tt <= t0:
                cur = (vv, ww)
            else:
                break
        if cur is None and ev:
            cur = (ev[0][1], ev[0][2])
        if not ev:
            d.text((left + 10, y + 14), 'no signal', fill='red', font=font_s)
            continue

        # build segments
        segs = []
        cur_t = t0
        cur_v = cur[0] if cur else None
        cur_w = cur[1] if cur else 1
        for tt, vv, ww in ev:
            if tt <= t0:
                continue
            if tt >= t1:
                break
            if tt > cur_t:
                segs.append((cur_t, tt, cur_v, cur_w))
            cur_t = tt
            cur_v = vv
            cur_w = ww
        segs.append((cur_t, t1, cur_v, cur_w))

        if cur_w == 1:
            yh, yl = y + 12, y + row_h - 14
            for a, b, v, w in segs:
                xa, xb = x_of(a), x_of(b)
                yy = yh if v == '1' else yl
                d.line([(xa, yy), (xb, yy)], fill='#2e7d32' if v == '1' else '#777777', width=3)
                if xa > left:
                    d.line([(xa, yh), (xa, yl)], fill='#333333', width=2)
            # last transition line
            last_t = segs[-1][1]
            d.line([(x_of(last_t), yh), (x_of(last_t), yl)], fill='#333333', width=2)
        else:
            yh, yl = y + 12, y + row_h - 14
            for a, b, v, w in segs:
                xa, xb = x_of(a), x_of(b)
                d.line([(xa, yh), (xb, yh)], fill='#1565c0', width=2)
                d.line([(xa, yl), (xb, yl)], fill='#1565c0', width=2)
                if xa > left:
                    d.line([(xa, yh), (xa, yl)], fill='#333333', width=2)
                txt = 'X' if v is None else (f'{v:0{(w+3)//4}X}' if radix == 'hex' else str(v))
                if radix == 'bcd24' and v is not None:
                    txt = (f'{(v>>20)&0xF}{(v>>16)&0xF}:'
                           f'{(v>>12)&0xF}{(v>>8)&0xF}:'
                           f'{(v>>4)&0xF}{v&0xF}')
                if xb - xa > 24:
                    tw = d.textlength(txt, font=font_s)
                    d.text(((xa + xb) / 2 - tw / 2, y + 18), txt, fill='#0d47a1', font=font_s)
            last_t = segs[-1][1]
            d.line([(x_of(last_t), yh), (x_of(last_t), yl)], fill='#333333', width=2)

    img.save(out_png)
    print('saved', out_png)


def main():
    global changes
    signals, changes = parse_vcd(VCD)

    out_dir = os.path.join(os.path.dirname(__file__), '..', 'images')
    os.makedirs(out_dir, exist_ok=True)

    p = 'tb_digital_clock_top.'
    d = p + 'dut.'

    draw_wave(os.path.join(out_dir, 'wave_time.png'),
              '1 Hz tick and 24-hour rollover',
              [(d + 'tick_1hz', 'tick_1hz', 'bin'),
               (d + 'time_bcd', 'time_bcd (HH:MM:SS)', 'bcd24'),
               (d + 'time_edit_bcd', 'time_edit_bcd', 'bcd24')],
              19_000_000, 42_000_000)

    draw_wave(os.path.join(out_dir, 'wave_cl_set.png'),
              'CL setting: key nibble -> edit -> commit',
              [(p + 'pi_in', 'pi_in (mode-9 keys)', 'hex'),
               (d + 'key_press', 'key_press', 'hex'),
               (d + 'setting', 'setting', 'bin'),
               (d + 'cursor', 'cursor', 'unsigned'),
               (d + 'time_bcd', 'time_bcd', 'bcd24'),
               (d + 'time_edit_bcd', 'time_edit_bcd', 'bcd24')],
              83_000_000, 118_000_000)

    draw_wave(os.path.join(out_dir, 'wave_alarm.png'),
              'Alarm: 3 beeps x 2 groups',
              [(d + 'alarm_en', 'alarm_en', 'bin'),
               (d + 'alarm_trigger', 'alarm_trigger', 'bin'),
               (d + 'beep_en', 'beep_en', 'bin'),
               (d + 'u_beep_ctrl.beep_cnt', 'beep_cnt', 'unsigned'),
               (d + 'time_bcd', 'time_bcd', 'bcd24')],
              138_000_000, 322_000_000)

    draw_wave(os.path.join(out_dir, 'wave_countdown.png'),
              'Countdown: 1 -> 0, 2 beeps x 1 group',
              [(d + 'cd_running', 'cd_running', 'bin'),
               (d + 'cd_expired', 'cd_expired', 'bin'),
               (d + 'cd_remain_bcd', 'cd_remain_bcd', 'bcd24'),
               (d + 'cd_expire_pulse', 'cd_expire_pulse', 'bin'),
               (d + 'beep_en', 'beep_en', 'bin')],
              510_000_000, 575_000_000)

    draw_wave(os.path.join(out_dir, 'wave_display.png'),
              '8-digit dynamic scan (CL 00:00:00)',
              [(d + 'tick_1khz', 'tick_1khz', 'bin'),
               (p + 'dig_n', 'dig_n (one-hot low)', 'hex'),
               (p + 'seg_n', 'seg_n (g..a,dp)', 'hex'),
               (d + 'u_display_ctrl.disp', 'disp (8 nibbles)', 'hex')],
              6_300_000, 7_100_000)

    draw_wave(os.path.join(out_dir, 'wave_key.png'),
              'Mode-9 key: nibble change -> 20 ms debounce -> key_press',
              [(p + 'pi_in', 'pi_in (key 3:0)', 'hex'),
               (d + 'key_press', 'key_press', 'hex'),
               (d + 'setting', 'setting', 'bin'),
               (d + 'cursor', 'cursor', 'unsigned'),
               (d + 'time_edit_bcd', 'time_edit_bcd', 'bcd24')],
              85_500_000, 94_500_000)

    draw_wave(os.path.join(out_dir, 'wave_rollover.png'),
              '23:59:59 -> 00:00:00 at one 1 Hz tick',
              [(d + 'tick_1hz', 'tick_1hz', 'bin'),
               (d + 'time_bcd', 'time_bcd', 'bcd24')],
              40_120_000, 40_180_000)

    draw_wave(os.path.join(out_dir, 'wave_buzzer.png'),
              'Buzzer tone: beep_en gates a 2.7 kHz square wave (SIM_FAST)',
              [(d + 'beep_en', 'beep_en', 'bin'),
               (p + 'buzzer', 'buzzer (active low)', 'bin'),
               (d + 'u_buzzer_tone.tone', 'tone', 'bin'),
               (d + 'u_buzzer_tone.cnt', 'tone counter', 'unsigned')],
              139_700_000, 140_200_000)

    # Print useful event times for documentation
    for name in ['tb_digital_clock_top.dut.time_bcd',
                 'tb_digital_clock_top.dut.alarm_trigger',
                 'tb_digital_clock_top.dut.cd_expire_pulse',
                 'tb_digital_clock_top.dut.beep_en']:
        ev = changes.get(name, [])
        print(name, 'events', len(ev))
        for x in ev[:6]:
            print('  ', x)


if __name__ == '__main__':
    main()

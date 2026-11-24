import sys
p = r'C:\ZZJ\APP\intelFPGA\17.1\MyprojectsZZJ\DigitalClock\refs\body_map.txt'
lines = open(p, encoding='utf-8').read().splitlines()
needle = sys.argv[1] if len(sys.argv) > 1 else '图3.15'
for i, line in enumerate(lines):
    if needle in line:
        for j in range(max(0, i-4), min(len(lines), i+4)):
            print(j, lines[j][:500])
        print('---')

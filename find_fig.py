import os
import sys

p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'refs', 'body_map.txt')
with open(p, encoding='utf-8') as f:
    lines = f.read().splitlines()

needle = sys.argv[1] if len(sys.argv) > 1 else '图3.15'
for i, line in enumerate(lines):
    if needle in line:
        for j in range(max(0, i - 4), min(len(lines), i + 4)):
            print(j, lines[j][:500])
        print('---')

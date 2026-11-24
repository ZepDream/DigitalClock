import glob
import os

import docx

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'refs')
for p in glob.glob(os.path.join(BASE, '*.docx')):
    try:
        d = docx.Document(p)
    except Exception as e:
        print('SKIP', p, e)
        continue
    out = []
    for para in d.paragraphs:
        t = para.text.strip()
        if t:
            out.append(t)
    out.append('\n=== TABLES ===\n')
    for ti, table in enumerate(d.tables):
        out.append(f'--- TABLE {ti+1} ---')
        for row in table.rows:
            cells = []
            for c in row.cells:
                cells.append(' '.join(c.text.split()))
            out.append(' | '.join(cells))
    dst = os.path.splitext(p)[0] + '.extracted.txt'
    with open(dst, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))
    print(os.path.basename(p), len(out), 'blocks ->', os.path.basename(dst))

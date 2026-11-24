import os

import docx
from docx.oxml.ns import qn

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'refs')
p = os.path.join(BASE, 'EDA实验箱使用手册（修订版）.docx')
d = docx.Document(p)
rels = d.part.rels
outdir = os.path.join(BASE, 'images')
os.makedirs(outdir, exist_ok=True)
idx = 0
last_text = ''
for para in d.paragraphs:
    text = para.text.strip()
    if text:
        last_text = text
    blips = para._element.findall('.//' + qn('a:blip'))
    for blip in blips:
        rid = blip.get(qn('r:embed'))
        if not rid or rid not in rels:
            continue
        part = rels[rid].target_part
        ext = os.path.splitext(part.partname)[1]
        idx += 1
        fn = f'{idx:03d}{ext}'
        with open(os.path.join(outdir, fn), 'wb') as f:
            f.write(part.blob)
        print(f'{fn}\t{last_text[:80]}')
print('TOTAL', idx)

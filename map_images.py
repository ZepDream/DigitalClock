import os

import docx
from docx.oxml.ns import qn
from docx.text.paragraph import Paragraph

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'refs')
p = os.path.join(BASE, 'EDA实验箱使用手册（修订版）.docx')
d = docx.Document(p)
rels = d.part.rels


def images_in(el):
    out = []
    for blip in el.findall('.//' + qn('a:blip')):
        rid = blip.get(qn('r:embed'))
        if rid and rid in rels:
            out.append(rels[rid].target_part.partname)
    return out


lines = []
for child in d.element.body.iterchildren():
    if child.tag == qn('w:p'):
        para = Paragraph(child, d)
        text = para.text.strip()
        imgs = images_in(child)
        if text or imgs:
            lines.append(f'P|{text}|{";".join(imgs)}')
    elif child.tag == qn('w:tbl'):
        lines.append('TABLE')

with open(os.path.join(BASE, 'body_map.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

for i, line in enumerate(lines):
    if '图3.28' in line or 'NO.9' in line or '动态扫描电路' in line:
        for j in range(max(0, i - 6), min(len(lines), i + 3)):
            print(j, lines[j][:300])
        print('---')

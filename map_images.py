import docx, os
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph

base = r'C:\ZZJ\APP\intelFPGA\17.1\MyprojectsZZJ\DigitalClock\refs'
p = os.path.join(base, 'EDA实验箱使用手册（修订版）.docx')
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
open(os.path.join(base, 'body_map.txt'), 'w', encoding='utf-8').write('\n'.join(lines))
for i, line in enumerate(lines):
    if '图3.28' in line or 'NO.9' in line or '动态扫描电路' in line:
        for j in range(max(0, i-6), min(len(lines), i+3)):
            print(j, lines[j][:300])
        print('---')

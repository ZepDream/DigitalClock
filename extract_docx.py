import docx, os, glob

base = r'C:\ZZJ\APP\intelFPGA\17.1\MyprojectsZZJ\DigitalClock\refs'
for p in glob.glob(os.path.join(base, '*.docx')):
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
    open(dst, 'w', encoding='utf-8').write('\n'.join(out))
    print(os.path.basename(p), len(out), 'blocks ->', os.path.basename(dst))

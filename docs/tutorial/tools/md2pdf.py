#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 docs/ 下的 Markdown 转成带中文标题、页脚的 PDF，输出到 文档/。

流程：Markdown → HTML（本地 CSS）→ Chrome headless 打印 PDF → pypdf + reportlab 加页脚页码。

依赖：pip install markdown pypdf reportlab；本机需有 Chrome 或 Edge。

用法（在任意目录执行都可以，脚本按自身位置定位工程根）：
    python docs/tutorial/tools/md2pdf.py            # 转换全部
    python docs/tutorial/tools/md2pdf.py --list     # 只列出将生成的文件
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent          # docs/tutorial/tools -> 工程根
OUT_DIR = ROOT / '文档'
BUILD_DIR = OUT_DIR / '.build'

try:
    import markdown
except ImportError:
    sys.exit('缺少依赖：pip install markdown')

# ---------------------------------------------------------------- 输出命名
# （源文件 -> 中文文件名，标题取 Markdown 的 H1）
TUTORIAL_NAMES = {
    'README.md': '教程_00_总览与学习路线',
    '01_从C到Verilog.md': '教程_01_从C到Verilog',
    '02_认识这个工程.md': '教程_02_认识这个工程',
    '03_Quartus全流程.md': '教程_03_Quartus全流程',
    '04_顶层与连接.md': '教程_04_顶层与连接',
    '05_模块解读_一.md': '教程_05_模块解读一_时钟按键控制',
    '06_模块解读_二.md': '教程_06_模块解读二_计时显示蜂鸣',
    '07_Verilog语法速查.md': '教程_07_Verilog语法速查',
    '08_仿真实战.md': '教程_08_仿真实战',
    '09_断点与调试.md': '教程_09_断点与调试',
    '10_上板与排错.md': '教程_10_上板与排错',
    '11_附录.md': '教程_11_附录',
}
DOC_NAMES = {
    '00_board_config.md': '说明书_00_板级与显示配置',
    '00_design_baseline.md': '说明书_01_总体设计基线',
    '00_traceability_matrix.md': '说明书_02_需求对照表',
    '00_document_plan.md': '说明书_03_文档方案',
    '00_document_outlines.md': '说明书_04_五份说明书详细大纲',
    '01_key_manual.md': '说明书_05_按键操作说明书',
    '02_divider_manual.md': '说明书_06_分频器说明书',
    '03_architecture_manual.md': '说明书_07_系统架构说明书',
    '04_simulation_manual.md': '说明书_08_仿真操作流程说明书',
    '05_final_plan.md': '说明书_09_最终方案',
    '06_git_sync.md': '说明书_10_Git双机同步说明',
}

CSS = """
@page { size: A4; margin: 20mm 16mm 22mm 16mm; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: "Microsoft YaHei", "PingFang SC", "Segoe UI", sans-serif;
       font-size: 10.5pt; line-height: 1.72; color: #1A1A1A; }
h1 { font-size: 21pt; margin: 0 0 14px; padding-bottom: 8px;
     border-bottom: 3px solid #1565C0; color: #0D47A1; }
h2 { font-size: 15pt; margin: 22px 0 8px; padding-left: 9px;
     border-left: 5px solid #1565C0; page-break-after: avoid; }
h3 { font-size: 12.5pt; margin: 16px 0 6px; color: #263238; page-break-after: avoid; }
h4 { font-size: 11pt; margin: 12px 0 4px; page-break-after: avoid; }
p, li { font-size: 10.5pt; }
ul, ol { padding-left: 22px; }
li { margin: 3px 0; }
code { font-family: "Consolas", "Cascadia Mono", monospace; font-size: 9.5pt;
       background: #F2F4F6; padding: 1px 4px; border-radius: 3px; color: #B71C1C; }
pre { background: #F7F9FA; border: 1px solid #DDE3E8; border-left: 4px solid #90A4AE;
      border-radius: 4px; padding: 9px 12px; margin: 9px 0;
      page-break-inside: avoid; overflow: visible; }
pre code { background: none; padding: 0; color: #1A1A1A; font-size: 8.8pt;
           white-space: pre-wrap; word-break: break-all; }
table { border-collapse: collapse; width: 100%; margin: 10px 0; font-size: 9.5pt; }
th, td { border: 1px solid #C7D0D6; padding: 5px 7px; vertical-align: top; text-align: left; }
th { background: #ECEFF1; font-weight: 700; }
tr { page-break-inside: avoid; }
img { max-width: 100%; height: auto; page-break-inside: avoid; display: block; margin: 8px auto; }
blockquote { margin: 10px 0; padding: 8px 12px; background: #FFF8E1;
             border-left: 4px solid #F9A825; color: #4E342E; }
blockquote p { margin: 4px 0; }
details { border: 1px solid #DDE3E8; border-radius: 4px; padding: 6px 10px; margin: 9px 0; background: #FAFAFA; }
summary { font-weight: 700; cursor: default; }
hr { border: none; border-top: 1px solid #DDE3E8; margin: 18px 0; }
a { color: #1565C0; text-decoration: none; }
strong { color: #B71C1C; }
"""

HTML_TMPL = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
{body}
</body>
</html>
"""


def find_browser():
    cands = [
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    ]
    for c in cands:
        if os.path.exists(c):
            return c
    for name in ('chrome', 'msedge'):
        p = shutil.which(name)
        if p:
            return p
    raise SystemExit('没找到 Chrome / Edge，无法打印 PDF')


def md_title(text, fallback):
    for line in text.splitlines():
        if line.startswith('# '):
            return line[2:].strip()
    return fallback



def preprocess(text: str) -> str:
    """Python-Markdown 要求列表前有空行；本工程的文档是 CommonMark 风格，
    很多列表紧跟在“**看图要点**：”这类行后面。这里补一个空行，保证列表能正常渲染。"""
    import re as _re
    out, fence = [], False
    item = _re.compile(r'^([-*+]|\d+\.)\s+')
    for line in text.split('\n'):
        if line.lstrip().startswith('```'):
            fence = not fence
            out.append(line)
            continue
        if not fence and item.match(line) and out:
            prev = out[-1]
            if (prev.strip() and not item.match(prev)
                    and not prev.lstrip().startswith(('|', '>', '<', '```'))
                    and not prev.startswith(('    ', '\t'))):
                out.append('')
        out.append(line)
    return '\n'.join(out)


def md_to_html(md_path: Path, title: str) -> str:
    text = preprocess(md_path.read_text(encoding='utf-8'))
    body = markdown.markdown(
        text,
        extensions=['tables', 'fenced_code', 'sane_lists', 'md_in_html', 'attr_list'],
    )
    body = body.replace('<details>', '<details open>')
    # 相对图片路径 -> 绝对 file URI（MD 文件所在目录为基准）
    def fix_img(m):
        src = m.group(1)
        if re.match(r'^(https?:|data:|file:)', src):
            return m.group(0)
        p = (md_path.parent / src).resolve()
        return f'src="{(p.as_uri())}"'
    body = re.sub(r'src="([^"]+)"', fix_img, body)
    # 图片居中 + 限制高度，避免一张图占满整页
    body = body.replace('<img ', '<img style="max-height:150mm;" ')
    return HTML_TMPL.format(title=title, css=CSS, body=body)


def print_pdf(browser: str, html_path: Path, pdf_path: Path):
    with tempfile.TemporaryDirectory(prefix='md2pdf_') as profile:
        cmd = [
            browser,
            '--headless=new', '--disable-gpu', '--no-sandbox', '--disable-extensions',
            f'--user-data-dir={profile}',
            '--virtual-time-budget=15000',
            '--no-pdf-header-footer',
            f'--print-to-pdf={pdf_path}',
            html_path.as_uri(),
        ]
        r = subprocess.run(cmd, capture_output=True, timeout=180)
        if not pdf_path.exists():
            # 老版本 Chrome 用另一个开关名
            cmd[cmd.index('--no-pdf-header-footer')] = '--print-to-pdf-no-header'
            r = subprocess.run(cmd, capture_output=True, timeout=180)
        if not pdf_path.exists():
            raise RuntimeError(f'打印失败：{pdf_path.name}\n{r.stderr[-500:]}')


def add_footer(pdf_path: Path, footer_text: str):
    """在每个页面底部加“标题 · 第 N / M 页”。"""
    from pypdf import PdfReader, PdfWriter
    from reportlab.pdfgen import canvas
    from reportlab.lib.colors import Color
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont

    font_name = 'SimHei'
    if font_name not in pdfmetrics.getRegisteredFontNames():
        for cand, idx in ((r'C:\Windows\Fonts\simhei.ttf', 0),
                          (r'C:\Windows\Fonts\msyh.ttc', 0),
                          (r'C:\Windows\Fonts\simsun.ttc', 0)):
            if os.path.exists(cand):
                pdfmetrics.registerFont(TTFont(font_name, cand, subfontIndex=idx))
                break

    writer = PdfWriter(clone_from=str(pdf_path))
    total = len(writer.pages)
    for i, page in enumerate(writer.pages, 1):
        w = float(page.mediabox.width)
        h = float(page.mediabox.height)
        buf = tempfile.NamedTemporaryFile(suffix='.pdf', delete=False).name
        c = canvas.Canvas(buf, pagesize=(w, h))
        c.setFillColor(Color(0.45, 0.45, 0.45))
        c.setFont(font_name, 8)
        c.drawCentredString(w / 2, 12, f'{footer_text} · 第 {i} / {total} 页')
        c.save()
        overlay = PdfReader(buf)
        page.merge_page(overlay.pages[0])
        os.unlink(buf)
    tmp = pdf_path.with_suffix('.tmp.pdf')
    with open(tmp, 'wb') as f:
        writer.write(f)
    os.replace(tmp, pdf_path)


def collect_targets():
    targets = []
    for name, out in TUTORIAL_NAMES.items():
        p = ROOT / 'docs' / 'tutorial' / name
        if p.exists():
            targets.append((p, out))
    for name, out in DOC_NAMES.items():
        p = ROOT / 'docs' / name
        if p.exists():
            targets.append((p, out))
    return targets


def main():
    if '--list' in sys.argv:
        for p, out in collect_targets():
            print(f'{p.relative_to(ROOT)}  ->  文档/{out}.pdf')
        return
    browser = find_browser()
    OUT_DIR.mkdir(exist_ok=True)
    BUILD_DIR.mkdir(exist_ok=True)
    targets = collect_targets()
    print(f'浏览器: {browser}\n共 {len(targets)} 个文件 -> {OUT_DIR}\n')
    index = []
    for p, out in targets:
        pdf = OUT_DIR / f'{out}.pdf'
        html = BUILD_DIR / f'{out}.html'
        title = md_title(p.read_text(encoding='utf-8'), out)
        html.write_text(md_to_html(p, title), encoding='utf-8')
        print(f'  转换 {p.relative_to(ROOT)} ...', end='', flush=True)
        print_pdf(browser, html, pdf)
        add_footer(pdf, out.replace('_', ' '))
        from pypdf import PdfReader
        pages = len(PdfReader(str(pdf)).pages)
        size = pdf.stat().st_size / 1024
        print(f' {pages} 页, {size:.0f} KB')
        index.append((out, title, pages, size))
    # 索引
    lines = ['# 文档目录（PDF）', '',
             '由 `docs/` 与 `docs/tutorial/` 下的 Markdown 自动生成；重新生成：',
             '',
             '```bat',
             'python docs\\tutorial\\tools\\md2pdf.py',
             '```', '',
             '| PDF | 内容 | 页数 | 大小 |', '|---|---|---|---|']
    for out, title, pages, size in index:
        lines.append(f'| [{out}.pdf]({out}.pdf) | {title} | {pages} | {size:.0f} KB |')
    lines += ['', '源文件：', '',
              '- `docs/tutorial/` — 初学者教程（12 篇）',
              '- `docs/` — 说明书与设计文档（11 篇）',
              '', '图片、表格、代码块、折叠答案都已展开为静态内容，可直接打印。']
    (OUT_DIR / 'README.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    shutil.rmtree(BUILD_DIR, ignore_errors=True)
    total = sum(s for _, _, _, s in index) / 1024
    print(f'\n完成：{len(index)} 个 PDF，共 {total:.1f} MB')


if __name__ == '__main__':
    main()

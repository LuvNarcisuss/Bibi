"""Render approved agreement sources into matching HTML and embedded-font PDFs."""
from pathlib import Path
from html import escape
import re
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import reportlab

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'Assets'
styles = getSampleStyleSheet()
font_root = Path(reportlab.__file__).resolve().parent / 'fonts'
pdfmetrics.registerFont(TTFont('AgreementRegular', str(font_root / 'Vera.ttf')))
pdfmetrics.registerFont(TTFont('AgreementBold', str(font_root / 'VeraBd.ttf')))
styles.add(ParagraphStyle(name='AgreementTitle', fontName='AgreementBold', fontSize=22, leading=28, textColor=colors.HexColor('#6943bd'), spaceAfter=20))
styles.add(ParagraphStyle(name='AgreementHeading', fontName='AgreementBold', fontSize=12, leading=17, spaceBefore=15, spaceAfter=8, keepWithNext=True))
styles.add(ParagraphStyle(name='AgreementBody', fontName='AgreementRegular', fontSize=10, leading=15, spaceAfter=8, alignment=TA_LEFT))

def footer(canvas, document):
    canvas.setStrokeColor(colors.HexColor('#e4d7ff'))
    canvas.line(46, 42, A4[0] - 46, 42)
    canvas.setFont('AgreementRegular', 8)
    canvas.setFillColor(colors.HexColor('#625b73'))
    canvas.drawString(46, 29, document.title)
    canvas.drawRightString(A4[0] - 46, 29, str(document.page))

for name in ['TermsOfService', 'PrivacyPolicy']:
    lines = (ASSETS / f'agreement-source-{name}.txt').read_text().splitlines()
    story = []
    html = []
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        style = 'AgreementTitle' if index == 0 else 'AgreementHeading' if re.match(r'^\d+(?:\.\d+)?\.?(?: |$)', line) else 'AgreementBody'
        text = re.sub(r'https://[^\s]+', lambda match: '<a href="' + match[0] + '">' + match[0] + '</a>', escape(line))
        story.append(Paragraph(text, styles[style]))
        tag = 'h1' if index == 0 else 'h2' if style == 'AgreementHeading' else 'p'
        html.append(f'<{tag}>{text}</{tag}>')
    pdf = SimpleDocTemplate(str(ASSETS / f'{name}.pdf'), pagesize=A4, rightMargin=46, leftMargin=46,
                           topMargin=46, bottomMargin=58, title=lines[0], author='Bibi', invariant=1)
    pdf.build(story, onFirstPage=footer, onLaterPages=footer)
    (ASSETS / f'{name}.html').write_text(
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f'<title>{escape(lines[0])}</title><style>'
        'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;'
        'background:#f8f5ff;color:#28213f;line-height:1.65;margin:0;padding:24px;overflow-wrap:anywhere}'
        'main{max-width:760px;margin:auto}h1{color:#6943bd;font-size:28px}'
        'h2{font-size:22px;margin-top:30px}p{margin:12px 0}'
        '</style></head><body><main>\n' + '\n'.join(html) + '\n</main></body></html>\n')
    print(name)

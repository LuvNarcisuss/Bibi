"""Render the approved local agreement text as versioned PDF assets."""
from pathlib import Path
from html import escape
import re
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'Assets'
styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='AgreementTitle', fontName='Helvetica-Bold', fontSize=22, leading=28, textColor=colors.HexColor('#6943bd'), spaceAfter=20))
styles.add(ParagraphStyle(name='AgreementHeading', fontName='Helvetica-Bold', fontSize=12, leading=17, spaceBefore=15, spaceAfter=8, keepWithNext=True))
styles.add(ParagraphStyle(name='AgreementBody', fontName='Helvetica', fontSize=9.5, leading=14, spaceAfter=8, alignment=TA_LEFT))

def footer(canvas, document):
    canvas.setStrokeColor(colors.HexColor('#e4d7ff'))
    canvas.line(46, 42, A4[0] - 46, 42)
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(colors.HexColor('#625b73'))
    canvas.drawString(46, 29, document.title)
    canvas.drawRightString(A4[0] - 46, 29, str(document.page))

for name in ['TermsOfService', 'PrivacyPolicy']:
    lines = (ASSETS / f'agreement-source-{name}.txt').read_text().splitlines()
    story = []
    for index, line in enumerate(lines):
        if not line.strip():
            continue
        style = 'AgreementTitle' if index == 0 else 'AgreementHeading' if re.match(r'^\d+(?:\.\d+)?\.?(?: |$)', line) else 'AgreementBody'
        story.append(Paragraph(escape(line), styles[style]))
    pdf = SimpleDocTemplate(str(ASSETS / f'{name}.pdf'), pagesize=A4, rightMargin=46, leftMargin=46,
                           topMargin=46, bottomMargin=58, title=lines[0], author='Bibi', invariant=1)
    pdf.build(story, onFirstPage=footer, onLaterPages=footer)
    print(name)

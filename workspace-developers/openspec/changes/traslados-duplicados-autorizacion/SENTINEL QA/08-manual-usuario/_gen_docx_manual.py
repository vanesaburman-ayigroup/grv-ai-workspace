# -*- coding: utf-8 -*-
"""Genera un .docx con la MARCA Colonia Suiza desde un .md.

Uso:
    python _gen_docx_marca.py <src.md> <titulo> <subtitulo> <out.docx>

Flujo:
  1) md -> docx "target" (python-docx): headings, tablas, listas, codigo fenced,
     blockquotes, bold/inline code. Inserta un page-break inicial (hueco de portada).
  2) Fase A (zip/XML): copia theme + fontTable + fuentes embebidas + estilos de
     parrafo del modelo + portada (con swap de titulo/subtitulo/version).
  3) Fase B (python-docx): mapea fuentes/colores en runs y formatea tablas
     (header navy, grilla) con el look de marca.

Basado en _build_branding.py y _gen_informe_docx_html.py del repo.
"""
import sys, re, zipfile, os
sys.stdout.reconfigure(encoding="utf-8")

SRC       = sys.argv[1]
TITULO    = sys.argv[2]
SUBTITULO = sys.argv[3]
OUT       = sys.argv[4]
VERSION_NUEVA = "Versión 1.0   ·   Agosto 2026"

MODELO = "C:/Users/Usuario/Documents/Proyectos/grv-ai-workspace/workspace-developers/modelo_actual.docx"
VERSION_MODELO = "Versión 1.0   ·   Junio 2026"
TITULO_MODELO   = "Reporte de Funcionalidades"
SUBTITULO_MODELO = "Siniestralidad"

TARGET = "_tmp_target.docx"
OUT_A  = "_tmp_faseA.docx"

# ============================================================ 1) md -> docx
import docx
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_BREAK, WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

md_text = open(SRC, encoding="utf-8").read()

doc = Document()
st = doc.styles["Normal"]
st.font.name = "Inter"
st.font.size = Pt(10.5)
for sec in doc.sections:
    sec.left_margin = Cm(2.2); sec.right_margin = Cm(2.2)

# page break inicial: deja el "hueco" que la Fase A reemplaza por la portada del modelo
p0 = doc.add_paragraph()
p0.add_run().add_break(WD_BREAK.PAGE)


def add_runs(par, text):
    """**negrita**, *cursiva*, `codigo`, resto plano."""
    for tok in re.split(r"(\*\*.+?\*\*|\*[^*]+\*|`[^`]+`)", text):
        if not tok:
            continue
        if tok.startswith("**") and tok.endswith("**"):
            par.add_run(tok[2:-2]).bold = True
        elif len(tok) > 2 and tok.startswith("*") and tok.endswith("*"):
            par.add_run(tok[1:-1]).italic = True
        elif tok.startswith("`") and tok.endswith("`"):
            r = par.add_run(tok[1:-1]); r.font.name = "Consolas"; r.font.size = Pt(9)
        else:
            par.add_run(tok)


def shade_paragraph(p, fill):
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear"); shd.set(qn("w:fill"), fill)
    pPr.append(shd)


def add_code_block(lines):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(4); pf.space_after = Pt(4); pf.left_indent = Cm(0.3)
    shade_paragraph(p, "F4F5F6")
    for i, ln in enumerate(lines):
        if i:
            p.add_run().add_break(WD_BREAK.LINE)
        r = p.add_run(ln.replace("\t", "    "))
        r.font.name = "Consolas"; r.font.size = Pt(8.5)
        r.font.color.rgb = RGBColor(0x1A, 0x20, 0x23)


def _png_size(path):
    import struct
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])  # (ancho, alto) en px


def add_image(path, caption=""):
    """![alt](path) -> imagen centrada, escalada para entrar en la caja util
    (max 16cm ancho x 20cm alto), preservando aspecto. Alt -> epigrafe gris."""
    if not os.path.exists(path):
        add_runs(doc.add_paragraph(), "[imagen no encontrada: %s]" % path)
        return
    w, h = _png_size(path)
    w_cm, h_cm = w / 96 * 2.54, h / 96 * 2.54
    scale = min(16.0 / w_cm, 20.0 / h_cm, 1.0)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(path, width=Cm(w_cm * scale))
    if caption:
        cp = doc.add_paragraph(); cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = cp.add_run(caption); r.italic = True; r.font.size = Pt(8.5)
        r.font.color.rgb = RGBColor(0x89, 0x96, 0xA0)


def flush_table(rows):
    rows = [r for r in rows if r.strip()]
    if not rows:
        return
    def cells(line):
        return [c.strip() for c in line.strip().strip("|").split("|")]
    header = cells(rows[0])
    data = rows[2:] if len(rows) > 1 and set(rows[1].replace("|", "").strip()) <= set("-: ") else rows[1:]
    t = doc.add_table(rows=1, cols=len(header))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for j, c in enumerate(header):
        cellp = t.rows[0].cells[j].paragraphs[0]
        add_runs(cellp, c)
        for r in cellp.runs:
            r.bold = True
    for line in data:
        cs = cells(line)
        row = t.add_row()
        for j in range(len(header)):
            add_runs(row.cells[j].paragraphs[0], cs[j] if j < len(cs) else "")


# --- strip del H1 + primer H2 (los lleva la portada) ---
lines = md_text.splitlines()
i = 0
# saltear blockquote-intro y encabezados de portada
skipped_h1 = skipped_h2 = False
while i < len(lines):
    s = lines[i].strip()
    if not skipped_h1 and s.startswith("# "):
        skipped_h1 = True; i += 1; continue
    if skipped_h1 and not skipped_h2 and s.startswith("## "):
        skipped_h2 = True; i += 1; continue
    if skipped_h1 and not s:
        i += 1; continue
    break

while i < len(lines):
    line = lines[i]; s = line.strip()
    # codigo fenced
    if s.startswith("```"):
        blk = []; i += 1
        while i < len(lines) and not lines[i].strip().startswith("```"):
            blk.append(lines[i]); i += 1
        i += 1  # cierre
        add_code_block(blk); continue
    # tabla
    if s.startswith("|"):
        tbl = []
        while i < len(lines) and lines[i].strip().startswith("|"):
            tbl.append(lines[i]); i += 1
        flush_table(tbl); continue
    # imagen ![alt](path)
    mimg = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)\s*$", s)
    if mimg:
        add_image(mimg.group(2), mimg.group(1)); i += 1; continue
    if s.startswith("### "):
        add_runs(doc.add_heading(level=3), s[4:])
    elif s.startswith("## "):
        add_runs(doc.add_heading(level=2), s[3:])
    elif s.startswith("# "):
        add_runs(doc.add_heading(level=1), s[2:])
    elif s in ("---", "***"):
        pass
    elif s.startswith("> "):
        p = doc.add_paragraph(); shade_paragraph(p, "E0FBFB")
        p.paragraph_format.left_indent = Cm(0.3)
        add_runs(p, s[2:])
    elif re.match(r"^\d+\.\s", s):
        add_runs(doc.add_paragraph(style="List Number"), re.sub(r"^\d+\.\s+", "", s))
    elif s.startswith("- "):
        indent = len(line) - len(line.lstrip())
        style = "List Bullet 2" if indent >= 2 else "List Bullet"
        add_runs(doc.add_paragraph(style=style), s[2:])
    elif s:
        add_runs(doc.add_paragraph(), s)
    i += 1

doc.save(TARGET)
print("target:", TARGET)

# ============================================================ 2) Fase A (branding zip)
zm = zipfile.ZipFile(MODELO); zt = zipfile.ZipFile(TARGET)
m_doc = zm.read("word/document.xml").decode("utf-8")
t_doc = zt.read("word/document.xml").decode("utf-8")
m_styles = zm.read("word/styles.xml").decode("utf-8")
t_styles = zt.read("word/styles.xml").decode("utf-8")
m_rels = zm.read("word/_rels/document.xml.rels").decode("utf-8")
t_rels = zt.read("word/_rels/document.xml.rels").decode("utf-8")

def get_style(xml, sid):
    m = re.search(r'<w:style [^>]*w:styleId="%s"[^>]*>.*?</w:style>' % sid, xml, re.S)
    return m.group(0) if m else None

new_styles = t_styles
dd = re.search(r"<w:docDefaults>.*?</w:docDefaults>", m_styles, re.S)
if dd:
    new_styles = re.sub(r"<w:docDefaults>.*?</w:docDefaults>", lambda _: dd.group(0), new_styles, flags=re.S)
for sid in ["Normal","Heading1","Heading2","Heading3","Heading4","Title","Subtitle"]:
    ms = get_style(m_styles, sid)
    if not ms:
        continue
    if get_style(new_styles, sid):
        new_styles = re.sub(r'<w:style [^>]*w:styleId="%s"[^>]*>.*?</w:style>' % sid, lambda _: ms, new_styles, flags=re.S)
    else:
        new_styles = new_styles.replace("</w:styles>", ms + "</w:styles>")

# portada del modelo: <body> .. parrafo de la version
m_body = m_doc.find("<w:body>") + len("<w:body>")
vpos = m_doc.find(VERSION_MODELO)
assert vpos > 0, "no se encontro la version en el modelo"
m_cover = m_doc[m_body:m_doc.find("</w:p>", vpos) + len("</w:p>")]
m_cover += '<w:p><w:pPr><w:rPr/></w:pPr><w:r><w:rPr><w:rtl w:val="0"/></w:rPr><w:br w:type="page"/></w:r></w:p>'

# target: <body> .. primer page break (el hueco que insertamos)
t_body = t_doc.find("<w:body>") + len("<w:body>")
t_br = t_doc.find('<w:br w:type="page"')
t_ce = t_doc.find("</w:p>", t_br) + len("</w:p>")

# imagenes de la portada del modelo -> copiar + rels nuevos
m_rel_map = dict(re.findall(r'<Relationship Id="([^"]+)"[^>]*Target="([^"]+)"', m_rels))
used = sorted(set(re.findall(r'r:embed="([^"]+)"', m_cover)))
next_rid = max([int(r[3:]) for r in re.findall(r'Id="(rId\d+)"', t_rels)] + [0]) + 1
add_rels, media_copies, rid_swap = [], [], {}
for r in used:
    tgt = m_rel_map[r]; ext = tgt.rsplit(".", 1)[-1]
    newname = "media/cover_%s.%s" % (r, ext); newrid = "rId%d" % next_rid; next_rid += 1
    rid_swap[r] = newrid
    add_rels.append('<Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="%s"/>' % (newrid, newname))
    media_copies.append(("word/" + tgt, "word/" + newname))
for old, new in rid_swap.items():
    m_cover = m_cover.replace('r:embed="%s"' % old, 'r:embed="%s"' % new)
new_t_rels = t_rels.replace("</Relationships>", "".join(add_rels) + "</Relationships>")

for a, b in [(TITULO_MODELO, TITULO), (SUBTITULO_MODELO, SUBTITULO), (VERSION_MODELO, VERSION_NUEVA)]:
    pat = '<w:t xml:space="preserve">%s</w:t>' % a
    pat2 = "<w:t>%s</w:t>" % a
    if pat in m_cover:
        m_cover = m_cover.replace(pat, '<w:t xml:space="preserve">%s</w:t>' % b, 1)
    elif pat2 in m_cover:
        m_cover = m_cover.replace(pat2, "<w:t>%s</w:t>" % b, 1)
    else:
        print("  swap NO encontrado:", repr(a))

new_t_doc = t_doc[:t_body] + m_cover + t_doc[t_ce:]

# la portada del modelo usa DrawingML/VML (a:, wp:, pic:, v:...) -> el <w:document>
# del target (generado por python-docx) puede no declarar esos namespaces. Uso la
# apertura del modelo, que es superset de prefijos.
m_open = re.search(r"<w:document\b[^>]*>", m_doc).group(0)
new_t_doc = re.sub(r"<w:document\b[^>]*>", m_open.replace("\\", "\\\\"), new_t_doc, count=1)

replace = {
    "word/document.xml": new_t_doc.encode("utf-8"),
    "word/styles.xml": new_styles.encode("utf-8"),
    "word/_rels/document.xml.rels": new_t_rels.encode("utf-8"),
    "word/theme/theme1.xml": zm.read("word/theme/theme1.xml"),
    "word/fontTable.xml": zm.read("word/fontTable.xml"),
    "word/_rels/fontTable.xml.rels": zm.read("word/_rels/fontTable.xml.rels"),
}
extra = {}
for src, dst in media_copies:
    extra[dst] = zm.read(src)
for f in zm.namelist():
    if f.startswith("word/fonts/"):
        extra[f] = zm.read(f)

MIME = {
    "png":"image/png","jpeg":"image/jpeg","jpg":"image/jpeg","gif":"image/gif",
    "emf":"image/x-emf","wmf":"image/x-wmf","bmp":"image/bmp","tiff":"image/tiff",
    "ttf":"application/x-font-ttf","otf":"application/vnd.ms-opentype",
}
ct = zt.read("[Content_Types].xml").decode("utf-8")
declared = set(e.lower() for e in re.findall(r'<Default Extension="([^"]+)"', ct))
# extensiones de todo lo que inyecto (imagenes de portada + fuentes embebidas)
exts = set(dst.rsplit(".", 1)[-1].lower() for _s, dst in media_copies)
exts |= set(f.rsplit(".", 1)[-1].lower() for f in zm.namelist() if f.startswith("word/fonts/"))
for e in sorted(exts):
    if e not in declared and e in MIME:
        ct = ct.replace("</Types>", '<Default Extension="%s" ContentType="%s"/></Types>' % (e, MIME[e]))
        declared.add(e)
replace["[Content_Types].xml"] = ct.encode("utf-8")

with zipfile.ZipFile(OUT_A, "w", zipfile.ZIP_DEFLATED) as zo:
    for item in zt.infolist():
        zo.writestr(item.filename, replace.get(item.filename) or zt.read(item.filename))
    for name, data in extra.items():
        zo.writestr(name, data)
zm.close(); zt.close()
print("faseA:", OUT_A)

# ============================================================ 3) Fase B (runs + tablas)
d = Document(OUT_A)
COLOR_MAP = {"1B4F9D": "1A2023", "333333": "000000"}
HEAD_FMT = {"Heading 1": 22, "Heading 2": 15, "Heading 3": 13}

def set_run_font(run, name):
    r = run._element.get_or_add_rPr()
    rf = r.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts"); r.insert(0, rf)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rf.set(qn(attr), name)

def map_run(run, in_heading=None):
    f = run.font
    if in_heading:
        set_run_font(run, "Red Hat Display"); f.size = Pt(HEAD_FMT[in_heading]); f.bold = True
        f.color.rgb = RGBColor(0x1A, 0x20, 0x23); return
    if f.name in ("Calibri", "Cambria", "Arial") or f.name is None:
        rpr = run._element.find(qn("w:rPr"))
        if rpr is not None and rpr.find(qn("w:rFonts")) is not None:
            set_run_font(run, "Inter")
    if f.color and f.color.rgb is not None:
        hexv = str(f.color.rgb).upper()
        if hexv in COLOR_MAP:
            f.color.rgb = RGBColor.from_string(COLOR_MAP[hexv])

body_started = False
for p in d.paragraphs:
    if not body_started:
        if p._element.xpath('.//w:br[@w:type="page"]'):
            body_started = True
        continue
    sname = p.style.name
    hd = sname if sname in HEAD_FMT else None
    for run in p.runs:
        map_run(run, in_heading=hd)

def set_cell_borders(cell, col="CCCCCC", sz=4):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:tcBorders"))
    if old is not None: tcPr.remove(old)
    bd = OxmlElement("w:tcBorders")
    for side in ("top","left","bottom","right"):
        el = OxmlElement("w:" + side)
        el.set(qn("w:val"),"single"); el.set(qn("w:sz"),str(sz)); el.set(qn("w:space"),"0"); el.set(qn("w:color"),col)
        bd.append(el)
    tcPr.append(bd)

def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    old = tcPr.find(qn("w:shd"))
    if old is not None: tcPr.remove(old)
    sh = OxmlElement("w:shd"); sh.set(qn("w:val"),"clear"); sh.set(qn("w:fill"),fill)
    tcPr.append(sh)

for t in d.tables:
    for ri, row in enumerate(t.rows):
        for cell in row.cells:
            set_cell_borders(cell)
            set_cell_shading(cell, "1A2023" if ri == 0 else ("F7F7F7" if ri % 2 == 0 else "FFFFFF"))
            for p in cell.paragraphs:
                for run in p.runs:
                    set_run_font(run, "Inter")
                    if ri == 0:
                        run.font.bold = True; run.font.size = Pt(9.5)
                        run.font.color.rgb = RGBColor(0xFF,0xFF,0xFF)
                    else:
                        run.font.size = Pt(9.5)
                        if run.font.color and run.font.color.rgb is not None:
                            hx = str(run.font.color.rgb).upper()
                            run.font.color.rgb = RGBColor.from_string(COLOR_MAP.get(hx, "000000") if hx == "FFFFFF" or hx in COLOR_MAP else hx)

d.save(OUT)

# ============================================================ 4) Fase C: re-embeber fuentes
# python-docx descarta word/fonts/* al guardar -> las reinyectamos desde el modelo.
zin = zipfile.ZipFile(OUT); zmod = zipfile.ZipFile(MODELO)
parts = {n: zin.read(n) for n in zin.namelist()}
zin.close()
inject = ["word/fontTable.xml", "word/_rels/fontTable.xml.rels", "word/theme/theme1.xml"]
inject += [n for n in zmod.namelist() if n.startswith("word/fonts/")]
for n in inject:
    try: parts[n] = zmod.read(n)
    except KeyError: pass
zmod.close()
ct = parts["[Content_Types].xml"].decode("utf-8")
if 'Extension="ttf"' not in ct:
    ct = ct.replace("</Types>", '<Default Extension="ttf" ContentType="application/x-font-ttf"/></Types>')
if "/word/fontTable.xml" not in ct:
    ct = ct.replace("</Types>", '<Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/></Types>')
parts["[Content_Types].xml"] = ct.encode("utf-8")
drels = parts["word/_rels/document.xml.rels"].decode("utf-8")
if "fontTable" not in drels:
    rid = "rId%d" % (max([int(x) for x in re.findall(r'Id="rId(\d+)"', drels)] + [900]) + 1)
    drels = drels.replace("</Relationships>", '<Relationship Id="%s" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/></Relationships>' % rid)
    parts["word/_rels/document.xml.rels"] = drels.encode("utf-8")
sett = parts.get("word/settings.xml", b"").decode("utf-8")
if sett and "embedTrueTypeFonts" not in sett:
    sett = re.sub(r"(<w:settings\b[^>]*>)", r"\1<w:embedTrueTypeFonts/><w:saveSubsetFonts/>", sett, count=1)
    parts["word/settings.xml"] = sett.encode("utf-8")
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zo:
    for n, data in parts.items():
        zo.writestr(n, data)
nf = len([n for n in parts if n.startswith("word/fonts/")])
print("fuentes re-embebidas:", nf)

for tmp in (TARGET, OUT_A):
    try: os.remove(tmp)
    except OSError: pass
print("GUARDADO:", OUT)

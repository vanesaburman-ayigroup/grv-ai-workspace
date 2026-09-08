# -*- coding: utf-8 -*-
"""Normaliza el manual .md para que entre por lo que _gen_docx_marca.py soporta.

- Desenvuelve parrafos hard-wrapped (una linea = un parrafo en el generador).
- Une los items de lista partidos en varias lineas, preservando la indentacion
  (el generador usa la indentacion para List Bullet 2).
- Colapsa cada blockquote multilinea en pocas lineas '> ...':
    * los '### titulo' internos pasan a '> **titulo**'
    * los items internos pasan a '> - item' (vinetas con caracter)
    * las imagenes internas SALEN del blockquote (el generador no las ve dentro)
- Deja tablas intactas y le pone encabezado a la tabla de portada sin header.
"""
import re, sys

SRC, DST = sys.argv[1], sys.argv[2]
lines = open(SRC, encoding="utf-8").read().splitlines()

IMG = re.compile(r"^!\[([^\]]*)\]\(([^)]+)\)\s*$")
BOLD_ONLY = re.compile(r"^\*\*.+\*\*$")
LIST_START = re.compile(r"^(\s*)(?:[-*]\s+|\d+\.\s+)")


def is_special(s):
    return (not s.strip() or s.lstrip().startswith(("#", ">", "|", "```", "---", "***"))
            or IMG.match(s.strip()) or LIST_START.match(s))


out = []
i = 0
n = len(lines)
while i < n:
    raw = lines[i]
    s = raw.strip()

    # tabla: intacta
    if s.startswith("|"):
        tbl = []
        while i < n and lines[i].strip().startswith("|"):
            tbl.append(lines[i]); i += 1
        # header vacio -> le pongo uno
        if set(tbl[0].replace("|", "").strip()) == set():
            ncols = tbl[0].strip().strip("|").count("|") + 1
            if ncols == 2:
                tbl[0] = "| Dato | Detalle |"
            else:
                tbl[0] = "|" + "|".join([" "] * ncols) + "|"
        out += tbl
        continue

    # blockquote
    if s.startswith(">"):
        inner = []
        while i < n and lines[i].strip().startswith(">"):
            inner.append(re.sub(r"^\s*>\s?", "", lines[i])); i += 1
        # procesar el interior
        buf = []
        pend_imgs = []

        def flush(prefix="> "):
            if buf:
                out.append(prefix + " ".join(x.strip() for x in buf if x.strip()))
                del buf[:]

        j = 0
        while j < len(inner):
            t = inner[j]
            ts = t.strip()
            m = IMG.match(ts)
            if m:
                flush(); pend_imgs.append(ts); j += 1; continue
            if ts.startswith("#"):
                flush()
                out.append("> **" + ts.lstrip("#").strip() + "**")
                j += 1; continue
            if LIST_START.match(t):
                flush()
                item = re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", t).strip()
                j += 1
                while j < len(inner) and inner[j].strip() and not is_special(inner[j]):
                    item += " " + inner[j].strip(); j += 1
                out.append("> - " + item)
                continue
            if not ts:
                flush(); j += 1; continue
            buf.append(t); j += 1
        flush()
        for im in pend_imgs:
            out.append("")
            out.append(im)
        continue

    # item de lista: unir continuaciones
    m = LIST_START.match(raw)
    if m:
        item = raw.rstrip()
        i += 1
        while i < n and lines[i].strip() and not is_special(lines[i]):
            item += " " + lines[i].strip(); i += 1
        out.append(item)
        continue

    # heading / imagen / hr / vacio
    if not s or s.startswith("#") or IMG.match(s) or s in ("---", "***") or s.startswith("```"):
        out.append(raw); i += 1
        continue

    # linea toda en negrita -> parrafo propio (preguntas de FAQ)
    if BOLD_ONLY.match(s):
        out.append(s); i += 1
        continue

    # parrafo de prosa: unir lineas
    par = [s]; i += 1
    while i < n and lines[i].strip() and not is_special(lines[i]) and not BOLD_ONLY.match(lines[i].strip()):
        par.append(lines[i].strip()); i += 1
    out.append(" ".join(par))

open(DST, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("prep:", DST, len(out), "lineas")

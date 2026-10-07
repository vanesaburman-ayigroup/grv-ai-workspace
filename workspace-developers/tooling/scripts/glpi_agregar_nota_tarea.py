"""
glpi_agregar_nota_tarea.py — agrega una NOTA (Notepad) a una ProjectTask de GLPI (proyecto MDA).
NUNCA toca el ticket (lo ve el cliente): solo itemtype=ProjectTask via /front/notepad.form.php.

Stdlib-only. Login por formulario (tooling/lib/glpi.py); cada POST usa un token CSRF nuevo.
Idempotente: si la tarea ya tiene una nota con el mismo marcador, no crea otra.

Uso:
  python tooling/scripts/glpi_agregar_nota_tarea.py [--dry-run] [--solo 2632]

Las notas salen de docs/soporte-n3/GLPI-<ticket>/ (01-script.sql, 02-rollback.sql, 01-plan-fix.md).
"""
from __future__ import annotations
import argparse
import html
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tooling.lib import glpi  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DOCS = ROOT / "docs" / "soporte-n3"


def esc(t: str) -> str:
    return html.escape(t, quote=False)


def leer(ticket: int, nombre: str) -> str:
    return (DOCS / f"GLPI-{ticket}" / nombre).read_text(encoding="utf-8").rstrip() + "\n"


def p(t: str) -> str:
    return f"<p>{esc(t)}</p>"


def ul(items: list[str]) -> str:
    return "<ul>" + "".join(f"<li>{esc(i)}</li>" for i in items) + "</ul>"


def pre(t: str) -> str:
    return f"<pre>{esc(t)}</pre>"


def nota_2632() -> tuple[str, str]:
    m = "[DIAGNOSTICO N3 GLPI-2632]"
    c = (p(m) + "<h3>Causa raíz</h3>"
         + p("Solicitud de CD (GCBA AUTOSEGURO, tipo 158): faltan 2 cartas en cs.cd_cartas. "
             "Módulo 7 (OTRAS CITACIONES) carta 7 'Respuesta a Telegrama' y módulo 8 (RECHAZOS) carta 18 "
             "'EP FECHA PMI ANTERIOR VIGENCIA'. Es solo falta de datos de catálogo; la carta 17 inactiva del módulo 8 no se toca ni se reutiliza.")
         + "<h3>Veredicto consumers-of</h3>"
         + p("NO hay que tocar código. Las cartas se leen dinámicamente (wslistados, wssolicitudesgenericas, MFE solicitudesgenericas); "
             "nadie hardcodea id_carta ni numero_carta. Sin caché: no hace falta redeploy ni reinicio. "
             "Detalle en docs/soporte-n3/GLPI-2632/03-consumers.md.")
         + "<h3>01-script.sql</h3>" + pre(leer(2632, "01-script.sql"))
         + "<h3>02-rollback.sql</h3>" + pre(leer(2632, "02-rollback.sql")))
    return m, c


def nota_2892() -> tuple[str, str]:
    m = "[DIAGNOSTICO N3 GLPI-2892]"
    c = (p(m) + "<h3>Causa raíz</h3>"
         + p("Falta 'Nota de Débito' en el catálogo cs.tipo_facturacion (lo lee wslistados GET /tipos-facturacion y alimenta los "
             "desplegables 'Tipo de factura' del MFE auditoriafacturacion). Se agregan Nota de Débito A/B/C/M.")
         + "<h3>Veredicto consumers-of</h3>"
         + p("NO hay que tocar código: alcanza con el INSERT. Ningún consumidor ramifica por id ni por descripción; sin caché. "
             "Única dependencia textual: la descripción debe terminar en la letra (BuscadorDialog.tsx y vista consulta_auditoria_facturacion_view), "
             "que se cumple. Tabla latin1: ejecutar con charset coherente y verificar el HEX. "
             "Pendiente de negocio (no bloquea): alcance A/B/C/M vs MiPyme; una nota de crédito si exigiría código. "
             "Detalle en docs/soporte-n3/GLPI-2892/03-consumers.md.")
         + "<h3>01-script.sql</h3>" + pre(leer(2892, "01-script.sql"))
         + "<h3>02-rollback.sql</h3>" + pre(leer(2892, "02-rollback.sql")))
    return m, c


def nota_2738() -> tuple[str, str]:
    m = "[DIAGNOSTICO N3 GLPI-2738]"
    plan = leer(2738, "01-plan-fix.md")
    filas = re.findall(r"^\|\s*(\d+(?:-\d+)?)\s*\|\s*([\d, ]+)\|\s*(.+?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*$", plan, re.M)
    clientes = [f"{n}. {nom} - denuncias totales {tot}, 2026: {y}" for n, _id, nom, tot, y in filas]
    if len(clientes) < 25:
        raise RuntimeError(f"no pude parsear la tabla de clientes de 01-plan-fix.md ({len(clientes)} filas)")
    c = (p(m) + "<h3>Causa raíz</h3>"
         + p("El front resuelve el logo del cliente con un switch cerrado de 14 clientes; el resto devuelve undefined "
             "(la cabecera muestra '-' y DatosDenuncia muestra un <img> roto). Los 14 nombres del switch coinciden con "
             "REPLACE(REPLACE(clientes.nombre,' ',''),'.','') en BD: el backend está bien. Faltan logos de ~30 clientes y falta una guardia.")
         + "<h3>Plan de fix (resumen, sin aplicar)</h3>"
         + ul([
             "libreriamodulosgrv (base origin/master 4.23.1, en worktree nuevo): en src/utils/utils.tsx reemplazar el switch por un mapa LOGOS con clave normalizada "
             "(sin tildes, mayúsculas, solo A-Z0-9). Agregar los cases/entradas de los clientes nuevos cuando haya PNG (IAPSER, GCBA, Chubut, etc.) y alias de sub-marcas "
             "'Seguridad e Higiene - X' (IAPSER, HORIZONTE, GOB CHUBUT, AUTOSEGURO GCBA) a confirmar con Comercial. PNG nuevos en src/assets/LogosClientes/.",
             "Guardia en DatosDenuncia.tsx:153: si getLogoCliente devuelve undefined no renderizar el <img> roto; mostrar texto o '-' (mismo criterio que CabeceraDenuncia.tsx:157-160).",
             "Cierre de la lib: tests/story (sin logo, con tilde, sub-marca), bump patch 4.23.2, npm run lint y typecheck.",
             "MFE a bumpear a sas-modules-features-lib 4.23.2: atencioncliente (4.11.0), logistica (4.11.0), auditoriafacturacion (4.18.1), auditoriamedica (4.18.1), mesadecarga (4.18.1), tramitadores (4.23.1). "
             "En los de 4.11.0 y 4.18.1 revisar el CHANGELOG de la lib antes (el salto arrastra cambios intermedios). Lint y typecheck en cada uno.",
             "Copias propias del switch (decidir alcance): grv-frontend Utils/icons.js y contrataciones Utils/icons.js (mismo switch de 14, default null, <img> sin guardia en DatosDenuncia.js); "
             "portalclientes utils/utils.js:53 (solo 7 logos; sus usuarios son ART/aseguradoras, conviene completar).",
             "Backend: nada obligatorio. Higiene opcional en otro ticket: wsempleador EmpleadorPolizaSearchServiceImpl usa razonSocial en vez de nombre.",
         ])
         + "<h3>Clientes sin logo, por volumen de denuncias</h3>" + ul(clientes)
         + p("Pedido mínimo a Mesa/Comercial (impacto 2026): IAPSER (14.280, más 1.431 de Seguridad e Higiene), GCBA (7.936), Autoseguro Chubut (1.415), "
             "SMG Compañía Argentina de Seguros (413), Consejo de la Magistratura (315), Ministerio Público de la Defensa (195), BAPRO (163). "
             "Confirmar que las sub-marcas usan el logo de la marca madre. Detalle en docs/soporte-n3/GLPI-2738/01-plan-fix.md."))
    return m, c


TAREAS = {209: (2632, nota_2632), 210: (2892, nota_2892), 211: (2738, nota_2738)}


def csrf(page: str) -> str:
    m = re.search(r'name="_glpi_csrf_token"\s+value="([^"]+)"', page)
    if not m:
        raise RuntimeError("no encontre _glpi_csrf_token")
    return m.group(1)


def tab(s: glpi.Session, tid: int) -> str:
    return s._get("/ajax/common.tabs.php?_target=/front/projecttask.form.php"
                  f"&_itemtype=ProjectTask&_glpi_tab=Notepad$1&id={tid}")


def tiene_nota(s: glpi.Session, tid: int, marcador: str) -> bool:
    page = tab(s, tid)
    return marcador in page or marcador in html.unescape(page)


def titulo_tarea(s: glpi.Session, tid: int) -> str:
    for col in s.kanban(39).values():
        for it in (col.get("items") or {}).values():
            if str(it.get("id")) == f"ProjectTask-{tid}":
                return html.unescape(re.sub(r"<[^>]+>", "", it.get("title", ""))).strip()
    return ""


def notas_existentes(s: glpi.Session, tid: int) -> list[tuple[str, str]]:
    """(id_nota, contenido HTML) de cada form de edicion del tab Notepad."""
    out = []
    for f in re.findall(r"<form.*?</form>", tab(s, tid), re.S):
        i = re.search(r'name="id"\s+value="(\d+)"', f)
        c = re.search(r"<textarea[^>]*name=\"content\"[^>]*>(.*?)</textarea>", f, re.S)
        if i and c:
            out.append((i.group(1), html.unescape(c.group(1))))
    return out


def editar(s: glpi.Session, tid: int, marcador: str, contenido: str, dry: bool) -> None:
    """Actualiza IN PLACE la nota que lleva el marcador (no crea ni borra)."""
    cand = [(i, c) for i, c in notas_existentes(s, tid) if marcador in c]
    if len(cand) != 1:
        print(f"[tarea {tid}] se esperaba 1 nota con {marcador}, hay {len(cand)}: se omite")
        return
    nid, actual = cand[0]
    if actual.strip() == contenido.strip():
        print(f"[tarea {tid}] nota {nid} ya esta al dia")
        return
    import difflib
    d = [l for l in difflib.unified_diff(actual.splitlines(), contenido.splitlines(), lineterm="", n=0) if l[:1] in "+-" and l[:3] not in ("+++", "---")]
    print(f"[tarea {tid}] nota {nid}: {len(d)//2} lineas cambian")
    if dry:
        for l in d[:6]:
            print("   ", l[:160])
        return
    post(s, "/front/notepad.form.php", [("_glpi_csrf_token", csrf(tab(s, tid))), ("id", nid),
                                        ("content", contenido), ("update", "Update")])


def post(s: glpi.Session, path: str, fields: list[tuple[str, str]]) -> None:
    body = urllib.parse.urlencode(fields).encode("utf-8")
    req = urllib.request.Request(f"{s.base}{path}", data=body, method="POST")
    try:
        with s.opener.open(req, timeout=60) as r:
            r.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"POST {path} -> HTTP {e.code}") from None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--editar", action="store_true", help="actualiza in place la nota existente con el texto actual")
    ap.add_argument("--solo", type=int, help="procesar solo este ticket (2632, 2892, 2738)")
    a = ap.parse_args()
    s = glpi.Session()
    for tid, (ticket, build) in TAREAS.items():
        if a.solo and a.solo != ticket:
            continue
        # seguridad: la tarea debe ser la del ticket (titulo termina en "(<ticket>)")
        titulo = titulo_tarea(s, tid)
        if not re.search(rf"\({ticket}\)\s*$", titulo.strip()):
            print(f"[tarea {tid}] el titulo {titulo!r} no corresponde al ticket {ticket}: se omite")
            continue
        marcador, contenido = build()
        if a.editar:
            editar(s, tid, marcador, contenido, a.dry_run)
            continue
        if tiene_nota(s, tid, marcador):
            print(f"[tarea {tid}] ya tiene la nota {marcador} -> no se crea otra")
            continue
        fields = [("_glpi_csrf_token", csrf(tab(s, tid))), ("itemtype", "ProjectTask"), ("items_id", str(tid)),
                  ("content", contenido), ("add", "Add")]
        print(f"[tarea {tid}] ({titulo}) nota {marcador}: {len(contenido)} bytes de HTML")
        if a.dry_run:
            print("  dry-run: no se envia (POST /front/notepad.form.php, itemtype=ProjectTask)")
            continue
        post(s, "/front/notepad.form.php", fields)
        print(f"[tarea {tid}] verificado: {tiene_nota(s, tid, marcador)}")


if __name__ == "__main__":
    main()

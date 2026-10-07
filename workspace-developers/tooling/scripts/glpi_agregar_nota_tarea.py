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
    c = (p("ESTADO: aplicado en PROD el 07/10/2026 (verificado: ids 68 y 69, módulos 7 y 8, números 7 y 18, sin pérdida de caracteres). Ticket resuelto.")
         + p(m) + "<h3>Causa raíz</h3>"
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
             "desplegables 'Tipo de factura' del MFE auditoriafacturacion). El alta es de 10 filas en cs.tipo_facturacion: "
             "Nota de Débito A/B/C/M, Factura MiPyME A/B/C y Nota de Débito MiPyME A/B/C "
             "(Factura de Crédito Electrónica MiPyME, Ley 27.440). La Nota de Crédito MiPyME NO se agrega porque resta y requeriría código. "
             "Ids esperados 10-19; total 19 filas.")
         + "<h3>Veredicto consumers-of</h3>"
         + p("NO hay que tocar código: alcanza con el INSERT. Ningún consumidor ramifica por id ni por descripción; sin caché. "
             "Única dependencia textual: la descripción debe terminar en la letra (BuscadorDialog.tsx y vista consulta_auditoria_facturacion_view), "
             "que se cumple. Tabla latin1: ejecutar con charset coherente y verificar el HEX. "
             "Detalle en docs/soporte-n3/GLPI-2892/03-consumers.md.")
         + "<h3>Advertencia operativa</h3>"
         + p("La tabla es latin1 y el cliente suele ser utf8mb4; el script convierte el literal con CONVERT(v.descripcion USING latin1) "
             "en el NOT EXISTS para evitar el error 1267 'Illegal mix of collations'.")
         + "<h3>Decisiones de negocio</h3>"
         + p("Resuelta: los comprobantes MiPyME se incluyen.")
         + "<h3>Preguntas abiertas (no bloquean el alta)</h3>"
         + ul(["¿El monto de la Nota de Débito es positivo?",
               "¿Se debe impedir una Nota de Débito con el mismo número que una factura?",
               "¿En qué pantallas aplica?",
               "Confirmar con Nacho Núñez que audita facturas MiPyME."])
         + "<h3>01-script.sql</h3>" + pre(leer(2892, "01-script.sql"))
         + "<h3>02-rollback.sql</h3>" + pre(leer(2892, "02-rollback.sql")))
    return m, c


def nota_2883() -> tuple[str, str]:
    m = "[DIAGNOSTICO N3 GLPI-2883]"
    c = (p(m) + "<h3>Resumen del pedido</h3>"
         + p("Lote de cartas para la Solicitud de CD (GCBA AUTOSEGURO, tipo 158), pedido por Agustín Mesplet (Gestor de Registros y Afiliaciones) el 1/10; "
             "Laila Chaina (Team Leader) agregó 'Respuesta a Telegrama' (carta 7 de OTRAS CITACIONES, ya contemplada en GLPI 2632). "
             "Son 18 cartas nuevas: 1 en ABANDONO (nro 10), 5 en ALTAS (nros 5 a 9), 8 en un módulo nuevo MORTALES (nros 1 a 8) y 4 en RECHAZOS (nros 19 a 22). "
             "Además 2 bajas lógicas (activo = 0, sin DELETE): OTRAS CITACIONES 6 (id 34, 9 solicitudes; se mueve a MORTALES 1) y RECHAZOS 14 (id 48, 73 solicitudes; la reemplaza RECHAZOS 19). "
             "Datos verificados en PROD solo con SELECT; la tabla cs.cd_cartas es latin1 con UK (id_modulo, numero_carta) e id_carta AUTO_INCREMENT.")
         + "<h3>Veredicto consumers-of</h3>"
         + p("Mismo mecanismo que GLPI 2632: NO hay que tocar código. Las cartas se leen dinámicamente (wslistados, wssolicitudesgenericas, MFE solicitudesgenericas), "
             "nadie hardcodea id_carta ni numero_carta, sin caché, sin redeploy ni reinicio. El módulo nuevo también aparece solo (findByActivoTrue). "
             "Ver GLPI 2632 (docs/soporte-n3/GLPI-2632/03-consumers.md).")
         + "<h3>Tabla del lote</h3>"
         + ul([
             "ABANDONO (1), nro 10: Citación a Turno Médico con prórroga.",
             "ALTAS (3), nro 5: Alta por telemedicina. Adecuada a Res. 20-2026.",
             "ALTAS (3), nro 6: Se revoca alta por dictamen.",
             "ALTAS (3), nro 7: Comunicación resultado de Hipoacusia detectada en exámenes periódicos.",
             "ALTAS (3), nro 8: Suspensión de Tratamiento por afección inculpable.",
             "ALTAS (3), nro 9: Rectificación Alta con incapacidad a sin incapacidad.",
             "MORTALES (nuevo, 'MODULO MORTALES', id 9 por AUTO_INCREMENT), nro 1: Suspensión plazos 298 Derechohabientes. Pedido de documentación.",
             "MORTALES, nro 2: Aceptación 298 Derechohabientes: Solicitud de documentación no recibida.",
             "MORTALES, nro 3: Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades.",
             "MORTALES, nro 4: Rechazo por prescripción (fecha del hecho).",
             "MORTALES, nro 5: Rechazo por prescripción (fecha de la denuncia).",
             "MORTALES, nro 6: Rechazo por falta de datos objetivos: Solicitud de autopsia.",
             "MORTALES, nro 7: Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro.",
             "MORTALES, nro 8: Rechazo mortal-trabajador fuera de nómina.",
             "RECHAZOS (8), nro 19: Rechazo Accidente dentro de su domicilio - No configura in itinere.",
             "RECHAZOS (8), nro 20: Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.",
             "RECHAZOS (8), nro 21: Reversión de rechazo. Caso sin alta. Citación.",
             "RECHAZOS (8), nro 22: Reversión de rechazo. Caso con alta.",
         ])
         + "<h3>Resuelta</h3>"
         + p("La carta de PMI quedó RESUELTA: 'Rechazo PMI anterior a vigencia de Autoseguro' es la misma que 'EP FECHA PMI ANTERIOR VIGENCIA' de GLPI 2632 (definido por la usuaria). "
             "Va solo en 2632 (RECHAZOS 18) y no en este lote.")
         + "<h3>Cartas ambiguas y dudas abiertas (comentadas en el script, no se insertan)</h3>"
         + p("Quedan 4 ambiguas; si se activan se numeran 8, 23, 24 y 25 respectivamente.")
         + ul([
             "Deslinde serológico (OTRAS CITACIONES, nro 8): ya existe en ABANDONO (id 64, nro 9, 18 solicitudes). Confirmar si es otra carta o la misma mal ubicada.",
             "Pluriempleo (RECHAZOS, nro 23): existe id 50, nro 16, 'RECHAZO PLURIEMPLEO' (3 solicitudes). ¿Carta nueva o renombre?",
             "No concurrir a citación (RECHAZOS, nro 24): parecida a id 39, nro 5.",
             "Trayecto IN ITINERE (RECHAZOS, nro 25): parecida a id 38, nro 4.",
         ])
         + "<h3>Marcas '>>>' del script a confirmar antes de ejecutar</h3>"
         + ul([
             ">>> MORTALES: módulo nuevo (no existe hoy) con 8 cartas. Confirmar con Agustín Mesplet que es un módulo y no una carta.",
             ">>> CARTA NUEVA (telemedicina): 'Alta por telemedicina. Adecuada a Res. 20-2026.' se inserta como carta nueva (ALTAS 5) aunque ya existe 'Alta por telemedicina' (ALTAS 4, id 19, 1577 solicitudes). Confirmar que no es un renombre.",
             "'Suspensión plazos 298 Derechohabientes' se escribe sin el punto después de 298, como en el pedido (la carta vieja lo tenía).",
         ])
         + "<h3>Dependencia con GLPI 2632</h3>"
         + p("GLPI 2632 ya está aplicada en PROD (ids 68 y 69), por lo que la dependencia de numeración queda cumplida: OTRAS CITACIONES 7 'Respuesta a Telegrama' y RECHAZOS 18 'EP FECHA PMI ANTERIOR VIGENCIA' están ocupadas. "
             "En RECHAZOS el 17 está inactiva (no se toca), de ahí se numera desde el 19. Orden: este script en bajo y luego PROD (aún pendiente, se aplica otro día). "
             "Verificación con HEX y chequeo de '?' (latin1) incluidos; el rollback chequea uso previo.")
         + "<h3>01-script.sql</h3>" + pre(leer(2883, "01-script.sql"))
         + "<h3>02-rollback.sql</h3>" + pre(leer(2883, "02-rollback.sql")))
    return m, c


def nota_2738() -> tuple[str, str]:
    m = "[DIAGNOSTICO N3 GLPI-2738]"
    plan = leer(2738, "01-plan-fix.md")
    filas = re.findall(r"^\|\s*(\d+(?:-\d+)?)\s*\|\s*([\d, ]+)\|\s*(.+?)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*$", plan, re.M)
    clientes = [f"{n}. {nom} - denuncias totales {tot}, 2026: {y}" for n, _id, nom, tot, y in filas]
    if len(clientes) < 25:
        raise RuntimeError(f"no pude parsear la tabla de clientes de 01-plan-fix.md ({len(clientes)} filas)")
    c = (p(m) + "<h3>Causa raíz</h3>"
         + p("El front resuelve el logo del cliente con un switch cerrado de 14 clientes; el resto devuelve undefined/null "
             "(la cabecera muestra '-' y DatosDenuncia muestra un <img> roto). Los 14 nombres del switch coinciden con "
             "REPLACE(REPLACE(clientes.nombre,' ',''),'.','') en BD: el backend está bien. Faltan logos de ~30 clientes y falta una guardia.")
         + "<h3>Dónde está el problema (hay varias copias del switch)</h3>"
         + ul([
             "CEM usa el repo repos/grvx/frontend/frontend (@grv/frontend, lib 4.23.1) y tiene su PROPIA copia del switch: Utils/icons.js:16-50 (getImage, 14 cases, default null, PNG en commons/assets/LogoCliente/). "
             "El síntoma de Mesa es DatosDenuncia.js:403, un <img> sin guardia. cabeceraCompleta.js:406-407 y Form/Cabecera/cabecera.js:258,472 tienen una guardia que mira nombreLogo y no el resultado de getImage, por eso tampoco protege.",
             "CEM no usa CabeceraDenuncia ni DatosDenuncia de la lib para el logo: la lib no es la causa del síntoma en CEM. Sí lo es para los MFE que usan CabeceraDenuncia de la lib (libreriamodulosgrv, src/utils/utils.tsx y DatosDenuncia.tsx:153).",
             "No existen logos oficiales extra en ningún repo: solo los mismos 14 PNG copiados (CEM, contrataciones, tramitadores, lib; solicitudesgenericas tiene 10 y portalclientes 7).",
             "Alias reutilizables sin logo nuevo: Horizonte INACTIVO, S&H Horizonte y CD Cuentas Gerenciadas Horizonte usan el logo HORIZONTE. Colonia Suiza Salud solo tiene logos corporativos (el legado logo_img .gif no tiene consumidores).",
         ])
         + "<h3>Plan de fix (sin aplicar)</h3>"
         + ul([
             "Frontend CEM (repos/grvx/frontend/frontend, obligatorio): en Utils/icons.js normalizar la clave (sin tildes, mayúsculas, solo A-Z0-9), sumar los logos nuevos y alias de sub-marcas, y poner guardias en DatosDenuncia.js:403, cabeceraCompleta.js:406-407 y cabecera.js:258,472 que miren el resultado de getImage.",
             "contrataciones (mismo patrón): Utils/icons.js y guardia en DatosDenuncia.js:298 (y cabecera.js:218,389-391, CabeceraCompleta.js:341-342).",
             "libreriamodulosgrv (base origin/master 4.23.1, en worktree nuevo): en src/utils/utils.tsx reemplazar el switch por un mapa normalizado con los logos y alias nuevos, assets en src/assets/LogosClientes/ y guardia en DatosDenuncia.tsx:153 (mismo criterio que CabeceraDenuncia.tsx:157-160). Bump 4.23.2, tests/story, lint y typecheck.",
             "MFE que usan CabeceraDenuncia de la lib, solo con bump a 4.23.2: atencioncliente (4.11.0), logistica (4.11.0), auditoriafacturacion (4.18.1), auditoriamedica (4.18.1), mesadecarga (4.18.1), tramitadores (4.23.1). En los de 4.11.0 y 4.18.1 revisar el CHANGELOG de la lib antes (el salto arrastra cambios intermedios). Lint y typecheck en cada uno.",
             "portalclientes (opcional): utils/utils.js:53 tiene solo 7 logos y sus usuarios son ART/aseguradoras; conviene completar.",
             "Recomendación: un solo catálogo compartido en la lib (reutilizar catalogo.json de feature/logos-clientes-portables: agregar un cliente = PNG + una línea) que CEM y contrataciones importen, en vez de mantener tres copias del switch.",
             "Backend: nada obligatorio. Higiene opcional en otro ticket: wsempleador EmpleadorPolizaSearchServiceImpl usa razonSocial en vez de nombre.",
         ])
         + "<h3>Estimación</h3>"
         + p("Revisada a 8 h: tres repos (CEM, contrataciones, lib) más los bumps de los MFE consumidores.")
         + "<h3>Clientes sin logo, por volumen de denuncias</h3>" + ul(clientes)
         + p("Pedido mínimo a Mesa/Comercial (impacto 2026): IAPSER (14.280, más 1.431 de Seguridad e Higiene), GCBA (7.936), Autoseguro Chubut (1.415), "
             "SMG Compañía Argentina de Seguros (413), Consejo de la Magistratura (315), Ministerio Público de la Defensa (195), BAPRO (163). "
             "Confirmar que las sub-marcas usan el logo de la marca madre.")
         + "<h3>Pendientes</h3>"
         + ul([
             "Logos oficiales de Mesa/Comercial (PNG, mismo estilo y tamaño que los existentes).",
             "Ver la pantalla en vivo con una denuncia IAPSER o GCBA en CEM para confirmar el síntoma.",
             "Detalle en docs/soporte-n3/GLPI-2738/01-plan-fix.md y 03-consumers.md.",
         ]))
    return m, c


TAREAS = {209: (2632, nota_2632), 210: (2892, nota_2892), 211: (2738, nota_2738), 212: (2883, nota_2883)}


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
    ap.add_argument("--solo", type=int, help="procesar solo este ticket (2632, 2892, 2738, 2883)")
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

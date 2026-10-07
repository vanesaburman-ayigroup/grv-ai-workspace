"""
glpi_asignar_y_crear_tarea.py — asigna un ticket de GLPI a la usuaria + un grupo y crea la
tarea interna en un proyecto MDA (36 = Nivel 2, 39 = Nivel 3), asociada al ticket.

Stdlib-only. Login por formulario (tooling/lib/glpi.py); cada POST usa un token CSRF nuevo.
ESCRIBE en GLPI: usar primero --dry-run (imprime los payloads, no envía nada).

Uso:
  python tooling/scripts/glpi_asignar_y_crear_tarea.py --ticket 2632 --group "MDA 3" \
      --type back --horas 1 --descripcion "texto" [--project 39] [--estado "MDA- EN CURSO"] \
      [--fecha 2026-10-07] [--dry-run]

Pasos (cada uno idempotente):
  1) asigna: agrega a la usuaria y al grupo como actores 'assign' SIN quitar los existentes.
  2) crea la tarea (si no hay ya una en el kanban del proyecto con "(<ticket>)" en el título).
  3) asocia la tarea al ticket (projecttask_ticket.form.php).
"""
from __future__ import annotations
import argparse
import html
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tooling.lib import glpi  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def csrf(page: str) -> str:
    m = re.search(r'name="_glpi_csrf_token"\s+value="([^"]+)"', page) or \
        re.search(r'_glpi_csrf_token"[^>]*value="([^"]+)"', page)
    if not m:
        raise RuntimeError("no encontré _glpi_csrf_token")
    return m.group(1)


def post(s: glpi.Session, path: str, fields: list[tuple[str, str]]) -> str:
    body = urllib.parse.urlencode(fields).encode("utf-8")
    req = urllib.request.Request(f"{s.base}{path}", data=body, method="POST")
    try:
        with s.opener.open(req, timeout=60) as r:
            return r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"POST {path} -> HTTP {e.code}") from None


def tab(s: glpi.Session, itemtype: str, form: str, tabname: str, id_: int, extra: str = "") -> str:
    return s._get(f"/ajax/common.tabs.php?_target=/front/{form}&_itemtype={itemtype}"
                  f"&_glpi_tab={tabname}&id={id_}{extra}")


def ticket_info(s: glpi.Session, tid: int) -> dict:
    main = tab(s, "Ticket", "ticket.form.php", "Ticket$main", tid)
    page = s.ticket_html(tid)
    t = re.search(r"<title>Ticket - (.*?) - ID \d+", page, re.S)
    title = html.unescape(t.group(1)).strip() if t else ""
    actors = {"requester": [], "observer": [], "assign": []}
    for m in re.finditer(r'<select[^>]*data-actor-type="(\w+)"[^>]*>(.*?)</select>', main, re.S):
        for o in re.finditer(r"<option\s([^>]*)>", m.group(2)):
            a = dict(re.findall(r'data-([\w-]+)="([^"]*)"', o.group(1)))
            if 'selected' not in o.group(1):
                continue
            actors[m.group(1)].append({
                "itemtype": a["itemtype"], "items_id": a["items-id"],
                "use_notification": int(a.get("use-notification", "1")),
                "alternative_email": a.get("alternative-email", ""),
            })
    return {"title": title, "actors": actors, "main": main}


def group_id_by_name(s: glpi.Session, main: str, name: str) -> str:
    # 1) ya es actor del ticket
    for m in re.finditer(r'<option[^>]*value="Group_(\d+)"[^>]*data-text="([^"]*)"', main):
        if html.unescape(m.group(2)).strip() == name:
            return m.group(1)
    # 2) buscar con el mismo endpoint AJAX del selector de actores
    idor = re.search(r"_idor_token:\s*'([0-9a-f]+)'", main).group(1)
    body = urllib.parse.urlencode({
        "action": "getActors", "actortype": "assign", "users_right": "all", "entity_restrict": 0,
        "searchText": name, "_idor_token": idor, "itiltemplate_class": "TicketTemplate",
        "itiltemplates_id": 1, "itemtype": "Ticket", "items_id": 0,
        "returned_itemtypes[]": "Group", "page": 1}).encode()
    req = urllib.request.Request(f"{s.base}/ajax/actors.php", data=body, method="POST",
                                 headers={"X-Requested-With": "XMLHttpRequest",
                                          "X-Glpi-Csrf-Token": csrf(main)})
    raw = s.opener.open(req, timeout=30).read().decode("utf-8", "replace")
    data = json.loads(raw)
    found = []

    def walk(n):
        if isinstance(n, dict):
            if n.get("itemtype") == "Group" and "items_id" in n:
                found.append((str(n["items_id"]), n.get("text", "")))
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)
    walk(data)
    exact = [i for i, t in found if html.unescape(t).strip().endswith(name)]
    if len(exact) != 1:
        raise RuntimeError(f"grupo {name!r}: candidatos ambiguos o ninguno: {found}")
    return exact[0]


def asignar(s, tid, uid, gid_name, dry):
    info = ticket_info(s, tid)
    gid = group_id_by_name(s, info["main"], gid_name)
    actors = info["actors"]
    for itemtype, iid in (("User", uid), ("Group", gid)):
        if not any(a["itemtype"] == itemtype and a["items_id"] == iid for a in actors["assign"]):
            actors["assign"].append({"itemtype": itemtype, "items_id": iid,
                                     "use_notification": 1 if itemtype == "User" else 0,
                                     "alternative_email": ""})
    fields = [("id", str(tid)), ("_actors", json.dumps(actors)), ("update", "1"),
              ("_glpi_csrf_token", csrf(info["main"]))]
    print(f"[ticket {tid}] titulo={info['title']!r} grupo {gid_name!r}=Group_{gid} usuaria=User_{uid}")
    print(f"[ticket {tid}] payload actores: {json.dumps(actors)}")
    if dry:
        return info
    post(s, f"/front/ticket.form.php?id={tid}", fields)
    return info


def buscar_tarea(s, project, tid):
    for col in s.kanban(project).values():
        for it in (col.get("items") or {}).values():
            t = re.sub(r"<[^>]+>", "", it.get("title", ""))
            if re.search(rf"\({tid}\)\s*$", t.strip()):
                return int(str(it["id"]).partition("-")[2]), t
    return None


def estado_id(s, project, nombre):
    for cid, col in s.kanban(project).items():
        if (col.get("name") or "").strip() == nombre.strip():
            return cid
    raise RuntimeError(f"estado {nombre!r} no existe en el kanban del proyecto {project}")


def crear_tarea(s, a, uid, titulo, dry):
    dup = buscar_tarea(s, a.project, a.ticket)
    if dup:
        print(f"[tarea] ya existe para {a.ticket}: id={dup[0]} {dup[1]!r} -> no se crea otra")
        return dup[0]
    form = tab(s, "ProjectTask", "projecttask.form.php", "ProjectTask$main", 0, f"&projects_id={a.project}")
    f = form[form.find('<form id="project_task_'):]
    desc = "".join(f"<p>{html.escape(p, quote=False)}</p>" for p in a.descripcion.split("\n") if p.strip())
    fields = [
        ("entities_id", "0"), ("projecttasktemplates_id", "0"), ("projects_id", str(a.project)),
        ("is_recursive", "0"), ("projecttasks_id", "0"), ("name", titulo),
        ("projecttasktypes_id", "0"), ("projectstates_id", estado_id(s, a.project, a.estado)),
        ("auto_projectstates", "0"), ("percent_done", "0"), ("auto_percent_done", "0"),
        ("is_milestone", "0"), ("teammember_list", ""), ("teammember_list[]", f"User_{uid}"),
        ("plan_start_date", f"{a.fecha} 08:00:00"), ("plan_end_date", f"{a.fecha} 18:00:00"),
        ("planned_duration", str(int(a.horas * 3600))), ("effective_duration", "0"),
        ("content", desc), ("comment", ""), ("add", "1"), ("_glpi_csrf_token", csrf(f)),
    ]
    print("[tarea] payload:", json.dumps([(k, v) for k, v in fields if k != "_glpi_csrf_token"],
                                          ensure_ascii=False))
    if dry:
        return None
    post(s, "/front/projecttask.form.php", fields)
    got = buscar_tarea(s, a.project, a.ticket)
    if not got:
        raise RuntimeError("la tarea no aparece en el kanban tras crearla; revisar a mano")
    print(f"[tarea] creada id={got[0]}")
    return got[0]


def asociar(s, task_id, tid, dry):
    page = tab(s, "ProjectTask", "projecttask.form.php", "ProjectTask_Ticket$1", task_id)
    if re.search(rf"ticket\.form\.php\?id={tid}\b", page):
        print(f"[asoc] la tarea {task_id} ya tiene el ticket {tid}")
        return
    fields = [("projecttasks_id", str(task_id)), ("tickets_id", str(tid)), ("add", "1"),
              ("_glpi_csrf_token", csrf(page))]
    print("[asoc] payload:", [(k, v) for k, v in fields if k != "_glpi_csrf_token"])
    if not dry:
        post(s, "/front/projecttask_ticket.form.php", fields)


def equipo(s, task_id, uid, dry):
    """Agrega a la usuaria como miembro del equipo de la tarea (teammember_list no persiste en el add)."""
    page = tab(s, "ProjectTask", "projecttask.form.php", "ProjectTaskTeam$1", task_id)
    if re.search(rf"user\.form\.php\?id={uid}", page):
        print(f"[equipo] la usuaria ya es miembro de la tarea {task_id}")
        return
    fields = [("projecttasks_id", str(task_id)), ("itemtype", "User"), ("items_id", str(uid)),
              ("add", "1"), ("_glpi_csrf_token", csrf(page))]
    print("[equipo] payload:", [(k, v) for k, v in fields if k != "_glpi_csrf_token"])
    if not dry:
        post(s, "/front/projecttaskteam.form.php", fields)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ticket", type=int, required=True)
    p.add_argument("--group", default="MDA 3")
    p.add_argument("--type", choices=["back", "front"], required=True)
    p.add_argument("--horas", type=float, required=True)
    p.add_argument("--descripcion", required=True)
    p.add_argument("--project", type=int, default=39)
    p.add_argument("--estado", default="MDA- EN CURSO")
    p.add_argument("--fecha", default="2026-10-07")
    p.add_argument("--user-id", required=True, help="id GLPI de la usuaria (dueña de GLPI_USER)")
    p.add_argument("--solo-ticket", action="store_true")
    p.add_argument("--solo-tarea", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()
    s = glpi.Session()
    uid = str(a.user_id)
    info = None
    if not a.solo_tarea:
        info = asignar(s, a.ticket, uid, a.group, a.dry_run)
    if not a.solo_ticket:
        info = info or ticket_info(s, a.ticket)
        titulo = f"[BUG]{{{a.type}}} {info['title']} ({a.ticket})"
        tid = crear_tarea(s, a, uid, titulo, a.dry_run)
        if tid:
            asociar(s, tid, a.ticket, a.dry_run)
            equipo(s, tid, uid, a.dry_run)
            print(f"URL tarea: {s.base}/front/projecttask.form.php?id={tid}")
    print(f"URL ticket: {s.base}/front/ticket.form.php?id={a.ticket}")


if __name__ == "__main__":
    main()

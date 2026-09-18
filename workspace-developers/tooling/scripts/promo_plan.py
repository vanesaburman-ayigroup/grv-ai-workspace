"""
promo_plan.py — plan de promoción quirúrgica de un ticket entre ramas (develop → release → stage → master).
Trabaja sobre los repos clonados en repos/grvx/ con git. Stdlib-only.

Por cada repo que toca el ticket:
  A. Commits del ticket (desde las MRs del tracker): mergeados en la rama origen o, si la MR sigue
     abierta, desde su rama fuente (cherry-pick anticipado, marcado como tal).
  B. Commits INTERCALADOS de terceros que están en origen y no en destino, con qué archivos tocan,
     a qué ticket pertenecen y si ese ticket está aprobado según el tracker. Los que tocan los mismos
     archivos que el ticket son riesgo de conflicto o de pisado silencioso.
  C. Dry-run del cherry-pick en un worktree temporal sobre el destino, en el orden original: aplica
     limpio / conflictúa en qué archivos; y qué archivos del ticket quedarían distintos a la rama origen.
  D. Las dos opciones, con recomendación:
       1) Cherry-pick a una rama promo/<TICKET>-a-<destino> (comandos exactos).
       2) Promover la rama completa (origen → destino) — viable sólo si todo lo intercalado está aprobado.
  E. SQL del ticket que hay que aplicar en el ambiente destino.

Salidas: prs/reviews/promo/<TICKET>-a-<destino>.md + .json, y el campo promo_plan[<destino>] en el tracker
de cada MR del ticket (lo muestran el Excel y el dashboard).

Uso:
    python tooling/scripts/promo_plan.py GRV-2328 --to test          # test == rama release
    python tooling/scripts/promo_plan.py GRV-2182 --to stage --from release
    python tooling/scripts/promo_plan.py GRV-2328 --to prod --no-fetch
"""

from __future__ import annotations
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from collections import defaultdict
from datetime import date, datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import env  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

TRACKER_PATH = env.REVIEWS_DIR / "tracker.json"
OUT_DIR = env.REVIEWS_DIR / "promo"
_TICKET_RE = re.compile(r"\b([A-Z]{2,10}-\d{1,6})\b")


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def git(repo: Path, *args: str, check: bool = True) -> str:
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} -> {r.stderr.strip()[:300]}")
    return r.stdout.strip()


def git_ok(repo: Path, *args: str) -> bool:
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True).returncode == 0


def resolve_branch(name: str) -> str:
    return env.PROMO_BRANCHES.get(name.lower(), name)


def previous_branch(to_branch: str) -> str:
    if to_branch in env.PROMO_ORDER and env.PROMO_ORDER.index(to_branch) > 0:
        return env.PROMO_ORDER[env.PROMO_ORDER.index(to_branch) - 1]
    return "develop"


def ticket_readiness(tracker: dict, ticket: str) -> str:
    mrs = [m for m in tracker["mrs"].values() if m.get("ticket") == ticket or ticket in (m.get("tickets") or [])]
    if not mrs:
        return "no está en mi tracker"
    if all(m["state"] == "merged" and m.get("verdict") == "Approve" for m in mrs):
        return "aprobado y mergeado"
    if all(m["state"] == "merged" for m in mrs):
        return "mergeado sin veredicto Approve mío"
    return "con MRs abiertas"


def commit_files(repo: Path, sha: str) -> list[str]:
    out = git(repo, "show", "--pretty=format:", "--name-only", "-m", "--first-parent", sha)
    return sorted({ln.strip() for ln in out.splitlines() if ln.strip()})


def is_merge(repo: Path, sha: str) -> bool:
    return len(git(repo, "rev-list", "--parents", "-n", "1", sha).split()) > 2


def ya_aplicado_por_contenido(repo: Path, sha: str, to_b: str) -> bool:
    """
    Si el CONTENIDO de `sha` ya está en `to_b`, aunque con otro SHA.

    `merge-base --is-ancestor` sólo ve ancestría, así que un commit que llegó al destino por un
    cherry-pick anterior figura como ausente y se vuelve a proponer. `git cherry` compara por
    patch-id (el hash del diff, sin contexto de posición), que es lo que identifica al mismo
    cambio aplicado dos veces: marca `-` lo ya aplicado y `+` lo genuinamente nuevo.

    Los merge commits no tienen patch-id util, así que para ellos se devuelve False y decide la
    ancestría.
    """
    if is_merge(repo, sha):
        return False
    try:
        out = git(repo, "cherry", f"origin/{to_b}", sha, f"{sha}^")
    except RuntimeError:
        return False
    return out.strip().startswith("-")


def plan_repo(repo: Path, project: str, mrs: list[dict], from_b: str, to_b: str, tracker: dict, fetch: bool) -> dict:
    res: dict = {"project": project, "repo": str(repo), "from": from_b, "to": to_b, "warnings": []}
    if fetch:
        refs = [from_b, to_b] + [m["source_branch"] for m in mrs if m["state"] == "opened"]
        r = subprocess.run(["git", "-C", str(repo), "fetch", "--quiet", "origin", *refs], capture_output=True, text=True)
        if r.returncode != 0:
            res["warnings"].append(f"fetch falló ({r.stderr.strip()[:120]}); uso las refs locales")
    for b in (from_b, to_b):
        if not git_ok(repo, "rev-parse", "--verify", f"origin/{b}"):
            res["error"] = f"no existe origin/{b} en {project}"
            return res

    # A. commits del ticket
    ticket_commits: list[dict] = []
    for m in sorted(mrs, key=lambda x: (x.get("merged_at") or "9999", x["iid"])):
        merged_in_from = bool(m.get("merge_commit_sha")) and git_ok(repo, "merge-base", "--is-ancestor", m["merge_commit_sha"], f"origin/{from_b}")
        for c in m.get("commits") or []:
            sha = c["sha"]
            if not git_ok(repo, "cat-file", "-e", f"{sha}^{{commit}}"):
                res["warnings"].append(f"{m['project']}!{m['iid']}: commit {sha[:8]} no está en el clon (¿squash/rebase? ¿falta fetch?)")
                continue
            in_from = git_ok(repo, "merge-base", "--is-ancestor", sha, f"origin/{from_b}")
            in_to = git_ok(repo, "merge-base", "--is-ancestor", sha, f"origin/{to_b}")
            ticket_commits.append({
                "sha": sha, "short": sha[:8], "title": c.get("title", ""), "author": c.get("author", ""), "date": c.get("date", ""),
                "mr": f"{m['project']}!{m['iid']}", "mr_state": m["state"], "in_from": in_from, "in_to": in_to,
                "files": commit_files(repo, sha), "merge": is_merge(repo, sha),
            })
        if m["state"] == "merged" and m.get("merge_commit_sha") and not any(c["in_from"] for c in ticket_commits if c["mr"] == f"{m['project']}!{m['iid']}"):
            # merge con squash: los commits originales no están en develop, el merge commit sí
            mc = m["merge_commit_sha"]
            if git_ok(repo, "cat-file", "-e", f"{mc}^{{commit}}"):
                ticket_commits.append({"sha": mc, "short": mc[:8], "title": f"(merge/squash de !{m['iid']})", "author": m.get("author", ""), "date": m.get("merged_at", ""),
                                       "mr": f"{m['project']}!{m['iid']}", "mr_state": m["state"], "in_from": merged_in_from,
                                       "in_to": git_ok(repo, "merge-base", "--is-ancestor", mc, f"origin/{to_b}"), "files": commit_files(repo, mc), "merge": is_merge(repo, mc)})
    # orden original: topológico según la rama donde viven
    order = {}
    for ref in [f"origin/{from_b}"] + [f"origin/{m['source_branch']}" for m in mrs if m["state"] == "opened"]:
        if git_ok(repo, "rev-parse", "--verify", ref):
            for i, sha in enumerate(git(repo, "rev-list", "--reverse", f"origin/{to_b}..{ref}").splitlines()):
                order.setdefault(sha, i)
    ticket_commits.sort(key=lambda c: order.get(c["sha"], 10**6))
    # Lo ya promovido por cherry-pick tiene otro SHA en el destino: sin el chequeo por patch-id se
    # vuelve a proponer y el plan pide re-aplicar algo que ya está.
    for c in ticket_commits:
        if not c["in_to"] and ya_aplicado_por_contenido(repo, c["sha"], to_b):
            c["in_to"] = True
            c["equivalente_en_destino"] = True
    pending = [c for c in ticket_commits if not c["in_to"]]
    ticket_files = sorted({f for c in pending for f in c["files"]})
    ya_por_contenido = [c["short"] for c in ticket_commits if c.get("equivalente_en_destino")]
    res.update({"ticket_commits": ticket_commits, "pending_commits": pending, "already_in_to": [c["short"] for c in ticket_commits if c["in_to"]],
                "ya_aplicados_por_contenido": ya_por_contenido,
                "anticipado": [c["mr"] for c in pending if c["mr_state"] == "opened"], "ticket_files": ticket_files})
    if ya_por_contenido:
        res["warnings"].append(
            f"{len(ya_por_contenido)} commit(s) ya están en {to_b} con OTRO sha (llegaron por cherry-pick): "
            f"{', '.join(ya_por_contenido[:6])}. No se vuelven a promover.")
    if not pending:
        res["nota"] = f"Todos los commits del ticket ya están en origin/{to_b}."

    # B. intercalados de terceros en origen y no en destino
    ticket_shas = {c["sha"] for c in ticket_commits}
    mr_merge_shas = {m.get("merge_commit_sha") for m in mrs if m.get("merge_commit_sha")}
    foreign: list[dict] = []
    same_ticket_untracked: list[dict] = []
    this_ticket = (mrs[0].get("ticket") or "").upper()
    log = git(repo, "log", "--reverse", "--format=%H%x1f%an%x1f%ad%x1f%s", "--date=short", f"origin/{to_b}..origin/{from_b}")
    for ln in log.splitlines():
        sha, author, d, subject = (ln.split("\x1f") + ["", "", ""])[:4]
        if sha in ticket_shas or sha in mr_merge_shas:
            continue
        files = commit_files(repo, sha)
        overlap = sorted(set(files) & set(ticket_files))
        tk = _TICKET_RE.search(subject.upper())   # también atrapa 'fix/grv-2328-...' en los merges
        tkt = tk.group(1) if tk else ""
        entry = {"sha": sha, "short": sha[:8], "author": author, "date": d, "title": subject, "ticket": tkt,
                 "files": files, "overlap": overlap, "merge": is_merge(repo, sha)}
        if this_ticket and tkt == this_ticket:
            same_ticket_untracked.append(entry)   # mismo ticket, pero en una MR que no está en mi tracker (ej. !505)
        else:
            foreign.append(entry)
    res["same_ticket_untracked"] = same_ticket_untracked
    if same_ticket_untracked:
        res["warnings"].append(
            f"{len(same_ticket_untracked)} commit(s) de {this_ticket} en {from_b} que NO vienen de las MRs trackeadas "
            f"({', '.join(c['short'] for c in same_ticket_untracked[:4])}): decidir si van en la promoción o ya están superados.")
    by_ticket: dict[str, dict] = {}
    for f in foreign:
        k = f["ticket"] or "(sin ticket)"
        e = by_ticket.setdefault(k, {"ticket": k, "commits": 0, "con_riesgo": 0, "autores": set(), "estado": ticket_readiness(tracker, k) if f["ticket"] else "sin ticket en el mensaje"})
        e["commits"] += 1
        e["con_riesgo"] += 1 if f["overlap"] else 0
        e["autores"].add(f["author"])
    for e in by_ticket.values():
        e["autores"] = sorted(e["autores"])
    res.update({"foreign": foreign, "foreign_by_ticket": list(by_ticket.values()),
                "foreign_risk": [f for f in foreign if f["overlap"]]})

    # C. dry-run del cherry-pick en worktree temporal
    dry: dict = {"status": "no_probado", "applied": [], "conflict": None, "conflict_files": [], "differs_from_source": []}
    if pending:
        tmp = Path(tempfile.mkdtemp(prefix=f"promo-{project}-"))
        try:
            git(repo, "worktree", "add", "--detach", str(tmp), f"origin/{to_b}")
            wt = tmp
            git(wt, "config", "user.email", "promo-plan@local")
            git(wt, "config", "user.name", "promo-plan")
            for c in pending:
                args = ["cherry-pick", "-x"] + (["-m", "1"] if c["merge"] else []) + [c["sha"]]
                r = subprocess.run(["git", "-C", str(wt), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
                if r.returncode != 0:
                    files_u = git(wt, "diff", "--name-only", "--diff-filter=U", check=False)
                    dry.update({"status": "conflicto", "conflict": c["short"], "conflict_files": files_u.splitlines(),
                                "conflict_msg": (r.stderr or r.stdout).strip()[:400]})
                    subprocess.run(["git", "-C", str(wt), "cherry-pick", "--abort"], capture_output=True)
                    break
                dry["applied"].append(c["short"])
            else:
                dry["status"] = "ok"
                if ticket_files:
                    diff = git(wt, "diff", "--name-status", "HEAD", f"origin/{from_b}", "--", *ticket_files, check=False)
                    dry["differs_from_source"] = [ln.split("\t", 1)[-1] for ln in diff.splitlines() if ln.strip()]
        except RuntimeError as e:
            dry.update({"status": "error", "conflict_msg": str(e)[:300]})
        finally:
            subprocess.run(["git", "-C", str(repo), "worktree", "remove", "--force", str(tmp)], capture_output=True)
            shutil.rmtree(tmp, ignore_errors=True)
    res["dry_run"] = dry

    # D. opciones
    ticket_id = mrs[0].get("ticket") or project
    promo_branch = f"promo/{ticket_id}-a-{to_b}".replace("(sin ticket)", project)
    picks = " ".join(c["sha"] for c in pending)
    repo_path = f"repos/grvx/{mrs[0]['group']}/{project}"
    # Un solo commit por promoción: N cherry-picks dejan N commits con sha nuevo en el destino, y
    # cada uno vuelve a figurar en el `develop -> release` de cualquier otro, que ve commits ajenos
    # que ya están aplicados. `-n` aplica todo sin commitear y se cierra con un commit unico.
    msg = f"promo({ticket_id}): {len(pending)} commit(s) de {from_b} a {to_b}"
    res["opcion_cherry_pick"] = {
        "rama": promo_branch,
        "comandos": [
            f"git -C {repo_path} fetch origin {from_b} {to_b}",
            f"git -C {repo_path} checkout -b {promo_branch} origin/{to_b}",
            f"git -C {repo_path} cherry-pick -x -n {picks}" if picks else "# nada que cherry-pickear",
            f'git -C {repo_path} commit -m "{msg}"' if picks else "",
            f"git -C {repo_path} push -u origin {promo_branch}",
            f"# abrir MR {promo_branch} -> {to_b} en GitLab (grvx/{mrs[0]['group']}/{project})",
        ],
        "commits_squasheados": len(pending),
        "viable": dry["status"] == "ok",
    }
    res["opcion_cherry_pick"]["comandos"] = [c for c in res["opcion_cherry_pick"]["comandos"] if c]
    foreign_not_ready = [e for e in by_ticket.values() if e["estado"] not in ("aprobado y mergeado",)]
    res["opcion_rama_completa"] = {
        "comandos": [f"git -C repos/grvx/{mrs[0]['group']}/{project} checkout -b promo/{from_b}-a-{to_b}-{date.today().strftime('%Y%m%d')} origin/{from_b}",
                     f"git -C repos/grvx/{mrs[0]['group']}/{project} push -u origin promo/{from_b}-a-{to_b}-{date.today().strftime('%Y%m%d')}",
                     f"# abrir MR promo/{from_b}-a-{to_b}-... -> {to_b}: arrastra {len(foreign)} commit(s) de terceros"],
        "arrastra": len(foreign),
        "tickets_no_listos": [e["ticket"] for e in foreign_not_ready],
        "viable": not foreign_not_ready,
    }
    # recomendación
    if not pending:
        rec = "Nada que promover: el ticket ya está en el destino."
    elif res["opcion_rama_completa"]["viable"] and foreign:
        rec = f"Promover la rama completa: todo lo intercalado ({len(foreign)} commits) está aprobado y mergeado; evita cherry-picks y mantiene la historia igual a {from_b}."
    elif not foreign:
        rec = f"Cualquiera de las dos: no hay commits de terceros entre {to_b} y {from_b}. La rama completa es más simple."
    elif dry["status"] == "ok" and not res["foreign_risk"]:
        rec = f"Cherry-pick a `{promo_branch}`: aplica limpio y ningún commit ajeno toca los archivos del ticket. La rama completa arrastraría {len(foreign)} commit(s) de {', '.join(res['opcion_rama_completa']['tickets_no_listos'])} que no están listos."
    elif dry["status"] == "ok" and res["foreign_risk"]:
        rec = (f"Cherry-pick aplica limpio PERO {len(res['foreign_risk'])} commit(s) ajenos tocan los mismos archivos ({', '.join(sorted({f for x in res['foreign_risk'] for f in x['overlap']})[:4])}). "
               f"Revisar a mano que el resultado en {to_b} no pierda nada (ver 'archivos distintos a {from_b}'): es exactamente cómo se perdió la !505.")
    elif dry["status"] == "conflicto":
        rec = (f"El cherry-pick conflictúa en {dry['conflict']} ({', '.join(dry['conflict_files'][:3])}). Opciones: resolver el conflicto en la rama promo, "
               f"o esperar a que se aprueben {', '.join(res['opcion_rama_completa']['tickets_no_listos']) or 'los tickets intercalados'} y promover la rama completa.")
    else:
        rec = "No pude probar el cherry-pick (ver dry_run.conflict_msg)."
    res["recomendacion"] = rec
    return res


def render_md(ticket: str, from_b: str, to_b: str, repos: list[dict], sqls: list[tuple[str, str]]) -> str:
    L = [f"# Plan de promoción {ticket}: `{from_b}` → `{to_b}`", "",
         f"_Generado {date.today().isoformat()} por `promo_plan.py` sobre `repos/grvx/`. Ambientes: {', '.join(f'{k}={v}' for k, v in env.PROMO_BRANCHES.items())}._", ""]
    for r in repos:
        L += [f"## {r['project']}", ""]
        if r.get("error"):
            L += [f"❌ {r['error']}", ""]
            continue
        for w in r["warnings"]:
            L.append(f"> ⚠️ {w}")
        if r.get("nota"):
            L += [f"✅ {r['nota']}", ""]
        L += [f"**Recomendación:** {r['recomendacion']}", ""]
        L += [f"### Commits del ticket pendientes en `{to_b}` ({len(r['pending_commits'])})", ""]
        if r["pending_commits"]:
            L += ["| # | SHA | MR | Título | Autor | Fecha | Estado |", "|---|---|---|---|---|---|---|"]
            for i, c in enumerate(r["pending_commits"], 1):
                st = "mergeado en " + from_b if c["in_from"] else ("**MR abierta — cherry-pick anticipado**" if c["mr_state"] == "opened" else "no está en " + from_b)
                L.append(f"| {i} | `{c['short']}` | {c['mr']} | {c['title'][:70].replace('|', '/')} | {c['author']} | {c['date'][:10]} | {st} |")
        else:
            L.append("_ninguno_")
        if r["already_in_to"]:
            L += ["", f"Ya en `{to_b}`: {', '.join(f'`{s}`' for s in r['already_in_to'])}"]
        if r.get("same_ticket_untracked"):
            L += ["", f"### ⚠️ Commits del mismo ticket en `{from_b}` que no vienen de mis MRs ({len(r['same_ticket_untracked'])})", "",
                  "Decidir si entran en la promoción (agregarlos al cherry-pick) o si las MRs actuales ya los superan.", ""]
            L += [f"- `{c['short']}` {c['title'][:70]} — {c['author']} {c['date']}{' — toca archivos del ticket' if c['overlap'] else ''}" for c in r["same_ticket_untracked"]]
        L += ["", f"### Commits de terceros intercalados en `{from_b}` y no en `{to_b}` ({len(r['foreign'])})", ""]
        if r["foreign_by_ticket"]:
            L += ["| Ticket | Commits | Tocan archivos del ticket | Estado en mi tracker | Autores |", "|---|---|---|---|---|"]
            for e in sorted(r["foreign_by_ticket"], key=lambda x: -x["con_riesgo"]):
                L.append(f"| {e['ticket']} | {e['commits']} | {'⚠️ ' + str(e['con_riesgo']) if e['con_riesgo'] else '—'} | {e['estado']} | {', '.join(e['autores'])} |")
            if r["foreign_risk"]:
                L += ["", "**Riesgo de conflicto / pisado silencioso:**", ""]
                for f in r["foreign_risk"]:
                    L.append(f"- `{f['short']}` {f['ticket'] or ''} {f['title'][:60]} — {', '.join(f['overlap'])}")
        else:
            L.append("_ninguno — el destino sólo recibiría este ticket_")
        d = r["dry_run"]
        L += ["", f"### Dry-run del cherry-pick sobre `origin/{to_b}`", ""]
        if d["status"] == "ok":
            L.append(f"✅ Aplica limpio ({len(d['applied'])} commits).")
            if d["differs_from_source"]:
                L.append(f"⚠️ Archivos del ticket que quedarían distintos a `{from_b}` (cambios ajenos intercalados; verificar que no falte nada): {', '.join(f'`{x}`' for x in d['differs_from_source'])}")
            else:
                L.append(f"Los archivos del ticket quedan idénticos a `{from_b}`.")
        elif d["status"] == "conflicto":
            L += [f"❌ Conflicto en `{d['conflict']}`: {', '.join(d['conflict_files']) or '(ver mensaje)'}", "", "```", d.get("conflict_msg", ""), "```"]
        else:
            L.append(f"— {d['status']}: {d.get('conflict_msg', '')}")
        L += ["", "### Opción 1 — cherry-pick quirúrgico", "", "```bash", *r["opcion_cherry_pick"]["comandos"], "```", "",
              "### Opción 2 — promover la rama completa", "",
              f"Arrastra **{r['opcion_rama_completa']['arrastra']}** commit(s) de terceros. " +
              ("✅ Viable: todo lo intercalado está aprobado y mergeado." if r["opcion_rama_completa"]["viable"] else
               f"⛔ No recomendable hoy: {', '.join(r['opcion_rama_completa']['tickets_no_listos'])} no están listos."),
              "", "```bash", *r["opcion_rama_completa"]["comandos"], "```", ""]
    if sqls:
        L += [f"## SQL a aplicar en el ambiente de `{to_b}`", ""]
        L += [f"- `{p}` ({proj})" for proj, p in sqls]
        L += ["", "Aplicar ANTES del deploy si el código nuevo los necesita; registrar en el Excel (`SQL aplicado`).", ""]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ticket", help="ticket (GRV-2328) o key/proyecto!iid de una MR")
    ap.add_argument("--to", required=True, help="ambiente (dev|test|stage|prod) o rama destino")
    ap.add_argument("--from", dest="from_", help="rama origen (default: la anterior en la cadena)")
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--json", action="store_true", help="imprimir el JSON completo al final")
    args = ap.parse_args()

    if not TRACKER_PATH.exists():
        print(f"!! no existe {TRACKER_PATH}; corré refresh_my_reviews.py"); return 2
    tracker = json.loads(TRACKER_PATH.read_text(encoding="utf-8"))
    to_b = resolve_branch(args.to)
    from_b = resolve_branch(args.from_) if args.from_ else previous_branch(to_b)

    mrs_all = tracker["mrs"]
    sel = [m for m in mrs_all.values() if m.get("ticket") == args.ticket or args.ticket in (m.get("tickets") or [])
           or m["key"] == args.ticket or f"{m['project']}!{m['iid']}" == args.ticket]
    if not sel:
        print(f"!! no hay MRs de {args.ticket} en el tracker"); return 2
    ticket = sel[0].get("ticket") or args.ticket

    by_project: dict[str, list[dict]] = defaultdict(list)
    for m in sel:
        by_project[m["project"]].append(m)
    repos_out = []
    for project, mrs in by_project.items():
        repo = env.REPOS_DIR / "grvx" / mrs[0]["group"] / project
        if not (repo / ".git").exists():
            repos_out.append({"project": project, "error": f"repo no clonado en {repo} — corré /sync-repos {mrs[0]['group']}", "warnings": []})
            continue
        print(f"[{project}] {len(mrs)} MR(s) · {from_b} -> {to_b} ...")
        repos_out.append(plan_repo(repo, project, mrs, from_b, to_b, tracker, fetch=not args.no_fetch))
    sqls = [(m["project"], p) for m in sel for p in m.get("sql_files") or []]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stem = OUT_DIR / f"{ticket}-a-{to_b}"
    md = render_md(ticket, from_b, to_b, repos_out, sqls)
    stem.with_suffix(".md").write_text(md, encoding="utf-8")
    payload = {"ticket": ticket, "from": from_b, "to": to_b, "generated_at": _now(), "repos": repos_out, "sql": [{"project": p, "file": f} for p, f in sqls]}
    stem.with_suffix(".json").write_text(json.dumps(payload, ensure_ascii=False, indent=1, default=list), encoding="utf-8")

    # resumen al tracker
    for m in sel:
        r = next((x for x in repos_out if x["project"] == m["project"]), {})
        m.setdefault("promo_plan", {})
        m["promo_plan"][to_b] = {
            "fecha": date.today().isoformat(), "from": from_b, "to": to_b,
            "cherry_pick": (r.get("dry_run") or {}).get("status", "error" if r.get("error") else "no_probado"),
            "conflictos": (r.get("dry_run") or {}).get("conflict_files", []),
            "distintos_a_origen": (r.get("dry_run") or {}).get("differs_from_source", []),
            "pendientes": len(r.get("pending_commits") or []),
            "anticipado": bool(r.get("anticipado")),
            "intercalados": len(r.get("foreign") or []),
            "intercalados_riesgo": len(r.get("foreign_risk") or []),
            "mismo_ticket_no_trackeados": [c["short"] for c in r.get("same_ticket_untracked") or []],
            "tickets_no_listos": (r.get("opcion_rama_completa") or {}).get("tickets_no_listos", []),
            "rama_completa_viable": (r.get("opcion_rama_completa") or {}).get("viable", False),
            "rama_promo": (r.get("opcion_cherry_pick") or {}).get("rama", ""),
            "recomendacion": r.get("recomendacion") or r.get("error", ""),
            "reporte": str(stem.with_suffix(".md").relative_to(env.PROJECT_ROOT)).replace("\\", "/"),
        }
    TRACKER_PATH.write_text(json.dumps(tracker, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"\n-> {stem.with_suffix('.md').relative_to(env.PROJECT_ROOT)}")
    for r in repos_out:
        print(f"[{r['project']}] {r.get('recomendacion') or r.get('error')}")
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=1, default=list))
    return 0


if __name__ == "__main__":
    sys.exit(main())

---
name: mis-reviews
description: >-
  Centro de seguimiento intensivo de las MRs de GitLab donde la usuaria figura como REVIEWER.
  Trae y mantiene al día las MRs asignadas, orquesta por cada una la review completa
  (spring-boot-review / react-mfe-review / mariadb-migration-review según lo tocado, consumers-of
  SIEMPRE sobre endpoints/tablas/SPs, cruce con Jira, verificación adversarial de bloqueantes),
  genera los comentarios listos para GitLab, y mantiene el Excel de seguimiento en Google Drive
  (SOPORTE N2 / N3) con MRs, observaciones, commits, SQL, asignaciones y el checklist por ticket
  para mergear/promover sin que falte ningún commit, servicio, front ni SQL. Disparadores
  "/mis-reviews", "actualizá mis reviews", "qué MRs tengo para revisar", "revisá todo lo que tengo
  asignado", "armá el tracker de MRs", "qué me falta promover del ticket X".
---

# mis-reviews

Orquestador de reviews + tracker de promociones para la revisora técnica del SAS. Tres piezas:

1. **Refresh** (`tooling/scripts/refresh_my_reviews.py`, stdlib) — MRs donde soy reviewer → stubs en `prs/<group>/` + `prs/reviews/tracker.json` (clasificación regex: kinds, SQL, tablas, SPs, endpoints, properties, smells, solapamientos, commits, Jira).
2. **Review orquestada** (`workflow.js` en esta carpeta + `tooling/prompts/mr_review_orchestrated.md`) — por MR: especialistas por kind ∥ `consumers-of` ∥ Jira → verificación adversarial de 🔴 → consolidador escribe Findings/Verdict en el stub, `.review-comment.md` y actualiza el tracker con las observaciones.
3. **Excel en Drive** (`scripts/build_tracker_xlsx.py`, openpyxl) — `<REVIEWS_DRIVE_DIR>/SOPORTE N2|N3/Tracker-MRs-<nivel>.xlsx` + carpeta por ticket. Las columnas ✏ (amarillas) que edites a mano vuelven al tracker en la próxima corrida.

Postear a GitLab **nunca** es automático: sigue siendo `/post-pr-comment <stub>` por MR.

## Invocación

```
/mis-reviews                      # refresh + review de todo lo pendiente + Excel
/mis-reviews --solo-tracker       # sólo refresh + Excel (rápido, sin agentes) — ideal para /loop
/mis-reviews --mr wsdocumento!1396    # revisar una sola (acepta key, "proyecto!iid" o URL)
/mis-reviews --incluir-drafts     # también MRs Draft/WIP
/mis-reviews --role both          # reviewer + assignee
/mis-reviews --forzar             # re-revisar aunque ya estén revisadas (mismo sha)
/mis-reviews --ticket GRV-2182    # estado de promoción de un ticket (lee el tracker, no corre agentes)
/mis-reviews --equipo             # tickets "pendiente de MR" (Jira + GLPI) de todo el equipo, no sólo los míos
/mis-reviews --equipo --people "Carla Debernardi,Alejandro Minue"   # subconjunto de gente
```

## Procedimiento

### 1. Refresh del tracker

```bash
python tooling/scripts/refresh_my_reviews.py --json [--include-drafts] [--role both]
```

Leer la salida: cuántas MRs, cuáles son `new`/`changed`, cuántas `pendiente`/`re-review`, y el bloque `===PENDING_JSON===` (fichas de las pendientes). Si falla por token → ver Troubleshooting del CLAUDE.md. Si `repos/grvx/` no existe, avisar que `consumers-of` va a quedar sin datos y sugerir `/sync-repos` (no bloquear).

Con `--solo-tracker` saltar al paso 4. Con `--ticket X` saltar al paso 5.

### 2. Seleccionar qué revisar

Pendientes = `state == opened` y `review_status ∈ {pendiente, re-review}` (o todas las abiertas con `--forzar`; sólo la indicada con `--mr`). Mostrar la lista antes de largar los agentes (una línea por MR: ticket, proyecto!iid, kinds, SQL sí/no, solapa con). Si son más de 8, avisar el costo y seguir igual salvo que la usuaria frene.

### 3. Correr el workflow

Invocar la tool `Workflow` con `scriptPath` = `.claude/skills/mis-reviews/workflow.js` (ruta absoluta del repo) y `args`:

```json
{
  "mrs": [ ...fichas del PENDING_JSON, tal cual... ],
  "protocol": "tooling/prompts/mr_review_orchestrated.md",
  "dev_protocol": "tooling/prompts/dev_review.md",
  "now": "<fecha ISO de hoy>"
}
```

La usuaria pidió explícitamente que esto se orqueste con workflow; no hace falta volver a pedir permiso por invocarlo desde este skill. Mientras corre, no adelantar resultados. Al terminar, leer `results[]` y `failed[]`. Para cada `failed`, ofrecer correrla suelta con `/review-pr <stub>`.

Si la tool `Workflow` no está disponible en la sesión, degradar: por cada MR pendiente lanzar en paralelo agentes `general-purpose` con los mismos prompts del protocolo (roles especialista, consumers-of, jira) y luego un consolidador — mismo output.

### 4. Regenerar el Excel en Drive

```bash
python .claude/skills/mis-reviews/scripts/build_tracker_xlsx.py
```

Si dice que el `.xlsx` está bloqueado, avisar que lo cierre y volver a correr (escribió una copia con timestamp mientras tanto). Si Drive no está montado (`G:` ausente), avisar y dejar `prs/reviews/tracker.csv` como respaldo.

Después, exportar el **dashboard** (misma fuente, otra vista):

```bash
python .claude/skills/mis-reviews/scripts/export_dashboard_data.py
```

Genera `dashboard/data.json` (lo lee `dashboard/index.html`), `dashboard/dist/index.html` (single-file, offline) y `dashboard/dist/artifact.html` (para publicar con la tool Artifact). El dashboard es estático: se despliega a Vercel con `npx vercel deploy dashboard --prod` (o conectando el repo; cada export + push actualiza los datos). Como muestra títulos de MRs y resúmenes de Jira, activar **Deployment Protection** en Vercel (password o Vercel Authentication) antes de compartir la URL.

### 5. Reporte final a la usuaria

Tabla con una fila por MR procesada:

| Ticket | MR | Veredicto | Consumers-of | Jira | Obs 🔴/🟡 | QA Sentinel | Comentario |
|---|---|---|---|---|---|---|---|

Después:
- **Solapamientos y orden de merge sugerido** (si hubo).
- **Promoción por ticket** (de la hoja `Tickets`): qué falta para cada ticket con algo pendiente (MRs sin mergear, SQL sin aplicar, promo parcial).
- Ruta del Excel y de los `.review-comment.md`; recordar el comando exacto por MR: `python tooling/scripts/post_pr_comment.py <stub> --dry-run`.
- MRs marcadas `qa_sentinel=true`: proponer explícitamente correr QA Sentinel en local antes de aprobar.

Con `--ticket X`: sólo leer `tracker.json`, filtrar por ticket y mostrar MRs (estado/review/ramas/sha/merge commit), commits, SQL, promo por ambiente y la lista de "Falta". No corre agentes.

## MRs antiguas no cuentan (+21 días sin novedades)

`refresh_my_reviews.py` calcula `dias_sin_actividad` (desde `updated_at`) y marca `stale=true` en las MRs abiertas con más de `STALE_DAYS=21` días sin actividad. No suman en los KPIs del Excel (hoja Resumen) ni en "¿Qué hago hoy?" del dashboard — no hay que sacarlas manualmente. Siguen visibles aparte: hoja **Antiguas** del Excel y pestaña **Antiguas** del dashboard, con los días exactos.

## Resumen de cada ticket (cacheado)

Para que "¿Qué hago hoy?" muestre una frase real por ticket ("GRV-2283: nuevo filtro para...") en vez de sólo el título de la MR:

```bash
python tooling/scripts/ticket_briefs.py            # junta título+descripción+comentarios de Jira, SOLO de los tickets con novedades
```

Cachea por ticket en `tracker.json` (`ticket_briefs`), comparando el `updated` de Jira: si no cambió, no vuelve a pedir nada (ni los comentarios). Imprime `===BRIEFS_JSON===` con el material de los tickets que sí cambiaron — leerlo y escribir una frase de una línea por cada uno (sin repetir el código de ticket adelante, se corta solo en el dashboard) con:

```bash
python tooling/scripts/update_ticket_brief.py <TICKET> --resumen "..." --jira-updated "<el jira_updated del JSON>" --jira-status "<estado>"
```

Si un ticket vive en un proyecto Jira sin acceso, `ticket_briefs.py` lo reporta y el dashboard cae automáticamente al título de la MR — no bloquea el resto.

## Seguimiento de equipo: Jira + GLPI (`--equipo`)

Además de "mis" MRs como reviewer, `/mis-reviews --equipo` rastrea los tickets en estado **"pendiente de MR"** de un grupo de personas (default: Carla Debernardi, Alejandro Minue, Maximiliano Carubin, Leandro Lesca, Vanesa Burman — editable con `--people`), en dos sistemas:

- **Jira**: issues con `status = "PENDIENTE DE MR"` (JQL vía `tooling/lib/jira.py:search_jql`, endpoint `/rest/api/3/search/jql` — Atlassian dio de baja el viejo `/search` en 2026).
- **GLPI** (`soporte.colonia-suiza.com`): **no tiene la API REST habilitada** (`GET /apirest.php/initSession` → `"API desactivada"`). `tooling/lib/glpi.py` hace login por formulario (usuario/contraseña normales, cookie de sesión) y reutiliza los mismos endpoints AJAX que la interfaz web:
  - `/ajax/kanban.php?action=refresh&itemtype=Project&items_id=<36|39>&column_field=projectstates_id` — tablero Kanban completo de los proyectos **"MDA Nivel 2"** (id 36) y **"MDA Nivel 3"** (id 39), que son los tableros de seguimiento del equipo de soporte SAS. Tiene una columna literal **"MDA - PENDIENTE DE MR"**.
  - Ese primer JSON sólo trae el progreso (%), no la descripción — para los links reales a Jira/GitLab hay que pedir además `/ajax/kanban.php?itemtype=ProjectTask&items_id=<id>&action=load_item_panel` por cada tarjeta (`glpi.py` ya lo hace solo).

```bash
python tooling/scripts/team_pending_mr.py                    # equipo default, ventana de 14 días en Jira
python tooling/scripts/team_pending_mr.py --people "Carla Debernardi,Alejandro Minue"
python tooling/scripts/team_pending_mr.py --json              # para consumir desde otro script
```

Por cada ticket encontrado (Jira o GLPI), busca links `gitlab.com/grvx/.../merge_requests/N` en la descripción y los comentarios/panel — si no encuentra ninguno, lo marca **"SIN MR todavía"** en vez de asumir que hay algo escondido. Muchos tickets de GLPI referencian su ticket de Jira en la descripción (o al revés, un MR trae "GLPI-NNNN" en el título/rama en vez de un ticket Jira) — el cruce contempla ambos sentidos.

**Límite conocido**: la búsqueda de MRs es por URL completa (`https://gitlab.com/...`); si alguien pega la MR como atajo (p. ej. "te dejo `wscie10!62`" sin la URL completa) no la detecta sola — hay que agregarla a mano al tracker (ver "Agregar una MR fuera del refresh normal" abajo). Pasó con GRV-2238 en esta sesión.

**Credenciales**: `.env` → `GLPI_URL`, `GLPI_USER`, `GLPI_PASSWORD` (usuario y contraseña normales de GLPI, no un token — no hay API key porque la REST está desactivada).

### Agregar una MR fuera del refresh normal

`refresh_my_reviews.py` sólo trae MRs donde la usuaria figura como reviewer/assignee en GitLab. Para revisar una MR encontrada por `--equipo` (de otra persona, sin que la usuaria sea reviewer todavía) o citada a mano (ver límite de arriba), agregarla directo al tracker con `gitlab.fetch_mr_ref` + `refresh_my_reviews.build_entry` (mismo patrón que usa el refresh normal, sin pasar por la lista de reviewer) y después seguir el flujo normal (Workflow de review orquestada + Excel + dashboard). No hay todavía un comando de una sola línea para esto — es un script corto de ~15 líneas, ver el historial de esta skill para el patrón exacto.

## Tablero (Kanban) y pedidos de promoción por drag-and-drop

Pestaña "2. Tablero" del dashboard: una tarjeta por ticket en 4 columnas — **Para revisión** · **Requiere cambios** · **Para promover a test** · **Para promover a master** (columna = derivada de `review_status`/`verdict`/`promo_test`/`promo_prod`, no se edita a mano; un ticket sale del tablero cuando ya está promovido a prod). Tocar una tarjeta abre un panel con todo: servicios/front, tablas/SPs/SQL, MRs, observaciones, comentarios de Jira cacheados, plan de promoción y siguiente paso.

**Arrastrar** una tarjeta de "Para promover a test" a "Para promover a master" **sólo funciona en la versión con login** (mesa-reviews-sas.vercel.app — la copia offline y el Artifact son fotos fijas, no tienen a quién pedirle nada). Al soltar, inserta una fila en Supabase `mesa_reviews_actions` (`estado=pendiente`) — no ejecuta nada por sí sola.

Para procesar los pedidos (correr el `promo_plan.py` real — fetch + dry-run de cherry-pick, **nunca push**) y republicar el resultado:

```bash
python tooling/scripts/process_promo_requests.py
```

Marca cada pedido `listo` (con la recomendación y los comandos, visibles en la tarjeta y en el modal) o `error`, y al final re-exporta el snapshot a Supabase. No hace falta correrlo aparte de memoria: conviene sumarlo al final de `/mis-reviews` (después del Excel/dashboard) o dejarlo en un `/loop` si querés que se revise solo cada tanto.

Tabla: `dashboard/supabase/0002_mesa_reviews_actions.sql` (aplicada el 2026-09-08 vía MCP de Supabase). RLS: el viewer sólo puede insertar/leer sus propias filas; sólo la service role (este script) las actualiza.

## Dashboard "Mesa de Reviews SAS" (Vercel)

Después de cada refresh/review/promo, regenerar y publicar el dashboard (una pantalla por pregunta, pensado para lectura rápida):

```bash
python .claude/skills/mis-reviews/scripts/export_dashboard_data.py   # dashboard/data.json (+ data.enc.json si hay DASHBOARD_PASSPHRASE) + dist/
python tooling/scripts/deploy_dashboard.py                          # sube dashboard/ a Vercel (proyecto mesa-reviews-sas, producción)
```

- URL: https://mesa-reviews-sas.vercel.app — app **aparte** de cerebrOS. Acceso con **login de Supabase** (mismo proyecto `clienteos` que cerebrOS; la usuaria entra con su cuenta). Los datos NO viajan en el deploy: el export hace upsert del snapshot en la tabla `mesa_reviews_snapshots` (una fila por usuario, RLS `user_id = auth.uid()`) y la página logueada lee su fila. **Actualizar datos = correr el export; redeploy sólo cuando cambia el código.**
- Config en `.env` (copiada de `clienteos/.env.local`): `SUPABASE_URL`, `SUPABASE_ANON_KEY` (pública, va a `assets/config.js`), `SUPABASE_SERVICE_ROLE_KEY` (sólo el script), `SUPABASE_OWNER_EMAIL` → `SUPABASE_OWNER_UID` (se cachea solo). Vercel: `VERCEL_TOKEN`, `VERCEL_TEAM_ID`, `VERCEL_PROJECT`.
- Tabla: `dashboard/supabase/0001_mesa_reviews.sql` (aplicar una vez en el SQL editor del proyecto o vía MCP de Supabase).
- Fallback sin Supabase: datos cifrados (`data.enc.json`) + frase `DASHBOARD_PASSPHRASE`. Copia offline: `dashboard/dist/index.html` (datos en claro — no compartir). Maqueta como Artifact: `dashboard/dist/artifact.html`.

## Plan de promoción quirúrgica (`--promo`)

La cadena real del SAS es `develop → release → stage → master` (`release` es lo que se despliega a **test**; `tooling/lib/env.py:PROMO_BRANCHES`). Cuando un ticket tiene varias MRs y en el medio entraron commits de otros, promover "la rama" arrastra lo ajeno y promover "los commits" puede pisar o perder cambios (caso !505/TAR-15). El plan contempla **las dos opciones** y recomienda una.

```
/mis-reviews --promo GRV-2328 --to test            # develop → release
/mis-reviews --promo GRV-2182 --to stage           # release → stage (origen = anterior en la cadena)
/mis-reviews --promo GRV-2328 --to prod --from release
```

Corre `python tooling/scripts/promo_plan.py <ticket> --to <env|rama> [--from <rama>] [--no-fetch]` (necesita `repos/grvx/` clonado; hace `git fetch` de las ramas involucradas, sin escribir en el remoto) y por cada repo del ticket:

1. **Commits del ticket** pendientes en el destino, en el orden original. Si la MR sigue abierta se toman de su rama fuente y se marcan **anticipado**.
2. **Commits de terceros intercalados** entre destino y origen, agrupados por ticket, con su estado según mi tracker (aprobado y mergeado / mergeado sin mi Approve / con MRs abiertas / no lo reviso yo) y cuáles tocan archivos del ticket (**riesgo de conflicto o pisado silencioso**). Aparte: commits **del mismo ticket que no vienen de mis MRs** (ej. una MR anterior ya mergeada).
3. **Dry-run del cherry-pick** en un worktree temporal sobre `origin/<destino>`: aplica limpio / conflictúa (archivos) y qué archivos del ticket quedarían **distintos al origen** (señal de que hay cambios ajenos que hay que mirar a mano).
4. **Opción 1** cherry-pick a `promo/<TICKET>-a-<destino>` (comandos exactos, convención del equipo) · **Opción 2** rama completa `origen → destino` (viable sólo si todo lo intercalado está aprobado). **Recomendación** en función de eso.
5. **SQL** del ticket a aplicar en el ambiente destino.

Salidas: `prs/reviews/promo/<TICKET>-a-<rama>.md` + `.json`; `promo_plan[<rama>]` en el tracker (hoja **Plan promoción** del Excel y bloque "Plan de promoción" del dashboard). Después: regenerar Excel y dashboard. El script **no** crea ramas ni pushea: los comandos los ejecuta la usuaria.

### Dos reglas de la promoción (valen para todos los tickets, no sólo AP)

**1. Un solo commit por promoción.** Los comandos que genera el plan usan `cherry-pick -x -n` y cierran
con un `commit` único, en vez de dejar N commits sueltos en el destino.

**2. Lo pendiente se mide por CONTENIDO (patch-id), no por ancestría.** Promover por cherry-pick deja
en el destino commits con el mismo contenido y distinto sha; `merge-base --is-ancestor` los da por
ausentes y los vuelve a proponer. `promo_plan.py` lo resuelve con `ya_aplicado_por_contenido()`, que
consulta `git cherry`. A mano:

```bash
git cherry -v origin/<destino> origin/<origen> | grep '^+'   # + falta de verdad · - ya aplicado
```

Sin esto, los commits ya promovidos siguen apareciendo en el `develop → release` de cualquier otra
persona (y además inflan el diff de tres puntos que muestra GitLab, por múltiples merge-bases).

⚠️ **Nunca** `git merge -s ours develop` sobre `release`/`stage` para "anclar la ancestría": marca como
mergeado contenido que la rama nunca recibió, y el trabajo pendiente de otros queda enterrado sin aviso.

## QA Sentinel — pruebas en local de lo que se está subiendo (`--qa`)

Para tickets complejos (Block, multi-ws, SQL + código, consumidores 🔴, `qa_sentinel=true` en el tracker) se corre **QA Sentinel** (repo de Leandro clonado en `QA_Sentinel/`, gitignored) sobre el ticket. Integración: `tooling/scripts/qa_sentinel_bridge.py` + los agentes `sentinel-*` sincronizados a `.claude/agents/` + el workflow oficial `QA_Sentinel/.claude/workflows/qa-sentinel-pipeline.js`.

```
/mis-reviews --qa GRV-2182                 # Fase 1 documental (estático + plan + matriz + auditoría) → gate humano
/mis-reviews --qa GRV-2182 --env dev       # ambiente objetivo (default test; URL desde QA_URL_<ENV> en .env o --url)
/mis-reviews --qa GRV-2182 --fase2         # tras tu OK: especialistas aprobados (+ --ejecutar para correr specs)
/mis-reviews --qa GRV-2182 --publicar      # copiar evidencia a Drive y actualizar tracker/Excel
```

Reglas de la integración (no negociables):
- El input para QA Sentinel es **siempre `prd_md`** (el requerimiento que arma el bridge), nunca `jira_hu`: así ningún agente crea subtareas ni comenta en Jira. Postear en Jira lo decide la revisora.
- Todo lo de QA Sentinel vive bajo `QA_Sentinel/` (`Documentacion/<TICKET>/`, `tests/<TICKET>/`, `src/pages/`). En cada prompt a los agentes incluir: *"Raíz de QA Sentinel: `<abs>/QA_Sentinel`. Todas las rutas relativas de los skills (Documentacion/, tests/, src/, .env, playwright.config.ts) se resuelven bajo esa raíz; `npm`/`npx` se corren con cwd ahí."* Si un agente escribió en la raíz del workspace: `python tooling/scripts/qa_sentinel_bridge.py fix-paths <TICKET>`.
- Nada se ejecuta contra producción. `ejecutarSpecs` sólo con `--ejecutar` y URL de dev/test/stage.
- El **gate humano** del pipeline se respeta: la Fase 2 se lanza en una segunda invocación, después de que la usuaria apruebe plan, matriz y estáticas.
- Qase no está configurado: `subir_casos_qase` va a fallar y los agentes lo registran como `fallo` — es esperado, no es un error del pipeline.

### Procedimiento `--qa <ticket>` (Fase 1)

1. Prerrequisitos (una vez por máquina): `QA_Sentinel/` clonado; `python tooling/scripts/sync_qa_sentinel_agents.py` (y reiniciar Claude Code la primera vez); `npm install` + `npx playwright install chromium` dentro de `QA_Sentinel/`; `src/` presente (si no está el oficial, quedan los stubs mínimos generados acá — marcados como tales).
2. `python tooling/scripts/qa_sentinel_bridge.py prepare <ticket> --env <dev|test|stage> [--url URL]` → lee el bloque `===QA_ARGS===`. Si la URL falta, la Fase 1 (documental) puede seguir; avisar que la Fase 2 con ejecución la necesita.
3. Invocar `Workflow` con `scriptPath` = `<abs>/QA_Sentinel/.claude/workflows/qa-sentinel-pipeline.js` y `args` = el JSON de `QA_ARGS` (con `faseAprobada: false`). El workflow devuelve `gate: ESPERANDO_APROBACION_HUMANA` con `para_revisar` (estáticas, plan, matriz), la auditoría y `bloqueantes`. Si `agentType` no resuelve (sesión sin reiniciar), degradar: `Agent(general-purpose)` con el contenido de `.claude/agents/sentinel-static-agent.md` como prompt + `CONTEXTO_SENTINEL` + regla de raíz, y después `sentinel-auditor-agent` igual.
4. `python tooling/scripts/qa_sentinel_bridge.py publish <ticket> --fase 1 --veredicto "<veredicto del auditor>"` y regenerar el Excel. Presentar a la usuaria los tres artefactos (rutas en Drive), la cobertura real de criterios y la **tabla de derivación** para la Fase 2 aplicando el test de insumo del skill `qa_sentinel` (ui / api / e2e / regresion / smoke / performance — activar sólo con insumo real; para MRs de soporte casi siempre `regresion` + `e2e` o `api`; `smoke` sólo con URL alcanzable). **Detenerse acá.**

### Procedimiento `--qa <ticket> --fase2 [--ejecutar]`

Sólo con aprobación explícita. Relanzar el mismo workflow con `faseAprobada: true`, `planRuta`, `matrizRuta` (del resultado de la Fase 1), `agentes: [...]` (los aprobados), `ejecutarSpecs`, más `modulosImpactados`, `hallazgosEstatico`, `criteriosSinCaso`, `casosPorEspecialidad` del retorno del estático. Al terminar: `publish <ticket> --fase 2 --veredicto <smoke|auditor>`, regenerar Excel, y reportar reporte maestro + gaps de cobertura + skills que fallaron. Si corrió con `--ejecutar`, adjuntar `playwright-report/` (el bridge lo copia a Drive).

## Mantenerlo al día solo

- Manual: `/mis-reviews --solo-tracker` cada mañana (30 s, sin agentes).
- Automático en la sesión: `/loop 2h /mis-reviews --solo-tracker`.
- Programado fuera de sesión: `/schedule` con `python tooling/scripts/refresh_my_reviews.py --no-stubs && python .claude/skills/mis-reviews/scripts/build_tracker_xlsx.py` (requiere `.env` y Drive montado en la máquina que lo corre).

## Estados del tracker

`pendiente` → (review) → `revisada` → (`/post-pr-comment`) → `posteada` → (merge en GitLab) → `mergeada`. Si el autor pushea después de tu review: `re-review` (queda anotado el sha viejo → nuevo). Si comenta después de tu review: las observaciones `abierta` pasan a `respondida?` para que las mires. Las MRs mergeadas se conservan como memoria de promociones (merge commit sha, fecha) hasta que las borres del `tracker.json`.

## Archivos

```
.claude/skills/mis-reviews/
├── SKILL.md                         ← este archivo
├── workflow.js                      ← orquestación (Workflow tool, scriptPath)
└── scripts/build_tracker_xlsx.py    ← Excel en Drive (openpyxl)
tooling/scripts/refresh_my_reviews.py    ← refresh + clasificación + tracker.json/INDEX.md/csv
tooling/scripts/update_review_tracker.py ← lo usa el consolidador; también sirve a mano
tooling/scripts/team_pending_mr.py       ← --equipo: cruce Jira + GLPI de "pendiente de MR" por persona
tooling/lib/glpi.py                      ← sesión GLPI por formulario (sin API REST) + kanban/tickets
tooling/prompts/mr_review_orchestrated.md ← protocolo por rol + criterios obligatorios
prs/reviews/tracker.json                 ← fuente de verdad (versionado)
prs/reviews/INDEX.md · tracker.csv       ← vistas
```

Config en `.env`: `GITLAB_USERNAME` (opcional), `REVIEWS_DRIVE_DIR` (default `G:\Mi Unidad\NUEVO AGENTE SOPORTE`), `JIRA_*` (opcional, para estado del ticket en el refresh), `GLPI_URL`/`GLPI_USER`/`GLPI_PASSWORD` (para `--equipo`).

## Límites

- La clasificación del refresh es regex: puede omitir un endpoint construido dinámicamente o listar una tabla mencionada en un comentario. Los agentes deben confirmar contra el diff.
- `consumers-of` sólo ve lo clonado en `repos/grvx/`. Ws no clonados se reportan como tales.
- No aprueba, no mergea, no postea. Eso lo decide la usuaria.
- `--equipo` sólo detecta MRs citadas como URL completa (ver límite en la sección de GLPI arriba); atajos tipo `wscie10!62` sin URL no se detectan solos.
- GLPI no tiene API REST habilitada en esta instancia — todo pasa por login de formulario + endpoints AJAX de la interfaz web, que Teclib/GLPI puede cambiar en una actualización sin aviso (a diferencia de una API versionada).

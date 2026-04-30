# Changelog

Todos los cambios notables de este workspace quedan documentados acá.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Versionado según SemVer liviano (ver `GOVERNANCE.md`).

## [Unreleased]

### Hooks
- **`.claude/hooks/README.md`** nuevo: guía de instalación, uso,
  formateadores, typecheck/lint, sound alerts y checklist de cierre de feature.
- **`pre-commit-typescript-quality`** nuevo: ejecuta scripts existentes
  `lint` y `typecheck` cuando hay TypeScript staged; warn por default y
  blocking opcional con `GRV_TS_CHECK_MODE=block`.
- **`post-tool-feature-workflow`** nuevo: checklist de cierre de feature con
  reminders para TypeScript, `mariadb-migration-review`, `changelog-keeper` y
  `/plan` cuando queden pasos abiertos.
- **`post-tool-auto-format`** actualizado: suma `google-java-format` para
  servicios Java y explicita Prettier para React/TypeScript.
- **`post-tool-sound-alert`** documentado con explicación de eventos y sonidos.
- **`pre-tool-branch-guard`** nuevo: guardrail PreTool para advertir o
  bloquear cambios de Claude Code en ramas protegidas.
- **`post-tool-auto-format`** nuevo: PostTool que ejecuta formateadores ya
  instalados sobre archivos editados por Claude.
- **`post-tool-cost-tracker`** nuevo: PostTool de observabilidad que registra
  uso/tokens/costos reportados por Claude Code y permite ver un resumen local.
- **`post-tool-sound-alert`** nuevo: alertas sonoras opt-in para atención,
  fin de tarea, fin de plan, skills y subagentes, con comandos on/off/status.
- **`scripts/install-hooks.sh`** nuevo: instalador shell para wrappers de hooks
  Git locales.
- **`docs/how-to-add-a-hook.md`** actualizado con guía de instalación,
  hooks PreTool/PostTool y comandos de sound alerts.

### Optimización de tokens
- **`CLAUDE.md` adelgazado** de ~1.370 palabras a ~570 (58% menos).
  Se mantuvo lo esencial operativo y se movió el contexto extendido a
  `docs/onboarding-humans.md`. Ahorro estimado: ~3.500 tokens por sesión,
  todas las sesiones.
- **`docs/onboarding-humans.md`** nuevo. Versión larga del contexto
  para que la lean los humanos del equipo. Claude solo la lee si el
  usuario se la pide explícitamente o si la invoca el skill `onboarding`.
- **`.claude/mcp-minimal.json`** nuevo. Perfil reducido con solo
  `mariadb-dev` y `context7` para sesiones del día a día. El perfil
  full sigue en `.claude/mcp.json`. Switch manual entre uno y otro
  documentado en `docs/mcp-setup.md`. Ahorro adicional: ~2.000-3.000
  tokens por sesión cuando se usa minimal.
- **`docs/mcp-setup.md`** actualizado con guía de cuándo usar minimal vs full.

### Agregado
- **Skill `workspace-contribution`** (alpha): cierra el loop entre
  "Claude detecta un hueco" y "el workspace mejora". Cuando un skill
  recibe información que no tenía documentada, ofrece capturarla como
  propuesta en una rama `contrib/<usuario>/<slug>` con commit local
  (auto-push opcional via `GRV_WORKSPACE_AUTO_PUSH`).
- Helper `skills/engineering/workspace-contribution/helper.md` para
  invocación consistente desde otros skills.
- Template `templates/workspace-contribution-mr.md` para los MRs de
  contribución.
- Sección de governance para el flujo de review de contribuciones
  propuestas.
- Skills actualizados para ofrecer captura al cierre del flujo:
  `grv-glosario`, `grv-arquitectura-plataforma`, `grv-bugs-conocidos`,
  `grv-regulaciones-srt`, `grv-best-practices`, `grv-provincia-art`,
  `grv-sgc`, `grv-satapp`.
- Variable `GRV_WORKSPACE_AUTO_PUSH` en `.env.example`.
- `.gitignore` excluye `.claude/pending-contributions.yaml` y
  `.claude/user.yaml`.

## [0.1.0] — Bootstrap inicial

### Agregado
- Estructura base del workspace con 3 ejes: dominio GRV, ingeniería, procesos.
- `README.md`, `CLAUDE.md`, `GOVERNANCE.md` como documentos fundacionales.
- Configuración de Claude Code (`.claude/settings.json`, `.claude/mcp.json`).
- Integración con 6 MCPs: MariaDB (dev y prod read-only), Playwright, Context7, Sequential Thinking, Granola.
- Skill de onboarding para nuevos usuarios del workspace.
- **12 skills de dominio GRV**: glosario, arquitectura de plataforma, regulaciones SRT, Provincia ART, SGC, Satapp, siniestros, turnos/logística, autorizaciones médicas, prestaciones, facturación, bugs conocidos.
- **9 skills de ingeniería**: review de migraciones MariaDB, review de Spring Boot, review de React MFE, generación de tests funcionales, sincronización de API doc, diagramas C4, mantenimiento de changelog, auditoría de versionado de BD, buenas prácticas GRV.
- **3 skills de procesos**: detector de automatizaciones, Granola a action items, post-mortem de deploys.
- **6 subagentes**: domain expert, reviewer, migration guard, test author, doc keeper, process analyst.
- **Prompt library** inicial con plantillas para tareas recurrentes.
- **Context files** en YAML: microservicios, equipo, glosario, regulaciones, integraciones, bugs conocidos, tablas sensibles, tablas pesadas.
- **Templates**: migration, ADR, post-mortem, C4, MR.
- **Hooks**: pre-commit para migraciones, secretos, sincronización de API, y post-edit de tests.
- **Case study** inicial documentando un caso real end-to-end.
- **SQL script** para crear usuario `claude_readonly` (pendiente de aplicación en infra).

### Notas de madurez
- Todos los skills arrancan en **alpha** o **beta** según el caso.
- `mariadb-migration-review` apunta a **beta** en semana 1.
- `functional-test-author` se mantiene en **alpha** hasta afinar lectura de fuentes variadas.

### Pendiente
- Crear usuario dedicado `claude_readonly` en MariaDB (ver `sql/create-claude-readonly-user.sql`).
- Poblar `context/sensitive-tables.yaml` con la lista real del cliente.
- Integrar GitLab MCP para que el reviewer pueda comentar directo en MRs.

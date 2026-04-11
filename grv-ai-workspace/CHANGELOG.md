# Changelog

Todos los cambios notables de este workspace quedan documentados acá.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Versionado según SemVer liviano (ver `GOVERNANCE.md`).

## [Unreleased]

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

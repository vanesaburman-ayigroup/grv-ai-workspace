# Changelog

Todos los cambios notables de este workspace quedan documentados acá.

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).
Versionado según SemVer liviano (ver `GOVERNANCE.md`).

## [0.2.0] — Fase 1: Skills para arquitectos, líderes técnicos, testing unitario y OpenAPI

### Agregado — Skills de ingeniería

- **`openapi-from-scratch`** (alpha): genera `openapi.yaml` (OpenAPI 3.0) leyendo controllers Spring Boot cuando el servicio no tiene Swagger anotado.
- **`openapi-validator`** (alpha): valida un `openapi.yaml` con reglas estándar Spectral + reglas custom GRV (versionado `/v1`, snake_case en query params, operationId único, etc.).
- **`unit-test-author`** (alpha): escribe tests unitarios puros (JUnit 5 + Mockito + AssertJ para Java; Jest + RTL + MSW para TypeScript). Complementa a `functional-test-author`.
- **`test-coverage-strategy`** (alpha): decide qué cubrir con qué nivel de test (unit / integración / E2E). Aplica la pirámide de testing al stack GRV.
- **`adr-helper`** (alpha): guía la escritura de ADRs completos usando `templates/adr-template.md`, cruzando con `context/microservices.yaml`.
- **`architecture-patterns`** (alpha): aplica patrones distribuidos al stack GRV (outbox, saga, CQRS, circuit breaker, retry/backoff, dual write).
- **`observability-blueprint`** (alpha): define qué loguear, qué métricas exponer (Micrometer) y qué alertas configurar (Sentry + SLOs).
- **`api-design-review`** (alpha): revisa el diseño de un endpoint antes de implementarlo (método HTTP, versionado, breaking changes, naming, paginación).
- **`database-design-heavy-table`** (alpha): estrategia para cambios de schema en tablas heavy (siniestros, datos_denuncia_srt_logs, auditoria_facturacion_log) sin lock.

### Agregado — Skills de procesos

- **`tech-debt-audit`** (alpha): inventario y priorización P0/P1/P2 de deuda técnica de un servicio o la plataforma.
- **`release-readiness`** (alpha): checklist maestro pre-release (migraciones, API, tests, changelog, feature flags, rollback, alertas).
- **`cross-team-impact`** (alpha): árbol de dependencias y orden de deploy para cambios que afectan múltiples servicios.
- **`incident-command`** (alpha): playbook para gestionar incidents activos (primeros 5 minutos, rollback vs rollforward, comunicación).
- **`sprint-planning-impact`** (alpha): evaluación técnica pre-planning de tickets del sprint (servicios afectados, riesgo, dependencias, sizing).

### Agregado — Agentes

- **`grv-architect`** (alpha): orquesta skills para arquitectos (adr-helper, architecture-patterns, observability-blueprint, api-design-review, database-design-heavy-table, c4-diagrams).
- **`grv-tech-lead`** (alpha): orquesta skills para tech leads (tech-debt-audit, release-readiness, cross-team-impact, incident-command, sprint-planning-impact).

### Agregado — Templates

- `junit5-test.java`: JUnit 5 + Mockito + AssertJ con `@Nested`, `@ParameterizedTest`, Object Mother integrado.
- `jest-component-test.tsx`: Jest + RTL + MSW con `describe.each`, `userEvent`, manejo de errores de API.
- `test-builder.java`: patrón Object Mother / Builder con factories nombradas.
- `test-factory.ts`: Faker-based factory con variantes nombradas (equivalente a Object Mother en TS).
- `openapi-skeleton.yaml`: estructura GRV-standard OpenAPI 3.0 con servers dev/prod, schemas de dominio, responses reutilizables.
- `release-readiness-checklist.md`: checklist completo con checkboxes por sección y sign-off.
- `tech-debt-entry.md`: template para documentar cada item de deuda técnica.
- `incident-runbook.md`: runbook de incidente con pasos de diagnóstico, mitigación y escalamiento.

### Agregado — Prompts

- `architecture-tradeoff.md`: comparar 2-3 alternativas arquitectónicas con criterios GRV.
- `endpoint-design.md`: diseño guiado de endpoint nuevo antes de implementar.
- `tech-debt-prioritization.md`: armar tabla P0/P1/P2 para llevar al planning.
- `onboarding-tech-deep.md`: onboarding profundo a un servicio para dev nuevo.
- `breaking-change-evaluation.md`: evaluar si un cambio es breaking y qué plan de migración aplicar.

### Agregado — Hooks

- **`post-edit-test-suggestion.sh`** (PostToolUse): si se edita código fuente sin test asociado, sugiere usar `/unit-test-author`.
- **`pre-commit-openapi-sync.sh`** (git pre-commit): si hay cambios en `*Controller.java`, recuerda actualizar el `openapi.yaml`.

### Modificado

- **`api-doc-sync`**: agregado modo standalone (delegar a `openapi-from-scratch` cuando no hay anotaciones); detección de springdoc vs swagger-core; `related_skills` actualizado.
- **`functional-test-author`**: agregada sección "Relación con unit-test-author" con tabla de cuándo usar cada skill.
- **`grv-doc-keeper`**: carga `openapi-from-scratch` y `openapi-validator`.
- **`grv-reviewer`**: carga `api-design-review` cuando el diff incluye cambios de contrato.
- **`grv-test-author`**: carga `unit-test-author` y `test-coverage-strategy`.
- **`settings.json`**: registrado hook `post-edit-test-suggestion.sh`.

### Pendiente para Fase 1 completar

- Hooks Tier 1 restantes: `post-edit-changelog-suggest.sh`, `post-edit-pii-in-logs.sh`, `pre-commit-conventional-commits.sh`, `pre-commit-todo-orphan.sh`
- `scripts/install-hooks.sh` + `.pre-commit-config.yaml`
- GitLab MCP y Sentry MCP
- Verificación end-to-end (ver sección 6 del plan)

## [Unreleased]

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

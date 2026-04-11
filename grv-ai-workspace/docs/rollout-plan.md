# Rollout Plan

Plan de adopción del workspace `grv-ai-workspace` dentro del equipo GRV.

## Principios

1. **Empieza chico, crece por evidencia.** Arrancamos con `[OWNER_NAME]` y `[COMAINTAINER_NAME]`. Escalamos cuando haya casos reales documentados que convenzan al resto.
2. **No es un producto, es un proceso.** El workspace mejora con el uso. Esperamos iteración continua.
3. **Dogfooding antes de rollout.** Antes de enseñarle a nadie, lo usamos nosotros en tareas reales durante 2+ semanas.
4. **Evidencia > marketing.** Un case study documentado convence más que 10 demos.

## Fase 0 — Bootstrap (días 1-2) ✅

- [x] Crear repo `grv-ai-workspace` en GitLab interno.
- [x] `README.md`, `CLAUDE.md`, `GOVERNANCE.md`, `CHANGELOG.md`.
- [x] Estructura de carpetas completa.
- [x] `.claude/settings.json`, `.claude/mcp.json`.
- [x] Hooks pre-commit iniciales.
- [x] Context files base (microservices, team, glossary, regulations, integrations, known-bugs).
- [x] Skills con contenido inicial en todos los ejes.
- [x] 6 subagentes definidos.
- [x] Docs de setup.
- [ ] Clonar localmente, configurar `.env`, probar MCPs.
- [ ] Primer commit `v0.1.0` del workspace.

## Fase 1 — Dogfooding (semana 1)

**Usuarios**: `[OWNER_NAME]`, `[COMAINTAINER_NAME]`.

**Tareas reales a pasar por el workspace**:

- Al menos 2 migraciones SQL → `mariadb-migration-review`
- Al menos 2 MRs de Spring Boot → `spring-boot-review` + agente `grv-reviewer`
- Al menos 1 MR de frontend → `react-mfe-review`
- Al menos 1 tanda de tests → `functional-test-author`
- Al menos 1 consulta de dominio → `grv-domain-expert`
- Al menos 1 reunión transcrita → `granola-to-actions`

**Output esperado**: primer case study en `docs/case-studies/001-<nombre>.md`
con antes/después, qué funcionó, qué no.

**Criterio de éxito**: `mariadb-migration-review` promovido de alpha a beta.

## Fase 2 — Expansión de dominio (semana 2-3)

- [ ] Completar `context/microservices.yaml` con los servicios pendientes.
- [ ] Poblar `context/sensitive-tables.yaml` con la lista real.
- [ ] Aplicar `sql/create-claude-readonly-user.sql` en dev (con `[DEVOPS_REFERENT]`).
- [ ] Agregar casos reales a los skills de dominio (regulaciones, bugs conocidos).
- [ ] MariaDB MCP dev estable, prod configurado con switch explícito.
- [ ] Segundo y tercer case study.

**Criterio de éxito**: `spring-boot-review` y `react-mfe-review` a beta.

## Fase 3 — Documentación y procesos (semana 4-5)

- [ ] `api-doc-sync` probado en un MR real.
- [ ] `c4-diagrams` generando diagramas para 2 servicios.
- [ ] `changelog-keeper` corriendo semanalmente.
- [ ] `db-versioning-audit` corriendo sobre wssiniestralidad.
- [ ] `automation-finder` corriendo sobre tickets cerrados de la semana.
- [ ] `granola-to-actions` integrado al flujo post-reunión.
- [ ] `deploy-post-mortem` listo con integración Sentry.

**Criterio de éxito**: 3+ case studies publicados; `functional-test-author` a beta.

## Fase 4 — Rollout al equipo (semana 6-7)

- [ ] Sesión de presentación al equipo (30 min + demo).
- [ ] Onboarding 1 a 1 con cada dev interesado.
- [ ] Apertura del canal de feedback.
- [ ] Primer ritual mensual con retro.

**Criterio de éxito**: 4+ usuarios activos del workspace.

## Fase 5 — Maduración (mes 2+)

- [ ] Promoción a production de los 3 skills prioritarios.
- [ ] Integración con GitLab MCP (reviewer comenta en MRs).
- [ ] Automatización de hooks en CI (no solo local).
- [ ] Medición de impacto: tiempo ahorrado, bugs detectados, tests escritos.

## Métricas a trackear

- Cantidad de skills usados por semana
- Cantidad de MRs que pasaron por el reviewer antes de merge
- Bugs detectados por el reviewer que hubieran pasado a main
- Tiempo promedio de review de MR (con/sin workspace)
- Cantidad de tickets creados por `granola-to-actions`
- Satisfacción del equipo (encuesta simple al cierre de cada mes)

## Riesgos y mitigaciones

| Riesgo | Probabilidad | Mitigación |
|---|---|---|
| Falsos positivos en reviewer → frustración | Alta al inicio | Warn mode hasta production. Retro mensual. |
| Claude alucina código/tablas | Media | Context files + MCP de MariaDB + regla "no inventes" en CLAUDE.md |
| Adopción baja por fricción de setup | Media | docs/mcp-setup.md detallado; ofrecer ayuda 1 a 1 |
| Dependencia excesiva de IA → atrofia del equipo | Baja pero real | Mantener cultura de review humano obligatorio |
| Leak de PII | Baja con las salvaguardas | Logging sin resultados + warning + disciplina humana |

## Plan de comunicación

- **Semana 1-2**: silencio; dogfooding interno.
- **Semana 3**: mensaje informal en el canal del equipo anunciando que existe y linkeando el primer case study.
- **Semana 4**: segundo case study; pedir feedback.
- **Semana 5-6**: sesión de presentación formal al equipo.
- **Mes 2+**: actualización mensual en stand-up del equipo.

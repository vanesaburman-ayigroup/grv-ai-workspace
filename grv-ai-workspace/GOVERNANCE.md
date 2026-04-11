# GOVERNANCE

Este documento define cómo evoluciona el workspace `grv-ai-workspace`.

## Ownership

- **Owner**: `[OWNER_NAME]` — decisión final sobre scope, merges, cambios estructurales.
- **Co-maintainer**: `[COMAINTAINER_NAME]` — review de MRs, gestión del día a día.
- **Contributors**: cualquier miembro del equipo GRV. Ver `context/team.yaml`.

Cada skill, agente y hook tiene un **referente** declarado en su propio archivo (campo `owner:` del frontmatter). El referente es quien responde dudas, revisa PRs que tocan ese componente y decide si promover nivel de madurez.

## Niveles de madurez

Todo skill, agente o hook declara su madurez:

| Nivel | Significado | Criterios de promoción |
|---|---|---|
| **alpha** | Funciona pero requiere supervisión humana constante. Puede tener bugs, falsos positivos, o cubrir solo un subset del caso. | Usado en al menos 1 caso real. README del skill actualizado. |
| **beta** | Usable con review ocasional. Cubre el caso principal pero falla en edge cases. | Usado en al menos 3 casos reales distintos. Al menos 1 ejemplo documentado en el SKILL.md. Owner asignado. |
| **production** | Probado, estable, documentado. Seguro de invocar sin supervisión para el caso que cubre. | Usado en al menos 5 casos reales. 2 ejemplos documentados (éxito y caso que NO cubre). Validado por owner y al menos 1 revisor distinto. Cambios de aquí en más requieren MR con review obligatorio. |

La degradación de nivel (ej: production → beta) también está permitida si se detecta un problema. Cualquier miembro puede abrirlo como issue.

## Flujo de cambios

### Cambios chicos (tipo, typo, clarificación de doc)

1. Commit directo a `main` permitido para owner y co-maintainer.
2. Para el resto: MR simple con título `docs: ...`, merge sin review obligatorio si no toca código de hooks.

### Cambios medianos (nuevo skill, nuevo prompt, cambio en un skill beta o alpha)

1. Branch `feat/<skill-name>` o `feat/<prompt-name>`.
2. MR con descripción que incluye:
   - **Problema** que resuelve (qué pasaba antes sin esto).
   - **Solución** propuesta (qué hace el skill/prompt/agente).
   - **Ejemplo real** donde se probó. No sirve ejemplo inventado.
   - **Impacto** en otros skills/agents (si aplica).
3. Review por al menos 1 maintainer.
4. Merge a `main`.

### Cambios grandes (skill production, cambio estructural, MCP nuevo, hook crítico)

1. Branch.
2. **ADR** (Architecture Decision Record) en `docs/adr/NNN-titulo.md` usando el template de `templates/adr-template.md`.
3. MR linkeado al ADR.
4. Review por owner + co-maintainer (ambos).
5. Al menos 2 casos reales probados antes del merge.
6. Entry en `CHANGELOG.md`.
7. Comunicación al equipo en el canal interno.

## Versionado

### Workspace global

SemVer liviano en `CHANGELOG.md`:

- **PATCH** (0.1.X): fixes, documentación, skills nuevos en alpha.
- **MINOR** (0.X.0): skills promovidos a beta/production, nuevos agentes, nuevos hooks, nuevos MCPs.
- **MAJOR** (X.0.0): cambios estructurales que requieren reconfiguración por parte de los usuarios.

### Skills individuales

Cada skill tiene su propio `version:` en el frontmatter. Avanza independientemente del workspace global. Convención: `v1`, `v2`, `v3` sin subversiones (lo que describe el tweet disparador). La historia queda en el git log.

## Ritual mensual

**Cuándo**: última semana del mes, 30 minutos, híbrido.
**Quiénes**: owner, co-maintainer, y cualquier usuario activo del workspace.
**Agenda**:

1. (5 min) Qué se agregó/cambió este mes (lee CHANGELOG).
2. (10 min) Qué skill/agente usó más cada uno, y para qué.
3. (10 min) Qué faltó / dónde Claude se equivocó / qué hubo que corregir a mano.
4. (5 min) Prioridades del próximo mes: qué promover de nivel, qué agregar, qué matar.

El resultado queda en `docs/retros/YYYY-MM.md`.

## Contribuciones propuestas desde el uso

El workspace tiene un skill (`workspace-contribution`) que captura
mejoras al `context/` cuando alguien detecta un hueco durante su uso
normal. Estas contribuciones llegan como MRs en ramas `contrib/<usuario>/<slug>`
con label `workspace-contribution`.

**Flujo de review**:

1. El usuario creó la rama desde Claude Code y puede haber pusheado
   (si tiene `GRV_WORKSPACE_AUTO_PUSH=true`) o no.
2. El MR aparece en GitLab con el label.
3. **Review en el día hábil siguiente** (idealmente). Son cambios chicos,
   no justifica acumularlos.
4. El owner o co-maintainer mergea, pide ajustes o descarta.
5. Si se descarta, dejar comentario explicativo para que el autor aprenda.

**Qué puede venir por esta vía** (scope del skill):

- Definiciones nuevas o correcciones al `context/glossary.yaml`
- Mapeos de servicios/MFEs que reemplazan placeholders
- Convenciones del equipo que van a `grv-best-practices`
- Referencias regulatorias
- Bugs nuevos al catálogo
- Detalles de integraciones externas

**Qué NO puede venir por esta vía** (requieren MR manual):

- Cambios a skills existentes (texto, flujo, estructura)
- Cambios a hooks, settings o MCPs
- Skills o agentes nuevos completos
- Cambios a `CLAUDE.md` o `GOVERNANCE.md`

**Revisión mensual de contribuciones rechazadas**: en el ritual mensual,
dedicar 2-3 minutos a repasar los MRs `workspace-contribution` que se
descartaron o que necesitaron ajuste significativo. Eso nos dice si el
skill está calibrado (muchas rechazadas = el skill captura cosas que no
debería, hay que ajustar).

## Qué se mata

No todo lo que se crea vive para siempre. Si un skill o prompt:

- No se usa en 2 meses → revisar si el caso sigue vigente; si no, archivarlo en `skills/_archive/`.
- Genera más ruido que valor (falsos positivos, alucinaciones, etc.) → bajar nivel o archivar.
- Fue reemplazado por un skill mejor → marcar como deprecated en su frontmatter y apuntar al reemplazo.

Los archivados no se borran (puede volver a ser útil), pero salen del radar de descubrimiento.

## Conflictos y decisiones

Cuando hay desacuerdo sobre diseño, prioridad, o scope:

1. Conversación en el MR o issue.
2. Si no se resuelve en 48h, decisión del owner.
3. Si el owner cambia una decisión del co-maintainer, queda registrado como ADR.

## Confidencialidad

El workspace es **público dentro de GRV consultora**. No debe contener:

- Credenciales, tokens, passwords, API keys (aunque sean de dev).
- Datos personales reales de pacientes / trabajadores denunciantes.
- Contratos o información comercial sensible del cliente.
- Números de denuncia reales en ejemplos (usar placeholders tipo `DNN-XXXXX`).

Los hooks de pre-commit validan secretos; el resto depende de disciplina humana.

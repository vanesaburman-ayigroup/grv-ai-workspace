---
name: onboarding
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: onboarding
related_skills: [grv-glosario, grv-arquitectura-plataforma, grv-best-practices]
related_agents: [grv-domain-expert]
triggers:
  - "primera vez que alguien abre el workspace"
  - "usuario pregunta '¿qué hay acá?' o '¿cómo empiezo?'"
  - "usuario dice 'corré el onboarding' o 'hacé un tour'"
---

# Skill: onboarding

## Propósito

Dar un tour guiado del workspace `grv-ai-workspace` a usuarios nuevos o
existentes del equipo de AYI que nunca lo exploraron a fondo. Este skill
es **conversacional**: no genera artefactos, solo guía.

## Cuándo usarme

- Primera vez que alguien del equipo abre Claude Code en este workspace.
- Alguien quiere entender qué skills/agents existen.
- Alguien vuelve al workspace tras tiempo y necesita refrescar qué cambió.

## Cuándo NO usarme

- El usuario ya sabe qué quiere y pide un skill específico — ir directo a ese.
- El usuario es el owner o co-maintainer (ya conocen la estructura).

## Flujo

### Paso 1 — Bienvenida y contexto

Saludar brevemente y preguntar:

1. ¿Es tu primera vez en `grv-ai-workspace`?
2. ¿Qué te trajo acá? (opciones: "explorar qué hay", "una tarea concreta", "me lo recomendaron")
3. ¿Qué tipo de trabajo hacés en el equipo de AYI sobre la plataforma GRV? (backend, frontend, devops, PM, QA, otro)

Adaptar el tour según las respuestas. Si menciona "una tarea concreta",
ofrecer ir directo al skill apropiado en lugar del tour completo.

### Paso 2 — Explicación del propósito

En 3-4 oraciones, explicar:

> "Este workspace asiste al equipo de AYI en el desarrollo sobre la
> plataforma de GRV. Combina conocimiento del dominio (siniestros, turnos,
> autorizaciones, facturación, integraciones), prácticas de ingeniería
> (review de migraciones, code review, tests, documentación) y análisis
> de procesos (oportunidades de automatización). Se integra a Claude Code
> via skills, agentes, hooks y MCPs."

Referencia clave: `CLAUDE.md`. Mencionar también la regla de oro: "si no sé, pregunto, no invento".

### Paso 3 — Tour de los ejes

Mostrar los 3 ejes del workspace con 1 ejemplo cada uno:

**Dominio** (`skills/domain/`):
> "Skills que conocen el dominio GRV: ART, SRT, siniestros laborales (AT,
> EP, in-itinere), turnos, traslados, autorizaciones médicas, prestaciones,
> facturación, integraciones con Provincia ART / SGC / Satapp / SAP.
> Ej: `grv-regulaciones-srt` te puede responder qué dice la Res. 3326/14."

**Ingeniería** (`skills/engineering/`):
> "Skills para review de migraciones SQL, code review de Spring Boot y
> React, generación de tests funcionales, sincronización de Swagger,
> mantenimiento de changelog y diagramas C4. Ej: si tocás una migración,
> `mariadb-migration-review` te valida el checklist antes de commitear."

**Procesos** (`skills/processes/`):
> "Skills para detectar oportunidades de automatización, convertir
> transcripciones de Granola en action items, y generar post-mortems
> de deploys."

### Paso 4 — Tour de los agentes

Explicar qué es un agente (rol con contexto propio) y mostrar los 6:

- `grv-domain-expert` — consultor del negocio
- `grv-reviewer` — code review con reglas del equipo
- `grv-migration-guard` — migraciones SQL
- `grv-test-author` — tests funcionales reales
- `grv-doc-keeper` — documentación sincronizada
- `grv-process-analyst` — oportunidades de automatización

### Paso 5 — Tour de los MCPs

Listar los MCPs disponibles y para qué sirve cada uno:

- **mariadb-dev / mariadb-prod** — consultar la BD real en AWS RDS (read-only, con salvaguardas)
- **context7** — documentación actualizada de libs
- **sequential-thinking** — razonamiento paso a paso para tareas complejas
- **playwright** — E2E testing y verificación visual
- **granola** — transcripciones de reuniones

Advertir: MariaDB **siempre arranca en DEV**. El cambio a PROD es explícito
y requiere confirmación.

### Paso 6 — Hooks activos

Mencionar que hay hooks que se disparan automáticamente:

- pre-commit de migraciones (warn)
- pre-commit de secretos (blocking)
- pre-commit de API sync (warn)
- post-edit de tests (warn)

### Paso 7 — Primera tarea sugerida

Según el perfil del usuario, sugerir una primera tarea para probar:

- **Backend dev**: "¿querés que revisemos juntos una migración SQL que tengas pendiente?"
- **Frontend dev**: "¿tenés un MR de frontend que podamos pasar por `react-mfe-review`?"
- **Tech lead / PM**: "¿querés que tomemos la última reunión de Granola y saquemos action items?"
- **QA**: "¿tenés un ticket al que le falten tests? Probemos `functional-test-author`."

### Paso 8 — Cierre

Recordar:

1. El archivo `CLAUDE.md` es el contexto global (leer si querés saber más).
2. `GOVERNANCE.md` explica cómo contribuir.
3. `docs/case-studies/` tiene ejemplos reales de uso.
4. La **regla de oro**: si Claude no sabe algo, pregunta. No inventa.
5. **Si durante el uso llenás un hueco del workspace** (definís un término,
   confirmás un nombre, reportás un bug nuevo), Claude va a ofrecerte
   capturarlo como contribución via `workspace-contribution`. Es opt-in:
   vos decidís si sí, si lo guardás en buffer para después, o si no.
   Las contribuciones quedan en ramas `contrib/<tu-nombre>/<slug>` para
   que las LTs revisen.
6. Feedback al owner del workspace (`[OWNER_NAME]`).

Ofrecer quedarse disponible para cualquier duda o dar paso al skill que
corresponda a la tarea real del usuario.

## Output

Una conversación de ~5-10 mensajes, no un artefacto. Al final, dejar al
usuario con una acción concreta sugerida.

## Límites

- No reemplaza la lectura de `CLAUDE.md` para usuarios técnicos que quieran profundizar.
- No sabe sobre skills que se agregaron después de la última actualización
  de este archivo — mantenerlo actualizado cuando el inventario de skills cambie.

## Notas para el mantenedor

Cuando se agrega o saca un skill/agente/MCP significativo, revisar este
skill y actualizar los pasos 3, 4, 5.

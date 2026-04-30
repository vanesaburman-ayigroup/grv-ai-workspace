---
name: sprint-planning-impact
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [cross-team-impact, release-readiness, tech-debt-audit, database-design-heavy-table]
related_agents: [grv-tech-lead]
triggers:
  - "preparar el sprint"
  - "revisar el backlog antes del planning"
  - "cuánto impacto tiene este ticket"
  - "sizing del sprint"
  - "qué preguntar en el refinamiento"
  - "dependencias entre tickets"
---

# Skill: sprint-planning-impact

## Propósito

Evaluar el impacto sistémico de los tickets del sprint **antes del refinamiento**, para que el tech lead llegue con preguntas precisas y el equipo pueda estimar con información real.

La diferencia entre un refinamiento productivo y uno que da vueltas en círculos suele ser cuánto preparó el tech lead.

## Cuándo usarme

- 1-2 días antes del refinamiento / planning del sprint.
- Al evaluar si un ticket es tan grande que hay que partirlo.
- Cuando hay dudas sobre el orden de implementación de tickets que se tocan.

## Cuándo NO usarme

- Para hacer el refinamiento en sí (el skill prepara la info, el equipo decide).
- Para un ticket de bugfix simple sin impacto en otras partes.

## Dimensiones de evaluación por ticket

Para cada ticket del sprint, el skill evalúa:

### 1. Servicios tocados
Cruzar con `context/microservices.yaml`:
- ¿Qué microservicio(s) hay que modificar?
- ¿Hay cambios en contratos de API (nuevos endpoints, campos nuevos)?
- ¿Hay cambios de schema de BD?

### 2. Riesgo técnico
| Señal | Nivel de riesgo |
|---|---|
| Toca tabla heavy (siniestros, auditoria_facturacion_log) | ALTO |
| Hay migration SQL | MEDIO-ALTO |
| Breaking change en API | ALTO |
| Integración con sistema externo (SATApp, SAP) | MEDIO |
| Solo código interno sin cambio de contrato | BAJO |

### 3. Dependencias entre tickets del sprint
¿El ticket A debe terminarse antes de empezar el ticket B? ¿Por qué?
Detectar dependencias ocultas que el equipo quizás no vio.

### 4. Sizing sugerido

Estimación basada en señales técnicas (no sustituye la estimación del equipo):
- **S** (1-2 días): cambio en un solo servicio, sin migration SQL, sin cambio de contrato
- **M** (3-5 días): cambio en 1-2 servicios, con migration SQL sencilla, o cambio de API non-breaking
- **L** (1-2 semanas): múltiples servicios, migration SQL en tabla heavy, o breaking change con coordinación requerida
- **XL** (+ de 2 semanas): sugiere partir el ticket

### 5. Preguntas para el PO / refinamiento

Qué información falta para estimar correctamente:
- ¿Cuáles son los criterios de aceptación exactos para este caso borde?
- ¿El campo X es obligatorio o opcional?
- ¿Hay que actualizar el registro histórico o solo los nuevos?

## Flujo

### Paso 1 — Recibir el backlog del sprint

Pedir la lista de tickets (IDs o descripción). Si hay acceso al Jira MCP, leerlos directamente.

### Paso 2 — Evaluar cada ticket

Aplicar las 5 dimensiones de evaluación.

### Paso 3 — Detectar dependencias entre tickets

Identificar si algún ticket del sprint depende de otro del mismo sprint. Proponer orden.

### Paso 4 — Calcular carga real del sprint

Sumar las estimaciones y comparar con la capacidad del equipo. Si la suma es muy alta, señalar qué sacar.

## Output

```
SPRINT PLANNING IMPACT — Sprint <número>
==========================================

TICKETS EVALUADOS

| Ticket | Servicios | Riesgo | Migration | Sizing | Dependencias |
|---|---|---|---|---|---|
| GRV-1234 | ws-siniestralidad | ALTO | Sí (tabla heavy) | L | Ninguna |
| GRV-1235 | ws-facturacion | BAJO | No | S | Ninguna |
| GRV-1236 | ws-siniestralidad + ws-facturacion | ALTO | No (breaking API) | M | GRV-1234 debe ir primero |
| GRV-1237 | app-frontend | BAJO | No | M | Depende de GRV-1236 |

DEPENDENCIAS DETECTADAS
  GRV-1234 → GRV-1236 → GRV-1237 (cadena de 3 tickets, todos en el sprint)
  Riesgo: si GRV-1234 se atrasa, los dos siguientes también se atrasan.
  Recomendación: arrancar GRV-1234 el primer día del sprint.

CARGA ESTIMADA
  L (8 días) + S (2 días) + M (5 días) + M (5 días) = 20 días
  Si el equipo tiene 3 devs × 10 días = 30 días disponibles → cabe, pero justo.

PREGUNTAS PARA EL PO (por ticket)
  GRV-1234: ¿La migration debe preservar el histórico de datos o solo aplica a registros nuevos?
  GRV-1236: ¿Los consumers de /v1/siniestros/{id} en ws-facturacion pueden actualizar en el mismo sprint?

FLAGS DE RIESGO
  🔴 GRV-1234: migration en tabla heavy — necesita strategy de database-design-heavy-table antes de implementar
  🟡 GRV-1236: breaking change en API — coordinar con equipo de facturación (ver cross-team-impact)
```

## Límites

- Alpha: sin integración con Jira MCP — el usuario debe proveer la descripción de los tickets.
- El sizing sugerido es una heurística técnica, no reemplaza la estimación del equipo.
- No evalúa el impacto de negocio (prioridad desde el PO) — solo el impacto técnico.

## TODO para promover a beta

- [ ] Integrar con Jira MCP para leer tickets directamente
- [ ] Calibrar los criterios de sizing con el equipo (¿los tamaños S/M/L coinciden con la experiencia?)
- [ ] Usado en 1 sprint real con retroalimentación incorporada

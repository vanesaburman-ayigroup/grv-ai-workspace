---
name: cross-team-impact
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [release-readiness, sprint-planning-impact, api-design-review, database-design-heavy-table]
related_agents: [grv-tech-lead, grv-architect]
triggers:
  - "qué se rompe si cambio X"
  - "qué servicios dependen de Y"
  - "quién más usa esta tabla"
  - "impacto del cambio"
  - "a quién notificar"
  - "orden de deploy"
---

# Skill: cross-team-impact

## Propósito

Identificar todos los servicios y equipos afectados por un cambio antes de implementarlo. Consulta `context/microservices.yaml` para construir el árbol de dependencias y produce: lista de servicios a notificar, orden de deploy seguro, y señales de riesgo.

## Cuándo usarme

- Antes de hacer un breaking change en una API.
- Cuando se refactoriza una tabla de BD compartida entre servicios.
- Al planificar un cambio que toca el schema de un evento SQS.
- Para saber en qué orden deployar múltiples servicios que cambian juntos.

## Cuándo NO usarme

- Para evaluar el impacto técnico interno de un servicio → usá `spring-boot-review`.
- Para gestionar el incident si algo ya se rompió → usá `incident-command`.

## Fuentes de información

- `context/microservices.yaml`: dependencias entre servicios (qué llama a qué)
- `context/integrations.yaml`: integraciones externas
- `context/heavy-tables.yaml`: qué servicios comparten tablas
- `context/team.yaml`: owners de cada servicio

## Tipos de dependencia a analizar

| Tipo | Ejemplo | Riesgo |
|---|---|---|
| API REST directa | ws-facturacion llama a ws-siniestralidad `/v1/siniestros/{id}` | ALTO: breaking change rompe inmediatamente |
| Tabla de BD compartida | `auditoria_facturacion_log` usada por ws-facturacion y ws-siniestralidad | ALTO: cambio de schema afecta ambos |
| Evento SQS | ws-prestaciones emite evento que consume ws-notificaciones | MEDIO: schema del evento cambia |
| Configuración compartida | config-server con properties compartidas | BAJO-MEDIO |

## Flujo

### Paso 1 — Describir el cambio

Pedir al usuario:
1. ¿Qué se cambia? (endpoint, tabla, evento SQS, librería compartida)
2. ¿Es breaking o non-breaking?
3. ¿En qué servicio está el cambio?

### Paso 2 — Construir árbol de dependencias

Leer `context/microservices.yaml` y encontrar:
- **Dependencias directas**: servicios que llaman directamente al servicio/endpoint/tabla afectados
- **Dependencias transitivas**: servicios que dependen de los anteriores (2 saltos)
- Para tablas: qué servicios leen o escriben en esa tabla

### Paso 3 — Clasificar el impacto

Para cada servicio afectado:
- **Impacto directo**: puede romperse si el cambio se deploya sin coordinación
- **Impacto indirecto**: puede ser afectado si alguno de sus dependientes se rompe
- **Sin impacto**: el servicio usa el recurso de una manera que no cambia

### Paso 4 — Orden de deploy

Para cambios coordinados (varios servicios cambian juntos), definir el orden seguro:
1. Deployar primero el servicio con la interfaz nueva (backward compatible)
2. Migrar los consumers uno a uno
3. Remover la interfaz vieja

### Paso 5 — Lista de notificaciones

Para cada equipo owner de un servicio afectado, generar el mensaje de notificación.

## Output

```
CROSS-TEAM IMPACT — <cambio>
==============================
Servicio origen: ws-siniestralidad
Cambio: Se remueve campo 'codigo_legacy' de GET /v1/siniestros/{id} response

ÁRBOL DE DEPENDENCIAS
  ws-siniestralidad
  ├── ws-facturacion [IMPACTO DIRECTO — usa 'codigo_legacy' en cálculo de facturas]
  ├── app-frontend [IMPACTO DIRECTO — muestra 'codigo_legacy' en pantalla de detalle]
  └── ws-reportes [SIN IMPACTO — solo usa campos fecha_accidente y estado]

CLASIFICACIÓN
  🔴 ws-facturacion: CRÍTICO — remover campo antes de actualizar ws-facturacion rompe la integración
  🔴 app-frontend: CRÍTICO — hay que actualizar el frontend junto con el backend
  🟢 ws-reportes: SIN IMPACTO

ORDEN DE DEPLOY RECOMENDADO
  1. Agregar /v2/siniestros/{id} sin codigo_legacy (mantener /v1 con el campo)
  2. Deploy ws-facturacion actualizado para usar /v2/
  3. Deploy app-frontend actualizado
  4. Deprecar /v1/siniestros/{id} (90 días de margen)
  5. Remover /v1/ en un deploy posterior

EQUIPOS A NOTIFICAR
  - Equipo Facturación: ver context/team.yaml para el owner de ws-facturacion
  - Equipo Frontend: owner de app-frontend
  Mensaje sugerido: "Se planea remover el campo 'codigo_legacy' del endpoint 
  GET /v1/siniestros/{id}. Nueva versión disponible en /v2/. 
  Migración requerida antes de [fecha]."

RIESGO GENERAL: ALTO — requiere coordinación entre 2 equipos
```

## Límites

- Alpha: `context/microservices.yaml` puede estar desactualizado — el skill advierte cuando hay incertidumbre.
- No detecta dependencias que no estén documentadas en el contexto (dependencias implícitas por BD directa, por ejemplo).
- El árbol de dependencias transitivas se limita a 2 saltos para evitar falsos positivos.

## TODO para promover a beta

- [ ] Actualizar `context/microservices.yaml` con dependencias completas (hoy incompleto)
- [ ] Caso de estudio real: cambio coordinado entre 2+ servicios documentado
- [ ] Agregar a `context/team.yaml` los owners actualizados por servicio

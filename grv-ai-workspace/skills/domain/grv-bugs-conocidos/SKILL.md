---
name: grv-bugs-conocidos
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: domain
related_skills: [grv-arquitectura-plataforma, grv-turnos-logistica, grv-siniestros]
related_agents: [grv-reviewer, grv-domain-expert]
triggers:
  - "usuario reporta un bug y hay que verificar si ya lo conocemos"
  - "usuario pregunta '¿esto se parece a algún bug que tuvimos?'"
  - "reviewer detecta un patrón sospechoso y quiere cruzarlo con el catálogo"
---

# Skill: grv-bugs-conocidos

## Propósito

Ser el catálogo vivo de bugs conocidos y aleccionadores de la plataforma.
Funciona como memoria institucional: cuando alguien reporta un síntoma,
este skill verifica si ya lo vimos antes y apunta al root cause documentado
o al pattern.

## Fuente de verdad

**`context/known-bugs.yaml`**. Si un bug no está ahí, este skill **no lo
conoce** y lo dice. No inventa bugs parecidos ni completa con suposiciones.

## Cuándo usarme

- "Estamos viendo X, ¿se parece a algo que ya debuggeamos?"
- "Antes de tocar el servicio wsturnos, ¿hay bugs abiertos que debería tener en cuenta?"
- "El reviewer detectó un `@Recover` sospechoso — ¿es el patrón conocido?"
- Preparación de retrospectivas o post-mortems.

## Cuándo NO usarme

- Para debuggear en tiempo real un bug nuevo — ese es trabajo del
  reviewer + domain expert + código.
- Para documentar un bug nuevo — ese flujo es un MR al workspace que
  agrega una entry al YAML.

## Flujo

1. Escuchar al usuario y extraer los síntomas observables (qué se ve, qué
   servicio, qué datos).
2. Buscar en `known-bugs.yaml` por:
   - `services` que coincidan
   - `symptoms` parecidos
   - `pattern` similar
3. Si hay match: devolver el id del bug, estado, root cause documentado
   y hint de detección.
4. Si hay duda: mostrar los candidatos y dejar que el usuario discrimine.
5. Si no hay match: **decirlo claramente**. No inventar un bug que
   "podría ser parecido".
6. Ofrecer documentarlo como bug nuevo en el YAML si aplica.

## Output

```
Match encontrado: <id-del-bug>
Estado: <open | fixed | mitigated>
Servicios: <lista>
Root cause: <...>
Pattern: <...>
Hint de detección: <...>

Para diagnosticar este caso específico: <pasos sugeridos>
```

Si no hay match:

```
No encontré un bug conocido que coincida con estos síntomas. Los bugs
abiertos en los servicios <lista> son: <ids>.

¿Querés que lo documentemos como bug nuevo en context/known-bugs.yaml?
Te ayudo a estructurarlo.
```

## Ejemplos

### Ejemplo 1: match directo

**Usuario**: Después de cancelar un turno, el traslado asociado quedó en
estado ASIGNADO en la planilla. ¿Ya habíamos visto esto?

**Respuesta**:
```
Sí, matchea con bug-logistica-etiqueta-asignado (abierto).

Servicios: wsturnos, wslogistica
Root cause: el @Recover en WSTurnos silencia el fallo de actualización
            de etiqueta en WSLogistica. El traslado se cancela pero la
            etiqueta sigue 1/ASIGNADO.
Pattern: retry con @Recover que silencia errores sin compensar ni propagar.
Caso histórico emblemático: traslado ID 2469285.

Para diagnosticar este caso específico:
1. Revisar logs de WSTurnos en el momento de la cancelación.
2. Verificar estado en BD (dev primero): traslados y traslados_etiquetas.
3. Revisar el método de anulación buscando @Recover.

Referente: [LOGISTICS_REFERENT].
```

### Ejemplo 2: pattern match sin id exacto

**Usuario**: Tenemos un caso donde un servicio hace un retry con @Recover
sobre una llamada a otra BD y nadie se entera cuando falla.

**Respuesta**:
```
Esto matchea con el pattern de dos bugs del catálogo:

- bug-logistica-etiqueta-asignado (caso concreto en wsturnos/wslogistica)

Pattern común: "Retry con @Recover que silencia errores sin compensar
ni propagar".

Fix hint que ya tenemos documentado:
- @Recover debe: (a) loguear con contexto completo, (b) marcar el
  registro como inconsistente para reconciliación posterior, (c) emitir
  evento/métrica.

Si el caso que viste es en un servicio distinto, ¿querés que lo agreguemos
como bug nuevo en known-bugs.yaml con el mismo pattern?
```

### Ejemplo 3: no match

**Usuario**: Tengo un bug donde una consulta de prestaciones devuelve
el doble de filas cuando se filtra por cierta fecha.

**Respuesta**:
```
No tengo un bug conocido que coincida con estos síntomas. Los bugs
documentados sobre prestaciones son: (ninguno específico en
known-bugs.yaml todavía).

Esto parece un bug nuevo. Si confirmás el comportamiento, te ayudo a:
1. Diagnosticarlo con el MCP de MariaDB dev (con LIMIT).
2. Documentarlo como entry nueva en known-bugs.yaml una vez que
   tengamos root cause.
```

## Ofrecer captura como contribución

Cuando el usuario reporta un bug que claramente no está en el catálogo
y tiene suficiente info (síntomas, servicios, root cause o al menos
hipótesis), al cierre del flujo ofrecer invocar `workspace-contribution`
con `type: known-bugs`. Ver
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` debe estar formado como entry YAML siguiendo el
formato de `context/known-bugs.yaml` (id, title, status, services,
root_cause, symptoms, pattern, detection_hint).

**Importante**: no capturar como contribución bugs sin root cause aún.
Si el bug está en fase de diagnóstico, esperar a tener al menos una
hipótesis sólida antes de agregarlo al catálogo.

## Límites

- El catálogo no es exhaustivo. Solo contiene los bugs que el equipo
  decidió documentar como aleccionadores.
- No reemplaza herramientas de tracking (Jira, Sentry). Es memoria,
  no sistema de tickets.

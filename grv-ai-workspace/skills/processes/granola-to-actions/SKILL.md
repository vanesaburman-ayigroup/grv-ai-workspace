---
name: granola-to-actions
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [automation-finder]
related_agents: [grv-process-analyst]
triggers:
  - "usuario pide 'resumí la reunión' o 'saca action items de la reunión'"
  - "usuario pega o menciona una transcripción de Granola"
  - "usuario dice 'qué decidimos en la reunión de ayer'"
---

# Skill: granola-to-actions

## Propósito

Transformar una transcripción de reunión (desde Granola vía su MCP, o
pegada manualmente) en un conjunto estructurado de: decisiones, action
items con responsable, riesgos, y preguntas abiertas.

## Fuente de verdad

- **La transcripción cruda** es la fuente primaria. Todo lo que el skill
  diga tiene que poder rastrearse a una parte específica de la transcripción.
- Si algo "no se dijo pero es razonable asumir", el skill **no lo asume**.
  Lo marca como "no cubierto explícitamente en la reunión".

## Cuándo usarme

- Post-reunión, para capturar qué se decidió sin que alguien tenga que
  hacerlo a mano.
- Cuando un dev pregunta "¿qué pasó en la reunión de planificación?"
  (usando Granola como memoria del equipo).
- Para alimentar al `automation-finder` con insights de procesos discutidos.

## Flujo

1. Obtener la transcripción (MCP Granola o pegada).
2. Leer completa (no saltar partes).
3. Identificar:
   - **Decisiones** ("acordamos X", "vamos con Y", "descartamos Z").
   - **Action items** ("X lo hace Juan para el miércoles").
   - **Preguntas abiertas** ("hay que averiguar si...").
   - **Riesgos mencionados** ("podría pasar que...").
   - **Temas no cerrados** (discusiones que no llegaron a decisión).
4. Atribuir responsables solo cuando están explícitos en la transcripción.
   Si dice "lo vemos después" sin asignar, no atribuir.
5. Generar el reporte.

## Regla de honestidad

- **Citas textuales cuando hay ambigüedad**. Si hay duda de si X se
  decidió o se discutió, citar el fragmento y dejar que el usuario
  decida cómo interpretarlo.
- **Nunca poblar un campo inventando**. Si no hay decisiones, el bloque
  de decisiones queda vacío con un "No se tomaron decisiones explícitas
  en esta reunión".

## Output

```
===========================================================
MEETING NOTES — <título o fecha>
Duración: <si está disponible>
Participantes: <lista si está disponible>
===========================================================

RESUMEN EN UNA LÍNEA
  <una oración con el punto central de la reunión>

DECISIONES
  1. <decisión> — contexto breve
  2. ...

ACTION ITEMS
  - [ ] <acción> — responsable: <nombre> — fecha: <si se mencionó>
  - [ ] ...

PREGUNTAS ABIERTAS
  - <pregunta> (nadie lo respondió en la reunión)
  - ...

RIESGOS MENCIONADOS
  - <riesgo>
  - ...

TEMAS NO CERRADOS
  - <tema discutido sin decisión>
  - ...

AMBIGÜEDADES
  [cosas que necesitan confirmación de un participante]
```

## Ejemplo de ambigüedad bien manejada

**Transcripción** (fragmento):
> Pri: "...y con respecto al bug del traslado, creo que podemos dejarlo
> para la próxima sprint, ¿no?"
> Vane: "sí, dale"
> (pasan a otro tema sin más detalle)

**Output relevante**:
```
DECISIONES
  1. El bug del traslado se posterga a la próxima sprint.
     Contexto: acordado entre Pri y Vane, sin detalle de cuál bug específico
     ni prioridad asignada para la próxima sprint.

AMBIGÜEDADES
  - ¿A qué bug del traslado se refieren? En el workspace hay dos abiertos:
    bug-logistica-anular-turno y bug-logistica-etiqueta-asignado. Confirmar
    con Pri/Vane cuál es.
```

## Límites

- La calidad del output depende de la calidad de la transcripción. Granola
  es bueno pero no perfecto; nombres de personas a veces se confunden.
- No "interpreta" lo que no se dijo. Si la reunión fue caótica y no se
  cerró nada, el reporte va a reflejar eso (y eso es útil: señala que
  hace falta una reunión de seguimiento).
- No atribuye fechas cuando no se mencionaron. "Para el próximo sprint"
  sin fecha concreta se mantiene así.

## TODO para promover a beta

- [ ] Mejor integración con Granola MCP (búsqueda por fecha, serie de reuniones).
- [ ] Detección de temas recurrentes a lo largo de varias reuniones (para
      alimentar `automation-finder`).
- [ ] Plantilla de export para pegar directo en Notion/Confluence.

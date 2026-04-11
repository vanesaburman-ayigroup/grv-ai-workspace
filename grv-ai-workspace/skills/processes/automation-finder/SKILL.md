---
name: automation-finder
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [granola-to-actions, deploy-post-mortem]
related_agents: [grv-process-analyst]
triggers:
  - "usuario pide '¿qué podemos automatizar?'"
  - "usuario describe un proceso manual repetitivo"
  - "usuario comparte una transcripción de reunión buscando oportunidades"
  - "review mensual de tickets cerrados para oportunidades"
---

# Skill: automation-finder

## Propósito

Detectar oportunidades de automatización dentro del trabajo del equipo y
del cliente. No automatiza nada por su cuenta — analiza y propone
candidatos con estimación de esfuerzo, impacto y riesgo.

## Insumos posibles

- **Descripción verbal** de un proceso manual.
- **Transcripción de reunión** (via Granola MCP).
- **Lista de tickets cerrados** de Jira (manual o via integración futura).
- **Logs de incidentes recurrentes** (Sentry, post-mortems).
- **Bug repetitivos** del catálogo (`known-bugs.yaml`).

## Heurística de detección

Un proceso es buen candidato a automatizar si cumple 3+ de estas:

1. **Repetitivo**: ocurre al menos 1 vez por semana.
2. **Basado en reglas**: la decisión humana sigue un criterio claro.
3. **Alto volumen**: consume varias horas/semana del equipo.
4. **Baja variabilidad**: los inputs son parecidos cada vez.
5. **Error humano frecuente**: los fallos se explican por olvido o fatiga.
6. **Fácilmente observable**: hay datos (logs, tickets) que lo registran.

Un proceso es **mal candidato** si:

- Requiere juicio experto caso a caso.
- Los inputs varían mucho.
- Ocurre pocas veces pero cada vez es distinto.
- El costo de un error automatizado es alto y difícil de detectar.

## Cuándo usarme

- Retrospectiva mensual: "¿qué podemos sacar del plato humano?"
- Planificación de iniciativas de IA interna.
- Cuando el PM pregunta "¿en qué estamos perdiendo tiempo?"
- Análisis de bugs repetitivos para proponer detectores automáticos.

## Flujo

1. Pedir el insumo (proceso, transcripción, tickets, logs).
2. Identificar los "pasos" del proceso actual.
3. Aplicar la heurística — ¿es buen candidato?
4. Si es buen candidato, proponer una o más opciones:
   - **Automatización total** (bot / job / integración).
   - **Asistencia** (skill de Claude, herramienta que ayuda pero no decide).
   - **Mejora de proceso** (sin IA, solo cambios de flujo).
5. Para cada opción, estimar: esfuerzo (S/M/L), impacto (bajo/medio/alto),
   riesgo (bajo/medio/alto).
6. Sugerir cómo empezaría el POC si el equipo aprueba.

## Output

```
===========================================================
AUTOMATION FINDER
Proceso analizado: <nombre>
Insumo: <descripción | transcripción | tickets>
===========================================================

DESCRIPCIÓN DEL PROCESO ACTUAL
  Pasos: ...
  Frecuencia: ...
  Tiempo aproximado por ejecución: ...
  Quién lo ejecuta: ...

DIAGNÓSTICO (aplicando heurística)
  ✅ Repetitivo
  ✅ Basado en reglas
  ❓ Alto volumen (pendiente de confirmar)
  ✅ Baja variabilidad
  ...
  Conclusión: buen / mal / dudoso candidato

PROPUESTAS

  Opción A — <título>
    Qué hace: ...
    Esfuerzo: M
    Impacto: alto
    Riesgo: bajo
    Primer paso: ...

  Opción B — <título>
    ...

RIESGOS Y OBJECIONES ANTICIPADAS
  ...

DATOS QUE FALTAN PARA DECIDIR
  ...
```

## Ejemplo

**Usuario**: Cada vez que mergeamos una migración nueva a dev, alguien
del equipo tiene que revisar manualmente que el esquema en dev coincida
con el código. Nos toma como 20 min cada vez, y lo hacemos 3-4 veces por
semana. A veces se nos pasa y rompemos el pipeline.

**Respuesta**:
```
Diagnóstico: BUEN CANDIDATO a automatización.

Heurística:
  ✅ Repetitivo (3-4/semana)
  ✅ Basado en reglas (comparar schema vs migraciones del repo)
  ✅ Volumen razonable (~80 min/semana)
  ✅ Baja variabilidad
  ✅ Error humano documentado ("a veces se nos pasa")

Propuestas:

  Opción A — Hook + skill `db-versioning-audit` en CI
    Qué hace: en cada MR, antes del merge a dev, correr
      db-versioning-audit automáticamente y bloquear el merge si hay
      drift entre repo y dev.
    Esfuerzo: S (el skill ya existe en alpha, falta armarle un job CI)
    Impacto: alto (0 min/semana humanos, elimina los "se nos pasa")
    Riesgo: bajo (solo lee dev)
    Primer paso: definir cómo tracker las migraciones aplicadas (tema
      pendiente en el skill). Una vez definido, armar el job.

  Opción B — Notificación diaria post-sync
    Qué hace: un cron diario que corre el audit y manda reporte al
      canal del equipo si hay drift.
    Esfuerzo: S
    Impacto: medio (detecta el problema pero después del hecho)
    Riesgo: bajo
    Recomendación: complementa a la opción A, no la reemplaza.

Datos que faltan:
  - ¿Cómo trackeamos migraciones aplicadas? (Bloqueante para ambas opciones.
    Ver db-versioning-audit → TODO).
  - ¿El pipeline actual permite agregar un job bloqueante antes del merge?

Sugiero arrancar con Opción A pero solo después de resolver el tracking.
```

## Límites

- No ejecuta automatizaciones — solo propone.
- La estimación de esfuerzo es aproximada; depende del contexto real.
- No ve "el bosque" del equipo — depende de que el usuario aporte el
  panorama de carga actual.

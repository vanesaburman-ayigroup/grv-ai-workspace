---
name: incident-triage
version: v1
maturity: alpha
when_to_use: "Triage rápido de un incidente en producción mientras está activo. No reemplaza el post-mortem posterior."
---

# Prompt: incident-triage

## Cuerpo

```
Modo: INCIDENT TRIAGE. Esto es un incidente activo en producción.
Prioridad: respuestas rápidas y accionables. Sin divagar.

Actuá como grv-reviewer + grv-domain-expert.

Voy a describirte el síntoma. Necesito, en este orden:

1. SEVERIDAD PROPUESTA (P0/P1/P2/P3) y por qué.
2. SERVICIOS POTENCIALMENTE INVOLUCRADOS (consultar microservices.yaml).
3. MATCH CON BUGS CONOCIDOS (consultar known-bugs.yaml).
4. PRIMERA ACCIÓN DE MITIGACIÓN recomendada (rollback, feature flag,
   kill switch, query manual, etc).
5. QUÉ DATOS NECESITO YA para confirmar la hipótesis.
6. A QUIÉN ESCALAR según ownership (consultar team.yaml).

Reglas del modo incidente:
- Respuestas breves, bullets, sin prosa larga.
- Si no sabés algo crítico, pedímelo en una sola pregunta clara.
- NO propongas fix definitivo. Eso es para después del triage.
- Si hay riesgo de pérdida de datos o caída total, marcalo PRIMERO.

Síntoma:
{SYMPTOM}

Servicios que se sospechan (si alguien ya indicó):
{SUSPECT_SERVICES}

Ventana temporal:
{TIMEFRAME}

Quién reportó:
{REPORTER}
```

## Variables

- `{SYMPTOM}` — qué se está viendo en prod (obligatorio).
- `{SUSPECT_SERVICES}` — opcional.
- `{TIMEFRAME}` — cuándo empezó (opcional).
- `{REPORTER}` — quién avisó (opcional).

## Notas

- Este prompt es para los primeros 10 minutos del incidente. Después,
  ya con la mitigación en marcha, usar `deploy-post-mortem` para el
  análisis completo.
- No reemplaza la comunicación humana. El triage ayuda a quien está
  manejando el incidente, no lo sustituye.

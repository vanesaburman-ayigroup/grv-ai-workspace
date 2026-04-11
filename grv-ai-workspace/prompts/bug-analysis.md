---
name: bug-analysis
version: v1
maturity: beta
when_to_use: "Primer análisis estructurado de un bug reportado, antes de arrancar a debuggear."
---

# Prompt: bug-analysis

## Cuerpo

```
Actuá como grv-domain-expert combinado con grv-reviewer.

Voy a describirte un bug reportado. Antes de proponer fix, quiero que:

1. Identifiques el/los servicios involucrados consultando
   context/microservices.yaml.
2. Verifiques si el síntoma matchea con algún bug en
   context/known-bugs.yaml.
3. Si no hay match directo, busques patterns similares (@Recover
   silencioso, lock wait, race condition, etc).
4. Listes las 3 hipótesis más probables de root cause, ordenadas por
   probabilidad y con la evidencia que las sustenta.
5. Propongas qué datos o logs hacen falta para discriminar entre
   hipótesis. Si necesitás consultar datos reales, usá el MCP MariaDB
   dev (preguntame antes si hace falta prod).

NO propongas un fix todavía. El objetivo de este prompt es entender
antes de actuar.

Reglas:
- Si algo no está en el contexto y no podés verificar, pregúntame.
  No inventes.
- Si el bug es uno conocido, decímelo explícitamente con el id.

Descripción del bug:

{BUG_DESCRIPTION}

Datos adicionales (si los tengo):
- Servicio sospechoso: {SERVICE}
- Fecha/hora del incidente: {TIMESTAMP}
- Usuario afectado / caso concreto: {CASE}
- Stack trace (si aplica): {STACK_TRACE}
- Logs relevantes: {LOGS}
```

## Variables

- `{BUG_DESCRIPTION}` — descripción libre del bug (obligatorio).
- `{SERVICE}` — servicio sospechoso (opcional).
- `{TIMESTAMP}` — cuándo pasó (opcional).
- `{CASE}` — caso concreto, ej. "traslado ID 2469285" (opcional).
- `{STACK_TRACE}` — si tenés uno (opcional).
- `{LOGS}` — fragmentos relevantes (opcional).

## Notas

- Funciona mejor cuando la descripción del bug es concreta ("el traslado
  quedó en ASIGNADO tras cancelar el turno") que cuando es vaga
  ("el sistema anda mal").
- Si el bug es crítico en prod, usar este prompt como primer paso pero
  escalarlo rápido a una reunión humana.

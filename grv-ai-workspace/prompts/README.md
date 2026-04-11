# Prompt Library

Prompts reutilizables para tareas recurrentes del equipo. Inspirados en
el concepto del tweet que disparó este workspace, pero con una diferencia:
**los prompts acá no viven aislados**. Se apoyan en skills, context y
agentes para no empezar cada vez desde cero.

## Formato

Cada prompt es un archivo `.md` con:

1. **Frontmatter**: `name`, `version`, `when_to_use`, `maturity`.
2. **Prompt**: el texto a copiar-pegar (o invocar directamente).
3. **Variables**: placeholders a completar por el usuario.
4. **Notas**: cuándo funciona, cuándo no.

## Convención de versionado

Tal como dice el tweet original: `v1 → v2 → v3` sin subversiones. La
historia queda en git.

## Prompts disponibles

- `bug-analysis.md` — primer análisis de un bug reportado.
- `feature-breakdown.md` — descomponer una feature grande en tickets.
- `mr-description.md` — generar descripción estructurada de un MR.
- `incident-triage.md` — triage rápido de un incidente en producción.

## Cómo agregar un prompt

1. Crear `<nombre>.md` con el frontmatter y el cuerpo.
2. Probar en al menos 1 caso real.
3. MR con descripción y caso de prueba.
4. Merge.

## Cómo usar un prompt desde Claude Code

```
Usuario: "usá el prompt bug-analysis para el ticket JIRA-1234"
Claude: [carga el prompt, lo completa con el contexto del ticket, y ejecuta]
```

O directamente copiar-pegar el cuerpo del prompt en una conversación.

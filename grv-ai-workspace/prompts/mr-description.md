---
name: mr-description
version: v1
maturity: beta
when_to_use: "Generar una descripción estructurada de un MR a partir del diff y el ticket."
---

# Prompt: mr-description

## Cuerpo

```
Generá una descripción de MR estructurada para el siguiente cambio.

Formato:

## ¿Qué resuelve?
[1-2 oraciones del problema, con link al ticket si aplica]

## ¿Cómo lo resuelve?
[Explicación concisa del approach. Si hay decisiones no obvias, justificarlas.]

## Archivos tocados
[Lista con 1 línea por archivo explicando qué cambió]

## Testing manual
[Pasos concretos para que un revisor pueda probarlo]

## Riesgo
[Bajo / Medio / Alto. Justificar. Mencionar cualquier bug conocido
relacionado (ver context/known-bugs.yaml).]

## Pendientes / Out of scope
[Cosas que NO cubre este MR y por qué, si aplica]

## Checklist
- [ ] Tests actualizados
- [ ] Documentación actualizada (swagger/changelog si aplica)
- [ ] Sin secretos hardcodeados
- [ ] Migraciones revisadas con grv-migration-guard (si aplica)

---

Reglas:
- No inventes archivos ni cambios que no estén en el diff.
- Si el diff tiene cambios no obvios, marcalos como "¿seguro que quisiste
  esto?" para que el autor revise.
- Si detectás un pattern peligroso conocido, incluirlo en Riesgo.

Inputs:

Ticket: {TICKET}
Diff:
{DIFF}
```

## Variables

- `{TICKET}` — descripción del ticket o link (obligatorio para contexto).
- `{DIFF}` — output de `git diff` o el contenido del MR (obligatorio).

## Notas

- El auto-review previo al MR se hace con `grv-reviewer`, no con este prompt.
  Este prompt solo genera la descripción.
- Si el MR es muy grande (>500 líneas), sugerir partirlo antes de
  generar descripción.

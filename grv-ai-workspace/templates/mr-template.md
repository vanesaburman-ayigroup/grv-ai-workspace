# <Título corto del MR, en imperativo>

Ticket: <JIRA-XXXX>

## ¿Qué resuelve?

<1-2 oraciones del problema que este MR resuelve. Si es feature,
describir el valor para el usuario. Si es bugfix, mencionar el síntoma.>

## ¿Cómo lo resuelve?

<Explicación concisa del approach. Mencionar decisiones no obvias y
por qué se tomaron así. Si descartaste otra opción, decilo.>

## Archivos tocados

- `ruta/al/archivo.java` — qué cambió
- `ruta/al/otro.sql` — qué cambió
- ...

## Testing manual

Pasos concretos para que un revisor pueda reproducir:

1. ...
2. ...
3. ...

Resultado esperado: ...

## Riesgo

**Nivel**: bajo | medio | alto

**Justificación**: ...

**Bugs conocidos relacionados** (de `context/known-bugs.yaml`): ninguno / lista

## Pendientes / Out of scope

Cosas que este MR NO cubre y por qué:
- ...

## Checklist

- [ ] Tests actualizados (validados contra fuente de verdad, no contra implementación)
- [ ] Documentación actualizada (swagger, changelog, README) si aplica
- [ ] Sin secretos hardcodeados
- [ ] Migraciones revisadas con `grv-migration-guard` (si aplica)
- [ ] Code review con `grv-reviewer` antes de pedir review humano
- [ ] Compatible backward con código vivo durante el deploy (si aplica)
- [ ] Commits convencionales (`feat:`, `fix:`, etc)

## Screenshots / GIFs (opcional)

<Si el cambio es visual, agregar screenshot del antes/después.>

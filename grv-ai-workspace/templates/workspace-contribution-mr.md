# [workspace-suggestion] <Título corto>

**Tipo**: glossary | microservices | best-practices | regulations | known-bugs | integrations
**Autor**: <git user.name>
**Capturado desde**: Claude Code (skill `workspace-contribution`)
**Label**: `workspace-contribution`

## ¿Qué agrega/corrige este MR?

<1-2 oraciones describiendo el cambio. El skill `workspace-contribution`
completa esto automáticamente con la descripción que dio el usuario.>

## ¿De qué conversación salió?

<Contexto breve de la sesión donde se detectó el hueco. Ayuda al revisor
a entender por qué esta contribución apareció.>

## ¿Por qué importa?

<Por qué esta información es útil para el resto del equipo. Una oración
es suficiente.>

## Validaciones automáticas que pasó

- [x] YAML sigue siendo válido tras el cambio
- [x] Sin secretos detectados
- [x] Sin PII detectada (heurística conservadora)
- [x] Rama base actualizada al momento de la captura
- [x] Sin cambios locales no committeados en el archivo destino

## ¿Qué NO hizo el skill?

- No validó el contenido a nivel semántico (eso es el review humano).
- No creó este MR automáticamente — fue creado por el usuario con
  `git push` manual.
- No mergeó nada.

## Checklist del revisor (LT)

- [ ] El contenido es correcto a nivel de dominio.
- [ ] El formato es consistente con el resto del archivo.
- [ ] No introduce duplicados con otras entries existentes.
- [ ] Si toca un término con `status: pending`, ¿resuelve ese pendiente
      o hay que dejarlo marcado todavía?
- [ ] Si es un bug nuevo, ¿el pattern está bien capturado para que el
      reviewer lo pueda detectar en el futuro?
- [ ] Merge o pedir ajustes.

## Si hay que ajustar antes de mergear

Opciones:
1. **Cambios chicos**: editar directo en el MR y mergear.
2. **Cambios grandes**: comentar en el MR y pedirle al autor que
   vuelva a correr `workspace-contribution` con la versión corregida.
3. **Descartar**: cerrar el MR con una explicación (el autor la lee
   y aprende).

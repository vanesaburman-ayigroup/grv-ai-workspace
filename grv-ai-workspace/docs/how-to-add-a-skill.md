# How to add a skill

Un skill es una carpeta con un `SKILL.md` (obligatorio) y opcionalmente
scripts, templates o datos. Claude Code los autocarga cuando una tarea
los requiere.

## Estructura mínima

```
skills/<categoria>/<skill-name>/
├── SKILL.md          # Obligatorio
├── README.md         # Opcional pero recomendado para humanos
├── examples/         # Casos reales donde el skill se usó
│   └── 001-*.md
└── templates/        # Opcional: plantillas que el skill genera
```

`<categoria>` es una de: `domain`, `engineering`, `processes`, o `onboarding`.

## Frontmatter obligatorio del SKILL.md

```yaml
---
name: nombre-del-skill
version: v1
maturity: alpha  # alpha | beta | production
owner: "[OWNER_NAME]"
category: engineering
related_skills: []
related_agents: []
triggers:
  - "cuando el usuario pida review de una migración"
  - "cuando aparezca un archivo V0XX__*.sql modificado"
---
```

## Estructura del cuerpo

El SKILL.md sigue esta estructura (flexible pero recomendada):

1. **Propósito** — una frase: qué hace el skill.
2. **Cuándo usarme** — señales concretas que indican que corresponde.
3. **Cuándo NO usarme** — casos donde hay otro skill mejor o donde no aplica.
4. **Contexto necesario** — qué información pedirle al usuario antes de empezar.
5. **Flujo** — pasos numerados que el skill sigue.
6. **Output** — formato del resultado esperado.
7. **Ejemplos** — al menos uno real (en beta+, dos).
8. **Conocimiento de dominio** — referencias a `context/*.yaml`, resoluciones, etc.
9. **Límites conocidos** — qué no hace, dónde falla.

## Flujo para agregar un skill nuevo

1. Branch `feat/skill-<nombre>`.
2. Crear la carpeta y `SKILL.md` con frontmatter `maturity: alpha`.
3. Escribir el contenido basado en un caso real.
4. Probar el skill en al menos 1 caso → documentarlo en `examples/001-*.md`.
5. MR con descripción: problema que resuelve, caso de prueba, impacto.
6. Review de un maintainer.
7. Merge a main.
8. Entry en `CHANGELOG.md`.

## Promoción de nivel

Para subir de `alpha` → `beta`:

- Usado en al menos 3 casos reales.
- README del skill actualizado.
- Al menos 1 ejemplo documentado.
- Owner declarado.

Para subir de `beta` → `production`:

- Usado en al menos 5 casos reales.
- 2 ejemplos documentados (uno de éxito y uno que NO cubre).
- Validación por owner + 1 revisor distinto.
- Entry en `CHANGELOG.md` como MINOR bump.

## Buenas prácticas

- **Un skill = un problema**. Si notás que hace dos cosas, partilo.
- **Referí `context/*.yaml` en vez de duplicar**. Si necesitás saber qué servicios existen, apuntá a `microservices.yaml`, no copies la lista.
- **Escribí para Claude, no para humanos**. El SKILL.md es prompt engineering, no documentación bonita. Sé directo, imperativo, concreto.
- **Ejemplos reales, no inventados**. Un ejemplo de un ticket real vale más que 10 inventados.
- **Flujo numerado explícito**. Claude sigue mejor un "1. hacer X, 2. hacer Y" que un párrafo floreado.
- **Declarar triggers**. Ayudan a la autocarga del skill.

## Anti-patrones

- Skills que dependen de otros skills implícitamente (sin declararlo).
- Skills con >500 líneas — probablemente hacen muchas cosas, partir.
- Skills sin ejemplos (si no se usó, no existe).
- Skills con contenido que debería estar en `context/`.

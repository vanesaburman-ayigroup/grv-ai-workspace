# How to add an agent

Un **subagente** (o simplemente "agente") es un rol con contexto propio.
A diferencia de los skills (que son módulos de conocimiento cargables),
un agente tiene personalidad, criterio y se invoca explícitamente.

## Skill vs Agente — cuándo elegir cada uno

| | Skill | Agente |
|---|---|---|
| Qué es | Módulo de conocimiento + procedimiento | Rol con criterio propio |
| Invocación | Automática (por triggers) o explícita | Generalmente explícita |
| Contexto | Compartido con la sesión actual | Aislado, propio |
| Caso ideal | "Cómo hacer X" | "Pensá como Y" |
| Ejemplo | `mariadb-migration-review` | `grv-migration-guard` |

Regla simple: si lo que necesitás es un **procedimiento** → skill. Si
necesitás un **punto de vista** (reviewer, expert, analyst) → agente.

## Estructura

```
agents/<agent-name>.md
```

Un solo archivo markdown por agente. Sin frontmatter complejo.

## Plantilla

```markdown
# <agent-name>

**Rol**: <descripción en una línea>
**Maturity**: alpha | beta | production
**Owner**: [OWNER_NAME]
**Invocación**: explícita | automática

## Propósito

Qué hace este agente y por qué existe como rol separado.

## Skills que carga

Lista de skills que este agente usa automáticamente cuando se invoca:

- skills/domain/grv-glosario
- skills/engineering/mariadb-migration-review
- (etc)

## Personalidad y estilo

Cómo se expresa. Cuán asertivo. Qué asume. Qué pide antes de opinar.

## Límites

Qué NO hace. Cuándo delega a otro agente.

## Ejemplos de uso

### Ejemplo 1: ...

**Input del usuario**: ...
**Comportamiento esperado**: ...
```

## Flujo para agregar un agente

1. Branch `feat/agent-<nombre>`.
2. Evaluar primero: ¿esto debería ser un skill? Si sí, parar y hacer un skill.
3. Crear `agents/<nombre>.md` con la plantilla.
4. Probar el agente en 2+ casos reales.
5. MR con descripción y casos.
6. Review.
7. Entry en CHANGELOG.

## Buenas prácticas

- **Los agentes no duplican conocimiento**. Todo el conocimiento vive en skills y context. Los agentes orquestan.
- **Los agentes tienen opinión**. No son neutrales. Si no tenés claro el estilo, probablemente no hace falta el agente.
- **Los agentes pueden delegar a otros agentes**. Ej: el reviewer puede delegar una pregunta regulatoria al domain-expert.
- **Los agentes evolucionan más lento que los skills**. Cambiar un agente afecta a quien lo invoca; cambiar un skill es más contenido.

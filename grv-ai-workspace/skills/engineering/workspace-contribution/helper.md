# Helper — invocar workspace-contribution desde otros skills

Este archivo es para **otros skills** que quieran ofrecer captura de
contribución cuando detectan un hueco de información. Define el patrón
común de invocación para que no tengamos que duplicar la lógica en
cada skill.

## Cuándo otros skills deberían invocarme

Cuando se cumplan **las tres** condiciones:

1. El skill detectó un hueco de información en `context/` (un término
   no definido, un servicio no mapeado, un bug nuevo, una convención
   no documentada, etc).
2. El usuario aportó la información que faltaba en la conversación.
3. La información es del tipo que `workspace-contribution` puede
   capturar (ver "Scope del skill" en `SKILL.md`).

Si alguna de las tres no se cumple, no invocar. Si el hueco es sobre
algo fuera de scope (ej: un cambio en un SKILL.md), mencionarlo al
usuario pero no invocar a este skill.

## Patrón de invocación (qué hacer al final del flujo del skill invocante)

Al cierre del flujo, después de haber resuelto la tarea original del
usuario, el skill invocante agrega algo así:

```
[... respuesta al usuario con la info que pidió ...]

---

Aparte: acabás de darme información que el workspace no tenía
documentada (<qué>). ¿Querés que la capturemos como propuesta de
mejora? Lo hace el skill workspace-contribution y queda listo para
que las LTs revisen.

  Sí          → creo una rama con el cambio
  Esperar     → lo guardo en buffer, procesamos varias juntas después
  No          → seguimos sin capturarlo
```

Si el usuario responde "sí" o "esperar", pasar a `workspace-contribution`
con los siguientes datos:

```yaml
contribution_request:
  type: glossary | microservices | best-practices | regulations | known-bugs | integrations
  file: <path relativo al workspace>
  description: <una línea de qué se está agregando>
  proposed_content: |
    <el YAML o markdown a insertar, ya formateado>
  insertion_hint: <dónde insertar — "al final de la sección X" o "reemplazando el entry Y">
  context: <de qué conversación salió, 1-2 oraciones>
```

Si el usuario responde "no", seguir normalmente sin invocar.

## Ejemplo de invocación desde `grv-glosario`

Supongamos que el usuario preguntó por ROAM y el skill detectó que
está marcado como pendiente. Tras la conversación donde el usuario
aportó la definición real:

```
[grv-glosario responde con la definición tal como quedó acordada]

---

Aparte: ROAM estaba marcado como "pendiente de validar" en
context/glossary.yaml y acabás de darme la definición real. ¿Querés
que la capturemos como propuesta de mejora?

  Sí / Esperar / No
```

Si responde "sí":

```yaml
# grv-glosario pasa esto a workspace-contribution:
contribution_request:
  type: glossary
  file: context/glossary.yaml
  description: "Definir ROAM con la definición real del equipo"
  proposed_content: |
    ROAM:
      definition: >
        <definición que dio el usuario>
      related: [<términos relacionados si los mencionó>]
  insertion_hint: "reemplazar el entry actual de ROAM que está marcado como pending"
  context: "Sesión de consulta sobre grv-siniestros, el usuario aclaró la definición correcta"
```

Y `workspace-contribution` sigue desde ahí con su flujo normal.

## Reglas para los skills invocantes

1. **No forzar la captura.** La opción "No" es legítima y frecuente.
   Muchos huecos son demasiado chicos o específicos para ameritar un MR.

2. **Preguntar una sola vez por interacción.** No reintentar en el
   mismo turno si el usuario dijo no.

3. **No contaminar la respuesta principal.** La pregunta de captura va
   al final, separada con `---` o equivalente, y es opcional de
   responder.

4. **No asumir el contenido.** El skill invocante tiene que pasar el
   `proposed_content` ya formado, no delegarlo a `workspace-contribution`
   porque este último no tiene el contexto de dominio.

5. **Respetar el "esperar".** Si el usuario eligió "esperar", no
   volver a preguntar en el mismo tema durante la misma sesión.

## Anti-patrones

- ❌ Ofrecer captura en cada mensaje cuando el usuario claramente está
  en medio de otra tarea.
- ❌ Invocar sin que el usuario haya aportado información nueva
  (no hay nada que capturar).
- ❌ Ofrecer captura cuando el hueco es algo que el skill debería
  haber sabido (esto es un bug del skill, no una contribución).
- ❌ Insistir después de un "no".
- ❌ Capturar sin `proposed_content` (delegarle el formato al usuario
  o a otro skill).

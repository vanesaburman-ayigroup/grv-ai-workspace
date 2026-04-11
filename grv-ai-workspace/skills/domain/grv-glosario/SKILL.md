---
name: grv-glosario
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: domain
related_skills: [grv-regulaciones-srt, grv-siniestros]
related_agents: [grv-domain-expert]
triggers:
  - "usuario pregunta qué significa un término ART/SRT"
  - "aparece una sigla desconocida (ILT, ATEP, ESOP, CIE-10, etc)"
  - "usuario pide definir un concepto del dominio"
---

# Skill: grv-glosario

## Propósito

Ser la fuente de verdad para los términos del dominio ART/SRT/GRV. Resuelve
siglas, explica conceptos, remite a las resoluciones pertinentes.

## Cuándo usarme

- Alguien pregunta "¿qué es X?" donde X es un término de dominio.
- En una conversación aparece una sigla y hace falta traducirla.
- Un skill de otro eje necesita referenciar un término y quiere que la
  explicación sea consistente.

## Fuente de verdad

**`context/glossary.yaml`** es la fuente primaria. Todo lo que respondas
debe estar basado en ese archivo. Si el término no está, primero buscá en
`context/regulations.yaml` y `context/integrations.yaml`. Si sigue sin
aparecer, **decí que no sabés** y sugerí agregarlo al glosario.

## Flujo

1. Identificar el término exacto que está preguntando el usuario (cuidado
   con confusiones de siglas similares).
2. Buscar en `context/glossary.yaml`.
3. Si existe: responder con la definición, el `full_name` si aplica, y
   referencias cruzadas (`related`, `regulation`, etc).
4. Si no existe pero aparece en `regulations.yaml`: responder desde ahí.
5. Si no existe en ningún lado: decir "no tengo este término en el glosario"
   y **ofrecer agregarlo** si el usuario confirma la definición.
6. Para términos con `known_issue` o `important`, siempre mencionarlo.

## Output

Formato compacto:

```
**<TERMINO>** (<full_name si aplica>)
<definición en 1-3 oraciones>
<nota importante o known_issue si aplica>
<referencia a resolución si aplica>
Relacionado: <términos cruzados>
```

Para preguntas que involucran múltiples términos, responder cada uno
separado por una línea en blanco.

## Ejemplos

### Ejemplo 1: sigla simple

**Usuario**: ¿qué es ILT?

**Respuesta**:
```
**ILT** (Incapacidad Laboral Transitoria)
Período en el que el trabajador siniestrado no puede trabajar y la ART
debe pagarle una prestación dineraria.

Importante: el día del accidente cuenta como día trabajado, NO como día
de ILT. Se calcula con ChronoUnit.DAYS.between(LocalDate, LocalDate).

Regulación: Res. SRT 237/96.
```

### Ejemplo 2: término con known issue

**Usuario**: ¿qué es una trazadora CIE-10?

**Respuesta**:
```
**CIE-10 trazadora**
Subset de códigos CIE-10 que dispara validaciones especiales en el flujo
SRT.

⚠️ Known issue: en producción, el lookup devuelve códigos de Brucellosis
(A23.x) en lugar de los correctos de trauma. Probable fallo en JOIN/filtro,
no en los datos. Ver context/known-bugs.yaml → bug-cie10-trazadora-wrong-codes.

Relacionado: CIE-10, trazadora.
```

### Ejemplo 3: término no existente

**Usuario**: ¿qué es DIS?

**Respuesta**:
```
No tengo "DIS" en el glosario. ¿Podrías darme contexto o la definición?
Si es un término que usamos recurrentemente, lo agrego a
context/glossary.yaml para que quede disponible para el resto del equipo.
```

## Ofrecer captura como contribución

Cuando el usuario aporta una definición que no estaba en el glosario
(o corrige una marcada como `pending`), al cierre del flujo ofrecer
invocar `workspace-contribution`. Ver el patrón en
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` debe estar ya formado como entry YAML válida
siguiendo el formato del resto del glosario.

## Límites

- No inventa definiciones. Si no está en `context/`, no sabe.
- No reemplaza a un abogado laboralista ni a la SRT en cuestiones regulatorias
  complejas — solo brinda la definición operativa que usamos en el equipo.
- Los términos muy específicos del código (nombres de clases, funciones)
  no están en el glosario, están en el código.

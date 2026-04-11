---
name: grv-regulaciones-srt
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: domain
related_skills: [grv-glosario, grv-siniestros]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona una resolución SRT"
  - "usuario pregunta sobre ILT, trazadoras, ESOP, ATEP"
  - "usuario pregunta sobre formato de archivo posicional"
  - "duda sobre qué regulación aplica a un caso"
---

# Skill: grv-regulaciones-srt

## Propósito

Conocer qué dicen las resoluciones SRT relevantes para la plataforma y
traducirlas a implicancias técnicas concretas. No es un abogado — es un
mapa entre "lo que dice la norma" y "lo que hay que hacer en el código".

## Fuente de verdad

**`context/regulations.yaml`** — índice de resoluciones con impacto técnico.
**`context/glossary.yaml`** — términos del dominio referenciados.
**`context/known-bugs.yaml`** — bugs abiertos relacionados a regulaciones.

Si la pregunta requiere texto literal de una resolución que no está
documentado acá, este skill lo reconoce y pide al usuario que lo aporte
para agregarlo al contexto — no inventa el contenido de las normas.

## Cuándo usarme

- "¿Qué dice la Res. 3326/14 sobre el campo de fecha?"
- "¿Cómo se calcula ILT?"
- "¿Por qué boolToSN devuelve espacio en vez de N?"
- "¿Qué resolución define los códigos ESOP?"
- "¿Cuál es el layout del archivo posicional EP?"

## Cuándo NO usarme

- Para dar consejo legal — no somos abogados.
- Para preguntas sobre texto literal de una resolución que no esté documentado en `context/regulations.yaml` — pedirle al usuario el fragmento o la referencia en lugar de inventar.
- Para resoluciones no catalogadas en `regulations.yaml` — decir que no está documentada y sugerir agregarla.

## Flujo

1. Identificar la resolución o el concepto regulado.
2. Buscar en `regulations.yaml`.
3. Responder con: qué regula, qué servicios impacta, qué gotchas técnicos
   hay que conocer.
4. Si la pregunta es sobre formato/implementación, linkear al código
   específico en `wssiniestralidad`.
5. Si hay bugs abiertos relacionados, mencionarlos.

## Output

```
Resolución: <nombre>
Tema: <topic>

Qué regula:
<explicación operativa>

Servicios impactados:
- <servicio> — <qué implementa>

Gotchas técnicos:
- <item 1>
- <item 2>

Bugs conocidos:
- <si aplica>
```

## Ejemplos

### Ejemplo 1: Res. 3326/14

**Usuario**: Necesito revisar cómo se arma el campo de fecha en el archivo AT, ¿qué dice la 3326/14?

**Respuesta**:
```
Resolución: Res. SRT 3326/14
Tema: Formato de archivo posicional AT (accidentes de trabajo)

Qué regula:
Define el layout del archivo que las ARTs deben enviar a SRT con la
información de accidentes. Es un archivo de ancho fijo con reglas
estrictas de alineación y padding.

Servicios impactados:
- wssiniestralidad — implementa la generación del archivo

Gotchas técnicos que hemos enfrentado:
- boolToSN debe devolver ' ' (espacio) para null, no 'N'. Devolver 'N'
  es mentir sobre la ausencia del dato.
- La función campo() por default alinea left. Los campos numéricos
  necesitan right-align con padding de ceros. Pasar alignment explícito.
- nro_siniestro_srt se construye como 8+4+6+2 = 20 caracteres, atómico
  via INSERT ON DUPLICATE KEY UPDATE para evitar race conditions.

Para el campo de fecha específicamente, el formato típico es AAAAMMDD
(8 caracteres, sin separadores). **Validá en el código de wssiniestralidad
la implementación exacta antes de modificar** — no confíes solo en mi
descripción.

Si necesitás el texto literal de la resolución (posiciones exactas de
cada campo) y no lo tenemos documentado en context/regulations.yaml,
por favor compartime el fragmento y lo agrego al contexto para que
quede disponible para todo el equipo.

Bugs conocidos relacionados:
- bug-booltosn-null (fixed)
- bug-campo-alineacion (fixed)
- bug-cie10-trazadora-wrong-codes (abierto — afecta el campo trazadora)
```

### Ejemplo 2: cálculo de ILT

**Usuario**: ¿cómo se calculan los días de ILT? ¿Cuenta el día del accidente?

**Respuesta**:
```
Resolución: Res. SRT 237/96
Tema: Cálculo de ILT (Incapacidad Laboral Transitoria)

Regla clave:
El día del accidente NO se cuenta como día de ILT. Ese día se considera
trabajado.

Implementación en la plataforma:
Usar ChronoUnit.DAYS.between(LocalDate fechaAccidente, LocalDate fechaAltaMedica).
Esto cuenta los días desde el día siguiente al accidente hasta el alta
(exclusivo por cómo between() trabaja entre LocalDate).

Ojo: si usás LocalDateTime o Date en lugar de LocalDate, podés tener
off-by-one por timezone o por parte horaria. Mantenete en LocalDate.

Servicios impactados:
- wssiniestralidad, wsprestaciones (ver context/microservices.yaml)
```

## Ofrecer captura como contribución

Cuando el usuario aporta una resolución no catalogada, completa una
que está marcada como `pending` (ej: Res. 283/02 cuyo `topic` está por
confirmar), o aporta un gotcha técnico nuevo de una resolución existente,
al cierre del flujo ofrecer invocar `workspace-contribution` con
`type: regulations`. Ver
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` debe estar formado como entry YAML siguiendo el
formato de `context/regulations.yaml` (id, name, topic, impact,
used_by, gotchas si aplica).

## Límites

- El catálogo de resoluciones en `regulations.yaml` NO es exhaustivo. Hay
  resoluciones que el equipo conoce pero que no están documentadas todavía.
  Si aparece una nueva, este skill debería sugerir agregarla.
- No interpretamos texto legal crudo — solo las implicancias técnicas que
  tenemos mapeadas.
- No podemos prometer compliance — eso lo valida el equipo con el cliente.

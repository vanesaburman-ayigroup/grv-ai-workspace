---
name: grv-arquitectura-plataforma
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: domain
related_skills: [grv-glosario, grv-bugs-conocidos]
related_agents: [grv-domain-expert, grv-reviewer]
triggers:
  - "usuario pregunta qué servicio hace X"
  - "usuario pregunta por la arquitectura de la plataforma"
  - "usuario necesita saber quién toca un flujo end-to-end"
---

# Skill: grv-arquitectura-plataforma

## Propósito

Mapear flujos funcionales a microservicios concretos de la plataforma GRV/ART.
Responde preguntas tipo "¿qué servicio toca cuando pasa X?" y "¿quién es
referente de Y?".

## Fuente de verdad

**`context/microservices.yaml`** — mapa de servicios, responsabilidades, dependencias, owners.
**`context/integrations.yaml`** — integraciones externas.
**`context/known-bugs.yaml`** — bugs que afectan flujos conocidos.

## Cuándo usarme

- "¿Qué pasa cuando se anula un turno con traslado programado?"
- "¿Qué servicios tocan cuando genero un archivo SRT?"
- "¿Quién es owner de wssiniestralidad?"
- "¿Qué integraciones tiene wstraslado?"
- "¿Por qué wsauditoriafacturacion y wsauditoriatraslados comparten tabla?"

## Flujo

1. Identificar el concepto/flujo sobre el que pregunta el usuario.
2. Buscar en `microservices.yaml` todos los servicios que lo mencionan
   (en `responsibility`, `critical_tables`, `depends_on`, `known_bugs`).
3. Si aplica, consultar `integrations.yaml` para integraciones externas.
4. Consultar `known-bugs.yaml` para advertir si hay bugs conocidos.
5. Construir un mapa simple del flujo: qué servicio empieza, qué llama,
   qué persiste, qué publica.
6. Identificar el/los referentes.

## Output

```
Flujo: <nombre del flujo>

Servicios involucrados:
  1. <servicio> — <qué hace en este flujo>
  2. <servicio> — ...

Dependencias externas: <si aplica>

Tablas tocadas: <si aplica>

Referentes: <lista>

⚠️ Bugs conocidos que afectan este flujo: <si aplica>
```

## Ejemplos

### Ejemplo 1: flujo de anulación de turno con traslado

**Usuario**: ¿qué servicios tocan cuando se anula un turno que tenía un traslado programado?

**Respuesta**:
```
Flujo: anulación de turno con traslado

Servicios involucrados:
  1. wsturnos — recibe la petición de anulación. Llama a findTrasladoProgramado.
  2. wstraslado — si el traslado está PROGRAMADO, debería ejecutar cancelación.
  3. wslogistica — debería actualizar etiqueta del traslado (1/ASIGNADO → 5/CANCELADO).

Tablas tocadas: turnos, traslados, traslados_etiquetas, logistica_planilla

Referentes: [LOGISTICS_REFERENT]

⚠️ Bugs conocidos que afectan este flujo:
  - bug-logistica-anular-turno: anularTurno solo envía email en lugar de
    ejecutar la cancelación completa cuando el traslado está PROGRAMADO.
  - bug-logistica-etiqueta-asignado: @Recover en WSTurnos silencia fallos
    de actualización de etiqueta en WSLogistica.

Recomendación: revisar ambos bugs antes de tocar el código. Ver
context/known-bugs.yaml.
```

### Ejemplo 2: ubicar un servicio

**Usuario**: ¿quién toca la generación de archivos posicionales SRT?

**Respuesta**:
```
Servicio: wssiniestralidad

Responsabilidad: Gestión de denuncias y generación de archivos
posicionales para la SRT según Res. 3326/14 (AT) y 3327/14 (EP).

Tablas críticas: datos_denuncia_srt_logs, siniestros, denuncias

Integraciones externas: SRT (upload de archivos)

Referente: [BACKEND_REFERENT]

Complejidad conocida:
  - Construcción del nro_siniestro_srt (8+4+6+2 caracteres, atómico)
  - Alineación de campos (boolToSN, padding)
  - Trazadoras CIE-10 con lookup por JOIN (bug abierto)

Si vas a tocar este servicio, ojo con:
  - bug-cie10-trazadora-wrong-codes (abierto)
  - Reglas estrictas de formato en Res. 3326/14 y 3327/14
```

## Ofrecer captura como contribución

Cuando el usuario aporta información sobre un servicio no documentado
(nombre real de un MFE, responsabilidad de un servicio faltante,
dependencia no mapeada), al cierre del flujo ofrecer invocar
`workspace-contribution` con `type: microservices`. Ver
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` debe estar formado como entry YAML siguiendo
el formato de `context/microservices.yaml`. Para reemplazo de
placeholders (ej: `[FRONTEND_NAME_MESADECARGA]`), el `insertion_hint`
debe decir "reemplazar placeholder X por el nombre real".

## Límites

- No tiene el código fuente indexado. Si la pregunta requiere saber exactamente
  qué hace el método X, hay que leer el código.
- La lista de servicios en `microservices.yaml` no es exhaustiva todavía
  (30+ servicios, varios sin documentar). Si el servicio no aparece, decirlo
  explícitamente en lugar de inventar.
- No diagrama automáticamente — eso lo hace `c4-diagrams`.

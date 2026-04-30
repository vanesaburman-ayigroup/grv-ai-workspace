---
name: grv-siniestros
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: domain
related_skills: [grv-glosario, grv-regulaciones-srt, grv-arquitectura-plataforma]
related_agents: [grv-domain-expert]
triggers:
  - "usuario pregunta sobre denuncias, siniestros, AT, EP, in-itinere"
  - "usuario debe diseñar o modificar flujo de siniestros"
  - "usuario pregunta por el ciclo de vida de una denuncia"
---

# Skill: grv-siniestros

## Propósito

Conocer el ciclo de vida de un siniestro laboral en la plataforma de GRV,
desde la denuncia inicial hasta el cierre. Este skill es el mapa entre
conceptos de negocio y estructuras de datos reales del sistema.

## Fuente de verdad

- `context/glossary.yaml` — términos del dominio.
- `context/microservices.yaml` — servicios involucrados.
- `context/regulations.yaml` — regulaciones asociadas.
- `context/known-bugs.yaml` — bugs abiertos que afectan este flujo.

Si este skill necesita mencionar algo que no está en esos archivos, lo
marca como **pendiente de validar** y ofrece agregarlo al usuario.

## Alcance

Este skill cubre **siniestros laborales** (AT, EP, accidentes in-itinere).
No cubre **accidentes personales**, que son otra unidad de negocio de GRV
con sus propias reglas y modelo; para ese caso se debe crear un skill
aparte cuando sea necesario.

## Ciclo de vida conceptual (a validar con el equipo)

El ciclo de vida real del sistema puede variar. Este es el modelo inicial
basado en lo que el workspace conoce; debe validarse con el equipo y
ajustarse en iteraciones sucesivas.

```
  1. Ingreso          → Mesa de carga registra la denuncia
  2. Clasificación    → AT / EP / in-itinere
  3. Primera atención → Asignación de turno y/o traslado
  4. Tratamiento      → Prestaciones (autorizadas, brindadas, facturadas)
  5. ILT              → Cálculo de días de incapacidad temporal
  6. Alta médica      → Cierre del tratamiento
  7. Envío a SRT      → Archivo posicional (AT: Res. 3326/14, EP: Res. 3327/14)
```

Cada paso puede tener flujos alternos, retrabajos y reaperturas. Los
detalles exactos están pendientes de documentar con el equipo.

## Tablas principales

- `denuncias` — tabla maestra de denuncias registradas.
- `siniestros` — tabla maestra de siniestros.
- `datos_denuncia_srt_logs` — **fuente de verdad** para datos que van a SRT.
  **NO usar `denuncias` para decisiones sobre qué enviar a SRT** — usar este log.
- `config_trazadora_cie10` — configuración del lookup de CIE-10 trazadora.
  ⚠️ bug abierto: ver `known-bugs.yaml` → `bug-cie10-trazadora-wrong-codes`.

Cualquier tabla adicional que se necesite debe verificarse con el MCP de
MariaDB dev (`SHOW TABLES`, `DESCRIBE`) en lugar de asumirla.

## Cuándo usarme

- Preguntas sobre flujos end-to-end de siniestros laborales.
- Diseño de nuevas features que tocan denuncias.
- Diagnóstico de datos de denuncias reales (combinando con MCP de MariaDB).
- Explicación del dominio a alguien nuevo.

## Cuándo NO usarme

- Preguntas sobre accidentes personales — esa unidad de negocio no está
  cubierta por este skill. Decirlo explícitamente y ofrecer crear un skill
  nuevo.
- Preguntas sobre autoasegurados cuando el flujo difiere del mundo ART
  típico — avisar que las reglas específicas pueden variar y pedir contexto.

## Flujo

1. Entender qué parte del ciclo está preguntando el usuario.
2. Identificar si se trata de siniestro laboral; si no, detenerse y
   aclararlo.
3. Mapear a los servicios y tablas involucradas (ver `microservices.yaml`).
4. Si hay regulación asociada, delegar esa parte a `grv-regulaciones-srt`.
5. Si el usuario quiere ver datos reales, usar MCP MariaDB dev (siempre con
   LIMIT y filtros por fecha).
6. Alertar sobre cualquier bug abierto relacionado (ver `known-bugs.yaml`).
7. Si aparece un término o una regla que no está documentada, **decilo
   explícitamente y pedí confirmación**. No inventes.

## Puntos de atención frecuentes

1. **Denuncia ≠ siniestro**. Una denuncia puede asociarse a un siniestro
   existente (reapertura) o crear uno nuevo. El modelo exacto debe validarse
   con el equipo.

2. **Fuente de verdad para SRT**: `datos_denuncia_srt_logs`, no `denuncias`.

3. **nro_siniestro_srt**: 20 caracteres con estructura 8+4+6+2. Generación
   atómica.

4. **ILT**: día del accidente NO cuenta. Ver `grv-regulaciones-srt` →
   Res. 237/96.

5. **Accidentes in-itinere**: son siniestros laborales. Cubiertos por la
   Ley 24.557, con sus propios criterios de admisibilidad (que dependen
   del trayecto entre casa y trabajo).

## Ejemplos

### Ejemplo 1: bug de trazadora

**Usuario**: La denuncia X está devolviendo una trazadora de Brucellosis
pero el diagnóstico es de trauma. ¿Qué pasa?

**Respuesta**:
```
Este es un bug conocido: bug-cie10-trazadora-wrong-codes (abierto, ver
context/known-bugs.yaml).

Contexto:
El lookup de CIE-10 trazadora devuelve códigos A23.x (Brucellosis) en
lugar de los correctos para trauma. El problema está en el JOIN o filtro
sobre config_trazadora_cie10, no en los datos.

Para diagnosticar el caso específico, sugiero:

1. Verificar qué código CIE-10 tiene la denuncia en datos_denuncia_srt_logs
   (usando MCP MariaDB dev, con LIMIT).

2. Verificar qué devuelve el lookup de trazadora para ese código.

3. Comparar con la lógica del servicio wssiniestralidad.

Referente: [BACKEND_REFERENT].

Recomendación: abrir ticket para fixear el root cause, no workaround
del caso específico.
```

### Ejemplo 2: pregunta fuera de scope

**Usuario**: ¿Cómo se gestiona una denuncia de accidente personal en el sistema?

**Respuesta**:
```
Los accidentes personales son una unidad de negocio distinta de los
siniestros laborales. Este skill (grv-siniestros) cubre solo el mundo
ART (AT, EP, in-itinere).

No tengo el flujo de accidentes personales documentado en el workspace
todavía. Dos opciones:

1. ¿Podés contarme el flujo y lo documentamos juntos? Creamos un skill
   grv-accidentes-personales o expandimos este.

2. ¿Es para una feature específica? Si sí, te puedo ayudar a preguntarle
   al referente correcto y capturar lo que responda en el workspace.

No quiero inventar el flujo para no darte información incorrecta.
```

## Límites conocidos

- **Alpha**: muchos detalles del modelo de datos y del flujo real del
  sistema están pendientes de validar con el equipo. Las respuestas deben
  marcar claramente cuándo están basadas en `context/` y cuándo son
  extrapolación que necesita confirmación.
- No cubre accidentes personales ni reglas específicas de autoasegurados.
- El modelo de datos real puede tener más tablas de las listadas — usar
  MCP MariaDB para verificar cuando haya duda.

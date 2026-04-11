---
name: grv-turnos-logistica
version: v1
maturity: alpha
owner: "[LOGISTICS_REFERENT]"
category: domain
related_skills: [grv-arquitectura-plataforma, grv-bugs-conocidos, grv-prestaciones]
related_agents: [grv-domain-expert, grv-reviewer]
triggers:
  - "usuario menciona turnos, traslados, agencias, logística"
  - "usuario reporta problema con planilla, etiquetas de traslado"
  - "usuario pregunta por integración con Google Maps o Moovear"
---

# Skill: grv-turnos-logistica

## Propósito

Conocer el dominio de turnos médicos y traslados de pacientes siniestrados.
Es uno de los ejes con más bugs históricos del sistema y por eso merece
atención especial.

## Modelo conceptual

```
Denuncia → requiere atención médica
         → se agenda un TURNO con prestador
         → si el paciente no puede trasladarse solo, se programa TRASLADO
         → el TRASLADO se asigna a una AGENCIA de traslados
         → la agencia recibe la orden con etiquetas de estado
         → el paciente va al turno, recibe prestación
         → se factura por la prestación y por el traslado
```

## Servicios involucrados

- `wsturnos` — gestión de turnos (crear, reprogramar, anular)
- `wstraslado` — gestión de traslados (programar, asignar, cancelar)
- `wslogistica` — orquesta turnos + traslados, mantiene planilla y etiquetas

Ver `context/microservices.yaml` para detalles.

## Estados y etiquetas de traslado

Las etiquetas codifican el estado del traslado en `wslogistica`:

| Etiqueta | Código | Estado |
|---|---|---|
| 1 | ASIGNADO | Asignado a agencia, pendiente de ejecución |
| 2 | EN CURSO | La agencia está ejecutando el traslado |
| 3 | COMPLETADO | Traslado realizado |
| 4 | NO REALIZADO | No se pudo completar |
| 5 | CANCELADO | Cancelado antes de ejecutar |

⚠️ Bug abierto: traslados quedan con etiqueta 1/ASIGNADO cuando deberían
pasar a 5/CANCELADO. Ver `bug-logistica-etiqueta-asignado`.

## Bugs históricos en este eje (lectura obligatoria)

### bug-logistica-anular-turno (abierto)

`anularTurno` en WSTurnos detecta traslado PROGRAMADO y solo envía email
en lugar de ejecutar la cancelación completa. Consecuencia: el traslado
queda activo aunque el turno esté anulado.

### bug-logistica-etiqueta-asignado (abierto)

`@Recover` en WSTurnos silencia fallos de actualización de etiqueta en
WSLogistica. El traslado se cancela pero la etiqueta sigue 1/ASIGNADO.
Caso emblemático: traslado ID 2469285.

### Integraciones externas problemáticas

- **Google Maps geocoding**:
  - "GBA NORTE" no se reconoce como location
  - Sarmiento/Chubut tiene mismatch de geocoding
  - CABA requiere normalización de dirección
  - En frontend, la API key no se inyecta en build-time — se resolvió
    con el pattern de `credentials.js`. *[TODO: confirmar nombre exacto
    del MFE que implementa este pattern para documentarlo en
    `context/microservices.yaml`.]*
- **Moovear**: historial de 403 por IP whitelisting en AWS

## Cuándo usarme

- Diseño de features que tocan turnos o traslados.
- Diagnóstico de bugs reportados en logística.
- Preguntas sobre el ciclo de vida de un traslado.
- Preguntas sobre integraciones con agencias, Google Maps, Moovear.

## Flujo para diagnóstico de bug

1. Entender qué reportó el usuario (síntoma observable).
2. Consultar `known-bugs.yaml` — ¿matchea con un bug conocido?
3. Si no, mapear el flujo con `grv-arquitectura-plataforma`.
4. Si hace falta ver datos reales, usar MCP MariaDB dev (preguntando
   antes si debe ser prod).
5. Generar hipótesis de root cause y listar puntos del código a revisar.

## Ejemplo de diagnóstico

**Usuario**: El traslado 2469285 quedó como ASIGNADO pero el turno fue cancelado.

**Respuesta**:
```
Este caso matchea con bug-logistica-etiqueta-asignado (abierto).

Hipótesis: @Recover en WSTurnos capturó una excepción al intentar
actualizar la etiqueta en WSLogistica, logueó y retornó sin propagar el
error. Por eso el traslado quedó con etiqueta 1/ASIGNADO en lugar de
pasar a 5/CANCELADO.

Para confirmar:

1. Revisar logs de WSTurnos en el momento de la cancelación. Buscar
   mensajes de @Recover sobre traslado 2469285.

2. Verificar estado actual en BD (dev/prod según corresponda):
   SELECT id, estado, etiqueta, updated_at
   FROM traslados WHERE id = 2469285 LIMIT 1;

   SELECT * FROM traslados_etiquetas
   WHERE id_traslado = 2469285
   ORDER BY fecha DESC LIMIT 5;

3. Revisar el método de anulación en WSTurnos, específicamente cualquier
   catch con @Recover.

Recomendación de fix (no aplicar sin revisión):
   - @Recover debe propagar el error o marcar el registro como
     inconsistente para reconciliación asincrónica.
   - O: reemplazar por outbox pattern con reintento idempotente.

Referente: [LOGISTICS_REFERENT].
```

## Límites

- No tenemos mapeadas todas las agencias prestadoras — solo el patrón de
  integración.
- El código de wsturnos/wstraslado/wslogistica tiene 2+ años de historia
  con varios dueños — cuando haya duda, preguntar al referente.

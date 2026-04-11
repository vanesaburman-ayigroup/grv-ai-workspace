---
name: grv-facturacion
version: v1
maturity: alpha
owner: "[BACKEND_REFERENT]"
category: domain
related_skills: [grv-prestaciones, grv-arquitectura-plataforma, grv-bugs-conocidos]
related_agents: [grv-domain-expert, grv-reviewer]
triggers:
  - "usuario menciona facturación, auditoría de facturación, nomencladores"
  - "usuario diseña o debugea wsauditoriafacturacion o wsauditoriatraslados"
  - "usuario menciona lock wait en auditoria_facturacion_log"
---

# Skill: grv-facturacion

## Propósito

Conocer el dominio de facturación de prestaciones en la plataforma GRV/ART.
La facturación es el proceso por el cual los prestadores cobran a la ART
por las prestaciones brindadas, y la ART valida/audita esas facturas antes
de pagarlas.

## Modelo conceptual

```
Prestador presenta factura → contiene ítems (prestaciones brindadas)
   ↓
Auditoría automática → valida: autorización previa, tarifa, coherencia con historia
   ↓
Auditoría manual → auditores revisan casos flagueados
   ↓
Decisión → APROBADA (total o parcial) / RECHAZADA / OBSERVADA
   ↓
Si APROBADA → orden de pago → integración con SAP Business One
```

## Servicios involucrados

- `wsauditoriafacturacion` — auditoría de facturas generales
- `wsauditoriatraslados` — auditoría de facturas específicas de traslados
- `ws-sapintegration` — integración con SAP B1 para ejecución de pagos
- `wsprestaciones` — valida que las prestaciones facturadas efectivamente existan
- `wsautorizaciones` — valida que las prestaciones facturadas estaban autorizadas

## Tabla crítica

**`auditoria_facturacion_log`** es la tabla donde ambos servicios
(`wsauditoriafacturacion` y `wsauditoriatraslados`) escriben. Esto causa
problemas de concurrencia.

⚠️ Bug abierto: `bug-lock-wait-auditoria`. Dos servicios escribiendo
concurrentemente sin particionamiento. Fix recomendado: outbox pattern +
SQS FIFO + SKIP LOCKED para consumers.

## Integración con SAP Business One

Via `ws-sapintegration`:

- Creación de facturas de compra en SAP B1
- Actualización de estados
- Custom UDFs con prefijo `U_GRV_`
- Session management explícito (login por batch)
- Historial: certificado SSL expirado en junio 2023 (problema de infra,
  no de código)

## Auditoría automática - reglas típicas

1. **Validación de autorización**: la prestación facturada tiene que tener
   una autorización previa aprobada que la cubra.
2. **Validación de tarifa**: el monto facturado tiene que coincidir con la
   tarifa vigente del nomenclador al momento de la prestación.
3. **Validación de fecha**: la fecha de prestación tiene que estar dentro
   del período de vigencia del siniestro (entre denuncia y alta médica).
4. **Validación de prestador**: el prestador tiene que estar habilitado y
   dentro de la red de la ART.
5. **Validación de duplicados**: la misma prestación no puede facturarse
   dos veces.
6. **Validación de coherencia**: que el tipo de prestación sea coherente
   con el diagnóstico del siniestro.

## Cuándo usarme

- Diseño de reglas de auditoría automática.
- Diagnóstico de bugs en `wsauditoriafacturacion` o `wsauditoriatraslados`.
- Revisión de código que toca `auditoria_facturacion_log`.
- Preguntas sobre el flujo de pago a prestadores.

## Consideraciones críticas

1. **Concurrencia**: nunca agregar lógica que bloquee más filas de
   `auditoria_facturacion_log` sin evaluar impacto. El bug ya mencionado
   muestra que esta tabla es sensible.

2. **Idempotencia**: toda operación de facturación debe ser idempotente.
   Reintentos de SAP o del prestador no pueden generar doble pago.

3. **Trazabilidad**: toda decisión (aprobar, rechazar, observar) debe
   quedar loguada con contexto completo. Los auditores reclaman a los
   reclamos de prestadores con esto.

4. **Tarifas versionadas**: las tarifas cambian con el tiempo. Siempre
   usar la tarifa vigente en la fecha de prestación, no la actual.

## Ejemplo

**Usuario**: Tengo que agregar una nueva regla de auditoría que valide
que los medicamentos facturados estén en el vademécum aprobado. ¿Dónde va?

**Respuesta**:
```
La regla es parte de la auditoría automática, va en wsauditoriafacturacion.

Consideraciones antes de implementar:

1. Evitar pegarle a auditoria_facturacion_log más de lo necesario — la
   tabla ya sufre de lock wait. Hacer la validación en memoria o contra
   una tabla cacheada del vademécum.

2. El vademécum es versionado: ¿qué versión aplica? La vigente al
   momento de la prestación, no al de la factura. Modelar con fecha_vigencia_desde
   y fecha_vigencia_hasta.

3. Idempotencia: si corre dos veces sobre la misma factura, debe dar el
   mismo resultado.

4. Logging: cada rechazo por vademécum debe tener logueado (id_factura,
   id_prestacion, codigo_medicamento, version_vademecum_usada).

5. Integración: esta validación puede correr antes o después del envío a
   SAP. Recomendado: antes, para no ensuciar SAP con rechazos posteriores.

Servicios tocados:
- wsauditoriafacturacion (principal)
- posiblemente wsprestaciones (si el vademécum vive ahí)

Bug conocido a tener en cuenta:
- bug-lock-wait-auditoria: si esta regla escribe a auditoria_facturacion_log,
  considerar outbox pattern.

Referente: [BACKEND_REFERENT].
```

## Límites

- **Alpha**: el mapeo exacto a tablas de tarifas/nomencladores pendiente.
- El modelo de datos de prestadores y sus contratos no está documentado
  en detalle acá.
- Las reglas exactas de SAP para cada tipo de factura dependen de la
  configuración del cliente.

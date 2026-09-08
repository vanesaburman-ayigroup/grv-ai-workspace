## Why

En la pantalla de **Auditoría de Traslados** (MFE `auditoriafacturacion`) el auditor ve **solo una parte** de las observaciones del traslado, **mezcladas** entre sí y **sin poder atribuir el origen** de cada una. La causa es estructural: cada módulo del ecosistema (tramitador, CEM, logística, peaje, estacionamiento, SATAPP, auditoría) escribe sus observaciones en **columnas distintas y dispersas** de dos tablas físicas (`cs.traslados` y `cs.traslados_internos`), y el drawer de auditoría proyecta solo algunas.

El caso más crítico es **SATAPP**, que **no tiene columna propia**: el método `agregarObservaciones` de `wslogistica` (`TrasladoServiceImpl.java:2541-2598`) **concatena** la observación del viaje en la **misma caja** que el tramitador (`observaciones`/`observaciones_regreso`/`observaciones_traslado` en `traslados`, u `observaciones_ida`/`observaciones_vuelta` en `traslados_internos`), distinguiéndola apenas por etiquetas embebidas en texto libre (`[Peaje:..][Estacionamiento:..][Espera:..]`). El auditor **ve** el texto de SATAPP pero **no puede saber que es de SATAPP**, ni separarlo de lo que escribió el tramitador.

Además, el drawer **no muestra** varias fuentes que sí existen en la base: observación de **control**, **traslado negativo**, **datos pool**, **anulación** y **estacionamiento** (texto no estructurado). El resultado es que el auditor no puede **demostrar las observaciones de todos los módulos** (fila 78 del relevamiento, prioridad ALTA) ni operar con la "experiencia certera" que pide el negocio.

La solución (Propuesta 2, **opción B** del documento de relevamiento) es **centralizar** todas las observaciones en una tabla unificada con **atribución explícita de origen**, y presentarlas en el drawer como un **feed unificado por traslado, filtrable por origen**, con ícono y color por fuente (paleta SAS). La transición se hace **sin big-bang**: las formas vieja (columnas concatenadas) y nueva (tabla + feed) **conviven** mediante backfill + dual-write hasta consolidar.

## What Changes

- **Nueva tabla `cs.traslados_observaciones`** (DDL): registro único, atómico y atribuido de cada observación, con `origen`/módulo (TRAMITADOR/CEM/LOGISTICA/PEAJE/ESTACIONAMIENTO/SATAPP/AUDITORIA), `subtipo` opcional (sub-clasificación dentro del módulo: para tramitador CONTROL/ANULACION/TRASLADO_NEGATIVO/DATOS_POOL/DESESTIMO), `tramo` (IDA/VUELTA/GENERAL), `texto`, `usuario_sistema`, `fecha_hora`, FK lógica al traslado (`id_traslado` para `traslados`, `id_traslado_interno` para `traslados_internos`) y `CHECK` de exclusividad de ids (MariaDB 10.5.29 lo evalúa). No reemplaza de inmediato las columnas actuales.
- **Backfill inicial (DML)**: poblar `traslados_observaciones` desde las columnas de observación actuales de `traslados` y `traslados_internos`, infiriendo el `origen` por la columna de procedencia (y, para SATAPP, detectando las etiquetas embebidas). Script separado del DDL, **idempotente y re-ejecutable**.
- **Dual-write (convivencia)**: cada módulo que hoy escribe su columna de observación (`wstraslados`, `wslogistica` —incl. CEM, peaje y el `agregarObservaciones` de SATAPP—, `wsauditoriatraslados`) **sigue escribiendo su columna actual** y **además** inserta una fila en `traslados_observaciones` con su `origen`. Ningún módulo deja de escribir su columna durante la transición. **Estacionamiento queda como follow-up** (hoy embebido en texto libre, sin fuente estructurada): no entra al dual-write en esta fase.
- **Feed unificado en el drawer** (`auditoriafacturacion`): nuevo bloque "Observaciones del traslado" que lee `traslados_observaciones` y muestra un **timeline filtrable por origen** (y por subtipo dentro del tramitador), con ícono/color por fuente (paleta SAS) y orden estable `fecha_hora, id`. Componente custom **prop-driven y SOLID** (`sas-component-lib` no tiene hoy un timeline apto; se reusa si aparece uno).
- **Vista de transición**: durante la convivencia el drawer puede mostrar **ambas** vistas (las cajas/columnas actuales y el feed nuevo) para que el auditor compare y valide, sin perder lo que ya veía.
- **Lectura backend del feed** (`wsauditoriatraslados`): nuevo endpoint/proyección que devuelve las observaciones unificadas de un traslado desde `traslados_observaciones`, ordenadas y agrupables por origen/tramo. El contrato del drawer actual no se rompe (campos nuevos, opcionales).
- **Consolidación final (fuera de esta entrega)**: cuando todos los módulos escriban la tabla nueva y el feed sea fuente única, deprecar la lectura de columnas dispersas. Se documenta el criterio de corte; no se ejecuta en esta fase.

## Capabilities

### New Capabilities
- `centralizar-observaciones`: registro unificado y atribuido de las observaciones de un traslado (tabla `traslados_observaciones` con `origen`), con backfill + dual-write para convivencia, y un feed unificado filtrable por origen en el drawer de auditoría.

### Modified Capabilities
<!-- No hay specs canónicas previas en openspec/specs/ para esta capacidad. -->

## Impact

**Base de datos (esquema `cs`)** — DDL y DML separados (MariaDB no hace DDL transaccional):
- `CREATE TABLE cs.traslados_observaciones` (`IF NOT EXISTS`, InnoDB, `utf8mb4_unicode_ci`, columna `subtipo VARCHAR(40) NULL`, índices por `id_traslado` y `id_traslado_interno`, `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))`).
- Script de **backfill** idempotente desde las columnas actuales de `traslados` y `traslados_internos`.
- Ambos pasan por `mariadb-migration-review`. Tablas grandes involucradas: `traslados` (~1.47M), `traslados_internos`.

**Backend** — dual-write y lectura del feed:
- `wstraslados` — al escribir `observaciones`/`observaciones_regreso`/`observaciones_traslado`/`observaciones_control`/`observacion_traslado_negativo`/`observacion_datos_pool`/`observaciones_desestimo`/`observaciones_anulacion`, además inserta en `traslados_observaciones` (`origen='TRAMITADOR'` con su `subtipo`).
- `wslogistica` — CEM (`observaciones_ida/_vuelta`), logística (`observaciones_logistica` y afines), peaje (`observaciones_peaje_ida/_vuelta`), anulación de vuelta, y especialmente `agregarObservaciones` (SATAPP) → dual-write con su `origen` real en lugar de concatenar. Estacionamiento: follow-up (sin fuente estructurada hoy).
- `wsauditoriatraslados` — observación de auditoría (`observacionAuditoria`) → dual-write origen `AUDITORIA`; nueva lectura/proyección del feed unificado para el drawer.

**Frontend** (`auditoriafacturacion`, MFE de auditoría de facturación):
- Nuevo componente de **feed de observaciones** (custom prop-driven, SOLID, paleta SAS) con filtro por origen (y por subtipo dentro del tramitador), ícono y color por fuente.
- Wiring en el drawer simple (`FormAuditar.tsx`) y múltiple (`AuditarTabla.tsx`); modo "ambas vistas" durante la transición.

**Sin cambios de API pública existente:** el contrato del drawer actual se mantiene; los datos del feed se exponen como **campos/recurso nuevos y opcionales**. Backward-compatible: se puede desplegar la tabla + backfill + dual-write **antes** que el front del feed sin romper nada.

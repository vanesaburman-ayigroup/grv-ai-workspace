# Gaps detectados en TEST — centralización de observaciones (GRV-2084)

> Addendum al SDD/PRD. Registra 3 gaps de mapeo que QA detectó en TEST sobre la implementación
> ya mergeada a develop, su causa raíz (verificada) y los cambios aplicados por repo.
> Rama de trabajo en todos los repos: `feature/GRV-2084-gaps-observaciones` (desde develop).

## Causa raíz común
La implementación original cubrió el dual-write en **wstraslados / wslogistica / wsauditoriatraslados**,
pero NO en **wsturnos**, que es quien **crea el traslado** cuando un tramitador genera un turno
(`TurnosServiceImpl.createNewTraslado`, JPA propio, sin delegar en wstraslados). Verificado en réplica:
385/385 de las observaciones sin fila en el feed tenían `id_turno NOT NULL` (creadas por el path de
turno, post-backfill). Read-side y backfill estaban OK; el agujero era write-side en wsturnos.

## Gap 1 — Observación del tramitador del turno no aparece en el feed
- **Qué**: la observación que el tramitador carga en el paso 2 ("requiere traslado") de "generar turno"
  va a `cs.traslados.observaciones` (IDA) / `observaciones_regreso` (VUELTA), escrita por **wsturnos**,
  que no hacía dual-write.
- **Fix**: wsturnos entra al alcance del dual-write. Nuevo scaffolding (`OrigenObservacion`,
  `TramoObservacion`, `TrasladosObservaciones`, `ITrasladosObservacionesRepository`,
  `TrasladosObservacionesWriter` — SLF4J, best-effort `REQUIRES_NEW`) y enganche en
  `createNewTraslado`: `origen='TRAMITADOR'`, IDA/VUELTA, después del `save`.

## Gap 2 — Motivo de cambio de estado de logística no aparece
- **Qué**: el motivo del cambio de estado (a CANCELADO, o de CANCELADO a REALIZADO) tiene un motivo
  **tabulado** (`id_motivo_anulacion` → `motivos_anulacion.descripcion`) y uno **escrito** a mano
  (`observaciones_anulacion`); además el motivo del realizado-desde-cancelado vive SOLO en
  `cs.traslados_log` (`accion='CAMBIO_MANUAL_ESTADO_FINAL'`). Nada de esto entraba como LOGISTICA.
- **Decisión**: **ambas fuentes combinadas** → `origen='LOGISTICA'`, `subtipo='CAMBIO_ESTADO'`,
  texto `"Cambio de estado: {tabulado} - {escrito}"` (fuente A) y el texto del cambio final con su
  motivo (fuente B, desde el flujo de `traslados_log`).
- **Fix (wslogistica `TrasladoServiceImpl`)**:
  - Fuente A modulo-externo: en `setDatosCancelacionDesdeModuloExterno` (tiene el `MotivoAnulacion`).
  - Fuente A modal de validación: en `actualizarDatosTraslado` (resuelve la descripción por id contra
    `motivos_anulacion`; sólo registra si hubo cancelación).
  - Fuente B: en `registrarLogCambioEstadoFinal` (espeja el cambio final realizado-desde-cancelado).
  - Helpers nuevos: `registrarDualWriteCambioEstado`, `registrarDualWriteCambioEstadoPorId`,
    `construirTextoCambioEstado`.

## Gap 3 — Características del traslado + traslado prioritario
- **Características** (móvil grande / con acompañante / silla de ruedas): flags `int(11)` por tramo en
  `cs.traslados` (no en internos). **Nueva categoría `origen='CARACTERISTICAS'`**, texto sintetizado
  por tramo (ej. "Móvil grande, Silla de ruedas").
  - **Fix**: `ALTER ENUM origen += 'CARACTERISTICAS'` (script 011); valor agregado al enum
    `OrigenObservacion` de los 4 repos (wsturnos/wstraslados/wslogistica/wsauditoriatraslados);
    dual-write en wsturnos (`registrarCaracteristicas`, IDA/VUELTA); backfill histórico (script 012);
    config visual en el front (`feedObservacionesConfig.ts`: icono `Accessible`, color verde,
    `ORDEN_ORIGENES`) + i18n es/en + type `OrigenObservacion` del front.
- **Traslado prioritario**: ya se dual-escribía crudo; ahora con prefijo `"Traslado prioritario: {texto}"`
  dentro de `origen='LOGISTICA'` (`registrarDualWriteLogisticaOperativa` / `prefijarTrasladoPrioritario`).

## Scripts SQL (orden de aplicación, después del 010)
1. `011_alter_origen_add_caracteristicas.sql` — ALTER ENUM (antes de cualquier dual-write/backfill de CARACTERISTICAS).
2. `012_backfill_caracteristicas.sql` — backfill histórico de características por tramo (idempotente).

## Matriz de fuentes — filas nuevas/ajustadas
| Fuente | Quién escribe | origen | subtipo | tramo |
|---|---|---|---|---|
| Obs. tramitador del turno | **wsturnos** (alta turno) | TRAMITADOR | (NULL) | IDA / VUELTA |
| Características del traslado | **wsturnos** (alta) + backfill | **CARACTERISTICAS** | (NULL) | IDA / VUELTA |
| Cambio de estado (tabulado+escrito) | wslogistica | LOGISTICA | **CAMBIO_ESTADO** | GENERAL |
| Cambio de estado final (traslados_log) | wslogistica | LOGISTICA | **CAMBIO_ESTADO** | GENERAL |
| Traslado prioritario | wslogistica | LOGISTICA | (NULL) | GENERAL |

## Pendiente / follow-up
- **wstraslados** path directo `/traslados/crear` (`TrasladoServiceDTOImpl.save`): el alta por turno
  (wsturnos) ya está cubierta; el alta directa por wstraslados (legacy, en deprecación hacia wslogistica)
  no tiene aún el dual-write TRAMITADOR en la creación — follow-up de baja prioridad.
- **Características en internos**: no existen columnas en `cs.traslados_internos` (sólo prioritario).
- **Verificación**: sin JDK 11 local (sólo JDK 21) → compilar en CI. Front: `tsc --noEmit` + `npm run lint`
  en CI / con Nexus. Luego spring-boot-review (back) + react-mfe-review (front) + MRs por repo a develop.

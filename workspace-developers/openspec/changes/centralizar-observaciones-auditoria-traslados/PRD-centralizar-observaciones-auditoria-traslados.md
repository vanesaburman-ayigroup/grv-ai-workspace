# PRD — Centralización de observaciones de Auditoría de Traslados (GRV-2084)

| | |
|---|---|
| **Producto / Módulo** | Auditoría de Traslados (auditoría de facturación) |
| **Épica / Ticket** | GRV-2084 — Propuesta 2, opción B |
| **Estado** | Listo para QA (diseño) |
| **Documentos relacionados** | `proposal.md` (resumen de cambio) · `design.md` (diseño técnico / SDD) · `historias-usuario-GRV-2084.md` (HU para QA) · `specs/centralizar-observaciones/spec.md` · `docs/Propuestas-Auditoria-Traslados-SATAPP-Junio-2026.md` (relevamiento, secciones 2 y 3) |
| **Última actualización** | 18/06/2026 |
| **Responsables** | Vanesa Burman · Yanina Di Prima |

---

## 1. Objetivo

Que el auditor pueda ver **todas** las observaciones de un traslado en un **único feed**, con la **fuente claramente identificada** (tramitador, CEM, logística, peaje, estacionamiento, SATAPP, auditoría) y poder **filtrar por origen**, en lugar de ver solo una parte, mezclada y sin saber quién escribió cada cosa.

## 2. Contexto y problema

Hoy las observaciones de un traslado las escriben **muchos módulos**, cada uno en **columnas distintas** de dos tablas (`traslados` y `traslados_internos`), y el drawer de auditoría solo muestra algunas. Esto genera tres problemas:

- **No se ve todo**: el drawer no muestra las observaciones de control, traslado negativo, datos pool, anulación ni estacionamiento.
- **Está mezclado**: las observaciones del tramitador y de otros módulos comparten cajas, sin separación clara.
- **No se puede atribuir el origen**: el caso más grave es **SATAPP**, que **no tiene columna propia** — su observación se **concatena** en la misma caja que el tramitador, con etiquetas embebidas en el texto (`[Peaje:..][Estacionamiento:..][Espera:..]`). El auditor ve el texto pero no puede saber que es de SATAPP, ni separarlo.

El auditor necesita poder **demostrar las observaciones de todos los módulos** (pedido de prioridad ALTA del relevamiento) con trazabilidad real por origen.

## 3. Usuarios

- **Auditor de traslados** (usuario principal): revisa y audita traslados; necesita ver y atribuir todas las observaciones.
- **QA**: certifica el comportamiento antes del release.
- **Equipos de los módulos** (tramitador, logística): adoptan el dual-write en su servicio.

## 4. Alcance

**Incluye:**
- **Tabla unificada** `traslados_observaciones`: cada observación es una fila con su **origen**, **tramo**, **texto**, **usuario** y **fecha/hora**.
- **Backfill** del histórico: las observaciones ya cargadas se migran a la tabla nueva con su origen inferido.
- **Dual-write**: durante la transición cada módulo sigue escribiendo su columna actual **y además** la tabla nueva. Migración gradual, sin big-bang.
- **Feed unificado** en el drawer (simple y múltiple): timeline cronológico, **filtrable por origen**, con ícono/color por fuente (paleta SAS), incluyendo las fuentes antes no visibles.
- **Convivencia de vistas**: durante la transición se muestran ambas presentaciones (cajas históricas + feed nuevo) para validar que no se pierde nada.
- **SATAPP atribuible** desde el día 1 del dual-write.

**No incluye (fuera de esta entrega):**
- **Consolidación final** (quitar las cajas históricas y dejar el feed como fuente única): se diseña el criterio de corte, no se ejecuta.
- **Cartel "monto no informado por SATAPP"** (Propuesta 3): change aparte.
- **Persistir km/espera/estacionamiento de SATAPP del lado escritura** (`persistirMontoViaje`): decisión de negocio separada.
- **Observación de estacionamiento atribuida (`origen='ESTACIONAMIENTO'`)**: hoy el estacionamiento está embebido en texto libre, sin fuente estructurada. El valor `ESTACIONAMIENTO` queda reservado en el modelo, pero su carga al feed es un **follow-up** que depende de que logística estructure esa observación; **no es entregable en esta fase** (ni por backfill ni por dual-write). Entrará por dual-write cuando exista la fuente estructurada.

## 5. Requisitos funcionales

| ID | Requisito | Detalle |
|---|---|---|
| RF-1 | Registro atribuido | Cada observación queda como fila en `traslados_observaciones` con su origen, tramo, texto, usuario y fecha. |
| RF-2 | SATAPP atribuible | La observación de SATAPP es distinguible del texto del tramitador (no por etiquetas embebidas). |
| RF-3 | Backfill del histórico | Las observaciones existentes se migran a la tabla nueva con su origen inferido por columna. |
| RF-4 | Backfill idempotente | Re-ejecutar el backfill no duplica filas. |
| RF-5 | Dual-write | Durante la transición cada módulo escribe su columna actual y la tabla nueva. |
| RF-6 | Adopción incremental | Los módulos migran de a uno; los no migrados siguen funcionando. |
| RF-7 | Feed unificado | El drawer muestra todas las observaciones en un timeline con la fuente identificada. |
| RF-8 | Filtro por origen | El feed se puede filtrar por uno o varios orígenes (y por subtipo dentro de tramitador) sin recargar. |
| RF-9 | Fuentes antes ocultas, **atribuidas y distinguibles** | Aparecen en el feed control, traslado negativo, datos pool, anulación y desestimo, cada una **distinguible** entre sí (no solo "visible") mediante un **subtipo** dentro de `origen=TRAMITADOR` (CONTROL, ANULACION, TRASLADO_NEGATIVO, DATOS_POOL, DESESTIMO), de modo que el auditor pueda filtrarlas/agruparlas por separado. **Estacionamiento** queda como **follow-up dependiente de la fuente estructurada** (hoy embebido en texto libre, sin columna propia): no es entregable en esta fase; entrará por dual-write cuando logística estructure la observación. |
| RF-10 | Convivencia de vistas | Durante la transición se muestran las cajas históricas y el feed; la info visible nunca baja del estado actual. |
| RF-11 | Contrato intacto | El feed se expone como datos nuevos y opcionales; el backend se puede desplegar antes que el front. |

> El detalle en formato Historia de Usuario (Dado/Cuando/Entonces) está en `historias-usuario-GRV-2084.md` (HU-1 a HU-7).

## 6. Requisito no funcional

- **Migración segura**: DDL y backfill en scripts separados (la base no permite revertir DDL dentro de una transacción); ambos idempotentes y revisados con el control de migraciones. El backfill sobre la tabla grande de traslados se planifica en ventana de bajo tráfico.
- **No pérdida de información**: en ningún momento de la transición el auditor ve menos de lo que ve hoy (la presentación histórica se conserva hasta la consolidación final).

## 7. Fuentes de observación por origen (referencia)

> Quién escribe cada observación y con qué `origen`/`subtipo`/`tramo` entra al feed. Nombres de columna en **minúsculas** (forma real del `DESCRIBE`). El `origen` es el **módulo**; el `subtipo` discrimina los tipos de observación de un mismo módulo (hoy solo tramitador).

| Fuente | Quién escribe | Columna histórica | Origen | Subtipo | Tramo | ¿Visible hoy? |
|---|---|---|---|---|---|:---:|
| Tramitador (gestión) | wstraslados | `observaciones` / `observaciones_regreso` / `observaciones_traslado` | TRAMITADOR | (NULL) | IDA / VUELTA / GENERAL | ✅ (mezclada) |
| Tramitador — control | wstraslados | `observaciones_control` | TRAMITADOR | CONTROL | GENERAL | ❌ |
| Tramitador — traslado negativo | wstraslados | `observacion_traslado_negativo` | TRAMITADOR | TRASLADO_NEGATIVO | GENERAL | ❌ |
| Tramitador — datos pool | wstraslados | `observacion_datos_pool` | TRAMITADOR | DATOS_POOL | GENERAL | ❌ |
| Tramitador — desestimo | wstraslados | `observaciones_desestimo` | TRAMITADOR | DESESTIMO | GENERAL | ❌ |
| Anulación | wstraslados / wslogistica | `observaciones_anulacion` / `observaciones_anulacion_vuelta` | TRAMITADOR | ANULACION | IDA / VUELTA | ❌ |
| CEM (espontáneo) | wslogistica | `traslados_internos.observaciones_ida` / `observaciones_vuelta` | CEM | (NULL) | IDA / VUELTA | ✅ parcial |
| Logística (operativa) | wslogistica | `observaciones_logistica` y afines | LOGISTICA | (NULL) | GENERAL | ✅ |
| Logística — base | wslogistica | `observaciones_base_ida` / `observaciones_base_vuelta` | LOGISTICA | (NULL) | IDA / VUELTA | ✅ |
| Peaje | wslogistica | `observaciones_peaje_ida` / `observaciones_peaje_vuelta` | PEAJE | (NULL) | IDA / VUELTA | ✅ |
| **Estacionamiento (follow-up)** | wslogistica | (hoy embebido en texto libre, **sin fuente estructurada**) | ESTACIONAMIENTO | (NULL) | IDA / VUELTA | ❌ — **no entregable en esta fase**; entra por dual-write futuro |
| SATAPP (viaje) | wslogistica (`agregarObservaciones`) | concatenado en la caja del tramitador/CEM | SATAPP | (NULL) | IDA / VUELTA | ⚠️ embebido, no atribuible |
| Auditoría | wsauditoriatraslados | `observacionAuditoria` | AUDITORIA | (NULL) | GENERAL | ✅ |

## 8. Criterios de aceptación / casos de prueba (QA)

| # | Caso | Dónde | Resultado esperado |
|---|---|---|---|
| CP-01 | Observación de tramitador | Drawer | Aparece con `origen=TRAMITADOR` y tramo correcto |
| CP-02 | Observación de CEM | Drawer (interno) | Aparece con `origen=CEM` |
| CP-03 | Observación de logística | Drawer | Aparece con `origen=LOGISTICA` |
| CP-04 | Observación de peaje | Drawer | Aparece con `origen=PEAJE` |
| CP-05 | Observación de SATAPP | Drawer | Aparece con `origen=SATAPP`, separada del tramitador |
| CP-06 | Observación de auditoría | Drawer | Aparece con `origen=AUDITORIA` |
| CP-07 | Control / traslado negativo / datos pool / desestimo | Drawer | Aparecen en el feed **y son distinguibles entre sí** por su `subtipo` (CONTROL / TRASLADO_NEGATIVO / DATOS_POOL / DESESTIMO), filtrables por separado. **Estacionamiento NO se valida en esta fase** (follow-up dependiente de la fuente estructurada). |
| CP-08 | Anulación | Drawer | Aparece atribuida con `origen=TRAMITADOR`, `subtipo=ANULACION` y `tramo` IDA/VUELTA según la pata anulada (antes no se mostraba) |
| CP-09 | Filtro por un origen (solo SATAPP) | Feed | Muestra solo SATAPP |
| CP-10 | Filtro por varios orígenes | Feed | Muestra solo los seleccionados |
| CP-11 | Sin filtro | Feed | Muestra todas, orden cronológico con **desempate estable `fecha_hora, id`** (determinista aun con fechas de backfill repetidas) |
| CP-12 | Convivencia: feed vs cajas históricas | Drawer | El feed no pierde nada respecto de las cajas; **SATAPP no aparece duplicado**: la caja histórica de-enfatiza la etiqueta SATAPP embebida y la fuente atribuida es el feed |
| CP-13 | Dual-write: observación nueva | DB | Queda en la columna histórica **y** en la tabla nueva: en la **misma transacción** cuando el módulo la maneja; si es best-effort y falla, se loguea y el **backfill idempotente reconcilia** la fila faltante (eventualmente consistente, nunca se pierde) |
| CP-14 | Backfill: histórico migrado | DB | Cada texto histórico genera su fila con origen/tramo |
| CP-15 | Backfill idempotente | DB | Re-ejecutar no duplica |
| CP-16 | SATAPP embebido inequívoco | DB | Dos filas: TRAMITADOR + SATAPP |
| CP-17 | SATAPP embebido ambiguo | DB | Una fila TRAMITADOR marcada para revisión; no se pierde texto |
| CP-18 | Contrato intacto (backend sin front del feed) | Pantalla | Funciona igual que antes |
| CP-19 | Rollback del front (feed apagado) | Pantalla | Vuelve a las cajas históricas, sin errores |
| CP-20 | Invariante de id | DB | Exactamente uno de `id_traslado` / `id_traslado_interno`, **garantizado por `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))`** (MariaDB 10.5.29 lo evalúa). Fallback verificable: query de control post-backfill que devuelve 0 filas inválidas |

## 9. Supuestos y dependencias

- La lista definitiva de columnas de observación quedó **cerrada** con el `DESCRIBE` de `traslados` y `traslados_internos` en la réplica (18/06/2026): 16 columnas de texto en `traslados` + 11 en `traslados_internos` (27 en total), todas mapeadas a `origen`/`subtipo`/`tramo` o excluidas con justificación en el SDD (D3).
- **Motor de BD:** MariaDB 10.5.29 (verificado en réplica). Relevante porque desde 10.2.1 evalúa restricciones `CHECK`, lo que habilita el constraint de exclusividad de ids (CP-20).
- El feed depende de que los módulos adopten el dual-write; la adopción es incremental (no requiere release coordinado).
- La verificación de DDL/backfill/dual-write se hace en réplica/STAGE (el acceso de diagnóstico es solo lectura).
- La consolidación final (fuente única) es una entrega posterior con criterios de corte definidos en el diseño.
- **Estacionamiento atribuido** depende de que logística estructure la observación de estacionamiento (hoy embebida en texto libre): es un **follow-up** fuera de esta fase.

## 10. Métrica de aporte IA vs intervención humana

> Estimación cualitativa del tramo de trabajo de este desarrollo (diseño).

| | | |
|---|---|---|
| 🤖 | **Ejecución automatizada (IA)** | **~85%** · redacción de PRD/HU/spec, diseño técnico (SDD), modelo de datos, plan de migración/convivencia, matrices de fuentes y casos de prueba, a partir del relevamiento verificado contra código |
| 🧑‍💻 | **Decisiones / presencia humana** | **~100% de las decisiones** · elección de la opción B (tabla unificada), reglas de atribución de origen por módulo, criterio de convivencia/consolidación, paleta SAS, validación funcional |
| ⚖️ | **Balance** | ✅ sano · las decisiones de negocio (qué centralizar, cómo atribuir, hasta dónde llega esta fase) fueron humanas; la documentación y el diseño, asistidos |

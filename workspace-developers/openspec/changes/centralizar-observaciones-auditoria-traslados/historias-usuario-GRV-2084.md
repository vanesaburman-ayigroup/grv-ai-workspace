# GRV-2084 — Historias de Usuario (centralización de observaciones de Auditoría de Traslados)

> Subtareas de **GRV-2084** en formato HU con criterios de aceptación basados en los specs del change
> (`specs/centralizar-observaciones/spec.md`). Pensadas para que QA las tome desde el workspace de specs.
> Criterios en formato **Dado / Cuando / Entonces** (Gherkin), trazables a los escenarios del spec.

---

## HU-1 — Tabla unificada de observaciones con atribución de origen

**Contexto.** Hoy las observaciones de un traslado están dispersas en muchas columnas de dos tablas (`cs.traslados` y `cs.traslados_internos`), y SATAPP ni siquiera tiene columna propia: se concatena en la misma caja que el tramitador con etiquetas embebidas. Se crea una tabla única `cs.traslados_observaciones` donde cada observación es una fila atómica con su `origen`/módulo (TRAMITADOR, CEM, LOGISTICA, PEAJE, ESTACIONAMIENTO, SATAPP, AUDITORIA), un `subtipo` opcional (sub-clasificación dentro del módulo: para tramitador CONTROL/ANULACION/TRASLADO_NEGATIVO/DATOS_POOL/DESESTIMO; NULL = común), su `tramo` (IDA/VUELTA/GENERAL), `texto`, `usuario_sistema` y `fecha_hora`.

**Historia.** Como **auditor de traslados**, quiero que cada observación quede registrada con su origen (y subtipo cuando aplica), para saber **quién** escribió cada cosa y de qué tipo es, sin tener que adivinarlo por etiquetas en texto libre.

**Criterios de aceptación.**
- **Dado** que un módulo registra una observación, **Cuando** se guarda, **Entonces** queda una fila en `traslados_observaciones` con el `origen` de ese módulo, el `subtipo` cuando aplica, el `tramo`, el `texto`, el `usuario_sistema` y la `fecha_hora`.
- **Dado** una observación de control / anulación / traslado negativo / datos pool / desestimo del tramitador, **Entonces** queda con `origen='TRAMITADOR'` y el `subtipo` correspondiente, distinguible y filtrable por separado.
- **Dado** un traslado de `cs.traslados`, **Entonces** la fila tiene `id_traslado` informado e `id_traslado_interno` nulo; **Dado** uno de `cs.traslados_internos`, al revés; el `CHECK` de exclusividad lo garantiza a nivel datos.
- **Dado** que SATAPP informa una observación de viaje, **Entonces** queda con `origen='SATAPP'` y es distinguible del texto del tramitador (sin depender de etiquetas embebidas).

**Notas técnicas.** `CREATE TABLE IF NOT EXISTS cs.traslados_observaciones` (InnoDB, `utf8mb4_unicode_ci`, columna `subtipo VARCHAR(40) NULL`, índices por `id_traslado` y por `id_traslado_interno`, `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` — MariaDB 10.5.29 lo evalúa). DDL separado del DML (D5). _Spec: "Registro unificado y atribuido de observaciones del traslado"._

---

## HU-2 — Backfill del histórico (idempotente)

**Contexto.** Para que el feed muestre también las observaciones ya cargadas, se migran las columnas actuales hacia la tabla nueva, infiriendo el origen por la columna de procedencia. El script es re-ejecutable: no duplica.

**Historia.** Como **auditor**, quiero ver en el feed también las observaciones históricas, para no perder lo que se cargó antes de la nueva tabla.

**Criterios de aceptación.**
- **Dado** un traslado con observaciones en sus columnas actuales, **Cuando** se ejecuta el backfill, **Entonces** cada texto no vacío genera una fila con el `origen` y el `tramo` que corresponden a esa columna.
- **Dado** que el backfill se ejecuta dos veces, **Entonces** no se crean filas duplicadas (idempotente).
- **Dado** una caja con texto del tramitador y de SATAPP concatenado por etiquetas, **Cuando** la separación es inequívoca, **Entonces** se crean dos filas (TRAMITADOR + SATAPP); **Cuando** es ambigua, **Entonces** se conserva como TRAMITADOR y se marca para revisión (no se pierde texto).

**Notas técnicas.** Script DML separado, `INSERT ... SELECT ... WHERE NOT EXISTS`. `fecha_hora` histórica = mejor fecha disponible del traslado. Revisado con `mariadb-migration-review`. _Spec: "Backfill inicial idempotente desde las columnas actuales"._

---

## HU-3 — Convivencia por dual-write (sin big-bang)

**Contexto.** Durante la transición, cada módulo sigue escribiendo su columna actual y además inserta en la tabla nueva. Así la migración es gradual, por módulo, y el rollback es trivial (la columna vieja sigue siendo el respaldo).

**Historia.** Como **desarrollador del ecosistema**, quiero que cada módulo adopte la tabla nueva sin dejar de escribir su columna, para migrar de a poco sin un release coordinado ni riesgo de pérdida.

**Criterios de aceptación.**
- **Dado** que un módulo registra una observación durante la transición, **Entonces** queda en su columna histórica **y** en `traslados_observaciones` con el mismo texto y su `origen`.
- **Dado** que algunos módulos ya hacen dual-write y otros todavía no, **Entonces** los traslados siguen funcionando: se siguen leyendo las columnas históricas y el feed muestra lo que ya esté en la tabla nueva.
- **Dado** que el insert en la tabla nueva falla, **Entonces** la operación principal del módulo no se bloquea (la columna histórica es el respaldo).

**Notas técnicas.** Dual-write por repo (`wstraslados`, `wslogistica`, `wsauditoriatraslados`), adopción incremental; insert en la misma transacción cuando es posible. _Spec: "Dual-write durante la convivencia"._

---

## HU-4 — Feed unificado filtrable por origen en el drawer

**Contexto.** El drawer suma un bloque "Observaciones del traslado": un timeline cronológico de todas las observaciones (orden estable `fecha_hora, id`), con la fuente identificada por ícono/color (paleta SAS) y filtrable por origen (y por subtipo dentro del tramitador). Incluye las fuentes que hoy el drawer no muestra (control, traslado negativo, datos pool, anulación, desestimo). Estacionamiento queda como follow-up (sin fuente estructurada hoy).

**Historia.** Como **auditor**, quiero ver todas las observaciones del traslado en un único feed, con su origen identificado y poder filtrar por fuente, para revisar de un vistazo qué dijo cada módulo.

**Criterios de aceptación.**
- **Dado** un traslado con observaciones de varios módulos, **Entonces** el feed muestra cada una con su fuente (ícono/color) y su tramo (ida/vuelta/general).
- **Dado** que selecciono uno o más orígenes en el filtro (p. ej. solo SATAPP), o un subtipo del tramitador, **Entonces** el feed muestra solo esos orígenes/subtipos y oculta el resto, sin recargar.
- **Dado** un traslado con observación de control / traslado negativo / datos pool / anulación / desestimo, **Entonces** esas observaciones aparecen en el feed atribuidas a `origen='TRAMITADOR'` con su `subtipo`, distinguibles entre sí (antes no se mostraban). **Estacionamiento** no se valida en esta fase (follow-up).

**Notas técnicas.** Componente prop-driven (sas-component-lib primero; si no, custom SOLID). Mapeo origen→ícono/color dentro de la paleta SAS. Drawer simple (`FormAuditar.tsx`) y múltiple (`AuditarTabla.tsx`). _Spec: "Feed unificado de observaciones en el drawer de auditoría"._

---

## HU-5 — Convivencia de vistas (vieja + nueva) durante la transición

**Contexto.** Para que el auditor valide que el feed no pierde nada, durante la transición se muestran ambas presentaciones: las cajas históricas actuales y el feed unificado. La presentación histórica no se elimina hasta la consolidación final.

**Historia.** Como **auditor**, quiero ver durante la transición tanto las cajas de observaciones que ya conocía como el feed nuevo, para comprobar que el feed muestra todo lo que veía antes (y más).

**Criterios de aceptación.**
- **Dado** que la convivencia está activa, **Cuando** abro el drawer, **Entonces** veo el feed unificado **y** la presentación histórica de observaciones (cajas actuales).
- **Dado** una observación que un módulo no adaptado todavía no escribió en la tabla nueva, **Entonces** la sigo viendo en la presentación histórica (la información visible nunca es menor a la actual).
- **Dado** que se desactiva el feed (rollback del front), **Entonces** la pantalla vuelve a las cajas históricas y sigue funcionando.

**Notas técnicas.** Modo "ambas vistas" en el drawer. Consolidación final (quitar las cajas históricas) es entrega posterior, con criterios de corte (D7). _Spec: "Vista de transición con ambas presentaciones"._

---

## HU-6 — Lectura del feed sin romper el contrato actual

**Contexto.** El feed se expone como datos nuevos y opcionales, sin tocar los campos que el drawer ya recibe. Así el backend (tabla + backfill + dual-write) se puede desplegar antes que el front del feed.

**Historia.** Como **desarrollador**, quiero exponer el feed sin alterar el contrato actual del drawer, para poder desplegar el backend antes que el front sin romper nada.

**Criterios de aceptación.**
- **Dado** que se libera la lectura del feed, **Entonces** los campos actuales del drawer (`observaciones`, `detalle`, `detalleLogistica`, `observacionAuditoria`, estado de logística) siguen presentes con su forma actual.
- **Dado** que se despliegan la tabla, el backfill y el dual-write sin el front del feed, **Entonces** la pantalla de auditoría sigue funcionando igual que antes, sin errores por datos nuevos no consumidos.

**Notas técnicas.** Feed como recurso/campos nuevos y opcionales en `wsauditoriatraslados`. _Spec: "Lectura del feed sin romper el contrato actual del drawer"._

---

## HU-7 — Verificación QA (E2E del feed y la convivencia)

**Contexto.** Suite de aceptación end-to-end que valida la atribución de origen, el filtro, la convivencia de vistas y la no-pérdida de información, en el drawer simple y múltiple.

**Historia.** Como **QA**, quiero un conjunto de casos E2E sobre el feed y la convivencia, para certificar la centralización de observaciones antes de release.

**Criterios de aceptación (casos de prueba).**
- Observaciones de las **7 fuentes** (tramitador, CEM, logística, peaje, estacionamiento, SATAPP, auditoría) aparecen atribuidas en el feed.
- **Filtro por origen** muestra/oculta correctamente; combinación de varios orígenes.
- **SATAPP atribuible**: una observación de SATAPP aparece como SATAPP, no mezclada con tramitador.
- **Fuentes antes ocultas** (control, traslado negativo, datos pool, anulación, estacionamiento) aparecen en el feed.
- **Convivencia**: el feed y las cajas históricas muestran lo mismo (el feed no pierde nada).
- **Dual-write**: una observación nueva queda en la columna histórica y en la tabla nueva.
- **Backfill idempotente**: re-ejecutar no duplica.
- **Contrato intacto**: desplegar backend sin el front del feed no rompe la pantalla.

**Notas técnicas.** Verificación de DDL/backfill/dual-write en réplica/STAGE (el MCP read-only no ejecuta DDL/DML). Front cubierto por tests del componente de feed + esta suite E2E. _Spec: todos los escenarios de `centralizar-observaciones`._

---

## Matriz de fuentes de observación por origen

> Referencia única para QA: qué módulo escribe cada observación, en qué columna histórica, y con qué `origen`/`tramo` entra a `traslados_observaciones`.

> Nombres de columna en **minúsculas** (forma real del `DESCRIBE`). `origen` = módulo; `subtipo` = sub-clasificación dentro del módulo (hoy solo tramitador).

| Fuente | Quién escribe | Columna histórica | `origen` | `subtipo` | `tramo` | ¿Visible hoy en el drawer? |
|---|---|---|---|---|---|:---:|
| Tramitador (gestión) | wstraslados | `traslados.observaciones` / `observaciones_regreso` / `observaciones_traslado` | TRAMITADOR | (NULL) | IDA / VUELTA / GENERAL | ✅ (mezclada) |
| Tramitador — control | wstraslados | `observaciones_control` | TRAMITADOR | CONTROL | GENERAL | ❌ |
| Tramitador — traslado negativo | wstraslados | `observacion_traslado_negativo` | TRAMITADOR | TRASLADO_NEGATIVO | GENERAL | ❌ |
| Tramitador — datos pool | wstraslados | `observacion_datos_pool` | TRAMITADOR | DATOS_POOL | GENERAL | ❌ |
| Tramitador — desestimo | wstraslados | `observaciones_desestimo` | TRAMITADOR | DESESTIMO | GENERAL | ❌ |
| Anulación | wstraslados / wslogistica | `observaciones_anulacion` / `observaciones_anulacion_vuelta` | TRAMITADOR | ANULACION | IDA / VUELTA | ❌ |
| CEM (espontáneo) | wslogistica | `traslados_internos.observaciones_ida` / `observaciones_vuelta` | CEM | (NULL) | IDA / VUELTA | ✅ parcial |
| Logística (operativa) | wslogistica | `observaciones_logistica` / `_prioritario` / `_habilita_espera` | LOGISTICA | (NULL) | GENERAL | ✅ (`detalleLogistica`) |
| Logística — base | wslogistica | `observaciones_base_ida` / `_vuelta` | LOGISTICA | (NULL) | IDA / VUELTA | ✅ (dentro de `detalle`) |
| Peaje | wslogistica | `observaciones_peaje_ida` / `_vuelta` | PEAJE | (NULL) | IDA / VUELTA | ✅ (dentro de `detalle`) |
| **Estacionamiento (follow-up)** | wslogistica | (hoy embebido en texto libre, **sin fuente estructurada**) | ESTACIONAMIENTO | (NULL) | IDA / VUELTA | ❌ — **no entregable en esta fase** |
| SATAPP (viaje) | wslogistica (`agregarObservaciones`) | concatenado en `observaciones`/`observaciones_regreso`/`observaciones_traslado` u `observaciones_ida/_vuelta` (etiquetas `[Peaje:..][Estacionamiento:..][Espera:..]`) | SATAPP | (NULL) | IDA / VUELTA | ⚠️ embebido, no atribuible |
| Auditoría | wsauditoriatraslados | `observacionAuditoria` (editable) | AUDITORIA | (NULL) | GENERAL | ✅ |

---

## Matriz consolidada de casos de prueba para QA

| # | Caso | Dónde | Resultado esperado |
|---|---|---|---|
| CP-01 | Crear observación de tramitador | Drawer | Aparece en el feed con `origen=TRAMITADOR` y tramo correcto |
| CP-02 | Observación de CEM (traslado espontáneo) | Drawer (interno) | Aparece con `origen=CEM` |
| CP-03 | Observación de logística (operativa/base) | Drawer | Aparece con `origen=LOGISTICA` |
| CP-04 | Observación de peaje | Drawer | Aparece con `origen=PEAJE` |
| CP-05 | Observación de SATAPP | Drawer | Aparece con `origen=SATAPP`, **separada** del tramitador |
| CP-06 | Observación de auditoría (editar `observacionAuditoria`) | Drawer | Aparece con `origen=AUDITORIA` |
| CP-07 | Observación de control / traslado negativo / datos pool / desestimo | Drawer | Aparecen en el feed **y son distinguibles entre sí** por `subtipo` (CONTROL/TRASLADO_NEGATIVO/DATOS_POOL/DESESTIMO), filtrables por separado. Estacionamiento NO se valida en esta fase (follow-up) |
| CP-08 | Observación de anulación | Drawer | Aparece con `origen=TRAMITADOR`, `subtipo=ANULACION` y `tramo` IDA/VUELTA según la pata anulada (antes no se mostraba) |
| CP-09 | Filtro por un origen (solo SATAPP) | Feed | Muestra solo SATAPP; oculta el resto |
| CP-10 | Filtro por varios orígenes | Feed | Muestra solo los seleccionados |
| CP-11 | Sin filtro | Feed | Muestra todas las observaciones, orden cronológico con desempate estable `fecha_hora, id` |
| CP-12 | Convivencia: feed vs cajas históricas | Drawer | El feed muestra lo mismo que las cajas (no pierde nada); **SATAPP no se ve duplicado** (la caja histórica de-enfatiza la etiqueta embebida) |
| CP-13 | Dual-write: observación nueva | DB | Queda en la columna histórica **y** en `traslados_observaciones`: misma transacción cuando el módulo la maneja; si es best-effort y falla, se loguea y el backfill idempotente reconcilia |
| CP-14 | Backfill: histórico migrado | DB | Cada texto histórico no vacío genera su fila con origen/tramo correcto |
| CP-15 | Backfill idempotente (re-ejecutar) | DB | No se duplican filas |
| CP-16 | Backfill de SATAPP embebido inequívoco | DB | Dos filas: TRAMITADOR + SATAPP |
| CP-17 | Backfill de SATAPP embebido ambiguo | DB | Una fila TRAMITADOR marcada para revisión; no se pierde texto |
| CP-18 | Contrato intacto: backend sin front del feed | Pantalla | La pantalla funciona igual que antes; campos actuales presentes |
| CP-19 | Rollback del front (feed apagado) | Pantalla | Vuelve a las cajas históricas, sin errores |
| CP-20 | Invariante de id | DB | Cada fila tiene exactamente uno de `id_traslado` / `id_traslado_interno`, garantizado por `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` (MariaDB 10.5.29 lo evalúa); fallback: query de control post-backfill = 0 filas inválidas |

> Los casos de DB (CP-13 a CP-17, CP-20) se verifican en réplica/STAGE; el MCP MariaDB read-only no ejecuta DDL/DML.

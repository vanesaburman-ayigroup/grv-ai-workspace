## Context

La pantalla de **Auditoría de Traslados** vive en el MFE `auditoriafacturacion` (React 18 + Redux Toolkit Query + `sas-component-lib` + MUI v5) y consume `wsauditoriatraslados` (Spring Boot 2.x, Java 11, **MariaDB 10.5.29** —verificado vía `SELECT VERSION()` en la réplica el 18/06/2026—, esquema `cs`). Las observaciones de un traslado las escriben **varios módulos** del ecosistema (tramitador, CEM, logística, peaje, estacionamiento, SATAPP, auditoría), cada uno en **columnas distintas** de dos tablas físicas: `cs.traslados` (legacy: tramitador + remis) y `cs.traslados_internos` (moderno: CEM/espontáneo).

> **Versión de motor (fija).** `MariaDB 10.5.29-MariaDB-log`. Relevante porque desde 10.2.1 MariaDB **evalúa** las restricciones `CHECK` (no las ignora como hacía MySQL 5.x), lo que habilita la decisión D6 sobre el CHECK de exclusividad de ids.

> **Fuente de verdad funcional.** `docs/Propuestas-Auditoria-Traslados-SATAPP-Junio-2026.md`, secciones 2 (mapeo de observaciones por traslado) y 3 (Propuesta 2). Este diseño implementa la **opción B** de la Propuesta 2.

**Mapeo de observaciones verificado contra código (sección 2 del doc):**

> **Notación de columnas.** Todos los nombres de columna de este documento se escriben en **minúsculas**, tal como los devuelve el `DESCRIBE` real de `cs.traslados` / `cs.traslados_internos` (ver Open Questions). Se evita la forma en mayúsculas para no inducir error al escribir el SQL del backfill.

| Origen | Quién escribe | Tabla.columna | ¿Visible hoy en auditoría? |
|---|---|---|---|
| **Tramitador** (gestión/creación) | `wstraslados` | `traslados.observaciones` / `observaciones_regreso` | ✅ pero **mezclada** en la caja del tramo |
| Tramitador — control | `wstraslados` | `traslados.observaciones_control` | ❌ |
| Tramitador — traslado negativo | `wstraslados` | `traslados.observacion_traslado_negativo` | ❌ |
| Tramitador — datos pool | `wstraslados` | `traslados.observacion_datos_pool` | ❌ |
| Tramitador — desestimo | `wstraslados` | `traslados.observaciones_desestimo` | ❌ |
| Tramitador — observación grande (`observaciones_traslado`) | `wstraslados` | `traslados.observaciones_traslado` (vc5000; puede traer SATAPP embebido) | ⚠️ embebido, no atribuible |
| Anulación | `wstraslados` / `wslogistica` | `traslados.observaciones_anulacion` / `observaciones_anulacion_vuelta` (e ídem en `traslados_internos`) | ❌ |
| **CEM** (espontáneo) | `wslogistica` | `traslados_internos.observaciones_ida` / `observaciones_vuelta` | ✅ parcial (caja del tramo de internos) |
| **Logística** (operativa) | `wslogistica` | `observaciones_logistica`, `observaciones_traslado_prioritario`, `observaciones_habilita_espera` | ✅ (`detalleLogistica`) |
| Logística — base | `wslogistica` | `observaciones_base_ida` / `observaciones_base_vuelta` | ✅ (dentro de `detalle`) |
| **Peaje** | `wslogistica` | `observaciones_peaje_ida` / `observaciones_peaje_vuelta` | ✅ (dentro de `detalle`) |
| **Estacionamiento** | `wslogistica` | hoy embebido en texto libre (no estructurado) | ❌ |
| **SATAPP** (viaje) | `wslogistica` vía `agregarObservaciones` (`TrasladoServiceImpl.java:2541-2598`) | **concatenado** en `observaciones`/`observaciones_regreso`/`observaciones_traslado` (traslados) u `observaciones_ida` / `observaciones_vuelta` (internos), con etiquetas `[Peaje:..][Estacionamiento:..][Espera:..]` | ⚠️ visible pero **embebido y no atribuible** |
| **Auditoría** | `wsauditoriatraslados` | `observacionAuditoria` (editable en el drawer) | ✅ |

**Lo que muestra hoy el drawer** (verificado en `view 002` + `DatosAuditoriaDTO` + front): (1) `observaciones` (caja del viaje), (2) `detalle` = [obs peaje, kms, espera, obs base], (3) `detalleLogistica` (texto libre de logística), (4) `observacionAuditoria` (editable), (5) estado de logística como chip.

**GAPS identificados:** (a) no se muestran control, traslado negativo, datos pool, anulación, desestimo ni estacionamiento; (b) **no hay atribución de origen** — sobre todo SATAPP comparte caja con el tramitador y solo se distingue por etiquetas en texto libre; (c) control, traslado negativo, datos pool, anulación y desestimo son todas escrituras del módulo tramitador (`origen='TRAMITADOR'`) pero **conceptualmente distintas entre sí** — sin un campo de sub-clasificación, el feed las muestra pero no las hace distinguibles ni filtrables entre sí (ver D1, columna `subtipo`).

**Tamaños en prod (esquema `cs`):** `traslados` ~1.47M filas; `traslados_internos` (volumen menor, moderno). El esquema `cs` tiene default `latin1`; las columnas de texto nuevas se crean en `utf8mb4`.

## Goals / Non-Goals

**Goals:**
- Centralizar todas las observaciones en una tabla única con **atribución explícita de origen**.
- Cerrar los GAPS de visibilidad (control, traslado negativo, datos pool, anulación, estacionamiento) y, sobre todo, hacer **SATAPP atribuible**.
- Presentar un **feed unificado por traslado, filtrable por origen**, con ícono/color por fuente (paleta SAS), en el drawer simple y múltiple.
- Hacer la transición **sin big-bang**: backfill + dual-write con convivencia de ambas vistas, adopción incremental por módulo.
- No romper el contrato actual del drawer ni el orden de despliegue (backend desplegable antes que front).

**Non-Goals:**
- No se ejecuta la **consolidación final** (deprecar la lectura de columnas dispersas) en esta entrega: se diseña el criterio de corte, no se ejecuta.
- No se implementa la **Propuesta 3** (cartel "monto no informado por SATAPP") — es un change aparte.
- No se cambia el **modelo de montos** ni `persistirMontoViaje` (gap de km/espera/estacionamiento del lado escritura) — fuera de alcance, es decisión de negocio separada.
- No se eliminan ni renombran columnas de observación existentes.

## Decisions

### D1 — Tabla única `cs.traslados_observaciones` con FK lógica a dos tablas físicas

Como las observaciones provienen de **dos tablas físicas** (`traslados` y `traslados_internos`) que no comparten PK, la tabla unificada usa **dos columnas de identificación opcionales** (`id_traslado` BIGINT NULL, `id_traslado_interno` BIGINT NULL) en lugar de una FK dura única. Cada fila informa **exactamente una** de las dos (invariante de aplicación). Se descarta una tabla polimórfica con `tipo_traslado` + `id_entidad` porque oscurece las consultas del feed y los índices; dos columnas explícitas con índice por cada una son más legibles y baratas de consultar.

**DDL (separado del DML — ver D5):**

```sql
CREATE TABLE IF NOT EXISTS cs.traslados_observaciones (
  id                   BIGINT       NOT NULL AUTO_INCREMENT,
  id_traslado          BIGINT       NULL,
  id_traslado_interno  BIGINT       NULL,
  tramo                ENUM('IDA','VUELTA','GENERAL')                                   NOT NULL,
  origen               ENUM('TRAMITADOR','CEM','LOGISTICA','PEAJE',
                            'ESTACIONAMIENTO','SATAPP','AUDITORIA')                      NOT NULL,
  subtipo              VARCHAR(40)  NULL,
  texto                TEXT         NOT NULL,
  usuario_sistema      VARCHAR(120) NULL,
  fecha_hora           DATETIME     NOT NULL,
  PRIMARY KEY (id),
  KEY idx_to_id_traslado          (id_traslado),
  KEY idx_to_id_traslado_interno  (id_traslado_interno),
  CONSTRAINT chk_to_exactamente_un_id
    CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- `ENGINE=InnoDB` (transaccional, FK lógicas, consistente con el resto de `cs`).
- `utf8mb4_unicode_ci` para soportar acentos/emoji en texto libre sin pérdida.
- Índices por `(id_traslado)` y `(id_traslado_interno)` para que el feed por traslado sea una lookup directa.
- `texto TEXT NOT NULL` (las observaciones pueden ser largas; no se trunca).
- `subtipo VARCHAR(40) NULL`: **sub-clasificación dentro del `origen`**. El `origen` representa el **módulo** que escribe (TRAMITADOR, CEM, …); `subtipo` discrimina los distintos tipos de observación que **un mismo módulo** genera. Para `origen='TRAMITADOR'` los valores son `CONTROL`, `ANULACION`, `TRASLADO_NEGATIVO`, `DATOS_POOL`, `DESESTIMO`; `NULL` = observación común de gestión (las cajas `observaciones`/`observaciones_regreso`/`observaciones_traslado`). El feed puede **filtrar y agrupar por `subtipo`** dentro del módulo tramitador, lo que resuelve la atribución diferenciada que piden RF-9/CP-07 sin contaminar el ENUM `origen` (que se mantiene como "módulo"). Para los demás orígenes `subtipo` queda `NULL` por ahora (reservado para futuras sub-clasificaciones, p. ej. SATAPP peaje/espera/estacionamiento si el negocio lo pide).
- `usuario_sistema VARCHAR(120) NULL`: usuario humano que cargó la observación, o el literal `'SATAPP'` para las escrituras automáticas del callback de SATAPP (no se usa el literal `'EVENTO'` en esta entrega — ver nota al pie de D1).
- `fecha_hora DATETIME NOT NULL`: la del momento de la observación (en backfill, la mejor fecha disponible del traslado; ver D3).
- **Sin FK física** a `traslados`/`traslados_internos`: por el tamaño de `traslados` (~1.47M) y para no acoplar el ciclo de vida; la integridad la garantiza la aplicación (dual-write) y el backfill.
- **CHECK de exclusividad de ids — DECIDIDO: se incluye.** El `CONSTRAINT chk_to_exactamente_un_id CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` garantiza de forma determinista que cada fila tenga **exactamente uno** de los dos ids (resuelve CP-20 a nivel datos, no solo por aplicación). MariaDB 10.5.29 **evalúa** los CHECK (confirmado en Context), por lo que la garantía es real. **Fallback:** si `mariadb-migration-review` objeta el CHECK por costo en el `INSERT ... SELECT` masivo del backfill (~1.47M filas), se quita el constraint y CP-20 se valida con una **query de control post-backfill** (`SELECT COUNT(*) FROM cs.traslados_observaciones WHERE (id_traslado IS NULL) = (id_traslado_interno IS NULL)` debe dar 0). Ver D6 y Open Questions (cerrada).

> **Nota — `usuario_sistema='EVENTO'`:** se descarta el literal `'EVENTO'` para esta entrega. No existe en el alcance ningún módulo que escriba observaciones desde un EVENT/scheduler de la BD hacia esta tabla; las escrituras automáticas conocidas son las de SATAPP (`usuario_sistema='SATAPP'`). Si en el futuro un EVENT poblara la tabla, deberá definirse a qué `origen` corresponde antes de usar el literal. Por ahora se evita para no dejar un valor sin `origen` asociado (hallazgo de testabilidad #13).

### D2 — Dual-write por módulo, con `origen` real (convivencia, no big-bang)

Cada módulo que hoy escribe su columna **sigue escribiéndola** y **además** inserta una fila en `traslados_observaciones` con su `origen`. No se quita ninguna escritura existente. Esto permite:

- **Rollback trivial**: si el dual-write falla, la columna histórica sigue siendo la fuente y el feed simplemente muestra menos.
- **Adopción incremental**: cada repo (`wstraslados`, `wslogistica`, `wsauditoriatraslados`) puede adoptar el dual-write en su propio MR/branch sin coordinar un release único.

El caso **SATAPP** es el de mayor valor: en lugar de que `agregarObservaciones` concatene en la caja del tramitador con etiquetas, hace dual-write de una fila `origen='SATAPP'` (manteniendo, por convivencia, la concatenación actual hasta la consolidación). Así el feed atribuye SATAPP correctamente desde el primer día de dual-write, sin esperar el backfill ni la consolidación.

**Doble presentación de SATAPP en convivencia (mitigación):** como el feed ya muestra SATAPP atribuido **y** la caja histórica del tramitador sigue conteniendo el mismo fragmento SATAPP concatenado con etiquetas, el mismo texto podría verse dos veces durante la convivencia. Para evitarlo, durante la convivencia la **presentación histórica deja de resaltar/duplicar** la etiqueta SATAPP embebida: el front de-enfatiza (atenúa o colapsa) el fragmento `[Peaje:..][Estacionamiento:..][Espera:..]` dentro de la caja del tramitador, de modo que la fuente "rica" de SATAPP sea el feed y la caja no lo muestre por segunda vez como si fuera del tramitador. Ver Riesgos y CP-12 (la convivencia se valida contemplando que SATAPP no se cuente dos veces).

**Atomicidad (garantía real) — dual-write AISLADO en `REQUIRES_NEW`:**
- **Por qué NO "misma transacción":** se evaluó insertar en la misma transacción del módulo, pero tiene un riesgo grave (detectado en el dev-review de la implementación). Si el `INSERT` en `traslados_observaciones` falla a nivel DB (la tabla aún no existe durante el rollout, o un valor de ENUM/constraint no coincide), Hibernate marca la transacción como `rollback-only`. Aunque el `try/catch` del dual-write trague la excepción, al commit Spring lanza `UnexpectedRollbackException` y **se revierte la operación principal** (la escritura histórica incluida) — exactamente lo contrario del best-effort buscado, y un riesgo de romper operaciones de negocio (auditoría, cancelación, callback SATAPP) durante la ventana de migración.
- **Decisión:** el `INSERT` del feed corre **siempre en su propia transacción `REQUIRES_NEW`** (`TransactionTemplate`), con el `try/catch` **envolviendo** la ejecución de esa transacción nueva. Así un fallo del feed solo hace rollback de esa transacción aislada; la transacción del caller (la escritura histórica) **nunca queda envenenada** y commitea igual. Es best-effort **real**.
- **Trade-off aceptado:** se renuncia a la atomicidad estricta histórico↔feed (la fila del feed puede faltar transitoriamente si su `INSERT` falla, o quedar huérfana en el raro caso de que la operación principal se revierta *después* del insert del feed). Es deliberado: la columna histórica es la fuente de verdad y nunca debe bloquearse por el feed secundario.
- **Red de seguridad transversal:** el **backfill idempotente** (D3) reconcilia lo que falte — al re-ejecutarse, inserta las filas que el dual-write no llegó a crear (sin duplicar las que sí existen). Ninguna observación de la columna histórica queda permanentemente fuera del feed.

Esta es la garantía que cumple CP-13: la observación queda en la columna histórica (de forma garantizada) **y** en la tabla nueva (best-effort aislado, reconciliado por el backfill cuando su `INSERT` falla). Implementado así en wsauditoriatraslados !277, wslogistica !548 y wstraslados !279.

### D3 — Backfill idempotente, separado del DDL, con `origen` inferido por columna

Un script DML aparte (no en el mismo archivo que el `CREATE TABLE`, ver D5) recorre las columnas de observación de `traslados` y `traslados_internos` y genera una fila por cada texto no vacío, mapeando **columna → origen/subtipo/tramo**.

**Regla de asignación de `tramo`** (determinista, aplicada a toda la tabla de mapeo):
- La columna **trae el tramo en el nombre** (`_ida`/`_vuelta`/`_regreso`) → `IDA` o `VUELTA` según corresponda (`_regreso` ≡ `VUELTA`).
- La columna es **direccional por convención del módulo** aunque no lo lleve en el nombre (la caja principal `observaciones` es del tramo de ida; `observaciones_regreso` es vuelta) → `IDA` / `VUELTA`.
- La columna es **no direccional** (aplica al traslado completo, no a un tramo): control, traslado negativo, datos pool, desestimo, logística operativa → `GENERAL`.
- **Anulación:** se asigna por la dirección del **tramo anulado**: `observaciones_anulacion` → `IDA` (anulación del tramo de ida), `observaciones_anulacion_vuelta` → `VUELTA` (anulación del tramo de vuelta). Son columnas direccionales (existen separadas ida/vuelta), por eso **no** se mapean a `GENERAL`: el `tramo` indica qué pata del viaje se anuló, dato útil para el auditor.

**Tabla de mapeo — `cs.traslados` (16 columnas de texto del DESCRIBE):**

| Columna de origen (`cs.traslados`) | `origen` | `subtipo` | `tramo` |
|---|---|---|---|
| `observaciones` (vc500) | TRAMITADOR | NULL | IDA |
| `observaciones_regreso` (vc500) | TRAMITADOR | NULL | VUELTA |
| `observaciones_traslado` (vc5000) | TRAMITADOR | NULL | GENERAL · **caja grande con posible SATAPP embebido** (mismo tratamiento que `observaciones`, ver "SATAPP embebido") |
| `observaciones_control` (vc1000) | TRAMITADOR | CONTROL | GENERAL |
| `observacion_traslado_negativo` (vc1000) | TRAMITADOR | TRASLADO_NEGATIVO | GENERAL |
| `observacion_datos_pool` (vc2000) | TRAMITADOR | DATOS_POOL | GENERAL |
| `observaciones_desestimo` (vc300) | TRAMITADOR | DESESTIMO | GENERAL |
| `observaciones_anulacion` (vc500) | TRAMITADOR | ANULACION | IDA |
| `observaciones_anulacion_vuelta` (vc255) | TRAMITADOR | ANULACION | VUELTA |
| `observaciones_logistica` (vc500) | LOGISTICA | NULL | GENERAL |
| `observaciones_traslado_prioritario` (vc500) | LOGISTICA | NULL | GENERAL |
| `observaciones_habilita_espera` (vc500) | LOGISTICA | NULL | GENERAL |
| `observaciones_base_ida` (vc500) | LOGISTICA | NULL | IDA |
| `observaciones_base_vuelta` (vc500) | LOGISTICA | NULL | VUELTA |
| `observaciones_peaje_ida` (vc500) | PEAJE | NULL | IDA |
| `observaciones_peaje_vuelta` (vc500) | PEAJE | NULL | VUELTA |

**Tabla de mapeo — `cs.traslados_internos` (11 columnas de texto del DESCRIBE):**

| Columna de origen (`cs.traslados_internos`) | `origen` | `subtipo` | `tramo` |
|---|---|---|---|
| `observaciones_ida` (text) | CEM | NULL | IDA · **caja con posible SATAPP embebido** (ver "SATAPP embebido") |
| `observaciones_vuelta` (text) | CEM | NULL | VUELTA · **caja con posible SATAPP embebido** |
| `observaciones_logistica` (text) | LOGISTICA | NULL | GENERAL |
| `observaciones_traslado_prioritario` (vc500) | LOGISTICA | NULL | GENERAL |
| `observaciones_habilita_espera` (vc500) | LOGISTICA | NULL | GENERAL |
| `observaciones_base_ida` (vc500) | LOGISTICA | NULL | IDA |
| `observaciones_base_vuelta` (vc500) | LOGISTICA | NULL | VUELTA |
| `observaciones_peaje_ida` (vc500) | PEAJE | NULL | IDA |
| `observaciones_peaje_vuelta` (vc500) | PEAJE | NULL | VUELTA |
| `observaciones_anulacion` (vc255) | TRAMITADOR | ANULACION | IDA |
| `observaciones_anulacion_vuelta` (vc255) | TRAMITADOR | ANULACION | VUELTA |

**Columnas excluidas del backfill (justificación):**
- **`origen='ESTACIONAMIENTO'`** y **`origen='AUDITORIA'`**: no tienen columna estructurada en `traslados`/`traslados_internos`. Estacionamiento está hoy embebido en texto libre (entra al feed por dual-write a futuro, ver D7 y #4); auditoría vive en `observacionAuditoria` de `wsauditoriatraslados` (otra entidad) y se incorpora por dual-write del propio servicio de auditoría, no por este backfill.
- Ninguna otra columna de texto de las dos tablas queda sin mapear: las 16 de `traslados` y las 11 de `traslados_internos` (27 en total, lista cerrada por el `DESCRIBE` del 18/06/2026 — ver Open Questions) están todas asignadas o excluidas con justificación arriba.

- **Idempotencia:** se necesita una clave que evite duplicar al re-ejecutar. Como la tabla no tiene una clave natural de la observación, el backfill usa una estrategia segura y re-ejecutable: o bien (a) `INSERT ... SELECT ... WHERE NOT EXISTS (fila equivalente por id_traslado/origen/subtipo/tramo/texto)`, o bien (b) un script que primero borra solo las filas de backfill marcables y reinserta. Se prefiere **(a)** por no destruir nada (validar con `mariadb-migration-review`). El mismo `WHERE NOT EXISTS` hace que el backfill sirva de **red de reconciliación** del dual-write best-effort (D2): inserta lo que falte sin tocar lo ya presente.
- **`fecha_hora` en backfill:** se usa la mejor fecha disponible del traslado (fecha de creación/última modificación del registro); si no hay una columna fiable, `NOW()` de la corrida del backfill, documentándolo. Es un dato histórico aproximado, aceptable para el feed. Para el desempate del orden cronológico ver D4 (`ORDER BY fecha_hora, id`).
- **SATAPP embebido:** las cajas grandes `traslados.observaciones` / `observaciones_regreso` / `observaciones_traslado` y `traslados_internos.observaciones_ida` / `observaciones_vuelta` pueden traer texto del tramitador/CEM **y** de SATAPP concatenado por `agregarObservaciones` con etiquetas. El backfill intenta separar el fragmento de SATAPP por sus marcadores (`[Peaje:..]`, `[Estacionamiento:..]`, `[Espera:..]`); si la separación es inequívoca, crea dos filas (TRAMITADOR/CEM + SATAPP); si es ambigua, conserva todo como TRAMITADOR/CEM y lo marca para revisión (**no se pierde texto**). El dual-write nuevo de SATAPP (D2) ya nace limpio, así que el problema embebido es solo histórico.
- **Estacionamiento histórico:** hoy está embebido en texto libre (no estructurado); el backfill **no** crea filas `origen='ESTACIONAMIENTO'` — el valor existe en el ENUM pero su fuente estructurada no existe todavía. Se atiende por **dual-write a futuro** (follow-up), cuando logística estructure la observación de estacionamiento (ver D7 y la conciliación de alcance con el PRD, RF-9/CP-07).

### D4 — Feed unificado en el front, prop-driven y reusable (paleta SAS)

El drawer (`FormAuditar.tsx` simple, `AuditarTabla.tsx` múltiple) suma un bloque "Observaciones del traslado" que renderiza el feed leído de `traslados_observaciones`:

- **Componente — DECIDIDO: custom prop-driven y SOLID.** Se relevó `sas-component-lib` y no expone hoy un componente de timeline/feed con atribución por origen + filtro que cubra este caso (sus componentes de lista no contemplan ícono/color por fuente ni el filtro por chips de origen). Por lo tanto se crea un componente **custom prop-driven y SOLID** (recibe la lista de observaciones y la config de orígenes/subtipos; no conoce el dominio de auditoría — transportable y reusable por otras pantallas). Se reusa el patrón del banner prop-driven del evolutivo de concurrencia (`AvisoConcurrencia`). Si durante la implementación aparece en `sas-component-lib` un timeline apto, se prioriza reusarlo (la decisión de "custom" es el piso, no un impedimento al reuso si surge la alternativa). Esto cierra el alcance del front para dimensionar el Paso 4 del plan de migración.
- **Atribución visual por origen**, con **paleta SAS**:
  - teal primario `#0ddcd6` / teal oscuro `#0A8F8B`
  - grises `#3C4043` / `#5F6368` / `#9AA0A6`
  - fondo `#F4F5F6`, línea `#DADCE0`
  - cada `origen` mapea a un ícono + color de la paleta (p. ej. SATAPP en teal `#0ddcd6`, auditoría en gris `#3C4043`, etc.; la asignación exacta se define con UX dentro de la paleta).
- **Filtro por origen** (y por `subtipo` dentro de TRAMITADOR): chips/checkboxes que muestran/ocultan orígenes/subtipos en el feed sin recargar.
- **Orden cronológico** por `fecha_hora` con **desempate estable `ORDER BY fecha_hora, id`**: como en el backfill muchas filas comparten la misma `fecha_hora` aproximada (D3), el `id` (auto-incremental, monótono) define un orden determinista y reproducible entre empates. Agrupable por tramo (ida/vuelta/general). Esto hace que el orden del feed sea objetivamente verificable (CP-11).
- **Modo de transición**: el bloque del feed convive con la presentación histórica (cajas actuales) — ver D7. Durante la convivencia la caja histórica del tramitador **de-enfatiza** la etiqueta SATAPP embebida para no mostrar SATAPP dos veces (ver D2 y CP-12).

### D5 — DDL y DML en scripts separados (MariaDB no hace DDL transaccional)

MariaDB no soporta DDL transaccional: un `CREATE TABLE` no se puede revertir dentro de una transacción y mezclarlo con DML rompe el rollback. Por eso:

- **Script 1 (DDL):** solo el `CREATE TABLE IF NOT EXISTS cs.traslados_observaciones`. Idempotente (`IF NOT EXISTS`).
- **Script 2 (DML):** solo el **backfill** (`INSERT ... SELECT ... WHERE NOT EXISTS`). Idempotente/re-ejecutable, dentro de transacción.
- Ambos pasan por **`mariadb-migration-review`** antes de aplicarse.
- Orden de aplicación: DDL → (deploy backend con dual-write) → DML backfill. El backfill se corre **después** de habilitar el dual-write para no perder observaciones nuevas creadas durante la ventana de migración (las nuevas ya entran por dual-write; el backfill solo trae lo histórico).

### D6 — Charset, collation e integridad

- Tabla en `utf8mb4` / `utf8mb4_unicode_ci`: las observaciones son texto libre del usuario; `unicode_ci` ordena/compara mejor el español que `general_ci` y soporta caracteres extendidos. (El feed no hace búsqueda acento-insensible como el buscador general; solo lista y filtra por origen.)
- **Invariante "exactamente uno de los dos ids" — DECIDIDO: con CHECK.** Además de la garantía por aplicación (dual-write) y backfill, se incluye el `CONSTRAINT chk_to_exactamente_un_id CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` en el DDL (D1). **MariaDB 10.5.29 evalúa CHECK** (confirmado en Context vía `SELECT VERSION()`), por lo que la invariante queda garantizada de forma determinista a nivel datos y CP-20 es verificable directamente sobre la BD. **Fallback** (si `mariadb-migration-review` lo objeta por costo de evaluación en el `INSERT ... SELECT` de ~1.47M filas): quitar el CHECK y validar CP-20 con una query de control post-backfill (`SELECT COUNT(*) ... WHERE (id_traslado IS NULL) = (id_traslado_interno IS NULL)` = 0). Decisión por defecto: **incluirlo**; el costo de evaluación de un CHECK booleano simple por fila es marginal frente a la garantía. (Open Question del CHECK: **cerrada**.)
- Sin FK física (D1): el tamaño de `traslados` y la independencia de ciclo de vida lo desaconsejan; los índices por id cubren la lectura del feed.

### D7 — Convivencia de vistas y criterio de consolidación (fuera de esta entrega)

Durante la transición el drawer muestra **ambas** presentaciones (cajas históricas + feed), para que el auditor valide que el feed no pierde nada. La **consolidación final** (deprecar la lectura de columnas dispersas y dejar el feed como fuente única) se ejecuta **en una entrega posterior**, cuando se cumplan los criterios de corte:

1. Todos los módulos relevantes hacen dual-write (tramitador, CEM, logística, peaje, estacionamiento, SATAPP, auditoría).
2. El backfill cubrió el histórico y se resolvió el universo "marcado para revisión" de SATAPP embebido.
3. Se validó en STAGE que el feed iguala o supera lo que muestran las cajas históricas.

Recién entonces se quita la presentación histórica del drawer (y, opcionalmente, se planifica dejar de escribir columnas duplicadas — decisión por módulo, fuera de alcance acá).

## Risks / Trade-offs

- **Divergencia entre columna histórica y tabla nueva (dual-write)** → si el insert del feed falla y la columna no, el feed muestra menos que la caja. **Mitigación:** el insert del feed corre en transacción propia `REQUIRES_NEW` aislada (D2) — su fallo nunca tumba la escritura histórica; el error se loguea y el **backfill idempotente reconcilia** lo que falte; además la presentación histórica sigue visible durante la convivencia (D7), así que la información nunca baja del estado actual.
- **Doble visualización de SATAPP en convivencia** → con el dual-write SATAPP aparece atribuido en el feed y, en paralelo, el mismo fragmento sigue concatenado en la caja histórica del tramitador → el auditor podría verlo dos veces y confundirse al validar (CP-12). **Mitigación:** durante la convivencia la caja histórica **de-enfatiza / no resalta** la etiqueta SATAPP embebida (la fuente rica de SATAPP es el feed); la concatenación no se elimina (no se toca la escritura histórica), solo se atenúa en la presentación. Contemplado en D2, D4 y CP-12.
- **SATAPP embebido ambiguo en el backfill** → texto donde no se puede separar tramitador de SATAPP. **Mitigación:** conservar como TRAMITADOR y marcar para revisión; el dual-write nuevo de SATAPP ya nace limpio (D3).
- **`fecha_hora` aproximada en el histórico** → el backfill no tiene la fecha exacta de cada observación vieja. **Mitigación:** usar la mejor fecha del traslado y documentar que las filas de backfill tienen fecha aproximada; las nuevas (dual-write) sí son exactas.
- **Volumen del backfill sobre `traslados` (~1.47M)** → el `INSERT ... SELECT` puede ser largo y tomar locks. **Mitigación:** correr en ventana de bajo tráfico, por lotes si hace falta, idempotente para reanudar; revisado con `mariadb-migration-review`.
- **Duplicación temporal de la escritura (dual-write)** → cada observación se escribe dos veces durante la transición. **Mitigación:** es deliberado y acotado en el tiempo (hasta la consolidación, D7); el costo es marginal frente al valor de trazabilidad.
- **Sin FK física** → posibilidad de filas huérfanas si un traslado se borra. **Mitigación:** en `cs` los traslados rara vez se borran físicamente; el feed filtra por id existente; se puede agregar limpieza posterior si aparece el caso.
- **Mapeo origen↔columna incompleto** → si una columna de observación quedó sin mapear, no entra al feed. **Mitigación:** la tabla de mapeo (D3) está **cerrada** con el `DESCRIBE` de `traslados`/`traslados_internos` en réplica (18/06/2026): las 27 columnas de texto (16 + 11) están todas asignadas a `origen`/`subtipo`/`tramo` o excluidas con justificación. Estacionamiento y auditoría se documentan como excluidas del backfill (entran por dual-write, no por backfill).

## Migration Plan

- **Paso 1 — DDL (esta entrega):** aplicar Script 1 (`CREATE TABLE IF NOT EXISTS cs.traslados_observaciones`), revisado con `mariadb-migration-review`. Idempotente, sin impacto en datos.
- **Paso 2 — Dual-write (esta entrega):** MRs por repo (`wstraslados`, `wslogistica`, `wsauditoriatraslados`) en branches `feature/centralizar-observaciones-auditoria-traslados`, cada módulo escribiendo su columna actual **y** la tabla nueva con su `origen`. Adopción incremental.
- **Paso 3 — Backfill (esta entrega):** aplicar Script 2 (backfill idempotente) **después** de habilitar el dual-write, en ventana de bajo tráfico. Re-ejecutable si se interrumpe.
- **Paso 4 — Feed en el front (esta entrega):** componente de feed + filtro por origen en el drawer (simple y múltiple), modo "ambas vistas" (convivencia).
- **Rollback:** desactivar el feed en el front (la pantalla vuelve a las cajas históricas); el dual-write puede revertirse por MR sin tocar datos; la tabla y el backfill pueden quedarse (no se leen si el feed está apagado) o dropearse. Como nada deja de escribir su columna histórica, el rollback es limpio.
- **Consolidación (posterior, fuera de esta entrega):** cumplidos los criterios de D7, quitar la presentación histórica del drawer y planificar el cese de escritura duplicada por módulo.

## Matriz de trazabilidad (RF / CP del PRD → Decisiones del SDD)

> Vincula cada requisito funcional (RF-1…RF-11) y caso de aceptación (CP-01…CP-20) del PRD con la(s) decisión(es) de diseño que lo cubren. Sirve de checklist de cobertura para el cierre del diseño.

| Requisito / CP | Decisión(es) | Nota |
|---|---|---|
| RF-1 Registro atribuido | D1, D2 | Tabla `traslados_observaciones` con `origen`/`subtipo`/`tramo`; dual-write con `origen` real |
| RF-2 SATAPP atribuible | D2, D3 | Dual-write `origen='SATAPP'` (nace limpio) + separación del embebido histórico en el backfill |
| RF-3 Backfill del histórico | D3 | Mapeo columna→origen/subtipo/tramo de las 27 columnas |
| RF-4 Backfill idempotente | D3, D5 | `INSERT ... SELECT ... WHERE NOT EXISTS`; DML separado del DDL |
| RF-5 Dual-write | D2 | Cada módulo escribe su columna **y** la tabla nueva |
| RF-6 Adopción incremental | D2 | Por repo/MR, sin release coordinado |
| RF-7 Feed unificado | D4 | Componente custom prop-driven; orden `fecha_hora, id` |
| RF-8 Filtro por origen | D4 | Chips por `origen` y por `subtipo` dentro de TRAMITADOR |
| RF-9 Fuentes antes ocultas | D1 (`subtipo`), D3, D7 | Control/negativo/datos pool/anulación/desestimo entran por backfill con `subtipo`; **estacionamiento = follow-up** (dual-write futuro, no esta fase) |
| RF-10 Convivencia de vistas | D2, D7 | Ambas presentaciones; SATAPP de-enfatizado en la caja histórica |
| RF-11 Contrato intacto | D2, D5, D7 | Datos nuevos y opcionales; backend desplegable antes que front |
| CP-01 Tramitador | D1, D2, D3 | `origen=TRAMITADOR`, `subtipo=NULL` |
| CP-02 CEM | D1, D2, D3 | `origen=CEM` |
| CP-03 Logística | D1, D2, D3 | `origen=LOGISTICA` |
| CP-04 Peaje | D1, D2, D3 | `origen=PEAJE` |
| CP-05 SATAPP separado | D2, D3 | `origen=SATAPP` distinguible del tramitador |
| CP-06 Auditoría | D1, D2 | `origen=AUDITORIA` (dual-write del propio `wsauditoriatraslados`) |
| CP-07 Control / negativo / datos pool | D1 (`subtipo`), D3 | Aparecen y son **distinguibles** por `subtipo` (CONTROL/TRASLADO_NEGATIVO/DATOS_POOL/DESESTIMO) |
| CP-08 Anulación | D1 (`subtipo=ANULACION`), D3 | `tramo` IDA/VUELTA según pata anulada |
| CP-09 Filtro por un origen | D4 | |
| CP-10 Filtro por varios orígenes | D4 | |
| CP-11 Sin filtro / orden cronológico | D4 | Desempate estable `fecha_hora, id` |
| CP-12 Convivencia feed vs cajas | D2, D7 | SATAPP no se cuenta dos veces (de-énfasis del embebido) |
| CP-13 Dual-write nuevo | D2 | Insert del feed en tx propia `REQUIRES_NEW` (best-effort aislado) + log + reconciliación por backfill |
| CP-14 Backfill migrado | D3 | |
| CP-15 Backfill idempotente | D3 | |
| CP-16 SATAPP embebido inequívoco | D3 | Dos filas TRAMITADOR + SATAPP |
| CP-17 SATAPP embebido ambiguo | D3 | Una fila TRAMITADOR marcada para revisión |
| CP-18 Contrato intacto | D5, D7 | |
| CP-19 Rollback del front | D4, D7, Migration Plan | |
| CP-20 Invariante de id | D1, D6 | `CHECK` incluido (fallback: query de control) |

> **Cobertura de estacionamiento (hallazgo #4):** RF-9 y CP-07/CP-08 quedan cubiertos para control, traslado negativo, datos pool, anulación y desestimo en esta fase; **estacionamiento queda marcado como follow-up** dependiente de la fuente estructurada (D7), no entregable en esta entrega. El PRD lo refleja en RF-9 y en la nota de CP-07.

## Open Questions

- **Lista definitiva de columnas de observación — ✅ RESUELTO** (`DESCRIBE` en réplica, 18/06/2026). Columnas de texto a recorrer en el backfill:
  - **`cs.traslados`:** `observaciones`(vc500), `observaciones_regreso`(500), `observaciones_control`(1000), `observaciones_traslado`(5000), `observaciones_traslado_prioritario`(500), `observaciones_logistica`(500), `observaciones_base_ida`(500), `observaciones_base_vuelta`(500), `observaciones_peaje_ida`(500), `observaciones_peaje_vuelta`(500), `observaciones_habilita_espera`(500), `observaciones_anulacion`(500), `observaciones_anulacion_vuelta`(255), `observaciones_desestimo`(300), `observacion_datos_pool`(2000), `observacion_traslado_negativo`(1000).
  - **`cs.traslados_internos`:** `observaciones_ida`(text), `observaciones_vuelta`(text), `observaciones_logistica`(text), `observaciones_base_ida`(500), `observaciones_base_vuelta`(500), `observaciones_peaje_ida`(500), `observaciones_peaje_vuelta`(500), `observaciones_habilita_espera`(500), `observaciones_traslado_prioritario`(500), `observaciones_anulacion`(255), `observaciones_anulacion_vuelta`(255).
  - **Nota:** las cajas grandes `traslados.observaciones`/`observaciones_regreso`/`observaciones_traslado` y `traslados_internos.observaciones_ida`/`observaciones_vuelta` son donde hoy SATAPP concatena (vía `agregarObservaciones`) → en el backfill se mapean como TRAMITADOR/CEM y el texto SATAPP embebido se separa cuando es inequívoco o se marca para revisión (D3). `observaciones_desestimo` y `observacion_datos_pool`/`observacion_traslado_negativo`/`observaciones_control` se mapean a TRAMITADOR con su `subtipo` (DESESTIMO/DATOS_POOL/TRASLADO_NEGATIVO/CONTROL). Ninguna de las dos tablas tiene columna estructurada de estacionamiento (histórico embebido en texto libre → ver decisión de estacionamiento más abajo).
- **`fecha_hora` del backfill:** ¿existe una columna de fecha por observación o por tramo que permita una fecha histórica más precisa que la fecha del traslado? Si no, se asume la del traslado / corrida del backfill. El orden del feed usa desempate estable `fecha_hora, id` (D4), por lo que el orden es determinista aun con fechas repetidas.
- **Separación de SATAPP embebido:** ¿el negocio prefiere intentar la separación automática por etiquetas en el backfill (riesgo de error de parseo) o conservar el histórico como TRAMITADOR y confiar el atribuible solo al dual-write nuevo? Por defecto se separa solo cuando es inequívoco.
- **Asignación final de ícono/color por origen** dentro de la paleta SAS: a definir con UX (la paleta está fijada; el mapeo exacto no).
- **CHECK de exclusividad de ids — ✅ RESUELTO (18/06/2026):** se **incluye** el `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` (D1/D6). MariaDB 10.5.29 lo evalúa. Fallback documentado (query de control post-backfill) si `mariadb-migration-review` lo objeta por costo en el backfill masivo.
- **Componente de feed — ✅ RESUELTO (18/06/2026):** componente **custom prop-driven y SOLID** (D4); `sas-component-lib` no tiene hoy un timeline con atribución por origen + filtro. Se reusa si aparece uno apto durante la implementación.
- **Estacionamiento — ✅ RESUELTO (18/06/2026):** el valor `origen='ESTACIONAMIENTO'` se **mantiene en el ENUM**, pero **no** tiene fuente estructurada hoy (embebido en texto libre). En esta entrega **no** entra por backfill ni se estructura el dual-write; queda como **follow-up**: entrará al feed por dual-write cuando logística estructure la observación de estacionamiento (relacionado con la decisión de negocio de persistir estacionamiento/km/espera de SATAPP, fuera de alcance de este change). El PRD (RF-9/CP-07) se ajustó para marcar estacionamiento como **dependiente de la fuente estructurada (follow-up)**, no entregable en esta fase.

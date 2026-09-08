## ADDED Requirements

### Requirement: Registro unificado y atribuido de observaciones del traslado

El sistema SHALL almacenar cada observación de un traslado como una fila atómica en la tabla `cs.traslados_observaciones`, con su **origen** (módulo) explícito (`TRAMITADOR`, `CEM`, `LOGISTICA`, `PEAJE`, `ESTACIONAMIENTO`, `SATAPP`, `AUDITORIA`), un **subtipo** opcional (`VARCHAR(40)` NULL) que sub-clasifica la observación dentro del módulo, su **tramo** (`IDA`, `VUELTA`, `GENERAL`), el **texto**, el **usuario o sistema** que la cargó y la **fecha/hora**. Para `origen='TRAMITADOR'` el `subtipo` SHALL distinguir las observaciones de gestión común (`NULL`) de las de control (`CONTROL`), anulación (`ANULACION`), traslado negativo (`TRASLADO_NEGATIVO`), datos pool (`DATOS_POOL`) y desestimo (`DESESTIMO`). El sistema SHALL referenciar el traslado mediante `id_traslado` cuando proviene de `cs.traslados` o `id_traslado_interno` cuando proviene de `cs.traslados_internos`, y cada fila SHALL tener exactamente uno de los dos identificadores informado, garantizado por una restricción `CHECK` a nivel de tabla.

#### Scenario: Una observación queda registrada con su origen
- **WHEN** un módulo (tramitador, CEM, logística, peaje, SATAPP o auditoría) registra una observación sobre un traslado
- **THEN** se inserta una fila en `traslados_observaciones` con el `origen` correspondiente a ese módulo, el `subtipo` cuando aplica, el `tramo`, el `texto`, el `usuario_sistema` y la `fecha_hora`

#### Scenario: Las observaciones del tramitador son distinguibles por subtipo
- **WHEN** el tramitador registra una observación de control, anulación, traslado negativo, datos pool o desestimo
- **THEN** la fila queda con `origen='TRAMITADOR'` y el `subtipo` correspondiente (`CONTROL`, `ANULACION`, `TRASLADO_NEGATIVO`, `DATOS_POOL` o `DESESTIMO`), de modo que el feed pueda filtrarlas y agruparlas por separado dentro del módulo tramitador

#### Scenario: La invariante de un solo identificador se garantiza a nivel datos
- **WHEN** se intenta insertar una fila con ambos identificadores informados o con ambos nulos
- **THEN** la restricción `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` la rechaza (MariaDB 10.5 evalúa CHECK); si la restricción se descarta por costo en el backfill masivo, una query de control post-backfill SHALL verificar que no existan filas inválidas

#### Scenario: La fila apunta al traslado correcto según la tabla de origen
- **WHEN** la observación corresponde a un traslado de `cs.traslados`
- **THEN** la fila tiene `id_traslado` informado e `id_traslado_interno` nulo; y a la inversa para un traslado de `cs.traslados_internos`

#### Scenario: SATAPP deja de ser inatribuible
- **WHEN** SATAPP informa una observación de viaje (peaje, estacionamiento o espera) sobre un traslado
- **THEN** queda registrada con `origen = 'SATAPP'` y es distinguible del texto del tramitador, sin depender de etiquetas embebidas en texto libre

### Requirement: Backfill inicial idempotente desde las columnas actuales

El sistema SHALL poblar `traslados_observaciones` a partir de las columnas de observación existentes de `cs.traslados` y `cs.traslados_internos`, infiriendo el `origen` por la columna de procedencia. El backfill SHALL ser idempotente y re-ejecutable: una segunda ejecución NO SHALL duplicar las filas ya migradas.

#### Scenario: Las observaciones existentes quedan migradas con su origen inferido
- **WHEN** se ejecuta el backfill sobre traslados con observaciones en sus columnas actuales (en `cs.traslados`: `observaciones`, `observaciones_regreso`, `observaciones_traslado`, `observaciones_control`, `observacion_traslado_negativo`, `observacion_datos_pool`, `observaciones_desestimo`, `observaciones_anulacion`, `observaciones_anulacion_vuelta`, `observaciones_logistica`, `observaciones_traslado_prioritario`, `observaciones_habilita_espera`, `observaciones_base_ida/_vuelta`, `observaciones_peaje_ida/_vuelta`; y las equivalentes de `cs.traslados_internos`: `observaciones_ida/_vuelta`, `observaciones_logistica`, `observaciones_traslado_prioritario`, `observaciones_habilita_espera`, `observaciones_base_ida/_vuelta`, `observaciones_peaje_ida/_vuelta`, `observaciones_anulacion/_vuelta`)
- **THEN** cada texto no vacío genera una fila en `traslados_observaciones` con el `origen`, el `subtipo` (cuando aplica al tramitador) y el `tramo` que corresponden a esa columna, según el mapeo de las 27 columnas del SDD (D3)

#### Scenario: El backfill no duplica al re-ejecutarse
- **WHEN** el script de backfill se ejecuta por segunda vez
- **THEN** no se crean filas duplicadas para observaciones ya migradas (la operación es idempotente)

#### Scenario: La observación de SATAPP embebida se separa en el backfill
- **WHEN** una columna de observación contiene texto del tramitador concatenado con texto de SATAPP marcado por etiquetas (`[Peaje:..]`, `[Estacionamiento:..]`, `[Espera:..]`)
- **THEN** el backfill registra el texto del tramitador con `origen = 'TRAMITADOR'` y, cuando puede separar el fragmento de SATAPP de forma inequívoca, lo registra con `origen = 'SATAPP'`; si no puede separarlo sin ambigüedad, lo conserva como `TRAMITADOR` y lo marca para revisión manual (no se pierde texto)

### Requirement: Dual-write durante la convivencia

Mientras dure la transición, cada módulo que hoy escribe su columna de observación SHALL seguir escribiendo esa columna **y además** SHALL insertar la fila equivalente en `traslados_observaciones` con su `origen`. Ningún módulo SHALL dejar de escribir su columna actual durante la convivencia. El sistema NO SHALL exigir que todos los módulos migren a la vez (la adopción puede ser incremental por módulo).

#### Scenario: Cada escritura va a la columna vieja y a la tabla nueva
- **WHEN** un módulo registra una observación nueva durante la transición
- **THEN** la observación queda en su columna histórica (forma vieja) y en `traslados_observaciones` (forma nueva), con el mismo texto y el `origen` del módulo; el insert en la tabla nueva corre en una **transacción propia `REQUIRES_NEW` (aislada)**, de modo que un fallo del feed no pueda revertir la escritura histórica

#### Scenario: El insert de la tabla nueva es best-effort aislado y se reconcilia
- **WHEN** el insert en `traslados_observaciones` falla (p. ej. la tabla todavía no existe durante el rollout, o un valor de ENUM/constraint no coincide)
- **THEN** como el insert corre en su propia transacción `REQUIRES_NEW`, su fallo NO marca `rollback-only` la transacción del módulo: la operación principal NO se bloquea (la columna histórica es el respaldo), el error se loguea, y el **backfill idempotente** reconcilia la fila faltante en una corrida posterior (sin duplicar las existentes)

#### Scenario: Adopción incremental sin romper a los módulos no migrados
- **WHEN** algunos módulos ya hacen dual-write y otros todavía no
- **THEN** los traslados siguen funcionando: las columnas históricas se siguen leyendo y el feed muestra lo que ya esté en la tabla nueva, sin requerir que todos los módulos migren simultáneamente

### Requirement: Feed unificado de observaciones en el drawer de auditoría

El sistema SHALL mostrar en el drawer de auditoría un **feed unificado** de las observaciones del traslado, leído desde `traslados_observaciones`, ordenado cronológicamente (con desempate estable por `fecha_hora` y luego `id`) y con la **fuente identificable** (ícono y color por origen, según la paleta SAS). El feed SHALL ser **filtrable por origen** (y por `subtipo` dentro de tramitador), e incluir las fuentes que hoy el drawer no muestra (control, traslado negativo, datos pool, anulación, desestimo) además de las que ya muestra. El origen `ESTACIONAMIENTO` queda reservado en el modelo pero su carga es un follow-up (no entregable en esta fase, ver más abajo).

#### Scenario: El auditor ve el origen de cada observación
- **WHEN** el auditor abre el drawer de un traslado con observaciones de varios módulos
- **THEN** ve cada observación con su fuente identificada por ícono/color (tramitador, CEM, logística, peaje, SATAPP, auditoría) y su tramo (ida/vuelta/general)

#### Scenario: El auditor filtra el feed por origen
- **WHEN** el auditor selecciona uno o más orígenes en el filtro del feed (p. ej. solo SATAPP), o un subtipo del tramitador
- **THEN** el feed muestra únicamente las observaciones de esos orígenes/subtipos y oculta el resto, sin recargar la pantalla

#### Scenario: El feed ordena de forma determinista aun con fechas repetidas
- **WHEN** varias observaciones comparten la misma `fecha_hora` (típico de las filas del backfill con fecha aproximada)
- **THEN** el feed las ordena de forma estable por `fecha_hora` y luego por `id`, produciendo un orden reproducible

#### Scenario: Aparecen las fuentes antes no visibles, distinguibles entre sí
- **WHEN** un traslado tiene observación de control, traslado negativo, datos pool, anulación o desestimo
- **THEN** esas observaciones aparecen en el feed atribuidas a `origen='TRAMITADOR'` con su `subtipo` (antes no se mostraban en el drawer) y el auditor puede distinguirlas y filtrarlas por separado

#### Scenario: Estacionamiento es un follow-up dependiente de la fuente estructurada
- **WHEN** se entrega esta fase del feed
- **THEN** las observaciones de estacionamiento NO se cargan todavía (hoy están embebidas en texto libre, sin columna estructurada); el valor `origen='ESTACIONAMIENTO'` queda reservado y se poblará por dual-write cuando logística estructure esa observación

### Requirement: Vista de transición con ambas presentaciones

Durante la convivencia el sistema SHALL poder mostrar en el drawer **tanto** la presentación histórica (cajas/columnas actuales) **como** el feed unificado, de modo que el auditor pueda comparar y validar sin perder lo que ya veía. El sistema NO SHALL eliminar la presentación histórica antes de la consolidación final.

#### Scenario: El auditor compara la vista vieja y la nueva
- **WHEN** la convivencia está activa y el auditor abre el drawer
- **THEN** puede ver el feed unificado y, además, la presentación histórica de observaciones (las cajas actuales) para contrastar que no falta nada

#### Scenario: SATAPP no se muestra duplicado durante la convivencia
- **WHEN** una observación de SATAPP aparece atribuida en el feed y su fragmento sigue concatenado con etiquetas en la caja histórica del tramitador/CEM
- **THEN** la presentación histórica **de-enfatiza** (atenúa o no resalta) la etiqueta SATAPP embebida, de modo que el mismo texto de SATAPP no se muestre dos veces; la concatenación histórica no se elimina (no se toca la escritura), solo se atenúa en la presentación

#### Scenario: No se pierde información durante la transición
- **WHEN** una observación todavía no fue migrada/escrita en la tabla nueva por un módulo no adaptado
- **THEN** el auditor la sigue viendo en la presentación histórica del drawer, de modo que la información visible nunca es menor a la actual

### Requirement: Lectura del feed sin romper el contrato actual del drawer

El sistema SHALL exponer las observaciones unificadas de un traslado como datos **nuevos y opcionales** (recurso o campos adicionales) que el drawer consume para el feed, sin alterar ni quitar los campos que el drawer de auditoría ya recibe hoy. El despliegue de la tabla, el backfill y el dual-write SHALL ser posible **antes** que el front del feed sin romper el comportamiento existente.

#### Scenario: El contrato existente del drawer no cambia
- **WHEN** se libera la lectura del feed unificado
- **THEN** los campos actuales del drawer (`observaciones`, `detalle`, `detalleLogistica`, `observacionAuditoria`, estado de logística) siguen presentes con su forma actual

#### Scenario: Backend desplegable antes que el front
- **WHEN** se despliegan la tabla, el backfill y el dual-write sin el front del feed
- **THEN** la pantalla de auditoría sigue funcionando igual que antes, sin errores por datos nuevos no consumidos

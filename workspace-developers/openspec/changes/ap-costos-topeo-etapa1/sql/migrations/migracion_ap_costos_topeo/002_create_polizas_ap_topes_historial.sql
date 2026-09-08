-- -----------------------------------------------------------------------------
-- V33 — CREATE TABLE `cs`.`polizas_ap_topes_historial`
-- -----------------------------------------------------------------------------
-- Repo destino: wsmesacarga (src/main/resources/sql/)
-- Autor: Vanesa Burman — Fecha: 2026-07-30 — Ticket: PENDIENTE (ap-costos-topeo-etapa1)
--              El ticket de Jira todavía NO existe. Mientras no exista, la referencia
--              trazable es el change OpenSpec `ap-costos-topeo-etapa1` (AP Costos y Topeo,
--              etapa 1). Al crearlo, reemplazar este placeholder por el GRV-NNNN acá y en
--              V32/V34.
-- Depende de: V32__CREATE_polizas_ap_topes.sql (correr V32 primero)
--
-- POR QUÉ EXISTE ESTA TABLA
-- El tope de AP se puede AMPLIAR, y la ampliación no es un dato técnico: es una decisión
-- comercial que el cliente autoriza. Si la ampliación se hiciera con un UPDATE sobre
-- `polizas_ap_topes` y nada más, el monto anterior desaparece y con él la pregunta que
-- siempre se termina haciendo tres meses después: "¿quién amplió este tope, cuándo y con
-- qué autorización?". Esta tabla contesta eso.
-- Por eso el `motivo` es NOT NULL: la regla de negocio es que toda modificación del tope
-- exige motivo, y la base lo exige también —no queda a criterio de quien programe la
-- pantalla—.
--
-- QUÉ SE VERSIONA: LOS TRES ATRIBUTOS QUE CAMBIAN EL SIGNIFICADO DEL TOPE
-- El monto no es lo único que define cuánto cubre la póliza. Pasar la `ventana` de ANUAL a
-- EVENTO altera el tope tanto como cambiar el importe —el mismo número deja de ser el techo
-- del año y pasa a ser el techo de cada siniestro, o al revés—, y lo mismo vale para
-- `iva_incluido`: apagar el flag mueve el denominador del semáforo un 21 por ciento sin que
-- se haya tocado un peso. Si el historial versionara sólo la suma, esos dos cambios
-- redefinirían la cobertura sin dejar rastro y la pregunta "¿por qué este caso pasó a
-- Excedido si nadie tocó el monto?" no tendría respuesta en ninguna tabla.
-- Por eso se versionan los tres: suma, ventana e IVA.
--
-- ADEMÁS: es la que permite que `polizas_ap_topes` tenga UNA sola fila por
-- (póliza, documento, ventana). El historial vive acá, no en filas duplicadas de la tabla
-- de topes (ver nota 4 de V32).
--
-- DECISIONES CABLEADAS ACÁ
--
-- 1) Es append-only por diseño. Nadie hace UPDATE ni DELETE sobre esta tabla: se inserta
--    una fila por cada cambio. Por eso no tiene `activo` ni columnas de baja lógica —una
--    fila de historial no se "da de baja", y si se pudiera editar dejaría de servir como
--    evidencia—. Sí tiene `usuario_alta`/`fecha_alta`, que son el quién y el cuándo.
--
-- 2) EL CRITERIO DE LOS NULL: NULL = "este atributo NO participó del cambio".
--    Es el mismo criterio para los tres pares anterior/nuevo, y es lo que hace legible el
--    historial: al leer una fila se ve de una qué se tocó y qué quedó igual, sin tener que
--    comparar contra la fila anterior ni contra el estado actual del tope.
--
--    - `suma_anterior` NULL sólo en el ALTA (antes no había tope, no hay monto anterior).
--      En CORRECCION / AMPLIACION / BAJA viene siempre con el valor que se reemplaza.
--      `suma_nueva` es NOT NULL: toda fila de historial deja asentado el monto vigente
--      después del cambio, incluso cuando el cambio no fue del monto.
--    - `ventana_anterior` / `ventana_nueva`: AMBAS NULL cuando la ventana no cambió (el caso
--      normal: una ampliación de monto no toca la ventana). Cuando cambió, van las dos con
--      el valor viejo y el nuevo. En el ALTA va sólo `ventana_nueva` (no hay anterior).
--    - `iva_incluido_anterior` / `iva_incluido_nuevo`: idéntico. AMBAS NULL si el flag no
--      participó; en el ALTA sólo `iva_incluido_nuevo`.
--
--    Ojo con la consecuencia práctica: "ventana_nueva IS NULL" NO significa que el tope no
--    tenga ventana —significa que ESE cambio no la tocó, y la ventana vigente hay que
--    buscarla en la última fila del historial que la haya escrito, o en `polizas_ap_topes`.
--    Por eso la reconstrucción del estado a una fecha se hace con el último valor NO NULL de
--    cada atributo, no con la última fila.
--
--    Se eligió el par anterior/nuevo por atributo en lugar de un JSON con el diff, o de un
--    snapshot completo de la fila: el par se consulta con SQL plano (`WHERE ventana_nueva IS
--    NOT NULL` responde "¿alguna vez se cambió la ventana de este tope?"), no depende de
--    funciones JSON, y no obliga a versionar columnas que no son parte del significado del
--    tope (los usuarios y fechas de auditoría ya están en `polizas_ap_topes`).
--
-- 3) `tipo_cambio` SIN CHECK, mismo criterio que `ventana` en V32: el juego de valores es
--    dato, no estructura. Valores previstos: ALTA / CORRECCION / AMPLIACION / BAJA
--    (y REACTIVACION, cuando un asegurado que salió de la póliza vuelve y se reenciende su
--    tope). Un CHECK IN (...) obligaría a un ALTER TABLE + deploy para admitir un tipo
--    nuevo; los valores válidos se documentan en el COMMENT y se validan en la aplicación.
--    Por el mismo motivo `ventana_anterior` / `ventana_nueva` tampoco llevan CHECK: si V32
--    admite una ventana nueva (p. ej. 'MENSUAL') sin ALTER, el historial tiene que poder
--    registrarla sin ALTER también, o el cambio de ventana falla justo al querer auditarlo.
--
-- 4) `id_historial` en BIGINT: esta tabla crece por evento, no por asegurado, y es la que
--    va a tener más filas del paquete. `id_tope` en INT(11) para espejar
--    `polizas_ap_topes`.`id_tope`.
--
-- 5) SIN FOREIGN KEYS (convención del ecosistema, verificada). Relación lógica:
--      `polizas_ap_topes_historial`.`id_tope` -> `polizas_ap_topes`.`id_tope`  (N:1)
--    Consecuencia a tener en cuenta: si alguien borra una fila de `polizas_ap_topes` el
--    historial queda huérfano. Es una razón más para no borrar topes (se apagan con
--    activo=0, ver V32).
--
-- 6) El único CHECK es `motivo <> ''`. NOT NULL solo no alcanza: un VARCHAR NOT NULL acepta
--    la cadena vacía y la regla "exige motivo" se evaporaría. Como la columna está en
--    utf8mb4_unicode_ci (collation PAD SPACE), la comparación también rechaza un motivo
--    hecho sólo de espacios. Es un CHECK simple, sin subquery.
--
-- IDEMPOTENTE: CREATE TABLE IF NOT EXISTS. Se puede correr N veces.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `cs`.`polizas_ap_topes_historial` (
  `id_historial`   BIGINT(20)     NOT NULL AUTO_INCREMENT,

  -- Relación lógica (sin FK, ver nota 5) con polizas_ap_topes.id_tope INT(11).
  `id_tope`        INT(11)        NOT NULL
      COMMENT 'Tope al que pertenece el cambio. Lógico -> polizas_ap_topes.id_tope (sin FK)',

  -- Atributo versionado 1 de 3: el MONTO.
  `suma_anterior`  DECIMAL(16,2)  NULL
      COMMENT 'Suma asegurada que se reemplaza. NULL únicamente en el ALTA',
  `suma_nueva`     DECIMAL(16,2)  NOT NULL
      COMMENT 'Suma asegurada que queda vigente después del cambio. NOT NULL: se asienta siempre, incluso si el cambio no fue del monto',

  -- Atributo versionado 2 de 3: la VENTANA. Cambiar ANUAL -> EVENTO redefine el tope tanto
  -- como cambiar el importe (ver encabezado). VARCHAR(10) espeja polizas_ap_topes.ventana.
  `ventana_anterior` VARCHAR(10)  NULL
      COMMENT 'Ventana que se reemplaza. NULL si la ventana no participó del cambio, y también en el ALTA (no hay anterior)',
  `ventana_nueva`    VARCHAR(10)  NULL
      COMMENT 'Ventana vigente después del cambio: ANUAL | EVENTO | POLIZA. NULL si la ventana no participó del cambio. NULL NO significa sin ventana: significa que este cambio no la tocó',

  -- Atributo versionado 3 de 3: el flag de IVA. Apagarlo mueve el denominador del semáforo
  -- un 21% sin tocar el monto. TINYINT(1) espeja polizas_ap_topes.iva_incluido.
  `iva_incluido_anterior` TINYINT(1) NULL
      COMMENT 'Flag de IVA que se reemplaza. NULL si el flag no participó del cambio, y también en el ALTA',
  `iva_incluido_nuevo`    TINYINT(1) NULL
      COMMENT 'Flag de IVA vigente después del cambio (1 = la suma ya incluye IVA). NULL si el flag no participó del cambio',

  `motivo`         VARCHAR(500)   NOT NULL
      COMMENT 'Justificación del cambio. Obligatorio por regla de negocio: en una AMPLIACION es la referencia de la autorización del cliente',
  `tipo_cambio`    VARCHAR(20)    NOT NULL
      COMMENT 'ALTA | CORRECCION | AMPLIACION | BAJA | REACTIVACION. Es DATO: sin CHECK para poder agregar tipos sin ALTER',

  `usuario_alta`   INT(11)        NULL
      COMMENT 'id_persona que ejecutó el cambio (NULL si el cambio vino de un proceso automático / carga masiva)',
  `fecha_alta`     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
      COMMENT 'Momento del cambio',

  PRIMARY KEY (`id_historial`),

  -- Consulta natural: "mostrame la historia de este tope, del cambio más nuevo al más
  -- viejo". El índice compuesto resuelve el filtro y el orden en un solo paso (sin filesort).
  KEY `idx_polizas_ap_topes_hist_tope_fecha` (`id_tope`, `fecha_alta`),

  CONSTRAINT `ck_polizas_ap_topes_hist_motivo_no_vacio` CHECK (`motivo` <> '')

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Historial append-only de cambios del tope AP (alta, corrección, ampliación autorizada, baja). Versiona los 3 atributos que cambian el significado del tope: suma, ventana e iva_incluido (NULL en un par anterior/nuevo = ese atributo no participó del cambio). Motivo obligatorio. Sin FKs por convención del ecosistema';


-- -----------------------------------------------------------------------------
-- VERIFICACIÓN (read-only, se puede correr tal cual)
-- -----------------------------------------------------------------------------

-- 1) La tabla existe, con el charset esperado.
SELECT `TABLE_NAME`, `ENGINE`, `TABLE_COLLATION`
  FROM `INFORMATION_SCHEMA`.`TABLES`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial';

-- 2) Columnas y nulabilidad. Esperado: suma_nueva / motivo / tipo_cambio NOT NULL;
--    suma_anterior, ventana_anterior, ventana_nueva, iva_incluido_anterior e
--    iva_incluido_nuevo NULL-ables (los 4 últimos son los agregados para versionar ventana
--    e IVA: si no aparecen, la tabla se creó con una versión vieja de este archivo —ojo, el
--    CREATE TABLE IF NOT EXISTS no la corrige, hay que ALTERearla a mano).
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `IS_NULLABLE`, `COLUMN_DEFAULT`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial'
 ORDER BY `ORDINAL_POSITION`;

-- 3) Índices (esperado: PRIMARY, idx_polizas_ap_topes_hist_tope_fecha sobre id_tope+fecha_alta).
SELECT `INDEX_NAME`, `NON_UNIQUE`, `SEQ_IN_INDEX`, `COLUMN_NAME`
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial'
 ORDER BY `INDEX_NAME`, `SEQ_IN_INDEX`;

-- 4) El CHECK del motivo quedó declarado.
SELECT `CONSTRAINT_NAME`, `CHECK_CLAUSE`
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap_topes_historial';

-- 5) Control de integridad lógica (tiene que dar 0 filas): historial sin tope.
SELECT h.`id_historial`, h.`id_tope`
  FROM `cs`.`polizas_ap_topes_historial` h
  LEFT JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = h.`id_tope`
 WHERE t.`id_tope` IS NULL;

-- 6) Control de integridad lógica (tiene que dar 0 filas): tope activo sin ninguna fila de
--    historial. Todo tope debería tener al menos su ALTA registrada.
SELECT t.`id_tope`
  FROM `cs`.`polizas_ap_topes` t
  LEFT JOIN `cs`.`polizas_ap_topes_historial` h ON h.`id_tope` = t.`id_tope`
 WHERE t.`activo` = 1
   AND h.`id_historial` IS NULL;

-- 7) LOS 4 CAMPOS DE VERSIONADO DE VENTANA E IVA EXISTEN. Tiene que devolver 4.
--    Este control es el que atrapa el caso "la tabla ya estaba creada": el
--    CREATE TABLE IF NOT EXISTS de arriba es idempotente por NOMBRE, no por FORMA, así que
--    si `polizas_ap_topes_historial` se había creado a mano o con una versión anterior de
--    este archivo, no falla y tampoco agrega las columnas. Si esto devuelve menos de 4,
--    aplicar el ALTER de remediación de abajo.
SELECT COUNT(*) AS deben_ser_4
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial'
   AND `COLUMN_NAME` IN ('ventana_anterior', 'ventana_nueva',
                         'iva_incluido_anterior', 'iva_incluido_nuevo');

-- 8) Coherencia del criterio de los NULL (tiene que dar 0 filas): un par anterior/nuevo
--    a medias, o un cambio de ventana / IVA declarado pero con el mismo valor a los dos
--    lados (no es un cambio, es ruido en el historial).
SELECT `id_historial`, `id_tope`, `tipo_cambio`,
       `ventana_anterior`, `ventana_nueva`,
       `iva_incluido_anterior`, `iva_incluido_nuevo`
  FROM `cs`.`polizas_ap_topes_historial`
 WHERE (`ventana_anterior` IS NOT NULL AND `ventana_nueva` IS NULL)
    OR (`iva_incluido_anterior` IS NOT NULL AND `iva_incluido_nuevo` IS NULL)
    OR (`ventana_anterior` = `ventana_nueva`)
    OR (`iva_incluido_anterior` = `iva_incluido_nuevo`);


-- -----------------------------------------------------------------------------
-- REMEDIACIÓN (comentado — sólo si la verificación 7 devolvió menos de 4)
-- -----------------------------------------------------------------------------
-- Para una tabla que ya existía sin los campos de versionado de ventana e IVA. Es aditivo
-- (columnas NULL-ables, sin default), así que no toca las filas existentes: el historial
-- viejo queda con los 4 campos en NULL, que con el criterio de la nota 2 se lee como
-- "esos cambios no tocaron ventana ni IVA" — que es exactamente lo que pasó, porque antes
-- no se podían tocar por esta vía.
--
-- ALTER TABLE `cs`.`polizas_ap_topes_historial`
--   ADD COLUMN IF NOT EXISTS `ventana_anterior`      VARCHAR(10) NULL AFTER `suma_nueva`,
--   ADD COLUMN IF NOT EXISTS `ventana_nueva`         VARCHAR(10) NULL AFTER `ventana_anterior`,
--   ADD COLUMN IF NOT EXISTS `iva_incluido_anterior` TINYINT(1)  NULL AFTER `ventana_nueva`,
--   ADD COLUMN IF NOT EXISTS `iva_incluido_nuevo`    TINYINT(1)  NULL AFTER `iva_incluido_anterior`;
--
-- Después de aplicarlo, volver a correr la verificación 7 (tiene que dar 4).
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- ROLLBACK (comentado — destructivo, borra la trazabilidad de los cambios de tope)
-- -----------------------------------------------------------------------------
-- DROP TABLE IF EXISTS `cs`.`polizas_ap_topes_historial`;
-- -----------------------------------------------------------------------------

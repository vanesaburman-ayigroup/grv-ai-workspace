-- -----------------------------------------------------------------------------
-- V32 — CREATE TABLE `cs`.`polizas_ap_topes`
-- -----------------------------------------------------------------------------
-- Repo destino: wsmesacarga (src/main/resources/sql/)
-- Autor: Vanesa Burman — Fecha: 2026-07-30 — Ticket: PENDIENTE (ap-costos-topeo-etapa1)
--              El ticket de Jira todavía NO existe. Mientras no exista, la referencia
--              trazable es el change OpenSpec `ap-costos-topeo-etapa1` (AP Costos y Topeo,
--              etapa 1). Al crearlo, reemplazar este placeholder por el GRV-NNNN acá y en
--              V33/V34.
--
-- POR QUÉ EXISTE ESTA TABLA
-- En Accidentes Personales la suma asegurada es un TOPE por (póliza, asegurado): lo que
-- la póliza cubre para esa persona, IVA incluido. Hoy ese dato no vive en ninguna parte:
-- `polizas_ap` describe la póliza (vigencia, empleador, detalle de cobertura) pero no
-- cuánto se puede gastar por persona, así que el consumo se controla a mano y se entera
-- de que se pasó el tope cuando ya se pasó.
-- Esta tabla es el denominador del semáforo de consumo: sin tope no hay porcentaje, y sin
-- porcentaje no hay aviso al pasar de nivel (Alto / Muy alto / Excedido).
--
-- DECISIONES QUE ESTÁN CABLEADAS ACÁ (y por qué)
--
-- 1) `nro_doc` en latin1_swedish_ci DENTRO de una tabla utf8mb4.
--    La tabla nueva se crea utf8mb4/utf8mb4_unicode_ci, que es la convención vigente,
--    PERO `nro_doc` se declara explícitamente CHARACTER SET latin1 COLLATE
--    latin1_swedish_ci porque el asegurado se resuelve joineando contra
--    `cs`.`afiliados`.`nro_doc`, que es VARCHAR(50) latin1_swedish_ci (tabla legacy en
--    latin1). Si se declarara utf8mb4:
--      - los joins directos revientan con "Illegal mix of collations", y
--      - al "arreglarlo" con CONVERT()/COLLATE en el ON, MariaDB convierte la columna
--        indexada y PIERDE el índice de `afiliados` -> full scan.
--    NO "corregir" esta columna a utf8mb4 sin migrar antes `afiliados`. Si alguien la
--    normaliza por prolijidad, rompe el join y el plan de ejecución en silencio.
--
-- 2) `tipo_doc` DECIMAL(22,0): espeja el tipo real de `cs`.`afiliados`.`tipo_doc`
--    (DECIMAL(22,0), legacy, es así). Mismo motivo que el punto 1: joinear sin conversión
--    implícita. Va NULL porque la nómina de AP suele llegar con número de documento sin
--    tipo, y el tipo se completa cuando se identifica a la persona.
--
-- 3) SIN FOREIGN KEYS. Se verificó INFORMATION_SCHEMA.KEY_COLUMN_USAGE: ni `polizas_ap`
--    ni `denuncia_poliza` tienen FKs declaradas; el ecosistema no las usa. Relaciones
--    lógicas (a validar en la aplicación, no en la base):
--      `polizas_ap_topes`.`id_poliza`   -> `polizas_ap`.`id_poliza`   (N:1)
--      `polizas_ap_topes`.`id_afiliado` -> `afiliados`.`id_afiliado`  (N:1, opcional)
--      `polizas_ap_topes`.(`tipo_doc`,`nro_doc`) -> `afiliados`.(`tipo_doc`,`nro_doc`)
--
-- 4) ELECCIÓN DEL UNIQUE — uk_polizas_ap_topes_poliza_doc_ventana
--    (`id_poliza`, `nro_doc`, `ventana`)
--
--    a) POR QUÉ NO ENTRA `tipo_doc`.
--       En MariaDB los NULL son DISTINTOS a efectos de un índice UNIQUE. Como `tipo_doc`
--       es opcional (ver punto 2), incluirlo anularía la garantía justo en el caso más
--       frecuente: se podrían cargar (poliza 10, tipo NULL, doc 12345678) y
--       (poliza 10, tipo 1, doc 12345678) como dos topes activos para la MISMA persona, y
--       el semáforo tomaría uno de los dos según el orden del plan. Dejándolo afuera, el
--       par (póliza, documento) identifica al asegurado, que es como se lo identifica en
--       la operación real. Costo aceptado: dentro de una misma póliza no van a poder
--       coexistir un DNI y una LC con el mismo número (caso patológico); es una restricción
--       preferible a perder el control de duplicados.
--
--    b) POR QUÉ SÍ ENTRA `ventana`.
--       La ventana del tope (ANUAL / EVENTO / POLIZA) cambia el significado del monto, así
--       que dos topes con ventanas distintas no son duplicados: son dos reglas distintas y
--       deben poder convivir.
--
--    c) POR QUÉ NO ENTRA `activo`.
--       Meter la marca de baja lógica en un UNIQUE es un anti-patrón: sólo tolera UNA fila
--       con activo=0 por clave. La segunda baja del mismo (póliza, documento, ventana)
--       —asegurado que sale, vuelve y sale otra vez— falla con "Duplicate entry" en
--       producción. El modelo acordado es: la baja NO borra ni duplica la fila, la APAGA
--       (activo=0 + fecha_baja/usuario_baja), y si el asegurado vuelve se REACTIVA la misma
--       fila; la trazabilidad de cada cambio vive en `polizas_ap_topes_historial` (V33),
--       que es el lugar correcto para el historial. Resultado: como máximo una fila por
--       (póliza, documento, ventana), activa o apagada, y el UNIQUE la protege siempre.
--       Si más adelante el negocio exige conservar N filas históricas del mismo tope en
--       esta tabla, la forma correcta NO es agregar `activo` al UNIQUE sino indexar una
--       columna generada que sea NULL cuando el tope no está vigente (los NULL no colisionan):
--         -- ALTER TABLE `cs`.`polizas_ap_topes`
--         --   ADD COLUMN IF NOT EXISTS `vigente_uk` TINYINT(1)
--         --       AS (IF(`activo` = 1, 1, NULL)) PERSISTENT;
--         -- ALTER TABLE `cs`.`polizas_ap_topes`
--         --   DROP INDEX `uk_polizas_ap_topes_poliza_doc_ventana`,
--         --   ADD UNIQUE KEY `uk_polizas_ap_topes_vigente`
--         --       (`id_poliza`, `nro_doc`, `ventana`, `vigente_uk`);
--       Queda comentado a propósito: es una decisión de negocio, no se aplica por default.
--
--    d) PRECONDICIÓN DEL ALTA: el documento tiene que llegar NORMALIZADO.
--       Este UNIQUE protege únicamente si el mismo documento se escribe SIEMPRE igual, y
--       `nro_doc` es texto libre (VARCHAR, ver punto 1). Para el índice, '12345678',
--       '012345678', '12.345.678' y '12345678 ' son CUATRO claves distintas: la MISMA
--       persona podría quedar con cuatro topes activos en la misma póliza, y el semáforo
--       tomaría uno de los cuatro según el orden del plan —exactamente el agujero que el
--       UNIQUE pretendía cerrar—.
--       La base NO puede resolverlo sola: normalizar en un CHECK exigiría funciones que
--       MariaDB no admite en CHECK, y una columna generada normalizada obligaría a
--       reindexar y a duplicar el criterio en dos lugares.
--       Por eso la regla es del SERVICIO, y es una PRECONDICIÓN del alta, no una prolijidad:
--       **antes de insertar o actualizar, el servicio normaliza el documento — sin puntos,
--       sin espacios (ni internos ni al borde), sin guiones y sin ceros a la izquierda—, y
--       lo persiste ya normalizado.** La búsqueda del tope normaliza con el mismo criterio,
--       o no encuentra lo que se guardó.
--       NO insertar en esta tabla desde un script suelto, una carga masiva o una pantalla
--       nueva sin pasar por esa normalización: el UNIQUE va a aceptar el duplicado sin
--       devolver ningún error y el desvío recién se ve cuando el tope da un porcentaje que
--       no cierra. Si aparece un origen de datos nuevo, el control de duplicados de la
--       verificación de este archivo (consulta 7) es el que lo detecta.
--
-- 5) CHECK: hay uno solo, sobre `suma_asegurada`.
--    - `suma_asegurada > 0`: un tope de 0 o negativo no es un tope, es un dato mal cargado
--      (y haría que TODO caso arranque "Excedido"). Es un CHECK simple, sin subquery
--      (MariaDB no admite subqueries en CHECK).
--    - NO se pone CHECK sobre `ventana`. La decisión de negocio es explícita: la ventana
--      del tope es DATO, tiene que poder cambiar sin tocar estructura. Un
--      CHECK (ventana IN ('ANUAL','EVENTO','POLIZA')) obligaría a un ALTER TABLE —es decir,
--      una migración y un deploy— para admitir una ventana nueva (p. ej. 'MENSUAL'), que es
--      exactamente lo que se quiso evitar. Los valores válidos se documentan en el COMMENT
--      de la columna y se validan en la aplicación / parametrización.
--
-- 6) Montos en DECIMAL(16,2). Nunca float/double: sobre importes con IVA, el redondeo
--    binario mueve el porcentaje del semáforo y por lo tanto el nivel que se avisa.
--
-- IDEMPOTENTE: CREATE TABLE IF NOT EXISTS. Se puede correr N veces.
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `cs`.`polizas_ap_topes` (
  `id_tope`          INT(11)        NOT NULL AUTO_INCREMENT,

  -- Relación lógica (sin FK, ver nota 3) con polizas_ap.id_poliza INT(11).
  `id_poliza`        INT(11)        NOT NULL
      COMMENT 'Póliza AP dueña del tope. Lógico -> polizas_ap.id_poliza (sin FK)',

  -- Identificación del asegurado. Tipos ESPEJADOS de cs.afiliados para joinear con índice.
  `tipo_doc`         DECIMAL(22,0)  NULL
      COMMENT 'Espeja afiliados.tipo_doc (DECIMAL legacy). Opcional: la nómina AP suele traer solo el número',
  `nro_doc`          VARCHAR(50) CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL
      COMMENT 'Documento del asegurado, YA NORMALIZADO: el servicio lo normaliza ANTES de insertar (sin puntos, sin espacios, sin guiones, sin ceros a la izquierda) porque el UNIQUE compara texto y 12345678 vs 012345678 son dos claves distintas -> dos topes activos para la misma persona. Precondicion del alta, no prolijidad: no insertar sin normalizar. latin1 A PROPOSITO para joinear directo contra afiliados.nro_doc sin romper collations ni perder el indice. NO convertir a utf8mb4',
  `id_afiliado`      INT(11)        NULL
      COMMENT 'Se resuelve al vincular el asegurado. Acelera el join y evita depender del documento cuando la persona ya está identificada. Lógico -> afiliados.id_afiliado (sin FK)',

  -- El tope propiamente dicho.
  `suma_asegurada`   DECIMAL(16,2)  NOT NULL
      COMMENT 'Tope de cobertura para (póliza, asegurado). DECIMAL, nunca float',
  `iva_incluido`     TINYINT(1)     NOT NULL DEFAULT 1
      COMMENT '1 = la suma asegurada ya incluye IVA (criterio vigente). Se deja explícito para no volver a discutirlo por caso',
  `moneda`           VARCHAR(3)     NOT NULL DEFAULT 'ARS'
      COMMENT 'ISO 4217. Hoy siempre ARS; explícito para no asumirlo si aparece otra',
  `ventana`          VARCHAR(10)    NOT NULL DEFAULT 'ANUAL'
      COMMENT 'Ventana de acumulación del tope: ANUAL (default, criterio vigente) | EVENTO | POLIZA. Es DATO: sin CHECK para poder agregar valores sin ALTER',

  -- Auditoría / baja lógica.
  `activo`           TINYINT(1)     NOT NULL DEFAULT 1
      COMMENT '1 = tope vigente. La baja apaga la fila (no la borra ni la duplica); si el asegurado vuelve se reactiva esta misma fila',
  `fecha_alta`       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_alta`     INT(11)        NULL
      COMMENT 'id_persona que cargó el tope. INT(11) para acompañar a polizas_ap.responsable_carga',
  `fecha_modificacion` DATETIME     NULL,
  `usuario_modificacion` INT(11)    NULL,
  `fecha_baja`       DATETIME       NULL,
  `usuario_baja`     INT(11)        NULL,

  PRIMARY KEY (`id_tope`),

  -- Un solo tope por (póliza, documento, ventana). Ver nota 4 para el por qué de cada
  -- columna incluida y de las dos que quedaron afuera (tipo_doc y activo).
  -- OJO: sólo protege si `nro_doc` llega normalizado — lo garantiza el servicio, no la
  -- base (ver nota 4.d). Con documento sin normalizar el duplicado entra sin error.
  -- Además, al ser `id_poliza` la columna más a la izquierda, este mismo índice resuelve
  -- "traeme los topes de la póliza X" -> no se crea otro índice por póliza (sería
  -- redundante y encarece las escrituras sin ganar nada).
  UNIQUE KEY `uk_polizas_ap_topes_poliza_doc_ventana` (`id_poliza`, `nro_doc`, `ventana`),

  -- Buscar por documento sin conocer la póliza (el consumo llega por siniestro/afiliado,
  -- no por póliza) y joinear contra afiliados.
  KEY `idx_polizas_ap_topes_doc` (`nro_doc`, `tipo_doc`),

  -- Camino rápido cuando el asegurado ya está identificado.
  KEY `idx_polizas_ap_topes_afiliado` (`id_afiliado`),

  CONSTRAINT `ck_polizas_ap_topes_suma_positiva` CHECK (`suma_asegurada` > 0)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Tope de cobertura AP por (póliza, asegurado), IVA incluido. Denominador del semáforo de consumo. Sin FKs por convención del ecosistema';


-- -----------------------------------------------------------------------------
-- VERIFICACIÓN (read-only, se puede correr tal cual)
-- -----------------------------------------------------------------------------

-- 1) La tabla existe, con el charset esperado.
SELECT `TABLE_NAME`, `ENGINE`, `TABLE_COLLATION`
  FROM `INFORMATION_SCHEMA`.`TABLES`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes';

-- 2) `nro_doc` quedó en latin1_swedish_ci y `tipo_doc` en DECIMAL(22,0)
--    (si esto no da latin1_swedish_ci / decimal, el join contra afiliados NO va a usar índice).
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `CHARACTER_SET_NAME`, `COLLATION_NAME`, `IS_NULLABLE`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes'
 ORDER BY `ORDINAL_POSITION`;

-- 3) Índices creados (esperado: PRIMARY, uk_polizas_ap_topes_poliza_doc_ventana,
--    idx_polizas_ap_topes_doc, idx_polizas_ap_topes_afiliado).
SELECT `INDEX_NAME`, `NON_UNIQUE`, `SEQ_IN_INDEX`, `COLUMN_NAME`
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes'
 ORDER BY `INDEX_NAME`, `SEQ_IN_INDEX`;

-- 4) El CHECK quedó declarado.
SELECT `CONSTRAINT_NAME`, `CHECK_CLAUSE`
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap_topes';

-- 5) PRUEBA REAL DE COLLATION: este join tiene que ejecutar sin "Illegal mix of collations".
--    Con la tabla vacía devuelve 0 filas; lo que se está probando es que compile.
SELECT COUNT(*) AS joins_ok
  FROM `cs`.`polizas_ap_topes` t
  JOIN `cs`.`afiliados` a
    ON a.`nro_doc` = t.`nro_doc`;

-- 6) Y que el plan use el índice de afiliados por nro_doc (no un full scan).
--    En la columna `key` de la fila de `a` tiene que aparecer un índice sobre nro_doc;
--    si dice NULL con type=ALL, se perdió el latin1 de la nota 1.
EXPLAIN SELECT t.`id_tope`, a.`id_afiliado`
  FROM `cs`.`polizas_ap_topes` t
  JOIN `cs`.`afiliados` a ON a.`nro_doc` = t.`nro_doc`;

-- 7) CONTROL DE NORMALIZACIÓN DEL DOCUMENTO (tiene que dar 0 filas).
--    El UNIQUE no puede detectar esto (ver nota 4.d): son claves distintas para el índice
--    pero la misma persona. Correr esta consulta después de cada carga de topes —sobre todo
--    si vino de una carga masiva o de un script suelto—.
--    a) Documentos que quedaron con basura (puntos, espacios, guiones, ceros a la izquierda).
--       El control va por LENGTH además de por `<>`: la collation de esta columna es
--       PAD SPACE, así que '12345678 ' = '12345678' y un espacio al final NO se vería
--       comparando con `<>`.
SELECT `id_tope`, `id_poliza`, `nro_doc`, LENGTH(`nro_doc`) AS largo
  FROM `cs`.`polizas_ap_topes`
 WHERE LENGTH(`nro_doc`) <> LENGTH(TRIM(REPLACE(REPLACE(REPLACE(`nro_doc`, '.', ''), '-', ''), ' ', '')))
    OR `nro_doc` LIKE '0%';

--    b) La misma persona con más de un tope en la misma póliza y ventana, detectada
--       comparando el documento YA normalizado. Si devuelve filas, hay que unificar a mano
--       (dejar el tope correcto y apagar los otros con activo=0) ANTES de usar el semáforo.
--       (se normaliza con funciones de STRING, no con `+ 0`: un documento con letras
--        —pasaporte— castea a 0 y agruparía a todos los pasaportes como duplicados).
SELECT `id_poliza`,
       TRIM(LEADING '0' FROM
            TRIM(REPLACE(REPLACE(REPLACE(`nro_doc`, '.', ''), '-', ''), ' ', ''))) AS doc_normalizado,
       `ventana`,
       COUNT(*)                       AS topes,
       GROUP_CONCAT(`id_tope`)        AS ids,
       GROUP_CONCAT(`nro_doc`)        AS variantes_cargadas
  FROM `cs`.`polizas_ap_topes`
 WHERE `activo` = 1
 GROUP BY `id_poliza`, doc_normalizado, `ventana`
HAVING COUNT(*) > 1;


-- -----------------------------------------------------------------------------
-- ROLLBACK (comentado — destructivo, borra los topes cargados)
-- -----------------------------------------------------------------------------
-- Ejecutar V33 (historial) ANTES que este drop si se está revirtiendo todo el paquete,
-- porque el historial referencia lógicamente id_tope.
--
-- DROP TABLE IF EXISTS `cs`.`polizas_ap_topes`;
-- -----------------------------------------------------------------------------

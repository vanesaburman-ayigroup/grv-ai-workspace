-- =============================================================================
-- V34 - ALTER TABLE `cs`.`denuncia_poliza` — denormalización del tope AP
-- =============================================================================
-- Fecha: 2026-07-30
-- Repo destino: wsmesacarga  →  src/main/resources/sql/V34__ALTER_denuncia_poliza_ADD_tope.sql
--               (convención LOCAL de este repo: `V<N>__<DESCRIPCION>.sql`, sin
--                subcarpeta `migrations/`; el último número usado era V31, y V32/V33
--                quedan reservados en este mismo cambio para `polizas_ap_topes` y
--                `polizas_ap_topes_historial`.)
-- Change OpenSpec: `ap-costos-topeo-etapa1` (AP Costos y Topeo, etapa 1)
-- Ticket Jira: PENDIENTE — todavía no existe el ticket. Al crearlo, reemplazar este
--              placeholder por el GRV-NNNN en este archivo y en V32/V33.
--
-- POR QUÉ (no el qué)
-- El semáforo de consumo AP necesita un DENOMINADOR por siniestro. El tope vive en
-- `polizas_ap_topes` con grano (póliza, documento del asegurado, ventana), o sea que
-- para llegar al tope de una denuncia hay que resolver el documento del accidentado:
--   denuncia_poliza → denuncias → afiliados → (tipo_doc, nro_doc) → polizas_ap_topes
-- Esa cadena cruza tres tablas legacy con tipos y collations desparejos
-- (`denuncias.id_afiliado` es DECIMAL(22,0) contra `afiliados.id_afiliado` INT(11);
-- `afiliados.nro_doc` es latin1 contra tablas nuevas utf8mb4) y hay que recorrerla en
-- CADA consulta del semáforo, del tablero de cartera y de cada vista de consumo.
--
-- Se copia el tope RESUELTO al vínculo para que el motor de consumo arranque y termine
-- en `denuncia_poliza`: es el filtro que acota el universo AP (73 denuncias) antes de
-- cruzar `turnos` (~4,3M) y `erogaciones` (~1,15M). Sin la denormalización, el filtro
-- que hace trivial el problema depende de un join que el optimizador puede resolver mal.
--
-- POR QUÉ TAMBIÉN `id_tope` Y `fecha_resolucion_tope`
-- Un valor denormalizado sin procedencia es un valor en el que no se puede confiar.
-- `id_tope` dice DE QUÉ FILA salió y `fecha_resolucion_tope` CUÁNDO se resolvió: con
-- esos dos datos se puede detectar por consulta (bloque 4.C) que el tope de la póliza
-- se editó o se amplió después y que el vínculo quedó viejo. Sin ellos, la única forma
-- de saberlo sería recalcular todo a ciegas.
--
-- POR QUÉ TAMBIÉN `ventana` E `iva_incluido`
-- No alcanza con copiar el monto: el monto sin su regla de lectura no es comparable.
--   - `ventana` (ANUAL / EVENTO / POLIZA) define SOBRE QUÉ RANGO se acumula el consumo.
--     El mismo importe topea distinto si es por año calendario o por evento; sin este dato
--     el motor tendría que volver a `polizas_ap_topes` para saber qué sumar, que es
--     exactamente el join que la denormalización viene a evitar.
--   - `iva_incluido` evita el error silencioso de comparar un consumo NETO contra un tope
--     CON IVA (o al revés): un 21% de diferencia que no rompe nada, sólo da mal el
--     porcentaje del semáforo.
-- Las dos espejan el tope EN EL MOMENTO DE LA RESOLUCIÓN, igual que `suma_asegurada`.
--
-- ALCANCE
-- Seis columnas nuevas, todas aditivas. No modifica ni borra datos existentes.
-- El BACKFILL de las 73 denuncias AP vivas va en el bloque 3 y está COMENTADO A
-- PROPÓSITO: no se puede ejecutar hasta que negocio cargue los topes en V32.
--
-- REQUISITOS
-- - MariaDB 10.0+ (`ADD COLUMN IF NOT EXISTS`).
-- - V32 (`cs`.`polizas_ap_topes`) aplicada ANTES, si se va a correr el backfill.
--   El ALTER de este script no depende de V32 y puede aplicarse solo.
--
-- NO SE DECLARAN FOREIGN KEYS
-- Se verificó INFORMATION_SCHEMA.KEY_COLUMN_USAGE: ni `denuncia_poliza` ni `polizas_ap`
-- tienen FKs declaradas, y el ecosistema no usa FKs en ninguna parte. `id_tope` es una
-- relación LÓGICA contra `polizas_ap_topes`.`id_tope`, sostenida por el servicio.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. DDL — columnas denormalizadas del tope
-- -----------------------------------------------------------------------------
-- `denuncia_poliza` ya está en utf8mb4 / utf8mb4_unicode_ci, así que estas columnas
-- heredan el charset de la tabla y NO hace falta la excepción latin1 que sí aplica a
-- `nro_doc` en las tablas nuevas de este cambio (ver V32). No agregar CHARACTER SET acá.
--
-- Las seis columnas se agregan AL FINAL (sin `AFTER`) a propósito: es la única forma
-- de que InnoDB pueda usar ALGORITHM=INSTANT. Con 73 filas da igual en tiempo real,
-- pero deja el patrón correcto para cuando la tabla crezca. No se fuerza
-- `ALGORITHM=INSTANT` explícito porque haría fallar el script entero en un motor que
-- no lo soporte, y el fallback (COPY de 73 filas) es inofensivo.

ALTER TABLE `cs`.`denuncia_poliza`
  ADD COLUMN IF NOT EXISTS `suma_asegurada` DECIMAL(16,2) NULL
      COMMENT 'Tope resuelto al asociar la denuncia a la póliza, CON IVA incluido. NULL = tope no resuelto (estado SIN_TOPE en el semáforo, no 0%). DECIMAL, nunca float.',
  ADD COLUMN IF NOT EXISTS `moneda` VARCHAR(3) NOT NULL DEFAULT 'ARS'
      COMMENT 'ISO-4217 de la suma asegurada. Default ARS: hoy toda la cartera AP es en pesos.',
  ADD COLUMN IF NOT EXISTS `id_tope` INT NULL
      COMMENT 'Relación lógica a polizas_ap_topes.id_tope (sin FK, criterio del ecosistema). Trazabilidad: de qué fila salió el valor, para detectar que quedó viejo si el tope se editó o amplió después.',
  ADD COLUMN IF NOT EXISTS `fecha_resolucion_tope` DATETIME NULL
      COMMENT 'Cuándo se resolvió el tope. NULL con suma_asegurada NULL = nunca se intentó; distinto de resuelto y sin resultado.',
  ADD COLUMN IF NOT EXISTS `ventana` VARCHAR(10) NULL
      COMMENT 'Ventana de acumulación copiada del tope al resolverlo: ANUAL | EVENTO | POLIZA. El motor la necesita para saber sobre qué rango acumula el consumo. NULL = tope no resuelto. Sin DEFAULT a propósito: un ANUAL por default mentiría sobre un tope que nadie resolvió.',
  ADD COLUMN IF NOT EXISTS `iva_incluido` TINYINT(1) NULL
      COMMENT 'Copiado del tope al resolverlo: 1 = la suma_asegurada ya incluye IVA. Evita comparar un consumo neto contra un tope con IVA (21% de error silencioso en el %). NULL = tope no resuelto.';

-- OJO con `moneda`: es NOT NULL DEFAULT 'ARS', así que las 73 filas preexistentes quedan
-- en 'ARS' sin pasar por el backfill. Es correcto hoy (100% de la cartera AP está en
-- pesos), pero si alguna póliza se cargara en USD el backfill DEBE pisar la moneda junto
-- con el monto — está contemplado en el UPDATE del bloque 3.
--
-- No se agrega CHECK sobre `moneda`: un CHECK en una tabla existente fuerza validación de
-- todas las filas y no aporta contra un dato que el servicio ya valida contra el catálogo.


-- -----------------------------------------------------------------------------
-- 2. ÍNDICES — decisión: NO se crea ninguno ahora. Justificación.
-- -----------------------------------------------------------------------------
-- Medición real sobre `cs` (verificada contra INFORMATION_SCHEMA.STATISTICS el 07/08/2026):
-- `denuncia_poliza` tiene **73 filas** y ya trae **SEIS** índices:
--     PRIMARY                      (id_denuncia_poliza)
--     uk_denuncia_poliza_activo    UNIQUE (id_denuncia, activo)
--     idx_denuncia_poliza_denuncia (id_denuncia)
--     idx_denuncia_poliza_poliza   (id_poliza)
--     idx_denuncia_poliza_fecha    (fecha_asociacion)
--     idx_denuncia_poliza_usuario  (usuario_asociacion)
--
-- REDUNDANCIA DETECTADA (se documenta, NO se toca acá):
-- `idx_denuncia_poliza_denuncia` (id_denuncia) es un PREFIJO EXACTO de
-- `uk_denuncia_poliza_activo` (id_denuncia, activo), así que no aporta ningún plan que la
-- UNIQUE no cubra: es escritura y espacio de más. `idx_denuncia_poliza_usuario`
-- (usuario_asociacion) tampoco tiene consulta conocida que lo use. Dropear índices NO es
-- aditivo (cambia planes de ejecución de código ajeno y no se revierte gratis en una tabla
-- grande), así que va en una migración propia con su propia decisión. Anotado para que el
-- inventario de arriba no se lea como "está todo bien".
--
-- La tabla entera entra en UNA página de InnoDB. Cualquier índice sobre las columnas
-- nuevas sería IGNORADO por el optimizador: un full scan de 73 filas cuesta menos que
-- el doble salto índice→PK. Y el motor de consumo no filtra por estas columnas: filtra
-- por `activo = 1` (+ `id_denuncia`) y LEE la suma asegurada de la fila que ya trajo.
-- Agregar un índice acá sería costo de escritura y una línea más para mantener, a cambio
-- de nada medible. Se documenta el umbral para no tener que re-razonarlo:
--
-- CREAR `idx_denuncia_poliza_tope` CUANDO se cumplan las dos condiciones:
--   (a) la tabla pase las ~50.000 filas (hoy: 73 → falta un factor 700), y
--   (b) exista una consulta REAL que filtre por `id_tope` — el caso previsto es
--       "el tope X se amplió: refrescar los vínculos activos que salieron de esa fila",
--       hoy resuelto por scan.
--
-- ALTER TABLE `cs`.`denuncia_poliza`
--   ADD INDEX IF NOT EXISTS `idx_denuncia_poliza_tope` (`id_tope`, `activo`);
--
-- El mismo criterio aplica a un índice para la query de control (`suma_asegurada IS NULL
-- AND activo = 1`): es un reporte de gestión que se corre a mano sobre 73 filas.
--
-- OBSERVACIÓN sobre un índice PREEXISTENTE (fuera del alcance de este script, pero afecta
-- a la re-resolución del tope del paso 3.4): `uk_denuncia_poliza_activo` es UNIQUE
-- (id_denuncia, activo) con `activo` TINYINT, o sea que una denuncia admite como máximo
-- UNA fila activa y UNA inactiva. La primera desasociación entra; una SEGUNDA
-- re-asociación de la misma denuncia choca contra la unicidad al intentar dejar un
-- segundo vínculo con `activo = 0`. Hoy no hay casos (73 filas, ninguna denuncia
-- repetida), pero conviene saberlo antes de construir la pantalla de cambio de póliza.
-- No se toca acá: cambiar una UNIQUE existente no es aditivo y necesita decisión propia.


-- -----------------------------------------------------------------------------
-- 3. BACKFILL — **NO EJECUTAR TODAVÍA. TODO ESTE BLOQUE ESTÁ COMENTADO.**
-- -----------------------------------------------------------------------------
-- CUÁNDO SE CORRE
-- Recién DESPUÉS de que negocio cargue los topes en `cs`.`polizas_ap_topes` (V32). Antes
-- de eso el UPDATE no haría nada (no hay filas para joinear) y sólo generaría la ilusión
-- de que el proceso corrió.
--
-- QUÉ POBLA
-- Las **73 denuncias AP activas** (`denuncia_poliza.activo = 1`, medición del 30/07/2026),
-- repartidas en **7 pólizas** con siniestros. De esas 73, **3 tienen `id_afiliado` NULL**:
-- son IRRESOLUBLES por documento y NO son un error del proceso — el tope de esas tres se
-- carga a mano cuando se complete el afiliado de la denuncia. El bloque 4 las separa
-- justamente para que no se cuenten como falla.
--
-- POR QUÉ POR DOCUMENTO Y NO POR PÓLIZA
-- El tope es por (póliza, asegurado): dos asegurados de la misma póliza pueden tener
-- sumas distintas. Resolver por póliza sola le daría a todos el tope del primero.
--
-- CADENA Y TIPOS (leer antes de tocar los joins)
--   denuncia_poliza.id_denuncia  BIGINT(20)      = denuncias.id_denuncia   INT(11)
--   denuncias.id_afiliado        DECIMAL(22,0)   = afiliados.id_afiliado   INT(11)
--   afiliados.nro_doc            VARCHAR(50) latin1_swedish_ci
--                                                = polizas_ap_topes.nro_doc  (declarada
--     explícitamente latin1 en V32 justamente para que este join no dé "Illegal mix of
--     collations" ni pierda el índice por conversión implícita — ver el comentario de V32)
--   afiliados.tipo_doc           DECIMAL(22,0)  ~ polizas_ap_topes.tipo_doc DECIMAL(22,0)
--     (mismo tipo, pero NULL-able del lado del tope: NO se joinea por igualdad — ver la
--      trampa del NULL más abajo)
-- El par DECIMAL vs INT de `id_afiliado` es legacy y obliga al motor a convertir; con
-- 73 filas de lado conductor es irrelevante. NO "arreglarlo" con un CAST que anule el
-- índice de `afiliados`.
--
-- ⚠ TRAMPA DEL NULL EN `tipo_doc` — NO REVERTIR ESTO
-- `polizas_ap_topes`.`tipo_doc` es NULL-able y el caso ESPERADO es NULL: la nómina de AP
-- llega con el NÚMERO de documento y sin el tipo (está dicho en V32, nota 2). En SQL
-- `NULL = <valor>` no es verdadero sino UNKNOWN, así que un join
--     AND t.`tipo_doc` = a.`tipo_doc`
-- descarta TODAS las filas de tope con tipo_doc NULL — es decir, el caso normal. El
-- backfill correría sin error, informaría 0 filas afectadas y el bug sería INVISIBLE:
-- parecería que negocio todavía no cargó los topes.
-- Por eso se joinea por la clave única REAL de V32 (id_poliza, nro_doc, ventana) + activo,
-- y el tipo de documento se usa sólo como FILTRO TOLERANTE:
--     AND (t.`tipo_doc` IS NULL OR t.`tipo_doc` = a.`tipo_doc`)
-- que acepta el tope sin tipo y, cuando el tipo está cargado, exige que coincida.
-- Si alguien "prolija" esto de vuelta a una igualdad simple, rompe el backfill en silencio.
--
-- QUÉ TOPE SE ELIGE SI HAY MÁS DE UNO
-- La unicidad REAL de V32 es **(id_poliza, nro_doc, ventana)** — sin `tipo_doc` y sin
-- `activo`, con la justificación escrita en V32 (tipo_doc es NULL-able y los NULL son
-- distintos entre sí en un UNIQUE; `activo` en la clave rompería la segunda baja lógica).
-- O sea: un mismo asegurado, dentro de una póliza, puede tener **como máximo UN tope por
-- ventana** — y por lo tanto hasta tres filas: ANUAL, EVENTO y POLIZA. El backfill toma
-- **ANUAL**, que es el criterio vigente de negocio y el DEFAULT de la tabla.
-- El paso 3.0 lista los (póliza, documento) con más de un tope activo para que gestión
-- confirme la ventana ANTES de correr el UPDATE: si aparece alguno, no se adivina, se
-- pregunta.
--
-- IDEMPOTENCIA
-- El UPDATE sólo toca filas con `suma_asegurada IS NULL`: correrlo dos veces no repisa
-- nada ni mueve `fecha_resolucion_tope`. Para RE-resolver a propósito un vínculo (porque
-- el tope se amplió) va el UPDATE del paso 3.4, acotado por `id_tope`.
--
-- ......................................................................
-- 3.0 PRE-CHEQUEO (read-only) — ambigüedad de VENTANA. Debe devolver 0 filas.
--     Agrupa por (id_poliza, nro_doc) — el par que identifica al asegurado según el UNIQUE
--     real de V32 — y NO por tipo_doc: la ambigüedad que hay que detectar es de ventana
--     (un asegurado con ANUAL + EVENTO cargados), no de tipo de documento. Metiendo
--     tipo_doc en el GROUP BY, un tope con tipo NULL y otro con tipo 1 del mismo asegurado
--     caerían en grupos distintos y el chequeo diría "0 filas" estando ambiguo.
-- ......................................................................
-- SELECT pt.`id_poliza`, pt.`nro_doc`,
--        COUNT(*)                                            AS topes_activos,
--        GROUP_CONCAT(pt.`ventana`  ORDER BY pt.`ventana`)    AS ventanas,
--        GROUP_CONCAT(pt.`id_tope`  ORDER BY pt.`ventana`)    AS ids_tope,
--        GROUP_CONCAT(COALESCE(pt.`tipo_doc`, 'NULL') ORDER BY pt.`ventana`) AS tipos_doc
--   FROM `cs`.`polizas_ap_topes` pt
--  WHERE pt.`activo` = 1
--  GROUP BY pt.`id_poliza`, pt.`nro_doc`
-- HAVING COUNT(*) > 1;
--
-- ......................................................................
-- 3.1 DRY-RUN (read-only) — exactamente lo que el UPDATE va a escribir.
--     Revisar montos y moneda ANTES de ejecutar el paso 3.3.
-- ......................................................................
-- SELECT dp.`id_denuncia_poliza`,
--        dp.`id_denuncia`,
--        d.`nro_asignado`,
--        dp.`id_poliza`,
--        a.`tipo_doc`        AS tipo_doc_afiliado,
--        t.`tipo_doc`        AS tipo_doc_tope,      -- NULL es el caso normal (ver trampa)
--        a.`nro_doc`,
--        t.`id_tope`,
--        t.`suma_asegurada`  AS suma_a_escribir,
--        t.`moneda`          AS moneda_a_escribir,
--        t.`ventana`         AS ventana_a_escribir,
--        t.`iva_incluido`    AS iva_incluido_a_escribir
--   FROM `cs`.`denuncia_poliza` dp
--   JOIN `cs`.`denuncias`  d ON d.`id_denuncia` = dp.`id_denuncia`
--   JOIN `cs`.`afiliados`  a ON a.`id_afiliado` = d.`id_afiliado`
--   JOIN `cs`.`polizas_ap_topes` t
--          -- clave única REAL de V32: (id_poliza, nro_doc, ventana). NO agregar
--          -- `t.tipo_doc = a.tipo_doc` acá: mata el join cuando el tope no trae tipo.
--          ON  t.`id_poliza` = dp.`id_poliza`
--          AND t.`nro_doc`   = a.`nro_doc`
--          AND t.`ventana`   = 'ANUAL'
--          AND t.`activo`    = 1
--          -- tipo de documento como filtro TOLERANTE, no como parte de la clave:
--          AND (t.`tipo_doc` IS NULL OR t.`tipo_doc` = a.`tipo_doc`)
--  WHERE dp.`activo` = 1
--    AND dp.`suma_asegurada` IS NULL
--  ORDER BY dp.`id_poliza`, a.`nro_doc`;
--
-- ......................................................................
-- 3.2 CONTEO ANTES
-- ......................................................................
-- SELECT COUNT(*) AS sin_tope_antes
--   FROM `cs`.`denuncia_poliza`
--  WHERE `activo` = 1 AND `suma_asegurada` IS NULL;
--
-- ......................................................................
-- 3.3 BACKFILL. Correr en una transacción y confirmar contra el dry-run.
--     El WHERE `suma_asegurada IS NULL` es lo que lo hace idempotente: NO sacarlo.
-- ......................................................................
-- START TRANSACTION;
--
-- UPDATE `cs`.`denuncia_poliza` dp
--   JOIN `cs`.`denuncias`  d ON d.`id_denuncia` = dp.`id_denuncia`
--   JOIN `cs`.`afiliados`  a ON a.`id_afiliado` = d.`id_afiliado`
--   JOIN `cs`.`polizas_ap_topes` t
--          -- clave única REAL de V32: (id_poliza, nro_doc, ventana). El tipo de documento
--          -- NO va acá: `t.tipo_doc` es NULL en el caso normal y `NULL = valor` nunca es
--          -- verdadero, así que el UPDATE resolvería 0 topes y el error sería invisible.
--          ON  t.`id_poliza` = dp.`id_poliza`
--          AND t.`nro_doc`   = a.`nro_doc`
--          AND t.`ventana`   = 'ANUAL'
--          AND t.`activo`    = 1
--          AND (t.`tipo_doc` IS NULL OR t.`tipo_doc` = a.`tipo_doc`)
--    SET dp.`suma_asegurada`        = t.`suma_asegurada`,
--        dp.`moneda`                = t.`moneda`,
--        dp.`ventana`               = t.`ventana`,
--        dp.`iva_incluido`          = t.`iva_incluido`,
--        dp.`id_tope`               = t.`id_tope`,
--        dp.`fecha_resolucion_tope` = NOW()
--  WHERE dp.`activo` = 1
--    AND dp.`suma_asegurada` IS NULL;
--
-- -- Verificar el conteo de filas afectadas contra el dry-run del 3.1 y recién entonces:
-- COMMIT;
-- -- ROLLBACK;   <-- si el número no coincide
--
-- ......................................................................
-- 3.4 RE-RESOLUCIÓN de un tope que se amplió o se editó (NO es parte del backfill
--     inicial; queda documentado para que no se improvise después).
--     Reemplazar <ID_TOPE> por el id de la fila de polizas_ap_topes que cambió.
-- ......................................................................
-- UPDATE `cs`.`denuncia_poliza` dp
--   JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = dp.`id_tope`
--    SET dp.`suma_asegurada`        = t.`suma_asegurada`,
--        dp.`moneda`                = t.`moneda`,
--        dp.`ventana`               = t.`ventana`,
--        dp.`iva_incluido`          = t.`iva_incluido`,
--        dp.`fecha_resolucion_tope` = NOW()
--  WHERE dp.`activo` = 1
--    AND dp.`id_tope` = <ID_TOPE>
--    AND (dp.`suma_asegurada` <> t.`suma_asegurada`
--         OR dp.`moneda`       <> t.`moneda`
--         OR dp.`ventana`      <> t.`ventana`
--         OR dp.`iva_incluido` <> t.`iva_incluido`
--         OR dp.`ventana`      IS NULL
--         OR dp.`iva_incluido` IS NULL);


-- -----------------------------------------------------------------------------
-- 4. CONTROL DE GESTIÓN (read-only) — qué falta y de quién es la pelota
-- -----------------------------------------------------------------------------
-- Estas tres consultas son el tablero de regularización del tope. 4.A y 4.B se pueden
-- correr desde ya, apenas aplicado el ALTER (antes del backfill devuelven las 73 como
-- pendientes, que es la foto correcta). 4.C queda comentada porque lee
-- `polizas_ap_topes`: sin V32 aplicada falla con "table doesn't exist".

-- 4.A Resumen por estado. Separa lo que le falta a NEGOCIO (cargar el tope) de lo que le
--     falta a OPERACIONES (completar el afiliado de la denuncia). Sin esta distinción las
--     3 denuncias sin `id_afiliado` parecen una falla del proceso de backfill, y no lo son.
SELECT CASE
         WHEN dp.`suma_asegurada` IS NOT NULL              THEN 'RESUELTO'
         WHEN d.`id_afiliado`     IS NULL                  THEN 'IRRESOLUBLE_SIN_AFILIADO'
         WHEN a.`id_afiliado`     IS NULL                  THEN 'IRRESOLUBLE_AFILIADO_INEXISTENTE'
         WHEN a.`nro_doc` IS NULL OR a.`nro_doc` = ''      THEN 'IRRESOLUBLE_AFILIADO_SIN_DOCUMENTO'
         ELSE                                                   'PENDIENTE_CARGA_TOPE'
       END                                    AS estado,
       COUNT(*)                               AS denuncias,
       COUNT(DISTINCT dp.`id_poliza`)         AS polizas
  FROM `cs`.`denuncia_poliza` dp
  JOIN `cs`.`denuncias` d      ON d.`id_denuncia` = dp.`id_denuncia`
  LEFT JOIN `cs`.`afiliados` a ON a.`id_afiliado` = d.`id_afiliado`
 WHERE dp.`activo` = 1
 GROUP BY estado
 ORDER BY denuncias DESC;
-- Baseline verificado sobre `cs`, antes de cargar cualquier tope:
--   PENDIENTE_CARGA_TOPE          70   (7 pólizas)
--   IRRESOLUBLE_SIN_AFILIADO       3   (1 póliza: la 983320)
--   ...................................
--   total                         73   (0 afiliados sin documento)
-- Dato que ayuda a leer las 3 irresolubles: las tres son de la póliza 983320 y las tres
-- tienen `nro_asignado` NULL, o sea que son denuncias que nunca llegaron a numerarse.
-- No es información perdida de un caso operativo: es un alta a medio hacer. Confirmar con
-- gestión si corresponde completarlas o dar de baja el vínculo (`activo = 0`).

-- 4.B Detalle accionable: una fila por denuncia AP sin tope resuelto, con el documento
--     que negocio necesita para cargar el tope, o el motivo por el que no se puede.
--     La columna `de_quien_es` separa EXPLÍCITAMENTE las 3 denuncias con `id_afiliado`
--     NULL (medición del 30/07/2026): son irresolubles por documento y NO son una falla
--     del backfill. Sin esa columna, quien lea el listado cuenta 3 errores que no existen.
SELECT CASE
         WHEN d.`id_afiliado` IS NULL                 THEN 'IRRESOLUBLE — OPERACIONES (denuncia sin afiliado, NO es error del backfill)'
         WHEN a.`id_afiliado` IS NULL                 THEN 'IRRESOLUBLE — OPERACIONES (afiliado inexistente, NO es error del backfill)'
         WHEN a.`nro_doc` IS NULL OR a.`nro_doc` = '' THEN 'IRRESOLUBLE — OPERACIONES (afiliado sin documento, NO es error del backfill)'
         ELSE                                              'PENDIENTE — NEGOCIO (cargar el tope)'
       END                                            AS de_quien_es,
       dp.`id_denuncia_poliza`,
       dp.`id_denuncia`,
       d.`nro_asignado`,
       dp.`id_poliza`,
       p.`poliza`,
       p.`razon_social`,
       a.`tipo_doc`,
       a.`nro_doc`,
       dp.`fecha_asociacion`,
       CASE
         WHEN d.`id_afiliado` IS NULL                 THEN 'Denuncia sin afiliado: completar el accidentado; el tope no se puede resolver por documento'
         WHEN a.`id_afiliado` IS NULL                 THEN 'id_afiliado apunta a un afiliado inexistente: revisar la denuncia'
         WHEN a.`nro_doc` IS NULL OR a.`nro_doc` = '' THEN 'Afiliado sin nro_doc: completar el documento'
         ELSE 'Falta cargar el tope de este asegurado en polizas_ap_topes (ventana ANUAL)'
       END                                            AS que_falta
  FROM `cs`.`denuncia_poliza` dp
  JOIN `cs`.`denuncias` d      ON d.`id_denuncia` = dp.`id_denuncia`
  LEFT JOIN `cs`.`afiliados` a ON a.`id_afiliado` = d.`id_afiliado`
  LEFT JOIN `cs`.`polizas_ap` p ON p.`id_poliza` = dp.`id_poliza`
 WHERE dp.`activo` = 1
   AND dp.`suma_asegurada` IS NULL
 ORDER BY (d.`id_afiliado` IS NULL) DESC, dp.`id_poliza`, dp.`id_denuncia`;

-- 4.C Desincronizados: el vínculo tiene tope resuelto pero la fila de origen cambió
--     después (edición o ampliación). Éste es el control que justifica `id_tope`.
--     Requiere V32 aplicada. Devuelve las candidatas al UPDATE del paso 3.4.
-- SELECT dp.`id_denuncia_poliza`, dp.`id_denuncia`, d.`nro_asignado`, dp.`id_tope`,
--        dp.`suma_asegurada` AS suma_denormalizada,
--        t.`suma_asegurada`  AS suma_vigente,
--        dp.`moneda`         AS moneda_denormalizada,
--        t.`moneda`          AS moneda_vigente,
--        dp.`ventana`        AS ventana_denormalizada,
--        t.`ventana`         AS ventana_vigente,
--        dp.`iva_incluido`   AS iva_denormalizado,
--        t.`iva_incluido`    AS iva_vigente,
--        dp.`fecha_resolucion_tope`,
--        t.`activo`          AS tope_sigue_activo
--   FROM `cs`.`denuncia_poliza` dp
--   JOIN `cs`.`denuncias` d ON d.`id_denuncia` = dp.`id_denuncia`
--   LEFT JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = dp.`id_tope`
--  WHERE dp.`activo` = 1
--    AND dp.`suma_asegurada` IS NOT NULL
--    AND (t.`id_tope` IS NULL                          -- el tope de origen desapareció
--         OR t.`activo` <> 1                           -- o fue dado de baja
--         OR t.`suma_asegurada` <> dp.`suma_asegurada`  -- o el monto cambió
--         OR t.`moneda`       <> dp.`moneda`
--         OR t.`ventana`      <> dp.`ventana`           -- o le cambiaron la ventana
--         OR t.`iva_incluido` <> dp.`iva_incluido`      -- o el criterio de IVA
--         OR dp.`ventana`      IS NULL                  -- o quedó a medio resolver
--         OR dp.`iva_incluido` IS NULL);


-- -----------------------------------------------------------------------------
-- 5. VERIFICACIÓN del DDL (read-only) — correr después del ALTER
-- -----------------------------------------------------------------------------
-- Debe devolver exactamente 6 filas: `moneda` con COLUMN_DEFAULT = 'ARS' e
-- IS_NULLABLE = 'NO'; las otras cinco IS_NULLABLE = 'YES' y COLUMN_DEFAULT NULL.
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `IS_NULLABLE`, `COLUMN_DEFAULT`, `COLLATION_NAME`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'denuncia_poliza'
   AND `COLUMN_NAME` IN ('suma_asegurada', 'moneda', 'id_tope', 'fecha_resolucion_tope',
                         'ventana', 'iva_incluido')
 ORDER BY `ORDINAL_POSITION`;

-- Las 73 filas preexistentes deben quedar: suma_asegurada NULL, id_tope NULL,
-- fecha_resolucion_tope NULL, ventana NULL, iva_incluido NULL, moneda 'ARS'.
-- `irresolubles_sin_afiliado` se cuenta APARTE (esperado: 3): son denuncias sin
-- accidentado, no una falla del proceso. `pendientes_carga_tope` es el número que negocio
-- tiene que llevar a 0 cargando topes en polizas_ap_topes.
SELECT COUNT(*)                                                  AS total_activas,
       SUM(dp.`suma_asegurada` IS NULL)                           AS sin_tope,
       SUM(dp.`id_tope` IS NULL)                                  AS sin_id_tope,
       SUM(dp.`fecha_resolucion_tope` IS NULL)                    AS sin_fecha,
       SUM(dp.`ventana` IS NULL)                                  AS sin_ventana,
       SUM(dp.`iva_incluido` IS NULL)                             AS sin_iva,
       SUM(dp.`moneda` = 'ARS')                                   AS en_pesos,
       SUM(dp.`suma_asegurada` IS NULL AND d.`id_afiliado` IS NULL)     AS irresolubles_sin_afiliado,
       SUM(dp.`suma_asegurada` IS NULL AND d.`id_afiliado` IS NOT NULL) AS pendientes_carga_tope
  FROM `cs`.`denuncia_poliza` dp
  JOIN `cs`.`denuncias` d ON d.`id_denuncia` = dp.`id_denuncia`
 WHERE dp.`activo` = 1;
-- Baseline esperado inmediatamente después del ALTER (sin backfill):
--   total_activas 73 · sin_tope 73 · sin_ventana 73 · sin_iva 73 · en_pesos 73
--   irresolubles_sin_afiliado 3 · pendientes_carga_tope 70


-- -----------------------------------------------------------------------------
-- 6. ROLLBACK (comentado)
-- -----------------------------------------------------------------------------
-- Es un DROP de columnas AGREGADAS por este script: no hay pérdida de datos
-- preexistentes. Sí se pierden los topes ya resueltos por el backfill, que se
-- reconstruyen volviendo a correr el bloque 3 (los topes de origen viven en
-- `polizas_ap_topes`, que este rollback no toca).
--
-- ALTER TABLE `cs`.`denuncia_poliza`
--   DROP COLUMN IF EXISTS `iva_incluido`,
--   DROP COLUMN IF EXISTS `ventana`,
--   DROP COLUMN IF EXISTS `fecha_resolucion_tope`,
--   DROP COLUMN IF EXISTS `id_tope`,
--   DROP COLUMN IF EXISTS `moneda`,
--   DROP COLUMN IF EXISTS `suma_asegurada`;
--
-- Si además se creó el índice opcional del bloque 2:
-- ALTER TABLE `cs`.`denuncia_poliza` DROP INDEX IF EXISTS `idx_denuncia_poliza_tope`;
-- =============================================================================

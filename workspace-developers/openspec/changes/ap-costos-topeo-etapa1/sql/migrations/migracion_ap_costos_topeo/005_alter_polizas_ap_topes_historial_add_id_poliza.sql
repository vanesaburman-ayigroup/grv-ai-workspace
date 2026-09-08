-- =============================================================================
-- V36 - ALTER TABLE `cs`.`polizas_ap_topes_historial` — historial del TOPE GENERAL
-- =============================================================================
-- Fecha: 2026-08-10
-- Repo destino: wsmesacarga  →  src/main/resources/sql/V36__ALTER_polizas_ap_topes_historial_ADD_id_poliza.sql
--               (convención LOCAL de ese repo: `V<N>__<DESCRIPCION>.sql`, sin subcarpeta
--                `migrations/`. Último número tomado por este change: V35.)
-- Change OpenSpec: `ap-costos-topeo-etapa1` (AP Costos y Topeo, etapa 1)
-- Ticket Jira: PENDIENTE — todavía no existe el ticket. Al crearlo, reemplazar este
--              placeholder por el GRV-NNNN acá y en V32/V33/V34/V35.
-- Depende de: V33 (crea la tabla) y V35 (crea `polizas_ap.suma_asegurada`, el dato que
--             este historial pasa a versionar). Sin V33 falla con «table doesn't exist».
--
-- ⚠ LA MISMA COLISIÓN DE NUMERACIÓN QUE V32-V35 — leer el README del paquete antes de
-- commitear este archivo en el repo. Si se decide renumerar los archivos de AP, este se
-- mueve con ellos. No renumerar por iniciativa propia.
--
-- POR QUÉ (no el qué)
-- V35 puso el TOPE GENERAL en `polizas_ap.suma_asegurada` y lo declaró **obligatorio en el
-- alta**. Falta la otra mitad del ciclo de vida: ese tope **se edita**. Una póliza vigente a
-- la que negocio le corrige el monto (se transcribió mal) o se lo amplía (el cliente autorizó
-- más cobertura) mueve el denominador del semáforo de **todos** los asegurados de esa póliza
-- de una sola vez — es justamente la contracara del modelo de dos niveles: una edición del
-- general tiene mucho más alcance que una edición de una excepción.
--
-- Y `polizas_ap` **no tiene historial propio**: no hay `polizas_ap_historial`, ni columnas de
-- versionado, ni triggers. Sin esta migración, editar el tope general sería un `UPDATE` que
-- borra el monto anterior y no deja quién, cuándo ni con qué autorización. Es exactamente la
-- pregunta que V33 existe para contestar sobre las excepciones («¿quién amplió este tope,
-- cuándo y con qué autorización?»), y que hoy quedaría sin respuesta en el nivel que MÁS
-- casos afecta.
--
-- POR QUÉ SE REUSA `polizas_ap_topes_historial` Y NO SE CREA UNA TABLA NUEVA
-- Se evaluaron las dos y se eligió reusar, por tres razones concretas:
--   1. Los seis atributos que hay que versionar son **los mismos**: suma, ventana, IVA, con el
--      mismo criterio de NULL («este atributo no participó del cambio»), el mismo `motivo`
--      NOT NULL y el mismo vocabulario de `tipo_cambio`. Una tabla nueva sería esta tabla
--      copiada, y el criterio de los NULL —que es lo delicado— quedaría escrito dos veces con
--      dos oportunidades de divergir.
--   2. La pregunta que se hace negocio es «¿cómo se movió el tope de ESTE asegurado?», y la
--      respuesta cruza los dos niveles: primero lo cubría el general de 5.000.000, después se
--      le cargó una excepción de 8.000.000. Con dos tablas eso es un UNION que alguien tiene
--      que acordarse de escribir; con una, es un `ORDER BY fecha_alta`.
--   3. La tabla es append-only y no tiene FKs (criterio del ecosistema), así que admitir un
--      segundo tipo de fila no rompe ninguna integridad declarada.
--
-- CÓMO SE DISTINGUE UNA FILA DE CADA NIVEL — esto es el contrato, no un detalle
--     id_tope IS NOT NULL  AND id_poliza IS NULL      →  cambio de una EXCEPCIÓN (V32/V33)
--     id_tope IS NULL      AND id_poliza IS NOT NULL  →  cambio del TOPE GENERAL (V35)
-- Por eso `id_tope` pasa a ser NULL-able y aparece `id_poliza`. El CHECK del bloque 3 impide
-- la única combinación sin sentido (las dos nulas): una fila de historial que no dice de qué
-- tope habla no es evidencia de nada.
--
-- ⚠ POR QUÉ **NO** SE POBLA `id_poliza` EN LAS FILAS DE EXCEPCIÓN NUEVAS
-- Sería redundante y peor: la póliza de una excepción ya está en `polizas_ap_topes.id_poliza`,
-- que es el dueño del dato. Copiarla acá abre la posibilidad de que las dos difieran y de que
-- alguien lea la copia vieja. El backfill del bloque 4 **sí** la completa para las filas
-- históricas, pero como conveniencia de lectura y de una sola vez; el servicio de excepciones
-- (`wsaccidentespersonales`) sigue insertando `id_poliza` NULL, y eso es lo correcto.
-- Consecuencia deliberada: `id_poliza IS NOT NULL` NO alcanza para identificar una fila del
-- general — la condición es `id_tope IS NULL`. Ver la vista de lectura del bloque 6.
--
-- IMPACTO EN `wsaccidentespersonales` — nulo, verificado contra el código
-- Su entidad `PolizaApTopeHistorial` mapea `@Column(name = "id_tope", nullable = false)`, pero
-- `nullable=false` en JPA sólo afecta la generación de DDL (que este ecosistema no usa) y el
-- pre-chequeo de Hibernate al insertar ESA entidad — que siempre setea `idTope` desde
-- `TopeApHistorialAsentador.base()`. Relajar la columna en la base no cambia nada de eso.
-- Sus tres consultas (`buscarCambiosDeVentana`, `buscarCambiosDeIva`, `existsByIdTope`) y el
-- endpoint `GET /topes/{idTope}/historial` filtran por `h.idTope = :idTope`, así que **no
-- devuelven** las filas del general. Es lo correcto: ese endpoint es el historial de UNA
-- excepción. El historial del general se lee por `id_poliza` (bloque 6).
--
-- ALCANCE
-- Un `MODIFY` que relaja una columna, una columna nueva, un índice, un CHECK y un backfill
-- derivable. **No se pierde ni se reescribe ningún dato existente**: el `MODIFY` sólo permite
-- NULL donde antes no se permitía (ninguna fila actual tiene NULL, así que no hay conversión),
-- y el backfill escribe una columna que acaba de nacer.
--
-- REQUISITOS
-- - MariaDB 10.0+ (`ADD COLUMN IF NOT EXISTS`, `DROP CONSTRAINT IF EXISTS`). Sobre 10.5.29.
-- - V33 aplicada. V35 aplicada (si no, el historial versiona un dato que no existe todavía).
--
-- NO SE DECLARAN FOREIGN KEYS
-- Criterio del ecosistema (V32/V33/V34/V35). `id_poliza` es una relación **lógica** a
-- `polizas_ap.id_poliza`, igual que `id_tope` lo es a `polizas_ap_topes.id_tope`.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. `id_tope` pasa a NULL-able
-- -----------------------------------------------------------------------------
-- Es un `MODIFY`, no un `ADD`: **no es idempotente por sintaxis pero sí por efecto** —
-- re-correrlo deja la columna igual (MariaDB no falla al re-declarar la misma definición).
-- Se repite el COMMENT completo a propósito: un `MODIFY COLUMN` sin `COMMENT` **borra** el
-- comentario que dejó V33. Al comentario original se le agrega la nueva regla de lectura.
--
-- ⚠ El `MODIFY` es un ALTER de tipo COPY en MariaDB 10.5 (relajar NOT NULL no es INSTANT).
-- Con la tabla chica (7 filas en stage, 0 en dev y en prod al aplicar el paquete) es
-- instantáneo. Si algún día esta tabla creció, correrlo en ventana: bloquea escrituras.

ALTER TABLE `cs`.`polizas_ap_topes_historial`
  MODIFY COLUMN `id_tope` INT(11) NULL
    COMMENT 'Tope al que pertenece el cambio. Logico -> polizas_ap_topes.id_tope (sin FK). NULL = el cambio NO es de una excepcion sino del TOPE GENERAL de la poliza (polizas_ap.suma_asegurada, V35); en ese caso id_poliza dice de que poliza. Discriminador de nivel: id_tope IS NULL -> general, id_tope IS NOT NULL -> excepcion.';


-- -----------------------------------------------------------------------------
-- 2. `id_poliza` — de qué póliza es el cambio del tope general
-- -----------------------------------------------------------------------------
-- Se agrega AL FINAL (sin `AFTER id_tope`, que sería más lindo de leer en un DESCRIBE) para
-- habilitar ALGORITHM=INSTANT. Mismo criterio que V35: no se fuerza el algoritmo explícito
-- porque haría fallar el script entero en un motor que no lo soporte.
--
-- POR QUÉ NULL-able y no `NOT NULL DEFAULT 0`: un `0` sería una póliza inexistente
-- indistinguible de «no aplica», y las filas de excepción legítimamente no tienen que
-- llenarla (ver el banner). NULL acá significa «esta fila no habla del tope general».

ALTER TABLE `cs`.`polizas_ap_topes_historial`
  ADD COLUMN IF NOT EXISTS `id_poliza` INT(11) NULL
    COMMENT 'Poliza cuyo TOPE GENERAL cambio. Logico -> polizas_ap.id_poliza (sin FK). Se completa SOLO en las filas del general (id_tope NULL). En las filas de excepcion queda NULL a proposito: la poliza de una excepcion es dato de polizas_ap_topes.id_poliza y copiarla aca permitiria que difieran. EXCEPCION: el backfill de V36 la completo de una sola vez en las filas historicas por comodidad de lectura, asi que id_poliza NOT NULL NO identifica una fila del general: la condicion es id_tope IS NULL.';


-- -----------------------------------------------------------------------------
-- 3. CHECK de alcance — **NO es idempotente. Leer antes de correr.**
-- -----------------------------------------------------------------------------
-- POR QUÉ: una fila con las dos columnas en NULL no dice de qué tope habla. No rompe ninguna
-- consulta —simplemente no la devuelve ninguna— y por eso es peor que un error: es evidencia
-- que se perdió en silencio. El CHECK convierte ese bug en un fallo al insertar.
--
-- No se exige lo inverso (que NO estén las dos completas) a propósito: el backfill del
-- bloque 4 deja justamente filas de excepción con las dos, y es correcto.
--
-- ⚠ MariaDB 10.5 no tiene `ADD CONSTRAINT IF NOT EXISTS`. En una SEGUNDA corrida el 3.B falla
-- con `ERROR 1826: Duplicate CHECK constraint name`. Igual que en V35, ese error es el
-- resultado ESPERADO de re-correr y no deja nada a medias. Para no depender de leerlo, correr
-- primero el 3.A.

-- 3.A Pre-chequeo. 0 = el CHECK no existe (correr el 3.B) · 1 = ya está (saltear el 3.B).
SELECT COUNT(*) AS check_ya_existe
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap_topes_historial'
   AND `CONSTRAINT_NAME`   = 'ck_polizas_ap_topes_hist_alcance';

-- 3.B El CHECK. Saltear si el 3.A devolvió 1.
ALTER TABLE `cs`.`polizas_ap_topes_historial`
  ADD CONSTRAINT `ck_polizas_ap_topes_hist_alcance`
      CHECK (`id_tope` IS NOT NULL OR `id_poliza` IS NOT NULL);


-- -----------------------------------------------------------------------------
-- 4. BACKFILL de `id_poliza` en las filas de excepción ya existentes
-- -----------------------------------------------------------------------------
-- ⚠ ESTE ES EL ÚNICO BLOQUE QUE ESCRIBE DATOS. Es enteramente **derivable** —sale de
-- `polizas_ap_topes.id_poliza`, que es el dueño— así que no inventa nada y es re-corrible.
-- Es lo contrario del backfill de V35, que NO existe porque el tope general no se deduce de
-- ninguna parte.
--
-- POR QUÉ correrlo si el banner dice que las filas de excepción no necesitan `id_poliza`:
-- para que la consulta «todo lo que le pasó al tope de esta póliza, los dos niveles juntos»
-- (bloque 6.B) se pueda escribir con un `WHERE id_poliza = ?` en vez de un OR con subquery.
-- Es comodidad de lectura, no corrección de un dato faltante. **Saltearlo no rompe nada.**
--
-- 4.A Dry-run: cuántas filas va a tocar y con qué valor. Ninguna debería quedar sin póliza;
--     si `sin_poliza_resoluble` > 0 hay filas de historial cuyo tope ya no existe (la tabla
--     es append-only pero `polizas_ap_topes` no lo es del todo: nadie borra, pero pudo
--     haberse limpiado a mano en un ambiente bajo). Ésas se dejan como están.
SELECT COUNT(*)                            AS filas_a_actualizar,
       SUM(t.`id_poliza` IS NULL)          AS sin_poliza_resoluble,
       COUNT(DISTINCT t.`id_poliza`)       AS polizas_distintas
  FROM `cs`.`polizas_ap_topes_historial` h
  LEFT JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = h.`id_tope`
 WHERE h.`id_tope`   IS NOT NULL
   AND h.`id_poliza` IS NULL;
-- Baseline esperado el 10/08/2026: stage 7 filas / 0 sin resolver / 1 póliza (983320, los
-- datos de prueba del change). dev 0 filas. Producción 0 filas (la tabla está vacía).

-- 4.B El UPDATE. Va dentro de una transacción a propósito: es la única escritura del script.
START TRANSACTION;

UPDATE `cs`.`polizas_ap_topes_historial` h
  JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = h.`id_tope`
   SET h.`id_poliza` = t.`id_poliza`
 WHERE h.`id_tope`   IS NOT NULL
   AND h.`id_poliza` IS NULL;

-- Verificar que el conteo de filas afectadas coincida con `filas_a_actualizar` del 4.A y
-- ENTONCES confirmar. Si no coincide, ROLLBACK y revisar.
COMMIT;
-- ROLLBACK;  -- ← usar éste en su lugar si el conteo no cerró


-- -----------------------------------------------------------------------------
-- 5. ÍNDICE para leer el historial del general
-- -----------------------------------------------------------------------------
-- V33 dejó `idx_polizas_ap_topes_hist_tope_fecha (id_tope, fecha_alta)`, que no sirve para
-- buscar por póliza. El acceso nuevo es «el historial del tope general de la póliza N,
-- cronológico», que es un `WHERE id_poliza = ? ORDER BY fecha_alta`: la columna de filtro y
-- la de orden en el mismo índice evitan el filesort.
--
-- Sí se crea, a diferencia de V35 que decidió no crear ninguno, y no es incoherente: allá la
-- tabla tiene 30 filas y el motor llega por PK; acá la tabla es append-only y **crece con cada
-- edición de cada tope** (es la que va a tener más filas del paquete), y el drawer de la
-- pantalla la consulta por póliza en caliente.
--
-- `CREATE INDEX IF NOT EXISTS` existe en MariaDB 10.0+: idempotente de verdad.
CREATE INDEX IF NOT EXISTS `idx_polizas_ap_topes_hist_poliza_fecha`
    ON `cs`.`polizas_ap_topes_historial` (`id_poliza`, `fecha_alta`);


-- -----------------------------------------------------------------------------
-- 6. CONSULTAS DE LECTURA (read-only) — cómo se lee cada nivel
-- -----------------------------------------------------------------------------
-- 6.A Historial del TOPE GENERAL de una póliza. Es lo que muestra el drawer de la pantalla
--     de la póliza. Ojo con el `id_tope IS NULL`: sin él, y después del backfill del bloque 4,
--     esta consulta devolvería también los cambios de las excepciones de esa póliza.
SELECT h.`id_historial`, h.`fecha_alta`, h.`tipo_cambio`,
       h.`suma_anterior`, h.`suma_nueva`,
       h.`ventana_anterior`, h.`ventana_nueva`,
       h.`iva_incluido_anterior`, h.`iva_incluido_nuevo`,
       h.`motivo`, h.`usuario_alta`
  FROM `cs`.`polizas_ap_topes_historial` h
 WHERE h.`id_poliza` = /* :idPoliza */ 46
   AND h.`id_tope`   IS NULL
 ORDER BY h.`fecha_alta` DESC, h.`id_historial` DESC;

-- 6.B Los DOS niveles juntos, cronológico: cómo se movió la cobertura de esta póliza, tanto
--     por el general como por las excepciones de sus asegurados. Es la razón nº 2 del banner
--     para no haber creado una tabla aparte, y la que aprovecha el backfill del bloque 4.
SELECT CASE WHEN h.`id_tope` IS NULL THEN 'GENERAL' ELSE 'EXCEPCION' END AS nivel,
       h.`id_tope`, t.`nro_doc`,
       h.`fecha_alta`, h.`tipo_cambio`, h.`suma_anterior`, h.`suma_nueva`,
       h.`motivo`, h.`usuario_alta`
  FROM `cs`.`polizas_ap_topes_historial` h
  LEFT JOIN `cs`.`polizas_ap_topes` t ON t.`id_tope` = h.`id_tope`
 WHERE h.`id_poliza` = /* :idPoliza */ 46
 ORDER BY h.`fecha_alta` DESC, h.`id_historial` DESC;

-- 6.C Control de integridad lógica: pólizas CON tope general cargado y SIN ninguna fila de
--     historial del general. Debería dar 0. Si da > 0, ese tope se cargó con un `UPDATE`
--     suelto en vez de por pantalla — o sea, sin motivo y sin quién.
--     ⚠ Va a dar > 0 en stage para los 4 topes generales de prueba que se cargaron a mano el
--     10/08/2026 (pólizas 28, 45, 46, 52). Es esperado: se cargaron con SQL, antes de que
--     existiera el endpoint. En producción tiene que dar 0.
SELECT p.`id_poliza`, p.`poliza`, p.`razon_social`, p.`suma_asegurada`
  FROM `cs`.`polizas_ap` p
 WHERE p.`suma_asegurada` IS NOT NULL
   AND NOT EXISTS (
        SELECT 1 FROM `cs`.`polizas_ap_topes_historial` h
         WHERE h.`id_poliza` = p.`id_poliza`
           AND h.`id_tope`   IS NULL)
 ORDER BY p.`id_poliza`;


-- -----------------------------------------------------------------------------
-- 7. VERIFICACIÓN del DDL (read-only) — correr después de los bloques 1-5
-- -----------------------------------------------------------------------------
-- 7.A Las dos columnas. Debe devolver:
--     id_tope    int(11) | YES | NULL   ← si dice NO, el MODIFY del bloque 1 no corrió
--     id_poliza  int(11) | YES | NULL
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `IS_NULLABLE`, `COLUMN_DEFAULT`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial'
   AND `COLUMN_NAME` IN ('id_tope', 'id_poliza')
 ORDER BY `ORDINAL_POSITION`;

-- 7.B Los CHECK. Deben ser 2: `ck_polizas_ap_topes_hist_motivo_no_vacio` (V33) y
--     `ck_polizas_ap_topes_hist_alcance` (éste). Si falta el segundo, se salteó el 3.B.
SELECT `CONSTRAINT_NAME`, `CHECK_CLAUSE`
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap_topes_historial'
 ORDER BY `CONSTRAINT_NAME`;

-- 7.C El índice nuevo: 2 filas, NON_UNIQUE = 1, en orden id_poliza / fecha_alta.
SELECT `INDEX_NAME`, `NON_UNIQUE`, `SEQ_IN_INDEX`, `COLUMN_NAME`
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes_historial'
   AND `INDEX_NAME`   = 'idx_polizas_ap_topes_hist_poliza_fecha'
 ORDER BY `SEQ_IN_INDEX`;

-- 7.D Estado de los datos. `huerfanas` tiene que ser 0 SIEMPRE: es la combinación que el
--     CHECK del bloque 3 prohíbe. Si da > 0, el CHECK no está puesto y ya entraron filas
--     inservibles.
SELECT COUNT(*)                                                        AS total_filas,
       SUM(`id_tope` IS NOT NULL)                                      AS de_excepcion,
       SUM(`id_tope` IS NULL AND `id_poliza` IS NOT NULL)              AS del_tope_general,
       SUM(`id_tope` IS NOT NULL AND `id_poliza` IS NOT NULL)          AS excepcion_con_poliza_backfilleada,
       SUM(`id_tope` IS NULL AND `id_poliza` IS NULL)                  AS huerfanas
  FROM `cs`.`polizas_ap_topes_historial`;
-- Baseline esperado el 10/08/2026, recién aplicado V36 (antes de usar el endpoint):
--   STAGE: total 7 · de_excepcion 7 · del_tope_general 0 · backfilleadas 7 · huerfanas 0
--   DEV:   total 0 en todo
--   PROD:  total 0 en todo

-- 7.E La prueba que no miente: inserta una fila del general y la borra, dentro de una
--     transacción con ROLLBACK. Prueba que `id_tope` NULL entra de verdad (o sea que el
--     bloque 1 corrió) y que el CHECK del bloque 3 no la rechaza. No deja datos.
START TRANSACTION;
INSERT INTO `cs`.`polizas_ap_topes_historial`
       (`id_tope`, `id_poliza`, `suma_anterior`, `suma_nueva`, `ventana_nueva`,
        `iva_incluido_nuevo`, `motivo`, `tipo_cambio`, `usuario_alta`)
VALUES (NULL, 1, NULL, 1.00, 'ANUAL', 1, 'PRUEBA V36 - se revierte', 'ALTA', NULL);
SELECT ROW_COUNT() AS inserto_ok;  -- ESPERADO: 1
ROLLBACK;

-- 7.F Contraprueba del CHECK: esto DEBE fallar con
--     `ERROR 4025: CONSTRAINT 'ck_polizas_ap_topes_hist_alcance' failed`.
--     Si entra sin error, el CHECK no está puesto. Descomentar sólo para verificar.
-- START TRANSACTION;
-- INSERT INTO `cs`.`polizas_ap_topes_historial`
--        (`id_tope`, `id_poliza`, `suma_nueva`, `motivo`, `tipo_cambio`)
-- VALUES (NULL, NULL, 1.00, 'PRUEBA V36 - debe fallar', 'ALTA');
-- ROLLBACK;


-- -----------------------------------------------------------------------------
-- 8. ROLLBACK (comentado)
-- -----------------------------------------------------------------------------
-- ⚠ ESTE ROLLBACK **DESTRUYE EVIDENCIA**, y es el punto de toda la migración: el
-- `DROP COLUMN id_poliza` borra el historial del tope general —quién lo cargó, cuándo, con qué
-- motivo y desde qué monto—, y no se reconstruye de ninguna parte (`polizas_ap` no tiene
-- historial propio; eso es lo que V36 vino a resolver). Las filas quedarían con `id_tope` NULL
-- y sin decir de qué póliza hablan, o sea inservibles. Respaldar ANTES, siempre:
--
-- CREATE TABLE `cs`.`polizas_ap_topes_historial_respaldo_v36` AS
--   SELECT * FROM `cs`.`polizas_ap_topes_historial`;
--
-- Orden obligado: primero el CHECK (dropear una columna con un CHECK vivo encima falla),
-- después las filas del general (si quedan, el `MODIFY` a NOT NULL falla), después la columna,
-- y recién al final volver `id_tope` a NOT NULL.
--
-- ALTER TABLE `cs`.`polizas_ap_topes_historial`
--   DROP CONSTRAINT IF EXISTS `ck_polizas_ap_topes_hist_alcance`;
--
-- DROP INDEX IF EXISTS `idx_polizas_ap_topes_hist_poliza_fecha`
--   ON `cs`.`polizas_ap_topes_historial`;
--
-- -- Esto borra la evidencia. Que sea explícito y no un efecto colateral del MODIFY.
-- DELETE FROM `cs`.`polizas_ap_topes_historial` WHERE `id_tope` IS NULL;
--
-- ALTER TABLE `cs`.`polizas_ap_topes_historial`
--   DROP COLUMN IF EXISTS `id_poliza`,
--   MODIFY COLUMN `id_tope` INT(11) NOT NULL
--     COMMENT 'Tope al que pertenece el cambio. Lógico -> polizas_ap_topes.id_tope (sin FK)';
-- =============================================================================

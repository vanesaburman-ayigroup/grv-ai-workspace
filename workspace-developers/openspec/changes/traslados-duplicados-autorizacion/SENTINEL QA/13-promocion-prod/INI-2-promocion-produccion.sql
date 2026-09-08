-- =============================================================================================
--  INI-2 · Autorizacion de traslados duplicados del mismo dia
--  PROMOCION A PRODUCCION — script unico de base de datos
-- =============================================================================================
--
--  Autor : Vanesa Yanina Burman — Lider Tecnica
--  Fecha : 24/08/2026 (regenerado)
--
--  QUE HACE, en orden:
--    0. Preflight: fotografia del estado actual. NO modifica nada.
--    1. DDL  — la tabla del pedido y las dos columnas de marca.        [commit implicito]
--    2. DDL  — la columna de 'visto' del solicitante.                 [commit implicito]
--    3. DML  — el permiso y su asignacion por perfil.                 [transaccional]
--    4. SP   — los cuatro stored procedures del listado.              [DROP + CREATE]
--    5. Verificaciones finales.
--    6. Rollback, comentado.
--
--  ORDEN NO NEGOCIABLE: la base va ANTES del despliegue de los servicios. El mapeo por
--  `resultClasses` de Hibernate exige que el SP devuelva TODAS las columnas mapeadas, asi
--  que con el codigo nuevo contra el SP viejo la pantalla ROMPE. Al reves no: el SP nuevo
--  contra el codigo viejo devuelve columnas de mas, que se ignoran.
--
--  VENTANA SIN PROCEDURE: MariaDB no tiene CREATE OR REPLACE PROCEDURE, asi que el bloque 4
--  hace DROP + CREATE y deja unos segundos sin el procedimiento. Correr en horario de bajo
--  trafico de logistica, y guardar antes el cuerpo previo (bloque 0.5).
--
--  IDEMPOTENTE: se puede correr mas de una vez. El DDL usa IF NOT EXISTS, el DML usa
--  NOT EXISTS y los SP se recrean.
--
--  PERFILES QUE LLEVAN EL PERMISO EN PRODUCCION — decision de negocio del 21/08/2026:
--    · referente_siniestros
--    · jefe_de_siniestros
--  DIFERENCIA CON LOS AMBIENTES BAJOS: en DEV y TEST el permiso esta tambien en
--  `gerente_de_siniestros` y `supervisor`. En produccion NO. Si despues se decide
--  sumarlos, se agregan al IN del bloque 3.2 y se vuelve a correr: es idempotente.
--
--  FUENTE DE LOS CUERPOS DE LOS SP — leidos de `origin/promo/INI-2-prod`, la rama que va a master:
--    · wsturnos     6e64f4b 2026-08-24
--    · wslogistica  320a48d 2026-08-24
-- =============================================================================================

USE cs;

-- =============================================================================================
-- 0. PREFLIGHT — correr y LEER antes de seguir. No modifica nada.
-- =============================================================================================

-- 0.1 La tabla del pedido, ¿ya existe? (esperado en una promocion limpia: 0)
SELECT COUNT(*) AS tabla_ya_existe
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'autorizaciones_traslado_duplicado';

-- 0.2 Las columnas de marca, ¿ya existen? (esperado: 0 filas)
SELECT TABLE_NAME, COLUMN_NAME
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'cs'
   AND COLUMN_NAME IN ('es_duplicado_autorizado', 'fecha_visto_solicitante');

-- 0.3 El permiso, ¿ya existe? (esperado: 0 filas)
SELECT id_permiso, permiso, activo FROM cs.permisos_sas
 WHERE permiso = 'autorizar_traslado_mismo_dia';

-- 0.4 CLAVE — que id le va a tocar al permiso, y que hay ocupando el espacio.
--     El script NO fija el id: toma MAX+1. Esta consulta es para saber cual sera.
--     Al 21/08/2026 en produccion MAX(id_permiso) = 101 (`editar_cie10_bloqueado`),
--     asi que el permiso nuevo deberia quedar en 102.
SELECT MAX(id_permiso) AS max_actual, MAX(id_permiso) + 1 AS id_que_tomara,
       COUNT(*) AS total_permisos
  FROM cs.permisos_sas;

-- 0.5 OBLIGATORIO — respaldo del cuerpo previo de los cuatro SP.
--
--     HACERLO CON mysqldump, NO con SHOW CREATE PROCEDURE. La salida de SHOW no es
--     restaurable tal cual: viene sin `DELIMITER`, el cliente la trunca, y no trae el
--     sql_mode con el que el procedure fue creado. Es el unico rollback del bloque 4, asi
--     que tiene que ser un archivo que se pueda volver a aplicar.
--
--       mysqldump -h <host> -u <user> -p --no-data --no-create-info --routines \
--                 --skip-triggers cs > respaldo_sp_cs_$(date +%Y%m%d_%H%M).sql
--
--     Y verificar que el archivo contenga los cuatro:
--       grep -c 'CREATE.*PROCEDURE' respaldo_sp_cs_*.sql
--
--     Estas cuatro consultas quedan sólo para dejar constancia de que existian y con que
--     definer y sql_mode. NO son el respaldo.
SHOW CREATE PROCEDURE cs.consulta_turnos_tramitadores_sp;
SHOW CREATE PROCEDURE cs.consulta_traslado_remis_amb_logistica;
SHOW CREATE PROCEDURE cs.consulta_traslados_aereos_logistica;
SHOW CREATE PROCEDURE cs.consulta_traslados_internos_logistica;

-- 0.6 Los perfiles a los que se va a asignar el permiso, ¿existen con ese nombre?
--     Si alguno no aparece, el CROSS JOIN del bloque 3.2 no le asigna nada y no avisa.
SELECT id_perfil, perfil FROM cs.perfiles_sas
 WHERE perfil IN ('referente_siniestros', 'jefe_de_siniestros');

-- =============================================================================================
-- 1. DDL — la tabla del pedido y las columnas de marca          [COMMIT IMPLICITO, no revierte]
-- =============================================================================================

-- OJO: en MariaDB el DDL hace commit implicito y NO se revierte con ROLLBACK. Para
-- deshacerlo hay que correr el bloque 6.

CREATE TABLE IF NOT EXISTS `autorizaciones_traslado_duplicado`
(
    `id_autorizacion_traslado_duplicado` INT(11)       NOT NULL AUTO_INCREMENT,

    -- La autorización del turno que se está cargando. Es el ancla: por ahí se llega al turno, al
    -- paciente y a la fecha.
    `id_autorizacion`                    INT(11)       NOT NULL,

    -- El traslado que espera la excepción. Nullable porque el pedido se registra en el mismo
    -- momento en que se crea el traslado y el orden de inserción puede variar; y son dos columnas
    -- porque el duplicado puede ser de transporte público, siguiendo el patrón de
    -- `traslados_agencias_historico`.
    `id_traslado`                        INT(11)       DEFAULT NULL,
    `id_traslado_transporte_publico`     INT(11)       DEFAULT NULL,

    -- 1 pendiente, 2 aprobada, 3 rechazada. Mismos códigos que `estados_autorizaciones` para no
    -- introducir un vocabulario nuevo, pero sin depender de ese catálogo.
    `estado`                             INT(11)       NOT NULL DEFAULT 1,

    -- Por qué el gestor necesita los dos traslados. Es lo único que lee quien autoriza, y el
    -- filtro real contra el pedido hecho por las dudas.
    `justificacion`                      VARCHAR(1000) NOT NULL,

    `id_solicitante`                     INT(11)       NOT NULL,
    `fecha_solicitud`                    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `id_autorizante`                     INT(11)       DEFAULT NULL,
    `fecha_autorizacion`                 DATETIME      DEFAULT NULL,

    -- Motivo del rechazo. Vuelve al gestor, así que no puede quedar sólo en un log.
    `dictamen`                           VARCHAR(1000) DEFAULT NULL,

    PRIMARY KEY (`id_autorizacion_traslado_duplicado`),

    -- La grilla del que autoriza y el contador de la card filtran por estado.
    KEY `idx_atd_estado` (`estado`),
    KEY `idx_atd_autorizacion` (`id_autorizacion`),
    KEY `idx_atd_traslado` (`id_traslado`),

    CONSTRAINT `fk_atd_autorizacion` FOREIGN KEY (`id_autorizacion`)
        REFERENCES `autorizaciones` (`id_autorizacion`),
    CONSTRAINT `fk_atd_traslado` FOREIGN KEY (`id_traslado`)
        REFERENCES `traslados` (`id_traslado`),
    CONSTRAINT `fk_atd_traslado_tp` FOREIGN KEY (`id_traslado_transporte_publico`)
        REFERENCES `traslados_transporte_publico` (`id_traslado`)
) ENGINE = InnoDB;

-- =============================================================================================
-- 2. traslados — la marca que ve logística                     [DDL · no transaccional]
-- =============================================================================================

-- Flag denormalizado, al solo efecto de que el SP del listado de logística lo devuelva sin
-- joinear a la tabla nueva. `consulta_traslado_remis_amb_logistica` es el SP más caliente del
-- flujo, así que se le agrega una columna al SELECT y nada más. Mismo criterio que
-- `requiere_revision`, que ya es un flag operativo en esta tabla.
--
-- Sirve para marcar la fila y evitar que logística cancele por duplicado un traslado que está
-- autorizado: hoy esas cancelaciones son ~130 por mes con el motivo 16.
ALTER TABLE cs.traslados
    ADD COLUMN IF NOT EXISTS es_duplicado_autorizado TINYINT(1) DEFAULT NULL
    COMMENT 'Segundo traslado del mismo dia con excepcion autorizada: no cancelar por duplicado';

ALTER TABLE cs.traslados_transporte_publico
    ADD COLUMN IF NOT EXISTS es_duplicado_autorizado TINYINT(1) DEFAULT NULL
    COMMENT 'Segundo traslado del mismo dia con excepcion autorizada: no cancelar por duplicado';

-- =============================================================================================

-- =============================================================================================
-- 2. DDL — la columna de 'visto' del solicitante                [COMMIT IMPLICITO, no revierte]
-- =============================================================================================

-- Es el apagado de la card del solicitante: mientras esta en NULL, el pedido resuelto
-- cuenta como 'no visto' y la card sigue encendida en el home de quien pidio.
ALTER TABLE cs.autorizaciones_traslado_duplicado
    ADD COLUMN IF NOT EXISTS fecha_visto_solicitante DATETIME DEFAULT NULL
    COMMENT 'Cuando el solicitante vio el resultado de su pedido; NULL = todavia no lo vio';

-- El indice de la card del solicitante. Va ACA y no en el CREATE TABLE del bloque 1 porque
-- usa `fecha_visto_solicitante`, que se agrega recien en este bloque.
--
-- POR QUE IMPORTA QUE ESTE: es el indice que sirve la rama «mis duplicados resueltos» del SP
-- del listado (`WHERE ATD.id_solicitante = ? AND ATD.estado IN (2,3)`). DEV y TEST lo tienen;
-- si el CREATE TABLE del bloque 1 corre sin el, una segunda pasada NO lo agrega —por el
-- `IF NOT EXISTS`— y produccion queda con otro esquema que TEST, en silencio.
ALTER TABLE cs.autorizaciones_traslado_duplicado
    ADD INDEX IF NOT EXISTS idx_atd_solicitante_visto
        (id_solicitante, estado, fecha_visto_solicitante);

-- =============================================================================================
-- 3. DML — el permiso y su asignacion por perfil                            [TRANSACCIONAL]
-- =============================================================================================

START TRANSACTION;

-- 3.1 El permiso. El id NO se fija: se toma el proximo libre del ambiente.
--
--     Por que no se fija: la version anterior de este script insertaba `id_permiso = 101`
--     con el comentario «el ultimo ocupado es el 100». Era cierto al escribirlo y dejo de
--     serlo: GRV-2239 (CIE-10) tomo el 101 en el medio. Verificado el 21/08/2026 — en
--     PRODUCCION el 101 es `editar_cie10_bloqueado` y en DEV es `log_cirugias`, asi que el
--     espacio de ids divergio entre ambientes y ningun numero fijo sirve para todos.
--     Es indiferente para el comportamiento: las dos puntas resuelven el permiso POR
--     NOMBRE (decision D7), nunca por id.
--
--     Por que el MAX() va en su propia sentencia y no dentro del INSERT: si se pone
--     `SELECT MAX(...) FROM permisos_sas WHERE NOT EXISTS (...)`, el WHERE se evalua ANTES
--     de la agregacion. Con el permiso ya existente el WHERE filtra todas las filas,
--     MAX() sobre el conjunto vacio da NULL, COALESCE(NULL,0)+1 da 1 — y la consulta
--     DEVUELVE IGUAL UNA FILA, porque una agregacion sin GROUP BY siempre devuelve una.
--     Resultado: en el segundo pase insertaria el permiso otra vez con id_permiso = 1.
SET @id_permiso_nuevo = (SELECT COALESCE(MAX(id_permiso), 0) + 1 FROM cs.permisos_sas);

INSERT INTO cs.permisos_sas (id_permiso, permiso, descripcion, activo, usuario_alta)
SELECT @id_permiso_nuevo,
       'autorizar_traslado_mismo_dia',
       'Autorizar la excepcion para que un paciente tenga dos traslados el mismo dia',
       1,
       1
 WHERE NOT EXISTS (SELECT 1 FROM cs.permisos_sas
                    WHERE permiso = 'autorizar_traslado_mismo_dia');

-- 3.2 La asignacion por perfil. Se resuelve POR NOMBRE con CROSS JOIN (decision D7): asi
--     el script no depende de que los ids de perfil coincidan entre ambientes.
--
--     PRODUCCION LLEVA SOLO ESTOS DOS PERFILES (decision de negocio del 21/08/2026).
--     En DEV y TEST estan tambien `gerente_de_siniestros` y `supervisor`.
INSERT INTO cs.perfiles_permisos_sas (id_perfil, id_permiso, activo, usuario_alta)
SELECT pf.id_perfil, perm.id_permiso, 1, 1
  FROM cs.perfiles_sas pf
 CROSS JOIN (SELECT id_permiso FROM cs.permisos_sas
              WHERE permiso = 'autorizar_traslado_mismo_dia') perm
 WHERE pf.perfil IN ('referente_siniestros', 'jefe_de_siniestros')
   AND NOT EXISTS (SELECT 1 FROM cs.perfiles_permisos_sas ppp
                    WHERE ppp.id_perfil = pf.id_perfil
                      AND ppp.id_permiso = perm.id_permiso);

-- 3.3 CONTROL antes de confirmar. Tienen que dar 1 y 2 respectivamente.
--     Si no dan eso: ROLLBACK y revisar. NO confirmar a ciegas.
SELECT COUNT(*) AS permisos_esperado_1 FROM cs.permisos_sas
 WHERE permiso = 'autorizar_traslado_mismo_dia';

SELECT COUNT(*) AS perfiles_esperado_2
  FROM cs.perfiles_permisos_sas ppp
  JOIN cs.permisos_sas perm ON perm.id_permiso = ppp.id_permiso
 WHERE perm.permiso = 'autorizar_traslado_mismo_dia';

--     ATENCION, ESTO NO ES OPCIONAL: hay que resolver la transaccion ACA, antes de pasar al
--     bloque 4. El bloque 4 es DDL (DROP/CREATE PROCEDURE) y en MariaDB el DDL hace COMMIT
--     IMPLICITO: si se deja la transaccion abierta y se sigue, el primer DROP del bloque 4
--     confirma estos INSERT sin que nadie los haya revisado. El "COMMIT comentado" da una
--     sensacion de control que no existe.
--
--     Descomentar UNA de las dos lineas segun lo que dio 3.3:
--       - dio 1 y 2      -> COMMIT
--       - dio otra cosa  -> ROLLBACK, y NO seguir al bloque 4
-- COMMIT;
-- ROLLBACK;

-- =============================================================================================
-- 4. STORED PROCEDURES — los cuatro del listado                       [DROP + CREATE]
-- =============================================================================================
--
--  Requisito: haber guardado el respaldo del bloque 0.5. MariaDB no tiene
--  CREATE OR REPLACE PROCEDURE, asi que hay una ventana de segundos sin el procedimiento.
--
--  El DROP y el DELIMITER los agrega ESTE script: los archivos del repo no los traen, y
--  ejecutarlos tal cual falla con «PROCEDURE already exists» (discrepancia D-15 del SDD).
-- =============================================================================================

-- ---------------------------------------------------------------------------------------------
--  ANTES DE SEGUIR: fijar el sql_mode de la sesion.
--
--  Los cuerpos de estos procedures usan `DEFAULT '\'%'` y `CONCAT(x, " ", y)` con alias entre
--  comillas dobles. Con NO_BACKSLASH_ESCAPES el CREATE falla; con ANSI_QUOTES es peor, porque
--  el CREATE pasa y la falla aparece en la PRIMERA LLAMADA al procedure, ya en produccion.
--
--  Y el modo de falla es grave: el DROP de mas abajo ya se ejecuto, asi que un CREATE que
--  falla deja produccion SIN los cuatro procedures y la pantalla de logistica caida.
--
--  1) Anotar el modo con el que estan creados hoy (deberia ser el mismo en los cuatro):
SELECT ROUTINE_NAME, SQL_MODE, DEFINER FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs'
   AND ROUTINE_NAME IN ('consulta_turnos_tramitadores_sp', 'consulta_traslado_remis_amb_logistica', 'consulta_traslados_aereos_logistica', 'consulta_traslados_internos_logistica');

--  2) Y fijarlo en la sesion antes de recrearlos. Si el paso 1 devolvio otro modo, usar ESE.
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

--  3) Confirmar que la sesion puede crear con el DEFINER que traen los cuerpos
--     (`admin@'%'`). Si CURRENT_USER() es otro y no tiene SET_USER_ID / SUPER, el CREATE
--     falla con error 1227 —otra vez, DESPUES del DROP—. Si no coincide, hay que correr el
--     bloque 4 con el usuario admin o quitar la clausula DEFINER de los cuatro cuerpos.
SELECT CURRENT_USER() AS usuario_de_la_sesion;

-- ---------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------
-- 4.1 consulta_turnos_tramitadores_sp   (de wsturnos: src/main/resources/sql/consulta_turnos_tramitadores_sp.sql)
-- ---------------------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS cs.consulta_turnos_tramitadores_sp;

DELIMITER $$
create
    definer = admin@`%` procedure `cs`.`consulta_turnos_tramitadores_sp`(IN filtros longtext, OUT total_registros int)
BEGIN

    DECLARE select_clause LONGTEXT;
    DECLARE from_clause LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE order_clause LONGTEXT;
    DECLARE sql_query LONGTEXT;
    DECLARE tipo_orden VARCHAR(4);
    DECLARE comodin_like_inicio VARCHAR(3) DEFAULT '\'%';
    DECLARE comodin_like_fin VARCHAR(2) DEFAULT '%\'';
    DECLARE tramitador VARCHAR(1000);
    DECLARE sentido_orden VARCHAR(4); -- 'asc' o 'desc'

    SET @tramitador = 'null';

    -- Columnas del pedido de excepción de traslado duplicado. Las miran dos pestañas y nada más:
    -- "Traslados duplicados" (los pendientes, para quien autoriza) y "Mis duplicados resueltos"
    -- (el resultado, para el gestor que pidió).
    -- Por defecto viajan en NULL y el JOIN a la tabla del pedido NO se agrega, así que el resto de
    -- las tabs ejecuta exactamente el mismo plan que antes de estos cambios.
    -- Van CAST-eadas para que el driver reciba el tipo declarado en TurnosMapping y no un NULL
    -- sin tipo. Son ocho y van siempre las ocho: el mapping las lee por posición.
    SET @select_duplicado = ' CAST(NULL AS SIGNED) as "idAutorizacionTrasladoDuplicado",
    CAST(NULL AS CHAR) as "justificacionDuplicado",
    CAST(NULL AS CHAR) as "solicitanteDuplicado",
    CAST(NULL AS DATETIME) as "fechaSolicitudDuplicado",
    CAST(NULL AS SIGNED) as "estadoDuplicado",
    CAST(NULL AS CHAR) as "dictamenDuplicado",
    CAST(NULL AS DATETIME) as "fechaAutorizacionDuplicado",
    CAST(NULL AS CHAR) as "autorizanteDuplicado"';

    SET @from_clause = ' FROM turnos T
    	LEFT JOIN denuncias d ON d.id_denuncia = T.id_denuncia
        LEFT JOIN afiliados A ON d.id_afiliado = A.id_afiliado
        LEFT JOIN empleadores E ON d.id_empleador = E.id_empleador
        LEFT JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN severidades S ON d.id_severidad = S.id_severidad
		LEFT JOIN autorizaciones AUT ON AUT.id_autorizacion = T.id_autorizacion
        LEFT JOIN personas P ON d.id_auditor = P.id_persona ';

    SET @where_clause = ' WHERE d.activo = 1 ';

    SET @order_clause = ' ORDER BY d.fecha_ocurrencia desc';

    IF JSON_VALID(filtros) IS NOT NULL THEN

        -- Filtro por gestores / tramitador logueado
        SET @filtro_id_gestores = REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idGestores')), '[', ''), ']', '');
        SET @filtro_id_tramitador = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTramitadorLogueado'));

        -- Quién pidió las excepciones de traslado duplicado. Es un campo propio y NO se reusa
        -- `idTramitadorLogueado` a propósito: ese filtro arrastra `AND d.id_auditor = X`, así que
        -- acotaría la pestaña a las denuncias donde el gestor además es el auditor. Justo los
        -- pedidos que hizo cubriendo a otro —los que más necesita ver— quedarían afuera. Acá el
        -- criterio es «quién pidió», sin importar de quién sea la denuncia.
        SET @filtro_id_solicitante_duplicado = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSolicitanteDuplicado'));

        IF @filtro_id_tramitador IS NOT NULL AND @filtro_id_tramitador != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_auditor = ', @filtro_id_tramitador);
        END IF;

        -- Mis denuncias / asignadas a mí
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.misDenuncias')) = 'true' THEN
            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND COALESCE(d.es_asignacion_temporal, 0) = 0'
                                );
        ELSEIF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.denunciasOtros')) = 'true' THEN
            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND d.es_asignacion_temporal = 1'
                                );
        END IF;

        IF (@filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '')
            OR (@filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '') THEN
            -- Si llega lista de gestores, se usa esa lista
            IF @filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '' THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND d.id_auditor IN (', @filtro_id_gestores, ')'
                                    );
            ELSE
                -- Si no hay lista de gestores, se usa el tramitador logueado
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND d.id_auditor = ', @filtro_id_gestores
                                    );
            END IF;
        END IF;

        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.esOrdenarDesc')) = 'true' THEN
            SET sentido_orden = 'desc';
        ELSE
            SET sentido_orden = 'asc';
        END IF;

        SET @idTipoTurno = CAST(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoTurno')) AS UNSIGNED);
        -- filtro pendiente de programar
        IF (JSON_EXTRACT(filtros, '$.pendienteProgramar')) = true THEN
            SET @where_clause = CONCAT(@where_clause,
                                       ' AND (T.id_estado_turno in (14, 15, 16, 17) AND AUT.id_estado_autorizacion not in (3, 5)) ',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1))
                                       AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ) '
                                );

            -- Si es tipo cirugía (4)
            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NULL '
                                    );
            END IF;
        END IF;

        -- filtro pendiente de procesar
        IF (JSON_EXTRACT(filtros, '$.pendienteProcesar')) = true THEN
            SET @where_clause = CONCAT(@where_clause,
                                       ' AND (T.id_estado_turno in (0, 3, 4, 5, 1, 2, 7, 10, 11, 12, 13, 18, 22) AND AUT.id_estado_autorizacion in (0, 2, 4) AND TIMESTAMP(DATE(T.fecha_turno), CAST(T.hora_turno AS TIME)) < NOW())',
                                       ' AND T.fecha_turno >= NOW() - INTERVAL 180 DAY',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR  ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1)) AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) )');

            -- Si es tipo cirugía (4) con Protocolos Pendientes
            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NOT NULL '
                                    );
            END IF;
        END IF;

        -- filtro pendiente de aprobar
        IF (JSON_EXTRACT(filtros, '$.pendienteAprobar')) = true THEN
            SET @where_clause = CONCAT(@where_clause, ' AND (AUT.id_estado_autorizacion = 1)',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR  ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1)) AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) )');

            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NOT NULL '
                                    );
            END IF;
        END IF;

        -- filtro idTurno
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')) != '' THEN
            SET @where_clause =
                    CONCAT(@where_clause, ' AND T.id_turno = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')));
        END IF;

        -- filtro dni paciente
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND A.nro_doc LIKE ', comodin_like_inicio,
                                       JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')), comodin_like_fin, ' ');
        END IF;

        -- filtro nro denuncia
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND (d.nro_provisorio LIKE ',
                                       CONCAT(comodin_like_inicio, JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')),
                                              comodin_like_fin),
                                       ' OR d.nro_asignado LIKE ',
                                       CONCAT(comodin_like_inicio, JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')),
                                              comodin_like_fin),
                                       ')');
        END IF;

        -- Filtro: Nombre y apellido paciente
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')) != '' THEN
            SET @afiliado = REPLACE(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')), '"', '');
            SET  @afiliado = REGEXP_REPLACE( @afiliado, '\\s+', ' ');
            SET  @afiliado = LTRIM(RTRIM( @afiliado));

            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND CONCAT(CONVERT(TRIM(A.nombre) USING utf8mb4), " ", CONVERT(TRIM(A.apellido) USING utf8mb4)) ',
                    'COLLATE utf8mb4_spanish_ci LIKE "%',
                    @afiliado,
                    '%" COLLATE utf8mb4_spanish_ci'
                                );
        END IF;

        -- orden por idTurno
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.ordenIdTurno')) IS NOT NULL THEN
            SET @order_clause = CONCAT(' ORDER BY T.id_turno ', sentido_orden);
        END IF;

        -- orden por nroDenuncia
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.ordenDenuncia')) IS NOT NULL THEN
            SET @order_clause = CONCAT(' ORDER BY COALESCE(d.nro_asignado, d.nro_provisorio) ', sentido_orden);
        END IF;

        -- Filtros por clasificacion de siniestros
        SET @idClasificacionSiniestros := JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idClasificacionSiniestros'));
        IF @idClasificacionSiniestros IS NOT NULL THEN
            SET @where_clause := CONCAT(@where_clause, ' AND ', consulta_filtro_clasificacion_siniestros_tramitadores(@idClasificacionSiniestros));
        END IF;

        -- Filtros por cuentas
        SET @idCuentas := JSON_UNQUOTE(JSON_EXTRACT(filtros,'$.idCuentas'));
        IF @idCuentas IS NOT NULL AND @idCuentas != '' THEN
            SET @from_clause = CONCAT(@from_clause, ' LEFT JOIN cuentas_empleadores_sas ces ON d.id_empleador = ces.id_empleador ');
            SET @where_clause = CONCAT(@where_clause, ' AND  ces.id_cuenta IN (' ,  @idCuentas, ') ');
        END IF;

        -- Filtro Clientes Sas
        SET @filtro_idClientes = JSON_UNQUOTE(JSON_EXTRACT(filtros,'$.idClientes'));
        IF @filtro_idClientes IS NOT NULL AND @filtro_idClientes != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND  d.id_cliente IN (' ,  @filtro_idClientes, ') ');
        END IF;

        -- Filtro por empleadores
        SET @filtro_idEmpleadores = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idEmpleadores'));
        IF @filtro_idEmpleadores IS NOT NULL AND @filtro_idEmpleadores != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_empleador IN (', @filtro_idEmpleadores, ')');
        END IF;

        -- Filtro por estados médicos (de la denuncia)
        SET @filtro_idEstadosMedico = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idEstadosMedico'));
        IF @filtro_idEstadosMedico IS NOT NULL AND @filtro_idEstadosMedico != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_estado_medico IN (', @filtro_idEstadosMedico, ')');
        END IF;

        -- Filtro por tipo siniestro
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_tipo_siniestro = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')));
        END IF;

        -- Filtro por severidad
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_severidad = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')));
        END IF;

        -- Filtro fecha denuncia (rango)
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_denuncia) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_denuncia) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')), '")');
        END IF;

        -- Filtro fecha ocurrencia (rango)
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_ocurrencia) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_ocurrencia) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')), '")');
        END IF;

        -- Filtro fecha alta (rango)
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_alta) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_alta) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')), '")');
        END IF;

        -- filtro solicitado por prestador
        IF (JSON_EXTRACT(filtros, '$.solicitaPrestador')) = true THEN
            SET @where_clause = CONCAT(@where_clause, ' AND AUT.id_estado_autorizacion = 9',
                                       ' AND T.solicitada_prestador IS TRUE');
        END IF;

        -- filtro evolutivo e informe de prestadores
        IF (JSON_EXTRACT(filtros, '$.evolutivoInformePrestador')) = true THEN
            SET @where_clause = CONCAT(@where_clause, ' AND T.id_estado_turno = 23',
                                       ' AND T.solicitada_prestador IS TRUE');
        END IF;

        -- filtro traslados duplicados pendientes de autorizar
        -- El pedido de excepción se ancla a la autorización del turno, así que se llega por AUT.
        -- El JOIN se resuelve contra el ÚLTIMO pedido de esa autorización (MAX del id) por dos
        -- razones: un turno reeditado puede tener más de un pedido histórico y el que vale es el
        -- último —mismo criterio que AutorizacionTrasladoDuplicadoRepository.findByAutorizacion—,
        -- y así la grilla no multiplica filas por turno.
        -- Es INNER JOIN porque la pestaña muestra sólo los turnos que tienen pedido pendiente.
        --
        -- OJO SI AGREGÁS OTRA PESTAÑA SOBRE ESTA TABLA: este IF y el ELSEIF de abajo son
        -- EXCLUYENTES y tienen que seguir siéndolo. Las dos ramas inyectan el mismo alias ATD (y
        -- PS) en @from_clause; si las dos se ejecutaran en la misma llamada, el JOIN se agregaría
        -- dos veces y el PREPARE fallaría con "Not unique table/alias: ATD". Una pestaña nueva va
        -- como otro ELSEIF de esta misma cadena, no como un IF suelto.
        IF (JSON_EXTRACT(filtros, '$.trasladosDuplicadosPendientes')) = true THEN
            SET @from_clause = CONCAT(@from_clause,
                                      ' INNER JOIN autorizaciones_traslado_duplicado ATD
                                            ON ATD.id_autorizacion = AUT.id_autorizacion
                                           AND ATD.id_autorizacion_traslado_duplicado = (
                                                SELECT MAX(ATD2.id_autorizacion_traslado_duplicado)
                                                  FROM autorizaciones_traslado_duplicado ATD2
                                                 WHERE ATD2.id_autorizacion = AUT.id_autorizacion)
                                        LEFT JOIN personas PS ON PS.id_persona = ATD.id_solicitante ');
            -- Pendiente Y con el traslado todavia vivo.
            --
            -- Por que se filtra por el estado del traslado: si audmed rechazo la autorizacion, el
            -- traslado quedo cancelado y aprobar la excepcion no tiene nada que aplicar. Antes ese
            -- pedido seguia apareciendole al referente como si hubiera algo que decidir. Peor: al
            -- aprobarlo se le daba estado de logistica y el traslado cancelado reaparecia en la
            -- grilla. Lo segundo ya lo frena el servicio; esto saca de la bandeja lo que no
            -- corresponde resolver.
            --
            -- OJO, LOS DOS CATALOGOS DE ESTADO USAN LOS MISMOS NUMEROS CON OTRO SIGNIFICADO:
            --   codigo | traslados            | traslados_transporte_publico
            --   -------|----------------------|------------------------------
            --      4   | Cancelado            | REALIZADO
            --      5   | Rechazado            | Rechazado por Auditoria
            --      6   | -                    | ANULADO
            -- Por eso son 4 y 5 para el traslado normal, y 5 y 6 para el transporte publico.
            -- Aplicarle el criterio del normal al publico descartaria los Realizados (que estan
            -- bien) y dejaria pasar los Anulados (que estan muertos).
            --
            -- Un pedido con las DOS columnas de traslado en NULL tampoco entra: no hay traslado
            -- sobre el que aplicar la excepcion, asi que es irresoluble y no debe ocupar la bandeja.
            SET @where_clause = CONCAT(@where_clause, ' AND ATD.estado = 1
                AND ( EXISTS (SELECT 1 FROM traslados TRV
                               WHERE TRV.id_traslado = ATD.id_traslado
                                 AND TRV.id_estado_traslado NOT IN (4, 5))
                   OR EXISTS (SELECT 1 FROM traslados_transporte_publico TPV
                               WHERE TPV.id_traslado = ATD.id_traslado_transporte_publico
                                 AND TPV.id_estado_traslado NOT IN (5, 6)) ) ');
            -- El autorizante todavía no existe (el pedido está pendiente), así que esa columna va en
            -- NULL y no se agrega el JOIN a `personas` que la resolvería para nada.
            SET @select_duplicado = ' ATD.id_autorizacion_traslado_duplicado as "idAutorizacionTrasladoDuplicado",
    ATD.justificacion as "justificacionDuplicado",
    CONCAT(PS.nombre, " ", PS.apellido) as "solicitanteDuplicado",
    ATD.fecha_solicitud as "fechaSolicitudDuplicado",
    ATD.estado as "estadoDuplicado",
    ATD.dictamen as "dictamenDuplicado",
    ATD.fecha_autorizacion as "fechaAutorizacionDuplicado",
    CAST(NULL AS CHAR) as "autorizanteDuplicado"';

        -- filtro «mis duplicados resueltos»: la vuelta del resultado al gestor que pidió.
        -- Es ELSEIF y no un IF suelto a propósito: las dos ramas usan el mismo alias ATD, y si las
        -- dos vinieran en true se agregaría el JOIN dos veces y el SP fallaría por alias duplicado.
        -- Son excluyentes por definición —una mira pendientes, la otra resueltos—.
        --
        -- El solicitante sale de `idSolicitanteDuplicado` y NO de `idTramitadorLogueado`: ese otro
        -- filtro agrega `AND d.id_auditor = X` y dejaría afuera los pedidos que el gestor hizo
        -- sobre denuncias ajenas, que son los que más necesita ver. Si no viene, el filtro no se
        -- aplica: concatenar un NULL dejaría todo @where_clause en NULL y el PREPARE reventaría.
        ELSEIF (JSON_EXTRACT(filtros, '$.misDuplicadosResueltos')) = true
            AND @filtro_id_solicitante_duplicado IS NOT NULL
            AND @filtro_id_solicitante_duplicado != '' THEN
            SET @from_clause = CONCAT(@from_clause,
                                      ' INNER JOIN autorizaciones_traslado_duplicado ATD
                                            ON ATD.id_autorizacion = AUT.id_autorizacion
                                           AND ATD.id_autorizacion_traslado_duplicado = (
                                                SELECT MAX(ATD2.id_autorizacion_traslado_duplicado)
                                                  FROM autorizaciones_traslado_duplicado ATD2
                                                 WHERE ATD2.id_autorizacion = AUT.id_autorizacion)
                                        LEFT JOIN personas PS ON PS.id_persona = ATD.id_solicitante
                                        LEFT JOIN personas PA ON PA.id_persona = ATD.id_autorizante ');
            SET @where_clause = CONCAT(@where_clause,
                                       ' AND ATD.id_solicitante = ', @filtro_id_solicitante_duplicado,
                                       ' AND ATD.estado IN (2, 3) ');
            -- Del autorizante se devuelve el NOMBRE y nunca el id: al usuario no se le muestra
            -- ningún id, y por eso el tooltip de logística venía mostrando un número o nada.
            SET @select_duplicado = ' ATD.id_autorizacion_traslado_duplicado as "idAutorizacionTrasladoDuplicado",
    ATD.justificacion as "justificacionDuplicado",
    CONCAT(PS.nombre, " ", PS.apellido) as "solicitanteDuplicado",
    ATD.fecha_solicitud as "fechaSolicitudDuplicado",
    ATD.estado as "estadoDuplicado",
    ATD.dictamen as "dictamenDuplicado",
    ATD.fecha_autorizacion as "fechaAutorizacionDuplicado",
    CONCAT(PA.nombre, " ", PA.apellido) as "autorizanteDuplicado"';
        END IF;

    END IF;

    SET @select_clause = CONCAT('SELECT SQL_CALC_FOUND_ROWS
    T.id_turno as "idTurno",
	d.id_denuncia as "idDenuncia",
    d.nro_asignado as "nroAsignado",
    d.nro_provisorio as "nroProvisorio",
    CONCAT(A.nombre, " ", A.apellido) as "paciente",
    E.es_vip as "esVip",
    A.nro_doc as "nroDocPaciente",
    E.razon_social as "razonSocialEmpleador",
    c.nombre AS cliente,
    S.descripcion as "severidad",
    d.id_estado_medico as "idEstadoMedico",
	d.es_sin_baja_laboral as "esSinBajaLaboral",
	d.es_rechazado as "esRechazado",
    CONCAT(DATE(T.fecha_turno), " ", T.hora_turno) as "fechaTurno",
	CONCAT(P.nombre, " ", P.apellido) as "analista",
    T.fecha_solicitada as "fechaSolicitada",
    AUT.fecha_autorizacion as "fechaAutorizacion",
	AUT.id_autorizacion as "idAutorizacion",
	AUT.id_tipo_turno_solicitado as "idTipoTurno", ',
                                @tramitador, ' as "tramitador", ', @select_duplicado);

    -- Construir la consulta final con paginación y ordenación
    SET @sql_query = CONCAT(@select_clause, @from_clause, @where_clause, @order_clause);

    -- Añadir paginación
    IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.limit')) IS NOT NULL AND
       JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.offset')) IS NOT NULL THEN
        SET @sql_query = CONCAT(@sql_query, ' LIMIT ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.limit')), ' OFFSET ',
                                JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.offset')));
    END IF;

    PREPARE stmt FROM @sql_query;
#     PREPARE stmt FROM 'SELECT @sql_query from alarma limit 1';
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT FOUND_ROWS() INTO total_registros;

-- Limpiar variables
    SET @select_clause = NULL;
    SET @where_clause = NULL;
    SET @from_clause = NULL;
    SET @order_clause = NULL;
    SET @sql_query = NULL;
    SET @select_duplicado = NULL;
    SET @filtro_id_solicitante_duplicado = NULL;

END
$$
DELIMITER ;

-- Control: el procedure quedo creado y expone las columnas nuevas.
SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs' AND ROUTINE_NAME = 'consulta_turnos_tramitadores_sp';

-- ---------------------------------------------------------------------------------------------
-- 4.2 consulta_traslado_remis_amb_logistica   (de wslogistica: src/main/resources/sql/storedProcedure/consulta_traslado_remis_amb_logistica.sql)
-- ---------------------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS cs.consulta_traslado_remis_amb_logistica;

DELIMITER $$
CREATE DEFINER=`admin`@`%` PROCEDURE `cs`.`consulta_traslado_remis_amb_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query LONGTEXT;
    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
    DECLARE tipoPrestacionId INT;
    DECLARE prestadorId INT;
    DECLARE nroSiniestro VARCHAR(50);
    DECLARE dniPaciente VARCHAR(15);
    DECLARE nombrePaciente VARCHAR(15);
    DECLARE apellidoPaciente VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
    DECLARE isEspontaneo VARCHAR(5);
    DECLARE tipoTransporteId INT;
   	DECLARE idDenuncia INT;
    DECLARE soloPrioritarios VARCHAR(5);
    DECLARE soloRequierenRevision VARCHAR(5);
    DECLARE idClientes LONGTEXT;
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);

    SET fechaDesde = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET tipoPrestacionId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoPrestacionId')), 'null');
    SET prestadorId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET nroSiniestro = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nroSiniestro')), 'null');
    SET dniPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniPaciente')), 'null');
    SET nombrePaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombrePaciente')), 'null');
    SET apellidoPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoPaciente')), 'null');
    SET clienteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET isEspontaneo = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.isEspontaneo')), 'null');
    SET tipoTransporteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoTransporteId')), 'null');
    SET idDenuncia = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idDenuncia')), 'null');
    SET soloPrioritarios = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloPrioritarios')), 'null');
    SET soloRequierenRevision = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloRequierenRevision')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');
    SET offset_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');

    SET where_clause = ' WHERE 1=1 AND (t.id_tipo_traslado IN (1, 2))';

    SET where_clause = CONCAT(where_clause,
       ' AND tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL');

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
            ' AND tu.fecha_turno BETWEEN CONCAT("', fechaDesde, ' 00:00:00") AND CONCAT("', fechaHasta, ' 23:59:59")');
    END IF;

    IF tipoPrestacionId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_tipo_turno = ', tipoPrestacionId);
    END IF;

    IF prestadorId IS NOT NULL THEN
       SET where_clause = CONCAT( where_clause,
	    ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
	    ' OR t.id_proveedor_servicio_traslado_vuelta = ', prestadorId,
		' OR (tah.id_proveedor_servicio_traslado = ', prestadorId,
    	' AND tah.id_etiqueta_agencia IN (1,2) ))');
    END IF;

    IF nroSiniestro IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (d.nro_asignado LIKE ''%', nroSiniestro, '%'' OR d.nro_provisorio LIKE ''%', nroSiniestro, '%'')');
    END IF;

    IF dniPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nro_doc = "', dniPaciente, '"');
    END IF;

    IF nombrePaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nombre LIKE "%', nombrePaciente, '%"');
    END IF;

    IF apellidoPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.apellido LIKE "%', apellidoPaciente, '%"');
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND d.id_empleador IN (SELECT e.id_empleador FROM empleadores e WHERE e.id_cliente = ', clienteId, ')');
    END IF;

    IF estadoId IS NOT NULL THEN
    	SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
	END IF;

    IF isEspontaneo IS NOT NULL THEN
    	IF isEspontaneo = 'true' THEN
        	SET where_clause = CONCAT(where_clause, ' AND t.es_espontaneo_asociado = 1');
        ELSE
        	SET where_clause = CONCAT(where_clause, ' AND t.es_espontaneo_asociado IS NULL');
        END IF;
    END IF;

    IF tipoTransporteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_tipo_traslado = ', tipoTransporteId, ' OR t.id_tipo_traslado_regreso = ', tipoTransporteId, ')');
    END IF;

    IF idDenuncia IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_denuncia = ', idDenuncia);
    END IF;

    IF soloPrioritarios IS NOT NULL AND soloPrioritarios = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.es_traslado_prioritario = 1');
    END IF;

    IF soloRequierenRevision IS NOT NULL AND soloRequierenRevision = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.requiere_revision = 1');
    END IF;

	IF idClientes IS NOT NULL AND idClientes != '' THEN
	   SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    SET sql_query = CONCAT('
        SELECT DISTINCT
            t.id_traslado as nro_traslado,
            t.id_turno as id_turno,
            COALESCE(d.nro_asignado, d.nro_provisorio) as nro_denuncia,
            d.id_denuncia as id_denuncia,
            a.nro_doc as dni_paciente,
            a.nombre as nombre_paciente,
            a.apellido as apellido_paciente,
            a.telefono as telefono_paciente,
            NULLIF(
                CONCAT_WS(
                    '''',
                    NULLIF(a.codigo_pais_celular, ''''),
                    NULLIF(a.codigo_area_celular, ''''),
                    NULLIF(a.numero_celular, '''')
                ),
                ''''
            ) as celular_paciente,
            tu.hora_turno as hora_traslado,
            DATE_FORMAT(tu.fecha_turno, "%d/%m/%Y") as fecha_traslado,
            c.nombre as cliente,
            CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
            t.id_tipo_traslado as id_tipo_traslado_ida,
            ttr.descripcion as descripcion_tipo_traslado_ida,
            t.id_tipo_traslado_regreso as id_tipo_traslado_vuelta,
            ttr.descripcion as descripcion_tipo_traslado_vuelta,
          	pst_ida.codigo AS codigo_agencia_ida,
			p_ida.razon_social AS descripcion_agencia_ida,
			pst_vuelta.codigo AS codigo_agencia_vuelta,
			p_vuelta.razon_social AS descripcion_agencia_vuelta,
            t.direccion_origen as origen_ida,
            t.direccion_destino as destino_ida,
			t.direccion_destino as origen_vuelta,
            t.direccion_destino_regreso as destino_vuelta,
            t.id_estado_traslado as estado_id,
            et.descripcion as estado_descripcion,
           	CASE WHEN t.es_espontaneo_asociado = 1 THEN TRUE ELSE FALSE END AS is_espontaneo,
            tu.id_tipo_turno as tipo_prestacion,
            tt.descripcion as prestacion,
			l1.nombre AS localidad_origen_ida,
			l2.nombre AS localidad_destino_ida,
            l2.nombre AS localidad_origen_vuelta,
			l3.nombre AS localidad_destino_vuelta,
			p1.nombre AS traslado_provincia_origen_ida,
    		p2.nombre AS traslado_provincia_destino_ida,
    		p2.nombre AS traslado_provincia_origen_vuelta,
    		p3.nombre AS traslado_provincia_destino_vuelta,
			NULL as apellido_empleado,
			NULL as nombre_empleado,
			NULL as dni_empleado,
            CASE WHEN t.id_tipo_viaje = 1 THEN FALSE ELSE TRUE END AS is_ida_vuelta,
			FALSE as is_transporte_publico,
			etl_ida.id_estado_logistica as estado_logistica_ida_id,
			etl_ida.descripcion as estado_logistica_ida_descripcion,
			etl_vuelta.id_estado_logistica as estado_logistica_vuelta_id,
			etl_vuelta.descripcion as estado_logistica_vuelta_descripcion,
			t.requiere_revision as requiere_revision,
            t.archivo_autorizacion_ambulancia as autorizacion_ambulancia,
            ti.id_satapp_ida as id_satapp_ida,
            ti.id_satapp_vuelta as id_satapp_vuelta,
            ti.id_moovear_ida as id_moovear_ida,
            ti.id_moovear_vuelta as id_moovear_vuelta,
            ptr.nombre as nombre_tramitador,
            ptr.apellido as apellido_tramitador,
            t.es_duplicado_autorizado as es_duplicado_autorizado
        FROM traslados t
        JOIN turnos tu ON t.id_turno = tu.id_turno
        JOIN denuncias d ON tu.id_denuncia = d.id_denuncia
        JOIN afiliados a ON d.id_afiliado = a.id_afiliado
        LEFT JOIN personas ptr ON ptr.id_persona = d.id_auditor
        JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
        JOIN tipos_traslados ttr ON t.id_tipo_traslado = ttr.id_tipo_traslado
        JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
        LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
        LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
		LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
		LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
		LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
		LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
		LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
		LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
		LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
		LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
		LEFT JOIN traslados_agencias_historico tah ON t.id_traslado = tah.id_traslado
		LEFT JOIN traslado_integraciones ti ON t.id_traslado = ti.id_traslado
    	', where_clause);

    IF sortOrder NOT IN ('ASC', 'DESC') THEN
	    SET sortOrder = 'DESC';
	END IF;

    SET sql_query = CONCAT( sql_query,
	    ' ORDER BY ',
	CASE
    	WHEN sortField = 'fechaTraslado' THEN CONCAT('tu.fecha_turno ', sortOrder) --
    	ELSE CONCAT('t.id_traslado ', sortOrder)
	END
	);

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('SELECT COUNT(DISTINCT t.id_traslado) INTO @total_records
	FROM traslados t
	JOIN turnos tu ON t.id_turno = tu.id_turno
	JOIN denuncias d ON tu.id_denuncia = d.id_denuncia
	JOIN afiliados a ON d.id_afiliado = a.id_afiliado
	LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
	LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
	LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
	LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
	JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
	JOIN tipos_traslados ttr ON t.id_tipo_traslado = ttr.id_tipo_traslado
	JOIN clientes c ON c.id_cliente = d.id_cliente
	LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
	LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
	LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
	LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
	LEFT JOIN traslados_agencias_historico tah ON t.id_traslado = tah.id_traslado
	', where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END
$$
DELIMITER ;

-- Control: el procedure quedo creado y expone las columnas nuevas.
SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs' AND ROUTINE_NAME = 'consulta_traslado_remis_amb_logistica';

-- ---------------------------------------------------------------------------------------------
-- 4.3 consulta_traslados_aereos_logistica   (de wslogistica: src/main/resources/sql/storedProcedure/consulta_traslados_aereos_logistica.sql)
-- ---------------------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS cs.consulta_traslados_aereos_logistica;

DELIMITER $$
CREATE DEFINER=`admin`@`%` PROCEDURE `cs`.`consulta_traslados_aereos_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query LONGTEXT;
    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
	DECLARE tipoPrestacionId INT;
    DECLARE prestadorId INT;
    DECLARE nroSiniestro VARCHAR(50);
    DECLARE dniPaciente VARCHAR(15);
    DECLARE nombrePaciente VARCHAR(15);
    DECLARE apellidoPaciente VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
  	DECLARE idDenuncia INT;
    DECLARE soloRequierenRevision VARCHAR(5);
    DECLARE idClientes LONGTEXT;
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);

    SET fechaDesde = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET tipoPrestacionId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoPrestacionId')), 'null');
    SET prestadorId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET nroSiniestro = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nroSiniestro')), 'null');
    SET dniPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniPaciente')), 'null');
    SET nombrePaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombrePaciente')), 'null');
    SET apellidoPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoPaciente')), 'null');
    SET clienteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET idDenuncia = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idDenuncia')), 'null');
    SET soloRequierenRevision = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloRequierenRevision')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');
    SET offset_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');

    SET where_clause = ' WHERE 1=1 ';

    SET where_clause = CONCAT(where_clause,
       ' AND tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL');

    -- GRV-1955: excluir turnos pendientes de aprobación del auditor médico
    SET where_clause = CONCAT(where_clause,
       ' AND tu.id_estado_turno NOT IN (1, 2, 4, 9, 12, 13, 14, 15, 16, 17, 18, 26)');

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
            ' AND tu.fecha_turno BETWEEN CONCAT("', fechaDesde, ' 00:00:00") AND CONCAT("', fechaHasta, ' 23:59:59")');
    END IF;

    IF tipoPrestacionId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_tipo_turno = ', tipoPrestacionId);
    END IF;

    IF prestadorId IS NOT NULL THEN
        SET where_clause = CONCAT( where_clause,
	    ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
	    ' OR t.id_proveedor_servicio_traslado_regreso = ', prestadorId, ')');
    END IF;

    IF nroSiniestro IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (d.nro_asignado LIKE ''%', nroSiniestro, '%'' OR d.nro_provisorio LIKE ''%', nroSiniestro, '%'')');
    END IF;

    IF dniPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nro_doc = "', dniPaciente, '"');
    END IF;

    IF nombrePaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nombre LIKE "%', nombrePaciente, '%"');
    END IF;

    IF apellidoPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.apellido LIKE "%', apellidoPaciente, '%"');
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND d.id_empleador IN (SELECT e.id_empleador FROM empleadores e WHERE e.id_cliente = ', clienteId, ')');
    END IF;

    IF estadoId IS NOT NULL THEN
    	SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
	END IF;

    IF idDenuncia IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.id_denuncia = ', idDenuncia);
    END IF;

    IF soloRequierenRevision IS NOT NULL AND soloRequierenRevision = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.requiere_revision = 1');
    END IF;

	IF idClientes IS NOT NULL AND idClientes != '' THEN
	   SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    SET sql_query = CONCAT('
        SELECT DISTINCT
            t.id_traslado as nro_traslado,
            t.id_turno as id_turno,
            COALESCE(d.nro_asignado, d.nro_provisorio) as nro_denuncia,
            t.id_denuncia as id_denuncia,
            a.nro_doc as dni_paciente,
            a.nombre as nombre_paciente,
            a.apellido as apellido_paciente,
            a.telefono as telefono_paciente,
            NULLIF(
                CONCAT_WS(
                    '''',
                    NULLIF(a.codigo_pais_celular, ''''),
                    NULLIF(a.codigo_area_celular, ''''),
                    NULLIF(a.numero_celular, '''')
                ),
                ''''
            ) as celular_paciente,
		    tu.hora_turno as hora_traslado,
    		DATE_FORMAT(tu.fecha_turno, "%d/%m/%Y") AS fecha_traslado,
            c.nombre as cliente,
            CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
            t.id_tipo_traslado_ida as id_tipo_traslado_ida,
            ttr.descripcion as descripcion_tipo_traslado_ida,
            t.id_tipo_traslado_vuelta as id_tipo_traslado_vuelta,
            ttr.descripcion as descripcion_tipo_traslado_vuelta,
            pst_ida.codigo AS codigo_agencia_ida,
		    p_ida.razon_social AS descripcion_agencia_ida,
		    pst_vuelta.codigo AS codigo_agencia_vuelta,
		    p_vuelta.razon_social AS descripcion_agencia_vuelta,
            t.origen_ida as origen_ida,
            t.destino_ida as destino_ida,
            t.destino_ida as origen_vuelta,
            t.destino_vuelta as destino_vuelta,
            t.id_estado_traslado as estado_id,
            et.descripcion as estado_descripcion,
		    NULL as is_espontaneo,
            tu.id_tipo_turno as tipo_prestacion,
            tt.descripcion as prestacion,
            l1.nombre AS localidad_origen_ida,
            l2.nombre AS localidad_destino_ida,
            l2.nombre AS localidad_origen_vuelta,
            l3.nombre AS localidad_destino_vuelta,
		    p1.nombre AS traslado_provincia_origen_ida,
    		p2.nombre AS traslado_provincia_destino_ida,
    		p2.nombre AS traslado_provincia_origen_vuelta,
    		p3.nombre AS traslado_provincia_destino_vuelta,
		    NULL as apellido_empleado,
		    NULL as nombre_empleado,
		    NULL as dni_empleado,
		    CASE WHEN t.id_tipo_viaje = 1 THEN FALSE ELSE TRUE END AS is_ida_vuelta,
		    TRUE as is_transporte_publico,
		    etl_ida.id_estado_logistica as estado_logistica_ida_id,
		    etl_ida.descripcion as estado_logistica_ida_descripcion,
		    etl_vuelta.id_estado_logistica as estado_logistica_vuelta_id,
		    etl_vuelta.descripcion as estado_logistica_vuelta_descripcion,
		    t.requiere_revision as requiere_revision,
		    ptr.nombre as nombre_tramitador,
		    ptr.apellido as apellido_tramitador,
		    NULL as autorizacion_ambulancia,
            NULL as id_satapp_ida,
            NULL as id_satapp_vuelta,
            NULL as id_moovear_ida,
            NULL as id_moovear_vuelta,
            t.es_duplicado_autorizado as es_duplicado_autorizado
        FROM traslados_transporte_publico t
        JOIN turnos tu ON t.id_turno = tu.id_turno
        JOIN denuncias d ON t.id_denuncia = d.id_denuncia
        JOIN afiliados a ON d.id_afiliado = a.id_afiliado
        LEFT JOIN personas ptr ON ptr.id_persona = d.id_auditor
        JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
        JOIN tipos_traslados ttr ON t.id_tipo_traslado_ida = ttr.id_tipo_traslado
        JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
        LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_regreso = pst_vuelta.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
        LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
        LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
        LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
	    LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
	    LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
	    LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
        LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
	    LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
	    LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
    ', where_clause);

     IF sortOrder NOT IN ('ASC', 'DESC') THEN
	    SET sortOrder = 'DESC';
	END IF;

    SET sql_query = CONCAT( sql_query,
	    ' ORDER BY ',
	CASE
    	WHEN sortField = 'fechaTraslado' THEN CONCAT('tu.fecha_solicitada ', sortOrder)
    	ELSE CONCAT('t.id_traslado ', sortOrder)
	END
	);

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('SELECT COUNT(DISTINCT t.id_traslado) INTO @total_records
		FROM traslados_transporte_publico t
		JOIN turnos tu ON t.id_turno = tu.id_turno
		JOIN denuncias d ON t.id_denuncia = d.id_denuncia
		JOIN afiliados a ON d.id_afiliado = a.id_afiliado
		LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
		LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
		LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_regreso = pst_vuelta.id_proveedor_servicio_traslado
		LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
		JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
		JOIN tipos_traslados ttr ON t.id_tipo_traslado_ida = ttr.id_tipo_traslado
		JOIN clientes c ON c.id_cliente = d.id_cliente
		LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
		LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
		LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
		LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado',
		where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END
$$
DELIMITER ;

-- Control: el procedure quedo creado y expone las columnas nuevas.
SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs' AND ROUTINE_NAME = 'consulta_traslados_aereos_logistica';

-- ---------------------------------------------------------------------------------------------
-- 4.4 consulta_traslados_internos_logistica   (de wslogistica: src/main/resources/sql/storedProcedure/consulta_traslados_internos_logistica.sql)
-- ---------------------------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS cs.consulta_traslados_internos_logistica;

DELIMITER $$
create
    definer = admin@`%` procedure `cs`.`consulta_traslados_internos_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query    LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query  LONGTEXT;

    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
    DECLARE prestadorId INT;
    DECLARE dniEmpleado VARCHAR(15);
    DECLARE nombreEmpleado VARCHAR(15);
    DECLARE apellidoEmpleado VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
    DECLARE tipoTransporteId INT;
    DECLARE soloPrioritarios VARCHAR(5);
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);
    DECLARE isTransportePublico VARCHAR(5);
    DECLARE idClientes LONGTEXT;

    SET fechaDesde        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET prestadorId       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET dniEmpleado       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniEmpleado')), 'null');
    SET nombreEmpleado    = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombreEmpleado')), 'null');
    SET apellidoEmpleado  = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoEmpleado')), 'null');
    SET clienteId         = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId          = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET tipoTransporteId  = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoTransporteId')), 'null');
    SET soloPrioritarios = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloPrioritarios')), 'null');
    SET offset_json       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder         = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField         = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');
    SET isTransportePublico = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.isTransportePublico')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');

    SET where_clause = ' WHERE 1=1';

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.fecha_traslado BETWEEN ', QUOTE(fechaDesde), ' AND ', QUOTE(fechaHasta));
    END IF;

    IF prestadorId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
                                  ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
                                  ' OR t.id_proveedor_servicio_traslado_vuelta = ', prestadorId, ')');
    END IF;

    IF dniEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.nro_doc = ', QUOTE(dniEmpleado));
    END IF;

    IF nombreEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.nombre LIKE ', QUOTE(CONCAT('%', nombreEmpleado, '%')));
    END IF;

    IF apellidoEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.apellido LIKE ', QUOTE(CONCAT('%', apellidoEmpleado, '%')));
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.id_cliente = ', clienteId);
    END IF;

    IF estadoId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
    END IF;

    IF isTransportePublico IS NOT NULL AND isTransportePublico = 'true' THEN
        SET where_clause = CONCAT(where_clause,' AND (t.id_tipo_traslado_ida IN (4,5) OR t.id_tipo_traslado_vuelta IN (4,5))');
    ELSEIF tipoTransporteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_tipo_traslado_ida = ', tipoTransporteId, ' OR t.id_tipo_traslado_vuelta = ', tipoTransporteId, ')');
    END IF;

    IF idClientes IS NOT NULL AND idClientes != '' THEN
        SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    IF soloPrioritarios IS NOT NULL AND soloPrioritarios = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.traslado_prioritario = 1');
    END IF;

    IF sortOrder NOT IN ('ASC', 'DESC') THEN
        SET sortOrder = 'DESC';
    END IF;

    SET
        sql_query = CONCAT('
  SELECT DISTINCT
  t.id_traslado_interno                         AS nro_traslado,
  NULL                                          AS id_turno,
  NULL                                          AS nro_denuncia,
  NULL                                          AS id_denuncia,
  NULL                                          AS dni_paciente,
  NULL                                          AS nombre_paciente,
  NULL                                          AS apellido_paciente,
  NULL                                          AS telefono_paciente,
  NULL                                          AS celular_paciente,
  t.hora_traslado                               AS hora_traslado,
  DATE_FORMAT(t.fecha_traslado, "%d/%m/%Y")     AS fecha_traslado,
  c.nombre                                      AS cliente,
  CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
  t.id_tipo_traslado_ida                        AS id_tipo_traslado_ida,
  ttr.descripcion                               AS descripcion_tipo_traslado_ida,
  t.id_tipo_traslado_vuelta                     AS id_tipo_traslado_vuelta,
  ttra.descripcion                              AS descripcion_tipo_traslado_vuelta,
  pst_ida.codigo                                AS codigo_agencia_ida,
  p_ida.razon_social                            AS descripcion_agencia_ida,
  pst_vuelta.codigo                             AS codigo_agencia_vuelta,
  p_vuelta.razon_social                         AS descripcion_agencia_vuelta,
  t.origen_ida                                  AS origen_ida,
  t.destino_ida                                 AS destino_ida,
  t.origen_vuelta                               AS origen_vuelta,
  t.destino_vuelta                              AS destino_vuelta,
  t.id_estado_traslado                          AS estado_id,
  et.descripcion                                AS estado_descripcion,
  NULL                                          AS is_espontaneo,
  NULL                                          AS tipo_prestacion,
  NULL                                          AS prestacion,
  l1.nombre                                     AS localidad_origen_ida,
  l2.nombre                                     AS localidad_destino_ida,
  l3.nombre                                     AS localidad_origen_vuelta,
  l4.nombre                                     AS localidad_destino_vuelta,
  p1.nombre AS traslado_provincia_origen_ida,
  p2.nombre AS traslado_provincia_destino_ida,
  p2.nombre AS traslado_provincia_origen_vuelta,
  p3.nombre AS traslado_provincia_destino_vuelta,
  pe.apellido                                   AS apellido_empleado,
  pe.nombre                                     AS nombre_empleado,
  pe.nro_doc                                AS dni_empleado,
  CASE WHEN t.id_tipo_viaje = 1 THEN 0 ELSE 1 END        AS is_ida_vuelta,
  CASE WHEN t.id_tipo_traslado_ida IN (4,5) THEN 1 ELSE 0 END AS is_transporte_publico,
  etl_ida.id_estado_logistica                   AS estado_logistica_ida_id,
  etl_ida.descripcion                           AS estado_logistica_ida_descripcion,
  etl_vuelta.id_estado_logistica                AS estado_logistica_vuelta_id,
  etl_vuelta.descripcion                        AS estado_logistica_vuelta_descripcion,
  NULL                                          AS requiere_revision,
  NULL                                          AS nombre_tramitador,
  NULL                                          AS apellido_tramitador,
  NULL as autorizacion_ambulancia,
  ti.id_satapp_ida as id_satapp_ida,
  ti.id_satapp_vuelta as id_satapp_vuelta,
  ti.id_moovear_ida as id_moovear_ida,
  ti.id_moovear_vuelta as id_moovear_vuelta,
  NULL as es_duplicado_autorizado
FROM traslados_internos t
  JOIN tipos_traslados ttr   ON t.id_tipo_traslado_ida    = ttr.id_tipo_traslado
  LEFT JOIN tipos_traslados ttra  ON t.id_tipo_traslado_vuelta = ttra.id_tipo_traslado
  JOIN clientes c            ON t.id_cliente              = c.id_cliente
  JOIN personas pe           ON t.id_persona              = pe.id_persona
  LEFT JOIN proveedores_servicios_traslados pst_ida   ON t.id_proveedor_servicio_traslado_ida   = pst_ida.id_proveedor_servicio_traslado
  LEFT JOIN proveedores p_ida                        ON pst_ida.id_proveedor                    = p_ida.id_proveedor
  LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
  LEFT JOIN proveedores p_vuelta                     ON pst_vuelta.id_proveedor                 = p_vuelta.id_proveedor
  LEFT JOIN estados_traslados et                     ON t.id_estado_traslado                    = et.id_estado_traslado
  LEFT JOIN localidades l1 ON t.id_localidad_origen_ida      = l1.id_localidad
  LEFT JOIN localidades l2 ON t.id_localidad_destino_ida     = l2.id_localidad
  LEFT JOIN localidades l3 ON t.id_localidad_origen_vuelta   = l3.id_localidad
  LEFT JOIN localidades l4 ON t.id_localidad_destino_vuelta  = l4.id_localidad
  LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
  LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
  LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
  LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
  LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
  LEFT JOIN traslado_integraciones ti ON t.id_traslado_interno = ti.id_traslado_interno
    ', where_clause);

    SET sql_query = CONCAT(sql_query,
                           ' ORDER BY ',
                           CASE
                               WHEN sortField = 'fechaTraslado' THEN CONCAT('t.fecha_traslado ', sortOrder)
                               ELSE CONCAT('t.id_traslado_interno ', sortOrder)
                               END
                    );

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('
    SELECT COUNT(DISTINCT t.id_traslado_interno) INTO @total_records
    FROM traslados_internos t
      LEFT JOIN proveedores_servicios_traslados pst_ida     ON t.id_proveedor_servicio_traslado_ida   = pst_ida.id_proveedor_servicio_traslado
      LEFT JOIN proveedores p_ida                            ON pst_ida.id_proveedor                    = p_ida.id_proveedor
      LEFT JOIN proveedores_servicios_traslados pst_vuelta  ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
      LEFT JOIN proveedores p_vuelta                         ON pst_vuelta.id_proveedor                 = p_vuelta.id_proveedor
      JOIN tipos_traslados ttr   ON t.id_tipo_traslado_ida    = ttr.id_tipo_traslado
      LEFT JOIN tipos_traslados ttra  ON t.id_tipo_traslado_vuelta = ttra.id_tipo_traslado
      JOIN clientes c            ON c.id_cliente              = t.id_cliente
      JOIN personas pe           ON pe.id_persona             = t.id_persona
      LEFT JOIN estados_traslados et ON t.id_estado_traslado  = et.id_estado_traslado
      LEFT JOIN localidades l1 ON t.id_localidad_origen_ida      = l1.id_localidad
      LEFT JOIN localidades l2 ON t.id_localidad_destino_ida     = l2.id_localidad
      LEFT JOIN localidades l3 ON t.id_localidad_origen_vuelta   = l3.id_localidad
      LEFT JOIN localidades l4 ON t.id_localidad_destino_vuelta  = l4.id_localidad
    ', where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END
$$
DELIMITER ;

-- Control: el procedure quedo creado y expone las columnas nuevas.
SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs' AND ROUTINE_NAME = 'consulta_traslados_internos_logistica';

-- =============================================================================================
-- 5. VERIFICACIONES FINALES — todas tienen que dar lo indicado
-- =============================================================================================

-- 5.1 La tabla existe y esta vacia (es una promocion, no una migracion de datos).
SELECT COUNT(*) AS pedidos_esperado_0 FROM cs.autorizaciones_traslado_duplicado;

-- 5.2 Las tres columnas nuevas existen. Esperado: 3 filas.
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA = 'cs'
   AND COLUMN_NAME IN ('es_duplicado_autorizado', 'fecha_visto_solicitante')
 ORDER BY TABLE_NAME, COLUMN_NAME;

-- 5.3 Ninguna marca quedo encendida por accidente. Las dos tienen que dar 0.
SELECT COUNT(*) AS traslados_marcados_esperado_0 FROM cs.traslados
 WHERE es_duplicado_autorizado IS NOT NULL;
SELECT COUNT(*) AS tp_marcados_esperado_0 FROM cs.traslados_transporte_publico
 WHERE es_duplicado_autorizado IS NOT NULL;

-- 5.4 El permiso quedo UNA sola vez. El id que le toco depende del ambiente y NO se
--     compara contra ningun valor esperado.
SELECT COUNT(*) AS filas_esperado_1 FROM cs.permisos_sas
 WHERE permiso = 'autorizar_traslado_mismo_dia';
SELECT id_permiso, permiso, activo FROM cs.permisos_sas
 WHERE permiso = 'autorizar_traslado_mismo_dia';

-- 5.5 Los perfiles asignados son EXACTAMENTE los dos de produccion, y estan activos.
SELECT ppp.id_perfil, ps.perfil, ppp.activo
  FROM cs.perfiles_permisos_sas ppp
  JOIN cs.permisos_sas perm ON perm.id_permiso = ppp.id_permiso
  LEFT JOIN cs.perfiles_sas ps ON ps.id_perfil = ppp.id_perfil
 WHERE perm.permiso = 'autorizar_traslado_mismo_dia'
 ORDER BY ppp.id_perfil;

-- 5.6 Los cuatro procedures existen y se recrearon hoy. Esperado: 4 filas.
SELECT ROUTINE_NAME, LAST_ALTERED FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs' AND ROUTINE_NAME IN ('consulta_turnos_tramitadores_sp', 'consulta_traslado_remis_amb_logistica', 'consulta_traslados_aereos_logistica', 'consulta_traslados_internos_logistica')
 ORDER BY ROUTINE_NAME;

-- 5.7 Nadie perdio permisos. Comparar contra el valor anotado ANTES de correr el script:
--     el total tiene que ser el de antes + 2.
SELECT COUNT(*) AS total_asignaciones FROM cs.perfiles_permisos_sas;

-- =============================================================================================
-- 6. ROLLBACK — comentado a proposito. Descomentar SOLO si hay que volver atras.
-- =============================================================================================
--
--  ORDEN INVERSO al de aplicacion, y con una advertencia: si ya hay pedidos cargados, el
--  DROP de la tabla PIERDE la traza de quien autorizo que. Antes de borrar, exportar:
--    SELECT * FROM cs.autorizaciones_traslado_duplicado;
--
--  Los SP se restauran con el respaldo del bloque 0.5, no con este bloque.
--
-- -- 6.1 Quitar la asignacion por perfil y el permiso.
-- START TRANSACTION;
-- DELETE ppp FROM cs.perfiles_permisos_sas ppp
--   JOIN cs.permisos_sas perm ON perm.id_permiso = ppp.id_permiso
--  WHERE perm.permiso = 'autorizar_traslado_mismo_dia';
-- DELETE FROM cs.permisos_sas WHERE permiso = 'autorizar_traslado_mismo_dia';
-- COMMIT;
--
-- -- 6.2 Quitar las columnas de marca.
-- ALTER TABLE cs.traslados                   DROP COLUMN IF EXISTS es_duplicado_autorizado;
-- ALTER TABLE cs.traslados_transporte_publico DROP COLUMN IF EXISTS es_duplicado_autorizado;
--
-- -- 6.3 Quitar la tabla del pedido. ¡Exportar antes!
-- DROP TABLE IF EXISTS cs.autorizaciones_traslado_duplicado;

-- =============================================================================================
--  FIN
-- =============================================================================================

-- =====================================================================
-- V001 — `cs`.`ap_semaforo_parametros`
-- Fecha: 2026-07-30
-- Repo destino: wsaccidentespersonales  (servicio NUEVO)
-- Ruta en el repo: sql/migrations/V001__crear_tabla_ap_semaforo_parametros.sql
-- Change OpenSpec: ap-costos-topeo-etapa1  ·  spec: ap-semaforo-gestion
-- Jira: PENDIENTE — todavia no existe el ticket. Completar el codigo
--       GRV-____ antes de subir la migracion al repo del servicio.
-- =====================================================================
-- POR QUE EXISTE ESTA TABLA
--
--   El semaforo de AP tiene que poder recalibrarse SIN DEPLOY. Negocio ya
--   pidio dos cosas que, si viven en codigo, obligan a compilar y desplegar
--   el servicio cada vez que cambian de opinion:
--
--   1) Mover los cortes intermedios de la escala (hoy 40% y 70%). Son los
--      unicos dos cortes discutidos: se hablo de bajar el corte medio de 70
--      a 65 para adelantar el aviso a gestion.
--
--   2) Pasar de "solo avisar" a "bloquear autorizaciones" cuando la
--      proyeccion excede el tope. El bloqueo se implementa AHORA pero
--      arranca DESACTIVADO; se prende cuando negocio se decida, tocando
--      una fila de esta tabla y nada mas.
--
--   Ademas, el ruido de los avisos por cambio de nivel se regula por nivel
--   (Alto / Muy alto / Excedido), tambien como dato.
--
--   => Todo lo que negocio puede querer cambiar sin pedir una release vive
--      aca. Lo que es regla de negocio dura vive en la vista/servicio.
--
-- POR QUE NO SE USA `cs`.`parametros` (que ya existe, con 567 filas)
--
--   * `cs`.`parametros` es key-value en texto: no tipa el valor, no puede
--     expresar el CHECK de coherencia entre `umbral_bajo` y `umbral_medio`
--     (viven en filas distintas, no en la misma fila) y no garantiza que
--     exista una sola configuracion vigente del modulo.
--   * Tampoco tiene auditoria de quien cambio que: aca hace falta saber quien
--     movio un corte o quien prendio el bloqueo de autorizaciones, porque el
--     parametro impacta plata (topes de poliza). Por eso tabla propia, tipada,
--     con fila unica activa garantizada por la BD y con auditoria completa.
--
-- LOS CORTES 90 Y 100 SON FIJOS — NO SE PARAMETRIZAN
--
--   Por eso NO hay columnas `umbral_alto` ni `umbral_excedido` en esta tabla,
--   y no es un olvido:
--     * 90%  es la marca de "no autorizar mas prestaciones" (Muy alto).
--     * 100% es el tope mismo (Excedido) — es la suma asegurada, no un
--            porcentaje opinable.
--   Ambos son regla de negocio dura y viven en la vista/servicio del
--   semaforo como constantes. Si alguien agrega esas columnas aca, esta
--   habilitando a mover el significado de "excedido", que es exactamente lo
--   que la regla prohibe. La escala completa queda:
--
--     Bajo      : pct <  umbral_bajo            (default  40)
--     Medio     : umbral_bajo  <= pct < umbral_medio  (default 70)
--     Alto      : umbral_medio <= pct <  90     (90 FIJO)
--     Muy alto  : 90 <= pct <= 100              (90 y 100 FIJOS)
--     Excedido  : pct > 100                     (100 FIJO)
--
--   Se usa UNA sola escala: los mismos cortes que clasifican el nivel son
--   los que deciden si corresponde avisar. No hay una segunda tabla de
--   porcentajes de aviso en paralelo.
--
-- PATRON: FILA UNICA ACTIVA (configuracion)
--
--   La tabla es de configuracion global del modulo AP, no por poliza ni por
--   cliente. Se espera exactamente UNA fila con `activo = 1`; los cambios se
--   hacen por UPDATE sobre esa fila. Las filas viejas se dejan con
--   `activo = 0` si en algun momento se prefiere versionar en vez de pisar.
--   La unicidad de la fila activa la garantiza la BD (ver `uk_...` mas abajo),
--   no la aplicacion: si el dia que alguien inserta una segunda fila activa
--   el servicio elige la "primera" con un LIMIT 1, el semaforo pasa a
--   depender del orden fisico de lectura. Eso es un bug silencioso; mejor que
--   el INSERT falle.
--
-- CONVENCIONES DEL ECOSISTEMA APLICADAS
--   * SIN FOREIGN KEYS. Se verifico en INFORMATION_SCHEMA.KEY_COLUMN_USAGE
--     que la base `cs` no declara FKs (ni `denuncia_poliza` ni `polizas_ap`
--     las tienen). Solo indices; las relaciones logicas se documentan.
--   * utf8mb4 / utf8mb4_unicode_ci en tablas nuevas.
--   * Montos en DECIMAL. Nunca float/double. (Aca no hay montos: los
--     umbrales son PORCENTAJES, DECIMAL(5,2).)
--   * Auditoria en toda tabla nueva.
--   * Idempotente: reejecutable sin efecto.
-- =====================================================================


-- =====================================================================
-- 1) ESTRUCTURA
-- =====================================================================

CREATE TABLE IF NOT EXISTS `cs`.`ap_semaforo_parametros` (

  `id_parametro`                      INT           NOT NULL AUTO_INCREMENT,

  -- ---------- Cortes PARAMETRIZABLES de la escala ----------
  -- Porcentaje de la proyeccion sobre la suma asegurada (con IVA incluido).
  -- DECIMAL(5,2) admite hasta 999.99; el CHECK los acota a < 90 igual.
  `umbral_bajo`                       DECIMAL(5,2)  NOT NULL DEFAULT 40.00
      COMMENT 'Corte Bajo->Medio en % de la suma asegurada. Parametrizable.',
  `umbral_medio`                      DECIMAL(5,2)  NOT NULL DEFAULT 70.00
      COMMENT 'Corte Medio->Alto en % de la suma asegurada. Parametrizable.',
  -- NO agregar umbral_alto (90) ni umbral_excedido (100): son FIJOS por regla
  -- de negocio y viven en la vista/servicio. Ver banner de cabecera.

  -- ---------- Habilitacion del aviso por cambio de nivel ----------
  -- El aviso se registra UNA sola vez por (siniestro, nivel); estos flags
  -- solo deciden si ese nivel genera aviso o no. Apagar un nivel reduce
  -- ruido para gestion sin tocar los otros y sin deploy.
  `avisar_nivel_alto`                 TINYINT(1)    NOT NULL DEFAULT 1
      COMMENT '1 = avisa al ingresar a nivel Alto.',
  `avisar_nivel_muy_alto`             TINYINT(1)    NOT NULL DEFAULT 1
      COMMENT '1 = avisa al ingresar a nivel Muy alto (>= 90%, corte fijo).',
  `avisar_nivel_excedido`             TINYINT(1)    NOT NULL DEFAULT 1
      COMMENT '1 = avisa al ingresar a nivel Excedido (> 100%, corte fijo).',

  -- ---------- Interruptor avisar / bloquear ----------
  -- DEFAULT 0 A PROPOSITO: el comportamiento acordado para el arranque es
  -- SOLO AVISAR y dejar la decision de autorizar en la persona. El bloqueo
  -- esta implementado en el servicio pero apagado. Pasar de "solo avisar" a
  -- "bloquear" es UPDATE ... SET bloquear_autorizacion_al_exceder = 1 sobre
  -- la fila activa: NO requiere deploy, ni release, ni reinicio del servicio
  -- (el servicio lee este parametro, no lo cachea de por vida).
  -- Con el flag en 1 el rechazo sigue admitiendo override justificado, igual
  -- que el topeo que ya existe en el sistema.
  `bloquear_autorizacion_al_exceder`  TINYINT(1)    NOT NULL DEFAULT 0
      COMMENT '0 = solo avisa (default acordado). 1 = bloquea autorizaciones al exceder el tope. Cambio sin deploy.',

  -- ---------- Vigencia + auditoria ----------
  `activo`                            TINYINT(1)    NOT NULL DEFAULT 1
      COMMENT '1 = fila de configuracion vigente. Se espera UNA sola activa.',
  `fecha_alta`                        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usuario_alta`                      INT           NULL
      COMMENT 'id_persona que dio de alta la fila. NULL = seed de migracion.',
  `fecha_modificacion`                DATETIME      NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP
      COMMENT 'Se actualiza sola en cada UPDATE (ON UPDATE CURRENT_TIMESTAMP).',
  `usuario_modificacion`              INT           NULL
      COMMENT 'id_persona que hizo el ultimo cambio de parametros. Lo setea la app en el UPDATE.',
  -- Baja logica: se completa cuando se versiona (activo pasa a 0), para saber
  -- quien y cuando dejo de usar esa configuracion. Mismo par que el resto de
  -- las tablas del paquete.
  `fecha_baja`                        DATETIME      NULL DEFAULT NULL
      COMMENT 'Fecha en que la fila se dio de baja (activo = 0). NULL mientras esta vigente.',
  `usuario_baja`                      INT           NULL
      COMMENT 'id_persona que dio de baja la fila. NULL mientras esta vigente.',

  -- Columna generada para que la BD garantice UNA sola fila activa:
  -- vale 1 cuando activo=1 y NULL cuando activo=0. El indice UNIQUE ignora
  -- los NULL, asi que admite N filas historicas inactivas y una sola activa.
  `fila_activa`                       TINYINT(1)
      AS (IF(`activo` = 1, 1, NULL)) PERSISTENT
      COMMENT 'Derivada. Solo existe para sostener el UNIQUE de fila unica activa.',

  PRIMARY KEY (`id_parametro`),
  UNIQUE KEY `uk_ap_semaforo_parametros_activa` (`fila_activa`),

  -- Coherencia de la escala. Ver justificacion en el bloque de abajo.
  CONSTRAINT `ck_ap_semaforo_escala_coherente`
      CHECK (`umbral_bajo` > 0
         AND `umbral_bajo` < `umbral_medio`
         AND `umbral_medio` < 90)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Parametros del semaforo de costos AP. Fila unica activa. Los cortes 90 y 100 son FIJOS y NO estan aca.';


-- ---------------------------------------------------------------------
-- 1.b) COMPATIBILIDAD con ambientes donde V001 ya se corrio con la forma
--      anterior (columna `id_responsable`, sin baja logica). El CREATE de
--      arriba es IF NOT EXISTS, asi que en esos ambientes no hace nada:
--      estos ALTER son los que alinean el esquema. Todos con IF EXISTS /
--      IF NOT EXISTS, asi que son no-op en una base nueva.
-- ---------------------------------------------------------------------
ALTER TABLE `cs`.`ap_semaforo_parametros`
  CHANGE COLUMN IF EXISTS `id_responsable` `usuario_modificacion` INT NULL
      COMMENT 'id_persona que hizo el ultimo cambio de parametros. Lo setea la app en el UPDATE.';

ALTER TABLE `cs`.`ap_semaforo_parametros`
  ADD COLUMN IF NOT EXISTS `fecha_baja` DATETIME NULL DEFAULT NULL
      COMMENT 'Fecha en que la fila se dio de baja (activo = 0). NULL mientras esta vigente.'
      AFTER `usuario_modificacion`,
  ADD COLUMN IF NOT EXISTS `usuario_baja` INT NULL
      COMMENT 'id_persona que dio de baja la fila. NULL mientras esta vigente.'
      AFTER `fecha_baja`;


-- =====================================================================
-- POR QUE CHECK Y NO UNA VERIFICACION COMENTADA
-- =====================================================================
--   Se eligio CHECK. Razones:
--
--   * El servidor es MariaDB 10.5.29 (verificado con SELECT VERSION() sobre
--     la replica read-only, 2026-07-30). Desde 10.2.1 MariaDB soporta y
--     ENFORZA CHECK, y desde 10.2 admite indices sobre columnas generadas:
--     las dos garantias declarativas de este script estan cubiertas por el
--     motor que hay en produccion, no por una version futura.
--   * La condicion del CHECK compara solo columnas de la MISMA fila contra
--     literales: no hay subquery, ni funcion no determinista, ni referencia
--     a otra tabla. Es exactamente el caso que MariaDB acepta.
--   * Esta tabla se edita a mano o desde una pantalla de configuracion, no
--     por un proceso batch controlado. Un `umbral_medio = 30` con
--     `umbral_bajo = 40` no explota: deja el semaforo clasificando al
--     reves, en silencio, sobre topes de poliza. Una verificacion comentada
--     al pie del script no protege de un UPDATE hecho en marzo del año que
--     viene; el CHECK si.
--   * El literal 90 dentro del CHECK es legitimo justamente PORQUE 90 es un
--     corte fijo de negocio. No es un valor de configuracion escondido en
--     una constraint: es la misma regla que prohibe parametrizarlo, escrita
--     tambien en la BD. `umbral_medio < 90` impide que el corte
--     parametrizable se meta arriba del corte fijo y deje el nivel Alto
--     vacio o invertido.
--   * Consecuencia asumida: si algun dia negocio cambia el corte fijo de
--     90, hay que hacer `ALTER TABLE ... DROP CONSTRAINT / ADD CONSTRAINT`.
--     Es deliberado — cambiar 90 es cambiar la regla, y una regla se cambia
--     con una migracion revisada, no con un UPDATE.
--
--   Se agrega ADEMAS el bloque de verificacion read-only del final, que no
--   reemplaza al CHECK: sirve para dejar constancia del estado post-deploy.
--
--   Nota sobre el `activo`: la unicidad de la fila activa NO se puede
--   expresar en un CHECK (necesita mirar otras filas). Por eso va como
--   columna generada + UNIQUE, que es la unica forma declarativa de
--   sostenerlo en MariaDB sin trigger.


-- =====================================================================
-- 2) SEED — fila de configuracion vigente (idempotente)
-- =====================================================================
-- Todos los valores son los defaults acordados con negocio:
--   40 / 70 · avisos de los 3 niveles prendidos · BLOQUEO APAGADO.
--
-- DOS DETALLES DEL SEED, los dos deliberados:
--
--   * `FROM DUAL` es obligatorio, no cosmetico. Un SELECT de literales con
--     WHERE necesita una tabla de la cual colgar el WHERE: sin FROM, MariaDB
--     corta con error de sintaxis (1064) y la migracion no aplica.
--
--   * La guarda es `NOT EXISTS (SELECT 1 FROM ap_semaforo_parametros)` — la
--     tabla ENTERA vacia, no solo "sin fila activa". Con el patron de fila
--     unica activa, guardar por `WHERE activo = 1` tendria dos problemas:
--     (a) si alguien versiono la configuracion y dejo la fila vigente en
--         `activo = 0` a proposito, reejecutar el script le resucitaria una
--         fila activa con los defaults, pisando la decision operativa;
--     (b) si por lo que fuera ya hubiese una fila activa, el INSERT igual
--         reventaria contra `uk_ap_semaforo_parametros_activa` (1062).
--     Guardando por tabla vacia el script es realmente reejecutable sin
--     efecto y nunca puede crear una segunda fila activa.

INSERT INTO `cs`.`ap_semaforo_parametros`
       (`umbral_bajo`, `umbral_medio`,
        `avisar_nivel_alto`, `avisar_nivel_muy_alto`, `avisar_nivel_excedido`,
        `bloquear_autorizacion_al_exceder`,
        `activo`, `fecha_alta`, `usuario_alta`)
SELECT 40.00, 70.00,
       1, 1, 1,
       0,            -- SOLO AVISA. Se prende por UPDATE cuando negocio lo decida.
       1, NOW(), NULL
  FROM DUAL
 WHERE NOT EXISTS (
       SELECT 1 FROM `cs`.`ap_semaforo_parametros`
 );


-- =====================================================================
-- 3) VERIFICACION (read-only — EJECUTABLE, correr junto con la migracion)
-- =====================================================================
-- Estas migraciones se aplican A MANO: la verificacion es el unico control
-- de que quedo bien. Por eso V1..V4 van DESCOMENTADAS y se corren siempre
-- (son SELECT puros, no escriben nada). Solo V5/V6 quedan comentadas,
-- porque son pruebas NEGATIVAS que deben fallar a proposito y abortarian
-- el script si corrieran solas.

-- V1. La tabla existe con el charset/collation esperados
-- ESPERADO: 1 fila, InnoDB, utf8mb4_unicode_ci
SELECT 'V1 tabla' AS chequeo, TABLE_NAME, ENGINE, TABLE_COLLATION
  FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_semaforo_parametros';

-- V2. Hay EXACTAMENTE una fila activa, con los defaults acordados
-- ESPERADO: 1 fila · 40.00 / 70.00 · 1/1/1 · bloqueo 0 · activo 1
--           usuario_modificacion / fecha_baja / usuario_baja en NULL
SELECT 'V2 fila activa' AS chequeo, id_parametro,
       umbral_bajo, umbral_medio,
       avisar_nivel_alto, avisar_nivel_muy_alto, avisar_nivel_excedido,
       bloquear_autorizacion_al_exceder,
       activo, fecha_alta, usuario_alta,
       fecha_modificacion, usuario_modificacion,
       fecha_baja, usuario_baja
  FROM `cs`.`ap_semaforo_parametros`
 WHERE activo = 1;

-- V3. Coherencia de la escala y del arranque (debe dar todo 'OK')
SELECT 'V3 coherencia' AS chequeo,
       (SELECT COUNT(*) FROM `cs`.`ap_semaforo_parametros` WHERE activo = 1) AS filas_activas,
       CASE WHEN (SELECT COUNT(*) FROM `cs`.`ap_semaforo_parametros` WHERE activo = 1) = 1
            THEN 'OK — fila unica' ELSE 'REVISAR — no hay exactamente una fila activa' END AS unicidad,
       CASE WHEN EXISTS (SELECT 1 FROM `cs`.`ap_semaforo_parametros`
                          WHERE activo = 1 AND umbral_bajo < umbral_medio AND umbral_medio < 90)
            THEN 'OK — umbral_bajo < umbral_medio < 90' ELSE 'REVISAR — escala incoherente' END AS escala,
       CASE WHEN EXISTS (SELECT 1 FROM `cs`.`ap_semaforo_parametros`
                          WHERE activo = 1 AND bloquear_autorizacion_al_exceder = 0)
            THEN 'OK — arranca SOLO AVISANDO' ELSE 'REVISAR — el bloqueo quedo prendido' END AS modo_arranque;

-- V4. La constraint quedo declarada (y por lo tanto se enforza)
-- ESPERADO: ck_ap_semaforo_escala_coherente
SELECT 'V4 constraint' AS chequeo, CONSTRAINT_NAME, CHECK_CLAUSE
  FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA = 'cs' AND TABLE_NAME = 'ap_semaforo_parametros';

-- V4.b Las columnas de auditoria quedaron con el nombre unificado del paquete
-- ESPERADO: usuario_modificacion, fecha_baja, usuario_baja (3 filas).
--           Si aparece id_responsable, el ALTER de compatibilidad no corrio.
SELECT 'V4b auditoria' AS chequeo, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_semaforo_parametros'
   AND COLUMN_NAME IN ('usuario_modificacion','fecha_baja','usuario_baja','id_responsable')
 ORDER BY ORDINAL_POSITION;

-- V5. Prueba NEGATIVA del CHECK — DEBE FALLAR con ER_CONSTRAINT_FAILED (4025).
--     Queda COMENTADA porque escribe y porque tiene que fallar. Correrla a
--     mano solo en ambiente bajo. Si NO falla, el CHECK no se creo
--     (servidor < 10.2.1) y hay que sostener la coherencia en el servicio.
-- UPDATE `cs`.`ap_semaforo_parametros` SET umbral_medio = 30.00 WHERE activo = 1;
-- ESPERADO: ERROR 4025 CONSTRAINT `ck_ap_semaforo_escala_coherente` failed

-- V6. Prueba NEGATIVA de la fila unica activa — DEBE FALLAR con 1062.
--     Idem V5: comentada, solo ambiente bajo.
-- INSERT INTO `cs`.`ap_semaforo_parametros` (activo) VALUES (1);
-- ESPERADO: ERROR 1062 Duplicate entry for key 'uk_ap_semaforo_parametros_activa'


-- =====================================================================
-- 4) OPERACION POSTERIOR (para el runbook, NO parte de la migracion)
-- =====================================================================
-- Cambiar el corte medio de 70 a 65 (pedido tipico de negocio):
--   UPDATE `cs`.`ap_semaforo_parametros`
--      SET umbral_medio = 65.00, usuario_modificacion = <id_persona>
--    WHERE activo = 1;
--
-- Pasar de "solo avisar" a "bloquear" (SIN DEPLOY):
--   UPDATE `cs`.`ap_semaforo_parametros`
--      SET bloquear_autorizacion_al_exceder = 1, usuario_modificacion = <id_persona>
--    WHERE activo = 1;
--
-- Silenciar el aviso del nivel Alto por ruido:
--   UPDATE `cs`.`ap_semaforo_parametros`
--      SET avisar_nivel_alto = 0, usuario_modificacion = <id_persona>
--    WHERE activo = 1;
--
-- Nota: el UPDATE PISA el valor anterior (queda el ultimo responsable y la
-- ultima fecha, no la serie de cambios). Si negocio pide trazabilidad del
-- historial de parametros, se resuelve versionando en dos pasos —
--   1) UPDATE ... SET activo = 0, fecha_baja = NOW(), usuario_baja = <id_persona>
--        WHERE activo = 1;
--   2) INSERT de la fila nueva con los valores nuevos y activo = 1
--        (el UNIQUE de fila activa ya lo permite, porque `fila_activa` queda
--         en NULL en la fila dada de baja)
-- — o con una tabla `ap_semaforo_parametros_historial` en una migracion
-- aparte. Fuera del alcance de V001.
--
-- Ojo con el orden: primero la baja y despues el INSERT. Al revés choca
-- contra `uk_ap_semaforo_parametros_activa` (1062).


-- =====================================================================
-- 5) ROLLBACK (comentado — descomentar solo si hay que revertir)
-- =====================================================================
-- Tabla nueva sin dependencias de datos preexistentes: el rollback es DROP.
-- No hay FKs que soltar (el ecosistema no usa FKs).
--
-- DROP TABLE IF EXISTS `cs`.`ap_semaforo_parametros`;
--
-- Rollback SUAVE (si la tabla ya se esta usando y solo se quiere volver al
-- comportamiento de arranque, sin perder la fila):
-- UPDATE `cs`.`ap_semaforo_parametros`
--    SET umbral_bajo = 40.00, umbral_medio = 70.00,
--        avisar_nivel_alto = 1, avisar_nivel_muy_alto = 1, avisar_nivel_excedido = 1,
--        bloquear_autorizacion_al_exceder = 0
--  WHERE activo = 1;
-- =====================================================================

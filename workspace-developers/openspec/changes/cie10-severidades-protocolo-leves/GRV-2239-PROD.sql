-- ============================================================================
-- GRV-2239 / SE-258 — SQL de PRODUCCIÓN
-- Base: cs
-- Autor: Vanesa Burman
-- Fecha: 13/08/2026
--
-- CORRER ANTES DE DESPLEGAR. Las entidades JPA mapean las dos columnas nuevas:
-- si el código sube antes que los ALTER, los servicios NO ARRANCAN.
--
-- Orden de deploy posterior: wscie10 -> wsauditoria -> wsturnos -> auditoriamedica
--
-- Estado previo verificado en prod el 13/08/2026 (lectura):
--   - Ninguna de las dos columnas existe
--   - El parámetro BLOQUEO_EDICION_CIE10 no existe
--   - El permiso editar_cie10_bloqueado no existe
--   - Los 4 códigos: id_severidad=1, días 10/10/10, habilita_autoaprobacion=1
--   - cs.autorizaciones: 2.238.224 filas
-- ============================================================================

-- Que falle rápido si hay contención, en vez de encolar la plataforma.
-- El lock_wait_timeout global de estos servidores es de 24 horas.
SET SESSION lock_wait_timeout = 5;


-- ============================================================================
-- BLOQUE 1 — autorizaciones.es_aprobacion_automatica
-- ============================================================================
-- INSTANT: cambio de metadatos, no reconstruye la tabla pese a los 2,2 M de filas.
-- No necesita ventana de mantenimiento, pero evitar la primera hora de la mañana
-- (los SPs de tableros hacen CREATE TABLE ... AS SELECT sobre esta tabla).
-- NO cambiar a NOT NULL: la entidad la mapea y los caminos que no la setean mandan NULL.

ALTER TABLE `cs`.`autorizaciones`
  ADD COLUMN IF NOT EXISTS `es_aprobacion_automatica` TINYINT(1) NULL DEFAULT 0
  COMMENT 'GRV-2239: 1 = aprobada automáticamente por el protocolo de leves; 0/NULL = no',
  ALGORITHM=INSTANT;


-- ============================================================================
-- BLOQUE 2 — Bloqueo de edición del CIE-10
-- ============================================================================
-- NULL y no NOT NULL: 15 entidades JPA mapean esta tabla y ninguna usa @DynamicInsert,
-- así que un alta mandaría NULL explícito y un NOT NULL daría error 1048.

ALTER TABLE `cs`.`diagnosticos_cie10`
  ADD COLUMN IF NOT EXISTS `edicion_bloqueada` TINYINT(1) NULL DEFAULT 0
  COMMENT 'GRV-2239: 1 = el auditor médico no puede cambiar el CIE-10 de una denuncia que tenga este código',
  ALGORITHM=INSTANT;

UPDATE `cs`.`diagnosticos_cie10`
   SET edicion_bloqueada = 1
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado: 4 filas afectadas

-- Kill switch. Va ENCENDIDO: el permiso no se asigna a nadie y las correcciones
-- puntuales se resuelven por Mesa de Ayuda sobre la base (Anexo A del plan de pruebas).
INSERT INTO `cs`.`parametros` (`param_name`, `param_value`)
VALUES ('BLOQUEO_EDICION_CIE10', '1')
ON DUPLICATE KEY UPDATE `param_value` = `param_value`;

-- usuario_alta es NOT NULL SIN default y el servidor corre con STRICT_TRANS_TABLES:
-- omitirla da error 1364. 2004 es el usuario técnico de las últimas altas de permisos.
INSERT INTO `cs`.`permisos_sas` (`permiso`, `descripcion`, `activo`, `usuario_alta`)
SELECT 'editar_cie10_bloqueado',
       'Permite corregir el CIE-10 en denuncias con código de patología trazadora bloqueado',
       1,
       2004
  FROM DUAL
 WHERE NOT EXISTS (
       SELECT 1 FROM `cs`.`permisos_sas` WHERE `permiso` = 'editar_cie10_bloqueado');


-- ============================================================================
-- BLOQUE 3 — Catálogo de los 4 CIE-10 trazadores
-- ============================================================================
-- ⚠️ EN SESIÓN INTERACTIVA, NUNCA POR RUNNER.
-- El COMMIT va comentado a propósito: revisar la verificación antes de confirmar.
-- Si se corre por runner, la transacción queda abierta con los locks tomados sobre
-- el catálogo y, con el lock_wait_timeout global de 24 h, cualquier ALTER posterior
-- encola las lecturas de media plataforma.
--
-- Va ÚLTIMO a propósito: minimiza la ventana en que el catálogo queda en Grave sin
-- el código nuevo desplegado, y evita chocar con el ALTER del bloque 2.

-- Estado previo, para dejar registro en el log de la corrida
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado: id_severidad = 1, los tres días = 10, habilita_autoaprobacion = 1, en los cuatro.
-- Si algún valor difiere, PARAR: alguien tocó el catálogo y hay que rehacer el rollback.

START TRANSACTION;

UPDATE `cs`.`diagnosticos_cie10`
   SET id_severidad       = 2,   -- Grave, escala del catálogo
       dias_baja_leve     = 120,
       dias_baja_moderado = 120,
       dias_baja_grave    = 120
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');

-- Subir la severidad NO alcanza: el único interruptor por código es este flag.
UPDATE `cs`.`diagnosticos_cie10`
   SET habilita_autoaprobacion = 0
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');

-- Verificación DENTRO de la transacción — revisar antes de confirmar
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado: 4 filas, id_severidad = 2, los tres días = 120, habilita_autoaprobacion = 0

-- COMMIT;
-- ROLLBACK;


-- ============================================================================
-- VERIFICACIÓN POSTERIOR
-- ============================================================================

SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion, edicion_bloqueada
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');
-- 4 filas: severidad 2, días 120/120/120, autoaprobación 0, bloqueo 1

SELECT param_name, param_value FROM `cs`.`parametros`
 WHERE param_name = 'BLOQUEO_EDICION_CIE10';
-- 1 fila, valor '1'

SELECT id_permiso, permiso, activo FROM `cs`.`permisos_sas`
 WHERE permiso = 'editar_cie10_bloqueado';
-- 1 fila, activo 1

SHOW COLUMNS FROM `cs`.`autorizaciones`     LIKE 'es_aprobacion_automatica';
SHOW COLUMNS FROM `cs`.`diagnosticos_cie10` LIKE 'edicion_bloqueada';

-- El permiso NO le tiene que quedar a nadie — es la decisión tomada:
SELECT COUNT(*) AS perfiles_con_el_permiso
  FROM `cs`.`perfiles_permisos_sas` pp
  JOIN `cs`.`permisos_sas` p ON p.id_permiso = pp.id_permiso
 WHERE p.permiso = 'editar_cie10_bloqueado';
-- Esperado: 0

-- A las pocas horas del deploy, que la autoaprobación esté funcionando.
-- Si devuelve 0 filas, revisar que wsturnos haya levantado con la versión nueva:
SELECT DATE(fecha_solicitud) AS dia, COUNT(*) AS autoaprobadas
  FROM `cs`.`autorizaciones`
 WHERE es_aprobacion_automatica = 1
   AND fecha_solicitud >= CURDATE()
 GROUP BY DATE(fecha_solicitud);


-- ============================================================================
-- ROLLBACK  (valores previos verificados en prod — los 4 códigos comparten los mismos)
-- ============================================================================

-- a) Apagar el bloqueo de edición, en caliente y sin desplegar:
-- UPDATE `cs`.`parametros` SET param_value = '0'
--  WHERE param_name = 'BLOQUEO_EDICION_CIE10';

-- b) Revertir el catálogo a los valores previos:
-- UPDATE `cs`.`diagnosticos_cie10`
--    SET id_severidad = 1, dias_baja_leve = 10, dias_baja_moderado = 10, dias_baja_grave = 10,
--        habilita_autoaprobacion = 1, edicion_bloqueada = 0
--  WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');

-- c) La autoaprobación de protocolo se revierte POR DEPLOY, no por SQL:
--    volver atrás wsturnos. No hay parámetro que la apague.

-- NO DROPEAR LAS COLUMNAS: DROP COLUMN sí reconstruye la tabla, y autorizaciones
-- tiene 2,2 M de filas. Para revertir el comportamiento alcanza con revertir el
-- deploy; las columnas quedan inertes.

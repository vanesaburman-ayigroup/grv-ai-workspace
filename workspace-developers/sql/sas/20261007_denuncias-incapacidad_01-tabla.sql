-- ============================================
-- Script: tabla cs.denuncias_incapacidad
-- Descripcion: crea cs.denuncias_incapacidad, donde se guarda la incapacidad
--              DEFINITIVA y la PRESUNTA de cada denuncia fuera de cs.denuncias.
--              Una fila por (denuncia, tipo). La presunta queda como respaldo.
--
-- Columnas y valores de CHECK (las entidades Java dependen de ellos):
--   tipo   : PRESUNTA | DEFINITIVA
--   origen : MANUAL | CIERRE | MIGRACION | PORTAL
--   porcentaje : NULL o entre 0 y 100
--
-- Verificar antes de aplicar (solo lectura):
--   1. SHOW CREATE TABLE cs.denuncias;
--      El tipo de id_denuncia debe coincidir con la columna id_denuncia de abajo
--      (cs.denuncias.id_denuncia es INT(11); verificado en el primario de produccion).
--   2. SHOW CREATE TABLE cs.personas;
--      El tipo de id_persona debe coincidir con la columna id_persona de abajo
--      (cs.personas.id_persona es DECIMAL(22,0); verificado en el primario de produccion).
--   3. SELECT VERSION();
--      Los CHECK solo se aplican desde MariaDB 10.2.1; en versiones anteriores
--      se aceptan y se ignoran sin error, y la tabla quedaria sin validacion.
--   4. SHOW TABLES LIKE 'denuncias_incapacidad';   (paso OBLIGATORIO)
--      Debe dar vacio. El CREATE TABLE no lleva IF NOT EXISTS a proposito: si la
--      tabla ya existe falla con error 1050 y no se debe seguir; comparar con
--      SHOW CREATE TABLE cs.denuncias_incapacidad antes de decidir.
--   5. Que no existan triggers ni vistas que dependan de esta tabla.
--   6. SELECT @@hostname, @@tx_isolation;
--      Correrlo en el primario del ambiente correcto. En MariaDB 10.x la variable
--      es @@tx_isolation (@@transaction_isolation recien existe desde MariaDB 11.1).
--
-- Orden de despliegue:
--   La tabla va ANTES que los jar de wsdocumento, wsauditoria y wstramitador,
--   porque esos ws leen y escriben en ella al arrancar el flujo.
--   Despues, opcionalmente, el script de backfill de la incapacidad DEFINITIVA.
--
-- Verificar despues de crear la tabla (solo lectura):
--   SHOW CREATE TABLE cs.denuncias_incapacidad;
--   Debe mostrar los 3 CHECK (tipo, origen, porcentaje), el UNIQUE
--   uk_denuncias_incapacidad_denuncia_tipo, ENGINE=InnoDB y CHARSET=utf8mb4.
--
-- Como revertir:
--   1. Bajar primero los jar de wsdocumento, wsauditoria y wstramitador (o confirmar
--      que ningun servicio usa la tabla); si no, van a fallar.
--   2. Revisar si hay datos:
--      SELECT tipo, origen, COUNT(*) FROM cs.denuncias_incapacidad GROUP BY tipo, origen;
--   3. Si hay datos, guardar antes una copia (el nombre de la copia lleva la fecha):
--      CREATE TABLE cs.denuncias_incapacidad_bkp_20261007 AS
--        SELECT * FROM cs.denuncias_incapacidad;
--      SELECT COUNT(*) FROM cs.denuncias_incapacidad_bkp_20261007;  -- debe igualar el original
--   4. DROP TABLE IF EXISTS cs.denuncias_incapacidad;
-- ============================================

CREATE TABLE cs.denuncias_incapacidad (
    id_denuncia_incapacidad BIGINT NOT NULL AUTO_INCREMENT,
    id_denuncia             INT(11)       NOT NULL,
    tipo                    VARCHAR(12) NOT NULL,
    con_incapacidad         TINYINT(1) NOT NULL DEFAULT 0,
    porcentaje              DECIMAL(5,2) NULL,
    origen                  VARCHAR(10) NOT NULL,
    id_persona              DECIMAL(22,0) NULL,
    fecha_carga             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id_denuncia_incapacidad),
    UNIQUE KEY uk_denuncias_incapacidad_denuncia_tipo (id_denuncia, tipo),
    CONSTRAINT chk_denuncias_incapacidad_tipo CHECK (tipo IN ('DEFINITIVA', 'PRESUNTA')),
    CONSTRAINT chk_denuncias_incapacidad_origen CHECK (origen IN ('MANUAL', 'CIERRE', 'MIGRACION', 'PORTAL')),
    CONSTRAINT chk_denuncias_incapacidad_porcentaje CHECK (porcentaje IS NULL OR porcentaje BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Verificacion posterior (solo lectura):
-- SHOW CREATE TABLE cs.denuncias_incapacidad;
-- SELECT tipo, origen, COUNT(*) FROM cs.denuncias_incapacidad GROUP BY tipo, origen;
-- ============================================

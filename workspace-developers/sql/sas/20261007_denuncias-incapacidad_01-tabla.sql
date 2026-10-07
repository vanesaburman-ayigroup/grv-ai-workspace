-- ============================================
-- Script: 20261007_denuncias-incapacidad_01-tabla.sql
-- Descripcion: crea cs.denuncias_incapacidad, donde se guarda la incapacidad
--              DEFINITIVA y la PRESUNTA de cada denuncia fuera de cs.denuncias.
--              Una fila por (denuncia, tipo). La presunta queda como respaldo.
--
-- Columnas y valores de CHECK (las entidades Java dependen de ellos):
--   tipo   : PRESUNTA | DEFINITIVA
--   origen : MANUAL | CIERRE | MIGRACION
--   porcentaje : NULL o entre 0 y 100
--
-- Verificar antes de aplicar (solo lectura):
--   1. SHOW CREATE TABLE cs.denuncias;
--      El tipo de id_denuncia debe coincidir con la columna id_denuncia de abajo
--      (hoy DECIMAL(22,0)).
--   2. SHOW CREATE TABLE cs.personas;
--      El tipo de id_persona debe coincidir con la columna id_persona de abajo
--      (hoy DECIMAL(22,0)).
--   3. SELECT VERSION();
--      Los CHECK solo se aplican desde MariaDB 10.2.1; en versiones anteriores
--      se aceptan y se ignoran sin error, y la tabla quedaria sin validacion.
--   4. SHOW TABLES LIKE 'denuncias_incapacidad';
--      Si ya existe, IF NOT EXISTS no hace nada y oculta una tabla preexistente
--      distinta: comparar con SHOW CREATE TABLE cs.denuncias_incapacidad.
--   5. Que no existan triggers ni vistas que dependan de esta tabla.
--   6. @@hostname: correrlo en el primario del ambiente correcto.
--
-- Orden de despliegue:
--   La tabla va ANTES que los jar de wsdocumento, wsauditoria y wstramitador,
--   porque esos ws leen y escriben en ella al arrancar el flujo.
--   Despues, opcionalmente, el backfill 20261007_denuncias-incapacidad_02-backfill-definitiva.sql.
--
-- Como revertir:
--   DROP TABLE cs.denuncias_incapacidad;
--   Solo si no hay datos que conservar: antes revisar
--   SELECT tipo, origen, COUNT(*) FROM cs.denuncias_incapacidad GROUP BY tipo, origen;
--   y dar de baja los jar que la usan, o van a fallar.
-- ============================================

CREATE TABLE IF NOT EXISTS cs.denuncias_incapacidad (
    id_denuncia_incapacidad BIGINT NOT NULL AUTO_INCREMENT,
    id_denuncia             DECIMAL(22,0) NOT NULL,
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
    CONSTRAINT chk_denuncias_incapacidad_origen CHECK (origen IN ('MANUAL', 'CIERRE', 'MIGRACION')),
    CONSTRAINT chk_denuncias_incapacidad_porcentaje CHECK (porcentaje IS NULL OR porcentaje BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Verificacion posterior (solo lectura):
-- SHOW CREATE TABLE cs.denuncias_incapacidad;
-- SELECT tipo, origen, COUNT(*) FROM cs.denuncias_incapacidad GROUP BY tipo, origen;
-- ============================================

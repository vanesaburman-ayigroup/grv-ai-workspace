-- ============================================
-- Script: 01-denuncias_incapacidad.sql
-- Descripción: incapacidad definitiva y presunta por denuncia, fuera de cs.denuncias.
--              Una fila por (denuncia, tipo). La presunta queda como respaldo.
-- BORRADOR: no aplicado. Antes de correrlo verificar con DESCRIBE cs.denuncias
--           el tipo exacto de id_denuncia (debe coincidir con la columna de abajo)
--           y que no existan triggers ni vistas que dependan de esta tabla.
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
    CONSTRAINT chk_denuncias_incapacidad_origen CHECK (origen IN ('MANUAL', 'CIERRE', 'MIGRACION'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Verificación:
-- SHOW CREATE TABLE cs.denuncias_incapacidad;
-- SELECT tipo, origen, COUNT(*) FROM cs.denuncias_incapacidad GROUP BY tipo, origen;
-- ============================================

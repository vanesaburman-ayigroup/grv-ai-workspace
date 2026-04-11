-- =============================================================================
-- create-claude-readonly-user.sql
-- =============================================================================
-- Crea el usuario dedicado `claude_readonly` para el MCP de MariaDB.
-- Este usuario es usado por grv-ai-workspace para consultas read-only desde
-- los skills y agentes.
--
-- Aplicar en DEV y PROD (dos veces, con los passwords respectivos).
--
-- Pre-requisito: tener privilegios de GRANT en el servidor (normalmente DBA).
-- Contacto: [DEVOPS_REFERENT]
--
-- Post-aplicación:
--   1. Actualizar .env con las nuevas credenciales:
--      GRV_MARIADB_DEV_USER=claude_readonly
--      GRV_MARIADB_DEV_PASSWORD=<password-generado>
--   2. Reiniciar el MCP server de MariaDB.
--   3. Verificar con: SELECT USER(), CURRENT_USER();
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Crear el usuario
-- -----------------------------------------------------------------------------
-- Reemplazar <STRONG_PASSWORD> por un password generado con un password manager.
-- Mínimo 24 caracteres, mix de mayúsculas, minúsculas, números y símbolos.

CREATE USER IF NOT EXISTS 'claude_readonly'@'%'
  IDENTIFIED BY '<STRONG_PASSWORD>';

-- -----------------------------------------------------------------------------
-- 2. Otorgar solo permisos de lectura
-- -----------------------------------------------------------------------------
-- Incluye SELECT, SHOW VIEW, SHOW DATABASES, y acceso a metadata.
-- NO incluye: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, GRANT, TRIGGER,
-- LOCK TABLES, EVENT, SUPER, PROCESS, RELOAD, SHUTDOWN, FILE.

GRANT SELECT ON *.* TO 'claude_readonly'@'%';
GRANT SHOW VIEW ON *.* TO 'claude_readonly'@'%';
GRANT SHOW DATABASES ON *.* TO 'claude_readonly'@'%';

-- Permite ver explain plans (útil para optimizar queries)
-- EXPLAIN no requiere grant adicional en MariaDB, viene con SELECT.

-- -----------------------------------------------------------------------------
-- 3. Límites de recursos
-- -----------------------------------------------------------------------------
-- Previene queries runaway y limita el impacto si algo sale mal.

ALTER USER 'claude_readonly'@'%'
  WITH MAX_QUERIES_PER_HOUR 2000
       MAX_CONNECTIONS_PER_HOUR 500
       MAX_USER_CONNECTIONS 10;

-- -----------------------------------------------------------------------------
-- 4. Aplicar cambios
-- -----------------------------------------------------------------------------

FLUSH PRIVILEGES;

-- -----------------------------------------------------------------------------
-- 5. Verificación
-- -----------------------------------------------------------------------------
-- Correr estas queries para validar que el usuario quedó correcto:

-- SHOW GRANTS FOR 'claude_readonly'@'%';

-- Debería mostrar solo GRANT SELECT, SHOW VIEW, SHOW DATABASES.

-- -----------------------------------------------------------------------------
-- 6. (Opcional) Restricción por host
-- -----------------------------------------------------------------------------
-- En PROD, es recomendable restringir el host desde el que se puede conectar.
-- Reemplazar '%' por la IP/subnet desde donde corre el MCP.
-- Ejemplo (comentado):
--
--   CREATE USER 'claude_readonly'@'10.0.1.0/255.255.255.0'
--     IDENTIFIED BY '<STRONG_PASSWORD>';
--
-- En DEV '%' está bien porque corre local.

-- =============================================================================
-- Rollback (si hace falta revertir)
-- =============================================================================
--
--   DROP USER IF EXISTS 'claude_readonly'@'%';
--   FLUSH PRIVILEGES;
--
-- =============================================================================

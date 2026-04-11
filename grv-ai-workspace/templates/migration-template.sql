-- =============================================================================
-- Migration: V<NNN>__<descripcion>.sql
-- Servicio: <nombre>
-- Autor: <tu-nombre>
-- Fecha: YYYY-MM-DD
-- Ticket: <JIRA-XXXX>
-- =============================================================================
--
-- OBJETIVO DE NEGOCIO
--   <Qué problema resuelve esta migración. Si no podés explicarlo en
--    2 oraciones, probablemente está haciendo demasiado.>
--
-- IMPACTO TÉCNICO
--   Tablas tocadas: <lista>
--   Riesgo: <bajo | medio | alto>
--   Tamaño estimado de tablas afectadas: <aprox>
--   ¿Requiere ventana de mantenimiento?: <sí/no, por qué>
--
-- ROLLBACK PLAN
--   <Cómo se revierte si algo sale mal. Si la migración es irreversible,
--    decir "IRREVERSIBLE — backup previo obligatorio".>
--
-- VERIFICACIÓN POST-APLICACIÓN
--   <Queries o pasos para confirmar que la migración dejó el estado esperado.>
--
-- CHECKLIST
--   [ ] Revisado con grv-migration-guard / mariadb-migration-review
--   [ ] Probado en dev con resultado ok
--   [ ] Compatible backward con código vivo durante el deploy
--   [ ] Idempotente (se puede re-correr sin romper)
--   [ ] Sin PII en comentarios ni ejemplos
--   [ ] InnoDB explícito si crea tabla nueva
--   [ ] ALGORITHM/LOCK explícitos si es ALTER sobre tabla grande
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. DDL
-- -----------------------------------------------------------------------------

-- <statements>


-- -----------------------------------------------------------------------------
-- 2. DML (backfill, si aplica)
-- -----------------------------------------------------------------------------
-- Importante: separar en archivo distinto si el DDL es complejo.
-- MariaDB no hace DDL transaccional, si falla a la mitad queda inconsistente.

-- <statements>


-- -----------------------------------------------------------------------------
-- 3. Verificación
-- -----------------------------------------------------------------------------
-- Queries de sanity check (solo para el autor, no se ejecutan en aplicación).

-- SELECT COUNT(*) FROM tabla_afectada;
-- SHOW INDEX FROM tabla_afectada;

-- =====================================================================
-- AP — Costos y Topeo · Entrega 1.A — Asignar el perfil comercial a Iván Chaparro
-- Change OpenSpec: ap-costos-topeo-etapa1  ·  spec: ap-perfiles-acceso
-- Requiere haber corrido antes: 01-perfil-comercial-ap.sql
-- =====================================================================
-- QUE HACE
--   Vincula a Ivan Chaparro con el perfil `gestor_comercial_accidentes_personales`
--   en `personas_perfiles_sas`. IDEMPOTENTE: reejecutable sin duplicar.
--
-- ANTES DE EJECUTAR
--   1) Correr el PASO 0 y CONFIRMAR que devuelve UNA sola persona.
--      Si devuelve varias (homonimos) o ninguna, PARAR y resolver a mano:
--      NO asumir cual es. Un perfil asignado a la persona equivocada le da
--      acceso a datos economicos que no le corresponden.
--   2) Setear @USUARIO con el id_persona del responsable del alta.
-- =====================================================================

SET @PERFIL_NUEVO = 'gestor_comercial_accidentes_personales';
SET @USUARIO      = NULL;   -- <<< COMPLETAR: id_persona del responsable

-- =====================================================================
-- PASO 0 — Resolver el id_persona de Ivan Chaparro (SOLO LECTURA)
-- =====================================================================
SELECT 'P0 candidatos' AS chequeo, p.id_persona, p.nombre, p.apellido,
       p.nro_doc, p.email, p.activo
  FROM personas p
 WHERE p.apellido LIKE '%Chaparro%'
   AND p.nombre   LIKE '%Iv%n%'      -- cubre Ivan / Iván
 ORDER BY p.activo DESC, p.id_persona;
-- ESPERADO: 1 fila activa. Si hay mas de una, elegir a mano y setear el id abajo.
-- (Si la tabla de personas tiene otro nombre de columna para el estado,
--  ajustar `activo` segun el DESCRIBE.)

-- Completar con el id confirmado del paso 0:
SET @ID_PERSONA = NULL;   -- <<< COMPLETAR con el id_persona de Ivan Chaparro


-- =====================================================================
-- VERIFICACION PREVIA
-- =====================================================================
-- V1. El perfil existe y esta activo (lo creo el script 01)
SELECT 'V1 perfil' AS chequeo, id_perfil, perfil, id_modulo_sas, activo
  FROM perfiles_sas
 WHERE perfil = @PERFIL_NUEVO;
-- ESPERADO: 1 fila activa

-- V2. Perfiles que la persona ya tiene hoy
SELECT 'V2 perfiles actuales' AS chequeo, pf.id_perfil, pf.perfil, pp.activo
  FROM personas_perfiles_sas pp
  JOIN perfiles_sas pf ON pf.id_perfil = pp.id_perfil
 WHERE pp.id_persona = @ID_PERSONA
 ORDER BY pp.activo DESC, pf.id_perfil;
-- Revisar: si ya tiene el perfil comercial activo, no hay nada que hacer.


-- =====================================================================
-- ASIGNACION (transaccional)
-- =====================================================================
START TRANSACTION;

SET @ID_PERFIL = (SELECT id_perfil FROM perfiles_sas
                   WHERE perfil = @PERFIL_NUEVO AND activo = 1 LIMIT 1);

-- Alta del vinculo solo si no existe
INSERT INTO personas_perfiles_sas (id_persona, id_perfil, activo, fecha_alta, usuario_alta)
SELECT @ID_PERSONA, @ID_PERFIL, 1, NOW(), @USUARIO
 WHERE @ID_PERSONA IS NOT NULL
   AND @ID_PERFIL  IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM personas_perfiles_sas
                    WHERE id_persona = @ID_PERSONA AND id_perfil = @ID_PERFIL);

-- Si el vinculo existia dado de baja, reactivarlo
UPDATE personas_perfiles_sas
   SET activo = 1, fecha_baja = NULL, usuario_baja = NULL
 WHERE id_persona = @ID_PERSONA AND id_perfil = @ID_PERFIL AND activo = 0;


-- =====================================================================
-- VERIFICACION POSTERIOR (revisar ANTES de confirmar)
-- =====================================================================
SELECT 'P1 asignado' AS chequeo, pp.id_persona, p.nombre, p.apellido,
       pf.perfil, pp.activo, pp.fecha_alta
  FROM personas_perfiles_sas pp
  JOIN personas     p  ON p.id_persona = pp.id_persona
  JOIN perfiles_sas pf ON pf.id_perfil = pp.id_perfil
 WHERE pp.id_persona = @ID_PERSONA AND pp.id_perfil = @ID_PERFIL;
-- ESPERADO: 1 fila, activo = 1, con el nombre de Ivan Chaparro

SELECT 'P2 permisos efectivos' AS chequeo, pe.id_permiso, pe.permiso
  FROM personas_perfiles_sas pp
  JOIN perfiles_permisos_sas ppe ON ppe.id_perfil = pp.id_perfil AND ppe.activo = 1
  JOIN permisos_sas          pe  ON pe.id_permiso = ppe.id_permiso
 WHERE pp.id_persona = @ID_PERSONA AND pp.activo = 1
 ORDER BY pe.id_permiso;
-- ESPERADO: los permisos del perfil comercial (los 2 heredados del analista
-- + los permisos nuevos de AP cuando se corra el script 03)


-- =====================================================================
-- CONFIRMAR o REVERTIR — descomentar UNA
-- =====================================================================
-- COMMIT;
-- ROLLBACK;

-- RECORDATORIO OPERATIVO: los permisos viajan en la cookie `datos_usuario`,
-- que se escribe en el login. Ivan tiene que CERRAR SESION Y VOLVER A ENTRAR
-- para que el perfil nuevo tenga efecto en el frontend.


-- =====================================================================
-- BAJA (si hay que revertir despues del COMMIT) — baja logica
-- =====================================================================
-- UPDATE personas_perfiles_sas
--    SET activo = 0, fecha_baja = NOW(), usuario_baja = @USUARIO
--  WHERE id_persona = @ID_PERSONA AND id_perfil = @ID_PERFIL AND activo = 1;

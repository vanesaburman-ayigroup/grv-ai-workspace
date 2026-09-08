-- =====================================================================
-- AP — Asignar el perfil comercial a la persona que va a usar la pantalla
-- Change OpenSpec: ap-prefacturacion-y-topeo-venta  ·  spec: ap-perfiles-acceso
-- =====================================================================
-- QUE HACE
--   Vincula una persona al perfil `gestor_comercial_accidentes_personales`, que es el que
--   habilita la pantalla de valores de venta. Cierra la tarea 1.2.1 de
--   `ap-costos-topeo-etapa1`, que quedo pendiente justamente por resolver el id_persona.
--
-- POR QUE HACE FALTA ADEMAS DE LOS PERMISOS
--   El script `02` da de alta los permisos y los cuelga del PERFIL. Pero un perfil sin
--   personas no habilita a nadie: `PermisoGuard` mira los permisos del usuario, que salen
--   de sus perfiles. Verificado en dev el 07/09/2026: el perfil 40 existe, tiene sus dos
--   permisos, y **cero personas asignadas**.
--
-- A QUIEN
--   Verificado en dev: `Ivan Albornoz` -> id_persona **645**.
--
--   OJO CON EL HOMONIMO. En este proyecto hay dos Ivan y no son la misma persona:
--     * Ivan ALBORNOZ  -> Gerencia Comercial. Es quien pacta los valores de venta y el
--                         usuario de esta pantalla. Es el de este script.
--     * Ivan CHAPARRO  -> es de quien son los Excel que hoy usa facturacion. Otro rol,
--                         y no aparece en `cs.personas` de dev.
--   Asignarle el perfil comercial al que no corresponde le da acceso a los precios
--   pactados con cada cliente, que es justo lo que el permiso separado busca evitar.
--
-- IDEMPOTENTE: reejecutable. No duplica el vinculo y reactiva el que estuviera de baja.
--
-- AMBIENTE: dev. Para otro ambiente hay que resolver el id_persona de nuevo — NO es
--   portable, igual que los id_perfil.
--
-- DESPUES DE EJECUTAR
--   **Re-login.** Los perfiles y permisos viajan en la cookie `datos_usuario`.
-- =====================================================================


-- ---------- Parametros ----------
SET @PERFIL   = 'gestor_comercial_accidentes_personales';
SET @PERSONA  = 645;       -- Ivan Albornoz en DEV. Verificar antes de correr en otro ambiente.
SET @USUARIO  = 1000045;   -- Vanesa Burman, responsable del alta


-- =====================================================================
-- VERIFICACION PREVIA  (solo lectura — leer antes de seguir)
-- =====================================================================

-- 1) Que la persona es la que se cree. Si el nombre no es el esperado, PARAR.
SELECT id_persona, nombre, apellido, nro_doc
  FROM personas
 WHERE id_persona = @PERSONA;
-- Esperado en dev: 1 fila, Ivan Albornoz.

-- 2) Que el perfil existe y tiene los permisos de venta colgados.
SELECT ps.id_perfil, ps.perfil, pm.permiso
  FROM perfiles_sas ps
  JOIN perfiles_permisos_sas pps ON pps.id_perfil = ps.id_perfil AND pps.activo = 1
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
 WHERE ps.perfil = @PERFIL
   AND pm.permiso IN ('ver_valores_venta_ap', 'administrar_valores_venta_ap')
 ORDER BY pm.permiso;
-- Esperado: 2 filas. Si sale vacio, correr primero el script `02`.

-- 3) Con que perfiles cuenta hoy esa persona.
SELECT ps.perfil, pp.activo
  FROM personas_perfiles_sas pp
  JOIN perfiles_sas ps ON ps.id_perfil = pp.id_perfil
 WHERE pp.id_persona = @PERSONA
 ORDER BY ps.perfil;


START TRANSACTION;

-- =====================================================================
-- El vinculo persona -> perfil
-- =====================================================================

INSERT INTO personas_perfiles_sas (id_persona, id_perfil, activo, fecha_alta, usuario_alta)
SELECT @PERSONA, ps.id_perfil, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
 WHERE ps.perfil = @PERFIL
   AND NOT EXISTS (SELECT 1 FROM personas_perfiles_sas x
                    WHERE x.id_persona = @PERSONA AND x.id_perfil = ps.id_perfil);

-- Reactivar si el vinculo existia dado de baja, limpiando la fecha: una fila activa con
-- fecha_baja cargada es un estado que despues nadie entiende.
UPDATE personas_perfiles_sas pp
  JOIN perfiles_sas ps ON ps.id_perfil = pp.id_perfil
   SET pp.activo = 1, pp.fecha_baja = NULL, pp.usuario_baja = NULL
 WHERE pp.id_persona = @PERSONA
   AND ps.perfil = @PERFIL
   AND pp.activo = 0;


-- =====================================================================
-- VERIFICACION POSTERIOR
-- =====================================================================

SELECT p.id_persona, p.nombre, p.apellido, ps.perfil, pp.activo
  FROM personas_perfiles_sas pp
  JOIN perfiles_sas ps ON ps.id_perfil = pp.id_perfil
  JOIN personas p ON p.id_persona = pp.id_persona
 WHERE pp.id_persona = @PERSONA
   AND ps.perfil = @PERFIL;
-- Esperado: 1 fila, activo=1.

-- Los permisos EFECTIVOS que le quedan de AP. Es lo que va a viajar en la cookie.
SELECT DISTINCT pm.permiso
  FROM personas_perfiles_sas pp
  JOIN perfiles_permisos_sas pps ON pps.id_perfil = pp.id_perfil AND pps.activo = 1
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso AND pm.activo = 1
 WHERE pp.id_persona = @PERSONA
   AND pp.activo = 1
   AND (pm.permiso LIKE '%\_ap' OR pm.permiso = 'ver_consolidado_cirugia')
 ORDER BY pm.permiso;
-- Esperado: ver_valores_venta_ap y administrar_valores_venta_ap.

-- Control de idempotencia.
SELECT id_persona, id_perfil, COUNT(*) AS veces
  FROM personas_perfiles_sas
 WHERE id_persona = @PERSONA
 GROUP BY id_persona, id_perfil
HAVING COUNT(*) > 1;
-- Esperado: 0 filas.


-- COMMIT;   -- descomentar despues de validar
-- ROLLBACK; -- si algo no cuadra


-- =====================================================================
-- COMO SE VERIFICA DEL LADO DE LA APLICACION
-- =====================================================================
--   1) Re-login del usuario.
--   2) Tiene que aparecer el item "Valores de venta AP" en el menu lateral.
--   3) `GET /grv/accidentespersonales/ap/valores-venta?idCliente=<n>` -> 200, no 403.
--   4) La grilla va a salir VACIA y eso es correcto: `cs.ap_valores_venta` tiene 0 filas en
--      dev. La carga de la grilla es trabajo de comercial (medido: 10 filas por cliente
--      cubren el 92% del volumen).
-- =====================================================================

-- =====================================================================
-- AP — Prefacturacion y topeo sobre venta · Permisos de valor de venta
--                                            y de administracion de topes
-- Change OpenSpec: ap-prefacturacion-y-topeo-venta  ·  spec: ap-perfiles-acceso
-- =====================================================================
-- QUE HACE
--   Da de alta los TRES permisos que el codigo de `wsaccidentespersonales`
--   exige hoy y que no existen en ningun ambiente, y los asocia al perfil
--   que corresponde. Sin ellos hay 15 endpoints construidos que devuelven
--   403 a cualquier usuario.
--
-- POR QUE FALTAN (verificado el 07/09/2026)
--   El modelo de permisos se rediseño despues de que se escribiera el script
--   de alta original (tarea 1.6 de `ap-costos-topeo-etapa1`) y nadie volvio
--   al SQL. El permiso unico `cargar_valor_venta_prestacion` se partio en el
--   par ver/administrar, y aparecio `administrar_topes_ap` para separar leer
--   de escribir sobre los topes.
--
--   ESTADO DE PARTIDA EN STAGE (de la tarea 1.6, ya ejecutada)
--     103 ver_semaforo_ap              -> gestion   ·  lo usa el codigo  OK
--     104 ver_indicadores_ap           -> gestion   ·  lo usa el codigo  OK
--     105 ver_consolidado_cirugia      -> gestion   ·  declarado, endpoint pendiente (tarea 5.11)
--     106 cargar_valor_venta_prestacion-> comercial ·  HUERFANO: ya no lo pide nadie
--     107 ver_margen_ap                -> comercial ·  sin consumidor todavia; lo usara la vista de margen
--
--   LO QUE ESTE SCRIPT AGREGA
--     administrar_topes_ap          -> gestion    (escrituras de topes y de valores manuales)
--     ver_valores_venta_ap          -> comercial  (lectura de la grilla y los contratos)
--     administrar_valores_venta_ap  -> comercial  (escrituras de la grilla y los contratos)
--
--   Los nombres NO son opinables: salen de `Constantes.java` del ws y tienen
--   que coincidir exactamente, porque `PermisoGuard` compara por string
--   contra lo que viaja en la cookie `datos_usuario`.
--
-- QUE ENDPOINT DESBLOQUEA CADA UNO
--   administrar_topes_ap
--     POST   /ap/topes                       TopeApController
--     PUT    /ap/topes/{idTope}              TopeApController
--     DELETE /ap/topes/{idTope}              TopeApController  (baja logica)
--     POST   /ap/valores-manuales            ValorManualApController
--     PUT    /ap/valores-manuales/{id}       ValorManualApController
--     DELETE /ap/valores-manuales/{id}       ValorManualApController
--   ver_valores_venta_ap  +  administrar_valores_venta_ap
--     los 11 mappings de ValorVentaApController
--     los  4 mappings de ContratoVentaApController
--
-- IDEMPOTENTE: reejecutable. No duplica permisos ni vinculos.
--   `permisos_sas.id_permiso` es AUTO_INCREMENT (no se fuerza el id).
--   `perfiles_permisos_sas` tiene PK compuesta (id_perfil, id_permiso).
--   Los vinculos se resuelven por JOIN sobre el NOMBRE del perfil y del
--   permiso: los id_perfil difieren entre ambientes (stage 28/29, replica de
--   prod 22/25) y hardcodearlos rompe el script al cambiar de ambiente.
--
-- AMBIENTE: dev / test / stage. **NO ejecutar en produccion.**
--   En prod no existen todavia ni los permisos de AP ni el perfil comercial
--   (verificado contra el catalogo de `configurar-sas`, que es un snapshot de
--   prod: no tiene ninguno de los `*_ap`). El alta en prod es una decision
--   aparte, con su propia ventana.
--
-- ANTES DE EJECUTAR
--   1) Setear @USUARIO con el id_persona del responsable del alta.
--   2) Ejecutar el bloque de VERIFICACION PREVIA y leer la salida.
--   3) Decidir sobre el permiso huerfano (bloque 3, comentado por defecto).
--   4) COMMIT o ROLLBACK a mano segun la VERIFICACION POSTERIOR.
--
-- DESPUES DE EJECUTAR
--   Los permisos viajan en la cookie `datos_usuario`: hace falta
--   **re-login** para que un usuario los vea. Sin eso el 403 sigue.
-- =====================================================================


-- ---------- Parametros ----------
SET @PERFIL_GESTION   = 'gestor_accidentes_personales';
SET @PERFIL_COMERCIAL = 'gestor_comercial_accidentes_personales';
SET @USUARIO          = NULL;   -- <<< COMPLETAR: id_persona del responsable del alta

-- Corte de seguridad: con @USUARIO en NULL los INSERT fallan por NOT NULL
-- en usuario_alta, y la transaccion no deja nada a medias.


-- =====================================================================
-- VERIFICACION PREVIA  (solo lectura — revisar antes de seguir)
-- =====================================================================

-- 1) Los dos perfiles tienen que existir. Si alguno no aparece, PARAR:
--    en ese ambiente todavia no se corrio `01-perfil-comercial-ap.sql`
--    del change `ap-costos-topeo-etapa1`.
SELECT id_perfil, perfil, id_modulo_sas, activo
  FROM perfiles_sas
 WHERE perfil IN (@PERFIL_GESTION, @PERFIL_COMERCIAL)
 ORDER BY perfil;
-- Esperado: 2 filas, las dos con activo=1.

-- 2) Foto de los permisos de AP que ya estan.
SELECT id_permiso, permiso, activo
  FROM permisos_sas
 WHERE permiso LIKE '%\_ap'
    OR permiso IN ('cargar_valor_venta_prestacion', 'ver_consolidado_cirugia')
 ORDER BY permiso;
-- Esperado en stage: 5 filas (103-107). Los 3 nuevos NO deben aparecer.

-- 3) Reparto actual de permisos por perfil.
SELECT ps.perfil, pm.permiso, pps.activo
  FROM perfiles_permisos_sas pps
  JOIN perfiles_sas  ps ON ps.id_perfil  = pps.id_perfil
  JOIN permisos_sas  pm ON pm.id_permiso = pps.id_permiso
 WHERE ps.perfil IN (@PERFIL_GESTION, @PERFIL_COMERCIAL)
 ORDER BY ps.perfil, pm.permiso;


START TRANSACTION;

-- =====================================================================
-- BLOQUE 1 — Alta de los tres permisos
-- =====================================================================

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'administrar_topes_ap',
       'Administrar topes de polizas AP: alta, edicion y baja logica de excepciones por asegurado, y carga de valores manuales de consumo (medicacion y prestaciones no convenidas)',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'administrar_topes_ap');

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'ver_valores_venta_ap',
       'Consultar la grilla de valores de venta de AP por cliente, prestacion y zona, sus historiales y los vencimientos de contrato',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'ver_valores_venta_ap');

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'administrar_valores_venta_ap',
       'Cargar y corregir valores de venta de AP, anularlos, aplicar aumentos masivos, duplicar la estructura de un contrato a otro cliente y exportar la grilla',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'administrar_valores_venta_ap');


-- =====================================================================
-- BLOQUE 2 — Asociacion a los perfiles
--   JOIN por NOMBRE, no por id: los ids difieren entre ambientes.
-- =====================================================================

-- 2.a  administrar_topes_ap  ->  perfil de GESTION
--      Nota de criterio: `ValorManualApController` (medicacion y no convenidas)
--      exige este mismo permiso. Si negocio decide que la carga de valores
--      manuales la hace el tramitador y no el gestor, hay que sumar el
--      vinculo tambien a `analista_accidentes_personales` — es agregar un
--      bloque igual a este cambiando @PERFIL_GESTION.
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
  JOIN permisos_sas pm ON pm.permiso = 'administrar_topes_ap'
 WHERE ps.perfil = @PERFIL_GESTION
   AND NOT EXISTS (
         SELECT 1 FROM perfiles_permisos_sas x
          WHERE x.id_perfil  = ps.id_perfil
            AND x.id_permiso = pm.id_permiso);

-- 2.b  ver_valores_venta_ap  ->  perfil COMERCIAL
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
  JOIN permisos_sas pm ON pm.permiso = 'ver_valores_venta_ap'
 WHERE ps.perfil = @PERFIL_COMERCIAL
   AND NOT EXISTS (
         SELECT 1 FROM perfiles_permisos_sas x
          WHERE x.id_perfil  = ps.id_perfil
            AND x.id_permiso = pm.id_permiso);

-- 2.c  administrar_valores_venta_ap  ->  perfil COMERCIAL
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
  JOIN permisos_sas pm ON pm.permiso = 'administrar_valores_venta_ap'
 WHERE ps.perfil = @PERFIL_COMERCIAL
   AND NOT EXISTS (
         SELECT 1 FROM perfiles_permisos_sas x
          WHERE x.id_perfil  = ps.id_perfil
            AND x.id_permiso = pm.id_permiso);

-- 2.d  Reactivar el vinculo si existe pero quedo dado de baja.
--      (Sin esto, una baja previa deja el INSERT sin efecto y el 403 sigue,
--       porque la fila existe con activo=0 y el NOT EXISTS la encuentra.)
--      Se limpian tambien fecha_baja y usuario_baja: dejar una fila activa
--      con fecha de baja cargada es un estado que despues nadie entiende.
--      Mismo criterio que el paso 3 de `01-perfil-comercial-ap.sql`.
UPDATE perfiles_permisos_sas pps
  JOIN perfiles_sas ps ON ps.id_perfil  = pps.id_perfil
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
   SET pps.activo = 1, pps.fecha_baja = NULL, pps.usuario_baja = NULL
 WHERE pps.activo = 0
   AND ( (ps.perfil = @PERFIL_GESTION   AND pm.permiso = 'administrar_topes_ap')
      OR (ps.perfil = @PERFIL_COMERCIAL AND pm.permiso IN ('ver_valores_venta_ap',
                                                           'administrar_valores_venta_ap')) );


-- =====================================================================
-- BLOQUE 3 — El permiso huerfano  (COMENTADO — decision pendiente)
-- =====================================================================
-- `cargar_valor_venta_prestacion` (106 en stage) ya no lo referencia ningun
-- punto del codigo: se partio en el par ver/administrar de arriba.
--
-- Se deja COMENTADO a proposito. Antes de darlo de baja conviene confirmar
-- que ningun otro ws lo lee — se chequea con `/consumers-of` sobre el nombre
-- del permiso, no de memoria. Es baja LOGICA y reversible: para revertir,
-- los mismos dos UPDATE con activo = 1.
--
-- UPDATE perfiles_permisos_sas pps
--   JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
--    SET pps.activo = 0, pps.fecha_baja = CURRENT_TIMESTAMP, pps.usuario_baja = @USUARIO
--  WHERE pm.permiso = 'cargar_valor_venta_prestacion'
--    AND pps.activo = 1;
--
-- UPDATE permisos_sas
--    SET activo = 0, fecha_baja = CURRENT_TIMESTAMP, usuario_baja = @USUARIO
--  WHERE permiso = 'cargar_valor_venta_prestacion'
--    AND activo = 1;
--
-- `ver_margen_ap` (107) NO se toca: hoy no tiene consumidor en el codigo,
-- pero es el permiso de la vista de margen por prestacion (venta, costo y
-- diferencia), que sigue en el alcance. Darlo de baja obligaria a volver a
-- crearlo con otro id.


-- =====================================================================
-- VERIFICACION POSTERIOR  (leer antes de decidir COMMIT o ROLLBACK)
-- =====================================================================

-- 1) Los tres permisos existen y estan activos.
SELECT id_permiso, permiso, activo
  FROM permisos_sas
 WHERE permiso IN ('administrar_topes_ap',
                   'ver_valores_venta_ap',
                   'administrar_valores_venta_ap')
 ORDER BY permiso;
-- Esperado: 3 filas, las tres con activo=1.

-- 2) El reparto por perfil quedo como se espera.
SELECT ps.perfil, pm.permiso, pps.activo
  FROM perfiles_permisos_sas pps
  JOIN perfiles_sas  ps ON ps.id_perfil  = pps.id_perfil
  JOIN permisos_sas  pm ON pm.id_permiso = pps.id_permiso
 WHERE pm.permiso IN ('administrar_topes_ap',
                      'ver_valores_venta_ap',
                      'administrar_valores_venta_ap')
 ORDER BY ps.perfil, pm.permiso;
-- Esperado: 3 filas, todas activo=1
--   gestor_accidentes_personales            administrar_topes_ap
--   gestor_comercial_accidentes_personales  administrar_valores_venta_ap
--   gestor_comercial_accidentes_personales  ver_valores_venta_ap

-- 3) Control de idempotencia: ningun vinculo duplicado.
SELECT pps.id_perfil, pps.id_permiso, COUNT(*) AS veces
  FROM perfiles_permisos_sas pps
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
 WHERE pm.permiso LIKE '%\_ap'
 GROUP BY pps.id_perfil, pps.id_permiso
HAVING COUNT(*) > 1;
-- Esperado: 0 filas.


-- COMMIT;   -- descomentar despues de validar las tres verificaciones
-- ROLLBACK; -- usar si algo no cuadra


-- =====================================================================
-- COMO SE VERIFICA QUE FUNCIONO, DEL LADO DE LA APLICACION
-- =====================================================================
--   1) Re-login del usuario de prueba (los permisos viajan en la cookie
--      `datos_usuario`; sin re-login el 403 sigue aunque el SQL este bien).
--   2) Pegarle a un endpoint de lectura y a uno de escritura:
--        GET  /grv/accidentespersonales/ap/valores-venta       -> 200, no 403
--        POST /grv/accidentespersonales/ap/topes               -> 200/201, no 403
--   3) En stage hay dos usuarios de prueba creados en la tarea 1.7:
--      `qa.tramitadores.rbpi` y `qa.tramitadores.hn8p`.
-- =====================================================================

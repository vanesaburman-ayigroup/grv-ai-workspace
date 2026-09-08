-- =====================================================================
-- AP - Permisos de PREFACTURACION
-- Change OpenSpec: ap-prefacturacion-y-topeo-venta  ·  spec: ap-perfiles-acceso
-- =====================================================================
-- POR QUE EXISTE
--   El perfil de facturacion no tenia permiso propio. Sus pantallas quedaban gateadas por
--   `ver_indicadores_ap`, que es el permiso de los INDICADORES DE GERENCIA sobre toda la cartera.
--
--   Que dos responsabilidades distintas compartieran una llave tenia una consecuencia concreta: no
--   habia forma de darle a Veronica acceso a prefacturacion sin darle tambien el tablero de
--   gerencia, ni de darle a gerencia el tablero sin darle la prefactura. Y del lado del front, los
--   cuatro items de menu de prefacturacion no se podian mostrar sin mostrar tambien el tablero.
--
--   VERIFICADO CONTRA DEV EL 07/09/2026 (`db.dev.sas.colonia-suiza.com.ar`, base `cs`):
--     · permisos de AP presentes: 1006 ver_semaforo_ap · 1007 ver_indicadores_ap
--       1008 ver_consolidado_cirugia · 1009 administrar_topes_ap
--       1010 ver_valores_venta_ap · 1011 administrar_valores_venta_ap
--     · de prefacturacion: NINGUNO (permiso LIKE prefactur -> 0 filas)
--
-- LOS DOS PERMISOS
--   ver_prefacturacion_ap           facturacion   la grilla del mes, el listado de prefacturas,
--                                                 medicamentos y "Como funciona"
--   administrar_prefacturacion_ap   facturacion   CERRAR la prefactura (congela importes y habilita
--                                                 la factura) y reabrirla mientras no haya factura
--
--   VAN SEPARADOS ver / administrar por el mismo criterio que en valores de venta: mirar la
--   prefactura de un mes para entender un importe y cerrarla -que es un acto con consecuencia
--   contable- no son la misma responsabilidad. Hoy `administrar` no lo consume ningun endpoint
--   porque la entidad prefactura todavia no existe; se da de alta igual para que el reparto por
--   perfil quede decidido de una vez y no haya que volver a tocar la base cuando exista.
--
-- A QUE PERFIL VAN
--   `gestor_accidentes_personales` (dev id 39). Es el perfil de gestion/facturacion de AP: ya tiene
--   `administrar_topes_ap`, `ver_semaforo_ap`, `ver_indicadores_ap` y `ver_consolidado_cirugia`.
--
--   NO van al perfil comercial (dev id 40). Comercial pacta y carga los valores de venta; no
--   prefactura. Darle el permiso le abriria un menu de cuatro items que no le corresponde.
--
--   CONSECUENCIA CONOCIDA Y ACEPTADA: la pantalla "Como funciona" es documentacion del circuito y
--   le sirve a los dos perfiles, pero su item de menu cuelga del padre de prefacturacion. Por eso
--   en el front su RUTA se gatea con hasAnyPermission(VER_PREFACTURACION_AP, VER_VALORES_VENTA_AP,
--   VER_INDICADORES_AP) y no solo con el de prefacturacion: comercial llega por link, no por menu.
--   No se resuelve dandole el permiso de prefacturacion a comercial.
--
-- IDEMPOTENTE: reejecutable. No duplica permisos ni vinculos, y reactiva los que esten de baja.
--   Los perfiles se resuelven por NOMBRE: los id_perfil difieren por ambiente
--   (dev 38/39/40, stage 28/29, replica de prod 22/25).
--
-- AMBIENTE: dev / test / stage. **NO ejecutar en produccion.**
--
-- ===================================================================
-- ESTADO POR AMBIENTE
--   dev    APLICADO el 07/09/2026, con COMMIT y verificado releyendo la base.
--            permisos: 1012 ver_prefacturacion_ap · 1013 administrar_prefacturacion_ap
--            2 vinculos activos al perfil 39, 0 duplicados.
--            Idempotencia PROBADA: la segunda corrida inserto 0 filas.
--   test   PENDIENTE
--   stage  PENDIENTE
--   prod   NO CORRER. Y ademas seria inutil hoy: las 6 tablas `ap_*` no estan en produccion
--            (0 de 6), asi que el modulo entero no funciona ahi todavia.
-- ===================================================================
--   Los id_permiso de arriba son los que quedaron EN DEV y NO son portables: cada ambiente
--   asigna los suyos por AUTO_INCREMENT. Este script nunca los usa como literal.
-- ===================================================================

-- -- verificacion previa (solo lectura) ------------------------------
SELECT 'permisos de AP antes' AS bloque, id_permiso, permiso, activo
  FROM permisos_sas
 WHERE permiso LIKE '%\_ap' OR permiso LIKE '%prefactur%'
 ORDER BY permiso;

SELECT 'perfil de gestion' AS bloque, id_perfil, perfil, activo
  FROM perfiles_sas
 WHERE perfil = 'gestor_accidentes_personales';

START TRANSACTION;

-- -- 1) alta de los dos permisos -------------------------------------
--   `usuario_alta` es NOT NULL sin default. Se usa 1 (usuario de sistema), igual que el 02.
INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT * FROM (
    SELECT 'ver_prefacturacion_ap' AS permiso,
           'AP: ver la prefacturacion mensual por cliente y periodo' AS descripcion,
           1 AS activo, CURRENT_TIMESTAMP AS fecha_alta, 1 AS usuario_alta
) t
WHERE NOT EXISTS (SELECT 1 FROM permisos_sas p WHERE p.permiso = 'ver_prefacturacion_ap');

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT * FROM (
    SELECT 'administrar_prefacturacion_ap' AS permiso,
           'AP: cerrar y reabrir la prefactura mensual' AS descripcion,
           1 AS activo, CURRENT_TIMESTAMP AS fecha_alta, 1 AS usuario_alta
) t
WHERE NOT EXISTS (SELECT 1 FROM permisos_sas p WHERE p.permiso = 'administrar_prefacturacion_ap');

-- reactivar si alguno estuviera dado de baja
UPDATE permisos_sas
   SET activo = 1, fecha_baja = NULL, usuario_baja = NULL
 WHERE permiso IN ('ver_prefacturacion_ap', 'administrar_prefacturacion_ap')
   AND activo = 0;

-- -- 2) vinculo con el perfil de gestion / facturacion ---------------
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, 1
  FROM perfiles_sas ps
  JOIN permisos_sas pm
       ON pm.permiso IN ('ver_prefacturacion_ap', 'administrar_prefacturacion_ap')
 WHERE ps.perfil = 'gestor_accidentes_personales'
   AND NOT EXISTS (SELECT 1 FROM perfiles_permisos_sas x
                    WHERE x.id_perfil = ps.id_perfil AND x.id_permiso = pm.id_permiso);

UPDATE perfiles_permisos_sas pps
  JOIN perfiles_sas ps ON ps.id_perfil = pps.id_perfil
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
   SET pps.activo = 1, pps.fecha_baja = NULL, pps.usuario_baja = NULL
 WHERE ps.perfil = 'gestor_accidentes_personales'
   AND pm.permiso IN ('ver_prefacturacion_ap', 'administrar_prefacturacion_ap')
   AND pps.activo = 0;

-- -- 3) verificacion posterior ---------------------------------------
SELECT 'reparto final' AS bloque, ps.perfil, pm.permiso, pps.activo
  FROM perfiles_permisos_sas pps
  JOIN perfiles_sas ps ON ps.id_perfil = pps.id_perfil
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
 WHERE pm.permiso LIKE '%prefactur%'
 ORDER BY ps.perfil, pm.permiso;

-- duplicados: tiene que dar 0
SELECT 'duplicados' AS bloque, COUNT(*) AS n FROM (
    SELECT id_perfil, id_permiso FROM perfiles_permisos_sas
     GROUP BY id_perfil, id_permiso HAVING COUNT(*) > 1) t;

COMMIT;

-- -- Falta RE-LOGIN: los permisos viajan en la cookie `datos_usuario`. --

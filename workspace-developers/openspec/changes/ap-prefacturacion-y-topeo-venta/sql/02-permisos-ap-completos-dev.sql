-- =====================================================================
-- AP — Permisos y perfiles completos de Accidentes Personales
-- Change OpenSpec: ap-prefacturacion-y-topeo-venta  ·  spec: ap-perfiles-acceso
-- =====================================================================
-- POR QUE EXISTE ESTE SCRIPT ADEMAS DEL 01
--   El `01-permisos-valor-venta-y-topes.sql` da de alta SOLO los tres permisos nuevos,
--   asumiendo que el resto ya estaba. Eso es cierto en STAGE y **falso en DEV**.
--
--   VERIFICADO CONTRA DEV EL 07/09/2026 (`db.dev.sas.colonia-suiza.com.ar`, base `cs`):
--     · las 6 tablas `ap_*` SI estan (V001-V006 aplicadas)
--     · permisos de AP en `permisos_sas`:              **NINGUNO**
--     · perfil `gestor_comercial_accidentes_personales`: **NO EXISTE**
--     · perfiles que si hay: 38 `analista_accidentes_personales`, 39 `gestor_accidentes_personales`,
--       los dos con solo `crear_turnos_analista_quirurgico` y `crear_turnos_laboratorio`
--
--   Los permisos 103-107 de la tarea 1.6 de `ap-costos-topeo-etapa1` se cargaron **en stage**, a
--   mano, y ese script nunca quedo en el repo. Por eso dev nunca los tuvo.
--
--   Consecuencia que importa: sin `ver_semaforo_ap` **las pantallas de Costos y Topeo que ya
--   estan construidas y mergeadas a develop no funcionan en dev**. No es solo un bloqueo de lo
--   nuevo: es que el ambiente nunca estuvo completo.
--
-- QUE HACE
--   Deja el conjunto ENTERO de permisos y perfiles de AP, no un incremento. Reemplaza al `01`
--   en un ambiente vacio; en uno que ya tenga parte, es idempotente y completa lo que falte.
--
--   1. Crea el perfil comercial si no esta, copiando los permisos base del analista (mismo
--      criterio de `01-perfil-comercial-ap.sql` de la etapa 1).
--   2. Da de alta los SEIS permisos que exige `Constantes.java` del ws.
--   3. Asocia cada permiso al perfil que corresponde.
--   4. Reactiva vinculos que existieran dados de baja.
--
-- LOS SEIS PERMISOS Y QUIEN LOS NECESITA
--   ver_semaforo_ap               gestion    ConsumoApController, CarteraApController, TopeApController (GET)
--                                            + el menu de denuncia del front (`MenuDenuncia.js`)
--   ver_indicadores_ap            gestion    CarteraApController, ParametrosSemaforoApController
--   ver_consolidado_cirugia       gestion    declarado; su endpoint es la tarea 5.11, pendiente
--   administrar_topes_ap          gestion    escrituras de /ap/topes y de /ap/valores-manuales
--   ver_valores_venta_ap          comercial  lecturas de /ap/valores-venta y /ap/contratos-venta
--   administrar_valores_venta_ap  comercial  escrituras de esos dos
--
-- IDEMPOTENTE: reejecutable. No duplica permisos, perfil ni vinculos.
--   Los perfiles se resuelven por NOMBRE: los id_perfil difieren por ambiente
--   (dev 38/39, stage 28/29, replica de prod 22/25).
--
-- AMBIENTE: dev / test / stage. **NO ejecutar en produccion.**
--
-- ═══════════════════════════════════════════════════════════════════
-- ESTADO POR AMBIENTE
--   dev    APLICADO el 07/09/2026, con COMMIT y verificado releyendo la base.
--            perfil `gestor_comercial_accidentes_personales` -> id_perfil 40 (modulo 1)
--            permisos: 1006 ver_semaforo_ap · 1007 ver_indicadores_ap
--                      1008 ver_consolidado_cirugia · 1009 administrar_topes_ap
--                      1010 ver_valores_venta_ap · 1011 administrar_valores_venta_ap
--            6 vinculos activos, 0 duplicados.
--            Idempotencia PROBADA: la segunda corrida inserto 0 filas.
--   stage  PENDIENTE. Ahi ya estan los permisos 103-107 con los nombres VIEJOS
--            (`cargar_valor_venta_prestacion`, `ver_margen_ap`) cargados a mano por la
--            tarea 1.6 de `ap-costos-topeo-etapa1`. Al correr este script se suman los
--            tres nuevos sin tocar los viejos; el huerfano se decide aparte (bloque 3).
--   test   PENDIENTE, sin verificar.
--   prod   NO CORRESPONDE todavia.
--
--   **Los ids NO son portables entre ambientes.** En stage el perfil comercial es 29 y
--   en la replica de prod los perfiles de AP son 22 y 25. Por eso el script resuelve
--   todo por NOMBRE: los ids de arriba son un registro de lo que paso, no un parametro.
--
--   Este bloque existe porque el problema que motivo el script fue exactamente su
--   ausencia: la tarea 1.6 se ejecuto en stage, el script no quedo en el repo y nadie
--   anoto el estado, asi que dev nunca los tuvo y nadie se enteró hasta hoy.
-- ═══════════════════════════════════════════════════════════════════
--
-- ANTES DE EJECUTAR
--   Setear @USUARIO. En dev el id_persona de Vanesa Burman es 1000045 (leido de la base).
--
-- DESPUES DE EJECUTAR
--   **Re-login obligatorio.** Los permisos viajan en la cookie `datos_usuario`: sin volver a
--   entrar, el 403 sigue aunque el SQL este bien.
-- =====================================================================


-- ---------- Parametros ----------
SET @MODULO           = 1;      -- tramitadores
SET @PERFIL_ANALISTA  = 'analista_accidentes_personales';
SET @PERFIL_GESTION   = 'gestor_accidentes_personales';
SET @PERFIL_COMERCIAL = 'gestor_comercial_accidentes_personales';
SET @USUARIO          = 1000045;  -- Vanesa Burman, leido de `cs.personas` en dev el 07/09/2026
                                  -- En otro ambiente hay que cambiarlo: el id_persona no es portable.

-- Si se copia este script a otro ambiente y @USUARIO no corresponde, los INSERT igual
-- se ejecutan (la FK no valida contra personas). El dato queda mal atribuido, no roto:
-- verificar el id antes de correrlo fuera de dev.


-- =====================================================================
-- VERIFICACION PREVIA  (solo lectura)
-- =====================================================================

SELECT id_perfil, perfil, id_modulo_sas, activo
  FROM perfiles_sas
 WHERE perfil IN (@PERFIL_ANALISTA, @PERFIL_GESTION, @PERFIL_COMERCIAL)
 ORDER BY perfil;
-- En dev antes de correr esto: 2 filas (falta el comercial).

SELECT id_permiso, permiso, activo
  FROM permisos_sas
 WHERE permiso IN ('ver_semaforo_ap', 'ver_indicadores_ap', 'ver_consolidado_cirugia',
                   'administrar_topes_ap', 'ver_valores_venta_ap', 'administrar_valores_venta_ap')
 ORDER BY permiso;
-- En dev antes de correr esto: 0 filas.


START TRANSACTION;

-- =====================================================================
-- BLOQUE 1 — Perfil comercial
-- =====================================================================

INSERT INTO perfiles_sas (perfil, id_modulo_sas, activo, fecha_alta, usuario_alta)
SELECT @PERFIL_COMERCIAL, @MODULO, 1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM perfiles_sas WHERE perfil = @PERFIL_COMERCIAL);

-- Los permisos base del analista, para que el perfil nuevo pueda operar como los demas.
-- Se copia el conjunto ACTIVO: si el analista tiene un permiso dado de baja, no se arrastra.
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT nuevo.id_perfil, pps.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas nuevo
  JOIN perfiles_sas origen ON origen.perfil = @PERFIL_ANALISTA
  JOIN perfiles_permisos_sas pps ON pps.id_perfil = origen.id_perfil AND pps.activo = 1
 WHERE nuevo.perfil = @PERFIL_COMERCIAL
   AND NOT EXISTS (SELECT 1 FROM perfiles_permisos_sas x
                    WHERE x.id_perfil = nuevo.id_perfil AND x.id_permiso = pps.id_permiso);


-- =====================================================================
-- BLOQUE 2 — Los seis permisos
-- =====================================================================

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'ver_semaforo_ap',
       'Ver el semaforo de consumo contra el tope de un siniestro AP y su desglose',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'ver_semaforo_ap');

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'ver_indicadores_ap',
       'Ver los indicadores agregados de la cartera AP y parametrizar los cortes del semaforo',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'ver_indicadores_ap');

INSERT INTO permisos_sas (permiso, descripcion, activo, fecha_alta, usuario_alta)
SELECT 'ver_consolidado_cirugia',
       'Ver el consolidado de costos de una cirugia por autorizacion',
       1, CURRENT_TIMESTAMP, @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM permisos_sas WHERE permiso = 'ver_consolidado_cirugia');

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
-- BLOQUE 3 — Los vinculos, por nombre de perfil
--   Mismo reparto con el que se cargo stage, mas administrar_topes_ap en gestion.
-- =====================================================================

-- gestion: ver_semaforo_ap, ver_indicadores_ap, ver_consolidado_cirugia, administrar_topes_ap
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
  JOIN permisos_sas pm ON pm.permiso IN ('ver_semaforo_ap', 'ver_indicadores_ap',
                                         'ver_consolidado_cirugia', 'administrar_topes_ap')
 WHERE ps.perfil = @PERFIL_GESTION
   AND NOT EXISTS (SELECT 1 FROM perfiles_permisos_sas x
                    WHERE x.id_perfil = ps.id_perfil AND x.id_permiso = pm.id_permiso);

-- comercial: ver_valores_venta_ap, administrar_valores_venta_ap
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT ps.id_perfil, pm.id_permiso, 1, CURRENT_TIMESTAMP, @USUARIO
  FROM perfiles_sas ps
  JOIN permisos_sas pm ON pm.permiso IN ('ver_valores_venta_ap', 'administrar_valores_venta_ap')
 WHERE ps.perfil = @PERFIL_COMERCIAL
   AND NOT EXISTS (SELECT 1 FROM perfiles_permisos_sas x
                    WHERE x.id_perfil = ps.id_perfil AND x.id_permiso = pm.id_permiso);

-- Reactivar lo que existiera dado de baja, limpiando la fecha: una fila activa con fecha_baja
-- cargada es un estado que despues nadie entiende.
UPDATE perfiles_permisos_sas pps
  JOIN perfiles_sas ps ON ps.id_perfil  = pps.id_perfil
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
   SET pps.activo = 1, pps.fecha_baja = NULL, pps.usuario_baja = NULL
 WHERE pps.activo = 0
   AND ( (ps.perfil = @PERFIL_GESTION AND pm.permiso IN ('ver_semaforo_ap', 'ver_indicadores_ap',
                                                         'ver_consolidado_cirugia', 'administrar_topes_ap'))
      OR (ps.perfil = @PERFIL_COMERCIAL AND pm.permiso IN ('ver_valores_venta_ap',
                                                           'administrar_valores_venta_ap')) );


-- =====================================================================
-- VERIFICACION POSTERIOR  (leer antes de decidir COMMIT o ROLLBACK)
-- =====================================================================

-- 1) Los seis permisos, activos.
SELECT id_permiso, permiso, activo
  FROM permisos_sas
 WHERE permiso IN ('ver_semaforo_ap', 'ver_indicadores_ap', 'ver_consolidado_cirugia',
                   'administrar_topes_ap', 'ver_valores_venta_ap', 'administrar_valores_venta_ap')
 ORDER BY permiso;
-- Esperado: 6 filas, todas activo=1.

-- 2) El reparto.
SELECT ps.perfil, pm.permiso, pps.activo
  FROM perfiles_permisos_sas pps
  JOIN perfiles_sas  ps ON ps.id_perfil  = pps.id_perfil
  JOIN permisos_sas  pm ON pm.id_permiso = pps.id_permiso
 WHERE pm.permiso IN ('ver_semaforo_ap', 'ver_indicadores_ap', 'ver_consolidado_cirugia',
                      'administrar_topes_ap', 'ver_valores_venta_ap', 'administrar_valores_venta_ap')
 ORDER BY ps.perfil, pm.permiso;
-- Esperado: 6 filas, todas activo=1
--   gestor_accidentes_personales            administrar_topes_ap
--   gestor_accidentes_personales            ver_consolidado_cirugia
--   gestor_accidentes_personales            ver_indicadores_ap
--   gestor_accidentes_personales            ver_semaforo_ap
--   gestor_comercial_accidentes_personales  administrar_valores_venta_ap
--   gestor_comercial_accidentes_personales  ver_valores_venta_ap

-- 3) El perfil comercial existe y tiene los permisos base del analista.
SELECT ps.perfil, COUNT(*) AS permisos_activos
  FROM perfiles_sas ps
  JOIN perfiles_permisos_sas pps ON pps.id_perfil = ps.id_perfil AND pps.activo = 1
 WHERE ps.perfil IN (@PERFIL_ANALISTA, @PERFIL_GESTION, @PERFIL_COMERCIAL)
 GROUP BY ps.perfil
 ORDER BY ps.perfil;

-- 4) Control de idempotencia: ningun vinculo duplicado.
SELECT pps.id_perfil, pps.id_permiso, COUNT(*) AS veces
  FROM perfiles_permisos_sas pps
  JOIN permisos_sas pm ON pm.id_permiso = pps.id_permiso
 WHERE pm.permiso LIKE '%\_ap' OR pm.permiso = 'ver_consolidado_cirugia'
 GROUP BY pps.id_perfil, pps.id_permiso
HAVING COUNT(*) > 1;
-- Esperado: 0 filas.


-- COMMIT;   -- descomentar despues de validar las cuatro verificaciones
-- ROLLBACK; -- usar si algo no cuadra


-- =====================================================================
-- COMO SE VERIFICA DEL LADO DE LA APLICACION
-- =====================================================================
--   1) Re-login (los permisos viajan en la cookie `datos_usuario`).
--   2) Perfil de gestion: entrar a un siniestro AP y ver la seccion Costos y Topeo
--      (`GET /ap/siniestros/{id}/consumo` -> 200, no 403), y el tablero de Cartera AP.
--   3) Perfil comercial: `GET /ap/valores-venta?idCliente=<n>` -> 200, no 403.
-- =====================================================================

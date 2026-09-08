-- =====================================================================
-- AP — Costos y Topeo · Entrega 1.A — Perfil de gestor comercial de AP
-- Change OpenSpec: ap-costos-topeo-etapa1  ·  spec: ap-perfiles-acceso
-- =====================================================================
-- QUE HACE
--   Crea el perfil de GESTOR COMERCIAL de Accidentes Personales como copia
--   EXACTA de los permisos de `analista_accidentes_personales` (id_perfil 22),
--   sobre el modulo 1 (tramitadores) — mismo criterio con el que ya se creo
--   `gestor_accidentes_personales` (id_perfil 25).
--
-- ESTADO DE PARTIDA (verificado en replica read-only, julio 2026)
--   id 22 analista_accidentes_personales -> permisos activos 13, 18
--   id 25 gestor_accidentes_personales   -> permisos activos 13, 18  (copia ya hecha)
--   13 = crear_turnos_analista_quirurgico
--   18 = crear_turnos_laboratorio
--
-- IDEMPOTENTE: reejecutable. No duplica el perfil ni los vinculos de permisos.
--   `perfiles_sas.id_perfil` es AUTO_INCREMENT (no se fuerza el id).
--   `perfiles_permisos_sas` tiene PK compuesta (id_perfil, id_permiso).
--
-- ANTES DE EJECUTAR
--   1) Confirmar con negocio el NOMBRE del perfil (@PERFIL_NUEVO).
--   2) Setear @USUARIO con el id_persona del responsable del alta.
--   3) Ejecutar los bloques de VERIFICACION PREVIA y revisar la salida.
--   4) COMMIT o ROLLBACK a mano segun el resultado de la verificacion posterior.
-- =====================================================================

-- ---------- Parametros ----------
SET @PERFIL_ORIGEN = 'analista_accidentes_personales';  -- de quien se copian los permisos
SET @PERFIL_NUEVO  = 'gestor_comercial_accidentes_personales';  -- CONFIRMADO 30/07/2026
SET @MODULO        = 1;      -- tramitadores (mismo modulo que 22 y 25)
SET @USUARIO       = NULL;   -- <<< COMPLETAR: id_persona del responsable del alta

-- Nota sobre el nombre: a futuro este perfil podria pasar a ser el comercial
-- GENERAL (no solo AP). `perfiles_sas.perfil` es VARCHAR(200) y no es FK de
-- nada, asi que renombrarlo despues es un UPDATE de una fila: el `id_perfil`
-- (que es lo que referencia perfiles_permisos_sas y personas_perfiles_sas)
-- no cambia. Arrancamos explicito con AP y se generaliza cuando haga falta.

-- Corte de seguridad: sin usuario no se ejecuta.
-- (Si @USUARIO es NULL, los INSERT fallan por NOT NULL en usuario_alta.)


-- =====================================================================
-- VERIFICACION PREVIA (solo lectura — revisar antes de seguir)
-- =====================================================================

-- V1. El perfil origen existe y tiene permisos activos
SELECT 'V1 origen' AS chequeo, p.id_perfil, p.perfil, p.id_modulo_sas, p.activo,
       COUNT(pp.id_permiso) AS permisos_activos
  FROM perfiles_sas p
  LEFT JOIN perfiles_permisos_sas pp
         ON pp.id_perfil = p.id_perfil AND pp.activo = 1
 WHERE p.perfil = @PERFIL_ORIGEN
 GROUP BY p.id_perfil, p.perfil, p.id_modulo_sas, p.activo;
-- ESPERADO: 1 fila, id_perfil 22, modulo 1, activo 1, permisos_activos 2

-- V2. Detalle de los permisos que se van a copiar
SELECT 'V2 permisos a copiar' AS chequeo, pe.id_permiso, pe.permiso, pe.descripcion
  FROM perfiles_sas p
  JOIN perfiles_permisos_sas pp ON pp.id_perfil = p.id_perfil AND pp.activo = 1
  JOIN permisos_sas pe          ON pe.id_permiso = pp.id_permiso
 WHERE p.perfil = @PERFIL_ORIGEN
 ORDER BY pe.id_permiso;
-- ESPERADO: 13 crear_turnos_analista_quirurgico · 18 crear_turnos_laboratorio

-- V3. El perfil nuevo NO existe todavia (si devuelve fila, ya fue creado)
SELECT 'V3 destino' AS chequeo, id_perfil, perfil, id_modulo_sas, activo
  FROM perfiles_sas
 WHERE perfil = @PERFIL_NUEVO;
-- ESPERADO en la 1ra corrida: 0 filas


-- =====================================================================
-- ALTA (transaccional)
-- =====================================================================
START TRANSACTION;

-- 1) Perfil nuevo — solo si no existe (id_perfil lo asigna AUTO_INCREMENT)
INSERT INTO perfiles_sas (perfil, id_modulo_sas, activo, fecha_alta, usuario_alta)
SELECT @PERFIL_NUEVO, @MODULO, 1, NOW(), @USUARIO
 WHERE NOT EXISTS (SELECT 1 FROM perfiles_sas WHERE perfil = @PERFIL_NUEVO);

-- Resolver el id del perfil destino (recien creado o preexistente)
SET @ID_NUEVO = (SELECT id_perfil FROM perfiles_sas WHERE perfil = @PERFIL_NUEVO LIMIT 1);
SET @ID_ORIGEN = (SELECT id_perfil FROM perfiles_sas WHERE perfil = @PERFIL_ORIGEN LIMIT 1);

-- 2) Copiar los permisos ACTIVOS del origen — solo los que falten
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso, activo, fecha_alta, usuario_alta)
SELECT @ID_NUEVO, pp.id_permiso, 1, NOW(), @USUARIO
  FROM perfiles_permisos_sas pp
 WHERE pp.id_perfil = @ID_ORIGEN
   AND pp.activo = 1
   AND NOT EXISTS (SELECT 1
                     FROM perfiles_permisos_sas x
                    WHERE x.id_perfil = @ID_NUEVO
                      AND x.id_permiso = pp.id_permiso);

-- 3) Reactivar vinculos que existieran dados de baja (deja el estado consistente)
UPDATE perfiles_permisos_sas pp
   SET pp.activo = 1, pp.fecha_baja = NULL, pp.usuario_baja = NULL
 WHERE pp.id_perfil = @ID_NUEVO
   AND pp.activo = 0
   AND pp.id_permiso IN (SELECT id_permiso
                           FROM perfiles_permisos_sas
                          WHERE id_perfil = @ID_ORIGEN AND activo = 1);


-- =====================================================================
-- VERIFICACION POSTERIOR (revisar ANTES de confirmar)
-- =====================================================================

-- P1. El perfil quedo creado y activo
SELECT 'P1 perfil creado' AS chequeo, id_perfil, perfil, id_modulo_sas, activo, fecha_alta
  FROM perfiles_sas
 WHERE id_perfil = @ID_NUEVO;
-- ESPERADO: 1 fila, modulo 1, activo 1

-- P2. PARIDAD de permisos con el analista: debe dar 'OK'
SELECT 'P2 paridad' AS chequeo,
       (SELECT COUNT(*) FROM perfiles_permisos_sas WHERE id_perfil = @ID_ORIGEN AND activo = 1) AS permisos_origen,
       (SELECT COUNT(*) FROM perfiles_permisos_sas WHERE id_perfil = @ID_NUEVO  AND activo = 1) AS permisos_destino,
       CASE WHEN NOT EXISTS (
              -- diferencia simetrica de los dos conjuntos de id_permiso
              SELECT id_permiso FROM perfiles_permisos_sas WHERE id_perfil = @ID_ORIGEN AND activo = 1
              AND id_permiso NOT IN (SELECT id_permiso FROM perfiles_permisos_sas WHERE id_perfil = @ID_NUEVO AND activo = 1)
              UNION ALL
              SELECT id_permiso FROM perfiles_permisos_sas WHERE id_perfil = @ID_NUEVO AND activo = 1
              AND id_permiso NOT IN (SELECT id_permiso FROM perfiles_permisos_sas WHERE id_perfil = @ID_ORIGEN AND activo = 1)
            ) THEN 'OK — conjuntos identicos'
            ELSE 'REVISAR — hay diferencias' END AS resultado;
-- ESPERADO: permisos_origen = permisos_destino = 2, resultado 'OK'

-- P3. Detalle de los permisos del perfil nuevo
SELECT 'P3 detalle' AS chequeo, pe.id_permiso, pe.permiso
  FROM perfiles_permisos_sas pp
  JOIN permisos_sas pe ON pe.id_permiso = pp.id_permiso
 WHERE pp.id_perfil = @ID_NUEVO AND pp.activo = 1
 ORDER BY pe.id_permiso;
-- ESPERADO: 13 · 18

-- P4. Los tres perfiles AP juntos (foto final)
SELECT 'P4 perfiles AP' AS chequeo, p.id_perfil, p.perfil, p.id_modulo_sas, p.activo,
       COUNT(pp.id_permiso) AS permisos_activos
  FROM perfiles_sas p
  LEFT JOIN perfiles_permisos_sas pp ON pp.id_perfil = p.id_perfil AND pp.activo = 1
 WHERE p.perfil IN (@PERFIL_ORIGEN, 'gestor_accidentes_personales', @PERFIL_NUEVO)
 GROUP BY p.id_perfil, p.perfil, p.id_modulo_sas, p.activo
 ORDER BY p.id_perfil;
-- ESPERADO: 3 filas (22 analista, 25 gestor, N comercial), todas con 2 permisos activos


-- =====================================================================
-- CONFIRMAR o REVERTIR — descomentar UNA de las dos
-- =====================================================================
-- COMMIT;
-- ROLLBACK;


-- =====================================================================
-- ROLLBACK POSTERIOR (si ya se hizo COMMIT y hay que dar de baja)
-- Baja LOGICA, nunca DELETE fisico.
-- =====================================================================
-- START TRANSACTION;
-- UPDATE perfiles_permisos_sas
--    SET activo = 0, fecha_baja = NOW(), usuario_baja = @USUARIO
--  WHERE id_perfil = @ID_NUEVO AND activo = 1;
-- UPDATE perfiles_sas
--    SET activo = 0, fecha_baja = NOW(), usuario_baja = @USUARIO
--  WHERE id_perfil = @ID_NUEVO AND activo = 1;
-- -- Verificar que no queden personas con el perfil asignado:
-- SELECT COUNT(*) AS personas_con_perfil
--   FROM personas_perfiles_sas WHERE id_perfil = @ID_NUEVO AND activo = 1;
-- COMMIT;

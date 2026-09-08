-- ============================================================================
-- GRV-2239 — Remediación puntual: severidad + fecha probable de fin de ILT
-- Denuncia: 138563/0  (id_denuncia = 493702, nro_provisorio HZ493702)
-- Base: cs
-- Autor: Vanesa Burman
-- Fecha: 18/08/2026
--
-- QUÉ CORRIGE
-- La denuncia quedó con `denuncias.id_severidad = 1` (Leve) pese a que sus tres
-- diagnósticos CIE-10 son Graves en el catálogo, y con la fecha probable de fin
-- de ILT calculada con los 10 días viejos de T06.8.
-- Ambos campos se completan al alta y no se resincronizan: la denuncia es del
-- 07/04/2026, anterior a la corrección del catálogo de GRV-2239.
--
-- POR QUÉ NO SE HACE DESDE EL SISTEMA
-- La fecha probable de fin de ILT no es editable en pantalla: se recalcula sola,
-- y sólo cuando CAMBIA el código CIE-10 (AuditoriaMedicaServiceImpl, método
-- guardarDatosDenuncia). Como T06.8 quedó con `edicion_bloqueada = 1` por este
-- mismo ticket, el auditor no puede cambiar el diagnóstico y por lo tanto no
-- puede disparar el recálculo. Por eso va por Mesa de Ayuda.
--
-- ATENCIÓN A LAS DOS ESCALAS — no confundirlas:
--   denuncias.id_severidad          -> tabla `severidades`           (1 Leve, 2 GRAVE, 3 Muerte, 4 Crónico, 5 Moderado)
--   denuncias.id_severidad_denuncia -> tabla `severidades_denuncias` (1 Leve, 2 Mod s/int, 3 Mod c/int, 4 GRAVE, 5 Mortal)
--
-- Este script toca SOLO `id_severidad` (1 -> 2) y `fecha_probable_fin_ilt`.
-- `id_severidad_denuncia` ya está en 4 (Grave) y NO se modifica.
--
-- Estado verificado en producción el 18/08/2026 (lectura):
--   id_severidad = 1 | id_severidad_denuncia = 4 | id_estado_medico = 1 (ILT)
--   fecha_baja              = 2026-04-07
--   fecha_probable_fin_ilt  = 2026-04-17  (10 días -> el valor viejo de T06.8)
--   principal   T06.8 -> catálogo severidad 2, 120 días
--   secundario  S32.0 -> catálogo severidad 2, 180 días
--   secundario  S82.2 -> catálogo severidad 2, 180 días
--
-- ⚠️ EN SESIÓN INTERACTIVA. El COMMIT va comentado a propósito.
-- ============================================================================

SET SESSION lock_wait_timeout = 5;

-- ----------------------------------------------------------------------------
-- 1) Estado previo — dejar registro en el log de la corrida
-- ----------------------------------------------------------------------------
SELECT d.id_denuncia,
       d.nro_asignado,
       d.id_severidad                                  AS sev_catalogo_actual,
       s.descripcion                                   AS sev_catalogo_desc,
       d.id_severidad_denuncia                         AS sev_denuncia_actual,
       sd.descripcion                                  AS sev_denuncia_desc,
       d.diagnostico_cie10                             AS cie10_principal,
       DATE(d.fecha_baja)                              AS fecha_baja,
       DATE(d.fecha_probable_fin_ilt)                  AS fpfi_actual,
       DATEDIFF(d.fecha_probable_fin_ilt, d.fecha_baja) AS dias_aplicados_hoy,
       d.id_estado_medico
  FROM cs.denuncias d
  LEFT JOIN cs.severidades           s  ON s.id_severidad            = d.id_severidad
  LEFT JOIN cs.severidades_denuncias sd ON sd.id_severidad_denuncia  = d.id_severidad_denuncia
 WHERE d.id_denuncia = 493702;
-- Esperado ANTES: sev_catalogo_actual = 1 (Leve), sev_denuncia_actual = 4 (Grave),
--                 fecha_baja = 2026-04-07, fpfi_actual = 2026-04-17, dias_aplicados_hoy = 10
-- Si sev_catalogo_actual ya es 2 y fpfi_actual ya es 2026-08-05, está corregido: NO seguir.

-- ----------------------------------------------------------------------------
-- 2) Corrección
-- ----------------------------------------------------------------------------
START TRANSACTION;

-- 2.a) Severidad del catálogo: Leve -> Grave
--      Idempotente: si ya está en 2, afecta 0 filas y no rompe nada.
UPDATE cs.denuncias
   SET id_severidad = 2          -- Grave, escala del catálogo `severidades`
 WHERE id_denuncia  = 493702
   AND id_severidad = 1;
-- Esperado: 1 fila afectada

-- 2.b) Fecha probable de fin de ILT: fecha_baja + 120 días
--      120 = dias_baja_grave de T06.8 tras GRV-2239. Reproduce exactamente lo que
--      haría `AuditoriaMedicaServiceImpl.diasSegunSeveridad` con severidad Grave:
--      para Grave/Muerte/Crónico usa dias_baja_grave, y suma sobre fecha_baja.
--      No se hardcodea la fecha: se calcula desde el catálogo, así queda trazable.
UPDATE cs.denuncias d
  JOIN cs.diagnosticos_cie10 c ON c.codigo = d.diagnostico_cie10
   SET d.fecha_probable_fin_ilt = DATE_ADD(d.fecha_baja, INTERVAL c.dias_baja_grave DAY)
 WHERE d.id_denuncia = 493702
   AND d.fecha_baja IS NOT NULL
   AND c.dias_baja_grave > 0;
-- Esperado: 1 fila afectada, fecha_probable_fin_ilt = 2026-08-05

-- ----------------------------------------------------------------------------
-- 3) Verificación DENTRO de la transacción — revisar ANTES de confirmar
-- ----------------------------------------------------------------------------
SELECT d.id_denuncia,
       d.nro_asignado,
       d.id_severidad                                   AS sev_catalogo,
       s.descripcion                                    AS sev_catalogo_desc,
       d.id_severidad_denuncia                          AS sev_denuncia,
       sd.descripcion                                   AS sev_denuncia_desc,
       DATE(d.fecha_baja)                               AS fecha_baja,
       DATE(d.fecha_probable_fin_ilt)                   AS fpfi_nueva,
       DATEDIFF(d.fecha_probable_fin_ilt, d.fecha_baja) AS dias_aplicados
  FROM cs.denuncias d
  LEFT JOIN cs.severidades           s  ON s.id_severidad           = d.id_severidad
  LEFT JOIN cs.severidades_denuncias sd ON sd.id_severidad_denuncia = d.id_severidad_denuncia
 WHERE d.id_denuncia = 493702;
-- Esperado DESPUÉS: sev_catalogo = 2 (Grave), sev_denuncia = 4 (Grave) sin cambios,
--                   fpfi_nueva = 2026-08-05, dias_aplicados = 120

-- COMMIT;
-- ROLLBACK;

-- ============================================================================
-- ROLLBACK posterior (valores previos verificados en producción)
-- ============================================================================
-- UPDATE cs.denuncias
--    SET id_severidad           = 1,
--        fecha_probable_fin_ilt = '2026-04-17 00:00:00'
--  WHERE id_denuncia = 493702;

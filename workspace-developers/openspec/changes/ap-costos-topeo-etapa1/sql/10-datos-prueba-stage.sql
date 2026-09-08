-- -----------------------------------------------------------------------------
-- 10 — DATOS DE PRUEBA del semáforo de consumo AP (STAGE)
-- -----------------------------------------------------------------------------
-- Change OpenSpec: ap-costos-topeo-etapa1
-- Autor: Vanesa Burman — Fecha: 2026-08-10
-- Ambiente: STAGE. Aplicado y verificado el 2026-08-10.
-- Reversión: 99-cleanup-datos-prueba-stage.sql
--
-- POR QUÉ EXISTE
-- `cs`.`polizas_ap_topes` estaba VACÍA en stage, así que TODO siniestro AP caía en
-- SIN_TOPE y el semáforo no podía validarse. Este script carga 7 topes elegidos a
-- propósito para que el motor produzca los 5 niveles de la escala (40/70/90/100),
-- más los dos bordes exactos (40,00% y 100,00%) donde se decide si el corte es
-- inclusivo o exclusivo.
--
-- CÓMO SE ELIGIERON LAS SUMAS ASEGURADAS
-- El consumo es REAL (erogaciones + turnos de stage) y no se toca. Lo sintético es
-- el denominador: para cada siniestro se calculó la PROYECCIÓN
-- (FACTURADO + DEVENGADO + ESTIMADO + valores manuales que computan) y se fijó una
-- suma_asegurada que hace caer el porcentaje en el nivel buscado.
--
-- SET DE PRUEBA RESULTANTE (verificado el 2026-08-10)
--   nro_asignado  doc         PROYECCIÓN     TOPE           PCT       NIVEL
--   SW502068      22064459    1.411.579,82   5.000.000,00    28,23%   BAJO
--   SW498249      28967761      336.089,68     600.000,00    56,01%   MEDIO
--   SW498407      38078491      287.590,04     360.000,00    79,89%   ALTO
--   SW498001      38462423      263.050,98     280.000,00    93,95%   MUY ALTO
--   SW504078      31004943      204.919,20     150.000,00   136,61%   EXCEDIDO
--   SW498024      27918394       24.000,00      60.000,00    40,00%   MEDIO (borde)
--   SW498034      33438430       24.000,00      24.000,00   100,00%   MUY ALTO (borde)
-- Los 54 siniestros AP activos restantes quedan SIN_TOPE a propósito: son el caso
-- de control de "no mostrar semáforo engañoso".
--
-- MARCA DE DATO DE PRUEBA
-- `polizas_ap_topes` no tiene columna de observación, así que la marca va en
-- `polizas_ap_topes_historial`.`motivo` (prefijo 'DATO DE PRUEBA ap-costos-topeo-etapa1')
-- y en `ap_valores_manuales`.`observaciones`. El cleanup matchea por esa marca.
--
-- IDEMPOTENCIA: cada bloque chequea existencia por la UNIQUE de negocio
-- (id_poliza, nro_doc, ventana), así que re-correrlo no duplica.
-- -----------------------------------------------------------------------------

SET @usr    := 2004;             -- usuario técnico de stage
SET @marca  := 'DATO DE PRUEBA ap-costos-topeo-etapa1 - borrable (99-cleanup-datos-prueba-stage.sql)';
SET @poliza := 46;               -- cs.polizas_ap.id_poliza — póliza '983320' (95% del facturado AP)

START TRANSACTION;

-- 1) TOPES ---------------------------------------------------------------------
--    tipo_doc=6 (DNI) e id_afiliado salen del afiliado real de cada denuncia.
--    ventana='ANUAL', iva_incluido=1, moneda='ARS', activo=1.
INSERT INTO cs.polizas_ap_topes
    (id_poliza, tipo_doc, nro_doc, id_afiliado, suma_asegurada,
     iva_incluido, moneda, ventana, activo, usuario_alta)
SELECT * FROM (
    SELECT @poliza, 6, '22064459', 338908, 5000000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '28967761', 335365,  600000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '38078491', 335498,  360000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '38462423', 335136,  280000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '31004943', 340873,  150000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '27918394', 335154,   60000.00, 1, 'ARS', 'ANUAL', 1, @usr UNION ALL
    SELECT @poliza, 6, '33438430', 335163,   24000.00, 1, 'ARS', 'ANUAL', 1, @usr
) nuevos (id_poliza, tipo_doc, nro_doc, id_afiliado, suma_asegurada,
          iva_incluido, moneda, ventana, activo, usuario_alta)
WHERE NOT EXISTS (
    SELECT 1 FROM cs.polizas_ap_topes t
    WHERE t.id_poliza = nuevos.id_poliza
      AND t.nro_doc   = nuevos.nro_doc
      AND t.ventana   = nuevos.ventana
);

-- 2) HISTORIAL (es la MARCA de dato de prueba) --------------------------------
INSERT INTO cs.polizas_ap_topes_historial
    (id_tope, suma_anterior, suma_nueva, ventana_anterior, ventana_nueva,
     iva_incluido_anterior, iva_incluido_nuevo, motivo, tipo_cambio, usuario_alta)
SELECT t.id_tope, NULL, t.suma_asegurada, NULL, t.ventana, NULL, t.iva_incluido,
       CONCAT(@marca, ' | nivel esperado: ', CASE t.nro_doc
           WHEN '22064459' THEN 'BAJO'
           WHEN '28967761' THEN 'MEDIO'
           WHEN '38078491' THEN 'ALTO'
           WHEN '38462423' THEN 'MUY_ALTO'
           WHEN '31004943' THEN 'EXCEDIDO'
           WHEN '27918394' THEN 'MEDIO (borde 40,00%)'
           WHEN '33438430' THEN 'MUY_ALTO (borde 100,00%)' END),
       'ALTA', @usr
FROM cs.polizas_ap_topes t
WHERE t.id_poliza = @poliza
  AND t.ventana   = 'ANUAL'
  AND t.nro_doc IN ('22064459','28967761','38078491','38462423','31004943','27918394','33438430')
  AND NOT EXISTS (SELECT 1 FROM cs.polizas_ap_topes_historial h WHERE h.id_tope = t.id_tope);

-- 3) DESNORMALIZACIÓN en denuncia_poliza (es lo que lee el motor) -------------
--    Se resuelve por (id_poliza, nro_doc del afiliado de la denuncia), no por id
--    hardcodeado, para que el script sirva igual en dev.
UPDATE cs.denuncia_poliza dp
JOIN cs.denuncias d  ON d.id_denuncia = dp.id_denuncia
JOIN cs.afiliados a  ON a.id_afiliado = d.id_afiliado
JOIN cs.polizas_ap_topes t
      ON  t.id_poliza = dp.id_poliza
      AND t.nro_doc   = a.nro_doc
      AND t.ventana   = 'ANUAL'
      AND t.activo    = 1
SET dp.suma_asegurada        = t.suma_asegurada,
    dp.moneda                = t.moneda,
    dp.id_tope               = t.id_tope,
    dp.fecha_resolucion_tope = NOW(),
    dp.ventana               = t.ventana,
    dp.iva_incluido          = t.iva_incluido
WHERE dp.activo = 1
  AND dp.id_denuncia IN (502068, 498249, 498407, 498001, 504078, 498024, 498034);

-- 4) VALORES MANUALES sobre SW502068 (caso BAJO) ------------------------------
--    Dos filas que COMPUTAN consumo (medicación valuada por vademécum y una
--    prestación no convenida con acuerdo particular) y una tercera que NO computa
--    porque ya está facturada en la erogación 1154595 — ese es el caso de prueba
--    del anti-doble-conteo (el CHECK exige computa_consumo=0 si hay id_erogacion).
INSERT INTO cs.ap_valores_manuales
    (id_denuncia, id_erogacion, computa_consumo, tipo, descripcion, monto, iva_incluido,
     moneda, fecha_imputacion, cantidad, precio_unitario, fuente_precio, fecha_precio,
     referencia_acuerdo, observaciones, activo, usuario_alta)
SELECT * FROM (
    SELECT 502068, NULL, 1, 'MEDICACION',
           'Enoxaparina 40 mg/0,4 ml jeringa prellenada',
           58200.00, 1, 'ARS', '2026-07-15', 12.000, 4850.00,
           'Alfabeta - lista de precios 2026-07', '2026-07-15', NULL, @marca, 1, @usr
    UNION ALL
    SELECT 502068, NULL, 1, 'NO_CONVENIDA',
           'Honorario cirujano traumatologo - prestacion fuera de nomenclador',
           95000.00, 1, 'ARS', '2026-07-22', NULL, NULL,
           NULL, NULL, 'Acuerdo particular ACU-2026-0417 (mail 2026-07-22)', @marca, 1, @usr
    UNION ALL
    SELECT 502068, 1154595, 0, 'MEDICACION',
           'Kit de curacion ambulatoria - YA facturado en erogacion 1154595',
           12500.00, 1, 'ARS', '2026-06-01', 1.000, 12500.00,
           'Factura 00005-00009927', '2026-06-01', NULL, @marca, 1, @usr
) nuevos (id_denuncia, id_erogacion, computa_consumo, tipo, descripcion, monto, iva_incluido,
          moneda, fecha_imputacion, cantidad, precio_unitario, fuente_precio, fecha_precio,
          referencia_acuerdo, observaciones, activo, usuario_alta)
WHERE NOT EXISTS (
    SELECT 1 FROM cs.ap_valores_manuales v
    WHERE v.id_denuncia = nuevos.id_denuncia
      AND v.descripcion = nuevos.descripcion
      AND v.activo      = 1
);

-- 5) VERIFICACIÓN -------------------------------------------------------------
--    Recalcula la proyección y el nivel con la escala 40/70/90/100 (los cortes 40
--    y 70 salen de ap_semaforo_parametros; 90 y 100 son fijos). Tiene que devolver
--    7 filas: BAJO, MEDIO, ALTO, MUY_ALTO, EXCEDIDO, MEDIO, MUY_ALTO.
SELECT d.nro_asignado, a.nro_doc, dp.id_tope, dp.suma_asegurada,
       COALESCE(e.facturado, 0) + COALESCE(t.devengado, 0)
                                + COALESCE(t.estimado, 0)
                                + COALESCE(m.manual, 0)                       AS proyeccion,
       ROUND((COALESCE(e.facturado, 0) + COALESCE(t.devengado, 0)
                                       + COALESCE(t.estimado, 0)
                                       + COALESCE(m.manual, 0))
             / dp.suma_asegurada * 100, 2)                                    AS pct,
       CASE
         WHEN (COALESCE(e.facturado,0)+COALESCE(t.devengado,0)+COALESCE(t.estimado,0)+COALESCE(m.manual,0))
              / dp.suma_asegurada * 100 <  sp.umbral_bajo  THEN 'BAJO'
         WHEN (COALESCE(e.facturado,0)+COALESCE(t.devengado,0)+COALESCE(t.estimado,0)+COALESCE(m.manual,0))
              / dp.suma_asegurada * 100 <  sp.umbral_medio THEN 'MEDIO'
         WHEN (COALESCE(e.facturado,0)+COALESCE(t.devengado,0)+COALESCE(t.estimado,0)+COALESCE(m.manual,0))
              / dp.suma_asegurada * 100 <  90              THEN 'ALTO'
         WHEN (COALESCE(e.facturado,0)+COALESCE(t.devengado,0)+COALESCE(t.estimado,0)+COALESCE(m.manual,0))
              / dp.suma_asegurada * 100 <= 100             THEN 'MUY_ALTO'
         ELSE 'EXCEDIDO'
       END                                                                    AS nivel
FROM cs.denuncia_poliza dp
JOIN cs.denuncias d ON d.id_denuncia = dp.id_denuncia
LEFT JOIN cs.afiliados a ON a.id_afiliado = d.id_afiliado
CROSS JOIN cs.ap_semaforo_parametros sp
LEFT JOIN (
    SELECT id_denuncia, SUM(COALESCE(monto_facturado, 0) - COALESCE(monto_debitado, 0)) AS facturado
    FROM cs.erogaciones GROUP BY id_denuncia
) e ON e.id_denuncia = dp.id_denuncia
LEFT JOIN (
    SELECT id_denuncia,
           SUM(CASE WHEN id_estado_turno IN (19, 23) AND valor_facturacion IS NULL
                    THEN COALESCE(valor_prestacion, 0) ELSE 0 END) AS devengado,
           SUM(CASE WHEN id_estado_turno NOT IN (19, 23) AND valor_facturacion IS NULL
                    THEN COALESCE(valor_prestacion, 0) ELSE 0 END) AS estimado
    FROM cs.turnos GROUP BY id_denuncia
) t ON t.id_denuncia = dp.id_denuncia
LEFT JOIN (
    SELECT id_denuncia, SUM(monto) AS manual
    FROM cs.ap_valores_manuales
    WHERE activo = 1 AND computa_consumo = 1
    GROUP BY id_denuncia
) m ON m.id_denuncia = dp.id_denuncia
WHERE dp.activo = 1
  AND dp.id_tope IS NOT NULL
  AND sp.fila_activa = 1
ORDER BY dp.id_tope;

-- Revisar el output de (5) y recién entonces:
-- COMMIT;
-- ROLLBACK;
COMMIT;

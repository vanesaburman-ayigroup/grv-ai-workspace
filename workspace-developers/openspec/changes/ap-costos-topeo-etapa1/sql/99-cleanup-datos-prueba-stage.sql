-- -----------------------------------------------------------------------------
-- 99 — REVERSIÓN de los DATOS DE PRUEBA de AP Costos y Topeo en STAGE
-- -----------------------------------------------------------------------------
-- Change OpenSpec: ap-costos-topeo-etapa1
-- Autor: Vanesa Burman — Fecha: 2026-08-10
-- Ambiente: STAGE únicamente. NO correr en producción.
--
-- QUÉ BORRA ESTE SCRIPT
-- El set de prueba cargado el 2026-08-10 para que el semáforo de consumo AP tenga
-- casos en los 5 niveles (Bajo / Medio / Alto / Muy alto / Excedido). Son datos
-- SINTÉTICOS montados sobre siniestros AP REALES de stage: los topes y los valores
-- manuales son inventados, el consumo (erogaciones y turnos) es real y NO se toca.
--
-- CÓMO SE IDENTIFICAN LOS DATOS DE PRUEBA
-- `cs`.`polizas_ap_topes` NO tiene columna de observación/motivo, así que la marca
-- vive en dos lugares:
--   1) `cs`.`polizas_ap_topes_historial`.`motivo`, que arranca con el literal
--      'DATO DE PRUEBA ap-costos-topeo-etapa1' (una fila ALTA por tope).
--   2) Los ids concretos, enumerados abajo. Al 2026-08-10 la tabla estaba VACÍA,
--      así que los topes de prueba son los id_tope 1..12 — pero el borrado de este
--      script NO usa el rango de ids: matchea por la marca del historial, así que
--      sigue siendo correcto si después alguien carga topes reales.
--
-- ⚠ `cs`.`polizas_ap`.`suma_asegurada` (el TOPE GENERAL) es la excepción: esa tabla
-- no tiene ni motivo ni historial, así que NO hay marca posible en la base. Se
-- revierte por lista explícita de `id_poliza` en el bloque 7, al pie. Es el único
-- borrado de este script que no está respaldado por una marca: si alguien cargó un
-- tope general de verdad en stage entre medio, el bloque 7 se lo lleva. Por eso el
-- bloque 7 imprime los valores ANTES de anularlos y sólo pisa los montos exactos
-- que cargó la prueba.
--
-- IDS CONCRETOS CARGADOS (referencia; el borrado NO depende de esta lista)
--   polizas_ap_topes.id_tope          : 1..7   (id_poliza=46, póliza '983320')
--                                       8      (id_poliza=52, doc 46900519)
--                                       9, 10  (id_poliza=28, docs 55358305 / 53802912)
--                                       11, 12 (id_poliza=46, docs 25549372 / 39804776)
--   polizas_ap_topes_historial        : 12 filas (una por tope, tipo_cambio='ALTA')
--   ap_valores_manuales.id_valor_manual: 1, 2, 3               (todas id_denuncia=502068)
--   denuncia_poliza.id_denuncia_poliza: 10, 13, 15, 18, 23, 36, 41
--     (denuncias 498001, 498024, 498034, 498249, 498407, 502068, 504078)
--   polizas_ap.suma_asegurada         : id_poliza 28, 29, 43, 45, 46, 51, 52
--
-- ORDEN OBLIGATORIO: primero se desengancha `denuncia_poliza` (guarda el id_tope),
-- después el historial, después los topes, y recién al final el tope general de
-- `polizas_ap`. Al revés falla, deja huérfanos, o deja una ventana en la que el
-- semáforo ya no tiene excepción y todavía no tiene general. No hay FKs declaradas
-- entre estas tablas, así que el orden es responsabilidad del script, no del motor.
--
-- El borrado del historial (bloque 4) es el que resuelve QUÉ topes son de prueba,
-- así que la tabla temporal se llena ANTES de tocar nada.
-- -----------------------------------------------------------------------------

START TRANSACTION;

-- 0) Foto previa (dejar el output en el ticket antes de borrar) -----------------
SELECT 'ANTES' AS momento,
       (SELECT COUNT(*) FROM cs.polizas_ap_topes)                                   AS topes,
       (SELECT COUNT(*) FROM cs.polizas_ap_topes_historial)                         AS historial,
       (SELECT COUNT(*) FROM cs.ap_valores_manuales)                                AS valores_manuales,
       (SELECT COUNT(*) FROM cs.denuncia_poliza WHERE activo = 1 AND id_tope IS NOT NULL) AS dp_con_tope,
       (SELECT COUNT(*) FROM cs.polizas_ap WHERE suma_asegurada IS NOT NULL)         AS polizas_con_tope_general;

-- Foto de los topes generales que el bloque 7 va a anular. Guardar este output:
-- es lo único que permite reponerlos si se borró algo que no era de prueba.
SELECT id_poliza, poliza, suma_asegurada
  FROM cs.polizas_ap
 WHERE id_poliza IN (28, 29, 43, 45, 46, 51, 52)
 ORDER BY id_poliza;

-- Los topes a borrar, resueltos por la MARCA del historial ---------------------
DROP TEMPORARY TABLE IF EXISTS tmp_topes_prueba_ap;
CREATE TEMPORARY TABLE tmp_topes_prueba_ap (
    id_tope INT NOT NULL PRIMARY KEY
) ENGINE = InnoDB;

INSERT INTO tmp_topes_prueba_ap (id_tope)
SELECT DISTINCT h.id_tope
FROM cs.polizas_ap_topes_historial h
WHERE h.motivo LIKE 'DATO DE PRUEBA ap-costos-topeo-etapa1%';

-- Control: tienen que salir 12 (7 de la primera carga + 5 de la revisión de la
-- tarde del 10/08). Si sale otro número, PARAR y revisar antes de seguir.
SELECT COUNT(*) AS topes_de_prueba_detectados FROM tmp_topes_prueba_ap;

-- 1) Desnormalización en denuncia_poliza: volver las 6 columnas a "tope no resuelto"
--    (NULL en suma_asegurada/id_tope/fecha_resolucion_tope/ventana/iva_incluido).
--    `moneda` es NOT NULL con default 'ARS' y ya venía en 'ARS' antes de la carga:
--    se deja como está, no se toca.
UPDATE cs.denuncia_poliza dp
JOIN tmp_topes_prueba_ap t ON t.id_tope = dp.id_tope
SET dp.suma_asegurada        = NULL,
    dp.id_tope               = NULL,
    dp.fecha_resolucion_tope = NULL,
    dp.ventana               = NULL,
    dp.iva_incluido          = NULL;

-- 2) Valores manuales de prueba (marcados en `observaciones`) -------------------
DELETE FROM cs.ap_valores_manuales
WHERE observaciones LIKE 'DATO DE PRUEBA ap-costos-topeo-etapa1%';

-- 3) Avisos de nivel generados por el motor sobre los topes de prueba ----------
--    (al 2026-08-10 la tabla está vacía; esto limpia lo que haya emitido el
--     semáforo mientras se probaba, incluidos los avisos sin id_tope de las
--     mismas denuncias del set)
DELETE a FROM cs.ap_avisos_nivel_siniestro a
JOIN tmp_topes_prueba_ap t ON t.id_tope = a.id_tope;

--    Las 5 denuncias del final son las de las excepciones nuevas (SW498032,
--    SW475289, SW479979, SW496878, SW510548): sus avisos pueden no tener id_tope
--    si el semáforo los emitió cuando todavía topeaban por el tope GENERAL.
DELETE FROM cs.ap_avisos_nivel_siniestro
WHERE id_tope IS NULL
  AND id_denuncia IN (498001, 498024, 498034, 498249, 498407, 502068, 504078,
                      498032, 475289, 479979, 496878, 510548);

-- 4) Historial de los topes de prueba -----------------------------------------
DELETE h FROM cs.polizas_ap_topes_historial h
JOIN tmp_topes_prueba_ap t ON t.id_tope = h.id_tope;

-- 5) Los topes -----------------------------------------------------------------
DELETE p FROM cs.polizas_ap_topes p
JOIN tmp_topes_prueba_ap t ON t.id_tope = p.id_tope;

-- 7) TOPE GENERAL de las pólizas (cs.polizas_ap.suma_asegurada) ----------------
--    Va al final a propósito: mientras existan los topes de prueba, el motor
--    resuelve por EXCEPCION y el general no se mira. Anularlo antes no rompe
--    nada, pero deja una ventana donde el semáforo miente en las dos puntas.
--
--    Vuelve a NULL, que es el estado exacto anterior a la prueba: las 7 pólizas
--    estaban en NULL (la columna la creó V35 sin default, y el alta obligatoria
--    del tope en la pantalla de la póliza todavía no está implementada, así que
--    nada más pudo haberlas escrito).
--
--    ⚠ El filtro por MONTO EXACTO es la única protección que hay: si alguien
--    cargó un tope general de verdad desde la pantalla, no matchea y sobrevive.
--    Si el bloque afecta menos de 7 filas, es justamente eso — revisar el output
--    del bloque 0 antes de dar el cleanup por completo.
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 46 AND suma_asegurada = 5000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 28 AND suma_asegurada = 6000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 45 AND suma_asegurada = 6000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 51 AND suma_asegurada = 8000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 52 AND suma_asegurada = 8000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 29 AND suma_asegurada = 5000000.00;
UPDATE cs.polizas_ap SET suma_asegurada = NULL WHERE id_poliza = 43 AND suma_asegurada = 5000000.00;

--    `iva_incluido`, `moneda` y `ventana` de `polizas_ap` NO se tocan: son NOT NULL
--    con default (1 / 'ARS' / 'ANUAL'), los creó V35 con ese valor para las 30
--    pólizas y la prueba nunca los escribió. No son dato de prueba.

-- 8) Verificación posterior: los 5 contadores tienen que dar 0 -----------------
SELECT 'DESPUES' AS momento,
       (SELECT COUNT(*) FROM cs.polizas_ap_topes)                                   AS topes,
       (SELECT COUNT(*) FROM cs.polizas_ap_topes_historial)                         AS historial,
       (SELECT COUNT(*) FROM cs.ap_valores_manuales)                                AS valores_manuales,
       (SELECT COUNT(*) FROM cs.denuncia_poliza WHERE activo = 1 AND id_tope IS NOT NULL) AS dp_con_tope,
       (SELECT COUNT(*) FROM cs.polizas_ap WHERE suma_asegurada IS NOT NULL)         AS polizas_con_tope_general;

DROP TEMPORARY TABLE IF EXISTS tmp_topes_prueba_ap;

-- Revisar el output de (6) y recién entonces:
-- COMMIT;
-- ROLLBACK;
COMMIT;

-- -----------------------------------------------------------------------------
-- NOTA: `polizas_ap_topes.id_tope` y `ap_valores_manuales.id_valor_manual` son
-- AUTO_INCREMENT y NO se resetean. Después de correr esto la próxima carga
-- arranca en 13 y en 4 respectivamente. Es lo correcto: no reusar ids.
-- -----------------------------------------------------------------------------

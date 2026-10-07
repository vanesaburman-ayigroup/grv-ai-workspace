-- GLPI 2892 - Rollback del alta en cs.tipo_facturacion de 'Nota de Débito A/B/C/M', 'Factura MiPyME A/B/C'
-- y 'Nota de Débito MiPyME A/B/C'. Borra SOLO esas 10 filas (ids > 9) por descripcion. Si alguna ya fue usada por una factura, NO se puede borrar
-- (FK desde auditoria_facturacion_log, erogaciones_masivas_job_log, materiales_quirurgicos_erogacion_log;
-- erogaciones y pedidos_materiales_quirurgicos_detalles guardan el id sin FK). La tabla no tiene columna activo:
-- si estan en uso, dejarlas.

SELECT @@hostname AS host, DATABASE() AS bd;

-- Previa: si algun conteo es > 0 las filas estan en uso -> NO borrar.
SELECT 'auditoria_facturacion_log' AS tabla, COUNT(*) AS en_uso
FROM cs.auditoria_facturacion_log a JOIN cs.tipo_facturacion t ON t.id_tipo_facturacion = a.id_tipo_facturacion
WHERE t.id_tipo_facturacion > 9 AND (t.descripcion LIKE 'Nota de D%bito _' OR t.descripcion LIKE 'Nota de D%bito MiPyME _' OR t.descripcion LIKE 'Factura MiPyME _')
UNION ALL SELECT 'erogaciones_masivas_job_log', COUNT(*)
FROM cs.erogaciones_masivas_job_log a JOIN cs.tipo_facturacion t ON t.id_tipo_facturacion = a.id_tipo_factura
WHERE t.id_tipo_facturacion > 9 AND (t.descripcion LIKE 'Nota de D%bito _' OR t.descripcion LIKE 'Nota de D%bito MiPyME _' OR t.descripcion LIKE 'Factura MiPyME _')
UNION ALL SELECT 'materiales_quirurgicos_erogacion_log', COUNT(*)
FROM cs.materiales_quirurgicos_erogacion_log a JOIN cs.tipo_facturacion t ON t.id_tipo_facturacion = a.id_tipo_facturacion
WHERE t.id_tipo_facturacion > 9 AND (t.descripcion LIKE 'Nota de D%bito _' OR t.descripcion LIKE 'Nota de D%bito MiPyME _' OR t.descripcion LIKE 'Factura MiPyME _')
UNION ALL SELECT 'erogaciones', COUNT(*)
FROM cs.erogaciones a JOIN cs.tipo_facturacion t ON t.id_tipo_facturacion = a.id_tipo_facturacion
WHERE t.id_tipo_facturacion > 9 AND (t.descripcion LIKE 'Nota de D%bito _' OR t.descripcion LIKE 'Nota de D%bito MiPyME _' OR t.descripcion LIKE 'Factura MiPyME _')
UNION ALL SELECT 'pedidos_materiales_quirurgicos_detalles', COUNT(*)
FROM cs.pedidos_materiales_quirurgicos_detalles a JOIN cs.tipo_facturacion t ON t.id_tipo_facturacion = a.id_tipo_facturacion
WHERE t.id_tipo_facturacion > 9 AND (t.descripcion LIKE 'Nota de D%bito _' OR t.descripcion LIKE 'Nota de D%bito MiPyME _' OR t.descripcion LIKE 'Factura MiPyME _');

START TRANSACTION;

DELETE FROM cs.tipo_facturacion
WHERE id_tipo_facturacion > 9
  AND (descripcion LIKE 'Nota de D%bito _' OR descripcion LIKE 'Nota de D%bito MiPyME _' OR descripcion LIKE 'Factura MiPyME _')
  AND RIGHT(descripcion, 1) IN ('A', 'B', 'C', 'M');

-- Verificacion: deben quedar las 9 filas originales (ids 1-9) y ninguna 'Nota de Débito' ni 'MiPyME'
SELECT id_tipo_facturacion, descripcion FROM cs.tipo_facturacion ORDER BY id_tipo_facturacion;

-- COMMIT;
-- ROLLBACK;
-- Nota: el AUTO_INCREMENT queda avanzado (no se reutilizan 10-19); es inocuo.

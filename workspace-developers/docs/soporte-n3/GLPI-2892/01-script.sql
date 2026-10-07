-- GLPI 2892 - Faltan 'Nota de debito' (A/B/C/M) y los comprobantes MiPyME (Factura y Nota de Debito, A/B/C) en el catalogo cs.tipo_facturacion (lo lee wslistados GET /tipos-facturacion
-- y alimenta los desplegables 'Tipo de factura' del MFE auditoriafacturacion).
-- Ejecutar primero en ambiente bajo y luego en PROD. Verificar @@hostname antes.
-- Idempotente: no inserta si ya existe la misma descripcion. id_tipo_facturacion lo asigna AUTO_INCREMENT
-- (hoy ids 1-9, proximo 10); no se fijan ids. El front deriva la letra del filtro con
-- descripcion.trim().slice(-1) y la vista con RIGHT(descripcion,1): la descripcion DEBE terminar en la letra.
-- Nombres alineados con cs.tipo_factura ('Nota de Débito A', 'Nota de Débito C', 'Nota de Débito MiPyme A').
-- MiPyME = Factura de Crédito Electrónica MiPyME (Ley 27.440): Factura y Nota de Débito, letras A/B/C.
-- Tabla latin1 y cliente utf8mb4: la comparacion del NOT EXISTS convierte el literal con CONVERT(... USING latin1)
-- (sin eso da error 1267 'Illegal mix of collations'). Ejecutar con el cliente en un charset coherente (la 'é' entra en latin1); ver HEX en la verificacion.

SELECT @@hostname AS host, DATABASE() AS bd;

START TRANSACTION;

INSERT INTO cs.tipo_facturacion (descripcion)
SELECT v.descripcion
FROM (
  SELECT 'Nota de Débito A' AS descripcion
  UNION ALL SELECT 'Nota de Débito B'
  UNION ALL SELECT 'Nota de Débito C'
  UNION ALL SELECT 'Nota de Débito M'
  UNION ALL SELECT 'Factura MiPyME A'
  UNION ALL SELECT 'Factura MiPyME B'
  UNION ALL SELECT 'Factura MiPyME C'
  UNION ALL SELECT 'Nota de Débito MiPyME A'
  UNION ALL SELECT 'Nota de Débito MiPyME B'
  UNION ALL SELECT 'Nota de Débito MiPyME C'
) v
WHERE NOT EXISTS (
  SELECT 1 FROM cs.tipo_facturacion t WHERE t.descripcion = CONVERT(v.descripcion USING latin1)
);

-- Verificacion: 10 filas nuevas (Nota de Débito A/B/C/M, Factura MiPyME A/B/C, Nota de Débito MiPyME A/B/C;
-- ids 10-19 si nadie inserto antes) y las 9 previas intactas.
-- Si 'Débito' se ve roto (mojibake) -> ROLLBACK y reejecutar con el charset correcto del cliente.
SELECT id_tipo_facturacion, descripcion, HEX(descripcion) AS hex_descripcion
FROM cs.tipo_facturacion
ORDER BY id_tipo_facturacion;

SELECT COUNT(*) AS total_esperado_19 FROM cs.tipo_facturacion;

-- Si la verificacion es correcta:
-- COMMIT;
-- Si algo no coincide:
-- ROLLBACK;

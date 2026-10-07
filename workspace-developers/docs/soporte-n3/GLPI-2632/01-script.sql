-- GLPI 2632 - Solicitud de CD (GCBA AUTOSEGURO, tipo 158): faltan 2 cartas en cs.cd_cartas
-- Ejecutar primero en ambiente bajo y luego en PROD. Verificar @@hostname antes.
-- Idempotente: no inserta si ya existe el par (id_modulo, numero_carta) (UK uq_cd_cartas_modulo_numero)
-- ni la misma descripcion en el modulo. id_carta lo asigna AUTO_INCREMENT (no se hardcodea).
-- No reutiliza la carta 17 inactiva del modulo 8 (PENDIENTE DEFINICION POR CLIENTE).

SELECT @@hostname AS host, DATABASE() AS bd;

START TRANSACTION;

-- Modulo 7 (OTRAS CITACIONES), carta 7
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT 7, 7, 'Respuesta a Telegrama', 1
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM cs.cd_cartas
  WHERE id_modulo = 7 AND (numero_carta = 7 OR descripcion = 'Respuesta a Telegrama')
);

-- Modulo 8 (RECHAZOS), carta 18
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT 8, 18, 'EP FECHA PMI ANTERIOR VIGENCIA', 1
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1 FROM cs.cd_cartas
  WHERE id_modulo = 8 AND (numero_carta = 18 OR descripcion = 'EP FECHA PMI ANTERIOR VIGENCIA')
);

-- Verificacion: deben verse las 2 filas nuevas (activo = 1) y la 17 del modulo 8 intacta (activo = 0)
SELECT id_carta, id_modulo, numero_carta, descripcion, activo
FROM cs.cd_cartas
WHERE (id_modulo = 7 AND numero_carta >= 6) OR (id_modulo = 8 AND numero_carta >= 16)
ORDER BY id_modulo, numero_carta;

-- Si la verificacion es correcta:
-- COMMIT;
-- Si algo no coincide:
-- ROLLBACK;

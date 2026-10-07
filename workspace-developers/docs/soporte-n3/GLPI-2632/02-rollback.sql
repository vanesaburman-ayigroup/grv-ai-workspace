-- GLPI 2632 - Rollback del alta de cartas. Borra SOLO las 2 filas de 01-script.sql,
-- identificadas por clave natural y descripcion exacta. Si alguna solicitud ya las usa, NO borrar: baja logica.

SELECT @@hostname AS host, DATABASE() AS bd;

-- Previa: si devuelve filas, hay solicitudes usando la carta -> usar la baja logica del final.
SELECT sg.id_cd_modulo, sg.id_cd_carta, COUNT(*) AS solicitudes
FROM cs.solicitudes_genericas sg
JOIN cs.cd_cartas c ON c.id_carta = sg.id_cd_carta
WHERE (c.id_modulo = 7 AND c.numero_carta = 7 AND c.descripcion = 'Respuesta a Telegrama')
   OR (c.id_modulo = 8 AND c.numero_carta = 18 AND c.descripcion = 'EP FECHA PMI ANTERIOR VIGENCIA')
GROUP BY sg.id_cd_modulo, sg.id_cd_carta;

START TRANSACTION;

DELETE FROM cs.cd_cartas
WHERE (id_modulo = 7 AND numero_carta = 7 AND descripcion = 'Respuesta a Telegrama')
   OR (id_modulo = 8 AND numero_carta = 18 AND descripcion = 'EP FECHA PMI ANTERIOR VIGENCIA');

-- Verificacion: debe devolver 0 filas
SELECT id_carta, id_modulo, numero_carta, descripcion
FROM cs.cd_cartas
WHERE (id_modulo = 7 AND numero_carta = 7) OR (id_modulo = 8 AND numero_carta = 18);

-- COMMIT;
-- ROLLBACK;

-- Alternativa sin borrado fisico (si ya hay solicitudes):
-- UPDATE cs.cd_cartas SET activo = 0
--  WHERE (id_modulo = 7 AND numero_carta = 7) OR (id_modulo = 8 AND numero_carta = 18);

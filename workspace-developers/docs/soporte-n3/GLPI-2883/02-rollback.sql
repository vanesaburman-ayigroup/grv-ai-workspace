-- GLPI 2883 - Rollback del lote de cartas. Borra SOLO las cartas insertadas por 01-script.sql (clave natural + descripcion exacta),
-- revierte las 2 bajas logicas y elimina el modulo MORTALES si quedo vacio. Si alguna solicitud ya usa una carta, NO borrar: baja logica.

SELECT @@hostname AS host, DATABASE() AS bd;

-- Previa: si devuelve filas, hay solicitudes usando cartas del lote -> usar la baja logica del final en vez del DELETE.
SELECT sg.id_cd_modulo, sg.id_cd_carta, COUNT(*) AS solicitudes
FROM cs.solicitudes_genericas sg
JOIN cs.cd_cartas c ON c.id_carta = sg.id_cd_carta
JOIN cs.cd_modulos m ON m.id_modulo = c.id_modulo
WHERE (m.nombre = 'MODULO ABANDONO' AND c.numero_carta = 10 AND c.descripcion = 'Citación a Turno Médico con prórroga')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 5 AND c.descripcion = 'Alta por telemedicina. Adecuada a Res. 20-2026.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 6 AND c.descripcion = 'Se revoca alta por dictamen.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 7 AND c.descripcion = 'Comunicación resultado de Hipoacusia detectada en exámenes periódicos.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 8 AND c.descripcion = 'Suspensión de Tratamiento por afección inculpable.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 9 AND c.descripcion = 'Rectificación Alta con incapacidad a sin incapacidad.')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 1 AND c.descripcion = 'Suspensión plazos 298 Derechohabientes. Pedido de documentación')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 2 AND c.descripcion = 'Aceptación 298 Derechohabientes: Solicitud de documentación no recibida')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 3 AND c.descripcion = 'Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 4 AND c.descripcion = 'Rechazo por prescripción (fecha del hecho)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 5 AND c.descripcion = 'Rechazo por prescripción (fecha de la denuncia)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 6 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de autopsia')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 7 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 8 AND c.descripcion = 'Rechazo mortal-trabajador fuera de nómina')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 19 AND c.descripcion = 'Rechazo Accidente dentro de su domicilio - No configura in itinere')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 20 AND c.descripcion = 'Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 21 AND c.descripcion = 'Reversión de rechazo. Caso sin alta. Citación')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 22 AND c.descripcion = 'Reversión de rechazo. Caso con alta.')
GROUP BY sg.id_cd_modulo, sg.id_cd_carta;

START TRANSACTION;

DELETE c FROM cs.cd_cartas c
JOIN cs.cd_modulos m ON m.id_modulo = c.id_modulo
WHERE (m.nombre = 'MODULO ABANDONO' AND c.numero_carta = 10 AND c.descripcion = 'Citación a Turno Médico con prórroga')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 5 AND c.descripcion = 'Alta por telemedicina. Adecuada a Res. 20-2026.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 6 AND c.descripcion = 'Se revoca alta por dictamen.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 7 AND c.descripcion = 'Comunicación resultado de Hipoacusia detectada en exámenes periódicos.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 8 AND c.descripcion = 'Suspensión de Tratamiento por afección inculpable.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 9 AND c.descripcion = 'Rectificación Alta con incapacidad a sin incapacidad.')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 1 AND c.descripcion = 'Suspensión plazos 298 Derechohabientes. Pedido de documentación')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 2 AND c.descripcion = 'Aceptación 298 Derechohabientes: Solicitud de documentación no recibida')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 3 AND c.descripcion = 'Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 4 AND c.descripcion = 'Rechazo por prescripción (fecha del hecho)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 5 AND c.descripcion = 'Rechazo por prescripción (fecha de la denuncia)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 6 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de autopsia')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 7 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 8 AND c.descripcion = 'Rechazo mortal-trabajador fuera de nómina')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 19 AND c.descripcion = 'Rechazo Accidente dentro de su domicilio - No configura in itinere')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 20 AND c.descripcion = 'Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 21 AND c.descripcion = 'Reversión de rechazo. Caso sin alta. Citación')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 22 AND c.descripcion = 'Reversión de rechazo. Caso con alta.');

-- Reactiva las 2 cartas dadas de baja por el lote
UPDATE cs.cd_cartas SET activo = 1
WHERE id_carta IN (34, 48) AND activo = 0
  AND ((id_modulo = 7 AND numero_carta = 6) OR (id_modulo = 8 AND numero_carta = 14));

-- Borra el modulo MORTALES solo si no tiene cartas
DELETE FROM cs.cd_modulos
WHERE nombre = 'MODULO MORTALES'
  AND id_modulo NOT IN (SELECT id_modulo FROM (SELECT DISTINCT id_modulo FROM cs.cd_cartas) x);

-- Verificacion: 0 cartas del lote, MORTALES ausente, 34 y 48 activas
SELECT id_modulo, nombre FROM cs.cd_modulos WHERE nombre = 'MODULO MORTALES';
SELECT id_carta, id_modulo, numero_carta, activo FROM cs.cd_cartas WHERE id_carta IN (34, 48);
SELECT COUNT(*) AS cartas_lote_restantes FROM cs.cd_cartas c JOIN cs.cd_modulos m ON m.id_modulo = c.id_modulo
WHERE (m.nombre = 'MODULO ABANDONO' AND c.numero_carta = 10 AND c.descripcion = 'Citación a Turno Médico con prórroga')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 5 AND c.descripcion = 'Alta por telemedicina. Adecuada a Res. 20-2026.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 6 AND c.descripcion = 'Se revoca alta por dictamen.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 7 AND c.descripcion = 'Comunicación resultado de Hipoacusia detectada en exámenes periódicos.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 8 AND c.descripcion = 'Suspensión de Tratamiento por afección inculpable.')
   OR (m.nombre = 'MODULO ALTAS' AND c.numero_carta = 9 AND c.descripcion = 'Rectificación Alta con incapacidad a sin incapacidad.')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 1 AND c.descripcion = 'Suspensión plazos 298 Derechohabientes. Pedido de documentación')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 2 AND c.descripcion = 'Aceptación 298 Derechohabientes: Solicitud de documentación no recibida')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 3 AND c.descripcion = 'Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 4 AND c.descripcion = 'Rechazo por prescripción (fecha del hecho)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 5 AND c.descripcion = 'Rechazo por prescripción (fecha de la denuncia)')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 6 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de autopsia')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 7 AND c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro')
   OR (m.nombre = 'MODULO MORTALES' AND c.numero_carta = 8 AND c.descripcion = 'Rechazo mortal-trabajador fuera de nómina')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 19 AND c.descripcion = 'Rechazo Accidente dentro de su domicilio - No configura in itinere')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 20 AND c.descripcion = 'Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 21 AND c.descripcion = 'Reversión de rechazo. Caso sin alta. Citación')
   OR (m.nombre = 'MODULO RECHAZOS' AND c.numero_carta = 22 AND c.descripcion = 'Reversión de rechazo. Caso con alta.');

-- COMMIT;
-- ROLLBACK;

-- Alternativa sin borrado fisico (si ya hay solicitudes): baja logica del lote
-- UPDATE cs.cd_cartas c JOIN cs.cd_modulos m ON m.id_modulo = c.id_modulo SET c.activo = 0
--  WHERE (ver las condiciones del DELETE de arriba);

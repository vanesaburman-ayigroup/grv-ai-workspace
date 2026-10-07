-- GLPI 2883 - Solicitud de CD (GCBA AUTOSEGURO, tipo 158): lote de cartas nuevas + modulo MORTALES + 2 bajas logicas.
-- Ejecutar primero en ambiente bajo y luego en PROD. Verificar @@hostname antes.
-- Idempotente: no inserta si ya existe el par (id_modulo, numero_carta) (UK uq_cd_cartas_modulo_numero)
-- ni la misma descripcion en el modulo. id_carta lo asigna AUTO_INCREMENT. El id_modulo se resuelve por nombre.
-- DEPENDENCIA: GLPI 2632 (01-script.sql) reserva OTRAS CITACIONES 7 ('Respuesta a Telegrama', ya acordada) y
--   RECHAZOS 18 ('EP FECHA PMI ANTERIOR VIGENCIA'); este lote numera RECHAZOS desde 19. Aplicar 2632 antes.
-- Charset: cs.cd_cartas es latin1 (la tilde se guarda en 1 byte, p.ej. o con tilde = F3). Conectar con un
--   cliente utf8/utf8mb4 (conversion automatica); la verificacion final muestra HEX y detecta '?' (perdida de caracteres).
-- Las cartas ambiguas (ver 03-lote.md) estan COMENTADAS despues de los inserts.

SELECT @@hostname AS host, DATABASE() AS bd;

START TRANSACTION;

-- 1) Modulo nuevo MORTALES (cd_modulos tiene UK por nombre)
INSERT INTO cs.cd_modulos (nombre, activo)
SELECT 'MODULO MORTALES', 1 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM cs.cd_modulos WHERE nombre = 'MODULO MORTALES');

-- MODULO ABANDONO
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 10, 'Citación a Turno Médico con prórroga', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ABANDONO'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 10 OR c.descripcion = 'Citación a Turno Médico con prórroga'));

-- MODULO ALTAS
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 5, 'Alta por telemedicina. Adecuada a Res. 20-2026.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ALTAS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 5 OR c.descripcion = 'Alta por telemedicina. Adecuada a Res. 20-2026.'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 6, 'Se revoca alta por dictamen.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ALTAS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 6 OR c.descripcion = 'Se revoca alta por dictamen.'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 7, 'Comunicación resultado de Hipoacusia detectada en exámenes periódicos.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ALTAS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 7 OR c.descripcion = 'Comunicación resultado de Hipoacusia detectada en exámenes periódicos.'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 8, 'Suspensión de Tratamiento por afección inculpable.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ALTAS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 8 OR c.descripcion = 'Suspensión de Tratamiento por afección inculpable.'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 9, 'Rectificación Alta con incapacidad a sin incapacidad.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO ALTAS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 9 OR c.descripcion = 'Rectificación Alta con incapacidad a sin incapacidad.'));

-- MODULO MORTALES
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 1, 'Suspensión plazos 298 Derechohabientes. Pedido de documentación', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 1 OR c.descripcion = 'Suspensión plazos 298 Derechohabientes. Pedido de documentación'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 2, 'Aceptación 298 Derechohabientes: Solicitud de documentación no recibida', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 2 OR c.descripcion = 'Aceptación 298 Derechohabientes: Solicitud de documentación no recibida'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 3, 'Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 3 OR c.descripcion = 'Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 4, 'Rechazo por prescripción (fecha del hecho)', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 4 OR c.descripcion = 'Rechazo por prescripción (fecha del hecho)'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 5, 'Rechazo por prescripción (fecha de la denuncia)', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 5 OR c.descripcion = 'Rechazo por prescripción (fecha de la denuncia)'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 6, 'Rechazo por falta de datos objetivos: Solicitud de autopsia', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 6 OR c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de autopsia'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 7, 'Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 7 OR c.descripcion = 'Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 8, 'Rechazo mortal-trabajador fuera de nómina', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO MORTALES'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 8 OR c.descripcion = 'Rechazo mortal-trabajador fuera de nómina'));

-- MODULO RECHAZOS
INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 19, 'Rechazo Accidente dentro de su domicilio - No configura in itinere', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO RECHAZOS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 19 OR c.descripcion = 'Rechazo Accidente dentro de su domicilio - No configura in itinere'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 20, 'Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO RECHAZOS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 20 OR c.descripcion = 'Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T.'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 21, 'Reversión de rechazo. Caso sin alta. Citación', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO RECHAZOS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 21 OR c.descripcion = 'Reversión de rechazo. Caso sin alta. Citación'));

INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
SELECT m.id_modulo, 22, 'Reversión de rechazo. Caso con alta.', 1
FROM cs.cd_modulos m
WHERE m.nombre = 'MODULO RECHAZOS'
  AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 22 OR c.descripcion = 'Reversión de rechazo. Caso con alta.'));

-- AMBIGUAS: NO se ejecutan hasta confirmar (descomentar solo las confirmadas)
-- MODULO OTRAS CITACIONES 8: Deslinde de responsabilidad por abandono en caso de serológico
--   Motivo: ya existe en ABANDONO: id 64 numero 9 'Se notifica deslinde de Responsabilidad por inasistencia. Casos Serológicos...' (18 solicitudes). El pedido lo ubica en OTRAS CITACIONES con otro nombre.
-- INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
-- SELECT m.id_modulo, 8, 'Deslinde de responsabilidad por abandono en caso de serológico', 1
-- FROM cs.cd_modulos m
-- WHERE m.nombre = 'MODULO OTRAS CITACIONES'
--   AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 8 OR c.descripcion = 'Deslinde de responsabilidad por abandono en caso de serológico'));

-- MODULO RECHAZOS 23: Rechazo PMI anterior a vigencia de Autoseguro
--   Motivo: GLPI 2632 ya propone 'EP FECHA PMI ANTERIOR VIGENCIA' (RECHAZOS 18, sin ejecutar). Confirmar si es la misma carta; si lo es, renombrar en 2632 y no insertar esta.
-- INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
-- SELECT m.id_modulo, 23, 'Rechazo PMI anterior a vigencia de Autoseguro', 1
-- FROM cs.cd_modulos m
-- WHERE m.nombre = 'MODULO RECHAZOS'
--   AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 23 OR c.descripcion = 'Rechazo PMI anterior a vigencia de Autoseguro'));

-- MODULO RECHAZOS 24: Rechazo pluriempleo. Lugar de destino de otra A.R.T.
--   Motivo: existe id 50 numero 16 'RECHAZO PLURIEMPLEO' (3 solicitudes). Confirmar si es carta nueva o renombre.
-- INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
-- SELECT m.id_modulo, 24, 'Rechazo pluriempleo. Lugar de destino de otra A.R.T.', 1
-- FROM cs.cd_modulos m
-- WHERE m.nombre = 'MODULO RECHAZOS'
--   AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 24 OR c.descripcion = 'Rechazo pluriempleo. Lugar de destino de otra A.R.T.'));

-- MODULO RECHAZOS 25: Rechazo por no concurrir a citación
--   Motivo: parecida a id 39 numero 5 'Rechazo Inasistencia Citación médica con conocimiento de fecha de notif. Fehaciente'. Confirmar si es nueva.
-- INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
-- SELECT m.id_modulo, 25, 'Rechazo por no concurrir a citación', 1
-- FROM cs.cd_modulos m
-- WHERE m.nombre = 'MODULO RECHAZOS'
--   AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 25 OR c.descripcion = 'Rechazo por no concurrir a citación'));

-- MODULO RECHAZOS 26: Rechazo por alteración del trayecto IN ITINERE
--   Motivo: parecida a id 38 numero 4 'Rechazo evaluación médica + altera In itinere' (1 solicitud). Confirmar si es nueva.
-- INSERT INTO cs.cd_cartas (id_modulo, numero_carta, descripcion, activo)
-- SELECT m.id_modulo, 26, 'Rechazo por alteración del trayecto IN ITINERE', 1
-- FROM cs.cd_modulos m
-- WHERE m.nombre = 'MODULO RECHAZOS'
--   AND NOT EXISTS (SELECT 1 FROM cs.cd_cartas c WHERE c.id_modulo = m.id_modulo AND (c.numero_carta = 26 OR c.descripcion = 'Rechazo por alteración del trayecto IN ITINERE'));

-- 2) Bajas logicas pedidas ('se debe borrar'). NO se borra fisico: hay solicitudes que las referencian
--    (id 34 con 9 solicitudes, id 48 con 73). Con activo = 0 dejan de ofrecerse y el historico sigue mostrando la carta.
UPDATE cs.cd_cartas SET activo = 0
WHERE id_carta IN (34, 48) AND activo = 1
  AND ((id_modulo = 7 AND numero_carta = 6 AND descripcion LIKE 'Suspensi%plazos 298%Derechohabientes%')
    OR (id_modulo = 8 AND numero_carta = 14 AND descripcion LIKE 'Rechazo por accidente no laboral (ej. En su domicilio)'));

-- Verificacion: modulos, cartas del lote (con HEX) y las 2 bajas
SELECT id_modulo, nombre, activo FROM cs.cd_modulos ORDER BY id_modulo;
SELECT c.id_carta, c.id_modulo, c.numero_carta, c.activo, c.descripcion, HEX(c.descripcion) AS hex_desc
FROM cs.cd_cartas c
WHERE c.id_modulo IN (SELECT id_modulo FROM cs.cd_modulos WHERE nombre = 'MODULO MORTALES')
   OR (c.id_modulo = 1 AND c.numero_carta >= 9)
   OR (c.id_modulo = 3 AND c.numero_carta >= 4)
   OR (c.id_modulo = 7 AND c.numero_carta >= 6)
   OR (c.id_modulo = 8 AND c.numero_carta >= 14)
ORDER BY c.id_modulo, c.numero_carta;
-- Debe dar 0 (si da > 0 se perdieron caracteres al convertir a latin1: ROLLBACK y cambiar el charset del cliente)
SELECT COUNT(*) AS filas_con_signo_pregunta FROM cs.cd_cartas WHERE descripcion LIKE '%?%' AND id_carta > 64;
-- Esperado: 18 cartas nuevas (1 ABANDONO + 5 ALTAS + 8 MORTALES + 4 RECHAZOS) y id 34 y 48 con activo = 0

-- Si la verificacion es correcta:
-- COMMIT;
-- Si algo no coincide:
-- ROLLBACK;

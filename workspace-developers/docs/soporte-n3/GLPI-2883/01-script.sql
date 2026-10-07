-- GLPI 2883 - Solicitud de CD (GCBA AUTOSEGURO, tipo 158): lote de cartas nuevas + modulo MORTALES + 2 bajas logicas.
-- Ejecutar primero en ambiente bajo y luego en PROD. Verificar @@hostname antes.
-- Idempotente: no inserta si ya existe el par (id_modulo, numero_carta) (UK uq_cd_cartas_modulo_numero)
-- ni la misma descripcion en el modulo. id_carta lo asigna AUTO_INCREMENT. El id_modulo se resuelve por nombre.
-- DEPENDENCIA: GLPI 2632 (01-script.sql) reserva OTRAS CITACIONES 7 ('Respuesta a Telegrama', ya acordada) y
--   RECHAZOS 18 ('EP FECHA PMI ANTERIOR VIGENCIA'); este lote numera RECHAZOS desde 19. Aplicar 2632 antes.
-- Charset: cs.cd_cartas es latin1 (la tilde se guarda en 1 byte, p.ej. o con tilde = F3). Conectar con un
--   cliente utf8/utf8mb4 (conversion automatica); la verificacion final muestra HEX y detecta '?' (perdida de caracteres).
-- Las cartas ambiguas (ver 03-lote.md) estan COMENTADAS despues de los inserts.
--
-- MARCAS PARA REVISAR ANTES DE EJECUTAR (buscar '>>>'):
--   >>> MORTALES      : modulo NUEVO (no existe hoy) + 8 cartas. Confirmar con Agustin Mesplet que es un modulo y no una carta.
--   >>> CARTA NUEVA   : 'Alta por telemedicina. Adecuada a Res. 20-2026.' se inserta aunque ya existe 'Alta por telemedicina' (id 19).
--   >>> YA EXISTEN (x5) : PMI, Deslinde serologico, Pluriempleo, No concurrir a citacion, Trayecto IN ITINERE: no se insertan;
--                       la ubicacion de cada una esta en un comentario mas abajo (PMI = misma carta que GLPI 2632, RECHAZOS 18).

SELECT @@hostname AS host, DATABASE() AS bd;

START TRANSACTION;

-- 1) >>> MORTALES: MODULO NUEVO. Se crea aca (cd_modulos tiene UK por nombre). Confirmar que no es una carta de otro modulo.
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
-- >>> CARTA NUEVA: ya existe 'Alta por telemedicina' (id 19). Esta es la version adecuada a la Res. 20-2026; confirmar que va como carta nueva y no como renombre de la 19.
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

-- >>> MODULO MORTALES (NUEVO): 8 cartas, numeros 1 a 8. La 1 reemplaza a la id 34 de OTRAS CITACIONES (baja logica mas abajo).
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

-- >>> YA EXISTEN (no se insertan): cartas del pedido que se encuentran en el sistema con otro nombre.
--    El usuario las encuentra en estos modulos (se le informa en la respuesta del ticket):
--    - 'Deslinde de responsabilidad por abandono en caso de serologico'
--        -> MODULO ABANDONO, carta 9: 'Se notifica deslinde de Responsabilidad por inasistencia. Casos Serologicos...'
--    - 'Rechazo pluriempleo. Lugar de destino de otra A.R.T.'
--        -> MODULO RECHAZOS, carta 16: 'RECHAZO PLURIEMPLEO'
--    - 'Rechazo por no concurrir a citacion'
--        -> MODULO RECHAZOS, carta 5: 'Rechazo Inasistencia Citacion medica con conocimiento de fecha de notif. Fehaciente'
--    - 'Rechazo por alteracion del trayecto IN ITINERE'
--        -> MODULO RECHAZOS, carta 4: 'Rechazo evaluacion medica + altera In itinere'
--    - 'Rechazo PMI anterior a vigencia de Autoseguro'
--        -> MODULO RECHAZOS, carta 18: 'EP FECHA PMI ANTERIOR VIGENCIA' (misma carta, definido por Vane; cargada por GLPI 2632)

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

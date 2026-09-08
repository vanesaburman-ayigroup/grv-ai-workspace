-- =============================================================================================
--  ¿Cuántas entregas de ortopedia con traslado van a fallar con el gate de INI-2?
-- =============================================================================================
--
--  POR QUE ESTA MEDICION DECIDE ALGO
--
--  `wstramitador` crea el turno de la entrega de ortopedia llamando por HTTP a
--  `POST /turnos/crear` de `wsturnos` (OrtopediasServiceImpl:952 ->
--  generarTurnoTrasladoOrtopedia:1382 -> RestInvokeServiceImpl).
--
--  Con INI-2 ese endpoint devuelve 409 CONFLICT si el paciente ya tiene un traslado vigente
--  ese dia. Y `wstramitador` NO distingue el 409: lo convierte en un RuntimeException generico
--  (RestInvokeServiceImpl, catch de HttpClientErrorException). Peor: su DTO no tiene
--  `idMotivoTrasladoMismoDia` ni `justificacionTrasladoDuplicado` ni
--  `idSolicitanteTrasladoDuplicado` — cero ocurrencias en todo el repo — asi que los TRES
--  caminos que el gate acepta estan cerrados para ese flujo. No puede declarar el motivo ni
--  pedir la autorizacion.
--
--  Consecuencia: desde que INI-2 entre a produccion, entregar un pedido de ortopedia con
--  traslado FALLA cuando el paciente ya tiene un traslado ese dia. Esta medicion dice si eso
--  es un incidente o una rareza.
--
--  YA ESTA MEDIDO: es una rareza. UN caso en ocho meses, que no habria fallado. El resultado
--  completo esta al final del archivo. NO bloquea la promocion.
--
--  COMO IDENTIFICAMOS LOS TURNOS DE ORTOPEDIA
--  `generarTurnoTrasladoOrtopedia` los crea con `id_prestacion = 4453` (ID_PRESTACION_TRASLADO)
--  y `id_tipo_prestacion = 2` (TIPO_PRESTACION_NO_NOMENCLADAS), tipo de turno CONSULTA.
--
--  CUIDADO CON LA COLUMNA. Como el tipo de prestacion es 2 (NO NOMENCLADAS), el 4453 vive en
--  `autorizaciones.id_prestacion_no_nomenclada`, NO en `autorizaciones.id_prestacion`. En el
--  catalogo nomenclado el 4453 es "INMUNOELECTROFORESIS", asi que buscar por la columna
--  equivocada da CERO y parece que el flujo no existe. Esta medicion se corrio primero mal por
--  ese motivo.
--
--  Y LO QUE DE VERDAD SEPARA ORTOPEDIA DEL RESTO es la tabla `traslados_pedidos_ortopedia`
--  (id_pedido_ortopedia, id_traslado, id_turno): solo las entregas creadas por `wstramitador`
--  quedan vinculadas ahi. Sin ese cruce se mezclan con las cargas manuales de gestores, que
--  usan la misma prestacion no nomenclada 4453 desde el drawer de `tramitadores`. Ver la
--  query 5 al final: es la que decide.
--
--  REPLICA LA LOGICA DEL GATE
--  `TrasladoDuplicadoValidator` cuenta traslados de la MISMA denuncia, en la MISMA fecha,
--  con estado NOT IN (4 Cancelado, 5 Rechazado), excluyendo el turno que se esta cargando.
--  Estas queries usan ese mismo criterio.
--
--  SOLO LECTURA. Correr contra PRODUCCION.
-- =============================================================================================

USE cs;

-- ---------------------------------------------------------------------------------------------
-- 1. Universo: cuantas entregas de ortopedia con traslado hubo, y en que periodo
-- ---------------------------------------------------------------------------------------------
SELECT COUNT(*)            AS turnos_ortopedia_con_traslado,
       MIN(t.fecha_turno)  AS desde,
       MAX(t.fecha_turno)  AS hasta
  FROM turnos t
  JOIN traslados tr    ON tr.id_turno       = t.id_turno
  JOIN autorizaciones a ON a.id_autorizacion = t.id_autorizacion
 WHERE a.id_prestacion_no_nomenclada = 4453
   AND t.fecha_turno >= '2026-01-01';

-- ---------------------------------------------------------------------------------------------
-- 2. LA CIFRA QUE DECIDE: de esas, cuantas habrian recibido 409
--    (el paciente ya tenia otro traslado vigente ese mismo dia)
-- ---------------------------------------------------------------------------------------------
SELECT COUNT(*) AS habrian_fallado_con_409
  FROM turnos t
  JOIN traslados tr     ON tr.id_turno        = t.id_turno
  JOIN autorizaciones a ON a.id_autorizacion  = t.id_autorizacion
 WHERE a.id_prestacion_no_nomenclada = 4453
   AND t.fecha_turno >= '2026-01-01'
   AND EXISTS (
         SELECT 1
           FROM traslados tr2
           JOIN turnos t2 ON t2.id_turno = tr2.id_turno
          WHERE t2.id_denuncia = t.id_denuncia
            AND DATE(t2.fecha_turno) = DATE(t.fecha_turno)
            AND t2.id_turno <> t.id_turno
            AND tr2.id_estado_traslado NOT IN (4, 5)
       );

-- ---------------------------------------------------------------------------------------------
-- 3. Distribucion por mes — para ver si es estable, creciente o un pico aislado
-- ---------------------------------------------------------------------------------------------
SELECT DATE_FORMAT(t.fecha_turno, '%Y-%m') AS mes,
       COUNT(*)                            AS total_ortopedia_con_traslado,
       SUM(CASE WHEN EXISTS (
             SELECT 1 FROM traslados tr2
               JOIN turnos t2 ON t2.id_turno = tr2.id_turno
              WHERE t2.id_denuncia = t.id_denuncia
                AND DATE(t2.fecha_turno) = DATE(t.fecha_turno)
                AND t2.id_turno <> t.id_turno
                AND tr2.id_estado_traslado NOT IN (4, 5)
           ) THEN 1 ELSE 0 END)            AS habrian_fallado
  FROM turnos t
  JOIN traslados tr     ON tr.id_turno        = t.id_turno
  JOIN autorizaciones a ON a.id_autorizacion  = t.id_autorizacion
 WHERE a.id_prestacion_no_nomenclada = 4453
   AND t.fecha_turno >= '2026-01-01'
 GROUP BY mes
 ORDER BY mes;

-- ---------------------------------------------------------------------------------------------
-- 4. Casos concretos, los ultimos 20 — para entender el patron
--    (sin datos del paciente: sólo lo necesario para razonar el caso)
-- ---------------------------------------------------------------------------------------------
SELECT t.id_denuncia,
       DATE(t.fecha_turno) AS fecha,
       t.id_turno          AS turno_ortopedia,
       (SELECT COUNT(*)
          FROM traslados tr2
          JOIN turnos t2 ON t2.id_turno = tr2.id_turno
         WHERE t2.id_denuncia = t.id_denuncia
           AND DATE(t2.fecha_turno) = DATE(t.fecha_turno)
           AND t2.id_turno <> t.id_turno
           AND tr2.id_estado_traslado NOT IN (4, 5)) AS otros_traslados_vigentes
  FROM turnos t
  JOIN traslados tr     ON tr.id_turno        = t.id_turno
  JOIN autorizaciones a ON a.id_autorizacion  = t.id_autorizacion
 WHERE a.id_prestacion_no_nomenclada = 4453
   AND t.fecha_turno >= '2026-01-01'
   AND EXISTS (
         SELECT 1 FROM traslados tr2
           JOIN turnos t2 ON t2.id_turno = tr2.id_turno
          WHERE t2.id_denuncia = t.id_denuncia
            AND DATE(t2.fecha_turno) = DATE(t.fecha_turno)
            AND t2.id_turno <> t.id_turno
            AND tr2.id_estado_traslado NOT IN (4, 5)
       )
 ORDER BY t.fecha_turno DESC
 LIMIT 20;

-- ---------------------------------------------------------------------------------------------
-- 5. LA QUERY QUE DECIDE: separar ortopedia real (vinculada por wstramitador) del resto
--    Sin este cruce, las cargas manuales de gestores se cuentan como si fueran de ortopedia.
-- ---------------------------------------------------------------------------------------------
SELECT CASE WHEN tpo.id_traslado IS NOT NULL
            THEN 'ORTOPEDIA (via wstramitador)'
            ELSE 'otro origen (carga manual)'
       END                                        AS origen,
       COUNT(*)                                   AS total,
       SUM(CASE WHEN EXISTS (
             SELECT 1 FROM traslados tr2
               JOIN turnos t2 ON t2.id_turno = tr2.id_turno
              WHERE t2.id_denuncia = t.id_denuncia
                AND DATE(t2.fecha_turno) = DATE(t.fecha_turno)
                AND t2.id_turno <> t.id_turno
                AND tr2.id_estado_traslado NOT IN (4, 5)
           ) THEN 1 ELSE 0 END)                   AS habrian_fallado
  FROM turnos t
  JOIN traslados tr     ON tr.id_turno       = t.id_turno
  JOIN autorizaciones a ON a.id_autorizacion = t.id_autorizacion
  LEFT JOIN traslados_pedidos_ortopedia tpo ON tpo.id_traslado = tr.id_traslado
 WHERE a.id_prestacion_no_nomenclada = 4453
   AND t.fecha_turno >= '2026-01-01'
 GROUP BY origen;

-- Control de sanidad: confirmar que la tabla de vinculo no esta simplemente sin poblar
SELECT COUNT(*) AS filas_totales, MAX(id_traslado_pedido_ortopedia) AS max_id
  FROM traslados_pedidos_ortopedia;

SELECT table_name, create_time, table_rows
  FROM information_schema.tables
 WHERE table_schema = 'cs'
   AND table_name IN ('traslados_pedidos_ortopedia', 'pedidos_ortopedia');

-- =============================================================================================
--  RESULTADO — ejecutado sobre PRODUCCION el 21/08/2026
-- =============================================================================================
--
--  Query 1 (universo)   : 2.322 turnos con prestacion no nomenclada 4453 y traslado, en 2026
--  Query 2 (el 409)     : 562 habrian recibido 409  (24%)
--  Query 3 (por mes)    : estable entre 43 y 98 por mes; pico en julio con 98
--
--  Query 5 — LA QUE CAMBIA LA CONCLUSION:
--
--    origen                          total   habrian_fallado
--    ------------------------------  -----   ---------------
--    ORTOPEDIA (via wstramitador)        1                 0
--    otro origen (carga manual)      2.321               562
--
--  Control de sanidad: `traslados_pedidos_ortopedia` tiene UNA fila en toda la base
--  (max_id = 1), creada el 24/01/2026. No esta sin poblar: es que ese camino casi no se usa.
--  Para contraste, `pedidos_ortopedia` tiene 38.645 filas.
--
--  LECTURA
--
--  1. El flujo `generarTurnoTrasladoOrtopedia` esta practicamente en desuso: UN caso en ocho
--     meses, y ese unico caso NO habria fallado. El acoplamiento con `wstramitador` es real
--     como mecanismo, pero su volumen hoy es despreciable. NO bloquea la promocion.
--
--  2. Los 562 NO son de ortopedia. Son cargas manuales de gestores que usan la prestacion no
--     nomenclada 4453 desde el drawer de `tramitadores` — el drawer que SI muestra el bloque de
--     conflicto con sus tres salidas. Esos casos no fallan: son exactamente el fenomeno que el
--     circuito viene a detectar, con la interfaz para resolverlo. Contarlos como fallas fue
--     leer al reves el resultado esperado.
--
--  3. Queda como seguimiento, no como condicion: pedirle al equipo de ortopedia que sume los
--     tres campos al DTO y distinga el 409 del 500, ANTES de que empiecen a usar ese flujo en
--     volumen. `pedidos_ortopedia` se creo el 01/08/2026 y ya tiene 38.645 filas, asi que el
--     riesgo puede crecer aunque hoy sea uno.
-- =============================================================================================

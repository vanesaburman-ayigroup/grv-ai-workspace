-- ============================================
-- Script: 20261007_denuncias-incapacidad_02-backfill-definitiva.sql
-- Descripcion: carga en cs.denuncias_incapacidad la incapacidad DEFINITIVA historica
--              de las denuncias ya cerradas, tomandola del cierre vigente de cada
--              denuncia en cs.cierres_denuncias_log.
--
-- Lo ejecuta una persona a mano, bloque por bloque (ver "Como correrlo").
--
-- Verificar antes de aplicar (solo lectura):
--   SELECT VERSION();
--   SELECT @@sql_mode, @@binlog_format, @@transaction_isolation, @@lock_wait_timeout;
--   SELECT @@hostname;   -- el MCP del entorno lee PROD; el script se corre en el
--                        -- primario del ambiente correcto, confirmar donde estas conectada.
--   SHOW CREATE TABLE cs.denuncias;
--   SHOW CREATE TABLE cs.cierres_denuncias_log;
--   DESCRIBE cs.estados_medicos;   -- confirmar que existe es_cierre (lo usa A9)
--   SELECT COUNT(*) FROM cs.cierres_denuncias_log;   -- si es muy grande, partir el
--                        -- INSERT por rangos de id_denuncia (ver bloque B)
--   Recomendado: correr A1 a A9 (solo lectura) en prod antes de aplicar y revisar los numeros.
--
-- Orden de uso:
--   1. Crear la tabla con 20261007_denuncias-incapacidad_01-tabla.sql.
--   2. Correr el bloque A (verificacion previa, solo lectura) y revisar los numeros.
--   3. Correr el bloque B completo como UNA tanda, sin pausa (ver "Como correrlo").
--   4. Correr el bloque C (verificacion posterior, solo lectura).
--   Es indistinto correrlo antes o despues del deploy de los ws que escriben la tabla:
--   no pisa filas existentes (ver bloque B).
--
-- Como correrlo (DBeaver):
--   * NO ejecutar el archivo entero con Alt+X: la transaccion del bloque B quedaria
--     abierta (sin COMMIT ni ROLLBACK) hasta cerrar la sesion y mantendria locks.
--   * NO ejecutar el INSERT suelto: en auto-commit se confirma sin vuelta atras.
--   * Seleccionar el bloque B completo (desde SET SESSION hasta el ultimo SELECT de
--     control) y ejecutarlo como script (Alt+X sobre la seleccion). Revisar los
--     resultados; despues seleccionar y ejecutar SOLO la linea COMMIT o SOLO la
--     linea ROLLBACK (descomentandola).
--
-- Idempotente: se puede correr N veces. Solo inserta las denuncias que todavia no
-- tienen fila (id_denuncia, 'DEFINITIVA'); una segunda corrida inserta 0 filas.
--
-- Criterio de cierre vigente: el de mayor id_cierre_denuncia_log de la denuncia.
--   - Las ediciones de un cierre se hacen sobre la misma fila (UPDATE), no generan otra.
--   - Una fila nueva en el log solo aparece por un nuevo cierre (p. ej. tras una reapertura)
--     o por el mantenimiento que agrega denuncias cerradas sin log.
--   - fecha_carga_alta no sirve para ordenar: es editable y puede ser NULL.
--   - Es el mismo criterio que usan los scripts de saneo existentes sobre esta tabla.
--   Si el cierre vigente tiene id_incapacidad NULL (p. ej. cierre por muerte, donde el
--   cierre limpia el dato) no se inserta nada y no se cae a un cierre anterior.
--   Las filas del log con id_denuncia NULL se ignoran (ver A1b).
--
-- Mapeo:
--   id_denuncia     = cierres_denuncias_log.id_denuncia
--   tipo            = 'DEFINITIVA'
--   con_incapacidad = (id_incapacidad = 1)
--   porcentaje      = NULL siempre. Decision D3: la columna porcentaje_incapacidad (en
--                     denuncias y en el log) es compartida con la incapacidad presunta y
--                     no se puede separar con certeza cual de las dos representa, asi que
--                     no se migra. El porcentaje definitivo lo cargan los ws desde ahora.
--   origen          = 'MIGRACION'
--   id_persona      = cierres_denuncias_log.id_responsable
--   fecha_carga y fecha_modificacion = cierres_denuncias_log.fecha_carga_alta, que es la
--                     fecha de alta medica del cierre (aproximada, no la fecha real de la
--                     carga), o la hora actual (NOW()) si es NULL.
--
-- Compatible con MariaDB 10.x: sin funciones de ventana, subconsulta con MAX.
-- ============================================


-- ============================================
-- BLOQUE A - Verificacion previa (SOLO LECTURA)
-- ============================================

-- A1. Cierres con id_incapacidad no nulo (sobre todo el log).
SELECT COUNT(*) AS cierres_con_id_incapacidad
FROM cs.cierres_denuncias_log
WHERE id_incapacidad IS NOT NULL;

-- A1b. Filas del log con id_denuncia NULL (no se migran).
SELECT COUNT(*) AS filas_log_con_id_denuncia_null
FROM cs.cierres_denuncias_log
WHERE id_denuncia IS NULL;

-- A2. Denuncias con mas de un cierre (el criterio "ultimo" importa en estas).
SELECT COUNT(*) AS denuncias_con_mas_de_un_cierre
FROM (
    SELECT id_denuncia
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
    HAVING COUNT(*) > 1
) m;

-- A3. De esas, en cuantas el dato de incapacidad (id_incapacidad o texto del porcentaje)
--     cambia entre el cierre vigente y alguno anterior.
SELECT COUNT(DISTINCT v.id_denuncia) AS multiples_con_incapacidad_distinta
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
    HAVING COUNT(*) > 1
) u ON u.id_max = v.id_cierre_denuncia_log
JOIN cs.cierres_denuncias_log o
  ON o.id_denuncia = v.id_denuncia
 AND o.id_cierre_denuncia_log < v.id_cierre_denuncia_log
 AND NOT (o.id_incapacidad <=> v.id_incapacidad
          AND o.porcentaje_incapacidad <=> v.porcentaje_incapacidad);

-- A4. Cierres vigentes cuyo id_incapacidad no es 0 ni 1 (se tratan como sin incapacidad).
SELECT v.id_incapacidad, COUNT(*) AS cantidad
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad IS NOT NULL
GROUP BY v.id_incapacidad;

-- A5. Informativo: cierres vigentes con incapacidad = 1 que tienen porcentaje cargado.
--     El porcentaje NO se migra (decision D3): las filas MIGRACION quedan con porcentaje NULL.
SELECT COUNT(*) AS vigentes_con_incapacidad_y_porcentaje
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad = 1
  AND v.porcentaje_incapacidad IS NOT NULL
  AND TRIM(v.porcentaje_incapacidad) <> '';

-- A6. Informativo: cierres vigentes con incapacidad = 1 y sin porcentaje.
SELECT COUNT(*) AS vigentes_con_incapacidad_sin_porcentaje
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad = 1
  AND (v.porcentaje_incapacidad IS NULL OR TRIM(v.porcentaje_incapacidad) = '');

-- A7. Filas que insertaria el bloque B (cierre vigente con id_incapacidad no nulo y sin fila DEFINITIVA).
--     Anotar este numero: se compara con ROW_COUNT() del bloque B.
SELECT COUNT(*) AS filas_a_insertar
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_denuncia IS NOT NULL
  AND v.id_incapacidad IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM cs.denuncias_incapacidad di
        WHERE di.id_denuncia = v.id_denuncia
          AND di.tipo = 'DEFINITIVA'
  );

-- A8. Filas DEFINITIVA que ya existen (escritas por los ws); el bloque B no las toca.
SELECT origen, COUNT(*) AS cantidad
FROM cs.denuncias_incapacidad
WHERE tipo = 'DEFINITIVA'
GROUP BY origen;

-- A9. Denuncias reabiertas: cierre vigente con incapacidad pero estado medico actual que no es de cierre.
--     Hoy se insertan igual (es el ultimo dato definitivo conocido). VERIFICAR con DESCRIBE
--     cs.estados_medicos que existe la columna es_cierre antes de correr esta consulta.
SELECT COUNT(*) AS reabiertas_con_cierre_previo_con_incapacidad
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
JOIN cs.denuncias d ON d.id_denuncia = v.id_denuncia
LEFT JOIN cs.estados_medicos e ON e.id_estado_medico = d.id_estado_medico
WHERE v.id_incapacidad IS NOT NULL
  AND COALESCE(e.es_cierre, 0) <> 1;


-- ============================================
-- BLOQUE B - INSERT (escribe). UNA tanda, sin pausa humana.
-- Una fila DEFINITIVA por denuncia, desde su cierre vigente (mayor id_cierre_denuncia_log),
-- solo si id_denuncia e id_incapacidad no son NULL. No pisa filas existentes: el NOT EXISTS
-- evita tocar lo que ya escribieron los ws, y el UNIQUE (id_denuncia, tipo) lo respalda.
-- El porcentaje no se migra (decision D3): queda NULL.
-- Si el volumen es grande y hay riesgo de lock wait, correr por tramos agregando
-- "AND v.id_denuncia BETWEEN <desde> AND <hasta>" al WHERE del SELECT interno.
--
-- Seleccionar desde "SET SESSION" hasta el ultimo SELECT de control y ejecutar como
-- script. Despues decidir: seleccionar y ejecutar SOLO COMMIT o SOLO ROLLBACK.
-- ============================================

SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Control: @@autocommit puede ser 1 (START TRANSACTION lo suspende hasta COMMIT/ROLLBACK);
-- @@in_transaction debe ser 0 antes de empezar (si da 1 hay una transaccion abierta previa).
SELECT @@autocommit AS autocommit, @@in_transaction AS in_transaction_antes, @@transaction_isolation AS aislamiento;

START TRANSACTION;

INSERT INTO cs.denuncias_incapacidad
    (id_denuncia, tipo, con_incapacidad, porcentaje, origen, id_persona, fecha_carga, fecha_modificacion)
SELECT x.id_denuncia,
       'DEFINITIVA',
       x.con_incapacidad,
       NULL,
       'MIGRACION',
       x.id_responsable,
       COALESCE(x.fecha_carga_alta, NOW()),
       COALESCE(x.fecha_carga_alta, NOW())
FROM (
    SELECT v.id_denuncia,
           v.id_responsable,
           v.fecha_carga_alta,
           CASE WHEN v.id_incapacidad = 1 THEN 1 ELSE 0 END AS con_incapacidad
    FROM cs.cierres_denuncias_log v
    JOIN (
        SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
        FROM cs.cierres_denuncias_log
        WHERE id_denuncia IS NOT NULL
        GROUP BY id_denuncia
    ) u ON u.id_max = v.id_cierre_denuncia_log
    WHERE v.id_denuncia IS NOT NULL
      AND v.id_incapacidad IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM cs.denuncias_incapacidad di
            WHERE di.id_denuncia = v.id_denuncia
              AND di.tipo = 'DEFINITIVA'
      )
) x;

-- Filas insertadas: debe ser igual a A7. Tiene que ir inmediatamente despues del INSERT.
SELECT ROW_COUNT() AS filas_insertadas;

-- Control dentro de la transaccion: pendientes debe dar 0; migradas_total >= filas_insertadas
-- (suma las de corridas anteriores); con_porcentaje_debe_ser_0 debe dar 0 (decision D3).
SELECT
    (SELECT COUNT(*)
       FROM cs.cierres_denuncias_log v
       JOIN (SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
               FROM cs.cierres_denuncias_log
              WHERE id_denuncia IS NOT NULL
              GROUP BY id_denuncia) u ON u.id_max = v.id_cierre_denuncia_log
      WHERE v.id_denuncia IS NOT NULL
        AND v.id_incapacidad IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM cs.denuncias_incapacidad di
                         WHERE di.id_denuncia = v.id_denuncia AND di.tipo = 'DEFINITIVA')
    ) AS pendientes_debe_ser_0,
    (SELECT COUNT(*) FROM cs.denuncias_incapacidad
      WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION') AS migradas_total,
    (SELECT COUNT(*) FROM cs.denuncias_incapacidad
      WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION' AND porcentaje IS NOT NULL) AS con_porcentaje_debe_ser_0,
    @@in_transaction AS in_transaction_debe_ser_1;

-- Decision. Si filas_insertadas coincide con A7 y los controles dan lo esperado:
-- seleccionar y ejecutar SOLO la linea COMMIT (descomentarla). Si algo no cierra:
-- seleccionar y ejecutar SOLO la linea ROLLBACK. No dejar la transaccion abierta.
-- COMMIT;
-- ROLLBACK;


-- ============================================
-- BLOQUE C - Verificacion posterior (SOLO LECTURA)
-- ============================================

-- C1. Conteo por origen y por con_incapacidad.
SELECT origen, con_incapacidad, COUNT(*) AS cantidad
FROM cs.denuncias_incapacidad
WHERE tipo = 'DEFINITIVA'
GROUP BY origen, con_incapacidad
ORDER BY origen, con_incapacidad;

-- C2. Control de porcentaje: las filas MIGRACION no deben tener porcentaje (ambas columnas deben dar 0).
SELECT COALESCE(SUM(porcentaje IS NOT NULL), 0)                      AS migracion_con_porcentaje_debe_ser_0,
       COALESCE(SUM(con_incapacidad = 0 AND porcentaje IS NOT NULL), 0) AS sin_incapacidad_con_porcentaje_debe_ser_0
FROM cs.denuncias_incapacidad
WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION';

-- C3. Pendientes tras el INSERT: debe dar 0 (idempotencia).
SELECT COUNT(*) AS pendientes
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_denuncia IS NOT NULL
  AND v.id_incapacidad IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM cs.denuncias_incapacidad di
        WHERE di.id_denuncia = v.id_denuncia
          AND di.tipo = 'DEFINITIVA'
  );

-- C4. Muestra de 10 filas migradas contra el cierre original (sin orden aleatorio: toma las primeras por clave).
SELECT di.id_denuncia_incapacidad,
       di.id_denuncia,
       di.con_incapacidad,
       di.porcentaje,
       di.id_persona,
       di.fecha_carga,
       v.id_cierre_denuncia_log,
       v.id_incapacidad          AS cierre_id_incapacidad,
       v.porcentaje_incapacidad  AS cierre_porcentaje_texto,
       v.id_responsable          AS cierre_id_responsable,
       v.fecha_carga_alta        AS cierre_fecha_carga_alta
FROM cs.denuncias_incapacidad di
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    WHERE id_denuncia IS NOT NULL
    GROUP BY id_denuncia
) u ON u.id_denuncia = di.id_denuncia
JOIN cs.cierres_denuncias_log v ON v.id_cierre_denuncia_log = u.id_max
WHERE di.tipo = 'DEFINITIVA'
  AND di.origen = 'MIGRACION'
ORDER BY di.id_denuncia_incapacidad
LIMIT 10;


-- ============================================
-- NOTAS
-- ============================================
-- Que NO cubre:
--   * El porcentaje de las filas MIGRACION queda NULL (decision D3): la columna
--     porcentaje_incapacidad es compartida entre la presunta y la definitiva y no se puede
--     separar con certeza cual de las dos representa; ademas el cierre copia ese valor.
--     Solo se carga con_incapacidad (desde id_incapacidad).
--   * La incapacidad PRESUNTA no se backfillea. Las filas PRESUNTA las escriben los ws
--     desde ahora.
--   * Denuncias cuyo cierre vigente tiene id_incapacidad NULL (p. ej. cierres por muerte,
--     donde el cierre borra el dato): quedan sin fila, o sea "sin dato".
--   * Filas del log con id_denuncia NULL: se ignoran (A1b las cuenta).
--   * Denuncias cerradas que nunca pasaron por cierres_denuncias_log: no hay fuente.
--   * Una denuncia reabierta cuyo ultimo cierre tenia incapacidad se carga igual (A9 la cuenta).
--
-- Como revertir (solo lo que cargo este script):
--   Revisar primero la cantidad:
--     SELECT COUNT(*) FROM cs.denuncias_incapacidad WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION';
--   Borrar:
--     DELETE FROM cs.denuncias_incapacidad WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION';
--   NO borrar filas con otro origen ('MANUAL' o 'CIERRE'): son las que escriben los ws.
--   Si un ws edita una fila origen MIGRACION, puede quedar con otro origen o mantenerlo segun
--   su implementacion; confirmar con el SELECT de arriba antes de borrar.
-- ============================================

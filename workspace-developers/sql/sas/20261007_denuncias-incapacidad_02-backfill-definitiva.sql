-- ============================================
-- Script: 02-backfill-denuncias_incapacidad_definitiva.sql
-- Descripcion: carga en cs.denuncias_incapacidad la incapacidad DEFINITIVA historica
--              de las denuncias ya cerradas, tomandola del cierre vigente de cada
--              denuncia en cs.cierres_denuncias_log.
--
-- NO APLICADO. Lo ejecuta la usuaria a mano, bloque por bloque.
--
-- Orden de uso:
--   1. Crear la tabla con 01-denuncias_incapacidad.sql.
--   2. Correr el bloque A (verificacion previa, solo lectura) y revisar los numeros.
--   3. Correr el bloque B (INSERT).
--   4. Correr el bloque C (verificacion posterior, solo lectura).
--   Es indistinto correrlo antes o despues del deploy de los ws que escriben la tabla:
--   no pisa filas existentes (ver bloque B).
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
--
-- Mapeo:
--   id_denuncia     = cierres_denuncias_log.id_denuncia
--   tipo            = 'DEFINITIVA'
--   con_incapacidad = (id_incapacidad = 1)
--   porcentaje      = porcentaje_incapacidad convertido a numero (0 a 100); NULL si no es
--                     convertible o si con_incapacidad = 0
--   origen          = 'MIGRACION'
--   id_persona      = cierres_denuncias_log.id_responsable
--   fecha_carga     = cierres_denuncias_log.fecha_carga_alta (o la hora actual si es NULL)
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

-- A2. Denuncias con mas de un cierre (el criterio "ultimo" importa en estas).
SELECT COUNT(*) AS denuncias_con_mas_de_un_cierre
FROM (
    SELECT id_denuncia
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
    HAVING COUNT(*) > 1
) m;

-- A3. De esas, en cuantas el dato de incapacidad cambia entre el cierre vigente y alguno anterior.
SELECT COUNT(DISTINCT v.id_denuncia) AS multiples_con_incapacidad_distinta
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
    HAVING COUNT(*) > 1
) u ON u.id_max = v.id_cierre_denuncia_log
JOIN cs.cierres_denuncias_log o
  ON o.id_denuncia = v.id_denuncia
 AND o.id_cierre_denuncia_log < v.id_cierre_denuncia_log
 AND NOT (o.id_incapacidad <=> v.id_incapacidad);

-- A4. Cierres vigentes cuyo id_incapacidad no es 0 ni 1 (se tratan como sin incapacidad).
SELECT v.id_incapacidad, COUNT(*) AS cantidad
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad IS NOT NULL
GROUP BY v.id_incapacidad;

-- A5. Porcentajes no convertibles a numero entre 0 y 100, entre los cierres vigentes con incapacidad.
--     Se cuentan los que tienen texto (no NULL ni vacio) pero no pasan la conversion.
SELECT COUNT(*) AS porcentajes_no_convertibles
FROM (
    SELECT REPLACE(REPLACE(REPLACE(TRIM(v.porcentaje_incapacidad), '%', ''), ' ', ''), ',', '.') AS pct
    FROM cs.cierres_denuncias_log v
    JOIN (
        SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
        FROM cs.cierres_denuncias_log
        GROUP BY id_denuncia
    ) u ON u.id_max = v.id_cierre_denuncia_log
    WHERE v.id_incapacidad = 1
      AND v.porcentaje_incapacidad IS NOT NULL
      AND TRIM(v.porcentaje_incapacidad) <> ''
) t
WHERE NOT (t.pct REGEXP '^[0-9]{1,3}([.][0-9]{1,4})?$' AND CAST(t.pct AS DECIMAL(10,4)) <= 100);

-- A5b. Ejemplos de esos valores no convertibles (hasta 30 distintos).
SELECT t.porcentaje_incapacidad, COUNT(*) AS cantidad
FROM (
    SELECT v.porcentaje_incapacidad,
           REPLACE(REPLACE(REPLACE(TRIM(v.porcentaje_incapacidad), '%', ''), ' ', ''), ',', '.') AS pct
    FROM cs.cierres_denuncias_log v
    JOIN (
        SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
        FROM cs.cierres_denuncias_log
        GROUP BY id_denuncia
    ) u ON u.id_max = v.id_cierre_denuncia_log
    WHERE v.id_incapacidad = 1
      AND v.porcentaje_incapacidad IS NOT NULL
      AND TRIM(v.porcentaje_incapacidad) <> ''
) t
WHERE NOT (t.pct REGEXP '^[0-9]{1,3}([.][0-9]{1,4})?$' AND CAST(t.pct AS DECIMAL(10,4)) <= 100)
GROUP BY t.porcentaje_incapacidad
ORDER BY cantidad DESC
LIMIT 30;

-- A6. Cierres vigentes con incapacidad = 1 y sin porcentaje (quedan con_incapacidad = 1, porcentaje NULL).
SELECT COUNT(*) AS con_incapacidad_sin_porcentaje
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad = 1
  AND (v.porcentaje_incapacidad IS NULL OR TRIM(v.porcentaje_incapacidad) = '');

-- A7. Filas que insertaria el bloque B (cierre vigente con id_incapacidad no nulo y sin fila DEFINITIVA).
SELECT COUNT(*) AS filas_a_insertar
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad IS NOT NULL
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
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
JOIN cs.denuncias d ON d.id_denuncia = v.id_denuncia
LEFT JOIN cs.estados_medicos e ON e.id_estado_medico = d.id_estado_medico
WHERE v.id_incapacidad IS NOT NULL
  AND COALESCE(e.es_cierre, 0) <> 1;


-- ============================================
-- BLOQUE B - INSERT (escribe)
-- Una fila DEFINITIVA por denuncia, desde su cierre vigente (mayor id_cierre_denuncia_log),
-- solo si id_incapacidad no es NULL. No pisa filas existentes: el NOT EXISTS evita
-- tocar lo que ya escribieron los ws, y el UNIQUE (id_denuncia, tipo) lo respalda.
-- Si el volumen es grande y hay riesgo de lock wait, correr por tramos agregando
-- "AND v.id_denuncia BETWEEN <desde> AND <hasta>" al WHERE.
-- ============================================

START TRANSACTION;

INSERT INTO cs.denuncias_incapacidad
    (id_denuncia, tipo, con_incapacidad, porcentaje, origen, id_persona, fecha_carga, fecha_modificacion)
SELECT x.id_denuncia,
       'DEFINITIVA',
       x.con_incapacidad,
       CASE
           WHEN x.con_incapacidad = 1
            AND x.pct REGEXP '^[0-9]{1,3}([.][0-9]{1,4})?$'
            AND CAST(x.pct AS DECIMAL(10,4)) <= 100
           THEN CAST(x.pct AS DECIMAL(5,2))
           ELSE NULL
       END,
       'MIGRACION',
       x.id_responsable,
       COALESCE(x.fecha_carga_alta, NOW()),
       COALESCE(x.fecha_carga_alta, NOW())
FROM (
    SELECT v.id_denuncia,
           v.id_responsable,
           v.fecha_carga_alta,
           CASE WHEN v.id_incapacidad = 1 THEN 1 ELSE 0 END AS con_incapacidad,
           REPLACE(REPLACE(REPLACE(TRIM(v.porcentaje_incapacidad), '%', ''), ' ', ''), ',', '.') AS pct
    FROM cs.cierres_denuncias_log v
    JOIN (
        SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
        FROM cs.cierres_denuncias_log
        GROUP BY id_denuncia
    ) u ON u.id_max = v.id_cierre_denuncia_log
    WHERE v.id_incapacidad IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM cs.denuncias_incapacidad di
            WHERE di.id_denuncia = v.id_denuncia
              AND di.tipo = 'DEFINITIVA'
      )
) x;

-- Revisar las filas afectadas contra A7 antes de confirmar.
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

-- C2. Control de porcentaje: con incapacidad con y sin porcentaje, y sin incapacidad con porcentaje (debe ser 0).
SELECT SUM(con_incapacidad = 1 AND porcentaje IS NOT NULL) AS con_incapacidad_con_porcentaje,
       SUM(con_incapacidad = 1 AND porcentaje IS NULL)     AS con_incapacidad_sin_porcentaje,
       SUM(con_incapacidad = 0 AND porcentaje IS NOT NULL) AS sin_incapacidad_con_porcentaje_debe_ser_0
FROM cs.denuncias_incapacidad
WHERE tipo = 'DEFINITIVA' AND origen = 'MIGRACION';

-- C3. Pendientes tras el INSERT: debe dar 0 (idempotencia).
SELECT COUNT(*) AS pendientes
FROM cs.cierres_denuncias_log v
JOIN (
    SELECT id_denuncia, MAX(id_cierre_denuncia_log) AS id_max
    FROM cs.cierres_denuncias_log
    GROUP BY id_denuncia
) u ON u.id_max = v.id_cierre_denuncia_log
WHERE v.id_incapacidad IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM cs.denuncias_incapacidad di
        WHERE di.id_denuncia = v.id_denuncia
          AND di.tipo = 'DEFINITIVA'
  );

-- C4. Muestra de 10 filas migradas contra el cierre original.
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
    GROUP BY id_denuncia
) u ON u.id_denuncia = di.id_denuncia
JOIN cs.cierres_denuncias_log v ON v.id_cierre_denuncia_log = u.id_max
WHERE di.tipo = 'DEFINITIVA'
  AND di.origen = 'MIGRACION'
ORDER BY RAND()
LIMIT 10;


-- ============================================
-- NOTAS
-- ============================================
-- Que NO cubre:
--   * La incapacidad PRESUNTA no se backfillea. cs.denuncias.porcentaje_incapacidad es una
--     columna compartida entre la presunta y la definitiva y no se puede separar con certeza
--     cual de las dos representa; ademas el cierre copia ese valor. Las filas PRESUNTA las
--     escriben los ws desde ahora.
--   * Denuncias cuyo cierre vigente tiene id_incapacidad NULL (p. ej. cierres por muerte,
--     donde el cierre borra el dato): quedan sin fila, o sea "sin dato".
--   * Denuncias cerradas que nunca pasaron por cierres_denuncias_log: no hay fuente.
--   * Porcentajes con texto no numerico, fuera de 0 a 100 o con mas de 4 decimales: la fila
--     se inserta con con_incapacidad correcto y porcentaje NULL (ver A5 y A5b).
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

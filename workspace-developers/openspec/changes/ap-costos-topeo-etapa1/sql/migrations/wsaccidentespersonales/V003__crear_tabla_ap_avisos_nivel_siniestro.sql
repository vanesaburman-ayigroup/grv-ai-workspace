-- ================================================================================
-- V003 - CREATE TABLE cs.ap_avisos_nivel_siniestro
-- Fecha: 2026-07-30
-- Repo destino: wsaccidentespersonales  (servicio NUEVO)
-- Ruta en el repo: sql/migrations/V003__crear_tabla_ap_avisos_nivel_siniestro.sql
-- Change OpenSpec: ap-costos-topeo-etapa1  ·  spec: ap-semaforo-gestion
-- Ticket: PENDIENTE -- todavia no existe el issue de Jira. Trazabilidad por el
--         change de OpenSpec `ap-costos-topeo-etapa1`. Completar el GRV-NNNN
--         cuando se cree (placeholder deliberado, no borrar la linea).
--
-- Descripcion (el POR QUE, no el que):
--   El semaforo se calcula en cada consulta, pero el aviso al gestor tiene que
--   dispararse UNA sola vez por nivel alcanzado. Si el "ya avise" viviera en
--   memoria del servicio, cada refresh de pantalla, cada instancia detras del
--   gateway y cada reinicio del contenedor volverian a avisar lo mismo (el
--   antipatron de estado mutable en static ya nos paso en el ecosistema). Por eso
--   el hecho "este siniestro alcanzo este nivel" se persiste, y la unicidad la
--   garantiza la BASE, no el codigo: con dos instancias concurrentes calculando el
--   mismo siniestro, el UNIQUE es lo unico que serializa de verdad. El segundo
--   INSERT choca con duplicate key y el servicio lo traga sin avisar de nuevo.
--
--   La tabla guarda ademas la FOTO del momento del aviso (porcentaje, proyeccion y
--   suma asegurada vigentes). Es necesario porque el tope se puede AMPLIAR con
--   motivo: si manana la suma asegurada sube, el aviso ya emitido tiene que seguir
--   siendo explicable -- "se aviso EXCEDIDO cuando el tope era X" -- y no quedar
--   como un falso positivo contra el tope nuevo.
--
--   Al exceder el tope el sistema SOLO avisa. El bloqueo de autorizaciones existe
--   pero arranca DESACTIVADO y se activa por parametro en base: esta tabla no
--   bloquea nada, es registro de aviso.
--
-- POR QUE NO HAY `activo` NI BAJA LOGICA:
--   Cada fila es un hecho historico consumado (se aviso, alguien lo vio). No se da
--   de baja. Ademas un `activo` en el UNIQUE lo volveria inutil: alcanzaria con
--   poner activo = 0 para que el mismo aviso se vuelva a emitir. Re-avisar despues
--   de una ampliacion de tope NO se resuelve borrando ni desactivando filas: se
--   resuelve con `id_tope` dentro del UNIQUE (ver el bloque siguiente), de modo que
--   el aviso quede unico por (siniestro, nivel, tope) y el historial se conserve.
--
-- AMPLIACION DE TOPE -- POR QUE `id_tope` ENTRA EN EL UNIQUE:
--   El tope se puede AMPLIAR (polizas_ap_topes admite un tope nuevo con motivo).
--   Al ampliarlo el denominador crece, el porcentaje BAJA y el siniestro sale de
--   EXCEDIDO. Cuando el consumo vuelve a superar el tope NUEVO hay que avisar otra
--   vez -- es el momento mas importante para avisar. Con un UNIQUE por
--   (id_denuncia, nivel) ese segundo INSERT choca con el aviso VIEJO (el del tope
--   anterior), el servicio lo traga como "ya avise" y el gestor nunca se entera.
--   Por eso el UNIQUE incluye el tope vigente al momento del aviso.
--
--   TRAMPA DEL NULL: en MariaDB dos NULL no colisionan en un UNIQUE, asi que un
--   UNIQUE (id_denuncia, nivel, id_tope) con id_tope NULL-able permitiria INFINITAS
--   filas del mismo nivel para una poliza sin tope regularizado -- se pierde la
--   garantia "un aviso por nivel" justo en el caso degradado. Se resuelve sin
--   ensuciar el dato de negocio: `id_tope` queda NULL-able (NULL = no habia tope
--   identificable, que es la verdad), y el UNIQUE usa la columna generada PERSISTENT
--   `id_tope_uk` = IFNULL(id_tope, 0), que colapsa todos los NULL en el centinela 0
--   y vuelve a colisionar. Alternativa descartada: `id_tope INT NOT NULL DEFAULT 0`
--   -- mismo efecto, pero miente sobre el dato (0 no es un tope) y arrastra el
--   centinela a todos los JOIN y reportes.
--
--   TRADE-OFF ASUMIDO (explicito): esta forma puede avisar DOS VECES el mismo nivel
--   del mismo siniestro si el tope cambia -- una por tope. Se acepta a proposito:
--   es mejor avisar dos veces que no avisar cuando el siniestro se paso del tope.
--   El "ruido" es acotado (una vez por ampliacion, que es un evento excepcional y
--   con motivo registrado) y cada aviso es explicable por su propio denominador
--   (suma_asegurada_al_avisar + id_tope). El caso inverso -- silencio sobre un
--   siniestro excedido -- no tiene deteccion posible y es el que cuesta plata.
--
--   El servicio DEBE poblar id_tope leyendolo de denuncia_poliza.id_tope (el tope
--   vigente de esa denuncia) en el mismo calculo que produce pct_al_avisar, para
--   que la foto y la clave hablen del mismo tope. Sin backfill: la tabla nace vacia.
--
-- SALTO DE DOS O MAS NIVELES (de Medio directo a Excedido) -- CONFIRMADO:
--   La estructura NO exige los niveles intermedios y no puede exigirlos: no hay FK,
--   ni columna de orden, ni CHECK ni trigger que mire otras filas (un CHECK no
--   admite subqueries en MariaDB 10.5), y `nivel` no tiene DEFAULT ni dependencia
--   de ninguna otra columna. Insertar directamente EXCEDIDO como PRIMERA y UNICA
--   fila de un siniestro es una operacion valida y no falla. Una erogacion grande que
--   lleva un siniestro del 35% al 120% inserta UNA sola fila, nivel = 'EXCEDIDO',
--   con pct_al_avisar = 120.00 -- y eso es exactamente el aviso correcto: al
--   gestor le importa donde esta, no por donde paso.
--   Dos consecuencias que quedan cubiertas por el mismo diseno:
--     1) Si mas adelante negocio pide "avisar tambien los niveles saltados", se
--        resuelve insertando las N filas en la MISMA transaccion (ALTO, MUY_ALTO,
--        EXCEDIDO), todas con el mismo pct_al_avisar real. El UNIQUE lo tolera sin
--        cambiar estructura.
--     2) Un salto es detectable a posteriori sin columna extra: pct_al_avisar muy
--        por encima del umbral del nivel avisado, o ausencia de las filas de los
--        niveles inferiores para ese id_denuncia.
--
-- ORDEN DE LOS NIVELES -- TRAMPA:
--   `nivel` es texto, asi que ordenar alfabeticamente MIENTE
--   ('ALTO' < 'EXCEDIDO' < 'MUY_ALTO'). Para "el nivel mas alto alcanzado" hay que
--   ordenar explicitamente, por ejemplo:
--     ORDER BY CASE nivel WHEN 'ALTO' THEN 1 WHEN 'MUY_ALTO' THEN 2
--                         WHEN 'EXCEDIDO' THEN 3 END DESC
--   No se agrega una columna de orden a proposito: seria una segunda fuente de
--   verdad de una escala que ya vive en el servicio (y los cortes 90/100 son FIJOS,
--   solo 40 y 70 son parametrizables).
--
-- DOMINIO DE `nivel` -- EL CHECK ES CASE-INSENSITIVE (a tener en cuenta):
--   La tabla es utf8mb4_unicode_ci, y `_ci` = case-insensitive. Por lo tanto el
--   CHECK `nivel IN ('ALTO','MUY_ALTO','EXCEDIDO')` acepta tambien 'alto', 'Alto' o
--   'ExCeDiDo': la base valida el dominio, NO la forma. Consecuencias reales:
--     - El UNIQUE tambien es case-insensitive, asi que 'ALTO' y 'alto' SI colisionan
--       -- la garantia "un aviso por nivel y tope" no se rompe por casing.
--     - Pero el dato quedaria guardado como lo mando el cliente, y todo lo que
--       compare por string exacto (el CASE de orden de mas abajo, el switch del
--       front, los GROUP BY de los reportes) empezaria a fallar en silencio.
--   Por eso la normalizacion a MAYUSCULAS es responsabilidad del SERVICIO: el enum
--   Java es la fuente del valor y se persiste con name() (siempre mayusculas); si
--   algun dia entra por payload libre, va .toUpperCase() antes del INSERT. No se
--   agrega un trigger de UPPER() para no tener dos fuentes de verdad del dominio.
--
-- SIN FOREIGN KEYS: el ecosistema no declara FKs (verificado en
--   INFORMATION_SCHEMA.KEY_COLUMN_USAGE sobre denuncia_poliza y polizas_ap). Solo
--   indices; la relacion logica queda en los COMMENT.
--
-- TIPO DE id_denuncia (verificado el 30/07/2026 -- no re-relevar):
--   denuncias.id_denuncia INT(11) / denuncia_poliza.id_denuncia BIGINT(20) /
--   erogaciones.id_denuncia INT(10) / turnos.id_denuncia DECIMAL(22,0). Se adopta
--   BIGINT(20) espejando denuncia_poliza, la puerta de entrada del universo AP.
--   El join contra INT sigue usando indice.
-- ================================================================================

CREATE TABLE IF NOT EXISTS `cs`.`ap_avisos_nivel_siniestro` (

  `id_aviso`                   BIGINT(20)     NOT NULL AUTO_INCREMENT
                               COMMENT 'PK subrogada.',

  `id_denuncia`                BIGINT(20)     NOT NULL
                               COMMENT 'Siniestro que alcanzo el nivel. Relacion logica con cs.denuncias.id_denuncia (INT(11)) y cs.denuncia_poliza.id_denuncia (BIGINT(20)). Sin FK.',

  `nivel`                      VARCHAR(15)    NOT NULL
                               COMMENT 'Nivel alcanzado y avisado: ALTO (70-90) | MUY_ALTO (90-100) | EXCEDIDO (>100). Bajo y Medio no generan aviso, por eso no estan en el dominio. Validado por CHECK chk_ap_avisos_nivel, que por la collation _ci es case-insensitive: el servicio normaliza a MAYUSCULAS.',

  `id_tope`                    INT(11)        NULL
                               COMMENT 'Tope vigente usado como denominador del aviso. Relacion logica con cs.polizas_ap_topes.id_tope (sin FK). Lo pobla el servicio leyendo denuncia_poliza.id_tope en el mismo calculo que produce pct_al_avisar. NULL = poliza sin tope regularizado. Entra en el UNIQUE (via id_tope_uk) para que una AMPLIACION de tope habilite un aviso nuevo del mismo nivel.',

  `id_tope_uk`                 INT(11)        AS (IFNULL(`id_tope`, 0)) PERSISTENT
                               COMMENT 'Columna TECNICA, solo para el UNIQUE: colapsa id_tope NULL en el centinela 0 porque en MariaDB los NULL no colisionan y un NULL-able en la clave permitiria avisos duplicados infinitos. No usar en queries de negocio ni en JOINs: para eso esta id_tope. Generada -- no listarla en los INSERT.',

  -- ---------- Foto del momento del aviso ----------
  `pct_al_avisar`              DECIMAL(7,2)   NOT NULL
                               COMMENT 'Porcentaje de consumo sobre el tope en el instante del aviso. Puede superar 100 (EXCEDIDO) -- de ahi el (7,2). Es lo que permite reconstruir por que se aviso y detectar saltos de nivel.',

  `proyeccion_al_avisar`       DECIMAL(16,2)  NULL
                               COMMENT 'Consumo proyectado (facturado + estimado + valores manuales) al momento del aviso. Nullable porque puede no haber proyeccion calculable si falta el estimado.',

  `suma_asegurada_al_avisar`   DECIMAL(16,2)  NULL
                               COMMENT 'Tope vigente (CON IVA) usado como denominador en ese momento -- el IMPORTE de la fila apuntada por id_tope. Es la foto que sostiene el aviso si despues el tope se amplia. Nullable solo para el caso degradado de poliza sin tope regularizado.',

  `moneda`                     VARCHAR(3)     NOT NULL DEFAULT 'ARS'
                               COMMENT 'ISO 4217 de los importes de la foto, para que proyeccion y suma asegurada sean comparables a futuro. VARCHAR(3) por consistencia con polizas_ap_topes y denuncia_poliza (no CHAR: CHAR paddea a la derecha y ensucia comparaciones).',

  `fecha_aviso`                DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                               COMMENT 'Cuando se registro el aviso.',

  `evento_disparador`          VARCHAR(40)    NULL
                               COMMENT 'Que operacion lo disparo (ej. AUDITAR_FACTURA, AUTORIZAR_PRESTACION, CARGA_VALOR_MANUAL, RECALCULO_BATCH). Sirve para explicar un aviso sin tener que reconstruir el timeline a mano.',

  -- ---------- Acuse de lectura ----------
  `usuario_visto`              INT            NULL
                               COMMENT 'id_persona que marco el aviso como visto. NULL = pendiente. INT por la convencion de tablas nuevas (el legacy usa DECIMAL(22,0) para usuario; no se replica).',

  `fecha_visto`                DATETIME       NULL
                               COMMENT 'Cuando se marco como visto. NULL = pendiente.',

  -- ---------- Auditoria ----------
  `usuario_alta`               INT            NULL
                               COMMENT 'id_persona en cuya sesion se disparo el calculo. NULL cuando lo genera un proceso batch (no hay usuario).',

  `fecha_alta`                 DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                               COMMENT 'Auditoria de insercion. Se mantiene aparte de fecha_aviso: fecha_aviso es dato de negocio, fecha_alta es tecnica (si algun dia se backfillean avisos historicos, las dos difieren).',

  PRIMARY KEY (`id_aviso`),

  -- LA regla del requerimiento: un aviso por (siniestro, nivel) PARA UN MISMO TOPE,
  -- garantizado por la base. Es tambien el candado de concurrencia entre instancias
  -- y el que habilita el INSERT idempotente del servicio:
  --   INSERT INTO cs.ap_avisos_nivel_siniestro
  --          (id_denuncia, nivel, id_tope, pct_al_avisar, ...)   -- id_tope_uk NO
  --   VALUES (...)
  --   ON DUPLICATE KEY UPDATE id_aviso = id_aviso;   -- no-op si ya se aviso
  -- (equivalente a INSERT IGNORE, pero explicito sobre que no se pisa la foto
  -- original: el primer aviso de ESE tope es el que vale).
  --
  -- id_tope_uk (= IFNULL(id_tope,0)) en lugar de id_tope: sin el centinela, los
  -- avisos con id_tope NULL no colisionarian entre si y se repetiria el aviso en
  -- cada consulta. Ver "AMPLIACION DE TOPE" en el banner para el trade-off asumido
  -- (puede avisar dos veces el mismo nivel si el tope cambia -- deliberado).
  -- El prefijo (id_denuncia, nivel) del mismo indice sigue sirviendo los lookups
  -- de "este siniestro ya fue avisado en este nivel?" sin indice extra.
  UNIQUE KEY `uk_ap_avisos_denuncia_nivel_tope` (`id_denuncia`, `nivel`, `id_tope_uk`),

  -- Bandeja de pendientes de acuse: WHERE fecha_visto IS NULL ORDER BY fecha_aviso.
  KEY `idx_ap_avisos_pendientes` (`fecha_visto`, `fecha_aviso`),

  -- Distribucion de cartera por nivel (COUNT(*) GROUP BY nivel en la base, no en
  -- Java) y listados por nivel con recencia.
  KEY `idx_ap_avisos_nivel_fecha` (`nivel`, `fecha_aviso`),

  -- Dominio cerrado de nivel. OJO: por la collation utf8mb4_unicode_ci este CHECK es
  -- CASE-INSENSITIVE ('alto' pasa). Valida el dominio, no la forma: la normalizacion
  -- a mayusculas la hace el servicio (enum Java persistido con name()). Detalle y
  -- consecuencias en el banner, seccion "DOMINIO DE nivel".
  CONSTRAINT `chk_ap_avisos_nivel`
    CHECK (`nivel` IN ('ALTO','MUY_ALTO','EXCEDIDO')),

  -- Un porcentaje negativo es un error de calculo, no un estado posible.
  CONSTRAINT `chk_ap_avisos_pct_no_negativo`
    CHECK (`pct_al_avisar` >= 0),

  -- Coherencia del acuse: o estan los dos datos del visto, o ninguno.
  CONSTRAINT `chk_ap_avisos_visto`
    CHECK ((`usuario_visto` IS NULL AND `fecha_visto` IS NULL)
        OR (`usuario_visto` IS NOT NULL AND `fecha_visto` IS NOT NULL))

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='AP: registro de que un siniestro alcanzo un nivel del semaforo, para no repetir el mismo aviso en cada consulta. Unico por (id_denuncia, nivel, tope vigente): una ampliacion de tope habilita un aviso nuevo del mismo nivel a proposito.';


-- ================================================================================
-- VERIFICACION -- EJECUTABLE, read-only. Correr TAL CUAL despues de aplicar.
-- Estas migraciones se aplican A MANO: esta es la unica red de control, por eso los
-- SELECT van descomentados. Ninguno escribe.
-- ================================================================================

-- 1) Tabla, engine y collation.  Esperado: 1 fila, InnoDB, utf8mb4_unicode_ci.
SELECT TABLE_NAME, ENGINE, TABLE_COLLATION
  FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_avisos_nivel_siniestro';

-- 2) Columnas, nulabilidad y expresion de la generada.
--    Esperado: moneda = varchar(3) NOT NULL DEFAULT 'ARS'; id_tope = int(11) YES;
--    id_tope_uk con EXTRA que dice STORED/PERSISTENT GENERATED.
SELECT ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT,
       EXTRA, GENERATION_EXPRESSION
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_avisos_nivel_siniestro'
 ORDER BY ORDINAL_POSITION;

-- 3) El UNIQUE existe, es realmente unico (NON_UNIQUE = 0) y tiene las 3 columnas
--    en orden (id_denuncia, nivel, id_tope_uk).
SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, NON_UNIQUE
  FROM INFORMATION_SCHEMA.STATISTICS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_avisos_nivel_siniestro'
 ORDER BY INDEX_NAME, SEQ_IN_INDEX;

-- 3b) Control duro del punto 3: tiene que devolver exactamente 1 fila con
--     columnas_uk = 'id_denuncia,nivel,id_tope_uk'. Si devuelve otra cosa, el
--     UNIQUE no protege la ampliacion de tope.
SELECT INDEX_NAME,
       GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS columnas_uk
  FROM INFORMATION_SCHEMA.STATISTICS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_avisos_nivel_siniestro'
   AND NON_UNIQUE = 0 AND INDEX_NAME <> 'PRIMARY'
 GROUP BY INDEX_NAME;

-- 4) Los 3 CHECK quedaron declarados (nivel, pct no negativo, coherencia del visto).
SELECT CONSTRAINT_NAME, CHECK_CLAUSE
  FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA = 'cs' AND TABLE_NAME = 'ap_avisos_nivel_siniestro';

-- 5) La tabla nace vacia (no hay backfill). Esperado: 0.
SELECT COUNT(*) AS debe_ser_0 FROM cs.ap_avisos_nivel_siniestro;

-- --------------------------------------------------------------------------------
-- 6) PRUEBA FUNCIONAL -- OPCIONAL Y SOLO EN DEV. Queda COMENTADA a proposito porque
--    escribe (aunque haga ROLLBACK: toma locks y consume AUTO_INCREMENT, y en PROD
--    no se corre). Cubre las 3 garantias de una sola pasada:
--      a) mismo (denuncia, nivel, tope): NO duplica y no pisa la foto original;
--      b) mismo (denuncia, nivel) con tope AMPLIADO: SI inserta -- vuelve a avisar;
--      c) id_tope NULL repetido: NO duplica, gracias al centinela de id_tope_uk;
--      d) salto de dos niveles: EXCEDIDO entra como primer y unico aviso, sin ALTO
--         ni MUY_ALTO previos.
-- START TRANSACTION;
-- INSERT INTO cs.ap_avisos_nivel_siniestro
--        (id_denuncia, nivel, id_tope, pct_al_avisar, proyeccion_al_avisar,
--         suma_asegurada_al_avisar, evento_disparador)
-- VALUES (999999999, 'EXCEDIDO', 1, 120.00, 1200000.00, 1000000.00, 'PRUEBA')
--     ON DUPLICATE KEY UPDATE id_aviso = id_aviso;
-- -- (a) mismo tope, otro porcentaje -> no-op
-- INSERT INTO cs.ap_avisos_nivel_siniestro
--        (id_denuncia, nivel, id_tope, pct_al_avisar, proyeccion_al_avisar,
--         suma_asegurada_al_avisar, evento_disparador)
-- VALUES (999999999, 'EXCEDIDO', 1, 135.00, 1350000.00, 1000000.00, 'PRUEBA')
--     ON DUPLICATE KEY UPDATE id_aviso = id_aviso;
-- -- (b) tope ampliado (id_tope = 2) -> tiene que entrar una fila nueva
-- INSERT INTO cs.ap_avisos_nivel_siniestro
--        (id_denuncia, nivel, id_tope, pct_al_avisar, proyeccion_al_avisar,
--         suma_asegurada_al_avisar, evento_disparador)
-- VALUES (999999999, 'EXCEDIDO', 2, 110.00, 2200000.00, 2000000.00, 'PRUEBA')
--     ON DUPLICATE KEY UPDATE id_aviso = id_aviso;
-- -- (c) sin tope identificado, dos veces -> una sola fila
-- INSERT INTO cs.ap_avisos_nivel_siniestro
--        (id_denuncia, nivel, id_tope, pct_al_avisar, evento_disparador)
-- VALUES (999999999, 'ALTO', NULL, 75.00, 'PRUEBA')
--     ON DUPLICATE KEY UPDATE id_aviso = id_aviso;
-- INSERT INTO cs.ap_avisos_nivel_siniestro
--        (id_denuncia, nivel, id_tope, pct_al_avisar, evento_disparador)
-- VALUES (999999999, 'ALTO', NULL, 88.00, 'PRUEBA')
--     ON DUPLICATE KEY UPDATE id_aviso = id_aviso;
-- SELECT nivel, id_tope, id_tope_uk, COUNT(*) AS filas, MIN(pct_al_avisar) AS pct_1er
--   FROM cs.ap_avisos_nivel_siniestro
--  WHERE id_denuncia = 999999999
--  GROUP BY nivel, id_tope, id_tope_uk
--  ORDER BY nivel, id_tope_uk;
-- -- Esperado: 3 filas -> (ALTO, NULL, 0, 1, 75.00)
-- --                      (EXCEDIDO, 1, 1, 1, 120.00)
-- --                      (EXCEDIDO, 2, 2, 1, 110.00)
-- ROLLBACK;

-- ================================================================================
-- ROLLBACK (comentado a proposito -- borra el historial de avisos y hace que todos
-- los avisos ya emitidos se vuelvan a emitir en la proxima consulta)
-- ================================================================================
-- DROP TABLE IF EXISTS `cs`.`ap_avisos_nivel_siniestro`;

-- ================================================================================
-- V002 - CREATE TABLE cs.ap_valores_manuales
-- Fecha: 2026-07-30
-- Repo destino: wsaccidentespersonales  (servicio NUEVO)
-- Ruta en el repo: sql/migrations/V002__crear_tabla_ap_valores_manuales.sql
-- Change OpenSpec: ap-costos-topeo-etapa1  ·  spec: ap-consumo-topeo
-- Ticket: PENDIENTE -- todavia no existe el issue en Jira. Trazabilidad por el
--         change de OpenSpec `ap-costos-topeo-etapa1`. Reemplazar por GRV-NNNN
--         cuando se cree (placeholder intencional, no borrar sin el numero real).
--
-- Descripcion (el POR QUE, no el que):
--   El consumo de un siniestro AP no se puede armar solo con lo que ya esta en
--   base. Hay dos huecos que hoy se tapan a mano en una planilla y que, por eso,
--   no entran al denominador del semaforo:
--
--   (a) MEDICACION: la erogacion de farmacia dice literalmente "medicacion" y
--       nada mas. El cliente pide el detalle (que medicamento, cuanto, a que
--       precio) y ese precio se consulta en un portal externo que NO conserva
--       historial: si no lo guardamos nosotros en el momento de la consulta, el
--       dato se pierde y no hay forma de reconstruir con que precio se valorizo
--       un consumo de hace seis meses. Por eso van juntos precio_unitario,
--       fuente_precio y fecha_precio: sin la fecha y la fuente el precio no es
--       auditable.
--
--   (b) NO_CONVENIDA: prestaciones fuera de grilla (tipicamente cirugias) que se
--       acuerdan por presupuesto. No tienen valor en el nomenclador ni en
--       valores_venta_prestacion, asi que el unico origen posible del monto es la
--       carga manual con la referencia del acuerdo que lo respalda.
--
-- POR QUE UNA SOLA TABLA Y NO DOS:
--   Ambos casos son el mismo hecho de negocio -- "un monto cargado a mano que
--   suma al consumo de un siniestro AP" -- y tienen el mismo consumidor: la vista
--   ap_consumo_siniestro. Separarlos obligaria a un UNION ALL permanente en esa
--   vista, a dos entidades, dos repositorios, dos endpoints y dos permisos para
--   una diferencia de 5 columnas. Las columnas comunes (id_denuncia, tipo, monto,
--   iva_incluido, moneda, fecha_imputacion, activo, auditoria) son la mayoria del
--   registro. Ademas el universo es minimo (73 denuncias AP al 30/07/2026): no hay
--   argumento de volumen para partirla.
--   El costo de la decision son columnas nullable condicionadas por `tipo`, y se
--   mitiga con los CHECK de mas abajo, que hacen obligatorio en base lo que cada
--   tipo necesita. Si mas adelante aparece un tercer tipo con muchos campos
--   propios, ahi si corresponde una tabla satelite y NO seguir sumando columnas
--   nullable a esta.
--
-- TIPOS Y JOINS (verificado en INFORMATION_SCHEMA el 30/07/2026 -- no re-relevar):
--   La clave de denuncia esta declarada distinta en cada tabla del ecosistema:
--     cs.denuncias.id_denuncia        INT(11)        (PK)
--     cs.denuncia_poliza.id_denuncia  BIGINT(20)
--     cs.erogaciones.id_denuncia      INT(10)
--     cs.turnos.id_denuncia           DECIMAL(22,0)  (nullable)
--   Se adopta BIGINT(20) para espejar denuncia_poliza, que es la puerta de entrada
--   del universo AP (toda consulta arranca por ahi). El join contra INT sigue
--   usando indice: la comparacion entre enteros de distinto ancho no invalida el
--   indice. La unica precaucion real es turnos.id_denuncia DECIMAL(22,0): al
--   cruzar, la conversion tiene que quedar del lado de la constante o de esta
--   tabla, NUNCA envolviendo turnos.id_denuncia en una funcion (ahi si se pierde
--   el indice).
--
-- SIN FOREIGN KEYS: se verifico que el ecosistema no declara FKs (ni
--   denuncia_poliza ni polizas_ap tienen ninguna). No se agregan CONSTRAINT ...
--   FOREIGN KEY. Las relaciones logicas quedan documentadas en los COMMENT de
--   cada columna y se garantizan por servicio.
--
-- CHECK CONSTRAINTS: MariaDB 10.2.1+ los valida realmente. Aun asi la validacion
--   server-side en el servicio es obligatoria: el CHECK es la red, no el control.
-- ================================================================================

CREATE TABLE IF NOT EXISTS `cs`.`ap_valores_manuales` (

  `id_valor_manual`   BIGINT(20)     NOT NULL AUTO_INCREMENT
                      COMMENT 'PK subrogada.',

  -- ---------- Anclaje del consumo ----------
  `id_denuncia`       BIGINT(20)     NOT NULL
                      COMMENT 'Siniestro al que se imputa. Relacion logica con cs.denuncias.id_denuncia (INT(11)) y con cs.denuncia_poliza.id_denuncia (BIGINT(20)). Sin FK: el ecosistema no usa FKs.',

  `id_erogacion`      INT(10)        NULL
                      COMMENT 'Opcional. Relacion logica con cs.erogaciones.id_erogacion (INT(10) signed, tipo espejado a proposito). Se completa cuando esta fila DETALLA una erogacion ya cargada (el clasico "medicacion" sin detalle). En ese caso computa_consumo TIENE que ir en 0 para no contar el monto dos veces, y eso lo enforza chk_ap_val_man_no_doble_conteo. Relacion 1:N: una misma erogacion se detalla con tantas filas como medicamentos, por eso el indice de erogacion no es unico.',

  `computa_consumo`   TINYINT(1)     NOT NULL DEFAULT 1
                      COMMENT '1 = el monto suma al consumo del siniestro. 0 = la fila es solo el detalle de una erogacion ya contabilizada (ver id_erogacion). Evita el doble conteo contra el tope. El DEFAULT 1 sirve al caso normal (carga sin erogacion asociada): cuando se manda id_erogacion, el servicio tiene que setear 0 EXPLICITAMENTE o el INSERT falla por el CHECK.',

  -- ---------- Discriminante ----------
  `tipo`              VARCHAR(20)    NOT NULL
                      COMMENT 'MEDICACION | NO_CONVENIDA. Dominio validado por CHECK chk_ap_val_man_tipo.',

  -- ---------- Comun a los dos tipos ----------
  `descripcion`       VARCHAR(255)   NOT NULL
                      COMMENT 'MEDICACION: nombre del medicamento tal como se compro (droga + presentacion + potencia). Es el requerimiento explicito del cliente: la erogacion de farmacia solo dice "medicacion". NO_CONVENIDA: descripcion de la prestacion acordada.',

  `monto`             DECIMAL(16,2)  NOT NULL
                      COMMENT 'Monto que entra al consumo. Para MEDICACION el servicio lo calcula como cantidad * precio_unitario; no se hace columna generada porque NO_CONVENIDA no tiene cantidad ni precio unitario y porque el monto es el dato de negocio (la fuente de verdad del consumo), no un derivado a recalcular.',

  `iva_incluido`      TINYINT(1)     NOT NULL DEFAULT 1
                      COMMENT '1 = el monto ya incluye IVA. El tope por (poliza, asegurado) es CON IVA incluido, asi que el consumo tiene que ser comparable: si entra un monto sin IVA el servicio lo normaliza antes de acumular.',

  `moneda`            VARCHAR(3)     NOT NULL DEFAULT 'ARS'
                      COMMENT 'ISO 4217. VARCHAR(3) -- no CHAR(3) -- para espejar el tipo que ya usan cs.polizas_ap_topes y cs.denuncia_poliza: si la columna que se compara contra el tope tiene otro tipo, el join/comparacion queda a merced de la conversion implicita. Presente para que el consumo sea comparable contra la moneda del tope; hoy siempre ARS.',

  `fecha_imputacion`  DATE           NOT NULL
                      COMMENT 'Fecha a la que se imputa el consumo (compra del medicamento / realizacion de la prestacion). NO es la fecha de carga: es la que define en que ventana cae el gasto cuando el tope es ANUAL o por EVENTO.',

  -- ---------- Especifico de MEDICACION ----------
  `cantidad`          DECIMAL(12,3)  NULL
                      COMMENT 'Unidades / envases. Con decimales porque hay presentaciones fraccionadas. Obligatorio para MEDICACION (CHECK).',

  `precio_unitario`   DECIMAL(16,2)  NULL
                      COMMENT 'Precio por unidad al momento de la consulta. Obligatorio para MEDICACION (CHECK).',

  `fuente_precio`     VARCHAR(120)   NULL
                      COMMENT 'De donde salio el precio (nombre del portal / farmacia / lista consultada). Obligatorio para MEDICACION: sin fuente el precio no es auditable.',

  `fecha_precio`      DATE           NULL
                      COMMENT 'Fecha en que se consulto ese precio. Obligatorio para MEDICACION. Es la columna que construye el historial de precios que el portal externo NO conserva, y la que ordena la busqueda del ultimo precio conocido.',

  -- ---------- Especifico de NO_CONVENIDA ----------
  `referencia_acuerdo` VARCHAR(120)  NULL
                      COMMENT 'Identificacion del presupuesto / acuerdo que respalda el monto (nro de presupuesto, orden de compra, expediente). Obligatorio para NO_CONVENIDA (CHECK).',

  `observaciones`     VARCHAR(500)   NULL
                      COMMENT 'Texto libre de gestion.',

  -- ---------- Baja logica + auditoria ----------
  `activo`            TINYINT(1)     NOT NULL DEFAULT 1
                      COMMENT '1 = vigente y computable. Baja SIEMPRE logica: un valor manual dado de baja tiene que seguir explicando un consumo historico ya avisado.',

  `fecha_alta`        DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                      COMMENT 'Fecha de carga del registro.',

  `usuario_alta`      INT            NULL
                      COMMENT 'id_persona que cargo. INT por la convencion de las tablas nuevas (varias tablas legacy usan DECIMAL(22,0) para el usuario; no se replica).',

  `fecha_baja`        DATETIME       NULL
                      COMMENT 'Fecha de la baja logica.',

  `usuario_baja`      INT            NULL
                      COMMENT 'id_persona que dio de baja.',

  `motivo_baja`       VARCHAR(255)   NULL
                      COMMENT 'Por que se dio de baja. NULL solo mientras la fila esta activa: al dar de baja es OBLIGATORIO y no puede ser blanco (chk_ap_val_man_baja). Se pide porque estos montos mueven el semaforo: una baja sin motivo deja un consumo que baja sin explicacion.',

  PRIMARY KEY (`id_valor_manual`),

  -- Consumo por siniestro: es el acceso dominante. La vista ap_consumo_siniestro
  -- filtra por id_denuncia + activo + computa_consumo y agrupa/proyecta por tipo:
  --   SELECT tipo, SUM(monto)
  --     FROM cs.ap_valores_manuales
  --    WHERE id_denuncia = ? AND activo = 1 AND computa_consumo = 1
  --    GROUP BY tipo;
  -- El orden de columnas sigue el orden de uso real: primero las tres igualdades
  -- del WHERE y al final `tipo`, que solo agrupa. La version anterior
  -- (id_denuncia, tipo, activo) dejaba `tipo` en el medio sin que la consulta lo
  -- filtre, y eso corta el rango util del indice en el primer componente no
  -- usado: `activo` (y menos aun `computa_consumo`) ya no se podia resolver por
  -- indice y quedaba como filtro sobre la fila. Con este orden el acceso es un
  -- solo rango contiguo y el GROUP BY sale ordenado del propio indice (sin
  -- temporary/filesort). Sumar `monto` al final lo haria covering, pero con este
  -- volumen (73 denuncias AP) no paga el ancho extra de clave.
  KEY `idx_ap_val_man_denuncia_activo` (`id_denuncia`, `activo`, `computa_consumo`, `tipo`),

  -- "Ultimo precio conocido de un medicamento" (sugerencia al volver a cargar):
  --   SELECT precio_unitario, fuente_precio, fecha_precio
  --     FROM cs.ap_valores_manuales
  --    WHERE tipo = 'MEDICACION' AND descripcion = ? AND activo = 1
  --    ORDER BY fecha_precio DESC, id_valor_manual DESC
  --    LIMIT 1;
  -- Las tres columnas de igualdad van primero y fecha_precio queda ultima: asi el
  -- ORDER BY ... DESC LIMIT 1 se resuelve con un backward scan del indice, una sola
  -- fila leida y sin filesort. El tie-break por id_valor_manual tambien sale del
  -- indice: InnoDB le appendea la PK a todo indice secundario.
  -- descripcion se indexa COMPLETA (no por prefijo) a proposito: con un prefijo la
  -- igualdad deja de ser exacta, obliga a verificar contra la fila y el optimizador
  -- puede perder la garantia de orden y meter filesort. El costo de indexar el
  -- largo completo es 255 * 4 = 1020 bytes de clave, muy por debajo del limite de
  -- 3072 de InnoDB con row_format DYNAMIC, y la tabla es diminuta (73 denuncias AP
  -- al 30/07/2026): no hay razon para pagar el prefijo.
  -- El matcheo por nombre lo hace la collation: utf8mb4_unicode_ci es
  -- case-insensitive y accent-insensitive, asi que "Ibuprofeno 600" e
  -- "ibuprofeno 600" caen en la misma entrada del indice sin normalizar nada en
  -- Java. Lo que la collation NO resuelve son las variantes de escritura del mismo
  -- medicamento ("Ibuprof. 600mg"): eso se acota en la UI ofreciendo las
  -- descripciones ya usadas (autosuggest sobre este mismo indice) en lugar de
  -- texto libre. Sin eso, el historial de precios se fragmenta y la sugerencia
  -- deja de aparecer -- es el unico punto donde este diseno depende del front.
  KEY `idx_ap_val_man_ultimo_precio` (`tipo`, `descripcion`, `activo`, `fecha_precio`),

  -- Para resolver "esta erogacion ya tiene detalle cargado?".
  -- Queda NO UNICO a proposito: la relacion con la erogacion es 1:N, no 1:1. Una
  -- unica erogacion de farmacia que dice "medicacion" se detalla con TANTAS filas
  -- como medicamentos se compraron -- que es exactamente el requerimiento del
  -- cliente (saber que medicamentos, cada uno con su precio y su fuente). Un
  -- UNIQUE (id_erogacion) impediria cargar el segundo medicamento del mismo
  -- comprobante. Tampoco sirve UNIQUE (id_erogacion, descripcion): el mismo
  -- medicamento puede repetirse en la misma erogacion a precios distintos, y con
  -- baja logica el UNIQUE ademas bloquearia recargar una fila dada de baja.
  -- La regla que SI hay que sostener es la de no doble conteo, y esa la enforza
  -- chk_ap_val_man_no_doble_conteo (abajo), no un UNIQUE.
  KEY `idx_ap_val_man_erogacion` (`id_erogacion`),

  -- Dominio del discriminante.
  -- OJO con la collation: la tabla es utf8mb4_unicode_ci (case- y
  -- accent-insensitive), asi que este CHECK acepta tambien 'medicacion',
  -- 'Medicacion' o 'MEDICACIÓN'. NO es un dominio case-sensitive: si el servicio
  -- inserta con otro casing, la fila entra y el discriminante queda inconsistente
  -- para todo lo que compare en Java (switch/enum) o exporte a Excel.
  -- Contrato: el servicio normaliza `tipo` a MAYUSCULAS (y sin acentos) ANTES de
  -- insertar -- se hace en el mapper de la entidad, no en el controller, para que
  -- valga tambien en cargas por lote. El CHECK es la red contra un valor
  -- inventado, no contra el casing.
  CONSTRAINT `chk_ap_val_man_tipo`
    CHECK (`tipo` IN ('MEDICACION','NO_CONVENIDA')),

  -- Obligatoriedad condicionada por tipo: es lo que hace que una sola tabla no
  -- degenere en "todo nullable".
  CONSTRAINT `chk_ap_val_man_medicacion`
    CHECK (`tipo` <> 'MEDICACION'
           OR (`cantidad` IS NOT NULL
               AND `precio_unitario` IS NOT NULL
               AND `fuente_precio` IS NOT NULL
               AND `fecha_precio` IS NOT NULL)),

  CONSTRAINT `chk_ap_val_man_no_convenida`
    CHECK (`tipo` <> 'NO_CONVENIDA' OR `referencia_acuerdo` IS NOT NULL),

  -- Un monto negativo no es un ajuste: es un error de carga. Los ajustes se hacen
  -- por baja logica + alta nueva, que deja rastro.
  CONSTRAINT `chk_ap_val_man_monto_no_negativo`
    CHECK (`monto` >= 0),

  -- Anti doble conteo. La regla la enuncia el COMMENT de id_erogacion ("cuando
  -- id_erogacion no es NULL, computa_consumo debe ir en 0") pero hasta ahora nada
  -- la enforzaba: una fila con id_erogacion + computa_consumo = 1 hace que el
  -- monto se sume dos veces contra el tope (una por la erogacion original y otra
  -- por su propio detalle), y el error se ve recien en el semaforo, cuando el
  -- consumo ya se comunico al cliente. Es CHECK de una sola fila, sin subquery:
  -- valido en MariaDB 10.5.
  CONSTRAINT `chk_ap_val_man_no_doble_conteo`
    CHECK (`id_erogacion` IS NULL OR `computa_consumo` = 0),

  -- Coherencia de la baja logica. Se exige tambien motivo_baja NO VACIO, no solo
  -- NOT NULL: con motivo_baja NULL-able el servicio podia grabar '' o '   ' y la
  -- constraint pasaba igual, dejando exactamente el agujero que el COMMENT de la
  -- columna dice querer cerrar (un consumo que baja sin explicacion). TRIM() en
  -- CHECK es determinista y esta permitido.
  CONSTRAINT `chk_ap_val_man_baja`
    CHECK (`activo` = 1
           OR (`fecha_baja` IS NOT NULL
               AND `motivo_baja` IS NOT NULL
               AND TRIM(`motivo_baja`) <> ''))

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='AP: valores cargados a mano que entran al consumo del siniestro (medicacion con detalle y precio consultado, y prestaciones no convenidas por presupuesto).';


-- ================================================================================
-- VERIFICACION (read-only, EJECUTABLE -- correr despues de aplicar)
-- Estas migraciones se aplican A MANO: la verificacion es el unico control de que
-- el DDL quedo como se penso, asi que va sin comentar. Todo es SELECT / EXPLAIN,
-- no muta nada.
-- ================================================================================

-- 1) La tabla existe con el engine y la collation esperados.
SELECT TABLE_NAME, ENGINE, TABLE_COLLATION
  FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_valores_manuales';

-- 2) Columnas y nulabilidad. Chequear en particular que `moneda` sea varchar(3)
--    (no char(3)), para que empareje con cs.polizas_ap_topes y cs.denuncia_poliza.
SELECT ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_valores_manuales'
 ORDER BY ORDINAL_POSITION;

-- 3) Los 3 indices esperados: idx_ap_val_man_denuncia_activo (id_denuncia, activo,
--    computa_consumo, tipo -- EN ESE ORDEN), idx_ap_val_man_ultimo_precio y
--    idx_ap_val_man_erogacion (NON_UNIQUE = 1: la relacion con la erogacion es 1:N).
SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, SUB_PART, NON_UNIQUE
  FROM INFORMATION_SCHEMA.STATISTICS
 WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'ap_valores_manuales'
 ORDER BY INDEX_NAME, SEQ_IN_INDEX;

-- 4) Los 6 CHECK quedaron declarados (tipo, medicacion, no_convenida,
--    monto_no_negativo, no_doble_conteo, baja). Si devuelve menos de 6, faltan.
SELECT CONSTRAINT_NAME, CHECK_CLAUSE
  FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA = 'cs' AND TABLE_NAME = 'ap_valores_manuales'
 ORDER BY CONSTRAINT_NAME;

-- 5) Plan del acceso dominante (consumo por siniestro): tiene que usar
--    idx_ap_val_man_denuncia_activo y NO decir "Using temporary" ni "Using filesort".
EXPLAIN SELECT `tipo`, SUM(`monto`)
          FROM `cs`.`ap_valores_manuales`
         WHERE `id_denuncia` = 1
           AND `activo` = 1
           AND `computa_consumo` = 1
         GROUP BY `tipo`;

-- 6) Plan del "ultimo precio conocido de un medicamento" (el requisito funcional de
--    sugerir el precio anterior al volver a cargar): tiene que usar
--    idx_ap_val_man_ultimo_precio y NO decir "Using filesort".
EXPLAIN SELECT `precio_unitario`, `fuente_precio`, `fecha_precio`
          FROM `cs`.`ap_valores_manuales`
         WHERE `tipo` = 'MEDICACION'
           AND `descripcion` = 'IBUPROFENO 600 MG X 20'
           AND `activo` = 1
         ORDER BY `fecha_precio` DESC, `id_valor_manual` DESC
         LIMIT 1;

-- 7) Ninguna fila viola las dos reglas nuevas (esperado: 0 y 0 en tabla nueva; si
--    la tabla ya tenia datos de una version previa del DDL, hay que corregirlos
--    antes de que los CHECK entren en vigencia).
SELECT
  (SELECT COUNT(*) FROM `cs`.`ap_valores_manuales`
    WHERE `id_erogacion` IS NOT NULL AND `computa_consumo` <> 0)  AS doble_conteo,
  (SELECT COUNT(*) FROM `cs`.`ap_valores_manuales`
    WHERE `activo` = 0
      AND (`fecha_baja` IS NULL
           OR `motivo_baja` IS NULL
           OR TRIM(`motivo_baja`) = ''))                          AS bajas_sin_motivo;

-- ================================================================================
-- ROLLBACK (comentado a proposito -- borra datos cargados por gestion)
-- ================================================================================
-- DROP TABLE IF EXISTS `cs`.`ap_valores_manuales`;

-- =============================================================================
-- V35 - ALTER TABLE `cs`.`polizas_ap` — TOPE GENERAL de la póliza
-- =============================================================================
-- Fecha: 2026-08-10
-- Repo destino: wsmesacarga  →  src/main/resources/sql/V35__ALTER_polizas_ap_ADD_suma_asegurada.sql
--               (convención LOCAL de este repo: `V<N>__<DESCRIPCION>.sql`, sin
--                subcarpeta `migrations/`. Último número tomado por este change: V34.)
-- Change OpenSpec: `ap-costos-topeo-etapa1` (AP Costos y Topeo, etapa 1)
-- Ticket Jira: PENDIENTE — todavía no existe el ticket. Al crearlo, reemplazar este
--              placeholder por el GRV-NNNN acá y en V32/V33/V34.
--
-- ⚠ COLISIÓN DE NUMERACIÓN — LEER ANTES DE COMMITEAR ESTE ARCHIVO EN EL REPO
-- El repo `wsmesacarga` ya tiene un `V32__FIX_predicado_sargable_patologia_trazadora.sql`
-- (commit 34e2f2e, 2026-08-07, change **DE-01-intake**), o sea que el V32 de ESTE change
-- (`V32__CREATE_polizas_ap_topes.sql`) choca por número con uno ajeno. V35 está libre en
-- el repo (el máximo real es V32), pero si se decide renumerar los archivos de AP para
-- resolver la colisión, este archivo se mueve con ellos. No renumerar acá por iniciativa
-- propia: es una decisión que afecta a los cuatro archivos y a lo ya aplicado en dev/stage.
--
-- POR QUÉ (no el qué)
-- Decisión de negocio del 10/08/2026. En la reunión, Verónica lo dijo así: «aseguro a
-- todos mis empleados por cinco millones, A CADA UNO». O sea que el monto asegurado es
-- **el mismo para todos los asegurados de la póliza**, y se aplica **individualmente** a
-- cada uno (no es una bolsa compartida que se agota entre todos).
--
-- Hasta ahora el único lugar donde vivía un tope era `cs`.`polizas_ap_topes` (V32), con
-- grano (póliza, documento, ventana): una fila POR ASEGURADO. Modelar el caso normal ahí
-- obligaría a que negocio cargue una fila por cada empleado de cada póliza para repetir
-- **el mismo número**. Eso es, en la práctica, la planilla que este cambio viene a
-- eliminar: nadie la va a mantener, va a quedar incompleta, y cada asegurado sin fila
-- quedaría en `SIN_TOPE` sin que eso signifique nada real (el tope existe, está en el
-- contrato, sólo que nadie lo transcribió).
--
-- Por eso el modelo queda en DOS NIVELES:
--   1. **TOPE GENERAL** = `polizas_ap.suma_asegurada` (esta migración). Se carga UNA vez,
--      en la pantalla de la póliza, y aplica a CADA asegurado de esa póliza.
--   2. **EXCEPCIONES** = `polizas_ap_topes` (V32), sólo para los asegurados cuyo tope se
--      APARTA del general (gerencia con suma mayor, ampliación puntual). Con historial y
--      motivo (V33), porque apartarse del contrato general es justamente lo que hay que
--      poder justificar después.
--
-- La resolución es EN VIVO, en el motor de `wsaccidentespersonales`:
--     excepción por (id_poliza, nro_doc, ventana)  →  si no hay, TOPE GENERAL de la póliza
-- Las seis columnas de `denuncia_poliza` que agregó V34 quedan como **CACHE OPCIONAL**: el
-- motor NO depende de ellas. Consecuencia buscada: cargar o corregir un tope se refleja al
-- instante, sin backfill, sin tocar `wsdocumento` (dueño de `denuncia_poliza`) y sin
-- escribir dentro de un GET.
--
-- POR QUÉ `suma_asegurada` VA **NULL-ABLE** AUNQUE EL ALTA LA EXIJA
-- La obligatoriedad es del **ALTA NUEVA** (validación de aplicación, en la misma
-- transacción de `PolizaApServiceImpl.crearPoliza`), **no de la columna**. Hay pólizas ya
-- cargadas sin tope: 30 en stage, 12 en dev (medición del 10/08/2026). Poner la columna
-- NOT NULL deja dos salidas y las dos son peores:
--   (a) NOT NULL sin DEFAULT → el ALTER **falla** sobre una tabla con filas, o MariaDB
--       inventa el default implícito del tipo (0.00) según el sql_mode. Un tope 0.00 es el
--       peor dato posible: hace que **todos** los siniestros de esa póliza arranquen
--       «Excedido» (es el mismo riesgo que V32 cubre con `ck_polizas_ap_topes_suma_positiva`).
--   (b) NOT NULL DEFAULT <algo> → las 30 pólizas quedan con un número que **nadie pactó**,
--       indistinguible de un tope real cargado por negocio. Se pierde para siempre la
--       pregunta «¿a esta póliza le falta el tope?».
-- Con NULL, «falta el tope» es un estado EXPLÍCITO y consultable: es lo que alimenta el
-- estado `SIN_TOPE` del semáforo (que NO es 0 %, y la pantalla lo distingue) y la query de
-- control del bloque 4, que es la lista que negocio tiene que llevar a cero.
--
-- POR QUÉ LAS OTRAS TRES **SÍ** VAN NOT NULL CON DEFAULT
-- `suma_asegurada` es el DATO (lo que se pactó, y puede no estar). `ventana`,
-- `iva_incluido` y `moneda` son la **REGLA DE LECTURA** de ese dato, y la regla tiene un
-- default correcto, verificable y único hoy: ANUAL, con IVA, en pesos. Un default acá no
-- inventa un acuerdo comercial: fija la interpretación vigente, y queda lista para cuando
-- se cargue el monto.
--
-- ⚠ ESTO PARECE CONTRADECIR A V34, Y NO LA CONTRADICE — no "prolijar" ninguno de los dos
-- En V34 las mismas `ventana` e `iva_incluido` se declararon **NULL-ables a propósito**,
-- con este argumento escrito: «un ANUAL por default mentiría sobre un tope que nadie
-- resolvió». Sigue siendo cierto **ahí**, porque en `denuncia_poliza` esas columnas son el
-- CACHE del resultado de una resolución: si la resolución no ocurrió, no hay nada que
-- copiar y NULL es la única respuesta honesta.
-- Acá son otra cosa: son la DECLARACIÓN de la póliza, no la copia de un cálculo. La póliza
-- se lee en ventana anual y con IVA aunque todavía no le hayan cargado el monto. Misma
-- columna, distinto significado según la tabla. Si alguien alinea las dos "por
-- consistencia", rompe una de las dos.
--
-- POR QUÉ `moneda` Y `ventana` SE DECLARAN utf8mb4 EN UNA TABLA latin1
-- `cs`.`polizas_ap` es **latin1_swedish_ci** (y así se deja: `nro_doc` de `afiliados` y de
-- `polizas_ap_topes` también lo son, a propósito — ver V32). Sin `CHARACTER SET` explícito,
-- estas dos columnas heredarían latin1, mientras que sus contrapartes en
-- `polizas_ap_topes` son **utf8mb4_unicode_ci**. El motor las va a mezclar en el mismo
-- expression: `COALESCE(excepcion.ventana, general.ventana)`.
-- Se verificó en dev (MariaDB 10.5.29) que esa mezcla **no** da «Illegal mix of
-- collations»: MariaDB coerciona latin1 → utf8mb4 en `COALESCE`, `CASE` y `=`. Así que
-- esto NO es un bug que se esté evitando; es simetría deliberada, por dos razones:
--   - la coerción implícita es la que **anula el uso de índice** cuando el lado convertido
--     es el indexado (exactamente la trampa que V32 documenta para `nro_doc`), y no
--     conviene dejarla latente en las columnas que el motor va a comparar en cada consulta;
--   - un `COALESCE` entre dos columnas del MISMO dominio que resuelven con reglas de
--     comparación distintas es una diferencia invisible en el código y molesta de
--     diagnosticar.
-- Regla general del cambio, para no leerlo como incoherente con V32: **cada columna toma
-- el charset de aquello contra lo que se la va a comparar.** `nro_doc` se declara latin1
-- porque se joinea contra `afiliados` (latin1); `ventana` y `moneda` se declaran utf8mb4
-- porque se resuelven contra `polizas_ap_topes` (utf8mb4).
--
-- ALCANCE
-- Cuatro columnas nuevas + un CHECK. Todo aditivo: no modifica ni borra datos existentes.
-- **No hay backfill y no debe haberlo**: el tope general es un dato de negocio que sale
-- del contrato de cada póliza. Lo carga negocio, póliza por póliza, por pantalla. Cualquier
-- UPDATE masivo acá sería inventar sumas aseguradas.
--
-- REQUISITOS
-- - MariaDB 10.0+ (`ADD COLUMN IF NOT EXISTS`). Verificado sobre 10.5.29.
-- - Independiente de V32/V33/V34: este ALTER se puede aplicar solo. La query de control
--   del bloque 4 **sí** lee `polizas_ap_topes` (V32) y `denuncia_poliza`.
--
-- NO SE DECLARAN FOREIGN KEYS
-- Criterio del ecosistema (ver V32/V34): no hay FKs en ninguna parte. No aplica acá de
-- todos modos: las cuatro columnas son escalares.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. DDL — tope general de la póliza
-- -----------------------------------------------------------------------------
-- Las cuatro columnas se agregan AL FINAL (sin `AFTER`) a propósito: es la única forma de
-- que InnoDB pueda usar ALGORITHM=INSTANT. Con 30 filas el tiempo da igual, pero deja el
-- patrón correcto. No se fuerza `ALGORITHM=INSTANT` explícito porque haría fallar el
-- script entero en un motor que no lo soporte, y el fallback (COPY de 30 filas) es
-- inofensivo.
--
-- `suma_asegurada` es DECIMAL(16,2), igual que `polizas_ap_topes.suma_asegurada` y que
-- `denuncia_poliza.suma_asegurada`. Nunca FLOAT/DOUBLE: es dinero y se compara contra
-- acumulados de `erogaciones`. Del lado Java, BigDecimal, `compareTo` (no `equals`) y
-- `setScale(2, HALF_UP)`.

ALTER TABLE `cs`.`polizas_ap`
  ADD COLUMN IF NOT EXISTS `suma_asegurada` DECIMAL(16,2) NULL
      COMMENT 'TOPE GENERAL de la poliza, CON IVA incluido. Aplica a CADA asegurado individualmente (no es una bolsa compartida). Las excepciones por asegurado van en polizas_ap_topes y tienen prioridad. NULL = tope no cargado todavia: estado SIN_TOPE en el semaforo, NO 0%. Obligatorio en el alta nueva por validacion de aplicacion, NULL-able en la columna por las polizas preexistentes. DECIMAL, nunca float.',
  ADD COLUMN IF NOT EXISTS `iva_incluido` TINYINT(1) NOT NULL DEFAULT 1
      COMMENT 'Regla de lectura del monto: 1 = suma_asegurada ya incluye IVA. Criterio vigente: el tope se carga CON IVA. Evita comparar un consumo neto contra un tope con IVA (21% de error silencioso en el % del semaforo).',
  ADD COLUMN IF NOT EXISTS `moneda` VARCHAR(3)
      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      NOT NULL DEFAULT 'ARS'
      COMMENT 'ISO-4217 del tope general. Default ARS: hoy el 100% de la cartera AP esta en pesos. utf8mb4 explicito para espejar polizas_ap_topes.moneda (la tabla es latin1).',
  ADD COLUMN IF NOT EXISTS `ventana` VARCHAR(10)
      CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
      NOT NULL DEFAULT 'ANUAL'
      COMMENT 'Ventana de acumulacion del tope general: ANUAL | EVENTO | POLIZA. Define SOBRE QUE RANGO el motor acumula el consumo; el mismo importe topea distinto por anio calendario que por evento. Default ANUAL = criterio vigente de negocio, igual que polizas_ap_topes.ventana. utf8mb4 explicito para espejar esa columna.';

-- OJO con las tres NOT NULL: las pólizas preexistentes (30 en stage, 12 en dev) quedan en
-- iva_incluido = 1 / moneda = 'ARS' / ventana = 'ANUAL' **sin pasar por ningún proceso**.
-- Es correcto hoy y es el punto: cuando negocio cargue el monto, la regla de lectura ya
-- está bien puesta. Si alguna vez entra una póliza en USD o con ventana por EVENTO, la
-- pantalla del alta tiene que dejar elegirlas — no alcanza con cargar el monto.
--
-- No se agrega CHECK sobre `moneda` ni sobre `ventana`: mismo criterio que V32/V34. Un
-- CHECK de dominio sobre una tabla existente no aporta contra un dato que el servicio ya
-- valida contra catálogo, y cada valor nuevo (una moneda más, una ventana más) obligaría a
-- una migración para poder cargarlo.


-- -----------------------------------------------------------------------------
-- 2. CHECK de suma positiva — **NO es idempotente. Leer antes de correr.**
-- -----------------------------------------------------------------------------
-- POR QUÉ existe: un tope 0 o negativo no rompe nada, hace algo peor — pone **todos** los
-- siniestros de la póliza en «Excedido» y el número parece calculado. Es el mismo riesgo
-- que V32 cubre en `polizas_ap_topes` con `ck_polizas_ap_topes_suma_positiva`; sin este
-- CHECK, el tope general sería el único de los tres lugares sin piso.
--
-- POR QUÉ se escribe `IS NULL OR > 0` pudiendo escribir sólo `> 0`: son equivalentes
-- (`NULL > 0` es UNKNOWN y un CHECK sólo falla con FALSE, así que las 30 filas con NULL
-- pasan igual), pero la forma larga deja escrito que el NULL está PERMITIDO A PROPÓSITO.
-- Sin eso, el próximo que lea el CHECK va a creer que el NULL se colaba por un descuido.
--
-- ⚠ MariaDB 10.5 **no tiene** `ADD CONSTRAINT IF NOT EXISTS`. En una SEGUNDA corrida de
-- este script, el statement de abajo falla con
--     ERROR 1826: Duplicate CHECK constraint name 'ck_polizas_ap_suma_positiva'
-- (verificado re-corriendo el script completo en dev el 10/08/2026). Ese error es el
-- resultado ESPERADO de re-correr y **no deja nada a medias**: el CHECK ya estaba y los
-- datos no se tocan. El resto del script sí es idempotente (`ADD COLUMN IF NOT EXISTS`
-- sale con warning y sigue). Para saber de antemano cuál de los dos casos es, correr
-- primero el pre-chequeo:
--
-- Comportamiento del CHECK, verificado en dev (UPDATE dentro de una transacción con
-- ROLLBACK, sin dejar datos): rechaza `0` y `-5.00` con
--     ERROR 4025: CONSTRAINT `ck_polizas_ap_suma_positiva` failed for `cs`.`polizas_ap`
-- y acepta `5000000.00` y `NULL`. O sea que cubre lo que tiene que cubrir sin estorbar a
-- las pólizas que todavía no tienen tope.

-- 2.A Pre-chequeo. 0 = el CHECK no existe (correr el 2.B) · 1 = ya está (saltear el 2.B).
SELECT COUNT(*) AS check_ya_existe
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap'
   AND `CONSTRAINT_NAME`   = 'ck_polizas_ap_suma_positiva';

-- 2.B El CHECK. Saltear si el 2.A devolvió 1.
ALTER TABLE `cs`.`polizas_ap`
  ADD CONSTRAINT `ck_polizas_ap_suma_positiva`
      CHECK (`suma_asegurada` IS NULL OR `suma_asegurada` > 0);


-- -----------------------------------------------------------------------------
-- 3. ÍNDICES — decisión: NO se crea ninguno. Justificación.
-- -----------------------------------------------------------------------------
-- `cs`.`polizas_ap` tiene 30 filas en stage y 12 en dev (10/08/2026). La tabla entera entra
-- en una página de InnoDB: cualquier índice sobre `suma_asegurada` sería IGNORADO por el
-- optimizador (un full scan de 30 filas cuesta menos que el doble salto índice→PK).
--
-- Y el motor no filtra por estas columnas: llega a la póliza por `id_poliza` (PK, vía
-- `denuncia_poliza`) y LEE la suma de la fila que ya trajo. La query de control del bloque 4
-- sí filtra por `suma_asegurada IS NULL`, pero es un reporte de gestión que se corre a mano
-- sobre 30 filas.
--
-- CREAR un índice CUANDO se cumplan las dos condiciones (para no re-razonarlo):
--   (a) la tabla pase las ~50.000 pólizas (hoy: 30 → falta un factor 1.600), y
--   (b) exista una consulta en CALIENTE (no un reporte a mano) que filtre por el tope.


-- -----------------------------------------------------------------------------
-- 4. QUERY DE CONTROL (read-only) — pólizas AP sin tope general
-- -----------------------------------------------------------------------------
-- Esta es la lista que NEGOCIO tiene que llevar a cero, y el motivo por el que
-- `suma_asegurada` es NULL-able: sin NULL, esta consulta no se podría escribir.
--
-- La urgencia NO es la misma para todas, y por eso se separan. Una póliza sin tope general
-- pero SIN siniestros no le da un dato malo a nadie hoy; una CON siniestros activos tiene
-- casos que el semáforo no puede evaluar en este momento.
--
-- ⚠ LA EXCEPCIÓN TAPA LA FALTA DEL GENERAL — no contar de más
-- Un asegurado con excepción en `polizas_ap_topes` resuelve su tope **sin** el general
-- (la excepción tiene prioridad). O sea que una póliza sin tope general puede tener parte
-- de sus siniestros perfectamente resueltos. Contar «denuncias activas» a secas
-- sobreestima el problema. Lo que se cuenta como bloqueado es la denuncia cuyo asegurado
-- **no** tiene excepción propia: ésa es la que queda en SIN_TOPE de verdad.
--
-- Requiere V32 aplicada (lee `polizas_ap_topes`). Sin V32 falla con «table doesn't exist»:
-- en ese caso, sacar el LEFT JOIN a topes y leer todas las denuncias activas como
-- bloqueadas, que es la foto correcta cuando no hay excepciones posibles.

-- 4.A Resumen por prioridad. Es el tablero de regularización.
--     `activo` no existe en `polizas_ap` (la tabla no tiene baja lógica), así que se usa
--     `fecha_hasta` para separar la cartera viva de la histórica.
SELECT CASE
         WHEN COALESCE(dn.`denuncias_bloqueadas`, 0) > 0                   THEN '1_URGENTE — con siniestros que hoy quedan SIN_TOPE'
         WHEN COALESCE(dn.`denuncias_activas`, 0)   > 0                    THEN '2_CUBIERTA_POR_EXCEPCIONES — siniestros resueltos sin el general'
         WHEN p.`fecha_hasta` IS NULL OR p.`fecha_hasta` >= CURDATE()      THEN '3_VIGENTE_SIN_SINIESTROS — cargar antes del primer caso'
         ELSE                                                                   '4_HISTORICA — vencida y sin siniestros, no urge'
       END                                          AS prioridad,
       COUNT(*)                                     AS polizas,
       SUM(COALESCE(dn.`denuncias_activas`, 0))     AS denuncias_activas,
       SUM(COALESCE(dn.`denuncias_bloqueadas`, 0))  AS denuncias_sin_tope
  FROM `cs`.`polizas_ap` p
  LEFT JOIN (
        SELECT dp.`id_poliza`,
               COUNT(*)                                        AS denuncias_activas,
               SUM(CASE WHEN t.`id_tope` IS NULL THEN 1 ELSE 0 END) AS denuncias_bloqueadas
          FROM `cs`.`denuncia_poliza` dp
          JOIN      `cs`.`denuncias` d ON d.`id_denuncia` = dp.`id_denuncia`
          LEFT JOIN `cs`.`afiliados` a ON a.`id_afiliado` = d.`id_afiliado`
          -- Excepción del asegurado. Se joinea por (id_poliza, nro_doc) SIN `tipo_doc`:
          -- `polizas_ap_topes.tipo_doc` es NULL-able y NULL es el caso NORMAL (la nómina AP
          -- llega con el número y sin el tipo — V32, nota 2). Con `t.tipo_doc = a.tipo_doc`
          -- este LEFT JOIN no matchearía NINGUNA excepción y el reporte contaría como
          -- bloqueadas denuncias que están resueltas. Misma trampa que documenta V34.
          LEFT JOIN `cs`.`polizas_ap_topes` t
                 ON  t.`id_poliza` = dp.`id_poliza`
                 AND t.`nro_doc`   = a.`nro_doc`
                 AND t.`activo`    = 1
         WHERE dp.`activo` = 1
         GROUP BY dp.`id_poliza`
       ) dn ON dn.`id_poliza` = p.`id_poliza`
 WHERE p.`suma_asegurada` IS NULL
 GROUP BY prioridad
 ORDER BY prioridad;
-- Baseline medido el 10/08/2026, inmediatamente después del ALTER (todas en NULL):
--   STAGE — 30 pólizas sin tope general:
--     1_URGENTE                       7 pólizas · 61 denuncias activas · 54 sin tope
--     3_VIGENTE_SIN_SINIESTROS        5 pólizas
--     4_HISTORICA                    18 pólizas
--   DEV   — 12 pólizas sin tope general:
--     1_URGENTE                       4 pólizas · 12 denuncias activas · 12 sin tope
--     4_HISTORICA                     8 pólizas  (en dev las 12 pólizas están vencidas)
--   Nota de lectura de stage: de las 11 pólizas vigentes, 6 tienen siniestros (caen en
--   1_URGENTE) y 5 no; la séptima urgente (id 28, poliza 17885) está vencida pero tiene
--   3 siniestros activos, así que urge igual. La vigencia ordena la prioridad, no la
--   reemplaza: un siniestro abierto sobre una póliza vencida necesita su tope.
--
-- ⚠ EL BASELINE DE STAGE YA NO SE REPRODUCE — es correcto, no es un bug de la consulta.
-- Unos minutos después de aplicar V35 se cargaron en stage **4 topes generales de prueba**
-- (pólizas 28 = 200.000, 45 = 500.000, 46 = 5.000.000 —el caso de Verónica—, 52 = 70.000),
-- así que la misma consulta hoy devuelve:
--     1_URGENTE                       3 pólizas · 4 denuncias activas · 4 sin tope
--     3_VIGENTE_SIN_SINIESTROS        5 pólizas
--     4_HISTORICA                    18 pólizas
--     (26 pólizas sin tope general en total, no 30)
-- Los dos números están bien: 30/54 es la foto **al aplicar** (la que reproduce un ambiente
-- limpio, y la que va a dar producción) y 26/4 es la foto **después de cargar 4 topes**. Si
-- se está validando el script en stage, comparar contra la segunda; en dev el baseline
-- original sigue intacto (12/12).
-- Corolario operativo, visible en este movimiento: cargar UN tope general resolvió de una
-- sola vez las 51 denuncias de la póliza 46 que estaban en SIN_TOPE (54 → 4). Es exactamente
-- lo que el modelo de dos niveles viene a lograr, y lo que 51 excepciones por asegurado
-- habrían hecho a mano.
-- Las 7 excepciones cargadas en stage son DATOS DE PRUEBA de este change (marcadas
-- 'DATO DE PRUEBA ap-costos-topeo-etapa1' en polizas_ap_topes_historial.motivo) y por eso
-- 61 − 54 = 7 denuncias figuran resueltas sin general. En producción, al aplicar V35,
-- `polizas_ap_topes` está vacía: TODAS las denuncias activas cuentan como bloqueadas.

-- 4.B Detalle accionable: una fila por póliza a regularizar, con lo que negocio necesita
--     para ir a buscar el contrato (número de póliza, razón social, CUIT, vigencia).
SELECT CASE
         WHEN COALESCE(dn.`denuncias_bloqueadas`, 0) > 0              THEN '1_URGENTE'
         WHEN COALESCE(dn.`denuncias_activas`, 0)   > 0               THEN '2_CUBIERTA_POR_EXCEPCIONES'
         WHEN p.`fecha_hasta` IS NULL OR p.`fecha_hasta` >= CURDATE() THEN '3_VIGENTE_SIN_SINIESTROS'
         ELSE                                                              '4_HISTORICA'
       END                                          AS prioridad,
       p.`id_poliza`,
       p.`poliza`,
       p.`razon_social`,
       p.`cuit`,
       p.`fecha_desde`,
       p.`fecha_hasta`,
       CASE WHEN p.`fecha_hasta` IS NULL OR p.`fecha_hasta` >= CURDATE()
            THEN 'VIGENTE' ELSE 'VENCIDA' END       AS vigencia,
       COALESCE(dn.`denuncias_activas`, 0)          AS denuncias_activas,
       COALESCE(dn.`denuncias_bloqueadas`, 0)       AS denuncias_sin_tope,
       COALESCE(ex.`excepciones_activas`, 0)        AS excepciones_cargadas,
       CASE
         WHEN COALESCE(dn.`denuncias_bloqueadas`, 0) > 0
           THEN CONCAT('Cargar el tope general: hay ', dn.`denuncias_bloqueadas`,
                       ' siniestro(s) que el semaforo no puede evaluar')
         WHEN COALESCE(dn.`denuncias_activas`, 0) > 0
           THEN 'Sus siniestros se resuelven por excepcion, pero falta el general para los proximos'
         WHEN p.`fecha_hasta` IS NULL OR p.`fecha_hasta` >= CURDATE()
           THEN 'Poliza vigente sin siniestros: cargar el tope antes del primer caso'
         ELSE 'Poliza vencida y sin siniestros: confirmar con gestion si corresponde cargarla'
       END                                          AS que_falta
  FROM `cs`.`polizas_ap` p
  LEFT JOIN (
        SELECT dp.`id_poliza`,
               COUNT(*)                                        AS denuncias_activas,
               SUM(CASE WHEN t.`id_tope` IS NULL THEN 1 ELSE 0 END) AS denuncias_bloqueadas
          FROM `cs`.`denuncia_poliza` dp
          JOIN      `cs`.`denuncias` d ON d.`id_denuncia` = dp.`id_denuncia`
          LEFT JOIN `cs`.`afiliados` a ON a.`id_afiliado` = d.`id_afiliado`
          LEFT JOIN `cs`.`polizas_ap_topes` t
                 ON  t.`id_poliza` = dp.`id_poliza`
                 AND t.`nro_doc`   = a.`nro_doc`
                 AND t.`activo`    = 1
         WHERE dp.`activo` = 1
         GROUP BY dp.`id_poliza`
       ) dn ON dn.`id_poliza` = p.`id_poliza`
  LEFT JOIN (
        SELECT `id_poliza`, COUNT(*) AS `excepciones_activas`
          FROM `cs`.`polizas_ap_topes`
         WHERE `activo` = 1
         GROUP BY `id_poliza`
       ) ex ON ex.`id_poliza` = p.`id_poliza`
 WHERE p.`suma_asegurada` IS NULL
 ORDER BY prioridad, `denuncias_sin_tope` DESC, p.`id_poliza`;

-- 4.C Contracara: excepciones que NO se apartan de nada porque su póliza no tiene general.
--     Hoy funcionan (la excepción resuelve sola), pero son la señal de que se está usando
--     el nivel 2 para hacer el trabajo del nivel 1 — o sea, volviendo a la planilla por
--     asegurado que este modelo vino a eliminar. Debería tender a 0.
SELECT p.`id_poliza`, p.`poliza`, p.`razon_social`,
       COUNT(*) AS excepciones_activas
  FROM `cs`.`polizas_ap_topes` t
  JOIN `cs`.`polizas_ap` p ON p.`id_poliza` = t.`id_poliza`
 WHERE t.`activo` = 1
   AND p.`suma_asegurada` IS NULL
 GROUP BY p.`id_poliza`
 ORDER BY `excepciones_activas` DESC;


-- -----------------------------------------------------------------------------
-- 5. VERIFICACIÓN del DDL (read-only) — correr después del ALTER
-- -----------------------------------------------------------------------------
-- Debe devolver exactamente 4 filas:
--   suma_asegurada  decimal(16,2) | YES | NULL   | (sin collation)
--   iva_incluido    tinyint(1)    | NO  | 1      | (sin collation)
--   moneda          varchar(3)    | NO  | 'ARS'  | utf8mb4 / utf8mb4_unicode_ci
--   ventana         varchar(10)   | NO  | 'ANUAL'| utf8mb4 / utf8mb4_unicode_ci
-- Si `moneda` o `ventana` salen en latin1_swedish_ci, la columna se creó SIN el
-- `CHARACTER SET` explícito (heredó el de la tabla): ver el razonamiento del banner y
-- corregir con el ALTER de remediación 5.C antes de que el motor las use.
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `IS_NULLABLE`, `COLUMN_DEFAULT`,
       `CHARACTER_SET_NAME`, `COLLATION_NAME`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap'
   AND `COLUMN_NAME` IN ('suma_asegurada', 'iva_incluido', 'moneda', 'ventana')
 ORDER BY `ORDINAL_POSITION`;

-- 5.A El CHECK quedó. Debe devolver 1 fila con CHECK_CLAUSE sobre `suma_asegurada`.
SELECT `CONSTRAINT_NAME`, `CHECK_CLAUSE`
  FROM `INFORMATION_SCHEMA`.`CHECK_CONSTRAINTS`
 WHERE `CONSTRAINT_SCHEMA` = 'cs'
   AND `TABLE_NAME`        = 'polizas_ap';

-- 5.B Estado de los datos. Las pólizas preexistentes deben quedar TODAS con
--     suma_asegurada NULL (el ALTER no inventa topes) y con la regla de lectura por
--     default. `con_tope` sólo crece cuando negocio carga: si da > 0 recién aplicado,
--     alguien escribió un monto que no salió de la pantalla.
SELECT COUNT(*)                             AS total_polizas,
       SUM(`suma_asegurada` IS NULL)        AS sin_tope_general,
       SUM(`suma_asegurada` IS NOT NULL)    AS con_tope,
       SUM(`iva_incluido` = 1)              AS con_iva,
       SUM(`moneda`  = 'ARS')               AS en_pesos,
       SUM(`ventana` = 'ANUAL')             AS ventana_anual,
       MIN(`suma_asegurada`)                AS tope_minimo,
       MAX(`suma_asegurada`)                AS tope_maximo
  FROM `cs`.`polizas_ap`;
-- Baseline esperado inmediatamente después del ALTER (10/08/2026):
--   STAGE: total 30 · sin_tope_general 30 · con_tope 0 · con_iva 30 · en_pesos 30 · ventana_anual 30
--   DEV:   total 12 · sin_tope_general 12 · con_tope 0 · con_iva 12 · en_pesos 12 · ventana_anual 12

-- 5.C REMEDIACIÓN (comentada) — sólo si la verificación de arriba mostró `moneda` o
--     `ventana` en latin1. Con 30 filas el MODIFY es instantáneo. No correr a ciegas.
-- ALTER TABLE `cs`.`polizas_ap`
--   MODIFY COLUMN `moneda`  VARCHAR(3)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ARS',
--   MODIFY COLUMN `ventana` VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'ANUAL';

-- 5.D La prueba que no miente: ejecuta la resolución REAL (excepción → general) tal como la
--     va a armar el motor, incluidos los `COALESCE` que mezclan las columnas nuevas con las
--     de `polizas_ap_topes`. Lo que se prueba es que COMPILE (que ningún `COALESCE` dé
--     «Illegal mix of collations») y que los conteos cierren. Requiere V32.
--     `t.ventana = p.ventana` es la semántica real: la excepción aplica sobre la MISMA
--     ventana que declara la póliza; una excepción cargada en otra ventana no la reemplaza.
SELECT COUNT(*)                                                       AS resoluciones,
       SUM(t.`id_tope` IS NOT NULL)                                   AS por_excepcion,
       SUM(t.`id_tope` IS NULL AND p.`suma_asegurada` IS NOT NULL)     AS por_tope_general,
       SUM(COALESCE(t.`suma_asegurada`, p.`suma_asegurada`) IS NULL)   AS quedan_sin_tope,
       COUNT(DISTINCT COALESCE(t.`ventana`, p.`ventana`))             AS ventanas_distintas,
       COUNT(DISTINCT COALESCE(t.`moneda`,  p.`moneda`))              AS monedas_distintas
  FROM `cs`.`denuncia_poliza` dp
  JOIN      `cs`.`polizas_ap` p ON p.`id_poliza`   = dp.`id_poliza`
  JOIN      `cs`.`denuncias`  d ON d.`id_denuncia` = dp.`id_denuncia`
  LEFT JOIN `cs`.`afiliados`  a ON a.`id_afiliado` = d.`id_afiliado`
  LEFT JOIN `cs`.`polizas_ap_topes` t
         ON  t.`id_poliza` = dp.`id_poliza`
         AND t.`nro_doc`   = a.`nro_doc`
         AND t.`activo`    = 1
         AND t.`ventana`   = p.`ventana`
 WHERE dp.`activo` = 1;
-- Baseline 10/08/2026 (recién aplicado, sin topes generales cargados):
--   STAGE: resoluciones 61 · por_excepcion 7 · por_tope_general 0 · quedan_sin_tope 54
--   DEV:   resoluciones 12 · por_excepcion 0 · por_tope_general 0 · quedan_sin_tope 12


-- -----------------------------------------------------------------------------
-- 6. ROLLBACK (comentado)
-- -----------------------------------------------------------------------------
-- Es un DROP de lo AGREGADO por este script: no hay pérdida de datos preexistentes.
-- ⚠ SÍ se pierden los topes generales que negocio haya cargado, y **no se reconstruyen
-- solos**: no existen en ningún otro lado (las excepciones de `polizas_ap_topes` son otro
-- dato, no una copia). Después de la primera carga, respaldar ANTES de revertir:
--
-- CREATE TABLE `cs`.`polizas_ap_respaldo_v35` AS
--   SELECT `id_poliza`, `poliza`, `suma_asegurada`, `iva_incluido`, `moneda`, `ventana`
--     FROM `cs`.`polizas_ap`;
--
-- El CHECK se dropea PRIMERO: dropear la columna con el CHECK vivo encima falla.
-- ALTER TABLE `cs`.`polizas_ap` DROP CONSTRAINT IF EXISTS `ck_polizas_ap_suma_positiva`;
--
-- ALTER TABLE `cs`.`polizas_ap`
--   DROP COLUMN IF EXISTS `ventana`,
--   DROP COLUMN IF EXISTS `moneda`,
--   DROP COLUMN IF EXISTS `iva_incluido`,
--   DROP COLUMN IF EXISTS `suma_asegurada`;
-- =============================================================================

-- =====================================================================
-- AP — Costos y Topeo · MOTOR DE CONSUMO
-- =====================================================================
-- Qué es esto: la consulta que, para una denuncia de Accidentes Personales
-- (o para un lote), devuelve el consumo separado en los 3 ESTADOS DE
-- CONFIANZA del modelo, la PROYECCIÓN y el estado del semáforo.
--
--   FACTURADO = ya impactó en factura auditada.  Fuente ÚNICA: cs.erogaciones.
--   DEVENGADO = prestación YA REALIZADA sin factura todavía.
--   ESTIMADO  = autorizado y NO realizado.
--   PROYECCIÓN = FACTURADO + DEVENGADO + ESTIMADO  (la cifra de vigilancia).
--
-- El semáforo se calcula sobre la PROYECCIÓN. El cierre/débito se decide
-- por el FACTURADO. Sin tope cargado el resultado es SIN_TOPE y NO se
-- calcula porcentaje (un semáforo sin denominador engaña).
--
-- TODO READ-ONLY: ninguna sentencia de este archivo escribe.
-- Motor validado contra STAGE el 10/08/2026 (MariaDB 10.5.29). Los números
-- de la validación están al pie, en el bloque V.
--
-- QUIÉN LO IMPLEMENTA: wsaccidentespersonales. La fase siguiente decide si
-- va por @Query nativa (recomendado: son CTEs y agregaciones, no entidades)
-- o por JPQL. Este archivo es el contrato de la lógica, no el código final.
--
-- ---------------------------------------------------------------------
-- ÍNDICE
--   Q1 · MOTOR CANÓNICO — una fila por denuncia AP (sirve para el detalle,
--        para la grilla y para la cartera; sólo cambia el filtro).
--   Q2 · DETALLE POR ÍTEM — las filas que explican cada monto de Q1
--        (es lo que se muestra al abrir el drawer "¿de dónde sale esto?").
--   Q3 · EXPLAIN — verificación de que el filtro por AP entra por índice.
--   V  · VALIDACIÓN contra stage: números reales y casos de prueba.
-- =====================================================================


-- =====================================================================
-- CATÁLOGOS REALES (leídos de stage — NO son números inventados)
-- =====================================================================
-- cs.estados_turnos (26 filas). Los que importan:
--    19 Realizado - Pend. Informe   ← REALIZADO
--    23 Realizado                   ← REALIZADO
--     6 Anulado          ← NO VA A OCURRIR, se excluye del ESTIMADO
--     9 Rechazado        ← NO VA A OCURRIR, se excluye del ESTIMADO
--    24 No Realizado     ← NO VA A OCURRIR, se excluye del ESTIMADO
--    25 Cerrado por Sistema ← NO VA A OCURRIR, se excluye del ESTIMADO
--
--  DECISIÓN DOCUMENTADA — los que quedan DENTRO del ESTIMADO a propósito:
--    0 Confeccionado, 4/5/7 Programados, 10..18 Solicitado/Pendiente,
--    21 Pend. Definición -Paciente Ausente-, 22 Reprogramación Solicitada,
--    26 No Programado.
--    El 21 y el 26 son discutibles (pueden no ocurrir nunca), pero el
--    semáforo es una herramienta de VIGILANCIA: pasarse de prudente es
--    barato, quedarse corto avisa tarde. Si negocio pide sacarlos, se
--    saca 21 y 26 de la lista y nada más cambia.
--
--  OJO con el 20 (Informado): un turno "Informado" está realizado, pero el
--  modelo cerrado define REALIZADO = (19,23) y no se reinterpreta acá.
--  En stage NO existe ningún turno AP en estado 20 (ver bloque V), así que
--  hoy no pierde plata. Si en prod aparecieran turnos 20 con
--  valor_prestacion, hay que llevar la pregunta a negocio.
--
-- cs.estados_traslados_logistica (8 filas):
--    4 REALIZADO, 8 NEGATIVO AUTORIZADO  ← cobran (DEVENGADO)
--    1 SOLICITADO, 2 ASIGNADO, 3 PROGRAMADO ← todavía no (ESTIMADO)
--    5 FALLIDO, 6 CANCELADO, 7 NO COORDINABLE ← no cobran, se excluyen
--
-- cs.tipos_erogaciones (4 filas) — clave para el anti-doble-conteo:
--    1 PEDIDOS_MAT_QX, 2 PEDIDOS_ORTOPEDIA, 3 SIMPLES, 4 MASIVAS
--    Es decir: cuando un material quirúrgico o una ortopedia SE FACTURA,
--    aterriza en cs.erogaciones. Por eso el consolidado de cirugía sólo
--    puede aportar la parte NO facturada. NO hay tipo de erogación para
--    traslados: los traslados se facturan por el circuito de auditoría de
--    facturas (traslados.id_factura_ida), no por erogaciones.
--
-- cs.estados_pedidos_ortopedia:  4 Cancelado, 5 Cerrado por Sistemas ← fuera
-- cs.estados_material_ortopedico: 7 Cancelado ← fuera
-- =====================================================================


-- =====================================================================
-- LA CADENA DE TRASLADOS — RESUELTA (era el riesgo declarado de la tarea)
-- =====================================================================
-- cs.traslados NO tiene id_denuncia. Se probaron las dos vías candidatas
-- contra los datos reales de stage (1.600.289 traslados):
--
--   (A) traslados.id_turno -> turnos.id_turno -> turnos.id_denuncia
--       1.600.281 traslados tienen id_turno; 1.592.366 (99,5%) llegan a
--       una denuncia.  ✔ ES LA CADENA BUENA.
--
--   (B) traslados.id_viaje_autorizado -> autorizaciones_traslados
--       Se probó contra las dos columnas plausibles del destino
--       (id_autorizacion_traslado, que es la PK, e id_viaje_autorizado):
--       de 446.901 traslados con id_viaje_autorizado, MATCHEAN 0 (cero)
--       en ambos casos.  ✘ La columna es residual/legacy, no sirve de FK.
--
-- Por eso el motor entra a traslados por id_turno. Queda igual una
-- ADVERTENCIA HONESTA: en stage el universo AP tiene 0 traslados, así que
-- el bloque de traslados está resuelto estructuralmente pero NO validado
-- con montos AP reales. Antes de darlo por bueno en prod, correr el
-- bloque V6.
--
-- TODO (acotado, no bloqueante): el motor suma sólo (monto - débito) de
-- ida y de vuelta. NO suma peaje_*, espera_*, ni estacionamiento_*, que en
-- traslados son columnas aparte. Para el semáforo la base alcanza; si
-- negocio quiere el costo completo del traslado hay que decidir si esos
-- extras entran (y entonces también entran en el débito).
--
-- NOTA sobre el archivo 00-diagnostico-datos-ap.sql: su bloque D3 usa
-- `tr.id_denuncia`, columna que NO existe. Ese bloque no corre; queda
-- reemplazado por lo de acá.
-- =====================================================================


-- =====================================================================
-- ANTI-DOBLE-CONTEO — las 5 reglas, y por qué cada una
-- =====================================================================
-- R1. El FACTURADO sale SÓLO de cs.erogaciones. Ninguna otra vía puede
--     aportar al FACTURADO, nunca.
-- R2. Un turno aporta (como DEVENGADO o como ESTIMADO) únicamente si
--     valor_facturacion IS NULL. En cuanto tiene valor de facturación, su
--     plata ya está viajando por el circuito de facturas.
-- R3. CIRUGÍA · materiales: el detalle aporta sólo si nro_factura IS NULL.
--     Si tiene número de factura, ese material ya está (o va a estar) en
--     erogaciones con id_tipo_erogacion = 1.
-- R4. CIRUGÍA · ortopedia: el pedido aporta sólo si NO tiene fila en
--     cs.relacion_erogaciones_ortopedia (esa tabla es el vínculo EXACTO
--     erogación ↔ pedido de ortopedia, no hace falta adivinar), y sólo si
--     no está cancelado/cerrado por sistemas.
-- R5. CIRUGÍA · honorarios: el presupuesto valorizado aporta sólo si el
--     turno al que está colgado NO aportó ya por valor_prestacion. Si no,
--     el mismo honorario se contaría dos veces (una por turnos, otra por
--     presupuesto). En stage este solape da 0 filas, pero la guarda queda
--     puesta porque es gratis y en prod puede aparecer.
-- Además: ap_valores_manuales aporta sólo con activo=1 AND
--     computa_consumo=1. El CHECK de la tabla ya garantiza que una fila
--     ligada a una erogación no compute.
-- =====================================================================


-- =====================================================================
-- Q1 · MOTOR CANÓNICO — una fila por denuncia AP
-- =====================================================================
-- Devuelve, por denuncia: los 3 estados de confianza desagregados por vía,
-- la proyección, el tope y el semáforo.
--
-- FILTRO — lo inyecta el servicio sobre el CTE `ap` (marcado abajo):
--   detalle de una denuncia :  AND dp.id_denuncia = :idDenuncia
--   grilla / lote           :  AND dp.id_denuncia IN (:idsDenuncia)
--   cartera completa        :  (sin filtro extra — así corre este archivo)
--
-- =====================================================================
-- EL TOPE SE RESUELVE EN VIVO, ACÁ (cambio del 10/08/2026)
-- =====================================================================
-- Antes el tope salía denormalizado de denuncia_poliza.suma_asegurada, que
-- lo iba a escribir un "resolutor de topes" que NUNCA se implementó: por eso
-- 54 de los 61 siniestros AP de stage daban SIN_TOPE teniendo la póliza
-- cargada. Ahora el motor lo resuelve en la misma consulta, en este orden:
--
--   a) EXCEPCIÓN → fila ACTIVA de polizas_ap_topes para
--      (id_poliza, nro_doc del afiliado del siniestro, ventana). Es el
--      asegurado que se aparta del tope general (o al que se le autorizó una
--      ampliación). PISA al general.
--   b) TOPE GENERAL → polizas_ap.suma_asegurada. Modelo acordado con negocio
--      el 10/08/2026: la póliza declara UN tope que aplica a CADA asegurado
--      por separado ("aseguro a todos mis empleados por cinco millones, a
--      cada uno"), no es una bolsa común.
--   c) SIN_TOPE → ninguno de los dos. Sin denominador no hay porcentaje.
--
-- La salida expone origen_tope (EXCEPCION | GENERAL | SIN_TOPE) e id_tope
-- (solo cuando aplicó una excepción): el usuario tiene que poder saber POR
-- QUÉ su caso topea en X. El mismo 5.000.000 puede ser el tope general de la
-- póliza o una ampliación que se le autorizó a esa persona.
--
-- denuncia_poliza pasa a ser CACHE OPCIONAL: sus 6 columnas de tope siguen
-- existiendo y las escribe wsdocumento, pero el motor NO depende de ellas.
-- Se lee suma_asegurada solo para exponerla como suma_asegurada_cache y poder
-- detectar que quedó vieja. Motivo: cargar o ampliar un tope tiene que verse
-- en el semáforo al instante, el dueño de denuncia_poliza es otro ws, y
-- escribir dentro de un GET no.
--
-- COLLATION: polizas_ap_topes.nro_doc y afiliados.nro_doc son los dos
-- latin1_swedish_ci A PROPÓSITO, así que el join va DIRECTO (un CONVERT
-- anularía el índice). Lo que sí se normaliza es el lado del AFILIADO: la
-- tabla de topes guarda el documento ya normalizado —precondición del ABM,
-- ver utils/DocumentoAsegurado— y afiliados es legacy (puntos, espacios,
-- ceros a la izquierda). La normalización va sobre af.nro_doc y no sobre
-- t.nro_doc para no matar uk_polizas_ap_topes_poliza_doc_ventana. Si los dos
-- criterios se desincronizan, el siniestro se cae al tope GENERAL en
-- silencio: es lo primero que hay que mirar cuando una excepción cargada
-- "no se aplica".
--
-- VENTANA / MONEDA / IVA del tope general: polizas_ap sólo tiene la suma, así
-- que ventana y moneda vuelven NULL (la moneda la completa el servicio con su
-- default ARS; la ventana hoy es informativa porque el motor no filtra el
-- consumo por fecha, y asumir ANUAL sería afirmar un criterio que el dato no
-- declara). iva_incluido vuelve 1: que el tope se carga CON IVA es regla
-- cerrada del modelo, no un supuesto.
-- =====================================================================

WITH ap AS (
    SELECT dp.id_denuncia,
           d.nro_asignado,
           dp.id_poliza,
           d.id_afiliado,
           dp.suma_asegurada AS suma_asegurada_cache
      FROM denuncia_poliza dp
      JOIN denuncias d ON d.id_denuncia = dp.id_denuncia
     WHERE dp.activo = 1
       -- <<< FILTRO DEL SERVICIO AQUÍ >>>
),

-- ---------------------------------------------------------------------
-- 0 · EXCEPCIÓN de tope del asegurado (pisa al tope general)
-- ---------------------------------------------------------------------
-- El UNIQUE es (id_poliza, nro_doc, ventana), así que la misma persona puede
-- tener una fila por ventana. Hoy toda la cartera es ANUAL (el default de la
-- columna) y es la que gana; el id_tope DESC es el desempate que garantiza
-- que el motor nunca devuelva dos filas ni elija al azar. Si negocio habilita
-- varias ventanas por asegurado, la PRECEDENCIA la define negocio y se cambia
-- este ORDER BY (en los dos lados: acá y en MotorConsumoSql).
tope_excepcion AS (
    SELECT ap.id_denuncia,
           t.id_tope,
           t.suma_asegurada,
           t.moneda,
           t.ventana,
           t.iva_incluido,
           ROW_NUMBER() OVER (
               PARTITION BY ap.id_denuncia
               ORDER BY CASE WHEN t.ventana = 'ANUAL' THEN 0 ELSE 1 END,
                        t.id_tope DESC) AS prioridad
      FROM ap
      JOIN afiliados af ON af.id_afiliado = ap.id_afiliado
      JOIN polizas_ap_topes t
             ON t.id_poliza = ap.id_poliza
            AND t.nro_doc = TRIM(LEADING '0' FROM REPLACE(REPLACE(REPLACE(REPLACE(
                              af.nro_doc, ' ', ''), '.', ''), '-', ''), '/', ''))
     WHERE t.activo = 1
),

-- ---------------------------------------------------------------------
-- 0.b · TOPE RESUELTO — excepción -> general -> nada
-- ---------------------------------------------------------------------
-- El predicado es `> 0` y no `IS NOT NULL` porque un tope en cero no es
-- denominador: se trata igual que la ausencia, nunca se divide por él.
--
-- DIFERENCIA DELIBERADA con MotorConsumoSql.MOTOR: allá estos seis CASE están
-- inline en el SELECT final, porque el Java sólo necesita el tope UNA vez (el
-- porcentaje y el nivel los calcula el service). Acá se aísla en un CTE porque
-- este archivo también resuelve pct y nivel, y el tope aparece cuatro veces:
-- copiarlo cuatro veces sería la forma de que un día dejen de coincidir.
tope AS (
    SELECT ap.id_denuncia,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.id_tope END AS id_tope,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.suma_asegurada
                WHEN pa.suma_asegurada > 0 THEN pa.suma_asegurada END AS suma_asegurada,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.moneda END AS moneda,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.ventana END AS ventana,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.iva_incluido
                WHEN pa.suma_asegurada > 0 THEN 1 END AS iva_incluido,
           CASE WHEN ex.suma_asegurada > 0 THEN 'EXCEPCION'
                WHEN pa.suma_asegurada > 0 THEN 'GENERAL'
                ELSE 'SIN_TOPE' END AS origen_tope
      FROM ap
      LEFT JOIN tope_excepcion ex
             ON ex.id_denuncia = ap.id_denuncia
            AND ex.prioridad = 1
      LEFT JOIN polizas_ap pa ON pa.id_poliza = ap.id_poliza
),

-- ---------------------------------------------------------------------
-- 1 · FACTURADO — fuente única: erogaciones (regla R1)
-- ---------------------------------------------------------------------
facturado AS (
    SELECT e.id_denuncia,
           SUM(COALESCE(e.monto_facturado, 0) - COALESCE(e.monto_debitado, 0)) AS monto,
           COUNT(*) AS items
      FROM erogaciones e
      JOIN ap ON ap.id_denuncia = e.id_denuncia
     GROUP BY e.id_denuncia
),

-- ---------------------------------------------------------------------
-- 2 · DEVENGADO por turnos — realizado (19,23) y todavía sin facturar
-- ---------------------------------------------------------------------
devengado_turnos AS (
    SELECT t.id_denuncia,
           SUM(t.valor_prestacion) AS monto,
           COUNT(*) AS items
      FROM turnos t
      JOIN ap ON ap.id_denuncia = t.id_denuncia
     WHERE t.id_estado_turno IN (19, 23)
       AND t.valor_facturacion IS NULL      -- R2
       AND t.valor_prestacion IS NOT NULL
     GROUP BY t.id_denuncia
),

-- ---------------------------------------------------------------------
-- 3 · ESTIMADO por turnos — autorizado, no realizado, y que PUEDE ocurrir
-- ---------------------------------------------------------------------
estimado_turnos AS (
    SELECT t.id_denuncia,
           SUM(t.valor_prestacion) AS monto,
           COUNT(*) AS items
      FROM turnos t
      JOIN ap ON ap.id_denuncia = t.id_denuncia
     WHERE t.id_estado_turno NOT IN (19, 23)      -- no realizado
       AND t.id_estado_turno NOT IN (6, 9, 24, 25) -- y que no va a ocurrir nunca
       AND t.valor_facturacion IS NULL             -- R2
       AND t.valor_prestacion IS NOT NULL
     GROUP BY t.id_denuncia
),

-- ---------------------------------------------------------------------
-- 4 · VALORES MANUALES — medicación y prestaciones no convenidas
-- ---------------------------------------------------------------------
-- Se cuentan como DEVENGADO: es consumo que YA ocurrió y que no tiene
-- factura en el sistema (es justamente el agujero que esta tabla tapa).
-- Se exponen igual en su propia columna para poder auditarlos aparte.
manuales AS (
    SELECT vm.id_denuncia,
           SUM(vm.monto) AS monto,
           COUNT(*) AS items
      FROM ap_valores_manuales vm
      JOIN ap ON ap.id_denuncia = vm.id_denuncia
     WHERE vm.activo = 1
       AND vm.computa_consumo = 1
     GROUP BY vm.id_denuncia
),

-- ---------------------------------------------------------------------
-- 5 · CIRUGÍA · honorarios — presupuesto valorizado (estado 2)
-- ---------------------------------------------------------------------
qx_honorarios AS (
    SELECT c.id_denuncia,
           SUM(COALESCE(pp.valor_convenido, 0)) AS monto,
           COUNT(*) AS items
      FROM cirugias c
      JOIN ap ON ap.id_denuncia = c.id_denuncia
      JOIN pedidos_presupuesto_prestaciones pp
             ON pp.id_autorizacion = c.id_autorizacion
      -- R5: si el turno del presupuesto ya aportó por valor_prestacion,
      --     este honorario NO se vuelve a contar.
      LEFT JOIN turnos tt
             ON tt.id_turno = pp.id_turno
            AND tt.valor_prestacion IS NOT NULL
     WHERE pp.id_estado_pedido_presupuestos = 2
       AND tt.id_turno IS NULL
     GROUP BY c.id_denuncia
),

-- ---------------------------------------------------------------------
-- 6 · CIRUGÍA · materiales quirúrgicos — cotización ganadora
-- ---------------------------------------------------------------------
-- La trampa histórica: agrupar por `grupo` a secas colapsa filas que en
-- realidad son materiales distintos, porque `grupo` viene 0 o NULL cuando
-- el material no forma parte de un grupo. Entonces:
--   grupo real (<> 0 y no nulo) → UNA vez por grupo (la cotización ganadora
--                                 es una sola para todo el grupo)
--   grupo 0 / NULL             → POR DETALLE
qx_materiales_grupo AS (
    SELECT pm.id_denuncia,
           MAX(COALESCE(de.monto_cotizacion, 0)) AS monto
      FROM pedidos_materiales_quirurgicos pm
      JOIN ap ON ap.id_denuncia = pm.id_denuncia
      JOIN pedidos_materiales_quirurgicos_detalles de
             ON de.id_pedido_material_quirurgico = pm.id_pedido_material_quirurgico
     WHERE COALESCE(de.grupo, 0) <> 0
       AND de.nro_factura IS NULL              -- R3
       AND COALESCE(de.es_eliminado_completo, 0) = 0
       AND de.monto_cotizacion IS NOT NULL
     GROUP BY pm.id_denuncia, pm.id_pedido_material_quirurgico, de.grupo
),
qx_materiales_detalle AS (
    SELECT pm.id_denuncia,
           COALESCE(de.monto_cotizacion, 0) AS monto
      FROM pedidos_materiales_quirurgicos pm
      JOIN ap ON ap.id_denuncia = pm.id_denuncia
      JOIN pedidos_materiales_quirurgicos_detalles de
             ON de.id_pedido_material_quirurgico = pm.id_pedido_material_quirurgico
     WHERE COALESCE(de.grupo, 0) = 0
       AND de.nro_factura IS NULL              -- R3
       AND COALESCE(de.es_eliminado_completo, 0) = 0
       AND de.monto_cotizacion IS NOT NULL
),
qx_materiales AS (
    SELECT id_denuncia, SUM(monto) AS monto, COUNT(*) AS items
      FROM (
            SELECT id_denuncia, monto FROM qx_materiales_grupo
            UNION ALL
            SELECT id_denuncia, monto FROM qx_materiales_detalle
           ) u
     GROUP BY id_denuncia
),

-- ---------------------------------------------------------------------
-- 7 · CIRUGÍA · ortopedia
-- ---------------------------------------------------------------------
-- R4: fuera lo que ya está en erogaciones (vínculo exacto por
-- relacion_erogaciones_ortopedia) y fuera lo cancelado.
qx_ortopedia AS (
    SELECT po.id_denuncia,
           SUM(COALESCE(od.valor, 0) * COALESCE(od.cantidad, 1)) AS monto,
           COUNT(*) AS items
      FROM pedidos_ortopedia po
      JOIN ap ON ap.id_denuncia = po.id_denuncia
      JOIN pedidos_ortopedia_detalle od
             ON od.id_pedido_ortopedia = po.id_pedido_ortopedia
     WHERE po.id_estado_pedido NOT IN (4, 5)             -- Cancelado / Cerrado x Sist.
       AND COALESCE(od.id_estado_material_ortopedico, 0) <> 7  -- material Cancelado
       AND od.valor IS NOT NULL
       AND NOT EXISTS (SELECT 1
                         FROM relacion_erogaciones_ortopedia reo
                        WHERE reo.id_pedido_ortopedia = po.id_pedido_ortopedia)
     GROUP BY po.id_denuncia
),

-- ---------------------------------------------------------------------
-- 8 · TRASLADOS — vía traslados.id_turno -> turnos.id_denuncia
-- ---------------------------------------------------------------------
-- Realizado(4) / Negativo autorizado(8) = DEVENGADO (ya ocurrió).
-- Solicitado(1)/Asignado(2)/Programado(3) = ESTIMADO (todavía no).
-- Fallido(5)/Cancelado(6)/No coordinable(7) = no cobran, no entran.
-- Sin doble conteo contra erogaciones: los traslados NO tienen tipo de
-- erogación, se facturan por otro circuito. Se excluye igual el tramo que
-- ya tiene factura asignada (id_factura_*) para no pisar la auditoría.
traslados_x AS (
    SELECT t.id_denuncia,
           SUM(CASE WHEN tr.id_estado_logistica_ida IN (4, 8)
                     AND tr.id_factura_ida IS NULL
                    THEN COALESCE(tr.monto_ida, 0) - COALESCE(tr.debito_ida, 0)
                    ELSE 0 END)
         + SUM(CASE WHEN tr.id_estado_logistica_vuelta IN (4, 8)
                     AND tr.id_factura_regreso IS NULL
                    THEN COALESCE(tr.monto_regreso, 0) - COALESCE(tr.debito_regreso, 0)
                    ELSE 0 END) AS devengado,
           SUM(CASE WHEN tr.id_estado_logistica_ida IN (1, 2, 3)
                    THEN COALESCE(tr.monto_ida, 0) - COALESCE(tr.debito_ida, 0)
                    ELSE 0 END)
         + SUM(CASE WHEN tr.id_estado_logistica_vuelta IN (1, 2, 3)
                    THEN COALESCE(tr.monto_regreso, 0) - COALESCE(tr.debito_regreso, 0)
                    ELSE 0 END) AS estimado,
           COUNT(*) AS items
      FROM turnos t
      JOIN ap ON ap.id_denuncia = t.id_denuncia
      JOIN traslados tr ON tr.id_turno = t.id_turno
     GROUP BY t.id_denuncia
),

-- ---------------------------------------------------------------------
-- 9 · PARÁMETROS DEL SEMÁFORO — la fila activa única
-- ---------------------------------------------------------------------
-- 40 y 70 son parámetros. 90 y 100 son FIJOS en el modelo (por eso están
-- escritos acá y no salen de la tabla).
parametros AS (
    SELECT COALESCE(MAX(p.umbral_bajo), 40)  AS umbral_bajo,
           COALESCE(MAX(p.umbral_medio), 70) AS umbral_medio
      FROM ap_semaforo_parametros p
     WHERE p.activo = 1
)

-- ---------------------------------------------------------------------
-- SALIDA
-- ---------------------------------------------------------------------
SELECT ap.id_denuncia,
       ap.nro_asignado,
       ap.id_poliza,

       -- tope RESUELTO EN VIVO (CTE `tope`)
       tp.id_tope,
       tp.suma_asegurada,
       tp.moneda,
       tp.ventana,
       tp.iva_incluido,
       tp.origen_tope,
       -- Cache de denuncia_poliza: NO participa del cálculo, viaja para poder
       -- ver que quedó vieja.
       ap.suma_asegurada_cache,

       -- desagregado por vía (para el drawer y para auditar el número)
       COALESCE(f.monto, 0)     AS facturado_erogaciones,
       COALESCE(dt.monto, 0)    AS devengado_turnos,
       COALESCE(mn.monto, 0)    AS devengado_manual,
       COALESCE(tx.devengado, 0) AS devengado_traslados,
       COALESCE(et.monto, 0)    AS estimado_turnos,
       COALESCE(qh.monto, 0)    AS estimado_qx_honorarios,
       COALESCE(qm.monto, 0)    AS estimado_qx_materiales,
       COALESCE(qo.monto, 0)    AS estimado_qx_ortopedia,
       COALESCE(tx.estimado, 0) AS estimado_traslados,

       -- los 3 estados de confianza
       CAST(COALESCE(f.monto, 0) AS DECIMAL(16,2)) AS facturado,
       CAST(COALESCE(dt.monto, 0) + COALESCE(mn.monto, 0)
          + COALESCE(tx.devengado, 0) AS DECIMAL(16,2)) AS devengado,
       CAST(COALESCE(et.monto, 0) + COALESCE(qh.monto, 0) + COALESCE(qm.monto, 0)
          + COALESCE(qo.monto, 0) + COALESCE(tx.estimado, 0) AS DECIMAL(16,2)) AS estimado,

       -- proyección = la cifra de vigilancia
       CAST(COALESCE(f.monto, 0) + COALESCE(dt.monto, 0) + COALESCE(mn.monto, 0)
          + COALESCE(tx.devengado, 0) + COALESCE(et.monto, 0) + COALESCE(qh.monto, 0)
          + COALESCE(qm.monto, 0) + COALESCE(qo.monto, 0)
          + COALESCE(tx.estimado, 0) AS DECIMAL(16,2)) AS proyeccion,

       -- porcentaje sobre el tope — NUNCA se divide sin tope > 0
       CASE WHEN tp.suma_asegurada IS NULL OR tp.suma_asegurada <= 0 THEN NULL
            ELSE ROUND((COALESCE(f.monto,0) + COALESCE(dt.monto,0) + COALESCE(mn.monto,0)
                      + COALESCE(tx.devengado,0) + COALESCE(et.monto,0) + COALESCE(qh.monto,0)
                      + COALESCE(qm.monto,0) + COALESCE(qo.monto,0) + COALESCE(tx.estimado,0))
                      / tp.suma_asegurada * 100, 2)
       END AS pct_proyeccion,

       -- semáforo: <bajo BAJO | <medio MEDIO | <90 ALTO | <=100 MUY_ALTO | >100 EXCEDIDO
       CASE WHEN tp.suma_asegurada IS NULL OR tp.suma_asegurada <= 0 THEN 'SIN_TOPE'
            WHEN (COALESCE(f.monto,0) + COALESCE(dt.monto,0) + COALESCE(mn.monto,0)
                + COALESCE(tx.devengado,0) + COALESCE(et.monto,0) + COALESCE(qh.monto,0)
                + COALESCE(qm.monto,0) + COALESCE(qo.monto,0) + COALESCE(tx.estimado,0))
                / tp.suma_asegurada * 100 < pr.umbral_bajo  THEN 'BAJO'
            WHEN (COALESCE(f.monto,0) + COALESCE(dt.monto,0) + COALESCE(mn.monto,0)
                + COALESCE(tx.devengado,0) + COALESCE(et.monto,0) + COALESCE(qh.monto,0)
                + COALESCE(qm.monto,0) + COALESCE(qo.monto,0) + COALESCE(tx.estimado,0))
                / tp.suma_asegurada * 100 < pr.umbral_medio THEN 'MEDIO'
            WHEN (COALESCE(f.monto,0) + COALESCE(dt.monto,0) + COALESCE(mn.monto,0)
                + COALESCE(tx.devengado,0) + COALESCE(et.monto,0) + COALESCE(qh.monto,0)
                + COALESCE(qm.monto,0) + COALESCE(qo.monto,0) + COALESCE(tx.estimado,0))
                / tp.suma_asegurada * 100 < 90  THEN 'ALTO'
            WHEN (COALESCE(f.monto,0) + COALESCE(dt.monto,0) + COALESCE(mn.monto,0)
                + COALESCE(tx.devengado,0) + COALESCE(et.monto,0) + COALESCE(qh.monto,0)
                + COALESCE(qm.monto,0) + COALESCE(qo.monto,0) + COALESCE(tx.estimado,0))
                / tp.suma_asegurada * 100 <= 100 THEN 'MUY_ALTO'
            ELSE 'EXCEDIDO'
       END AS nivel_semaforo

  FROM ap
  CROSS JOIN parametros pr
  JOIN tope tp ON tp.id_denuncia = ap.id_denuncia
  LEFT JOIN facturado        f  ON f.id_denuncia  = ap.id_denuncia
  LEFT JOIN devengado_turnos dt ON dt.id_denuncia = ap.id_denuncia
  LEFT JOIN estimado_turnos  et ON et.id_denuncia = ap.id_denuncia
  LEFT JOIN manuales         mn ON mn.id_denuncia = ap.id_denuncia
  LEFT JOIN qx_honorarios    qh ON qh.id_denuncia = ap.id_denuncia
  LEFT JOIN qx_materiales    qm ON qm.id_denuncia = ap.id_denuncia
  LEFT JOIN qx_ortopedia     qo ON qo.id_denuncia = ap.id_denuncia
  LEFT JOIN traslados_x      tx ON tx.id_denuncia = ap.id_denuncia
 ORDER BY proyeccion DESC;


-- =====================================================================
-- Q2 · DETALLE POR ÍTEM — de dónde sale cada peso de Q1
-- =====================================================================
-- Una fila por ítem de consumo, con su estado de confianza y su origen.
-- Es la consulta del drawer: el tramitador tiene que poder ver la lista,
-- no sólo el total. Reemplazar :idDenuncia.
--
-- Se deja como UNION ALL de las mismas 8 vías de Q1, con las MISMAS
-- condiciones. Si se toca una regla en Q1 hay que tocarla acá también:
-- son el mismo contrato visto agregado y visto en detalle.

SELECT 'FACTURADO' AS estado_confianza, 'EROGACION' AS origen,
       e.id_erogacion AS id_origen,
       CONCAT('Erogación tipo ', e.id_tipo_erogacion,
              COALESCE(CONCAT(' · fact. ', e.nro_factura), '')) AS descripcion,
       e.fecha_ingreso_factura AS fecha,
       COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0) AS monto
  FROM erogaciones e
 WHERE e.id_denuncia = :idDenuncia

UNION ALL
SELECT 'DEVENGADO', 'TURNO', t.id_turno,
       CONCAT('Turno realizado (estado ', t.id_estado_turno, ') sin facturar'),
       t.fecha_turno, t.valor_prestacion
  FROM turnos t
 WHERE t.id_denuncia = :idDenuncia
   AND t.id_estado_turno IN (19,23)
   AND t.valor_facturacion IS NULL
   AND t.valor_prestacion IS NOT NULL

UNION ALL
SELECT 'DEVENGADO', CONCAT('MANUAL_', vm.tipo), vm.id_valor_manual,
       vm.descripcion, vm.fecha_precio, vm.monto
  FROM ap_valores_manuales vm
 WHERE vm.id_denuncia = :idDenuncia
   AND vm.activo = 1 AND vm.computa_consumo = 1

UNION ALL
SELECT 'ESTIMADO', 'TURNO', t.id_turno,
       CONCAT('Turno no realizado (estado ', t.id_estado_turno, ')'),
       t.fecha_turno, t.valor_prestacion
  FROM turnos t
 WHERE t.id_denuncia = :idDenuncia
   AND t.id_estado_turno NOT IN (19,23)
   AND t.id_estado_turno NOT IN (6,9,24,25)
   AND t.valor_facturacion IS NULL
   AND t.valor_prestacion IS NOT NULL

UNION ALL
SELECT 'ESTIMADO', 'QX_MATERIAL', de.id_pedido_material_quirurgico_detalle,
       CONCAT('Material quirúrgico · cotización ',
              COALESCE(de.id_cotizacion_seleccionada, 0),
              ' · grupo ', COALESCE(de.grupo, 0)),
       NULL, de.monto_cotizacion
  FROM pedidos_materiales_quirurgicos pm
  JOIN pedidos_materiales_quirurgicos_detalles de
         ON de.id_pedido_material_quirurgico = pm.id_pedido_material_quirurgico
 WHERE pm.id_denuncia = :idDenuncia
   AND de.nro_factura IS NULL
   AND COALESCE(de.es_eliminado_completo,0) = 0
   AND de.monto_cotizacion IS NOT NULL

UNION ALL
SELECT 'ESTIMADO', 'QX_ORTOPEDIA', od.id_pedido_ortopedia_detalle,
       CONCAT('Ortopedia · pedido ', po.id_pedido_ortopedia,
              ' · estado ', po.id_estado_pedido),
       po.fecha_solicitud, COALESCE(od.valor,0) * COALESCE(od.cantidad,1)
  FROM pedidos_ortopedia po
  JOIN pedidos_ortopedia_detalle od ON od.id_pedido_ortopedia = po.id_pedido_ortopedia
 WHERE po.id_denuncia = :idDenuncia
   AND po.id_estado_pedido NOT IN (4,5)
   AND COALESCE(od.id_estado_material_ortopedico,0) <> 7
   AND od.valor IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM relacion_erogaciones_ortopedia reo
                    WHERE reo.id_pedido_ortopedia = po.id_pedido_ortopedia)

UNION ALL
SELECT 'ESTIMADO', 'QX_HONORARIO', pp.id_pedido_presupuesto,
       'Honorario de cirugía (presupuesto valorizado)',
       pp.fecha_carga, pp.valor_convenido
  FROM cirugias c
  JOIN pedidos_presupuesto_prestaciones pp ON pp.id_autorizacion = c.id_autorizacion
  LEFT JOIN turnos tt ON tt.id_turno = pp.id_turno AND tt.valor_prestacion IS NOT NULL
 WHERE c.id_denuncia = :idDenuncia
   AND pp.id_estado_pedido_presupuestos = 2
   AND tt.id_turno IS NULL

UNION ALL
SELECT CASE WHEN tr.id_estado_logistica_ida IN (4,8) THEN 'DEVENGADO' ELSE 'ESTIMADO' END,
       'TRASLADO_IDA', tr.id_traslado,
       CONCAT('Traslado ida · estado logística ', tr.id_estado_logistica_ida),
       tr.fecha_traslado, COALESCE(tr.monto_ida,0) - COALESCE(tr.debito_ida,0)
  FROM turnos t
  JOIN traslados tr ON tr.id_turno = t.id_turno
 WHERE t.id_denuncia = :idDenuncia
   AND tr.id_estado_logistica_ida IN (1,2,3,4,8)
   AND (tr.id_estado_logistica_ida NOT IN (4,8) OR tr.id_factura_ida IS NULL)

UNION ALL
SELECT CASE WHEN tr.id_estado_logistica_vuelta IN (4,8) THEN 'DEVENGADO' ELSE 'ESTIMADO' END,
       'TRASLADO_VUELTA', tr.id_traslado,
       CONCAT('Traslado vuelta · estado logística ', tr.id_estado_logistica_vuelta),
       tr.fecha_traslado, COALESCE(tr.monto_regreso,0) - COALESCE(tr.debito_regreso,0)
  FROM turnos t
  JOIN traslados tr ON tr.id_turno = t.id_turno
 WHERE t.id_denuncia = :idDenuncia
   AND tr.id_estado_logistica_vuelta IN (1,2,3,4,8)
   AND (tr.id_estado_logistica_vuelta NOT IN (4,8) OR tr.id_factura_regreso IS NULL)

 ORDER BY 1, 2, 6 DESC;


-- =====================================================================
-- Q3 · EXPLAIN — ¿el filtro por AP entra por índice?
-- =====================================================================
-- Lo que hay que ver: denuncia_poliza como tabla conductora (61 filas) y
-- erogaciones / turnos accedidos por `ref` sobre su índice de id_denuncia.
-- Si alguno apareciera como `ALL`, falta un índice y la cartera no escala.

EXPLAIN
SELECT dp.id_denuncia,
       SUM(COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0)) AS facturado
  FROM denuncia_poliza dp
  LEFT JOIN erogaciones e ON e.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1
 GROUP BY dp.id_denuncia;

EXPLAIN
SELECT t.id_denuncia, SUM(t.valor_prestacion)
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1 AND t.id_estado_turno IN (19,23)
 GROUP BY t.id_denuncia;

EXPLAIN
SELECT t.id_denuncia, COUNT(*)
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
  JOIN traslados tr ON tr.id_turno = t.id_turno
 WHERE dp.activo = 1
 GROUP BY t.id_denuncia;


-- =====================================================================
-- V · VALIDACIÓN CONTRA STAGE — 10/08/2026, MariaDB 10.5.29
-- =====================================================================
-- Todo lo que sigue son NÚMEROS MEDIDOS corriendo Q1 y Q2 tal cual están
-- en este archivo. No hay nada estimado a ojo.
--
-- Universo: 61 denuncias AP activas en denuncia_poliza, 7 pólizas distintas.
--
-- ANTES de la resolución en vivo (el tope salía de denuncia_poliza, que nadie
-- escribía): 7 denuncias con suma_asegurada y 54 en SIN_TOPE.
--   SIN_TOPE 54 · BAJO 1 · MEDIO 1 · ALTO 1 · MUY_ALTO 1 · EXCEDIDO 3
--
-- DESPUÉS (10/08/2026, con el tope general cargado en 4 de las 7 pólizas de
-- stage): 57 denuncias con tope y sólo 4 en SIN_TOPE.
--   ORIGEN DEL TOPE: EXCEPCION 7 · GENERAL 50 · SIN_TOPE 4
--   SEMÁFORO:  BAJO 48 · MEDIO 3 · ALTO 1 · MUY_ALTO 2 · EXCEDIDO 3 · SIN_TOPE 4
--   Las 3 ramas de la resolución y los 6 niveles quedan ejercitados con datos
--   reales. Los 4 SIN_TOPE son las pólizas 29, 43 y 51, que a propósito NO
--   tienen tope general cargado: son el caso de control de "no dibujar un
--   semáforo sin denominador".
--   Los montos NO cambiaron con este cambio (sólo cambió el denominador):
--   PROYECCIÓN de la cartera sigue en $5.129.393,49.
--
-- COBERTURA POR COMPONENTE (denuncias AP con el componente > 0):
--   FACTURADO  erogaciones ...... 14 / 61   $2.330.179,78
--   DEVENGADO  turnos ........... 32 / 61   $1.420.873,42
--   DEVENGADO  manual ...........  1 / 61     $153.200,00
--   DEVENGADO  traslados ........  0 / 61           $0,00
--   ESTIMADO   turnos ...........  2 / 61     $185.228,64
--   ESTIMADO   qx materiales ....  1 / 61     $790.000,00
--   ESTIMADO   qx ortopedia .....  3 / 61     $249.911,65
--   ESTIMADO   qx honorarios ....  0 / 61           $0,00
--   ESTIMADO   traslados ........  0 / 61           $0,00
--
-- TOTALES DE LA CARTERA AP EN STAGE:
--   FACTURADO ....  $2.330.179,78
--   DEVENGADO ....  $1.574.073,42
--   ESTIMADO .....  $1.225.140,29
--   PROYECCIÓN ...  $5.129.393,49
--
-- LAS 7 DENUNCIAS CON EXCEPCIÓN PROPIA (tope que se aparta del general):
--   id_denuncia  nro         tope           proyección       pct     nivel
--   502068       SW502068    5.000.000,00   1.411.579,82    28,23%   BAJO
--   498024       SW498024       60.000,00      24.000,00    40,00%   MEDIO
--   498407       SW498407      360.000,00     287.590,04    79,89%   ALTO
--   498001       SW498001      280.000,00     263.050,98    93,95%   MUY_ALTO
--   504078       SW504078      150.000,00     204.919,20   136,61%   EXCEDIDO
--   498249       SW498249      600.000,00   1.126.089,68   187,68%   EXCEDIDO
--   498034       SW498034       24.000,00      84.000,00   350,00%   EXCEDIDO
--
-- CASOS QUE AHORA TOPEAN POR EL TOPE GENERAL DE SU PÓLIZA (muestra):
--   id_denuncia  nro         póliza  tope general   proyección     pct     nivel
--   498032       SW498032    52         70.000,00    63.253,46    90,36%   MUY_ALTO
--   479979       SW479979    28        200.000,00    99.944,00    49,97%   MEDIO
--   475289       SW475289    28        200.000,00    85.140,33    42,57%   MEDIO
--   496878       SW496878    46      5.000.000,00   198.554,43     3,97%   BAJO
--   Antes de este cambio los cuatro daban SIN_TOPE con la póliza cargada.
--
-- LO QUE EL ANTI-DOBLE-CONTEO DEJA AFUERA (medido, no teórico):
--   · turnos en estado 6 Anulado / 24 No Realizado con valor_prestacion
--     cargado: 5 turnos, $109.965,81. Sin la exclusión, el ESTIMADO de
--     turnos de toda la cartera ($185.228,64) se habría inflado un 59%.
--   · turnos con valor_facturacion ya asignado (R2): 14 turnos,
--     $63.096,76 de valor_prestacion que NO se duplican contra la factura.
--   · material quirúrgico de la denuncia 502068, nro_factura
--     00007-00004642: $530.000 que no entran como ESTIMADO porque ya
--     están del lado de la factura (R3).
--   · ortopedia de la denuncia 498001: pedido 37106 Cancelado (estado 4)
--     con el material también Cancelado (estado 7): $90.000 (R4).
--   · valor manual de la 502068 ligado a la erogación 1154595 con
--     computa_consumo = 0: $12.500.
--   TOTAL EXCLUIDO A PROPÓSITO: $805.562,57.
--   Una suma ingenua daría $5.934.956,06 en vez de $5.129.393,49: el
--   semáforo estaría 13,6% inflado en toda la cartera, y en denuncias
--   puntuales muchísimo más. Esto es lo que justifica las 5 reglas.
--
-- CONTROL CRUZADO Q1 ↔ Q2 (el detalle tiene que sumar exactamente igual
-- que el agregado; si no, alguna regla está escrita distinto en un lado):
--   denuncia 502068 · Q1: F 1.042.363,45 | D 369.216,37 | E 0,00
--                    Q2: F 1.042.363,45 | D 369.216,37 | E ausente  ✔
--   denuncia 498249 · Q1: F   111.660,00 | D  60.952,24 | E 953.477,44
--                    Q2: F   111.660,00 | D  60.952,24 | E 953.477,44 ✔
--
-- CASO DE PRUEBA RICO — denuncia 502068 (tiene facturado + manual +
-- turnos + un material ya facturado que debe quedar afuera):
--   FACTURADO   $1.042.363,45  (erogación 1154595, tipo 3)
--   DEVENGADO     $369.216,37  = 4 turnos realizados ($216.016,37)
--                              + 2 valores manuales ($153.200,00)
--   ESTIMADO            $0,00  (su material de $530.000 YA está facturado)
--   PROYECCIÓN  $1.411.579,82  sobre tope $5.000.000 ⇒ 28,23% ⇒ BAJO
--
-- PERFORMANCE (stage; min/avg/max de 3 corridas):
--   Q1 cartera completa (61 denuncias) ...  240 / 243 / 248 ms
--   Q1 filtrado a una denuncia ...........  227 / 231 / 236 ms
--   Q2 detalle de una denuncia ...........  231 / 294 ms
--   (el piso de ~220 ms es latencia de red a stage, no de la consulta)
--
-- EXPLAIN — el filtro por AP entra por índice en las tres vías críticas:
--   facturado:  dp  type=index  key=uk_denuncia_poliza_activo  rows=61
--               e   type=ref    key=id_denuncia                rows=2
--   turnos:     dp  type=index  key=uk_denuncia_poliza_activo  rows=61
--               t   type=ref    key=idx_den_tipo_estado        rows=6
--   traslados:  dp  type=index  key=uk_denuncia_poliza_activo  rows=61
--               t   type=ref    key=idx_den_tipo_estado        rows=6
--               tr  type=ref    key=traslados_turnos_fk1       rows=1
--   Nunca se barren turnos (1,1 M) ni traslados (1,6 M).
--   Con la resolución del tope en vivo (10/08/2026) el plan de la consulta
--   completa cambia en dos puntos, medidos contra stage:
--     · denuncia_poliza pasa de `index` (cubierta por
--       uk_denuncia_poliza_activo) a `ALL` sobre sus 61 filas, porque ahora
--       la consulta necesita columnas que no están en el índice. Son 61
--       filas: irrelevante. Si el universo AP creciera, la salida es un
--       índice que cubra (activo, id_denuncia, id_poliza, suma_asegurada).
--     · el CTE de la excepción lo conduce polizas_ap_topes (7 filas en
--       stage) y entra a denuncia_poliza por idx_denuncia_poliza_poliza y a
--       afiliados por PK. La normalización del documento va sobre el lado
--       del afiliado justamente para que el índice del tope siga sirviendo.
--   TIEMPO: 228 / 229 / 230 ms — el mismo que antes del cambio (el piso de
--   ~220 ms es latencia de red a stage).
--   Dato lateral que refuerza la cadena elegida: traslados TIENE un índice
--   llamado `traslados_turnos_fk1` sobre id_turno — la vía por turno es la
--   que el esquema previó. id_viaje_autorizado no tiene índice útil.
--   Con 61 denuncias esto es holgado. Si el universo AP creciera a decenas
--   de miles habría que materializar el consumo, no rehacer la query.
--
-- LO QUE QUEDA SIN VALIDAR (alcance honesto, para no vender de más):
--   1. TRASLADOS: la cadena está resuelta y probada a nivel estructura
--      (1.592.366 de 1.600.289 traslados = 99,5% llegan a denuncia por
--      id_turno), pero el universo AP de stage tiene 0 traslados, así que
--      los montos AP de traslado NUNCA se ejercitaron. Correr V6.a y el
--      bloque de traslados en prod antes de confiar en ese número.
--   2. QX HONORARIOS: hay 8 cirugías AP en stage (4 denuncias), pero
--      ninguna con presupuesto valorizado (estado 2) ⇒ 0 filas. La guarda
--      R5 contra el doble conteo con turnos.valor_prestacion está escrita
--      pero no ejercitada.
--   3. Turnos en estado 19 y en estado 20: CERO en el universo AP de
--      stage (los únicos estados presentes son 4, 6, 16, 23, 24 y 26).
--      Es decir que hoy todo el DEVENGADO viene del estado 23 solo. Si en
--      prod aparecieran turnos en 20 (Informado) con valor_prestacion,
--      este motor los mandaría al ESTIMADO, que es sospechoso: un turno
--      Informado está realizado. Es una pregunta para negocio, no una
--      decisión para tomar acá.
--   4. Los 7 topes de excepción de stage son chicos respecto del consumo
--      real (3 de 7 dan EXCEDIDO). Sirven para ejercitar los 5 niveles,
--      pero NO son topes de negocio reales: no sacar conclusiones de
--      siniestralidad de esta tabla.
--   5. Los topes GENERALES de stage (pólizas 46 = 5.000.000, 28 = 200.000,
--      45 = 500.000, 52 = 70.000) también son DATO DE PRUEBA, cargados para
--      poder ejercitar el fallback y los 6 niveles. El 5.000.000 de la
--      póliza 46 es el número que dijo el cliente en la reunión; los otros
--      tres se eligieron para que el porcentaje cayera en el nivel buscado.
--      Ver 11-tope-general-poliza-stage.sql.
--   6. La PRECEDENCIA entre dos excepciones activas de distinta ventana para
--      la misma persona la decide hoy un ORDER BY determinista (ANUAL
--      primero, después id_tope DESC). No es una decisión de negocio: hoy
--      toda la cartera es ANUAL. Si negocio habilita varias ventanas por
--      asegurado, hay que preguntar cuál manda.
-- =====================================================================


-- ---------------------------------------------------------------------
-- V6 · CHEQUEOS DE VALIDACIÓN reutilizables (correr en cualquier ambiente)
-- ---------------------------------------------------------------------
-- V6.a · ¿La cadena de traslados sigue siendo id_turno? (debe dar ~99%)
SELECT 'V6a cadena traslados' AS chequeo,
       COUNT(*) AS traslados,
       SUM(t.id_denuncia IS NOT NULL) AS llegan_a_denuncia,
       ROUND(SUM(t.id_denuncia IS NOT NULL) / COUNT(*) * 100, 2) AS pct
  FROM traslados tr
  LEFT JOIN turnos t ON t.id_turno = tr.id_turno;

-- V6.b · ¿id_viaje_autorizado sirve de FK? (debe dar 0 — es residual)
SELECT 'V6b id_viaje_autorizado' AS chequeo,
       COUNT(*) AS con_viaje,
       SUM(at2.id_autorizacion_traslado IS NOT NULL) AS matchean
  FROM traslados tr
  LEFT JOIN autorizaciones_traslados at2
         ON at2.id_autorizacion_traslado = tr.id_viaje_autorizado
 WHERE tr.id_viaje_autorizado IS NOT NULL;

-- V6.c · Turnos AP por estado — para ver si aparecen estados nuevos
--        (sobre todo el 20 Informado y el 19, que en stage no existen)
SELECT 'V6c turnos AP x estado' AS chequeo,
       t.id_estado_turno, et.descripcion,
       COUNT(*) AS turnos,
       SUM(t.valor_prestacion IS NOT NULL) AS con_valor_prestacion,
       SUM(COALESCE(t.valor_prestacion,0)) AS suma
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
  LEFT JOIN estados_turnos et ON et.id_estado_turno = t.id_estado_turno
 WHERE dp.activo = 1
 GROUP BY t.id_estado_turno, et.descripcion
 ORDER BY turnos DESC;

-- V6.e · ¿De dónde sale el tope de cada siniestro AP? (reparto por origen)
--        Sirve para dos cosas: ver si quedan pólizas sin tope general
--        cargado, y detectar excepciones que NO se están aplicando por
--        desalineación del documento (el caso silencioso).
--
-- ⚠ Este chequeo tiene que expresar EXACTAMENTE la misma regla que Q1, o
--   "valida" algo distinto de lo que el semáforo muestra. Por eso repite el
--   CTE `tope_excepcion` con su ROW_NUMBER y usa `> 0` (no `id_tope IS NOT
--   NULL`): una excepción con suma 0 existe como fila pero NO es denominador,
--   y sin el ROW_NUMBER un asegurado con dos excepciones activas de distinta
--   ventana contaría dos veces en el reparto.
WITH ap AS (
    SELECT dp.id_denuncia, dp.id_poliza, d.id_afiliado
      FROM denuncia_poliza dp
      JOIN denuncias d ON d.id_denuncia = dp.id_denuncia
     WHERE dp.activo = 1
),
tope_excepcion AS (
    SELECT ap.id_denuncia,
           t.suma_asegurada,
           ROW_NUMBER() OVER (
               PARTITION BY ap.id_denuncia
               ORDER BY CASE WHEN t.ventana = 'ANUAL' THEN 0 ELSE 1 END,
                        t.id_tope DESC) AS prioridad
      FROM ap
      JOIN afiliados af ON af.id_afiliado = ap.id_afiliado
      JOIN polizas_ap_topes t
             ON t.id_poliza = ap.id_poliza
            AND t.nro_doc = TRIM(LEADING '0' FROM REPLACE(REPLACE(REPLACE(REPLACE(
                              af.nro_doc, ' ', ''), '.', ''), '-', ''), '/', ''))
     WHERE t.activo = 1
)
SELECT 'V6e origen del tope' AS chequeo,
       CASE WHEN ex.suma_asegurada > 0 THEN 'EXCEPCION'
            WHEN pa.suma_asegurada > 0 THEN 'GENERAL'
            ELSE 'SIN_TOPE' END AS origen,
       COUNT(*) AS siniestros
  FROM ap
  LEFT JOIN tope_excepcion ex
         ON ex.id_denuncia = ap.id_denuncia
        AND ex.prioridad = 1
  LEFT JOIN polizas_ap pa ON pa.id_poliza = ap.id_poliza
 GROUP BY origen;

-- V6.f · Excepciones cargadas que NO matchean ningún afiliado de su póliza.
--        Debe dar 0 filas. Si aparece alguna, el tope existe y el semáforo la
--        está ignorando: hay que revisar la normalización del documento.
SELECT 'V6f excepciones huerfanas' AS chequeo,
       t.id_tope, t.id_poliza, t.nro_doc, t.suma_asegurada
  FROM polizas_ap_topes t
 WHERE t.activo = 1
   AND NOT EXISTS (
       SELECT 1
         FROM denuncia_poliza dp
         JOIN denuncias d  ON d.id_denuncia = dp.id_denuncia
         JOIN afiliados af ON af.id_afiliado = d.id_afiliado
        WHERE dp.activo = 1
          AND dp.id_poliza = t.id_poliza
          AND t.nro_doc = TRIM(LEADING '0' FROM REPLACE(REPLACE(REPLACE(REPLACE(
                            af.nro_doc, ' ', ''), '.', ''), '-', ''), '/', ''))
   );

-- V6.g · ¿La cache de denuncia_poliza quedó vieja? (no rompe nada, pero es
--        lo primero que hay que mirar si un reporte armado sobre esa tabla
--        no coincide con la pantalla del semáforo)
--
-- ⚠ Misma advertencia que V6.e: el "vigente" con el que se compara tiene que
--   resolverse con la regla de Q1 (ROW_NUMBER + `> 0`). Un COALESCE crudo
--   tomaría una excepción en cero como si fuera el tope y reportaría como
--   "cache vieja" un caso que en realidad topea por el general.
WITH ap AS (
    SELECT dp.id_denuncia, dp.id_poliza, d.id_afiliado,
           dp.suma_asegurada AS suma_asegurada_cache
      FROM denuncia_poliza dp
      JOIN denuncias d ON d.id_denuncia = dp.id_denuncia
     WHERE dp.activo = 1
),
tope_excepcion AS (
    SELECT ap.id_denuncia,
           t.suma_asegurada,
           ROW_NUMBER() OVER (
               PARTITION BY ap.id_denuncia
               ORDER BY CASE WHEN t.ventana = 'ANUAL' THEN 0 ELSE 1 END,
                        t.id_tope DESC) AS prioridad
      FROM ap
      JOIN afiliados af ON af.id_afiliado = ap.id_afiliado
      JOIN polizas_ap_topes t
             ON t.id_poliza = ap.id_poliza
            AND t.nro_doc = TRIM(LEADING '0' FROM REPLACE(REPLACE(REPLACE(REPLACE(
                              af.nro_doc, ' ', ''), '.', ''), '-', ''), '/', ''))
     WHERE t.activo = 1
),
tope AS (
    SELECT ap.id_denuncia,
           ap.suma_asegurada_cache,
           CASE WHEN ex.suma_asegurada > 0 THEN ex.suma_asegurada
                WHEN pa.suma_asegurada > 0 THEN pa.suma_asegurada END AS vigente
      FROM ap
      LEFT JOIN tope_excepcion ex
             ON ex.id_denuncia = ap.id_denuncia
            AND ex.prioridad = 1
      LEFT JOIN polizas_ap pa ON pa.id_poliza = ap.id_poliza
)
SELECT 'V6g cache desactualizada' AS chequeo,
       id_denuncia,
       suma_asegurada_cache AS cache,
       vigente
  FROM tope
 WHERE suma_asegurada_cache IS NOT NULL
   AND (vigente IS NULL OR suma_asegurada_cache <> vigente);

-- V6.d · Cuánta plata deja afuera el anti-doble-conteo (debe ser > 0 y
--        hay que poder explicar cada peso)
SELECT 'V6d excluido a proposito' AS chequeo,
       SUM(CASE WHEN t.id_estado_turno IN (6,9,24,25)
                 AND t.valor_prestacion IS NOT NULL
                THEN t.valor_prestacion ELSE 0 END) AS turnos_que_no_ocurren,
       SUM(CASE WHEN t.valor_facturacion IS NOT NULL
                THEN COALESCE(t.valor_prestacion,0) ELSE 0 END) AS turnos_ya_facturados
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1;

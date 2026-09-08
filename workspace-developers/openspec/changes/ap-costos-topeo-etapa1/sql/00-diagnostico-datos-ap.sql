-- =====================================================================
-- AP — Costos y Topeo · DIAGNÓSTICO: de dónde sale la data del consumo
-- =====================================================================
-- TODO READ-ONLY. Ninguna sentencia escribe.
--
-- Para qué sirve: responder con números reales, antes de escribir una línea
-- de aplicación, cómo se va a ver el semáforo. Cada bloque corresponde a una
-- vía de consumo y dice cuánta data hay HOY para los 63 siniestros AP.
--
-- Orden de lectura: D0 (universo) → D1 (facturado, la primera entrega) →
-- D2..D5 (las otras vías) → D6 (dimensionamiento).
-- =====================================================================


-- =====================================================================
-- D0 · EL UNIVERSO AP — el filtro que hace todo lo demás barato
-- =====================================================================
-- Toda consulta del motor arranca por acá: acota de 450k denuncias a ~63.
SELECT 'D0 universo' AS diag,
       COUNT(DISTINCT dp.id_denuncia) AS denuncias_ap,
       COUNT(DISTINCT dp.id_poliza)   AS polizas_con_denuncia,
       COUNT(DISTINCT pa.id_empleador) AS empleadores
  FROM denuncia_poliza dp
  JOIN polizas_ap pa ON pa.id_poliza = dp.id_poliza
 WHERE dp.activo = 1;
-- ESPERADO (relevamiento 07/2026): 63 denuncias, <=30 pólizas.


-- =====================================================================
-- D1 · VÍA FACTURADO (erogaciones) — ES LA PRIMERA ENTREGA
-- =====================================================================
-- Esta es la query que alimenta el semáforo de la primera demo.
-- El dato YA EXISTE: no depende del hook del estimado ni de wsturnos.
SELECT 'D1 facturado x siniestro' AS diag,
       d.id_denuncia,
       d.nro_asignado,
       pa.poliza,
       pa.razon_social,
       COUNT(e.id_erogacion) AS cant_erogaciones,
       SUM(COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0)) AS facturado_neto,
       MIN(e.fecha_ingreso_factura) AS primera_factura,
       MAX(e.fecha_ingreso_factura) AS ultima_factura
  FROM denuncia_poliza dp
  JOIN denuncias   d  ON d.id_denuncia = dp.id_denuncia
  JOIN polizas_ap  pa ON pa.id_poliza  = dp.id_poliza
  LEFT JOIN erogaciones e ON e.id_denuncia = d.id_denuncia
 WHERE dp.activo = 1
 GROUP BY d.id_denuncia, d.nro_asignado, pa.poliza, pa.razon_social
 ORDER BY facturado_neto DESC;
-- QUÉ MIRAR: cuántos siniestros tienen facturado > 0 (esos son los que van a
-- mostrar semáforo real en la demo) y si la concentración sigue en una póliza.


-- D1.b · Cuántos siniestros AP tienen consumo facturado (resumen)
SELECT 'D1b cobertura facturado' AS diag,
       COUNT(*) AS total_siniestros_ap,
       SUM(CASE WHEN facturado_neto > 0 THEN 1 ELSE 0 END) AS con_facturado,
       ROUND(SUM(CASE WHEN facturado_neto > 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_con_facturado,
       SUM(facturado_neto) AS facturado_total_ap
  FROM (
    SELECT d.id_denuncia,
           SUM(COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0)) AS facturado_neto
      FROM denuncia_poliza dp
      JOIN denuncias d ON d.id_denuncia = dp.id_denuncia
      LEFT JOIN erogaciones e ON e.id_denuncia = d.id_denuncia
     WHERE dp.activo = 1
     GROUP BY d.id_denuncia
  ) t;


-- D1.c · Composición del facturado por tipo de erogación
-- Sirve para saber cuánto del consumo AP es medicación (tipo 4 = masivas).
SELECT 'D1c composicion' AS diag,
       e.id_tipo_erogacion,
       COUNT(*) AS cant,
       SUM(COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0)) AS monto
  FROM denuncia_poliza dp
  JOIN erogaciones e ON e.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1
 GROUP BY e.id_tipo_erogacion
 ORDER BY monto DESC;
-- NOTA: en el relevamiento global solo aparecen los tipos 3 (Simples) y
-- 4 (Masivas); los tipos 1/2 (MatQx/Ortopedia) no se usan en esta tabla.


-- =====================================================================
-- D2 · VÍA TURNOS — cuánto del estimado/devengado existe hoy en AP
-- =====================================================================
-- Mide el problema del 5,37% ACOTADO al universo AP (el global no sirve
-- para dimensionar esta entrega).
SELECT 'D2 turnos AP' AS diag,
       COUNT(*) AS turnos_ap,
       SUM(CASE WHEN t.id_estado_turno IN (19,23) THEN 1 ELSE 0 END) AS realizados,
       SUM(CASE WHEN t.valor_prestacion  > 0 THEN 1 ELSE 0 END) AS con_estimado,
       SUM(CASE WHEN t.valor_facturacion > 0 THEN 1 ELSE 0 END) AS con_facturado,
       SUM(CASE WHEN t.id_estado_turno IN (19,23) AND t.valor_prestacion > 0 THEN 1 ELSE 0 END) AS realizados_con_estimado,
       SUM(COALESCE(t.valor_prestacion,0))  AS suma_estimado,
       SUM(COALESCE(t.valor_facturacion,0)) AS suma_facturado_turnos
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1;
-- QUÉ MIRAR: `con_estimado` sobre `turnos_ap`. Si es tan bajo como el global,
-- confirma que el hook del estimado (entrega posterior) es imprescindible
-- para que la PROYECCIÓN sirva — pero no frena el semáforo por facturado.


-- D2.b · Anti-doble-conteo: turnos que ya están facturados
-- Estos NO deben aportar como devengado (el facturado sale de erogaciones).
SELECT 'D2b solape' AS diag,
       COUNT(*) AS turnos_con_valor_facturacion,
       SUM(CASE WHEN t.numero_factura IS NOT NULL THEN 1 ELSE 0 END) AS con_nro_factura,
       SUM(CASE WHEN t.id_estado_auditoria_facturacion = 1 THEN 1 ELSE 0 END) AS auditados
  FROM denuncia_poliza dp
  JOIN turnos t ON t.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1
   AND t.valor_facturacion IS NOT NULL;


-- =====================================================================
-- D3 · VÍA TRASLADOS
-- =====================================================================
-- Cobran REALIZADO(4) y NEGATIVO AUTORIZADO(8), y esos estados viven en
-- id_estado_logistica_ida / _vuelta (NO en id_estado_traslado).
SELECT 'D3 traslados AP' AS diag,
       COUNT(*) AS traslados_ap,
       SUM(CASE WHEN tr.id_estado_logistica_ida    IN (4,8) THEN 1 ELSE 0 END) AS ida_cobrable,
       SUM(CASE WHEN tr.id_estado_logistica_vuelta IN (4,8) THEN 1 ELSE 0 END) AS vuelta_cobrable,
       SUM(COALESCE(tr.monto_ida,0)     - COALESCE(tr.debito_ida,0))     AS monto_ida_neto,
       SUM(COALESCE(tr.monto_regreso,0) - COALESCE(tr.debito_regreso,0)) AS monto_vuelta_neto,
       SUM(CASE WHEN COALESCE(tr.monto_ida,0) = 0 AND tr.id_estado_logistica_ida IN (4,8)
                THEN 1 ELSE 0 END) AS cobrables_sin_monto
  FROM denuncia_poliza dp
  JOIN traslados tr ON tr.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1;
-- QUÉ MIRAR: `cobrables_sin_monto` = los que hay que estimar por convenio
-- (es la parte que negocio hoy resuelve "pidiendo un estimativo").


-- =====================================================================
-- D4 · VÍA CIRUGÍA — cuántas hay y si tienen costo armado
-- =====================================================================
SELECT 'D4 cirugias AP' AS diag,
       COUNT(DISTINCT c.id_cirugia) AS cirugias,
       COUNT(DISTINCT c.id_autorizacion) AS autorizaciones,
       SUM(CASE WHEN c.id_estado_cirugia = 1 THEN 1 ELSE 0 END) AS programadas
  FROM denuncia_poliza dp
  JOIN cirugias c ON c.id_denuncia = dp.id_denuncia
 WHERE dp.activo = 1;

-- D4.b · Honorarios valorizados (estado 2) de las cirugías AP
SELECT 'D4b honorarios' AS diag,
       COUNT(*) AS presupuestos,
       SUM(CASE WHEN pp.id_estado_pedido_presupuestos = 2 THEN 1 ELSE 0 END) AS valorizados,
       SUM(CASE WHEN pp.id_estado_pedido_presupuestos = 2
                THEN COALESCE(pp.valor_convenido,0) ELSE 0 END) AS monto_valorizado
  FROM denuncia_poliza dp
  JOIN cirugias c ON c.id_denuncia = dp.id_denuncia
  JOIN pedidos_presupuesto_prestaciones pp ON pp.id_autorizacion = c.id_autorizacion
 WHERE dp.activo = 1;

-- D4.c · Materiales — verificación del anti-doble-conteo por grupo
-- Muestra si en AP aparece el caso `grupo = 0/NULL` con montos distintos
-- (el que hacía perder plata al agrupar a secas).
SELECT 'D4c materiales grupos' AS diag,
       pm.id_pedido_material_quirurgico,
       de.grupo,
       COUNT(*) AS filas_del_grupo,
       COUNT(DISTINCT de.monto_cotizacion) AS montos_distintos,
       MAX(de.monto_cotizacion) AS monto_max,
       SUM(de.monto_cotizacion) AS suma_cruda_INCORRECTA
  FROM denuncia_poliza dp
  JOIN pedidos_materiales_quirurgicos pm ON pm.id_denuncia = dp.id_denuncia
  JOIN pedidos_materiales_quirurgicos_detalles de
       ON de.id_pedido_material_quirurgico = pm.id_pedido_material_quirurgico
 WHERE dp.activo = 1
 GROUP BY pm.id_pedido_material_quirurgico, de.grupo
HAVING montos_distintos > 1 OR filas_del_grupo > 1
 ORDER BY montos_distintos DESC, filas_del_grupo DESC;
-- QUÉ MIRAR: filas con `grupo` 0/NULL y montos_distintos > 1 → esas son las
-- que se deben sumar POR DETALLE, no colapsar por grupo.


-- =====================================================================
-- D5 · TOPES — cuánto falta cargar
-- =====================================================================
-- Hoy da 0 por definición (la columna no existe); sirve como línea de base
-- y, después del DDL, para medir el avance de la carga.
SELECT 'D5 polizas a cargar' AS diag,
       COUNT(*) AS polizas_ap_totales,
       COUNT(DISTINCT pa.id_empleador) AS empleadores,
       MIN(pa.fecha_desde) AS vigencia_min,
       MAX(pa.fecha_hasta) AS vigencia_max
  FROM polizas_ap pa;

-- D5.b · Asegurados distintos con siniestro AP (a cuántos hay que cargarles tope)
SELECT 'D5b asegurados' AS diag,
       COUNT(DISTINCT a.nro_doc) AS asegurados_con_siniestro
  FROM denuncia_poliza dp
  JOIN denuncias d  ON d.id_denuncia = dp.id_denuncia
  JOIN afiliados a  ON a.id_afiliado = d.id_afiliado
 WHERE dp.activo = 1;
-- (Ajustar el join a afiliados según el nombre real de la FK en denuncias.)


-- =====================================================================
-- D6 · DIMENSIONAMIENTO — ¿rinde la consulta?
-- =====================================================================
-- Verifica que el filtro por AP entra por índice y no barre las tablas.
EXPLAIN
SELECT d.id_denuncia,
       SUM(COALESCE(e.monto_facturado,0) - COALESCE(e.monto_debitado,0))
  FROM denuncia_poliza dp
  JOIN denuncias d ON d.id_denuncia = dp.id_denuncia
  LEFT JOIN erogaciones e ON e.id_denuncia = d.id_denuncia
 WHERE dp.activo = 1
 GROUP BY d.id_denuncia;
-- QUÉ MIRAR: que `erogaciones` se acceda por el índice de id_denuncia
-- (ref, no ALL). Si apareciera un full scan, hay que revisar el índice.

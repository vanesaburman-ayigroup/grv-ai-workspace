-- Cuerpos de los SP del listado de logistica en STAGE antes de INI-2 (20260819_124307)
-- Para restaurar uno: DROP PROCEDURE `<nombre>`; y correr su CREATE de abajo.

-- ===== consulta_traslado_remis_amb_logistica =====
CREATE DEFINER=`admin`@`%` PROCEDURE `consulta_traslado_remis_amb_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query LONGTEXT;
    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
    DECLARE tipoPrestacionId INT;
    DECLARE prestadorId INT;
    DECLARE nroSiniestro VARCHAR(50);
    DECLARE dniPaciente VARCHAR(15);
    DECLARE nombrePaciente VARCHAR(15);
    DECLARE apellidoPaciente VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
    DECLARE isEspontaneo VARCHAR(5);
    DECLARE tipoTransporteId INT;
   	DECLARE idDenuncia INT;
    DECLARE soloPrioritarios VARCHAR(5);
    DECLARE soloRequierenRevision VARCHAR(5);
    DECLARE idClientes LONGTEXT;
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);

    SET fechaDesde = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET tipoPrestacionId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoPrestacionId')), 'null');
    SET prestadorId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET nroSiniestro = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nroSiniestro')), 'null');
    SET dniPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniPaciente')), 'null');
    SET nombrePaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombrePaciente')), 'null');
    SET apellidoPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoPaciente')), 'null');
    SET clienteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET isEspontaneo = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.isEspontaneo')), 'null');
    SET tipoTransporteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoTransporteId')), 'null');
    SET idDenuncia = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idDenuncia')), 'null');
    SET soloPrioritarios = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloPrioritarios')), 'null');
    SET soloRequierenRevision = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloRequierenRevision')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');
    SET offset_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');

    SET where_clause = ' WHERE 1=1 AND (t.id_tipo_traslado IN (1, 2))';

    SET where_clause = CONCAT(where_clause,
       ' AND tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL');

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
            ' AND tu.fecha_turno BETWEEN CONCAT("', fechaDesde, ' 00:00:00") AND CONCAT("', fechaHasta, ' 23:59:59")');
    END IF;

    IF tipoPrestacionId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_tipo_turno = ', tipoPrestacionId);
    END IF;

    IF prestadorId IS NOT NULL THEN
       SET where_clause = CONCAT( where_clause,
	    ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
	    ' OR t.id_proveedor_servicio_traslado_vuelta = ', prestadorId,
		' OR (tah.id_proveedor_servicio_traslado = ', prestadorId,
    	' AND tah.id_etiqueta_agencia IN (1,2) ))');
    END IF;

    IF nroSiniestro IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (d.nro_asignado LIKE ''%', nroSiniestro, '%'' OR d.nro_provisorio LIKE ''%', nroSiniestro, '%'')');
    END IF;

    IF dniPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nro_doc = "', dniPaciente, '"');
    END IF;

    IF nombrePaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nombre LIKE "%', nombrePaciente, '%"');
    END IF;

    IF apellidoPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.apellido LIKE "%', apellidoPaciente, '%"');
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND d.id_empleador IN (SELECT e.id_empleador FROM empleadores e WHERE e.id_cliente = ', clienteId, ')');
    END IF;

    IF estadoId IS NOT NULL THEN
    	SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
	END IF;

    IF isEspontaneo IS NOT NULL THEN
    	IF isEspontaneo = 'true' THEN
        	SET where_clause = CONCAT(where_clause, ' AND t.es_espontaneo_asociado = 1');
        ELSE
        	SET where_clause = CONCAT(where_clause, ' AND t.es_espontaneo_asociado IS NULL');
        END IF;
    END IF;

    IF tipoTransporteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_tipo_traslado = ', tipoTransporteId, ' OR t.id_tipo_traslado_regreso = ', tipoTransporteId, ')');
    END IF;

    IF idDenuncia IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_denuncia = ', idDenuncia);
    END IF;

    IF soloPrioritarios IS NOT NULL AND soloPrioritarios = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.es_traslado_prioritario = 1');
    END IF;

    IF soloRequierenRevision IS NOT NULL AND soloRequierenRevision = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.requiere_revision = 1');
    END IF;

	IF idClientes IS NOT NULL AND idClientes != '' THEN
	   SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    SET sql_query = CONCAT('
        SELECT DISTINCT
            t.id_traslado as nro_traslado,
            t.id_turno as id_turno,
            COALESCE(d.nro_asignado, d.nro_provisorio) as nro_denuncia,
            d.id_denuncia as id_denuncia,
            a.nro_doc as dni_paciente,
            a.nombre as nombre_paciente,
            a.apellido as apellido_paciente,
            a.telefono as telefono_paciente,
            NULLIF(
                CONCAT_WS(
                    '''',
                    NULLIF(a.codigo_pais_celular, ''''),
                    NULLIF(a.codigo_area_celular, ''''),
                    NULLIF(a.numero_celular, '''')
                ),
                ''''
            ) as celular_paciente,
            tu.hora_turno as hora_traslado,
            DATE_FORMAT(tu.fecha_turno, "%d/%m/%Y") as fecha_traslado,
            c.nombre as cliente,
            CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
            t.id_tipo_traslado as id_tipo_traslado_ida,
            ttr.descripcion as descripcion_tipo_traslado_ida,
            t.id_tipo_traslado_regreso as id_tipo_traslado_vuelta,
            ttr.descripcion as descripcion_tipo_traslado_vuelta,
          	pst_ida.codigo AS codigo_agencia_ida,
			p_ida.razon_social AS descripcion_agencia_ida,
			pst_vuelta.codigo AS codigo_agencia_vuelta,
			p_vuelta.razon_social AS descripcion_agencia_vuelta,
            t.direccion_origen as origen_ida,
            t.direccion_destino as destino_ida,
			t.direccion_destino as origen_vuelta,
            t.direccion_destino_regreso as destino_vuelta,
            t.id_estado_traslado as estado_id,
            et.descripcion as estado_descripcion,
           	CASE WHEN t.es_espontaneo_asociado = 1 THEN TRUE ELSE FALSE END AS is_espontaneo,
            tu.id_tipo_turno as tipo_prestacion,
            tt.descripcion as prestacion,
			l1.nombre AS localidad_origen_ida,
			l2.nombre AS localidad_destino_ida,
            l2.nombre AS localidad_origen_vuelta,
			l3.nombre AS localidad_destino_vuelta,
			p1.nombre AS traslado_provincia_origen_ida,
    		p2.nombre AS traslado_provincia_destino_ida,
    		p2.nombre AS traslado_provincia_origen_vuelta,
    		p3.nombre AS traslado_provincia_destino_vuelta,
			NULL as apellido_empleado,
			NULL as nombre_empleado,
			NULL as dni_empleado,
            CASE WHEN t.id_tipo_viaje = 1 THEN FALSE ELSE TRUE END AS is_ida_vuelta,
			FALSE as is_transporte_publico,
			etl_ida.id_estado_logistica as estado_logistica_ida_id,
			etl_ida.descripcion as estado_logistica_ida_descripcion,
			etl_vuelta.id_estado_logistica as estado_logistica_vuelta_id,
			etl_vuelta.descripcion as estado_logistica_vuelta_descripcion,
			t.requiere_revision as requiere_revision,
            t.archivo_autorizacion_ambulancia as autorizacion_ambulancia,
            ti.id_satapp_ida as id_satapp_ida,
            ti.id_satapp_vuelta as id_satapp_vuelta,
            ti.id_moovear_ida as id_moovear_ida,
            ti.id_moovear_vuelta as id_moovear_vuelta,
            ptr.nombre as nombre_tramitador,
            ptr.apellido as apellido_tramitador
        FROM traslados t
        JOIN turnos tu ON t.id_turno = tu.id_turno
        JOIN denuncias d ON tu.id_denuncia = d.id_denuncia
        JOIN afiliados a ON d.id_afiliado = a.id_afiliado
		LEFT JOIN personas ptr ON ptr.id_persona = d.id_auditor
        JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
        JOIN tipos_traslados ttr ON t.id_tipo_traslado = ttr.id_tipo_traslado
        JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
        LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
        LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
		LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
		LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
		LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
		LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
		LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
		LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
		LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
		LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
		LEFT JOIN traslados_agencias_historico tah ON t.id_traslado = tah.id_traslado
		LEFT JOIN traslado_integraciones ti ON t.id_traslado = ti.id_traslado
    	', where_clause);

    IF sortOrder NOT IN ('ASC', 'DESC') THEN
	    SET sortOrder = 'DESC';
	END IF;

    SET sql_query = CONCAT( sql_query,
	    ' ORDER BY ',
	CASE
    	WHEN sortField = 'fechaTraslado' THEN CONCAT('tu.fecha_turno ', sortOrder) 
    	ELSE CONCAT('t.id_traslado ', sortOrder)
	END
	);

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('SELECT COUNT(DISTINCT t.id_traslado) INTO @total_records
	FROM traslados t
	JOIN turnos tu ON t.id_turno = tu.id_turno
	JOIN denuncias d ON tu.id_denuncia = d.id_denuncia
	JOIN afiliados a ON d.id_afiliado = a.id_afiliado
	LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
	LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
	LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
	LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
	JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
	JOIN tipos_traslados ttr ON t.id_tipo_traslado = ttr.id_tipo_traslado
	JOIN clientes c ON c.id_cliente = d.id_cliente
	LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
	LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
	LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
	LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
	LEFT JOIN traslados_agencias_historico tah ON t.id_traslado = tah.id_traslado
	', where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END

-- ===== consulta_traslados_aereos_logistica =====
CREATE DEFINER=`admin`@`%` PROCEDURE `consulta_traslados_aereos_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query LONGTEXT;
    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
	DECLARE tipoPrestacionId INT;
    DECLARE prestadorId INT;
    DECLARE nroSiniestro VARCHAR(50);
    DECLARE dniPaciente VARCHAR(15);
    DECLARE nombrePaciente VARCHAR(15);
    DECLARE apellidoPaciente VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
  	DECLARE idDenuncia INT;
    DECLARE soloRequierenRevision VARCHAR(5);
    DECLARE idClientes LONGTEXT;
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);

    SET fechaDesde = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET tipoPrestacionId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoPrestacionId')), 'null');
    SET prestadorId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET nroSiniestro = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nroSiniestro')), 'null');
    SET dniPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniPaciente')), 'null');
    SET nombrePaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombrePaciente')), 'null');
    SET apellidoPaciente = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoPaciente')), 'null');
    SET clienteId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET idDenuncia = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idDenuncia')), 'null');
    SET soloRequierenRevision = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloRequierenRevision')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');
    SET offset_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');

    SET where_clause = ' WHERE 1=1 ';

    SET where_clause = CONCAT(where_clause,
       ' AND tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL');

    
    SET where_clause = CONCAT(where_clause,
       ' AND tu.id_estado_turno NOT IN (1, 2, 4, 9, 12, 13, 14, 15, 16, 17, 18, 26)');

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
            ' AND tu.fecha_turno BETWEEN CONCAT("', fechaDesde, ' 00:00:00") AND CONCAT("', fechaHasta, ' 23:59:59")');
    END IF;

    IF tipoPrestacionId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND tu.id_tipo_turno = ', tipoPrestacionId);
    END IF;

    IF prestadorId IS NOT NULL THEN
        SET where_clause = CONCAT( where_clause,
	    ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
	    ' OR t.id_proveedor_servicio_traslado_regreso = ', prestadorId, ')');
    END IF;

    IF nroSiniestro IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (d.nro_asignado LIKE ''%', nroSiniestro, '%'' OR d.nro_provisorio LIKE ''%', nroSiniestro, '%'')');
    END IF;

    IF dniPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nro_doc = "', dniPaciente, '"');
    END IF;

    IF nombrePaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.nombre LIKE "%', nombrePaciente, '%"');
    END IF;

    IF apellidoPaciente IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND a.apellido LIKE "%', apellidoPaciente, '%"');
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND d.id_empleador IN (SELECT e.id_empleador FROM empleadores e WHERE e.id_cliente = ', clienteId, ')');
    END IF;

    IF estadoId IS NOT NULL THEN
    	SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
	END IF;

    IF idDenuncia IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.id_denuncia = ', idDenuncia);
    END IF;

    IF soloRequierenRevision IS NOT NULL AND soloRequierenRevision = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.requiere_revision = 1');
    END IF;

	IF idClientes IS NOT NULL AND idClientes != '' THEN
	   SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    SET sql_query = CONCAT('
        SELECT DISTINCT
            t.id_traslado as nro_traslado,
            t.id_turno as id_turno,
            COALESCE(d.nro_asignado, d.nro_provisorio) as nro_denuncia,
            t.id_denuncia as id_denuncia,
            a.nro_doc as dni_paciente,
            a.nombre as nombre_paciente,
            a.apellido as apellido_paciente,
            a.telefono as telefono_paciente,
            NULLIF(
                CONCAT_WS(
                    '''',
                    NULLIF(a.codigo_pais_celular, ''''),
                    NULLIF(a.codigo_area_celular, ''''),
                    NULLIF(a.numero_celular, '''')
                ),
                ''''
            ) as celular_paciente,
		    tu.hora_turno as hora_traslado,
    		DATE_FORMAT(tu.fecha_turno, "%d/%m/%Y") AS fecha_traslado,
            c.nombre as cliente,
            CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
            t.id_tipo_traslado_ida as id_tipo_traslado_ida,
            ttr.descripcion as descripcion_tipo_traslado_ida,
            t.id_tipo_traslado_vuelta as id_tipo_traslado_vuelta,
            ttr.descripcion as descripcion_tipo_traslado_vuelta,
            pst_ida.codigo AS codigo_agencia_ida,
		    p_ida.razon_social AS descripcion_agencia_ida,
		    pst_vuelta.codigo AS codigo_agencia_vuelta,
		    p_vuelta.razon_social AS descripcion_agencia_vuelta,
            t.origen_ida as origen_ida,
            t.destino_ida as destino_ida,
            t.destino_ida as origen_vuelta,
            t.destino_vuelta as destino_vuelta,
            t.id_estado_traslado as estado_id,
            et.descripcion as estado_descripcion,
		    NULL as is_espontaneo,
            tu.id_tipo_turno as tipo_prestacion,
            tt.descripcion as prestacion,
            l1.nombre AS localidad_origen_ida,
            l2.nombre AS localidad_destino_ida,
            l2.nombre AS localidad_origen_vuelta,
            l3.nombre AS localidad_destino_vuelta,
		    p1.nombre AS traslado_provincia_origen_ida,
    		p2.nombre AS traslado_provincia_destino_ida,
    		p2.nombre AS traslado_provincia_origen_vuelta,
    		p3.nombre AS traslado_provincia_destino_vuelta,
		    NULL as apellido_empleado,
		    NULL as nombre_empleado,
		    NULL as dni_empleado,
		    CASE WHEN t.id_tipo_viaje = 1 THEN FALSE ELSE TRUE END AS is_ida_vuelta,
		    TRUE as is_transporte_publico,
		    etl_ida.id_estado_logistica as estado_logistica_ida_id,
		    etl_ida.descripcion as estado_logistica_ida_descripcion,
		    etl_vuelta.id_estado_logistica as estado_logistica_vuelta_id,
		    etl_vuelta.descripcion as estado_logistica_vuelta_descripcion,
		    t.requiere_revision as requiere_revision,
			ptr.nombre as nombre_tramitador,
		    ptr.apellido as apellido_tramitador,
		    NULL as autorizacion_ambulancia,
            NULL as id_satapp_ida,
            NULL as id_satapp_vuelta,
            NULL as id_moovear_ida,
            NULL as id_moovear_vuelta
        FROM traslados_transporte_publico t
        JOIN turnos tu ON t.id_turno = tu.id_turno
        JOIN denuncias d ON t.id_denuncia = d.id_denuncia
        JOIN afiliados a ON d.id_afiliado = a.id_afiliado
		LEFT JOIN personas ptr ON ptr.id_persona = d.id_auditor
        JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
        JOIN tipos_traslados ttr ON t.id_tipo_traslado_ida = ttr.id_tipo_traslado
        JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
        LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_regreso = pst_vuelta.id_proveedor_servicio_traslado
        LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
        LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
        LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
        LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
	    LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
	    LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
	    LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
        LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado
	    LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
	    LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
    ', where_clause);

     IF sortOrder NOT IN ('ASC', 'DESC') THEN
	    SET sortOrder = 'DESC';
	END IF;

    SET sql_query = CONCAT( sql_query,
	    ' ORDER BY ',
	CASE
    	WHEN sortField = 'fechaTraslado' THEN CONCAT('tu.fecha_solicitada ', sortOrder)
    	ELSE CONCAT('t.id_traslado ', sortOrder)
	END
	);

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('SELECT COUNT(DISTINCT t.id_traslado) INTO @total_records
		FROM traslados_transporte_publico t
		JOIN turnos tu ON t.id_turno = tu.id_turno
		JOIN denuncias d ON t.id_denuncia = d.id_denuncia
		JOIN afiliados a ON d.id_afiliado = a.id_afiliado
		LEFT JOIN proveedores_servicios_traslados pst_ida ON t.id_proveedor_servicio_traslado_ida = pst_ida.id_proveedor_servicio_traslado
		LEFT JOIN proveedores p_ida ON pst_ida.id_proveedor = p_ida.id_proveedor
		LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_regreso = pst_vuelta.id_proveedor_servicio_traslado
		LEFT JOIN proveedores p_vuelta ON pst_vuelta.id_proveedor = p_vuelta.id_proveedor
		JOIN tipos_turnos tt ON tu.id_tipo_turno = tt.id_tipo_turno
		JOIN tipos_traslados ttr ON t.id_tipo_traslado_ida = ttr.id_tipo_traslado
		JOIN clientes c ON c.id_cliente = d.id_cliente
		LEFT JOIN localidades l1 ON t.id_localidad_origen_ida = l1.id_localidad
		LEFT JOIN localidades l2 ON t.id_localidad_destino_ida = l2.id_localidad
		LEFT JOIN localidades l3 ON t.id_localidad_destino_vuelta = l3.id_localidad
		LEFT JOIN estados_traslados et ON t.id_estado_traslado = et.id_estado_traslado',
		where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END

-- ===== consulta_traslados_internos_logistica =====
CREATE DEFINER=`admin`@`%` PROCEDURE `consulta_traslados_internos_logistica`(IN filters longtext, OUT total_records bigint)
BEGIN
    DECLARE sql_query    LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE total_query  LONGTEXT;

    DECLARE fechaDesde DATE;
    DECLARE fechaHasta DATE;
    DECLARE prestadorId INT;
    DECLARE dniEmpleado VARCHAR(15);
    DECLARE nombreEmpleado VARCHAR(15);
    DECLARE apellidoEmpleado VARCHAR(15);
    DECLARE clienteId INT;
    DECLARE estadoId INT;
    DECLARE tipoTransporteId INT;
    DECLARE soloPrioritarios VARCHAR(5);
    DECLARE offset_json INT;
    DECLARE limit_json INT;
    DECLARE sortOrder VARCHAR(4);
    DECLARE sortField VARCHAR(50);
    DECLARE isTransportePublico VARCHAR(5);
    DECLARE idClientes LONGTEXT;

    SET fechaDesde        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaDesde')), 'null');
    SET fechaHasta        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.fechaHasta')), 'null');
    SET prestadorId       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.prestadorId')), 'null');
    SET dniEmpleado       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.dniEmpleado')), 'null');
    SET nombreEmpleado    = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.nombreEmpleado')), 'null');
    SET apellidoEmpleado  = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.apellidoEmpleado')), 'null');
    SET clienteId         = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.clienteId')), 'null');
    SET estadoId          = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.estadoId')), 'null');
    SET tipoTransporteId  = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.tipoTransporteId')), 'null');
    SET soloPrioritarios = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.soloPrioritarios')), 'null');
    SET offset_json       = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.offset')), 'null');
    SET limit_json        = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.limit')), 'null');
    SET sortOrder         = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortOrder')), 'DESC');
    SET sortField         = COALESCE(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.sortField')), 'fechaTraslado');
    SET isTransportePublico = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.isTransportePublico')), 'null');
    SET idClientes = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(filters, '$.idClientes')), 'null');

    SET where_clause = ' WHERE 1=1';

    IF fechaDesde IS NOT NULL AND fechaHasta IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.fecha_traslado BETWEEN ', QUOTE(fechaDesde), ' AND ', QUOTE(fechaHasta));
    END IF;

    IF prestadorId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause,
                                  ' AND (t.id_proveedor_servicio_traslado_ida = ', prestadorId,
                                  ' OR t.id_proveedor_servicio_traslado_vuelta = ', prestadorId, ')');
    END IF;

    IF dniEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.nro_doc = ', QUOTE(dniEmpleado));
    END IF;

    IF nombreEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.nombre LIKE ', QUOTE(CONCAT('%', nombreEmpleado, '%')));
    END IF;

    IF apellidoEmpleado IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND pe.apellido LIKE ', QUOTE(CONCAT('%', apellidoEmpleado, '%')));
    END IF;

    IF clienteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND t.id_cliente = ', clienteId);
    END IF;

    IF estadoId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_estado_logistica_ida = ', estadoId, ' OR t.id_estado_logistica_vuelta = ', estadoId, ')');
    END IF;

    IF isTransportePublico IS NOT NULL AND isTransportePublico = 'true' THEN
        SET where_clause = CONCAT(where_clause,' AND (t.id_tipo_traslado_ida IN (4,5) OR t.id_tipo_traslado_vuelta IN (4,5))');
    ELSEIF tipoTransporteId IS NOT NULL THEN
        SET where_clause = CONCAT(where_clause, ' AND (t.id_tipo_traslado_ida = ', tipoTransporteId, ' OR t.id_tipo_traslado_vuelta = ', tipoTransporteId, ')');
    END IF;

    IF idClientes IS NOT NULL AND idClientes != '' THEN
        SET where_clause = CONCAT(where_clause, ' AND  d.id_cliente IN (' ,  idClientes, ') ');
    END IF;

    IF soloPrioritarios IS NOT NULL AND soloPrioritarios = 'true' THEN
        SET where_clause = CONCAT(where_clause, ' AND t.traslado_prioritario = 1');
    END IF;

    IF sortOrder NOT IN ('ASC', 'DESC') THEN
        SET sortOrder = 'DESC';
    END IF;

    SET
        sql_query = CONCAT('
  SELECT DISTINCT
  t.id_traslado_interno                         AS nro_traslado,
  NULL                                          AS id_turno,
  NULL                                          AS nro_denuncia,
  NULL                                          AS id_denuncia,
  NULL                                          AS dni_paciente,
  NULL                                          AS nombre_paciente,
  NULL                                          AS apellido_paciente,
  NULL                                          AS telefono_paciente,
  NULL                                          AS celular_paciente,
  t.hora_traslado                               AS hora_traslado,
  DATE_FORMAT(t.fecha_traslado, "%d/%m/%Y")     AS fecha_traslado,
  c.nombre                                      AS cliente,
  CASE WHEN c.autoseguro_habilitado_empleadores = 1 THEN TRUE ELSE FALSE END AS is_cliente_autoasegurado,
  t.id_tipo_traslado_ida                        AS id_tipo_traslado_ida,
  ttr.descripcion                               AS descripcion_tipo_traslado_ida,
  t.id_tipo_traslado_vuelta                     AS id_tipo_traslado_vuelta,
  ttra.descripcion                              AS descripcion_tipo_traslado_vuelta,
  pst_ida.codigo                                AS codigo_agencia_ida,
  p_ida.razon_social                            AS descripcion_agencia_ida,
  pst_vuelta.codigo                             AS codigo_agencia_vuelta,
  p_vuelta.razon_social                         AS descripcion_agencia_vuelta,
  t.origen_ida                                  AS origen_ida,
  t.destino_ida                                 AS destino_ida,
  t.origen_vuelta                               AS origen_vuelta,
  t.destino_vuelta                              AS destino_vuelta,
  t.id_estado_traslado                          AS estado_id,
  et.descripcion                                AS estado_descripcion,
  NULL                                          AS is_espontaneo,
  NULL                                          AS tipo_prestacion,
  NULL                                          AS prestacion,
  l1.nombre                                     AS localidad_origen_ida,
  l2.nombre                                     AS localidad_destino_ida,
  l3.nombre                                     AS localidad_origen_vuelta,
  l4.nombre                                     AS localidad_destino_vuelta,
  p1.nombre AS traslado_provincia_origen_ida,
  p2.nombre AS traslado_provincia_destino_ida,
  p2.nombre AS traslado_provincia_origen_vuelta,
  p3.nombre AS traslado_provincia_destino_vuelta,
  pe.apellido                                   AS apellido_empleado,
  pe.nombre                                     AS nombre_empleado,
  pe.nro_doc                                AS dni_empleado,
  CASE WHEN t.id_tipo_viaje = 1 THEN 0 ELSE 1 END        AS is_ida_vuelta,
  CASE WHEN t.id_tipo_traslado_ida IN (4,5) THEN 1 ELSE 0 END AS is_transporte_publico,
  etl_ida.id_estado_logistica                   AS estado_logistica_ida_id,
  etl_ida.descripcion                           AS estado_logistica_ida_descripcion,
  etl_vuelta.id_estado_logistica                AS estado_logistica_vuelta_id,
  etl_vuelta.descripcion                        AS estado_logistica_vuelta_descripcion,
  NULL                                          AS requiere_revision,
  NULL                                          AS nombre_tramitador,
  NULL                                          AS apellido_tramitador,
  NULL as autorizacion_ambulancia,
  ti.id_satapp_ida as id_satapp_ida,
  ti.id_satapp_vuelta as id_satapp_vuelta,
  ti.id_moovear_ida as id_moovear_ida,
  ti.id_moovear_vuelta as id_moovear_vuelta
FROM traslados_internos t
  JOIN tipos_traslados ttr   ON t.id_tipo_traslado_ida    = ttr.id_tipo_traslado
  LEFT JOIN tipos_traslados ttra  ON t.id_tipo_traslado_vuelta = ttra.id_tipo_traslado
  JOIN clientes c            ON t.id_cliente              = c.id_cliente
  JOIN personas pe           ON t.id_persona              = pe.id_persona
  LEFT JOIN proveedores_servicios_traslados pst_ida   ON t.id_proveedor_servicio_traslado_ida   = pst_ida.id_proveedor_servicio_traslado
  LEFT JOIN proveedores p_ida                        ON pst_ida.id_proveedor                    = p_ida.id_proveedor
  LEFT JOIN proveedores_servicios_traslados pst_vuelta ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
  LEFT JOIN proveedores p_vuelta                     ON pst_vuelta.id_proveedor                 = p_vuelta.id_proveedor
  LEFT JOIN estados_traslados et                     ON t.id_estado_traslado                    = et.id_estado_traslado
  LEFT JOIN localidades l1 ON t.id_localidad_origen_ida      = l1.id_localidad
  LEFT JOIN localidades l2 ON t.id_localidad_destino_ida     = l2.id_localidad
  LEFT JOIN localidades l3 ON t.id_localidad_origen_vuelta   = l3.id_localidad
  LEFT JOIN localidades l4 ON t.id_localidad_destino_vuelta  = l4.id_localidad
  LEFT JOIN provincias p1 ON l1.id_provincia = p1.id_provincia
  LEFT JOIN provincias p2 ON l2.id_provincia = p2.id_provincia
  LEFT JOIN provincias p3 ON l3.id_provincia = p3.id_provincia
  LEFT JOIN estados_traslados_logistica etl_ida ON t.id_estado_logistica_ida = etl_ida.id_estado_logistica
  LEFT JOIN estados_traslados_logistica etl_vuelta ON t.id_estado_logistica_vuelta = etl_vuelta.id_estado_logistica
  LEFT JOIN traslado_integraciones ti ON t.id_traslado_interno = ti.id_traslado_interno
    ', where_clause);

    SET sql_query = CONCAT(sql_query,
                           ' ORDER BY ',
                           CASE
                               WHEN sortField = 'fechaTraslado' THEN CONCAT('t.fecha_traslado ', sortOrder)
                               ELSE CONCAT('t.id_traslado_interno ', sortOrder)
                               END
                    );

    IF limit_json IS NOT NULL AND offset_json IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' LIMIT ', limit_json, ' OFFSET ', offset_json);
    END IF;

    PREPARE stmt FROM sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SET @total_records = 0;

    SET total_query = CONCAT('
    SELECT COUNT(DISTINCT t.id_traslado_interno) INTO @total_records
    FROM traslados_internos t
      LEFT JOIN proveedores_servicios_traslados pst_ida     ON t.id_proveedor_servicio_traslado_ida   = pst_ida.id_proveedor_servicio_traslado
      LEFT JOIN proveedores p_ida                            ON pst_ida.id_proveedor                    = p_ida.id_proveedor
      LEFT JOIN proveedores_servicios_traslados pst_vuelta  ON t.id_proveedor_servicio_traslado_vuelta = pst_vuelta.id_proveedor_servicio_traslado
      LEFT JOIN proveedores p_vuelta                         ON pst_vuelta.id_proveedor                 = p_vuelta.id_proveedor
      JOIN tipos_traslados ttr   ON t.id_tipo_traslado_ida    = ttr.id_tipo_traslado
      LEFT JOIN tipos_traslados ttra  ON t.id_tipo_traslado_vuelta = ttra.id_tipo_traslado
      JOIN clientes c            ON c.id_cliente              = t.id_cliente
      JOIN personas pe           ON pe.id_persona             = t.id_persona
      LEFT JOIN estados_traslados et ON t.id_estado_traslado  = et.id_estado_traslado
      LEFT JOIN localidades l1 ON t.id_localidad_origen_ida      = l1.id_localidad
      LEFT JOIN localidades l2 ON t.id_localidad_destino_ida     = l2.id_localidad
      LEFT JOIN localidades l3 ON t.id_localidad_origen_vuelta   = l3.id_localidad
      LEFT JOIN localidades l4 ON t.id_localidad_destino_vuelta  = l4.id_localidad
    ', where_clause);

    PREPARE stmt2 FROM total_query;
    EXECUTE stmt2;
    SELECT @total_records INTO total_records;
    DEALLOCATE PREPARE stmt2;

    SET sql_query = NULL;
    SET where_clause = NULL;
    SET total_query = NULL;
END


-- Cuerpo de consulta_turnos_tramitadores_sp en STAGE antes de aplicar INI-2 (20260819_104136)
-- Para restaurar: DROP PROCEDURE `consulta_turnos_tramitadores_sp`; y correr el CREATE de abajo.

CREATE DEFINER=`admin`@`%` PROCEDURE `consulta_turnos_tramitadores_sp`(IN filtros longtext, OUT total_registros int)
BEGIN

    DECLARE select_clause LONGTEXT;
    DECLARE from_clause LONGTEXT;
    DECLARE where_clause LONGTEXT;
    DECLARE order_clause LONGTEXT;
    DECLARE sql_query LONGTEXT;
    DECLARE tipo_orden VARCHAR(4);
    DECLARE comodin_like_inicio VARCHAR(3) DEFAULT '\'%';
    DECLARE comodin_like_fin VARCHAR(2) DEFAULT '%\'';
    DECLARE tramitador VARCHAR(1000);
    DECLARE sentido_orden VARCHAR(4); 

    SET @tramitador = 'null';

    SET @from_clause = ' FROM turnos T
    	LEFT JOIN denuncias d ON d.id_denuncia = T.id_denuncia
        LEFT JOIN afiliados A ON d.id_afiliado = A.id_afiliado
        LEFT JOIN empleadores E ON d.id_empleador = E.id_empleador
        LEFT JOIN clientes c ON d.id_cliente = c.id_cliente
        LEFT JOIN severidades S ON d.id_severidad = S.id_severidad
		LEFT JOIN autorizaciones AUT ON AUT.id_autorizacion = T.id_autorizacion
        LEFT JOIN personas P ON d.id_auditor = P.id_persona ';

    SET @where_clause = ' WHERE d.activo = 1 ';

    SET @order_clause = ' ORDER BY d.fecha_ocurrencia desc';

    IF JSON_VALID(filtros) IS NOT NULL THEN

        
        SET @filtro_id_gestores = REPLACE(REPLACE(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idGestores')), '[', ''), ']', '');
        SET @filtro_id_tramitador = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTramitadorLogueado'));

        IF @filtro_id_tramitador IS NOT NULL AND @filtro_id_tramitador != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_auditor = ', @filtro_id_tramitador);
        END IF;
        
        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.misDenuncias')) = 'true' THEN
            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND COALESCE(d.es_asignacion_temporal, 0) = 0'
                                );
        ELSEIF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.denunciasOtros')) = 'true' THEN
            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND d.es_asignacion_temporal = 1'
                                );
        END IF;

        IF (@filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '')
            OR (@filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '') THEN
            
            IF @filtro_id_gestores IS NOT NULL AND @filtro_id_gestores != '' THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND d.id_auditor IN (', @filtro_id_gestores, ')'
                                    );
            ELSE
                
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND d.id_auditor = ', @filtro_id_gestores
                                    );
            END IF;
        END IF;

        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.esOrdenarDesc')) = 'true' THEN
            SET sentido_orden = 'desc';
        ELSE
            SET sentido_orden = 'asc';
        END IF;

        SET @idTipoTurno = CAST(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoTurno')) AS UNSIGNED);
        
        IF (JSON_EXTRACT(filtros, '$.pendienteProgramar')) = true THEN
            SET @where_clause = CONCAT(@where_clause,
                                       ' AND (T.id_estado_turno in (14, 15, 16, 17) AND AUT.id_estado_autorizacion not in (3, 5)) ',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1))
                                       AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ) '
                                );

            
            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NULL '
                                    );
            END IF;
        END IF;

        
        IF (JSON_EXTRACT(filtros, '$.pendienteProcesar')) = true THEN
            SET @where_clause = CONCAT(@where_clause,
                                       ' AND (T.id_estado_turno in (0, 3, 4, 5, 1, 2, 7, 10, 11, 12, 13, 18, 22) AND AUT.id_estado_autorizacion in (0, 2, 4) AND TIMESTAMP(DATE(T.fecha_turno), CAST(T.hora_turno AS TIME)) < NOW())',
                                       ' AND T.fecha_turno >= NOW() - INTERVAL 180 DAY',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR  ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1)) AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) )');

            
            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NOT NULL '
                                    );
            END IF;
        END IF;

        
        IF (JSON_EXTRACT(filtros, '$.pendienteAprobar')) = true THEN
            SET @where_clause = CONCAT(@where_clause, ' AND (AUT.id_estado_autorizacion = 1)',
                                       ' AND  ( (d.id_estado_medico = 1 AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) ',
                                       ' OR  ((d.id_estado_medico = 2 OR (d.id_estado_medico = 9 AND d.es_sin_baja_laboral = 1)) AND (d.es_rechazado = 0 OR d.es_rechazado IS NULL)) )');

            IF @idTipoTurno = 4 THEN
                SET @where_clause = CONCAT(
                        @where_clause,
                        ' AND T.id_tipo_turno = 4
                        AND T.fecha_turno IS NOT NULL '
                                    );
            END IF;
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')) != '' THEN
            SET @where_clause =
                    CONCAT(@where_clause, ' AND T.id_turno = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTurno')));
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND A.nro_doc LIKE ', comodin_like_inicio,
                                       JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.dniPaciente')), comodin_like_fin, ' ');
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND (d.nro_provisorio LIKE ',
                                       CONCAT(comodin_like_inicio, JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')),
                                              comodin_like_fin),
                                       ' OR d.nro_asignado LIKE ',
                                       CONCAT(comodin_like_inicio, JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nroDenuncia')),
                                              comodin_like_fin),
                                       ')');
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')) != '' THEN
            SET @afiliado = REPLACE(JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.nombreApellidoPaciente')), '"', '');
            SET  @afiliado = REGEXP_REPLACE( @afiliado, '\\s+', ' ');
            SET  @afiliado = LTRIM(RTRIM( @afiliado));

            SET @where_clause = CONCAT(
                    @where_clause,
                    ' AND CONCAT(CONVERT(TRIM(A.nombre) USING utf8mb4), " ", CONVERT(TRIM(A.apellido) USING utf8mb4)) ',
                    'COLLATE utf8mb4_spanish_ci LIKE "%',
                    @afiliado,
                    '%" COLLATE utf8mb4_spanish_ci'
                                );
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.ordenIdTurno')) IS NOT NULL THEN
            SET @order_clause = CONCAT(' ORDER BY T.id_turno ', sentido_orden);
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.ordenDenuncia')) IS NOT NULL THEN
            SET @order_clause = CONCAT(' ORDER BY COALESCE(d.nro_asignado, d.nro_provisorio) ', sentido_orden);
        END IF;

        
        SET @idClasificacionSiniestros := JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idClasificacionSiniestros'));
        IF @idClasificacionSiniestros IS NOT NULL THEN
            SET @where_clause := CONCAT(@where_clause, ' AND ', consulta_filtro_clasificacion_siniestros_tramitadores(@idClasificacionSiniestros));
        END IF;

        
        SET @idCuentas := JSON_UNQUOTE(JSON_EXTRACT(filtros,'$.idCuentas'));
        IF @idCuentas IS NOT NULL AND @idCuentas != '' THEN
            SET @from_clause = CONCAT(@from_clause, ' LEFT JOIN cuentas_empleadores_sas ces ON d.id_empleador = ces.id_empleador ');
            SET @where_clause = CONCAT(@where_clause, ' AND  ces.id_cuenta IN (' ,  @idCuentas, ') ');
        END IF;

        
        SET @filtro_idClientes = JSON_UNQUOTE(JSON_EXTRACT(filtros,'$.idClientes'));
        IF @filtro_idClientes IS NOT NULL AND @filtro_idClientes != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND  d.id_cliente IN (' ,  @filtro_idClientes, ') ');
        END IF;
       
       
        SET @filtro_idEmpleadores = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idEmpleadores'));
        IF @filtro_idEmpleadores IS NOT NULL AND @filtro_idEmpleadores != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_empleador IN (', @filtro_idEmpleadores, ')');
        END IF;

        
        SET @filtro_idEstadosMedico = JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idEstadosMedico'));
        IF @filtro_idEstadosMedico IS NOT NULL AND @filtro_idEstadosMedico != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_estado_medico IN (', @filtro_idEstadosMedico, ')');
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_tipo_siniestro = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idTipoSiniestroAccidente')));
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND d.id_severidad = ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.idSeveridad')));
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_denuncia) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_denuncia) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaDenunciaHasta')), '")');
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_ocurrencia) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_ocurrencia) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaOcurrenciaHasta')), '")');
        END IF;

        
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_alta) >= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaDesde')), '")');
        END IF;
        IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')) IS NOT NULL
            AND JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')) != '' THEN
            SET @where_clause = CONCAT(@where_clause, ' AND DATE(d.fecha_alta) <= DATE("', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.fechaAltaHasta')), '")');
        END IF;
        
        
		IF (JSON_EXTRACT(filtros, '$.solicitaPrestador')) = true THEN
			SET @where_clause = CONCAT(@where_clause, ' AND AUT.id_estado_autorizacion = 9',
													  ' AND T.solicitada_prestador IS TRUE');
		END IF;

		
		IF (JSON_EXTRACT(filtros, '$.evolutivoInformePrestador')) = true THEN
			SET @where_clause = CONCAT(@where_clause, ' AND T.id_estado_turno = 23',
													  ' AND T.solicitada_prestador IS TRUE');
		END IF;

    END IF;

    SET @select_clause = CONCAT('SELECT SQL_CALC_FOUND_ROWS
    T.id_turno as "idTurno",
	d.id_denuncia as "idDenuncia",
    d.nro_asignado as "nroAsignado",
    d.nro_provisorio as "nroProvisorio",
    CONCAT(A.nombre, " ", A.apellido) as "paciente",
    E.es_vip as "esVip",
    A.nro_doc as "nroDocPaciente",
    E.razon_social as "razonSocialEmpleador",
    c.nombre AS cliente,
    S.descripcion as "severidad",
    d.id_estado_medico as "idEstadoMedico",
	d.es_sin_baja_laboral as "esSinBajaLaboral",
	d.es_rechazado as "esRechazado",
    CONCAT(DATE(T.fecha_turno), " ", T.hora_turno) as "fechaTurno",
	CONCAT(P.nombre, " ", P.apellido) as "analista",
    T.fecha_solicitada as "fechaSolicitada",
    AUT.fecha_autorizacion as "fechaAutorizacion", 
	AUT.id_autorizacion as "idAutorizacion", 
	AUT.id_tipo_turno_solicitado as "idTipoTurno", ',
                                @tramitador, ' as "tramitador"');

    
    SET @sql_query = CONCAT(@select_clause, @from_clause, @where_clause, @order_clause);

    
    IF JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.limit')) IS NOT NULL AND
       JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.offset')) IS NOT NULL THEN
        SET @sql_query = CONCAT(@sql_query, ' LIMIT ', JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.limit')), ' OFFSET ',
                                JSON_UNQUOTE(JSON_EXTRACT(filtros, '$.offset')));
    END IF;

    PREPARE stmt FROM @sql_query;

    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT FOUND_ROWS() INTO total_registros;


    SET @select_clause = NULL;
    SET @where_clause = NULL;
    SET @from_clause = NULL;
    SET @order_clause = NULL;
    SET @sql_query = NULL;

END

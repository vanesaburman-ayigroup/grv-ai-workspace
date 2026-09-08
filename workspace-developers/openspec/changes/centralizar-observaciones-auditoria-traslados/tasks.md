## 1. Base de datos — DDL de la tabla unificada (migración)

- [x] 1.1 Confirmar en réplica (MCP MariaDB read-only) el `DESCRIBE cs.traslados` y `DESCRIBE cs.traslados_internos` para cerrar la lista definitiva de columnas de observación y su nullability (cierra el mapeo de D3) — RESUELTO 18/06/2026: 16 + 11 columnas, mapeo cerrado en D3
- [ ] 1.2 Script 1 (DDL): `CREATE TABLE IF NOT EXISTS cs.traslados_observaciones` (`id` BIGINT PK AUTO_INCREMENT; `id_traslado` BIGINT NULL; `id_traslado_interno` BIGINT NULL; `tramo` ENUM('IDA','VUELTA','GENERAL') NOT NULL; `origen` ENUM('TRAMITADOR','CEM','LOGISTICA','PEAJE','ESTACIONAMIENTO','SATAPP','AUDITORIA') NOT NULL; `subtipo` VARCHAR(40) NULL; `texto` TEXT NOT NULL; `usuario_sistema` VARCHAR(120) NULL; `fecha_hora` DATETIME NOT NULL) ENGINE=InnoDB, `utf8mb4_unicode_ci`, índices `(id_traslado)` y `(id_traslado_interno)`, CONSTRAINT `chk_to_exactamente_un_id`
- [ ] 1.3 Incluir `CHECK ((id_traslado IS NULL) <> (id_traslado_interno IS NULL))` (DECIDIDO; MariaDB 10.5.29 lo evalúa). Fallback si `mariadb-migration-review` lo objeta por costo en el backfill masivo: quitar el CHECK y validar CP-20 con query de control post-backfill
- [ ] 1.4 Revisar el Script 1 con el skill `mariadb-migration-review`
- [ ] 1.5 Aplicar el DDL en STAGE y verificar que la tabla queda creada con charset/índices correctos

## 2. Backend — dual-write por módulo (convivencia)

- [ ] 2.1 `wstraslados`: al escribir `observaciones`/`observaciones_regreso`/`observaciones_traslado`/`observaciones_control`/`observacion_traslado_negativo`/`observacion_datos_pool`/`observaciones_desestimo`/`observaciones_anulacion`, insertar además en `traslados_observaciones` (`origen='TRAMITADOR'`, `subtipo` según columna — NULL para gestión, CONTROL/TRASLADO_NEGATIVO/DATOS_POOL/DESESTIMO/ANULACION para las demás —, tramo según columna), en la misma transacción. NO quitar la escritura de la columna histórica
- [ ] 2.2 `wslogistica` — CEM: al escribir `traslados_internos.observaciones_ida/_vuelta`, dual-write `origen='CEM'`
- [ ] 2.3 `wslogistica` — logística operativa: `observaciones_logistica`/`_traslado_prioritario`/`_habilita_espera`/`observaciones_base_ida/_vuelta` → dual-write `origen='LOGISTICA'`
- [ ] 2.4 `wslogistica` — peaje: `observaciones_peaje_ida/_vuelta` → dual-write `origen='PEAJE'`
- [ ] 2.5 `wslogistica` — anulación de vuelta (`observaciones_anulacion_vuelta`) → dual-write `origen='TRAMITADOR'`, `subtipo='ANULACION'`, tramo VUELTA
- [ ] 2.6 `wslogistica` — `agregarObservaciones` (SATAPP, `TrasladoServiceImpl.java:2541-2598`): mantener la concatenación actual (convivencia, **de-enfatizada en el front** para no duplicar) y **además** insertar fila `origen='SATAPP'`, `usuario_sistema='SATAPP'`, tramo según ida/vuelta — el feed atribuye SATAPP desde el día 1 del dual-write
- [ ] 2.7 `wslogistica` — estacionamiento: **follow-up, NO en esta fase** (hoy embebido en texto libre, sin fuente estructurada). El `origen='ESTACIONAMIENTO'` queda reservado en el ENUM; entrará por dual-write cuando logística estructure la observación
- [ ] 2.8 `wsauditoriatraslados`: al guardar `observacionAuditoria`, dual-write `origen='AUDITORIA'`, `usuario_sistema`=usuario del auditor
- [ ] 2.9 Atomicidad: el insert va en la **misma transacción** que la columna histórica cuando el módulo la maneja; si es best-effort y falla, loguear sin bloquear la operación principal (la columna histórica es el respaldo) — el backfill idempotente reconcilia lo faltante

## 3. Base de datos — backfill (migración DML, separada del DDL)

- [ ] 3.1 Script 2 (DML): backfill idempotente `INSERT ... SELECT ... WHERE NOT EXISTS` desde las 27 columnas de observación de `traslados` (16) y `traslados_internos` (11), mapeando columna → `origen`/`subtipo`/`tramo` (tablas de mapeo de D3). El mismo `WHERE NOT EXISTS` reconcilia lo que el dual-write best-effort no haya escrito
- [ ] 3.2 Estrategia de `fecha_hora` histórica: mejor fecha disponible del traslado; documentar si se cae a `NOW()` de la corrida
- [ ] 3.3 SATAPP embebido: separar el fragmento de SATAPP por etiquetas (`[Peaje:..]`/`[Estacionamiento:..]`/`[Espera:..]`) solo cuando es inequívoco (dos filas TRAMITADOR+SATAPP); si es ambiguo, conservar como TRAMITADOR y marcar para revisión (no perder texto)
- [ ] 3.4 Revisar el Script 2 con `mariadb-migration-review`; planificar lotes y ventana de bajo tráfico por el volumen de `traslados` (~1.47M)
- [ ] 3.5 Ejecutar el backfill en STAGE **después** de habilitar el dual-write; verificar idempotencia (segunda corrida no duplica)

## 4. Backend — lectura del feed unificado (auditoría)

- [ ] 4.1 `wsauditoriatraslados`: proyección/endpoint que devuelve las observaciones de un traslado desde `traslados_observaciones`, ordenadas por `fecha_hora, id` (desempate estable) y con `origen`/`subtipo`/`tramo`, agrupables/filtrables
- [ ] 4.2 Exponer el feed como datos **nuevos y opcionales**, sin alterar ni quitar los campos actuales del drawer (`observaciones`, `detalle`, `detalleLogistica`, `observacionAuditoria`, estado de logística)
- [ ] 4.3 Verificar que el backend es desplegable antes que el front del feed sin romper la pantalla actual

## 5. Frontend — feed de observaciones en el drawer

- [ ] 5.1 Crear componente custom **prop-driven y SOLID** (DECIDIDO: `sas-component-lib` no tiene hoy timeline con atribución por origen + filtro; recibe lista + config de orígenes/subtipos; no conoce el dominio de auditoría). Reusar si aparece uno apto durante la implementación
- [ ] 5.2 Mapear cada `origen` a ícono + color de la **paleta SAS** (teal `#0ddcd6`/`#0A8F8B`, grises `#3C4043`/`#5F6368`/`#9AA0A6`, bg `#F4F5F6`, line `#DADCE0`); asignación exacta con UX
- [ ] 5.3 Filtro por origen (y por subtipo dentro de TRAMITADOR) con chips/checkboxes que muestra/oculta sin recargar; orden de feed `fecha_hora, id`
- [ ] 5.4 Wiring en el drawer **simple** (`FormAuditar.tsx`) y **múltiple** (`AuditarTabla.tsx`)
- [ ] 5.5 Modo de **transición**: el feed convive con la presentación histórica (cajas actuales); la información visible nunca es menor a la actual. La caja histórica **de-enfatiza** la etiqueta SATAPP embebida para no mostrar SATAPP dos veces (mitigación de doble visualización, ver D2/D4/CP-12)
- [ ] 5.6 Aparecen en el feed las fuentes antes no visibles, distinguibles por `subtipo` (control, traslado negativo, datos pool, anulación, desestimo). Estacionamiento NO en esta fase (follow-up)

## 6. Pruebas y verificación

- [ ] 6.1 Backend: test funcional del dual-write (la observación queda en la columna histórica y en `traslados_observaciones` con el `origen` correcto)
- [ ] 6.2 Backend: test del backfill idempotente (segunda corrida no duplica; SATAPP embebido se separa solo cuando es inequívoco)
- [ ] 6.3 Backend: test de la lectura del feed (orden cronológico, atribución de origen/tramo, contrato actual del drawer intacto)
- [ ] 6.4 Frontend: test del componente de feed (render por origen, filtro por origen, sin término = sin filtro) y de la convivencia de ambas vistas
- [ ] 6.5 Verificación E2E manual en STAGE: drawer simple y múltiple, las 7 fuentes de origen, filtro por origen, comparación feed vs cajas históricas

## 7. Documentación y cierre

- [ ] 7.1 Documentar en runbook el resultado del `DESCRIBE` (lista definitiva de columnas), el universo SATAPP "marcado para revisión" del backfill, y la fecha histórica usada
- [ ] 7.2 Documentar los **criterios de consolidación final** (D7) y dejar registrado que la consolidación es una entrega posterior
- [ ] 7.3 `mr-comments` para los MR de backend (`wstraslados`/`wslogistica`/`wsauditoriatraslados`) y frontend (`auditoriafacturacion`), con link cruzado entre ellos y a este change de OpenSpec

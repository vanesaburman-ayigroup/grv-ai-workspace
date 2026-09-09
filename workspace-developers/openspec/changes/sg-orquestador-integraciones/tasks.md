## 1. wssolicitudesgenericas — modelo de datos

- [x] 1.1 Migración: agregar columna `sistema_origen` (nullable) a la entidad/tabla `SolicitudGenerica`
- [x] 1.2 Migración: crear tabla de alcance por sistema (`sistema`, `id_tipo_solicitud`, `puede_alta`, `puede_consulta`)
- [x] 1.3 Actualizar entidad `TiposSolicitudesGenericas`/`SolicitudGenerica` y repos JPA para leer/escribir `sistema_origen`

## 2. wssolicitudesgenericas — reutilizar validación de denuncia obligatoria (GRV-1929)

> Corrección: la validación ya existe (`SolicitudesGenericaCommonsImpl.validarDenunciaRequerida`,
> invocada desde `SolicitudesGenericasServiceCompose.altaSolicitudGenerica`). No se crea de nuevo —
> se conecta al camino de alta externa, que llama a `crearSolicitudGenerica` sin pasar por el compose.

- [x] 2.1 Confirmar que el nuevo punto de entrada para alta externa invoca `validarDenunciaRequerida` antes de `crearSolicitudGenerica`
- [x] 2.2 Test: alta externa rechazada sin denuncia cuando el tipo la requiere — `SolicitudGenericaServiceExternoImplTest.altaExterna_sinDenunciaYTipoLaRequiere_lanzaDenunciaRequeridaException` — MR !504
- [x] 2.3 Test: alta externa aceptada con denuncia cuando el tipo la requiere — `SolicitudGenericaServiceExternoImplTest.altaExterna_conDenunciaInformadaYTipoLaRequiere_creaLaSolicitud` — MR !504
- [x] 2.4 Test: alta externa sin cambios para tipos con `requiereDenuncia = false` — `SolicitudGenericaServiceExternoImplTest.altaExterna_sinDenunciaYTipoNoLaRequiere_creaLaSolicitudSinRechazo` — MR !504
- [x] 2.5 Confirmado que el SAS no tiene cambio de comportamiento: `SolicitudesGenericasServiceCompose.java` no fue tocado por TAR-15 (0 líneas de diff contra `develop`), y el único diff en `SolicitudesGenericaCommonsImpl.java` son 6 líneas que solo copian `sistemaOrigen`/`referenciaExterna` (quedan en `null` en el alta clásica). Test de regresión: `SolicitudesGenericaCommonsImplCrearTest.crearSolicitudGenerica_altaClasicaSinSistemaOrigen_persisteIgualQueAntes` — MR !504. Suite completa corrida localmente: 4/4 tests OK

## 3. wssolicitudesgenericas — endpoint de alta/consulta para uso del Orquestador

- [x] 3.1 Definir DTO de alta para llamadas de sistema externo (sin `idGestor`, con `sistemaOrigen` obligatorio y `idAreaGestion` resuelto) — `SolicitudGenericaExternaRequestDTO`
- [x] 3.2 Adaptar/crear el punto de entrada de alta para que acepte derivación exclusiva a área cuando el origen es externo — `SolicitudGenericaServiceExternoImpl.altaExterna` + `SolicitudGenericaExternoController`
- [x] 3.3 Endpoint o filtro de consulta que acote listado/detalle al `sistemaOrigen` del llamador — `GET /solicitudesgenericas/externas`, `GET /solicitudesgenericas/externas/{id}`
- [x] 3.4 Asegurar que la respuesta de consulta para origen externo no incluya nombre de gestor — `SolicitudGenericaExternaResponseDTO` (sin campo gestor)
- [x] 3.5 Mecanismo mínimo de idempotencia: aceptar y validar una clave de idempotencia por alta, rechazar duplicados — `referencia_externa` + `findBySistemaOrigenAndReferenciaExterna`

## 4. wsorquestadorintegraciones — API externa

- [x] 4.1 Agregar `GCBA` (provider por cliente, piloto — no `PORTAL_CLIENTES` genérico) a `security.api-keys.clients` — MR !96
- [x] 4.2 Nuevo controller `SolicitudesGenericasExternalController` bajo `/V1/external/solicitudes-genericas` — MR !96
- [x] 4.3 Endpoint POST de alta: reenvía a `wssolicitudesgenericas`, que valida el alcance por sistema — MR !96
- [x] 4.4 Endpoint GET de listado: acota por sistema autenticado (`authentication.getName()`) — MR !96
- [x] 4.5 Endpoint GET de detalle: rechaza si la SG no pertenece al sistema autenticado — MR !96
- [x] 4.6 Manejo de errores: propaga el status embebido en el body de `wssolicitudesgenericas` (SB2 legacy sin `ResponseEntity`, siempre HTTP 200 en transporte) — MR !96
- [ ] 4.7 Tests de integración: alta con API key válida/inválida, alcance permitido/no permitido, idempotencia — pendiente (`wsorquestadorintegraciones` no tiene `src/test`)
- [x] 4.8 Secreto compartido `X-INTERNAL-SECRET` entre el Orquestador y el endpoint interno de `wssolicitudesgenericas` — MR !96 (envío) + MR !504 (validación, fail-safe). Real en los 4 ambientes (dev/test/stage/prod) en ambos repos.
- [x] 4.9 `idSolicitante` real del usuario logueado en Portal (no cuenta de servicio) — corrección post-implementación, MR !504 + MR !96

## 5. Frontend SAS — visibilidad del sistema de origen

- [x] 5.1 Agregar columna/indicador de sistema de origen en la tabla de Solicitudes Genéricas (`grvx/frontend/solicitudesgenericas`) — **ampliado 2/9 (ver 7.7)**: además de la columna, agregar tratamiento visual (badge/color/resaltado de fila) para que salte a la vista en la grilla mezclada con el resto, no solo un dato más — confirmado implementado y funcionando en TEST (columna "SISTEMA ORIGEN" en la grilla interna) por QA (Leandro Bouza, exploración 08/09, OBS-005)
- [ ] 5.2 Verificar que las SG sin sistema de origen (SAS) se muestran igual que hoy

## 7. Pivote 2/9 — tipos de solicitud dedicados al canal cliente (reunión con Lucas Alama)

> Reemplaza el enfoque de reusar tipos existentes (161/160/113/112). Ver design.md, sección
> "Pivote 2/9". El contrato de los endpoints (3.1-3.5, 4.1-4.9) no cambia.

- [x] 7.1 Nombre final y convención visual: `Cliente - Consulta`/`Cliente - Reclamo`/`Cliente - Pedido` — cerrado, ver sección 8 (validado en las maquetas)
- [x] 7.2 Insertar los 3 tipos nuevos en `tipos_solicitudes_genericas` con `denuncia_requerida = 0` — ids 166/167/168 (Cliente - Consulta/Reclamo/Pedido), `id_categoria=1` igual que los tipos de referencia viejos — MR !504
- [x] 7.2b Confirmar que `idDenuncia` opcional sigue soportado en el alta externa aun con `denuncia_requerida = 0` en el tipo — ya cubierto por `SolicitudGenericaExternaRequestDTO.idDenuncia` (opcional desde el inicio), sin cambio de código
- [x] 7.3 Mapear los 3 tipos nuevos a las 7 áreas confirmadas (Tramitadores, Auditoría Médica, Call Center, Logística, Contrataciones, Mesa de Carga, Traslados) en `areas_gestion_solicitudes_genericas_tipo_solicitud` — **corregido 2/9 (segunda ronda)**: área dueña = pseudo-área nueva "Portal Cliente" (creada en el mismo seed), las 7 áreas reales son `id_area_gestion_derivada` — 21 filas — MR !504
- [x] 7.4 Reescribir `TAR-15-sg-seed-gcba.sql` para reemplazar los tipos de referencia viejos (161/160/113/112) por los 3 nuevos + su mapeo a las 7 áreas vía "Portal Cliente" — verificado por código que el alta externa no consulta esta tabla (no hay riesgo de romper el flujo externo) — MR !504
- [ ] 7.4b Definir si hace falta un mapeo N×N adicional entre las 7 áreas reales para que un jefe/referente pueda re-derivar manualmente una SG del cliente ya recibida hacia otra de las 7 (el modelo actual, vía "Portal Cliente", no lo habilita por cómo filtra `findAreasGestion`) — no implementar sin confirmar que se necesita
- [x] 7.5a Confirmado para Tramitadores: la SG ya cae hoy a un responsable del área (no a un gestor puntual) — sirve tal cual para el caso del cliente
- [x] 7.5b Confirmado por código (`SolicitudesGenericaCommonsImpl`, columna `id_es_responsable` en `areas_gestion_solicitudes_genericas_personas`) y por datos: es un comportamiento GENÉRICO del sistema, no específico de área. Las 7 áreas confirmadas ya tienen responsables cargados (Call Center 11, Tramitadores 31, Auditoría Médica 5, Logística 12, Contrataciones 4, Traslados 4, Mesa de Carga 8)
- [x] 7.6 Resuelto sin trabajo nuevo — ver 7.5b. No hace falta diseñar ni estimar nada de código para este punto
- [x] 7.7a Marca especial en la grilla del tablero de SG (badge/color/ícono en la fila) para que un responsable de área identifique de un vistazo cuáles SG vinieron del cliente, mezcladas en la lista general — precisado 2/9: es ampliación de la tarea 5.1 (mismo dato `sistema_origen`, falta el tratamiento visual en `grvx/frontend/solicitudesgenericas`), no una sección/pestaña nueva — confirmado implementado y visible en TEST (badge "GCBA" en la grilla interna) por QA (re-exploración 08/09, OBS-004)
- [ ] 7.7b Card nueva (tipo KPI/resumen, ej. "N SG de cliente pendientes") en la pantalla de SG de `grvx/frontend/solicitudesgenericas`, visible de entrada sin depender de escanear la grilla — componente nuevo, distinto del badge de 7.7a
- [ ] 7.8 Actualizar el catálogo de tipos para Javier (Google Sheet) para reflejar que GCBA usará estos 3 tipos nuevos, no el catálogo completo

## 8. Pantallas de Portal de Clientes — copiar y adaptar (NO es un MFE, NO se monta)

> Aclarado por la usuaria 2/9: Portal de Clientes no es un microfrontend y no monta ninguno de los
> MFE del SAS. La implementación real es copiar el JSX/lógica de las pantallas de
> `grvx/frontend/solicitudesgenericas` al proyecto propio de Portal y adaptarlo — no referenciar
> este repo en runtime. Maqueta de referencia (descartable, no commiteada) armada en
> `dev-standalone/GcbaNuevaSolicitud.jsx` de este repo, para visualizar el formulario de alta.

- [x] 8.1 Maqueta del formulario de alta (`FormularioNuevaSolicitudGenerica.js` adaptado): tipo de
  solicitud acotado a los 3 tipos cliente, selector de área de destino (las 7 reales, lo elige el
  usuario de Portal), SIN gestor, CON fecha de vencimiento y fecha de advertencia (confirmado que sí
  van, a diferencia de un supuesto inicial equivocado) — corrida en `localhost:8177`, **validada por
  la usuaria de negocio**
- [x] 8.1b Maquetas adicionales validadas, mismo harness (`localhost:8177`, selector de pantalla):
  tablero de Portal (`GcbaTableroSolicitudes.jsx`, reusa el componente real de grilla con
  `gestoresPorDefecto=false`), grilla en denuncia completa sin columna gestor
  (`GcbaGrillaDenuncia.jsx`), detalle de SG sin gestor/responsable (`GcbaDetalleSolicitud.jsx`), y
  comparación del lado SAS interno con la card "SG recibidas del cliente" + franja de color en la
  fila (`GcbaTableroInterno.jsx`, ver 7.7a/7.7b) — todas descartables, no commiteadas
- [x] 8.1c Comparado contra la referencia real (STAGE, usuario `ayi.logistica`, módulo Logística →
  Solicitudes Genéricas, recorrido con Playwright) — confirma tablero, cards, filtros, columnas y
  la mayoría de los campos del formulario coinciden con lo ya implementado (ver design.md, pivote
  2/9, tercera ronda)
- [x] 8.1d Gap real encontrado en la comparación: falta "Adjuntar archivo" en
  `NuevaSolicitudGenerica.js` de Portal — el formulario real (Logística) lo tiene — implementado:
  `DrawerNuevaSolicitud.js` maneja estado de `archivo` y lo pasa al `Formulario`/payload de alta
- [x] 8.1e Gap real encontrado: el real es un `Drawer` lateral abierto desde el tablero, no una
  página ruteada aparte — coincide además con el patrón que ya usa Portal en
  `ConsultasReclamos/DrawerNuevaConsulta`. Convertir `NuevaSolicitudGenerica.js` en el contenido de
  un drawer invocado desde el tablero (8.2), en vez de mantenerlo como ruta propia — implementado
  como `components/SolicitudesGenericas/DrawerNuevaSolicitud.js`
- [x] 8.2 Tablero principal de SG en Portal: portar el patrón de `SolicitudesGenericas.js` (monta
  `TableroCustom` + botón "Nueva Solicitud" vía `DrawerNuevaSGSinDenuncia` + `TablaSolicitudesGenericasCustom`),
  filtrado para que Portal **solo vea las SG desde/hacia sistema Portal Cliente** (filtro por
  `sistema_origen`, no existe hoy este filtro del lado del backend expuesto a Portal — confirmar
  si los endpoints `GET /solicitudesgenericas/externas` ya alcanzan para esto o falta algo) —
  confirmado funcionando end-to-end en TEST (menú "Solicitudes Genéricas", tablero con cards,
  grilla con columna N° Denuncia) por QA (re-exploración 08/09, OBS-N3)
- [x] 8.1f Bug encontrado por QA (re-exploración 08/09, BUG-N1, severidad Alta): las fechas de
  vencimiento/advertencia elegidas por el cliente en el formulario de Portal se enviaban en el
  payload pero se perdían en el camino — `SolicitudGenericaExternaRequestDTO` (contrato externo de
  `wssolicitudesgenericas`) nunca tuvo estos dos campos, así que el alta externa siempre pisaba lo
  elegido con el default fijo (alta + 30/15 días), sin avisar nada. Corregido agregando los campos
  (opcionales, con el mismo fallback de siempre si no vienen) en las 3 capas de la cadena
  (`wssolicitudesgenericas`, `wsorquestadorintegraciones` × 2 DTOs) — commits `0f8a56c`
  (wssolicitudesgenericas) y `e7746a2` (wsorquestadorintegraciones), en `develop` y `release`.
  Pendiente: que QA re-confirme en TEST tras el próximo deploy.
- [x] 8.2b Resuelto: todo usuario de Portal se comporta como "operador" (solo ve sus propias SG
  enviadas) — por ahora no hay vista tipo supervisor para Portal. Al portar `TableroCustom.js`
  (`SolicitudesGenericas/TableroCustom/TableroCustom.js:41`), alcanza con el equivalente a
  `TableroOperador` como único comportamiento; no hace falta portar `TableroSupervisor`.
- [x] 8.3 Sin botón "Consultar todas las SGs" en Portal — confirmado que existe hoy en el SAS
  (`FiltroSolicitudesGenericas.js:48-55`, abre un dialog con `searchTodasSG` sin acotar por área/
  denuncia) — al portar la pantalla, este botón directamente no se incluye
- [x] 8.3b Corrección: en la tabla del tablero principal, la columna GESTOR no se condiciona por
  `isOperador` (eso solo afecta la fecha) — se filtra con `gestoresPorDefecto=false` + `activeTab=0`
  (`TablaSolicitudesGenericas/TablaSolicitudesGenericas.js:287-293`). Para Portal alcanza con pasar
  esos props al mismo componente real, sin forkearlo — usado en la maqueta del tablero (8.2c)
- [x] 8.4 Grilla de SG dentro del detalle de siniestro/denuncia (menú secundario "Solicitudes
  Genéricas" de Portal, análoga a `SolicitudesGenericasPorDenuncia.js` → usa
  `DenunciaCompleta/TablaSolicitudesGenericas.js`, un archivo **distinto** al del tablero): esta
  variante **tiene columna "GESTOR" incondicional** (líneas 199-220, sin ningún flag que la saque)
  — al portar a Portal, sacar esta columna por completo del código, no hay flag para ocultarla —
  confirmado funcionando en TEST: la sección "Solicitudes Genéricas" en el detalle de denuncia crea
  SG asociadas a esa denuncia puntual (columna N° Denuncia completa) por QA (re-exploración 08/09,
  OBS-N4)
- [x] 8.5 Detalle de SG en Portal: remover toda referencia a gestor/responsable de los componentes
  equivalentes a `DetalleSolicitudGenerica.js` (usa `AsignarGestor`), `DatosDeSolicitudGenerica.js`
  (usa `CambiarGestor`, label "gestor", campo `row.responsable`), `CabeceraDatosDenuncia.js` (label
  "Gestor:", campo `gestor`/`tramitadorNombreCompleto`), y `MasInformacion/CardSolicitudDetalle.js`
  + `MasInformacionDetalle.js` (label "solicitanteResponsable", botón "gestorSolicitado"/
  `handleAsignarGestor`) — son 5 componentes distintos con referencias a gestor, no uno solo —
  resuelto: la implementación real de Portal (`components/SolicitudesGenericas/DrawerDetalle.js`)
  es un componente propio sin ningún campo/label de gestor, no un port literal de los 5 archivos
  legacy; confirmado por código (grep sin resultados de "gestor"/"responsable" salvo un ícono de
  tipo de evento de historial) y por QA (3 SG de prueba creadas sin gestor asignado, OBS-N3)

## 6. Documentación y cierre

- [ ] 6.1 Documentar en `docs/openApi.yaml` de `wsorquestadorintegraciones` los endpoints nuevos
- [ ] 6.2 Registrar en `CHANGELOG.md` de `wsorquestadorintegraciones` y `wssolicitudesgenericas` (crear si no existe)
- [ ] 6.3 Confirmar con Javier (GCBA) el contrato final antes del 11/9 y coordinar con el equipo de Portal de Clientes su integración contra `/V1/external/solicitudes-genericas`
- [ ] 6.4 Elevar a Gerencia las decisiones pendientes documentadas en proposal.md/design.md (alcance por sistema definitivo, área de derivación por tipo, fecha de MuleSoft, prioridad de SIMP)

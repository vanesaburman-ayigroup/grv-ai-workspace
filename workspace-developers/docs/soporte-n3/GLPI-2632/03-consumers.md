# GLPI 2632 - consumers-of `cs.cd_cartas` / `cs.cd_modulos`

Verificado el 2026-10-07 sobre `repos/grvx/` en su estado local (sin fetch) y contra BD (MCP MariaDB, solo SELECT; `@@hostname` = ip-172-19-1-132, es PROD).
Escaneo: 107 carpetas backend (incluye worktrees `*-wt-*`), 36 frontend.

## Veredicto: NO hay que tocar codigo
El alta es solo datos. Las cartas se leen dinamicamente de la tabla; nadie hardcodea `id_carta`, `numero_carta` ni listas de cartas.

## Verificacion en BD
- `cd_cartas`: UK `uq_cd_cartas_modulo_numero (id_modulo, numero_carta)`, `id_carta` AUTO_INCREMENT (proximo 68; MAX actual 64; 52 filas), FK a `cd_modulos`.
- Modulo 7 (OTRAS CITACIONES): cartas 1..6, el 7 esta libre. Modulo 8 (RECHAZOS): 1..16 activas; la 17 "PENDIENTE DEFINICION POR CLIENTE" tiene activo=0, el 18 esta libre. La 17 no se toca ni se reutiliza.
- Ninguna de las 2 descripciones existe (solo hay "TELEGRAMA / CD citacion serologia p/ laboratorio", id 33, distinta).
- `cd_modulos` ya tiene 7 y 8 activos: no hay que tocarla.
- `tipos_solicitudes_genericas.id_tipo_solicitud_generica = 158` es "Solicitud de CD (GCBA AUTOSEGURO)" (singular). Confirmado. El 159 es "Solicitud de TL".
- Unico tipo que usa estos modulos: 158 (8533 solicitudes, 4761 con modulo/carta). Ningun otro tipo referencia `id_cd_modulo`/`id_cd_carta`. Solo `solicitudes_genericas` apunta a estas tablas (`id_cd_modulo`, `id_cd_carta`). No hay otras tablas `cd_*`.

## Consumidores
Ningun ws escribe en `cd_cartas`/`cd_modulos` (sin `@Modifying` ni INSERT en Java). Las altas se hacen por SQL manual (precedente: `wstramitador/src/main/resources/sql/scripts/insert_cartas_sg.sql`, INSERT plano).

### wslistados (lectura del catalogo) - severidad media
| Tipo | Archivo:linea | Detalle |
|---|---|---|
| mapping-table | `entities/CdCarta.java:13`, `entities/CdModulo.java:11` | `@Table` cd_cartas / cd_modulos |
| query-read | `repositories/CdCartaRepository.java:11` | `findByModuloIdModuloAndActivoTrue` (filtra activo=1; sin lista fija) |
| query-read | `repositories/CdModuloRepository.java:11` | `findByActivoTrue` |
| consume-call | `service/CartaDocumentoServiceImpl.java:26,34`; `controller/CartaDocumentoController.java:38,49` | `findAllModulos` / `findCartasByModulo(idModulo)` |

(Copia identica en el worktree `wslistados-wt-filtro-ap-cliente`, sin uso productivo.)

### wssolicitudesgenericas - severidad media
| Tipo | Archivo:linea | Detalle |
|---|---|---|
| mapping-table | `entities/CdCarta.java:13`, `entities/CdModulo.java:11` | entidades |
| FK-write | `service/SolicitudesGenericaCommonsImpl.java:1264-1268` | guarda `new CdModulo(id)` / `new CdCarta(id)` recibidos del front (por id) |
| read | `service/SolicitudesGenericaCommonsImpl.java:152-157` | lee cdModulo/cdCarta de la solicitud |
| class-call | `service/SolicitudGenericaServiceReclamoImp.java:293-297,379-392` | si tipo = `ID_TIPO_SOLICITUD_CD` (158, `utils/consts/Constantes.java:126`) renombra el archivo de cierre `CD - {modulo sin prefijo} - CARTA N{numero_carta} - {idSolicitud}.ext`. Generico: 7 y 18 salen bien. |
| dto | `dto/solicitudesGenericas/SolicitudGenericaRequestDTO.java:33-34` | `idCdModulo`, `idCdCarta` |

### Frontend `solicitudesgenericas` - severidad media
| Tipo | Archivo:linea | Detalle |
|---|---|---|
| consume-call | `src/redux/actions/listados.js:179-223` | `fetchCdModulos` / `fetchCdCartas(idModulo)` -> {codigo: id, descripcion}; sin lista fija |
| consume-call | `components/SolicitudesGenericas/DenunciaCompleta/FormularioNuevaSolicitudGenerica.js:156,170,215,383-405` | selects modulo/carta solo para tipo 158 (`utils/const.js:226 CD_AUTOSEGURO: 158`); envia ids |
| read | `components/SolicitudesGenericas/DetalleSolicitudGenerica/DatosDeSolicitudGenerica.js:175` | muestra datos de CD en el detalle |

(`build/...86.grv-solicitudes-genericas.js` es artefacto compilado, ignorado.)

### Sin hits
wstramitador (y worktrees) solo contiene el script SQL de insert, no codigo. Ningun otro ws/MFE escaneado referencia `cd_cartas`, `cd_modulos`, `id_cd_carta` ni `id_cd_modulo`: sin SPs, vistas, reportes, enums, cachés ni validaciones por modulo/carta.

## Checklist
- Ids de carta fijos: ninguno (solo el literal 158, que es tipo de solicitud).
- Listas/enums de numero_carta: ninguno. Cache: ninguna (consulta directa).
- Validaciones por modulo: ninguna; el unico uso de modulo/carta es el renombre del archivo de cierre.
- Orden en pantalla: sin `OrderBy` explicito (sale por PK); las nuevas (id 68/69) quedan al final de su modulo, coincide con numero 7 y 18.
- Tras el INSERT no hace falta redeploy ni reinicio: el combo se llena por consulta al elegir modulo.
- Limite: busqueda por texto sobre java/sql/js/ts/properties en `src`; SQL dinamico armado por concatenacion de nombres no se detectaria, pero no se hallo ninguno.

# GLPI 2892 - consumidores de `cs.tipo_facturacion`

**Tipo**: table | **Scope**: all (`repos/grvx`, ramas principales; los `-wt-*` son worktrees duplicados) | **BD**: `@@hostname = ip-172-19-1-132` (PROD, solo SELECT, 2026-10-07)

## Veredicto

**No hay que tocar código. Alcanza con el INSERT (`01-script.sql`).**
Ningún consumidor ramifica por `id_tipo_facturacion` ni por la descripción (0 hits de `switch`/`if`/`CASE` por id o texto; no hay signo, tope ni chequeo de duplicados por tipo). El catálogo es dato puro: se lista, se guarda el id y se muestra la descripción. La única dependencia textual es "la descripción termina en la letra", que cumple `Nota de Débito A/B/C/M`.

Pregunta de negocio (no bloquea el alta): hoy nada resta ni invierte signo según el tipo, así que una nota de débito se carga y suma como cualquier comprobante (coherente: una ND aumenta el importe). Una **nota de crédito** sí exigiría código (resta); no se pidió. Confirmar con el solicitante: (a) solo ND A/B/C/M o también MiPyme (en `cs.tipo_factura` existen), (b) monto positivo.

## Estructura (PROD)
- `cs.tipo_facturacion(id_tipo_facturacion INT PK AUTO_INCREMENT, descripcion VARCHAR(100) NOT NULL)`, latin1, AUTO_INCREMENT=10. Sin `activo` ni `orden`. 9 filas: 1 Factura A, 2 Factura B, 3 Factura C, 4 Recibo A, 5 Ticket factura A, 6 Recibo B, 7 Recibo C, 8 Recibo M, 9 Factura M.
- `cs.tipo_factura` (otra tabla, 21 filas) ya tiene `Nota de Débito A` (11), `C` (19), `MiPyme A/C` (20/21) y NC; no tiene ND B ni M. Se alineó el nombre ("Nota de Débito X"). No se toca.
- FKs hacia la tabla: `auditoria_facturacion_log.id_tipo_facturacion` (ibfk_1), `erogaciones_masivas_job_log.id_tipo_factura` (ibfk_3), `materiales_quirurgicos_erogacion_log.id_tipo_facturacion` (fk_tipo_facturacion). Sin FK pero con la columna: `erogaciones`, `pedidos_materiales_quirurgicos_detalles` (y 2 backups de erogaciones).
- Uso actual (id: filas) en `auditoria_facturacion_log`: NULL 222.671, 1: 352.673, 2: 1.807, 3: 62.693, 4: 37, 6: 2, 7: 131, 9: 6. Ids nuevos 10-13 no chocan.
- Rutinas/vistas de PROD que la referencian: `consulta_auditoria_facturacion_turnos_sp`, `process_erogaciones_masivas_sp`, vista `consulta_auditoria_facturacion_view`. Sin comparaciones por valor de id (solo `id_tipo_factura = tipo_factura_in` y joins).

## wslistados (catálogo, solo lectura)
| Tipo | Archivo:línea | Nota |
|---|---|---|
| endpoint | `repos/grvx/backend/wslistados/src/main/java/ar/com/riovaradero/controller/TipoFacturacionController.java:17-35` | `GET /tipos-facturacion` (`@RequestMapping("/tipos-facturacion")`, `findAll`) |
| query-read | `.../serviceDTO/TipoFacturacionServiceDTOImpl.java:47` | `tipoFacturacionRepository.findAll()`; mapea `codigo=id`, `descripcion` (líneas 28-34). Sin ORDER BY ni filtro. |

- **Caché: no hay** (0 hits de `@Cacheable`/`EnableCaching` en wslistados). El alta se ve al instante, sin reiniciar ni redeploy. En el front, RTK Query (`listadosApi.ts:138-150`) lo pide al montar el componente: recargar la pantalla alcanza.
- Sin ORDER BY: las nuevas salen al final (por id).

## wsauditoriafacturacion (dueño de las FK) - `repos/grvx/backend/wsauditoriafacturacion/src/main/`
| Sev | Tipo | Archivo:línea | Match |
|---|---|---|---|
| 🟡 | mapping-table | `java/ar/com/riovaradero/entities/TipoFacturacion.java:11` | `@Table(name = "tipo_facturacion")` |
| 🟠 | mapping FK | `entities/AuditoriaFacturacionLog.java:45-48`, `Erogacion.java:92-95`, `ErogacionesMasivasJobLog.java:45-47`, `MaterialQuirurgicoErogacionLog.java:56-59`, `PedidosMaterialesQuirurgicosDetalles.java:125-128` | `@JoinColumn(id_tipo_facturacion)` |
| 🟠 | write | `service/AuditoriaFacturacionServiceImpl.java:463`, `:495` | `setTipoFacturacion(new TipoFacturacion(id))`: guarda el id que manda el front, sin validar su valor |
| 🟡 | validación | `serviceDTO/HoteleriaAuditoriaServiceDTOImpl.java:175` | solo `== null` (obligatorio) |
| 🟡 | filtro | `service/ErogacionesServiceImpl.java:142-143` | `cb.equal(idTipoFacturacion, filtro)` por el id que manda el front |
| 🟡 | query-read | `service/ErogacionesMasivasServiceImpl.java:196,203-204,220,238-239` | join `tipoFactura`, devuelve id/descripción y concatena texto |
| 🟡 | query-read | `service/DebitoFacturaServiceImpl.java:66-67` | id y descripción desde la vista |
| 🟡 | repo | `repositories/interfaces/ITipoFacturacionRepository.java:8` | `JpaRepository<TipoFacturacion,Integer>` |
| 🟡 | sql-view | `resources/sql/consulta_auditoria_facturacion_view.sql:76,89,118,137,180,211,251,282,316,332,362,378,406,422,452` | `LEFT JOIN cs.tipo_facturacion`; `letra_comprobante` = letra de "Factura X" en `numero_factura` o `RIGHT(descripcion_tipo_facturacion,1)` (línea 76): "Nota de Débito A" da A |
| 🟡 | sql-sp | `resources/sql/consulta_auditoria_facturacion_turnos_sp.sql:51,117,390` | `COALESCE(tfac.id_tipo_facturacion, tf.id_tipo_factura)` + LEFT JOIN; sin lógica por valor |
| 🟠 | sql-sp | `resources/sql/GLPI-2722/03_process_erogaciones_masivas_sp.sql:44,197,922,985,1173,1234` | `tipo_factura_in` se guarda en el job log y se copia a los logs; sin CASE por valor |
| 🟡 | DDL | `resources/sql/stored_procedure_erogaciones_masivas.sql:31` | `FOREIGN KEY (id_tipo_factura) REFERENCES tipo_facturacion` |

DTOs que solo transportan el id (sin lógica): `AuditoriaAutomaticaRequestDTO`, `AuditoriaMatQxCreateDTO`, `AuditoriaTurnosDTO`, `DatosFacturacionHoteleriaRequest`, `ErogacionCreateDTO`, `ErogacionesDTO`, `ErogacionesFiltrosDTO`, `ErogacionesRequestDTO`, `PedidoMaterialQxDetalleDTO`, `PedidoMatQxResponseDTO`, `DebitoFacturaResponseDTO`.
Duplicados por tipo+número: no hay chequeo de unicidad en código; signo y tope de montos no dependen del tipo.

## Otros backends (solo lectura / pass-through)
| Sev | Archivo:línea | Nota |
|---|---|---|
| 🟡 | `repos/grvx/backend/wsauditoriatraslados/src/main/java/ar/com/riovaradero/entities/TipoFacturacion.java:17`, `entities/AuditoriaFacturacionLog.java:51-52`, `CLAUDE.md:136` | catálogo readonly, solo JOIN |
| 🟡 | `repos/grvx/backend/ws-sasconnect/src/main/java/ar/com/riovaradero/serviceDTO/impl/PreliquidacionServiceDTOImpl.java:617` (DTO `dto/auditoria/AuditoriaAutomaticaRequestDTO.java:45`) | reenvía el id a la auditoría automática (SATAPP); sin lógica por valor |

## Frontend `auditoriafacturacion` - `repos/grvx/frontend/auditoriafacturacion/grv-auditoria-facturacion/src/main/reactjs/grv-auditoria-facturacion/src/`
| Sev | Archivo:línea | Uso |
|---|---|---|
| 🟡 | `utils/urls/urls.ts:68`, `redux/services/listadosApi.ts:138-150` | `GET {listados}/tipos-facturacion` |
| 🟡 | `components/TurnosTable/Commons/Facturacion.tsx:41-48` | select 'Tipo de factura': guarda id y descripción |
| 🟡 | `components/DetalleSiniestro/AuditoriaFacturacion/ErogacionLibre/DrawerFilters/Content.tsx:24,141` | desplegable de filtro |
| 🟡 | `components/BuscadorFactura/BuscadorDialog.tsx:52` (comentario 40-47) | `descripcion.trim().slice(-1).toUpperCase()` + `/^[A-Z]$/`, colapsa a letras únicas. 'Nota de Débito A/B/C/M' da letras ya existentes: el filtro no cambia. Se filtra por LETRA, no por id (el id está NULL en ~40% de las cabeceras). |
| 🟡 | `components/TurnosTable/Commons/Auditar.tsx:373` | muestra `tipoFacturacionDescripcion` + número |
| 🟡 | `DrawerCrearEditarErogacion.tsx:40,91,191-225`, `DrawerErogacionLibre.tsx:50,63`, `AuditarEditarPedidoDrawer.tsx:45-244`, `MaterialesQx.tsx:233`, `VerDetalleDrawer.tsx:98`, `DrawerEditarOrtopedia.tsx:41,89`, `AuditoriaSimpleDrawer.tsx:88-176`, `AuditoriaMultipleDrawer.tsx:84,174`, `DrawerAuditarPedido/FormularioFactura.tsx`, `HoteleriaTable/DrawerAuditoriaMasiva/index.tsx`, `hook/useBorradorErogacion.ts:32` | solo validan `!== 0` / `!!id` (obligatorio) y envían el id |

Resto de MFEs y librerías de `repos/grvx/frontend`: 0 hits.

## Efectos al agregar las 4 filas
- Aparecen en todos los desplegables 'Tipo de factura' (turnos simple/múltiple, hotelería, materiales Qx, ortopedia, erogación libre, erogación masiva) y en el filtro de erogación libre.
- Buscador de facturas: letras A/B/C/M ya existen; sin cambio.
- Vista de consulta: `letra_comprobante` prioriza la letra de "Factura X" del `numero_factura`; si el número no trae esa palabra cae en la letra de la descripción.

## Riesgos / puntos a validar
1. Charset latin1: insertar con el cliente en charset coherente (la `é` entra); el script muestra HEX para verificar.
2. Negocio: alcance A/B/C/M vs MiPyme; monto positivo (no hay lógica de signo).
3. Dependencia implícita "letra = último carácter": no cambiar el patrón de nombres sin revisar `BuscadorDialog.tsx:52` y la vista (línea 76).
4. No hay prevención de duplicados por tipo+número: una ND con el mismo número que una factura pasaría. Si se quiere evitar, es desarrollo aparte.

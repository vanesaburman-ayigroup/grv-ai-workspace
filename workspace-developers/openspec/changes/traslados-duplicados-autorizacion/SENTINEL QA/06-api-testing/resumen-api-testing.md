# API Testing — Circuito de autorización de traslados duplicados del mismo día

**Change OpenSpec:** `traslados-duplicados-autorizacion` · **Ticket:** INI-2
**Alcance:** `wsturnos`, `wslogistica`, `wstraslados`.
**Ambiente probado:** sólo DEV (`https://dev.sas.colonia-suiza.com.ar`). TEST no
tiene `wsturnos` desplegado.

Este documento acompaña a la colección Bruno en esta misma carpeta
(`tests/traslados-duplicados-autorizacion/API Testing/`). Los `.bru` de
**escritura** (pedir, resolver, crear turno, programar turno, cancelar,
marcar-duplicados-vistos) están escritos y listos pero **no se ejecutaron**:
cada uno documenta en su bloque `docs` qué dato consume y cómo revertirlo. Los
`.bru` de **lectura** de `wsturnos` (GET `traslados-duplicados-pendientes`,
GET `mis-duplicados-resueltos`, con y sin `idSolicitante`) se **ejecutaron
contra DEV sin token** (confirma R-1: el servicio no exige autenticación) y
sus resultados reales están en los `docs` de cada request. Los de
`wslogistica` (`conflictos-mismo-dia`) requieren token y no se ejecutaron
(exige 401 sin él, confirmado).

---

## 0. Incidente de origen y corrección — LEER ANTES QUE TODO LO DEMÁS

La primera pasada de este documento leyó el código de `wsturnos` contra el
**working tree local**, que estaba parado en la rama
`fix/pedir-traslado-duplicado-faltante` (no `main`: esa rama no existe en este
repo). Además, el `develop` **local** estaba **23 commits atrás** de
`origin/develop` (`f603379` del 14/08 vs. `2ea106c` del 18/08). Como
consecuencia:

- Se concluyó erróneamente que `GET /mis-duplicados-resueltos` y
  `POST /marcar-duplicados-vistos` no existían en el código — **sí existen**,
  en `origin/develop`, y de hecho responden en DEV (que está desplegado desde
  ahí). Fue un **hallazgo falso por lectura de rama equivocada**.
- Dos hallazgos propios (API-01 y API-02) se sacaron de una versión de
  `TrasladoDuplicadoValidator`/`TurnosController` que ya había sido corregida
  parcialmente en `origin/develop`.

**Corrección aplicada:** se releyeron los tres repos con `git fetch --all
--prune` + `git show origin/<rama>:<archivo>` / `git grep ... origin/<rama>`,
**sin tocar el checkout local** (había trabajo en curso en `wsturnos`). Ver la
sección 6 para el detalle de rama/commit/fecha por repo, y la sección 3 para
qué hallazgo se sostuvo, cuál se retiró y por qué.

---

## 1. Inventario de endpoints y contratos extraídos del código

Todos los contratos de esta sección se leyeron directo del código en
`repos/grvx/backend/{wsturnos,wslogistica,wstraslados}`, no de un OpenAPI (no
existe uno para este circuito).

### 1.1 `wsturnos` — `AutorizacionesController` (`@RequestMapping("/autorizaciones")`)

| Método | Ruta (gateway `/grv/turnos/...`) | DTO request | DTO response | Notas |
|---|---|---|---|---|
| GET | `/autorizaciones/traslados-duplicados-pendientes` | — | `ResponseDTO<Long>` | `contarPendientes()`: cuenta GLOBAL por `id_estado = 1`, no por cartera (R-3). Confirmado en vivo: `{"status":200,"message":"OK","body":1}`. |
| POST | `/autorizaciones/pedir-traslado-duplicado` | `PedirAutorizacionDuplicadoDTO` | `ResponseDTO<ResultadoAutorizacionDuplicadoDTO>` | Siempre 200 salvo excepción no controlada (500). No hay 201/404/409 de negocio. |
| POST | `/autorizaciones/resolver-traslado-duplicado` | `ResolverAutorizacionDuplicadoDTO` | `ResponseDTO<ResultadoAutorizacionDuplicadoDTO>` | Idem: siempre 200, el resultado tipado vive en el `body`. |
| GET | `/autorizaciones/mis-duplicados-resueltos?idSolicitante=` | — (`@RequestParam Long idSolicitante`, sin default) | `ResponseDTO<Long>` | **Agregado en esta corrección** (`AutorizacionesController.java:252` en `origin/develop`). Contador de resueltos-sin-ver del solicitante. Confirmado en vivo: `idSolicitante=1000007` → `{"status":200,"message":"OK","body":0}`; sin `idSolicitante` → **500** (`MissingServletRequestParameterException` sin handler específico, cae en el genérico). |
| POST | `/autorizaciones/marcar-duplicados-vistos` | `MarcarDuplicadosVistosDTO(idSolicitante @NotNull)` | `ResponseDTO<Integer>` (filas actualizadas) | **Agregado en esta corrección** (línea ~277). UPDATE masivo, idempotente por diseño: `WHERE ... AND fecha_visto_solicitante IS NULL`. No ejecutado (escribe), documentado con datos reales del pool (id 2/3 ya vistos el 2026-08-18 18:26:20). |

**`PedirAutorizacionDuplicadoDTO`:** `idAutorizacion` (`@NotNull`), `idTraslado`,
`idTrasladoTransportePublico`, `justificacion` (`@NotBlank`, **sin `@Size`** —
R-11), `idSolicitante` (`@NotNull`).

**`ResolverAutorizacionDuplicadoDTO`:** `idAutorizacionTrasladoDuplicado`
(`@NotNull`), `aprobar` (`@NotNull Boolean`), `idAutorizante` (`@NotNull`),
`dictamen` (**sin ninguna anotación de validación** — D-4).

**`ResultadoAutorizacionDuplicadoDTO`:** `resultado` (enum `APROBADA |
RECHAZADA | YA_RESUELTO | NO_ENCONTRADO | SIN_PERMISO | PENDIENTE`),
`idAutorizacionTrasladoDuplicado`, `idTraslado`, `resuelto` (boolean),
`mensaje`, `idAutorizante`, `fechaAutorizacion`. **Los seis valores de
`resultado` viajan siempre en HTTP 200** (R-9): no hay 403 para `SIN_PERMISO`,
no hay 409 para `YA_RESUELTO`, no hay 404 para `NO_ENCONTRADO`.

**Corrección: los dos endpoints SÍ existen.** La primera pasada de este
documento los buscó contra el working tree local
(`fix/pedir-traslado-duplicado-faltante`) y no los encontró; están en
`origin/develop` (ver sección 0 y 6) y ya tienen sus `.bru` en
`01-wsturnos-autorizaciones/17` a `20`.

**`GET /mis-duplicados-resueltos`** devuelve un **contador** (`Long`), igual
que `traslados-duplicados-pendientes` — no una lista con el detalle. El
detalle (resultado, autorizante, dictamen, justificación, fechas) **no viaja
por este endpoint**: viaja por `POST /turnos/tramitadores`
(`TramitadoresFilterDTO.misDuplicadosResueltos = true` +
`idSolicitanteDuplicado`), que agrega al listado general de turnos las
columnas `justificacionDuplicado`, `solicitanteDuplicado`,
`fechaSolicitudDuplicado`, `estadoDuplicado`, `dictamenDuplicado`,
`fechaAutorizacionDuplicado`, `autorizanteDuplicado` (`TurnosTramitadoresResponseDTO`,
poblado sólo cuando ese filtro está activo). **Esto cierra H-1** del análisis
estático (hueco de trazabilidad: "¿por dónde vuelve el resultado a quien
pidió?") — ver test `20-tramitadores-detalle-mis-duplicados-resueltos-H1`.

**`POST /marcar-duplicados-vistos`** hace un `UPDATE` masivo con
`@Modifying`, filtrando `estado IN (APROBADA, RECHAZADA) AND
fecha_visto_solicitante IS NULL` — es idempotente por construcción: una
segunda llamada no encuentra filas que actualizar y devuelve `0` sin tocar la
fecha ya sellada. Confirmado con datos reales del pool: los pedidos id 2 y 3
(`idSolicitante = 1000007`) ya tienen `fecha_visto_solicitante = 2026-08-18
18:26:20`.

### 1.2 `wsturnos` — `TurnosController` (los que activan el gate)

| Método | Ruta | Invoca el validador con | Efecto |
|---|---|---|---|
| POST | `/turnos/crear` (multipart) | `trasladoDuplicadoValidator.validar(idDenuncia, fechaTurno, requiereTraslado, idMotivoTrasladoMismoDia, **idAutorizacion=null**, idTurnoExcluido=null, tieneIntencionDePedido)` | 409 si hay traslado vigente sin motivo, sin pedido ni **intención de pedido**. `idAutorizacion` sigue siendo `null` en este camino (no puede ser otra cosa: la autorización nace con el turno), pero desde `origin/develop` hay un 7º parámetro `tieneIntencionDePedido` que cubre ese hueco — **API-01, ver sección 3, RETIRADO**. |
| PATCH | `/turnos/programar-turno` | `trasladoDuplicadoValidator.validarProgramacion(idTurno, fechaTurno, idMotivoTrasladoMismoDia)` → resuelve `idDenuncia` e `idAutorizacion` **reales** desde el turno | 409 si hay traslado vigente sin motivo ni pedido de excepción pendiente/aprobado. Acá sí aplica RF-4.2 completo. |

### 1.3 `TrasladoDuplicadoValidator` (el gate en sí)

En `origin/develop` el gate se reorganizó alrededor de un núcleo común,
`contarConflictoSinResolver()`, compartido por `crear`, `programar`, `editar`,
la tanda de programación de rehabilitación y `generarAutorizacion` (esto es lo
que la tarea 3.8 llama "unificar el criterio en las tres puntas"). El núcleo
no bloquea si: `requiereTraslado != true`, o `idDenuncia == null`, o
`fechaTurno == null`, o **`tieneIntencionDePedido == true`** (nuevo: cubre el
alta, donde el pedido todavía no existe), o `idMotivoTrasladoMismoDia !=
null`, o no hay traslados vigentes ese día, o
`tienePedidoDeExcepcion(idAutorizacion)` es `true`.

`tienePedidoDeExcepcion()` **sigue** haciendo
`findByAutorizacion(idAutorizacion).stream().anyMatch(PENDIENTE o APROBADA)`
— idéntico al código leído antes de la corrección. **API-02 se sostiene, ver
sección 3.**

### 1.4 `wslogistica` — `TrasladoController` (`@RequestMapping("/traslados")`)

| Método | Ruta (gateway `/grv/logistica/...`) | DTO request | DTO response |
|---|---|---|---|
| POST | `/traslados/conflictos-mismo-dia` | `ConflictoTrasladoRequestDTO(idDenuncia @NotNull, fechas @NotNull List<LocalDate>, idTurnoExcluido, idRegionCuerpo)` | `ResponseDTO<List<ConflictoPorFechaDTO>>` |

`ConflictoPorFechaDTO(fecha, tieneConflicto, traslados: List<TrasladoEnConflictoDTO>)`.
`TrasladoEnConflictoDTO` trae, por traslado: `idTurno`, `idTraslado`,
`esTransportePublico`, `tipoTurno`, `horaTurno`, `centroMedico`,
`idRegionCuerpo`, `estadoTraslado`, `estadoLogisticaIda/Vuelta`, `agencia`,
`agenciaInformada`, `horasAlViaje`, `mismaRegionCuerpo`, y `salidas`
(`SalidasConflictoDTO`: `puedeAnular`, `puedeDerivarALogistica`,
`puedeGuardarSinTraslado`, `requiereAutorizacion`, `detalle`).

Requiere autenticación (confirmado en vivo: 401 sin token) — a diferencia de
`wsturnos`, ver hallazgo de seguridad más abajo.

El umbral `wslogistica.conflicto-traslado.horas-minimas-anulacion` (default 3,
`@Value`) determina el Caso 6 de la matriz de salidas (EST-05: no está
declarado en ningún doc funcional).

### 1.5 `wstraslados` — `TrasladoController` (`@RequestMapping("/traslado")`)

| Método | Ruta (gateway `/grv/traslados/...`) | DTO request | DTO response |
|---|---|---|---|
| POST | `/traslado/cancelar-por-turno` | `List<IdTrasladoDTO>` (`idTraslado`, `idMotivoAnulacion`, `observacion`, `idTurno`, `idTipoTraslado`, `idAutorizacionTraslado`, `idResponsableAnulacion`) | `ResponseDTO` con resultado por elemento |

Reusado por `AutorizacionTrasladoDuplicadoServiceImpl.rechazar()` con
`idMotivoAnulacion = 16` (Constantes.MOTIVO_ANULACION_ALARMA_REPETIDA).

---

## 2. Tabla de casos por endpoint

| # | Archivo `.bru` | Endpoint | Caso | Ejecutable ahora |
|---|---|---|---|---|
| 01 | `01-pendientes-happy` | GET pendientes | Happy path, contrato confirmado | Sí |
| 02 | `02-pendientes-sin-token-defecto-seguridad` | GET pendientes | Seguridad — sin token (R-1) | Sí |
| 03 | `03-pedir-happy-sin-permiso-queda-pendiente` | POST pedir | Happy — queda PENDIENTE | Coordinar (escribe) |
| 04 | `04-pedir-happy-con-permiso-autoaprueba` | POST pedir | Happy — auto-aprueba (EST-07) | Coordinar (escribe) |
| 05 | `05-pedir-validacion-sin-justificacion` | POST pedir | Validación — `@NotBlank` | Sí |
| 06 | `06-pedir-borde-justificacion-2000-caracteres-truncamiento` | POST pedir | Borde — R-11, truncamiento | Coordinar (escribe si no falla) |
| 07 | `07-pedir-autorizacion-inexistente-no-encontrado` | POST pedir | Error negocio — NO_ENCONTRADO en 200 (R-9) | Sí |
| 08 | `08-pedir-sin-token-defecto-seguridad` | POST pedir | Seguridad — sin token (R-1) | Sí (usa id inexistente) |
| 09 | `09-pedir-defecto-seguridad-auto-aprobar...` | POST pedir | Seguridad — impersonación de `idSolicitante` (R-1) | Coordinar (escribe) |
| 10 | `10-resolver-aprobar-happy` | POST resolver | Happy — aprobar | Coordinar (escribe) |
| 11 | `11-resolver-rechazar-con-dictamen-happy` | POST resolver | Happy — rechazar con dictamen | Coordinar (escribe) |
| 12 | `12-resolver-rechazar-sin-dictamen-defecto-D4` | POST resolver | Defecto D-4 — dictamen no exigido server-side | Coordinar (escribe) |
| 13 | `13-resolver-idempotencia-ya-resuelto` | POST resolver | Idempotencia — YA_RESUELTO en 200 (R-9) | Sí (pool fijo id 2/3) |
| 14 | `14-resolver-no-encontrado` | POST resolver | Error negocio — NO_ENCONTRADO en 200 (R-9) | Sí |
| 15 | `15-resolver-sin-permiso-cuerpo-200` | POST resolver | Autorización — SIN_PERMISO en 200 (R-9) | Sí (pool fijo id 2) |
| 16 | `16-resolver-sin-token-defecto-seguridad` | POST resolver | Seguridad — sin token (R-1) | Sí (usa id inexistente) |
| 17 (carpeta 01) | `17-mis-duplicados-resueltos-happy` | GET mis-duplicados-resueltos | Happy — contador, agregado en esta corrección | **Sí — ejecutado, 200 body:0** |
| 18 (carpeta 01) | `18-mis-duplicados-resueltos-sin-idsolicitante-500` | GET mis-duplicados-resueltos | Validación — falta `@RequestParam` → 500 (hallazgo) | **Sí — ejecutado, 500 confirmado** |
| 19 (carpeta 01) | `19-marcar-duplicados-vistos-idempotencia` | POST marcar-duplicados-vistos | Idempotencia — WHERE con `fecha_visto_solicitante IS NULL` | Coordinar (escribe; documentado con datos reales del pool) |
| 20 (carpeta 01) | `20-tramitadores-detalle-mis-duplicados-resueltos-H1` | POST turnos/tramitadores | Cierra H-1 — detalle del resultado (dictamen, autorizante, fechas) | Sí (lectura; requiere completar el filtro) |
| 17 | `17-crear-turno-conflicto-sin-motivo-409` | POST crear | **El gate — 409** | Coordinar (requiere precondición) |
| 18 | `18-crear-turno-conflicto-con-motivo-pasa` | POST crear | Gate — motivo declarado pasa | Coordinar (escribe) |
| 19 | `19-crear-turno-sin-traslado-no-interviene` | POST crear | Borde — sin traslado | Coordinar (escribe) |
| 20 | `20-crear-turno-sin-fecha-no-interviene` | POST crear | Borde — sin fecha | Coordinar (escribe) |
| 21 | `21-crear-turno-pedido-pendiente-no-neutraliza-API01` | POST crear | **Test de regresión — API-01 RETIRADO** (el alta ya registra su propio pedido con `justificacionTrasladoDuplicado`/`idSolicitanteTrasladoDuplicado`) | Coordinar (escribe) |
| 22 | `22-programar-turno-pedido-pendiente-pasa` | PATCH programar | Gate — pedido pendiente pasa | Coordinar (escribe) |
| 23 | `23-programar-turno-pedido-aprobado-pasa` | PATCH programar | Gate — pedido aprobado pasa | Coordinar (escribe) |
| 24 | `24-programar-turno-pedido-rechazado-409` | PATCH programar | **Gate — pedido rechazado, 409** | Coordinar (escribe) |
| 25 | `25-programar-turno-aprobado-viejo-rechazo-nuevo-defecto-orden` | PATCH programar | **Defecto propio API-02 — SOSTENIDO tras re-verificación** contra `origin/develop` | Coordinar (escribe) |
| 26 | `26-programar-turno-rechazado-viejo-pendiente-nuevo-EST06` | PATCH programar | **EST-06 — el rechazo se neutraliza** | Coordinar (escribe) |
| 27 | `27-conflictos-happy-turno-suelto` | POST conflictos | Happy path | Sí |
| 28 | `28-conflictos-sin-auth-401` | POST conflictos | Seguridad — 401 sin token (confirmado en vivo) | Sí |
| 29 | `29-conflictos-validacion-campos` | POST conflictos | Validación — `@NotNull` | Sí |
| 30 | `30-conflictos-matriz-viaje-en-curso` | POST conflictos | Matriz SDD §5 — Caso 7 | Sí (requiere dato real) |
| 31 | `31-conflictos-matriz-tramo-facturable-y-monto-cargado` | POST conflictos | Matriz — Caso 8 | Sí (requiere dato real) |
| 32 | `32-conflictos-matriz-ida-realizada-vuelta-pendiente` | POST conflictos | Matriz — Caso 9 | Sí (requiere dato real) |
| 33 | `33-conflictos-matriz-agencia-informada` | POST conflictos | Matriz — agencia informada | Sí (requiere dato real) |
| 34 | `34-conflictos-matriz-sin-margen-horas-umbral` | POST conflictos | Matriz — umbral EST-05 | Sí (requiere dato real + confirmar property) |
| 35 | `35-cancelar-por-turno-happy-motivo-16` | POST cancelar-por-turno | Happy — motivo 16 | Coordinar (escribe, irreversible) |
| 36 | `36-cancelar-por-turno-validacion-body-vacio` | POST cancelar-por-turno | Validación — array vacío/malformado | Sí |

---

## 3. Defectos que estos tests exponen

Los primeros cuatro ya estaban identificados en el análisis estático
(`Documentacion/traslados-duplicados-autorizacion/Estaticas/`); los tests de
esta colección los vuelven reproducibles contra DEV con datos concretos.

**Sobre los dos hallazgos propios (API-01, API-02), re-verificados contra
`origin/develop` tras la corrección de la sección 0:**

- **API-01 — RETIRADO.** El código real de `origin/develop` (no el que se
  había leído antes) ya resuelve exactamente esto: el alta registra su propio
  pedido de excepción en la misma transacción (`registrarPedidoDelAlta`,
  `GenerarTrasladoDTO.tieneIntencionDePedidoDuplicado()`), con test unitario
  dedicado (`PedidoDuplicadoEnAltaTest.java`). Un hallazgo retirado con su
  motivo documentado, no sostenido por inercia.
- **API-02 — SOSTENIDO.** `tienePedidoDeExcepcion()` sigue usando `anyMatch`
  sobre toda la lista de pedidos históricos de la autorización, sin respetar
  el orden que el propio `findByAutorizacion()` ya construye (`ORDER BY ...
  DESC`, "el que vale es el último"). La tarea 3.8 unificó los **puntos de
  entrada** al gate (crear/editar/tanda/generarAutorizacion comparten
  `contarConflictoSinResolver()`), no la **lógica de recencia** dentro de
  `tienePedidoDeExcepcion()`. Ver el test 25 para el detalle línea por línea.

Se agrega además un hallazgo nuevo (API-03) encontrado al ejecutar los GETs de
lectura sin token, por indicación del coordinador.

1. **EST-06 — El rechazo se neutraliza volviendo a pedir** (`ALTA`). Test
   `26-programar-turno-rechazado-viejo-pendiente-nuevo-EST06`. Un traslado con
   un pedido RECHAZADO puede volver a pedirse: el nuevo pedido PENDIENTE
   habilita el guardado sin que nadie vea el rechazo anterior ni su dictamen.
   Se espera **200** (no 409) — ese resultado es la confirmación del defecto.

2. **R-9 — Los seis resultados de `resolver`/`pedir` viajan en HTTP 200, sin
   discriminar por status**. Tests 07, 13, 14, 15 (y el `NO_ENCONTRADO` de
   `pedir`). `SIN_PERMISO` no es 403, `YA_RESUELTO` no es 409, `NO_ENCONTRADO`
   no es 404. Cualquier cliente de la API que confíe en el código HTTP para
   diferenciar resultados de negocio se equivoca: hay que leer `body.resultado`.

3. **D-4 — El dictamen no es obligatorio al rechazar server-side**. Test
   `12-resolver-rechazar-sin-dictamen-defecto-D4`. El PRD lo declara
   obligatorio; `ResolverAutorizacionDuplicadoDTO.dictamen` no tiene ninguna
   anotación de validación y el service contempla explícitamente el caso null
   (`Constantes.VACIO`). Se espera **200 RECHAZADA** con dictamen nulo — la
   obligatoriedad es sólo de UI.

4. **R-11 — Justificación sin `@Size`, columna `VARCHAR(1000)`**. Test
   `06-pedir-borde-justificacion-2000-caracteres-truncamiento`. Con 2000
   caracteres se espera **500** con mensaje crudo del driver JDBC, no un 400
   de validación — porque no hay `@Size` que corte antes.

5. **API-01 (hallazgo propio) — RETIRADO tras re-verificación.** Se había
   documentado que el pedido de excepción nunca servía para el gate de ALTA
   porque `TurnosController.createTurno()` invoca el validador con
   `idAutorizacion` fijo en `null`. Eso seguía siendo cierto (`idAutorizacion`
   sigue siendo `null` ahí, no puede ser otra cosa), pero el hallazgo original
   se sacó de código que no tenía el resto del fix: en `origin/develop`,
   `GenerarTrasladoDTO` ahora trae `justificacionTrasladoDuplicado` +
   `idSolicitanteTrasladoDuplicado`, y `tieneIntencionDePedidoDuplicado()`
   evita el 409 en el mismo request que crea el turno; el pedido se registra
   atómicamente en la misma transacción (`registrarPedidoDelAlta`), apuntando
   al traslado NUEVO (no al preexistente, que era el bug que además arrastraba
   el camino viejo de `pedir-traslado-duplicado` usado por error en ediciones —
   ver el comentario de `AutorizacionesController.java:171` sobre el fix
   pendiente del lado del front). Test de regresión:
   `21-crear-turno-pedido-pendiente-no-neutraliza-API01`.

6. **API-02 (hallazgo propio) — SOSTENIDO tras re-verificación contra
   `origin/develop` (commit `2ea106c`, 2026-08-18).** "El pedido que vale es
   el último" sigue sin estar implementado del lado que consume la lista.
   `AutorizacionTrasladoDuplicadoRepository.findByAutorizacion()` ordena
   `desc` por id con el comentario explícito "el que vale es el último", pero
   `TrasladoDuplicadoValidator.tienePedidoDeExcepcion()` consume esa lista con
   `.stream().anyMatch(PENDIENTE o APROBADA)` — código **idéntico**, línea por
   línea, al que ya se había leído antes de la corrección. La tarea 3.8 unificó
   los puntos de entrada al gate (`crear`/`editar`/tanda/`generarAutorizacion`
   comparten ahora `contarConflictoSinResolver()`), pero no tocó esta función.
   Alcanza con que **cualquier** fila histórica sea PENDIENTE o APROBADA para
   neutralizar el gate, sin importar si la más reciente es un RECHAZO. La
   secuencia *aprobado viejo + rechazo nuevo* (la que D8/RF-4.3 exigen
   bloquear con 409) probablemente **tampoco** da 409 en la implementación
   actual — el mismo bug de raíz que produce EST-06, pero en la dirección
   contraria y sin numerar en el análisis estático. Test:
   `25-programar-turno-aprobado-viejo-rechazo-nuevo-defecto-orden`. Corrección
   sugerida: que `tienePedidoDeExcepcion()` tome sólo el primer elemento de la
   lista ya ordenada (`findFirst()`), no cualquier match.

7. **R-1 — Los endpoints de `wsturnos` responden sin autenticación y validan
   el permiso contra el `idAutorizante`/`idSolicitante` del body, no contra la
   sesión.** Tests 02, 08, 09, 16, y confirmado en vivo en esta corrección con
   los tests 17/18 (GETs ejecutados sin token, ambos respondieron: 200 y 500
   respectivamente, ninguno 401/403). La variante más grave es el test 09: con
   la sesión de `ayioperadort` (sin permiso) pero `idSolicitante` de
   `tramitador.supervisor` (con permiso) en el body, se espera **APROBADA**
   — cualquiera con un token válido de `wsturnos` puede autoaprobarse el
   duplicado impersonando a otra persona en el campo del DTO. Contrasta
   directamente con `wslogistica`, que sí exige token (test 28, 401
   confirmado en vivo): dos servicios del mismo circuito tratan la
   autenticación de forma inconsistente.

8. **API-03 (hallazgo propio, nuevo en esta corrección) — Falta un
   `@RequestParam` obligatorio en `mis-duplicados-resueltos` produce 500, no
   400.** Test `18-mis-duplicados-resueltos-sin-idsolicitante-500`, EJECUTADO
   contra DEV: `GET .../mis-duplicados-resueltos` sin `idSolicitante` devuelve
   `{"status":500,"message":"Error interno del servidor. Contacte al
   administrador.","body":"INTERNAL_SERVER_ERROR"}`. `GlobalExceptionHandler`
   no tiene un `@ExceptionHandler` para
   `MissingServletRequestParameterException`, así que cae en el genérico. Es
   un defecto menor de contrato (debería ser 400 con un mensaje que nombre el
   parámetro faltante), pero ruidoso para cualquier alerta de monitoreo que
   dispare por tasa de 5xx.

---

## 4. Endpoints del contrato sin cobertura de criterio de aceptación

- `GET /autorizaciones/traslados-duplicados-pendientes`: no tiene AC que
  declare si el conteo debe filtrar por cartera del autorizante (R-3). El
  test 01 lo deja documentado, no resuelto.
- `POST /turnos/tramitadores` con los filtros `misDuplicadosResueltos` /
  `trasladosDuplicadosPendientes`: no hay AC específico que declare el
  contrato de estas columnas del listado general (nacieron para cerrar H-1,
  pero H-1 en sí describía el hueco, no el contrato exacto de la solución).
  El test 20 lo cubre de forma exploratoria, no verificada contra un AC.
- `POST /traslado/cancelar-por-turno`: no hay AC sobre qué pasa cuando un
  elemento del array falla y otros no (transaccionalidad por elemento vs. por
  lote) — test 35 lo señala como pendiente de definición.
- **H-1 y RF-2.9 quedan cerrados** por esta corrección: el detalle del
  resultado que le vuelve al solicitante viaja por `POST /turnos/tramitadores`
  con `misDuplicadosResueltos`/`idSolicitanteDuplicado` (ver sección 1.1 y
  test 20), no por un endpoint dedicado. Documentado, ya no es hueco de
  trazabilidad — sigue faltando el AC formal que lo declare (punto anterior).

---

## 5. Efectos secundarios y dependencias (orden de la colección)

1. `01`/`02` (GET pendientes) no tienen dependencias, son de lectura. Igual
   `17`/`18` (GET mis-duplicados-resueltos, carpeta 01) y `20` (POST
   turnos/tramitadores, sólo lectura).
2. `03`–`09` (`pedir`) dependen de que exista una `autorizacion` real
   (`idAutorizacionPendiente` del pool, o una creada ad hoc). Efecto: nueva
   fila en `autorizaciones_traslado_duplicado`; si autoaprueba y tiene
   `idTraslado`, además marca logística.
3. `10`–`16` (`resolver`) dependen de un pedido creado por `03`/`04` (NUNCA
   reutilizar el pool fijo id 1 para resolver, salvo los tests de
   idempotencia/sin-permiso que usan a propósito el id 2/3 ya resueltos).
   Efecto: cambia estado del pedido; si rechaza, cancela el traslado asociado
   vía `wstraslados/cancelar-por-turno` (efecto en cascada, ver `35`).
4. `17`–`26` (gate en `crear`/`programar`) dependen de tener, antes de correr,
   un traslado vigente de la misma denuncia/fecha (creado con `18` o datos
   reales de `{{idDenuncia}}`), y en varios casos un pedido de excepción en el
   estado que el test necesita (creado con `03`/`04` y resuelto con
   `10`/`11`).
5. `27`–`34` (`conflictos-mismo-dia`) son de lectura pura, pero varios casos
   de la matriz (30–34) requieren datos reales existentes en DEV con el
   estado operativo exacto (viaje en curso, tramo facturable, etc.) — no se
   pueden fabricar sin tocar `traslados` directamente, así que se buscan con
   `db_dev.py` en vez de crearse.
6. `35`/`36` (`cancelar-por-turno`) son el efecto terminal de un rechazo: sólo
   correrlos con un traslado de prueba dedicado, nunca con datos reales de
   `{{idDenuncia}}` sin plan de reversión.
7. `19` (`marcar-duplicados-vistos`, carpeta 01) depende del estado de
   `fecha_visto_solicitante` del solicitante usado: confirmar con `db_dev.py`
   ANTES de correrlo si hay algún pedido resuelto y sin ver que no se quiera
   marcar todavía (el UPDATE es irreversible desde la API).

---

## 6. Autenticación

`wsturnos` **no exige token** (R-1): confirmado en esta corrección
ejecutando dos `GET` reales sin `Authorization` contra DEV (tests 01 y 17/18
de la carpeta 01) — ambos respondieron (200 y 500 respectivamente, ninguno
401/403). Por eso los `.bru` de lectura de `wsturnos` en esta colección usan
`auth: none` cuando fue seguro ejecutarlos. `wslogistica` sí exige token
(401 confirmado en vivo, test 28) y sus requests quedan con `auth: bearer` sin
ejecutar.

No se encontró en ningún repo un endpoint de login/token propio de este
circuito. El `token` del entorno Bruno (`environments/dev.bru`) queda
**vacío a propósito** para `wslogistica`/`wstraslados`, siguiendo la misma
convención que las colecciones Bruno preexistentes en `bruno/ws/wslogistica`:
completarlo manualmente obteniendo un JWT válido del login real de SAS con
`tramitador.supervisor` / `ayioperadort`.

`idPersonaConPermiso = 1000008` / `idPersonaSinPermiso = 1000007`:
**confirmado con `db_dev.py`** contra `autorizaciones_traslado_duplicado`
(no asumido): las tres filas del pool fijo (id 1/2/3) tienen
`id_solicitante = 1000007`, y las dos resueltas (id 2/3) tienen
`id_autorizante = 1000008`. Sigue pendiente sólo el mapeo de estos ids de
persona contra los usuarios LDAP `tramitador.supervisor`/`ayioperadort`
(confirmar contra `personas_perfiles_sas` antes de ejecutar cualquier test de
escritura que dependa de la sesión real, no sólo del id en el body).

---

## 7. Fuente del contrato — rama, commit y fecha por repo

Todos los contratos de este documento (y la corrección de la sección 0) se
leyeron con `git fetch --all --prune` + `git show <rama>:<archivo>` / `git
grep ... <rama> -- '*.java'`, **sin cambiar el checkout local** de ningún
repo. Fetch ejecutado: 18/08/2026.

| Repo | Rama leída | Commit | Fecha del commit | Estado del working tree local |
|---|---|---|---|---|
| `wsturnos` | `origin/develop` | `2ea106c` | 2026-08-18 | Working tree en `fix/pedir-traslado-duplicado-faltante` (no tocado); `develop` local en `f603379` (2026-08-14), **23 commits atrás** de `origin/develop` |
| `wslogistica` | `origin/develop` | `912a4c8` | 2026-08-14 | Working tree en `develop`, al día con `origin/develop` (mismo commit) — sin drift |
| `wstraslados` | `origin/develop` | `8feded9` | 2026-08-13 | Working tree en `bugfix/hardening-anulacion-traslado`; `develop` local en `dfd23d4` (2026-06-30), **muy atrás** de `origin/develop` — confirmado sin drift de contrato en `cancelar-por-turno`/`IdTrasladoDTO` para este circuito puntual |

**El HEAD sin fecha no dice nada** (el motivo por el que este mismo error ya
había producido un hallazgo falso, según deja escrito el SDD del change): por
eso cada fila de esta tabla lleva commit corto y fecha, no sólo el nombre de
la rama.

Ramas de feature relevantes verificadas con `git merge-base --is-ancestor
<rama> origin/develop` (en `wsturnos`):

| Rama | ¿Mergeada en `origin/develop`? |
|---|---|
| `origin/fix/INI-2-gate-en-todos-los-caminos` | **Sí** — es el commit `2ea106c` (merge commit) |
| `origin/fix/INI-2-pedido-en-el-alta` | **No** — pero el fix equivalente YA está en `origin/develop` bajo otro nombre/implementación (`registrarPedidoDelAlta` + `tieneIntencionDePedidoDuplicado`, con test dedicado `PedidoDuplicadoEnAltaTest.java`). No confundir "rama no mergeada" con "fix no aplicado": en este caso el fix llegó por otro camino. |

---

Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026

# Review cruzado de las 5 MRs de INI-02 — como un solo cambio

**Autor:** Vanesa Burman — QA
**Fecha:** 24/08/2026
**Alcance:** wsturnos !856, wslogistica !650, wstraslados !311, tramitadores !1823, logistica !454 — todas `promo/INI-2-prod` → `master`.
**Método:** lectura estática de `origin/promo/INI-2-prod` contra `origin/master` (con `fetch` previo), más consultas de sólo lectura a producción.

---

## Veredicto

**El circuito no cierra de punta a punta. No mergear todavía.**

El alta de un turno suelto funciona completa. Pero **la edición, la programación y el alta de tanda de rehabilitación tienen el gate levantado y la mitad que registra el pedido no existe o está rota**. Y la llave de invisibilidad para logística se abre sola por dos caminos que ninguna de las 5 MRs toca.

Son **5 bloqueantes**. Tres los verifiqué yo directamente sobre el código (H-1, H-2, H-4); los otros dos están documentados con archivo y línea.

---

## Las 8 etapas del circuito

| # | Etapa | Back | Front | ¿Completa? |
|---|---|---|---|---|
| 1 | Bloque de conflicto con 3 salidas | wslogistica !650 | tramitadores !1823 | Sí en 2 de 4 drawers (H-1, H-5) |
| 2 | Gate del servidor, 409 | wsturnos !856 | tramitadores !1823 | **Sí** |
| 3 | Pedido en la misma transacción del alta | wsturnos !856 | tramitadores !1823 | **Sólo en el alta de turno suelto.** Falta en edición (H-2), programación (H-4) y tanda (H-5) |
| 4 | Aprobar/rechazar por permiso por nombre | wsturnos !856 | tramitadores !1823 | **Sí** |
| 5 | El resultado vuelve al solicitante | wsturnos !856 | tramitadores !1823 | **Sí** |
| 6 | Invisibilidad + marca en la grilla | wsturnos escribe / wslogistica lee | logistica !454 | **No** (H-3, H-7) |
| 7 | Sólo cuenta el último pedido | wsturnos !856 | — | **Sí** |
| 8 | Nunca un id interno al usuario | — | tramitadores + logistica | **Sí** |

---

## Bloqueantes

### H-1 · El criterio de conflicto no es el mismo en los dos servicios: el gestor queda trabado sin salida

`wslogistica/ConflictoTrasladoServiceImpl.java:155` filtra `!esRehabilitacionDeOtraRegion(p, idRegionCuerpoNueva)`, y `compararRegion` (líneas 286-292) **descarta el conflicto cuando el plan es de rehabilitación y la región del cuerpo es distinta**.

**El gate de `wsturnos` no sabe nada de región.** `ITrasladoRepository.contarTrasladosVigentesEnFecha` cuenta por denuncia + fecha + estado, y nada más.

**En producción:** sesión de rehabilitación con traslado, mismo día, otra región del cuerpo. `wslogistica` contesta «sin conflicto» → `BloqueConflictoTraslado` hace `if (!hayConflicto) return null` → **no se renderiza nada**. El gestor no tiene dónde declarar el motivo ni pedir la excepción. Y `wsturnos` cuenta el traslado y devuelve **409**. **El turno no se puede guardar y la pantalla no ofrece ninguna salida.**

Afecta los tres caminos de rehabilitación. Es justo el escenario del plan de diez sesiones que motivó la feature.

> **Verificado directamente:** leí las dos implementaciones. El filtro por región está sólo en `wslogistica`.

### H-2 · En la edición, la intención de pedido levanta el gate y nadie registra el pedido

`TurnosController.java:264` pasa `tieneIntencionDePedidoDuplicado()` a `validarEdicion`, y el validador devuelve 0 conflictos en cuanto hay intención. Pero **`registrarPedidoDelAlta` tiene un único llamador: `TurnosServiceImpl.java:1734`, dentro de `createTurno`**. `updateTurno` no lo llama.

El front no compensa: el payload de edición **sí** manda `justificacionTrasladoDuplicado` e `idSolicitanteTrasladoDuplicado`, porque el builder es compartido.

**En producción:** el gestor edita un turno, elige «pedir autorización», escribe la justificación y guarda. El turno se guarda, el traslado se crea, y **no se crea ninguna fila en `autorizaciones_traslado_duplicado`**. No aparece en la pestaña de ningún referente, no aparece en «Mis duplicados resueltos», y el traslado queda con `id_estado_logistica_ida = NULL`: **invisible para logística para siempre**. El gestor ve «turno guardado con éxito» y el paciente no tiene traslado.

Es una pérdida silenciosa, de la misma familia que el bug que esta MR arregló para el alta.

> **Verificado directamente:** `grep -rn "registrarPedidoDelAlta"` devuelve un solo call site real, en `createTurno`. Y `updateTurno` es `@Transactional` pelado, sin `rollbackFor`.

### H-3 · La llave de invisibilidad se abre sola por dos caminos que ninguna MR toca

Con el pedido en PENDIENTE, dos lugares ponen `id_estado_logistica_ida = SOLICITADO` sin mirar el estado del pedido:

- `wsturnos/AutorizacionesServiceImpl.java:1839-1860` (`cambiarEstadoTraslado`, desde `POST /autorizaciones/dictaminar-autorizacion`).
- `wsturnos/TurnosServiceImpl.java:894-937` (`programarTurno`) — y para transporte público **sin siquiera exigir autorización aprobada**.

Ninguno de los dos está en el diff de !856. Y el gate no los frena, porque `tienePedidoDeExcepcion` acepta PENDIENTE como justificación válida.

**En producción:** el pedido queda PENDIENTE y el traslado invisible — bien hasta acá. Después un referente aprueba la **autorización del turno**, que es una acción distinta, mucho más frecuente, y hecha por alguien que no ve el pedido de duplicado. El traslado baja a la grilla de logística **sin la marca de duplicado autorizado**. Logística lo ve como duplicado no autorizado y lo cancela con motivo 16 —las ~130 cancelaciones/mes que INI-2 vino a eliminar— o lo despacha sin que nadie haya autorizado la excepción. Y si el pedido se rechaza después, se cancela un traslado que ya podía estar asignado.

### H-4 · `pedir-traslado-duplicado` devuelve 400 en programación y en edición de rehabilitación

`PedirAutorizacionDuplicadoDTO.java:35` declara `@NotNull private Long idSolicitante`, y el controller usa `@Valid` (`AutorizacionesController.java:196`). De los cuatro call sites de `BloqueConflictoTraslado`, **sólo uno pasa `idSolicitante`**:

| drawer | ¿pasa `idSolicitante`? |
|---|---|
| `DrawerNuevoTurno/components/StepTraslado.jsx:165` | **Sí** |
| `DrawerProgramarTurno/index.jsx:285` | **No** |
| `TurnosRehabilitacion/.../DrawerEditarTurno/index.jsx:165` | **No** |
| `DrawerGenerarAutorizacion/components/StepTraslado.js:344` | **No** (ver H-5) |

**En producción:** en esos dos drawers el `idAutorizacion` existe, así que el bloque muestra el botón «Enviar pedido». Al apretarlo el request sale con `idSolicitante: undefined` y el back contesta **400**. El gestor ve «No se pudo registrar el pedido» y no tiene forma de resolver el conflicto por esa vía.

> **Verificado directamente:** el `@NotNull`, el `@Valid` del controller, y los cuatro call sites con sus props.

### H-5 · La salida «pedir autorización» del alta de tanda de rehabilitación es una salida muerta

En `DrawerGenerarAutorizacion/components/StepTraslado.js:344` no hay `idAutorizacion`, así que el bloque entra en `esAlta` y muestra el cartel «el pedido se registra al guardar el turno». **No es cierto en ese camino:**

1. No se le pasa `onChangeJustificacion`, así que la justificación queda en el state local del bloque y nunca entra al request.
2. `validarGeneracionAutorizacion` **rechaza la intención de pedido a propósito** — su propio comentario lo dice: «La intención de pedido NO se acepta en este camino… `generarAutorizacion` crea los traslados pero no registra ningún pedido».

**En producción:** quien no tiene el permiso elige «pedir autorización», escribe la justificación, guarda, y recibe 409 con las fechas en conflicto. Su única salida real es cancelar el traslado ajeno o guardar sin traslado.

---

## Hallazgos no bloqueantes

### H-6 · ALTO — El pedido de edición y programación apunta al traslado equivocado

El javadoc de `AutorizacionesController.java:176-186` documenta el problema con nombre propio: *«FIX PENDIENTE DEL LADO DEL FRONT… el front manda en `idTraslado` el id del primer conflicto, es decir el traslado preexistente»*. El front de esta promoción **no lo corrigió**: `BloqueConflictoTraslado.jsx` manda `idTraslado: aAutorizar?.idTraslado`, donde `aAutorizar` sale de los conflictos, nunca del turno que se está editando.

**Efecto:** al aprobar se marca y se re-solicita el traslado viejo, pisando su estado real, mientras el traslado del turno editado queda sin marca y logística lo cancela por duplicado. Es el mismo defecto que INI-2 arregló para el alta, vivo en las otras dos puntas.

Convive con H-4: mientras el 400 exista, este camino no se llega a ejecutar.

### H-7 · MEDIO — `duplicadoAutorizadoPor`: el front lo lee y el back no lo devuelve nunca

`logistica/TrasladosTypes.ts:97` lo declara y `TablaTraslados.tsx:76-78` lo usa para el tooltip con nombre. `wslogistica` agrega **sólo** `esDuplicadoAutorizado`; cero hits de `duplicadoAutorizadoPor` en todo su `src/main`, y ningún SP devuelve un alias de autorizante. No rompe —el ternario cae al texto genérico— pero **logística nunca ve quién autorizó la excepción**.

### H-8 · MEDIO — El 500 del alta sin solicitante

`TurnosServiceImpl.java:1731` lanza `IllegalArgumentException` **dentro** del try de `createTurno`, así que lo agarra el `catch (Exception)` y sale un 500. El front muestra «hubo un problema en el sistema» en vez del mensaje real.

### H-9 · MEDIO — Riesgos operativos del script SQL

- **Dos de los cuatro `CREATE PROCEDURE` no están calificados con el esquema** (`consulta_turnos_tramitadores_sp` y `consulta_traslados_internos_logistica`); los otros dos usan `` `cs`.`…` ``. Dependen del `USE cs;` del encabezado. Si el bloque 4 se corre en una sesión nueva —que es lo que el propio script pide, para usar el usuario `admin`— el `DROP` borra el SP de `cs` y el `CREATE` lo crea en otro esquema: **grilla de tramitadores caída en producción**. Arreglo trivial: calificar los cuatro con `cs.`.
- **El gate transaccional del bloque del permiso es ilusorio si se corre de una pasada:** `START TRANSACTION` seguido de DDL hace commit implícito en MariaDB, así que el `ROLLBACK` comentado no revertiría nada. El rollback real es el `DELETE` del final.
- **Orden obligatorio: SP primero, WS después.** El `@ConstructorResult` exige las 8 columnas nuevas en *todas* las pestañas: si el WS sube contra el SP viejo, revienta la grilla completa, no sólo las dos tabs nuevas.
- **Divergencia PROD/TEST de perfiles:** el script de promoción asigna el permiso a 2 perfiles; los ambientes bajos lo tienen en 4 (suma `gerente_de_siniestros` y `supervisor`). La rama de auto-aprobación se comporta distinto según el ambiente, así que **lo probado en TEST con esos perfiles no es representativo de producción**.

### H-10 · BAJO

- `RESULTADO_CANCELACION` del front declara dos valores que `wslogistica` nunca emite (`RECHAZADO_PRESTADOR`, `FALLO_COMUNICACION`): los dos salen como `REQUIERE_REVISION`. Un fallo de comunicación —falla nuestra, `origen: SISTEMA`— se pinta como WARNING en vez de ERROR, cuando el criterio del propio código es que eso va a mesa de ayuda. Se arregla mirando `origen` en vez de `resultado`.
- `ResultadoCancelacionDTO` de `wstraslados` omite el 7º campo de `wslogistica` (`agencias`). No rompe, pero es una truncación de contrato en el pasamanos.
- **Comparación de fechas asimétrica:** `wslogistica` hace `tu.fechaTurno IN (:fechas)` (datetime contra `LocalDate`) mientras `wsturnos` usa `FUNCTION('DATE', …)`. Medido en producción: de 202.589 turnos desde mayo, **2** tienen hora distinta de 00:00:00. Mismo síntoma que H-1, con frecuencia ínfima.
- `esDuplicadoAutorizado: boolean` en `TrasladosTypes.ts:95` no es nullable, pero el back devuelve `null`. Sin impacto en runtime; el tipo miente igual que `requiereRevision`.
- Constante duplicada en `wsturnos/Constantes.java`: `ID_TIPO_VIAJE_IDA_VUELTA` (153) y `TIPO_VIAJE_IDA_VUELTA` (452), las dos `2L`.

---

## Lo que se verificó y está sano

Vale tanto como los defectos, así que va con evidencia:

- **Los 3 campos del payload del alta** existen en `GenerarTrasladoDTO:68,89,103` con el nombre exacto que manda el front, y **los lee el service** (`TurnosServiceImpl:1727-1740`). `UpdateTurnoDTO.updateTrasladoDTO` es del mismo tipo, así que en edición también llegan.
- **Los 5 endpoints nuevos que consume el front existen** con ese path y ese verbo (`AutorizacionesController:194,211,231,256,281` y el POST de `wslogistica`).
- **Los estados de logística coinciden valor por valor:** `ESTADO_LOGISTICA_SOLICITADO = 1L` en `wsturnos` == `EstadosTrasladosLogisticaEnum.SOLICITADO(1)`; los 8 valores son idénticos en los dos repos. Y el filtro de la grilla existe: `AND t.id_estado_logistica_ida IS NOT NULL` en los dos SP de consulta.
- **Quién pone y quién saca el NULL:** nadie lo setea, la invisibilidad es el default de la columna. Lo saca `aprobar()`, que además escribe `es_duplicado_autorizado = 1` en traslado normal **y** en transporte público, y lanza `IllegalStateException` si no pudo aplicarlo a ninguno.
- **`cancelar-por-turno`: contrato aditivo y consumidor en la misma promoción.** Los otros dos consumidores del mismo action ignoran el argumento nuevo: no rompen.
- **Mapeo del SP de tramitadores:** las 8 columnas nuevas van **al final** del SELECT en las tres ramas, con el mismo orden y tipo que el `@ConstructorResult`. Ningún índice existente se corre.
- **Los 3 SP de logística:** la columna va última y el mapeo es `resultClasses` **por nombre**, no posicional. El `NULL as es_duplicado_autorizado` en traslados internos es deliberado y correcto (son traslados de personal, no de pacientes).
- **Permiso por nombre, y la query es válida contra producción.** El javadoc dejaba `personas_perfiles_sas` «sin confirmar contra la base»: **confirmado**. Y hay **13 referentes y 12 jefes activos** en producción, así que va a haber quien apruebe.
- **El script SQL crea todo lo que el código espera:** tabla con las 12 columnas de la entidad, los 4 índices, las 3 FK, los 4 SP con firma y cuerpo idénticos al repo, y el permiso asignado **por nombre** a `referente_siniestros` y `jefe_de_siniestros` (el script del repo lo hacía por id hardcodeado; el de promoción lo corrige).
- **PK de la tabla nueva: sin riesgo de `key_generator`.** `@GeneratedValue(IDENTITY)` contra `AUTO_INCREMENT`. Cero `INSERT` a `autorizaciones` y cero referencias a `key_generator` en el script y en el código nuevo.
- **Etapa 7 verificada en las dos capas:** el SP joinea contra `MAX(id)` y `tienePedidoDeExcepcion` hace `findFirst()` sobre la lista ordenada desc.
- **Residuos de la estrategia vieja: ninguno.** Cero referencias a columnas `duplicado_*` sobre `autorizaciones` en los 5 diffs y en el script, y confirmado contra producción que esa tabla no tiene ninguna columna `duplicado%`. De SE-268 y SE-273 quedan sólo comentarios que documentan la exclusión: ni `fechaLimiteCargaTurnos`, ni `leyendaLimiteCargaTurnos`, ni `admiteTurnosFuturos`. **El corte quedó limpio.**

---

## Consumidores y caminos de escritura que nadie había mirado

Además de los tres ya documentados (`wstramitador`, `grv-frontend`/CEM, `ws-sasconnect`):

| Repo | Dónde | Por qué importa |
|---|---|---|
| **wsauditoria** | `AutorizacionesServiceImpl.java:796,814` | Pone `id_estado_logistica_ida = SOLICITADO` al aprobar. **Es H-3 desde fuera del corte.** El más relevante de la lista. |
| **contrataciones** (front) | `redux/actions/traslados.js:17,203` | POST real a `wstraslados /traslado/save`. **Segundo front** que escribe traslados por el camino legacy, sin gate. No estaba en el mapa. |
| **wsconsultasreclamos** | `EvolucionServiceImpl.java:193,227,516` | **Crea turnos** desde evoluciones, sin pasar por `turnos/crear`. |
| **wsauditoriatraslados** | `TrasladoStrategy.java:121,187` | Escribe `traslados` y `traslados_transporte_publico`. |
| **wsauditoriafacturacion** | `TurnosServiceImpl.java:79` y otros | Escribe `turnos`. |
| **wsorquestadorintegraciones** | `WsLogisticaClient.java:30,43` | Escribe estado de traslados por endpoints en `permitAll()`. |
| **wsaccidentespersonales** | `MotorConsumoSql.java:311,319,498` | Lee `id_estado_logistica_ida IN (4,8)` / `IN (1,2,3)` para calcular consumos AP. Un duplicado pendiente (NULL) no computa hasta que se aprueba: **mueve importes de AP en el tiempo**. |
| **SAS Classic** (legacy) | `AltaTrasladoAction.java:72-276` | Da de alta y cambia estado por EJB contra la misma base. Fuera de todo microservicio y de todo validador. |
| **libdatabase** | entidades + repositorios con `JpaRepository` completo | Cualquier ws que la importe hereda capacidad de escritura sobre esas tablas. |

Y una deuda interna que vale nombrar: **`wsturnos/AuditoriaInformesMedicosQueryBuilder.java` es un clon en Java de `consulta_turnos_tramitadores_sp`** y no tiene ni las 8 columnas nuevas ni el filtro de duplicados. No rompe hoy —es otro endpoint— pero es el tipo de divergencia que se cobra en la próxima modificación del SP.

---

## Qué no se verificó

- **La frecuencia real de H-3.** El camino existe y está verificado; cuántas veces por mes se dispara depende de la configuración de autoaprobación por protocolo y no se puede medir desde el repo.
- **Nada de runtime.** No se ejecutó el script, ni tests, ni se levantaron los servicios.
- **El comportamiento de `CANCELADO_PARCIAL`** en el bloque: viene con `cancelado = true`, así que el front lo trata como resuelto y refresca; debería reaparecer solo si el traslado sigue contando. Autocorrectivo por diseño, pero no probado.
- **Los ambientes bajos:** no se comparó el esquema de TEST/DEV contra producción más allá de la divergencia de perfiles ya reportada.

---

*Generado por Vanesa Burman — QA · 24/08/2026*

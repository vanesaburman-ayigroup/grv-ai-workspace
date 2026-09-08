# Code Review — Spring Boot · Promoción a producción INI-2

**Change:** autorización de traslados duplicados del mismo día — SAS Colonia Suiza
**Ramas revisadas:** `promo/INI-2-prod` en `wsturnos`, `wslogistica`, `wstraslados`
**Base de comparación:** `origin/master` (producción) y, para verificar el corte quirúrgico, `origin/release`
**Skill aplicada:** `spring-boot-review` (checklist de persistencia/transacciones, error handling, API, nullability, microservicio y observabilidad)

---

## Resumen

| Severidad | Cantidad | ¿Bloquea la promoción? |
|---|---|---|
| 🔴 BLOQUEANTE | 3 | Sí (2 de código, 1 de orden de despliegue) |
| 🟠 ALTA | 3 | 1 sí · 2 no (mitigables con seguimiento) |
| 🟡 MEDIA | 5 | No |
| 🔵 BAJA | 3 | No |

**Veredicto:** **NO promover tal cual.** Dos hallazgos de código bloquean (H1 y H2) y son de arreglo chico —siete líneas y una anotación—. El resto del circuito está sano: se verificó símbolo por símbolo que no quedaron inyecciones sin bean, constantes sin traer ni firmas huérfanas, y las cuatro notas de promoción son factualmente correctas contra `origin/master` y `origin/release`.

Los riesgos ya aceptados por la líder técnica (sin JWT en `wsturnos`, `idAutorizante` en el body, ausencia de `@Version`, los seis resultados en HTTP 200, REST dentro de `@Transactional` en `rechazar()`) no se repiten acá. **La única excepción es A4**, que sube de severidad por un cambio de esta misma promoción del lado de `wslogistica`: está en H5.

---

## 🔴 BLOQUEANTES

### H1 — El gate de la tanda de rehabilitación quedó sin quién lo llame

**Bloquea la promoción: SÍ.**

`TrasladoDuplicadoValidator.validarTandaProgramacion(...)` existe, compila y no tiene ningún invocador en la rama.

- `wsturnos/src/main/java/ar/com/riovaradero/service/TrasladoDuplicadoValidator.java:171` — el método.
- `wsturnos/src/main/java/ar/com/riovaradero/controller/TurnosRehabilitacionController.java:136-143` — el endpoint `POST /turnos-rehabilitacion/programar-turno` **no lo llama**. Sólo llama a `denunciaTurnoValidator.validarPuedeProgramarTurno`.

En `origin/release` el call site sí está:

```
origin/release:.../TurnosRehabilitacionController.java:147
    trasladoDuplicadoValidator.validarTandaProgramacion(programarTurnos);
```

**Por qué importa:** es el camino que el propio javadoc del método nombra como el caso del ticket — «el plan de diez sesiones que se programa de una y saca cuatro remises duplicados». En la tanda el traslado todavía no existe cuando se valida, así que `validarProgramacion` (el camino individual, que sí está cableado) no lo cubre: deduce «requiere traslado» de un traslado ya cargado y por eso deja pasar exactamente ese caso. Con el código tal como está, el circuito bloquea el alta, la edición, la programación individual y la generación de autorización, y **deja abierto el único camino masivo**. No falla, no loguea: simplemente no valida.

**Es una omisión limpia del corte, no una decisión.** `git diff origin/master origin/release -- .../TurnosRehabilitacionController.java` son **+7 líneas y 0 borradas**, todas INI-2 (import, `@Autowired`, comentario y la llamada). Traerlas no arrastra ningún otro ticket.

**Fix:** portar esas 7 líneas. La llamada va después del `forEach` de `validarPuedeProgramarTurno` y **antes del `try`**, por lo mismo que SE-214: el 409 tiene que llegar al handler global y no al `catch (Exception)` que devuelve 500.

---

### H2 — `createTurno` no tiene `rollbackFor`: el pedido puede quedar committeado con el alta fallida

**Bloquea la promoción: SÍ.**

`wsturnos/src/main/java/ar/com/riovaradero/service/TurnosServiceImpl.java:1628-1632`

```java
@Transactional            // ← sin rollbackFor
@Override
public UpdateCreateTurnoResponseDTO createTurno(
    MultipartFile file, CreateTurnoDTO createTurnoDTO, MultipartFile ordenMedica, MultipartFile archivoPresupuesto)
    throws Exception {    // ← excepción CHEQUEADA
```

El comentario del bloque de INI-2 (línea 1717) afirma:

> «Va dentro de la transacción del alta: si el alta se revierte, el pedido tampoco existe.»

**Eso no se sostiene.** Spring, con `@Transactional` sin `rollbackFor`, revierte sólo ante `RuntimeException`/`Error`. Una excepción **chequeada** hace **commit** y se propaga igual. Y `createTurno` declara `throws Exception`, con al menos dos caminos chequeados **posteriores** al registro del pedido:

- `guardarArchivo(file, ...)` — `TurnosServiceImpl.java:2144`, `throws Exception`, invocado en la línea 1739 (justo después del bloque del pedido).
- `autorizacionesService.setDetalleAutorizacionPdf(...)` — `IAutorizacionesService.java:24`, `throws Exception`, invocado en la línea ~1787.

Secuencia concreta del defecto: el gestor da de alta un turno con traslado y justificación, el pedido se registra, después falla el guardado de la receta o el armado del PDF → el front recibe 500 y muestra «no se pudo crear el turno», pero en base quedan committeados el turno, el traslado, la autorización **y el pedido de excepción**. Si además quien pidió tenía el permiso, `aprobar()` ya le puso `id_estado_logistica_ida = 1` y `es_duplicado_autorizado = 1`: **el traslado bajó al sector de un turno que el front cree inexistente**. El gestor reintenta y duplica todo, pedido incluido.

El propio archivo prueba que el idiom es conocido: `procesarTurno` (línea ~1837) y `cancelarTrasladosPorTurno` en `wstraslados` (línea 649) usan `@Transactional(rollbackFor = Exception.class)`.

No es un artefacto del corte —`origin/release` tiene la misma anotación—, pero INI-2 es lo que mete estado nuevo y visible para el sector traslados dentro de esa transacción, así que la deuda pasa a tener consecuencia funcional en esta promoción.

**Fix:** `@Transactional(rollbackFor = Exception.class)` en `createTurno`. Si se teme el efecto sobre el resto del alta, la alternativa mínima es envolver el bloque de INI-2 (o el `catch (Exception e)` de la línea 1792) para relanzar como `RuntimeException`; pero la anotación es la corrección correcta y la que ya usan los métodos hermanos.

---

### H3 — Orden de despliegue: sin los scripts y los SP recreados, rompe más que la feature

**Bloquea la promoción: SÍ (es una precondición de la ventana de deploy, no un defecto de código).**

El encabezado del DDL dice, literalmente:

> `IMPORTANTE : script entregado para revisión. NO ejecutado en ningún ambiente.`
> — `wsturnos/src/main/resources/sql/scripts/alter_autorizaciones_traslado_duplicado_mismo_dia.sql`

Y hay una dependencia que va más allá del circuito nuevo: los dos DTO de listado están mapeados como resultado de stored procedure, así que **si el SP no devuelve las columnas nuevas, la consulta entera falla, no sólo el campo**.

- `wsturnos` — `TurnosTramitadoresResponseDTO` es `@Entity` con `@SqlResultSetMapping`/`@ConstructorResult`; la promoción le agrega **8 `@ColumnResult`** (`idAutorizacionTrasladoDuplicado`, `justificacionDuplicado`, `solicitanteDuplicado`, `fechaSolicitudDuplicado`, `estadoDuplicado`, `dictamenDuplicado`, `fechaAutorizacionDuplicado`, `autorizanteDuplicado`). Si `consulta_turnos_tramitadores_sp` no se recrea, **se cae la grilla de tramitadores completa, todas las pestañas**.
- `wslogistica` — `TrasladoResponseDTO` usa `resultClasses = TrasladoResponseDTO.class` y suma `esDuplicadoAutorizado`. Los tres SP de listado fueron actualizados en la rama (`consulta_traslado_remis_amb_logistica`, `consulta_traslados_aereos_logistica`, y `NULL as es_duplicado_autorizado` en `consulta_traslados_internos_logistica`). Si no se recrean, **se cae el listado de logística completo**.

Checklist mínimo, en este orden, antes de subir los jars:

1. `alter_autorizaciones_traslado_duplicado_mismo_dia.sql` — tabla + las dos columnas `es_duplicado_autorizado` + permiso `autorizar_traslado_mismo_dia` y sus 4 perfiles.
2. `INI-2-alter-autorizaciones-traslado-duplicado-visto-solicitante.sql` — **imprescindible aparte**: el bloque 1 del script anterior **no** crea `fecha_visto_solicitante`, y la entidad la mapea (`AutorizacionTrasladoDuplicado.java:79`). Sin esta columna, arranca pero falla toda lectura/escritura de la tabla.
3. Recrear los 4 SP (1 de `wsturnos`, 3 de `wslogistica`).
4. Recién entonces desplegar. El rollback tiene el mismo problema al revés: **bajar el jar sin bajar el SP** deja las grillas rotas.

Lo verificado y **correcto** del DDL: la FK `fk_atd_traslado_tp` apunta a `traslados_transporte_publico(id_traslado)` y ese *es* el nombre real de la PK (`TrasladosTransportePublico.java:32`, `@Column(name = "id_traslado")`); el `SET @id_permiso_nuevo` fuera del `INSERT ... SELECT` es la forma idempotente correcta; el `ADD COLUMN IF NOT EXISTS` es reejecutable.

---

## 🟠 ALTA

### H4 — `aprobar()` devuelve `NO_ENCONTRADO` pero deja el pedido committeado en `APROBADA`

**Bloquea la promoción: SÍ, es de una línea.**

`wsturnos/.../AutorizacionTrasladoDuplicadoServiceImpl.java:285-350`

En `resolver()` el estado ya se persistió (`pedido.setEstado(APROBADA)` + `save`, líneas 253-260) **antes** de llamar a `aprobar()`. Si después ninguno de los dos bloques encuentra su traslado, `aprobar()` loguea el warn, devuelve `noEncontrado(...)` con `resuelto = false` y **retorna normalmente**: la transacción **commitea** el `APROBADA`.

El resultado es el peor de los dos mundos, y es justo el que el javadoc del método dice haber cerrado: el pedido figura resuelto —desaparece de la grilla de pendientes para siempre—, el front recibe «avisá a soporte», y el traslado no tiene ni estado de logística ni la marca. Nadie lo puede reintentar desde ninguna pantalla.

El mismo camino se recorre desde el alta: `registrar()` → `aprobar()`. Ahí el pedido nace `APROBADA` y queda igual de inaplicable.

**Fix:** que ese caso no commitee. Lo más directo es lanzar una `RuntimeException` de negocio en lugar de retornar (o mover el `save` del estado a después de `aprobar()`, sólo si `seAplico`). Dejarlo `PENDIENTE` es preferible a un `APROBADA` inaplicable: al menos sigue en la grilla de quien autoriza.

### H5 — A4 empeora por esta promoción: `wslogistica` dejó de fallar con 500 y `wsturnos` sigue sin leer el body

**Bloquea la promoción: NO, pero cambia la evaluación de A4 y hay que decidirlo antes de la ventana.**

A4 estaba anotado como «`fetchLogisticaOnCancelacion` devuelve `void`, el rechazo no comprueba si la cancelación ocurrió». Esta promoción **le quita la última red de seguridad** que ese diseño tenía:

- Antes (`origin/master`, `wslogistica/.../TrasladoServiceImpl.java`): traslado inexistente → `throw new IllegalArgumentException("No se encontró el traslado con id: " + idTraslado)` → 500 → `restTemplate.exchange` en `wsturnos` lanzaba `HttpServerErrorException` → **la transacción de `resolver()` revertía y el pedido NO quedaba `RECHAZADA`**.
- Ahora (línea 3186): `return ResultadoCancelacionDTO.noEncontrado(idTraslado)` → **HTTP 200**. Y el `catch (Exception)` del final devuelve `ResultadoCancelacionDTO.errorSistema(idTraslado)`, también 200.

Del otro lado, `wsturnos` no fue tocado: `IRestInvokeService.java:50` sigue declarando `void fetchLogisticaOnCancelacion(...)` y `RestInvokeServiceImpl.java:508-512` sigue deserializando en `ResponseDTO.class` y descartando el cuerpo. Es decir: `rechazar()` (línea 380) ya **no tiene ninguna vía** —ni body ni status— para enterarse de que la cancelación no ocurrió. El pedido commitea `RECHAZADA`, el gestor lee «se canceló el traslado» y el traslado sigue vivo y coordinado.

Nota de contexto: `wstraslados` **sí** hizo el trabajo completo en esta misma promoción (`fetchLogisticaOnCancelacion` devuelve `ResultadoCancelacionDTO`, `cancelarTrasladosPorTurno` lo propaga al front, `agregarResultado` loguea el `!cancelado`). Los dos consumidores del mismo endpoint quedaron con criterios opuestos.

**Fix mínimo (no invasivo, ~15 líneas):** replicar en `wsturnos` lo que ya se hizo en `wstraslados` — que `fetchLogisticaOnCancelacion` devuelva el DTO y que `rechazar()` chequee `isCancelado()`; si vino `false`, no devolver `RECHAZADA` sino un resultado que lo diga, y no commitear el estado.

### H6 — La intención de pedido desarma el gate en la edición, pero `updateTurno` no registra ningún pedido

**Bloquea la promoción: NO** (existe igual en `origin/release`, no es artefacto del corte) — **pero es el agujero que el circuito vino a cerrar.**

`contarConflictoSinResolver` (`TrasladoDuplicadoValidator.java:362`) devuelve 0 en cuanto `tieneIntencionDePedido == true`, antes de tocar la base. `TurnosController.java:264-274` le pasa ese flag en la edición, tomado de `updateTurnoDTO.getUpdateTrasladoDTO().tieneIntencionDePedidoDuplicado()`.

En el alta eso es correcto y está bien argumentado: `createTurno` registra el pedido unas líneas más abajo, en la misma transacción. **En la edición no hay nada equivalente**: `registrarPedidoDelAlta` se invoca en un único lugar (`TurnosServiceImpl.java:1728`, dentro de `createTurno`). `updateTurno` no lo llama.

Consecuencia: mandar cualquier string no vacío en `justificacionTrasladoDuplicado` al editar un turno **pasa el gate y no deja pedido alguno**. Es textualmente lo que el comentario de `validarGeneracionAutorizacion` (líneas 228-232) se niega a permitir para la generación de autorización: «aceptarla dejaría pasar el duplicado sin que quede pedido que resolver: ni autorización, ni rastro».

**Fix:** o `updateTurno` registra su propio pedido (como el alta), o `validarEdicion` no acepta la intención y exige motivo declarado o pedido preexistente. Cualquiera de los dos cierra el agujero; el segundo es de una línea.

---

## 🟡 MEDIA

### H7 — Nada garantiza el invariante «una sola de las dos columnas de traslado»
**No bloquea.**

`PedirAutorizacionDuplicadoDTO` declara `idTraslado` y `idTrasladoTransportePublico` **ambos opcionales**, sin validación cruzada, mientras la entidad y el javadoc de `registrarPedidoDelAlta` afirman «nunca se llenan las dos columnas a la vez».

- **Ambos null** → el pedido se guarda igual; `aprobar()` no entra en ningún bloque, `seAplico = false` → cae en H4.
- **Ambos con valor** → `aprobar()` marca los dos traslados; y `rechazar()` manda los dos ids a `wslogistica`, que resuelve por `request.idTrasladoTransportePublico() != null` (`TrasladoServiceImpl.java:3172`) y **cancela sólo el de transporte público**: el traslado normal queda vivo con el pedido en `RECHAZADA`.

**Fix:** un `@AssertTrue` en el DTO (o un chequeo en `pedir()`) que exija exactamente uno.

### H8 — `contarTrasladosVigentesEnFecha`: join implícito INNER y `FUNCTION('DATE')` sobre la columna filtrada
**No bloquea.**

`wsturnos/.../repositories/ITrasladoRepository.java`

```sql
AND FUNCTION('DATE', t.turno.fechaTurno) = FUNCTION('DATE', :fecha)
AND t.estadoTraslado.idEstadoTraslado NOT IN (4, 5)
```

Dos cosas:
1. `t.estadoTraslado.idEstadoTraslado` genera un **INNER JOIN implícito**. Un traslado con `id_estado_traslado` NULL **no se cuenta como conflicto** y el gate lo deja pasar — silenciosamente, que es la peor forma de no validar. Si esos NULL existen en `traslados` (los hubo: `GRV-2229` fue precisamente «setear último estado conocido a turnos con estado null»), el gate tiene un hueco. Se arregla con `LEFT JOIN` explícito + `(estado IS NULL OR estado NOT IN (4,5))`.
2. `FUNCTION('DATE', t.turno.fechaTurno)` inhabilita cualquier índice sobre `fecha_turno`. Preferible `fechaTurno >= :desde AND fechaTurno < :hasta`. El costo se multiplica: la tanda llama a esta query una vez por sesión.

### H9 — El permiso no chequea que el perfil esté activo
**No bloquea.**

`IPermisoSasRepository.contarPermisoDePersona` filtra `pps.activo = 1`, `ppp.activo = 1` y `perm.activo = 1`, pero **no** `perfiles_sas.activo`. Una persona cuyo perfil fue dado de baja lógicamente conserva la capacidad de autorizar excepciones (y de auto-aprobarse la propia, vía `registrar()`).

Sobre la advertencia del javadoc («`personas_perfiles_sas` se toma de la documentación y quedó sin confirmar contra la base»): **la forma de la query es correcta**. El esquema de `cs` documentado para las tablas SAS usa `personas_perfiles_sas(id_persona, id_perfil, activo)`, que es exactamente lo que la query asume. Igual conviene correrla una vez contra PROD antes del deploy: es la query de la que dependen `pedir`, `registrar` y `resolver`, y si falla, falla con un 500 en runtime, no en el arranque.

### H10 — Las notas 2 y 3 atribuyen a SE-273 dos cambios distintos, y `release` perdió una lógica que producción tiene
**No bloquea. La promoción está bien; la advertencia es para cuando se promueva `release`.**

Verifiqué las cuatro notas contra `origin/master` y `origin/release`. **Las cuatro son factualmente correctas** (detalle en «Destacados»). El problema es de etiquetado y de lo que revela:

- `AutorizacionesController.java:50` y `TurnosController.java:256` describen SE-273 como «validación estado médico 10 y fecha sin modificar al editar».
- `TurnosController.java:498` describe SE-273 como «no anular turnos al cerrar un siniestro que sigue en gestión».

Son dos alcances distintos con el mismo número; uno de los dos está mal etiquetado y eso vuelve la nota inútil justo cuando se la va a usar (al re-promover, para saber qué revertir).

Más importante, el dato que aparece al verificarla: en `origin/master` (producción) el controller usa `isEnvioMailLogistica` + `MULTI_STATUS`; en `origin/release` **no existe ese uso en el controller**, aunque el campo sigue en `AnularTurnosPorDenunciaResponseDTO`. O sea que **`release` está por debajo de producción en ese punto**: si se promueve tal cual, se regresiona el criterio de los traslados facturables al cerrar siniestro. Esta promoción hace bien en conservar producción; el problema hay que resolverlo en `release`.

### H11 — Dos consultas evitables por request
**No bloquea.**

- `TrasladoDuplicadoValidator.validarProgramacion` (líneas 136 y 144) hace `turnoRepository.findById(idTurno)` **dos veces** para leer denuncia y autorización del mismo turno. Con el `open-in-view` por defecto la segunda pega en el contexto de persistencia, pero es gratis unificarla en una variable — como sí hacen `validarEdicion` y `validarTandaProgramacion`.
- `ConflictoTrasladoServiceImpl.descripcionesEstadoTraslado()` hace `estadoTrasladoRepository.findAll()` del catálogo **una vez por `mapear`**, y `mapear` se llama dos veces por request (traslados + transporte público). Son once filas, así que es menor, pero se resuelve calculándolo una vez en `consultarConflictos` o cacheándolo.

---

## 🔵 BAJA

### H12 — Código muerto de la feature
**No bloquea.** También está muerto en `origin/release`, así que no es artefacto del corte: `Constantes.LOG_ERROR_PEDIDO_DUPLICADO_EN_ALTA`, `AutorizacionTrasladoDuplicadoRepository.findFirstByIdTrasladoOrderByIdAutorizacionTrasladoDuplicadoDesc`, `EstadoAutorizacionDuplicadoEnum.estaPendiente` y `.fromCodigo`. Los cuatro tienen una sola aparición: su declaración. El del repositorio es el que más engaña, porque su javadoc describe un caso de uso («resolver desde la grilla, donde el usuario tiene el traslado y no la autorización») que hoy no existe.

Nota menor de duplicación: `Constantes.java` declara `UNO_LONG_DUPLICADO = 1L` y `ESTADO_LOGISTICA_SOLICITADO = 1L` conviviendo con el ya existente `ONE_LONG = 1L`, que el propio validator usa.

### H13 — `@Size(max = 1000)` sobre la justificación no se valida en el alta
**No bloquea.**

`TurnosController.java:286-290`: el `@RequestPart(value = "dto") CreateTurnoDTO createTurnoDTO` **no lleva `@Valid`** (tampoco lo lleva el de `updateTurno`). Las anotaciones nuevas de `GenerarTrasladoDTO` (`@Size(max = 1000)` en `justificacionTrasladoDuplicado`) no se aplican nunca por ese camino. La columna es `VARCHAR(1000) NOT NULL`, así que una justificación más larga llega hasta el flush y aborta el alta completa con un 500 opaco. Es pre-existente del endpoint, y la feature nueva le agrega un campo más que lo puede disparar.

### H14 — Detalles de estilo/inyección en `AutorizacionesController`
**No bloquea.** `@Autowired private AutorizacionTrasladoDuplicadoServiceImpl autorizacionDuplicadoService;` está declarado en la **línea 165**, después de varios métodos, en vez de junto al resto de las dependencias (línea 41-43); y se inyecta la clase concreta en lugar de una interfaz. Funciona (sin interfaz Spring proxya con CGLIB, así que `@Transactional` sigue activo y los `private` llamados desde dentro comparten transacción como se espera), pero rompe la convención del resto del servicio y complica el testeo.

---

## 🟢 Destacados — verificado y correcto

- **Las cuatro notas de promoción son exactas.** Comprobadas contra `origin/master` y `origin/release`:
  - `AutorizacionesController.java:50` — la línea `validarDenunciaAdmiteTurnosFuturos` es idéntica a producción; `release` la reemplaza por `validarPuedeGenerarAutorizacion` (SE-268). Coherente.
  - `TurnosController.java:256` — `release` agrega efectivamente `validarPuedeProgramarTurno` en `updateTurno`; la promoción no la trae. Coherente (el etiquetado del ticket es lo cuestionado en H10, no el hecho).
  - `TurnosController.java:498` — la línea conservada (`isEnvioMailLogistica` → `MULTI_STATUS`) es exactamente la de `master`; `release` tiene `PARTIAL_CONTENT`. Coherente, y es la nota mejor puesta de las tres (ver H10).
  - `EstadosTrasladosEnum.java:6` (wslogistica) — se conserva la numeración de producción (6..9). Verifiqué que **el circuito nuevo no lee ninguno de los códigos renumerados**: `ESTADOS_SIN_CONFLICTO` usa CANCELADO=4 y RECHAZADO=5, y las descripciones de la grilla salen del catálogo `estados_traslados` por query, no del enum. El corte es seguro.
- **El pedido del alta apunta al traslado correcto y no puede quedar huérfano.** Verifiqué que `createNewTraslado` (línea 2280) y `createTrasladoTransportePublico` hacen su propio `save` y devuelven la entidad con id, así que los ids que se le pasan a `registrarPedidoDelAlta` son reales y no dependen de cascade ni de flush. El `else if` con `LOG_PEDIDO_DUPLICADO_SIN_TRASLADO` cubre el caso de intención sin traslado creado. Es el bug original de INI-2 (pedido apuntando al traslado preexistente) bien cerrado.
- **`marcarResueltosComoVistos` está bien hecho:** la condición «sin ver» vive en el `WHERE` del update, así que es idempotente de verdad; `clearAutomatically = true` está justificado y correctamente argumentado; la fecha entra por parámetro y no como `CURRENT_TIMESTAMP`, coherente con el resto del circuito.
- **Sin PII en logs.** Los logs del circuito llevan ids (turno, autorización, traslado, solicitante, autorizante) y **nunca** la justificación ni datos del paciente, con el criterio explicitado en el comentario de la línea 170. Cumple el checklist de la skill.
- **La guarda de facturación por tramo de `wslogistica`** (`resolverTramosACancelar` / `combinar`) es la mejor parte de la promoción: los tramos son independientes, no cancela lo facturable, marca `requiereRevision` cuando no cancela nada, y `marcarParaRevisionBestEffort` está aislado para no tapar el error original. El `recortar(...)` por longitud de columna (500 ida / 255 vuelta) evita que una observación larga tumbe la cancelación entera.
- **`ConflictoTrasladoServiceImpl` no tiene N+1**: `idsConAgenciaInformada` resuelve las agencias informadas con **una sola query por lote de ids** en vez de una por traslado, y las proyecciones evitan traer entidades. `@Transactional(readOnly = true)` correctamente aplicado en las lecturas (también en `contarPendientes` y `contarResueltosSinVer`).
- **El handler de `MissingServletRequestParameterException`** convierte en 400 lo que antes caía en el `catch (Exception)` y salía como 500. Correcto y bien acotado.
- **`tienePedidoDeExcepcion` toma sólo el último pedido** (`findByAutorizacion` ordena por id descendente + `findFirst`), no un `anyMatch` sobre el histórico. Cierra el agujero de RF-4.3 —un aprobado viejo neutralizando un rechazo nuevo— y es coherente con el `MAX(id)` que joinea la grilla.

---

## Preguntas al autor

1. **H1** — ¿Se dejó afuera `TurnosRehabilitacionController` a propósito, o es la omisión que parece? Son 7 líneas, todas INI-2.
2. **H5** — A4 estaba «identificado y sin decidir». Con `wslogistica` devolviendo 200 en los caminos de falla, ¿se decide ahora portar a `wsturnos` lo que ya se hizo en `wstraslados`, o se acepta que el rechazo no verifique nada?
3. **H4** — Cuando el pedido se aprueba pero no se puede aplicar: ¿queda `PENDIENTE` (recuperable desde la grilla) o se lanza para revertir? Hoy queda `APROBADA` e inaplicable, que es la única opción sin salida.
4. **H6** — ¿La edición va a registrar su propio pedido, o el gate de edición deja de aceptar la intención?
5. **H3** — ¿Quién corre los 4 SP y los 2 scripts, y en qué orden respecto del deploy de los jars? El plan de rollback necesita el orden inverso explícito.
6. **H10** — ¿Cuál de las dos notas tiene el número de ticket correcto? Y aparte: ¿está registrado que `release` perdió `isEnvioMailLogistica` respecto de producción?

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026*

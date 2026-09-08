## Why

Cuando un gestor de tramitadores carga un turno con traslado en una fecha donde el paciente **ya tiene un traslado vigente**, hoy el sistema no lo frena: se pide un segundo remis a una agencia, con costo, para un paciente que ya tenía viaje. Logística lo cancela **si lo detecta** — a veces con la agencia ya avisada; cuando no lo detecta, se paga.

**El volumen es dos órdenes de magnitud mayor al estimado.** En la reunión del 06/08 se habló de unos 4 casos por mes. Medido sobre la base: **307 días-paciente por mes** con más de un traslado vigente, creciendo de 254 en enero a 394 en junio de 2026. De esos, **~58 por mes no tienen ningún motivo declarado**, y los 2.156 restantes están «declarados» contra una autorización que **no existe como circuito**: el campo se llena, nadie lo aprueba.

**El problema no se ve en los números de logística**, y por eso venía subestimado: «OTROS MOTIVOS» concentra 10.869 de ~15.900 anulaciones (68%) y el 47% de ellas no tiene observación escrita. El motivo específico de duplicado (16) subestima el volumen real, así que no sirve como línea de base.

Falta, entonces, un circuito de excepción explícito: que el segundo traslado del mismo día **requiera una decisión de alguien con autoridad**, que esa decisión quede registrada con quién, cuándo y por qué, y que el resultado le vuelva a quien lo pidió. Y que el gate **no viva sólo en el front**, porque hoy cualquier llamada directa al backend lo esquiva.

## What Changes

- **Bloque de conflicto en el drawer de nuevo turno** (`tramitadores`): al elegir una fecha con traslado vigente se muestra el traslado en conflicto **por sus datos, nunca por su id** (turno, tipo, hora, centro médico, agencia y si a la agencia ya se le avisó), y el gestor **elige una de tres salidas excluyentes**: anular el traslado preexistente, guardar el turno sin traslado, o pedir/declarar la autorización del duplicado. **Qué salidas están habilitadas lo decide el backend**, caso por caso, según el estado operativo real: el front sólo las renderiza.
- **Nueva tabla `cs.autorizaciones_traslado_duplicado`**: el pedido de excepción con su `estado` (pendiente / aprobada / rechazada), la **justificación** del solicitante, el **dictamen** de quien resuelve, ambos actores, sus fechas, y `fecha_visto_solicitante` para la devolución del resultado.
- **Nuevo permiso `autorizar_traslado_mismo_dia`**, asignado a los perfiles de referente, jefe de siniestros, gerente de siniestros y supervisor. **El permiso es el único discriminador** — no se usa el rol —, y se resuelve por nombre en las dos puntas.
- **Circuito de pedir y resolver** (`wsturnos`): quien **no** tiene el permiso escribe una justificación obligatoria y el pedido queda pendiente; quien **sí** lo tiene resuelve en el acto y el duplicado queda aprobado a su nombre, sin pedirse autorización a sí mismo. Un pedido resuelto no se vuelve a resolver, y el segundo que abra el mismo pedido recibe un aviso en lugar de pisarlo.
- **Card en el home de quien autoriza** con la cantidad de pedidos pendientes, que lleva a la grilla ya filtrada; y **card en el home de quien pide** con el resultado de sus pedidos —quién los resolvió, cuándo y con qué dictamen—, que se apaga sola al leerlos.
- **La llave de visibilidad de logística es `id_estado_logistica_ida`, no el estado del traslado**: mientras el pedido está pendiente el traslado se crea con ese campo **nulo**, así que logística **no lo ve** y no puede cancelarlo como duplicado. Al aprobar se le asigna Solicitado y recién ahí baja al sector, **marcado** con franja, ícono con tooltip y entrada en la leyenda. Al rechazar se cancela con el motivo de anulación 16 y logística nunca se enteró.
- **Gate server-side** (`wsturnos`): el alta y la programación de un turno con segundo traslado del mismo día **se rechazan con 409 CONFLICT** si no hay ni motivo declarado ni pedido de excepción. Se acepta motivo declarado, pedido pendiente o pedido aprobado, y **se rechaza explícitamente un pedido RECHAZADO** — si no, alcanzaría con pedir la excepción y que la nieguen para cargar el traslado igual.
- **La anulación del preexistente reutiliza el circuito de cancelación que ya existe** (`wstraslados`), que cancela todos los tramos del turno —ida, vuelta y transporte público— en una sola transacción, y **devuelve el resultado real** para que el gestor vea antes de guardar si el traslado quedó vigente.
- **Regla transversal de presentación: nunca se muestra un id al usuario.** Ni de turno, ni de traslado, ni de autorización, ni de persona. Aplica también a los textos que se persisten: la observación de anulación nombra el turno por su tipo y hora.

## Capabilities

### New Capabilities

- `conflicto-traslado-mismo-dia`: detección del conflicto con el estado operativo real del traslado preexistente, las tres salidas excluyentes resueltas por el backend, el caso de la tanda de rehabilitación, y la regla transversal de no mostrar identificadores internos.
- `autorizacion-traslado-duplicado`: el pedido de excepción y su resolución — justificación obligatoria, auto-aprobación de quien tiene el permiso, dictamen obligatorio al rechazar, idempotencia y card de pendientes de quien autoriza.
- `devolucion-resultado-solicitante`: la vuelta del circuito — card en el home de quien pidió, con el resultado, el autorizante por su nombre, el dictamen, y el marcado de vistos que apaga la card.
- `visibilidad-duplicado-logistica`: qué ve el sector logística en cada uno de los cuatro casos, con `id_estado_logistica_ida` como llave de visibilidad, la marca del duplicado autorizado y la cancelación por motivo 16.
- `gate-servidor-traslado-duplicado`: la validación en el backend que no depende del front — 409 CONFLICT, qué acepta, el rechazo explícito del pedido RECHAZADO y la obligación de invocarla desde todo endpoint que cree o programe turnos.

### Modified Capabilities

<!-- No hay specs canónicas previas en openspec/specs/ para estas capacidades. -->

## Impact

**Base de datos (esquema `cs`, MariaDB 10.5)** — DDL y DML separados; los stored procedures van **antes** que el código:

- `CREATE TABLE cs.autorizaciones_traslado_duplicado` con FK a `autorizaciones` y a `traslados`.
- `ALTER TABLE cs.traslados ADD COLUMN es_duplicado_autorizado` — la marca que hace que logística no lo cancele.
- `ALTER TABLE cs.autorizaciones_traslado_duplicado ADD COLUMN fecha_visto_solicitante` — el apagado de la card del solicitante.
- Alta del permiso `autorizar_traslado_mismo_dia` y su asignación por perfil, resuelta **por nombre** con `CROSS JOIN` (no por id fijo).
- **Cuatro stored procedures reemplazados** para exponer los datos del pedido en el listado de turnos y el filtro de pendientes. `resultClasses` de Hibernate exige que el SP devuelva **todas** las columnas mapeadas, así que el SP tiene que estar aplicado **antes** de desplegar el código: el orden inverso rompe la pantalla. MariaDB no tiene `CREATE OR REPLACE PROCEDURE`, así que el DROP+CREATE deja una ventana — se aplica en horario de bajo tráfico y con backup del cuerpo previo.

**Backend:**

- `wsturnos` (Java 11, **Spring Boot 2.1.2 — EOL**, `javax.*`, JUnit 4, sin Lombok en entidades): la tabla, la entidad, el repositorio, el servicio con la máquina de estados, los cinco endpoints del circuito, el validador del gate y el mapeo a 409 en el `GlobalExceptionHandler`.
- `wslogistica` (**Spring Boot 3.3.13** — no comparte el EOL de `wsturnos`): el endpoint de conflictos del mismo día, que es el que decide qué salidas están habilitadas, y la cancelación por motivo 16.
- `wstraslados` (Spring Boot 2.1.2): que `cancelar-por-turno` devuelva el resultado real de la cancelación en lugar de un 200 vacío — sin esto el front da por cancelado un traslado que sigue vigente.

**Frontend:**

- `tramitadores` (React, JS sin RTK Query): el bloque de conflicto dentro del wizard de nuevo turno, la tab y la grilla de pedidos pendientes, el drawer de resolución, y las dos cards del home.
- `logistica` (React + TypeScript): la marca del duplicado autorizado en la grilla — franja, ícono con tooltip y leyenda —, convivendo con la señal de «requiere revisión» sin taparla.

**Despliegue en cinco servicios coordinados.** dev ← `develop`, test ← `release`, stage ← `stage` por webhook de AWS CodePipeline; prod ← `master` por Jenkins. **El front no se puede desplegar solo**: sin el backend, el filtro de la grilla se descarta en silencio y la pestaña muestra los ~4,4 millones de turnos del histórico como si fueran pedidos pendientes.

**Sin cambios incompatibles de API.** Los endpoints son nuevos; los campos agregados a los DTO existentes son opcionales y los consumidores que no los conocen siguen funcionando.

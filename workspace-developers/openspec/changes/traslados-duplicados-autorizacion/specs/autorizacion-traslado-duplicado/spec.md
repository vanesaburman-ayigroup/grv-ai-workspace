## ADDED Requirements

### Requirement: El permiso es el único discriminador

El sistema SHALL decidir quién puede autorizar un traslado duplicado del mismo día **exclusivamente** por el permiso `autorizar_traslado_mismo_dia`, y NO SHALL usar el rol ni el perfil como criterio. El permiso SHALL resolverse **por su nombre** en el backend y en el frontend, de modo que su identificador interno pueda diferir entre ambientes sin afectar el comportamiento.

#### Scenario: Habilitación por permiso, no por rol

- **WHEN** se evalúa si una persona puede resolver pedidos de autorización
- **THEN** la decisión se toma consultando el permiso `autorizar_traslado_mismo_dia` por nombre, y NO comparando su rol o su perfil contra una lista

#### Scenario: El identificador del permiso difiere entre ambientes

- **WHEN** el permiso quedó dado de alta con distinto identificador interno en dos ambientes
- **THEN** el circuito funciona igual en los dos, porque ninguna de las dos puntas lo resuelve por identificador

### Requirement: Pedido de autorización con justificación obligatoria

Un gestor **sin** el permiso SHALL poder pedir la autorización del traslado duplicado escribiendo una **justificación obligatoria**. El sistema NO SHALL registrar el pedido sin justificación. La justificación SHALL ser el texto que lee quien resuelve.

#### Scenario: El gestor sin permiso pide la autorización

- **WHEN** un gestor sin el permiso elige autorizar los dos traslados y escribe la justificación
- **THEN** el pedido queda registrado en estado **pendiente**, a nombre del solicitante y con su fecha, y el turno se guarda

#### Scenario: Sin justificación no hay pedido

- **WHEN** se intenta registrar un pedido sin justificación
- **THEN** el sistema lo rechaza

### Requirement: Quien tiene el permiso resuelve en el acto

Un gestor **con** el permiso SHALL resolver el duplicado en el momento: declara el motivo y el pedido queda **aprobado y registrado a su nombre**. El sistema NO SHALL crear un pedido pendiente que esa misma persona deba aprobarse a sí misma.

#### Scenario: Auto-aprobación de quien tiene el permiso

- **WHEN** un gestor con el permiso elige autorizar los dos traslados y declara el motivo
- **THEN** el pedido se registra directamente como **aprobado**, con esa persona como autorizante y solicitante, y el traslado baja a logística en el acto

### Requirement: El pedido se registra en la misma transacción que el turno

El sistema SHALL registrar el pedido de autorización **dentro de la misma transacción** que crea el turno y su traslado, y SHALL asociarlo al **traslado recién creado**. El sistema NO SHALL asociar el pedido al traslado preexistente, y NO SHALL dejar pedidos huérfanos si la creación del turno falla. La transacción SHALL revertirse también ante excepciones verificadas (`rollbackFor = Exception.class`).

#### Scenario: El pedido apunta al traslado nuevo

- **WHEN** se crea un turno con traslado que requiere autorización
- **THEN** el pedido queda asociado al traslado que se acaba de crear, y al aprobarlo se marca y se libera **ese** traslado, no el preexistente

#### Scenario: Si falla la creación del turno no queda rastro del pedido

- **WHEN** la creación del turno falla después de haberse registrado el pedido, por cualquier excepción incluidas las verificadas
- **THEN** la transacción se revierte completa y no queda ni turno, ni traslado, ni pedido

### Requirement: Card de pedidos pendientes para quien autoriza

Quien tiene el permiso SHALL ver en su home una card con la **cantidad de pedidos pendientes**, que lleva a la grilla ya filtrada a esos pedidos. La card SHALL mostrarse únicamente cuando la persona tiene el permiso **y** existe al menos un pedido pendiente.

#### Scenario: La card aparece con pedidos pendientes

- **WHEN** una persona con el permiso entra a su home y hay pedidos pendientes
- **THEN** ve la card con la cantidad, y al entrar accede a la grilla filtrada a los pendientes

#### Scenario: Sin pedidos la card no se muestra

- **WHEN** no hay ningún pedido pendiente
- **THEN** la card no se muestra, igual que el resto de las cards del home

#### Scenario: Sin el permiso no hay card ni grilla

- **WHEN** una persona sin el permiso entra a su home
- **THEN** no ve la card de pendientes ni la pestaña de la grilla de autorizaciones

### Requirement: La grilla muestra solicitante, fecha y justificación

En la grilla de pedidos pendientes cada fila SHALL mostrar el **solicitante**, la **fecha del pedido** y la **justificación**. Las acciones disponibles SHALL ser **ver detalle**, **gestionar autorización** y **ver información de traslado**.

#### Scenario: La fila da el contexto para decidir

- **WHEN** quien autoriza abre la grilla de pendientes
- **THEN** cada fila muestra quién pidió, cuándo y con qué justificación, sin necesidad de abrir el detalle para saber de qué se trata

#### Scenario: Ver información del traslado

- **WHEN** quien autoriza elige «ver información de traslado» sobre una fila
- **THEN** accede a la información del traslado en conflicto, no a su identificador

### Requirement: Resolución con dictamen obligatorio al rechazar

Al resolver un pedido el sistema SHALL exigir el **dictamen para rechazar** y SHALL tratarlo como opcional para aprobar. El sistema NO SHALL permitir un rechazo sin dictamen, porque deja al gestor sin saber qué hacer con el turno. La obligatoriedad SHALL estar garantizada **en el backend** y no sólo en la validación del formulario.

#### Scenario: Rechazo sin dictamen

- **WHEN** se intenta rechazar un pedido sin dictamen, incluso llamando al endpoint directamente
- **THEN** el backend rechaza la operación y el pedido queda como estaba

#### Scenario: Aprobación sin dictamen

- **WHEN** se aprueba un pedido sin escribir dictamen
- **THEN** la aprobación se registra igual, porque el dictamen es opcional al aprobar

### Requirement: Un pedido resuelto no se vuelve a resolver

El sistema SHALL impedir que un pedido ya resuelto —aprobado o rechazado— vuelva a resolverse. Si dos personas abren el mismo pedido, la segunda SHALL recibir un **aviso de que ya fue resuelto**, con quién lo resolvió y cuándo, y la grilla SHALL refrescarse. Ese aviso NO SHALL presentarse como un error.

#### Scenario: Dos personas abren el mismo pedido

- **WHEN** una segunda persona intenta resolver un pedido que acaba de ser resuelto
- **THEN** recibe la información de que ya fue resuelto, por quién y cuándo, su decisión no se aplica, y la grilla se actualiza

#### Scenario: La resolución es idempotente

- **WHEN** la misma resolución se envía dos veces
- **THEN** la segunda no altera el estado, el autorizante ni la fecha registrados por la primera

### Requirement: El pedido que vale es el último

Cuando un traslado tiene más de un pedido a lo largo del tiempo, el sistema SHALL considerar **únicamente el último** para decidir si el duplicado está habilitado. Todas las puntas —el listado, el validador del gate y las consultas de estado— SHALL usar el mismo criterio. Un pedido aprobado **anterior** a un rechazo NO SHALL habilitar el traslado.

#### Scenario: Un rechazo posterior no se neutraliza con un aprobado viejo

- **WHEN** un traslado tiene un pedido aprobado y, después, un pedido rechazado
- **THEN** el estado vigente es **rechazado**: el traslado no aparece habilitado ni en la grilla ni ante el validador

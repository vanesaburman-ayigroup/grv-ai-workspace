## ADDED Requirements

### Requirement: Quien pidió la autorización se entera del resultado

El sistema SHALL devolverle el resultado a quien pidió la autorización. En su home SHALL ver una card con la **cantidad de pedidos resueltos que todavía no vio**, y al entrar SHALL acceder a la lista con, por cada pedido: el **resultado** (aprobado o rechazado), **quién lo resolvió** identificado por su nombre, **cuándo**, el **dictamen** y la **justificación que él mismo había escrito**.

#### Scenario: El gestor ve el resultado de su pedido

- **WHEN** un pedido del gestor fue aprobado o rechazado y él todavía no lo vio
- **THEN** su home muestra la card con el contador, y al entrar ve el resultado, el nombre de quien resolvió, la fecha, el dictamen y su propia justificación

#### Scenario: El autorizante se nombra por su nombre

- **WHEN** la lista muestra quién resolvió el pedido
- **THEN** lo identifica por su nombre y NO por su identificador interno

#### Scenario: Un rechazo llega con su explicación

- **WHEN** el pedido fue rechazado
- **THEN** el gestor ve el dictamen que explica por qué, de modo que sepa qué hacer con el turno

### Requirement: La card se apaga al leer los resultados

Al entrar a la lista, los pedidos resueltos SHALL quedar marcados como **vistos** y la card SHALL apagarse sola. El marcado SHALL ser **idempotente**: volver a entrar NO SHALL repisar la fecha del primer visto ni reactivar la card.

#### Scenario: Leer los resultados apaga la card

- **WHEN** el gestor entra a la lista de sus pedidos resueltos
- **THEN** esos pedidos quedan marcados como vistos y la card desaparece de su home

#### Scenario: Volver a entrar no altera lo ya visto

- **WHEN** el gestor vuelve a entrar a la lista
- **THEN** puede seguir consultando sus pedidos, la fecha del primer visto no se modifica y la card no reaparece

#### Scenario: Un pedido nuevo vuelve a encender la card

- **WHEN** un pedido posterior del mismo gestor se resuelve
- **THEN** la card reaparece contando únicamente ese pedido no visto

### Requirement: La card del resultado la ve quien pide, no quien aprueba

El sistema SHALL mostrar la card del resultado a **todos los tramitadores que puedan cargar un turno con traslado y NO tengan** el permiso `autorizar_traslado_mismo_dia`. El sistema NO SHALL mostrarla al referente, al jefe de siniestros, al gerente de siniestros ni a quien tenga el permiso, porque ellos ya tienen la card de pedidos **pendientes**. La card SHALL aparecer sólo cuando hay algo que mostrar.

#### Scenario: El gestor sin permiso ve la card del resultado

- **WHEN** un tramitador que puede cargar turnos con traslado y no tiene el permiso tiene pedidos resueltos sin ver
- **THEN** ve la card del resultado en su home

#### Scenario: Quien autoriza no ve la card del resultado

- **WHEN** una persona con el permiso entra a su home
- **THEN** ve la card de pedidos **pendientes** y NO la card de resultados, y nunca las dos a la vez

### Requirement: Nomenclatura consistente entre las dos caras del circuito

El sistema SHALL usar el **mismo vocabulario** para las dos caras del circuito, distinguiéndolas por su estado, y SHALL usarlo de forma idéntica en **todos** los lugares donde aparece —cards del home y pestañas de la grilla— y en **ambos** perfiles:

- Lo que ve quien **autoriza**: «Autorización Doble Traslado Pendiente».
- Lo que ve quien **pide**: «Autorización Doble Traslado Resuelta».

#### Scenario: El mismo nombre en la card y en la pestaña

- **WHEN** una persona ve la card de su home y luego la pestaña de la grilla correspondiente
- **THEN** las dos usan exactamente el mismo texto

#### Scenario: Cada perfil ve sólo la pestaña que le corresponde

- **WHEN** se renderizan las pestañas de la grilla de turnos para un perfil cualquiera
- **THEN** se muestran únicamente las que le corresponden, **ninguna pestaña se renderiza vacía o sin texto**, y nadie ve las dos pestañas del circuito al mismo tiempo

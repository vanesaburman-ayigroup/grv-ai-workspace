## ADDED Requirements

### Requirement: La llave de visibilidad de logística es el estado de logística, no el estado del traslado

El sistema SHALL determinar si el sector logística ve un traslado por que **`id_estado_logistica_ida` no sea nulo**, y NO por el estado del traslado. El listado del sector NO filtra por estado de traslado en ningún momento, verificado sobre su stored procedure.

Esto SHALL sostenerse como **dos redes independientes**: el estado del traslado es lo que ve el gestor; el estado de logística nulo es lo que lo mantiene fuera de la grilla del sector.

#### Scenario: Un traslado con estado de logística nulo no aparece en la grilla

- **WHEN** un traslado tiene `id_estado_logistica_ida` nulo, cualquiera sea su estado de traslado
- **THEN** el sector logística no lo ve en su grilla

#### Scenario: Tocar el estado del traslado no lo hace visible

- **WHEN** alguien modifica por error el estado de un traslado que está pendiente de autorización
- **THEN** el traslado sigue invisible para logística, porque su estado de logística sigue nulo

### Requirement: Caso pendiente de autorización — logística no lo ve

Mientras el pedido está **pendiente**, el sistema SHALL crear el traslado con el estado de logística **nulo** y NO SHALL pasarlo a «Solicitado». Un traslado no está solicitado hasta que alguien lo autoriza: si bajara a logística, el sector lo vería como duplicado y lo cancelaría, que es exactamente el ruido que este circuito evita.

#### Scenario: El traslado pendiente no baja al sector

- **WHEN** se guarda un turno cuyo traslado duplicado quedó pendiente de autorización
- **THEN** el traslado se crea con estado de logística nulo y no aparece en la grilla del sector

### Requirement: Caso aprobado — baja a logística y llega marcado

Al aprobar el pedido, el sistema SHALL asignarle al traslado el estado de logística **Solicitado** —y el estado del tramo de vuelta cuando el viaje es de ida y vuelta— y SHALL encender la marca de **duplicado autorizado**. Recién entonces el traslado SHALL aparecer en la grilla del sector, y SHALL hacerlo **distinguido** con franja de color propia, ícono con tooltip y su entrada en la leyenda al pie. Sin la marca, logística vería dos traslados el mismo día y cancelaría uno, deshaciendo la autorización.

La marca SHALL aplicarse **también a los traslados de transporte público**, no sólo a los de agencia.

#### Scenario: Al aprobar, el traslado baja marcado

- **WHEN** quien autoriza aprueba el pedido
- **THEN** el traslado queda con estado de logística Solicitado y con la marca de duplicado autorizado encendida, y aparece en la grilla del sector con su franja, su ícono con tooltip y su entrada en la leyenda

#### Scenario: Un viaje de ida y vuelta recibe estado en los dos tramos

- **WHEN** el traslado aprobado corresponde a un viaje de ida y vuelta
- **THEN** ambos tramos reciben su estado de logística; en un viaje de sólo ida el tramo de vuelta queda nulo

#### Scenario: La marca alcanza al transporte público

- **WHEN** el traslado autorizado es de transporte público
- **THEN** también queda con la marca de duplicado autorizado, de modo que logística no lo cancele por duplicado

#### Scenario: La marca convive con la señal de requiere revisión

- **WHEN** una fila de la grilla es a la vez duplicado autorizado y requiere revisión
- **THEN** las dos señales se muestran juntas y distinguibles, y ninguna tapa a la otra

### Requirement: Caso rechazado — logística nunca se enteró

Al rechazar el pedido, el sistema SHALL cancelar el traslado con el **motivo de anulación 16** y el traslado NO SHALL haber tenido nunca estado de logística. La observación de la cancelación SHALL incluir el dictamen de quien rechazó.

#### Scenario: Al rechazar, el traslado se cancela sin haber pasado por el sector

- **WHEN** quien autoriza rechaza el pedido
- **THEN** el traslado queda cancelado con el motivo 16, su observación incluye el dictamen, y el sector logística nunca lo tuvo en su grilla

### Requirement: Caso anular el preexistente — logística sí participa

Es el único caso en que logística **ya tenía** el traslado en su grilla. La cancelación SHALL hacerse **con el circuito de cancelación que ya existe** —el mismo que dispara el drawer de cancelar traslado—, NO con uno nuevo, y SHALL cancelar **todos los tramos** del turno: ida, vuelta y transporte público, dentro de una única transacción. El circuito SHALL devolver el **resultado real** de la cancelación, y NO una respuesta vacía que el llamador deba interpretar como éxito.

#### Scenario: Se cancelan todos los tramos con el circuito existente

- **WHEN** el gestor elige anular el traslado preexistente
- **THEN** se cancelan sus tramos de ida, de vuelta y de transporte público mediante el circuito de cancelación ya existente, en una sola transacción

#### Scenario: El llamador recibe el resultado real

- **WHEN** la cancelación se ejecuta
- **THEN** la respuesta indica qué se canceló efectivamente y qué quedó vigente, de modo que el frontend no pueda dar por cancelado un traslado que sigue en pie

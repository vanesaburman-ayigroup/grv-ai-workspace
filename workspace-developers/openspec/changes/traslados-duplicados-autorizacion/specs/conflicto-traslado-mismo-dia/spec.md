## ADDED Requirements

### Requirement: Detección del conflicto por traslado vigente en la misma fecha

El sistema SHALL mostrar un bloque de conflicto cuando se carga un turno con traslado en una fecha en la que el paciente **ya tiene al menos un traslado vigente**. Se considera **vigente** todo traslado cuyo estado NO sea `Cancelado (4)` ni `Rechazado (5)`; el sistema NO SHALL usar ningún otro criterio de vigencia. La comparación SHALL hacerse por fecha de traslado y paciente, y NO SHALL considerar duplicado un traslado de otra región cuando el dato de región está informado en ambos.

#### Scenario: Segundo traslado en una fecha con uno vigente

- **WHEN** el gestor carga un turno con traslado en una fecha donde el paciente ya tiene un traslado en estado distinto de Cancelado y Rechazado
- **THEN** se muestra el bloque de conflicto con el traslado preexistente

#### Scenario: Un traslado cancelado no genera conflicto

- **WHEN** el único traslado del paciente en esa fecha está en estado `Cancelado (4)` o `Rechazado (5)`
- **THEN** no se muestra el bloque de conflicto y el turno se carga sin fricción

#### Scenario: Traslados de regiones distintas no son duplicado

- **WHEN** el traslado que se está cargando y el preexistente pertenecen a regiones distintas, y el dato de región está informado en ambos
- **THEN** no se consideran duplicado entre sí

#### Scenario: Varios traslados vigentes en la misma fecha

- **WHEN** el paciente tiene más de un traslado vigente en la fecha elegida
- **THEN** el bloque expone **todos** los traslados en conflicto, y la salida elegida se aplica sobre todos ellos — el sistema NO SHALL resolver sólo el primero y dejar el resto en pie

### Requirement: El conflicto se identifica por datos operativos, nunca por identificadores internos

El sistema SHALL identificar el traslado en conflicto por **número de turno, tipo de turno, hora, centro médico y agencia**, junto con su **estado operativo**: en qué estado de logística está y **si a la agencia ya se le avisó del viaje**. El sistema NO SHALL mostrar el identificador interno del **traslado** ni de la **autorización**.

El **número de turno SÍ se muestra**: no es un identificador interno sino el dato con el que el gestor, logística y el prestador nombran el turno entre ellos, y el que ya aparece en el resto de las pantallas del sistema.

#### Scenario: El bloque muestra el estado operativo, no sólo la existencia del conflicto

- **WHEN** se renderiza el bloque de conflicto
- **THEN** el gestor ve tipo de turno, hora, centro médico, agencia, estado de logística y si a la agencia ya se le informó el viaje, porque **anular un viaje ya avisado no es lo mismo que anular uno que todavía no salió**

#### Scenario: Ningún identificador interno llega a la pantalla

- **WHEN** el bloque de conflicto, la grilla de pedidos, el drawer de resolución o las cards muestran información de un traslado, turno, autorización o persona
- **THEN** cada uno se nombra por código, descripción, fecha, hora o nombre, y NO por su identificador interno — con la única excepción del **número de turno**, que es dato operativo y sí se muestra

### Requirement: Tres salidas excluyentes decididas por el backend

El sistema SHALL ofrecer al gestor **exactamente una de tres salidas excluyentes**, presentadas como una elección única —no como tres acciones sueltas— y cada una SHALL explicar qué implica **antes** de ser elegida:

1. **Anular el traslado preexistente** y quedarse con el nuevo.
2. **Guardar el turno sin traslado.**
3. **Autorizar los dos traslados** — pidiendo la autorización, o declarándola en el acto si tiene el permiso.

**Qué salidas están habilitadas lo SHALL decidir el backend**, caso por caso, según el estado operativo real del traslado preexistente. El frontend SHALL limitarse a renderizar lo que el backend habilita, de modo que un cambio de política de qué se puede anular NO requiera tocar el frontend.

#### Scenario: El backend habilita y el front sólo renderiza

- **WHEN** el frontend pide los conflictos de una fecha
- **THEN** la respuesta indica, por cada conflicto, si se puede anular, si se puede guardar sin traslado y si requiere autorización, y el frontend habilita únicamente esas salidas

#### Scenario: Un traslado ya realizado no se puede anular

- **WHEN** el traslado preexistente ya fue realizado, o tiene monto cargado, o alguno de sus tramos ya es facturable
- **THEN** la salida «anular el preexistente» NO está habilitada, y el bloque explica por qué

#### Scenario: Un viaje en curso es sólo informativo

- **WHEN** el viaje del traslado preexistente ya comenzó
- **THEN** el bloque informa la situación sin ofrecer anularlo, porque no hay traslado duplicado que evitar

#### Scenario: Elegir una salida deshabilita las otras

- **WHEN** el gestor elige una de las salidas disponibles
- **THEN** las otras dos quedan excluidas para ese conflicto

### Requirement: El resultado de la anulación se muestra antes de guardar

Cuando el gestor elige anular el traslado preexistente, el sistema SHALL mostrarle el **resultado real** de la anulación **antes** de confirmar el turno. Si el traslado quedó vigente —porque el prestador rechazó la baja o porque un tramo ya es facturable—, el sistema SHALL informarlo en el bloque y SHALL mantener **las otras salidas todavía disponibles**. El sistema NO SHALL dar por cancelado un traslado que sigue vigente.

#### Scenario: La anulación falla y el gestor lo ve

- **WHEN** la anulación del traslado preexistente no se concreta
- **THEN** el bloque informa que el traslado sigue vigente y las demás salidas siguen elegibles, sin que el gestor haya guardado nada

#### Scenario: La anulación alcanza todos los tramos del turno

- **WHEN** la anulación se concreta sobre un turno con tramo de ida, de vuelta y transporte público
- **THEN** se cancelan **todos** los tramos, mediante el circuito de cancelación que ya existe en el sistema y en una sola transacción

#### Scenario: La observación de anulación no nombra identificadores

- **WHEN** la anulación deja registrada su observación en el traslado cancelado
- **THEN** el texto nombra el turno con el que se duplicaba **por su tipo y su hora**, e incluye quién anuló y cuándo, sin ningún identificador interno

### Requirement: La tanda de rehabilitación informa en cuántas fechas hay conflicto

En la programación de una tanda de rehabilitación el sistema SHALL informar **en cuántas de las fechas** hay conflicto, y NO SHALL limitarse a indicar que alguna lo tiene.

#### Scenario: Tanda con conflicto en varias fechas

- **WHEN** se programa una tanda de rehabilitación y tres de sus fechas tienen un traslado vigente del paciente
- **THEN** el bloque informa que el conflicto ocurre en tres fechas, identificándolas por su fecha

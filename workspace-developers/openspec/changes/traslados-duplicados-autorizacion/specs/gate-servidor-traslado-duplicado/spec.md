## ADDED Requirements

### Requirement: El backend rechaza el duplicado sin motivo ni pedido

El backend SHALL rechazar el alta o la programación de un turno con **segundo traslado del mismo día** cuando no hay **ni motivo declarado ni pedido de excepción**, y SHALL responder **409 CONFLICT** con un mensaje explicativo. El gate NO SHALL depender del frontend: SHALL valer también para una llamada directa al endpoint.

#### Scenario: Alta de un duplicado sin motivo ni pedido

- **WHEN** se intenta crear un turno con traslado en una fecha donde el paciente ya tiene un traslado vigente, sin motivo declarado y sin pedido de excepción
- **THEN** el backend responde 409 CONFLICT con un mensaje que explica el conflicto, y no crea ni el turno ni el traslado

#### Scenario: El gate no se puede esquivar desde afuera del frontend

- **WHEN** la llamada llega directamente al endpoint, sin pasar por la pantalla
- **THEN** la validación se aplica igual

### Requirement: Qué acepta el gate

El backend SHALL aceptar el duplicado en tres casos, y sólo en esos tres:

1. **Motivo declarado** por quien tiene el permiso.
2. Pedido de excepción en estado **pendiente**.
3. Pedido de excepción en estado **aprobado**.

#### Scenario: Con motivo declarado no se consulta el estado de los pedidos

- **WHEN** el pedido de alta trae el motivo declarado
- **THEN** el gate lo acepta sin necesidad de consultar pedidos previos

#### Scenario: Pedido pendiente habilita el guardado

- **WHEN** el traslado tiene un pedido de excepción pendiente
- **THEN** el gate acepta el guardado, y el traslado queda sin estado de logística hasta que se resuelva

#### Scenario: Pedido aprobado habilita el guardado

- **WHEN** el traslado tiene un pedido de excepción aprobado
- **THEN** el gate acepta el guardado

#### Scenario: Sin traslado o sin fecha no hay nada que validar

- **WHEN** el turno no lleva traslado, o no tiene fecha de traslado
- **THEN** el gate no interviene

### Requirement: El gate rechaza explícitamente un pedido RECHAZADO

El backend SHALL rechazar el duplicado cuando el pedido de excepción está en estado **rechazado**. Si esto no valiera, alcanzaría con pedir la excepción y que la nieguen para cargar el traslado igual.

#### Scenario: Un pedido rechazado no habilita el traslado

- **WHEN** el traslado tiene un pedido de excepción rechazado
- **THEN** el backend responde 409 CONFLICT y no guarda el traslado

#### Scenario: Un pedido rechazado no se neutraliza con uno aprobado anterior

- **WHEN** el traslado tiene un pedido aprobado y, posteriormente, uno rechazado
- **THEN** el gate rechaza, porque el pedido que vale es el último

### Requirement: Todo endpoint que cree o programe turnos invoca la validación

**Cualquier** endpoint que cree o programe turnos SHALL invocar esta validación, con el mismo criterio con que hoy invoca la regla SE-214. Alcanza explícitamente al alta de turno, a la programación de turno, a la **edición** de turno, a la **programación en tanda de rehabilitación** y a la generación de autorización.

#### Scenario: La tanda de rehabilitación no esquiva el gate

- **WHEN** se programa en tanda una serie de turnos de rehabilitación y alguna de sus fechas tiene un traslado vigente del paciente sin motivo ni pedido
- **THEN** la validación se aplica y la operación no se completa

#### Scenario: Un conflicto en la tanda corta todas las fechas

- **WHEN** al menos una fecha de la tanda tiene conflicto no resuelto
- **THEN** se cortan **todas** las fechas de la tanda: ninguna se programa, para que la tanda no quede parcialmente cargada

#### Scenario: La edición de un turno también valida

- **WHEN** se edita un turno de modo que su traslado pase a caer en una fecha con un traslado vigente del paciente
- **THEN** la validación se aplica igual que en el alta

### Requirement: Los duplicados dentro de la misma operación también se detectan

El sistema SHALL detectar el conflicto también entre los traslados que se están creando **en la misma operación**, y NO SHALL limitarse a comparar contra los traslados ya persistidos.

#### Scenario: Dos fechas iguales dentro de una misma tanda

- **WHEN** una tanda incluye dos turnos con traslado para el mismo paciente en la misma fecha, sin que existiera ninguno previo
- **THEN** el conflicto se detecta entre ellos y la operación no se completa sin resolución

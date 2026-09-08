## ADDED Requirements

### Requirement: Valor de venta por prestación y zona

El sistema SHALL permitir registrar un **valor de venta** asociado a una prestación y a una **zona** (Buenos Aires/Santa Fe/Entre Ríos/Córdoba, Cuyo, Patagonia y centros propios), independiente del prestador. Este valor SHALL mantenerse **separado del costo** por convenio, que permanece de solo lectura.

El valor de venta **NO varía por cliente**: las dimensiones son **prestación × zona × vigencia**. Decisión de negocio confirmada (30/07/2026).

#### Scenario: Alta de un valor de venta

- **WHEN** un usuario del perfil comercial carga el valor de venta de una prestación para una zona, con fecha de vigencia
- **THEN** el sistema lo persiste como valor activo junto con la fecha y el usuario responsable de la carga

#### Scenario: El costo de convenio no se altera

- **WHEN** se carga o modifica un valor de venta
- **THEN** el sistema no modifica las tablas de convenios ni los montos pactados por prestador

#### Scenario: Prestación con valores distintos por zona

- **WHEN** una misma prestación tiene valor de venta cargado para dos zonas diferentes
- **THEN** el sistema conserva ambos valores y resuelve el aplicable según la zona del prestador que realizó la prestación

### Requirement: Vigencia y versionado del valor de venta

El valor de venta SHALL versionarse por copia (copy-on-write): al registrar un nuevo importe para una prestación y zona ya vigentes, el sistema SHALL cerrar la vigencia del valor anterior y crear una versión nueva, conservando el histórico consultable. La resolución del valor aplicable SHALL hacerse por **fecha de la prestación**.

#### Scenario: Actualización de precio por incremento

- **WHEN** el área comercial carga un incremento para una prestación y zona que ya tenían valor vigente
- **THEN** el sistema cierra la vigencia del valor anterior, lo conserva como histórico y activa la versión nueva desde su fecha de vigencia

#### Scenario: Valorización de una prestación pasada

- **WHEN** se valoriza una prestación cuya fecha de realización es anterior al último incremento
- **THEN** el sistema aplica el valor que estaba vigente a la fecha de la prestación, no el valor actual

#### Scenario: Consulta del histórico de precios

- **WHEN** un usuario del perfil comercial consulta el historial de una prestación y zona
- **THEN** el sistema devuelve las versiones anteriores con sus rangos de vigencia

#### Scenario: Carga de un valor con vigencia futura

- **WHEN** se carga un valor de venta con fecha de vigencia posterior a la fecha actual
- **THEN** el sistema lo registra como versión futura y no lo aplica hasta que su vigencia comience

### Requirement: Actualización masiva por porcentaje

El sistema SHALL permitir aplicar un **aumento por porcentaje sobre un conjunto de prestaciones** en una sola operación, además de la carga individual. Los incrementos llegan cada tres o cuatro meses desde comercial, y cargarlos de a uno es la tarea que hoy consume el tiempo.

La actualización masiva SHALL respetar el versionado: genera una versión nueva por cada valor afectado, con la vigencia indicada, conservando el histórico. El sistema MUST mostrar una **previsualización** de cuántos valores se van a afectar y con qué importes resultantes **antes** de confirmar.

#### Scenario: Aumento del 12% sobre una zona

- **WHEN** un usuario del perfil comercial aplica un aumento del 12% a las prestaciones de una zona con vigencia desde una fecha
- **THEN** el sistema previsualiza los valores afectados con su importe resultante y, al confirmar, cierra la vigencia de los valores anteriores y crea las versiones nuevas

#### Scenario: Previsualización sin confirmar

- **WHEN** el usuario solicita la previsualización de un aumento masivo y no la confirma
- **THEN** el sistema no modifica ningún valor

#### Scenario: Carga individual conserva su lugar

- **WHEN** el usuario necesita ajustar el valor de una única prestación
- **THEN** el sistema permite la carga individual sin obligar a pasar por la operación masiva

#### Scenario: Redondeo del importe resultante

- **WHEN** el aumento porcentual produce un importe con más de dos decimales
- **THEN** el sistema lo redondea a dos decimales de forma consistente y muestra el importe final en la previsualización

### Requirement: Base de cálculo del margen

El sistema SHALL permitir contrastar el **valor de venta** de una prestación contra el **costo** pactado con el prestador que la realizó, para obtener el margen por prestación. El margen SHALL calcularse sobre información existente, sin duplicar el modelo de costo.

#### Scenario: Margen de una prestación ejecutada

- **WHEN** se consulta el margen de una prestación que tiene valor de venta vigente y costo de convenio del prestador que la realizó
- **THEN** el sistema informa el costo, la venta y la diferencia entre ambos

#### Scenario: Prestación sin valor de venta cargado

- **WHEN** se consulta el margen de una prestación que no tiene valor de venta cargado para su zona
- **THEN** el sistema informa que no hay venta definida en lugar de asumir un valor o devolver cero

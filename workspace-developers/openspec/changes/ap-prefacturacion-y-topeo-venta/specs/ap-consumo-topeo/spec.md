## ADDED Requirements

### Requirement: Base de valorización — valor de venta del contrato del cliente más IVA

El sistema SHALL valorizar las tres instancias del consumo de un siniestro AP con el **valor de venta vigente del contrato del cliente a la fecha de realización** de la prestación, más la alícuota general de IVA. El sistema MUST NOT usar el costo (precio de convenio con el prestador, cotización de materiales, importe de la factura del prestador) como base del consumo que topea.

El tope está expresado **con IVA**; los valores del contrato se cargan **sin IVA**. La comparación numerador/denominador SHALL hacerse con las dos puntas con IVA, y el sistema SHALL declarar explícitamente que los importes que expone ya lo incluyen, para que ningún consumidor lo sume de nuevo. NO SHALL haber prestaciones exentas: la alícuota es una sola.

El **costo** SHALL conservarse por prestación, con su propia semántica y sin IVA, para poder medir margen.

#### Scenario: Prestación valorizada por contrato

- **WHEN** se calcula el consumo de una prestación de un siniestro AP y existe valor de venta vigente para ese cliente, esa prestación y esa fecha de realización
- **THEN** el sistema la valoriza con ese valor de venta más IVA, y no con el precio de convenio del prestador

#### Scenario: Aumento de grilla posterior a la prestación

- **WHEN** el contrato del cliente se actualiza con un valor nuevo después de la fecha de realización de una prestación ya facturada
- **THEN** esa prestación conserva el valor con el que se facturó, y el valor nuevo aplica a las prestaciones que resuelven contra la vigencia nueva

#### Scenario: Prestación sin valor de venta cargado

- **WHEN** no hay valor de venta para el cliente, la prestación y la fecha
- **THEN** el sistema informa la prestación como pendiente de valorizar, la cuenta en el indicador de consumo incompleto, y MUST NOT sustituirla por el costo ni por cero

#### Scenario: Declaración de IVA en la respuesta

- **WHEN** el sistema expone los importes de consumo de un siniestro
- **THEN** declara que los montos incluyen IVA y que el tope también, de modo que el consumidor no vuelva a aplicar la alícuota

#### Scenario: Costo conservado para el margen

- **WHEN** una prestación tiene tanto valor de venta como costo del prestador conocidos
- **THEN** el sistema expone los dos importes por separado y el consumo topea únicamente sobre el valor de venta

### Requirement: La cancelación de una autorización sale del cómputo

El sistema SHALL quitar del consumo el monto de una autorización **cancelada**. Un presupuesto aprobado suma al consumo del paciente desde su aprobación; si la autorización se cancela —típicamente porque el cliente no la aprobó al ver el consumo acumulado— ese monto SHALL dejar de computar.

Si la prestación cancelada estaba dentro de un lote de prefacturado, el sistema SHALL avisar a prefacturación en lugar de bloquear la cancelación.

#### Scenario: Presupuesto aprobado que suma

- **WHEN** una autorización de cirugía pasa a aprobada con su monto de presupuesto
- **THEN** el sistema lo incorpora al estimado del siniestro y el semáforo lo refleja

#### Scenario: Autorización cancelada

- **WHEN** una autorización que ya sumaba al estimado se cancela
- **THEN** el sistema quita su monto del cómputo y el porcentaje del semáforo baja en la consulta siguiente

#### Scenario: Cancelación de algo ya prefacturado

- **WHEN** se cancela una prestación que estaba dentro de un lote de prefacturado sin facturar
- **THEN** la cancelación se aplica, el monto sale del cómputo, y prefacturación recibe el aviso del movimiento sobre ese lote

### Requirement: Origen de la suma asegurada

La suma asegurada de cada póliza SHALL leerse de `cs.polizas_ap`, donde el área de negocio comenzó a cargarla. Deja de ser un dato inexistente que había que definir dónde vivía.

Mientras una póliza no tenga suma asegurada cargada, el semáforo de sus siniestros SHALL informar **SIN_TOPE** y su porcentaje SHALL ser nulo — nunca cero, porque un cero se lee como semáforo en verde y es peor que no tener el dato.

#### Scenario: Póliza sin suma asegurada

- **WHEN** un siniestro pertenece a una póliza sin suma asegurada cargada
- **THEN** el sistema muestra SIN_TOPE, no calcula porcentaje, y no lo cuenta en las bandas del semáforo

## MODIFIED Requirements

### Requirement: Clasificación del consumo en tres estados de confianza

El sistema SHALL clasificar cada ítem de consumo de un siniestro AP en exactamente uno de tres **estados de confianza**, todos ellos medidos en **valor de venta del contrato del cliente más IVA**:

- **Estimado**: autorización aprobada, todavía no realizada (turno futuro, cirugía en armado). Es previsión y puede cancelarse.
- **Devengado y prefacturado**: la prestación **ya se realizó**, esté o no dentro de un lote de prefacturado. **Las dos cosas son la misma categoría**, no dos.
- **Facturado al cliente**: ya se le facturó a quien nos paga, después de la prefacturación.

**Estar en un lote de prefacturado es un atributo del ítem, no un estado de confianza.** El estado de confianza responde "¿cuán seguro es que esta plata se gastó?"; el lote responde "¿ya lo presentamos al cliente?". El sistema MUST NOT introducir una cuarta capa por el hecho de que un ítem haya entrado a un lote.

**La factura del prestador NO es un estado de confianza.** Es el **costo** (sin IVA) y cumple otras dos funciones: medir margen y descubrir erogaciones tardías. Cuando aporta una prestación al siniestro, su importe SHALL convertirse al valor de venta del contrato del cliente más IVA y entrar por la instancia que corresponda, casi siempre devengado.

#### Scenario: Autorización aprobada sin realizar

- **WHEN** existe una autorización aprobada de un siniestro AP cuya prestación todavía no se realizó
- **THEN** el sistema la clasifica como estimado, valorizada con el valor de venta del contrato del cliente más IVA

#### Scenario: Prestación realizada, todavía suelta

- **WHEN** una prestación de un siniestro AP ya se realizó y no entró a ningún lote de prefacturado
- **THEN** el sistema la clasifica como devengado

#### Scenario: Prestación realizada y ya prefacturada

- **WHEN** una prestación ya realizada entra a un lote de prefacturado
- **THEN** el sistema la sigue clasificando como devengado y registra el lote como atributo, sin moverla de capa

#### Scenario: Prestación facturada al cliente

- **WHEN** se registra la factura emitida al cliente de un lote
- **THEN** las prestaciones de ese lote pasan a facturado al cliente

#### Scenario: La factura del prestador no crea una capa

- **WHEN** llega la factura de un prestador por una prestación ya realizada
- **THEN** el sistema registra su importe como costo y la prestación sigue clasificada por su propio estado de confianza, sin generar una cuarta capa

### Requirement: Doble vía de topeo — facturado y proyección

El sistema SHALL exponer, por cada siniestro AP, **dos cifras de consumo con propósitos distintos**, ambas en valor de venta más IVA:

- **Consumo facturado al cliente** = lo efectivamente facturado a quien nos paga. Es el **tope oficial**: la cifra contra la que se decide cerrar el siniestro y debitar.
- **Proyección** = Estimado + Devengado y prefacturado + Facturado al cliente. Es la cifra de **vigilancia**, contra la que corre el semáforo y se disparan las alertas.

La suma de estimado más devengado constituye el **pendiente de facturar** de la póliza y MUST poder consultarse por separado.

Los dos porcentajes MUST viajar por separado y MUST NOT ser intercambiables: con el facturado el aviso llega cuando ya no se puede hacer nada, y con la proyección se cerraría un siniestro por plata que todavía no se gastó.

#### Scenario: Siniestro con gasto en vuelo

- **WHEN** un siniestro AP tiene el facturado por debajo del tope pero su proyección lo supera
- **THEN** el sistema muestra las dos cifras y señala la alerta de vigilancia, sin habilitar el cierre

#### Scenario: Decisión de cierre y débito

- **WHEN** el consumo **facturado al cliente** de un siniestro AP alcanza o supera la suma asegurada
- **THEN** el sistema habilita la acción de cierre del siniestro, indicando que el tope oficial fue alcanzado

#### Scenario: Consulta del pendiente

- **WHEN** se consulta el detalle económico de un siniestro AP
- **THEN** el sistema informa por separado el facturado al cliente, el devengado y prefacturado, el estimado, el pendiente de facturar y el saldo disponible respecto del tope

### Requirement: Prevención del doble conteo

El sistema MUST NOT contar dos veces un mismo gasto. Con el numerador expresado en valor de venta, las reglas son:

- **Una prestación aporta una sola vez**, por su estado de confianza más avanzado. Que exista además la factura del prestador de esa prestación NO SHALL generar un aporte adicional: esa factura es costo.
- Cuando una **erogación** trae una prestación que **ya está cargada** en el siniestro (por número de autorización, o por coincidencia inequívoca de prestación, fecha y paciente), el sistema SHALL reconocerla como la factura de esa prestación y MUST NOT crear una prestación nueva.
- Cuando una **erogación libre** no se puede matchear, el ítem incorporado SHALL quedar marcado como no matcheado para revisión explícita, en lugar de integrarse en silencio.
- El costo de **materiales quirúrgicos** SHALL sumar la cotización ganadora **una sola vez por grupo real**; cuando el grupo es el valor centinela (0 o nulo), el monto SHALL contarse por línea de detalle.
- La unidad de agregación SHALL ser el **siniestro** (la denuncia).

#### Scenario: Prestación realizada cuya factura del prestador llega después

- **WHEN** una prestación clasificada como devengado recibe la factura de su prestador
- **THEN** el sistema registra el costo y la prestación sigue aportando una sola vez, por su estado de confianza

#### Scenario: Erogación matcheable con una prestación existente

- **WHEN** una línea de erogación trae el número de autorización de una prestación ya cargada
- **THEN** el sistema la vincula a esa prestación y no genera un aporte nuevo al consumo

#### Scenario: Erogación libre no matcheable

- **WHEN** una línea de erogación llega solo con el documento del paciente y no se puede vincular a ninguna prestación cargada
- **THEN** el sistema la incorpora como prestación nueva, valorizada por contrato, y la marca como no matcheada para revisión

#### Scenario: Materiales con cotización repetida por grupo

- **WHEN** un pedido de materiales tiene varias líneas de detalle del mismo grupo con el monto de la cotización ganadora repetido
- **THEN** el sistema suma ese monto una sola vez para el grupo

#### Scenario: Materiales con grupo centinela

- **WHEN** un pedido de materiales tiene varias líneas usadas cuyo grupo es 0 o nulo, con montos distintos
- **THEN** el sistema suma cada línea por separado y no colapsa los montos en uno solo

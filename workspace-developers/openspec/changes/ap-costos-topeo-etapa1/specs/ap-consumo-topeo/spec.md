## ADDED Requirements

### Requirement: Clasificación del consumo en tres estados de confianza

El sistema SHALL clasificar cada ítem de consumo de un siniestro AP en exactamente uno de tres **estados de confianza**:

- **Facturado**: ya impactó en factura auditada (monto real).
- **Devengado**: la prestación ya se realizó pero la factura aún no llegó (gasto incurrido pendiente de facturación/liquidación), valuado por convenio.
- **Estimado**: autorizado pero aún no realizado (previsión, puede cancelarse), valuado por convenio.

El monto de cada ítem MUST resolverse tomando siempre el dato más confiable disponible (auditado/debitado, luego facturado, luego estimado por convenio).

#### Scenario: Turno autorizado sin realizar

- **WHEN** existe un turno de un siniestro AP con valor de convenio cargado y su estado no es realizado
- **THEN** el sistema lo clasifica como `ESTIMADO`

#### Scenario: Turno realizado sin factura

- **WHEN** un turno de un siniestro AP tiene estado realizado (19 o 23) y todavía no tiene valor de facturación
- **THEN** el sistema lo clasifica como `DEVENGADO` con el monto del convenio

#### Scenario: Erogación auditada

- **WHEN** existe una erogación asociada a la denuncia AP con monto facturado
- **THEN** el sistema la clasifica como `FACTURADO` por el monto facturado neto del monto debitado

### Requirement: Doble vía de topeo — facturado y proyección

El sistema SHALL exponer, por cada siniestro AP, **dos cifras de consumo con propósitos distintos**:

- **Consumo facturado** = Facturado. Es el **tope oficial**: la cifra contra la que se decide cerrar el siniestro y debitar.
- **Proyección** = Facturado + Devengado + Estimado. Es la cifra de **vigilancia** del mes en curso, contra la que se dispara la alerta de no autorizar más prestaciones.

La suma de Devengado + Estimado constituye el **pasivo por siniestros pendientes** de la póliza y MUST poder consultarse por separado.

#### Scenario: Siniestro con gasto en vuelo

- **WHEN** un siniestro AP tiene facturado por debajo del tope pero su proyección lo supera
- **THEN** el sistema muestra ambas cifras y señala la alerta de vigilancia, sin marcar el siniestro como excedido a efectos de cierre

#### Scenario: Decisión de cierre y débito

- **WHEN** el consumo **facturado** de un siniestro AP alcanza o supera la suma asegurada
- **THEN** el sistema habilita la acción de cierre del siniestro con débito, indicando que el tope oficial fue alcanzado

#### Scenario: Consulta del pasivo pendiente

- **WHEN** se consulta el detalle económico de un siniestro AP
- **THEN** el sistema informa por separado el facturado, el devengado, el estimado y el saldo disponible respecto del tope

### Requirement: Vías de valorización de la etapa 1

El sistema SHALL agregar al consumo de cada siniestro AP las **cinco vías**: **prácticas/turnos**, **traslados**, **cirugía**, **medicación** (por carga manual del valor) y **laboratorio** (por multiplicador con precio cargado). Cada vía MUST aportar su monto en el mejor estado de confianza disponible, y el sistema SHALL indicar qué vías tienen ítems pendientes de valorizar, para que el total no se lea como completo cuando no lo está.

#### Scenario: Valorización de traslados

- **WHEN** un traslado de un siniestro AP tiene estado logístico Realizado (4) o Negativo autorizado (8) en el tramo correspondiente
- **THEN** el sistema lo incorpora al consumo, tomando el monto firme cuando existe y recalculando el estimado por convenio cuando todavía no hay monto

#### Scenario: Valorización de una cirugía

- **WHEN** se calcula el costo estimado de una cirugía de un siniestro AP
- **THEN** el sistema suma honorarios (presupuestos en estado Valorizado), materiales (cotización ganadora) y prótesis/ortopedia, y expone el consolidado

> **Corrección del 20/08/2026: la internación NO es un componente de la cirugía.** El texto anterior la incluía en este consolidado. Verificado contra la base: la internación es una **vía propia y más grande que la cirugía** — 31.726 autorizaciones en 14.155 denuncias contra 30.545 en 13.985 de cirugía, y **2.383 denuncias tienen internación sin ninguna cirugía**. Las cuatro columnas de `prestaciones` que existirían para el componente (`pq_gasto_internacion` y las de su familia) valen **cero en todas las filas** — no están nulas, están en cero, así que preguntar "¿tiene datos?" devuelve un sí engañoso. La internación entra al consumo por la vía de turnos, que no filtra por tipo, así que no se pierde ni se cuenta dos veces. Lo que no se puede hacer es anticiparla: el 80% de su importe entra como texto libre sin código de nomenclador, y sin código no hay precio de convenio con el que valorizarla antes de que llegue la factura.

#### Scenario: Consolidado de cirugía visible para AP

- **WHEN** un usuario de AP con permiso consulta el detalle de una cirugía
- **THEN** el sistema le muestra el consolidado de costo por componentes, reutilizando la información de Contrataciones sin duplicar su circuito

#### Scenario: Ítems pendientes de valorizar en alguna vía

- **WHEN** un siniestro tiene ítems de medicación o laboratorio sin valor cargado
- **THEN** el sistema informa el consumo con una marca de "incompleto" e indica cuántos ítems están pendientes de valorizar y en qué vía

### Requirement: Consulta de impacto de una prestación sobre el saldo

El sistema SHALL permitir consultar, para un siniestro AP, **cuánto saldo queda** y **si un monto adicional entra dentro de la suma asegurada**. Es el pedido recurrente del cliente antes de aprobar una cirugía: saber el consumo acumulado y si la cirugía presupuestada cabe en el tope.

#### Scenario: Cirugía que entra en el saldo

- **WHEN** se consulta el impacto de una cirugía presupuestada sobre un siniestro cuyo saldo disponible supera el monto del presupuesto
- **THEN** el sistema informa que el monto entra, y muestra el consumo resultante y el saldo que quedaría

#### Scenario: Cirugía que excede el saldo

- **WHEN** el monto presupuestado supera el saldo disponible del siniestro
- **THEN** el sistema informa que excede el tope, indicando por cuánto, para poder avisar al cliente antes de autorizar

### Requirement: Prevención del doble conteo

El sistema MUST NOT contar dos veces un mismo gasto. En particular:

- El **facturado** SHALL tomarse únicamente de las erogaciones; los turnos aportan solo mientras no estén facturados.
- El costo de **materiales quirúrgicos** SHALL sumar la cotización ganadora **una sola vez por grupo real**; cuando el grupo es el valor centinela (0 o nulo), el monto SHALL contarse por línea de detalle.
- La unidad de agregación SHALL ser el **siniestro** (la denuncia).

#### Scenario: Turno facturado que también tiene erogación

- **WHEN** un turno ya fue auditado y existe la erogación correspondiente
- **THEN** el sistema cuenta el gasto una sola vez, tomándolo de la erogación y excluyendo el aporte del turno

#### Scenario: Materiales con cotización repetida por grupo

- **WHEN** un pedido de materiales tiene varias líneas de detalle del mismo grupo con el monto de la cotización ganadora repetido
- **THEN** el sistema suma ese monto una sola vez para el grupo

#### Scenario: Materiales con grupo centinela

- **WHEN** un pedido de materiales tiene varias líneas usadas cuyo grupo es 0 o nulo, con montos distintos
- **THEN** el sistema suma cada línea por separado y no colapsa los montos en uno solo

### Requirement: Disponibilidad del valor estimado al autorizar

El sistema SHALL registrar el **valor estimado por convenio** en el momento de autorizar o dar de alta el turno, dejando constancia de que el origen del valor es el convenio. Adicionalmente SHALL proveer un proceso de **backfill idempotente** que complete el estimado del histórico, tomando el convenio vigente a la fecha del turno.

#### Scenario: Alta de turno con convenio vigente

- **WHEN** se autoriza o se da de alta un turno de un siniestro AP y existe convenio vigente para esa prestación
- **THEN** el sistema persiste el valor estimado del turno junto con el origen de valor "convenio"

#### Scenario: Backfill del histórico

- **WHEN** se ejecuta el proceso de backfill sobre turnos ya realizados sin valor estimado
- **THEN** el sistema completa el estimado con el convenio vigente a la fecha del turno, y una segunda ejecución no altera los valores ya completados

### Requirement: Carga manual de valores de medicación

El sistema SHALL permitir **cargar manualmente** el valor de la medicación de un siniestro AP e incorporarlo al consumo, dejando registrado **qué precio se usó, de qué fuente y en qué fecha**. Hoy el valor se consulta a mano en un portal externo que no conserva historial: registrar el precio utilizado MUST ser parte de la carga, para construir el historial que hoy no existe.

Cada ítem de medicación SHALL admitir una **descripción del medicamento entregado**. El sistema MUST NOT conformarse con la leyenda genérica "medicación", porque el cliente pide el detalle de lo entregado y hoy hay que buscarlo en las facturas del portal.

#### Scenario: Carga del valor de un medicamento

- **WHEN** un usuario de gestión carga el valor de un medicamento de un siniestro AP, con su descripción y el precio consultado
- **THEN** el sistema incorpora el monto al consumo del siniestro y registra el precio, la fuente, la fecha de consulta y el usuario responsable

#### Scenario: Reutilización del último precio cargado

- **WHEN** se carga un medicamento que ya tiene precio registrado en una carga anterior
- **THEN** el sistema ofrece el último precio conocido con su fecha, para que el usuario lo confirme o lo actualice

#### Scenario: Consulta del detalle entregado al cliente

- **WHEN** el cliente solicita el detalle de la medicación entregada de un siniestro
- **THEN** el sistema lista los medicamentos con su descripción, cantidad y valor, sin necesidad de recurrir a las facturas del portal

#### Scenario: Medicación sin valor cargado

- **WHEN** un siniestro AP tiene medicación registrada sin valor cargado
- **THEN** el sistema la muestra como pendiente de valorizar y la excluye del monto, señalando que el consumo está incompleto hasta que se cargue

### Requirement: Valorización de laboratorio por multiplicador

El sistema SHALL valorizar las determinaciones de laboratorio (y las radiografías que correspondan) mediante el esquema de **multiplicador por determinación × precio de la unidad**, que es el mecanismo que el negocio ya usa. El **precio de la unidad** SHALL poder cargarse y actualizarse manualmente, y el multiplicador por determinación SHALL tomarse del catálogo existente.

#### Scenario: Valorización automática de una determinación

- **WHEN** se valoriza una determinación de laboratorio que tiene multiplicador definido y hay precio de unidad cargado
- **THEN** el sistema calcula el valor como multiplicador por precio de unidad, sin pedir el monto al usuario

#### Scenario: Actualización del precio de la unidad

- **WHEN** un usuario habilitado actualiza el precio de la unidad
- **THEN** las determinaciones se valorizan con el precio nuevo desde su vigencia, y las prestaciones ya valorizadas conservan el precio que se les aplicó

#### Scenario: Determinación sin multiplicador

- **WHEN** se valoriza una determinación que no tiene multiplicador definido (por ejemplo una radiografía de monto plano)
- **THEN** el sistema permite cargar el valor manualmente en lugar de calcularlo

### Requirement: Carga manual de prestaciones no convenidas

El sistema SHALL permitir **cargar manualmente el valor** de una prestación que no está en la grilla de precios, como las cirugías que se acuerdan **por presupuesto** con el cliente. La carga MUST registrar el usuario, la fecha y una referencia o comentario que justifique el valor.

#### Scenario: Cirugía acordada por presupuesto

- **WHEN** se valoriza una cirugía cuya autorización no tiene precio en la grilla porque se acordó por presupuesto
- **THEN** el sistema permite cargar el valor acordado a mano, lo incorpora al consumo y lo distingue de los valores tomados de la grilla

#### Scenario: Trazabilidad de un valor cargado a mano

- **WHEN** se consulta una prestación cuyo valor fue cargado manualmente
- **THEN** el sistema informa que el valor es de carga manual, con el usuario, la fecha y la referencia del acuerdo

## ADDED Requirements

### Requirement: Home del perfil de prefacturación con métricas accionables

El sistema SHALL presentar al perfil de prefacturación una pantalla de inicio con métricas que digan **qué hay para hacer hoy**, cada una navegable al listado o a la pantalla que resuelve el caso. Las métricas SHALL ser:

- **Pendiente de facturar** — cantidad de prestaciones pendientes y su monto sin IVA del período en curso.
- **Movimientos sobre prefacturadas** — cantidad de prestaciones ya prefacturadas que un gestor canceló o cuyo valor cambió, sin revisar.
- **Erogaciones tardías sin facturar** — cantidad y monto sin IVA, con la aclaración de que se facturan aparte.
- **Margen de lo facturado** — porcentaje de margen de lo facturado, con la venta y el costo que lo componen.
- **Medicamentos sin revisar** — cantidad de medicamentos cuyo precio de referencia lleva más de 30 días sin actualizarse.

Cada métrica SHALL indicar con un semáforo si requiere acción o no. Una métrica en cero MUST decirlo explícitamente ("nada sin revisar") en lugar de mostrar solo el cero.

#### Scenario: Entrada a la pantalla de inicio

- **WHEN** el usuario de prefacturación entra al sistema
- **THEN** el sistema muestra las cinco métricas con su cantidad, su detalle y su estado de atención

#### Scenario: Navegación desde una métrica

- **WHEN** el usuario abre la métrica de pendiente de facturar
- **THEN** el sistema lo lleva al listado filtrado por prestaciones pendientes del período en curso

#### Scenario: Navegación a las tardías

- **WHEN** el usuario abre la métrica de erogaciones tardías sin facturar
- **THEN** el sistema lo lleva al listado con el filtro de solo tardías aplicado

#### Scenario: Métrica sin nada pendiente

- **WHEN** no hay movimientos sobre prestaciones prefacturadas sin revisar
- **THEN** la métrica lo informa como "nada sin revisar" y no queda marcada como requiriendo atención

### Requirement: Panel de pacientes a vigilar

El sistema SHALL presentar en la pantalla de inicio un panel de **pacientes a vigilar**, ordenado por porcentaje de consumo de la proyección de mayor a menor, con: denuncia (navegable al detalle), paciente, documento, cliente, **suma asegurada** (con IVA), **facturado**, **proyección con su porcentaje** y el **nivel del semáforo** escrito.

El panel SHALL declarar que el tope se mide **con IVA**, que los valores del contrato se cargan sin IVA y que el 21% se suma al consumo. SHALL declarar también que el semáforo corre sobre la **proyección** (para avisar antes) y que el **cierre y el débito** se deciden sobre el **facturado**.

El nivel SHALL escribirse siempre como texto, no solo comunicarse por color.

#### Scenario: Pacientes ordenados por riesgo

- **WHEN** el usuario abre el panel de pacientes a vigilar
- **THEN** el sistema lista los siniestros ordenados por porcentaje de proyección de mayor a menor, con el nivel del semáforo escrito en cada fila

#### Scenario: Siniestro con proyección alta y facturado bajo

- **WHEN** un siniestro tiene la proyección por encima del tope y el facturado por debajo
- **THEN** la fila muestra los dos porcentajes por separado, para que no se lea el nivel del semáforo como una habilitación de cierre

#### Scenario: Siniestro sin tope cargado

- **WHEN** un siniestro del panel no tiene suma asegurada resuelta
- **THEN** el sistema lo informa como sin tope y no muestra porcentaje ni semáforo, en lugar de mostrar cero

#### Scenario: Navegación al detalle del siniestro

- **WHEN** el usuario abre la denuncia desde el panel
- **THEN** el sistema lo lleva al detalle del siniestro, a la sección de costos y topeo

### Requirement: Aviso de contratos por vencer

El sistema SHALL avisar en la pantalla de inicio los **contratos de valor de venta por vencer**, con **un mes de anticipación** respecto de su fecha de fin de vigencia, indicando el cliente y la fecha, porque ese mes es el tiempo que lleva llegar a un acuerdo nuevo.

El aviso SHALL estar disponible en la pantalla de inicio. El envío por mail NO SHALL ser requisito de esta entrega.

#### Scenario: Contrato que vence el mes próximo

- **WHEN** un contrato de valor de venta vence dentro de los próximos treinta días
- **THEN** el sistema lo informa en la pantalla de inicio con su cliente y su fecha de vencimiento

#### Scenario: Contrato con vigencia lejana

- **WHEN** todos los contratos vencen más allá de los próximos treinta días
- **THEN** el sistema no genera aviso de vencimiento

### Requirement: El margen se mide contra el costo del prestador

El sistema SHALL calcular el margen de lo facturado como la diferencia entre el **valor de venta facturado** y el **costo que el prestador factura**, ambos sin IVA, e informar el porcentaje sobre la venta.

El sistema MUST declarar que el costo es lo que el prestador le factura a la compañía, que no topea y que no se le factura al cliente: sirve para el margen. Cuando falta el costo o falta la venta de una prestación, el margen de esa prestación MUST informarse como no calculable, y no como cero.

#### Scenario: Margen del período

- **WHEN** el usuario consulta el margen de lo facturado
- **THEN** el sistema informa el porcentaje, la venta facturada y el costo, aclarando que el costo es lo que el prestador factura

#### Scenario: Prestación sin costo conocido

- **WHEN** una prestación facturada todavía no tiene factura del prestador
- **THEN** el sistema no computa margen para esa prestación e informa que no es calculable, en lugar de asumir costo cero

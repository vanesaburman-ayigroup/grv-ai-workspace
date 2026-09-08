## ADDED Requirements

### Requirement: Valor de venta de un medicamento a partir del precio de referencia con descuento

El sistema SHALL construir el **valor de venta sin IVA** de un medicamento a partir de su **precio de referencia de Kairos** menos el **descuento con el que se trabaja**, que habitualmente es 15% o 20% y SHALL ser cargable por medicamento.

El valor resultante SHALL quedar registrado como valor de venta sin IVA, igual que el resto de los contratos, y el sistema SHALL mostrar además el importe que resulta al cliente con IVA. El sistema SHALL registrar el **precio de referencia usado**, el **descuento aplicado** y la **fecha** de la carga, porque el portal externo donde hoy se consulta no conserva historial.

Cada medicamento SHALL identificarse con su nombre, su presentación y su troquel.

#### Scenario: Carga del valor de un medicamento

- **WHEN** el usuario carga el precio de referencia de un medicamento y elige el descuento
- **THEN** el sistema calcula el valor de venta sin IVA, muestra el importe con IVA que resultaría al cliente, y registra el precio de referencia, el descuento y la fecha

#### Scenario: Actualización del precio de referencia

- **WHEN** el usuario actualiza el precio de referencia de un medicamento que ya tenía valor cargado
- **THEN** el sistema recalcula el valor de venta con el descuento vigente y conserva el registro del precio anterior con su fecha

#### Scenario: Consulta del valor vigente

- **WHEN** se consulta el listado de medicamentos
- **THEN** el sistema muestra por cada uno el precio de referencia, el descuento, el valor de venta sin IVA y la fecha de la última actualización

### Requirement: Antigüedad del precio como dato visible, con avisos a 30 y 90 días

El sistema SHALL informar, por cada medicamento, **cuánto tiempo pasó** desde la última actualización de su precio de referencia, y SHALL marcarlo cuando ese tiempo supera los **30 días** y con mayor severidad cuando supera los **90 días**.

La cantidad de medicamentos con más de 30 días sin revisar SHALL exponerse como indicador en la pantalla de inicio del perfil. Es el sustituto explícito de la actualización automática mientras esta no exista, y MUST seguir funcionando aunque la integración nunca se implemente.

#### Scenario: Precio con más de 30 días

- **WHEN** el precio de referencia de un medicamento lleva más de 30 días sin actualizarse
- **THEN** el sistema lo marca como pendiente de revisar y lo cuenta en el indicador de la pantalla de inicio

#### Scenario: Precio con más de 90 días

- **WHEN** el precio de referencia lleva más de 90 días sin actualizarse
- **THEN** el sistema lo marca con severidad mayor que el caso de 30 días

#### Scenario: Precio recién actualizado

- **WHEN** el precio se actualizó dentro de los últimos 30 días
- **THEN** el sistema no lo marca como pendiente de revisar

### Requirement: Integración con la API de Kairos, sujeta a viabilidad

El sistema SHALL soportar la actualización **manual** del precio de referencia como camino completo y suficiente. La **integración con la API de Kairos** SHALL tratarse como una opción a evaluar: si resulta viable, SHALL reemplazar la carga manual actualizando los precios de forma periódica **sin cambiar el modelo de datos ni el cálculo del valor de venta**.

Mientras la integración no exista, el sistema MUST declararlo cuando el usuario intente sincronizar, en lugar de fallar en silencio o de sugerir que los precios se actualizan solos.

#### Scenario: Intento de sincronizar sin integración disponible

- **WHEN** el usuario pide sincronizar los precios con Kairos y la integración no está disponible
- **THEN** el sistema informa que la integración está pendiente y que hasta entonces el valor se carga a mano con aviso por antigüedad

#### Scenario: Integración disponible

- **WHEN** la integración está disponible y se ejecuta la actualización periódica
- **THEN** los precios de referencia quedan actualizados con su fecha, el valor de venta se recalcula con el descuento vigente de cada medicamento, y los avisos por antigüedad se resetean

### Requirement: Exportación del listado de medicamentos

El sistema SHALL permitir exportar el listado de medicamentos con su precio de referencia, su descuento, su valor de venta sin IVA y la fecha de actualización, para revisarlo y negociarlo fuera del sistema.

#### Scenario: Exportación del listado

- **WHEN** el usuario exporta el listado de medicamentos
- **THEN** el sistema genera el archivo con todas las columnas del listado, incluida la fecha de última actualización de cada precio

### Requirement: La medicación queda fuera del alcance de esta etapa

El módulo SHALL presentar la pantalla de medicación en estado **en construcción**, sin datos simulados, indicando las tres razones por las que el circuito no se puede resolver todavía:

1. **No hay de dónde traer el consumo.** `cs.consumo_medicamentos` tiene **0 filas** para clientes AP: la medicación no queda registrada como consumo.
2. **No hay precio de referencia integrado.** El PVP vive en Kairos y no hay integración; hoy el precio se teclea a mano.
3. **No se puede colgar de una autorización.** La medicación no lleva autorización, así que llega en la carga masiva pegada solo al documento del paciente.

Mientras tanto, la medicación SHALL entrar a la prefactura como **ítem manual**, con origen marcado como **Manual**, su respaldo en la observación, y su valor de venta cargado por comercial en la grilla del cliente como cualquier otra prestación.

El módulo NO SHALL mostrar indicadores ni avisos sobre medicación —antigüedad del precio, medicamentos sin revisar— mientras la vista esté en construcción: avisar de un trabajo que no se puede hacer no sirve de nada.

#### Scenario: Ingreso a la vista de medicación

- **WHEN** un usuario entra a la pantalla de medicación
- **THEN** el sistema muestra el estado en construcción con las tres razones, y cómo entra la medicación mientras tanto

#### Scenario: Medicación en una prefactura

- **WHEN** hay que facturarle medicación a un cliente
- **THEN** se carga como ítem manual de la prefactura, con origen Manual, y su valor de venta se resuelve contra la grilla del cliente

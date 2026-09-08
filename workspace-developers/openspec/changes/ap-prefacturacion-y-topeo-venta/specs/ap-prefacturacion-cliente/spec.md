## ADDED Requirements

### Requirement: Listado de prestaciones a prefacturar

El sistema SHALL exponer un listado de las prestaciones de siniestros AP en condiciones de facturarse al cliente, filtrable por **fecha de realización** (filtro principal), **fecha de carga**, **cliente**, **DNI o paciente** y **estado**, con la marca de **erogación tardía** visible en la propia fila.

La **fecha de realización** SHALL ser el criterio de período. La fecha de carga MUST estar disponible como filtro adicional pero MUST NOT usarse para definir el período de facturación: la fecha de carga cambia (el gestor se entera después y carga una prestación de un mes anterior), y usarla como período deja la prestación en el mes equivocado.

Cada fila SHALL informar el **valor de venta sin IVA** tal como está en el contrato del cliente, y el listado SHALL informar el total del filtro con **subtotal sin IVA** y **total con IVA**.

#### Scenario: Prestación cargada después, realizada antes

- **WHEN** una prestación se realizó el 1° de julio y el gestor la cargó el 15 de julio, y se filtra por fecha de realización del 1° al 31 de julio
- **THEN** la prestación aparece en el listado de julio, y la fila muestra además su fecha de carga con la demora

#### Scenario: Filtro por período y cliente

- **WHEN** se filtra por un rango de fecha de realización y un cliente
- **THEN** el sistema devuelve solo las prestaciones de ese cliente realizadas en ese rango, con la cantidad, el subtotal sin IVA y el total con IVA del conjunto filtrado

#### Scenario: Erogaciones tardías identificables en el listado

- **WHEN** el listado contiene prestaciones marcadas como erogación tardía
- **THEN** cada una queda distinguible como tal en su fila y el sistema informa cuántas hay en el filtro

#### Scenario: Filtro que solo trae tardías

- **WHEN** el usuario pide ver únicamente las erogaciones tardías
- **THEN** el listado devuelve solo esas prestaciones, conservando el resto de los filtros aplicados

#### Scenario: Filtro sin resultados

- **WHEN** ningún registro cumple los filtros
- **THEN** el sistema informa que no hay prestaciones con esos filtros, sin devolver totales en cero que se lean como "no hay nada para facturar"

### Requirement: Tres estados de la prefacturación, reversibles hasta facturar

El sistema SHALL manejar exactamente tres estados por prestación en el circuito de facturación al cliente: **pendiente de facturar**, **prefacturado** (dentro de un lote) y **facturado al cliente**. Una prestación sacada de un lote o anulada SHALL quedar registrada con su motivo.

Las transiciones **pendiente → prefacturado** y **prefacturado → pendiente** MUST ser reversibles. La transición a **facturado al cliente** MUST ser terminal: una prestación facturada NO SHALL volver a un estado anterior ni recibir correcciones de valor.

Estos estados SHALL vivir en el modelo propio de prefacturación. El sistema MUST NOT reutilizar el catálogo de estados de facturación existente (No Aplicable, No Facturado, Facturado, Facturado Pendiente Revisión), que describe la factura **del prestador** y lo consume la auditoría de facturación de otro servicio.

#### Scenario: Prestación marcada por error

- **WHEN** una prestación entró a un lote y todavía no se registró la factura
- **THEN** el usuario puede devolverla a pendiente de facturar, y el total del lote se recalcula

#### Scenario: Prestación ya facturada

- **WHEN** se intenta devolver a pendiente o cambiar el valor de una prestación ya facturada al cliente
- **THEN** el sistema lo rechaza e informa que lo facturado no vuelve atrás

#### Scenario: Prestación sacada de un lote

- **WHEN** el usuario saca del lote una prestación cuya prestación fue cancelada por el gestor
- **THEN** el sistema la registra fuera del lote con el motivo, y el lote queda con el total recalculado

### Requirement: Un lote de prefacturado pertenece a un solo cliente

El sistema SHALL exigir que todo lote de prefacturado corresponda a **exactamente un cliente**. Elegir el cliente SHALL ser precondición para generar el lote: sin cliente seleccionado el sistema MUST informar qué falta en lugar de generar un lote mezclado.

Las **erogaciones tardías** de un cliente SHALL agruparse en un **lote separado** del lote del período, identificado como lote de tardías, porque corresponden a prestaciones de períodos ya facturados.

Un lote SHALL registrar el cliente, el período, la cantidad de prestaciones, el subtotal sin IVA, el IVA, el total y su estado (prefacturado o facturado, con el número de factura cuando está facturado).

#### Scenario: Intento de generar un lote sin cliente

- **WHEN** el usuario selecciona prestaciones de más de un cliente, o no eligió cliente, e intenta generar el lote
- **THEN** el sistema no genera el lote e informa que cada lote se factura a un cliente

#### Scenario: Selección con tardías y prestaciones del período

- **WHEN** la selección de un cliente incluye prestaciones del período y erogaciones tardías
- **THEN** el sistema genera dos lotes de ese cliente —uno del período y uno de tardías— e informa antes de confirmar cuántos lotes va a crear y por qué

#### Scenario: Selección con estados mezclados

- **WHEN** la selección incluye prestaciones pendientes y prestaciones ya prefacturadas o facturadas
- **THEN** el sistema no genera el lote e informa que un lote se arma solo con pendientes de facturar

#### Scenario: Deshacer un lote completo

- **WHEN** se deshace un lote que todavía no tiene factura registrada
- **THEN** todas sus prestaciones vuelven a pendiente de facturar y el sistema informa cuántas volvieron y por qué monto

### Requirement: Totales con subtotal sin IVA, IVA e importe total

El sistema SHALL presentar en toda selección y en todo lote tres importes explícitos: **subtotal sin IVA**, **IVA** e **importe total**. Los valores de venta se cargan y se guardan **sin IVA** —así se pactan los contratos— y el IVA se agrega al presentar y al facturar. El sistema MUST NOT presentar un único importe sin declarar si incluye IVA.

No SHALL haber prestaciones exentas: la alícuota aplicada es una sola y es la general.

#### Scenario: Total de una selección

- **WHEN** el usuario tilda un conjunto de prestaciones
- **THEN** el sistema informa la cantidad seleccionada, el subtotal sin IVA, el IVA y el total, y los actualiza al cambiar la selección

#### Scenario: Selección sobre todo el filtro

- **WHEN** el usuario elige seleccionar todas las prestaciones del filtro, más allá de la página que está viendo
- **THEN** la selección abarca el filtro completo y los totales corresponden a ese conjunto, no solo a la página visible

### Requirement: Trazabilidad de los movimientos sobre prestaciones ya prefacturadas

Cuando un gestor **cancela** una prestación o **cambia su valor** después de que entró a un lote, el sistema SHALL registrar el movimiento y **avisar a prefacturación**, informando qué prestación, qué lote, qué cambió, quién y cuándo. El sistema MUST NOT bloquear al gestor: la operación del gestor sigue y la decisión queda del lado de prefacturación.

Sobre cada movimiento el sistema SHALL ofrecer dos salidas: **sacar la prestación del lote** o **aceptar el estado nuevo** dejando el movimiento como revisado. Resolver un movimiento SHALL recalcular el total del lote.

Los movimientos SHALL contarse solo sobre lotes que todavía **no** se facturaron.

#### Scenario: Cancelación de una prestación prefacturada

- **WHEN** un gestor cancela una prestación que está en un lote sin facturar
- **THEN** la cancelación se aplica, y prefacturación recibe el aviso con la prestación, el lote, el usuario y la fecha, sin que el gestor quede bloqueado

#### Scenario: Cambio de valor de una prestación prefacturada

- **WHEN** el valor de una prestación que está en un lote sin facturar cambia
- **THEN** el sistema informa el valor que tenía en el lote y el valor nuevo, y permite tomar el nuevo o mantener el del lote

#### Scenario: Aviso antes de registrar la factura

- **WHEN** se intenta registrar la factura de un lote que tiene movimientos sin revisar
- **THEN** el sistema advierte cuántos son y qué pasó, antes de permitir continuar

#### Scenario: Movimiento sobre un lote ya facturado

- **WHEN** cambia algo de una prestación cuyo lote ya se facturó
- **THEN** el sistema no lo cuenta como movimiento pendiente de revisar, porque lo facturado no se modifica

### Requirement: El valor sale del contrato y se corrige en el contrato

El valor de cada prestación del listado SHALL leerse del **contrato de valor de venta vigente del cliente a la fecha de realización** de la prestación. El sistema MUST NOT permitir tipear ni editar ese valor en la pantalla de prefacturación.

Cuando un valor está mal, el sistema SHALL permitir **avisar a comercial**, que administra los contratos. La corrección hecha en el contrato SHALL propagarse automáticamente a **todas las prestaciones que todavía no se facturaron** (pendientes y prefacturadas) y NO SHALL alterar lo ya facturado al cliente.

#### Scenario: Aviso de valor incorrecto

- **WHEN** el usuario de prefacturación detecta un valor equivocado en una prestación
- **THEN** el sistema registra el aviso hacia comercial e informa que la corrección se hace una sola vez en el contrato

#### Scenario: Corrección del contrato que baja a lo no facturado

- **WHEN** comercial corrige el valor de venta de una prestación en el contrato de un cliente
- **THEN** las prestaciones pendientes y prefacturadas de ese cliente que resuelven contra ese valor quedan con el importe corregido, y las ya facturadas conservan el importe con el que se facturaron

#### Scenario: Prestación sin valor de venta en el contrato

- **WHEN** una prestación realizada no tiene valor de venta cargado para ese cliente y esa fecha
- **THEN** el sistema la muestra como pendiente de valorizar, no la incluye en el total y no la deja seleccionar para un lote

### Requirement: Detalle del lote descargable en PDF y Excel

El sistema SHALL permitir descargar el detalle de un lote —y el de una selección— en **PDF** y en **Excel**, con el detalle prestación por prestación, el subtotal sin IVA, el IVA y el total. La descarga SHALL estar disponible tanto para lotes prefacturados como para lotes ya facturados.

#### Scenario: Descarga del detalle de un lote

- **WHEN** el usuario pide el detalle de un lote en PDF o en Excel
- **THEN** el sistema genera el archivo con las prestaciones del lote, su cliente, su período y los tres importes

#### Scenario: Descarga del detalle de una selección

- **WHEN** el usuario pide el detalle de las prestaciones que tiene seleccionadas, antes de generar el lote
- **THEN** el sistema genera el archivo con esa selección y sus totales, para revisarla antes de armar el lote

### Requirement: Respaldo de la prestación consultable sin salir de la pantalla

El sistema SHALL permitir ver, desde la fila de la prestación, el **respaldo documental** disponible: informe médico, imagen o estudio, y autorización del cliente. Para cada documento SHALL informar si está cargado, si falta, o si no corresponde para esa prestación, y SHALL permitir abrirlo.

Cuando falta respaldo, el sistema SHALL permitir **reclamarlo** y MUST advertir que el cliente entra al portal a buscarlo. La ausencia de respaldo NO SHALL impedir facturar: es una advertencia, no un bloqueo.

#### Scenario: Respaldo completo

- **WHEN** una prestación tiene su informe, su imagen y su autorización cargados
- **THEN** el sistema lo informa como respaldo completo y aclara que el cliente va a encontrar todo en el portal

#### Scenario: Respaldo incompleto al generar el lote

- **WHEN** la selección incluye prestaciones sin respaldo completo
- **THEN** el sistema informa cuántas son antes de confirmar y permite generar el lote igual, advirtiendo que el cliente va a entrar a buscar el documento que falta

#### Scenario: Reclamo de un documento faltante

- **WHEN** el usuario reclama un documento que falta
- **THEN** el sistema registra el reclamo hacia quien corresponde, sin cambiar el estado de la prestación

### Requirement: Registro de la factura emitida al cliente

El sistema SHALL permitir registrar, sobre un lote prefacturado, el **número de factura** y la **fecha de emisión**, pasando sus prestaciones a **facturado al cliente**. El número de factura SHALL ser obligatorio.

La **emisión fiscal de la factura queda fuera del sistema**: acá se registra el número para cerrar el circuito. Una vez registrado, el lote y sus prestaciones MUST quedar congelados, sin volver atrás y sin recibir correcciones de valor.

#### Scenario: Registro de la factura de un lote

- **WHEN** el usuario registra el número y la fecha de la factura de un lote prefacturado
- **THEN** el lote queda facturado con ese número, sus prestaciones pasan a facturado al cliente, y el sistema informa el subtotal, el IVA y el total facturados

#### Scenario: Intento de registrar sin número de factura

- **WHEN** se intenta registrar la factura sin informar el número
- **THEN** el sistema lo rechaza indicando que falta el número de factura

### Requirement: El estado del ítem y su vocabulario

El sistema SHALL manejar el estado de cada ítem con el vocabulario que usa el área, verificado en la transcripción del 20/08 y en la reunión con facturación del 16/07:

| Estado | Qué significa | Acción propia |
|---|---|---|
| **Pendiente de prefacturar** | realizado en el período, todavía fuera de la prefactura | tildar y prefacturar |
| **Prefacturado** | ya está en la prefactura del cliente y el período | revertir el prefacturado |
| **Prefacturado observado** | estaba prefacturado y algo cambió después | revisar y confirmar, o revertir |

La unidad se llama **ítem**, no "línea". El documento se llama **prefactura**, no "lote": en 86 minutos de reunión la palabra "lote" no la dice nadie, y "prefactura" aparece en boca de los usuarios — *"generar prefactura"*, *"revertir items prefacturados"*, *"detalle de prefactura"*.

El motivo de existir del estado **no es medir avance**, y así SHALL comunicarse: es evitar que lo ya prefacturado vuelva a aparecer en el listado del mes siguiente. Textual de facturación: *"para que si mañana tiro el listado y le agrego más fechas no me traiga eso que ya estuvo en otra rendición — va a evitar débitos por facturación duplicada"*.

#### Scenario: Un ítem prefacturado no vuelve a ofrecerse

- **WHEN** un ítem fue prefacturado en un período y se genera el listado de un período posterior cuyo rango de fechas lo incluiría
- **THEN** el sistema NO lo ofrece como pendiente de prefacturar, y lo mantiene asociado a la prefactura en la que entró

#### Scenario: Un ítem prefacturado que cambia pasa a observado

- **WHEN** un ítem prefacturado sufre una de estas tres cosas: se cancela la prestación, el área comercial corrige el valor de venta del período, o llega la factura del prestador con un costo distinto al que había
- **THEN** el sistema lo pasa a **prefacturado observado**, indica cuál de las tres ocurrió, y lo deja como lo único que hay que revisar antes de cerrar

### Requirement: El valor de venta no se edita desde prefacturación

El sistema NO SHALL permitir que el perfil de facturación cargue ni modifique el valor de venta de un ítem. El valor sale de la grilla del cliente, que mantiene el perfil comercial.

Hoy facturación teclea el valor a mano porque no existe la grilla en el sistema — *"ellos cargan los datos básicos y nosotros le ponemos el valor de venta… es un trabajo manual, básicamente"* —, y ese paso **desaparece** con este change: no es una función que haya que conservar.

Cuando falta el precio, el sistema SHALL ofrecer **pedirlo al área comercial**, agrupando el pedido por código de prestación, porque un código sin precio traba todos sus ítems a la vez. Medido sobre un período real: **81 ítems pendientes corresponden a 17 códigos**, y los 5 primeros cubren 64 de los 81.

#### Scenario: Ítem sin precio en la grilla

- **WHEN** un ítem no tiene valor de venta resuelto contra la grilla del cliente
- **THEN** el sistema lo muestra como **sin precio** —nunca como $ 0—, lo deja fuera del total, y ofrece pedir el precio a comercial para todos los ítems de ese código

#### Scenario: El cierre no queda bloqueado esperando a otra área

- **WHEN** la prefactura tiene ítems sin precio y la usuaria decide cerrarla igual
- **THEN** el sistema avisa cuántos quedan afuera y que entran en la próxima prefactura cuando comercial cargue el valor, y permite cerrar

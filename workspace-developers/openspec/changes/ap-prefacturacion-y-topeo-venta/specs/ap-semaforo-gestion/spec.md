## ADDED Requirements

### Requirement: Aviso al 90% de la proyección, con destinatarios definidos

El sistema SHALL emitir el aviso de consumo cuando la **proyección** de un siniestro AP alcanza el **90%** de la suma asegurada. El corte es **uno solo** y es **fijo**: reemplaza el criterio anterior de emitir un aviso en cada cambio de nivel hacia arriba.

El aviso SHALL dirigirse a los **tramitadores que cargan autorizaciones** y a **auditoría médica**, que son quienes pueden frenar el gasto antes de que ocurra. Al 90% **todavía se puede autorizar**: el aviso avisa, no bloquea.

El aviso SHALL registrarse **una sola vez** por siniestro y por tope vigente. Una **ampliación del tope** SHALL habilitar un aviso nuevo cuando la proyección vuelva a cruzar el 90% del tope ampliado. El sistema SHALL informar en el detalle del siniestro y en los listados que el aviso del 90% ya se emitió.

Los cinco niveles del semáforo (Bajo, Medio, Alto, Muy alto, Excedido) SHALL seguir existiendo para leer el estado de la cartera, con 40 y 70 parametrizables y 90 y 100 fijos, pero **dejan de ser el disparador del aviso**.

#### Scenario: Cruce del 90%

- **WHEN** la proyección de un siniestro AP pasa del 90% de la suma asegurada
- **THEN** el sistema emite el aviso a los tramitadores que cargan autorizaciones y a auditoría médica, y lo registra

#### Scenario: El aviso no se repite

- **WHEN** la proyección de un siniestro que ya avisó al 90% sigue subiendo
- **THEN** el sistema no vuelve a emitir el aviso del 90% para ese siniestro y ese tope

#### Scenario: Aviso nuevo después de ampliar el tope

- **WHEN** se amplía el tope de un asegurado que ya había avisado, y la proyección vuelve a superar el 90% del tope ampliado
- **THEN** el sistema emite un aviso nuevo, porque corresponde a otro tope vigente

#### Scenario: Autorización posible después del aviso

- **WHEN** un siniestro ya avisó al 90% y se intenta cargar una autorización nueva
- **THEN** el sistema permite la autorización, mostrando el consumo y el saldo

#### Scenario: Consulta de siniestros que ya avisaron

- **WHEN** se filtra el listado de siniestros por los que ya avisaron al 90%
- **THEN** el sistema devuelve solo esos siniestros y lo indica en cada fila

### Requirement: Al 100% se cierra el siniestro y se bloquean las autorizaciones nuevas

Cuando el consumo supera la suma asegurada, el sistema SHALL **cerrar el siniestro** y **bloquear la carga de autorizaciones nuevas**. Reemplaza el criterio anterior de "avisa pero no bloquea, con bloqueo activable por parámetro".

Para seguir atendiendo al asegurado hace falta **ampliar el tope con autorización del cliente**, y la ampliación SHALL quedar registrada con **motivo, usuario y fecha**.

El **cierre del siniestro por tope** SHALL habilitarse únicamente cuando el **facturado al cliente** agotó la suma asegurada. El sistema SHALL informar el **motivo** de la habilitación o de su ausencia con un valor estable, no con un texto libre, cubriendo cuatro casos: el facturado alcanza el tope (**único que habilita**), el facturado está por debajo del tope, la proyección supera el tope pero el facturado no, y no hay tope definido.

Este servicio **no ejecuta el cierre de la denuncia**: expone el hecho de que el facturado alcanzó el tope. El cierre es un proceso de otro servicio, que registra su propia bitácora, dispara el proceso de incapacidad y notifica a los sistemas externos.

#### Scenario: Facturado que agota la suma asegurada

- **WHEN** el facturado al cliente de un siniestro AP alcanza o supera la suma asegurada
- **THEN** el sistema habilita el cierre por tope, informando que ese es el motivo, y deriva a la pantalla que ejecuta el cierre

#### Scenario: Proyección excedida con facturado por debajo

- **WHEN** la proyección supera el tope y el facturado al cliente todavía no
- **THEN** el sistema NO habilita el cierre e informa que esa plata todavía no se facturó y que puede no facturarse nunca, indicando cuánto falta facturar

#### Scenario: Siniestro sin tope cargado

- **WHEN** un siniestro AP no tiene suma asegurada resuelta
- **THEN** el sistema no habilita el cierre e informa que sin tope no hay contra qué medir el facturado

#### Scenario: Bloqueo de autorizaciones al superar el tope

- **WHEN** el consumo de un siniestro supera la suma asegurada y se intenta cargar una autorización nueva
- **THEN** el sistema la rechaza informando el consumo, el tope y el excedente

#### Scenario: Ampliación del tope para seguir atendiendo

- **WHEN** el cliente autoriza ampliar la suma asegurada de un asegurado con el siniestro bloqueado
- **THEN** el sistema registra la ampliación con motivo, usuario y fecha, y las autorizaciones vuelven a ser posibles dentro del tope ampliado

#### Scenario: El cierre no lo ejecuta este servicio

- **WHEN** el usuario confirma el cierre por tope desde el detalle del siniestro
- **THEN** el sistema deriva al proceso de cierre de denuncias, que es el que registra la bitácora del cierre y dispara sus efectos

### Requirement: Lo que se pasa del tope se debita

El sistema SHALL comunicar, cuando la proyección supera la suma asegurada, **el importe que excede y su consecuencia económica**: el cliente paga hasta la suma asegurada y lo que se pase se debita de la factura, o sea que lo pierde Colonia Suiza.

Textual de facturación: *"si se pasa no nos pagan nada… le facturamos en total ocho millones cien y esos cien los debita: yo te pago hasta ocho"*.

La pantalla SHALL dar el importe excedido y el porcentaje proyectado sobre la suma asegurada. NO SHALL explicar el mecanismo del débito en cada pantalla: quien la usa lo conoce.

#### Scenario: Proyección por encima del tope

- **WHEN** la proyección de un siniestro supera su suma asegurada
- **THEN** el sistema muestra el importe que se pasa y el porcentaje proyectado, y ofrece el aviso al cliente

### Requirement: El procedimiento que dispara llegar al tope

Al llegar al aviso, el sistema SHALL ofrecer los tres pasos del circuito real, en orden y con registro de quién y cuándo:

1. **Avisar al cliente** — la aseguradora decide si amplía el tope o si se corta.
2. **Registrar el aviso al paciente** — el cliente pide que se lo llame para decirle que llegó al tope y que no se dan más prestaciones.
3. **Cerrar el siniestro por tope** — el cierre se hace desde la denuncia, en tramitadores; desde acá queda el aviso de que corresponde.

Textual: *"se le avisa al cliente y el cliente nos pide que le avisemos al paciente, se la llama al paciente, le dice llegó al tope y no se da más prestaciones, se cierra el siniestro"*.

#### Scenario: Siniestro que llega al 90 %

- **WHEN** la proyección de un siniestro alcanza el 90 % de la suma asegurada
- **THEN** el sistema ofrece los tres pasos del procedimiento y registra cada uno con su autor y fecha

### Requirement: Erogación tardía sobre un siniestro ya cerrado

El sistema SHALL alertar de forma propia cuando llega una erogación tardía sobre un siniestro **ya cerrado por tope**, indicando su importe con IVA, la demora de la factura y si con ella el siniestro pasa la suma asegurada.

Es el caso más caro y el que nadie ve venir: *"las cirugías que nosotros cerramos y le dieron de alta, pero dos meses después llega la medicación que el centro médico nos facturó y nosotros tenemos que facturarlo, y por ahí se termina pasando de la suma"*.

#### Scenario: Medicación de una cirugía facturada después del alta

- **WHEN** entra una erogación cuya fecha de realización corresponde a un siniestro cerrado por tope
- **THEN** el sistema la incorpora igual —el prestador ya la cobró— y alerta si con ella la proyección supera la suma asegurada, indicando el importe excedido

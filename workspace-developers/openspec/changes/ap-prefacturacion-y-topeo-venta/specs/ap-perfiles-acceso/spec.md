## ADDED Requirements

### Requirement: Consulta de siniestros disponible en los dos perfiles

El sistema SHALL poner la **consulta de siniestros** del tramitador analista de AP a disposición de **los dos perfiles** (prefacturación y comercial): los dos necesitan ver el siniestro completo. La consulta SHALL ser filtrable por número de denuncia, paciente o documento, cliente, estado del siniestro, **nivel del semáforo** y **si ya avisó al 90%**.

Cada fila SHALL informar denuncia, paciente, documento, cliente, fecha del siniestro, estado, **suma asegurada** (con IVA), **porcentaje de proyección y de facturado por separado** y el **nivel del semáforo escrito**.

#### Scenario: Consulta desde el perfil de prefacturación

- **WHEN** un usuario del perfil de prefacturación abre la consulta de siniestros
- **THEN** el sistema le devuelve el listado con los mismos datos que ve el tramitador analista de AP

#### Scenario: Filtro por nivel del semáforo

- **WHEN** el usuario filtra por un nivel del semáforo
- **THEN** el sistema devuelve solo los siniestros en ese nivel

#### Scenario: Filtro por aviso emitido

- **WHEN** el usuario filtra por los siniestros que ya avisaron al 90%
- **THEN** el sistema devuelve solo esos y lo indica en cada fila

### Requirement: El acceso a lo económico del siniestro se hace por el menú de la denuncia

El sistema SHALL exponer la información económica de un siniestro AP dentro del **detalle de la denuncia**, a través de su **menú secundario**, en la sección **"Costos y Topeo"**. La sección SHALL estar gobernada por el permiso de semáforo de AP, chequeado en el backend, y MUST NOT ser visible para quien no lo tiene.

El menú secundario del que forma parte es el **real** de la denuncia (detalle, general, primera asistencia y derivaciones, seguimiento, turnos, auditoría médica, solicitudes genéricas, ortopedia, adelantos y reintegros, imágenes, requerimientos, hotelería, cirugías, insumos y medicación, auditoría de facturación, costos y topeo, cierre de siniestro). Este change MUST NOT introducir un menú paralelo para AP.

#### Scenario: Usuario con permiso de semáforo

- **WHEN** un usuario con el permiso de semáforo de AP abre el detalle de una denuncia
- **THEN** el menú secundario incluye la sección "Costos y Topeo" y desde ahí se ve el consumo contra la suma asegurada

#### Scenario: Usuario sin permiso de semáforo

- **WHEN** un usuario sin ese permiso abre el detalle de una denuncia
- **THEN** la sección "Costos y Topeo" no aparece en el menú, y el endpoint de consumo responde denegado si se lo invoca directamente

#### Scenario: Navegación desde el panel de pacientes a vigilar

- **WHEN** el usuario abre una denuncia desde el panel de pacientes a vigilar de la pantalla de inicio
- **THEN** el sistema lo lleva al detalle de esa denuncia, con la sección "Costos y Topeo" seleccionada

## MODIFIED Requirements

### Requirement: Separación entre perfil de gestión y perfil comercial


El sistema SHALL mantener dos perfiles distintos en el dominio AP, con permisos propios:

- **Prefacturación** — arma lo que se le cobra al cliente, vigila el consumo contra el tope y registra la factura emitida. Es el perfil que usa la operación de facturación de AP.
- **Comercial** — administra los **contratos de valor de venta** por cliente, sus vigencias y sus aumentos, y mira el margen. Es el perfil que usa comercial, dueño de los contratos.

La escritura de los contratos de valor de venta SHALL ser exclusiva del perfil comercial. La generación de lotes y el registro de la factura al cliente SHALL ser exclusivas del perfil de prefacturación. **Prefacturación no corrige valores**: avisa a comercial, que corrige en el contrato.

Todo chequeo de permisos SHALL hacerse **en el backend**. Ocultar un botón en el front NO SHALL considerarse control de acceso.

> Reemplaza al requisito homónimo de `ap-costos-topeo-etapa1`. El alcance pasa a ser **Separación entre perfil de prefacturación y perfil comercial**.

#### Scenario: Prefacturación intenta editar un contrato

- **WHEN** un usuario del perfil de prefacturación intenta modificar un valor de venta del contrato
- **THEN** el backend rechaza la operación por falta de permiso, con independencia de lo que muestre la pantalla

#### Scenario: Comercial intenta registrar una factura al cliente

- **WHEN** un usuario del perfil comercial intenta registrar la factura emitida de un lote
- **THEN** el backend rechaza la operación por falta de permiso

#### Scenario: Aviso de valor incorrecto entre perfiles

- **WHEN** prefacturación detecta un valor equivocado y lo avisa
- **THEN** el sistema registra el aviso hacia comercial, sin permitirle a prefacturación editar el valor

#### Scenario: Permiso nuevo y sesión vigente

- **WHEN** se da de alta un permiso nuevo del dominio AP para un usuario con sesión abierta
- **THEN** el permiso recién toma efecto después de que el usuario cierre sesión y vuelva a entrar

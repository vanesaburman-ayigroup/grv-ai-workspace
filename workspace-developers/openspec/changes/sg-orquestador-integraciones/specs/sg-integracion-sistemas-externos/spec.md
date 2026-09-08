## ADDED Requirements

### Requirement: Alta de Solicitud Genérica por un sistema externo autorizado
El Orquestador de Integraciones SHALL exponer un endpoint bajo `/V1/external/solicitudes-genericas`
que permita a un sistema externo autenticado con su API key dar de alta una Solicitud Genérica (SG),
sin requerir un operador logueado del SAS.

#### Scenario: Alta exitosa desde un sistema autorizado
- **WHEN** un sistema externo con API key válida y alcance habilitado para el tipo de solicitud
  solicitado envía un alta de SG
- **THEN** el Orquestador crea la SG contra `wssolicitudesgenericas`, registrando el sistema de
  origen, y devuelve el identificador de la SG creada

#### Scenario: Rechazo por API key inválida o ausente
- **WHEN** una llamada de alta llega sin API key o con una que no está registrada en
  `security.api-keys.clients`
- **THEN** el Orquestador rechaza la llamada sin invocar a `wssolicitudesgenericas`

#### Scenario: Rechazo por tipo de solicitud fuera de alcance del sistema
- **WHEN** un sistema externo autenticado solicita un alta de un tipo de solicitud que no está
  habilitado para él en la configuración de alcance
- **THEN** el Orquestador rechaza la solicitud sin invocar a `wssolicitudesgenericas`

### Requirement: Consulta de Solicitudes Genéricas por un sistema externo
El Orquestador SHALL exponer un endpoint de listado y uno de detalle que devuelvan únicamente las SG
visibles para el sistema externo autenticado, según su alcance configurado.

#### Scenario: Listado acotado al sistema que consulta
- **WHEN** un sistema externo autenticado solicita el listado de sus solicitudes
- **THEN** el Orquestador devuelve únicamente las SG cuyo sistema de origen coincide con el sistema
  autenticado

#### Scenario: Detalle de una solicitud ajena
- **WHEN** un sistema externo autenticado solicita el detalle de una SG que no le pertenece (sistema
  de origen distinto)
- **THEN** el Orquestador rechaza la consulta sin exponer datos de la solicitud

### Requirement: Identificación del sistema de origen
Toda SG generada por un sistema externo SHALL quedar registrada con su sistema de origen, visible en
la tabla de Solicitudes Genéricas del SAS junto al resto de la información de la solicitud.

#### Scenario: SG generada externamente muestra su origen en el SAS
- **WHEN** un operador interno del SAS abre el listado de Solicitudes Genéricas
- **THEN** las SG generadas por un sistema externo muestran ese sistema como origen, distinguibles de
  las cargadas por un operador del SAS

#### Scenario: SG generada por el SAS no tiene sistema de origen
- **WHEN** un operador del SAS da de alta una SG desde la pantalla interna
- **THEN** la SG queda registrada sin sistema de origen (equivalente al comportamiento actual)

### Requirement: Alcance configurable por sistema consumidor
El alcance de qué tipos de solicitud puede generar y consultar cada sistema externo SHALL ser
configuración de datos, no lógica de código específica para ese sistema.

#### Scenario: Habilitar un tipo de solicitud nuevo para un sistema sin desplegar código
- **WHEN** se agrega una fila de configuración que habilita un tipo de solicitud adicional para un
  sistema ya conectado
- **THEN** ese sistema puede operar con el tipo nuevo sin requerir un cambio de código en el
  Orquestador ni en `wssolicitudesgenericas`

### Requirement: Derivación exclusiva a área de gestión para SG externas
Toda SG generada por un sistema externo SHALL derivarse a un área de gestión completa. El Orquestador
no SHALL aceptar ni propagar una derivación a una persona puntual (gestor) para altas externas.

#### Scenario: Alta externa no expone selección de gestor
- **WHEN** un sistema externo envía un alta de SG
- **THEN** la SG resultante queda derivada a un área de gestión y no tiene un gestor individual
  asignado en el momento de la creación

#### Scenario: Consulta externa no expone nombre de gestor
- **WHEN** un sistema externo consulta el listado o detalle de una SG propia
- **THEN** la respuesta no incluye el nombre de una persona gestora, únicamente el área de gestión

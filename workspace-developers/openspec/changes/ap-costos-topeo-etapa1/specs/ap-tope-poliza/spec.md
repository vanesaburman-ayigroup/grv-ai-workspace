## ADDED Requirements

### Requirement: Persistencia del tope de la póliza AP

El sistema SHALL persistir la **suma asegurada** de cada póliza de Accidentes Personales por **asegurado/paciente**, expresada **con IVA incluido**, con moneda y **ventana de aplicación**. Hoy `cs.polizas_ap` no tiene ninguna columna de monto, por lo que el tope MUST almacenarse en una estructura nueva sin modificar destructivamente la póliza existente.

La ventana de aplicación SHALL ser **dato configurable y no código**, con los valores `ANUAL` (por vigencia anual de la póliza, **el valor por defecto**), `EVENTO` (por siniestro) y `POLIZA`. El criterio de negocio vigente es **anual**, pero está explícitamente sujeto a cambio: el sistema MUST poder pasar de anual a por-evento sin modificar la estructura de datos.

#### Scenario: Ventana anual por defecto

- **WHEN** se carga un tope sin especificar la ventana
- **THEN** el sistema lo registra con ventana `ANUAL`, que es el criterio vigente

#### Scenario: Cambio del criterio de ventana

- **WHEN** negocio decide que el tope pase a aplicarse por siniestro en lugar de anual
- **THEN** el cambio se realiza sobre el dato de la ventana, sin requerir modificaciones de estructura ni un despliegue de esquema

#### Scenario: Carga del tope al dar de alta una póliza

- **WHEN** un usuario de Mesa de Carga da de alta una póliza AP e ingresa la suma asegurada por asegurado
- **THEN** el sistema guarda el monto con su marca de IVA incluido, moneda y ventana, junto con la fecha y el usuario responsable de la carga

### Requirement: Suma asegurada obligatoria en el alta de la póliza AP

El alta de una póliza AP por Mesa de Carga SHALL exigir la **suma asegurada** como dato obligatorio. El sistema MUST NOT permitir dar de alta una póliza AP sin su tope, porque una póliza sin tope deja al siniestro sin control de consumo. La validación SHALL aplicarse en el backend, no solo en el formulario.

#### Scenario: Intento de alta sin suma asegurada

- **WHEN** un usuario intenta dar de alta una póliza AP sin informar la suma asegurada
- **THEN** el sistema rechaza el alta indicando que el dato es obligatorio, y no crea la póliza

#### Scenario: Alta enviada directamente al backend sin el dato

- **WHEN** se invoca el endpoint de alta de póliza AP sin la suma asegurada
- **THEN** el backend rechaza la operación con un error de validación

#### Scenario: Pólizas AP preexistentes sin tope

- **WHEN** existen pólizas AP dadas de alta antes de esta funcionalidad, sin suma asegurada
- **THEN** el sistema las identifica como pendientes de completar el tope y las expone en un listado para que negocio las regularice, sin bloquear su operación normal

### Requirement: Edición y ampliación del tope

El sistema SHALL permitir **editar la suma asegurada** de una póliza AP ya existente, y SHALL contemplar explícitamente la **ampliación del tope** durante la vida del siniestro cuando el cliente la autoriza. Toda modificación MUST conservar trazabilidad: valor anterior, valor nuevo, **motivo**, usuario y fecha. La modificación SHALL propagarse al consumo de los siniestros vinculados, de modo que el semáforo refleje el tope vigente.

#### Scenario: Corrección de una suma asegurada mal cargada

- **WHEN** un usuario habilitado edita la suma asegurada de una póliza AP indicando el motivo
- **THEN** el sistema guarda el valor nuevo, registra el cambio con motivo, usuario y fecha, y actualiza el tope de los siniestros vinculados activos

#### Scenario: Ampliación autorizada por el cliente

- **WHEN** el cliente autoriza ampliar la suma asegurada de un asegurado que está cerca del tope
- **THEN** el sistema registra el tope ampliado con su motivo, y el semáforo recalcula el nivel del siniestro contra el tope nuevo

#### Scenario: Siniestro que sale del nivel Excedido por una ampliación

- **WHEN** un siniestro estaba en nivel Excedido y se amplía el tope de modo que el consumo queda por debajo del 100%
- **THEN** el sistema recalcula el nivel y conserva en el historial que el caso estuvo excedido antes de la ampliación

#### Scenario: Consulta del historial de cambios del tope

- **WHEN** se consulta una póliza AP cuyo tope fue modificado
- **THEN** el sistema muestra el historial de valores con su motivo, quién los cambió y cuándo

#### Scenario: Tope duplicado para el mismo asegurado y ventana

- **WHEN** se intenta cargar un segundo tope activo para la misma combinación de póliza, documento del asegurado y ventana
- **THEN** el sistema rechaza el alta por unicidad y conserva el tope vigente

#### Scenario: Póliza sin tope cargado

- **WHEN** se consulta el semáforo de un siniestro cuya póliza no tiene tope cargado
- **THEN** el sistema informa el estado `SIN_TOPE` en lugar de calcular un porcentaje, y no muestra un semáforo engañoso

### Requirement: Resolución del tope EN VIVO, con tope general de póliza y excepciones

El sistema SHALL resolver el tope aplicable **en cada consulta del semáforo**, con la siguiente prioridad: (1) la **excepción** activa del asegurado en `polizas_ap_topes` para su póliza, documento y ventana; (2) el **tope general** de la póliza (`polizas_ap.suma_asegurada`), que aplica a cada asegurado por separado; (3) `SIN_TOPE`. El sistema SHALL informar de cuál de los tres niveles salió el tope, y NO SHALL depender de las columnas denormalizadas de `denuncia_poliza`, que quedan como caché opcional.

> Reemplaza la denormalización obligatoria hacia `denuncia_poliza` que este mismo change proponía. Motivo: el paso de denormalización dejaba el semáforo dependiendo de una escritura que nadie disparaba (54 de 61 siniestros de stage daban `SIN_TOPE` teniendo póliza cargada), obligaba a modificar un ws ajeno —dueño de `denuncia_poliza`— y a escribir dentro de un GET. Resolviéndolo en vivo, cargar o ampliar un tope se ve en el semáforo al instante.

#### Scenario: El asegurado tiene una excepción de tope

- **WHEN** se consulta el semáforo de un siniestro cuyo accidentado tiene un tope activo propio en la póliza
- **THEN** el sistema aplica la suma asegurada de esa excepción, informa el origen `EXCEPCION` e identifica la fila de tope aplicada

#### Scenario: El asegurado no tiene excepción y la póliza declara tope general

- **WHEN** se consulta el semáforo de un siniestro sin tope propio, en una póliza que declara suma asegurada
- **THEN** el sistema aplica el tope general de la póliza e informa el origen `GENERAL`, sin identificar ninguna fila de excepción

#### Scenario: La excepción pisa al tope general

- **WHEN** un asegurado tiene una excepción y su póliza también declara tope general
- **THEN** el sistema aplica la excepción, no el tope general

#### Scenario: Excepción dada de baja

- **WHEN** la excepción del asegurado está dada de baja lógicamente
- **THEN** el sistema vuelve a aplicar el tope general de la póliza

#### Scenario: Ampliación del tope reflejada sin ningún paso intermedio

- **WHEN** se amplía la suma asegurada de un asegurado que ya tiene siniestros abiertos
- **THEN** la consulta siguiente del semáforo ya usa el tope nuevo, sin requerir una actualización de las columnas de `denuncia_poliza`

#### Scenario: Caché de `denuncia_poliza` desactualizada

- **WHEN** las columnas de tope de `denuncia_poliza` están pobladas con un valor distinto del tope vigente
- **THEN** el sistema calcula con el tope vigente y deja registro de la divergencia, sin alterar el resultado

#### Scenario: Documento del asegurado con separadores o ceros a la izquierda

- **WHEN** el documento cargado en el padrón de afiliados tiene puntos, espacios o ceros a la izquierda y el tope está guardado normalizado
- **THEN** el sistema encuentra igual la excepción y no cae al tope general

#### Scenario: Una sola póliza activa por denuncia

- **WHEN** se consulta el tope de una denuncia AP
- **THEN** el sistema resuelve el tope a partir del único vínculo `denuncia_poliza` activo de esa denuncia

### Requirement: Identificación del universo AP

El sistema SHALL identificar los siniestros de Accidentes Personales por su vínculo activo en `denuncia_poliza`, y el universo de clientes AP por `clientes.tipo_cliente = 3` junto con `empleadores.acepta_polizas_ap = 1`.

#### Scenario: Filtrado del universo AP para el cálculo de consumo

- **WHEN** el motor de consumo determina qué siniestros procesar
- **THEN** el sistema considera únicamente las denuncias con vínculo activo en `denuncia_poliza`, acotando el volumen antes de cruzar las tablas grandes de turnos y erogaciones

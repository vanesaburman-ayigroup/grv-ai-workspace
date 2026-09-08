## ADDED Requirements

### Requirement: Tres vías de entrada de una prestación al siniestro

El sistema SHALL registrar y exponer, por cada prestación de un siniestro AP, **por qué vía entró**, distinguiendo exactamente tres:

- **Autorización** — la cargó el gestor. Nace con número de autorización y es la vía prolija.
- **Erogación asociada** — llegó en la carga masiva del sistema de auditoría de facturación **con** número de autorización, y por eso se puede matchear con lo ya cargado.
- **Erogación libre o simple** — llegó en la misma carga masiva **pegada solo al documento del paciente**, sin autorización ni turno.

La vía SHALL ser visible en el detalle del siniestro junto con la instancia de consumo, porque explica por qué una prestación aparece sin que nadie la haya informado.

#### Scenario: Prestación cargada por el gestor

- **WHEN** el gestor carga una autorización y su prestación
- **THEN** el sistema la registra con vía de entrada por autorización y con su número de autorización

#### Scenario: Erogación con número de autorización

- **WHEN** una línea de la carga masiva trae número de autorización y ese número existe en el siniestro
- **THEN** el sistema la asocia a la autorización correspondiente y la registra con vía de entrada por erogación asociada

#### Scenario: Erogación pegada solo al documento

- **WHEN** una línea de la carga masiva llega sin número de autorización y solo con el documento del paciente
- **THEN** el sistema la registra con vía de entrada por erogación libre, la vincula al siniestro por el documento, y la deja identificable como no matcheada

#### Scenario: Medicación sin autorización

- **WHEN** llega una línea de medicación que nadie autorizó (el prestador no pide autorización para entregar un analgésico; a lo sumo hay una orden médica en la evolución)
- **THEN** el sistema la incorpora al siniestro por la vía de erogación libre en lugar de descartarla por no tener autorización

### Requirement: Erogación tardía — definición, marcado y facturación aparte

El sistema SHALL marcar como **erogación tardía** la prestación cuya **fecha de realización** cae dentro de un período **ya facturado** al cliente. Es el caso del prestador que factura dos meses después de la atención e incluye prestaciones que nunca informó.

Una erogación tardía SHALL quedar visualmente distinguida en el listado de prefacturación y en el detalle del siniestro, SHALL contarse por separado, y SHALL facturarse **aparte**, en un lote propio del cliente y no dentro del lote del período corriente.

El sistema SHALL informar la cantidad de erogaciones tardías pendientes de facturar como indicador propio, porque hoy detectarlas es cruzar planillas a mano por documento.

#### Scenario: Prestación de un mes ya facturado

- **WHEN** aparece una prestación con fecha de realización dentro de un período cuyo lote ya fue facturado a ese cliente
- **THEN** el sistema la marca como erogación tardía y la deja pendiente de facturar, sin tocar el lote ya facturado

#### Scenario: Prestación de un período todavía no facturado

- **WHEN** aparece una prestación con fecha de realización dentro de un período que todavía no se facturó a ese cliente
- **THEN** el sistema NO la marca como tardía: entra al circuito normal de pendiente de facturar

#### Scenario: Lote de tardías separado

- **WHEN** se generan lotes para un cliente cuya selección incluye erogaciones tardías
- **THEN** las tardías van en un lote propio, identificado como lote de tardías, con su propio detalle y sus propios totales

#### Scenario: Indicador de tardías sin facturar

- **WHEN** un usuario de prefacturación abre su pantalla de inicio
- **THEN** el sistema informa cuántas erogaciones tardías están sin facturar y por qué monto sin IVA

### Requirement: La factura del prestador descubre lo no informado y se convierte a valor de venta

El sistema SHALL usar la factura del prestador (la erogación) como **detector de prestaciones no informadas**: cuando trae una prestación que no está en el siniestro, esa prestación SHALL incorporarse al consumo y al circuito de facturación al cliente.

El importe de la erogación es **costo sin IVA** y MUST NOT usarse como el importe a facturar al cliente. Al incorporarse, la prestación SHALL valorizarse con el **valor de venta del contrato del cliente vigente a su fecha de realización**, más IVA, y entrar por la **instancia que le corresponda** —normalmente devengado, porque la prestación ya se realizó—. La factura del prestador MUST NOT constituir una cuarta instancia de consumo.

El importe de costo SHALL conservarse junto a la prestación, porque es el término que permite medir margen.

#### Scenario: Erogación que trae una prestación que nadie informó

- **WHEN** la factura de un prestador incluye una radiografía y sesiones de kinesiología que el gestor nunca cargó
- **THEN** el sistema las incorpora al siniestro, las valoriza con el valor de venta del contrato del cliente más IVA, las clasifica como devengado, y conserva el importe de costo de la factura

#### Scenario: El costo no se factura al cliente

- **WHEN** una prestación entra por una erogación cuyo importe de costo difiere del valor de venta del contrato
- **THEN** lo que se factura al cliente es el valor de venta del contrato más IVA, y el importe de la erogación queda registrado solo como costo

#### Scenario: Erogación de una prestación ya cargada por autorización

- **WHEN** la erogación corresponde a una prestación que el gestor ya había cargado
- **THEN** el sistema no la suma dos veces: la reconoce como la factura de esa prestación y no genera una prestación nueva

#### Scenario: Prestación incorporada sin valor de venta en el contrato

- **WHEN** una prestación entra por erogación y no hay valor de venta cargado para ese cliente y esa fecha
- **THEN** el sistema la registra como pendiente de valorizar, sin usar el costo como sustituto del valor de venta

### Requirement: La carga masiva debe exigir número de autorización

El sistema SHALL exigir **número de autorización** en las líneas de la carga masiva de erogaciones, para que el match con la autorización sea automático y no queden líneas colgadas solo del documento del paciente.

Mientras esa exigencia no esté implementada del lado de la carga masiva, el sistema SHALL admitir la línea sin número de autorización, registrarla como **erogación libre** y dejarla **identificable como no matcheada**, para que la revisión sea explícita y no silenciosa.

> El requerimiento cruza el límite de este servicio: la carga masiva es de auditoría de facturación. Queda expresado acá porque de él depende que la vía B (erogación asociada) sea la norma y la vía C (erogación libre) la excepción.

#### Scenario: Línea de carga masiva con número de autorización

- **WHEN** una línea de la carga masiva trae número de autorización
- **THEN** el sistema la asocia automáticamente a esa autorización, sin intervención manual

#### Scenario: Línea de carga masiva sin número de autorización

- **WHEN** una línea llega sin número de autorización, con la exigencia todavía no implementada
- **THEN** el sistema la acepta, la marca como erogación libre no matcheada, y la expone para revisión en lugar de integrarla en silencio

### Requirement: Qué se muestra de una erogación tardía

El sistema SHALL mostrar la **demora concreta de esa erogación**, calculada como `DATEDIFF(fecha_ingreso_factura, fecha_carga)`: los días entre la fecha que dice la factura del prestador y su ingreso al sistema.

El sistema NO SHALL etiquetar la tardía como "prestador del interior", aunque esa sea la explicación que circula en el área.

Medido contra producción el 04/09/2026 sobre 14.411 erogaciones de clientes AP de 2026:

| Región del prestador | Erogaciones | Demora promedio | Máxima | % > 45 días |
|---|---:|---:|---:|---:|
| (proveedor sin provincia cargada) | 14.098 | 45,7 d | 401 d | 66,4 % |
| Interior | 200 | 39,9 d | 279 d | 28,5 % |
| AMBA / Buenos Aires | 113 | 50,2 d | 61 d | 74,3 % |

El **97,8 %** de los proveedores que aparecen en erogaciones AP no tiene provincia cargada, y en la porción que sí la tiene el interior tarda **menos** que AMBA. La categoría de prestador no explica la demora.

#### Scenario: Marca de una erogación tardía

- **WHEN** una erogación entra con fecha de realización de un período ya prefacturado
- **THEN** el sistema la marca como tardía y muestra los días de demora de esa factura en particular, no una categoría de prestador

### Requirement: El proveedor de una erogación no está donde parece

Toda consulta que necesite el prestador de una erogación SHALL resolverlo con un `COALESCE` de `id_proveedor_centro_medico`, `id_proveedor_ortopedia` e `id_proveedor_farmacia`, y NO SHALL leer `erogaciones.id_proveedor`.

Verificado el 04/09/2026: `cs.erogaciones.id_proveedor` está **NULL en las 27.308 erogaciones de clientes AP**. El proveedor vive en tres columnas según el tipo, y ahí está cargado al **99,6 %**:

| Columna | Erogaciones AP |
|---|---:|
| `id_proveedor_centro_medico` | 26.715 |
| `id_proveedor_ortopedia` | 255 |
| `id_proveedor_farmacia` | 233 |

La consulta que hoy usa Planeamiento para el exportado tiene este defecto y por eso su columna "proveedor" sale vacía siempre.

Dato relacionado: **23.969 de 27.308 (88 %)** de las erogaciones AP entran por **carga masiva**.

#### Scenario: Consulta que necesita el prestador de una erogación

- **WHEN** una consulta necesita identificar al prestador de una erogación de un cliente AP
- **THEN** lo resuelve con `COALESCE(id_proveedor_centro_medico, id_proveedor_ortopedia, id_proveedor_farmacia)` y NO con `erogaciones.id_proveedor`, que está NULL en las 27.308 erogaciones AP

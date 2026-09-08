## ADDED Requirements

### Requirement: Duplicación de la estructura de un contrato a otro cliente

El sistema SHALL permitir **duplicar la estructura de prestaciones** del contrato de un cliente hacia otro cliente, para no tener que cargar la lista completa de nuevo cuando se suma un cliente. Las prestaciones que se ofrecen son casi siempre las mismas; lo que cambia son los importes.

La duplicación SHALL permitir **excluir prestaciones** del conjunto a copiar, y los importes copiados SHALL quedar **editables** en el contrato destino.

#### Scenario: Alta de un cliente nuevo a partir de un contrato existente

- **WHEN** el usuario duplica la estructura del contrato de un cliente hacia un cliente nuevo
- **THEN** el sistema crea las filas de la grilla del cliente destino con las prestaciones del origen, y quedan editables

#### Scenario: Duplicación con exclusiones

- **WHEN** el usuario excluye algunas prestaciones al duplicar
- **THEN** el sistema no las crea en el contrato destino

#### Scenario: Duplicación sobre un cliente que ya tiene grilla

- **WHEN** el cliente destino ya tiene valores cargados para algunas de las prestaciones a copiar
- **THEN** el sistema informa el conflicto y no sobrescribe valores vigentes sin confirmación explícita

### Requirement: Vencimiento de la vigencia del contrato con aviso anticipado

El sistema SHALL registrar la **vigencia desde** y **vigencia hasta** de la grilla de un cliente, y SHALL avisar **un mes antes** del vencimiento, porque ese es el tiempo que lleva llegar a un acuerdo nuevo. El aviso SHALL estar disponible en la pantalla de inicio del perfil; el envío por mail NO SHALL ser requisito.

#### Scenario: Contrato con vencimiento próximo

- **WHEN** la vigencia de la grilla de un cliente termina dentro de los próximos treinta días
- **THEN** el sistema lo informa como contrato a renegociar, con el cliente y la fecha

#### Scenario: Contrato vencido

- **WHEN** la vigencia de la grilla de un cliente ya terminó y no hay vigencia nueva cargada
- **THEN** el sistema lo informa, y las prestaciones que resuelven contra ese contrato quedan como pendientes de valorizar en lugar de tomar el valor vencido

### Requirement: Descarga del contrato en Excel

El sistema SHALL permitir descargar la grilla de valores de venta de un cliente en **Excel**, con la prestación, la zona cuando aplica, el importe sin IVA y la vigencia. Es el archivo que se usa para negociar con el cliente.

#### Scenario: Descarga de la grilla de un cliente

- **WHEN** el usuario descarga la grilla de un cliente
- **THEN** el sistema genera el archivo con todas las filas vigentes de ese cliente y sus importes sin IVA

## MODIFIED Requirements

### Requirement: Valor de venta por prestación y zona


El sistema SHALL registrar el **valor de venta** de una prestación con la clave **cliente + prestación + zona (opcional) + vigencia**. El **cliente es dimensión obligatoria**: los valores se pactan por cliente y dos clientes pueden tener importes distintos para la misma prestación.

La **zona es opcional**: un contrato puede tener valores zonificados —cuando el costo cambia por región— o un único valor sin zona. El sistema MUST admitir las dos formas en el mismo modelo, y MUST NOT exigir zona para poder cargar un valor.

Los valores SHALL cargarse **sin IVA**, porque así se pactan los contratos; el IVA se agrega al presupuestar y al facturar. El valor de venta SHALL estar separado del costo por convenio con el prestador: son dos números distintos, con dueños distintos.

La primera operación de la pantalla SHALL ser **elegir el cliente**, porque la grilla que se carga es la que se pactó con ese cliente.

> Reemplaza al requisito homónimo de `ap-costos-topeo-etapa1`. El alcance pasa a ser **Valor de venta por cliente, prestación y zona opcional**.

#### Scenario: Carga del valor de una prestación para un cliente

- **WHEN** un usuario habilitado elige un cliente y carga el valor de venta de una prestación con su vigencia
- **THEN** el sistema lo registra sin IVA, asociado a ese cliente y a esa prestación

#### Scenario: Dos clientes con valores distintos para la misma prestación

- **WHEN** dos clientes tienen valores pactados distintos para la misma prestación en la misma fecha
- **THEN** el sistema resuelve el valor de cada uno según su propio contrato, sin mezclarlos

#### Scenario: Valor zonificado

- **WHEN** el contrato de un cliente diferencia por zona
- **THEN** el sistema permite cargar un importe por zona para la misma prestación y resuelve por la zona que corresponda

#### Scenario: Valor sin zona

- **WHEN** el contrato de un cliente no diferencia por zona
- **THEN** el sistema permite cargar un único valor para la prestación, sin exigir zona, y lo aplica a cualquier zona

#### Scenario: Consulta filtrada de la grilla

- **WHEN** el usuario consulta la grilla de valores de venta
- **THEN** el sistema la devuelve filtrable y paginada, con el cliente, la prestación, la zona cuando aplica, el importe sin IVA, la vigencia y el estado de cada fila

### Requirement: Actualización masiva por porcentaje


El sistema SHALL permitir aplicar un **aumento por porcentaje** sobre la grilla de un cliente, que es la forma habitual de actualizar (típicamente por IPC acumulado). La actualización masiva SHALL admitir **excluir prestaciones puntuales** cuyo valor se negoció aparte.

Antes de confirmar, el sistema SHALL **previsualizar** cuántos valores se van a afectar y los importes resultantes. Cada valor afectado SHALL versionarse: se cierra la vigencia anterior y se activa la nueva, conservando el histórico.

El sistema SHALL permitir además la **carga o edición individual** de un valor, para el caso del ítem que quedó desfasado respecto del costo de mercado.

El **redondeo** SHALL estar disponible como opción y MUST NOT aplicarse por defecto: los redondeos se acumulan entre aumentos sucesivos, porque el aumento siguiente se calcula sobre el importe ya redondeado.

> Reemplaza al requisito homónimo de `ap-costos-topeo-etapa1`. El alcance pasa a ser **Actualización masiva por porcentaje con exclusiones**.

#### Scenario: Aumento sobre toda la grilla de un cliente

- **WHEN** un usuario habilitado aplica un porcentaje a la grilla de un cliente con una fecha de vigencia
- **THEN** el sistema previsualiza cuántos valores cambian y con qué importes, y al confirmar versiona cada uno conservando el histórico

#### Scenario: Aumento con una prestación excluida

- **WHEN** el usuario excluye una prestación del aumento masivo porque se negoció un importe distinto
- **THEN** el sistema aplica el porcentaje al resto y deja la excluida con su valor, sin versionarla

#### Scenario: Ajuste individual de un valor desfasado

- **WHEN** el usuario corrige el importe de una única prestación de un cliente
- **THEN** el sistema versiona solo ese valor, con su vigencia y su histórico

#### Scenario: Redondeo no aplicado por defecto

- **WHEN** se aplica un aumento sin pedir redondeo
- **THEN** el sistema conserva los decimales resultantes del cálculo

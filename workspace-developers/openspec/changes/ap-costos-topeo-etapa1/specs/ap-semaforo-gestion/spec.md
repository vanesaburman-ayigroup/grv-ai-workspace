## ADDED Requirements

### Requirement: Semáforo de cinco niveles sobre la proyección

El sistema SHALL calcular un **semáforo de cinco niveles** según el porcentaje que la **proyección** representa sobre la suma asegurada del siniestro AP:

| Nivel | Rango |
|---|---|
| Bajo | menor a 40% |
| Medio | 40% a 70% |
| Alto | 70% a 90% |
| Muy alto | 90% a 100% |
| Excedido | mayor a 100% |

Los cortes de **Bajo→Medio (40%)** y **Medio→Alto (70%)** SHALL ser parametrizables sin necesidad de despliegue. Los cortes de **90%** y **100%** SHALL ser fijos por regla de negocio.

#### Scenario: Siniestro en nivel muy alto

- **WHEN** la proyección de un siniestro AP alcanza el 94% de la suma asegurada
- **THEN** el sistema lo clasifica en nivel `Muy alto` y muestra la alerta de no autorizar más prestaciones

#### Scenario: Un único criterio de escala

- **WHEN** el sistema evalúa el nivel de un siniestro y también decide si corresponde avisar
- **THEN** ambas cosas se resuelven con los mismos cortes de la escala de niveles, sin una segunda escala de porcentajes en paralelo

#### Scenario: Siniestro excedido

- **WHEN** la proyección supera el 100% de la suma asegurada
- **THEN** el sistema lo clasifica en nivel `Excedido`

#### Scenario: Cambio de umbral intermedio sin despliegue

- **WHEN** un usuario habilitado modifica el umbral intermedio de 70% a 65% en la parametrización
- **THEN** el semáforo recalcula los niveles con el nuevo corte sin requerir un despliegue de la aplicación

#### Scenario: Intento de mover un corte fijo

- **WHEN** se intenta parametrizar el corte de 90% o el de 100%
- **THEN** el sistema no lo permite, porque son cortes fijos de negocio

### Requirement: Semáforo en el detalle del siniestro

El sistema SHALL mostrar el semáforo del siniestro dentro del detalle de la denuncia, en una sección de costos y topeo que exponga las tres capas de consumo (Facturado, Devengado, Estimado) hasta la proyección, junto con el saldo disponible y el monto pendiente de facturar.

#### Scenario: Visualización de las tres capas

- **WHEN** un usuario de gestión abre la sección de costos y topeo de un siniestro AP
- **THEN** el sistema muestra las tres capas escalonadas con sus montos, la proyección total, las marcas de 90% y del tope, y el nivel del semáforo

#### Scenario: Tope a la vista mientras se navega el siniestro

- **WHEN** el usuario navega a otras secciones del detalle del siniestro (por ejemplo turnos o cirugía)
- **THEN** el sistema mantiene visible en la cabecera un resumen del consumo contra el tope

### Requirement: Vista agregada de cartera

El sistema SHALL presentar una vista agregada de la cartera AP que muestre la **distribución de casos por nivel** de semáforo y el **monto en riesgo** (niveles Muy alto y Excedido), sin listar la totalidad de los casos. Los contadores por nivel SHALL permitir navegar a la grilla filtrada por ese nivel.

#### Scenario: Consulta de la distribución de cartera

- **WHEN** un usuario de gestión abre la vista agregada de AP
- **THEN** el sistema muestra la cantidad de siniestros por nivel y el monto en riesgo, calculado por agregación

#### Scenario: Navegación desde un contador

- **WHEN** el usuario hace clic en el contador del nivel Muy alto
- **THEN** el sistema abre la grilla de siniestros filtrada por ese nivel

#### Scenario: Grilla filtrable por nivel

- **WHEN** el usuario filtra la grilla de pacientes por nivel de gasto
- **THEN** el sistema lista los siniestros de ese nivel con su consumo, su suma asegurada con IVA y la marca de caso quirúrgico

### Requirement: Aviso al cambiar de nivel

El sistema SHALL avisar cuando un siniestro **cambia de nivel hacia arriba** en la escala del semáforo, usando los mismos cortes que definen los niveles (no una escala paralela de porcentajes). Los avisos relevantes para gestión son el ingreso a **Alto**, a **Muy alto** y a **Excedido**. Cada aviso MUST registrarse una sola vez por nivel y por siniestro, para no repetir la misma alerta en cada consulta, y cada nivel SHALL poder tener el aviso habilitado o deshabilitado sin necesidad de un despliegue.

#### Scenario: Siniestro que ingresa a nivel Muy alto

- **WHEN** el consumo de un siniestro AP cruza el 90% de la suma asegurada y pasa a nivel Muy alto
- **THEN** el sistema registra el aviso de ese nivel y lo señala en la vista de gestión, para poder avisar al cliente

#### Scenario: Aviso ya registrado

- **WHEN** un siniestro que ya generó el aviso de un nivel vuelve a consultarse sin haber cambiado de nivel
- **THEN** el sistema no genera un aviso nuevo, y muestra que ese nivel ya fue alcanzado

#### Scenario: Siniestro que salta dos niveles de una vez

- **WHEN** el consumo de un siniestro pasa de nivel Medio a Excedido en una sola actualización (por ejemplo al impactar una cirugía)
- **THEN** el sistema registra el aviso del nivel alcanzado y no omite la señal por no haber pasado por los niveles intermedios

#### Scenario: Habilitar o deshabilitar el aviso de un nivel

- **WHEN** un usuario habilitado deshabilita el aviso del nivel Alto para reducir ruido
- **THEN** el sistema deja de generar ese aviso y mantiene los de Muy alto y Excedido, sin requerir un despliegue

### Requirement: Aviso sin bloqueo, con bloqueo activable por parámetro

Cuando la proyección de un siniestro supera la suma asegurada, el sistema SHALL **avisar** y dejar la decisión de autorizar en la persona. El **bloqueo** de nuevas autorizaciones MUST estar implementado pero **desactivado por defecto**, y SHALL poder activarse mediante un **parámetro en base de datos**, sin requerir un despliegue.

Cuando el bloqueo está activo, el sistema SHALL impedir la autorización e informar el motivo con el consumo y el tope, y MUST permitir el override con justificación registrada (mismo criterio que el topeo ya existente en el sistema).

#### Scenario: Comportamiento por defecto (solo avisa)

- **WHEN** la proyección de un siniestro supera el tope y el parámetro de bloqueo está desactivado
- **THEN** el sistema muestra la alerta de exceso pero permite continuar autorizando

#### Scenario: Bloqueo activado por parámetro

- **WHEN** un usuario habilitado activa el parámetro de bloqueo y luego se intenta autorizar una prestación para un siniestro cuya proyección excede el tope
- **THEN** el sistema rechaza la autorización informando el consumo, el tope y el excedente

#### Scenario: Override con justificación cuando el bloqueo está activo

- **WHEN** el bloqueo está activo y el usuario justifica la autorización por excepción
- **THEN** el sistema permite la operación y registra la justificación con el usuario y la fecha, quedando trazable

#### Scenario: Activación sin despliegue

- **WHEN** negocio decide pasar de "solo avisar" a "bloquear"
- **THEN** el cambio se aplica modificando el parámetro en base de datos, sin necesidad de un despliegue de la aplicación

### Requirement: Carga de valores en las vías de medicación y laboratorio

La interfaz SHALL permitir a gestión **cargar los valores** de medicación (precio y descripción del medicamento) y de laboratorio (precio de la unidad para el cálculo por multiplicador), e identificar los ítems que quedan **pendientes de valorizar**.

#### Scenario: Carga del valor de un medicamento desde el detalle del siniestro

- **WHEN** un usuario de gestión abre la sección de medicación de un siniestro y carga el precio y la descripción de un medicamento
- **THEN** el sistema incorpora el valor al consumo y muestra el ítem valorizado con su descripción

#### Scenario: Ítems pendientes de valorizar

- **WHEN** un siniestro tiene ítems de medicación o laboratorio sin precio cargado
- **THEN** la interfaz los muestra destacados como pendientes y aclara que el consumo mostrado está incompleto hasta completarlos

#### Scenario: Consulta del saldo antes de una cirugía

- **WHEN** un usuario de gestión necesita responder al cliente si una cirugía presupuestada entra en el tope
- **THEN** la interfaz permite ingresar el monto del presupuesto y muestra si entra en el saldo disponible, el consumo resultante y el remanente

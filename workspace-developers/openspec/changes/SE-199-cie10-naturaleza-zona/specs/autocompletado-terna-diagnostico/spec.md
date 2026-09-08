## ADDED Requirements

### Requirement: El orden canónico de carga es el diagnóstico primero

En las pantallas donde se carga la terna, el **diagnóstico CIE-10 SHALL cargarse primero**, y de él SHALL derivarse la naturaleza de la lesión y la zona corporal.

Este orden SHALL ser el mismo en la pestaña General (CEM) y en la pestaña de Auditoría Médica.

#### Scenario: Carga del diagnóstico en la pestaña General

- **WHEN** el gestor elige un diagnóstico CIE-10 que tiene relación configurada
- **THEN** se completan los ejes que la relación determina, y los que no quedan vacíos

#### Scenario: Se invierte el gate de habilitación en Auditoría Médica

- **WHEN** el auditor médico abre la pantalla de datos generales
- **THEN** el combo de diagnóstico CIE-10 está habilitado sin requerir que naturaleza y zona tengan valor previo

> Hoy ocurre lo contrario: el combo de CIE-10 está `disabled` hasta que naturaleza y zona estén cargadas. Ese gate se invierte. Es un cambio en el flujo de trabajo del auditor, y requiere definir qué ocurre con las denuncias que ya tienen los tres campos cargados.

### Requirement: El autocompletado actúa eje por eje

El autocompletado SHALL evaluar cada eje de forma independiente:

- Eje **con valor** en la relación: el campo se completa con ese valor.
- Eje **sin valor** (`NULL`): el campo no se toca y lo carga la persona.

No SHALL existir un comportamiento intermedio de precarga de baja confianza.

#### Scenario: Un solo eje autocompletado

- **WHEN** se elige un diagnóstico cuya relación fija la zona pero no interviene en la naturaleza
- **THEN** se completa la zona y el campo de naturaleza queda vacío y editable

#### Scenario: Diagnóstico sin relación configurada

- **WHEN** se elige un diagnóstico que no tiene relación en el catálogo
- **THEN** ningún campo se autocompleta, y los tres se cargan como hoy

#### Scenario: Cambio de diagnóstico después de haber autocompletado

- **WHEN** se cambia el diagnóstico por otro con una relación distinta
- **THEN** los ejes que la nueva relación determina se recalculan con sus valores

### Requirement: El valor autocompletado se puede cambiar

El campo que el sistema completa SHALL quedar editable. El sistema NO SHALL bloquear el valor ni impedir que la persona lo reemplace.

Definición del equipo de desarrollo, 21/08/2026. Pendiente de confirmación de Registros.

#### Scenario: La persona cambia un valor autocompletado

- **WHEN** el sistema completó la zona a partir del diagnóstico y la persona elige otra zona
- **THEN** se conserva el valor que eligió la persona

#### Scenario: El valor cambiado sobrevive al guardado

- **WHEN** se guarda la denuncia con un valor distinto al que propuso el sistema
- **THEN** se persiste el valor de la persona, sin volver a aplicar el de la relación

### Requirement: El eje que queda vacío se marca como pendiente

Cuando la relación completa un eje y el otro no es determinable, el campo vacío SHALL marcarse visiblemente como **pendiente de completar**, de modo que no se confunda con un campo ya resuelto.

Requisito agregado por el equipo de desarrollo el 21/08/2026, al adoptar el autocompletado de un solo eje. Pendiente de confirmación de Registros.

#### Scenario: Zona completada, naturaleza pendiente

- **WHEN** se elige `S93.4` (esguinces y torceduras del tobillo), que determina la zona pero no la naturaleza
- **THEN** la zona queda completada y el campo de naturaleza se muestra marcado como pendiente

#### Scenario: La marca desaparece al completar el campo

- **WHEN** la persona carga el valor del eje marcado como pendiente
- **THEN** la marca de pendiente deja de mostrarse

#### Scenario: Sin relación cargada no se marca nada

- **WHEN** el diagnóstico no tiene relación en el catálogo y los dos campos quedan vacíos
- **THEN** no se marca ningún campo como pendiente: la pantalla se comporta como hoy

### Requirement: Lo que no se puede determinar no se sugiere

Cuando el diagnóstico no tiene relación cargada para un eje, el sistema NO SHALL sugerir ningún valor para ese eje: el campo SHALL quedar vacío y a cargo de la persona.

El sistema NO SHALL ofrecer un valor de baja confianza como sugerencia. No sugerir cuesta que alguien cargue el campo a mano; sugerir mal introduce un dato inventado en un registro que viaja a la SRT.

Los códigos de patologías trazadoras quedan cubiertos por esta regla, no por una excepción aparte: en esas denuncias el CIE-10 es una etiqueta administrativa que no describe la lesión, y naturaleza y zona son el único registro de la lesión real.

#### Scenario: Denuncia con trazadora Politraumatismo grave

- **WHEN** la denuncia tiene la trazadora «Politraumatismo grave», que fija el diagnóstico `T06.8`
- **THEN** naturaleza y zona quedan vacías y editables, sin ningún valor sugerido por el sistema

#### Scenario: El caso agravado por la restricción de edición

- **WHEN** el diagnóstico de la denuncia además tiene `edicion_bloqueada = 1`, de modo que el auditor médico no puede cambiarlo
- **THEN** el sistema igualmente no autocompleta naturaleza ni zona, para no dejar un dato incorrecto que nadie pueda corregir

### Requirement: El autocompletado convive con las restricciones de edición ya existentes

El autocompletado NO SHALL sobrescribir ni eludir las condiciones que ya restringen estos campos.

#### Scenario: Campos deshabilitados por el contexto de la denuncia

- **WHEN** los campos están deshabilitados por `disableEdition` o por el contexto de diferencias de reingreso
- **THEN** el autocompletado no los modifica

#### Scenario: Permisos del auditor médico

- **WHEN** el usuario no tiene el permiso de auditor médico en la pantalla de Auditoría Médica
- **THEN** las reglas de edición vigentes se mantienen sin cambios

### Requirement: Alcance — las superficies donde la terna está completa

El autocompletado SHALL aplicarse en toda pantalla donde el diagnóstico CIE-10 convive con la naturaleza de la lesión y la zona corporal. El alcance NO SHALL definirse por número de diagnóstico sino por la presencia de los tres campos (`design.md` D-6 y D-12).

Las superficies alcanzadas son:

| Superficie | Diagnósticos |
|---|---|
| CEM · pestaña General | 1er diagnóstico |
| CEM · pestaña General | 2º y 3er diagnóstico |
| Auditoría Médica | 2º y 3er diagnóstico |
| Mesa de carga · Siniestralidad › Editar siniestro | los tres bloques |

Una pantalla que **no tiene selector de CIE-10** queda fuera: no hay evento del cual derivar la terna.

#### Scenario: Segundo y tercer diagnóstico de la pestaña General

- **WHEN** se elige el diagnóstico del segundo o del tercer bloque en la pestaña General
- **THEN** ese bloque autocompleta su propia terna, de forma independiente de los otros dos

#### Scenario: Mesa de carga, los tres bloques

- **WHEN** se edita un siniestro desde Mesa de carga y se elige el diagnóstico de cualquiera de los tres bloques
- **THEN** ese bloque autocompleta los ejes que la relación determina

#### Scenario: Auditoría Médica, gated por módulo

- **WHEN** el usuario no tiene el módulo de auditoría médica ni pertenece al área correspondiente
- **THEN** la pantalla se comporta como hoy y el autocompletado no interviene

#### Scenario: Pantalla sin selector de CIE-10

- **WHEN** la pantalla sólo arrastra el código del diagnóstico para armar el request, sin ofrecer dónde elegirlo
- **THEN** no hay autocompletado: no existe el evento que lo dispararía

### Requirement: Al guardar se confirma lo que completó el sistema

Cuando el sistema completó la naturaleza y/o la zona y la persona no cambió ese valor, al guardar el sistema SHALL mostrar los ejes que completó y SHALL pedir confirmación explícita antes de persistir.

Un eje que la persona editó después del autocompletado NO SHALL reportarse: el sistema compara el valor actual del campo contra el que había escrito. La edición NO SHALL interceptarse ni restringirse de ninguna otra forma.

Fundamento: al abrir una denuncia que ya tiene el CIE-10 cargado el autocompletado se dispara solo, sin que nadie lo haya pedido, y esos valores viajan a la SRT. Ver `design.md` D-13.

#### Scenario: El sistema completó los dos ejes y nadie los tocó

- **WHEN** se guarda una denuncia en la que el sistema completó naturaleza y zona
- **THEN** antes de persistir se listan los dos valores y se pide confirmación

#### Scenario: La persona editó uno de los ejes autocompletados

- **WHEN** el sistema completó la zona y la persona la reemplazó por otra antes de guardar
- **THEN** esa zona no se lista en la confirmación: ya fue mirada por una persona

#### Scenario: El sistema no completó nada

- **WHEN** el diagnóstico no tiene relación cargada y los dos campos los cargó una persona
- **THEN** no se pide ninguna confirmación y el guardado se comporta como hoy

#### Scenario: La marca de autocompletado no viaja al backend

- **WHEN** se guarda la denuncia
- **THEN** el request enviado al servicio no incluye la marca de autocompletado: es estado de la pantalla, no un dato de la denuncia

### Requirement: El valor autocompletado persiste tal como se mostró

El valor que el sistema completa SHALL persistirse con el mismo valor que la pantalla mostró. El sistema NO SHALL escribir en el campo un texto que la pantalla no pueda resolver contra su propio listado.

Fundamento: el identificador que se guarda se deriva del listado local buscando por texto, y un texto que no coincide carácter por carácter deja el identificador anterior — la pantalla mostraba lo nuevo y guardaba lo viejo. Ver `design.md` D-18.

#### Scenario: El valor completado sobrevive al guardado

- **WHEN** el sistema completa la zona y se guarda la denuncia sin tocar ese campo
- **THEN** al reabrir la denuncia la zona es la que el sistema había completado, no la anterior

### Requirement: El autocompletado no pisa lo que la persona está escribiendo

Cuando la consulta de la relación está en curso y la persona edita alguno de los campos, la respuesta NO SHALL sobrescribir lo que la persona escribió. Una respuesta que ya no corresponde al diagnóstico vigente SHALL descartarse.

Ver `design.md` D-17.

#### Scenario: Escritura manual mientras viaja la consulta

- **WHEN** la persona elige el diagnóstico y escribe la naturaleza a mano antes de que llegue la respuesta
- **THEN** se conserva lo que escribió la persona

#### Scenario: Respuesta que llega tarde

- **WHEN** llega la respuesta de un diagnóstico que ya fue reemplazado por otro
- **THEN** esa respuesta se descarta y no modifica ningún campo

### Requirement: Al cambiar el diagnóstico se recalcula la terna

Cuando se modifica el diagnóstico CIE-10 de una denuncia ya cargada, el sistema SHALL recalcular la terna, de modo que la naturaleza y la zona describan el código vigente y no el anterior.

El recálculo SHALL actualizar **únicamente el eje que la relación determina**. El eje que la relación no determina SHALL conservar su valor: NO SHALL vaciarse, porque dejaría incompleto un dato que la SRT exige.

El recálculo SHALL resolverse en el servicio que modifica el diagnóstico, no en cada pantalla, de modo que aplique por igual a todos los lugares desde los que se cambia el código. Ver `design.md` D-14 y D-15.

#### Scenario: El diagnóstico cambia y la relación determina los dos ejes

- **WHEN** una denuncia con contusión de tórax pasa a un diagnóstico de contusión de rodilla, cuya relación determina naturaleza y zona
- **THEN** la naturaleza y la zona quedan describiendo el diagnóstico nuevo

#### Scenario: El diagnóstico cambia y la relación determina un solo eje

- **WHEN** el diagnóstico nuevo determina la zona pero no la naturaleza
- **THEN** se actualiza la zona y la naturaleza cargada se conserva

#### Scenario: El diagnóstico nuevo no tiene relación

- **WHEN** el diagnóstico nuevo no está en el catálogo, es una patología trazadora, o el autocompletado está apagado
- **THEN** el recálculo se resuelve como «sin relación» y no modifica ningún campo

### Requirement: La pantalla puede elegir si se recalcula

El pedido de modificación del diagnóstico SHALL admitir una indicación de si la terna se recalcula:

| Indicación | Comportamiento |
|---|---|
| recalcular | se actualizan los ejes que la relación determina |
| no recalcular | se conserva la terna cargada |
| **ausente** | **equivale a NO recalcular** — no se toca nada |

El default SHALL ser recalcular: quien no envía la indicación es una pantalla que no ofrece la elección, y ahí lo correcto es que la terna describa el código vigente. Ver `design.md` D-16.

Donde la pantalla ofrece la elección, SHALL mostrar qué corresponde según el diagnóstico nuevo, con la opción de recalcular preseleccionada, y SHALL ofrecerla **sólo si el catálogo determina algo** para ese código.

#### Scenario: La pantalla pide no recalcular

- **WHEN** se cambia el diagnóstico indicando que no se recalcule
- **THEN** la naturaleza y la zona cargadas se conservan sin cambios

#### Scenario: La pantalla no manda la indicación

- **WHEN** se cambia el diagnóstico sin indicar nada
- **THEN** la terna se recalcula, igual que si se hubiera pedido explícitamente

#### Scenario: El diagnóstico nuevo no determina nada

- **WHEN** se cambia a un diagnóstico sin relación cargada
- **THEN** la pantalla no ofrece la elección, porque no hay nada que recalcular

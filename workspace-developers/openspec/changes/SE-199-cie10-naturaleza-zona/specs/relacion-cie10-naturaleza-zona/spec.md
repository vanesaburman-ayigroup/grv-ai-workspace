## ADDED Requirements

### Requirement: Catálogo de relaciones determinísticas, con ejes independientes

El sistema SHALL mantener un catálogo de relaciones entre un código CIE-10, una naturaleza de la lesión y una zona corporal. Cada eje SHALL ser independiente del otro: una relación SHALL poder determinar sólo la zona, sólo la naturaleza, o ambas.

Un eje sin valor (`NULL`) SHALL significar «no determinable», y el sistema no SHALL intervenir sobre ese campo. No SHALL existir un estado intermedio de valor sugerido: un eje está determinado o está vacío.

Toda relación SHALL tener valor en al menos uno de los dos ejes.

#### Scenario: Relación que determina los dos ejes

- **WHEN** se consulta la relación de `S80.0` (contusión de la rodilla)
- **THEN** el sistema devuelve naturaleza «Contusiones» y zona «Rodilla»

#### Scenario: Relación que determina sólo la zona

- **WHEN** se consulta la relación de `S81.8` (herida de otras partes de la pierna), cuya naturaleza admite variantes legítimas
- **THEN** el sistema devuelve zona «Pierna» y el eje naturaleza vacío

#### Scenario: Dorsopatía — zona determinable, naturaleza no

- **WHEN** se consulta la relación de `M54.4` (lumbalgia con ciática)
- **THEN** el sistema devuelve zona «Región lumbosacra» y el eje naturaleza vacío

#### Scenario: Relación sin ningún eje determinado

- **WHEN** se intenta dar de alta una relación con naturaleza y zona ambas vacías
- **THEN** el alta se rechaza: esa relación no aporta nada y equivale a no tener fila

#### Scenario: Código sin relación configurada

- **WHEN** se consulta la relación de un código que no está en el catálogo
- **THEN** el sistema responde que no hay relación, y no inventa un valor derivado

### Requirement: La fuente de verdad del catálogo de CIE-10 es `diagnosticos_cie10`

Las relaciones SHALL referenciar códigos de `diagnosticos_cie10`. El sistema NO SHALL usar `certezas_cie10` como catálogo de diagnósticos: su clave primaria es un identificador secuencial, el código real viene embebido en el texto de la descripción, y sólo 241 de sus 2.572 filas tienen código SRT asignado.

#### Scenario: Integridad referencial del código

- **WHEN** se intenta dar de alta una relación con un código que no existe en `diagnosticos_cie10`
- **THEN** el alta se rechaza

### Requirement: El catálogo se puebla con valores validados, no con la moda estadística

Los valores del catálogo SHALL provenir de una validación explícita del sector Registros. El sistema NO SHALL derivar relaciones automáticamente del valor más frecuente en los datos históricos.

Fundamento: el eje naturaleza está contaminado en el histórico por un valor por defecto («Contusiones» es la moda en nueve de los diez grupos del cuarto carácter, incluso en códigos que describen fracturas, heridas y esguinces). Poblar el catálogo con la moda cristalizaría ese error y le daría categoría de regla.

#### Scenario: Código con conflicto entre su descripción y la carga histórica

- **WHEN** un código cuyo texto describe un tipo de lesión (por ejemplo `S22.4`, «Fracturas múltiples de costillas») tiene como naturaleza más frecuente otra distinta («Contusiones», 100% de los casos)
- **THEN** ese código NO recibe naturaleza en el catálogo hasta que Registros defina el valor correcto, y el eje queda vacío

> El conflicto es **del eje**, no de la fila: la zona de esos códigos sí se carga cuando es determinable, porque los ejes son independientes. Ver `design.md` D-11.

### Requirement: Sólo se carga lo que se puede determinar

El catálogo SHALL contener una relación **únicamente** cuando la naturaleza o la zona correspondiente a ese código son determinables. Un eje que no se puede determinar SHALL quedar en `NULL`; un código cuyos dos ejes son indeterminables SHALL quedar **sin fila** en el catálogo.

El sistema NO SHALL cargar un valor de baja confianza con el único propósito de tener algo que ofrecer. Los códigos de concentración media (entre el 70% y el 89% en el análisis de evidencia) NO SHALL cargarse: son los que producen el dato plausible pero equivocado que nadie revisa.

#### Scenario: Código cuyos dos ejes son indeterminables

- **WHEN** un código no permite determinar ni la naturaleza ni la zona
- **THEN** no se le carga ninguna relación, y el autocompletado no interviene sobre esa denuncia

#### Scenario: Un mismo código que sirve a lesiones incompatibles

- **WHEN** se evalúa `S05.3`, configurado para las trazadoras «Rotura/estallido de vísceras» y «Castración o emasculación traumática»
- **THEN** se constata que no existe una naturaleza ni una zona derivables del código, y no se le carga relación

> Los 31 códigos configurados en `config_trazadora_cie10` caen bajo esta regla: para una denuncia con patología trazadora, el CIE-10 es una etiqueta administrativa del listado ROAM y no describe la lesión — el área médica decidió mantener un campo único con las dos semánticas (GRV-2207, 04/08/2026). En consecuencia, naturaleza y zona son el único lugar donde queda registrada la lesión real. Ver `design.md` D-2 para el fundamento completo, incluida la nota sobre los códigos de trazadora que sí son anatómicamente específicos.

### Requirement: Trazabilidad del catálogo

Cada relación SHALL registrar cuándo fue creada, cuándo modificada por última vez, y quién la modificó. El catálogo SHALL permitir desactivar una relación sin borrarla.

#### Scenario: Desactivación de una relación

- **WHEN** una relación se marca como inactiva
- **THEN** deja de aplicarse en el autocompletado, y su registro histórico se conserva

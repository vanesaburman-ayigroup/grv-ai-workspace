## ADDED Requirements

### Requirement: Búsqueda general resuelta en backend sobre el universo completo

El sistema SHALL resolver la búsqueda general de la pantalla de auditoría de traslados en el backend, aplicando el término sobre el universo completo ya acotado por los filtros estructurales (período, estado, prestador, etiqueta, pestaña), y NO sobre las filas de la página visible. El front NO SHALL filtrar resultados en memoria.

#### Scenario: La búsqueda alcanza filas que no están en la página visible
- **WHEN** el usuario tiene cargada la página 1 (20 filas) y escribe un término que coincide con una fila que está en la página 5
- **THEN** el backend devuelve esa fila y el total recalculado, sin que el usuario haya tenido que paginar ni filtrar previamente

#### Scenario: No se exige filtrado previo
- **WHEN** el usuario abre la pantalla y escribe directamente en el buscador sin haber aplicado ningún filtro estructural
- **THEN** el sistema busca sobre el universo del período por defecto y devuelve los resultados con su total exacto

#### Scenario: El total refleja la búsqueda
- **WHEN** se aplica un término de búsqueda que coincide con 37 filas del universo
- **THEN** el `total_records` devuelto es 37 y la paginación se calcula sobre 37, no sobre el total sin búsqueda

#### Scenario: Término vacío equivale a no buscar
- **WHEN** el término de búsqueda es nulo, vacío o solo espacios
- **THEN** el sistema devuelve el universo sin filtrar por búsqueda (idéntico al comportamiento sin buscador)

### Requirement: El filtro de búsqueda solo cubre los campos visibles de cada pestaña

El sistema SHALL buscar únicamente sobre las columnas visibles en pantalla de la pestaña activa, y NO sobre campos del detalle/drawer. El conjunto de campos buscables SHALL coincidir exactamente con el conjunto de campos resaltados en esa pestaña.

#### Scenario: No Auditados busca sobre sus columnas visibles
- **WHEN** la pestaña activa es "No Auditados" (`auditada=0`) y se busca un término
- **THEN** el filtro evalúa nro traslado, fecha/hora, denuncia, paciente, dni, proveedor ida/vuelta, direcciones y estados; y NO evalúa factura ni monto (no visibles en esa pestaña)

#### Scenario: Auditados busca sobre factura y monto
- **WHEN** la pestaña activa es "Auditados" (`auditada=1`) y se busca un número de factura o un monto
- **THEN** el filtro evalúa nro traslado, fecha, denuncia, paciente, dni, factura ida/vuelta, monto ida/vuelta y responsable de auditoría

#### Scenario: Desimputados busca sobre factura, monto y desimputación
- **WHEN** la pestaña activa es "Desimputados" y se busca un término
- **THEN** el filtro evalúa denuncia, paciente, dni, factura ida/vuelta, monto ida/vuelta y **responsable y fecha de desimputación** (columnas visibles de esa pestaña); y NO evalúa nro traslado (no visible en esa pestaña)

#### Scenario: Campos del drawer no participan de la búsqueda
- **WHEN** un término coincide solo con un dato que aparece exclusivamente en el detalle/drawer (p. ej. observaciones internas, localidad de origen del tramo)
- **THEN** la fila NO es devuelta por la búsqueda general

### Requirement: Resaltado de coincidencias en pantalla

El sistema SHALL resaltar (marca amarilla) las ocurrencias del término dentro de los valores visibles de las columnas de la pestaña activa. El resaltado SHALL ser case-insensitive y NO SHALL romperse ante caracteres especiales del término.

#### Scenario: Marca amarilla sobre la coincidencia
- **WHEN** el resultado contiene el término en un campo visible (p. ej. la denuncia "CH484768")
- **THEN** la subcadena coincidente se muestra con fondo amarillo dentro de la celda, conservando el resto del texto sin resaltar

#### Scenario: Caracteres especiales en el término
- **WHEN** el término contiene caracteres con significado en expresiones regulares (p. ej. `(`, `.`, `*`)
- **THEN** el resaltado los trata como texto literal y no produce error

#### Scenario: Sin término no hay resaltado
- **WHEN** no hay término activo
- **THEN** las celdas se muestran sin ninguna marca

#### Scenario: Se resalta la fecha/hora del traslado
- **WHEN** el término coincide con la fecha/hora visible de la fila (pestaña No Auditados o Auditados)
- **THEN** la coincidencia se resalta dentro de la columna de fecha/hora

#### Scenario: Se resalta el monto
- **WHEN** el término coincide con el monto visible de la fila (pestaña Auditados o Desimputados)
- **THEN** la coincidencia se resalta dentro de la celda de monto, conservando el formato del importe

### Requirement: El término de búsqueda se conserva al cambiar de pestaña

El sistema SHALL conservar el término de búsqueda general al cambiar de pestaña, manteniendo el campo del buscador y el filtro aplicado siempre alineados. El sistema NO SHALL dejar el campo vacío mientras el filtro de búsqueda sigue activo por detrás.

#### Scenario: El término persiste al cambiar de pestaña
- **WHEN** el usuario tiene un término aplicado en una pestaña y cambia a otra pestaña
- **THEN** el campo del buscador sigue mostrando el mismo término y el listado de la nueva pestaña aparece filtrado y resaltado por ese término

#### Scenario: Campo y filtro siempre alineados
- **WHEN** el campo del buscador muestra un término
- **THEN** ese término es el que está efectivamente aplicado al listado (nunca un campo vacío con filtro activo, ni un texto sin aplicar)

### Requirement: Disposición del buscador y de los controles de filtro

El sistema SHALL ubicar el buscador general en la misma zona inferior del bloque de filtros que los controles "Limpiar filtros" y "Aplicar filtros", de modo que la acción de aplicar filtros abarque también la búsqueda escrita.

#### Scenario: Aplicar filtros ejecuta también la búsqueda
- **WHEN** el usuario escribe un término en el buscador general y presiona "Aplicar filtros"
- **THEN** la búsqueda se ejecuta junto con los demás filtros estructurales

#### Scenario: Limpiar filtros limpia también el término
- **WHEN** el usuario presiona "Limpiar filtros"
- **THEN** se limpian tanto los filtros estructurales como el término del buscador general

### Requirement: Búsqueda insensible a mayúsculas y acentos

El sistema SHALL resolver la búsqueda de forma insensible a mayúsculas/minúsculas y a acentos, tanto en el filtro de backend como en el resaltado del front, de modo que el resultado y la marca coincidan.

#### Scenario: Coincidencia sin importar mayúsculas
- **WHEN** el usuario busca "perez" y existe el paciente "PEREZ"
- **THEN** la fila es devuelta y resaltada

#### Scenario: Coincidencia sin importar acentos
- **WHEN** el usuario busca "perez" (sin tilde) y existe el paciente "Pérez" (con tilde)
- **THEN** la fila es devuelta y la coincidencia se resalta sobre el texto original "Pérez"

### Requirement: La búsqueda se aplica por acción explícita, consistente con el resto de los filtros

Cuando la pantalla tiene un control explícito de aplicación de filtros (botón "Filtrar"), el sistema SHALL aplicar el término de búsqueda general al presionar ese control (o al confirmar con Enter en el campo), y NO SHALL auto-disparar la búsqueda mientras el usuario tipea. El patrón reutilizable SHALL ofrecer, además, un modo con retardo (debounce amplio) para pantallas que NO tengan control explícito de aplicación.

#### Scenario: El término viaja con el submit de filtros
- **WHEN** la pantalla tiene botón "Filtrar", el usuario escribe un término y presiona "Filtrar" (o Enter)
- **THEN** la búsqueda se ejecuta una sola vez con `offset` reseteado a 0, igual que el resto de los filtros estructurales

#### Scenario: No se dispara búsqueda mientras se tipea
- **WHEN** la pantalla tiene botón "Filtrar" y el usuario está escribiendo el término sin confirmar
- **THEN** no se realiza ninguna petición al backend hasta la acción explícita

#### Scenario: Modo debounce amplio como alternativa transportable
- **WHEN** el patrón se reutiliza en una pantalla sin botón de aplicar filtros
- **THEN** la búsqueda puede dispararse con un retardo amplio configurable tras dejar de tipear

### Requirement: Sin parpadeo de la tabla durante la carga

El sistema SHALL conservar las filas previas mostrando el indicador de carga mientras llega la nueva respuesta, sin vaciar la tabla.

#### Scenario: No hay flash de "sin resultados" durante la carga
- **WHEN** una búsqueda está en curso (`isFetching=true`)
- **THEN** la tabla mantiene las filas anteriores y muestra su overlay de carga, sin mostrar el mensaje de tabla vacía

### Requirement: Estrategia de búsqueda transportable detrás de una interfaz

El sistema SHALL exponer la búsqueda detrás de una interfaz `TrasladosSearchProvider` (patrón Strategy) seleccionable por configuración, de modo que el controller y el front dependan del contrato y no de la implementación. El patrón (campo en el request + provider + hook `useBusquedaBackend` + componente `Highlight`) SHALL ser reutilizable en otras pantallas cambiando el endpoint y el mapeo de campos visibles.

#### Scenario: Cambiar la implementación sin tocar capas superiores
- **WHEN** se selecciona otra implementación del provider por configuración (`traslados.search.provider`)
- **THEN** el controller, el endpoint y el front no requieren cambios

#### Scenario: Agregar una columna nueva a la pantalla
- **WHEN** se agrega una columna visible a una pestaña
- **THEN** habilitar su búsqueda requiere agregar una línea en la rama de esa pestaña del SP y un `<Highlight>` en esa columna, sin otros cambios estructurales

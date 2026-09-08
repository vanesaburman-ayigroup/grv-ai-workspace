## ADDED Requirements

### Requirement: Perfil de gestor comercial de AP

El sistema SHALL contar con un perfil de **gestor comercial de Accidentes Personales** en `cs.perfiles_sas`, creado como copia exacta de los permisos del perfil `analista_accidentes_personales` (id 22), sobre el módulo 1 (tramitadores). El alta MUST realizarse por script SQL idempotente con transacción explícita y verificaciones previa y posterior, de modo que una segunda ejecución no genere duplicados.

#### Scenario: Alta del perfil comercial cuando no existe

- **WHEN** se ejecuta el script de alta y no existe un perfil de gestor comercial de AP activo
- **THEN** el sistema crea la fila en `perfiles_sas` (módulo 1, `activo=1`) y replica en `perfiles_permisos_sas` los mismos permisos activos que tiene `analista_accidentes_personales` (13 `crear_turnos_analista_quirurgico` y 18 `crear_turnos_laboratorio`)

#### Scenario: Reejecución del script (idempotencia)

- **WHEN** se ejecuta el script de alta una segunda vez y el perfil ya existe activo
- **THEN** el sistema no inserta filas nuevas ni duplica vínculos de permisos, y la verificación posterior informa que el perfil ya estaba configurado

#### Scenario: Paridad de permisos con el analista

- **WHEN** se comparan los permisos activos del gestor comercial contra los de `analista_accidentes_personales`
- **THEN** ambos conjuntos MUST ser idénticos en cantidad y en `id_permiso`

### Requirement: Separación entre perfil de gestión y perfil comercial

El sistema SHALL distinguir el perfil de **gestión/facturación de AP** (consumo, semáforo, cierre al tope) del perfil **comercial/costos de AP** (valor de venta, margen). Un usuario con perfil de gestión MUST NOT poder cargar valores de venta, y un usuario con perfil comercial MUST NOT requerir permisos de gestión de consumo para operar su pantalla.

#### Scenario: Gestor de AP intenta cargar un valor de venta

- **WHEN** un usuario cuyo único perfil es `gestor_accidentes_personales` invoca el endpoint de alta de valor de venta
- **THEN** el backend rechaza la operación por falta del permiso `cargar_valor_venta_prestacion` y responde con error de autorización

#### Scenario: Gestor comercial consulta valores de venta

- **WHEN** un usuario con el perfil de gestor comercial de AP consulta la grilla de valores de venta por prestación y zona
- **THEN** el sistema devuelve los datos porque el perfil tiene el permiso correspondiente

### Requirement: Chequeo de permisos en el backend

Todo endpoint nuevo de AP (tope, consumo, semáforo, valor de venta, consolidado de cirugía) SHALL validar el permiso requerido **en el backend**. Ocultar la opción en la interfaz MUST NOT ser el único control de acceso.

#### Scenario: Llamada directa al endpoint sin permiso

- **WHEN** un usuario sin el permiso requerido invoca directamente el endpoint (por ejemplo con una herramienta HTTP, sin pasar por la UI)
- **THEN** el backend rechaza la operación con error de autorización y no devuelve datos

#### Scenario: Exposición del consolidado de cirugía con permiso propio

- **WHEN** un usuario de AP con el permiso `ver_consolidado_cirugia` consulta el consolidado de costo de una cirugía
- **THEN** el sistema devuelve el consolidado sin habilitarle el resto del módulo Contrataciones

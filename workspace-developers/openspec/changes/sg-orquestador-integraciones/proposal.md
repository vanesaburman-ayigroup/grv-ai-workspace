## Why

Solicitudes Genéricas (SG) es hoy una funcionalidad exclusiva del SAS interno: solo un operador con
usuario en el SAS puede darla de alta o consultarla. Portal de Clientes no tiene ninguna vía para
generar ni consultar una SG, así que cualquier pedido de un cliente externo requiere que un operador
interno lo cargue a mano, sin trazabilidad de que ese pedido vino de afuera. La misma necesidad se
anticipa para SIMP (Medicina Preventiva) y para otros sistemas de la compañía.

Hay un compromiso de fecha ya asumido con el cliente GCBA (reunión del 27/8/2026, Javier Sanchez):
el 11 de septiembre de 2026 el cliente tiene que poder iniciar una SG desde su acceso, sin pasos
manuales intermedios. Este cambio construye el mecanismo genérico que resuelve ese compromiso y deja
instalada la vía para que cualquier sistema autorizado (Portal ahora, SIMP y otros después) opere
contra SG sin repetir integración a medida cada vez.

## What Changes

- Se agrega un servicio de **alta de SG para sistemas externos**, expuesto por el Orquestador de
  Integraciones (`wsorquestadorintegraciones`), con credencial propia por sistema consumidor.
- Se agrega un servicio de **consulta de SG** (listado y detalle) para que el sistema externo vea el
  estado de lo que generó.
- Toda SG generada externamente registra su **sistema de origen** (módulo), visible en la tabla de
  Solicitudes Genéricas del SAS. El modelo de datos actual no contempla este concepto — es nuevo.
- Se agrega un **registro de sistemas habilitados** a operar contra el Orquestador, con el alcance
  (qué tipos de solicitud puede generar/consultar cada uno) configurable por sistema, no hardcodeado.
- Toda SG generada por un sistema externo se deriva siempre a un **área de gestión completa** (nunca
  a una persona puntual). El mecanismo de derivar a área o a persona ya existe en `wssolicitudesgenericas`;
  este cambio restringe la variante externa a "área" únicamente. Con esto el cliente externo nunca ve
  ni recibe el nombre de un gestor individual — no hace falta ocultar nada en el front, la SG externa
  simplemente nunca tiene una persona asignada en el momento de creación ni de consulta.
- **Corrección respecto del análisis inicial**: la validación de "tipo con `requiereDenuncia = true`
  exige `idDenuncia`" **ya existe** en producción (GRV-1929, `SolicitudesGenericaCommonsImpl
  .validarDenunciaRequerida`, invocada desde `SolicitudesGenericasServiceCompose.altaSolicitudGenerica`,
  el único entry-point del alta clásica). No es un hueco a cerrar. El punto real de esta change es que
  esa validación vive un nivel **arriba** de `crearSolicitudGenerica` (el método de bajo nivel que sí
  vamos a exponer al Orquestador) — así que el endpoint nuevo para sistemas externos tiene que invocar
  `validarDenunciaRequerida` explícitamente antes de crear, para no saltearse la regla por construcción
  y no por descuido. Es reutilizar lo que ya está, no crear una regla nueva. La restricción es por
  **tipo de solicitud**, no por área: un área como Logística puede seguir dando de alta SG sin denuncia
  para los tipos que no la requieren, sin cambio de comportamiento.

Explícitamente fuera de esta etapa, con su motivo:

- **Alta de SG desde SIMP**: el mecanismo queda genérico y disponible, pero la implementación
  concreta para SIMP se planifica aparte — la necesidad todavía no está formalizada, solo anticipada.
- **Migración de la integración a MuleSoft**: es la opción arquitectónicamente correcta (evaluada como
  Opción D en el documento base) pero su plazo es incompatible con el compromiso del 11/9. Se registra
  como evolución futura explícita, con fecha de migración a definir — no como deuda implícita.
- **Acceso conversacional por agentes de IA / MCP** (Opción E del documento base): requiere un LLM del
  lado del consumidor y no resuelve el requerimiento sistema-a-sistema planteado. Se construiría sobre
  esta misma integración, en una etapa independiente, sin modificarla.

## Capabilities

### New Capabilities

- `sg-integracion-sistemas-externos`: alta y consulta de Solicitudes Genéricas por parte de sistemas
  externos autorizados, a través del Orquestador de Integraciones — credencial por sistema, registro
  de sistema de origen, alcance configurable por sistema, y derivación exclusiva a área de gestión.
- `sg-validacion-tipo-requiere-denuncia`: garantizar que la validación existente (GRV-1929,
  `validarDenunciaRequerida`) se aplique también al alta que llega desde sistemas externos vía
  Orquestador, no solo al entry-point clásico del SAS.

### Modified Capabilities

_(no hay specs existentes en `openspec/specs/` para Solicitudes Genéricas — ambas capabilities son
nuevas en este repositorio de planificación, aunque el código de `wssolicitudesgenericas` ya existe
en producción)_

## Impact

- **`grvx/backend/wssolicitudesgenericas`**: nuevo campo/entidad de sistema de origen en el modelo de
  SG; nuevo endpoint (o variante) de alta y consulta pensado para ser invocado por el Orquestador, no
  por un usuario interactivo, que invoque `validarDenunciaRequerida` (GRV-1929, ya existente) antes de
  `crearSolicitudGenerica` — no se agrega regla de negocio nueva, se conecta la ya vigente al camino
  nuevo; exponer el sistema de origen en el listado de SG del SAS.
- **`grvx/backend/wsorquestadorintegraciones`**: nueva API externa — autenticación por credencial de
  sistema, validación de alcance (qué tipos puede operar cada sistema), llamada a
  `wssolicitudesgenericas` con el módulo de origen, forzando siempre derivación a área.
- **`grvx/frontend/solicitudesgenericas`** (pantalla interna del SAS): agregar columna/indicador de
  sistema de origen en la tabla de SG para que el operador interno distinga las que llegaron de afuera.
- **Portal de Clientes**: consumidor nuevo del Orquestador — fuera del alcance de código de esta
  change (la implementación del lado de Portal se coordina con ese equipo), pero es el caso de uso
  principal que valida el contrato.
- **Áreas de derivación (ver design.md para la evidencia completa)**: son tres casos, no una única
  área para todo — **`ATENCION CLIENTE`** (`id_area_gestion = 15`) para atención al cliente/
  auditoría (según lo ya hablado con GCBA), **`Traslados`** (`id_area_gestion = 12`) para traslados
  de pacientes (confirmado contra el historial real de 3 gestores: 938 SG, todas en área 12, cero en
  `Logística` id 4), y **`Mesa de Carga`** (`id_area_gestion = 16`) para un tercer caso que todavía
  falta definir con Javier — el catálogo actual no tiene ningún tipo de solicitud en esa área que
  sirva de referencia para un alta externa (los que existen son de generación interna de Carta
  Documento/Telegrama Laboral para el trámite de autoseguro, no algo que un usuario de GCBA pediría).
  Se cargan como configuración fija por tipo de solicitud en `sistemas_externos_sg_alcance`, **sin
  derivarlas del sistema de módulos de Keycloak/multimódulo** — esa relación es inconsistente incluso
  para el equipo interno real (de los 3 responsables del área 15, solo uno tiene el módulo "ATENCION
  CLIENTE") y multimódulo es una iniciativa aparte, todavía con migraciones pendientes en PROD, que
  conviene no acoplar al compromiso del 11/9 con GCBA.
- **Decisiones pendientes de validar con Gerencia/el equipo** (no se cierran en esta change, quedan
  explícitas): alcance exacto por sistema/tipo de solicitud; fecha objetivo de migración a MuleSoft;
  prioridad de SIMP frente a Portal.

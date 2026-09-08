## Context

`wsorquestadorintegraciones` ya expone una superficie externa bajo `/V1/external/**` (los callbacks
de Satapp para traslados), autenticada con `ApiKeyAuthenticationFilter` + `ApiKeyProperties`
(`security.api-keys.clients`: mapa `provider_name -> api_key`, con `rutasSinValidacion` como lista
explícita de excepciones — nunca un interruptor global). Este cambio agrega una superficie externa
nueva sobre el mismo mecanismo, en vez de inventar un esquema de auth propio: `Portal de Clientes`
pasa a ser un `provider_name` más en ese mapa, junto a `Satapp`.

`wssolicitudesgenericas` es el servicio de SG real: alta, consulta, áreas de gestión, tipos de
solicitud. Hoy lo consumen el SAS y `contrataciones`, ambos con un operador logueado detrás
(`idOperador` viaja en casi todos los DTOs de request). Un sistema externo no tiene ese concepto — no
hay persona logueada del lado de Portal, solo el sistema mismo.

El repo del Orquestador documenta como riesgo conocido la falta de un mecanismo explícito de
deduplicación/idempotencia (hoy relevante para no duplicar transacciones en SAP; acá aplica a no
duplicar SG si Portal reintenta una llamada que sí llegó a procesarse).

## Goals / Non-Goals

**Goals:**
- Que un sistema externo autenticado con su API key pueda dar de alta una SG y consultar las suyas,
  sin necesitar un operador logueado del SAS.
- Que la SG quede identificada con su sistema de origen y se derive siempre a un área, nunca a una
  persona.
- Que el alcance de qué puede hacer cada sistema (tipos de solicitud habilitados) sea configuración,
  no código.
- Que la validación de `requiereDenuncia` deje de depender del front y viva en el service común.

**Non-Goals:**
- No se implementa el consumo desde Portal de Clientes ni desde SIMP (queda para esos equipos /
  etapas futuras) — esta change entrega el contrato y el `provider` de ejemplo para GCBA.
- **Aclaración importante**: Portal de Clientes **no es un microfrontend del shell de SAS**. No se lo
  puede resolver reutilizando o exponiendo `grvx/frontend/solicitudesgenericas` vía module federation
  como se haría con un MFE interno. El equipo de Portal necesita migrar la pantalla completa o
  adaptarla de cero contra el contrato de este Orquestador, respetando las restricciones ya definidas
  (derivación a área, sin selector de gestor, sin concepto de denuncia visible). Ese trabajo de UI en
  Portal está fuera del alcance de código de esta change — es una dependencia de coordinación con ese
  equipo, no una tarea que se resuelva tocando los repos listados acá.
- No se migra nada a MuleSoft.
- No se agrega acceso por agentes de IA / MCP.
- No se resuelve idempotencia end-to-end más allá de lo mínimo indicado en Riesgos — un mecanismo
  completo de deduplicación cross-request queda anotado como decisión abierta, no cerrado acá.

## Decisions

### 1. Autenticación: reusar `ApiKeyAuthenticationFilter`, no crear un esquema nuevo

Se agrega `GCBA` como `provider_name` más en `security.api-keys.clients`, igual que Satapp.
Alternativa descartada: OAuth2 client-credentials completo — es el modelo "correcto" a largo plazo
(y el que probablemente use MuleSoft en la Opción D), pero agrega un authorization server y rotación
de tokens que no están montados hoy en este servicio; no se justifica para una integración de un
solo endpoint con plazo al 11/9. Queda anotado como parte de lo que se revisa en la migración a
MuleSoft.

**El provider es por CLIENTE, no por plataforma.** `GCBA` es el piloto — no `PORTAL_CLIENTES` como
provider genérico de toda la plataforma. Portal de Clientes sirve a más de un cliente (a futuro, por
ejemplo `HORIZONTE`); si todos compartieran el mismo `provider_name`/`sistema`, un cliente podría
listar o consultar SG de otro a través de los endpoints de listado/detalle, que filtran únicamente
por `sistema` (= identidad de la API key ya autenticada). Cada cliente nuevo que use Portal necesita
su propio `provider_name` en `security.api-keys.clients` — mismo patrón que ya usan
`Satapp`/`PortalProveedores` para otras integraciones de este mismo repo. `SIMP` (si en algún
momento pasa de anticipado a real) sería otro sistema/plataforma más, no un cliente — ahí sí
correspondería su propio provider a nivel plataforma.

### 2. Alcance por sistema: tabla de configuración, no un enum ni un `if` por provider

Se agrega una tabla `sistemas_externos_sg_alcance` (o similar) con
`(sistema, id_tipo_solicitud, puede_alta, puede_consulta)`. El Orquestador la consulta antes de
reenviar cualquier request a `wssolicitudesgenericas`. Alternativa descartada: hardcodear el alcance
de GCBA en código — resolvería el 11/9 pero repite exactamente el problema que esta change busca
evitar (repetir trabajo a medida por cada sistema nuevo).

### 3. Identidad del solicitante: la persona real logueada, con respaldo de usuario de servicio

**Corregido durante la implementación** (la decisión original acá era la inversa — "usuario de
servicio fijo, nunca la persona real"; quedó descartada al confirmar que GCBA sí tiene un usuario
real logueado del lado de Portal, no es una integración 100% máquina a máquina).

GCBA opera con usuarios reales de Portal de Clientes que ya existen como `Persona` en el modelo de
`wssolicitudesgenericas` (ej. Vanina Stellavato, `id_persona` 2429, ya confirmada en Keycloak con
módulo `CLIENTE`). El Orquestador manda ese `id_persona` real en cada alta
(`SolicitudGenericaExternaRequestDTO.idSolicitante`, opcional), y la SG queda a nombre de esa
persona — no de una cuenta genérica. `wssolicitudesgenericas` valida que el `idSolicitante`
informado exista antes de usarlo.

`SistemaExternoSg.personaSolicitante` (la persona de servicio fija por sistema) pasa de ser *la*
fuente del solicitante a un **respaldo**: se usa solo si el Orquestador no manda `idSolicitante` —
cubre una integración futura sin ningún usuario humano detrás (no es el caso de GCBA hoy). Sigue
siendo útil no eliminarlo: evita que una integración 100% automática (ej. una versión futura de
SIMP sin operador logueado) necesite resolver o crear una `Persona` ad hoc.

### 4. Derivación exclusiva a área

El endpoint externo de alta no expone el parámetro de derivar a persona: siempre resuelve
`idAreaGestion` a partir de la configuración del sistema (o de un default por sistema) y nunca acepta
un `idGestor`. Esto no requiere cambios en `wssolicitudesgenericas` — el mecanismo de derivar a área
ya existe; el Orquestador simplemente nunca ejercita la variante "a persona" para altas externas.

### 5. Reutilizar `validarDenunciaRequerida` (GRV-1929) en el endpoint externo, no reimplementarla

Corrección sobre el análisis inicial: la regla "`tipo.requiereDenuncia == true` ⇒ `idDenuncia`
obligatorio" **ya existe** — `SolicitudesGenericaCommonsImpl.validarDenunciaRequerida`, invocada por
`SolicitudesGenericasServiceCompose.altaSolicitudGenerica` (el único entry-point del alta clásica del
SAS, GRV-1929). El problema real es de cableado, no de regla faltante: esa validación vive un nivel
arriba de `crearSolicitudGenerica`, que es el método de bajo nivel que el endpoint nuevo para el
Orquestador va a llamar directamente (sin pasar por el compose, que trae lógica propia del flujo
interactivo del SAS — categoría consulta/reclamo, adjuntos, notificaciones a gestor — que no aplica a
un alta de sistema externo). Por eso el nuevo punto de entrada para sistemas externos debe invocar
`validarDenunciaRequerida` explícitamente antes de `crearSolicitudGenerica`, para no perder la regla
por la forma en que está cableada hoy, no porque falte crearla. El Orquestador no necesita conocer la
regla: si `wssolicitudesgenericas` la rechaza, el Orquestador propaga el error tal cual.

Aclaración de negocio (confirmada con la usuaria): la restricción es por **tipo de solicitud**, no por
área. Un área como Logística puede seguir dando de alta SG sin denuncia para los tipos que no la
requieren — no hay reglas nuevas por área que agregar.

### 6. Registrar sistema de origen: columna en `SolicitudGenerica`, no una tabla aparte

Se agrega `sistema_origen` (nullable, `null` = generada desde el SAS) directamente en la
entidad `SolicitudGenerica`, en vez de una tabla de auditoría separada. Es el dato mínimo que pide el
alcance de esta etapa (mostrarlo en la tabla de SG del SAS) y evita un join adicional en el listado.

## Risks / Trade-offs

- **[Riesgo] Reintentos de Portal duplican una SG** — el Orquestador no tiene hoy un mecanismo de
  idempotencia (riesgo ya documentado en este mismo repo para el flujo de SAP). → **Mitigación
  mínima para esta etapa**: exigir un `idempotencyKey` (o el id de la solicitud del lado del sistema
  externo) en el request de alta, y que `wssolicitudesgenericas` rechace un alta repetida con la misma
  clave para el mismo sistema. Un mecanismo más robusto queda como decisión abierta.
- **[Riesgo] `security.api-keys.clients` como único control de acceso** — una API key filtrada da
  acceso de alta a cualquier área configurada para ese sistema. → **Mitigación**: alcance acotado por
  sistema (Decisión 2) limita el daño; rotación de key queda en el procedimiento operativo estándar
  del equipo, no es parte del código de esta change.
- **[Riesgo] El endpoint externo nuevo llama a `crearSolicitudGenerica` sin pasar por el compose** —
  si alguien agrega ese endpoint sin el `validarDenunciaRequerida` explícito (por ejemplo copiando el
  patrón de otro caller de bajo nivel), la regla de GRV-1929 se saltea silenciosamente para las altas
  externas. → **Mitigación**: test de integración específico que verifica el rechazo end-to-end desde
  el endpoint externo (no solo a nivel unitario del método de validación, que ya está cubierto).
- **[Trade-off] Se sale sin MuleSoft** — aceptado explícitamente por plazo (documento base, Opción D).
  Consecuencia: el Orquestador acumula una responsabilidad de integración más, que en la migración
  futura hay que desmontar sin romper a los sistemas ya conectados (Portal, y potencialmente SIMP).

## Migration Plan

1. `wssolicitudesgenericas`: migración que agrega `sistema_origen` a `SolicitudGenerica` (nullable,
   default `null`) y la tabla de alcance por sistema. Sin impacto en filas existentes.
2. `wssolicitudesgenericas`: agregar la validación de `requiereDenuncia`, gateada de forma que no
   rompa altas existentes (ver Riesgo de auditoría arriba) antes de habilitarla en PROD.
3. `wsorquestadorintegraciones`: nuevo controller bajo `/V1/external/solicitudes-genericas/**`
   (alta, listado, detalle), nuevo `provider` en `security.api-keys.clients` para el sistema piloto.
4. `wssolicitudesgenericas` (frontend/tabla de SG del SAS): agregar columna de sistema de origen.
5. Habilitar la API key de Portal de Clientes/GCBA recién cuando ese equipo confirme que su
   integración está lista para consumirla — no antes, para no dejar una credencial activa sin
   contraparte.

No hay rollback de datos: `sistema_origen = null` y la ausencia de filas en la tabla de alcance son
el estado actual, así que desactivar la API key del sistema alcanza para desconectar la integración
sin tocar SG ya creadas.

## Pivote 2/9: tipos de solicitud dedicados al canal cliente (reunión con Lucas Alama)

**Corrige/reemplaza la recomendación original de reusar tipos existentes (161/160/113/112 — ver
sección siguiente, que queda como contexto histórico).** En la reunión del 2/9 con Lucas Alama se
definió un enfoque más simple:

1. **No exponer el catálogo interno de tipos de solicitud al cliente.** La tabla completa de
   tipos×área (armada para el catálogo de Javier) es, palabras de Lucas, "un embole" — el cliente no
   tiene por qué ver ni elegir entre decenas de tipos internos (CALL, SIC, etc.).
2. **Crear 2-3 tipos de solicitud genéricos nuevos, dedicados exclusivamente al canal cliente**:
   `Consulta`, `Reclamo`, `Pedido` (nombres de trabajo — falta definir el nombre final en
   `tipos_solicitudes_genericas.descripcion`, que debe ser **visualmente distinguible** de los tipos
   internos a simple vista en la bandeja del gestor, ej. prefijo `Cliente - `).
3. **Corrección 2/9 (post-reunión): `denuncia_requerida = 0` a nivel tipo, pero `idDenuncia` sigue
   siendo opcional y se acepta cuando viene**, no "nunca aplica". El cliente puede llegar a estos 3
   tipos por dos caminos distintos: (a) un flujo genérico sin contexto de siniestro (ahí no hay
   `idDenuncia` — el flag en 0 es correcto), y (b) **desde el detalle de un siniestro puntual**,
   donde el Portal ya conoce el `idDenuncia` y debe poder mandarlo — las SG tienen que verse también
   en el detalle de ese siniestro, como ya pasa con las SG creadas desde el SAS. El contrato externo
   ya soporta esto (`SolicitudGenericaExternaRequestDTO.idDenuncia` es opcional desde el inicio) — no
   hace falta cambio de código, solo no asumir que "no obligatoria" significa "nunca se manda".
4. **Áreas de derivación**: Lucas listó en la reunión Tramitadores, Auditoría Médica, Atención al
   Cliente (`Call Center` en la tabla `areas_gestion_solicitudes_genericas`), Logística,
   Contrataciones y Mesa de Carga; se suma Traslados por el volumen real que maneja (ver evidencia de
   la sección anterior). **Áreas de derivación confirmadas para los 3 tipos nuevos**:
   Tramitadores, Auditoría Médica, Call Center (Atención al Cliente), Logística, Contrataciones,
   Mesa de Carga, Traslados — 7 en total. Cada uno de los 3 tipos se mapea a las 7 en
   `areas_gestion_solicitudes_genericas_tipo_solicitud`.
5. **La SG externa NO debe asignarse a un gestor/analista específico** — el cliente no tiene que
   conocer la estructura interna del área. Tiene que llegar visible para el **jefe o referente del
   área**, quien la deriva/asigna manualmente. **CONFIRMADO 2/9 — resuelto, no requiere código
   nuevo**: el comportamiento "cae a un responsable sin gestor asignado" es **genérico por diseño**
   en `wssolicitudesgenericas`, no específico de Tramitadores. La tabla puente
   `areas_gestion_solicitudes_genericas_personas` tiene una columna `id_es_responsable` por
   persona×área, y toda la lógica de permisos en `SolicitudesGenericaCommonsImpl` (ej.
   `verificarPuedeCerrarse`, ticket GRV-1989: *"el responsable puede cerrar aunque la SG no tenga
   gestor asignado"*) compara contra esa columna sin ningún `if` hardcodeado por área. Se verificó
   contra datos reales que las 7 áreas confirmadas ya tienen personas marcadas como responsables:
   Call Center (11), Tramitadores (31), Auditoría Médica (5), Logística (12), Contrataciones (4),
   Traslados (4), Mesa de Carga (8). **No hace falta ninguna acción — ni de código ni de datos —
   para este punto.**
6. **Dos elementos visuales distintos en la pantalla de SG** (precisado 2/9, punto separado del
   nombre distinguible del punto 2) — no alcanza con la columna "Sistema Origen" ya agregada al
   frontend (tarea 5.1, un dato más de la fila):
   - **(a) Marca especial en la grilla**: badge/color/ícono en la fila para que salte a la vista al
     escanear la lista general mezclada con el resto, sin tener que abrir cada SG ni filtrar.
   - **(b) Card nueva en la pantalla de SG**: un elemento destacado tipo KPI/resumen (ej. "N SG de
     cliente pendientes") visible de entrada en la pantalla, sin depender de bajar/escanear la
     grilla — más notorio todavía que el badge de la fila.

   Ambos son trabajo de frontend nuevo sobre `grvx/frontend/solicitudesgenericas` — el dato de base
   (`sistema_origen`) ya existe (tarea 5.1); falta el tratamiento visual (badge de fila) y el
   componente nuevo (card de resumen). No es una sección/pestaña aparte para la lista completa —
   eso se descartó a favor de estos dos elementos, más simples de implementar ya.
7. Confirmado explícitamente por Lucas: enfoque **incremental** — arrancar con estos 2-3 tipos y no
   mostrarle a Javier el catálogo completo; se van agregando tipos a medida que se necesiten.
8. **Pantallas de Portal = mismo front de SG, trasladado con las restricciones ya conocidas.**
   Confirmado por la usuaria 2/9: las pantallas de SG del lado de Portal de Clientes no son un
   desarrollo nuevo desde cero — son el mismo frontend de Solicitudes Genéricas del SAS
   (`grvx/frontend/solicitudesgenericas`), portado/adaptado a Portal con las restricciones ya
   definidas en esta change (sin elegir gestor/analista, sin ver estructura interna, catálogo
   acotado a los 2-3 tipos genéricos). Responde la duda abierta de "cómo le va a ver el cliente
   después" (20:22 de la reunión) — no es una pantalla nueva a diseñar desde cero, es una adaptación.
9. **`id_area_gestion` de los 3 tipos nuevos = área nueva "Portal Cliente" (pseudo-área del canal
   cliente), NO una de las 7 áreas reales — RESUELTO e implementado, MR !504.** Corrección 2/9 a lo
   implementado en la primera versión del seed (que usaba `id_area_gestion = id_area_gestion_derivada`
   auto-referenciado por cada una de las 7 áreas). Se investigó el código antes de aplicar el
   cambio: **el alta externa (`SolicitudGenericaServiceExternoImpl` →
   `SolicitudesGenericaCommonsImpl.crearSolicitudGenerica`) no consulta esta tabla en absoluto** —
   el `idAreaGestion` que manda el Orquestador se valida solo como área **existente**
   (`AreaGestionSolicitudGenericaRepository.findById`) y se persiste directo en la SG, sin cruzar
   contra `areas_gestion_solicitudes_genericas_tipo_solicitud`. Esta tabla la usa exclusivamente la
   pantalla interna del operador (`SolicitudesGenericaCommonsImpl.findTiposSolicitudes` para "qué
   tipos puedo crear según mi área" y `findAreasGestion` para "a qué áreas puedo derivar una SG ya
   creada"). Se creó la pseudo-área **"Portal Cliente"** (id calculado dinámicamente,
   `MAX(id_area_gestion)+1`, no existe todavía en ningún ambiente) como área dueña de los 3 tipos
   nuevos, con las 7 áreas reales como derivadas — 21 filas. **Efecto práctico logrado**: como
   ningún operador real tiene asignada el área "Portal Cliente", estos 3 tipos no aparecen en el
   combo de "crear nueva SG" de ninguna de las 7 áreas reales — solo entran por el canal externo,
   exactamente lo pedido.
   **Caveat sin resolver, queda en Open Questions**: con este modelo, un operador de (por ejemplo)
   Tramitadores que recibe una de estas SG no va a ver, vía el combo estándar de "derivar a"
   (`findAreasGestion` filtra por el área REAL del operador logueado), las otras 6 áreas como
   destino de re-derivación manual — porque esa fila tiene `id_area_gestion = Portal Cliente`, no
   Tramitadores. Si el negocio necesita que un jefe de área pueda re-derivar manualmente entre las
   7 áreas, hace falta además un mapeo N×N entre ellas (no incluido en este seed) — no se agrega
   sin confirmar primero que haga falta.
10. Serológicos/triage de Tramitadores (17:14-17:26 de la reunión) era sobre un tipo interno viejo
    ("Apertura de dictamen"), no aplica a los 3 tipos nuevos del cliente — descartado, sin acción.

**Impacto en lo ya implementado**: el seed `TAR-15-sg-seed-gcba.sql` (que apuntaba a los tipos 161,
160, 113, 112 de referencia) fue reescrito — ahora da de alta los 3 tipos nuevos (166/167/168) y su
mapeo a las 7 áreas — MR !504. Los endpoints/DTOs/servicio ya implementados en
`wssolicitudesgenericas` y `wsorquestadorintegraciones` **no cambian** — el contrato
(`idTipoSolicitud`, `idAreaGestion`) sigue igual, solo cambian los valores de `idTipoSolicitud`
válidos para GCBA.

## Pantallas de Portal de Clientes (2/9) — copiar y adaptar, NO es un MFE

Aclarado explícitamente por la usuaria: **Portal de Clientes no es un microfrontend y no monta
ningún MFE del SAS**. La implementación real de las pantallas de SG en Portal es copiar el
JSX/lógica de `grvx/frontend/solicitudesgenericas` al proyecto propio de Portal y adaptarla con las
restricciones ya definidas — no una integración en runtime con este repo.

**Corrección 2/9 (tercera ronda) — comparación contra la referencia real**: se entró como
`ayi.logistica` a STAGE (`https://stage-publica.stage.sas.colonia-suiza.com.ar`, credenciales en
el Google Doc "SAS_Accesos") y se recorrió con Playwright el módulo real de Solicitudes Genéricas
de Logística — la referencia que pidió Lucas ("como está en logística"). Hallazgos que corrigen lo
ya implementado en `NuevaSolicitudGenerica.js`:

1. **Falta "Adjuntar archivo"** ("Subir o arrastrar archivo aquí" / "Seleccionar archivo") — el
   formulario real lo tiene, el de Portal no. Omisión real a corregir.
2. **Es un drawer lateral sobre el tablero, no una página ruteada aparte.** El real abre "Nueva
   Solicitud" como panel lateral (`Drawer`) superpuesto al tablero de SG, coincidiendo además con
   cómo Portal ya maneja "Nueva Consulta" en `ConsultasReclamos/DrawerNuevaConsulta` — se armó como
   página completa en `/portal/home/solicitudesGenericas/nueva`, desviándose de la convención
   propia del repo. A corregir: convertir a drawer, abierto desde el tablero (ver punto 8.2).
3. **Confirmado correcto**: el resto de los campos coincide con lo ya implementado — Tipo,
   Área (sin Gestor, correcto para Portal), "Añadir observación", Fecha de vencimiento/advertencia.
4. **Confirmado correcto**: el tablero real tiene exactamente el botón "Consultar todas las SG"
   (a sacar en Portal, ya documentado), las 3 cards (asignadas a mí/enviadas/cerradas, ya
   reflejadas en la maqueta `GcbaTableroInterno.jsx`), los filtros Reabiertas/Vencidas/Por vencer,
   y las columnas SOLICITUD/DENUNCIA/PACIENTE/ÁREA SOLICITANTE/SOLICITANTE/TIPO/FECHA
   ADVERTENCIA/FECHA VENCIMIENTO/ÁREA GESTIÓN/GESTOR/ESTADO/ACCIONES.

Se armó una maqueta descartable (`dev-standalone/GcbaNuevaSolicitud.jsx`, no commiteada) del
formulario de alta, corrida en local para revisión, con los ajustes confirmados por la usuaria:
mantiene fecha de vencimiento y fecha de advertencia (no se sacan, corrección a un supuesto inicial
equivocado), label "Añadir observación" (no un copy nuevo), tipo acotado a los 3 tipos cliente,
selector de área de destino visible (las 7 reales), sin campo de gestor.

Se releva además el resto de las pantallas involucradas (ver tasks.md, sección 8, con cita
archivo:línea de cada punto):

- **Tablero principal**: en el SAS vive en `SolicitudesGenericas.js` (monta `TableroCustom` +
  botón "Nueva Solicitud" + la tabla). Portal necesita ver solo sus propias SG (desde/hacia
  sistema Portal Cliente) — el filtro por `sistema_origen` de este lado no existe hoy expuesto a
  Portal, hay que confirmar si los endpoints externos ya alcanzan.
- **Resuelto 2/9**: `TableroCustom.js` elige entre `TableroOperador`/`TableroSupervisor` según
  `usuarioActivo.isOperador`, un flag que Portal no tiene de origen (Vanina entra por Keycloak con
  módulo `CLIENTE`, no como operador/supervisor SAS). La usuaria de negocio definió: **todo usuario
  de Portal se comporta como "operador"** (ve solo sus propias SG enviadas) — por ahora, no hay
  vista tipo supervisor para Portal. Al portar, alcanza con `TableroOperador` como único
  comportamiento; no hace falta portar `TableroSupervisor` en esta etapa.
- **Sin botón "Consultar todas las SGs"**: confirmado que existe en el SAS
  (`FiltroSolicitudesGenericas.js:48-55`) — al portar, directamente no se incluye.
- **Corrección tras lectura completa del archivo**: en la tabla del tablero principal
  (`TablaSolicitudesGenericas/TablaSolicitudesGenericas.js`), la columna GESTOR **no** se condiciona
  por `isOperador` (eso solo afecta la columna de fecha, línea 210) — se filtra por un flag
  separado, `gestoresPorDefecto`, combinado con `activeTab` (líneas 287-293: con
  `gestoresPorDefecto` falso y `activeTab=0`, se sacan tanto "Área Gestión" como "Gestor"). Para
  Portal alcanza con pasar `gestoresPorDefecto=false` y `activeTab=0` a este mismo componente real
  — no hace falta forkearlo para este caso.
- **Grilla de SG en el detalle de denuncia**: la variante que usa el menú secundario de denuncia
  completa (`DenunciaCompleta/TablaSolicitudesGenericas.js`, un archivo **distinto** al de arriba)
  sí tiene una columna "GESTOR" **incondicional**, sin ningún flag que la saque (líneas 199-220) —
  esta sí hay que sacarla directamente al portar, no hay flag que la oculte.
- **Detalle de SG**: hay referencias a gestor/responsable repartidas en 5 componentes distintos
  (`DetalleSolicitudGenerica.js`, `DatosDeSolicitudGenerica.js`, `CabeceraDatosDenuncia.js`,
  `MasInformacion/CardSolicitudDetalle.js`, `MasInformacionDetalle.js`) — no es un cambio en un
  solo lugar.

**Hallazgo sobre `areas_gestion_solicitudes_genericas_tipo_solicitud`** (relevado el 2/9, confirmado
con datos reales): la tabla tiene dos columnas de área con semántica distinta —
`id_area_gestion` es el área **dueña** del tipo (donde aterriza y desde donde se gestiona), e
`id_area_gestion_derivada` es a qué área esa área dueña puede **reenviarlo** después. Existe un
patrón ya usado en el catálogo — fila **auto-referenciada** (`id_area_gestion =
id_area_gestion_derivada`, ej. tipo 44 "Apertura dictamen" en Tramitadores) — que hace que el tipo
aterrice directo en esa área sin depender de un salto de derivación extra. El seed de los 3 tipos
nuevos usa ese patrón para las 7 áreas confirmadas, con `mail_a_solicitante_en_cierre = 1` (misma
convención que las filas auto-referenciadas existentes) para que el cliente se entere cuando se
cierra su SG.

## Recomendación original (contexto histórico — superada por el pivote de arriba)

Retomando lo ya hablado con Javier (GCBA) en la reunión del 27/8: el acceso de GCBA estaba pensado
para **dos casos separados**, cada uno con su propia área de destino — no una única área para todo:

| Caso | Área de destino | `id_area_gestion` |
|---|---|---|
| Atención al cliente / auditoría | `ATENCION CLIENTE` | **15** |
| Traslados de pacientes | `Traslados` | **12** *(confirmado — ver evidencia)* |
| Mesa de Carga (a definir con Javier qué pedido concreto) | `Mesa de Carga` | **16** *(agregada a pedido de la usuaria — ver caveat)* |

Evidencia relevada de la BD `cs` (no una decisión ya tomada, es la base para proponerla):

- `ATENCION CLIENTE` (id 15) es responsabilidad de Mara Renaudeau, Leonardo Carrasco y Marisel
  Martinez (39 personas asignadas), ya mezcla tipos de solicitud de todos los clientes sin
  segmentación por cliente. Mara además es la única de los tres responsables que tiene el módulo
  Keycloak "ATENCION CLIENTE" (id_modulo_sas 5) — coincide en nombre, pero eso es dato de contexto,
  no el criterio para elegir el área (ver más abajo por qué no atamos una cosa a la otra).
- **Confirmado por datos reales**: se relevó el historial completo de 3 gestores de traslados
  (Ailen Perez, Gonzalo Clivaggio, Lucila De La Vega) — 938 SG en total entre los tres, **todas en
  área `Traslados` (id 12), cero en `Logística` (id 4)**. Lucila tiene actividad reciente (julio
  2026) con tipos como "CALL (Gestión de traslado)" y "Reclamos/Consultas - At. al Cliente". El
  patrón operativo real usa exclusivamente el área 12 para este tipo de gestión.
- **`Mesa de Carga` (id 16) — caveat importante**: los únicos tipos de solicitud mapeados hoy a esta
  área son de generación de Carta Documento/Telegrama Laboral para uso interno de Tramitadores/
  Auditoría Médica gestionando el autoseguro (`Solicitud de CD (HORIZONTE)`, y hasta existen ya
  `Solicitud de CD (GCBA AUTOSEGURO)` / `Solicitud de TL (GCBA AUTOSEGURO)`, ids 158/159 — el mismo
  158 que ya usa `Constantes.ID_TIPO_SOLICITUD_CD` en el service de generación de CD). Ninguno de
  estos es un pedido que un usuario final de GCBA presentaría desde un portal — son pasos de un
  trámite legal interno. **No hay ningún tipo existente en esta área que sirva de referencia para un
  alta externa.** Si se agrega Mesa de Carga como destino, falta que Javier defina qué pedido
  concreto de GCBA correspondería ahí — no se inventa un tipo nuevo sin esa definición.

**Por qué NO se deriva del sistema de módulos de Keycloak/multimódulo**, aunque a primera vista
parezca tentador (el módulo "ATENCION CLIENTE" existe y hasta lo tiene la responsable del área 15):

1. La relación módulo↔área ya es inconsistente incluso para el equipo interno real: de los 3
   responsables del área 15, solo Mara tiene el módulo "ATENCION CLIENTE" — Leonardo y Marisel
   tienen el módulo "CEM". No hay una correspondencia 1:1 limpia de la que derivar una regla.
2. El puente que existe para esto (`areas_gestion_solicitudes_genericas.id_modulo_sas`, agregado en
   GRV-1873) hoy solo está cargado para Tramitadores — ni área 15 ni área 12/4 lo tienen. Completarlo
   es una decisión de la iniciativa de multimódulo, con su propio owner y cronograma.
3. **Multimódulo es una iniciativa aparte, todavía no cerrada en PROD** (el MR de multimodulo/
   multiperfil completo sigue con migraciones pendientes de aplicar a mano en PROD). Acoplar TAR-15
   a ese mecanismo ata el compromiso del 11/9 con GCBA al cronograma de otra iniciativa en curso —
   son cosas que conviene mantener desacopladas.
4. El módulo Keycloak "CLIENTE" (id 4, `gestor_autoseguros`) que sí usan contactos reales de GCBA
   hoy (ej. `n.orellano@buenosaires.gob.ar`) es para gestión de autoseguro, un dominio distinto al
   de Solicitudes Genéricas — no tiene ninguna fila en `areas_gestion_solicitudes_genericas_personas`
   y no aporta nada a esta decisión.

**Conclusión operativa**: `idAreaGestion` para GCBA se carga como **configuración fija por tipo de
solicitud** en `sistemas_externos_sg_alcance` — área 15 (`ATENCION CLIENTE`) para atención al
cliente/auditoría, área 12 (`Traslados`) para traslados, y área 16 (`Mesa de Carga`) para el caso
que falta definir con Javier — nunca derivado de un módulo. No se toca `id_modulo_sas` de ninguna de
las tres áreas como parte de esta change.

## Open Questions

- Nombre final de los 3 tipos de solicitud nuevos para el canal cliente (`Consulta`/`Reclamo`/
  `Pedido` son nombres de trabajo) y su convención de prefijo/formato para distinguirlos a simple
  vista de los tipos internos.
- Si un jefe/referente de área necesita re-derivar manualmente una SG del cliente entre las 7
  áreas reales (no solo recibirla), hace falta un mapeo N×N entre ellas en
  `areas_gestion_solicitudes_genericas_tipo_solicitud` — no incluido todavía (ver punto 9 del
  pivote 2/9 más arriba).
- Cómo ve el cliente en Portal el estado/seguimiento de su propia SG después de cargarla — Lucas lo
  preguntó explícitamente en la reunión (20:22) y quedó sin responder ("ya vemos cómo hacemos con
  el resto"). Aclarado 2/9: las pantallas de Portal son el mismo frontend de SG del SAS, trasladado
  con las restricciones ya conocidas — falta el trabajo concreto de portarlo, no es una pantalla a
  diseñar desde cero.
- Diseño visual concreto del badge en la grilla (7.7a) y de la card KPI en la pantalla de SG (7.7b).
- Mecanismo de idempotencia definitivo para reintentos del lado del sistema externo (ver Riesgos).
- Fecha objetivo de migración a MuleSoft.
- Prioridad y formalización de la necesidad de SIMP frente a Portal.

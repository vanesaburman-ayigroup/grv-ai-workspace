# Plan de Pruebas — Autorización de traslados duplicados del mismo día

| | |
|---|---|
| **Change OpenSpec** | `traslados-duplicados-autorizacion` |
| **Ticket** | **INI-2** (triage inbox, no Jira) |
| **Sistema** | SAS de siniestros laborales — Colonia Suiza (ART) |
| **Versión del plan** | 1.0 |
| **Fecha** | 18/08/2026 |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |
| **Ambiente de certificación** | **DEV únicamente** — `https://dev.sas.colonia-suiza.com.ar` |
| **Ambiente NO apto** | **TEST** — `wsturnos` sin desplegar (ver §4) |
| **Servicios involucrados** | `wsturnos`, `wslogistica`, `wstraslados`, `tramitadores` (MFE), `logistica` (MFE) |
| **Base** | MariaDB 10.5, esquema `cs` |
| **Insumos normativos** | PRD §5, §6 (RF-1.1→RF-5.1), §8 (C-01→C-16) · `design.md` D1–D10 · 5 `specs/*/spec.md` · SDD §5 y §6 |
| **Insumos de QA previos** | Análisis estático (EST-01→EST-23) · Verificación de aplicación (VAP-01→VAP-06) · Verificación de base (VBD-01→VBD-05) |

---

## 1. Resumen ejecutivo

Este plan certifica un circuito de autorización que atraviesa **cinco servicios, tres capas y dos microfrontends**. No es una funcionalidad de pantalla: es un control de negocio cuyo efecto real se verifica en base de datos, y cuya falla silenciosa —un pedido que nadie resuelve— deja a un paciente sin traslado sin que ningún actor del sistema reciba una señal.

**Tres condiciones marcan todo el plan:**

1. **Sólo hay un ambiente donde probar.** En TEST el frontend está desplegado y el backend de `wsturnos` no: los cinco endpoints del circuito responden **404**, no se enciende ninguna card y la pestaña de pendientes muestra **turnos sin filtrar sin dar error** (VAP-01). Es el peor modo de falla que el propio `design.md` había anticipado, ya materializado. **TEST se declara no apto** hasta que se despliegue `wsturnos`.

2. **La fecha del dato decide qué se puede probar.** Con traslados en fecha pasada el backend colapsa la matriz de salidas a `soloInformativo` («el viaje ya empezó») y **habilita una sola salida**. Todo caso que necesite las tres salidas exige **fechas futuras**; verificado que con el 25/08/2026 el bloque ofrece `ANULAR`, `SIN_TRASLADO` y `AUTORIZACION` (VAP-05).

3. **Parte del alcance está confirmado como no implementado.** Siete conductas que las specs declaran en modo `ADDED` corresponden a tareas abiertas en `tasks.md`. Este plan **no las prueba como casos normales**: las marca como *caso que se espera que falle* (XF) o las excluye por no implementado, con la tarea que lo respalda. Certificar contra una spec aspiracional sería certificar un control que no existe.

**Corrección de línea de base respecto del análisis estático.** El bloqueante **EST-01 queda resuelto**: `devolucion-resultado-solicitante` **sí está implementada** en DEV —contador `mis-duplicados-resueltos`, pestaña «Autorización Doble Traslado Resuelta» con Resultado / Lo resolvió / Fecha / **Dictamen** / Mi justificación, y `marcar-duplicados-vistos`— y el **hueco H-1 está cerrado**. El PRD §7.1 y el SDD §10, que la describen como hueco abierto, están **desactualizados respecto de su propio código** (VAP-03). Esa capability entra al alcance como funcionalidad entregada.

---

## 2. Objetivo y alcance

### 2.1 Objetivo del plan

Verificar que un segundo traslado del mismo día para el mismo paciente **sólo exista si alguien con autoridad lo autorizó**, que esa decisión quede **registrada y sea auditable**, que **logística no vea lo que no está autorizado** y **vea marcado lo que sí**, y que **el resultado vuelva a quien lo pidió**.

En términos operativos, el plan responde tres preguntas:

- ¿El control se puede evitar? (gate server-side, seguridad de los endpoints, motivo autodeclarativo)
- ¿El efecto que se ve en pantalla es el que quedó persistido? (verificación en BD de cada caso que escribe)
- ¿El circuito genera ruido o riesgo en logística? (la llave de visibilidad y la marca)

### 2.2 Alcance incluido

| # | Bloque | Qué se prueba |
|---|---|---|
| A-1 | **Detección del conflicto** | Bloque de conflicto en el wizard de nuevo turno, identificación por datos operativos, matriz de salidas habilitadas por el backend |
| A-2 | **Las tres salidas** | Anular el preexistente (con su resultado real antes de guardar), guardar sin traslado, pedir/autorizar |
| A-3 | **Pedido y resolución** | Justificación obligatoria, auto-aprobación con permiso, card y grilla de pendientes, drawer de resolución, dictamen, guard de «ya resuelto», criterio del último pedido |
| A-4 | **Devolución al solicitante** | Contador, pestaña de resueltas, dictamen visible, marcado de vistos idempotente, exclusividad de cards por perfil |
| A-5 | **Gate server-side** | 409 CONFLICT en `POST /turnos/crear` y `PATCH /turnos/programar-turno`; qué acepta y qué rechaza |
| A-6 | **Visibilidad en logística** | `id_estado_logistica_ida` como única llave, marca `es_duplicado_autorizado`, franja/ícono/leyenda, cancelación por motivo 16 |
| A-7 | **Integración entre servicios** | `wsturnos` → `wslogistica` en el rechazo; `tramitadores` → `wstraslados` → `wslogistica` en la anulación |
| A-8 | **Seguridad del circuito** | R-1: endpoints sin autenticación y permiso validado contra un `idAutorizante` que viaja en el body |
| A-9 | **Persistencia** | Verificación en BD de DEV de cada caso que escribe, con query declarada |

### 2.3 Alcance excluido explícitamente

| # | Fuera de alcance | Motivo |
|---|---|---|
| E-1 | **Solicitudes genéricas (SG)** | Descartado por decisión de negocio (PRD §4.2). Se sigue el patrón de Cirugías |
| E-2 | **Doble instancia de autorización** | Modelada en `autorizaciones` (estado 4 + segundo autorizante), **cero usos en 2026**, no se implementa |
| E-3 | **Retroactividad** | No se toca ninguno de los 2.156 casos históricos. No hay caso de migración ni de reproceso |
| E-4 | **El 68 % de anulaciones sin motivo específico** | Problema de calidad de datos de logística, anterior y ajeno a este change |
| E-5 | **STAGE y PRODUCCIÓN** | No promovidos. Además, `VBD-02` bloquea el despliegue: el script del permiso colisiona con `id_permiso = 101`, ya ocupado por `editar_cie10_bloqueado` |
| E-6 | **Prueba de carga y performance** | El change no declara requisito no funcional. Se registra `R-14` (`FUNCTION('DATE',…)` impide índice) como deuda observada, no como caso |
| E-7 | **Retiro del motivo autodeclarativo** | El PRD §11 pregunta 1 lo deja abierto sin fecha. Se prueba **el comportamiento actual**, no el deseado (ver GST-05) |
| E-8 | **Regresión funcional del resto del módulo Turnos** | Se cubre sólo el camino de alta/programación con traslado. Fuera de eso, regresión por suite existente |

### 2.4 Defectos ya corregidos — no se planifican como regresión de defecto abierto

Reverificados con evidencia propia en DEV (VAP-04). **Se prueban una vez, como confirmación**, no como bug abierto:

- «Ver información de traslado» **abre correctamente** (`POST /grv/traslados/traslado/detalles/id` → 200; el símbolo `resetTurnosTablaDetalle` ya no existe en el bundle).
- A **390 px** los botones «Atrás» y «Cancelar» **no se superponen**: envuelven en dos filas.
- El **resize no resetea el wizard**: de 1440 a 768 px se mantiene en el paso 2 con el bloque de conflicto intacto.

---

## 3. Estrategia de prueba por niveles

La estrategia es **de abajo hacia arriba en la verificación y de arriba hacia abajo en la ejecución**: cada caso se ejecuta desde la interfaz o desde el endpoint, y se **cierra en base de datos**. Un caso que sólo verifica lo que muestra la pantalla no está cerrado: el defecto más profundo que tuvo este circuito —el pedido asociado al traslado equivocado (D3)— era invisible en pantalla y evidente en una fila.

### 3.1 Nivel UI — tramitadores (gestor y quien autoriza)

**Herramienta:** navegador con panel de red y consola abiertos. Captura de evidencia obligatoria en cada caso.

| Aspecto | Criterio |
|---|---|
| **Superficie** | Wizard de nuevo turno (`StepTraslado`), drawer de programar turno, drawer de editar turno de rehabilitación, drawer de generar autorización — **los cuatro drawers montan el mismo bloque de conflicto** |
| **Qué se observa** | Que las salidas renderizadas sean **exactamente** las que el backend habilitó en `salidas` (`puedeAnular`, `puedeGuardarSinTraslado`, `requiereAutorizacion`) |
| **Regla transversal RF-5.1** | **Ningún identificador interno en pantalla.** Se verifica en el bloque, en la grilla, en el drawer de resolución y en las dos cards |
| **Accesibilidad** | Nombre accesible de los botones de acción de la grilla. **Defecto abierto confirmado**: `<button><img alt="icon"></button>` sin `title` ni `aria-label` (ATD-13) |
| **Responsive** | 1440 px y 390 px. Los tres defectos de layout están corregidos; se verifican una vez |
| **Copy** | Que el texto del `detalle` que manda el backend no contradiga el estado que muestra el front (`tasks 7.15`, abierto) |

### 3.2 Nivel UI — logística

| Aspecto | Criterio |
|---|---|
| **Superficie** | Grilla de traslados del sector (`TablaTraslados`) |
| **Qué se observa** | Franja de color propia, ícono con tooltip, entrada en la leyenda al pie, y **convivencia con las otras señales** (`requiereRevision`, `espontáneo`) |
| **Limitación declarada** | RF-3.4 **no define precedencia visual** (EST-17). Los casos de convivencia se ejecutan como **observación con evidencia**, no como pass/fail contra un criterio inexistente |

### 3.3 Nivel API

**Herramienta:** cliente HTTP (Postman / curl), sin sesión de navegador, para probar que el gate no depende del front.

| Endpoint | Servicio | Método | Qué se ejercita |
|---|---|---|---|
| `/grv/logistica/traslados/conflictos-mismo-dia` | `wslogistica` | POST | La matriz de salidas y el filtro de región. Exige JWT (**401** sin token en DEV y TEST) |
| `/grv/turnos/autorizaciones/traslados-duplicados-pendientes` | `wsturnos` | GET | Contador de pendientes. **Global, sin filtro de alcance** (R-2) |
| `/grv/turnos/autorizaciones/mis-duplicados-resueltos` | `wsturnos` | GET | Contador de resueltos no vistos del solicitante |
| `/grv/turnos/autorizaciones/pedir-traslado-duplicado` | `wsturnos` | POST | Alta del pedido; el `idSolicitante` del **body** decide la auto-aprobación |
| `/grv/turnos/autorizaciones/resolver-traslado-duplicado` | `wsturnos` | POST | Aprobar / rechazar; el `idAutorizante` del **body** decide el permiso |
| `/grv/turnos/autorizaciones/marcar-duplicados-vistos` | `wsturnos` | POST | Marcado idempotente de vistos |
| `/grv/turnos/turnos/crear` | `wsturnos` | POST | **Gate 409** |
| `/grv/turnos/turnos/programar-turno` | `wsturnos` | PATCH | **Gate 409** — es el único camino donde `idAutorizacion` se resuelve de verdad |
| `/grv/turnos/turnos/editar` | `wsturnos` | PUT | **No invoca el gate** (`tasks 4.5` abierto) → caso XF |

**Contrato a verificar además del comportamiento:**

- El **409 CONFLICT** debe traer mensaje explicativo. Verificar también que `body` no viene `null` sino la string `"CONFLICT"` — documentado como cosmético, se registra.
- Los seis resultados de la resolución (`SIN_PERMISO`, `YA_RESUELTO`, `NO_ENCONTRADO`, …) **viajan en HTTP 200** (R-9). Se verifica y se registra como deuda de contrato, no como fallo funcional: es una decisión deliberada del equipo que hay que confirmar o corregir.

### 3.4 Nivel BD

**Acceso:** conector de sólo lectura contra **DEV**.

```
python db_dev.py "SELECT ..."
```

> ⚠️ **El MCP de MariaDB apunta a PRODUCCIÓN sobre un primario escribible** (VBD-01). **Está prohibido usarlo en esta certificación.** Toda verificación de base se hace exclusivamente con el conector Python contra DEV. Una consulta de «¿está aplicada la migración?» hecha por el MCP responde por producción y devuelve un falso negativo.

**Tablas y columnas bajo verificación** (nombres confirmados contra el esquema real de DEV):

| Tabla | Columnas relevantes |
|---|---|
| `autorizaciones_traslado_duplicado` | `id_autorizacion_traslado_duplicado`, `id_autorizacion`, `id_traslado`, `id_traslado_transporte_publico`, `estado` (1 pendiente / 2 aprobada / 3 rechazada), `justificacion` (varchar 1000), `id_solicitante`, `fecha_solicitud`, `id_autorizante`, `fecha_autorizacion`, `dictamen` (varchar 1000), `fecha_visto_solicitante` |
| `traslados` | `id_estado_traslado`, **`id_estado_logistica_ida`**, `id_estado_logistica_vuelta`, **`es_duplicado_autorizado`**, `id_motivo_anulacion`, **`observaciones_anulacion`** (sin sufijo `_ida`), `observaciones_anulacion_vuelta`, `id_responsable_anulacion`, `fecha_anulacion`, `requiere_revision` |
| `traslados_transporte_publico` | **`es_duplicado_autorizado` — la columna existe y ningún código la escribe (R-8)** |
| `permisos_sas` / `perfiles_permisos_sas` | El permiso y su asignación por perfil |

**Consultas base del plan** (se referencian por su código en cada caso):

```sql
-- Q1 · Estado completo del pool de pedidos
SELECT id_autorizacion_traslado_duplicado AS id, id_autorizacion, id_traslado,
       id_traslado_transporte_publico AS id_tp, estado, justificacion,
       id_solicitante, fecha_solicitud, id_autorizante, fecha_autorizacion,
       dictamen, fecha_visto_solicitante
FROM autorizaciones_traslado_duplicado
ORDER BY id_autorizacion_traslado_duplicado;
```

```sql
-- Q2 · Efecto persistido sobre el traslado de un turno
SELECT t.id_traslado, t.id_turno, tu.fecha_turno, tu.hora_turno,
       t.id_estado_traslado, t.id_estado_logistica_ida, t.id_estado_logistica_vuelta,
       t.es_duplicado_autorizado, t.id_motivo_anulacion, t.observaciones_anulacion,
       t.id_responsable_anulacion, t.fecha_anulacion, t.requiere_revision
FROM traslados t JOIN turnos tu ON tu.id_turno = t.id_turno
WHERE t.id_turno = <idTurno>;
```

```sql
-- Q3 · Traslados vigentes del paciente en una fecha (el universo del conflicto)
SELECT t.id_traslado, tu.id_turno, tu.fecha_turno, tu.hora_turno,
       t.id_estado_traslado, t.id_estado_logistica_ida
FROM traslados t JOIN turnos tu ON tu.id_turno = t.id_turno
WHERE tu.id_denuncia = 464435
  AND DATE(tu.fecha_turno) = '<AAAA-MM-DD>'
  AND t.id_estado_traslado NOT IN (4, 5)
ORDER BY tu.hora_turno;
```

```sql
-- Q4 · El pedido que vale (criterio D8: el último)
SELECT id_autorizacion_traslado_duplicado, estado, id_autorizante, fecha_autorizacion
FROM autorizaciones_traslado_duplicado
WHERE id_traslado = <idTraslado>
ORDER BY id_autorizacion_traslado_duplicado DESC
LIMIT 1;
```

```sql
-- Q5 · Marca en transporte público (se espera vacía / NULL — R-8)
SELECT id_traslado_transporte_publico, id_turno, es_duplicado_autorizado
FROM traslados_transporte_publico
WHERE id_turno = <idTurno>;
```

```sql
-- Q6 · Permiso y perfiles habilitados
SELECT pf.id_perfil, pf.perfil
FROM perfiles_permisos_sas pp
JOIN permisos_sas  p  ON p.id_permiso = pp.id_permiso
JOIN perfiles_sas  pf ON pf.id_perfil = pp.id_perfil
WHERE p.permiso = 'autorizar_traslado_mismo_dia'
ORDER BY pf.id_perfil;
```

```sql
-- Q7 · Perfiles efectivos de un usuario de prueba
SELECT pps.id_persona, pe.nombre, pe.apellido, pps.id_perfil, ps.perfil
FROM personas_perfiles_sas pps
JOIN personas pe ON pe.id_persona = pps.id_persona
LEFT JOIN perfiles_sas ps ON ps.id_perfil = pps.id_perfil
WHERE pps.id_persona IN (1000007, 1000008);
```

### 3.5 Nivel integración entre servicios

Es el nivel que **ningún test automatizado cubre hoy** (SDD §12.3: *«la integración `wsturnos` → `wslogistica` del rechazo: ni un mock de contrato»*), y por eso se prueba a mano y con evidencia de red.

| Cadena | Disparador | Qué se verifica |
|---|---|---|
| **I-1 · Rechazo** | `resolver-traslado-duplicado` con decisión «rechazar» | `wsturnos.rechazar()` invoca a `wslogistica` **con la transacción de BD abierta** (R-10). Verificar: el traslado queda cancelado con **motivo 16**, la observación **incluye el dictamen**, y `id_estado_logistica_ida` **sigue nulo** |
| **I-2 · Rechazo con `wslogistica` caído** | Igual, con el servicio remoto indisponible | La excepción debe **revertir el UPDATE del pedido**: no puede quedar un pedido rechazado con el traslado vivo. Es el comportamiento deseado del acoplamiento frágil de R-10 |
| **I-3 · Anulación del preexistente** | Salida `ANULAR` desde el bloque | `tramitadores` → `wstraslados /traslado/cancelar-por-turno` → `wslogistica /cancelar-desde-modulo-externo`. Verificar que la respuesta trae el **resultado real por traslado** (`cancelado`, `requiereRevision`, `mensaje`) y **no un 200 vacío** |
| **I-4 · Anulación de todos los tramos** | Salida `ANULAR` sobre un turno con ida, vuelta y transporte público | Los tres tramos cancelados **en una sola transacción**, por el circuito de cancelación existente (D5) |

---

## 4. Criterios de entrada

**Ninguna ejecución arranca sin estos ocho ítems verificados y firmados.** Los tres primeros son de ambiente y son los que hoy dejan a TEST afuera.

| # | Criterio | Cómo se verifica | Estado hoy |
|---|---|---|---|
| **CE-1** | **`wsturnos` desplegado con el código del circuito** | `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` devuelve **200**, no 404. Sobre los tres POST se manda un GET: si la ruta existe el request llega al handler y falla ahí (400/500); si no existe, 404 | ✅ **DEV** · ❌ **TEST** (404 en los cinco) |
| **CE-2** | **`wslogistica` y `listados` desplegados** | `POST /grv/logistica/traslados/conflictos-mismo-dia` → **401** (existe y exige auth) · `GET /grv/listados/motivos-traslados/mismo-dia` → 200 | ✅ DEV y TEST |
| **CE-3** | **La pestaña de pendientes dispara request y filtra** | Abrir «Autorización Doble Traslado Pendiente»: debe verse un request al listado y una grilla **acotada a pedidos**. Si muestra turnos sin filtrar con las columnas del pedido en `-`, el filtro se está descartando en silencio → **ambiente no apto** | ✅ DEV (`1–1 de 1`) · ❌ TEST |
| **CE-4** | **Migración de base aplicada** | La tabla `autorizaciones_traslado_duplicado` existe con `fecha_visto_solicitante`; `traslados.es_duplicado_autorizado` y `traslados_transporte_publico.es_duplicado_autorizado` existen | ✅ DEV, verificado |
| **CE-5** | **Permiso dado de alta y asignado** | **Q6** debe devolver los perfiles habilitados. En DEV: `id_permiso = 1000` (no 101) asignado a los perfiles **2, 3, 9 y 10** | ✅ DEV |
| **CE-6** | **Usuarios de prueba con el perfil correcto** | **Q7**. Confirmado en DEV: `ayioperadort` = persona **1000007**, perfiles 4 y 11 → **sin** permiso. `tramitador.supervisor` = persona **1000008**, perfil **2 jefe_de_siniestros** → **con** permiso | ✅ con salvedad (§8.2) |
| **CE-7** | **Datos de prueba en FECHA FUTURA** | **Q3** sobre la fecha objetivo debe devolver al menos un traslado vigente con `fecha_turno > hoy`. **Con fecha pasada el backend colapsa a `soloInformativo` y habilita una sola salida**, y todo caso de tres salidas queda inejecutable | ⚠️ **verificación obligatoria antes de cada jornada** |
| **CE-8** | **Pedido pendiente limpio disponible** | **Q1**: debe existir al menos un pedido en `estado = 1` cuyo traslado esté **vigente** (`id_estado_traslado NOT IN (4,5)`), en fecha futura y con `id_estado_logistica_ida` nulo | ❌ **hoy no se cumple** — ver §8.4 |

> **CE-7 en una línea, para la checklist diaria:** si `Q3` devuelve un traslado con fecha menor o igual a hoy, el ambiente **no está listo** para los casos de tres salidas. Re-fechar el pool antes de empezar.

### 4.1 Declaración formal sobre TEST

**TEST se declara ambiente NO APTO para esta certificación.** El frontend está desplegado —el bundle de tramitadores es idéntico byte a byte al de DEV— y por eso se ven las pestañas nuevas y las columnas nuevas, pero el backend de `wsturnos` no tiene el código: los cinco endpoints devuelven 404.

El efecto no es un error visible sino **un falso positivo de pantalla**: la grilla de pendientes muestra turnos sin filtrar, que un usuario puede leer como una lista de pedidos que no lo son. **Ningún resultado obtenido en TEST es válido** mientras esto no se resuelva (`tasks 10.3`, requiere `aws sso login`).

Lo que falta es **un solo servicio**: `logistica` y `listados` sí están desplegados en TEST.

---

## 5. Criterios de salida y de aceptación

### 5.1 Criterios de salida de la ejecución

| # | Criterio |
|---|---|
| CS-1 | El **100 %** de los casos de prioridad **P1** ejecutados, sin bloqueos pendientes |
| CS-2 | ≥ **90 %** de los casos P2 ejecutados |
| CS-3 | Cada caso que escribe en base tiene su **verificación de BD ejecutada y su resultado adjunto**. Un caso cerrado sólo con evidencia de pantalla se considera **no ejecutado** |
| CS-4 | Todos los casos **XF** (se espera que fallen) ejecutados y su resultado **confirmado contra la tarea abierta** que lo respalda. Un XF que pasa es tan reportable como uno que falla: significa que la tarea se cerró sin avisar, o que el caso está mal escrito |
| CS-5 | Cero defectos **críticos** abiertos sin decisión de negocio registrada |
| CS-6 | El **rollback del pool ejecutado y verificado** con Q1/Q2 |
| CS-7 | Reporte de ejecución emitido con evidencia por caso |

### 5.2 Criterios de aceptación — condiciones de GO

El GO **no es funcional solamente**. Este circuito puede pasar sus 16 casuísticas y aun así no resolver el problema que lo justifica.

| # | Condición | Tipo | Bloquea el GO |
|---|---|---|---|
| **GO-1** | Las tres salidas del bloque funcionan **end-to-end contra el backend real**, sin stub y con fecha futura | Funcional | **Sí** |
| **GO-2** | Un pedido pendiente **no baja a logística**: `id_estado_logistica_ida` nulo, verificado con Q2 | Funcional | **Sí** |
| **GO-3** | Al aprobar, el traslado **correcto** —el nuevo, no el preexistente— recibe estado de logística y la marca | Funcional | **Sí** |
| **GO-4** | Al rechazar, el traslado se cancela con **motivo 16**, con el dictamen en la observación, y nunca tuvo estado de logística | Funcional | **Sí** |
| **GO-5** | El gate devuelve **409** ante una llamada directa al endpoint, sin pasar por la pantalla | Funcional | **Sí** |
| **GO-6** | Un pedido **rechazado** no habilita el traslado, ni siquiera con un aprobado anterior (criterio del último pedido) | Funcional | **Sí** |
| **GO-7** | El solicitante **recibe el resultado con el dictamen**, y la card se apaga sola de forma idempotente | Funcional | **Sí** |
| **GO-8** | **R-1 cerrado o aceptado por escrito**: confirmación de que los endpoints quedan detrás del gateway en STAGE y PROD. Hoy responden sin token y validan el permiso contra un id del body | Seguridad | **Sí** |
| **GO-9** | **VBD-02 corregido**: el script del permiso no debe fijar `id_permiso = 101`, ya ocupado en producción por `editar_cie10_bloqueado`. Si es `REPLACE` o `ON DUPLICATE KEY UPDATE`, **pisa un permiso ajeno en silencio** | Despliegue | **Sí** |
| **GO-10** | **EST-03 con decisión de negocio registrada**: qué pasa con un pedido que nadie resuelve (SLA, escalamiento, auto-rechazo o baja por defecto). Es el único riesgo con impacto sobre el asegurado | Negocio | **Sí** |
| **GO-11** | **EST-04 cerrado**: confirmar si el perfil 10 (supervisor) entra. En DEV **ya tiene el permiso asignado**, mientras el script lo marca «pendiente de confirmar» y cuatro documentos lo declaran distinto | Negocio | **Sí** |
| **GO-12** | **R-8 con decisión**: un duplicado autorizado de **transporte público** queda sin marca y sin estado de logística. O se implementa, o se declara fuera de alcance por escrito | Funcional | **Sí** |
| **GO-13** | El defecto de **múltiples conflictos** resuelto o aceptado: hoy la salida se aplica sólo al primero y el gestor **cree** haber resuelto todo | Funcional | **Sí** |
| **GO-14** | **EST-02 declarado**: el motivo autodeclarativo sigue habilitando el gate sin permiso ni pedido. O se restringe, o se acepta por escrito que la brecha sigue abierta hasta una fecha X | Negocio | **Sí** |
| **GO-15** | Métrica mínima disponible para medir si los ~285 casos mensuales bajan (`SELECT estado, COUNT(*) FROM autorizaciones_traslado_duplicado GROUP BY estado` expuesta) | Negocio | No — condiciona el post-GO |
| **GO-16** | Nombre accesible en los botones de acción de la grilla | Accesibilidad | No — se registra |

> **Criterio de éxito post-producción, ausente y necesario.** Todo el PRD se apoya en un número —2.156 autorizaciones inexistentes en 2026, validado contra producción en **2.381**— y **no hay ninguna métrica** que permita verificar que baje. El plan no puede certificar el objetivo de negocio, sólo el comportamiento. Se recomienda fijar el criterio antes del GO: *a 60 días, ≥ X % de los duplicados del mes tienen un pedido resuelto, y los declarados sin pedido bajan de 285 a Y*.

---

## 6. Matriz de riesgo → prioridad de prueba

Priorización por **impacto al asegurado** primero y **evitabilidad del control** después. Un control que se puede esquivar no protege nada, por muy bien que funcione cuando se lo usa.

**Escala de prioridad:** **P1** crítico (bloquea GO, se ejecuta primero) · **P2** alto · **P3** medio.

| Riesgo | Origen | Qué pasa si no se controla | Impacto | Evitabilidad | **Prio** | Casos |
|---|---|---|---|---|---|---|
| **EST-03** — pedido pendiente sin SLA ni alerta | Análisis estático | El traslado queda invisible para logística de forma indefinida. **El paciente no viaja**, se descubre el día del turno, ningún actor recibe señal. Es una **regresión**: hoy se paga un viaje de más, con el circuito el paciente se queda a pie | **Asegurado** | Estructural | **P1** | ATD-12, VDL-02 |
| **R-1** — endpoints sin autenticación, permiso contra un id del body | PRD §10 / SDD / **VAP-06 confirmado** | Cualquiera aprueba su propio duplicado pasando el id de un supervisor. **El control desaparece por completo** | Económico + integridad | **Trivial** | **P1** | SEG-01…SEG-05 |
| **EST-02** — el motivo autodeclarativo sigue habilitando el gate | Análisis estático | Los 2.156 casos anuales se siguen generando por el mismo camino, ahora **validados por el gate server-side**. El Bloque 4 no cierra la brecha que dice cerrar | Económico | Trivial | **P1** | GST-05, GST-06 |
| **EST-15 / `tasks 7.3`** — sólo se resuelve el primer conflicto | Evidencia de campo (`useConflictoTraslado.js:44`) | Se anula uno y quedan dos duplicados en pie. **El gestor cree haberlo resuelto**. Produce exactamente el gasto que el change viene a evitar | Económico | Silencioso | **P1** | CTM-06 **XF** |
| **R-8** — la marca nunca se escribe para transporte público | SDD / **confirmado en base** | Un duplicado de TP autorizado queda **sin marca y sin estado de logística**: invisible para el sector y cancelable como duplicado si alguna vez baja. En rehabilitación es el traslado más frecuente | Asegurado + económico | Estructural | **P1** | VDL-06 **XF**, GST-11 |
| **D1 / RF-3.2** — la llave de visibilidad | PRD / design | Si el pendiente bajara a logística, el sector lo cancelaría como duplicado: el ruido exacto que el circuito evita | Operativo | — | **P1** | VDL-01, VDL-02 |
| **RF-4.3 / D8** — el rechazo no debe habilitar | PRD / design | Alcanzaría con pedir la excepción y que la nieguen para cargar el traslado igual | Económico | Trivial | **P1** | GST-07, GST-08, ATD-11 |
| **EST-06** — el rechazo se neutraliza volviendo a pedir | Análisis estático | El rechazo es un obstáculo de un intento, no una decisión firme. Y quien recibe el segundo pedido **no sabe que ya fue rechazado** | Económico | Trivial | **P2** | ATD-14 |
| **VBD-02** — el script del permiso colisiona en producción | Verificación de base | Aborta la migración, o **pisa el permiso de CIE-10 en silencio** y deja a esos usuarios sin su funcionalidad | Colateral grave | — | **P1** | Criterio GO-9 (no es caso de prueba) |
| **EST-04** — el perfil supervisor sin confirmar | Análisis estático | Ese usuario es el actor de C-05 o el de C-04 —resultados opuestos—. **Sin la decisión, esos casos no tienen resultado esperado** | Bloquea la certificación | — | **P1** | Criterio GO-11 |
| **`tasks 3.9`** — dictamen obligatorio sólo en el formulario | tasks abierto | Una llamada directa rechaza sin dictamen. El rechazo llega al gestor sin explicación, que es lo que RF-2.6 quiere impedir | Operativo | Trivial | **P2** | ATD-08 **XF** |
| **`tasks 4.5`** — `PUT /turnos/editar` no invoca el gate | tasks abierto / SDD §6.3 | Se carga un duplicado editando en lugar de creando. Además puede darle estado de logística a un traslado pendiente, y entonces el rechazo posterior **cancela un viaje que la agencia ya coordinó** | Económico | Trivial | **P2** | GST-09 **XF**, VDL-03 |
| **`tasks 4.6` / D9** — la tanda esquiva el gate | tasks abierto | Una tanda de rehabilitación carga duplicados sin control, y el corte total de D9 no existe en ninguna capa | Económico | Trivial | **P2** | GST-10 **XF**, CTM-08 |
| **`tasks 4.7`** — no se detectan duplicados de la misma operación | tasks abierto | Dos turnos con traslado en la misma fecha dentro de una misma tanda no se ven entre sí | Económico | Trivial | **P2** | GST-12 **XF** |
| **R-2** — contador global vs. grilla filtrada | PRD §10 / SDD | Quien autoriza ve «3 pendientes» y una grilla vacía, y concluye que no hay nada que hacer | Operativo | Silencioso | **P2** | ATD-05 |
| **R-3** — pedido de otra cartera sin resolutor | PRD §10 | Existen pedidos que **estructuralmente nadie ve**. Alimenta EST-03 | Asegurado | Estructural | **P2** | ATD-12 (parcial, §11) |
| **R-22** — el gerente ve la pestaña pero nunca la card | SDD | Uno de los cuatro perfiles habilitados no tiene disparador. Y la spec declara que el perfil **no** es criterio | Operativo | — | **P3** | ATD-06 (§11: sin usuario) |
| **R-7** — `resolver()` sin control de concurrencia | SDD | Dos resoluciones simultáneas pueden pisarse: RF-2.8 no está garantizado, sólo es probable | Integridad | Baja probabilidad | **P3** | §11 — no reproducible |
| **R-21 / EST-17** — la marca compite con otras señales | SDD / análisis | Con `requiereRevision` la marca **desaparece de las dos capas**: es el escenario que RF-3.4 quiere evitar | Económico | Silencioso | **P2** | VDL-07 (observación) |
| **R-11** — sin `@Size` en justificación y dictamen | SDD | Un texto de 2000 caracteres pasa la validación y explota en el INSERT como 500 con el mensaje crudo de JDBC | UX / contrato | Trivial | **P3** | ATD-09 **XF** |
| **R-9** — los resultados viajan en HTTP 200 | SDD | Un cliente que sólo mire el status no distingue un rechazo de permiso de una aprobación exitosa | Contrato | — | **P3** | SEG-03, ATD-10 |
| **`tasks 5.5`** — el tooltip no nombra al autorizante | tasks abierto | Logística ve «duplicado autorizado» genérico y no sabe quién lo autorizó | Trazabilidad | — | **P3** | VDL-08 **XF** |
| **`tasks 7.14`** — si el endpoint de conflictos falla, el bloque desaparece | tasks abierto | Desaparece la única forma de declarar el motivo, y el backend rechaza al guardar. El gestor queda sin salida | Operativo | Silencioso | **P2** | CTM-14 **XF** |
| **`tasks 7.15`** — copy contradictorio | tasks abierto | «Estado: SOLICITADO» junto a «el viaje ya empezó» | UX | — | **P3** | CTM-15 |
| **Accesibilidad** — botones sin nombre accesible | **Confirmado en DEV y TEST** | `<img alt="icon">` sin `title` ni `aria-label`: inoperable con lector de pantalla | Accesibilidad | — | **P3** | ATD-13 **XF** |
| **EST-05** — la política de salidas no está en ningún artefacto normativo | Análisis estático | El resultado esperado de un caso depende de `wslogistica.conflicto-traslado.horas-minimas-anulacion`, configurable por ambiente y nunca validado por negocio | Testabilidad | — | **P2** | CTM-09…CTM-13 (contra configuración, no contra requisito) |
| **EST-12** — la regla de región es más amplia en la spec que en el código | Análisis estático | Si alguien implementa contra la spec, deja de detectar duplicados reales de consulta y cirugía | Económico | — | **P3** | CTM-16 |

---

## 7. Escenarios de prueba por capability

**Convenciones de esta sección.**
`P1/P2/P3` prioridad · `XF` = **caso que se espera que falle**, con la tarea abierta que lo respalda · `OBS` = se ejecuta como observación con evidencia porque el requisito no fija un resultado esperado objetivo · Cada caso declara **capa**, **trazabilidad** (RF · Scenario de spec · casuística C-xx) y **verificación en BD** cuando escribe.

### 7.1 `conflicto-traslado-mismo-dia` (CTM) — el bloque de conflicto

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **CTM-01** | Paciente **sin** traslado vigente en la fecha: se carga el turno con traslado y **no aparece el bloque** | UI + BD | P1 | RF-1.1 · **C-01** | **Q3** sobre la fecha debe devolver 0 filas antes; después, el traslado nuevo con su estado normal |
| **CTM-02** | Paciente **con** traslado vigente: aparece el bloque identificando el preexistente por **número de turno, tipo, hora, centro médico y agencia** | UI | P1 | RF-1.1, RF-1.2 · *Segundo traslado en una fecha con uno vigente* · C-02…C-05 | **Q3** confirma el vigente que el bloque muestra |
| **CTM-03** | El único traslado de la fecha está **Cancelado (4)** o **Rechazado (5)**: **no** hay bloque | UI + BD | P1 | RF-1.1 · *Un traslado cancelado no genera conflicto* | **Q3** devuelve 0 filas |
| **CTM-04** | El bloque muestra el **estado operativo**: estado de logística y si a la agencia ya se le avisó | UI | P2 | RF-1.2 · *El bloque muestra el estado operativo* | — · **ver §11**: el dato «agencia informada» no se puede generar desde la aplicación |
| **CTM-05** | **Ningún identificador interno** en el bloque, la grilla, el drawer de resolución ni las cards | UI | P1 | **RF-5.1**, D10 · *Ningún identificador interno llega a la pantalla* | — |
| **CTM-06** | **Dos o más traslados vigentes en la misma fecha**: el bloque los expone **todos** y la salida elegida se aplica **sobre todos** | UI + BD | **P1 · XF** | Spec CTM *Varios traslados vigentes* · `tasks 7.3` marcado `[x]` y **desmentido por la evidencia** (`useConflictoTraslado.js:44` toma `fechasConConflicto[0].traslados[0]`) | **Q3** después de anular: se espera que **queden vigentes los demás**, que es el defecto |
| **CTM-07** | Elegir una salida **excluye** las otras dos | UI | P2 | RF-1.3 · *Elegir una salida deshabilita las otras* | — |
| **CTM-08** | **Tanda de rehabilitación** con varias fechas en conflicto: el bloque informa **en cuántas fechas** hay conflicto, identificándolas | UI | P2 | RF-1.5 · *Tanda con conflicto en varias fechas* · **C-13** | **Q3** por cada fecha de la tanda |
| **CTM-09** | Salida **`resoluble`**: traslado Solicitado, fecha futura con margen, sin monto → **las tres salidas habilitadas** | UI + API | P1 | RF-1.3, RF-1.4, D2 · *El backend habilita y el front sólo renderiza* | `salidas` de la respuesta vs. lo renderizado |
| **CTM-10** | Salida **`sinAnular`**: faltan **menos de 3 h** para el viaje → sin «anular», con las otras dos | UI + API | P2 | SDD §5.4 guarda 3 · EST-05 | Se valida **contra la configuración**, no contra el requisito: `horas-minimas-anulacion` no está declarado en ningún documento funcional |
| **CTM-11** | Salida **`soloInformativo`** por **viaje en curso**: `horasAlViaje <= 0` → sólo se informa | UI + API | P2 | Spec CTM *Un viaje en curso es sólo informativo* | — |
| **CTM-12** | Salida **`soloInformativo`** por **facturable**: traslado Realizado o con monto > 0 → no se puede anular, y el bloque **explica por qué** | UI + API | P2 | Spec CTM *Un traslado ya realizado no se puede anular* | **Q2** confirma `id_estado_logistica_ida ∈ {4,5,8}` o monto > 0 |
| **CTM-13** | Existe una **cuarta bandera** en la respuesta, `puedeDerivarALogistica`, que no está en ningún documento funcional | API | P3 · **OBS** | EST-16 · RF-1.3 dice «exactamente tres» | Registrar el valor observado en cada rama; no hay resultado esperado |
| **CTM-14** | El endpoint de conflictos **falla**: hoy el bloque desaparece y con él la única forma de declarar el motivo, y el backend rechaza al guardar | UI | **P2 · XF** | `tasks 7.14` abierto | Verificar que el guardado devuelve **409** con el bloque ausente: el gestor queda sin salida |
| **CTM-15** | **Copy contradictorio**: «Estado del traslado: SOLICITADO» junto a «el viaje ya empezó» | UI | P3 · XF | `tasks 7.15` abierto · defecto 4 no reproducido por falta de datos | Requiere un traslado con viaje ya iniciado |
| **CTM-16** | Dos traslados de **regiones del cuerpo distintas** que **no** son plan de rehabilitación: **sí** deben ser duplicado | UI + API | P3 | EST-12 · la spec enuncia la regla sin la condición de rehabilitación que sí tiene el código | Confirmar que el conflicto aparece |

**Salida «anular el preexistente» — subgrupo con efecto en base:**

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **CTM-17** | Anular el preexistente: se cancela el viejo **con motivo y observación** y el nuevo sigue | UI + BD | P1 | RF-3.6 · **C-02** | **Q2** sobre el turno viejo: `id_estado_traslado = 4`, `id_motivo_anulacion` informado, `observaciones_anulacion` con texto, `id_responsable_anulacion` y `fecha_anulacion` cargados |
| **CTM-18** | La observación de anulación nombra el turno por **tipo y hora**, con quién anuló y cuándo, **sin ningún identificador** y sin escapado HTML | BD | P1 | RF-5.1, D10 · *La observación de anulación no nombra identificadores* | **Q2** — inspeccionar el literal de `observaciones_anulacion`: no debe contener el número de turno ni secuencias tipo `&#x2F;` |
| **CTM-19** | La anulación alcanza **todos los tramos**: ida, vuelta y transporte público, en una sola transacción | BD | P1 | RF-3.6, D5 · *La anulación alcanza todos los tramos* | **Q2** (`id_motivo_anulacion` e `id_motivo_anulacion_vuelta`) + **Q5** |
| **CTM-20** | **La anulación no se concreta** (prestador rechaza la baja o tramo facturable): el bloque lo informa **antes de guardar** y **las otras salidas siguen disponibles** | UI + API | P1 | RF-3.7 · **C-14** · *La anulación falla y el gestor lo ve* | **Q2**: el traslado **sigue vigente**; nada se guardó |
| **CTM-21** | La respuesta de `cancelar-por-turno` trae el **resultado real por traslado** y no un 200 vacío | API | P1 | RF-3.7, D5 · *El llamador recibe el resultado real* | Inspeccionar `resultado`, `cancelado`, `requiereRevision`, `mensaje`, `origen` |

**Salida «guardar sin traslado»:**

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **CTM-22** | Elegir «sin traslado»: se **destilda** «requiere traslado», desaparecen los campos obligatorios del traslado, se habilita «Siguiente» y **el turno se guarda solo** | UI + BD | P1 | RF-1.3 · **C-03** — **casuística huérfana: ninguna spec tiene un solo Scenario para esta salida** (EST-13) | **Q3**: la cantidad de traslados vigentes de la fecha **no cambia**; el turno nuevo existe **sin** fila en `traslados` |

### 7.2 `autorizacion-traslado-duplicado` (ATD) — pedir y resolver

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **ATD-01** | Gestor **sin** permiso elige «pedir autorización», escribe justificación y guarda: el pedido queda **pendiente** a su nombre y **el turno se guarda** | UI + BD | P1 | RF-2.1 · **C-04** · *El gestor sin permiso pide la autorización* | **Q1**: nueva fila con `estado = 1`, `id_solicitante = 1000007`, `fecha_solicitud` cargada, `id_autorizante` y `fecha_autorizacion` **nulos**. **Q2**: el traslado existe con **`id_estado_logistica_ida` NULO** |
| **ATD-02** | **Sin justificación no hay pedido**: el sistema lo rechaza (desde la pantalla **y** desde el endpoint) | UI + API | P1 | RF-2.1 · *Sin justificación no hay pedido* | **Q1**: no se crea ninguna fila |
| **ATD-03** | **El pedido apunta al traslado NUEVO**, no al preexistente | BD | **P1** | D3 · *El pedido apunta al traslado nuevo* — es la corrección del defecto más profundo que tuvo el circuito | **Q1** → tomar `id_traslado` del pedido creado y confirmar con **Q2** que corresponde al **turno recién creado**, no al que ya existía |
| **ATD-04** | Gestor **con** permiso elige «autorizar los dos»: el pedido se registra **aprobado en el acto**, con esa persona como solicitante **y** autorizante, y el traslado baja a logística | UI + BD | P1 | RF-2.2 · **C-05** · *Auto-aprobación de quien tiene el permiso* | **Q1**: `estado = 2`, `id_solicitante = id_autorizante = 1000008`. **Q2**: `id_estado_logistica_ida = 1` y `es_duplicado_autorizado = 1` |
| **ATD-05** | La **card de pendientes** aparece en el home de quien autoriza, con el contador, y lleva a la grilla filtrada. **Comparar el número de la card con la cantidad de filas de la grilla** | UI + API | P2 | RF-2.4 · *La card aparece con pedidos pendientes* · **R-2** | **Q1** con `WHERE estado = 1` — el contador es **global** (`countByEstado(1)`, sin filtro de alcance) y el listado está acotado: se espera divergencia |
| **ATD-06** | **Sin el permiso** no hay card de pendientes **ni pestaña** de la grilla de autorizaciones | UI | P1 | RF-2.4 · *Sin el permiso no hay card ni grilla* | — |
| **ATD-07** | **Sin pedidos pendientes** la card **no se muestra** | UI | P2 | RF-2.4 · *Sin pedidos la card no se muestra* | **Q1** con `estado = 1` → 0 filas |
| **ATD-08** | La grilla muestra **solicitante, fecha del pedido y justificación** en cada fila, y las tres acciones: ver detalle, gestionar autorización, ver información de traslado | UI | P1 | RF-2.5 · *La fila da el contexto para decidir* | — |
| **ATD-09** | «Ver información de traslado» **abre el modal** con los datos del traslado en conflicto | UI | P2 | RF-2.5 · *Ver información del traslado* — **defecto ya corregido**, se prueba como confirmación | — |
| **ATD-10** | **Aprobar** un pedido pendiente desde el drawer, **sin dictamen** (es opcional al aprobar) | UI + BD | P1 | RF-2.6 · **C-06** · *Aprobación sin dictamen* | **Q1**: `estado = 2`, `id_autorizante` y `fecha_autorizacion` cargados, `dictamen` nulo. **Q2**: `id_estado_logistica_ida = 1`, `es_duplicado_autorizado = 1` |
| **ATD-11** | **Rechazar con dictamen** desde el drawer | UI + BD | P1 | RF-2.6 · **C-07** | **Q1**: `estado = 3`, `dictamen` con texto. **Q2**: `id_estado_traslado = 4`, `id_motivo_anulacion = 16`, `observaciones_anulacion` **conteniendo el dictamen**, `id_estado_logistica_ida` **nulo** |
| **ATD-12** | **Rechazar sin dictamen**: no se permite. Probar **desde la pantalla y llamando al endpoint directamente** | UI + API | **P1 · XF (API)** | RF-2.6 · **C-08** · *Rechazo sin dictamen* — la spec exige enforcement **server-side**; **`tasks 3.9` está abierto**: hoy la obligatoriedad vive sólo en el formulario | **Q1**: se espera que la llamada directa **sí** rechace y deje `estado = 3` con `dictamen` nulo — eso es el defecto |
| **ATD-13** | **Pedido ya resuelto por otro**: el segundo recibe un **aviso** con quién resolvió y cuándo, su decisión **no se aplica**, y la grilla se refresca. **No debe presentarse como error** | UI + API | P1 | RF-2.7, RF-2.8 · **C-09** · *Dos personas abren el mismo pedido* | **Q1**: `id_autorizante` y `fecha_autorizacion` **no cambian** |
| **ATD-14** | **Idempotencia**: la misma resolución enviada dos veces no altera estado, autorizante ni fecha | API + BD | P1 | RF-2.8 · *La resolución es idempotente* | **Q1** antes y después: idénticos |
| **ATD-15** | **El pedido que vale es el último**: un traslado con un pedido **aprobado** y después uno **rechazado** queda como rechazado en las tres puntas (grilla, validador, consulta) | API + BD | **P1** | D8 · *Un rechazo posterior no se neutraliza con un aprobado viejo* — había **tres criterios distintos** en el código | **Q4** debe devolver `estado = 3`. Confirmar además que el traslado **no** aparece en la grilla de pendientes y que el gate **rechaza** (enlaza con GST-08) |
| **ATD-16** | **Justificación de más de 1000 caracteres** enviada por API | API | **P3 · XF** | R-11 — sin `@Size`, pasa la validación y explota en el INSERT | Se espera **500 con mensaje crudo de JDBC** en lugar de un 400 |
| **ATD-17** | Los resultados de la resolución (`SIN_PERMISO`, `YA_RESUELTO`, `NO_ENCONTRADO`) viajan en **HTTP 200** | API | P3 · OBS | R-9 — deuda de contrato deliberada, a confirmar o corregir | Registrar el status y el payload de cada rama |
| **ATD-18** | **Botones de acción de la grilla sin nombre accesible** | UI | **P3 · XF** | **Confirmado abierto en DEV y TEST**: `<button class="MuiIconButton-root"><img src="…svg" alt="icon"></button>`, sin `title` ni `aria-label` | — |
| **ATD-19** | **Reintento después de un rechazo**: el gestor vuelve a cargar el turno y vuelve a pedir. ¿Se permite? ¿Quien recibe el segundo pedido ve que ya fue rechazado una vez? | UI + BD | **P2 · OBS** | **EST-06** — ningún artefacto declara la regla. Por RF-4.2 un pedido **pendiente** habilita el guardado | **Q1**: se espera una **segunda fila pendiente** sobre el mismo traslado, sin ninguna señal del rechazo anterior. **Es un hueco de regla de negocio, no un defecto de código** |

### 7.3 `devolucion-resultado-solicitante` (DRS) — el resultado vuelve

> **Capability confirmada como implementada en DEV** (VAP-03). El PRD §7.1 (H-1, H-2) y el SDD §10 están desactualizados. **No hay ninguna casuística C-xx para este bloque**: la tabla §8 del PRD quedó congelada en la versión del 14/08 (EST-13). La trazabilidad es contra los Scenarios de la spec.

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **DRS-01** | Un pedido del gestor se resuelve: su home muestra la **card con el contador** de resueltos no vistos | UI + API | **P1** | *El gestor ve el resultado de su pedido* · RF-2.9 | **Q1**: `estado ∈ {2,3}`, `id_solicitante = 1000007`, **`fecha_visto_solicitante` NULA**. El endpoint `mis-duplicados-resueltos` debe devolver > 0 |
| **DRS-02** | Al entrar, la pestaña «Autorización Doble Traslado Resuelta» lista, por cada pedido: **Resultado**, **Lo resolvió** (por nombre), **Fecha**, **Dictamen** y **Mi justificación** | UI | **P1** | *El gestor ve el resultado* · *El autorizante se nombra por su nombre* | Contrastar los textos de pantalla con `justificacion` y `dictamen` de **Q1** |
| **DRS-03** | **Un rechazo llega con su explicación**: el dictamen que se hizo obligatorio al rechazar es visible para quien pidió | UI | **P1** | *Un rechazo llega con su explicación* · cierra **H-1** | **Q1**: el `dictamen` de la fila coincide literalmente con lo que muestra la pantalla |
| **DRS-04** | **Leer los resultados apaga la card**: al entrar quedan marcados como vistos y la card desaparece | UI + BD | P1 | *Leer los resultados apaga la card* | **Q1**: `fecha_visto_solicitante` pasa de nula a cargada. `marcar-duplicados-vistos` devuelve la cantidad marcada |
| **DRS-05** | **Volver a entrar no altera lo ya visto**: la fecha del primer visto **no se repisa** y la card no reaparece | UI + BD | P1 | *Volver a entrar no altera lo ya visto* — idempotencia | **Q1**: `fecha_visto_solicitante` idéntica a la del paso anterior. `marcar-duplicados-vistos` debe devolver **0** |
| **DRS-06** | **Un pedido nuevo vuelve a encender la card**, contando **únicamente** el no visto | UI + BD | P2 | *Un pedido nuevo vuelve a encender la card* | **Q1**: contar filas con `fecha_visto_solicitante IS NULL` y comparar con el contador |
| **DRS-07** | **Quien autoriza NO ve la card de resultados**, y **nunca las dos a la vez**: el supervisor ve «…Pendiente», el operador ve «…Resuelta» | UI | P1 | RF-2.10 · *Quien autoriza no ve la card del resultado* · *Cada perfil ve sólo la pestaña que le corresponde* | — |
| **DRS-08** | **Ninguna pestaña se renderiza vacía o sin texto** para ningún perfil | UI | P2 | *Cada perfil ve sólo la pestaña que le corresponde* · `tasks 7.11` | — |
| **DRS-09** | **Nomenclatura idéntica** entre la card del home y la pestaña de la grilla, en los dos perfiles | UI | P2 | *El mismo nombre en la card y en la pestaña* | — |
| **DRS-10** | **Paginación del marcado de vistos**: con más resueltos de los que entran en una página, ¿se marcan todos o sólo los visibles? | UI + BD | P3 · **OBS** | **EST-22** — el requisito admite **dos lecturas con resultados opuestos** | **Q1**: contar cuántas filas recibieron `fecha_visto_solicitante`. Registrar el comportamiento observado; no hay resultado esperado declarado |

### 7.4 `gate-servidor-traslado-duplicado` (GST) — el gate no vive en el front

> Todos estos casos se ejecutan **con cliente HTTP, sin sesión de navegador**. Es el punto del plan: el gate tiene que valer también para quien no pasa por la pantalla.

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **GST-01** | `POST /turnos/crear` con segundo traslado del día, **sin motivo y sin pedido** → **409 CONFLICT** con mensaje explicativo, y **no se crea ni el turno ni el traslado** | API + BD | **P1** | RF-4.1 · **C-10** · *Alta de un duplicado sin motivo ni pedido* | **Q3** antes y después: la cantidad de vigentes **no cambia** |
| **GST-02** | El mismo caso, llamando **directamente al endpoint sin pasar por la pantalla** | API | **P1** | *El gate no se puede esquivar desde afuera del frontend* | Ídem |
| **GST-03** | Turno **sin traslado** (`requiereTraslado` false o null) → el gate **no interviene** | API | P2 | *Sin traslado o sin fecha no hay nada que validar* · **C-03** | El turno se crea |
| **GST-04** | Turno **sin fecha** (plan de rehabilitación): **no se valida al crear** | API | P2 | **C-15** · *Sin traslado o sin fecha no hay nada que validar* | El turno se crea |
| **GST-05** | El mismo turno **sí se valida al programar** (`PATCH /programar-turno`) | API + BD | P2 | **C-15** — la spec cubre el «no valida al crear» y **no** el «sí valida al programar» (EST-13) | **Q2** tras programar |
| **GST-06** | Alta con **motivo declarado** por un usuario **sin** el permiso → **el gate acepta sin consultar pedidos** | API + BD | **P1** | RF-4.2 · *Con motivo declarado no se consulta el estado de los pedidos* · **EST-02** | **Q1**: **no** se crea ningún pedido. **Q2**: el traslado se crea normalmente. **Este caso demuestra que la brecha de 2.156 casos anuales sigue abierta** |
| **GST-07** | Alta con **`idMotivoTrasladoMismoDia` inventado**, que no existe en el catálogo | API | P2 | SDD §6.4: *el motivo no se valida contra el catálogo, cualquier `Long` no nulo alcanza* | Se espera que **acepte**. Registrar |
| **GST-08** | Programación con pedido **PENDIENTE** → el gate **acepta**, y el traslado queda **sin estado de logística** | API + BD | P1 | RF-4.2 · **C-12** · *Pedido pendiente habilita el guardado* | **Q2**: `id_estado_logistica_ida` nulo |
| **GST-09** | Programación con pedido **APROBADO** → el gate acepta | API + BD | P1 | RF-4.2 · *Pedido aprobado habilita el guardado* | **Q4** devuelve `estado = 2` |
| **GST-10** | Programación con pedido **RECHAZADO** → **409 CONFLICT**, no guarda | API + BD | **P1** | RF-4.3 · **C-11** · *Un pedido rechazado no habilita el traslado* | **Q4** devuelve `estado = 3`; **Q2** confirma que nada se guardó |
| **GST-11** | Traslado con un pedido **aprobado** y después uno **rechazado** → el gate **rechaza**, porque vale el último | API + BD | **P1** | RF-4.3, D8 · *Un pedido rechazado no se neutraliza con uno aprobado anterior* | **Q4** |
| **GST-12** | **`PUT /turnos/editar`** que hace caer el traslado en una fecha con un vigente → debería aplicar el gate | API + BD | **P2 · XF** | Spec GST *La edición de un turno también valida* · **`tasks 4.5` abierto**, el camino no invoca el validador (sí invoca SE-214) | **Q3**: se espera que el duplicado **se cargue igual** |
| **GST-13** | **Programación en tanda de rehabilitación** con una fecha en conflicto → debería cortar **todas** las fechas | API + BD | **P2 · XF** | Spec GST *Un conflicto en la tanda corta todas las fechas* · D9 · **`tasks 4.6` abierto** | **Q3** por fecha: se espera que la tanda se programe igual, **parcial o completa** |
| **GST-14** | **Dos turnos con traslado del mismo paciente en la misma fecha dentro de una misma tanda**, sin ninguno previo | API + BD | **P2 · XF** | Spec GST *Dos fechas iguales dentro de una misma tanda* · **`tasks 4.7` abierto** | **Q3**: se espera que **no se detecten entre sí** |
| **GST-15** | `POST /autorizaciones/generar-autorizacion` — camino que **no** invoca el validador | API | P3 · XF | RF-4.4 · SDD §6.3 | Registrar |
| **GST-16** | **Transporte público preexistente** + turno nuevo con traslado de agencia: `wslogistica` lo cuenta para el conflicto y `wsturnos` **no** | UI + API + BD | **P2 · XF** | **EST-08** · `tasks 5.4` abierto | Se espera **divergencia**: el bloque muestra el conflicto y el gate no lo bloquea, o al revés. **Q3** + **Q5** |
| **GST-17** | **Denuncia cerrada o rechazada** + traslado duplicado: **cuál de los dos 409 gana** (SE-214 vs. gate de duplicado) y qué mensaje ve el gestor | API | P3 · **OBS** | **C-16 — casuística huérfana**: ninguna spec menciona SE-214 ni la precedencia entre los dos gates (EST-13) | Registrar el mensaje devuelto. **No hay resultado esperado declarado** |
| **GST-18** | El **contrato del 409**: mensaje explicativo presente; `body` viene como la string `"CONFLICT"`, no `null` | API | P3 · OBS | SDD §4.5 — el javadoc dice «body null» y está equivocado | Registrar el payload literal |

### 7.5 `visibilidad-duplicado-logistica` (VDL) — qué ve el sector

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **VDL-01** | Un traslado con **`id_estado_logistica_ida` nulo** —cualquiera sea su estado de traslado— **no aparece** en la grilla de logística | UI + BD | **P1** | RF-3.1 · *Un traslado con estado de logística nulo no aparece en la grilla* | **Q2** confirma el nulo; la grilla del sector confirma la ausencia |
| **VDL-02** | **Pedido pendiente: logística NO lo ve.** El traslado se crea con estado de logística nulo y **no pasa a «Solicitado»** | UI + BD | **P1** | RF-3.2, D1 · **C-04** · *El traslado pendiente no baja al sector* | **Q2**: `id_estado_logistica_ida` **NULO** |
| **VDL-03** | **Dos redes independientes**: si se toca el **estado del traslado** de un pendiente, sigue invisible para logística | BD + UI | P2 | RF-3.8, D1 · *Tocar el estado del traslado no lo hace visible* | **Q2**: `id_estado_logistica_ida` sigue nulo. **Este caso es hoy un supuesto, no una invariante garantizada** (EST-10): `PUT /turnos/editar` es un camino documentado que puede tocarlo. Enlaza con GST-12 |
| **VDL-04** | **Al aprobar, el traslado baja marcado**: estado de logística **Solicitado** y `es_duplicado_autorizado` encendido; aparece en la grilla con **franja, ícono con tooltip y entrada en la leyenda** | UI + BD | **P1** | RF-3.3, RF-3.4 · **C-06** · *Al aprobar, el traslado baja marcado* | **Q2**: `id_estado_logistica_ida = 1` **y** `es_duplicado_autorizado = 1` |
| **VDL-05** | **Viaje de ida y vuelta**: ambos tramos reciben estado de logística. En un viaje de sólo ida, el tramo de vuelta queda **nulo** | BD | P2 | *Un viaje de ida y vuelta recibe estado en los dos tramos* | **Q2**: `id_estado_logistica_vuelta` cargado o nulo según el tipo de viaje |
| **VDL-06** | **Duplicado autorizado de transporte público**: debería recibir la marca | UI + BD | **P1 · XF** | *La marca alcanza al transporte público* · **R-8 confirmado en base**: la columna existe y ningún código la escribe · `tasks 5.4` abierto | **Q5**: se espera `es_duplicado_autorizado` **NULO**, y sin estado de logística → **invisible para el sector y cancelable como duplicado**. Es un agujero funcional, no cosmético |
| **VDL-07** | **Convivencia de señales**: una fila que es a la vez **duplicado autorizado** y **requiere revisión** | UI | **P2 · OBS + XF** | *La marca convive con la señal de requiere revisión* · **R-21**: la franja y el ícono usan cadenas de precedencia **distintas** · **EST-17**: RF-3.4 no declara precedencia, así que «distinguibles» no es verificable | **Q2** con `requiere_revision = 1` **y** `es_duplicado_autorizado = 1`. Se espera que **la marca desaparezca de las dos capas**. Documentar con captura |
| **VDL-08** | El **tooltip nombra a quien autorizó** | UI | **P3 · XF** | H-4 · `tasks 5.5` abierto — el front espera el nombre y **el backend no lo manda**, así que cae al texto genérico «duplicado autorizado» | — |
| **VDL-09** | **Al rechazar, logística nunca se enteró**: el traslado se cancela con **motivo 16**, la observación incluye el dictamen, y el traslado **nunca** tuvo estado de logística | UI + BD | **P1** | RF-3.5 · **C-07** · *Al rechazar, el traslado se cancela sin haber pasado por el sector* | **Q2**: `id_estado_traslado = 4`, `id_motivo_anulacion = 16`, `observaciones_anulacion` conteniendo el dictamen, `id_estado_logistica_ida` **nulo**. Y confirmar en la grilla del sector que nunca apareció |
| **VDL-10** | **Anular el preexistente: logística SÍ participa** — es el único caso donde el sector ya tenía el traslado. Verificar que **ve la cancelación** | UI + BD | P1 | RF-3.6 · **C-02**, columna «Logística ve la cancelación» — **ningún Scenario lo verifica hoy** | **Q2** + confirmación en la grilla del sector |

### 7.6 Seguridad del circuito (SEG)

> **R-1 es el riesgo abierto de mayor severidad del change, y está confirmado con evidencia propia** (VAP-06): las sondas a `wsturnos` respondieron a un `curl` desde una máquina de escritorio, **sin credencial**, en DEV y en TEST.

| ID | Caso | Capa | Prio | Trazabilidad | Verificación |
|---|---|---|---|---|---|
| **SEG-01** | Los cinco endpoints de `wsturnos` responden **sin token de autenticación** | API | **P1 · XF** | R-1 · `tasks 10.4` abierto — `AutorizacionesController` no tiene `@PreAuthorize`, `@Secured` ni `@RolesAllowed` | Ejecutar cada uno sin credencial y registrar el status |
| **SEG-02** | **Aprobar un pedido pasando el `idAutorizante` de un supervisor** desde un cliente sin sesión: el permiso se valida contra el id **del body**, no contra el llamante | API + BD | **P1 · XF** | R-1 — *«alguien puede aprobar su propio duplicado pasando el identificador de un supervisor»* | **Q1**: se espera que el pedido quede **aprobado**, con `id_autorizante` = el id suplantado. **Es la demostración de que el control es evitable** |
| **SEG-03** | **Pedir una autorización pasando el `idSolicitante` de alguien con el permiso**: el `idSolicitante` del body decide la **auto-aprobación** | API + BD | **P1 · XF** | R-1 · `pedir()` | **Q1**: se espera `estado = 2` sin que nadie con autoridad haya intervenido |
| **SEG-04** | Resolver con un `idAutorizante` **sin** el permiso → `SIN_PERMISO`. Verificar que el resultado **viaja en HTTP 200** y no en 403 | API | P2 | R-9 | Registrar status y payload |
| **SEG-05** | `wslogistica /traslados/conflictos-mismo-dia` **exige JWT**: sin token devuelve **401** | API | P1 | Contraste positivo: el servicio bien configurado del circuito | Confirmar 401 |

### 7.7 Integración entre servicios (INT)

| ID | Caso | Capa | Prio | Trazabilidad | Verificación en BD |
|---|---|---|---|---|---|
| **INT-01** | **Rechazo `wsturnos` → `wslogistica`**: el rechazo del pedido dispara la cancelación por motivo 16 en el otro servicio | API + BD | **P1** | RF-3.5 · I-1 · **ningún test automatizado cubre esta integración** (SDD §12.3) | **Q1** (`estado = 3`) + **Q2** (`id_motivo_anulacion = 16`) en la **misma** verificación |
| **INT-02** | **Rechazo con `wslogistica` indisponible**: la excepción debe **revertir el UPDATE del pedido** — no puede quedar rechazado con el traslado vivo | API + BD | P2 | R-10 — llamada REST saliente dentro de un método `@Transactional` | **Q1**: el pedido debe seguir en `estado = 1` |
| **INT-03** | **Anulación en cadena** `tramitadores` → `wstraslados /traslado/cancelar-por-turno` → `wslogistica /cancelar-desde-modulo-externo` | API + BD | P1 | RF-3.6, D5 · I-3 | **Q2** sobre todos los tramos del turno |
| **INT-04** | **La cadena de anulación devuelve el resultado real y el front lo interpreta bien**: un traslado que quedó vigente no puede mostrarse como anulado | UI + API | **P1** | RF-3.7 · D5 — antes respondía **200 con body vacío** y el front daba por cancelado lo que seguía vigente | Contrastar el payload de la respuesta con lo que muestra el bloque |
| **INT-05** | **Dependencia de versión**: el front de tramitadores **no puede correr contra un `wstraslados` anterior** al commit que devuelve el resultado real | Despliegue | P2 | SDD §9.1 dependencia 0 | Verificar el orden de despliegue en el ambiente antes de ejecutar |

### 7.8 Resumen de cobertura

| Capability | Casos | P1 | P2 | P3 | XF | OBS |
|---|---|---|---|---|---|---|
| `conflicto-traslado-mismo-dia` (CTM) | 22 | 11 | 7 | 4 | 3 | 2 |
| `autorizacion-traslado-duplicado` (ATD) | 19 | 11 | 4 | 4 | 3 | 3 |
| `devolucion-resultado-solicitante` (DRS) | 10 | 5 | 4 | 1 | 0 | 1 |
| `gate-servidor-traslado-duplicado` (GST) | 18 | 7 | 7 | 4 | 5 | 3 |
| `visibilidad-duplicado-logistica` (VDL) | 10 | 6 | 3 | 1 | 3 | 1 |
| Seguridad (SEG) | 5 | 4 | 1 | 0 | 3 | 0 |
| Integración (INT) | 5 | 3 | 2 | 0 | 0 | 0 |
| **TOTAL** | **89** | **47** | **28** | **14** | **17** | **10** |

**Cobertura de las 16 casuísticas del PRD:** C-01 → CTM-01 · C-02 → CTM-17…CTM-21, VDL-10 · **C-03 → CTM-22** (huérfana en las specs, cubierta acá) · C-04 → ATD-01, VDL-02 · C-05 → ATD-04 · C-06 → ATD-10, VDL-04 · C-07 → ATD-11, VDL-09 · C-08 → ATD-12 · C-09 → ATD-13, ATD-14 · C-10 → GST-01, GST-02 · C-11 → GST-10 · C-12 → GST-08 · C-13 → CTM-08, GST-13 · C-14 → CTM-20 · C-15 → GST-04, GST-05 · **C-16 → GST-17** (huérfana, cubierta como observación).

**Cobertura del alcance del 18/08 que §8 del PRD no registra:** DRS-01 → DRS-10 (10 casos sin casuística de origen, trazados directamente contra los Scenarios de la spec).

---

## 8. Datos de prueba

### 8.1 Ambiente y accesos

| Ítem | Valor |
|---|---|
| **URL** | `https://dev.sas.colonia-suiza.com.ar` |
| **BD** | Conector Python de sólo lectura contra DEV: `python db_dev.py "SELECT ..."` — acepta únicamente `SELECT`, `SHOW`, `DESCRIBE` |
| **Prohibido** | El **MCP de MariaDB apunta a producción** sobre un primario escribible. **No usarlo en esta certificación** |

### 8.2 Usuarios

| ID | Usuario | Persona | Perfiles reales en DEV | Permiso `autorizar_traslado_mismo_dia` | Para |
|---|---|---|---|---|---|
| **U-1** | `ayioperadort` / `<password unificada de QA en ambientes bajos>` | **1000007** — «AyiOperador Tramitador QA» | 4 `analista_enfermedades_profesionales`, 11 `analista_requerimientos` | **NO** | El que pide: CTM-*, ATD-01…03, DRS-*, VDL-02 |
| **U-2** | `tramitador.supervisor` / `<password unificada de QA en ambientes bajos>` | **1000008** — «Tramitador Supervisor QA» | **2 `jefe_de_siniestros`** | **SÍ** | El que resuelve: ATD-04…15, VDL-04, VDL-09 |

> ⚠️ **Dos precisiones que cambian el alcance y que conviene no pasar por alto.**
>
> 1. **El usuario se llama `tramitador.supervisor` pero su perfil es `jefe_de_siniestros` (2), no `supervisor` (10).** Todo lo que se certifique con él vale para el **jefe de siniestros**. El perfil 10, que es justamente el que EST-04 deja abierto, **no tiene usuario de prueba**.
> 2. **En DEV el permiso ya está asignado a los cuatro perfiles: 2, 3, 9 y 10** (verificado con Q6, `id_permiso = 1000`). Es decir, **el ambiente ya resolvió de hecho la pregunta abierta del supervisor**, mientras el script la marca «pendiente de confirmar» y cuatro documentos la declaran distinto. **Esa divergencia entre ambiente y documentación es un hallazgo de este plan** y hay que cerrarla antes del GO (GO-11).

**Usuarios que el plan necesita y no tiene** (ver §11): perfil **3 referente**, perfil **9 gerente** (para R-22), perfil **10 supervisor** (para EST-04), usuario de **otra cartera** (para R-3), usuario de **logística** (para VDL-* y para el control de EST-19), y un **segundo autorizante** distinto de U-2 para ejecutar ATD-13 de forma realista.

### 8.3 Denuncia y paciente

| Ítem | Valor |
|---|---|
| **Denuncia** | **B464435** · `id_denuncia = 464435` |
| **Paciente** | Ragnar Lothbrok · DNI 38401345 |
| **Estado** | Abierta, con traslados habilitados, dentro del alcance de U-1 y U-2 |

### 8.4 Estado del pool en DEV al 18/08/2026 — verificado con Q1 y Q2

| Pedido | Estado | Solicitante | Autorizante | Visto | Traslado | Turno | Fecha turno | Estado traslado | Log. ida | Marca | Motivo anul. |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **1** | 1 **PENDIENTE** | 1000007 | — | no | 1469808 | 4560455 | 25/08/2026 11:15 | **4 Cancelado** | **6** | — | **16** |
| **2** | 2 **APROBADA** | 1000007 | 1000008 | 18/08 18:26 | 1469809 | 4560456 | 01/09/2026 12:30 | 1 Solicitado | **1** | **1** | — |
| **3** | 3 **RECHAZADA** | 1000007 | 1000008 | 18/08 18:26 | 1469810 | 4560457 | 02/09/2026 13:45 | **4 Cancelado** | NULL | — | **16** |

**Otros traslados de la denuncia en fechas relevantes:**

| Traslado | Turno | Fecha | Hora | Estado | Log. ida | Rol en la prueba |
|---|---|---|---|---|---|---|
| 1469816 | 4560464 | 25/08/2026 | 00:10 | **1 Solicitado (vigente)** | NULL | **Es el traslado que genera el conflicto del 25/08** — el que aparece en el bloque |
| 1469807 | 4560454 | 25/08/2026 | 10:44 | 4 Cancelado | 6 | Residuo de una anulación previa |

**Lecturas obligadas de este estado, antes de ejecutar:**

- **Los pedidos 2 y 3 ya están vistos** (`fecha_visto_solicitante` cargada). La card del solicitante **no se enciende** con el pool tal como está: para ejecutar **DRS-01 a DRS-06 hay que generar un pedido nuevo y resolverlo**.
- **El pedido 1 no es un fixture limpio.** Figura **pendiente**, pero su traslado está **Cancelado (4), con motivo 16 y con `id_estado_logistica_ida = 6`**. Dos consecuencias:
  - Es un caso real de **EST-09.d** —el mundo cambió mientras el pedido estaba pendiente— y de **EST-10**: ese traslado **sí tuvo estado de logística**, así que la afirmación «nunca tuvo» de RF-3.5 no es una invariante garantizada.
  - **No sirve para ejecutar ATD-10 (aprobar)**: aprobarlo escribiría estado de logística y la marca sobre un traslado ya cancelado. **Hay que generar un pedido pendiente nuevo, en fecha futura, sobre un traslado vigente.**
- **Los pedidos 2 y 3 confirman el comportamiento esperado de `aprobar()` y `rechazar()`**, y sirven como línea de base documental: el aprobado tiene `id_estado_logistica_ida = 1` con `es_duplicado_autorizado = 1`, y el rechazado quedó cancelado con motivo 16 y **sin** estado de logística.

### 8.5 Datos a construir antes de cada jornada

Todo por **la aplicación**, no por SQL: el pool de DEV vale precisamente porque se armó **llamando a los endpoints reales**, y por eso es la única evidencia de que aprobar, rechazar y cancelar por motivo 16 funcionan de verdad.

| ID | Dato | Cómo se construye | Fecha | Para |
|---|---|---|---|---|
| **DP-1** | Traslado **vigente** en fecha futura | Turno con traslado desde el wizard, sin conflicto previo | **`hoy + 7 d`** | Base de todo conflicto |
| **DP-2** | Segundo turno **en la misma fecha** que DP-1 | Wizard → dispara el bloque | `hoy + 7 d` | CTM-02, CTM-09 |
| **DP-3** | Pedido **pendiente limpio** sobre traslado vigente | U-1 elige «pedir autorización» y guarda | `hoy + 7 d` | ATD-01, ATD-10, VDL-02, GST-08 |
| **DP-4** | Pedido **resuelto y NO visto** por U-1 | U-2 resuelve DP-3; **U-1 no entra a la pestaña** | — | **DRS-01 a DRS-05** |
| **DP-5** | **Tres traslados vigentes** en la misma fecha | Tres turnos con traslado, misma fecha | `hoy + 8 d` | **CTM-06 (XF)** |
| **DP-6** | Traslado con **menos de 3 h** al viaje | Turno de **hoy**, hora `+2 h` | hoy | CTM-10 (`sinAnular`) |
| **DP-7** | Traslado con **el viaje ya empezado** | Turno de hoy, hora `-1 h` | hoy | CTM-11 (`soloInformativo`) |
| **DP-8** | Traslado de **ida y vuelta** | Wizard con tipo de viaje ida y vuelta | `hoy + 7 d` | VDL-05, CTM-19 |
| **DP-9** | Traslado de **transporte público** vigente | Wizard con transporte público | `hoy + 7 d` | **VDL-06 (XF)**, **GST-16 (XF)** |
| **DP-10** | Traslado con pedido **aprobado y después rechazado** | Dos ciclos de pedido/resolución sobre el mismo traslado | `hoy + 7 d` | **ATD-15**, **GST-11** |
| **DP-11** | **Tanda de rehabilitación** ≥ 5 fechas, ≥ 3 en conflicto | Plan de rehabilitación | `hoy + 10 d` en adelante | CTM-08, **GST-13 (XF)** |

> **Regla de fechas, no negociable.** Todo dato que necesite las tres salidas se construye **en fecha futura**. Con fecha pasada el backend responde `horasAlViaje` negativo y colapsa a `soloInformativo`, y el caso no se puede ejecutar. Verificado que con **25/08/2026** el bloque ofrece `ANULAR`, `SIN_TRASLADO` y `AUTORIZACION`.

### 8.6 Cómo dejar el ambiente como estaba

El ambiente es **compartido**. El rollback es parte del plan, no un opcional.

| Paso | Acción | Verificación |
|---|---|---|
| **RB-0** | **Antes de empezar**: ejecutar **Q1**, **Q2** sobre los turnos del pool y **Q3** sobre las fechas objetivo, y **guardar la salida literal** como línea de base | La captura de Q1 debe coincidir con la tabla de §8.4 |
| **RB-1** | Identificar todo lo creado: los turnos generados durante la jornada, con **observación que empiece con `INI-2 PLAN QA`** — el mismo patrón que ya usan los pools (`INI-2 POOL TEST`) | Trazable sin depender de identificadores |
| **RB-2** | **Cancelar por la aplicación** —no por SQL— los traslados y turnos creados, con el circuito de cancelación normal | **Q3** sobre cada fecha vuelve al conteo de vigentes de RB-0 |
| **RB-3** | Los pedidos creados **no se borran**: quedan en `autorizaciones_traslado_duplicado` como evidencia de la corrida. **Documentarlos en el reporte** con su id y su estado final | **Q1** final adjunta al reporte |
| **RB-4** | **`fecha_visto_solicitante` es irreversible desde la aplicación.** Una vez marcado, no hay forma de desmarcarlo sin escribir en base. Por eso **DRS-01 a DRS-05 se ejecutan una sola vez y en orden**, sobre DP-4 | Ver §10 |
| **RB-5** | Comparar **Q1** y **Q2** finales con la línea de base de RB-0 y **anexar el diff al reporte** | Cierra CS-6 |

> **Lo que este plan NO hace:** no escribe en base por SQL, ni para preparar ni para revertir. Todo lo que necesite escritura directa —el estado «agencia informada», por ejemplo— queda fuera de alcance (§11).

---

## 9. Organización, entregables y secuencia

### 9.1 Secuencia sugerida de ejecución

El orden importa: hay casos que **consumen** el estado que otros necesitan.

| Bloque | Contenido | Por qué va acá |
|---|---|---|
| **0. Entrada** | CE-1 a CE-8 | Sin esto no se arranca. CE-7 (fecha futura) se re-verifica **cada jornada** |
| **1. API pura** | GST-*, SEG-* | No dependen de la UI ni ensucian el pool más de lo necesario, y **GST-01/02 y SEG-02 son los que deciden si el control existe**. Si el gate no funciona, el resto es cosmética |
| **2. Conflicto y salidas** | CTM-01 a CTM-16 | Sólo lectura sobre el pool en su mayoría |
| **3. Salidas con escritura** | CTM-17 a CTM-22 | Consumen traslados: van después de los de lectura |
| **4. Pedido y resolución** | ATD-01 a ATD-19 | Generan los pedidos que alimentan el bloque 5 |
| **5. Devolución** | DRS-01 a DRS-10 | **Requieren DP-4 sin ver.** Se ejecutan **una sola vez y en orden**: DRS-04 es irreversible |
| **6. Logística** | VDL-01 a VDL-10 | Necesitan los pedidos ya resueltos del bloque 4 |
| **7. Integración** | INT-01 a INT-05 | Cierran el circuito completo |
| **8. Rollback** | RB-1 a RB-5 | Con evidencia adjunta |

### 9.2 Entregables

| Entregable | Contenido |
|---|---|
| **Matriz de casos** | Los 89 casos con pasos, precondiciones, resultado esperado por capa y la query de verificación |
| **Reporte de ejecución** | Resultado por caso, evidencia de pantalla y de red, salida literal de cada query de BD |
| **Registro de defectos** | Separando **defecto** de **alcance no entregado**: un XF que falla no es un bug nuevo, es la confirmación de una tarea abierta |
| **Diff de base** | Q1 y Q2 antes y después, con el rollback verificado |
| **Recomendación de GO / NO-GO** | Contra los 16 criterios de §5.2 |

---

## 10. Riesgos de la propia prueba

Riesgos que introduce **ejecutar este plan**, no el software bajo prueba.

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| **RP-1** | **DEV es un ambiente compartido.** Escribir turnos, traslados y pedidos afecta a otros equipos, y el pool que otro dejó armado puede desaparecer o cambiar bajo los pies de la ejecución | Alto | Ejecutar en **ventana acordada y anunciada**. Marcar todo lo creado con `INI-2 PLAN QA`. **Q1 y Q3 al inicio y al final de cada jornada** para detectar interferencia |
| **RP-2** | **Marcar los pedidos como vistos es irreversible desde la aplicación.** Una vez que `fecha_visto_solicitante` se carga, la card no vuelve a encenderse para ese pedido y **DRS-01 a DRS-05 no se pueden repetir** sin generar datos nuevos | **Alto** | Ejecutar DRS **una sola vez, en orden, y con evidencia completa en el primer intento**. Preparar **dos** juegos de DP-4 por si el primero se consume mal |
| **RP-3** | **La ejecución genera duplicados reales en DEV**, que es exactamente lo que el sistema viene a evitar. Un traslado autorizado por prueba es indistinguible de uno de negocio | Medio | Rollback RB-2 obligatorio al cierre de cada jornada, y el marcado de RB-1 desde el minuto uno |
| **RP-4** | **Usar el MCP de MariaDB por costumbre.** Apunta a **producción**, sobre un **primario escribible**, y la garantía de sólo lectura es de la capa de herramienta, no de la base | **Crítico** | **Prohibición explícita.** Sólo el conector Python contra DEV. Toda query por el MCP debe tratarse como si corriera contra producción |
| **RP-5** | **Falso negativo de verificación de ambiente.** Un 404 de endpoint no distingue «base sin aplicar» de «código sin desplegar», y una consulta de migración hecha contra la base equivocada da falso negativo | Alto | CE-1 discrimina con la técnica del GET sobre un POST y usa DEV como control. CE-4 se verifica con el conector correcto |
| **RP-6** | **El resultado esperado depende de una configuración por ambiente.** `wslogistica.conflicto-traslado.horas-minimas-anulacion = 3` no está declarado en ningún documento funcional ni validado por negocio | Medio | CTM-10 a CTM-13 se ejecutan **contra la configuración vigente**, dejándolo explícito en el reporte. **No se puede escribir un caso reproducible contra el requisito hasta que EST-05 se cierre** |
| **RP-7** | **Certificar contra una spec aspiracional.** Los cinco deltas están escritos en modo normativo aspiracional; al menos seis Requirements corresponden a tareas abiertas | **Alto** | El régimen **XF** de este plan: cada caso de conducta no implementada declara la tarea abierta que lo respalda. **Un XF que pasa se reporta igual que uno que falla** |
| **RP-8** | **`tasks.md` no es fuente confiable de alcance.** Ya falló al menos una vez: `7.3` está `[x]` y la evidencia del mismo día lo desmiente | Alto | El alcance de este plan se construyó desde el **PRD, las specs y la evidencia de campo verificada**, usando `tasks.md` sólo como señal de tarea abierta |
| **RP-9** | **Prueba mayormente manual.** No hay tests de frontend en ninguno de los dos MFE, `wslogistica` corre con `<skipTests>true</skipTests>` en el `pom.xml`, y la máquina de estados de `wsturnos` no tiene un solo test | Medio | Registrar como recomendación de cierre. **Sacar `<skipTests>true</skipTests>` activa 47 tests ya escritos: es una línea** |
| **RP-10** | **Un solo usuario por lado.** Con un único autorizante, ATD-13 (dos personas resolviendo) sólo se puede simular secuencialmente, y R-3 (alcance por cartera) no se puede ejercitar | Medio | Solicitar los usuarios faltantes de §8.2. Mientras tanto, declarar la limitación en el reporte |

---

## 11. Qué NO se va a poder probar, y por qué

Esta sección existe para que nadie lea el reporte de ejecución como una certificación completa. **Lo que está acá no está probado, y el GO tiene que tomarse sabiéndolo.**

| # | No probable | Motivo | Consecuencia sobre el GO |
|---|---|---|---|
| **NP-1** | **Todo el circuito en TEST** | `wsturnos` no está desplegado: los cinco endpoints dan 404 (`tasks 10.3`) | **Cero casuísticas verificadas en un ambiente de certificación distinto de DEV.** La promoción a STAGE se apoya en una única corrida en el ambiente de desarrollo |
| **NP-2** | **La concurrencia real de R-7** | `resolver()` no tiene `@Version` ni `SELECT … FOR UPDATE`. Reproducir dos transacciones que lean `estado = 1` en el mismo instante exige control de temporización que la aplicación no ofrece | RF-2.8 («un pedido resuelto no se vuelve a resolver») queda **probado para el caso secuencial y no garantizado para el simultáneo**. El propio equipo decidió no agregar bloqueo optimista |
| **NP-3** | **El estado «agencia informada»** (guarda 5 de la matriz) | **No hay ningún flujo de la aplicación que lo produzca.** El aviso a la agencia no está automatizado (`traslados.mail_agencia_enviado` da 0 en todos los casos) y el dato vive en `traslados_agencia_historico`, que sólo se puede preparar por SQL de escritura — **fuera del alcance de este plan** | RF-1.2 y CTM-04 quedan **parcialmente verificados**. El caso borde «agencia informada de un viaje después cancelado (etiquetas 5/6) **no** cuenta como informada» no se ejecuta |
| **NP-4** | **El camino completo de transporte público** | R-8: la marca **nunca se escribe** para TP. No hay conducta que certificar, sólo la ausencia | VDL-06 y GST-16 se ejecutan **como XF documentales**. **GO-12 exige decisión de negocio**: en rehabilitación el TP es el traslado más frecuente, así que no es un borde |
| **NP-5** | **El perfil 10 (supervisor) y el perfil 9 (gerente)** | No hay usuarios de prueba. El único usuario «con permiso» disponible es perfil **2 jefe de siniestros** | **EST-04 no se puede cerrar por prueba**, y **R-22** (el gerente ve la pestaña y nunca la card) no se puede verificar. Ese usuario es el actor de C-05 o el de C-04 —resultados opuestos— según qué versión de la decisión valga |
| **NP-6** | **R-3 — el pedido de otra cartera sin resolutor** | Requiere un usuario de otra cartera y una denuncia fuera del alcance de U-2 | El riesgo estructural que alimenta **EST-03** —que existan pedidos que **nadie puede ver**— queda sin evidencia |
| **NP-7** | **EST-03 — un pedido que nadie resuelve** | No hay vencimiento, escalamiento, alerta ni métrica que probar: **no está diseñado**. No se puede probar la ausencia de un mecanismo | **Es el único riesgo con impacto sobre el asegurado y es una regresión.** GO-10 lo convierte en decisión de negocio previa al GO, no en deuda posterior |
| **NP-8** | **C-12 en `POST /turnos/crear`** | El controller pasa `idAutorizacion = null`, así que la vía «pedido pendiente/aprobado» **nunca se ejercita** en el alta. Sólo se verifica en `/programar-turno` | GST-08 y GST-09 se ejecutan **únicamente sobre `programar-turno`**. El alta acepta sólo por motivo declarado o por cero vigentes |
| **NP-9** | **Que el change resuelva el problema que lo justifica** | **No hay ninguna métrica**: ni contador de 409 emitidos, ni de pedidos por estado, ni de tiempo hasta la resolución. El PRD se apoya en 2.156 casos anuales (2.381 medidos en producción) y nada permite verificar que el número baje | Se puede certificar el comportamiento y **no** el objetivo de negocio. Agravado por **EST-02** (el motivo autodeclarativo sigue habilitando) y **EST-07** (la auto-aprobación no registra motivación): son los dos caminos por donde el número puede no moverse |
| **NP-10** | **La precedencia visual de las señales en la grilla de logística** | RF-3.4 **no declara** qué color, ni qué gana cuando la fila tiene otra señal. «Distinguibles» no es un criterio verificable, y hay al menos tres señales concurrentes | VDL-07 se ejecuta como **observación con evidencia**. Son 7 combinaciones que hoy **no se pueden escribir como casos** |
| **NP-11** | **El umbral de 3 horas como regla de negocio** | Vive en un `application.properties`, no en ningún documento que el negocio haya validado. Un caso escrito contra «3 horas» prueba la configuración, no el requisito | CTM-10 se reporta como *«verificado contra la configuración vigente del ambiente»*, con esa salvedad explícita |
| **NP-12** | **La auto-aprobación con registro de motivación** | Por diseño no exige justificación (sólo la exige quien pide) y el dictamen es opcional al aprobar. Lo único que queda registrado es el mismo motivo autodeclarativo de dos opciones que originó el problema | **EST-07**: para el perfil que más va a usar el circuito, el registro del *por qué* es el mismo que había antes. No es un defecto: es una consecuencia del diseño que el PRD no declara |

---

## 12. Recomendaciones de cierre

1. **Desplegar `wsturnos` en TEST antes de cualquier promoción**, y **bajar el frontend de TEST mientras tanto**: una pantalla que muestra turnos sin filtrar como si fueran pedidos pendientes es peor que una pantalla caída.
2. **Corregir el script del permiso** para que no fije `id_permiso = 101`: que lo deje al `AUTO_INCREMENT` y resuelva la FK por nombre, que es el criterio que la propia decisión **D7** ya adoptó. Relevar `SELECT MAX(id_permiso) FROM permisos_sas` en **cada** ambiente antes de aplicar.
3. **Cerrar R-1 antes de STAGE.** Es el único riesgo que vuelve irrelevante a todo el resto del plan: un control que se evita pasando un id en el body no es un control.
4. **Tomar decisión de negocio sobre EST-03** —el pedido sin resolver— antes del GO. Es el único hallazgo con impacto sobre el asegurado y el único que es una regresión.
5. **Cerrar la pregunta del supervisor**, y alinear los cuatro documentos con lo que el ambiente ya hace: en DEV el perfil 10 **tiene** el permiso.
6. **Actualizar el PRD §7.1 y el SDD §10**: H-1 y H-2 están cerrados y los documentos siguen describiéndolos como huecos abiertos. Un documento que subestima lo construido es tan caro como uno que lo sobrestima.
7. **Sacar `<skipTests>true</skipTests>` del `pom.xml` de `wslogistica`.** Una línea, 47 tests ya escritos, y son la única red de seguridad de la matriz de salidas.
8. **Exponer la métrica mínima** —conteo de pedidos por estado— para poder medir, a 60 días, si los 285 casos mensuales bajan.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026*

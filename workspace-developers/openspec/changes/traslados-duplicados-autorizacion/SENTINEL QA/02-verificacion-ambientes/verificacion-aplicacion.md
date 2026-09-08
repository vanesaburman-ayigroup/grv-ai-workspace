# Verificación de la aplicación — traslados duplicados (INI-2)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Ticket** | INI-2 |
| **Fecha** | 18/08/2026 |
| **Ambientes** | `test.sas.colonia-suiza.com.ar` · `dev.sas.colonia-suiza.com.ar` |
| **Usuarios** | `tramitador.supervisor` (con permiso) · `ayioperadort` (sin permiso) |
| **Método** | Sondas HTTP directas + navegación con Playwright, capturando red y consola |
| **Alcance de escritura** | **Ninguna.** No se guardó ningún turno, no se anuló ningún traslado, no se aprobó ni rechazó ningún pedido |

---

## 0. Resumen ejecutivo

**En TEST el frontend está desplegado y el backend del servicio `turnos` no.** Es exactamente el
modo de falla que `design.md` declaró como el peor del circuito —*«el front no se puede desplegar
solo… no da error»*— y **ya se materializó**.

Esto reconcilia las dos versiones en conflicto: quien mira la pantalla ve las pestañas nuevas y
concluye que está desplegado; quien mira la red ve 404 y concluye que no. Las dos observaciones
son correctas sobre capas distintas.

| # | Hallazgo | Severidad |
|---|---|---|
| **VAP-01** | En TEST el **front está desplegado sin su backend** — el modo de falla que el diseño advertía | **BLOQUEANTE** |
| **VAP-02** | Lo que falta en TEST es **sólo el servicio `turnos`**; `logistica` y `listados` sí están | Informativo (acota el fix) |
| **VAP-03** | **`devolucion-resultado-solicitante` SÍ está implementada, y el dictamen se muestra** → **H-1 cerrado**, **EST-01 resuelto** | **Corrige documentación** |
| **VAP-04** | **Tres de los cinco defectos conocidos están corregidos**; uno se confirma, uno no se reproduce | Informativo |
| **VAP-05** | En DEV el circuito funciona **end-to-end**, con las tres salidas reales | Informativo |
| **VAP-06** | Los endpoints responden **sin autenticación** — confirma R-1 | **ALTA** (seguridad) |

---

## 1. VAP-01 — En TEST el front está desplegado sin su backend · **BLOQUEANTE**

### La evidencia del front desplegado

El bundle del microfrontend de tramitadores es **idéntico byte a byte** en los dos ambientes:

```
md5(/tramitadores/grv-tramitadores.js)  TEST = DEV = 777a384c87e293a68e7e4e7cb8604a8e
```

Por eso en TEST **se ven** las pestañas «Autorización Doble Traslado Pendiente» (supervisor) y
«Autorización Doble Traslado Resuelta» (operador), y las columnas nuevas de la grilla.

### La evidencia del backend ausente

Sondas HTTP sobre `wsturnos`, con el control de que el mismo servicio responde en rutas viejas:

| Endpoint | TEST | DEV |
|---|---|---|
| `GET /grv/turnos/actuator/health` | **200** | 200 |
| `GET /grv/turnos/autorizaciones/consumo-cie10/1` | **200** | 200 |
| `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` | **404** | **200** (`body: 1`) |
| `GET /grv/turnos/autorizaciones/mis-duplicados-resueltos` | **404** | **200** (`body: 0`) |
| `POST /grv/turnos/autorizaciones/pedir-traslado-duplicado` | **404** | existe |
| `POST /grv/turnos/autorizaciones/resolver-traslado-duplicado` | **404** | existe |
| `POST /grv/turnos/autorizaciones/marcar-duplicados-vistos` | **404** | existe |

> **Nota de método.** Sobre los endpoints que son `POST` se envió un `GET`: si la ruta existe el
> request llega al handler y falla ahí (400/500), y si no existe da 404. Discrimina **sin escribir
> nada**. DEV funciona como control: los mismos requests nunca dan 404 ahí, lo que descarta que el
> 404 de TEST sea un artefacto de la técnica.

El servicio está **sano y bien ruteado**: `actuator/health` responde `UP` y un endpoint preexistente
del **mismo controller** responde 200 con datos reales. **Le falta el código, no la infraestructura.**

### El efecto visible, que es el peligroso

- Los 404 **se disparan solos al cargar el home**: con `tramitador.supervisor` falla
  `traslados-duplicados-pendientes`; con `ayioperadort` falla `mis-duplicados-resueltos`.
- **Ninguno de los dos usuarios ve card de autorización en TEST.**
- Al abrir la pestaña «Autorización Doble Traslado Pendiente» **no se dispara ningún request**, y
  la grilla muestra **turnos sin filtrar** (denuncias 999028, 999031…) con las columnas
  «Lo pidió / Fecha del pedido / Justificación» en `-`.

En DEV la misma pestaña trae `1–1 de 1` con datos reales.

> ⚠️ **Es el escenario que `design.md` describía como el peor modo de falla, ya ocurrido.** La
> pantalla no da error: muestra una grilla poblada que el usuario puede leer como «no hay pedidos
> pendientes» o, peor, como una lista de pedidos que no lo son.

### Qué hacer

Desplegar **`wsturnos`** en TEST (tarea 10.3: investigar por qué CodePipeline no promovió `release`;
requiere `aws sso login`, la sesión estaba vencida). **Hasta entonces la prueba funcional en TEST no
puede empezar** — y el front ya desplegado no debería quedar accesible en ese estado.

---

## 2. VAP-02 — Lo que falta es sólo `turnos`

| Servicio | Endpoint sonda | TEST | Estado |
|---|---|---|---|
| `logistica` | `POST /grv/logistica/traslados/conflictos-mismo-dia` | **401** | **Desplegado** (401 = existe y exige auth) |
| `listados` | `GET /grv/listados/motivos-traslados/mismo-dia` | **200** | **Desplegado** |
| `turnos` | los cinco del circuito | **404** | **NO desplegado** |

Acota el arreglo a un solo servicio, y confirma que el orden de despliegue de `design.md` (base →
backend → front) se rompió: el front salió antes que uno de los backends.

---

## 3. VAP-03 — La capability de devolución existe, y el dictamen se muestra · **corrige documentación**

**Resuelve el bloqueante EST-01** y **cierra el hueco H-1** del PRD y el SDD.

Verificado en DEV con `ayioperadort` (perfil **sin** el permiso):

- **El endpoint de lectura existe y se llama solo al cargar el home:**
  `GET /grv/turnos/autorizaciones/mis-duplicados-resueltos?idSolicitante=…` → `{"status":200,"body":0}`.
- **La pestaña «Autorización Doble Traslado Resuelta» lista los pedidos con las cuatro columnas que
  exige la spec**: *Resultado* (Rechazado / Autorizado), *Lo resolvió* — **por su nombre**,
  «Tramitador Supervisor QA» —, *Fecha de la respuesta*, **_Dictamen_** («Rechazado: los estudios se
  pueden agendar otro dia…», «Aprobado: interconsulta justificada…») y *Mi justificación*.
- **El marcado de vistos existe**: al abrir la pestaña se disparó
  `POST /grv/turnos/autorizaciones/marcar-duplicados-vistos` → 200.
- **La nomenclatura es correcta y excluyente**: el supervisor ve «…Pendiente» (`body: 1`) y **no**
  la de resueltas; el operador, al revés.

> **Corrección de un hallazgo intermedio propio.** Durante la sonda HTTP se concluyó que H-1 seguía
> abierto porque `mis-duplicados-resueltos` devuelve **un contador**, y seis variantes de un
> endpoint de detalle dieron 404. La conclusión era errónea: **el detalle no viaja por un endpoint
> propio, viaja por la grilla** (el SP del listado). El contador enciende la card; la pestaña
> muestra el detalle.

### Qué corregir en la documentación

| Documento | Dice | Realidad |
|---|---|---|
| PRD §7.1, hueco **H-1** | «El dictamen no se lee en ninguna parte» | **Se lee**, en la pestaña de resueltas |
| PRD §7.1, hueco **H-2** | «El gestor nunca se entera del resultado» | **Se entera**: contador + pestaña con dictamen |
| SDD §10 | Describe qué habría que construir para cerrarlos | **Ya está construido** |
| `tasks.md` 3.6 / 7.10 `[x]` | Implementado | **Correcto** |

`tasks.md` tenía razón; el PRD y el SDD quedaron desactualizados respecto de su propio código.

### Lo que queda pendiente de verificar

**La card renderizada** en el home del solicitante: **no concluyente por datos**. El contador de no
vistos daba **0**, y la card se muestra sólo con `> 0` — que es el comportamiento correcto («se
apaga sola al leerla»). Para verla hay que **generar un pedido nuevo y resolverlo**.

> El `marcar-duplicados-vistos` disparado devolvió `body: 0` — marcó **cero** registros, o sea que
> los pedidos ya estaban vistos. **El estado del pool no se alteró.**

---

## 4. VAP-04 — Los cinco defectos conocidos, reverificados

Reverificación con evidencia propia, sin dar por ciertos los reportes previos.

| # | Defecto reportado el 18/08 | Veredicto | Evidencia |
|---|---|---|---|
| 1 | «Ver información de traslado» no abre; `TypeError: E.resetTurnosTablaDetalle is not a function` | **REFUTADO — corregido** | Abre el modal «Información de Traslado», dispara `POST /grv/traslados/traslado/detalles/id` → 200, sin errores de consola. El string `resetTurnosTablaDetalle` tiene **0 ocurrencias** en el bundle actual |
| 2 | A 390 px «Atrás» y «Cancelar» se superponen ~50 px | **REFUTADO — corregido** | Geometría medida: «Atrás» en `y=1087`; «Cancelar» y «Siguiente» en `y=1139`. Envuelven en dos filas |
| 3 | El resize resetea el wizard al paso 1 y pierde lo cargado | **REFUTADO — corregido** | De 1440 a 768 px el wizard se mantuvo en el paso 2, con el bloque de conflicto y los radios intactos |
| 4 | Copy contradictorio: «Estado: SOLICITADO» junto a «el viaje ya empezó» | **NO REPRODUCIDO** | Depende de datos con viaje ya iniciado. El texto «el viaje ya empezó» **no está en el front**: lo manda el backend. Sigue abierto como riesgo de copy |
| 5 | Botones de la grilla sin nombre accesible | **CONFIRMADO** — en **DEV y TEST** | HTML real: `<button class="MuiIconButton-root"><img src="…svg" alt="icon"></button>`, sin `title` ni `aria-label` |

Tres de cinco ya estaban corregidos. **Confirma que la evidencia de campo del 18/08 no refleja el
estado actual del código** — coherente con que `tasks.md` tampoco es fuente confiable de alcance
(ver EST-15).

---

## 5. VAP-05 — En DEV el circuito funciona end-to-end

Con `ayioperadort`, denuncia **B464435**, turno de Consulta el **25/08/2026** (fecha **futura**, lo
que esquiva la limitación del pool viejo del 15/08):

Al tildar «Requiere traslado» aparece el **bloque de conflicto completo**
(`POST /grv/logistica/traslados/conflictos-mismo-dia` → 200):

> «El paciente ya tiene un traslado ese día — Turno 4560464 · Consulta · 00:10:00 · CENTRO MEDICO
> NOGOYA SAN JUSTO [RKT] — Elegí cómo resolverlo antes de guardar el turno»

Con **las tres salidas reales** como radios: `ANULAR`, `SIN_TRASLADO`, `AUTORIZACION`. **No** apareció
«el viaje ya empezó», porque la fecha era futura.

Con `tramitador.supervisor`: card «Autorización Doble Traslado Pendiente» en el home (`body: 1`),
pestaña con el pedido de B464435 mostrando «Lo pidió / Fecha del pedido / Justificación», menú de
tres puntitos con «Gestionar autorización» y «Ver información de traslado», y drawer de resolución
con **Cancelar / Rechazar / Autorizar**.

> **DEV es hoy el único ambiente donde se puede ejecutar la prueba funcional**, y conviene cargar
> los datos en **fechas futuras** para que el backend habilite las tres salidas.

---

## 6. VAP-06 — Los endpoints responden sin autenticación · confirma R-1

Las sondas a `wsturnos` **no necesitaron token** en ninguno de los dos ambientes: respondieron a un
`curl` desde una máquina de escritorio, sin credencial. Coincide con lo que el equipo ya había
registrado en `pool-datos-test.md` §6.5 y con el riesgo **R-1**, que el propio change califica como
el de mayor severidad abierta.

Sumado a que `resolver()` valida el permiso contra el `idAutorizante` que viaja **en el body**, el
circuito es hoy **evitable**: alguien puede aprobar su propio duplicado pasando el identificador de
un supervisor.

`wslogistica` está mejor: `conflictos-mismo-dia` devolvió **401** en los dos ambientes.

> **Es el punto que hay que cerrar antes de STAGE y PROD** (tarea 10.4), y no debería promoverse sin
> confirmar que los endpoints quedan detrás del gateway.

---

## 7. Lo que quedó sin verificar

| Punto | Motivo |
|---|---|
| **El bloque de conflicto en TEST** | **No verificado por datos**, no refutado. Los turnos hallados (999031 del 13/08, 999028) no tenían traslado vigente ese día: `tiene-por-denuncia-y-fecha` devolvió 200 sin conflicto |
| **La card del solicitante renderizada** | Contador en 0. Requiere generar un pedido y resolverlo |
| **Copy contradictorio (defecto 4)** | Requiere un traslado con viaje ya iniciado |
| **Aprobar / rechazar / cancelar por motivo 16 en TEST** | Bloqueado por VAP-01 |

---

Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026

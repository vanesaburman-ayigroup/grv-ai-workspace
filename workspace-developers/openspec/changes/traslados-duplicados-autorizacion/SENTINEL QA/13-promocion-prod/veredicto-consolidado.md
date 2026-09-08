# Veredicto consolidado — promoción INI-02

**Autor:** Vanesa Burman — QA
**Fecha:** 24/08/2026
**Entrada:** tres revisiones independientes sobre las mismas 5 MRs — review cruzado de contratos, `code-review` por repo, y sincronización a stage.

---

## El patrón que explica casi todo

Los tres informes convergen en una sola frase:

> **El circuito está completo en un solo drawer: `DrawerNuevoTurno`.** En los otros tres el gate está levantado y la mitad que resuelve el conflicto quedó a medio cablear.

Todo lo demás son consecuencias de eso. Verificado: `justificacionTrasladoDuplicado` e `idSolicitanteTrasladoDuplicado` llegan a un request **en un solo lugar** de todo el repo — `DrawerNuevoTurno/StepTraslado.jsx:174` → `useTurnosSave.js:765-766`.

| drawer | bloque de conflicto | `idSolicitante` | `onChangeJustificacion` | `onChangeSalida` | registra pedido |
|---|---|---|---|---|---|
| `DrawerNuevoTurno` | sí | **sí** | **sí** | sí | **sí** |
| `DrawerProgramarTurno` | sí | no | n/a | sí | no |
| `DrawerEditarTurno` (rehab) | sí | no | n/a | **`undefined`** | no |
| `DrawerGenerarAutorizacion` | sí | no | **no** | sí | **rechazado a propósito** |

---

## Un hallazgo metodológico que hay que atender primero

**Los cinco `master` locales estaban atrasados** cuando arrancaron las revisiones: wsturnos 16 commits, **wslogistica 115**, wstraslados 15, logistica 20, tramitadores 10.

Con ese baseline, todo `git diff master...promo/INI-2-prod` toma un merge-base viejo y **le atribuye a la promoción historia de master**. Produjo dos conclusiones falsas antes de detectarse (que INI-02 arrastraba GRV-2239 completo, y que `wslogistica` borraba ~1.950 líneas de tests).

**Es la tercera vez que este proyecto tropieza con lo mismo** — ya pasó con el clon 23 commits atrás en el API testing, y el SDD lo documenta en su D-16 retirado. La regla operativa: **siempre `origin/master...origin/promo/...`, con `fetch` previo**, y declarar rama + commit + fecha de fetch en el informe.

Con el baseline correcto, **el corte es efectivamente quirúrgico**: wsturnos 3 commits/29 archivos, wslogistica 1/34, wstraslados 1/7, logistica 1/4, tramitadores 2/32. Nada de GRV-2239, SE-268 ni SE-273.

---

## `cf1aa1c` (el fix de `contarPorTurno`): aprobado

La revisión lo validó punto por punto, y la evidencia es mejor que la que yo tenía cuando lo apliqué:

- **El JPQL es correcto, y no por casualidad.** `Turno` tiene `@Id private Long idTurno`; no existe campo `id`. Los dos paths son válidos por razones distintas: `t.turno.idTurno` nombra el atributo real, y `t.turno.id` funciona por el alias implícito de identificador de Hibernate. La prueba dura: **`t.turno.idTurno` ya lo usan dos queries preexistentes del mismo repositorio**, y Hibernate parsea todos los `@Query` al bootstrap — si fuera inválido el ws no arrancaría, y está en producción.
- **El cambio de semántica es neutro.** Los tres call sites consumen sólo un booleano y ninguno necesita la entidad después. `!= null` era true si y sólo si había exactamente 1 fila; `> 0` con ≥1. Idénticos en 0 y 1; con ≥2 el viejo tiraba excepción. Mejora estricta.
- **El call site que quedó está bien dejarlo.** `AutorizacionesServiceImpl:1826` no es alcanzable con un turno de dos traslados: el flujo está cerrado en `obtenerYActualizarAutorizacion:1265` a autorizaciones en estado 1, y en producción **los 3.089 turnos con 2+ traslados que tienen autorización la tienen APROBADA: cero casos alcanzables**.
- **El javadoc dice la verdad al pie de la letra**: 3.094 turnos con 2 o más (3.074 con 2, 19 con 3, 1 con 4); 48 con fecha 2026 y exactamente 5 en «Prog. Con Traslados Pend.»; el índice único es `traslados_turnos_fk1` con `Non_unique=1`; y las «~130 cancelaciones/mes con motivo 16» son 1.067 en 2026 = **133/mes**.

---

## Bloqueantes

### Los 4 de `tramitadores` — !1823 es la peor de las cinco

**B-1 · `DrawerEditarTurno` nunca se cableó al gate nuevo.** `index.jsx:57` destructura `setSalidaConflictoTraslado` del hook y `:174` lo pasa como `onChangeSalida` — **pero el hook no lo devuelve**: cero ocurrencias de `salidaConflicto` en `useEditarTurnoRehabilitacion.js`, y su `return` no lo incluye. Es `undefined`. No crashea (hay guarda): se come la elección en silencio, y la validación quedó en la regla vieja `(request?.idMotivoTrasladoMismoDia || !tieneTrasladoMismoDia)`.

*En producción:* un gestor sin el permiso edita un turno de rehabilitación con conflicto. El select de motivo está detrás de `puedeAutorizar`, así que `idMotivoTrasladoMismoDia` **nunca se puede setear** y «Guardar» queda deshabilitado para siempre. Anular tampoco lo salva: `tieneTrasladoMismoDia` es el booleano legacy y no se reevalúa. Cancelar y perder la edición — el callejón que este desarrollo vino a eliminar.

> Verificado directamente. El docblock de `exigeMotivoTrasladoMismoDia` nombra los cuatro drawers y advierte «y ya se desincronizaron una vez». Éste es el que quedó desincronizado.

**B-2 · El alta de tanda de rehabilitación tira la justificación.** `DrawerGenerarAutorizacion/StepTraslado.js:344` no pasa `idAutorizacion` (correcto, es alta) → `esAlta = true` → el bloque muestra el caption «el pedido se envía al guardar el turno» en vez del botón. Ese contrato exige que el padre levante el texto con `onChangeJustificacion`, y **este call site no lo pasa**.

*En producción:* el gestor escribe la justificación, lee que el pedido se envía al guardar, `exigeMotivoTrasladoMismoDia` devuelve false para `AUTORIZACION && !puedeAutorizar` y **lo deja guardar**. Nada llega al backend: tanda creada con traslado duplicado, sin motivo, sin pedido y sin nadie a quien autorizar. Es **peor que las declaraciones falsas** que el circuito viene a eliminar: al menos ésas dejaban registro.

**B-3 · Falta `idSolicitante` en dos de los tres call sites del pedido.** `DrawerProgramarTurno/index.jsx:285` y `DrawerEditarTurno/index.jsx:165`. Los dos tienen `idAutorizacion`, así que el botón «Enviar el pedido» **sí** renderiza y se postea `idSolicitante: undefined`, contra un DTO con `@NotNull` y un controller con `@Valid`.

*En producción:* **400**. Y si algún día pasara la validación, la pestaña «Autorización Doble Traslado Resuelta» filtra por `idSolicitanteDuplicado`, así que el dictamen **nunca le vuelve** a quien pidió.

> Verificado directamente: el `@NotNull`, el `@Valid`, y los cuatro call sites con sus props.

**B-4 · Un error de red traba el wizard sin campo ni explicación.** `useConflictoTraslado.js:79` comenta «el gate blando del motivo sigue estando, así que el gestor puede avanzar igual». **La premisa es falsa**: la MR eliminó el select de motivos de los cuatro drawers (4 sitios de remoción) y el único render que sobrevive está **dentro del bloque**. Con `isError`, `hayConflicto` es false → el bloque devuelve `null` → pero el gate corre sobre el booleano legacy, que sigue true.

*En producción:* cualquier 500, timeout o desfasaje de deploy en `conflictos-mismo-dia` deja al gestor con **«Siguiente» deshabilitado para siempre, sin campo visible y sin mensaje**, y pierde lo cargado. A un hipo del backend de distancia.

### Los 2 de contrato cruzado

**B-5 · Los dos servicios no coinciden en qué es un conflicto.** `wslogistica/ConflictoTrasladoServiceImpl.java:155` descarta el conflicto cuando el plan es de rehabilitación y la región del cuerpo es distinta. **El gate de `wsturnos` no sabe nada de región.** Resultado: el front no muestra el bloque y el back devuelve 409. El turno no se puede guardar y la pantalla no ofrece salida. Es el escenario del plan de diez sesiones que motivó la feature.

**B-6 · La edición levanta el gate y nadie registra el pedido.** `registrarPedidoDelAlta` tiene **un único llamador: `createTurno`**. `updateTurno` no lo llama, pero el validador acepta la intención en la edición y levanta el gate igual. El gestor ve «guardado con éxito» y no se creó ninguna fila: el traslado queda invisible para logística **para siempre**.

> Verificado directamente: un solo call site real, y `updateTurno` es `@Transactional` pelado.

---

## MAJOR que deberían entrar en la misma pasada

**M-1 · El validador ignora el estado del traslado — un 409 sobre duplicados que no existen.** `TrasladoDuplicadoValidator:146,288,333` pregunta «¿tiene traslado?» sin mirar si está cancelado o rechazado, mientras `contarTrasladosVigentesEnFecha` **sí** excluye 4 y 5.

Medido en producción, 2026: **1.096 turnos** cuyo único traslado está cancelado o rechazado, con otro traslado vigente el mismo día, en estados donde programar o editar es normal (751 «Prog. Con Traslados Pend.» + 345 «Programado Espontáneo»). Unos **137 por mes**.

*El daño es exactamente el que el circuito quiere evitar:* el gestor queda obligado a declarar «Autorizado por Supervisión» para un remis que nunca va a salir. Declaraciones falsas inducidas por el propio gate.

**Arreglo:** `AND t.estadoTraslado.idEstadoTraslado NOT IN (4, 5)` en la sonda. Mismo tamaño que `cf1aa1c`.

**M-2 · El pedido de edición y programación apunta al traslado equivocado.** `BloqueConflictoTraslado.jsx:190-195`: `aAutorizar` sale de `conflictos`, y el hook consulta con `idTurnoExcluido` = el turno editado, así que **`conflictos` contiene garantizadamente sólo traslados de otros turnos**. Al aprobar se marca y re-solicita el traslado viejo, pisando su estado real, y el del turno editado queda sin marca para que logística lo cancele. El javadoc de `pedirTrasladoDuplicado` ya lo documenta como «FIX PENDIENTE DEL LADO DEL FRONT»: sigue sin arreglar.

**M-3 · `agregarResultado` no hace nada cuando más importa.** `wstraslados/TrasladoServiceImpl:751-763`: javadoc «deja registro cuando no lo hizo», y **todo el cuerpo está dentro de `if (resultado != null)`**. Código nuevo (no existe en master) y el path es alcanzable (204, body vacío). Un traslado desaparece de la lista, la pantalla lo lee como éxito y queda vigente — la falla que la MR existe para eliminar. Y no recibe el `idTraslado`, así que es incapaz de nombrar el que perdió.

**M-4 · Tres cosas en `AutorizacionTrasladoDuplicadoServiceImpl`:**
- **TOCTOU en `resolver():212-249`.** MariaDB 10.5.29 en REPEATABLE-READ: el `findById` no lockea, dos transacciones leen PENDIENTE y las dos escriben. El javadoc afirma que evita que «dos referentes pisen quién resolvió de verdad» y no lo evita. Peor caso: uno aprueba y otro rechaza, y el traslado queda con estado de logística y marca *y* cancelado. Arreglo: `@Lock(PESSIMISTIC_WRITE)` o `UPDATE ... WHERE estado = 1`.
- **Pedido con los dos ids de traslado en null.** El DTO no exige ninguno y el servicio no valida. Queda un PENDIENTE que **nadie puede resolver nunca**: al aprobar lanza `IllegalStateException`, revierte, vuelve a PENDIENTE. Infla la card del autorizante para siempre.
- **`rechazar():388` hace HTTP dentro de la transacción**, con `new RestTemplate()` sin timeouts. Si logística procesa y la respuesta se pierde: traslado cancelado y pedido PENDIENTE. Y un logística colgado retiene la conexión de BD.

**M-5 · La invisibilidad se abre sola por tres caminos.** `AutorizacionesServiceImpl:1839-1860` (`dictaminar-autorizacion`), `TurnosServiceImpl:894-937` (`programarTurno`, y para transporte público **sin exigir autorización aprobada**), y **`wsauditoria/AutorizacionesServiceImpl:796,814`, que está fuera del corte**. Ninguno mira el estado del pedido, y el gate no los frena porque acepta PENDIENTE.

*En producción:* un referente aprueba la **autorización del turno** —acción distinta, más frecuente, hecha por alguien que no ve el pedido— y el traslado baja a la grilla **sin la marca**. Logística lo cancela con motivo 16: las 133/mes que INI-02 vino a eliminar.

---

## El orden de despliegue no es negociable

Verificado contra producción, hoy: `consulta_turnos_tramitadores_sp` **no tiene** las 8 columnas del duplicado; `es_duplicado_autorizado` **no existe** en `traslados` ni en `traslados_transporte_publico`; `autorizaciones_traslado_duplicado` **no existe**; y **el permiso `autorizar_traslado_mismo_dia` tampoco** (0 filas en `permisos_sas`).

Los DTO mapean **por nombre** sobre `resultClasses`: si falta una columna, **revienta la grilla de turnos de tramitadores entera** —no sólo las pestañas nuevas— y los tres listados de logística.

**Orden:** tabla + permiso → script del visto → columna `es_duplicado_autorizado` + recrear los 3 SP de logística → recrear `consulta_turnos_tramitadores_sp` → **recién ahí los artefactos**.

Y dos riesgos del script que hay que corregir antes de correrlo:

1. **Dos de los cuatro `CREATE PROCEDURE` no están calificados con el esquema.** Dependen del `USE cs;` del encabezado, y el propio script pide correr el bloque 4 en una sesión nueva para usar el usuario `admin`. Si se hace así, el `DROP` borra el SP de `cs` y el `CREATE` lo crea en otro esquema: **grilla de tramitadores caída en producción**. Arreglo: `cs.` en los cuatro.
2. **El gate transaccional del bloque del permiso es ilusorio:** `START TRANSACTION` seguido de DDL hace commit implícito en MariaDB. El rollback real es el `DELETE` del final, no el `ROLLBACK` comentado.

---

## Estado de stage

**INI-02 ya está mergeado en stage desde el 19/08** — pero es la versión **vieja**. En `wsturnos`, stage no tiene `contarPorTurno`, usa **`anyMatch`** en lugar de `findFirst` (o sea: un aprobado viejo neutraliza un rechazo posterior) y tiene 1 uso de `rollbackFor` en lugar de 3.

Las MRs !857 (wsturnos) y !1824 (tramitadores) llevan stage a la versión corregida: 16 y 6 archivos. Las otras tres (!651, !312, !455) **no traen commits**: sus ramas ya están dentro de stage.

Y un dato que master no puede dar: en stage, `mvn test` de `wsturnos` da **80 tests, 0 fallas**, y siguen verdes con `contarPorTurno` y `findFirst`. Master no los tiene, porque se sacaron del pom. **Stage es la única verificación automatizada del circuito que existe.**

---

## Lo que se verificó y está sano

- **Builds reales, no parseos.** Los tres backends compilan (`mvn -o -q compile -DskipTests`, exit 0). `tramitadores` compila con webpack producción: **12.698 módulos, 0 errores** — corrido dos veces por dos revisores distintos, una de ellas tras un `npm install` completo. Eso prueba que **todos los imports nuevos resuelven**, que era exactamente el agujero del corte.
- **Lint de `tramitadores`:** 10 errores en los archivos cambiados, y los 10 **preexisten en `origin/master`**: cero netos nuevos.
- **i18n:** las 63 claves nuevas resuelven en `es` y `en`, con los mismos placeholders.
- **Los contratos que cruzan repos, sanos:** los 3 campos del payload existen en `GenerarTrasladoDTO` con el nombre exacto y **los lee el service**; los 5 endpoints nuevos existen con ese path y verbo; los 8 estados de logística coinciden valor por valor entre `wsturnos` y `wslogistica`; el mapeo de los SP es **por nombre**, no posicional, y las columnas nuevas van al final; `cancelar-por-turno` es aditivo y sus otros dos consumidores ignoran el argumento nuevo sin romperse.
- **El permiso por nombre y su cadena de tablas confirmada contra producción**, con **13 referentes y 12 jefes activos**: va a haber quien apruebe.
- **La convención del `key_generator` respetada:** la entidad nueva usa `IDENTITY` sobre su propio `AUTO_INCREMENT` y no toca `autorizaciones.id_autorizacion`. Cero `INSERT` a esa tabla.
- **Números mágicos verificados en producción:** estado logística 1=SOLICITADO, tipo viaje 2=Ida/Vuelta, traslado 4=Cancelado / 5=Rechazado, motivo 16=«Cancelado por alarma repetida».
- **Residuos de la estrategia vieja: ninguno.** Cero referencias a columnas `duplicado_*` sobre `autorizaciones` en los 5 diffs y en el script, y confirmado contra producción que esa tabla no tiene ninguna. De SE-268 y SE-273 quedan sólo comentarios que documentan la exclusión. **El corte quedó limpio.**

---

## Recomendación

**Ninguna de las dos revisiones recomienda mergear las cinco tal como están.** Y las dos coinciden en el reparto:

| MR | veredicto |
|---|---|
| **wsturnos !856** | Mergeable **con M-1** (una línea: el filtro de estado). `cf1aa1c` aprobado. |
| **wslogistica !650** | Mergeable. Los MINOR van como follow-up. |
| **logistica !454** | Mergeable. Un reparo de UX: la MR **intercambia el significado de `InfoIcon`**, que logística ya lee en producción como «requiere revisión». Conviene invertirlo. |
| **wstraslados !311** | Mergeable **con M-3** (`agregarResultado` con `resultado == null`). |
| **tramitadores !1823** | **No va como está.** Cuatro bloqueantes, todos terminan con el gestor sin poder guardar o guardando un duplicado sin registro. |

**El camino que recomiendo, y por qué:** el circuito funciona completo en `DrawerNuevoTurno`, que es el camino de mayor volumen, y está probado a mano. Los otros tres drawers tienen el gate puesto y la resolución a medias — es decir, **hoy empeoran la situación en lugar de mejorarla**: bloquean sin ofrecer salida.

Lo más seguro es **mergear el alta y desactivar el gate en los otros tres caminos** hasta cerrar B-1 a B-6. Entrega el valor real —cierra el agujero por donde entra el volumen— sin romper lo que hoy funciona. Es un cambio de alcance, no una rebaja de calidad.

Si en cambio hay margen para una semana más, B-3 es trivial (una prop en dos drawers), B-1 y B-2 son de cableado, y B-5, B-6 y M-5 necesitan definición de negocio.

**Lo que sí conviene hacer ya, sin esperar nada:** mergear !857 y !1824 a stage. Llevan stage de la versión con bugs a la corregida, sin tocar producción, y habilitan validar los bloqueantes con los 80 tests de respaldo.

---

## Qué no se verificó

- **Nada de runtime.** Ningún test funcional, ningún navegador, ninguna prueba de integración. Los builds fueron compile-only. Los cuatro bloqueantes de `tramitadores` están trazados en código con archivo y línea, y tres los verifiqué yo por separado, pero **ninguno se observó ejecutando**.
- **El JPQL nuevo no lo valida ningún build:** `wsturnos` tiene un solo test unitario y `maven.test.skip` en el perfil prod. Un `@Query` mal escrito falla al arrancar, no en CI. La evidencia de `cf1aa1c` es indirecta pero fuerte (los paths ya corren en producción), no un boot de contexto.
- **`EXPLAIN` está bloqueado** por el MCP de sólo lectura: el uso de índice se deduce de `SHOW INDEX`, no de un plan.
- **Sin barrido automático de hook-deps:** el repo no tiene `eslint-plugin-react-hooks`, así que las dependencias se leyeron a mano. **CI nunca va a marcar una dep faltante.**
- **La frecuencia real de M-5** depende de la configuración de autoaprobación por protocolo y no se puede medir desde el repo.
- **El esquema, el `DEFINER` y el `sql_mode` de stage:** no verificables, porque el único MCP de base disponible apunta a producción.

---

*Generado por Vanesa Burman — QA · 24/08/2026*

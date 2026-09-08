# Revisión de código y funcionalidad — traslados duplicados (INI-2)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Fecha** | 19/08/2026 |
| **Fuente del código** | `origin/develop` de `wsturnos` · commit `2ea106c` · `fetch` del 19/08/2026 |
| **Alcance** | La máquina de estados del circuito, el gate, el registro del pedido en el alta y la interacción con logística |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |

> **Nota de método.** Todo lo de acá se leyó contra `origin/develop` con `fetch` previo, no
> contra el working tree — que está en `fix/pedir-traslado-duplicado-faltante` y cuyo
> `develop` local está **23 commits atrás**. Ese atajo ya produjo un hallazgo falso en esta
> misma revisión y otro en el SDD del equipo.

---

## 1. Lo que está bien hecho, y hay que decirlo

Antes de los hallazgos, porque condiciona cómo leerlos.

**Los javadoc de este circuito son excepcionales.** No describen *qué* hace el método —eso
se lee en el código— sino **por qué está así y qué defecto histórico corrige**. El de
`registrarPedidoDelAlta` explica en cinco líneas el bug más profundo que tuvo el circuito
(el pedido quedaba apuntando al traslado preexistente, así que aprobar marcaba el traslado
viejo). Eso es documentación que se sostiene sola.

**`registrar()` está extraído a propósito y por la razón correcta.** El javadoc lo dice:
la bifurcación «nace aprobado si tiene el permiso» es *«la parte fácil de reimplementar mal
en el segundo llamador, y es justamente la que decide si el traslado baja a logística
marcado»*. Es exactamente el criterio con el que se decide extraer un método.

**El camino del alta valida lo que tiene que validar.** `tieneIntencionDePedidoDuplicado()`
exige justificación **no vacía** —*«la intención es la justificación con texto: un string
vacío o en blanco no es un pedido»*— y la falta de solicitante corta el alta entera con una
excepción explícita, en lugar de guardar un pedido que nadie podría ver. El requisito
«sin justificación no hay pedido» **se cumple**.

**El riesgo R-8 está corregido.** `aprobar()` tiene su bloque de transporte público, con el
estado de logística, el tramo de vuelta y la marca. El SDD §11 lo declara abierto
(*«la marca nunca se escribe para transporte público»*) y **ya no lo está**. Es la cuarta
vez en esta revisión que la documentación resulta peor que el código.

---

## 2. Hallazgos

### REV-01 · El rechazo no comprueba que la cancelación haya ocurrido · **ALTA**

`rechazar()` marca el pedido como RECHAZADA y después pide la cancelación del traslado:

```java
restInvokeService.fetchLogisticaOnCancelacion(
    pedido.getIdTraslado(), pedido.getIdTrasladoTransportePublico(),
    request.getIdAutorizante(), Constantes.MOTIVO_ANULACION_ALARMA_REPETIDA, observacion);
```

**El método devuelve `void`.** Verificado en `IRestInvokeService:50`. No hay forma de saber
si la cancelación se concretó.

Si `wslogistica` responde con un fallo **sin lanzar excepción** —un 200 con cuerpo de
error, un tramo ya facturable, el prestador que rechaza la baja— el pedido queda
**RECHAZADA** y el traslado **sigue vigente**. Y como venía con `id_estado_logistica_ida`
nulo, queda en el peor estado posible: **vivo, sin cancelar, e invisible para logística**.
Nadie lo va a ver nunca, ni el sector ni el gestor.

Es el mismo modo de falla que la decisión **D5** identificó y arregló para la salida
«anular el preexistente» —donde el endpoint devolvía un 200 vacío y el front daba por
cancelado un traslado vigente— y que acá quedó **sin arreglar en el camino del rechazo**.

**No es teórico.** En DEV existe hoy esta divergencia: el pedido 1 figura **PENDIENTE** y
su traslado está **Cancelado con motivo 16 y con `id_estado_logistica_ida = 6`**. Los dos
lados de esta operación ya se desincronizaron en la práctica.

**Corrección.** Que `fetchLogisticaOnCancelacion` devuelva el resultado real —igual que se
hizo con `cancelar-por-turno` en D5— y que `rechazar()` no confirme el rechazo si la
cancelación no se concretó. Mientras eso no esté, RF-3.5 («al rechazar, el traslado se
cancela con motivo 16») es una **expectativa, no una garantía**.

---

### REV-02 · Un pedido se aprueba aunque su traslado no exista, en silencio · **ALTA**

`aprobar()` resuelve el traslado con `.ifPresent(...)`:

```java
trasladoRepository.findById(pedido.getIdTraslado())
    .ifPresent(traslado -> { /* estado de logística + marca */ });
...
return ResultadoAutorizacionDuplicadoDTO.aprobada(...);
```

Si el traslado **no está**, el bloque no corre, no se loguea nada, y el método **devuelve
`aprobada(...)` igual**. Queda un pedido en estado APROBADA sin ningún efecto: sin estado
de logística y sin marca. Para el autorizante la operación fue exitosa; para el circuito no
pasó nada.

El mismo patrón está en el bloque de transporte público.

Este es el estado que el circuito **no puede permitirse**, porque es indistinguible del
correcto desde cualquier pantalla: la grilla de pendientes ya no lo lista (está resuelto),
la card del solicitante dice «aprobado», y logística nunca lo recibe.

**Corrección.** Que el `orElseThrow` reemplace al `ifPresent`, o como mínimo que loguee en
`WARN` y devuelva un resultado distinto de `aprobada`. Un pedido aprobado que no encontró
su traslado es una inconsistencia, no un éxito.

---

### REV-03 · La justificación sin `@Size` tira abajo el alta completa del turno · **ALTA**

La columna es `justificacion VARCHAR(1000) NOT NULL` (verificado en base). Ni
`PedirAutorizacionDuplicadoDTO.justificacion` ni
`GenerarTrasladoDTO.justificacionTrasladoDuplicado` declaran `@Size`, y ningún `@Column`
declara `length`.

El SDD lo registra como **R-11** con severidad «deuda barata de cerrar». **En el camino del
alta es bastante más que eso.** El pedido se registra *dentro* de la transacción que crea el
turno, con `rollbackFor = Exception.class`. Entonces una justificación de 1.001 caracteres:

1. pasa la validación del DTO,
2. explota en el `INSERT` con error de truncamiento,
3. **revierte el alta entera** — turno, traslado y pedido,
4. y el `catch (Exception)` del controller la convierte en un **500 con el mensaje crudo de
   JDBC**.

El gestor pierde todo el wizard de tres pasos y recibe un error que no le dice qué hacer.
Y el disparador es que se le fue la mano escribiendo: exactamente lo que el circuito le
pide hacer, porque la justificación es *«el único texto que va a leer quien autoriza»*.

**Corrección.** `@Size(max = 1000)` en los dos DTO y `length = 1000` en el `@Column`. Es una
línea por lugar y evita el peor modo de falla del alta.

---

### REV-04 · La auto-aprobación decide sobre un identificador del cuerpo del pedido · **ALTA · seguridad**

```java
boolean puedeAutorizarse = tienePermisoParaAutorizar(idSolicitante);
```

`idSolicitante` llega **en el body**, tanto por `pedir()` como por el alta
(`GenerarTrasladoDTO.getIdSolicitanteTrasladoDuplicado()`). El controller **no tiene
`@PreAuthorize`, `@Secured` ni `@RolesAllowed`**, y verifiqué en vivo que los endpoints de
`wsturnos` responden **sin token** en DEV y en TEST.

El SDD lo registra como **R-1** apuntando a `resolver()`. **El camino del alta es peor**, y
por dos motivos:

- En `resolver()` la suplantación deja rastro: hay un pedido previo, con su solicitante y su
  fecha, que alguien puede auditar. En el alta, mandar el id de un supervisor produce un
  pedido que **nace aprobado a nombre de esa persona** y el traslado baja a logística
  marcado. **No queda ningún pendiente que nadie revise.**
- La auto-aprobación **no exige dictamen ni ninguna segunda mirada**. O sea que reproduce
  exactamente el problema autodeclarativo que el change vino a cerrar —el campo que
  «lo completa el mismo gestor que carga el turno y no hay nada del otro lado»— ahora con un
  permiso en el medio y con la traza a nombre de otro.

**Corrección.** Resolver la identidad **del token**, no del cuerpo. Mientras eso no esté,
el permiso `autorizar_traslado_mismo_dia` es **evitable**, y con él el circuito entero.

---

### REV-05 · Confirmados del SDD, con su lectura de revisión

| ID | Qué | Lectura |
|---|---|---|
| **R-7** | `resolver()` sin `@Version`, sin `FOR UPDATE` y sin constraint. El guard lee `pedido.getEstado()` **en memoria** | Confirmado. RF-2.8 («un pedido resuelto no se puede volver a resolver») es **probable, no garantizado**. El costo de cerrarlo es un `@Version` en la entidad |
| **R-10** | `rechazar()` hace una llamada REST **dentro** de `@Transactional` | Confirmado, y se agrava con REV-01: la transacción queda tomada esperando a `wslogistica`, y el único mecanismo que hoy protege la consistencia es que la excepción reviente |
| **D-4** | Dictamen obligatorio al rechazar, sin enforcement server-side: `request.getDictamen() != null ? ... : Constantes.VACIO` | Confirmado. La obligatoriedad vive sólo en el formulario |
| **API-02** | `tienePedidoDeExcepcion()` usa `anyMatch` sobre toda la lista histórica | Confirmado sobre `TrasladoDuplicadoValidator:413`. El rechazo se neutraliza **en las dos direcciones**: basta un pedido *pendiente* posterior. Rompe **RF-4.3** |
| **R-2** | `contarPendientes()` es `countByEstado(1)` **global**, sin alcance | Confirmado. El contador de la card y las filas de la grilla pueden no coincidir |

---

## 3. Corrección a un hallazgo propio: el motivo 16

En las exploratorias reporté **EXP-04** —que el motivo 16 es «Cancelado por alarma
repetida» y no un motivo de duplicado— con el encuadre de que el PRD lo había rebautizado
por error. **El código muestra que la decisión fue deliberada**, y el javadoc de
`rechazar()` la explica:

> *«con el motivo 16 «Cancelado por alarma repetida», que es el del traslado duplicado y el
> que el sector traslados ya viene usando a mano unas 130 veces por mes»*

Es decir: el equipo sabía cómo se llama el motivo y eligió reusar el que el sector **ya
usa** para este caso, en lugar de crear uno nuevo. Es una decisión razonable de adopción.

**Lo que sigue en pie del hallazgo es el problema de medición, no el de nomenclatura.** El
PRD justifica el desarrollo diciendo que el duplicado no se puede medir porque el motivo
específico «subestima el volumen real». Si el circuito cancela con ese mismo motivo, **sigue
sin poder medirse**: no hay forma de separar los rechazos del circuito nuevo de las
cancelaciones manuales del sector. Y sin eso no se puede responder la pregunta que
justifica el proyecto: ¿bajaron los 2.156 casos anuales?

**Corrección propuesta, más barata que un motivo nuevo:** el conteo por estado de
`autorizaciones_traslado_duplicado` ya distingue perfectamente los rechazos del circuito.
Alcanza con exponerlo como métrica —que es la recomendación 7 del propio SDD §12.4— en
lugar de intentar medirlo por el motivo de anulación.

---

## 4. Prioridad sugerida

En orden de retorno, no de severidad nominal:

1. **REV-04** — la identidad por token. Es lo único que hace que el permiso signifique algo.
2. **REV-03** — `@Size(max = 1000)`. Dos líneas, y evita que el gestor pierda el wizard entero.
3. **API-02** — el `anyMatch` por el primero de la lista ordenada. Es el agujero de RF-4.3.
4. **REV-02** — `ifPresent` → error explícito. Evita el estado indistinguible del correcto.
5. **REV-01** — que la cancelación devuelva su resultado. Es el mismo arreglo que D5 ya hizo
   en el camino de al lado.
6. **R-7** — un `@Version` en la entidad, y RF-2.8 pasa de probable a garantizado.
7. **Métrica del conteo por estado**, que cierra la pregunta de negocio del proyecto.

Los cuatro primeros son de bajo costo y cubren los dos requisitos que hoy no se cumplen
(RF-4.3 y la obligatoriedad del dictamen) más el peor modo de falla del alta.

---

## 5. Deuda estructural que este change expone

- **`autorizaciones.id_autorizacion` no es `AUTO_INCREMENT`**: lo asigna un
  `@TableGenerator` sobre la tabla `key_generator`. Cualquier carga de datos por SQL que
  inserte autorizaciones **rompe el alta de turnos de toda la base** con
  `constraint [PRIMARY]`, y no lo advierte ninguna guía. Ocurrió en esta misma sesión.
  Además las filas `ID_TURNO` (4.558.515 contra un máximo real de 4.561.099) e
  `ID_TRASLADO` están desincronizadas hace tiempo: quedaron vestigiales porque esas dos
  columnas **sí** son `AUTO_INCREMENT`. Conviene decidir si se limpian o si
  `id_autorizacion` se pasa a `AUTO_INCREMENT`.
- **Cero tests de la máquina de estados.** `pedir`, `resolver`, la auto-aprobación, el guard
  de «ya resuelto», `aprobar()` —donde se enciende la marca— y `rechazar()` —donde se fija el
  motivo— no tienen ninguno. Cuatro de los cinco hallazgos de esta revisión los habría
  atrapado un test de `aprobar()` y uno de `rechazar()`.
- **`wslogistica` no corre sus tests en el build** (`<skipTests>true</skipTests>` en el
  `pom.xml`): 47 tests escritos que el pipeline no ejecuta. Sacar esa línea es lo de mejor
  relación costo/beneficio de toda la lista.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

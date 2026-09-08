# PRD — Autorización de traslados duplicados del mismo día

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Fecha** | 14/08/2026 |
| **Ticket** | **INI-2** (triage inbox, no Jira) |
| **Referentes funcionales** | Silvio (Logística) y Karen — reunión del 06/08 · Yanina Di Prima, observación que reformuló el circuito |
| **Validado con** | Reunión del 06/08 · mediciones sobre datos de producción 2026 verificadas en base · circuito de Cirugías relevado en TEST |
| **Ambiente** | **DEV** completo. En **TEST** están la base y dos de los cuatro servicios (faltan `wslogistica` y `wstraslados`). Sin promover a stage ni producción. |

---

## 1. Objetivo

Que un segundo traslado del mismo día para el mismo paciente **exista sólo si alguien con autoridad lo autorizó**, y que esa autorización quede registrada.

Hoy el sistema ya afirma que esa autorización existe: cuando detecta el duplicado obliga a elegir un motivo, y el catálogo tiene exactamente dos opciones, «Autorizado por Supervisión» y «Autorizado por Auditoría Médica». Pero **el campo es autodeclarativo**: lo completa el mismo gestor que carga el turno y no hay nada del otro lado.

> **El dato que sostiene todo el desarrollo:** en 2026 se registraron **2.156 traslados duplicados** declarando una autorización que **nunca existió** (1.216 «por Supervisión» + 940 «por Auditoría Médica»). Son unos 285 por mes. El gate arrancó este año; en 2025 fueron 184 en total.

No estamos agregando un circuito nuevo: **estamos haciendo real el que el sistema ya dice que tiene**.

---

## 2. Contexto y problema

### 2.1 El volumen real es dos órdenes de magnitud mayor al estimado

En la reunión del 06/08 se estimó el problema en unos **4 casos por mes**. Medido sobre la base:

| Métrica 2026 | Valor |
|---|---|
| Días-paciente por mes con más de un traslado vigente | **307** |
| Enero → Junio | 254 → **394** (creciente) |
| Duplicados con motivo declarado (la autorización inexistente) | 2.156 |
| Duplicados **sin** motivo declarado | ~58 por mes |

### 2.2 Por qué el problema no se ve en los números de logística

Logística cancela los duplicados que detecta, pero el motivo que usa no permite medirlos: **«OTROS MOTIVOS» concentra 10.869 de ~15.900 anulaciones (68%)**, y el **47%** de ellas no tiene observación escrita. El motivo 16 **subestima** el volumen real, así que no sirve como línea de base.

> **Precisión del 19/08/2026.** Este párrafo llamaba al 16 «el motivo específico de duplicado», y **no lo es**: en el catálogo `motivos_anulacion` se llama **«Cancelado por alarma repetida»**, y **ninguno de los 23 motivos** refiere a traslados duplicados. El código lo nombra bien —la constante es `MOTIVO_ANULACION_ALARMA_REPETIDA`— y el javadoc de `rechazar()` explica la decisión: se reusa **el que el sector traslados ya viene usando a mano** para este caso, unas 130 veces por mes. Es una decisión razonable de adopción, no un error.
>
> **Lo que sí queda en pie es el problema de medición, y ahora aplica al circuito nuevo.** Si el rechazo cancela con el mismo motivo que las cancelaciones manuales del sector, **los dos siguen siendo indistinguibles**, y la pregunta que justifica este proyecto —«¿bajaron los 2.156 casos anuales?»— sigue sin poder responderse.
>
> **La salida es más barata que crear un motivo nuevo:** el conteo por estado de
> `autorizaciones_traslado_duplicado` ya separa perfectamente los rechazos del circuito de
> cualquier otra cancelación. Alcanza con exponerlo como métrica, que es la recomendación 7 del
> SDD §12.4. **Diferido a etapa 2 por decisión de negocio del 19/08** (no hace falta medir hoy).

### 2.3 Quién paga el problema

Un segundo traslado no autorizado se traduce en un remis pedido a una agencia, con costo, para un paciente que ya tenía viaje. Cuando logística lo detecta, lo cancela — a veces con la agencia ya avisada. Cuando no lo detecta, se paga.

---

## 3. Usuarios y permisos

| Rol | Permiso | Qué puede hacer |
|---|---|---|
| **Gestor / operador de tramitadores** | *sin* `autorizar_traslado_mismo_dia` | Ve el conflicto y elige una de tres salidas. Puede **pedir** la autorización, pero no declararla ni concederla. **Ve en su home la card con el resultado de sus pedidos.** |
| **Referente / supervisor / jefe de siniestros / gerente de siniestros** | **con** `autorizar_traslado_mismo_dia` | Además de las tres salidas, puede **autorizar en el acto** su propio duplicado. Ve la card en el home y resuelve los pedidos de los demás. |
| **Sector Logística** | *(no participa del circuito de autorización)* | Recibe el traslado **sólo si fue autorizado**, y lo ve marcado como duplicado autorizado. |
| **Equipo SAS** | — | Alta del permiso por perfil. |

**El permiso es el único discriminador.** No se usa el rol: la habilitación se resuelve con `hasPermission`, igual que las tabs de la grilla de Turnos. Perfiles a los que se asigna: **3, 2, 9 y 10**.

> ⚠️ **En DEV el permiso quedó con `id_permiso = 1000`, no 101** como decía el script. Corregir el script antes de aplicarlo en TEST y PROD.

---

## 4. Alcance

### 4.1 Incluido

- Detección del conflicto con el **estado operativo real** del traslado que ya existe (a qué hora, a qué centro, qué agencia, si ya se le avisó).
- Tres salidas resolubles **sin salir del drawer**.
- Circuito de pedido y resolución con registro de quién, cuándo y por qué.
- Card en el home de quien autoriza, con contador, y grilla filtrada a los pendientes.
- **Card en el home de quien pide**, con el resultado de sus pedidos y el dictamen de quien los resolvió.
- Validación en el backend, para que el gate no dependa del front.
- Marca del duplicado autorizado en la grilla de logística.

### 4.2 Excluido explícitamente

- **Solicitudes genéricas (SG)**: descartado. Se sigue el patrón de **Cirugías**, que es el circuito de aprobación que el sistema ya tiene.
- **Doble instancia de autorización**: existe modelada en `autorizaciones` (estado 4 + segundo autorizante) y tiene **cero usos en 2026**. No se implementa.
- **Retroactividad**: no se toca ninguno de los 2.156 casos ya registrados.
- **El 68% de anulaciones sin motivo específico**: es un problema de calidad de datos de logística, anterior a esto.

---

## 5. El circuito, en cuatro momentos

| # | Quién | Qué pasa |
|---|---|---|
| 1 | **Gestor** | Carga el segundo turno del día con traslado. El bloque de conflicto le muestra el traslado que ya existe y las salidas habilitadas. Elige una. |
| 2 | **Sistema** | Si pidió autorización, registra el pedido en estado **pendiente** con su justificación. **El turno se guarda**; lo que espera es el traslado. |
| 3 | **Quien autoriza** | Ve la card en el home con el contador. Entra a la grilla ya filtrada, lee la justificación, y **aprueba o rechaza dejando un dictamen**. |
| 4 | **Sistema** | **Aprobado:** el traslado recibe estado de logística y baja al sector. **Rechazado:** el traslado se cancela con motivo, y logística nunca lo vio. |

**Decisión tomada:** el turno se guarda en el momento del pedido y sólo el traslado espera. La alternativa —no guardar nada hasta la aprobación— obliga al gestor a cargar todo de nuevo y en la práctica lo empuja a no pedir. El turno médico no tiene nada que autorizar.

---

## 6. Requisitos funcionales

### Bloque 1 — El bloque de conflicto (lo que ve el gestor en tramitadores)

**RF-1.1** Al cargar un turno con traslado en una fecha donde el paciente **ya tiene un traslado vigente**, se muestra un bloque de conflicto. Vigente = cualquier estado excepto **Cancelado (4)** y **Rechazado (5)**.

**RF-1.2** El bloque identifica el traslado en conflicto **por sus datos, nunca por su id**: número de turno, tipo de turno, hora, centro médico y agencia. Y su estado operativo: en qué estado de logística está y **si a la agencia ya se le avisó del viaje** — porque anular un viaje ya avisado no es lo mismo que anular uno que todavía no salió.

**RF-1.3** El gestor **elige una** de tres salidas excluyentes. No son tres botones sueltos: es una elección, y cada opción explica qué implica antes de elegirla.

| Salida | Qué hace | Quién la ve |
|---|---|---|
| **Anular ese traslado y usar el nuevo** | Cancela el traslado preexistente con motivo y observación | Todos (si el backend la habilita) |
| **Guardar el turno sin traslado** | El paciente viaja con el que ya tiene. Destilda «requiere traslado» | Todos |
| **Pedir autorización** / **Autorizar los dos** | Según el permiso: pide, o autoriza en el acto | Todos, con distinta forma |

**RF-1.4** **Qué salidas están habilitadas lo decide el backend**, caso por caso, según el estado operativo. El front sólo las renderiza. Si mañana cambia la política de qué se puede anular, el front no se toca.

**RF-1.5** En una tanda de rehabilitación el bloque informa **en cuántas de las fechas** hay conflicto, no que alguna lo tenga.

### Bloque 2 — Pedir y resolver

**RF-2.1** El gestor **sin** el permiso escribe una **justificación obligatoria** y envía el pedido. Es el único texto que va a leer quien resuelve, y es el filtro real contra el pedido hecho por las dudas.

**RF-2.2** El gestor **con** el permiso resuelve en el acto: declara el motivo y el pedido queda **aprobado y registrado a su nombre**, sin pedirse autorización a sí mismo.

**RF-2.3** Mientras el pedido está pendiente, el traslado **no baja a logística** (ver Bloque 3).

**RF-2.4** Quien autoriza ve una **card en el home** con la cantidad de pedidos pendientes, que lleva a la grilla ya filtrada. La card sólo aparece si tiene el permiso **y** hay pedidos.

**RF-2.5** En la grilla, cada fila muestra el solicitante, la fecha del pedido y la justificación. Las acciones son: **ver detalle**, **gestionar autorización** y **ver información de traslado**.

**RF-2.6** Al resolver: **el dictamen es obligatorio para rechazar** y opcional para aprobar. Rechazar sin explicación deja al gestor sin saber qué hacer con el turno.

**RF-2.7** Si dos personas abren el mismo pedido, **el segundo recibe un aviso de que ya fue resuelto** y no lo pisa. No es un error: es información, y la grilla se refresca.

**RF-2.8** Un pedido resuelto **no se puede volver a resolver**.

**RF-2.9** **Quien pidió la autorización se entera del resultado.** En su home ve una card con la cantidad de pedidos resueltos que todavía no vio; al entrar accede a la lista con, por cada uno: el resultado, **quién lo resolvió** (por su nombre), cuándo, **el dictamen** y la justificación que él mismo había escrito. Al entrar, los pedidos quedan marcados como vistos y la card se apaga sola.

El dictamen es lo más importante de esa pantalla: es lo único que le explica **por qué** le dijeron que no. Sin esto, el dictamen obligatorio del rechazo no le llega a nadie.

**RF-2.10** **La card del resultado la ve quien pide, no quien aprueba.** La ven todos los tramitadores que puedan cargar un turno con traslado y **no** tengan el permiso `autorizar_traslado_mismo_dia`; queda excluido el referente, el jefe de siniestros y el gerente, que ya tienen la card de pedidos **pendientes**. Y sólo aparece cuando hay algo que mostrar.

### Bloque 3 — Cómo interviene logística en cada caso

Esta es la parte que más se cuidó, porque logística **atraviesa todos los casos** y el circuito no debe generarle ruido.

**RF-3.1 — La llave de visibilidad.** Lo que decide si logística ve un traslado **no es el estado del traslado**: es que **`id_estado_logistica_ida` no sea nulo**. Se verificó sobre el stored procedure del listado, que **no filtra por estado de traslado en ningún momento**.

> Evidencia: **6.188 traslados de 2026 tienen ese campo nulo** y por eso logística no los ve — **266 de ellos en estado Solicitado**. O sea: ya existen hoy traslados solicitados que todavía no bajaron al sector. El mecanismo no es una invención de este desarrollo.

**RF-3.2 — Caso pendiente de autorización: logística NO lo ve.** El traslado se crea con el estado de logística **nulo**. Esto es deliberado y corrige la primera versión de la propuesta: **el traslado no pasa a «Solicitado»**, porque no está solicitado hasta que alguien autoriza. Si fuera a Solicitado con estado de logística cargado, logística lo vería y lo cancelaría como duplicado, que es exactamente el ruido que se quiere evitar.

**RF-3.3 — Caso aprobado: baja a logística como cualquier traslado.** Al aprobar se le asigna el estado de logística **Solicitado** y recién ahí aparece en la grilla del sector.

**RF-3.4 — Caso aprobado: llega marcado.** La fila se distingue con **franja de color propia, ícono con tooltip y su entrada en la leyenda al pie**. Sin la marca, logística vería dos traslados el mismo día y cancelaría uno, deshaciendo la autorización.

> **No se reusa `requiere_revision`** para esto: significa «algo salió mal, mirá esto» (798 casos en 2026) y compartir la señal dejaría a logística sin poder distinguir un duplicado autorizado de un traslado con problema.

**RF-3.5 — Caso rechazado: logística nunca se enteró.** El traslado se cancela con el motivo de anulación **16** y nunca tuvo estado de logística.

**RF-3.6 — Caso «anular el preexistente»: logística sí participa.** Es el único caso donde logística **ya tenía** el traslado en su grilla. La cancelación se hace **con el circuito de cancelación que ya existe** (el mismo que dispara el drawer de cancelar traslado), no con uno nuevo, y **cancela todos los tramos** del turno: ida, vuelta y transporte público.

**RF-3.7 — El resultado de la anulación se muestra antes de guardar.** Si el traslado quedó vigente —el prestador rechazó la baja, o un tramo ya es facturable— el gestor lo tiene que ver **en el bloque**, con las otras salidas todavía disponibles.

**RF-3.8 — Dos redes independientes.** El estado del traslado es lo que ve el gestor; el estado de logística nulo es lo que lo mantiene fuera de la grilla. Si alguien toca el estado del traslado por error, sigue invisible para logística.

### Bloque 4 — El gate no puede vivir sólo en el front

**RF-4.1** El backend **rechaza** el alta o la programación de un turno con segundo traslado del mismo día si no hay ni motivo declarado ni pedido de excepción. Responde **409 CONFLICT** con un mensaje explicativo.

**RF-4.2** Acepta: motivo declarado, pedido **pendiente**, o pedido **aprobado**.

**RF-4.3** **Rechaza explícitamente un pedido RECHAZADO.** Si esto no valiera, alcanzaría con pedir la excepción y que te la nieguen para cargar el traslado igual.

**RF-4.4** Cualquier endpoint nuevo que cree o programe turnos **debe invocar esta validación**, igual que con la regla SE-214.

### Bloque 5 — Regla transversal de presentación

**RF-5.1** **Nunca se muestra un identificador *interno* al usuario.** Ni de traslado, ni de autorización, ni de persona. Todo se nombra por código, descripción, fecha, hora o nombre. Aplica también a los textos que se guardan: la observación de anulación nombra el turno por su tipo y hora, no por un identificador interno.

**La excepción es el número de turno**, que **sí se muestra**. No es un identificador interno: es el dato con el que el gestor, logística y el prestador nombran el turno entre ellos y por teléfono, y es el que aparece en el resto de las pantallas del sistema. Prohibirlo obligaría al usuario a salir a averiguar de qué turno se le está hablando, que es justo lo que la regla quiere evitar.

> **Revisión del 19/08/2026.** La versión anterior decía «ni de turno», lo que contradecía a **RF-1.2** —que enumera el número de turno entre los datos con los que se identifica el traslado en conflicto— y convertía en defecto algo que la pantalla hace bien. Se resolvió a favor de RF-1.2: **se corrige el requisito, no el código.** Con esto quedan sin efecto los hallazgos de QA que reportaban el número de turno en pantalla como violación de esta regla.

---

## 7. Dónde queda y quién ve cada texto que se escribe

El circuito produce cuatro textos. **Este cuadro es el estado real hoy, no el deseado.**

| Texto | Lo escribe | Se guarda en | Lo ve | Dónde |
|---|---|---|---|---|
| **Justificación** del pedido | Gestor que pide | `autorizaciones_traslado_duplicado.justificacion` | Sólo quien autoriza, **sólo mientras está pendiente** | Grilla de pendientes (truncada, completa en tooltip) y drawer de resolución (completa) |
| **Dictamen** de la resolución | Quien autoriza | `autorizaciones_traslado_duplicado.dictamen` (1000 car.) | **NADIE** | ⚠️ **Ninguna pantalla** |
| **Observación de anulación** | Gestor que anula | `traslados.observaciones_anulacion` (500) / `traslados.observaciones_anulacion_vuelta` (255) / `traslados_transporte_publico.observaciones_anulacion` (2500) y su `_vuelta` (255) | Logística y quien consulte el traslado | Historial de traslados y consulta del traslado |
| **Marca de duplicado autorizado** | El sistema | `traslados.es_duplicado_autorizado` | Logística | Franja, ícono y tooltip en su grilla |

### 7.1 Los cuatro huecos de trazabilidad — **tres cerrados, uno abierto**

> ### ⚠️ Actualización del 19/08/2026 — verificado en DEV y en TEST
>
> **H-1, H-2 y H-3 están cerrados.** Esta sección los describía como abiertos y **quedó
> desactualizada respecto de su propio código**: la capability `devolucion-resultado-solicitante`
> se implementó y está desplegada.
>
> Lo verificado, navegando los dos ambientes con los dos perfiles:
>
> - **Existe la pestaña «Autorización Doble Traslado Resuelta»** para quien pidió, y lista los
>   pedidos con **Resultado**, **Lo resolvió** —por su nombre—, **Fecha de la respuesta**,
>   **Dictamen** y **Mi justificación**.
> - **Existe el contador** de resueltos sin ver, que enciende la card del home
>   (`mis-duplicados-resueltos`), y el **marcado de vistos** que la apaga
>   (`marcar-duplicados-vistos`).
> - La nomenclatura es **excluyente y correcta**: quien autoriza ve «…Pendiente», quien pide ve
>   «…Resuelta», y nunca las dos.
>
> **H-4 sigue abierto**, y se confirmó con evidencia de las tres capas: los stored procedures no
> devuelven al autorizante, el DTO no declara el campo, y la respuesta del listado de logística
> trae `esDuplicadoAutorizado` pero **ningún dato de identidad** entre sus 53 campos. El bundle
> desplegado sí tiene la rama que usaría el nombre, así que es **texto muerto**.
>
> El detalle está en `SENTINEL QA/02-verificacion-ambientes/verificacion-aplicacion.md` y en
> `SENTINEL QA/05-evidencia/verificacion-grilla-logistica.md`.

Lo que sigue es la redacción original, **conservada a propósito**: es el estado en que se
tomaron las decisiones del circuito, y explica por qué el dictamen se hizo obligatorio.

**H-1 — ~~El dictamen no se lee en ninguna parte.~~ CERRADO.** Se escribe, se guarda, y **no viaja en ningún endpoint de lectura**: el listado de pendientes no lo devuelve y ninguna pantalla lo muestra. **Se lo hizo obligatorio al rechazar con el argumento de que «es lo único que le vuelve al gestor», y no le vuelve nada.**

**H-2 — ~~El gestor nunca se entera del resultado.~~ CERRADO.** Ni aprobado ni rechazado. No hay notificación, ni card, ni indicador en el turno. Se entera cuando el traslado aparece —o no aparece— o cuando pregunta.

**H-3 — ~~La justificación desaparece al resolverse.~~ CERRADO.** El listado sólo trae pendientes, así que una vez resuelto el pedido nadie puede releer por qué se pidió. Se pierde la posibilidad de auditar el criterio con el que se autoriza.

**H-4 — El tooltip de logística nunca dice quién autorizó. SIGUE ABIERTO.** El front espera el nombre del autorizante y **el backend no lo manda**, así que siempre cae al texto genérico «duplicado autorizado».

> **La raíz común valía para los cuatro:** el circuito estaba completo para **conceder** la
> autorización y no para devolver el resultado. **Esa mitad ya se construyó** — salvo el nombre
> del autorizante en la grilla de logística, que es H-4.

---

## 8. Casuísticas completas

Cada fila es un caso a probar. «Logística» es qué ve el sector.

| # | Situación | Salida elegida | Permiso | Resultado esperado | Logística |
|---|---|---|---|---|---|
| C-01 | Paciente sin traslado ese día | — | cualquiera | No hay bloque de conflicto | Recibe el traslado normal |
| C-02 | Ya tiene traslado vigente | Anular el preexistente | cualquiera | Se cancela el viejo con motivo y observación; el nuevo sigue | **Ve la cancelación** del que ya tenía |
| C-03 | Ya tiene traslado vigente | Sin traslado | cualquiera | Se destilda «requiere traslado»; el turno se guarda solo | No recibe nada nuevo |
| C-04 | Ya tiene traslado vigente | Pedir autorización | **sin** permiso | Pedido **pendiente**; el turno se guarda; el traslado espera | **No lo ve** |
| C-05 | Ya tiene traslado vigente | Autorizar los dos | **con** permiso | Pedido **aprobado** en el acto, a su nombre | **Lo recibe marcado** |
| C-06 | Pedido pendiente | Aprobar | con permiso | Traslado con estado de logística; flag de duplicado autorizado | **Lo recibe marcado** |
| C-07 | Pedido pendiente | Rechazar **con** dictamen | con permiso | Traslado cancelado con motivo 16 | **Nunca lo vio** |
| C-08 | Pedido pendiente | Rechazar **sin** dictamen | con permiso | **No se permite**: el dictamen es obligatorio | — |
| C-09 | Pedido ya resuelto por otro | Aprobar o rechazar | con permiso | Aviso de «ya resuelto»; no se pisa la resolución | Sin cambios |
| C-10 | Alta directa por API, sin motivo ni pedido | — | — | **409 CONFLICT**, no se crea nada | — |
| C-11 | Alta con pedido **rechazado** | — | — | **409 CONFLICT**: el rechazo no habilita | — |
| C-12 | Alta con pedido **pendiente** | — | — | Se permite: alguien lo va a resolver | No lo ve hasta la aprobación |
| C-13 | Tanda de rehabilitación con varias fechas en conflicto | cualquiera | cualquiera | Informa **en cuántas** fechas hay conflicto | Según la salida, por fecha |
| C-14 | Anulación que logística rechaza (tramo facturable) | Anular | cualquiera | Se informa el resultado **antes** de guardar; las otras salidas siguen disponibles | El traslado sigue vigente |
| C-15 | Turno sin fecha (plan de rehabilitación) | — | — | No se valida al crear; se valida **al programar** | — |
| C-16 | Denuncia cerrada o rechazada | — | — | Puede bloquearse antes, por **SE-214** | — |

---

## 9. Supuestos y dependencias

- La tabla `autorizaciones_traslado_duplicado` **no existe en producción**. **Primero la tabla, después el resto**; el listado la referencia con INNER JOIN.
- El reemplazo de los stored procedures de logística tiene una **ventana sin procedure** (MariaDB no admite `CREATE OR REPLACE PROCEDURE`). Coordinar fuera del horario de logística.
- Se verificaron **19 stored procedures** de traslados: **ninguno hace `SELECT *`**, así que agregar la columna es inocuo. Igual se agregó **al final** del SELECT.
- `wsturnos` y `wslogistica` corren sobre **Spring Boot 2.1.2, EOL**, y `wsturnos` está en producción como **SNAPSHOT**.
- Los ambientes bajos se despliegan por **CodePipeline** con webhook automático; el Jenkinsfile es código muerto para dev/test/stage.

---

## 10. Riesgos conocidos

| # | Riesgo | Estado |
|---|---|---|
| R-1 | **Los endpoints del circuito responden sin autenticación en DEV**, y validan el permiso contra un id que viaja **en el body**. Alguien podría aprobar su propio duplicado pasando el id de un supervisor. | **Confirmar que en stage y prod queden detrás del gateway.** |
| R-2 | El contador de la card y las filas de la grilla **pueden mostrar números distintos**: el contador es global y el listado queda acotado por los filtros del usuario. | Abierto |
| R-3 | Con el filtro de alcance **como estaba** (decisión del 14/08), quien autoriza ve sólo los pedidos de su alcance. **Un pedido de otra cartera puede quedar sin quien lo resuelva.** | A verificar en la prueba |
| R-4 | El catálogo de motivos llega **mezclado**: el front no pasa el tipo, aunque el backend ya lo soporta. Arreglarlo requiere hacerlo para los dos consumidores juntos, por el cache compartido. | Abierto |
| R-5 | «Anular ese traslado» cancela **todos los tramos** del turno, pero el texto habla en singular. | Ajustar el texto |
| R-6 | El escapado de i18n sigue activo para el resto de la aplicación: cualquier otro texto que interpole una fecha o una URL tiene el mismo defecto que se corrigió acá. | A decidir |

---

## 11. Preguntas abiertas

1. **¿Se conserva el motivo autodeclarativo?** Hoy conviven el motivo declarado y la autorización real. El motivo se mantuvo para que sigan funcionando las versiones del MFE que todavía no tienen el circuito. **¿Cuándo se retira?**
2. **¿Qué se hace con los 2.156 casos históricos?** No se toca nada, pero queda la pregunta de si Auditoría quiere revisarlos.
3. **¿El referente también autoriza, o sólo supervisor y jefe de siniestros?** Define R-3.

---

## 12. Decisiones cerradas

| Decisión | Cuándo | Por qué |
|---|---|---|
| Cualquier gestor puede **pedir**; sólo con permiso se **concede** | Observación de Yani | Una puerta cerrada no elimina la necesidad: la manda por afuera del sistema, y ahí es donde hoy se pierde |
| Se sigue el patrón de **Cirugías**, no solicitudes genéricas | 06/08 | Es el circuito de aprobación que el sistema ya tiene y el usuario ya conoce |
| **Tabla propia** para el pedido | 06/08 | El pedido tiene su propio ciclo y no es una autorización de prestación |
| El traslado pendiente **no va a «Solicitado»** y queda **sin estado de logística** | 06/08 | No está solicitado hasta que se autoriza, y así no genera ruido en logística |
| Al **rechazar**, el traslado **se cancela con motivo** | 06/08 | No queda un traslado huérfano esperando |
| El **turno se guarda**; sólo espera el traslado | 06/08 | Si no, el gestor pierde el trabajo y en la práctica no pide |
| **Dictamen obligatorio** al rechazar, opcional al aprobar | 14/08 | Un rechazo sin explicación vuelve como reclamo |
| **Ningún id a la vista** | 14/08 | Un id no le dice nada al usuario y lo obliga a salir a averiguar |
| **No se amplía el alcance de datos** por perfil | 14/08 | La visibilidad por cartera es una decisión de negocio anterior a este circuito |
| La validación vive **también en el backend** | 14/08 | El gate en el front lo esquiva cualquier otro camino de alta: ~58 casos por mes |
| **El resultado se le devuelve al gestor con una card en su home** | 18/08 | Cierra los huecos H-1 y H-2: hoy el gestor pide y nunca se entera de qué se resolvió. Es el mismo mecanismo que ya usa quien autoriza, así que el usuario no aprende nada nuevo |
| El desarrollo se identifica con el ticket **INI-2** | 18/08 | Viene de triage inbox, no de Jira. Reemplaza las referencias a GRV-2239, que corresponden a «CIE-10 · Trazadoras» |

---

## Nota de revisión — 18/08/2026

Dos correcciones puntuales, disparadas por la auditoría de la §13 del SDD contra el código (ver la nota de revisión de ese documento):

- **§7 — el nombre de la columna.** Decía `traslados.observaciones_anulacion_ida`. Esa columna **no existe**: se llama **`observaciones_anulacion`**, sin sufijo. Verificado en la entidad de `wslogistica` (`Traslado.java:286`, `@Column(name = "observaciones_anulacion")`) y por ausencia del nombre viejo en todo el repo. Importa porque cualquier SQL de soporte escrito contra el nombre inventado falla con «Unknown column». Los tres largos que declaraba (500 / 255 / 2500) estaban bien: coinciden exacto con las constantes de recorte del código.
- **§3 — la tabla de roles.** Nombraba tres roles para los cuatro perfiles a los que el script asigna el permiso. Se agregó el **gerente de siniestros** (perfil 9), que ya figuraba en la prosa de RF-2.10. Queda pendiente confirmar si el supervisor (perfil 10) entra — es la pregunta abierta 5, y el propio script lo marca «PENDIENTE DE CONFIRMAR».

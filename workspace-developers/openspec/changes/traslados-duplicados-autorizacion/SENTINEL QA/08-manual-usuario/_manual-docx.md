# Autorización de traslados duplicados del mismo día

## Manual de usuario del SAS — Colonia Suiza ART

**Cómo cargar, autorizar y coordinar un segundo traslado del mismo día para el mismo paciente.**

| Dato | Detalle |
|---|---|
| **Circuito** | Autorización de traslados duplicados del mismo día |
| **Aplicación** | SAS — Sistema de Administración de Siniestros |
| **Versión del manual** | 1.0 |
| **Fecha** | 19/08/2026 |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |
| **Dirigido a** | Gestores, referentes, jefes de siniestros, analistas y sector Logística |

---

## 1. Para quién es este manual y qué va a encontrar

Este manual explica **un solo circuito**: qué pasa cuando a un paciente se le carga un traslado en un día en el que **ya tiene otro traslado**. El sistema ya no deja seguir de largo: obliga a resolverlo, y deja registrada la decisión.

Está escrito para que lo puedas leer entero en veinte minutos, pero no hace falta: **buscá tu rol y andá directo a tu etapa.**

| Si sos… | Leé | Por qué |
|---|---|---|
| **Gestor / operador de tramitadores** | Capítulos 2, 3 y **4** (Etapa 1), más las Preguntas frecuentes | Sos quien carga el turno y quien se encuentra con el aviso. Tenés que saber elegir entre las tres salidas, y cómo enterarte del resultado de un pedido. |
| **Referente o jefe de siniestros con permiso para autorizar** | Capítulos 2, 3 y **5** (Etapa 2) | Sos quien recibe los pedidos y los resuelve. Lo más importante para vos es el **criterio** de aprobación y por qué el dictamen es lo único que le vuelve al gestor. Si además cargás turnos, leé también la Etapa 1. |
| **Sector Logística** | Capítulos 2, 3 y **6** (Etapa 3) | Vos no participás de la autorización, pero recibís el resultado. Lo que tenés que aprender es **reconocer la marca** de un traslado ya autorizado, y por qué hay traslados que no te van a llegar. |
| **Analista** | Capítulos 2, 3 y los recuadros de advertencia de las tres etapas | Te sirve para entender el circuito completo, saber dónde queda registrada cada decisión y poder explicarle a cada perfil qué esperar. |

Además vas a encontrar, al final:

- **Preguntas frecuentes** (capítulo 7) — las dudas reales: qué pasa si pedís una autorización sin necesitarla, cuánto tarda, cómo te enterás del resultado, qué hacés con el turno si te la rechazan.
- **Glosario** (capítulo 8) — cada término del circuito explicado en lenguaje de trabajo.

> **Sobre los recuadros con ⚠.** Este manual documenta el circuito **tal como funciona hoy**, incluidas las cosas que todavía no funcionan bien. Cada vez que hay algo que te puede confundir o dejar trabado, hay un recuadro que te lo avisa y te dice qué hacer mientras tanto. No están ahí para asustarte: están para que no pierdas tiempo pensando que el problema es tu computadora. Cada uno trae un código (por ejemplo **MAN-G-04**) que podés mencionar si tenés que reportarlo a mesa de ayuda.

> **Versión de este manual: 21/08/2026.** Se escribió recorriendo el sistema, así que refleja el estado de ese día. **Dos defectos que la primera versión documentaba ya se corrigieron** y sus recuadros se quitaron: la salida «Pedir autorización» **ahora se puede completar** al cargar un turno nuevo (eran los defectos MAN-G-01 y MAN-G-02). Si algo de lo que leés acá no coincide con lo que ves en pantalla, puede que se haya arreglado en el medio: avisá y lo actualizamos.

---

## 2. Por qué existe este circuito

Un traslado es un remis o una ambulancia que alguien pide a una agencia, y que **se paga**.

Cuando un paciente tiene dos traslados el mismo día, en general uno de los dos sobra: se reprogramó el turno, se cambió el centro médico, o alguien cargó dos veces lo mismo. Pero a veces **los dos hacen falta de verdad**: dos turnos en centros distintos, muchas horas entre uno y otro, un paciente que no puede moverse solo.

Hasta ahora el sistema pedía elegir un motivo del estilo «autorizado por Supervisión», y ese motivo lo escribía **la misma persona que cargaba el turno**. Nadie del otro lado miraba nada. En la práctica, la autorización se declaraba sola. El resultado: cientos de segundos traslados por mes con una autorización que nunca existió, y un sector de logística cancelando a mano lo que podía detectar, mientras el resto se pagaba.

**Lo que cambia ahora es simple:** un segundo traslado del mismo día existe **sólo si alguien con autoridad lo autorizó**, y esa decisión queda escrita, con nombre, fecha y motivo. No es un circuito nuevo: es hacer real el que el sistema decía tener.

Y trae una ventaja concreta para todos: cuando la decisión está registrada, **nadie tiene que adivinar**. Logística deja de cancelar por las dudas, el gestor deja de justificar por teléfono, y el jefe de siniestros tiene un lugar donde dejar su criterio escrito.

---

## 3. El circuito de un vistazo

Cuatro momentos. En el más común de todos, el circuito **termina en el primero**.

| # | Quién | Qué hace | Qué pasa después |
|---|---|---|---|
| **1** | **El gestor** | Carga el segundo turno del día con traslado. El sistema le avisa que el paciente ya tiene traslado ese día y le pide elegir entre tres salidas: **anular** el que ya existe, **guardar el turno sin traslado**, o **pedir la autorización**. | Si anuló o guardó sin traslado, **acá termina**. Si pidió autorización, sigue al momento 2. |
| **2** | **El sistema** | Registra el pedido como **pendiente**, con la justificación que escribió el gestor. **El turno queda guardado**; lo que queda esperando es el viaje. | El pedido le aparece a quien tiene el permiso para autorizar. Logística todavía **no ve nada**. |
| **3** | **Quien autoriza** (referente o jefe de siniestros) | Ve el pedido en su tablero, lee la justificación y **aprueba o rechaza escribiendo un dictamen**. | Su decisión cierra el pedido. No hay ida y vuelta ni segunda instancia. |
| **4** | **El sistema** | **Si se aprobó:** el traslado pasa al sector de traslados, **marcado** como segundo traslado del día autorizado. **Si se rechazó:** el traslado queda cancelado y Logística nunca lo ve. | El gestor lee el resultado y el dictamen en su pestaña de resueltos. |

Dos aclaraciones que evitan la mitad de las confusiones:

1. **El turno y el traslado son cosas distintas.** El turno médico se guarda siempre: no hay nada que autorizar en una consulta. Lo que espera la autorización es **el viaje**.
2. **Un pedido pendiente frena el traslado.** Mientras nadie resuelva, el traslado no baja a Logística y **nadie pasa a buscar al paciente**. Si el turno es para pronto, avisale a quien tiene que resolverlo.

Y una excepción útil: si vos mismo tenés el permiso para autorizar, no necesitás pedirle a nadie. **Podés autorizar tu propio duplicado en el acto**, a tu nombre, y el traslado baja marcado sin pasar por el momento 2.

---

# 4. Etapa 1 — El gestor: cargar el turno y resolver el conflicto

Esta etapa es para vos si cargás turnos con traslado y **no** tenés el permiso para autorizar traslados duplicados. Es el caso de la mayoría de los gestores y referentes.

## Qué vas a aprender

Cuando le cargás a un paciente un turno con traslado en un día en el que **ya tiene otro traslado**, el sistema te avisa y te obliga a decidir qué hacer. Acá vas a ver cómo se ve ese aviso, qué información te da y **cuál de las tres salidas te conviene** en cada situación.

No hace falta que sepas nada del circuito de antemano. Seguí los pasos en orden.

---

## Paso 1 — Entrá al sistema

Abrí el SAS y completá tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/01-gestor-01-login.png)

Si la pantalla tarda en cargar, esperá: la primera carga del día es la más lenta. No vuelvas a apretar **Ingresar** varias veces.

---

## Paso 2 — Ubicate en tu inicio

Después de entrar llegás a tu tablero, con tus tarjetas de trabajo de siempre: **Mis denuncias**, **Turnos** con sus pendientes de programar y de procesar, **Requerimientos pendientes**, **RAR** y las demás.

![Tablero de inicio del gestor con sus tarjetas de trabajo](capturas/01-gestor-02-home.png)

> **Sobre la tarjeta de resultados.** Cuando alguien resuelva un pedido de autorización tuyo, te va a aparecer en este tablero una tarjeta **«Autorización Doble Traslado Resuelta»** con la cantidad de respuestas que todavía no leíste. Si no tenés respuestas nuevas, la tarjeta no aparece: eso es normal, no es un error. En el **Paso 9** te mostramos dónde leer los resultados igual.

---

## Paso 3 — Abrí la denuncia y entrá a Turnos

Buscá la denuncia por su número desde **Consulta Siniestros** y abrila. Ya adentro, en el menú de la izquierda elegí **Turnos**.

Vas a ver la lista de turnos del paciente y, arriba a la derecha, el botón **Nuevo turno**.

![Sección Turnos de la denuncia, con la lista de turnos y el botón Nuevo turno](capturas/01-gestor-03-turnos-denuncia.png)

---

## Paso 4 — Cargá el turno nuevo

Apretá **Nuevo turno** y elegí el tipo de turno que estás cargando — en el ejemplo,
**Consulta**. Se abre un panel a la derecha con tres pasos: **Datos de turno**, **Traslado**
y **Confirmación**.

Completá el primer paso:

- **Fecha** y **Hora** del turno.
- **Cantidad**.
- **Centro médico** y **Prestación**: escribí al menos tres letras y elegí de la lista.
- **Observaciones** y adjuntos, si corresponden.

![Paso 1 del panel de nuevo turno, con fecha, hora, centro médico y prestación completos](capturas/01-gestor-04-wizard-paso1.png)

Cuando esté completo, apretá **Siguiente**.

---

## Paso 5 — Tildá «Requiere traslado» y leé el aviso

En el paso **Traslado**, tildá **Requiere traslado**.

Ese tilde es el que dispara la revisión. Si el paciente ya tiene traslado ese día, aparece un bloque naranja con todo lo que necesitás para decidir. **Es la pantalla más importante de esta etapa.**

![Bloque de conflicto: el aviso, los traslados que ya existen y las tres salidas](capturas/01-gestor-05-bloque-conflicto.png)

Leelo de arriba hacia abajo:

1. **El aviso**: «El paciente ya tiene un traslado ese día», y debajo **cuántos son** — en el ejemplo, **3 traslados vigentes**.
2. **La lista de los traslados que ya existen.** De cada uno te dice el **tipo de turno**, la **hora** y el **centro médico** al que va. Y cuando el traslado ya está solicitado te aclara además: *«Estado del traslado: SOLICITADO. Todavía no se le avisó a la agencia»* — o sea, todavía se puede dar marcha atrás sin costo.
3. **Una aclaración del viaje** cuando corresponde. En el ejemplo: *«El viaje es de ida y vuelta con espera, así que se cancelan los dos tramos juntos»*. Ojo con esto: si anulás, se van los dos tramos, no sólo uno.
4. **Las tres salidas**, para que elijas una.

> **Importante.** Mientras no elijas una salida no vas a poder guardar el turno. El sistema no te deja avanzar «como si no hubiera pasado nada»: es a propósito.

> **⚠ Leé la cantidad, no el primer renglón**
> El aviso te dice cuántos traslados hay en conflicto, y **puede haber más de uno**. En el ejemplo de la captura hay **tres**. Si elegís anular, la anulación se aplica a **todos** los que figuran en la lista, no sólo al primero: leelos los tres antes de decidir.
> Y después de guardar, **verificá en la lista de traslados de la denuncia** que quedó lo que vos querías. Si estás resolviendo un caso con varios traslados en juego, revisalos a mano: es la única forma de estar seguro.

> **Un aviso de más, que podés ignorar.** Al tildar «Requiere traslado» aparece también un cartelito naranja arriba, «Esta denuncia tiene traslados para la fecha indicada», que tapa el título de la pantalla por unos segundos. Dice lo mismo que el bloque, pero con menos detalle. **El que importa es el bloque.** Está reportado como **MAN-G-10**.

---

## Paso 6 — Elegí la salida: cuál te conviene

Esta es la duda real. Las tres salidas resuelven cosas distintas.

### Salida A — «Anular esos traslados y usar el nuevo»

**Cuándo la usás:** cuando el traslado que ya existía **ya no sirve**. Se reprogramó el turno, se cambió el centro médico, el paciente no va a ir a ese turno, o simplemente el traslado que estás cargando ahora reemplaza al anterior.

Al elegirla se abren dos campos:

- **Motivo**: viene precargado con *«Cancelado por alarma repetida»*. Cambialo si el motivo real es otro.
- **Observación**: la escribe el sistema por vos, y deja constancia de quién anuló, cuándo y contra qué traslado se duplicaba. Podés agregarle texto, pero **no borres lo que ya dice**: es la trazabilidad de la anulación.

![Salida «Anular»: motivo precargado y observación escrita por el sistema](capturas/01-gestor-06-salida-anular.png)

Apretá **Anular el traslado** para aplicarla.

> **Cuidado:** la anulación es inmediata y no se deshace desde acá. Si el viaje es de ida y vuelta, se cancelan los dos tramos. Y si el aviso te dijo que ya se le informó a la agencia, **coordiná con Logística antes de anular**.

> **Dos rarezas del texto de esta salida, para que no te confundan.** El botón dice «Anular **el** traslado» en singular aunque estés anulando varios — hacele caso a la lista, no al botón (**MAN-G-04**). Y la observación que escribe el sistema puede repetir dos veces tu nombre y avisarte que «quedan 89 caracteres»: es un defecto de armado del texto, no significa que falte nada (**MAN-G-09**).

### Salida B — «Guardar el turno sin traslado»

**Cuándo la usás:** cuando el paciente **ya tiene cómo viajar**. El traslado que existe lo lleva al centro médico y desde ahí puede ir al segundo turno, o vuelve con el mismo viaje. El turno hay que registrarlo igual, pero traslado nuevo no hace falta.

Al elegirla, el sistema **destilda «Requiere traslado» solo** y cierra el bloque: el turno va a quedar guardado sin traslado asociado.

![Al elegir «Guardar el turno sin traslado» se destilda «Requiere traslado» y el bloque se cierra](capturas/01-gestor-07-salida-sin-traslado.png)

Es la salida más simple y la más frecuente. Si dudás entre ésta y pedir autorización, preguntate: **¿el paciente necesita dos viajes distintos, o le alcanza con uno?** Si le alcanza con uno, es ésta.

### Salida C — «Pedir autorización para los dos traslados»

**Cuándo la usás:** cuando el paciente **realmente necesita los dos viajes** y ninguno se puede anular. Por ejemplo: kinesiología a la mañana en un centro y una interconsulta a la tarde en otro, sin posibilidad de volver al domicilio en el medio.

Al elegirla aparece el campo **«Por qué se necesitan los dos traslados»**. Es obligatorio y **lo va a leer una persona**: tu jefe de siniestros o quien tenga el permiso para autorizar. Escribí el motivo clínico o logístico concreto, no «se necesita».

![Salida «Pedir autorización» con la justificación escrita](capturas/01-gestor-08-salida-pedir-autorizacion.png)

**Al cargar un turno nuevo no hay ningún botón que apretar acá.** Escribís la justificación y seguís con el wizard: **el pedido se envía solo cuando guardás el turno**, junto con todo lo demás. Debajo del campo vas a ver la aclaración.

> Si estás **editando** un turno que ya existe, ahí sí aparece el botón **Enviar el pedido**, porque el turno ya está guardado y el pedido se puede registrar en el momento.

Mientras el pedido esté sin respuesta, **el traslado no baja a Logística**: nadie va a buscar al paciente hasta que se apruebe. Tenelo en cuenta si el turno es para pronto.

> **Si el texto te habla de «los dos traslados» y vos tenés tres,** no te preocupes: el texto de esta salida está escrito siempre en dos, sin importar cuántos haya. El pedido cubre el traslado nuevo que estás cargando. Está reportado como **MAN-G-04**.

---

## Paso 7 — Revisá el resumen y confirmá

Apretá **Siguiente** hasta el paso **Confirmación**. Ahí el sistema te muestra lo que estás por guardar: fecha, hora, cantidad, prestación, centro médico y, si corresponde, el tipo de viaje del traslado.

![Paso de confirmación con el resumen del turno](capturas/01-gestor-10-paso3-confirmacion.png)

Leelo antes de apretar **Confirmar** — sobre todo la fecha y la hora, que son las que disparan el conflicto.

> **Ojo:** este resumen **no** repite qué salida elegiste ni la justificación que escribiste. Y es justo la decisión con más consecuencias: una anulación afecta viajes ya pedidos, y un pedido de autorización le crea trabajo a otra persona. Si no te acordás, volvé con **Atrás** al paso Traslado y verificá antes de confirmar. Está reportado como **MAN-G-06**.

---

## Paso 8 — Confirmá y verificá en la lista

Apretá **Confirmar**. El panel se cierra y el turno nuevo aparece en la lista de turnos de la denuncia, con su fecha y hora.

![El turno nuevo ya guardado en la lista de turnos de la denuncia](capturas/01-gestor-11-turno-guardado-sin-traslado.png)

**Siempre verificá que el turno figure en la lista.** Si el panel no se cierra y te quedás en el paso de confirmación, el turno **no** se guardó: cancelá, revisá qué salida elegiste y volvé a intentar.

---

## Paso 9 — Leé la respuesta a tus pedidos

Cuando alguien resuelve un pedido tuyo, la respuesta te llega a la pestaña **«Autorización Doble Traslado Resuelta»**.

Para llegar: desde tu tablero de inicio entrá a la sección **Turnos** y elegí la última pestaña, **«Autorización Doble Traslado Resuelta»**. La pestaña está siempre, tengas o no respuestas nuevas.

![Pestaña «Autorización Doble Traslado Resuelta» con los pedidos ya respondidos](capturas/01-gestor-12-tab-resueltos.png)

De cada pedido resuelto vas a leer:

| Columna | Qué te dice |
|---|---|
| **Resultado** | **Autorizado** (verde) o **Rechazado** (rojo). |
| **Lo resolvió** | Quién te respondió, por su nombre. |
| **Fecha de la respuesta** | Cuándo la resolvió. |
| **Dictamen** | Lo que escribió al resolver: por qué te lo aprobó o te lo rechazó. |
| **Mi justificación** | El texto que habías escrito vos al pedirlo. |

El **Dictamen** y **Mi justificación** aparecen recortados con puntos suspensivos. Pasá el mouse por encima y el texto completo aparece en un cartelito.

Dos cosas para tener presentes:

- Si te lo **autorizaron**, el traslado sigue su curso normal y baja a Logística.
- Si te lo **rechazaron**, el traslado queda cancelado. Leé el dictamen: ahí está el criterio, y te sirve para la próxima vez que tengas un caso parecido.

> **Sobre las fechas y las horas de estas pantallas.** El bloque de conflicto muestra las horas con segundos (`09:00:00`) y esta pestaña muestra la fecha del turno al revés (`2026-09-08` en lugar de `08/09/2026`), distinto del resto del sistema. Es sólo el formato: el dato es correcto. Está reportado como **MAN-G-08**.

---

## Resumen de la Etapa 1

| Situación del paciente | Salida que elegís |
|---|---|
| El traslado que ya existe **no sirve más** (se reprogramó, cambió el centro) | **Anular** esos traslados y usar el nuevo |
| Con el traslado que ya tiene **le alcanza** para los dos turnos | **Guardar el turno sin traslado** |
| Necesita **los dos viajes** y ninguno se puede anular | **Pedir autorización** — con una justificación concreta |

Tres reglas que conviene no olvidar:

1. **El aviso te dice cuántos traslados hay, no uno solo.** Si dice «3 traslados vigentes», leé los tres antes de decidir: anular los alcanza a todos.
2. **«Ya se le avisó a la agencia» cambia las cosas.** Si el bloque no aclara que todavía no se avisó, coordiná con Logística antes de anular.
3. **Un pedido de autorización frena el traslado.** Mientras esté sin respuesta, nadie pasa a buscar al paciente. Si el turno es urgente, avisale a quien tiene que resolverlo.

---

# 5. Etapa 2 — El autorizante: aprobar o rechazar

Esta etapa es para vos si tenés el permiso para autorizar traslados duplicados. Es el caso de los jefes de siniestros y de los referentes con esa atribución.

## Qué vas a aprender

Cuando un gestor necesita dos traslados para el mismo paciente el mismo día y no puede anular ninguno, te manda un pedido. Vos lo aprobás o lo rechazás, y en los dos casos escribís un **dictamen**. Acá vas a ver dónde te llegan esos pedidos, qué información tenés para decidir, **con qué criterio** conviene resolver, y por qué el dictamen es la parte que más importa.

Es un trabajo corto — dos minutos por pedido — pero del otro lado hay un paciente que no va a tener cómo viajar hasta que resuelvas.

---

## Paso 1 — Entrá al sistema

Abrí el SAS y completá tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/02-autorizante-01-login.png)

Si la pantalla tarda, esperá: la primera carga del día es la más lenta. No vuelvas a apretar **Ingresar** varias veces.

---

## Paso 2 — Buscá la tarjeta en tu tablero

Después de entrar llegás a tu Tablero de Siniestros. Los pedidos de autorización **no te llegan por mail ni por notificación**: aparecen como una **tarjeta** en el grupo **Turnos**, llamada **«Autorización Doble Traslado Pendiente»**, con el número de pedidos que todavía no resolviste.

![Tablero de inicio: el grupo Turnos con la tarjeta «Autorización Doble Traslado Pendiente» y su contador](capturas/02-autorizante-03-card-pendiente.png)

> **Cuidado con esta tarjeta.** Hoy no entra bien en el grupo: el contador se ve cortado por arriba y el nombre queda cortado por abajo, así que es fácil pasarla de largo. Es la **última tarjeta del grupo Turnos**, abajo a la izquierda, y es la única con ícono de carpeta. Está reportado como **MAN-A-03**.

![Tablero completo del autorizante, con la tarjeta desbordada en el grupo Turnos mientras el resto entra bien](capturas/02-autorizante-02-home.png)

**Si la tarjeta no está, no es un error.** La tarjeta sólo aparece cuando tenés pedidos sin resolver. Cuando resolvés el último, desaparece.

![El mismo grupo Turnos cuando no quedan pedidos pendientes: la tarjeta ya no está](capturas/02-autorizante-12-home-sin-card.png)

Para entrar igual, sin la tarjeta: andá a la sección **Turnos** del menú de la izquierda y elegí la pestaña **«Autorización Doble Traslado Pendiente»**. La pestaña está siempre.

---

## Paso 3 — Leé la grilla: alcanza para decidir

Hacé clic en la tarjeta. Llegás a la sección Turnos, ya con la pestaña **«Autorización Doble Traslado Pendiente»** abierta y filtrada: sólo ves lo que tenés que resolver.

![Grilla de pedidos pendientes con las columnas Lo pidió, Fecha del pedido y Justificación](capturas/02-autorizante-04-grilla-pendientes.png)

Además de las columnas de siempre (denuncia, accidentado, documento, empleador, fecha del turno, severidad, analista), la grilla te agrega **las tres que importan para decidir**:

| Columna | Qué te dice |
|---|---|
| **Lo pidió** | Quién te mandó el pedido, por su nombre. |
| **Fecha del pedido** | Cuándo te lo pidió, con hora. Te dice cuánto lleva esperando. |
| **Justificación** | El texto que escribió el gestor: por qué necesita los dos traslados. |

La **Justificación** se muestra recortada. Pasá el mouse por encima para leerla completa, o abrí el pedido (Paso 5), donde aparece entera y destacada.

> **Dos cosas prácticas de esta pantalla.**
> - La grilla **no entra a lo ancho**: la columna **ACCIONES** queda cortada del lado derecho y el botón que necesitás puede no verse. Deslizá la tabla hacia la derecha (con la rueda del mouse apretando `Shift`, o arrastrando dentro de la tabla). **No hay barra de desplazamiento visible** que te avise. Está reportado como **MAN-A-02**.
> - La columna **FECHA AUTORIZACIÓN** siempre está vacía acá, y es correcto: un pedido pendiente todavía no tiene fecha de autorización. Ignorala en esta pestaña (**MAN-A-08**).

---

## Paso 4 — Abrí el menú de acciones de la fila

Al final de la fila, en **ACCIONES**, hay dos botones. El de los **tres puntitos** abre el menú.

![Menú de acciones de la fila con sus dos opciones](capturas/02-autorizante-05-menu-acciones.png)

Tiene dos opciones:

- **Gestionar autorización** — es la que usás. Abre el panel donde aprobás o rechazás.
- **Ver información de traslado** — **hoy no hace nada.**

El **otro** botón de la fila (el que está a la izquierda de los tres puntitos) **no** es «ver el pedido»: te abre la **denuncia completa** y te saca de la grilla. Si lo apretás por error, volvé con el navegador y entrá de nuevo a la pestaña.

> **⚠ «Ver información de traslado» no abre nada**
> La apretás y no pasa nada: no abre ningún panel, no da error, no avisa. La pantalla queda exactamente igual que antes del clic. **No es tu computadora ni tu conexión.**
> Hasta que se corrija, **no la uses**. Está reportado como **MAN-A-01**. Más abajo, en el Paso 5, te explicamos cómo conseguir esa información por otro camino.

![Después de elegir «Ver información de traslado» la pantalla queda igual, sin panel ni aviso](capturas/02-autorizante-defecto-ver-info.png)

> **Nota de accesibilidad.** Ninguno de los dos botones tiene nombre: si trabajás con lector de pantalla, los dos se anuncian simplemente como «icon». Está reportado como **MAN-A-04**.

---

## Paso 5 — Leé el pedido en el panel de resolución

Elegí **Gestionar autorización**. Se abre un panel a la derecha, **«Autorizar el segundo traslado del día»**. Es la pantalla donde decidís, y trae todo lo que necesitás sin obligarte a salir a buscar nada.

![Panel de resolución: la justificación del gestor destacada, los datos del pedido y del turno, y el campo Dictamen](capturas/02-autorizante-07-drawer-resolucion.png)

Leelo de arriba hacia abajo:

1. **Justificación del gestor** — destacada arriba, con una barra azul al costado. Es lo primero que se te muestra a propósito: es el argumento que tenés que evaluar.
2. **El pedido** — quién lo pidió y cuándo. Si la fecha del pedido es de hace varios días y el turno es para pronto, resolvelo ya.
3. **El turno** — tipo de turno, fecha y hora, paciente y denuncia. Es el turno **nuevo**, el que se sumó al día.
4. **Dictamen** — el campo donde escribís tu decisión.

> **Sobre «Tipo de turno».** Puede mostrarte una sigla del sistema (por ejemplo `FKT` por kinesiología) en lugar del nombre completo, y algunos rótulos aparecen en mayúsculas mezclados con los nuevos. Es cosmético. Está reportado como **MAN-A-07**.

### Qué te falta y cómo lo conseguís

El panel te dice qué turno se está cargando, pero **no** te muestra los traslados que el paciente **ya tiene** ese día — que es justamente lo que hace al segundo un duplicado. Y la opción que debería mostrártelo («Ver información de traslado») hoy no funciona.

Si la justificación del gestor no te alcanza para decidir, tenés dos caminos:

- Abrí la denuncia en otra pestaña y entrá a **Turnos**: ahí ves todos los turnos de ese día con sus horas y centros médicos.
- **Preguntale directamente al gestor** que lo pidió — su nombre está en la columna **Lo pidió**.

---

## Paso 6 — Con qué criterio se aprueba y con qué criterio se rechaza

Es la parte que ninguna pantalla te va a resolver. La pregunta concreta es:

> **¿Puede este paciente llegar a los dos turnos con un solo viaje?**

**Aprobás** cuando la respuesta es no. Los casos típicos:

- Los dos turnos son en **centros médicos distintos** y no hay forma de ir de uno al otro por sus propios medios.
- Hay **muchas horas entre los dos turnos** y el paciente tiene que volver al domicilio en el medio (no se lo puede dejar esperando media jornada).
- La **condición del paciente** no le permite trasladarse solo entre los dos turnos.

**Rechazás** cuando con un viaje alcanza:

- Los dos turnos son en el **mismo centro médico**, o en el mismo edificio: el traslado que ya existe lo lleva y lo trae.
- Los turnos son **casi seguidos** y el paciente puede esperar en el centro médico.
- El traslado que ya existe es de **ida y vuelta con espera**: ya cubre el día entero.
- La justificación **no dice nada concreto** («se necesita», «lo pidió el paciente») y no hay motivo clínico o logístico identificable.

Y una advertencia que no está en la pantalla: **rechazar cancela el traslado nuevo.** No es «dejarlo para después». Si tenés dudas, es mejor consultar con el gestor antes de rechazar que rechazar y que el paciente se quede sin viaje.

---

## Paso 7 — Escribí el dictamen: es lo único que le vuelve al gestor

El **Dictamen** es el campo más importante del panel, y conviene entender por qué.

Cuando resolvés, el gestor ve en su pestaña «Autorización Doble Traslado Resuelta» tres cosas: si fue **Autorizado** o **Rechazado**, tu nombre, y **el dictamen**. Nada más. No hay comentarios, ni hilo de conversación, ni aviso aparte. **Lo que escribas acá es toda la explicación que va a tener.**

Por eso:

- Escribí el **motivo**, no la decisión. «Rechazado» ya se lo dice el sistema; lo que necesita saber es *por qué*.
- Si rechazás, decile **qué hacer en su lugar**: «el traslado de las 09:00 es de ida y vuelta con espera, ya cubre los dos turnos» le resuelve el caso.
- Si aprobás, dejá **constancia del criterio**. Le sirve para la próxima vez, y le sirve a quien audite el caso más adelante.

### El dictamen es obligatorio para rechazar

Si apretás **Rechazar** con el dictamen vacío, el sistema no te deja: el rótulo pasa a rojo y te avisa *«Para rechazar hay que escribir el motivo: es lo único que le vuelve al gestor»*. El pedido no se toca, el panel queda abierto y podés escribir y reintentar.

![Al rechazar sin dictamen el campo se marca en rojo y el pedido no se resuelve](capturas/02-autorizante-08-rechazo-sin-dictamen.png)

**Para aprobar el dictamen es opcional** — el sistema te deja aprobar en blanco. **No lo hagas.** Una aprobación sin dictamen le llega al gestor como un «sí» sin ninguna explicación, y no queda constancia de por qué se autorizó una excepción.

---

## Paso 8 — Los dos caminos

### Camino A — Rechazar

Escribí el motivo en **Dictamen** y apretá **Rechazar**.

![El panel con un dictamen de rechazo escrito, antes de confirmar](capturas/02-autorizante-09-dictamen-rechazo.png)

Al confirmar, el **traslado nuevo queda cancelado** y el pedido sale de tu grilla de pendientes. El turno en sí sigue existiendo: lo que se cancela es el viaje.

> **No se deshace desde acá.** Si te equivocaste, el gestor tiene que volver a cargar el traslado y pedirlo de nuevo.

### Camino B — Autorizar

Escribí el motivo en **Dictamen** y apretá **Autorizar**.

![El panel con un dictamen de aprobación escrito, antes de confirmar](capturas/02-autorizante-10-dictamen-aprobacion.png)

El sistema te confirma en el mismo panel, en verde:

> *Se autorizó el segundo traslado del día. Ya pasó al sector de traslados para que lo coordinen.*

![Confirmación de la aprobación y la fila ya fuera de la grilla de pendientes](capturas/02-autorizante-11-confirmacion.png)

Fijate en dos cosas de esta pantalla, porque las dos son la señal de que salió bien:

1. **El mensaje verde.** Te dice explícitamente que el traslado **ya pasó a Logística**. Recién ahora alguien va a coordinar el viaje: mientras el pedido estaba pendiente, el traslado no existía para el sector de traslados.
2. **La grilla de atrás ya dice «No hay registros para mostrar».** El pedido salió de tus pendientes.

Cerrá el panel con **Cerrar**. Si volvés a la pestaña, la grilla queda vacía y en el tablero la tarjeta desaparece.

![La pestaña de pendientes vacía después de resolver el último pedido](capturas/02-autorizante-13-grilla-vacia.png)

---

## Paso 9 — Qué pasa después (y qué no vas a poder ver)

Después de **aprobar**:

- El traslado **baja a Logística**, con una **marca de duplicado autorizado**. La gente de traslados lo ve señalado, para que sepa que es el segundo viaje del día y que está autorizado. Eso es lo que se explica en la Etapa 3.
- El gestor **lee tu dictamen** en su pestaña «Autorización Doble Traslado Resuelta».

Después de **rechazar**:

- El traslado queda **cancelado** y no baja a Logística.
- El gestor lee tu dictamen en la misma pestaña.

> **⚠ Lo que hoy no podés hacer: consultar lo que resolviste**
> Una vez que resolvés un pedido, **no te queda ninguna pantalla donde volver a verlo.** La pestaña de resueltos existe sólo para el gestor que pidió, no para quien autoriza, y la tarjeta del tablero desaparece al llegar a cero.
> En la práctica: si necesitás recordar qué decidiste y por qué, **no lo vas a encontrar desde tu perfil**. Está reportado como **MAN-A-05**. Mientras no se corrija, si un caso es delicado conviene dejarte una nota propia, o mirar el caso desde la denuncia junto con el gestor.

---

## Resumen de la Etapa 2

| Situación | Qué hacés |
|---|---|
| Dos turnos en **centros distintos**, sin forma de ir de uno al otro | **Autorizar**, con el criterio en el dictamen |
| Muchas horas entre los dos turnos, tiene que volver al domicilio | **Autorizar** |
| Dos turnos en el **mismo centro médico**, o casi seguidos | **Rechazar**, explicando que un viaje alcanza |
| El traslado que ya existe es de **ida y vuelta con espera** | **Rechazar**, indicando que ya cubre el día |
| La justificación **no dice nada concreto** | **Rechazar** — o preguntale al gestor antes |

Cuatro reglas que conviene no olvidar:

1. **El dictamen es lo único que le vuelve al gestor.** Escribí el motivo siempre, también cuando aprobás, aunque el sistema te deje aprobar en blanco.
2. **Rechazar cancela el traslado.** No es postergarlo. Si dudás, consultá antes de rechazar.
3. **Mientras no resolvés, nadie pasa a buscar al paciente.** Mirá la columna **Fecha del pedido**: un pedido viejo con turno cercano es urgente.
4. **Resuelto un pedido, no lo vas a poder volver a consultar.** Si el caso es delicado, dejate la constancia por fuera.

---

# 6. Etapa 3 — Logística: recibir el traslado marcado

Esta etapa es para quien trabaja en el sector de logística: quien mira la grilla de traslados del día, asigna agencias y decide qué viaje sale y qué viaje se cancela.

## Lo único que no te podés olvidar

> **⚠ Una fila marcada NO se cancela por duplicado**
> Cuando veas **dos traslados del mismo paciente para el mismo día**, tu reflejo va a ser pensar que uno está repetido y cancelarlo. **Fijate primero si tiene la marca.**
> La marca significa que un jefe de siniestros ya miró ese caso y **autorizó los dos viajes**: el paciente necesita las dos salidas. Si la cancelás, el paciente se queda sin cómo volver, y alguien tiene que rehacer todo el circuito de autorización desde cero.
> **Marca = ya autorizado = sale.** Si te parece que igual está mal, preguntá antes de cancelar; no lo canceles «por las dudas».

Todo lo que sigue es cómo reconocer esa marca, y qué traslados **no te van a llegar** (que es la otra mitad del circuito, y la menos obvia).

---

## Paso 1 — Entrá al sistema

Abrí el SAS con tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/03-logistica-01-login.png)

Si la pantalla tarda en cargar, esperá. La primera carga del día es la más lenta; no vuelvas a apretar **Ingresar** varias veces.

---

## Paso 2 — Tu tablero de logística

Después de entrar llegás a tu tablero, con los contadores de siempre: los traslados de hoy y de mañana, hotelería, adelantos y reintegros.

![Tablero de logística con los contadores de traslados de hoy y de mañana](capturas/03-logistica-02-tablero.png)

**La marca de traslado autorizado no tiene contador propio en el tablero.** No hay una tarjeta que te avise «tenés un traslado autorizado». La marca vive **dentro de la grilla**, en la fila del traslado. Por eso el paso siguiente es entrar a la grilla y mirar. Está reportado como mejora (**MAN-L-05**).

---

## Paso 3 — Abrí la grilla de traslados del sector

Entrá a **Traslados → Pacientes**. Se abre la grilla con los filtros arriba, las pestañas **Remis/Ambulancia** y **Transporte público**, y la tabla abajo.

![Grilla de traslados de pacientes tal como abre, con el período puesto en el día de hoy](capturas/03-logistica-03-grilla-sector.png)

**El período viene puesto en el día de hoy.** Son dos campos, *desde* y *hasta*. Cambialos por el día que quieras mirar y apretá **Aplicar filtros** — hasta que no lo apretás, la tabla no cambia.

Así se ve la grilla filtrada por un día con varios traslados de un mismo paciente:

![Grilla filtrada por el 08/09/2026: tres traslados del mismo paciente, dos con marca y uno sin marca](capturas/03-logistica-04-grilla-filtrada.png)

Tres traslados del mismo paciente, el mismo día, en el mismo centro médico: **09:00, 10:00 y 10:30**. A simple vista parece un caso de traslados repetidos. **No lo es:** dos de los tres están autorizados, y la grilla te lo está diciendo.

---

## Paso 4 — Las tres capas de la marca

La marca se te muestra de **tres formas a la vez**. Con reconocer una alcanza, pero conviene saber las tres, porque según la pantalla en la que estés vas a ver unas u otras.

### Capa 1 — La franja de color al costado de la fila

Es la señal más rápida de leer: una **barra vertical verde** pegada al borde izquierdo de la fila.

![Dos filas con la franja verde al costado y una tercera fila sin franja](capturas/03-logistica-05-franja-color.png)

Mirá la diferencia: los traslados de **10:30** y **10:00** tienen la franja verde; el de **09:00** no tiene nada. El de las 09:00 es el traslado que ya existía —el «original»— y no necesita autorización. Los otros dos son los duplicados que **sí fueron autorizados**.

### Capa 2 — El ícono, y el texto que aparece al pasar el mouse

En la primera columna de la fila aparece un **ícono naranja**. Pasale el mouse por encima **sin hacer clic** y te muestra el texto:

![El ícono de la fila con su texto: «Segundo traslado del día autorizado»](capturas/03-logistica-06-icono-tooltip.png)

El texto dice exactamente: **«Segundo traslado del día autorizado»**.

Ese es el ícono, de cerca:

![Acercamiento del ícono de la marca: un octógono naranja con un signo de exclamación](capturas/03-logistica-08-zoom-celda-iconos.png)

> **Ojo con este ícono.** Es un octógono naranja con un signo de exclamación: la forma de una advertencia, la de algo que está mal. **Acá significa lo contrario**: significa que el caso ya se revisó y se autorizó. No te dejes llevar por la forma del ícono — **leé el texto** pasando el mouse. Está reportado como **MAN-L-03**.

> **Lo que el texto debería decir y no dice.** El aviso está previsto para nombrar a quien autorizó y aclarar «no cancelar por duplicado», pero hoy siempre se muestra la versión corta, sin nombre y sin esa aclaración. Si necesitás saber quién autorizó, preguntale al gestor de la denuncia. Está reportado como **MAN-L-01**.

### Capa 3 — La leyenda al pie de la tabla

Abajo de la tabla están las referencias de los colores de las franjas:

![Leyenda al pie: «Requiere revisión» en naranja, «Segundo traslado del día autorizado» en verde, «Es espontáneo» en rojo](capturas/03-logistica-07-leyenda.png)

Es tu chuleta: si no te acordás qué significa un color, está siempre ahí.

> **Una incoherencia a tener en cuenta.** En la leyenda, «Segundo traslado del día autorizado» figura con un círculo **verde** —el color de la franja—, pero el ícono que ves en la fila es **naranja**. Los dos son la misma marca. La leyenda te sirve para los colores de las franjas, no para los íconos. Está reportado junto con **MAN-L-03**.

---

## Paso 5 — Cómo distinguirla de las otras dos señales

Las franjas de color son tres y **cada fila muestra una sola**. Esta es la tabla completa:

| Franja | Qué significa | Qué se espera de vos |
|---|---|---|
| **Verde** | Segundo traslado del día **autorizado** | Que lo trates como cualquier traslado válido: asignale agencia. **No lo canceles por duplicado.** |
| **Naranja** | **Requiere revisión** | Que lo mires: hay algo del traslado que hay que corregir. |
| **Rojo** | **Es espontáneo** | Traslado cargado fuera del circuito habitual. |
| **Sin franja** | Traslado común, sin ninguna señal | Nada en particular. |

> **⚠ Cuidado: una fila puede tener más de un motivo, y la franja muestra sólo uno**
> Si un traslado está **autorizado como segundo del día** y además es **espontáneo** o **requiere revisión**, la franja te muestra el **otro** color —rojo o naranja— y la franja verde desaparece. La autorización sigue estando; **lo que se pierde es el aviso**.
> **Cómo protegerte:** cuando veas dos traslados del mismo paciente el mismo día, no decidas sólo por el color de la franja. **Mirá si la fila tiene el ícono** y pasale el mouse: el ícono sí se mantiene en esta pantalla. Y si no hay ícono ni certeza, **preguntá antes de cancelar**. Está reportado como **MAN-L-02**.

![La misma fila autorizada mostrando franja naranja y roja en lugar de la verde](capturas/03-logistica-10-defecto-franja-tapada.png)

---

## Paso 6 — Lo que NO te llega (y es correcto que no te llegue)

Esta es la mitad del circuito que no se ve, y la que más confusión genera. **No todos los traslados duplicados llegan a tu grilla.** Los que faltan no son un error del sistema.

En el ejemplo, de los cuatro traslados que existen para ese paciente ese día **a tu grilla llegan tres**. Fijate en el contador al pie de la tabla: **«1–3 de 3»**.

| Situación del traslado | ¿Lo ves en tu grilla? | Por qué |
|---|---|---|
| Segundo traslado **autorizado** | **Sí**, con la marca verde | Ya se resolvió a favor: hay que hacerlo. |
| Traslado **original** del día | **Sí**, sin marca | Nunca necesitó autorización. |
| Segundo traslado con pedido **pendiente de resolver** | **No** | Todavía no se decidió. No aparece hasta que alguien lo apruebe. |
| Segundo traslado con pedido **rechazado** | **No** | El rechazo cancela el traslado. No hay viaje que organizar. |

Las dos consecuencias prácticas:

1. **Si te avisan de un traslado que no ves en la grilla, probablemente esté esperando autorización.** No lo cargues a mano ni lo reclames como faltante: pedile al gestor de la denuncia que verifique en qué estado está el pedido. Cuando se apruebe, va a aparecer solo.
2. **Un traslado que apareció «de la nada» en tu grilla puede ser uno recién autorizado.** Es exactamente lo que pasó con el traslado de las **10:00** de este ejemplo: no estaba en la grilla mientras el pedido esperaba respuesta, y **apareció ya marcado** en cuanto el jefe de siniestros lo aprobó. Si aparece con la franja verde, está autorizado: sale.

---

## Paso 7 — El mismo traslado, visto dentro de la denuncia

Si entrás a la denuncia (haciendo clic en el número de siniestro de la fila) y vas a **Traslados**, ves los traslados de ese paciente. **Esta pantalla no es igual a la del sector.**

![Vista de Traslados dentro de la denuncia: las franjas verdes están, la columna de íconos no](capturas/03-logistica-09-traslado-en-denuncia.png)

Acá **la franja verde está y la leyenda al pie también, pero no hay ícono**. Es decir: no tenés dónde pasar el mouse para leer «Segundo traslado del día autorizado». El único aviso es el color.

Eso hace que en esta pantalla el problema del Paso 5 sea más grave: si la fila además es espontánea o requiere revisión, **no queda ninguna señal de que el traslado está autorizado**.

![Dentro de la denuncia, la fila autorizada que además es espontánea queda pintada de rojo y sin ningún ícono](capturas/03-logistica-11-defecto-denuncia-sin-marca.png)

**Recomendación mientras esto no esté corregido:** para decidir si cancelás o no un traslado duplicado, **hacelo desde la grilla del sector** (Traslados → Pacientes), que es donde están las tres capas de la marca. La vista de la denuncia sirve para consultar, no para decidir cancelaciones. Está reportado como **MAN-L-04**.

---

## Resumen de la Etapa 3

1. **Marca verde o ícono naranja con el texto «Segundo traslado del día autorizado» = el viaje sale.** No se cancela por duplicado.
2. **Ante dos traslados del mismo paciente el mismo día, revisá la marca antes de tocar nada.** Si no estás seguro, preguntá; cancelar es lo único que no se deshace solo.
3. **Lo que no ves, no es un error.** Los pedidos pendientes y los rechazados no bajan a tu sector, y está bien que sea así.
4. **Decidí desde la grilla del sector, no desde la denuncia.** Es la pantalla que muestra la marca completa.

---

# 7. Preguntas frecuentes

**1. Me equivoqué y pedí la autorización sin necesitarla. ¿Qué hago?**
No podés cancelar tu propio pedido desde el sistema. Avisale a quien lo va a resolver para que lo rechace, y pedile que en el dictamen aclare que fue un error tuyo — así el rechazo queda bien explicado. El turno no se pierde: lo único que se cancela al rechazar es el viaje. Si el paciente igual necesita traslado, cargalo aparte una vez rechazado.

**2. ¿Cuánto tarda en resolverse un pedido?**
El sistema no tiene ningún plazo, ni recordatorio, ni escalamiento automático. Depende enteramente de que quien autoriza entre a su tablero y lo vea. **Si el turno es para pronto, avisale por teléfono o por mail**: mientras el pedido esté pendiente nadie pasa a buscar al paciente. Quien autoriza tiene la columna **Fecha del pedido** justamente para priorizar los que llevan más tiempo esperando.

**3. ¿Cómo me entero de que me lo resolvieron?**
No te llega mail ni notificación. Te enterás por dos lugares: la tarjeta **«Autorización Doble Traslado Resuelta»** en tu tablero de inicio, con la cantidad de respuestas que todavía no leíste, y la pestaña del mismo nombre dentro de la sección **Turnos**, que está siempre. La costumbre sana es mirar la pestaña una vez por día si tenés pedidos abiertos.

**4. Me rechazaron la autorización. ¿Qué hago con el turno?**
**El turno sigue existiendo y no hay que volver a cargarlo.** Lo que se canceló es el viaje. Leé el dictamen: ahí está el motivo, y casi siempre está también la solución. Si el dictamen dice que el traslado que ya existía alcanza (por ejemplo, porque es de ida y vuelta con espera), no hay nada más que hacer: el paciente viaja con ese. Si el dictamen no te queda claro, hablá con quien lo resolvió — su nombre está en la columna **Lo resolvió**.

**5. ¿Puedo pedirla de nuevo?**
Sí, pero no sobre el mismo pedido: un pedido resuelto queda cerrado y no se reabre. Tenés que **volver a cargar el traslado** y pedir la autorización otra vez. Hacelo sólo si tenés información nueva que no estaba en la justificación original — si repetís lo mismo, lo más probable es que te lo vuelvan a rechazar. Escribí en la justificación qué cambió.

**6. ¿Quién puede autorizar?**
Cualquiera que tenga el permiso de autorizar traslados duplicados: referentes, supervisores, jefes de siniestros y gerentes de siniestros. **No es el rol lo que habilita, es el permiso**, así que puede haber gente de tu mismo puesto que lo tenga y gente que no. Si no sabés quién en tu equipo puede resolver, preguntale a tu jefe de siniestros. Y si vos mismo tenés el permiso, no necesitás pedirle a nadie: podés autorizar tu propio duplicado en el acto, a tu nombre.

**7. Tengo el permiso pero no veo la tarjeta de pedidos pendientes. ¿Está roto?**
Casi seguro que no. La tarjeta **sólo aparece cuando hay pedidos sin resolver**: si no hay ninguno, no está, y eso es lo normal. Además, hoy la tarjeta no entra bien en el grupo **Turnos** del tablero y se ve cortada, así que es fácil pasarla de largo. Para asegurarte, entrá a la sección **Turnos** y abrí la pestaña **«Autorización Doble Traslado Pendiente»**: esa pestaña está siempre, con pedidos o sin ellos. Si la pestaña tampoco te aparece, ahí sí puede ser que no tengas el permiso.

**8. ¿Logística puede cancelar un traslado autorizado?**
Técnicamente puede, como cualquier traslado — pero **no debe cancelarlo por duplicado**. Una fila marcada quiere decir que alguien con autoridad ya evaluó el caso y decidió que los dos viajes hacen falta. Si desde logística hay una razón distinta para cancelar (la agencia no puede, el paciente avisó que no va), eso es otra cosa y sigue el circuito habitual. La regla es: **ante la duda, preguntar antes de cancelar**, porque volver atrás implica rehacer todo el pedido de autorización.

**9. El paciente tiene tres traslados ese día, no dos. ¿El circuito sirve igual?**
Sí. El aviso te dice la cantidad real de traslados en conflicto y los lista todos. Lo que tenés que tener en cuenta es que algunos textos de la pantalla están escritos «en dos» — «los dos traslados», «los dos viajes» — sin importar cuántos haya. **Guiate por la lista, no por el texto.** Y si elegís anular, revisá después en la denuncia que quedó anulado lo que vos querías.

**10. Elegí «Guardar el turno sin traslado». ¿Después puedo agregarle el traslado?**
El turno queda guardado sin viaje asociado. Si más adelante resulta que el paciente sí necesita traslado, tenés que volver a la denuncia, entrar al turno y cargarle el traslado — y ahí el sistema va a volver a detectar el conflicto y a pedirte que elijas una salida. Es el mismo circuito, desde el principio.

**11. Anulé el traslado que ya existía y ahora me dicen que hacía falta. ¿Se puede deshacer?**
No desde el panel donde lo anulaste: la anulación es inmediata. Hay que **cargar el traslado de nuevo**. Y si el viaje era de ida y vuelta con espera, tené en cuenta que se cancelaron los dos tramos, así que hay que rehacer los dos. Por eso conviene leer bien el bloque antes de anular: si dice que **ya se le avisó a la agencia**, coordiná con Logística primero.

**12. ¿Dónde queda registrado todo esto?**
Cada decisión queda escrita y con nombre. La **anulación** queda con su motivo y su observación en el traslado anulado. El **pedido** queda con la justificación del gestor y la fecha. La **resolución** queda con el nombre de quien autorizó o rechazó, la fecha y el dictamen, y el gestor la lee en su pestaña de resueltos. Ése es el punto del circuito: que nadie tenga que reconstruir después, de memoria, por qué se hizo un segundo viaje.

---

# 8. Glosario

| Término | Qué significa en este circuito |
|---|---|
| **Turno** | La cita médica del paciente: fecha, hora, centro médico y prestación. **Se guarda siempre**, incluso cuando el traslado queda esperando una autorización: no hay nada que autorizar en una consulta. |
| **Traslado** | El viaje: el remis o la ambulancia que lleva al paciente. Es lo que tiene costo y lo que el circuito controla. |
| **Traslado duplicado** | Un segundo traslado para el mismo paciente en el mismo día, cuando ya hay otro vigente. Es lo que dispara todo el circuito. |
| **Traslado original** | En un día con duplicados, el traslado que ya existía. Nunca necesita autorización y en la grilla de logística aparece **sin marca**. |
| **Conflicto** | La situación que el sistema detecta al tildar «Requiere traslado»: el paciente ya tiene uno o más traslados vigentes ese día. El aviso te dice **cuántos**. |
| **Traslado vigente** | Un traslado que todavía está en pie: no fue anulado ni cancelado. Sólo los vigentes generan conflicto. |
| **Ida y vuelta con espera** | Un viaje que lleva al paciente, lo espera y lo trae. Suele **cubrir el día entero**: es el caso más común en el que un segundo traslado no hace falta. Si se anula, se cancelan los dos tramos juntos. |
| **Salida** | Cada una de las tres formas de resolver el conflicto: **anular** el traslado que ya existía, **guardar el turno sin traslado**, o **pedir la autorización**. Hay que elegir una para poder guardar. |
| **Pedido de autorización** | La solicitud que manda el gestor cuando el paciente necesita los dos viajes. Queda **pendiente** hasta que alguien lo resuelve, y mientras esté pendiente el traslado no baja a Logística. |
| **Justificación** | El texto que escribe el gestor al pedir: por qué el paciente necesita los dos traslados. Es lo único que quien autoriza tiene para evaluar, así que conviene que sea concreto. |
| **Dictamen** | El texto que escribe quien resuelve: por qué aprobó o rechazó. **Es obligatorio para rechazar** y es lo único que le vuelve al gestor. |
| **Autorizante** | Quien tiene el permiso para autorizar traslados duplicados: referente, supervisor, jefe de siniestros o gerente de siniestros. Es el **permiso** lo que habilita, no el puesto. |
| **Pedido pendiente** | Un pedido que todavía nadie resolvió. Le aparece a quien autoriza en su tarjeta del tablero, y **no le llega a Logística**. |
| **Pedido resuelto** | Un pedido ya aprobado o rechazado. No se reabre: si hace falta insistir, hay que cargar el traslado y pedir de nuevo. |
| **Duplicado autorizado** | El estado del traslado después de una aprobación: baja al sector de traslados con la **marca** que le dice a Logística que ese segundo viaje del día está autorizado. |
| **Marca** | La señal que Logística ve en la fila del traslado autorizado: **franja verde**, **ícono con el texto «Segundo traslado del día autorizado»**, y su entrada en la leyenda al pie. Significa: **el viaje sale, no se cancela por duplicado**. |
| **Requiere revisión** | Otra señal de la grilla de logística, con franja **naranja**. No tiene nada que ver con la autorización: indica que hay algo del traslado que hay que corregir. |
| **Es espontáneo** | Otra señal de la grilla de logística, con franja **roja**: un traslado cargado fuera del circuito habitual. Tampoco tiene relación con la autorización. |
| **Grilla del sector** | La pantalla **Traslados → Pacientes** de logística. Es la única que muestra la marca completa (franja, ícono y leyenda), así que es **desde acá** que hay que decidir si un traslado se cancela o no. |

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026*

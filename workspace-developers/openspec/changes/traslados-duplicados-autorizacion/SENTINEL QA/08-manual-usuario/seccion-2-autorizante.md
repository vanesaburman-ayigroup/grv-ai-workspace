# Sección 2 — Sos quien autoriza: resolvés los pedidos de doble traslado

Esta sección es para vos si tenés el permiso para autorizar traslados duplicados. Es el
caso de los jefes de siniestros y de los referentes con esa atribución.

## Qué vas a aprender

Cuando un gestor necesita dos traslados para el mismo paciente el mismo día y no puede
anular ninguno, te manda un pedido. Vos lo aprobás o lo rechazás, y en los dos casos
escribís un **dictamen**. Acá vas a ver dónde te llegan esos pedidos, qué información
tenés para decidir, **con qué criterio** conviene resolver, y por qué el dictamen es la
parte que más importa.

Es un trabajo corto — dos minutos por pedido — pero del otro lado hay un paciente que no
va a tener cómo viajar hasta que resuelvas.

---

## Paso 1 — Entrá al sistema

Abrí el SAS y completá tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/02-autorizante-01-login.png)

Si la pantalla tarda, esperá: la primera carga del día es la más lenta. No vuelvas a
apretar «Ingresar» varias veces.

---

## Paso 2 — Buscá la tarjeta en tu tablero

Después de entrar llegás a tu Tablero de Siniestros. Los pedidos de autorización no te
llegan por mail ni por notificación: aparecen como una **tarjeta** en el grupo **Turnos**,
llamada **«Autorización Doble Traslado Pendiente»**, con el número de pedidos que
todavía no resolviste.

![Tablero de inicio: el grupo Turnos con la tarjeta «Autorización Doble Traslado Pendiente» y su contador](capturas/02-autorizante-03-card-pendiente.png)

> **Cuidado con esta tarjeta.** Hoy no entra bien en el grupo: el contador se ve cortado
> por arriba y el nombre queda cortado por abajo, así que es fácil pasarla de largo. Es
> la última tarjeta del grupo **Turnos**, abajo a la izquierda, y es la única con icono de
> carpeta. Está reportado como **MAN-A-03**.

**Si la tarjeta no está, no es un error.** La tarjeta sólo aparece cuando tenés pedidos
sin resolver. Cuando resolvés el último, desaparece.

![El mismo grupo Turnos cuando no quedan pedidos pendientes: la tarjeta ya no está](capturas/02-autorizante-12-home-sin-card.png)

Para entrar igual, sin la tarjeta: andá a la sección **Turnos** del menú de la izquierda y
elegí la pestaña **«Autorización Doble Traslado Pendiente»**. La pestaña está siempre.

---

## Paso 3 — Leé la grilla: alcanza para decidir

Hacé clic en la tarjeta. Llegás a la sección Turnos, ya con la pestaña
**«Autorización Doble Traslado Pendiente»** abierta y filtrada: sólo ves lo que tenés que
resolver.

![Grilla de pedidos pendientes con las columnas Lo pidió, Fecha del pedido y Justificación](capturas/02-autorizante-04-grilla-pendientes.png)

Además de las columnas de siempre (denuncia, accidentado, documento, empleador, fecha del
turno, severidad, analista), la grilla te agrega **las tres que importan para decidir**:

| Columna | Qué te dice |
|---|---|
| **Lo pidió** | Quién te mandó el pedido, por su nombre. |
| **Fecha del pedido** | Cuándo te lo pidió, con hora. Te dice cuánto lleva esperando. |
| **Justificación** | El texto que escribió el gestor: por qué necesita los dos traslados. |

La **Justificación** se muestra recortada. Pasá el mouse por encima para leerla completa,
o abrí el pedido (Paso 5), donde aparece entera y destacada.

> **Dos cosas prácticas de esta pantalla.**
>
> - La grilla **no entra a lo ancho**: la columna **ACCIONES** queda cortada del lado
>   derecho y el botón que necesitás puede no verse. Deslizá la tabla hacia la derecha
>   (con la rueda del mouse apretando `Shift`, o arrastrando dentro de la tabla). No hay
>   barra de desplazamiento visible que te avise. Está reportado como **MAN-A-02**.
> - La columna **FECHA AUTORIZACIÓN** siempre está vacía acá, y es correcto: un pedido
>   pendiente todavía no tiene fecha de autorización. Ignorala en esta pestaña
>   (**MAN-A-08**).

---

## Paso 4 — Abrí el menú de acciones de la fila

Al final de la fila, en **ACCIONES**, hay dos botones. El de los **tres puntitos** abre el
menú.

![Menú de acciones de la fila con sus dos opciones](capturas/02-autorizante-05-menu-acciones.png)

Tiene dos opciones:

- **Gestionar autorización** — es la que usás. Abre el panel donde aprobás o rechazás.
- **Ver información de traslado** — **hoy no hace nada.** La apretás y no pasa nada: no
  abre ningún panel, no da error, no avisa. No es tu computadora ni tu conexión. Está
  reportado como **MAN-A-01**; hasta que se corrija, no la uses.

El **otro** botón de la fila (el que está a la izquierda de los tres puntitos) **no** es
«ver el pedido»: te abre la **denuncia completa** y te saca de la grilla. Si lo apretás por
error, volvé con el navegador y entrá de nuevo a la pestaña.

> **Nota de accesibilidad.** Ninguno de los dos botones tiene nombre: si trabajás con
> lector de pantalla, los dos se anuncian simplemente como «icon». Está reportado como
> **MAN-A-04**.

---

## Paso 5 — Leé el pedido en el panel de resolución

Elegí **Gestionar autorización**. Se abre un panel a la derecha,
**«Autorizar el segundo traslado del día»**. Es la pantalla donde decidís, y trae todo lo
que necesitás sin obligarte a salir a buscar nada.

![Panel de resolución: la justificación del gestor destacada, los datos del pedido y del turno, y el campo Dictamen](capturas/02-autorizante-07-drawer-resolucion.png)

Leelo de arriba hacia abajo:

1. **Justificación del gestor** — destacada arriba, con una barra azul al costado. Es lo
   primero que se te muestra a propósito: es el argumento que tenés que evaluar.
2. **El pedido** — quién lo pidió y cuándo. Si la fecha del pedido es de hace varios días
   y el turno es para pronto, resolvelo ya.
3. **El turno** — tipo de turno, fecha y hora, paciente y denuncia. Es el turno **nuevo**,
   el que se sumó al día.
4. **Dictamen** — el campo donde escribís tu decisión.

> **Sobre «Tipo de turno».** Puede mostrarte una sigla del sistema (por ejemplo `FKT` por
> kinesiología) en lugar del nombre completo. Está reportado como **MAN-A-07**.

### Qué te falta y cómo lo consigues

El panel te dice qué turno se está cargando, pero **no** te muestra los traslados que el
paciente **ya tiene** ese día — que es justamente lo que hace al segundo un duplicado. Y
la opción que debería mostrártelo («Ver información de traslado») hoy no funciona.

Si la justificación del gestor no te alcanza para decidir, tenés dos caminos:

- Abrí la denuncia en otra pestaña y entrá a **Turnos**: ahí ves todos los turnos de ese
  día con sus horas y centros médicos.
- Preguntale directamente al gestor que lo pidió — su nombre está en la columna
  **Lo pidió**.

---

## Paso 6 — Con qué criterio se aprueba y con qué criterio se rechaza

Es la parte que ninguna pantalla te va a resolver. La pregunta concreta es:

> **¿Puede este paciente llegar a los dos turnos con un solo viaje?**

**Aprobás** cuando la respuesta es no. Los casos típicos:

- Los dos turnos son en **centros médicos distintos** y no hay forma de ir de uno al otro
  por sus propios medios.
- Hay **muchas horas entre los dos turnos** y el paciente tiene que volver al domicilio en
  el medio (no se lo puede dejar esperando media jornada).
- La **condición del paciente** no le permite trasladarse solo entre los dos turnos.

**Rechazás** cuando con un viaje alcanza:

- Los dos turnos son en el **mismo centro médico**, o en el mismo edificio: el traslado que
  ya existe lo lleva y lo trae.
- Los turnos son **casi seguidos** y el paciente puede esperar en el centro médico.
- El traslado que ya existe es de **ida y vuelta con espera**: ya cubre el día entero.
- La justificación **no dice nada concreto** («se necesita», «lo pidió el paciente») y no
  hay motivo clínico o logístico identificable.

Y una advertencia que no está en la pantalla: **rechazar cancela el traslado nuevo.** No
es «dejarlo para después». Si tenés dudas, es mejor consultar con el gestor antes de
rechazar que rechazar y que el paciente se quede sin viaje.

---

## Paso 7 — Escribí el dictamen: es lo único que le vuelve al gestor

El **Dictamen** es el campo más importante del panel, y conviene entender por qué.

Cuando resolvés, el gestor ve en su pestaña «Autorización Doble Traslado Resuelta» tres
cosas: si fue **Autorizado** o **Rechazado**, tu nombre, y **el dictamen**. Nada más. No
hay comentarios, ni hilo de conversación, ni aviso aparte. **Lo que escribas acá es toda
la explicación que va a tener.**

Por eso:

- Escribí el **motivo**, no la decisión. «Rechazado» ya se lo dice el sistema; lo que
  necesita saber es *por qué*.
- Si rechazás, decile **qué hacer en su lugar**: «el traslado de las 09:00 es de ida y
  vuelta con espera, ya cubre los dos turnos» le resuelve el caso.
- Si aprobás, dejá **constancia del criterio**. Le sirve para la próxima vez, y le sirve a
  quien audite el caso más adelante.

### El dictamen es obligatorio para rechazar

Si apretás **Rechazar** con el dictamen vacío, el sistema no te deja: el rótulo pasa a rojo
y te avisa *«Para rechazar hay que escribir el motivo: es lo único que le vuelve al
gestor»*. El pedido no se toca, el panel queda abierto y podés escribir y reintentar.

![Al rechazar sin dictamen el campo se marca en rojo y el pedido no se resuelve](capturas/02-autorizante-08-rechazo-sin-dictamen.png)

**Para aprobar el dictamen es opcional** — el sistema te deja aprobar en blanco. **No lo
hagas.** Una aprobación sin dictamen le llega al gestor como un «sí» sin ninguna
explicación, y no queda constancia de por qué se autorizó una excepción.

---

## Paso 8 — Los dos caminos

### Camino A — Rechazar

Escribí el motivo en **Dictamen** y apretá **Rechazar**.

![El panel con un dictamen de rechazo escrito, antes de confirmar](capturas/02-autorizante-09-dictamen-rechazo.png)

Al confirmar, el **traslado nuevo queda cancelado** y el pedido sale de tu grilla de
pendientes. El turno en sí sigue existiendo: lo que se cancela es el viaje.

> **No se deshace desde acá.** Si te equivocaste, el gestor tiene que volver a cargar el
> traslado y pedirlo de nuevo.

### Camino B — Autorizar

Escribí el motivo en **Dictamen** y apretá **Autorizar**.

![El panel con un dictamen de aprobación escrito, antes de confirmar](capturas/02-autorizante-10-dictamen-aprobacion.png)

El sistema te confirma en el mismo panel, en verde:

> *Se autorizó el segundo traslado del día. Ya pasó al sector de traslados para que lo
> coordinen.*

![Confirmación de la aprobación y la fila ya fuera de la grilla de pendientes](capturas/02-autorizante-11-confirmacion.png)

Fijate en dos cosas de esta pantalla, porque las dos son la señal de que salió bien:

1. **El mensaje verde.** Te dice explícitamente que el traslado **ya pasó a Logística**.
   Recién ahora alguien va a coordinar el viaje: mientras el pedido estaba pendiente, el
   traslado no existía para el sector de traslados.
2. **La grilla de atrás ya dice «No hay registros para mostrar».** El pedido salió de tus
   pendientes.

Cerrá el panel con **Cerrar**. Si volvés a la pestaña, la grilla queda vacía y en el
tablero la tarjeta desaparece.

![La pestaña de pendientes vacía después de resolver el último pedido](capturas/02-autorizante-13-grilla-vacia.png)

---

## Paso 9 — Qué pasa después (y qué no vas a poder ver)

Después de aprobar:

- El traslado **baja a Logística**, con una **marca de duplicado autorizado**. La gente de
  traslados lo ve señalado, para que sepa que es el segundo viaje del día y que está
  autorizado. Eso es lo que se explica en la Sección 3.
- El gestor **lee tu dictamen** en su pestaña «Autorización Doble Traslado Resuelta».

Después de rechazar:

- El traslado queda **cancelado** y no baja a Logística.
- El gestor lee tu dictamen en la misma pestaña.

> ### ⚠ Lo que hoy no podés hacer: consultar lo que resolviste
>
> Una vez que resolvés un pedido, **no te queda ninguna pantalla donde volver a verlo.** La
> pestaña de resueltos existe sólo para el gestor que pidió, no para quien autoriza, y la
> tarjeta del tablero desaparece al llegar a cero.
>
> En la práctica: si necesitás recordar qué decidiste y por qué, **no lo vas a encontrar
> desde tu perfil**. Está reportado como **MAN-A-05**. Mientras no se corrija, si un caso
> es delicado conviene dejarte una nota propia, o mirar el caso desde la denuncia junto con
> el gestor.

---

## Resumen para tener a mano

| Situación | Qué hacés |
|---|---|
| Dos turnos en **centros distintos**, sin forma de ir de uno al otro | **Autorizar**, con el criterio en el dictamen |
| Muchas horas entre los dos turnos, tiene que volver al domicilio | **Autorizar** |
| Dos turnos en el **mismo centro médico**, o casi seguidos | **Rechazar**, explicando que un viaje alcanza |
| El traslado que ya existe es de **ida y vuelta con espera** | **Rechazar**, indicando que ya cubre el día |
| La justificación **no dice nada concreto** | **Rechazar** — o preguntale al gestor antes |

Cuatro reglas que conviene no olvidar:

1. **El dictamen es lo único que le vuelve al gestor.** Escribí el motivo siempre, también
   cuando aprobás, aunque el sistema te deje aprobar en blanco.
2. **Rechazar cancela el traslado.** No es postergarlo. Si dudás, consultá antes de
   rechazar.
3. **Mientras no resolvés, nadie pasa a buscar al paciente.** Mirá la columna
   **Fecha del pedido**: un pedido viejo con turno cercano es urgente.
4. **Resuelto un pedido, no lo vas a poder volver a consultar.** Si el caso es delicado,
   dejate la constancia por fuera.

---

## Anexo — Estado de esta pantalla en el ambiente de prueba

Lo relevado el 21/08/2026 en TEST, para quien tenga que corregirlo:

| Id | Qué pasa | Severidad |
|---|---|---|
| **MAN-A-01** | «Ver información de traslado» no abre nada: consulta el servidor, responde bien y no monta ningún panel, sin error ni aviso. | Alta |
| **MAN-A-06** | El servicio que resuelve el pedido responde sin ninguna credencial y toma al autorizante del dato que le manda el navegador, no de la sesión: se puede resolver a nombre de otra persona. | Alta |
| **MAN-A-02** | La grilla no entra a lo ancho con las tres columnas nuevas: la columna ACCIONES queda fuera de la pantalla y no hay barra de desplazamiento visible. | Media |
| **MAN-A-03** | La tarjeta del tablero desborda el grupo «Turnos»: el contador se corta por arriba y el nombre por abajo. | Media |
| **MAN-A-04** | Los dos botones de la fila no tienen nombre accesible: un lector de pantalla anuncia «icon» en los dos. | Media |
| **MAN-A-05** | Quien autoriza no tiene ninguna vista de los pedidos que ya resolvió: la pestaña de resueltos existe sólo para el gestor y la tarjeta desaparece al llegar a cero. | Media |
| **MAN-A-07** | El panel muestra el tipo de turno como sigla del sistema (`FKT`) y mezcla rótulos heredados en mayúsculas con los nuevos. | Baja |
| **MAN-A-08** | La columna «FECHA AUTORIZACIÓN» está siempre vacía en la pestaña de pendientes: ocupa ancho y confunde. | Baja |

Evidencia adicional:

- **MAN-A-01** — la pantalla inmediatamente después de elegir «Ver información de
  traslado»: idéntica a antes del clic, sin panel ni aviso.
  ![Después de elegir «Ver información de traslado» la pantalla queda igual](capturas/02-autorizante-defecto-ver-info.png)
- **MAN-A-03** — el tablero completo, donde se ve que la tarjeta desborda el grupo
  «Turnos» mientras el resto de los grupos entra bien.
  ![Tablero completo del autorizante con la tarjeta desbordada en el grupo Turnos](capturas/02-autorizante-02-home.png)

**Verificado y correcto:**

- El bloqueo de **rechazar sin dictamen** es real: no se dispara ninguna llamada al
  servidor y el pedido no se consume.
- El **contador de la tarjeta coincide con las filas de la grilla** (riesgo R-2 del
  change): se comprobó con 1 pendiente (contador 1 ↔ 1 fila) y con 0 (la tarjeta
  desaparece ↔ grilla vacía).
- Al aprobar, el **traslado correcto** — el del pedido, no otro — recibe el estado de
  logística y la marca de duplicado autorizado.
- Ningún identificador interno se le muestra al usuario en la grilla ni en el panel: todo
  se nombra por dato de negocio (regla RF-5.1).

**Qué se escribió en TEST para armar esta sección.** Una sola resolución, sobre el pedido
pendiente del pool de la denuncia 999033 (escenario C, turno de las 10:00 del 08/09/2026):
se **aprobó** con dictamen `INI-2 MANUAL …`. No se creó ni se tocó nada más. Nota: el
pedido que debía dejar la etapa 1 nunca se registró (defecto MAN-G-01), así que este era
el único pendiente disponible; su aprobación es además la que la etapa 3 necesita para
mostrar la marca en Logística. Para encontrarlo:

```sql
SELECT id_autorizacion_traslado_duplicado, id_traslado, estado, id_autorizante,
       fecha_autorizacion, dictamen
FROM   autorizaciones_traslado_duplicado
WHERE  dictamen LIKE 'INI-2 MANUAL%';
```

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026*

# Sección 1 — Sos el gestor: cargás el turno y resolvés el traslado duplicado

Esta sección es para vos si cargás turnos con traslado y **no** tenés el permiso para
autorizar traslados duplicados. Es el caso de la mayoría de los gestores y referentes.

## Qué vas a aprender

Cuando le cargás a un paciente un turno con traslado en un día en el que **ya tiene otro
traslado**, el sistema no te deja seguir de largo: te avisa y te obliga a decidir qué
hacer. Acá vas a ver cómo se ve ese aviso, qué información te da y **cuál de las tres
salidas te conviene** en cada situación.

No hace falta que sepas nada del circuito de antemano. Seguí los pasos en orden.

---

## Paso 1 — Entrá al sistema

Abrí el SAS y completá tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/01-gestor-01-login.png)

Si la pantalla tarda en cargar, esperá: la primera carga del día es la más lenta. No
vuelvas a apretar «Ingresar» varias veces.

---

## Paso 2 — Ubicate en tu inicio

Después de entrar llegás a tu tablero. Ahí tenés tus tarjetas de trabajo de siempre:
**Mis denuncias**, **Turnos** con sus pendientes de programar y de procesar,
**Requerimientos pendientes**, **RAR** y las demás.

![Tablero de inicio del gestor con sus tarjetas de trabajo](capturas/01-gestor-02-home.png)

> **Sobre la tarjeta de resultados.** Cuando alguien resuelva un pedido de autorización
> tuyo, te va a aparecer en este tablero una tarjeta **«Autorización Doble Traslado
> Resuelta»** con la cantidad de respuestas que todavía no leíste. Si no tenés respuestas
> nuevas, la tarjeta no aparece: eso es normal, no es un error. En el **Paso 9** te
> mostramos dónde leer los resultados igual.

---

## Paso 3 — Abrí la denuncia y entrá a Turnos

Buscá la denuncia por su número desde **Consulta Siniestros** y abrila. Ya adentro, en el
menú de la izquierda elegí **Turnos**.

Vas a ver la lista de turnos del paciente y, arriba a la derecha, el botón **Nuevo turno**.

![Sección Turnos de la denuncia, con la lista de turnos y el botón Nuevo turno](capturas/01-gestor-03-turnos-denuncia.png)

---

## Paso 4 — Cargá el turno nuevo

Apretá **Nuevo turno** y elegí el tipo de turno que estás cargando — en el ejemplo,
**Consulta**. Se abre un panel a la derecha con tres pasos: **Datos de turno**,
**Traslado** y **Confirmación**.

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

Ese tilde es el que dispara la revisión. Si el paciente ya tiene traslado ese día,
aparece un bloque naranja con todo lo que necesitás para decidir. **Es la pantalla más
importante de esta sección.**

![Bloque de conflicto: el aviso, los traslados que ya existen y las tres salidas](capturas/01-gestor-05-bloque-conflicto.png)

Leelo de arriba hacia abajo:

1. **El aviso**: «El paciente ya tiene un traslado ese día», y debajo cuántos son —
   en el ejemplo, **3 traslados vigentes**.
2. **La lista de los traslados que ya existen**. De cada uno te dice el **tipo de turno**,
   la **hora** y el **centro médico** al que va. Y cuando el traslado ya está solicitado,
   te aclara además: *«Estado del traslado: SOLICITADO. Todavía no se le avisó a la
   agencia»* — o sea, todavía se puede dar marcha atrás sin costo.
3. **Una aclaración del viaje** cuando corresponde. En el ejemplo: *«El viaje es de ida y
   vuelta con espera, así que se cancelan los dos tramos juntos»*. Ojo con esto: si anulás,
   se van los dos tramos, no sólo uno.
4. **Las tres salidas**, para que elijas una.

> **Importante.** Mientras no elijas una salida no vas a poder guardar el turno. El
> sistema no te deja avanzar «como si no hubiera pasado nada»: es a propósito.

---

## Paso 6 — Elegí la salida: cuál te conviene

Esta es la duda real. Las tres salidas resuelven cosas distintas.

### Salida A — «Anular esos traslados y usar el nuevo»

**Cuándo la usás:** cuando el traslado que ya existía **ya no sirve**. Se reprogramó el
turno, se cambió el centro médico, el paciente no va a ir a ese turno, o simplemente el
traslado que estás cargando ahora reemplaza al anterior.

Al elegirla se abren dos campos:

- **Motivo**: viene precargado con *«Cancelado por alarma repetida»*. Cambialo si el
  motivo real es otro.
- **Observación**: la escribe el sistema por vos, y deja constancia de quién anuló, cuándo
  y contra qué traslado se duplicaba. Podés agregarle texto, pero **no borres lo que ya
  dice**: es la trazabilidad de la anulación.

![Salida «Anular»: motivo precargado y observación escrita por el sistema](capturas/01-gestor-06-salida-anular.png)

Apretá **Anular el traslado** para aplicarla.

> **Cuidado:** la anulación es inmediata y no se deshace desde acá. Si el viaje es de ida
> y vuelta, se cancelan los dos tramos. Y si el aviso te dijo que ya se le informó a la
> agencia, coordiná con Logística antes de anular.

### Salida B — «Guardar el turno sin traslado»

**Cuándo la usás:** cuando el paciente **ya tiene cómo viajar**. El traslado que existe lo
lleva al centro médico y desde ahí puede ir al segundo turno, o vuelve con el mismo viaje.
El turno hay que registrarlo igual, pero traslado nuevo no hace falta.

Al elegirla, el sistema **destilda «Requiere traslado» solo** y cierra el bloque: el turno
va a quedar guardado sin traslado asociado.

![Al elegir «Guardar el turno sin traslado» se destilda «Requiere traslado» y el bloque se cierra](capturas/01-gestor-07-salida-sin-traslado.png)

Es la salida más simple y la más frecuente. Si dudás entre ésta y pedir autorización,
preguntate: **¿el paciente necesita dos viajes distintos, o le alcanza con uno?** Si le
alcanza con uno, es ésta.

### Salida C — «Pedir autorización para los dos traslados»

**Cuándo la usás:** cuando el paciente **realmente necesita los dos viajes** y ninguno se
puede anular. Por ejemplo: kinesiología a la mañana en un centro y una interconsulta a la
tarde en otro, sin posibilidad de volver al domicilio en el medio.

Al elegirla aparece el campo **«Por qué se necesitan los dos traslados»**. Es obligatorio y
lo va a leer una persona: tu jefe de siniestros o quien tenga el permiso para autorizar.
Escribí el motivo clínico o logístico concreto, no «se necesita».

![Salida «Pedir autorización» con la justificación escrita](capturas/01-gestor-08-salida-pedir-autorizacion.png)

Después apretás **Enviar el pedido**.

Mientras el pedido esté sin respuesta, **el traslado no baja a Logística**: nadie va a
buscar al paciente hasta que se apruebe. Tenelo en cuenta si el turno es para pronto.

> ### ⚠ Estado actual de esta salida en el ambiente de prueba
>
> Hoy, al cargar un **turno nuevo**, el botón «Enviar el pedido» no llega a registrar el
> pedido: aparece el mensaje **«No se pudo registrar el pedido. Reintentá o contactá a mesa
> de ayuda»** y, además, **desaparecen las tres salidas** y el botón «Siguiente» queda
> deshabilitado. Desde ahí no se puede continuar: hay que cancelar el panel y volver a
> empezar.
>
> ![El pedido falla, desaparecen las tres salidas y «Siguiente» queda deshabilitado](capturas/01-gestor-09-pedido-fallido.png)
>
> Mientras esto no esté corregido, si necesitás los dos traslados: guardá el turno con la
> **Salida B** para no perder el registro del turno, y pedile la autorización a tu
> referente por fuera del sistema. Está reportado como **MAN-G-01**.

---

## Paso 7 — Revisá el resumen y confirmá

Apretá **Siguiente** hasta el paso **Confirmación**. Ahí el sistema te muestra lo que
estás por guardar: fecha, hora, cantidad, prestación, centro médico y, si corresponde, el
tipo de viaje del traslado.

![Paso de confirmación con el resumen del turno](capturas/01-gestor-10-paso3-confirmacion.png)

Leelo antes de apretar **Confirmar** — sobre todo la fecha y la hora, que son las que
disparan el conflicto.

> **Ojo:** este resumen **no** repite qué salida elegiste ni la justificación que
> escribiste. Si no te acordás, volvé con **Atrás** al paso Traslado y verificá antes de
> confirmar. Está reportado como mejora (**MAN-G-06**).

---

## Paso 8 — Confirmá y verificá en la lista

Apretá **Confirmar**. El panel se cierra y el turno nuevo aparece en la lista de turnos de
la denuncia, con su fecha y hora.

![El turno nuevo ya guardado en la lista de turnos de la denuncia](capturas/01-gestor-11-turno-guardado-sin-traslado.png)

**Siempre verificá que el turno figure en la lista.** Si el panel no se cierra y te quedás
en el paso de confirmación, el turno **no** se guardó: cancelá, revisá qué salida elegiste
y volvé a intentar. (Hoy eso pasa cuando elegís la Salida C; está reportado como
**MAN-G-02**.)

---

## Paso 9 — Leé la respuesta a tus pedidos

Cuando alguien resuelve un pedido tuyo, la respuesta te llega a la pestaña **«Autorización
Doble Traslado Resuelta»**.

Para llegar: desde tu tablero de inicio entrá a la sección **Turnos** y elegí la última
pestaña, **«Autorización Doble Traslado Resuelta»**.

![Pestaña «Autorización Doble Traslado Resuelta» con los pedidos ya respondidos](capturas/01-gestor-12-tab-resueltos.png)

De cada pedido resuelto vas a leer:

| Columna | Qué te dice |
|---|---|
| **Resultado** | **Autorizado** (verde) o **Rechazado** (rojo). |
| **Lo resolvió** | Quién te respondió, por su nombre. |
| **Fecha de la respuesta** | Cuándo la resolvió. |
| **Dictamen** | Lo que escribió al resolver: por qué te lo aprobó o te lo rechazó. |
| **Mi justificación** | El texto que habías escrito vos al pedirlo. |

El **Dictamen** y **Mi justificación** aparecen recortados con puntos suspensivos. Pasá el
mouse por encima y el texto completo aparece en un cartelito.

Dos cosas para tener presentes:

- Si te lo **autorizaron**, el traslado sigue su curso normal y baja a Logística.
- Si te lo **rechazaron**, el traslado queda cancelado. Leé el dictamen: ahí está el
  criterio, y te sirve para la próxima vez que tengas un caso parecido.

---

## Resumen para tener a mano

| Situación del paciente | Salida que elegís |
|---|---|
| El traslado que ya existe **no sirve más** (se reprogramó, cambió el centro) | **Anular** esos traslados y usar el nuevo |
| Con el traslado que ya tiene **le alcanza** para los dos turnos | **Guardar el turno sin traslado** |
| Necesita **los dos viajes** y ninguno se puede anular | **Pedir autorización** — con una justificación concreta |

Tres reglas que conviene no olvidar:

1. **El aviso te dice cuántos traslados hay, no uno solo.** Si dice «3 traslados
   vigentes», leé los tres antes de decidir: anular los alcanza a todos.
2. **«Ya se le avisó a la agencia» cambia las cosas.** Si el bloque no aclara que todavía
   no se avisó, coordiná con Logística antes de anular.
3. **Un pedido de autorización frena el traslado.** Mientras esté sin respuesta, nadie
   pasa a buscar al paciente. Si el turno es urgente, avisale a quien tiene que resolverlo.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026*

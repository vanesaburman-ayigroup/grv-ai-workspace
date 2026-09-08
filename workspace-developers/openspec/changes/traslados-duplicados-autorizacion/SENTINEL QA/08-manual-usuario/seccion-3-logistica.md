# Sección 3 — Sos logística: reconocés el traslado que ya fue autorizado

Esta sección es para quien trabaja en el sector de logística: quien mira la grilla de
traslados del día, asigna agencias y decide qué viaje sale y qué viaje se cancela.

## Lo único que no te podés olvidar

> ## ⚠ Una fila marcada NO se cancela por duplicado
>
> Cuando veas **dos traslados del mismo paciente para el mismo día**, tu reflejo va a ser
> pensar que uno está repetido y cancelarlo. **Fijate primero si tiene la marca.**
>
> La marca significa que un jefe de siniestros ya miró ese caso y **autorizó los dos
> viajes**: el paciente necesita las dos salidas. Si la cancelás, el paciente se queda sin
> cómo volver, y alguien tiene que rehacer todo el circuito de autorización desde cero.
>
> **Marca = ya autorizado = sale.** Si te parece que igual está mal, preguntá antes de
> cancelar; no lo canceles «por las dudas».

Todo lo que sigue es cómo reconocer esa marca, y qué traslados **no te van a llegar**
(que es la otra mitad del circuito, y la menos obvia).

---

## Paso 1 — Entrá al sistema

Abrí el SAS con tu usuario y tu contraseña.

![Pantalla de ingreso al SAS](capturas/03-logistica-01-login.png)

Si la pantalla tarda en cargar, esperá. La primera carga del día es la más lenta; no
vuelvas a apretar «Ingresar» varias veces.

---

## Paso 2 — Tu tablero de logística

Después de entrar llegás a tu tablero, con los contadores de siempre: los traslados de
hoy y de mañana, hotelería, adelantos y reintegros.

![Tablero de logística con los contadores de traslados de hoy y de mañana](capturas/03-logistica-02-tablero.png)

**La marca de traslado autorizado no tiene contador propio en el tablero.** No hay una
tarjeta que te avise «tenés un traslado autorizado». La marca vive **dentro de la grilla**,
en la fila del traslado. Por eso el paso siguiente es entrar a la grilla y mirar.

---

## Paso 3 — Abrí la grilla de traslados del sector

Entrá a **Traslados → Pacientes**. Se abre la grilla con los filtros arriba, las pestañas
**Remis/Ambulancia** y **Transporte público**, y la tabla abajo.

![Grilla de traslados de pacientes tal como abre, con el período puesto en el día de hoy](capturas/03-logistica-03-grilla-sector.png)

**El período viene puesto en el día de hoy.** Son dos campos, *desde* y *hasta*. Cambialos
por el día que quieras mirar y apretá **Aplicar filtros** — hasta que no lo apretás, la
tabla no cambia.

Así se ve la grilla filtrada por un día con traslados de un mismo paciente:

![Grilla filtrada por el 08/09/2026: tres traslados del mismo paciente, dos con marca y uno sin marca](capturas/03-logistica-04-grilla-filtrada.png)

Tres traslados del mismo paciente, el mismo día, en el mismo centro médico: **09:00, 10:00
y 10:30**. A simple vista parece un caso de traslados repetidos. No lo es: dos de los tres
están autorizados, y la grilla te lo está diciendo.

---

## Paso 4 — Las tres capas de la marca

La marca se te muestra de **tres formas a la vez**. Con reconocer una alcanza, pero
conviene saber las tres, porque según la pantalla en la que estés vas a ver unas u otras.

### Capa 1 — La franja de color al costado de la fila

Es la señal más rápida de leer: una **barra vertical verde** pegada al borde izquierdo de
la fila.

![Dos filas con la franja verde al costado y una tercera fila sin franja](capturas/03-logistica-05-franja-color.png)

Mirá la diferencia: los traslados de **10:30** y **10:00** tienen la franja verde; el de
**09:00** no tiene nada. El de las 09:00 es el traslado que ya existía —el «original»—, y
no necesita autorización. Los otros dos son los duplicados que **sí fueron autorizados**.

### Capa 2 — El ícono, y el texto que aparece al pasar el mouse

En la primera columna de la fila, antes del número de traslado, aparece un **ícono
naranja**. Pasale el mouse por encima **sin hacer clic** y te muestra el texto:

![El ícono de la fila con su texto: «Segundo traslado del día autorizado»](capturas/03-logistica-06-icono-tooltip.png)

El texto dice exactamente: **«Segundo traslado del día autorizado»**.

Ese es el ícono, de cerca:

![Acercamiento del ícono de la marca: un octógono naranja con un signo de exclamación](capturas/03-logistica-08-zoom-celda-iconos.png)

> **Ojo con este ícono.** Es un octógono naranja con un signo de exclamación: la forma de
> una advertencia, la de algo que está mal. **Acá significa lo contrario**: significa que
> el caso ya se revisó y se autorizó. No te dejes llevar por la forma del ícono — leé el
> texto pasando el mouse. Está reportado como **MAN-L-03**.

### Capa 3 — La leyenda al pie de la tabla

Abajo de la tabla están las referencias de los colores de las franjas:

![Leyenda al pie: «Requiere revisión» en naranja, «Segundo traslado del día autorizado» en verde, «Es espontáneo» en rojo](capturas/03-logistica-07-leyenda.png)

Es tu chuleta: si no te acordás qué significa un color, está siempre ahí.

> **Una incoherencia a tener en cuenta.** En la leyenda, «Segundo traslado del día
> autorizado» figura con un círculo **verde** —el color de la franja—, pero el ícono que
> ves en la fila es **naranja**. Los dos son la misma marca. La leyenda te sirve para los
> colores de las franjas, no para los íconos. Está reportado junto con **MAN-L-03**.

---

## Paso 5 — Cómo distinguirla de las otras dos señales

Las franjas de color son tres y **cada fila muestra una sola**. Esta es la tabla completa:

| Franja | Qué significa | Qué se espera de vos |
|---|---|---|
| **Verde** | Segundo traslado del día **autorizado** | Que lo trates como cualquier traslado válido: asignale agencia. **No lo canceles por duplicado.** |
| **Naranja** | **Requiere revisión** | Que lo mires: hay algo del traslado que hay que corregir. |
| **Rojo** | **Es espontáneo** | Traslado cargado fuera del circuito habitual. |
| **Sin franja** | Traslado común, sin ninguna señal | Nada en particular. |

> ### ⚠ Cuidado: una fila puede tener más de un motivo, y la franja muestra sólo uno
>
> Si un traslado está **autorizado como segundo del día** y además es **espontáneo** o
> **requiere revisión**, la franja te muestra el **otro** color —rojo o naranja— y la
> franja verde desaparece. La autorización sigue estando; lo que se pierde es el aviso.
>
> ![La misma fila autorizada mostrando franja naranja y roja en lugar de la verde](capturas/03-logistica-10-defecto-franja-tapada.png)
>
> **Cómo protegerte:** cuando veas dos traslados del mismo paciente el mismo día, no
> decidas sólo por el color de la franja. **Mirá si la fila tiene el ícono** y pasale el
> mouse: el ícono sí se mantiene en esta pantalla. Y si no hay ícono ni certeza, preguntá
> antes de cancelar. Está reportado como **MAN-L-02**.

---

## Paso 6 — Lo que NO te llega (y es correcto que no te llegue)

Esta es la mitad del circuito que no se ve, y la que más confusión genera. **No todos los
traslados duplicados llegan a tu grilla.** Los que faltan no son un error del sistema.

De los cuatro traslados que existen para ese paciente ese día, **a tu grilla llegan tres**.
Fijate en el contador del pie de la captura del Paso 3: **«1–3 de 3»**.

| Situación del traslado | ¿Lo ves en tu grilla? | Por qué |
|---|---|---|
| Segundo traslado **autorizado** | **Sí**, con la marca verde | Ya se resolvió a favor: hay que hacerlo. |
| Traslado **original** del día | **Sí**, sin marca | Nunca necesitó autorización. |
| Segundo traslado con pedido **pendiente de resolver** | **No** | Todavía no se decidió. No aparece hasta que alguien lo apruebe. |
| Segundo traslado con pedido **rechazado** | **No** | El rechazo cancela el traslado. No hay viaje que organizar. |

Las dos consecuencias prácticas:

1. **Si te avisan de un traslado que no ves en la grilla, probablemente esté esperando
   autorización.** No lo cargues a mano ni lo reclames como faltante: pedile al gestor de
   la denuncia que verifique en qué estado está el pedido. Cuando se apruebe, va a
   aparecer solo.
2. **Un traslado que apareció «de la nada» en tu grilla puede ser uno recién autorizado.**
   Es exactamente lo que pasó con el traslado de las **10:00** de este ejemplo: no estaba
   en la grilla mientras el pedido esperaba respuesta, y **apareció ya marcado** en cuanto
   el jefe de siniestros lo aprobó. Si aparece con la franja verde, está autorizado: sale.

---

## Paso 7 — El mismo traslado, visto dentro de la denuncia

Si entrás a la denuncia (haciendo clic en el número de siniestro de la fila) y vas a
**Traslados**, ves los traslados de ese paciente. **Esta pantalla no es igual a la del
sector.**

![Vista de Traslados dentro de la denuncia: las franjas verdes están, la columna de íconos no](capturas/03-logistica-09-traslado-en-denuncia.png)

Acá **la franja verde está y la leyenda al pie también, pero no hay ícono**. Es decir: no
tenés dónde pasar el mouse para leer «Segundo traslado del día autorizado». El único aviso
es el color.

Eso hace que en esta pantalla el problema del Paso 5 sea más grave: si la fila además es
espontánea o requiere revisión, **no queda ninguna señal de que el traslado está
autorizado**.

![Dentro de la denuncia, la fila autorizada que además es espontánea queda pintada de rojo y sin ningún ícono](capturas/03-logistica-11-defecto-denuncia-sin-marca.png)

**Recomendación mientras esto no esté corregido:** para decidir si cancelás o no un
traslado duplicado, **hacelo desde la grilla del sector** (Traslados → Pacientes), que es
donde están las tres capas de la marca. La vista de la denuncia sirve para consultar, no
para decidir cancelaciones. Está reportado como **MAN-L-04**.

---

## Resumen: cuatro reglas

1. **Marca verde o ícono naranja con el texto «Segundo traslado del día autorizado» = el
   viaje sale.** No se cancela por duplicado.
2. **Ante dos traslados del mismo paciente el mismo día, revisá la marca antes de tocar
   nada.** Si no estás seguro, preguntá; cancelar es lo único que no se deshace solo.
3. **Lo que no ves, no es un error.** Los pedidos pendientes y los rechazados no bajan a
   tu sector, y está bien que sea así.
4. **Decidí desde la grilla del sector, no desde la denuncia.** Es la pantalla que muestra
   la marca completa.

---

## Anexo — Estado de estas pantallas en el ambiente de prueba

Lo relevado el **21/08/2026 en TEST** con el perfil de logística, para quien tenga que
corregirlo. El ambiente se sondeó antes de empezar y al terminar: los dos servicios
respondieron 200 en las seis sondas, así que nada de lo que sigue es efecto de un
despliegue en curso.

| Id | Qué pasa | Severidad |
|---|---|---|
| **MAN-L-01** | El texto de la marca nunca nombra a quien autorizó. El front tiene dos textos —uno genérico y uno que dice «Segundo traslado del día, autorizado por *tal*. No cancelar por duplicado.»— y el servicio que puebla la grilla **no devuelve el dato del autorizante**, así que siempre cae al genérico. Se pierde la frase más importante de las dos: la que dice explícitamente que no hay que cancelar. | Alta |
| **MAN-L-02** | La marca se pierde cuando la fila también es espontánea o requiere revisión. Las tres señales comparten la franja izquierda y se excluyen entre sí, con prioridad espontáneo → requiere revisión → duplicado autorizado. En la grilla del sector sobrevive el ícono; **dentro de la denuncia no queda nada**. | Alta |
| **MAN-L-03** | El ícono de la marca es un octógono naranja `#F29423` con signo de exclamación: la iconografía de una advertencia para señalar algo que está autorizado, y el mismo naranja que «Requiere revisión». Además no coincide con el color de su propia entrada en la leyenda, que es verde `#0B8F8A`. Induce justamente la acción que la marca quiere evitar. | Media |
| **MAN-L-04** | Dentro de la denuncia no se renderiza la columna de íconos: la marca queda reducida al color de la franja, sin texto ni tooltip. El color pasa a ser el único portador de la información, lo que además la hace inaccesible para quien no distingue esos colores. | Media |
| **MAN-L-05** | La marca no tiene ninguna presencia en el tablero de logística: no hay contador ni aviso de que llegó un traslado autorizado. Sólo se descubre entrando a la grilla y mirando fila por fila. | Baja |

### Detalle de la evidencia

- **MAN-L-01** — la respuesta del servicio que lista los traslados devuelve, para los dos
  traslados marcados, el campo que indica que están autorizados, pero **no incluye** el
  campo con el nombre de quien autorizó (no viene vacío: no viene). El texto observado al
  pasar el mouse fue el genérico, «Segundo traslado del día autorizado», en las dos filas.
- **MAN-L-02** — verificado sobre el build desplegado en TEST simulando las combinaciones
  que el juego de datos no tiene. En la grilla del sector, al marcar la fila como «requiere
  revisión» la franja pasó de verde a naranja y la fila sumó el ícono de esa señal: el
  ícono de la marca **sigue estando**, pero pasa a ser el segundo de dos íconos naranjas
  contiguos y deja de tener franja propia. Al marcarla como espontánea, la franja pasó a
  rojo y el ícono de la marca quedó como único ícono. En la vista de la denuncia, donde no
  hay columna de íconos, la fila espontánea quedó roja y **sin ninguna señal de la
  autorización**. Ninguna de estas simulaciones escribió nada en TEST: sólo se alteró lo
  que recibía el navegador.
- **MAN-L-03** — los dos íconos se descargaron del ambiente y se comparó su contenido. El
  de la marca es un octógono con signo de exclamación relleno `#F29423`; el de «Requiere
  revisión» es una hoja con lápiz, también `#F29423`. Distinto dibujo, idéntico naranja.
  El color de la franja de la marca, en cambio, es `#0B8F8A`.

### Verificado y correcto

- **La marca llega al traslado correcto.** El traslado que la etapa 2 aprobó apareció
  marcado en la grilla de logística, y el traslado original del día quedó sin marca. La
  franja medida en pantalla es exactamente el verde de la leyenda.
- **Los pedidos pendientes y los rechazados no bajan al sector.** El listado del día
  informó **3 de 3** filas: los dos duplicados autorizados y el original. El traslado del
  pedido rechazado no aparece, ni en la grilla del sector ni dentro de la denuncia.
- **La grilla del sector entra a lo ancho**, con la columna ACCIONES visible y sus botones
  accesibles. No repite el problema de ancho de la grilla del autorizante (MAN-A-02).
- **El ícono de la marca tiene texto alternativo correcto** («Segundo traslado del día
  autorizado»), así que un lector de pantalla lo anuncia. No repite el problema de los
  botones sin nombre del autorizante (MAN-A-04).
- **Ningún identificador interno se le muestra al usuario** (regla RF-5.1): todo se nombra
  por paciente, documento, hora, fecha, centro médico y estado del viaje.

### Limitación de este relevamiento

**No se pudo verificar contra la base de datos.** El nombre del servidor de la base de
TEST dejó de resolverse desde esta máquina durante toda la etapa (se reintentó cuatro
veces, separadas, con el mismo resultado), mientras la aplicación seguía respondiendo
normalmente. Todo lo que este anexo afirma sobre qué existe y qué no se verificó **por
pantalla y contra la respuesta del propio servicio** que puebla la grilla, que para este
caso es la fuente que ve el usuario. Queda pendiente confirmar contra la base:

```sql
-- Qué traslados del 08/09/2026 de la denuncia 999033 tienen estado de logística
-- asignado (los que bajan al sector) y cuál es el estado de su pedido.
SELECT t.id_traslado, t.id_estado_logistica, a.estado, a.fecha_autorizacion
FROM   traslados t
       LEFT JOIN autorizaciones_traslado_duplicado a ON a.id_traslado = t.id_traslado
WHERE  t.id_traslado IN (2470632, 2470633, 2470634, 2470635);
```

### Qué se dejó escrito en TEST

**Nada.** Esta etapa fue de sólo lectura: logística no crea turnos ni pedidos. No se
modificó ningún traslado, ningún pedido y ningún estado, ni se escribió ninguna
observación. Las combinaciones de señales que el juego de datos no tenía se produjeron
interceptando la respuesta en el navegador, sin tocar el servidor.

El pool de la denuncia **999033** quedó como lo dejó la etapa 2: los traslados de las
09:00, 10:00 y 10:30 del 08/09/2026 visibles en logística —los dos últimos marcados— y el
traslado del pedido rechazado cancelado e invisible. Para encontrarlo por pantalla:
**Traslados → Pacientes**, período **08/09/2026** a **08/09/2026**, Nro. Siniestro
**999033**.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026*

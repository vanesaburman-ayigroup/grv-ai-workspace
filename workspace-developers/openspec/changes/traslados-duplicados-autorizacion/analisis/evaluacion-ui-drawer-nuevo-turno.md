# Evaluación de UI — bloque de conflicto de traslados duplicados (drawer de nuevo turno)

**Ambiente:** DEV — https://dev.sas.colonia-suiza.com.ar
**Usuario:** `tramitador.supervisor` (perfil "Jefe De Siniestros", con permiso `autorizar_traslado_mismo_dia`)
**Denuncia:** B464435 — paciente Ragnar Lothbrok — turno del pedido pendiente: 4560455
**Fecha de la evaluación:** 14/08/2026, ~14:05 a 14:25 (hora Argentina)
**Herramienta:** Playwright sobre Chromium, anchos 1440 / 768 / 390 px
**Capturas:** `./capturas/` (los nombres se citan en cada hallazgo)
**Mediciones:** `./capturas/mediciones-espaciados-1440.json` (coordenadas, tamaños y tipografías reales tomadas del DOM a 1440 px)

---

## 0. Versión observada — IMPORTANTE

**Lo que hay hoy en DEV es la versión NUEVA, no la anterior.**

El bloque muestra el grupo de radio buttons con las tres opciones (`Anular ese traslado y usar el nuevo` / `Guardar el turno sin traslado` / `Autorizar los dos traslados`) y sus textos explicativos debajo de cada una. El `radiogroup` existe en el DOM con `name="salidaConflictoTraslado"` y valores `ANULAR`, `SIN_TRASLADO`, `AUTORIZACION`.

Es decir: **las MRs !1789 / !1790 (o al menos su contenido) ya están desplegadas en DEV**. Todo lo que sigue evalúa la versión con radio buttons — no la de botones sueltos apilados. Los problemas listados abajo son problemas de la versión nueva, no de la vieja.

Ver `capturas/08-paso2-requiere-traslado-tildado-1440.png` y `capturas/09-bloque-conflicto-detalle-1440.png`.

---

## 1. Qué se pudo recorrer y qué no

### Recorrido completo (sin escribir nada)

| Paso | Estado | Evidencia |
|---|---|---|
| Login con `tramitador.supervisor` | OK | — |
| Menú **Turnos** | OK | — |
| Tab **"Traslados duplicados a autorizar"** (última de las 6 tabs) | OK, visible | `01-tab-traslados-duplicados-1440.png` |
| Fila del pedido pendiente (turno 4560455, B464435, Ragnar Lothbrok) | OK | `01`, `02` |
| **Ojito** → denuncia completa B464435 | OK | `03-denuncia-B464435-1440.png` |
| Pestaña **Turnos** de la denuncia | OK | `04-drawer-nuevo-turno-paso1-1440.png` |
| **Nuevo turno → Consulta** | OK | `05-drawer-consulta-abierto-1440.png` |
| Paso 1 completado (fecha 15/08/2026, hora 16:00, cantidad 1, centro médico y prestación) | OK | `06-paso1-completo-1440.png` |
| Paso 2 **Traslado**, sin tildar | OK | `07-paso2-traslado-inicial-1440.png` |
| Paso 2 con **"Requiere traslado"** tildado → **aparece el bloque de conflicto** | OK | `08`, `09` |
| Las tres opciones recorridas una por una | OK | `10`, `12`, `13` |
| Sub-formulario de **anulación** (Motivo + Observación + botón "Anular el traslado") | OK | `10`, `11` |
| Responsive 1440 / 768 / 390 | OK | `14` a `19` |

### Lo que deliberadamente NO se hizo

- **No se apretó "Anular el traslado", "Guardar sin traslado" ni "Siguiente" hacia Confirmación.** Los tres botones estaban habilitados y son acciones que escriben en la base. El pedido pendiente de la tab sigue pendiente y el turno 4560454 sigue en `SOLICITADO`.
- **No se autorizó ni rechazó** el pedido desde la tab (los botones de tilde y cruz de la columna ACCIONES quedaron sin tocar).
- El drawer se cerró con **Cancelar**. No quedó ningún turno nuevo cargado.

### Un tropiezo menor, ya resuelto

En el primer login el shell single-spa quedó en blanco (`<main id="root">` vacío, sin errores de consola; el bundle `grv-tramitadores.js` quedó como request pendiente). Se resolvió recargando `/home`. No parece relacionado con el bloque evaluado, pero conviene saber que pasa: `capturas/00-home-1440.png` es esa pantalla en blanco.

---

## 2. Problemas encontrados, por gravedad

Se distingue **[DEFECTO]** (algo funcionalmente mal o roto) de **[ESTÉTICA]** (mejorable, no roto).

---

### 2.1 [DEFECTO] La observación de anulación se arma con la fecha HTML-escapada — CONFIRMADO

**Se confirma el reporte de la líder técnica.** El campo Observación se precarga con:

```
Cancelado por Supervisor Ayi el 14&#x2F;08&#x2F;2026 por duplicarse con el traslado  del mismo día.
```

Evidencia: `capturas/11-zoom-bloque-anular-html-escapado.png` (zoom), `capturas/10-opcion-anular-seleccionada-1440.png` (contexto).

**Dónde está el problema exactamente:** no es un problema de render. La entidad `&#x2F;` está en el **`value` del propio `<textarea>`**, leído directamente del DOM. Es decir, el string llega ya escapado desde donde se lo construye. Consecuencia: si el usuario aprieta "Anular el traslado", **eso se persiste tal cual en la observación del traslado anulado** y va a quedar así en la bitácora, en los reportes y en cualquier pantalla que muestre esa observación. No es cosmético.

**Segundo defecto en el mismo texto:** `"...por duplicarse con el traslado  del mismo día."` — hay **doble espacio** entre "traslado" y "del". Es una interpolación que resolvió a string vacío: falta el identificador del traslado o del turno con el que se duplica. El resto del bloque tiene otras interpolaciones que sí funcionan bien (el alert arma `Turno 4560454 · Consulta · 10:44:00 · CENTRO DE KINESIOLOGIA Y REABILITACIÓN (IFI)` correctamente, sin escapar nada), así que el problema está acotado a la plantilla de la observación de anulación.

**Revisión del resto de los textos:** no hay `&#x2F;` ni entidades escapadas en ningún otro texto del bloque. El único afectado es este.

---

### 2.2 [DEFECTO] "Guardar el turno sin traslado" convive con "Requiere traslado" tildado y con dos campos de traslado obligatorios

Al elegir la segunda opción, la pantalla dice tres cosas contradictorias al mismo tiempo:

1. El botón dice **"Guardar sin traslado"**.
2. Justo debajo, el checkbox **"Requiere traslado" sigue tildado en verde**.
3. Y más abajo siguen visibles **"Traslado solicitado por *"** y **"Tipo de viaje *"**, ambos marcados como obligatorios y ambos vacíos.

Evidencia: `capturas/13-opcion-guardar-sin-traslado.png`.

Esto responde directamente al "no tiene sentido" del reporte: el formulario está pidiendo obligatoriamente los datos del traslado que el usuario acaba de decir que no quiere. Y no queda claro si el botón "Guardar sin traslado" guarda el turno completo en el acto (salteando el paso 3 de Confirmación) o solo registra la decisión. Es la ambigüedad más costosa del bloque, porque el usuario no puede predecir qué va a pasar antes de apretar.

Lo mismo, en menor escala, aplica a las otras dos opciones: **cada una expone su propio botón primario dentro del paso** ("Anular el traslado", "Guardar sin traslado"), en el **mismo turquesa `#0DDCD6` que el "Siguiente" del pie del wizard**. Hay dos acciones primarias visualmente equivalentes en pantalla y ninguna indicación de cuál cierra el flujo.

---

### 2.3 [DEFECTO] El checkbox "Requiere traslado" se renderiza *después* del bloque de conflicto, con la misma sangría que las opciones

El checkbox que dispara todo el bloque queda **debajo** de las tres opciones, y con la sangría **idéntica** a la de los radios: las etiquetas de los radios arrancan en x=721 y "Requiere traslado" también en x=721. Separación vertical entre la descripción del tercer radio y el checkbox: **12 px**.

Evidencia: `capturas/09-bloque-conflicto-detalle-1440.png`, `capturas/11-zoom-bloque-anular-html-escapado.png`.

Leído por primera vez, el checkbox parece **una cuarta opción de la lista** — con la diferencia de que es un cuadrado en vez de un círculo y ya está tildado. Es la causa principal de que el bloque "no se entienda": la causa aparece después del efecto, y el control que la representa se disfraza de opción excluyente.

---

### 2.4 [DEFECTO] A 768 px y a 390 px el drawer se sale 47 px por la izquierda y no hay scroll para recuperarlo

El panel tiene un ancho calculado que siempre da **viewport + 47 px**:

| Viewport | Ancho del drawer | `left` | Resultado |
|---|---|---|---|
| 1440 px | 797 px | 643 | OK |
| 768 px | 815 px | **−47** | 47 px cortados a la izquierda |
| 390 px | 437 px | **−47** | 47 px cortados a la izquierda |

Y `document.documentElement.scrollWidth` sigue siendo igual al viewport: **no hay scroll horizontal**, así que esos 47 px son irrecuperables.

Evidencia: `capturas/14-responsive-768.png`, `capturas/15-responsive-390-paso1-clipping.png`, `capturas/16-responsive-390-bloque-conflicto.png`, `capturas/18-responsive-390-anular-scroll.png`, `capturas/19-responsive-768-bloque-conflicto.png`.

Lo que se pierde en el bloque de conflicto:

- **Los círculos de los radio buttons quedan cortados**: solo se ve un resto de arco, como un `)`. **Es imposible saber cuál opción está seleccionada.** El bloque entero deja de funcionar (`16`, `18`, `19`).
- Etiquetas mutiladas: `otivo *` (Motivo), `eservación *` (Observación), `aslado solicitado por *`, `edan 156 caracteres`, `tado del traslado`, `egí cómo resolverlo`.
- El botón "Anular el traslado" arranca en x=−15: su borde izquierdo queda fuera de pantalla.
- El título del drawer se lee `evo turno: Consulta`.

Es el hallazgo más grave en términos de "en 390 se va a romper": no se degrada, se rompe.

---

### 2.5 [DEFECTO] A 390 px los botones del pie se superponen entre sí

Medición directa a 390 px:

| Botón | left | right |
|---|---|---|
| Atrás | −15 | 105 |
| Cancelar | **87** | 207 |
| Siguiente | 223 | 343 |

"Cancelar" empieza en 87 cuando "Atrás" todavía termina en 105: **18 px de superposición real**, no óptica. Evidencia: `capturas/18-responsive-390-anular-scroll.png` — se ve la píldora de "Atrás" metida dentro del borde de "Cancelar".

Los tres botones son de 120 px fijos y no se apilan ni se encogen en mobile.

---

### 2.6 [DEFECTO] Cruzar el breakpoint reinicia el wizard y borra todo lo cargado

Al pasar de 1440 px a 768 px, el drawer volvió al **paso 1 con el formulario vacío**, perdiendo fecha, hora, cantidad, centro médico y prestación. Lo mismo al volver de 768 a 1440. Entre 390 y 768 el estado se preservó, así que el corte está en algún breakpoint intermedio (~900 px): al cruzarlo el componente se remonta.

En la práctica: si alguien está cargando un turno en una notebook y engancha/desengancha un monitor externo, o rota una tablet, pierde la carga. Se reprodujo dos veces.

---

### 2.7 [DEFECTO menor] "Fecha de carga" muestra la hora en formato de 12 horas sin AM/PM

El encabezado del drawer dice `Fecha de carga: 14/8/2026 - 02:14:55` cuando la hora real de la máquina era **14:14:55** (`America/Buenos_Aires`, verificado). Son las 14, no las 2.

Dos problemas juntos: reloj de 12 horas sin meridiano (02 en lugar de 14), y formato de fecha `d/m/yyyy` (14/8/2026) cuando el resto del sistema usa `dd/mm/yyyy` (la propia grilla de turnos muestra `15/08/2026`). Evidencia: cualquiera de las capturas del drawer, p. ej. `05`, `08`.

---

### 2.8 [ESTÉTICA / comprensión] El espaciado está invertido: las opciones están más cerca entre sí que cada etiqueta de su propia explicación

Es el hallazgo que explica técnicamente el "quedaron apretados". Medido a 1440 px:

| Distancia | Valor |
|---|---|
| Etiqueta de la opción → su propia descripción | **6 px** |
| Descripción de una opción → etiqueta de la **siguiente** opción | **3 px** |

O sea: **la separación entre dos alternativas excluyentes es la mitad de la separación interna de cada una**. El resultado es que las seis líneas se leen como un párrafo continuo de seis renglones, no como tres opciones. El paso vertical entre radios es de 44 px, que para un ítem de dos líneas (label 20 px + caption 15 px = 35 px de contenido) deja apenas 9 px de aire.

Evidencia: `capturas/09-bloque-conflicto-detalle-1440.png`, `capturas/11-zoom-bloque-anular-html-escapado.png`, mediciones en `mediciones-espaciados-1440.json`.

---

### 2.9 [ESTÉTICA] El aviso del conflicto se disuelve en el formulario apenas termina el recuadro del alert

El alert ámbar (con ícono, borde y fondo) está bien: se distingue. El problema es lo que viene inmediatamente después, que es parte del mismo mensaje y ya no tiene ninguna contención:

- `Estado del traslado: SOLICITADO. Todavía no se le avisó a la agencia.` — a **10 px** del borde inferior del alert, sin caja, sin sangría, 14 px regular gris.
- `Elegí cómo resolverlo antes de guardar el turno` — a **8 px** de la línea anterior, **con exactamente la misma tipografía, el mismo peso y el mismo color** (14 px / 400 / misma clase de estilo).

Consecuencia: la instrucción operativa (lo único que le dice al usuario qué tiene que hacer) tiene **cero jerarquía sobre un dato informativo**. Se lee como el segundo renglón de un mismo párrafo. Debería ser el título de la decisión y hoy es letra chica.

Además, todo el conjunto "alert + estado + instrucción + opciones + sub-formulario" **no está contenido en nada**: no hay caja, ni fondo, ni línea, ni título de sección que lo separe del resto del formulario del turno. Termina el tercer radio y arranca "Requiere traslado" con los campos normales del turno, en el mismo plano visual. El conflicto — que es una excepción que exige una decisión — está maquetado como si fuera un grupo de campos más.

---

### 2.10 [ESTÉTICA] Cuatro anchos de campo distintos y tres márgenes izquierdos distintos en 300 px de alto

Anchos medidos a 1440 px (columna de contenido de 734 px):

| Campo | Ancho |
|---|---|
| Motivo (anulación) | **239 px** |
| Motivos de traslado mismo día (autorización) | **239 px** |
| Traslado solicitado por | 363 px |
| Tipo de viaje | 363 px |
| Observación | 734 px |

Y los bordes izquierdos: 690 px (títulos y campos del formulario) → 688 px (círculos de los radios, 2 px afuera de la grilla) → 721 px (etiquetas de los radios y el checkbox) → 690 px otra vez (Motivo, Observación, campos de traslado).

Nada alinea con nada. En particular, **el sub-formulario de la opción elegida (Motivo / Observación / botón) arranca en x=690, alineado con el formulario general y NO indentado bajo la opción que lo generó** — así que visualmente no se lee como dependiente de esa opción. Evidencia: `capturas/11-zoom-bloque-anular-html-escapado.png`.

---

### 2.11 [DEFECTO menor] El valor del select Motivo choca con la flecha del desplegable

Con 239 px de ancho, el texto `Cancelado por alarma repetida` mide 215 px arrancando en x=675, o sea termina en x=890. La flecha del select ocupa de x=890 a x=914. **Cero píxeles de separación**: en la captura se ve el caret encima de la última letra. Con cualquier motivo más largo va a truncar. Evidencia: `capturas/11-zoom-bloque-anular-html-escapado.png` (mirar el final de "repetida").

---

### 2.12 [ESTÉTICA / DEFECTO menor] Los selects obligatorios se ven como líneas vacías, sin placeholder

`Traslado solicitado por *`, `Tipo de viaje *` y los dos de Motivo se renderizan como un subrayado con una flecha al final y **nada adentro** — ni "Seleccionar", ni texto de ayuda, ni un valor por defecto. Están marcados con asterisco rojo (obligatorios) pero un usuario que llega ahí no tiene indicio visual de que son desplegables ni de qué se espera.

Es además una **inconsistencia con el resto de la aplicación**: los filtros de la propia grilla de Turnos usan el placeholder `Seleccionar` en todos sus selects (ver `capturas/01-tab-traslados-duplicados-1440.png`).

---

### 2.13 [ESTÉTICA] Arriba todo apretado, abajo 130 px de aire muerto — y el pie no es fijo

En el estado inicial del bloque (con "Requiere traslado" tildado y ninguna opción elegida), el contenido termina en y=663 y los botones del pie están en y=796: **133 px de vacío** justo debajo de un bloque donde nada respira.

Peor: **el pie no es sticky** (`position: static`). Cuando se elige la opción de anular, el contenido crece y los botones se van a y=951, o sea **fuera de la ventana de 900 px de alto**. El usuario tiene que scrollear para llegar a "Siguiente" — y como los botones de acción de cada opción sí están a la vista, es fácil apretar el que no cierra el flujo.

---

### 2.14 [ESTÉTICA] Copy inconsistente entre las dos opciones que piden motivo

- Opción "Anular ese traslado y usar el nuevo" → etiqueta **`Motivo *`**.
- Opción "Autorizar los dos traslados" → etiqueta **`Motivos de traslado mismo día *`** (en plural, para un select de valor único, y con un nombre que suena a campo de base de datos).

Y en la opción de autorizar hay un texto de ayuda debajo del campo — `Queda registrado a tu nombre, con la fecha y el motivo que elijas.` — que repite lo que ya dice la descripción del radio de arriba (`Tenés el permiso para autorizarlo: queda autorizado en el acto, sin esperar a nadie.`). Evidencia: `capturas/12-opcion-autorizar-dos-traslados.png`.

Nota sobre otro contador: `Quedan 156 caracteres.` se pinta en `rgb(26,32,35)` (casi negro, el color del texto de entrada) mientras el resto de los helpers del bloque son `rgb(116,116,116)` gris. Un helper con color de contenido.

---

### 2.15 [ESTÉTICA] Estados de campo: qué está deshabilitado, qué obligatorio, qué vacío

Resumen de lo observado:

- **Deshabilitado:** el paso 3 "Confirmación" del stepper, el botón "Atrás" en el paso 1, y "Prestación" hasta que se elige Centro médico (esto último está bien resuelto).
- **Obligatorios y vacíos simultáneamente, dentro del bloque:** `Traslado solicitado por *` y `Tipo de viaje *` — y en la opción "Guardar el turno sin traslado" son obligatorios que el usuario no debería tener que completar (ver 2.2).
- **"Siguiente" deshabilitado sin decir por qué:** está gris tanto si falta elegir una opción como si faltan los dos selects de traslado. No hay mensaje de validación, ni borde rojo, ni nada que distinga los dos casos. El usuario ve un botón apagado y no sabe qué le falta.
- No se encontró ningún campo obligatorio que sea técnicamente imposible de completar, más allá de la contradicción del punto 2.2.

---

## 3. Propuestas de mejora de layout

Sin código; en términos de agrupación, jerarquía y espaciado.

### 3.1 Encerrar todo el conflicto en un único bloque con identidad propia

Hoy el conflicto está desparramado en el flujo del formulario. Debería ser **una sola tarjeta** — fondo ámbar suave o gris muy claro, borde de 1 px, esquinas redondeadas, padding interno de 16-20 px — que contenga, en este orden: el aviso, el estado del traslado existente, la instrucción y las tres opciones con su sub-formulario. Que se lea "acá hay algo que resolver antes de seguir" antes de leer una sola palabra.

El alert de MUI actual debería **dejar de ser una caja adentro de la nada** y pasar a ser el encabezado de esa tarjeta: ícono + título + los datos del turno en conflicto, sin borde propio (el borde ya lo da la tarjeta).

### 3.2 Poner el checkbox "Requiere traslado" ANTES del bloque, y despegarlo

El orden lógico es: primero la pregunta ("¿requiere traslado?"), después la consecuencia ("hay conflicto, resolvelo"). Hoy está invertido. Además hay que sacarle la sangría de 721 px: llevarlo al margen del formulario (690 px), separarlo con **24 px por debajo** del bloque de conflicto, y considerarlo parte del formulario del turno, no de la lista de opciones. Ideal: cuando aparece el conflicto, el checkbox queda arriba y visualmente atenuado (ya cumplió su función), y el foco se lo lleva la tarjeta.

### 3.3 Arreglar la jerarquía de espaciado de las opciones

La regla es simple y hoy está al revés:

- Etiqueta → su descripción: **4 px** (son una unidad, se pegan).
- Opción → opción siguiente: **16 px mínimo** (son cosas distintas, se separan).

Con eso solo, sin tocar nada más, el grupo pasa de "párrafo de seis renglones" a "tres alternativas". Es el cambio de mayor impacto por menor esfuerzo.

Reforzarlo dándole a cada opción una **superficie propia**: cada radio en una fila con padding de 12 px, borde de 1 px gris claro, y la fila seleccionada con borde y fondo de acento. Es el patrón de "radio card". Vuelve obvio, sin leer nada, que son tres cajas de las que se elige una — que es exactamente lo que hoy no se entiende.

### 3.4 Anidar el sub-formulario dentro de la opción elegida

Motivo, Observación y el botón de acción tienen que quedar **indentados al nivel de la etiqueta de su radio** (x=721, no 690) y dentro de la superficie de la opción seleccionada. Así el usuario ve que esos campos pertenecen a la decisión que tomó y no al turno. Con el patrón de radio card esto sale gratis: el sub-formulario se expande dentro de la tarjeta seleccionada.

### 3.5 Darle jerarquía tipográfica a la instrucción, y bajarle el ruido al dato

- `Elegí cómo resolverlo antes de guardar el turno` → **14-16 px, semibold, color de texto principal**, con 16 px de aire arriba. Es un título de sección, tratarlo como tal.
- `Estado del traslado: SOLICITADO. Todavía no se le avisó a la agencia.` → dato de contexto. Su lugar natural es **dentro del encabezado del aviso**, junto a los datos del turno en conflicto, en 12-13 px gris. Mejor todavía: `SOLICITADO` como chip de estado al lado del número de turno, y la aclaración ("todavía no se le avisó a la agencia") como texto secundario. Así el usuario entiende de un golpe qué tan reversible es lo que va a hacer.

### 3.6 Unificar anchos de campo y márgenes

Definir dos anchos y usar solo esos:

- **Campo corto** (Motivo, Tipo de viaje, Traslado solicitado por): mitad de la columna, ~360 px a 1440. El Motivo actual de 239 px es el que rompe la grilla y el que hace chocar el texto con la flecha.
- **Campo largo** (Observación): ancho completo.

Y **un solo margen izquierdo** para todo el formulario. Los círculos de los radios que hoy sobresalen 2 px a la izquierda de la grilla se corrigen alineando el borde del control, no la caja del label.

### 3.7 Una sola acción primaria, y en el pie

Los botones "Anular el traslado" / "Guardar sin traslado" dentro del paso compiten con "Siguiente" en el mismo color. Dos caminos, ambos válidos:

- **Preferible:** eliminar los botones por opción. La opción elegida es un dato del formulario; el flujo lo cierra el "Siguiente" del pie, y el paso 3 de Confirmación resume qué va a pasar ("se va a anular el traslado 4560454 y crear uno nuevo"). Es más seguro: nada se ejecuta hasta la confirmación final.
- **Si la acción tiene que ejecutarse en el acto** (porque anular es una llamada aparte), entonces el botón debe ser **secundario** (outline, no relleno turquesa), estar dentro de la superficie de la opción elegida, y decir en el propio botón que ejecuta ya ("Anular ahora"), con confirmación previa.

### 3.8 Coherencia entre la opción elegida y el resto del formulario

Si la opción es "Guardar el turno sin traslado", los campos `Traslado solicitado por` y `Tipo de viaje` **no deben estar visibles ni ser obligatorios**, y el checkbox "Requiere traslado" debería destildarse solo (o mostrarse deshabilitado con una nota de por qué). Hoy la pantalla se pide a sí misma datos que acaba de declarar innecesarios.

### 3.9 Pie fijo, y decir por qué "Siguiente" está apagado

Fijar la barra de acciones al pie del drawer (sticky, con separador y fondo) para que no se vaya de pantalla cuando el bloque crece. Y cuando "Siguiente" está deshabilitado, mostrar al lado, en 12 px, qué falta ("Elegí cómo resolver el conflicto" / "Completá Traslado solicitado por y Tipo de viaje"). Un botón gris sin explicación es la forma más rápida de que alguien abra un ticket.

### 3.10 Responsive: 47 px, apilado y radios visibles

- **Lo primero, y es un bug:** que el ancho del drawer no exceda el viewport. En ≤ 768 px debería ser 100 % del ancho, sin el offset de 47 px. Mientras eso no se arregle, el bloque es inusable en mobile porque los radios no se ven.
- Debajo de ~600 px: los campos en **una sola columna** (Fecha / Hora / Cantidad hoy siguen en tres columnas a 390 px, con la fecha en ~90 px y el placeholder truncado a `D/MM/YY`).
- Los botones del pie **apilados o a ancho completo** en mobile, nunca tres de 120 px fijos en fila (hoy se superponen 18 px).
- El stepper de 3 pasos a 390 px envuelve "Datos de turno" en tres renglones. Conviene un stepper compacto tipo "Paso 2 de 3 · Traslado".

### 3.11 Los dos arreglos de texto

- Generar la observación de anulación con la fecha **sin escapar HTML** (`14/08/2026`), y revisar el punto donde se arma ese string, porque el escape viene de ahí y se persiste.
- Completar el identificador que falta: `...por duplicarse con el traslado <N> del mismo día.` — y de paso sacar el doble espacio.
- Renombrar `Motivos de traslado mismo día` a `Motivo` (singular, consistente con la otra opción), y sacar el helper que repite la descripción del radio.
- Unificar el formato de fecha/hora del encabezado a `dd/MM/yyyy HH:mm` (24 horas).

---

## 4. Índice de capturas

| Archivo | Qué muestra |
|---|---|
| `00-home-1440.png` | El shell en blanco del primer login (tropiezo, resuelto recargando) |
| `01-tab-traslados-duplicados-1440.png` | Tab "Traslados duplicados a autorizar" con la fila de B464435 |
| `02-tab-acciones-scroll-derecha-1440.png` | Columna ACCIONES: los 3 botones envueltos en 2 filas; la grilla necesita scroll horizontal |
| `03-denuncia-B464435-1440.png` | Denuncia completa tras el ojito |
| `04-drawer-nuevo-turno-paso1-1440.png` | Menú "Nuevo turno" desplegado en la pestaña Turnos |
| `05-drawer-consulta-abierto-1440.png` | Drawer paso 1, vacío |
| `06-paso1-completo-1440.png` | Paso 1 completado |
| `07-paso2-traslado-inicial-1440.png` | Paso 2 sin tildar "Requiere traslado" |
| `08-paso2-requiere-traslado-tildado-1440.png` | **Bloque de conflicto completo a 1440** — versión con radios |
| `09-bloque-conflicto-detalle-1440.png` | El drawer entero recortado, para ver densidad |
| `10-opcion-anular-seleccionada-1440.png` | Opción "Anular", con Motivo, Observación y botón |
| `11-zoom-bloque-anular-html-escapado.png` | **`14&#x2F;08&#x2F;2026` confirmado**, doble espacio, caret sobre el texto del Motivo |
| `12-opcion-autorizar-dos-traslados.png` | Opción "Autorizar los dos", con `Motivos de traslado mismo día` |
| `13-opcion-guardar-sin-traslado.png` | **La contradicción:** "Guardar sin traslado" + "Requiere traslado" tildado + 2 campos obligatorios |
| `14-responsive-768.png` | 768 px: recorte de 47 px por la izquierda |
| `15-responsive-390-paso1-clipping.png` | 390 px: paso 1 recortado, 3 columnas apretadas |
| `16-responsive-390-bloque-conflicto.png` | **390 px: los radios cortados, imposible ver la selección** |
| `17-responsive-390-anular-fullpage.png` | 390 px, página completa |
| `18-responsive-390-anular-scroll.png` | **390 px: "Atrás" y "Cancelar" superpuestos**, etiquetas mutiladas |
| `19-responsive-768-bloque-conflicto.png` | 768 px: bloque de conflicto con el recorte |
| `mediciones-espaciados-1440.json` | Coordenadas, tamaños, tipografías y colores reales del DOM a 1440 px |

---

## 5. Resumen ejecutivo

Sobre la queja original ("no tiene sentido, está feo, los elementos quedaron apretados"), las tres partes se confirman y tienen causas concretas:

- **"No tiene sentido"** → el checkbox que dispara el bloque aparece *después* del bloque y disfrazado de cuarta opción (2.3), y la opción "guardar sin traslado" sigue exigiendo los datos del traslado (2.2).
- **"Apretados"** → la separación entre opciones (3 px) es **la mitad** de la separación interna de cada opción (6 px): la jerarquía de espaciado está literalmente invertida (2.8).
- **"Feo"** → cero contención del bloque, instrucción sin jerarquía tipográfica respecto de un dato informativo, cuatro anchos de campo y tres márgenes izquierdos distintos (2.9, 2.10).

Y hay tres defectos duros que exceden lo estético: la **fecha HTML-escapada que se va a persistir** (2.1), el **recorte de 47 px que hace invisibles los radios en 768 y 390** (2.4), y la **superposición de botones a 390** (2.5). El primero ya estaba reportado y queda confirmado con evidencia a nivel DOM.

**Versión evaluada: la NUEVA, con los tres radio buttons y sus explicaciones. Ya está en DEV.**

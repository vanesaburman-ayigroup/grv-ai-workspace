# Verificación en DEV de las once correcciones — traslados duplicados

- **Ambiente:** https://dev.sas.colonia-suiza.com.ar
- **Usuario:** `tramitador.supervisor` (Ayi Supervisor / Jefe De Siniestros), con permiso `autorizar_traslado_mismo_dia`
- **Denuncia:** B464435 — Ragnar Lothbrok (DNI 38401345, GCBA / PROVINCIA ART)
- **Fecha de la verificación:** 18/08/2026
- **Capturas:** `capturas-verificacion/`
- **Nada se guardó ni se resolvió.** Se abrieron drawers, se tildó y destildó, se eligieron opciones y se cerró con «Cancelar». El pedido pendiente sigue pendiente.

---

## 0. Estado del deploy de DEV

El deploy **está actualizado** con `develop`. Se confirma porque en la grilla ya aparece el menú de tres puntitos con las dos opciones, que es el último commit de la serie (`75110039 feat(turnos): menu de acciones y ver informacion de traslado en la tab de duplicados`). Ninguno de los puntos que se reportan abajo como faltantes se explica por un deploy viejo.

## 0.bis Limitación de los datos de prueba (leer antes de la tabla)

El pool de DEV tiene los traslados cargados el **15/08/2026**, que **hoy ya es pasado**. La respuesta real de `POST /grv/logistica/traslados/conflictos-mismo-dia` para esa fecha devuelve, para los tres traslados en conflicto:

```json
"horasAlViaje": -73,
"salidas": {
  "puedeAnular": false,
  "puedeDerivarALogistica": false,
  "puedeGuardarSinTraslado": true,
  "requiereAutorizacion": false,
  "detalle": "El viaje ya empezó, así que no hay traslado duplicado que evitar."
}
```

Es decir: **con los datos tal como están hoy, el bloque de conflicto sólo ofrece UNA salida** («Guardar el turno sin traslado») y las otras dos no se pueden ver. Ver `08-bloque-conflicto-1440.png`.

Para poder verificar los puntos 1 a 4 y 7 a 8 se interceptó en el navegador la respuesta de ese endpoint (y del gate `tiene-por-denuncia-y-fecha`) devolviendo `puedeAnular / puedeDerivarALogistica / requiereAutorizacion = true` con `horasAlViaje: 20`. **No se modificó código ni datos**: es un stub en memoria de la pestaña, que se desactivó al terminar. Las capturas obtenidas con stub están señaladas.

> **Acción sugerida antes de la prueba de la otra persona:** mover los turnos/traslados del pool a una fecha futura, o el flujo completo no se va a poder probar.

---

## 1. Tabla de veredictos

| # | Punto | Veredicto | Evidencia | Captura |
|---|---|---|---|---|
| 1 | Elección entre las tres salidas (radios, no tres botones sueltos) | **SÍ** | `<radiogroup>` real con tres `<radio>`: «Anular ese traslado y usar el nuevo», «Guardar el turno sin traslado», «Autorizar los dos traslados». El formulario de cada salida se despliega dentro de la opción elegida, no todos a la vez. | `09-tres-opciones-radio-1440.png` (stub), `10-opcion-anular-observacion.png`, `12-opcion-autorizar-los-dos.png` |
| 2 | Cada opción con su explicación debajo del título | **SÍ** | «El paciente viaja con el traslado que estás cargando. El que ya existía se cancela con su motivo.» / «El paciente viaja con el traslado que ya tiene. El turno se guarda igual.» / «Tenés el permiso para autorizarlo: queda autorizado en el acto, sin esperar a nadie.» Título en una línea, explicación en la de abajo, con jerarquía tipográfica. | `09-tres-opciones-radio-1440.png` |
| 3 | El traslado en conflicto se nombra por sus datos, no por su id | **SÍ** | Cartel: «Turno 4560454 · Consulta · 11:15:00 · CENTRO DE KINESIOLOGIA Y REABILITACIÓN (IFI) · AGENCIA DEMO SRL». El `idTraslado` (1469807) viaja en el JSON pero **no se pinta en ningún lado**. Barrido del DOM con `/\d{6,9}/`: sólo aparecen nro. de denuncia y DNI. | `09-tres-opciones-radio-1440.png` |
| 4 | Observación de anulación: fecha sin escapar y texto completo | **SÍ** | `value` real del `<textarea>`: `Cancelado por Supervisor Ayi el 18/08/2026 por duplicarse con el traslado del turno de Consulta 11:15:00 del mismo día.` Sin `&#x2F;`, sin hueco vacío, sin doble espacio. | `10-opcion-anular-observacion.png` |
| 5 | «Requiere traslado» antes del bloque de conflicto | **SÍ** | El checkbox está arriba, fuera de la tarjeta, alineado con el resto del formulario; la tarjeta de conflicto arranca debajo, con su propia sangría. | `08-bloque-conflicto-1440.png`, `09-tres-opciones-radio-1440.png` |
| 6 | «Guardar el turno sin traslado» destilda solo y habilita «Siguiente» | **SÍ** | Al elegir esa opción: «Requiere traslado» queda destildado, desaparece la tarjeta de conflicto **y** los obligatorios «Traslado solicitado por» / «Tipo de viaje», y «Siguiente» pasa de `disabled` a habilitado. Un solo clic, sin botón extra. | `11-guardar-sin-traslado-autodestildado.png` |
| 7 | Tarjeta con identidad propia y opciones que respiran | **PARCIAL** | Identidad sí: fondo crema, barra de acento naranja a la izquierda, separada del formulario. Respiración no: el hueco entre opciones es de **12 px** contra un padding interno de **10 px 12 px** — las opciones respiran lo mismo entre sí que adentro, así que el grupo se lee como una lista compacta y no como tres bloques. | `09-tres-opciones-radio-1440.png` |
| 8 | Responsive 1440 / 768 / 390 | **PARCIAL** | Los círculos de los radios **se ven completos en los tres anchos** (left 708 con tarjeta en x=695 a 1440; left 65 con tarjeta en x=52 a 768 y a 390): el desborde de ~47 px está corregido. Sin scroll horizontal del documento (`scrollWidth == innerWidth` en los tres). **Pero a 390 px los botones del pie se superponen**: «Atrás» ocupa x 32→152 y «Cancelar» x 102→222, misma línea (y=1143), 50 px pisados. También a 390 el stepper se corta («Confirmació»). | `09` (1440), `14-bloque-conflicto-768.png`, `15-bloque-conflicto-390.png`, `16-pie-botones-superpuestos-390.png` |
| 9 | Aprobar/rechazar como iconos verde y rojo con tooltip | **NO** | En la grilla hay **exactamente dos botones**: el ojito y el de tres puntitos. No hay iconos de aprobar ni de rechazar. Ninguno de los dos botones tiene `title` ni `aria-label`; al hacer hover no aparece ningún tooltip. Aprobar y rechazar viven ahora dentro del drawer de resolución («Rechazar» / «Autorizar»). | `01-grilla-traslados-duplicados-1440.png`, `02-celda-acciones-zoom.png` |
| 10 | Menú de tres puntitos con las dos opciones | **PARCIAL** | El menú está y tiene exactamente «Gestionar autorización» y «Ver información de traslado». «Gestionar autorización» abre bien el drawer de resolución. **«Ver información de traslado» NO abre nada**: tira `TypeError: E.resetTurnosTablaDetalle is not a function` en consola y la pantalla queda igual. Reproducido dos veces, la segunda con recarga limpia de la página. | `03-menu-tres-puntitos.png`, `05-drawer-gestionar-autorizacion.png`, `17-ver-info-traslado-no-abre.png`, `consola-errores.log` |
| 11 | «Mis denuncias / Denuncias de otros» presentes + drawer de resolución prolijo | **SÍ** | Los dos botones están en la tab. En el drawer: justificación destacada arriba en un bloque con barra azul, secciones «El pedido» / «El turno» / «Dictamen» separadas por divisores, y **ningún id de turno** (barrido del DOM: sólo B464435 y el DNI). | `01-grilla-traslados-duplicados-1440.png`, `05-drawer-gestionar-autorizacion.png` |

### Resolución de la contradicción entre 9 y 10

**Quedó sólo el menú de tres puntitos. Los iconos de aprobar/rechazar ya no están en la grilla.** No es un olvido de deploy: el commit `4ef88cbb feat(turnos): iconos en la grilla…` fue seguido por `75110039`, que explícitamente mueve las acciones al menú («Las dos acciones pasan a un menu de tres puntitos, junto al ojito»). La versión vigente es la del menú.

---

## 2. Lo que quedó mal o a medias, por gravedad

### DEFECTOS

1. **«Ver información de traslado» está roto — la opción no hace nada.**
   Causa raíz encontrada en el código de `develop`: `components/Turnos/TablaTurnos.js` llama `dispatch(actions.resetTurnosTablaDetalle())` (líneas 153 y 175), pero `redux/actions/index.js` **no re-exporta** `resetTurnosTablaDetalle` en su bloque `from './turnos'`. La acción existe en `redux/actions/turnos.js:478` y los demás consumidores la importan directo del archivo (`import { resetTurnosTablaDetalle } from '.../actions/turnos'`); sólo este componente la busca en el barrel. Resultado: excepción antes de disparar el fetch, y el drawer nunca abre. Fix: agregar el nombre al `export { … } from './turnos'` o importarlo directo del módulo.

2. **A 390 px «Atrás» y «Cancelar» se superponen 50 px** en el pie del drawer de nuevo turno. Es el pie compartido del wizard, así que afecta a todos los pasos, no sólo al de traslado.

3. **El bloque de conflicto resuelve sólo el primer traslado en conflicto.** La API devolvió **tres** traslados en conflicto para el 15/08 (turnos 4560454, 4560455, 4560456) y el front toma sólo uno: `useConflictoTraslado.js:44` → `const primerConflicto = fechasConConflicto[0]?.traslados?.[0] ?? null`. Quien resuelve «anular ese traslado» anula uno y deja los otros dos duplicados en pie, sin enterarse de que existen. No estaba en el pedido, pero es una decisión de producto que conviene confirmar.

4. **Copy contradictorio en el bloque de conflicto** cuando el turno es pasado: se leen seguidas «Estado del traslado: SOLICITADO. Todavía no se le avisó a la agencia.» y «El viaje ya empezó, así que no hay traslado duplicado que evitar.» El `detalle` lo manda el backend en función de `horasAlViaje < 0`, pero convive con una línea de estado que dice lo contrario. Ver `08-bloque-conflicto-1440.png`.

5. **Los botones de la grilla no tienen nombre accesible ni tooltip** (`title` y `aria-label` vacíos, `alt="icon"` / `alt="Icon"`). Para un lector de pantalla las dos acciones de la fila son indistinguibles, y el punto del tooltip que se había pedido no está cubierto por ninguna de las dos versiones.

### ESTÉTICA MEJORABLE

6. **Las opciones no respiran más entre sí que adentro** (12 px de gap contra 10–12 px de padding). Subir el gap a ~20 px, o bajar el padding, haría que se lean como tres alternativas y no como una lista.
7. **Las horas se muestran con segundos**: «11:15:00» en el cartel de conflicto y también dentro del texto de la observación de anulación. En el resto del sistema la hora va como `11:15`.
8. **A 390 px el stepper se corta**: el tercer paso se lee «Confirmació». No hace scroll ni se apila.
9. **El drawer de resolución mezcla capitalizaciones de etiqueta**: «Lo pidió:», «Fecha del pedido:», «Tipo de turno:» en oración conviviendo con «FECHA TURNO:», «ACCIONADO:», «DENUNCIA:» en mayúsculas, heredadas de los headers de la grilla.
10. **En 768 px el encabezado del drawer se pisa con el ícono de hamburguesa** del menú lateral, arriba a la izquierda. Ver `13-resize-768-estado.png` y `14-bloque-conflicto-768.png`.

---

## 3. Cosas que nadie pidió y están mal

- **`Tipo de turno: -`** en el drawer de resolución: campo vacío mostrado con guión, aunque el turno es de tipo Consulta (la grilla y el bloque de conflicto sí lo dicen). `05-drawer-gestionar-autorizacion.png`.
- **`FECHA AUTORIZACIÓN` y `SEVERIDAD` vacíos** en la fila de la grilla; severidad se pinta como chip «No informado» y la fecha queda en blanco sin placeholder.
- **Al redimensionar la ventana, el wizard de nuevo turno se resetea al paso 1 y pierde lo cargado.** Pasó al ir de 1440 a 768 px (`13-resize-768-estado.png`). En un uso real esto es rotar el teléfono o abrir la consola del navegador y perder el formulario.
- **Errores de consola preexistentes en toda la pantalla** (`consola-errores.log`): `Each child in a list should have a unique "key" prop` (varias veces), `validateDOMNesting(...): <div> cannot appear as a child of <td>`, `findDOMNode is deprecated`.
- **Dos servicios caídos en DEV, ajenos a este desarrollo**: `GET /coloniaChatbot/grv-colonia-chatbot.js` → 404, que rompe el parcel single-spa y deja el cartel «Ocurrió un error al cargar el asistente virtual»; `GET /grv/tramitador/referente-siniestros/contadores-por-gestores` → **504**; `GET /grv/novedades/stream` → `ERR_CONNECTION_RESET`.
- **No se encontró ninguna clave de i18n cruda** tipo `turnos.conflictoTraslado.algo` en pantalla. Todos los textos resolvieron.

---

## 4. Recorrido: hasta dónde se llegó

El recorrido se completó entero salvo dos puntos, ambos documentados arriba:

- **«Ver información de traslado»** no se pudo evaluar en contenido porque el drawer no abre (defecto 1). Se llegó hasta el clic en la opción del menú; la pantalla queda sin cambios y la excepción salta en consola. `17-ver-info-traslado-no-abre.png`.
- **Las tres salidas del bloque de conflicto** no se pueden ver con los datos reales de DEV, porque la fecha del pool (15/08/2026) ya pasó y el backend habilita una sola salida. Se verificaron con la respuesta del endpoint interceptada en el navegador, sin tocar código ni datos.

No se guardó ningún turno, no se anuló ningún traslado y no se autorizó ni rechazó ningún pedido. El drawer de nuevo turno se cerró siempre con «Cancelar» y el de resolución también.

---

## Anexo: inventario de capturas

| Archivo | Qué muestra |
|---|---|
| `01-grilla-traslados-duplicados-1440.png` | Tab «Traslados duplicados a autorizar» con «Mis denuncias / Denuncias de otros» y la fila del pedido pendiente |
| `02-celda-acciones-zoom.png` | Celda ACCIONES ampliada: sólo ojito + tres puntitos |
| `03-menu-tres-puntitos.png` | Menú abierto con «Gestionar autorización» y «Ver información de traslado» |
| `04-drawer-info-traslado.png` | Primer intento de «Ver información de traslado»: no abre nada |
| `05-drawer-gestionar-autorizacion.png` | Drawer de resolución: justificación destacada, secciones con divisores, sin ids |
| `06-drawer-nuevo-turno-paso1.png` | Menú «Nuevo turno» desplegado en la pestaña Turnos de la denuncia |
| `07-nuevo-turno-consulta.png` | Paso 1 «Datos de turno» del wizard |
| `08-bloque-conflicto-1440.png` | Bloque de conflicto con **datos reales**: una sola salida y el copy contradictorio |
| `09-tres-opciones-radio-1440.png` | Las tres salidas como radios (con stub del endpoint) |
| `10-opcion-anular-observacion.png` | «Anular ese traslado»: motivo, observación autogenerada y botón «Anular el traslado» |
| `11-guardar-sin-traslado-autodestildado.png` | Tras elegir «Guardar el turno sin traslado»: checkbox destildado, sin obligatorios, «Siguiente» habilitado |
| `12-opcion-autorizar-los-dos.png` | «Autorizar los dos traslados» con «Motivos de traslado mismo día» |
| `13-resize-768-estado.png` | El wizard reseteado al paso 1 después de redimensionar |
| `14-bloque-conflicto-768.png` | Bloque de conflicto a 768 px: radios completos |
| `15-bloque-conflicto-390.png` | Bloque de conflicto a 390 px: radios completos, stepper cortado |
| `16-pie-botones-superpuestos-390.png` | «Atrás» y «Cancelar» pisados a 390 px |
| `17-ver-info-traslado-no-abre.png` | Reproducción del fallo con página recargada |
| `consola-errores.log` | Volcado de los errores de consola de la sesión |

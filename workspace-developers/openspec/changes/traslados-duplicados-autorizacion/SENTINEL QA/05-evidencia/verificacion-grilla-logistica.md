# Verificación de la grilla del sector Logística — `traslados-duplicados-autorizacion` (INI-2)

Cierre de los tres requisitos que habían quedado **sin verificar** por falta de un usuario del sector.

| Dato | Valor |
|---|---|
| Ambiente | **DEV** — `https://dev.sas.colonia-suiza.com.ar` |
| Usuario | `ayi.logistica` — persona **1000015**, perfil **18 `gestor_logistica`** (rótulo en pantalla: *Logistica Ayi Logistica / Gestor Logistica*) |
| Pantallas | `/home/traslado/pacientes` (grilla de logística) y `/home/editar/traslados` (traslados dentro de la denuncia) |
| Endpoint de la grilla | `POST /grv/logistica/traslados/listar` |
| Denuncia | **B464435** — paciente Ragnar Lothbrok, DNI 38401345 |
| Base | consultada en modo **sólo lectura** (`db_dev.py`) |
| Alcance | **sólo lectura**: navegación, filtros, hover y capturas. No se canceló, editó ni guardó nada |

---

## Resumen de veredictos

| # | Requisito | Veredicto |
|---|---|---|
| 1 | **RF-3.4** — el traslado aprobado llega a logística **marcado** (franja + ícono con tooltip + leyenda) | ✅ **CONFIRMADO** (las tres capas están) |
| 2 | **H-4** — el tooltip **no** dice quién autorizó | ✅ **CONFIRMADO** (el backend no manda el autorizante) |
| 3 | **R-21 / NP-10** — la marca compite con otras señales y se pierde | ⚠️ **Mecanismo CONFIRMADO** / escenarios (a) y (b) **NO REPRODUCIBLES POR DATOS**; la parte más grave de NP-10 queda **REFUTADA** en el build desplegado |

---

## 1. RF-3.4 — el traslado aprobado llega MARCADO → **CONFIRMADO**

El traslado **1469809** (2º traslado del día, autorización **aprobada**) **aparece en la grilla de logística** y **está marcado**. Se verificaron las tres capas por separado.

**Cómo se llegó:** login `ayi.logistica` → *Traslados: Pacientes* → Período fecha `01/08/2026`–`30/09/2026`, DNI `38401345` → *Aplicar filtros*. La grilla devuelve 3 filas (1469809, 1469807, 1469808).

### 1.a Franja de color propia — ✅ presente

Estilo computado sobre el `<tr>` de la fila 1469809:

```
border-left: 5px solid rgb(11, 143, 138)     →  #0B8F8A  (teal, color exclusivo de "duplicado autorizado")
```

Las otras dos filas de la misma denuncia (1469807, 1469808) tienen `border-left: 0px` — la franja es exclusiva de la fila marcada.

> Capturas: `capturas-logistica/LOG-02-franja-fila-1469809.png`, `LOG-03-tabla-3-filas.png`, `LOG-01-grilla-completa.png`

### 1.b Ícono con tooltip — ✅ presente

Primera celda de la fila 1469809 (HTML real en DEV):

```html
<span style="display: inline-flex; align-items: center; gap: 4px;">
  <div class=""><img src="/logistica/fd2adc42e8d01469c4a6.svg"
       alt="Segundo traslado del día autorizado"></div>
</span>
```

Texto **exacto** del tooltip al hacer hover (`.MuiTooltip-tooltip`):

> **`Segundo traslado del día autorizado`**

Es el texto **genérico**, sin autorizante (ver punto 2).

> Capturas: `LOG-04-tooltip-duplicado.png`, `LOG-04b-tooltip-pagina-completa.png`

### 1.c Entrada en la leyenda al pie — ✅ presente

Leyenda al pie de la grilla, tres entradas con su punto de color (colores computados):

| Punto | Color computado | Texto |
|---|---|---|
| ● | `rgb(242, 148, 35)` = `#F29423` | Requiere revisión |
| ● | `rgb(11, 143, 138)` = `#0B8F8A` | **Segundo traslado del día autorizado** |
| ● | `rgb(227, 72, 80)` = `#E34850` | Es espontáneo |

El color del punto de la leyenda coincide exactamente con el de la franja de la fila 1469809.

> Captura: `LOG-05-leyenda-pie.png`

**Conclusión RF-3.4:** las tres capas existen y son consistentes entre sí en color. El riesgo original —"logística ve dos traslados el mismo día y cancela uno"— **está mitigado** en cuanto a la existencia de la marca. Los problemas remanentes son de *legibilidad* de la marca (ver hallazgos LOG-01 y LOG-02).

---

## 2. H-4 — ¿el tooltip dice QUIÉN autorizó? → **CONFIRMADO (no lo dice)**

### Evidencia de front (tooltip)

Texto leído en pantalla: **`Segundo traslado del día autorizado`** — la cadena genérica, no la enriquecida.

### Evidencia de red (respuesta del endpoint que puebla la grilla)

`POST /grv/logistica/traslados/listar`, request y respuesta capturados:

```json
// request
{"fechaDesde":"2026-08-01","fechaHasta":"2026-09-30","dniPaciente":"38401345",
 "isTransportePublico":false,"soloRequierenRevision":false,"soloPrioritarios":false,
 "limit":10,"offset":0,"sortOrder":"desc","sortField":"fechaTraslado"}
```

```json
// respuesta — objeto del traslado 1469809 (recortado a lo pertinente)
{"nroTraslado":1469809,"idTurno":4560456,"nroDenuncia":"B464435",
 "estadoId":1,"estadoDescripcion":"Solicitado",
 "estadoLogisticaIdaId":1,"estadoLogisticaIdaDescripcion":"SOLICITADO",
 "requiereRevision":null,
 "esDuplicadoAutorizado":true,
 "nombreTramitador":"AyiOperador","apellidoTramitador":"Tramitador QA", ...}
```

Claves completas del objeto devuelto (53 campos) — **no existe ninguna** con el autorizante:

```
nroTraslado, idTurno, nroDenuncia, idDenuncia, dniPaciente, nombrePaciente, apellidoPaciente,
telefonoPaciente, celularPaciente, horaTraslado, fechaTraslado, cliente, isClienteAutoasegurado,
idTipoTrasladoIda, descripcionTipoTrasladoIda, idTipoTrasladoVuelta, descripcionTipoTrasladoVuelta,
codigoAgenciaIda, descripcionAgenciaIda, codigoAgenciaVuelta, descripcionAgenciaVuelta,
origenIda, destinoIda, origenVuelta, destinoVuelta, estadoId, estadoDescripcion, isEspontaneo,
tipoPrestacion, prestacion, localidadOrigenIda, localidadDestinoIda, localidadOrigenVuelta,
localidadDestinoVuelta, apellidoEmpleado, nombreEmpleado, dniEmpleado, isIdaVuelta,
isTransportePublico, estadoLogisticaIdaId, estadoLogisticaIdaDescripcion, estadoLogisticaVueltaId,
estadoLogisticaVueltaDescripcion, requiereRevision, esDuplicadoAutorizado, nombreTramitador,
apellidoTramitador, autorizacionAmbulancia, trasladoProvinciaOrigenIda, trasladoProvinciaDestinoIda,
trasladoProvinciaOrigenVuelta, trasladoProvinciaDestinoVuelta, idSatappIda, idSatappVuelta
```

Búsquedas sobre el cuerpo completo de la respuesta:

| Búsqueda | Resultado |
|---|---|
| `duplicadoAutorizadoPor` | **NO** |
| `autorizante` / `Autorizante` | **NO** |
| `esDuplicadoAutorizado` | **SÍ** (`true`) |

### Evidencia de que el front sí lo espera

El bundle desplegado (`/logistica/grv-logistica.js`) contiene 5 ocurrencias de `duplicadoAutorizadoPor` y la lógica del ternario del tooltip:

```js
e.esDuplicadoAutorizado && ActionTooltip({
  title: e.duplicadoAutorizadoPor
       ? c("traslados.duplicadoAutorizadoPor", { autorizante: e.duplicadoAutorizadoPor })
       : c("traslados.duplicadoAutorizado"),
  ...
})
```

Como `duplicadoAutorizadoPor` nunca llega, la rama nunca se toma. La cadena rica —
`"Segundo traslado del día, autorizado por {{autorizante}}. No cancelar por duplicado."` —
es **texto muerto** hoy.

### Quién autorizó realmente (dato en base, no visible para logística)

```
autorizaciones_traslado_duplicado, id 2 → id_traslado 1469809, estado 2 (Aprobado),
id_solicitante 1000007, id_autorizante 1000008, fecha_autorizacion 2026-08-14 09:29:28,
dictamen: "Aprobado: interconsulta justificada, paciente con inmovilizacion."
```

**Veredicto H-4: CONFIRMADO.** El tooltip cae siempre al genérico porque el backend no expone el autorizante en el listado de logística. Impacto: logística ve *que* está autorizado, pero no *quién* lo autorizó ni con qué dictamen — no puede escalar ni pedir cuentas sin salir del sistema.

---

## 3. R-21 / NP-10 — la marca compite con otras señales

### 3.a Disponibilidad de datos en DEV — **no hay con qué probar los dos escenarios**

Consulta sobre `cs.traslados` (1.469.173 filas):

```sql
SELECT COUNT(*) tot, SUM(requiere_revision=1) rev1,
       SUM(es_espontaneo_asociado=1) esp1, SUM(es_duplicado_autorizado=1) dup1
FROM traslados;
-- tot=1469173  rev1=17  esp1=34460  dup1=1
```

```sql
SELECT id_traslado, requiere_revision, es_espontaneo_asociado, es_duplicado_autorizado
FROM traslados WHERE es_duplicado_autorizado IS NOT NULL;
-- 1469809 | NULL | NULL | 1     ← la única fila del ambiente
```

`cs.traslados_transporte_publico` con `es_duplicado_autorizado IS NOT NULL`: **0 filas**.

> **En todo DEV existe exactamente UNA fila con `es_duplicado_autorizado = 1`, y no tiene ni `requiere_revision` ni `es_espontaneo_asociado`.** Por lo tanto:
>
> - Escenario **(a)** espontáneo + duplicado autorizado → **NO REPRODUCIBLE POR DATOS**
> - Escenario **(b)** `requiere_revision` + duplicado autorizado → **NO REPRODUCIBLE POR DATOS**
>
> No se reportan como refutados: simplemente no hubo con qué probarlos por la vía de la interfaz.

### 3.b El mecanismo de precedencias divergentes SÍ se reprodujo, con otro par de banderas

Existen en DEV filas con `es_espontaneo_asociado = 1` **y** `requiere_revision = 1`, que ejercitan **el mismo mecanismo** (dos señales compitiendo por una única franja). Se las observó en la grilla real:

Filtro: Período `25/10/2025`–`10/11/2025`, 100 filas por página (41 resultados).

| Traslado | Banderas en la respuesta | Franja computada | Ícono en la 1ª celda | Tooltip leído |
|---|---|---|---|---|
| **1469007** | `requiereRevision:true`, `isEspontaneo:false` | `5px rgb(242,148,35)` = **#F29423 naranja (revisión)** | 1 ícono | `Requiere revisión` |
| **1469005** | `requiereRevision:true`, **`isEspontaneo:true`** | `5px rgb(227,72,80)` = **#E34850 rojo (espontáneo)** | 1 ícono | `Requiere revisión` |
| **1468984** | `requiereRevision:true`, **`isEspontaneo:true`** | `5px rgb(227,72,80)` = **#E34850 rojo (espontáneo)** | 1 ícono | `Requiere revisión` |
| 1469017, 1469009, 1469010, 1469000-04, 1468971-99 (26 filas) | sólo `isEspontaneo:true` | `5px #E34850` rojo | **sin ícono** | — |

**Observación clave:** en 1469005 y 1468984 la franja dice *espontáneo* (rojo) y el ícono dice *Requiere revisión* (naranja). **La señal "requiere revisión" se pierde de la franja y sólo sobrevive en el ícono.** Es exactamente el patrón que R-21 describe: **la franja usa una cadena excluyente y el ícono no**.

> Capturas: `LOG-08-grilla-oct-nov-2025.png`, `LOG-09-fila-1468984-esp-mas-rev.png`, `LOG-10-fila-1469005-esp-mas-rev.png`, `LOG-11-fila-1469007-solo-rev.png`, `LOG-12/13/14-tooltip-*.png`

### 3.c Lectura del código desplegado en DEV — las dos cadenas, verbatim

Extraídas del bundle servido por DEV (`/logistica/grv-logistica.js`, offsets 8529356 y 8536478):

**Franja — cadena EXCLUYENTE (ternarios anidados):**

```js
setRowStyle: e => !isPersonalInterno && (
  e.isEspontaneo            ? { borderLeft: `5px solid ${v.tableColors.espontaneo}` }          // #E34850
  : e.requiereRevision      ? { borderLeft: `5px solid ${v.tableColors.requiereRevision}` }    // #F29423
  : e.esDuplicadoAutorizado ? { borderLeft: `5px solid ${v.tableColors.duplicadoAutorizado}` } // #0B8F8A
  : {}
)
```

**Ícono — lógica ADITIVA (los dos íconos pueden convivir en un `span` flex):**

```js
render: e => (e.requiereRevision || e.esDuplicadoAutorizado)
  ? <span style={{display:"inline-flex", alignItems:"center", gap:"4px"}}>
      { e.requiereRevision && <ActionTooltip title={c("traslados.requiereRevision")}>
                                <img src={Gw} alt={c("traslados.requiereRevision")}/></ActionTooltip> }
      { e.esDuplicadoAutorizado && <ActionTooltip title={ e.duplicadoAutorizadoPor
                                ? c("traslados.duplicadoAutorizadoPor",{autorizante:e.duplicadoAutorizadoPor})
                                : c("traslados.duplicadoAutorizado") }>
                                <img src={Hw} alt={c("traslados.duplicadoAutorizado")}/></ActionTooltip> }
    </span>
  : null
```

**Leyenda:**

```js
referencias: isPersonalInterno ? [] : [
  { text: c("traslados.requiereRevision"),   color: "#F29423" },
  { text: c("traslados.duplicadoAutorizado"), color: "#0B8F8A" },
  ...(isTransportePublico ? [] : [{ text: c("traslados.esEspontaneo"), color: "#E34850" }])
]
```

### 3.d Veredicto desglosado

| Afirmación de la documentación | Veredicto | Por qué |
|---|---|---|
| La **franja** y el **ícono** usan cadenas de precedencia **distintas** | ✅ **CONFIRMADO** | La franja es un ternario excluyente de 3 niveles; el ícono es aditivo (dos `&&` en un `span`), y `isEspontaneo` no participa del ícono. Reproducido en vivo con el par espontáneo+revisión (3.b) y leído en el bundle desplegado (3.c) |
| **(a)** espontáneo + duplicado autorizado → franja **roja** con **tooltip de duplicado**: se contradicen | ⚠️ **NO REPRODUCIBLE POR DATOS** — pero **el código desplegado lo sostiene**: `isEspontaneo` gana la franja y el ícono de duplicado se sigue renderizando con su tooltip. Se observó el patrón equivalente en 1469005/1468984 | |
| **(b)** `requiere_revision` + duplicado autorizado → la marca de duplicado **no aparece ni en la franja ni en el ícono** | ⚠️ **NO REPRODUCIBLE POR DATOS**, y la parte grave queda **REFUTADA en el build desplegado**: se pierde **sólo de la franja** (gana `requiereRevision`, naranja); el **ícono de duplicado sí se renderiza**, al lado del de revisión, con su propio tooltip | |

> **Nota importante sobre versiones.** La afirmación de NP-10 ("no aparece ni en la franja ni en el ícono") es correcta contra la versión de `TablaTraslados.tsx` de la rama `feature/marca-duplicado-autorizado` (commit `f865c52`), donde el ícono era un ternario excluyente `requiereRevision ? … : esDuplicadoAutorizado ? … : null` y el `alt` era literal `'icon'`. **Lo que está desplegado en DEV es una versión posterior**, con el ícono aditivo y el `alt` internacionalizado. La documentación quedó desactualizada respecto del ambiente. Sigue siendo cierto que la **franja** se pierde en los dos escenarios.

---

## Hallazgos nuevos

### LOG-01 — El ícono de «duplicado autorizado» usa el naranja de «requiere revisión», contradiciendo su propia franja y la leyenda — **Severidad: Media-Alta**

Los dos SVG de la primera columna están pintados con **el mismo color**:

```xml
<!-- fd2adc42e8d01469c4a6.svg → duplicado autorizado -->
<svg width="18" height="18" ...><path d="M10 10H8V4H10M8 12H10V14H8M12.73 0H5.27L0 5.27V12.73L5.27 18H12.73L18 12.73V5.27L12.73 0Z" fill="#F29423"/></svg>

<!-- 812b41049b72bb99b0b5.svg → requiere revisión -->
<svg width="24" height="24" ...><path d="M4 6H2V20C2 ..." fill="#F29423"/></svg>
```

Consecuencias:

1. La leyenda al pie **enseña al usuario que `#F29423` significa «Requiere revisión»**. La fila 1469809 muestra un glifo `#F29423` — el mismo naranja — sobre una franja `#0B8F8A`. Según la propia leyenda, el ícono está diciendo lo contrario que la franja.
2. El glifo elegido para «duplicado autorizado» es un **octógono de advertencia con signo de exclamación** — la iconografía del peligro. Para comunicar *una excepción concedida* es la afordancia equivocada: se lee como «hay un problema con este traslado», que es justo la interpretación que empuja a cancelarlo.
3. Los dos íconos son **indistinguibles de un vistazo** (mismo color, tamaños 18 vs 24, ambos glifos abstractos). Sin hacer hover, un gestor no puede saber cuál está viendo.

Recomendación: pintar el ícono de duplicado con `#0B8F8A` (el mismo teal de su franja y de su punto de leyenda) y cambiar el glifo por uno de *autorización/visto* en lugar de advertencia.

> Evidencia: `LOG-03-tabla-3-filas.png` (franja teal + ícono naranja en la misma fila), `LOG-05-leyenda-pie.png`

### LOG-02 — La franja pierde la marca de duplicado autorizado cuando la fila también es espontánea o requiere revisión — **Severidad: Media** (Alta si el volumen de espontáneos crece)

`setRowStyle` es un ternario excluyente: `isEspontaneo` > `requiereRevision` > `esDuplicadoAutorizado`. La marca de duplicado es **la última de la cola**, así que cualquiera de las otras dos la tapa. El ícono la conserva, pero es un objeto de 18 px sin color propio (ver LOG-01), no una franja de 5 px que se ve barriendo la grilla.

Escala del riesgo con los datos actuales de DEV: **34.460** traslados con `es_espontaneo_asociado = 1` frente a **1** con `es_duplicado_autorizado = 1`. Cuando la funcionalidad se use en volumen, la colisión espontáneo↔duplicado no será excepcional.

Recomendación: no resolver la señalización con una sola franja excluyente. Alternativas: franja segmentada / con dos colores, o un *chip* propio para el duplicado autorizado que no compita por el borde izquierdo.

> Evidencia: cadena verbatim en 3.c; patrón observado en vivo con espontáneo+revisión en `LOG-09-fila-1468984-esp-mas-rev.png` y `LOG-10-fila-1469005-esp-mas-rev.png`

### LOG-03 — Dentro de la denuncia, la marca aparece sin ícono ni tooltip: la franja teal queda sin explicación — **Severidad: Baja-Media**

La grilla de traslados dentro de la denuncia (`/home/editar/traslados`, pestaña *Traslados* de B464435) usa el mismo componente con `isDetalleSiniestro = true`, que **suprime la columna del ícono** pero **conserva la leyenda**. Resultado observado sobre el traslado 1469809:

```
franja: 5px rgb(11, 143, 138)   ← la franja teal SÍ está
primera celda: <p ...>#1469809</p>   ← no hay ícono, por lo tanto NO hay tooltip
leyenda al pie: "Requiere revisión / Segundo traslado del día autorizado / Es espontáneo"  ← SÍ está
```

El usuario tiene que mapear color→significado leyendo la leyenda del pie; no hay hover que le diga nada. Combinado con LOG-01 (el teal ni siquiera está representado en el ícono) es un camino de lectura frágil.

> Evidencia: `LOG-07-detalle-traslados.png`

### LOG-04 — El ícono de la marca es accesible; el resto de los íconos y todos los botones de acción de la grilla, no — **Severidad: Media** (accesibilidad)

Inventario de elementos gráficos del `<tbody>` en la grilla de logística:

| Elemento | Columna | `alt` | `title` | `aria-label` |
|---|---|---|---|---|
| `fd2adc42e8d01469c4a6.svg` (marca duplicado) | 0 | **`Segundo traslado del día autorizado`** ✅ | — | — |
| `812b41049b72bb99b0b5.svg` (marca revisión) | 0 | **`Requiere revisión`** ✅ | — | — |
| `badebd4f85501bd3071e.svg` (tipo de viaje) | 6 | `icon` ❌ | — | — |
| `720c4a98554566992443.svg` | 11 (Acciones) | `icon` ❌ | — | — |
| `e710be850c4bb850fb9c.svg` | 11 (Acciones) | `icon` ❌ | — | — |
| `<svg>` (menú kebab) | 11 (Acciones) | — | — | **ninguno** ❌ |
| **9 de 9** `<button>` del `tbody` | 11 (Acciones) | — | **ninguno** | **ninguno** ❌ |

Los dos íconos que introduce este change **sí** tienen nombre accesible (el `alt` sale de i18n, no es `'icon'`). El problema es el resto de la grilla: los botones de acción —incluida la acción **destructiva de cancelar traslado**— no tienen nombre accesible alguno. Un lector de pantalla anuncia «botón» tres veces por fila sin decir cuál cancela.

Recomendación: `aria-label` en los tres controles de la columna Acciones y `alt` significativo en el ícono de tipo de viaje. Es preexistente al change, pero la columna de acciones que va pegada a la marca es donde el riesgo de cancelación accidental se materializa.

---

## Verificaciones adicionales solicitadas

### El traslado 1469810 (rechazado) — **NO aparece en la grilla** ✅ correcto

`id_estado_logistica_ida = NULL` en base. Filtrando por DNI 38401345 en el rango `01/08/2026`–`30/09/2026` (que **incluye** su fecha, 02/09/2026), la respuesta del endpoint devuelve `cantidadTotal: 3` con los traslados 1469809, 1469807 y 1469808. **1469810 está ausente.** Tampoco figura en la grilla de la denuncia (3 de 3 filas). El circuito de rechazo no filtra nada al sector: correcto.

### El traslado 1469808 (cancelado con estado de logística 6) — **SÍ aparece** ⚠️ coherente con la anomalía ya detectada

Lo que ve el sector, textual:

```
#1469808 | B464435 | 38401345 Ragnar Lothbrok | 11:15 25/08/2026 | PROVINCIA ART
De: CAPDEVILA JOSE ALBERTO 3051 (CABA) → A: CALLE 3 1524 (LA PLATA)
ESTADO IDA: CANCELADO   |   Tipo turno: Consulta   |   sin franja, sin ícono
```

Respuesta del endpoint: `estadoId:4 "Cancelado"`, `estadoLogisticaIdaId:6 "CANCELADO"`, `requiereRevision:null`, `esDuplicadoAutorizado:null`.

Es decir: la fila **es visible pero inerte** — chip rojo CANCELADO, sin marca de ninguna clase. Su hermano 1469807 (mismo día 25/08, también cancelado, `estadoLogisticaIdaId:6`) se ve idéntico. El sector no puede distinguir «cancelado porque la autorización quedó pendiente» de «cancelado por cualquier otro motivo»: no hay ninguna señal del circuito de duplicados en la fila. Consistente con la anomalía ya documentada (traslado con autorización pendiente que terminó cancelado *y* con estado de logística asignado), y agrava su lectura: quedó un registro visible en logística sin trazabilidad del motivo.

---

## Qué no se pudo ver, y por qué

1. **Escenario (a) — fila espontánea + duplicado autorizado.** No existe la fila en DEV. Para probarlo hace falta un traslado con `es_duplicado_autorizado = 1` **y** `es_espontaneo_asociado = 1`, con `id_estado_logistica_ida` no nulo. No hay forma de construirlo desde la interfaz (el circuito de autorización de duplicados no se dispara sobre traslados espontáneos por la vía del wizard de turnos) y el conector de base es de sólo lectura.
2. **Escenario (b) — fila con `requiere_revision` + duplicado autorizado.** Ídem: hace falta un traslado con `es_duplicado_autorizado = 1` **y** `requiere_revision = 1`. `requiere_revision` se enciende desde los drawers de verificación/asignación de agencia, que **son acciones de escritura** y quedaban fuera del alcance de esta verificación (además de que operarlas sobre 1469809 alteraría el único dato de prueba del ambiente).
   > **Dato a construir para cerrar el punto 3 en una próxima corrida:** dos traslados adicionales de un 2º turno del mismo día con autorización aprobada — uno marcado como espontáneo y otro con `requiere_revision = 1` — con estado de logística asignado. Con esos dos registros los escenarios (a) y (b) se verifican por interfaz en minutos.
3. **Autorizante en el tooltip.** No se pudo ver porque el backend no lo manda (eso *es* el hallazgo H-4). No hay configuración ni permiso que lo habilite: falta el campo en el SP y en el DTO del listado de logística.
4. **Marca en el tab «Transporte público».** El traslado 1469809 es Remis, y `traslados_transporte_publico` no tiene ninguna fila con `es_duplicado_autorizado` no nulo. Sin datos para verificar ese camino.
5. **Exportación a Excel.** No se verificó si la marca de duplicado autorizado viaja al archivo exportado: la acción dispara una descarga y se dejó fuera del alcance de sólo-lectura. Queda pendiente.
6. **Acciones de la fila marcada (cancelar / asignar agencia).** No se abrieron ni se operaron, por la regla de no escritura. Queda sin verificar si el sistema **impide o advierte** al intentar cancelar un traslado marcado como duplicado autorizado — que es, funcionalmente, la defensa que la marca pretende reemplazar.
7. **Nota de infraestructura (no es defecto funcional).** El bundle de DEV (14,09 MB, `grv-logistica.js`) se sirve sin compresión efectiva y la página de login se estanca de forma intermitente: hubo que implementar reintentos de login (1 de cada ~4 intentos falló con la pantalla sin `input[type=password]` a los 60 s). No se reporta como defecto del producto.

---

## Anexo — reproducción

```bash
# Grilla de logística, caso principal
# login ayi.logistica / <password unificada de QA>  →  /home/traslado/pacientes
# Período fecha: 01/08/2026 – 30/09/2026 ; DNI del paciente: 38401345 ; Aplicar filtros
#   → fila #1469809 con franja teal + ícono + tooltip "Segundo traslado del día autorizado"

# Mecanismo de precedencias (proxy espontáneo ↔ requiere revisión)
# Período fecha: 25/10/2025 – 10/11/2025 ; 100 filas por página
#   → #1468984 y #1469005: franja ROJA (espontáneo) + ícono "Requiere revisión"
#   → #1469007: franja NARANJA (revisión) + ícono "Requiere revisión"

# Datos, sólo lectura
python db_dev.py "SELECT id_traslado, requiere_revision, es_espontaneo_asociado, es_duplicado_autorizado FROM traslados WHERE es_duplicado_autorizado IS NOT NULL"
python db_dev.py "SELECT COUNT(*) tot, SUM(requiere_revision=1) rev1, SUM(es_espontaneo_asociado=1) esp1, SUM(es_duplicado_autorizado=1) dup1 FROM traslados"
python db_dev.py "SELECT * FROM autorizaciones_traslado_duplicado"
```

Capturas en `capturas-logistica/`:

| Archivo | Qué muestra |
|---|---|
| `LOG-00-home-gestor-logistica.png` | Home del perfil Gestor Logistica |
| `LOG-01-grilla-completa.png` | Grilla filtrada, 3 filas de B464435 |
| `LOG-02-franja-fila-1469809.png` | Franja teal de la fila marcada |
| `LOG-03-tabla-3-filas.png` | Franja teal + ícono naranja vs. filas sin marca (evidencia LOG-01) |
| `LOG-04-tooltip-duplicado.png` / `LOG-04b-...` | Tooltip «Segundo traslado del día autorizado» |
| `LOG-05-leyenda-pie.png` | Leyenda al pie con las tres entradas y sus colores |
| `LOG-06-detalle-denuncia.png` / `LOG-07-detalle-traslados.png` | La marca dentro de la denuncia, sin ícono (LOG-03) |
| `LOG-08-grilla-oct-nov-2025.png` | Grilla con 41 filas, espontáneos y revisión |
| `LOG-09/10/11-fila-*.png` | Filas 1468984, 1469005 (esp+rev) y 1469007 (sólo rev) |
| `LOG-12/13/14-tooltip-*.png` | Tooltips «Requiere revisión» sobre franja roja |

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026*

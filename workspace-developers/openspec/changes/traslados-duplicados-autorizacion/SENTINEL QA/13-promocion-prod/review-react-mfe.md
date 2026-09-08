# Code Review — React MFE · Promoción a producción INI-2

**Change:** INI-2 — autorización de traslados duplicados del mismo día
**Sistema:** SAS · Aseguradora Colonia Suiza
**Rama revisada:** `promo/INI-2-prod` (ambos repos)
**Skill:** `react-mfe-review`
**Fecha:** 21/08/2026

| Repo | Stack | Diff vs `origin/master` |
|---|---|---|
| `tramitadores` | React + JS (JSX, PropTypes, RTK Query, MUI v5 Grid v2, `sas-component-lib`) | 31 archivos, +2238 / −163 |
| `logistica` | React + TypeScript (RTK Query, MUI) | 4 archivos, +42 / −7 |

---

## Veredicto

```
============================================================
CODE REVIEW — React MFE · tramitadores + logistica · JS / TS
============================================================
RESUMEN   🔴 2 bloqueantes · 🟠 2 alta · 🟡 7 media · 🔵 6 baja

RECOMENDACIÓN:  NO GO
```

**No promover.** Hay dos defectos que no dependen de datos ni de configuración: uno impide que `tramitadores` compile, el otro tira una excepción al abrir una de las dos pestañas nuevas. Los dos son del tipo que el parseo con `@babel/parser` no puede detectar, porque no son errores de sintaxis sino de resolución de módulos. Ambos tienen fix de una línea.

El resto del corte quirúrgico está sorprendentemente sano: la revisión de referencias huérfanas encontró exactamente esos dos casos y nada más, y el circuito de i18n está limpio.

---

## 🔴 BLOQUEANTES

### B-1 · `exigeMotivoTrasladoMismoDia` no existe: `tramitadores` no compila

**¿Bloquea la promoción? SÍ. Es un fallo de build, no un riesgo.**

Tres archivos importan el módulo como default export y lo invocan:

| Archivo | Import | Uso |
|---|---|---|
| `.../Drawers/DrawerNuevoTurno/hooks/useTurnosSave.js` | :43 | :1015 |
| `.../Drawers/DrawerProgramarTurno/index.jsx` | :48 | :81 |
| `.../DrawerGenerarAutorizacion/components/StepTraslado.js` | :26 | :127 |

```js
import exigeMotivoTrasladoMismoDia from '../../components/BloqueConflictoTraslado/exigeMotivoTrasladoMismoDia';
```

El archivo **no está en el working tree, no está en `origin/master`, y el diff de la promoción no lo agrega**. El directorio contiene sólo tres archivos:

```
BloqueConflictoTraslado/
├── BloqueConflictoTraslado.jsx
├── useAnularConflicto.js
└── useConflictoTraslado.js
```

Verificación:

```bash
$ git ls-tree -r origin/master --name-only | grep -i exigeMotivo   # sin resultados
$ find . -iname "*exigeMotivo*"                                    # sin resultados
$ grep -n exigeMotivo /tmp/ini2-tram.diff   # las 3 líneas de import son «+», el módulo no aparece
```

**Causa raíz.** El módulo existe en `release`, en el commit `00af4050` *«fix(turnos): el motivo declarado se exige solo cuando es una autorizacion propia»*. Ese commit toca **7 archivos** y la promoción trajo **6**: se trajeron todos los consumidores y se dejó el módulo.

```
00af4050  (7 archivos)
  ✔ DrawerNuevoTurno/components/StepTraslado.jsx
  ✔ DrawerNuevoTurno/hooks/useTurnosSave.js
  ✔ DrawerProgramarTurno/index.jsx
  ✔ DrawerEditarTurno/index.jsx
  ✔ DrawerGenerarAutorizacion/components/StepTraslado.js
  ✘ TurnosRehabilitacion/.../hooks/useEditarTurnoRehabilitacion.js   ← no promovido
  ✘ BloqueConflictoTraslado/exigeMotivoTrasladoMismoDia.js           ← EL MÓDULO
```

Webpack va a cortar con `Module not found: Can't resolve './exigeMotivoTrasladoMismoDia'`. Es el motivo por el cual «los 25 archivos parsean con `@babel/parser`» no daba ninguna garantía: el parser valida sintaxis de un archivo aislado, no resuelve imports.

**Fix:** traer `exigeMotivoTrasladoMismoDia.js` del commit `00af4050`. Son 34 líneas y su única dependencia es `SALIDA_CONFLICTO_TRASLADO`, que ya está en `Utils/const.js` en esta rama.

**Consecuencia secundaria, decidir aparte:** el 4.º call site (`useEditarTurnoRehabilitacion.js`) tampoco se promovió. Si sólo se agrega el módulo, el flujo de **editar turno de rehabilitación** sigue exigiendo el motivo declarado siempre que haya traslado el mismo día — que es exactamente la desviación que INI-2 vino a eliminar (declarar en falso una autorización inexistente). Conviene confirmar si esa exclusión es deliberada o es el mismo olvido.

---

### B-2 · `ESTADO_DUPLICADO_RESUELTO_STYLE` se importa del módulo equivocado → la pestaña de resueltos se cae

**¿Bloquea la promoción? SÍ.** `TypeError` en runtime al renderizar la pestaña «Autorización Doble Traslado Resuelta».

`Utils/utils.js` agrega **dos** símbolos al import de `'./const'`:

```js
import {
    ...
    ESTADO_AUTORIZACION,
    ESTADO_DUPLICADO_RESUELTO,          // ✔ vive en const.js:917
    ESTADO_DUPLICADO_RESUELTO_STYLE,    // ✘ vive en styles.js:71
    ESTADO_PROCESAMIENTO,
    ...
} from './const';
```

Pero el diff lo definió en `Utils/styles.js`, no en `Utils/const.js`:

```
Utils/const.js:917    export const ESTADO_DUPLICADO_RESUELTO = { APROBADA: 2, RECHAZADA: 3 };
Utils/styles.js:71    export const ESTADO_DUPLICADO_RESUELTO_STYLE = { APROBADA: {...}, RECHAZADA: {...} };
```

`utils.js` ya tiene un segundo import desde `'./styles'` (líneas 50-55, con `ESTADO_ADELANTO_REINTEGRO_STYLE` y `ESTADO_HOTELERIA_STYLE`) — ahí es donde debía ir.

**Efecto en runtime.** Con la interop CommonJS de Babel, un named import inexistente no falla en el import: resuelve a `undefined` (webpack sólo emite un warning `export 'X' was not found`). El error aparece al usarlo:

```js
// Utils/utils.js:245
static getFilaResultadoDuplicado(estadoDuplicado, t) {
    if (estadoDuplicado === ESTADO_DUPLICADO_RESUELTO.APROBADA) {
        return { ... textColor: ESTADO_DUPLICADO_RESUELTO_STYLE.APROBADA.LC, ... };
        //                     └── undefined.APROBADA  →  TypeError
```

Llamado desde `components/Turnos/TablaTurnos.js:532`, en el `render` de la columna «Resultado»:

```js
const chipProps = Utils.getFilaResultadoDuplicado(row?.estadoDuplicado, t);
```

`Cannot read properties of undefined (reading 'APROBADA')`. Se dispara en la primera fila cuyo `estadoDuplicado` sea 2 o 3 — es decir, en **toda** fila de esa pestaña, porque el SP filtra los pendientes. La pestaña completa queda inutilizable: es la mitad «vuelta al gestor» del circuito.

**Fix:** mover `ESTADO_DUPLICADO_RESUELTO_STYLE` al import de `'./styles'` en `utils.js`.

---

## 🟠 ALTA

### A-1 · La salida «Guardar el turno sin traslado» sólo existe en 1 de los 4 drawers, y su ausencia deja un callejón sin salida

**¿Bloquea la promoción? SÍ, si el backend puede devolver la combinación descrita.** Requiere confirmar el contrato antes de promover.

En `BloqueConflictoTraslado.jsx`, la opción se agrega sólo si además de estar habilitada por el backend llega el callback:

```js
if (salidas?.puedeGuardarSinTraslado && onGuardarSinTraslado) {
    opciones.push({ valor: SALIDA_CONFLICTO_TRASLADO.SIN_TRASLADO, ... });
}
```

De los cuatro puntos de entrada, **sólo uno pasa `onGuardarSinTraslado`**:

| Punto de entrada | `onGuardarSinTraslado` | `idAutorizacion` | `idSolicitante` |
|---|---|---|---|
| `DrawerNuevoTurno/components/StepTraslado.jsx` | ✔ :171 | ✔ :166 | ✔ :165 |
| `DrawerProgramarTurno/index.jsx` | ✘ | ✔ :290 | ✘ |
| `DrawerEditarTurno/index.jsx` (rehab) | ✘ | ✔ :172 | ✘ |
| `DrawerGenerarAutorizacion/components/StepTraslado.js` | ✘ | ✘ | ✘ |

**El deadlock.** Si el backend responde `puedeAnular: false` (p. ej. un tramo ya facturable), `requiereAutorizacion: false` y `puedeGuardarSinTraslado: true`, en los tres drawers sin el callback pasa esto:

1. `opciones` queda vacío.
2. El `RadioGroup` no se renderiza — está detrás de `!resultadoPedido && opciones.length > 0`.
3. `salidaElegida` nunca sale de `null`, y `onChangeSalida` nunca se llama.
4. `exigeMotivoTrasladoMismoDia` entra por `if (!salidaConflicto) return true` → **se exige el motivo declarado**.
5. El único select de motivo vive **dentro** del `formularioAutorizacion`, que sólo se monta si la opción `AUTORIZACION` existe y está elegida — y no existe.

Resultado: el bloque se muestra con el cartel de conflicto, sin ninguna opción, y el botón de guardar/siguiente deshabilitado para siempre. Hay que cancelar el wizard y perder lo cargado. Es el mismo callejón sin salida que el propio código documenta haber arreglado para el caso del alta (comentario extenso en `esAlta`), reaparecido por otra vía.

**Fix:** pasar `onGuardarSinTraslado` en los tres drawers restantes (en `DrawerGenerarAutorizacion` y `DrawerEditarTurno` hay un checkbox de traslado que se puede destildar; en `DrawerProgramarTurno` hay que definir el equivalente). Como red de seguridad, conviene además que el bloque nunca pueda quedar con `opciones.length === 0` sin decir nada.

---

### A-2 · El pedido de autorización se envía sin `idSolicitante` justamente en los dos flujos donde el botón existe

**¿Bloquea la promoción? SÍ, salvo que el backend derive el solicitante del token.** Verificar en `wsturnos` antes de promover.

`manejarPedido` manda cuatro campos:

```js
const respuesta = await pedirAutorizacion({
    idAutorizacion, idTraslado: aAutorizar?.idTraslado, justificacion, idSolicitante
}).unwrap();
```

El botón que lo dispara sólo se renderiza cuando **no** es un alta:

```js
const esAlta = !idAutorizacion;
// ...
{esAlta ? <caption/> : <CustomButton onClick={manejarPedido} .../>}
```

Cruzando con la tabla de A-1, la asimetría es exacta y da vuelta el resultado esperado:

- `DrawerNuevoTurno/StepTraslado` **sí** pasa `idSolicitante`, pero en un alta `idAutorizacion` viene `undefined` → `esAlta === true` → el botón no se renderiza y `manejarPedido` nunca corre. (En modo edición, con `shiftById.idAutorizacion` presente, sí funciona bien.)
- `DrawerProgramarTurno` y `DrawerEditarTurno` **sí** pasan `idAutorizacion` → `esAlta === false` → el botón se renderiza → y **no** pasan `idSolicitante` → se envía `undefined`.

Es decir: el campo se pasa donde no se usa y falta donde se usa.

**Efecto en cascada,** si el backend no lo suple:

- `autorizaciones_traslado_duplicado.id_solicitante` queda nulo.
- En la grilla de pendientes, la columna «Lo pidió» (`row?.solicitanteDuplicado`) sale en guion, y en `DrawerResolverDuplicado` el campo «Solicitante» también. Quien autoriza no sabe quién pidió.
- Peor: `GET autorizaciones/mis-duplicados-resueltos?idSolicitante={id}` filtra por ese id. Esos pedidos **nunca** aparecen en la pestaña de resueltos ni encienden la card del home. El gestor no se entera nunca del dictamen — que es la mitad del valor del change.

**Fix:** pasar `idSolicitante={usuarioActivo?.id}` en los dos drawers. Nota: los dos ya importan `useSelector` (ver M-4, donde ese import está muerto), así que el cableado es trivial.

---

## 🟡 MEDIA

### M-1 · `useAnularConflicto`: loop infinito de requests si el catálogo de motivos vuelve vacío

**¿Bloquea? No.** Pero es una bomba de tiempo, y el disparador no es improbable.

```js
useEffect(() => {
    if (habilitado && !motivosAnulacion?.length) {
        dispatch(searchMotivosAnulacionTraslado(notificarError));
    }
}, [habilitado, motivosAnulacion, dispatch, notificarError]);
```

El reducer asigna la respuesta cruda (`redux/reducers/listados.js:235` → `motivosAnulacionTraslado: action.payload`). Si el endpoint devuelve un array **vacío** —catálogo sin cargar en ese ambiente, o filtrado por permisos— la identidad del array cambia en cada respuesta pero `length` sigue en 0: el effect vuelve a correr, vuelve a despachar, y así indefinidamente. Un GET en loop mientras el drawer esté abierto.

Con respuesta no vacía converge bien, y con error de red tampoco loopea (el reducer no toca la clave, la referencia no cambia). El fix habitual es un `useRef` de «ya lo pedí» o un flag de `loading` en el slice.

### M-2 · `observacionSugerida`: dependencia faltante (`conflictos`)

**¿Bloquea? No** en runtime — **sí puede bloquear el build** si el pipeline corre `react-hooks/exhaustive-deps` como error.

```js
const observacionSugerida = useMemo(() => {
    const aCancelar = conflictos?.length ? conflictos : [conflicto];   // ← usa conflictos
    ...
}, [usuarioActivo, conflicto, t]);                                     // ← no está en deps
```

La observación pre-armada es la que **queda asentada en la base** como constancia de la anulación, y con varios traslados el mismo día el texto los nombra a todos. Si `conflictos` cambia sin que cambie `conflictos[0]`, el texto guardado describe un conjunto que ya no es el que se canceló. En la práctica RTK Query devuelve objetos nuevos en cada fetch, así que el memo casi siempre se recalcula — el riesgo real es bajo, pero la violación de la regla es genuina y el dato es de auditoría.

### M-3 · `addShift` no invalida `duplicadosPendientes`: el contador del autorizante queda viejo

**¿Bloquea? No.**

INI-2 hace que `turnos/crear` registre el pedido de excepción en la misma transacción que el alta (campos `justificacionTrasladoDuplicado` + `idSolicitanteTrasladoDuplicado`). Pero el endpoint invalida un tag que no existe:

```js
tagTypes: ['shiftById', 'duplicadosPendientes', 'misDuplicadosResueltos'],
...
addShift:  invalidatesTags: ['homeReferenteSiniestro'],   // no declarado → RTK lo descarta
editShift: invalidatesTags: ['shiftById', 'homeContadores'],  // 'homeContadores' idem
```

Ambos tags huérfanos son **pre-existentes en `origin/master`** (verificado con `git show origin/master:.../turnosApi.js`), así que no los introduce INI-2 — pero INI-2 crea la dependencia. Efecto: tras un alta que genera un pedido, la card «Autorización Doble Traslado Pendiente» del autorizante no se actualiza hasta que se remonte o se recargue. Ruido menor; se arregla agregando `'duplicadosPendientes'` a `invalidatesTags` de `addShift` (y declarando los dos tags faltantes, o borrándolos).

**Sobre la invalidación cruzada `turnosApi` ↔ `logisticaApi`: confirmado que NO llega a producción como bug.** `logisticaApi` no declara `tagTypes` y `getConflictosMismoDia` no tiene `providesTags`, así que nadie intenta invalidarla por tags. El refresco del bloque se hace con un `refetch()` explícito (`refrescarConflictos`), y sólo cuando la anulación fue efectiva. Es la solución correcta para dos `createApi` separados. Los tags nuevos de INI-2 (`duplicadosPendientes`, `misDuplicadosResueltos`) sí están declarados y sus invalidaciones son intra-api.

### M-4 · Cuatro imports muertos en los dos archivos con `NOTA DE LA PROMOCIÓN`

**¿Bloquea? Depende del pipeline.** Con `no-unused-vars` en error —lo habitual— **el lint falla y el build no pasa**. Como en el worktree no hay `node_modules`, esto no se detectó localmente.

| Archivo | Línea | Símbolo |
|---|---|---|
| `DrawerProgramarTurno/index.jsx` | 34 | `dayjs` |
| `DrawerProgramarTurno/index.jsx` | 38 | `useSelector` (en `import { useDispatch, useSelector }`) |
| `DrawerEditarTurno/index.jsx` | 17 | `dayjs` |
| `DrawerEditarTurno/index.jsx` | 18 | `useSelector` |

Los cuatro los **agregó** la promoción, y lo único que los usaba era el código de SE-268 (`admiteTurnosFuturos`, `fechaLimiteTurno`, `leyendaLimiteTurno`) que la nota dice haber quitado. Cada uno tiene exactamente una aparición en su archivo: la del import.

**Lo demás de las dos notas quedó coherente**, verificado uno por uno:
- `CustomSelect` sí se sacó del import de `sas-component-lib` en `DrawerEditarTurno` (0 apariciones restantes). ✔
- `InputVariant` y `SIMBOLOS` siguen usados en ambos archivos por otros campos: correcto no tocarlos. ✔
- No quedan referencias vivas a `admiteTurnosFuturos`, `fechaLimiteTurno`, `leyendaLimiteTurno`, `fechaLimiteCargaTurnos` ni `leyendaLimiteCargaTurnos` — sólo las menciones dentro del texto de las notas. ✔
- No hay JSX roto ni variables declaradas sin uso más allá de los cuatro imports. ✔

### M-5 · Las notas de promoción son dos, no tres — y falta la del tercer recorte

**¿Bloquea? No.** Riesgo de deuda silenciosa.

`grep -rniE "NOTA DE LA PROMOCI|PROMOCI[OÓ]N A PRODUCCI"` devuelve **dos** resultados: `DrawerProgramarTurno/index.jsx:63` y `DrawerEditarTurno/index.jsx:71`.

El tercer sitio donde se recortó SE-268 es `components/DenunciaCompleta/Turnos/index.jsx`, y **no tiene nota**. Ahí se quitó:

```diff
-import Utils from '../../../Utils/utils';
-const denunciaAdmiteTurnos = Utils.denunciaAdmiteTurnosFuturos(denuncia);
...
-    disabled: !denunciaAdmiteTurnos,
```

El recorte está **limpio** (el identificador `Utils` ya no se usa en el archivo — la única coincidencia restante es la ruta `'../../../Utils/const'`, y `Utils.denunciaAdmiteTurnosFuturos` sigue existiendo en `utils.js` para su otro consumidor, `StepDatosTurno.jsx`). Pero sin la nota, nadie va a saber que ese `disabled` del botón «Generar autorización» tiene que volver cuando se promueva SE-268: el botón queda habilitado siempre, en silencio.

### M-6 · `esDuplicadoAutorizado` declarado como `boolean` no opcional (logistica)

**¿Bloquea? No, pero hay que verificar el contrato.**

```ts
requiereRevision: boolean,
+ esDuplicadoAutorizado: boolean,
+ duplicadoAutorizadoPor: string | null,
```

El propio type tiene, dos líneas arriba, un `//Agregar a la response:` sobre `requiereRevision` — señal de que estos campos dependen de trabajo de backend. Si el endpoint de producción todavía no los devuelve, el valor es `undefined`, falsy, y **la marca simplemente no aparece nunca**, sin ningún error visible. Declararlo no-opcional hace que TypeScript no pueda avisar de la diferencia.

Punto a favor: no hay ningún object literal anotado con `PedidoTrasladoType` en el repo (todas las apariciones son tipos de parámetro o de estado sobre respuestas de API), así que agregar dos campos requeridos **no rompe la compilación**. Verificado sobre las 44 referencias al type.

### M-7 · `MOTIVO_ANULACION_TRASLADO_DUPLICADO = 16` es un id de base hardcodeado, y la documentación se contradice

**¿Bloquea? No, pero hay que verificarlo contra la base de producción antes de promover.**

Dos descripciones del mismo id, en el mismo change, que no coinciden:

- `Utils/const.js`: *«Motivo de anulación que corresponde al traslado duplicado del mismo día (tabla `motivos_anulacion`, id_tipo = 2 → traslado)»*.
- `BloqueConflictoTraslado.jsx`, comentario del `formularioAnular`: *«El motivo viene pre-elegido en «Cancelado por alarma repetida»»*.

El propio comentario de `const.js` explica por qué importa: *«si el motivo queda mal cargado, la anulación no se puede distinguir después de una cancelación por cualquier otra causa»*. Si en la base de producción el id 16 no es el motivo correcto, todas las anulaciones por duplicado quedan mal clasificadas de forma indetectable — y es un dato que después nadie puede reconstruir. Confirmar el id contra `motivos_anulacion` en producción.

---

## 🔵 BAJA

Ninguno bloquea la promoción.

- **BJ-1 · Clave i18n muerta.** `turnos.conflictoTraslado.confirmarSinTraslado` (es: «Guardar sin traslado» / en: «Save without transfer») la agrega este diff y no tiene ninguna referencia en el código, ni literal ni dinámica. Causa: la salida `SIN_TRASLADO` se pushea con `contenido: null`, así que nunca hubo botón de confirmar que la use. Sus hermanas sí se usan (`confirmarAnulacion`, `enviarPedido`).
- **BJ-2 · Código muerto en `useConflictoTraslado`.** Devuelve `puedeDerivarALogistica` y `huboError`; ninguno se consume en ningún lado. `puedeDerivarALogistica` sugiere una cuarta salida que no se implementó — conviene decidir si va o se borra, porque un campo calculado y nunca leído se lee como olvido.
- **BJ-3 · Magic string donde hay constante.** `BloqueConflictoTraslado.jsx` compara `resultadoPedido?.resultado === 'APROBADA'` con literal, teniendo `RESULTADO_TRASLADO_DUPLICADO.APROBADA` en `Utils/const.js` (que `DrawerResolverDuplicado` sí usa, correctamente, en sus dos `switch`).
- **BJ-4 · PropTypes incompletos.** `BloqueConflictoTraslado` usa `onChangeJustificacion` pero no lo declara. `DrawerResolverDuplicado.pedido` no declara `idTipoTurno`, `estadoDuplicado`, `dictamenDuplicado`, `autorizanteDuplicado` ni `fechaAutorizacionDuplicado`, todos leídos por el drawer o por las columnas de la grilla. En un MFE sin TS los PropTypes son la única documentación del contrato.
- **BJ-5 · `usuarioActivo.id` sin optional chaining.** `Turnos.js:140` (inicializador de `useState`) y `:369`. Sigue la convención pre-existente —`master` ya lo hace en las líneas 101 y 263— así que no es una regresión nueva. Aun así, en un deep-link con `location.state.misDuplicadosResueltos` que se resuelva antes de que Redux rehidrate, el inicializador tira `TypeError` y se cae la página entera. El mismo archivo usa `usuarioActivo?.id` en el effect de `marcarDuplicadosVistos`, así que la inconsistencia está dentro del propio diff.
- **BJ-6 · Colores hardcodeados** en lugar de los tokens de `Utils/styles.js`: `#ed6c02`, `#fffcf7`, `#1976d2`, `#e0e0e0`, `#f3f8fd` (`BloqueConflictoTraslado`), `#f5f7f9`, `#d7373f`, `#4caf50` (`DrawerResolverDuplicado`), `#0B8F8A` (logistica). Detalle relacionado con lo ya reportado: en `TablaTraslados.tsx` la referencia de la leyenda de «duplicado autorizado» usa `#0B8F8A` (teal) mientras el ícono que efectivamente se renderiza es `InfoIcon` (naranja) — la leyenda y la marca no coinciden en color.

---

## Verificado sin hallazgos

Vale registrar dónde **no** hay problema, porque acota el riesgo de la promoción.

**Referencias huérfanas — barrido sistemático.** Se resolvieron con script todos los named imports de rutas relativas de los 25 archivos `.js`/`.jsx` del diff contra los exports reales de cada módulo destino. Después de descartar falsos positivos (hooks generados por `createApi` y exports por destructuring), quedaron exactamente los dos casos de B-1 y B-2. Además, verificados a mano:

- `RESPONSE_STATUS.CONFLICT` — existe (`const.js:1248`), y `RESPONSE_STATUS` ya estaba importado en `useTurnosSave.js:26`. ✔
- `SIMBOLOS.TRES_PUNTOS` (`const.js:660`), `SIMBOLOS.ESPACIO`, `SIMBOLOS.VACIO`. ✔
- Las 5 claves de `PERMISOS` usadas (`AUTORIZAR_TRASLADO_MISMO_DIA` + las 4 de grillas) existen en `permissionsConfig.js`. ✔
- `hasAnyPermission` es variádico (`(...perms) => perms.some(...)`), así que las llamadas con argumentos sueltos son correctas. ✔
- `resetTurnosTablaDetalle` se importa directo de `redux/actions/turnos` — correcto, el barrel no lo re-exporta (el comentario del código acierta). `actions.fetchTurnosTablaDetalle` **sí** está en el barrel (`index.js:120`), igual que `searchTiposTurno`, `searchMotivosAnulacionTraslado`, `fetchCancelarTraslado` y `setSnackbar`. ✔
- Selectores: `state.turnos.turnosTabla` (`reducers/turnos.js:20`), `state.listados.tiposTurno` (`reducers/listados.js:89`), `state.listados.motivosAnulacionTraslado` (`:88`) — los tres existen. El comentario de `DrawerResolverDuplicado` sobre haber corregido el slice equivocado se sostiene. ✔
- Métodos de `Utils` usados: `formatoFechaYHoradesdeBase`, `getString`, `convertirFechaYHoraABaseISO`, `getFilaResultadoDuplicado`. ✔
- Assets: `commons/assets/Indicadores/notebook-edit-outline.svg` y `folder-open.svg` (`IconFolderOpen` ya estaba importado en `CardsTurnosCirugiasInternados.jsx:10`) en tramitadores; `assets/varios/requiere-revision-icon.svg` en logistica. ✔

**i18n — limpio.** 201 claves literales referenciadas desde los 25 archivos del diff resuelven en `es` **y** en `en`; un segundo barrido más amplio (310 candidatas, incluidas las pasadas indirectamente y los 5 `t()` multilínea) tampoco encontró faltantes. Las 63 claves nuevas tienen paridad exacta es/en y los placeholders de interpolación coinciden entre idiomas (`cantidad`, `estado`, `agencia`, `usuario`, `fecha`, `turno`, `autorizante`). Las dos claves construidas dinámicamente enumeran completo: `` t(`generales.buttonLabel.${...}`) `` (2 valores) y `` t(`turnos.nuevoTurno.${descripcion}`) `` (10 hojas, todas presentes). En logistica, las 2 claves nuevas existen en ambos idiomas, `{{autorizante}}` coincide con lo que pasa el código y el guard de `null` elige bien la variante sin interpolación. Las 5 asimetrías es/en que existen en esos namespaces (`generales.siniestros.fechaControl`, `generales.tabLogistica.internados`, `generales.titulosNavHeader.gestores`, `referenteSiniestros.filtros.estadoMedico`, `referenteSiniestros.filtros.tipoSiniestro`) se verificaron contra `origin/master`: **son pre-existentes**, no las introduce INI-2. Único hallazgo del barrido: BJ-1.

**Rules of Hooks — correcto.** En `BloqueConflictoTraslado.jsx` el `if (!hayConflicto || cargando) return null` está **después** de los seis hooks (`useTranslation`, `usePermissions`, tres `useState`, la mutation, `useConflictoTraslado`, `useAnularConflicto`), que es el orden que la regla exige. Ningún hook dentro de `if`/`switch`/`for` en los archivos nuevos. Los custom hooks respetan el prefijo `use`. Los `useEffect` que resetean `salidaConflictoTraslado` cuando desaparece el conflicto están bien acotados, y el arreglo de deps del `useMemo` de validación en `useTurnosSave.js` (agregar `tieneTrasladoMismoDia`, `salidaConflictoTraslado`, `puedeAutorizarMismoDia`) es correcto y necesario.

**Refactors de rendering — buenos arreglos, no regresiones.** `SaveDrawerManager` → `renderDrawerNuevoTurno()` elimina un remount real: usado como `<SaveDrawerManager />`, el tipo del elemento cambiaba de identidad en cada render y React desmontaba el wizard. El prop `esAnalistaQuirurgico` que se dejó de pasar ya era inerte (el componente no recibía props). El `idTurnoCargadoRef` de `useTurnosSave` cubre el caso real del drawer sin backdrop que no se desmonta al cambiar de fila.

**Traducción posición ↔ valor de tab — bien resuelto.** `tabsVisibles` con `.filter(tab => !!tab.title)` más `posicionTabActiva` con `Math.max(0, findIndex(...))` maneja correctamente el caso de llegar con un `location.state` que no corresponde al perfil, y evita las tabs vacías que dejaba el `title: null`. Los índices nuevos (5 y 6) van al final, que es lo correcto dado que el valor viaja en el state de navegación.

**Circuito del front — completo.** Bloque de conflicto con sus tres salidas (con la salvedad de A-1), pestaña de pendientes con sus tres columnas del pedido, pestaña de resueltos con resultado/autorizante/fecha/dictamen/justificación, drawer de resolución con dictamen obligatorio sólo al rechazar y manejo explícito de `YA_RESUELTO`/`SIN_PERMISO`/`NO_ENCONTRADO`, las dos cards del home con `skip` correcto y filtrado por permiso, y la marca en la grilla de logística. Manejo de errores razonable en todos los caminos nuevos: el texto que se muestra es el del backend, no uno inventado por el front.

**Accesibilidad.** El `RadioGroup` del bloque lleva `aria-label`, y en logistica los `<img>` nuevos pasaron de `alt='icon'` a `alt={t(...)}` — mejora sobre el patrón del repo.

---

## Preguntas al autor

1. ¿La exclusión de `useEditarTurnoRehabilitacion.js` del commit `00af4050` es deliberada, o se fue con el mismo olvido que el módulo de B-1? Si es deliberada, ese flujo va a producción con la desviación que INI-2 vino a eliminar.
2. ¿`wsturnos` deriva el solicitante del token en `pedir-traslado-duplicado`, o depende del `idSolicitante` del body? De eso depende si A-2 es bloqueante o cosmético.
3. ¿El backend puede devolver `puedeAnular: false` + `requiereAutorizacion: false` + `puedeGuardarSinTraslado: true`? Es la combinación que produce el callejón sin salida de A-1.
4. ¿El id 16 de `motivos_anulacion` en **producción** es el motivo del traslado duplicado, o «Cancelado por alarma repetida»? (M-7)
5. ¿`esDuplicadoAutorizado` y `duplicadoAutorizadoPor` ya están en la response del endpoint de traslados en producción? (M-6)
6. ¿El pipeline gatea con `npm run lint`? Si sí, M-4 hay que resolverlo junto con los bloqueantes.

---

## Plan mínimo para habilitar la promoción

| # | Acción | Severidad |
|---|---|---|
| 1 | Traer `exigeMotivoTrasladoMismoDia.js` del commit `00af4050` | 🔴 B-1 |
| 2 | Mover `ESTADO_DUPLICADO_RESUELTO_STYLE` al import de `'./styles'` en `utils.js` | 🔴 B-2 |
| 3 | Pasar `onGuardarSinTraslado` en los tres drawers restantes | 🟠 A-1 |
| 4 | Pasar `idSolicitante` en `DrawerProgramarTurno` y `DrawerEditarTurno` | 🟠 A-2 |
| 5 | Borrar los 4 imports muertos (`dayjs`, `useSelector` ×2) | 🟡 M-4 |
| 6 | Correr `npm ci && npm run lint && npm run build` en el worktree | — |

Los puntos 1, 2 y 5 son mecánicos. Los puntos 3 y 4 necesitan una respuesta de las preguntas 2 y 3. Nada de esto exige rehacer el corte quirúrgico.

---

*Riesgos ya reportados y aceptados, no repetidos en este informe: falta de `aria-label`/`title` en los botones de acción de la grilla (`alt="icon"`); el ícono de «duplicado autorizado» de logistica con `fill="#F29423"`, el mismo naranja que «Requiere revisión»; y la pérdida de la franja de la marca cuando la fila es también espontánea o requiere revisión, por precedencia del ternario de `setRowStyle`. Tampoco se reporta como problema la ausencia de código de otros tickets (SE-268, GRV-2176, GRV-2226, GRV-2241, Cartera AP, Costos y Topeo, filtros de ortopedia, multirol/multi-MFE), que es deliberada.*

*Alcance: revisión estática de código. No se ejecutó lint, build ni tests — no hay `node_modules` en el worktree de `tramitadores`.*

Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026

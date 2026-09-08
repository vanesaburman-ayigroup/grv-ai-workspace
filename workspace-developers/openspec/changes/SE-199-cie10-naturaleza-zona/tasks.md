> **Estado al 31/08/2026.** El trabajo creció bastante más allá de las tres MRs iniciales: el autocompletado cubre hoy **cuatro superficies** (D-12), el servicio **recalcula la terna** al cambiar el diagnóstico (D-14) y el guardado de CEM **pide confirmación** de lo que completó el sistema (D-13).
>
> **Base**: migración aplicada en **DEV** y en **TEST** — 42 relaciones activas (16 con los dos ejes, 26 sólo zona) y kill switch en 1.
> **Código**: los **cinco repos** — `wscie10`, `frontend/grv-frontend`, `auditoriamedica`, `mesadecarga` y `tramitadores` — están en `develop` y en `release` (TEST), con los builds verificados en verde.
> **Falta**: **STAGE** y **PROD**. En los dos, la migración va **antes** que el código.
> **No implementado**: la **fase 6** (indicador de coherencia previo a la SRT). Ver D-19.
>
> El orden importa: la base va antes que el servicio (la entidad mapea la tabla nueva), y el servicio antes que los frontends. Referencias `D-n` al `design.md`.

## 1. Base de datos

- [x] 1.1 `CREATE TABLE cs.cie10_relaciones_validas` con `codigo_cie10` (FK a `diagnosticos_cie10`), `id_naturaleza_siniestro` (FK, **nullable**), `id_zona_afeccion` (FK, **nullable**), `activo` y auditoría. Sin campos de modo: la presencia del valor es la decisión (D-3)
- [x] 1.2 Constraint que impida la fila inútil: al menos uno de los dos ejes SHALL tener valor
- [x] 1.3 Kill switch en `cs.parametros` para apagar el autocompletado sin desplegar — mismo patrón que GRV-2239
- [x] 1.4 DML de carga de las **42 relaciones** confirmadas: 16 con terna completa, 15 con sólo zona, 11 del bloque C con zona y naturaleza en `NULL` (D-11). Idempotente, resolviendo naturaleza y zona **por código SRT**, no por id fijo
- [x] 1.5 Verificar que no se cargó ninguno de los 31 códigos de `config_trazadora_cie10` (D-2), ni `S42.2` ni `M62.1` — **verificado en origen contra la base**: los 42 códigos de la migración existen en `diagnosticos_cie10` y ninguno está en `config_trazadora_cie10`. La verificación 4.3 del script lo vuelve a comprobar tras aplicar
- [x] 1.6 Migración en `src/main/resources/sql/migrations/` con el encabezado de la convención del repo: descripción, autor, fecha, prerequisito, idempotencia y orden de ambientes
- [x] 1.7 Aplicar en **DEV** y verificar — aplicado el 27/08 en `db.dev.sas.colonia-suiza.com.ar/cs`. Las 5 verificaciones del script pasan (42 filas: 16 terna + 26 sólo zona, 0 zonas inactivas, 0 trazadoras, 0 excluidos, kill switch en 1). Además: **idempotencia** comprobada con una segunda corrida (0 filas afectadas) y el **CHECK** comprobado rechazando una fila con los dos ejes vacíos
- [x] 1.8 Aplicar en **TEST** y verificar — aplicada, con el mismo resultado que en DEV: **42 relaciones activas** (16 con los dos ejes, 26 sólo zona) y kill switch en 1
- [ ] 1.9 Aplicar en **STAGE** — antes de desplegar los cinco repos a STAGE
- [ ] 1.10 Aplicar en **PROD** — siempre antes de desplegar el servicio

## 2. `wscie10` — el endpoint de la relación

- [x] 2.1 Entidad `Cie10RelacionValida` y su repositorio. Las tres entidades del catálogo ya existen (`DiagnosticosCie10`, `NaturalezasSiniestro`, `ZonaAfectada`): reutilizarlas, no duplicar
- [x] 2.2 Servicio que resuelve la relación de un código y devuelve cada eje resuelto o vacío. Debe leer de `diagnosticos_cie10`, **nunca** de `certezas_cie10` (D-5)
- [x] 2.3 El servicio consulta `config_trazadora_cie10` y devuelve «sin relación» para esos códigos aunque existiera una fila cargada — cinturón y tiradores sobre 1.5 (D-2)
- [x] 2.4 Respeta el kill switch de 1.3: apagado, responde «sin relación» para todo
- [x] 2.5 Endpoint `GET /diagnosticoCie10/relacion/{codigo}` en `GestionCie10Controller`. **Corrección al plan**: iba a seguir la convención local del controller (`@PostMapping` para lecturas), pero el CLAUDE.md del repo marca eso como anti-patrón presente y pide explícitamente no replicarlo en endpoints nuevos. Va por GET, con el motivo documentado en el javadoc
- [x] 2.6 Test unitario del servicio, siguiendo `ValidadorEdicionCie10Test` — **9 casos**: terna completa, sólo zona, sin relación, trazadora, kill switch apagado, kill switch ausente, código nulo/vacío, código con espacios, y descripción inexistente. Suite completa: 22 tests, 0 fallas

## 3. Pestaña General (CEM) — `frontend/grv-frontend`

> El estado está **triplicado** (1º, 2º y 3er diagnóstico) con ternarios anidados de cuatro niveles. Riesgo de regresión alto: extraer antes de tocar. `multiple10.js` 334 líneas, `completar.js` 1.176, `completarForm.js` 1.436.

- [x] 3.1 Hook `useRelacionCie10` que resuelve la relación contra el endpoint, con caché del último código y fallback a «sin relación» si la consulta falla
- [x] 3.2 Efecto en `completar.js` disparado por el **código** del diagnóstico (no por la descripción, que cambia mientras se tipea). **Reordenado**: el CIE-10 pasa arriba de zona y naturaleza en `AutocompleteCompletar`, que es el orden que pide D-1
- [x] 3.3 Alcance en esta pantalla: el **primer diagnóstico** en `completar.js`. **Ampliado (D-12)**: el 2º y el 3º también autocompletan, en `multiple10.js` — `Multiple10Row` monta una instancia por diagnóstico, así que cada bloque resuelve su propia terna de forma independiente
- [x] 3.4 Marca de pendiente como **ícono con tooltip**, el patrón que el componente ya usa para diferencias de reingreso. Traducción nueva `generales.labels.completarManualmente` (es/en).
  > **Corregido tras el preview mockeado.** El primer intento la pasaba por `textoSugerencia` y **no se veía**: `CustomAutocomplete` prioriza «Campo Requerido» cuando el campo está vacío, que es justo cuando la marca aplica. Dos ajustes más de posicionamiento, ambos detectados en el preview: los `Grid` de zona y naturaleza necesitan `position: relative` (si no el ícono se ancla al `body` y aparece en el borde de la pantalla), y el ícono va dentro del campo (con `left: 100%` generaba 36px de scroll horizontal en mobile)
- [x] 3.5 El valor completado queda **editable**: se setea el `value` y el flujo existente (`serchIdAutocompletar`) deriva el id, igual que si lo hubiera elegido una persona (D-8)
- [x] 3.6 Con `disableEdition` el efecto sale temprano y no toca nada. **Además: no pisa lo ya cargado** — sólo completa campos vacíos, así que si alguien cargó la zona a mano su valor queda
- [x] 3.7 Al cambiar el código del diagnóstico el efecto se vuelve a disparar y recalcula los ejes pendientes
- [x] 3.8 `npm run lint` y `npm run typecheck` (o `tsc --noEmit`) — sin errores nuevos atribuibles a lo tocado; **build verificado en verde** en `develop` y en `release`

## 4. Pestaña Auditoría Médica — `auditoriamedica`, 2º y 3er diagnóstico

> **Alcance corregido el 27/08** (D-6): en esta pantalla el autocompletado va sobre el **2º y 3er diagnóstico**, que es lo único que tiene naturaleza y zona. El primer diagnóstico son tres campos planos sin esos dos, y **no se le agregan**. Todo vive en `ComboMultipleCie10.tsx` (199 líneas). TypeScript con Redux Toolkit, slices por combo. La pantalla está **gated** por el módulo `@grv/auditoria-medica` o por el área «AUDITORIA MEDICA».

- [x] 4.1 **Gate invertido**: el combo de CIE-10 queda `disabled={!isAuditorMedico}`, sin depender de naturaleza ni zona. También se ajustaron el `isRequired` y el placeholder, que dependían de la misma condición
- [x] 4.2 **No se pisa lo ya cargado**: el autocompletado sólo escribe sobre los campos vacíos (`base.naturalezaLesion || relacion...`). Un diagnóstico que ya viene completo queda intacto
- [x] 4.3 Al elegir el diagnóstico se completan los ejes determinados; el que no, se marca como pendiente vía `helperText` (D-9). Traducción nueva `denunciaCompleta.auditoriaMedica.completarManualmente` (es/en)
- [x] 4.4 `isAuditorMedico` sigue gobernando los tres combos. La restricción `edicion_bloqueada` de GRV-2239 aplica al primer diagnóstico (`DecisionesMedicasBox`), que esta fase no toca
- [x] 4.5 Interfaces `RelacionCie10` y `RelacionCie10Response` en el hook. `tsc --noEmit` limpio
- [x] 4.6 `tsc --noEmit` exit 0. Lint: **0 errores nuevos** — los 464 son `prettier/prettier` por CRLF, preexistentes en todo el repo, y el único no-prettier es un warning de `exhaustive-deps` que ya estaba

## 5. Verificación

- [ ] 5.1 Caso terna completa: `S80.0` completa Contusiones + Rodilla
- [ ] 5.2 Caso un solo eje: `S93.4` completa Tobillo y marca la naturaleza como pendiente
- [ ] 5.3 Caso bloque C: `S63.6` completa Dedos de las manos y deja la naturaleza libre (D-11)
- [ ] 5.4 Caso trazadora: una denuncia con `T06.8` no autocompleta nada (D-2)
- [ ] 5.5 Caso sin relación: `S42.2` y `M62.1` no completan nada
- [ ] 5.6 El valor completado se puede cambiar y persiste el cambio (D-8)
- [ ] 5.7 Kill switch apagado: la pantalla se comporta como hoy
- [ ] 5.8 No regresión del 2º y 3er diagnóstico en la pestaña General — ahora también autocompletan (D-12)
- [ ] 5.9 Medir contra la SRT después de un ciclo: ¿bajan `GJ` y `FA`?
- [ ] 5.10 Modal de confirmación al guardar (D-13): aparece cuando el sistema completó algo, no aparece cuando no completó nada, y deja de listar el eje que la persona editó
- [ ] 5.11 Recálculo al cambiar el diagnóstico (D-14/D-15): el eje determinado se actualiza y el que no se determina **conserva** su valor
- [ ] 5.12 `recalcularTerna` (D-16): con `false` la terna se conserva; **ausente** se comporta como `true`

## 6. Indicador de coherencia previo a la SRT (D-7) — **NO IMPLEMENTADO**

> **Diferida (D-19).** Nada de esta fase se construyó. La spec `specs/validacion-coherencia-terna/spec.md` describe comportamiento **pendiente**, no el sistema actual. Se conserva porque no depende del catálogo ni de las pantallas de carga: puede construirse y desplegarse después sin rehacer nada. **Informativo y no bloqueante** (D-7).

- [ ] 6.1 **Decidir dónde y cómo se muestra** — mirando la pantalla real de presentación. Es lo primero: define el resto de la fase
- [ ] 6.2 Servicio que evalúa la terna contra las reglas conocidas (`L1`, `L2`, `L3`, `L5`, `GK`, `FA`, `JI`, `GJ`, `L4`) y devuelve coherente / inconsistente, indicando **qué campo entra en conflicto con cuál**
- [ ] 6.3 Mostrar los **tres campos juntos** con el indicador — hoy se cargan por separado y nunca se ven como unidad
- [ ] 6.4 **No bloqueante**: una terna señalada se presenta igual, sin pasos extra ni confirmación adicional
- [ ] 6.5 El archivo generado es idéntico con o sin señalamiento — verificarlo explícitamente
- [ ] 6.6 Denuncias con trazadora: señalar como caso **estructural**, sin sugerir corrección (~6% de los casos)
- [ ] 6.7 Redacción del mensaje: no afirmar que la SRT va a rechazar. Son las reglas conocidas, no todas las que aplica el organismo
- [ ] 6.8 Sólo lectura: no modifica ningún campo de la denuncia

## 7. Pendiente de terceros

- [ ] 7.1 **Q2** — la naturaleza correcta de los 13 códigos del bloque C. No frena la implementación; sí la remediación de D-10
- [ ] 7.2 **D-10** — propuesta de remediación de los casos activos, una vez respondida Q2
- [ ] 7.3 **Q5** — quién mantiene la tabla cuando aparezcan códigos nuevos
- [ ] 7.4 Pruebas estáticas de Sentinel sobre el SDD, anunciadas en el ticket el 20/08

## 8. Alcance extendido — las otras superficies (D-12)

- [x] 8.1 **CEM · General · 2º y 3er diagnóstico** — `multiple10.js`, una instancia de la lógica por diagnóstico vía `Multiple10Row` (ver 3.3)
- [x] 8.2 **Mesa de carga** — Siniestralidad › Editar siniestro › `DiagnosticoLesiones.tsx`, **los tres bloques**
- [x] 8.3 **Auditoría Médica** — 2º y 3er diagnóstico en `ComboMultipleCie10.tsx`, gated por módulo `@grv/auditoria-medica` o área «AUDITORIA MEDICA» (ver sección 4)
- [x] 8.4 **Fuera a propósito**: `contrataciones`, por decisión del equipo
- [x] 8.5 **Fuera, verificado**: `PantallaLesionLeve` y `PantallaRiesgoMuerte` de CEM — sólo arrastran `diagnosticoCie10Codigo` para armar el request, no tienen selector de CIE-10 y por lo tanto no hay evento que dispare el autocompletado

## 9. Confirmación al guardar — CEM · General · 1er diagnóstico (D-13)

- [x] 9.1 Modal que lista los ejes que completó el sistema y pide confirmar antes de guardar. Reusa `ModalCamposFaltantes` con un **tipo nuevo**
- [x] 9.2 Se guarda el **texto que escribió el autocompletado** y se compara contra el valor actual del campo: si la persona lo editó, ese eje deja de reportarse. **No se intercepta la edición**
- [x] 9.3 El flag viaja en `datosCompletarGeneral.autocompletadoCie10` y **no llega al backend**: `UpdateRequestBuilder` arma el request campo por campo

## 10. Recálculo de la terna al cambiar el diagnóstico — `wscie10` (D-14 · D-15 · D-16)

- [x] 10.1 `modifyDiagnosticoCie10byIdDenuncia` recalcula la terna. Se resuelve **en el servicio y no en las pantallas** porque el CIE-10 se cambia desde tres lugares y ese método es el único por el que pasan los tres. Sigue el patrón que el método ya usaba con `recalcularFechaProbableFinIlt`
- [x] 10.2 **Sólo se pisa el eje que el catálogo determina** (D-15): el que no determina conserva su valor, porque vaciarlo dejaría incompleto un dato que la SRT exige
- [x] 10.3 Trazadoras y kill switch se resuelven como «sin relación» y no tocan nada (D-2)
- [x] 10.4 `recalcularTerna` en el request (D-16): `true` actualiza, `false` conserva, **ausente equivale a `true`** — quien no manda el flag no tuvo dónde elegir
- [x] 10.5 **Popover de Auditoría Médica**: ofrece la elección mostrando qué corresponde según el código nuevo, con un **checkbox tildado por defecto**. El bloque **sólo aparece si el catálogo determina algo**

## 11. Correcciones detectadas al implementar (D-17 · D-18)

- [x] 11.1 **Condición de carrera** (D-17): el efecto leía los valores de los campos dentro del `.then()` sin tenerlos en las dependencias, así que una escritura manual mientras viajaba la consulta se perdía. Corregido leyendo **por ref** y descartando respuestas obsoletas. `react-hooks/exhaustive-deps` está apagada en el repo, por eso el lint no lo detectaba
- [x] 11.2 **Bug de persistencia en CEM** (D-18): la descripción se toma del **listado local buscando por id**, no de la que devuelve el servicio. `serchIdAutocompletar` resuelve el id filtrando el listado con `valueCampo.includes(it.descripcion)`, y si el texto no coincide carácter por carácter deja el id anterior — la pantalla mostraba el valor autocompletado y al guardar volvía el viejo

## 12. Despliegue

- [x] 12.1 **DEV** — migración aplicada y los cinco repos (`wscie10`, `frontend/grv-frontend`, `auditoriamedica`, `mesadecarga`, `tramitadores`) en `develop`, builds en verde
- [x] 12.2 **TEST** — migración aplicada (42 relaciones activas, kill switch en 1) y los cinco repos en `release`, builds en verde
- [ ] 12.3 **STAGE** — **primero la migración (1.9), después el código** de los cinco repos
- [ ] 12.4 **PROD** — **primero la migración (1.10), después el código** de los cinco repos

## 13. Aviso en la pestaña de Auditoría Médica (D-20)

Detectado probando en TEST: esa pantalla guarda contra `wsauditoria`, no por `wscie10`, así que el
recálculo de D-14 no la alcanza; y no muestra naturaleza ni zona, así que la incoherencia era
invisible.

- [x] 13.1 Consultar el catálogo al elegir el primer diagnóstico y detectar la divergencia.
- [x] 13.2 Mostrar el aviso **arriba del diagnóstico**, con el valor actual como referencia
      («Zona afectada: Tobillo (Antes: Cuello)») y botón para aplicarlo.
- [x] 13.3 Aplicar sobre `request.denunciaCie10[0]`, para que viaje en el guardado.
- [x] 13.4 Invertir el default de `recalcularTerna`: ausente = no tocar (D-16 revisada).
- [ ] 13.5 Probar en DEV con una denuncia real.
- [ ] 13.6 Promover a TEST.

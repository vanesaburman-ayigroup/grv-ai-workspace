## Why

Los tres campos que describen la lesión de una denuncia — **diagnóstico CIE-10**, **naturaleza de la lesión** y **zona corporal afectada** — se cargan hoy de forma completamente independiente. No hay tabla que los vincule, no hay validación que los cruce, no hay autocompletado. Son tres catálogos separados (`diagnosticos_cie10` 1.064 filas, `naturalezas_siniestro` 80, `zonas_afeccion` 255) y una tabla transaccional (`denuncias_cie10`) que guarda la terna sin ninguna restricción de coherencia entre sus partes.

**La SRT sí valida esa coherencia, y nos la devuelve.** Medido sobre las respuestas reales del validador entre abril y agosto de 2026: **1.803 de 17.103 devoluciones (10,5%)** son inconsistencias de esta terna, afectando **731 de 6.830 denuncias (10,7%)**. El desglose ordena la prioridad:

| Código SRT | Qué dice | Tipo | Ocurrencias | Vigentes |
|---|---|---|---|---|
| `GJ` | Posible inconsistencia entre la lesión declarada y el diagnóstico | Observación | 1.318 | 252 |
| `FA` | Posible inconsistencia entre la zona de cuerpo y el diagnóstico | Observación | 316 | 70 |
| `JI` | Inconsistencia entre lesión declarada y diagnóstico | **Error** | 91 | 0 |
| `GK` | Inconsistencia entre zona de cuerpo y diagnóstico | **Error** | 78 | 0 |

`GJ` es **la observación más frecuente de todo el sistema**. Los 169 errores duros (`JI` + `GK`) obligaron a rehacer y reenviar.

**La SRT ya tiene la matriz de validez publicada como catálogo de errores.** En `codigos_error_srt` hay nueve códigos dedicados a esta terna: `L1` (zona inválida para diagnóstico de AT), `L2` (naturaleza inválida para el diagnóstico), `L3` (zona inválida para la naturaleza especificada), `L4`, `L5`, más `GK`, `FA`, `GJ` y `JI`. Registros no define esto desde cero: puede derivarlo de lo que la SRT ya viene rechazando.

**Y la estructura del CIE-10 aporta la mitad de la respuesta.** En el capítulo XIX (`S00`–`T98`) el tercer carácter codifica la región anatómica. Verificado contra cinco meses de envíos aceptados, la zona modal de cada bloque predice la anatomía **sin una sola excepción** (10 de 10): `S0_`→Cabeza, `S1_`→Cervical, `S2_`→Tórax, `S3_`→Lumbosacra, `S4_`→Hombro, `S5_`→Codo, `S6_`→Dedos de la mano, `S7_`→Cadera, `S8_`→Rodilla, `S9_`→Tobillo.

**Pero los datos históricos no son fuente de verdad para el eje naturaleza.** Agrupando por cuarto carácter, la naturaleza modal es «Contusiones» en nueve de diez grupos, incluso en códigos que describen fracturas, heridas y esguinces. Eso no es una relación: es un valor por defecto que se arrastra en la carga, y es muy probablemente la causa directa de que `GJ` sea la observación número uno. Poblar la tabla con la moda estadística cristalizaría el error histórico y le daría categoría de regla.

## What Changes

- **Nueva tabla de configuración `cs.cie10_relaciones_validas`**, con la terna (`codigo_cie10`, `id_naturaleza_siniestro`, `id_zona_afeccion`). Cada eje es independiente y admite `NULL`: **con valor** significa determinístico y se autocompleta; **`NULL`** significa no determinable y el campo lo carga la persona. No hay campo de modo. Sigue el patrón estructural de `especialidades_cie10_defaults`, que ya guarda exactamente esta terna para resolver otro problema.
- **Orden canónico de carga: el CIE-10 va primero**, y de él se derivan naturaleza y zona. Aplica a las dos pantallas.
- **Lo que no se puede determinar no se sugiere.** El catálogo tiene fila sólo para las relaciones determinables; un eje indeterminable queda sin valor y el sistema no toca el campo. No hay lista de exclusión ni valores de baja confianza «por si acaso»: la ausencia de fila es la decisión. Los 31 códigos de `config_trazadora_cie10` quedan cubiertos por esta regla — en esas denuncias el CIE-10 es una etiqueta administrativa que no describe la lesión. Ver `design.md` D-2.
- **Nuevo endpoint en `wscie10`**, bajo el mismo contexto donde ya viven `findByCodigo` y `edicion-bloqueada`, que devuelve la relación de un código dado, con cada eje resuelto o en `NULL`.
- **Autocompletado en las cuatro superficies donde la terna está completa** (D-12). El alcance no lo define el número de diagnóstico sino la presencia de los tres campos:

  | Superficie | Diagnósticos | Dónde |
  |---|---|---|
  | CEM · pestaña General | 1er diagnóstico | `completar.js` |
  | CEM · pestaña General | 2º y 3er diagnóstico | `multiple10.js` (`Multiple10Row`, una instancia por diagnóstico) |
  | Auditoría Médica | 2º y 3er diagnóstico | `ComboMultipleCie10.tsx`, gated por módulo `@grv/auditoria-medica` o área «AUDITORIA MEDICA» |
  | Mesa de carga | los tres bloques | Siniestralidad › Editar siniestro › `DiagnosticoLesiones.tsx` |

  Quedan **fuera a propósito** `contrataciones` (decisión del equipo) y `PantallaLesionLeve` / `PantallaRiesgoMuerte` de CEM — verificado: sólo arrastran `diagnosticoCie10Codigo` para armar el request, no tienen selector de CIE-10.

  En todas hay que respetar las restricciones de edición vigentes (`disableEdition`, `diferenciasReingreso`, permisos del auditor).
- **En Auditoría Médica se invierte el gate**: hoy el combo de CIE-10 está `disabled` hasta que naturaleza y zona tengan valor, o sea **el orden inverso al que se adopta**. Es un cambio en el flujo de trabajo del auditor médico, no un ajuste técnico.
- **Confirmación al guardar** en CEM · General · 1er diagnóstico (D-13): cuando el sistema completó naturaleza y/o zona, al guardar se listan esos campos y se pide confirmar. Motivo: al abrir una denuncia que ya tenía el CIE-10 cargado el autocompletado se dispara solo, y esos datos viajan a la SRT sin que nadie los haya mirado. Un eje que la persona editó deja de reportarse.
- **Recálculo de la terna al cambiar el diagnóstico** (D-14, D-15): `modifyDiagnosticoCie10byIdDenuncia`, en `wscie10`, recalcula naturaleza y zona para que describan el código vigente y no el anterior. Se pisa **sólo el eje que el catálogo determina**; el que no determina conserva su valor. Va en el servicio y no en las pantallas porque el CIE-10 se cambia desde tres lugares y ese método es el único por el que pasan los tres.
- **La pantalla puede elegir si se recalcula** (D-16): el request lleva `recalcularTerna` — `true` actualiza, `false` conserva, **ausente equivale a `true`**. El popover de Auditoría Médica ofrece la elección, con la opción tildada por defecto y sólo si hay algo que recalcular.
- **Chequeo de coherencia previo a la presentación SRT**, que replica `L1`, `L2`, `L3`, `GK` y `FA` sobre la terna antes de generar el archivo. No depende del autocompletado ni del orden de carga, y ataca los casos medidos de forma directa. **No implementado — diferido (D-19).**
- **Carga inicial del catálogo validada por Registros**, no derivada automáticamente de la estadística. La matriz candidata (133 códigos clasificados) se adjunta como `matriz-relaciones-candidatas.tsv`.

## Capabilities

### New Capabilities

- `relacion-cie10-naturaleza-zona`: el catálogo de relaciones determinísticas, la independencia entre ejes, el catálogo de CIE-10 que es fuente de verdad, y las reglas de qué se puede cargar y qué no.
- `autocompletado-terna-diagnostico`: el comportamiento en las dos pantallas — orden canónico con el CIE-10 primero, el valor editable, la marca del eje pendiente, y la convivencia con las restricciones de edición ya existentes.
- `validacion-coherencia-terna`: el chequeo previo a la presentación que replica las validaciones de coherencia de la SRT. **⚠️ NO IMPLEMENTADA.** La fase 6 quedó diferida (D-19): la spec describe comportamiento pendiente, no el sistema actual. Se conserva porque no depende del catálogo ni de las pantallas de carga.

### Modified Capabilities

<!-- No hay specs canónicas previas en openspec/specs/ para estas capacidades. -->

## Impact

**Base de datos (esquema `cs`, MariaDB)**

- `CREATE TABLE cs.cie10_relaciones_validas` con FK a `diagnosticos_cie10`, `naturalezas_siniestro` y `zonas_afeccion` — las tres FK existen y son consistentes con las que ya usa `denuncias_cie10`.
- Carga inicial por DML, con los valores que Registros valide. **No** se derivan de la moda estadística.
- **No** se modifican datos ya cargados. Ver la decisión de retroactividad en `design.md`.

**Backend**

- `wscie10` — endpoint nuevo de consulta de relación. Es el servicio que ya concentra la lógica de CIE-10 (`findByCodigo`, `edicion-bloqueada`, `modifyByIdDenuncia`).
- `wscie10` — `modifyDiagnosticoCie10byIdDenuncia` recalcula la terna al cambiar el diagnóstico, siguiendo el patrón que el método ya usaba con `recalcularFechaProbableFinIlt`, y acepta `recalcularTerna` en el request (D-14, D-16).
- El chequeo de coherencia previo a la presentación toca el circuito de generación del archivo SRT, no las pantallas de carga. **Sigue sin construirse** (D-19).

**Frontend — dos repos con stacks distintos, y el esfuerzo no es simétrico**

- `frontend/grv-frontend` (pestaña General, CEM): JavaScript sin tipos, Redux clásico, sin RTK Query. Los tres campos son `Autosuggest` independientes y **el estado está triplicado** — un juego de variables por cada diagnóstico (1º, 2º, 3º), inicializado con cadenas de ternarios anidados de cuatro niveles. `multiple10.js` son 334 líneas para dos diagnósticos; `completarForm.js`, 1.436. Riesgo de regresión alto: conviene extraer un hook común antes de tocar tres veces el mismo comportamiento.
- `auditoriamedica` (pestaña Auditoría Médica): TypeScript con Redux Toolkit, slices por combo, `ComboMultipleCie10.tsx` de 199 líneas. Más limpio, pero requiere invertir el gate de habilitación.
- **Terminaron siendo más de dos repos.** Con el alcance de D-12, el cambio toca **cinco**: `wscie10`, `frontend/grv-frontend`, `auditoriamedica`, `mesadecarga` y `tramitadores`.

**Alcance de volumen**

El **1er diagnóstico cubre el 95%** de los casos: de 6.835 denuncias con diagnóstico, sólo 370 tienen un 2º (5,4%) y 81 un 3º (1,2%). Además, cuando existe el 2º diagnóstico **siempre** trae su naturaleza y zona completas — cero casos incompletos, cero errores `K9`. La primera etapa puede acotarse al 1er diagnóstico sin dejar deuda funcional; el ahorro es de alcance, no de código, porque el estado triplicado de la pestaña General existe igual.

> **Lo que efectivamente se construyó fue más amplio.** Justamente porque el ahorro era de alcance y no de código, una vez resuelto el mecanismo se extendió al 2º y 3er diagnóstico y a las otras dos pantallas. Ver D-12.

**Agregado en las definiciones del equipo del 21/08** (a confirmar con Registros)

- **Propuesta de remediación de los casos activos.** El cambio aplica sólo a futuro, pero se suma el análisis y la propuesta de corrección para las denuncias todavía activas — las no presentadas o aún corregibles ante la SRT. Es una propuesta a revisar y aplicar por un senior, no una ejecución automática, y depende de que se definan los 13 conflictos. Ver `design.md` D-10.
- El valor autocompletado queda **editable** (D-8), y el eje que no se puede determinar se **marca como pendiente** (D-9).

**Estado de entrega (31/08/2026)**

- Migración aplicada en **DEV** y en **TEST**: 42 relaciones activas — 16 con los dos ejes, 26 sólo zona — y kill switch en 1.
- Los **cinco repos** están en `develop` y en `release` (TEST), con los builds verificados en verde.
- **Falta STAGE y PROD.** En los dos ambientes la migración va **antes** que el código.
- La **fase 6** (indicador de coherencia) no se implementó.

**Fuera de alcance**

- Recalcular o corregir denuncias ya presentadas y aceptadas por la SRT.
- Los 13 códigos en conflicto: no se cargan hasta que Registros defina el valor correcto.
- Las equivalencias con Provincia ART (GRV-2207), que son un bloqueante independiente.
- Los códigos inespecíficos por definición (`V49.4`, `T00`, `T06.8`, `T75`, `T14.2`) y `Z20.9`.

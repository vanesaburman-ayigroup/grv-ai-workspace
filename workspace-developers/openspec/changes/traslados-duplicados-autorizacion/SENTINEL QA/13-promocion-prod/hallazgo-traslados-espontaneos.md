# Hallazgo — Los traslados espontáneos y el gate de INI-2

**Autor:** Vanesa Burman — QA
**Fecha:** 22/08/2026
**Origen:** observación de negocio durante la revisión de la promoción: *«los traslados espontáneos a veces tienen turnos asociados, y se deben aprobar rápidamente»*.
**Severidad:** media — no bloquea la promoción, pero introduce fricción medible en un flujo urgente.

---

## Resumen en una línea

Crear un traslado espontáneo **no** pasa por el gate, así que su urgencia queda intacta. Pero el espontáneo **sí cuenta** como el traslado que bloquea a otros, y los dos motivos disponibles no describen ese caso: **~67 altas por mes** quedan empujadas a esperar una autorización o a declarar un motivo que afirma algo que no pasó.

---

## 1. Crear un espontáneo no pasa por el gate

Los cinco call sites del validador están **todos** en `wsturnos`:

| Endpoint | Método del validador |
|---|---|
| `POST /turnos/crear` | `validar(...)` |
| `POST /turnos/editar` | `validarEdicion(...)` |
| `POST /turnos/programar-turno` | `validarProgramacion(...)` |
| `POST /turnos-rehabilitacion/programar-turno` | `validarTandaProgramacion(...)` |
| `POST /autorizaciones/generar` | `validarGeneracionAutorizacion(...)` |

Pero hay **dos servicios distintos** que crean espontáneos, y **ninguno de los dos pasa por ahí**:

### 1.a — Logística

`wslogistica POST /guardar-traslado-espontaneo` → `TrasladoServiceImpl:259` → `trasladoStrategyFactory.getStrategy(...).saveTrasladoEspontaneo(...)`, que escribe por JPA. **No llama a `wsturnos` ni al validador** (cero referencias a `turnos/crear`, `DuplicadoValidator` o `idMotivoTrasladoMismoDia` en todo el repo).

### 1.b — CEM, el front del call center

Y este es el que importa para la pregunta *«¿tampoco pasa si el espontáneo tiene un turno asociado?»*. La cadena completa:

| paso | dónde |
|---|---|
| Drawer de traslados del call center | `grv-frontend` → `TrasladosDrawer/AmbulanciaIda` (los textos son `callCenter.traslados.drawer.*`) |
| Arma el request y despacha | `primeraAsistencia.js:139` → `actions.creacionTraslado(req, ...)`, con `confirmaCEM` en el payload |
| Endpoint | `FETCH_URL_GUARDAR_TRASLADO` = `${CONTEXT_TRASLADOS}/traslado/save` |
| Backend | **`wstraslados` `TrasladoController:78` `@PostMapping("/save")`** → `trasladoServiceDTO.save(dto)` |
| Y el turno | `TrasladoServiceDTOImpl:180` — **`Turno turno = generateTurno(dto)`** |

**El turno lo crea `wstraslados` él mismo.** No hay llamada a `wsturnos POST /turnos/crear`: el traslado y su turno nacen juntos en `save()`, y en la línea siguiente (`:182`) se marca `esEspontaneoAsociado` según el tipo de turno generado.

**Y `wstraslados` no conoce el gate: cero referencias** a `TrasladoDuplicadoValidator`, `idMotivoTrasladoMismoDia`, `autorizaciones_traslado_duplicado` o `turnos/crear` en todo `src/main`.

### Conclusión del punto 1

**Nada de INI-2 frena, demora ni pone a esperar la creación de un espontáneo, ni desde logística ni desde CEM, ni con turno asociado ni sin él.** La preocupación por la urgencia está cubierta.

**Pero eso mismo es un agujero en el gate**, y hay que decirlo con el mismo criterio con que el change justifica su propia existencia. El javadoc del validador dice: *«el gate del traslado duplicado vivía sólo en el front. Los cuatro drawers piden el motivo, pero cualquier otro camino de alta —una llamada directa al endpoint, un flujo que no pasa por el drawer— lo esquivaba sin resistencia»*. Ese argumento **aplica textualmente** a estos dos caminos: el gate del servidor cubre `wsturnos`, y hay otros dos servicios que escriben `traslados` con turno y lo esquivan igual que antes.

## 1.c — Y si en el espontáneo se **selecciona** un turno existente

Los dos caminos se comportan distinto, y esto importa.

**CEM no permite seleccionarlo.** `TrasladoServiceDTOImpl:918 generateTurno(dto)` arranca con `Turno turno = new Turno()` y no lee ningún `idTurno` del request: **siempre crea uno nuevo**.

**Logística sí.** `SaveTrasladoEspontaneoRequestDTO` tiene `Long idTurno` **opcional** (sin `@NotNull`), y `TrasladoStrategy:187`:

```java
Turno turno =
    request.idTurno() == null
        ? turnosService.crearTurnoTrasladoEspontaneo(request)
        : turnosService.findTurnoById(request.idTurno());
traslado.setTurno(turno);
...
traslado.setIsEspontaneoAsociado(true);
```

Si viene el `idTurno`, **el traslado se cuelga de un turno que ya existe**, sin verificar si ese turno ya tenía uno. Y se marca `isEspontaneoAsociado = true` igual, y con `estadoLogisticaIda = SOLICITADO` — o sea **visible para logística y despachable**.

Respondiendo la pregunta directa: **seleccionar un turno no cambia nada respecto del gate. Sigue sin pasar.** Ninguno de los dos caminos lo toca.

### Pero abre otra cosa: dos traslados en el mismo turno

**No hay constraint único en `traslados.id_turno`** — el único índice es `traslados_turnos_fk1`, `NON_UNIQUE = 1`— y en producción **ya hay 3.094 turnos con más de un traslado**, con hasta **4** en uno solo (6.209 traslados involucrados).

| año del turno | turnos con 2+ traslados | de esos, con un espontáneo |
|---|---|---|
| 2026 | 48 | **0** |
| 2025 | 220 | 13 |
| 2024 | 684 | 584 |
| 2023 | 421 | 366 |
| 2022 | 414 | 382 |
| 2021 | 344 | 322 |
| 2020 | 769 | 751 |
| 2019 | 187 | 151 |

El patrón es claro: **entre 2019 y 2024 casi todos los turnos con traslado duplicado venían de un espontáneo colgado de un turno existente. En 2026 son 48 y ninguno es espontáneo** — la práctica cambió o el camino dejó de usarse. Bien para el riesgo actual, pero el camino sigue abierto en el código.

### El problema concreto que esto le crea a INI-2

`ITrasladoRepository.findTrasladoByTurnoIdTurno` devuelve **un único `Traslados`**, no una lista:

```java
@Query("SELECT t FROM Traslados t WHERE t.turno.id = ?1")
Traslados findTrasladoByTurnoIdTurno(Long idTurno);
```

Sobre un turno con dos traslados, Spring Data lanza `IncorrectResultSizeDataAccessException`.

**El método ya existía en `master`**, pero ahí lo usaba **un solo lugar** (`AutorizacionesServiceImpl:1826`). **INI-2 le agrega tres call sites nuevos, todos en el validador:**

| línea | método | se ejecuta en |
|---|---|---|
| `TrasladoDuplicadoValidator:142` | `validarProgramacion` | `POST /turnos/programar-turno` |
| `TrasladoDuplicadoValidator:283` | `validarEdicion` | `POST /turnos/editar` |
| `TrasladoDuplicadoValidator:327` | `vaATenerTraslado` | `POST /turnos-rehabilitacion/programar-turno` |

Y como el validador corre **antes del `try`** —a propósito, para que la excepción de duplicado suba limpia al handler global— esa excepción **no queda contenida**: sale como **500**, no como el 409 del circuito. Programar o editar un turno que tenga dos traslados pasaría de funcionar a devolver error de sistema.

**Alcance real:** de los 48 turnos de 2026, por estado: Realizado 29, Anulado 9, No Realizado 5, y **«Prog. Con Traslados Pend.» 5**. Sólo esos últimos están en un estado donde programar o editar es una operación normal. Así que el riesgo es **bajo pero cierto**, y crece con cada espontáneo que alguien cuelgue de un turno existente.

### Los 5 turnos en riesgo, mirados de cerca

Los cinco son de **una sola denuncia, la 510852**, entre el 14 y el 21/07/2026, y **ninguno es espontáneo** (`es_espontaneo_asociado` en NULL). El patrón de cada uno es el mismo:

| turno | traslado | estado | `id_estado_logistica_ida` | creado por |
|---|---|---|---|---|
| 5166136 | 1604148 | Programado | 3 | *(null)* |
| 5166136 | **1604477** | Solicitado | **NULL** | 1594 |
| 5166138 | 1604150 | Cancelado | 5 | *(null)* |
| 5166138 | **1604479** | Solicitado | **NULL** | 1594 |
| 5166139 | 1604151 | Programado | 3 | *(null)* |
| 5166139 | **1604480** | Solicitado | **NULL** | 1594 |
| 5166140 | 1604152 | Programado | 3 | *(null)* |
| 5166140 | **1604481** | Solicitado | **NULL** | 1594 |
| 5169593 | 1604918 | Solicitado | **NULL** | 1594 |
| 5169593 | 1604919 | Solicitado | **NULL** | 1594 |

Dos cosas para notar:

1. **Todos los segundos traslados tienen `id_estado_logistica_ida` en NULL.** Es la misma marca que D1 usa como llave de invisibilidad para logística. Acá no la puso INI-2 —esto es producción, donde el circuito todavía no está— así que hay **otro camino que ya deja traslados invisibles para logística**, y conviene saber cuál antes de tratar ese NULL como propiedad exclusiva del circuito nuevo.

2. **El turno 5169593 tiene los dos traslados en NULL.** O sea: un turno con dos traslados y ninguno de los dos visible en la grilla de logística. Es exactamente el caso que el circuito viene a evitar, ya presente en producción, y sin relación con espontáneos.

Nada de esto cambia el fix —de hecho lo confirma: son turnos reales, en estado programable, donde el validador habría tirado 500— pero sí muestra que el turno-con-dos-traslados no es sólo cosa del espontáneo de logística. Vale una revisión aparte de por qué la 510852 quedó así.

### La corrección, que es barata

No hace falta tocar el comportamiento: alcanza con preguntar por **existencia** en lugar de pedir **la** fila. Un método nuevo en el repositorio y tres reemplazos en el validador:

```java
@Query("SELECT COUNT(t) FROM Traslados t WHERE t.turno.idTurno = :idTurno")
long contarPorTurno(@Param("idTurno") Long idTurno);
```

Y en el validador, las tres apariciones de `findTrasladoByTurnoIdTurno(x) != null` pasan a `contarPorTurno(x) > 0`. Misma semántica —«este turno tiene traslado»— sin el modo de falla. No cambia ninguna decisión del gate: sólo deja de romperse cuando hay más de uno.

> El call site preexistente de `AutorizacionesServiceImpl:1826` **sí** necesita la entidad, así que ahí no aplica el mismo cambio. Queda con la exposición que ya tenía en `master`: no es de esta promoción.

## 2. Pero el espontáneo sí bloquea a los demás

`ITrasladoRepository.contarTrasladosVigentesEnFecha` cuenta **todos** los traslados de la denuncia en la fecha, excluyendo sólo Cancelado (4) y Rechazado (5). **No filtra `es_espontaneo_asociado`.**

Así que la dirección inversa sí muerde: un gestor que carga un turno normal con traslado, el mismo día en que el paciente ya tuvo un espontáneo, **recibe el conflicto**.

### Volumen, medido sobre producción

**Espontáneos creados en 2026: 4.814.** De esos, el **62%** cae en un día en que el paciente ya tenía otro traslado:

| mes | espontáneos | con otro traslado el mismo día |
|---|---|---|
| 2026-01 | 442 | 321 |
| 2026-02 | 398 | 226 |
| 2026-03 | 676 | 401 |
| 2026-04 | 691 | 467 |
| 2026-05 | 690 | 423 |
| 2026-06 | 793 | 503 |
| 2026-07 | 646 | 391 |
| 2026-08 | 476 | 293 |

**Y las altas normales que quedan bloqueadas porque ese día hubo un espontáneo:**

| mes | altas bloqueadas por un espontáneo |
|---|---|
| 2026-01 | 70 |
| 2026-02 | 37 |
| 2026-03 | 56 |
| 2026-04 | 72 |
| 2026-05 | 90 |
| 2026-06 | 74 |
| 2026-07 | 90 |
| 2026-08 | 49 |

**Promedio: ~67 por mes.** Estable, sin tendencia.

## 3. El problema real: no hay motivo que describa el caso

`cs.motivos_traslado_mismo_dia` tiene **exactamente dos filas**:

| id | descripción | activo |
|---|---|---|
| 1 | Autorizado por Auditoría Médica | 1 |
| 2 | Autorizado por Supervisión | 1 |

**Ninguno dice «el paciente ya tuvo un traslado espontáneo».** Los dos afirman que alguien autorizó, y en este caso nadie autorizó nada: simplemente hubo un espontáneo antes. El gestor queda con dos salidas, las dos malas:

- **Declarar un motivo que no corresponde** — afirma una autorización que no existe, y contamina el dato que el circuito viene a generar.
- **Pedir la excepción y esperar** al referente o al jefe de siniestros. En un flujo cuya premisa es la urgencia, eso es exactamente lo que no se quiere.

~67 veces por mes.

## 4. Un cuarto dato: el circuito no puede representar un espontáneo

Los **4.814** espontáneos de 2026 tienen **`turnos.id_autorizacion` en NULL** — los 4.814, sin excepción.

El pedido de excepción se guarda contra `id_autorizacion` (es la FK de `autorizaciones_traslado_duplicado`), y `tienePedidoDeExcepcion(null)` devuelve `false` de entrada. Es decir: **el circuito no puede ni registrar un pedido para un espontáneo.**

Hoy no importa, porque el espontáneo no pasa por el gate. Pero deja una trampa: si alguna vez se conecta el gate a ese flujo —por consistencia, o para cerrar el agujero del punto 5— quedaría un **bloqueo sin salida posible**: no hay motivo aplicable, y no hay autorización contra la cual pedir la excepción.

## 5. Y un ajuste a la métrica del change

El `proposal.md` habla de cerrar **~58 casos por mes** de traslado duplicado sin motivo. Esa cifra **no incluye** los duplicados que arrancan con un espontáneo, porque ese camino no pasa por el gate: son **~400 por mes** que van a seguir ocurriendo.

No es un error del diseño —el espontáneo lo carga logística, con criterio propio y en el momento— pero conviene decirlo antes de medir el éxito del circuito contra un número que no puede bajar a cero. Es el mismo tipo de brecha que ya se documentó para `ws-sasconnect`.

---

## Recomendación

**Opción A — agregar un tercer motivo. Es la que recomiendo.**

`IMotivosTrasladosService.findMotivosTrasladoMismoDia()` hace un `findAll()` sobre la tabla y mapea a `EntityDTO(id, descripcion)`. **Sin filtro y sin lógica**: un `INSERT` en `cs.motivos_traslado_mismo_dia` aparece en el combo del drawer sin tocar una línea de código, en los cinco servicios.

```sql
INSERT INTO cs.motivos_traslado_mismo_dia (id_motivo_traslado_mismo_dia, descripcion, activo)
SELECT COALESCE(MAX(id_motivo_traslado_mismo_dia), 0) + 1, 'Traslado espontáneo previo', 1
  FROM cs.motivos_traslado_mismo_dia
 WHERE NOT EXISTS (SELECT 1 FROM cs.motivos_traslado_mismo_dia
                    WHERE descripcion = 'Traslado espontáneo previo');
```

El gestor resuelve en el momento, sin esperar a nadie, y **el dato queda honesto**: el duplicado se registra con su causa real en lugar de disfrazarse de autorización. Riesgo de código: cero. Requiere que negocio apruebe el texto del motivo.

> **De paso, un detalle preexistente:** ese `findAll()` **ignora la columna `activo`**. Un motivo desactivado sigue apareciendo en el combo. No es de esta promoción y no afecta a la opción A —el motivo nuevo nace activo— pero conviene anotarlo.

**Opción B — excluir los espontáneos del conteo.** Agregar `AND COALESCE(t.esEspontaneoAsociado, 0) = 0` a la query. Elimina la fricción por completo, pero **abre un agujero de ~400 casos por mes**: los duplicados que arrancan con un espontáneo dejarían de verse, y varios de esos son justamente los que el circuito quiere detectar. **No la recomiendo sin decisión explícita de negocio.**

**Opción C — dejarlo como está.** Aceptar ~67 casos por mes de fricción y ver cómo se comporta en las primeras semanas. Defendible, pero el costo previsible es que los gestores usen «Autorizado por Supervisión» como comodín, y eso arruina el dato.

---

## Efecto sobre la promoción

**Nada de esto bloquea el merge, pero hay una cosa que conviene corregir antes.**

| punto | qué requiere | ¿antes del merge? |
|---|---|---|
| 1.c — `findTrasladoByTurnoIdTurno` sobre turnos con 2+ traslados | ~~4 líneas en `wsturnos`~~ | **APLICADO** — commit `cf1aa1c` en `promo/INI-2-prod`, ya en la MR !856 |
| 3 — falta el motivo «Traslado espontáneo previo» | un `INSERT`, sin redeploy | No. Puede ir con el script o después |
| 1.a / 1.b — los espontáneos no pasan por el gate | decisión de alcance | No. El alcance declarado del change es `wsturnos` |
| 4 — el circuito no puede representar un espontáneo | nada hoy | No. Es una nota para quien amplíe el gate |
| 5 — la métrica de ~58/mes | corregir el texto del `proposal.md` | No |

### Estado del fix de 1.c

Aplicado y verificado el 24/08/2026:

- `ITrasladoRepository.contarPorTurno(idTurno)` — `SELECT COUNT(t) ... WHERE t.turno.idTurno = :idTurno`, con el javadoc que explica por qué no se usa el método que trae la entidad.
- Los tres usos del validador pasan a `contarPorTurno(...) > 0` (líneas 146, 288 y 333).
- El call site preexistente de `AutorizacionesServiceImpl:1826` **queda como estaba**: necesita la entidad, y su exposición ya venía de `master`.
- `mvn compile` en verde. El path `t.turno.idTurno` es el mismo que ya usa `getAllTrasladosByTurno` en ese repositorio, así que el JPQL resuelve.
- Commit **`cf1aa1c`**, pusheado a `promo/INI-2-prod` — la MR !856 ya lo tiene.

**No cambia ninguna decisión del gate:** la pregunta que hacía el validador —«este turno tiene traslado»— sigue dando la misma respuesta. Lo único que cambia es que deja de romperse cuando hay más de uno.

## Cobertura real del gate — resumen

| Camino de alta | Servicio | ¿Pasa por el gate? |
|---|---|---|
| Drawers de turnos (alta, edición, programación) | `wsturnos` | **Sí** |
| Tanda de rehabilitación | `wsturnos` | **Sí** |
| Generación de autorización | `wsturnos` | **Sí** |
| Entrega de ortopedia | `wstramitador` → `wsturnos` | **Sí** (recibe 409 sin poder resolverlo — ver `medicion-impacto-ortopedia.sql`) |
| **Espontáneo desde CEM** | `wstraslados /traslado/save` | **No** |
| **Espontáneo desde logística** | `wslogistica /guardar-traslado-espontaneo` | **No** |
| Portal de Prestadores | `ws-sasconnect` (JPA directo) | **No** |

Tres caminos fuera del gate. No es un defecto de esta promoción —el alcance del change es `wsturnos`— pero conviene que quede escrito antes de dar el circuito por cerrado.

## Cómo se verificó

- Call sites: `grep` sobre `wsturnos/src/main/java` en la rama `promo/INI-2-prod`.
- Camino del espontáneo de logística: `wslogistica TrasladoServiceImpl:259` y ausencia de referencias a `wsturnos` en ese repo.
- Camino del espontáneo de CEM: `grv-frontend TrasladosDrawer/AmbulanciaIda` → `primeraAsistencia.js:139` → `serverURL.js:80` → `wstraslados TrasladoController:78` → `TrasladoServiceDTOImpl:180 generateTurno(dto)`; y cero referencias al gate en todo `wstraslados/src/main`.
- Conteo del gate: `ITrasladoRepository.contarTrasladosVigentesEnFecha`, JPQL literal.
- Volúmenes: cuatro queries de sólo lectura sobre **producción**, cruzando `traslados.es_espontaneo_asociado` con `turnos`.
- Motivos y su endpoint: `cs.motivos_traslado_mismo_dia` y `wslistados MotivosTrasladosService.findMotivosTrasladoMismoDia()`.

---

*Generado por Vanesa Burman — QA · 22/08/2026*

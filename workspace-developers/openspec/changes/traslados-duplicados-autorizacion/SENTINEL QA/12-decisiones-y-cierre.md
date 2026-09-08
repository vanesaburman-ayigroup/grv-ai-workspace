# Decisiones tomadas y cierre de la jornada — 19/08/2026

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` (INI-2) |
| **Decidido por** | Vanesa Yanina Burman — Líder Técnica |
| **Sobre** | El triage de `10-triage-y-remediacion.md` |

---

## 1. Lo que se aplicó y quedó commiteado

Dos commits, en rama **`fix/INI-2-hallazgos-qa`** de cada repo. **Sin pushear.**

| Repo | Commit | Contenido |
|---|---|---|
| `wsturnos` | `9e74f0e` | A2, A3, A5, C2, C5 |
| `wslogistica` | `e2e9943` | C1 |

### Verificación

| Módulo | Tests | Resultado |
|---|---|---|
| `wsturnos` | 80 | **0 fallas**, `BUILD SUCCESS` |
| `wslogistica` | 47 | **0 fallas**, `BUILD SUCCESS` — y ahora **corren sin flag** |

Los **20 tests de `TrasladoDuplicadoValidatorTest`** son los que cubren A2: pasan, así que el gate
no se rompió.

### Detalle por ítem

**A2 — el pedido que vale es el último.** `tienePedidoDeExcepcion()` pasó de `anyMatch` sobre toda
la lista histórica a `findFirst()` sobre la lista que el repositorio **ya devolvía ordenada
descendente**. De los seis casos posibles del historial de pedidos **cambia uno solo**: aprobado
viejo + rechazo nuevo, que antes pasaba el gate y ahora lo bloquea. Es el agujero de **RF-4.3**.

**A3 — la aprobación no miente.** Los dos bloques de `aprobar()` pasaron de `ifPresent` a un
`isPresent()` con testigo. Si no se pudo aplicar sobre ningún traslado, ahora loguea en `WARN` y
devuelve `noEncontrado` en lugar de `aprobada`. Antes quedaba un pedido APROBADA sin estado de
logística ni marca, **indistinguible del caso correcto** desde cualquier pantalla.

**A5 — el permiso sin id fijo.** El script resolvía `id_permiso = 101` con el comentario «el último
ocupado es el 100»: cierto al escribirlo, falso hoy —el 101 está tomado en PROD por
`editar_cie10_bloqueado` y en DEV por `log_cirugias`—. Ahora toma el próximo libre del ambiente.

> **Error propio detectado y corregido en el camino.** La primera versión del parche agregaba
> `FROM cs.permisos_sas` para poder usar `MAX()`, y eso **rompía la idempotencia**: el `WHERE` se
> evalúa **antes** de la agregación, así que con el permiso ya existente el `WHERE` filtra todas las
> filas, `MAX()` sobre el conjunto vacío da `NULL`, `COALESCE(NULL,0)+1` da **1** — y la consulta
> **devuelve igual una fila**, porque una agregación sin `GROUP BY` siempre devuelve una. En un
> segundo pase habría insertado el permiso otra vez con `id_permiso = 1`. Se resolvió con la
> variable en sentencia aparte, que es la forma que ya tenía el script original. **Queda explicado
> en un comentario del propio script** para que nadie lo «simplifique» de vuelta.

**C1 — los 47 tests de `wslogistica`.** Se sacó `<skipTests>true</skipTests>` del `pom.xml`, previa
verificación de que los 47 pasan. El pipeline declaraba `BUILD SUCCESS` sin ejecutar ninguno.

**C2 — `@Size(max = 1000)`.** En los tres DTO y en la entidad. El caso grave era el del alta: el
pedido se registra dentro de la transacción del turno, así que 1.001 caracteres **revertían turno,
traslado y pedido**, y el gestor perdía el wizard de tres pasos con un 500 crudo de JDBC.

**C5 — parámetro faltante.** Handler de `MissingServletRequestParameterException` en el
`GlobalExceptionHandler`: ahora es 400 y no 500.

### Lo que no se pudo verificar contra base

**La red se cayó al final de la jornada** — DEV, TEST y el MCP de producción dejaron de resolver
DNS. La corrección de A5 se validó **por razonamiento sobre la semántica SQL, no en ejecución**.

> **Acción antes de aplicar en cualquier ambiente:** correr el script en **DEV** y comprobar la
> verificación 4.3, que ahora exige `COUNT(*) = 1`. Correrlo **dos veces** para confirmar la
> idempotencia — es exactamente el caso que estuvo roto.

---

## 2. Decisiones de negocio tomadas

| # | Pregunta | Decisión | Consecuencia |
|---|---|---|---|
| **A1** | La identidad se resuelve del cuerpo del pedido y los endpoints no autentican | **Se deja como está.** `wsturnos` no puede tener JWT todavía | Pasa de bloqueante a **riesgo aceptado con decisión registrada**. Conviene confirmar que en STAGE y PROD queden detrás del gateway |
| **B1** | ¿Cuándo se retira el motivo autodeclarativo? | **Se deja como está** | El gate sigue siendo evitable por ese camino. El circuito conviene con el motivo declarado |
| **B2** | ¿Qué pasa con un pedido que nadie resuelve? | **Etapa 2** | Sin SLA ni alerta por ahora. **Es el riesgo con impacto al asegurado**: si nadie resuelve, el paciente no viaja y se descubre el día del turno |
| **B3** | ¿Cómo se mide si el circuito funciona? | **Etapa 2** — no hace falta medir hoy | La pregunta «¿bajaron los 2.156 casos anuales?» queda sin poder responderse por ahora |
| **B4** | ¿El perfil supervisor autoriza? | **Sí, y también el gerente.** Entran los cuatro: supervisor, referente, jefe y gerente de siniestros | Coincide con lo que **DEV ya tenía aplicado**, así que no hay divergencia que corregir. El script quedó actualizado y la pregunta abierta, cerrada |
| **B5** | ¿Se muestra el número de turno? | **Se corrige el requisito, no el código** | **RF-5.1 enmendado** en el PRD y en la spec de `conflicto-traslado-mismo-dia`. Los hallazgos que reportaban el número de turno en pantalla **quedan sin efecto** |

### Lo único que quedó sin decidir

**A4 — que el rechazo compruebe si la cancelación ocurrió.** `fetchLogisticaOnCancelacion` devuelve
`void`, así que si `wslogistica` falla sin lanzar excepción el pedido queda RECHAZADA y el traslado
sigue **vivo, sin cancelar e invisible para logística**. Costo medio, toca dos servicios. Es el
mismo arreglo que la decisión **D5** ya hizo para la salida «anular el preexistente».

---

## 3. Lo que queda pendiente, por dueño

### Desarrollo

- **A4**, cuando se decida.
- **C3** — el ícono de duplicado autorizado usa `fill="#F29423"`, **el mismo naranja que la leyenda
  asigna a «Requiere revisión»**, y un octógono de advertencia. Debería usar el teal `#0B8F8A` de su
  propia franja y un glifo que no comunique peligro: representa una excepción **concedida**. Es del
  front de logística; conviene que lo valide quien definió la leyenda.
- **C4** — `aria-label` en los botones del `tbody` de la grilla de logística: **9 de 9** sin nombre
  accesible, incluida la acción de **cancelar**.
- **Tests de la máquina de estados.** Es lo transversal: **cuatro de los cinco hallazgos de la
  revisión de código los habría atrapado un test de `aprobar()` y uno de `rechazar()`**.
- **Grupo E** completo, cuando haya margen.

### Documentación del change

- **Grupo D** — siete correcciones. Dos ya hechas (RF-5.1 en el PRD y en la spec). Faltan: los
  huecos H-1/H-2/H-3 que el PRD y el SDD declaran abiertos y **están cerrados**; R-8 y R-21 en el
  SDD; `tasks.md` 10.3 y 7.3; y el motivo 16 en el PRD.
- **D7, el más importante a futuro:** las specs tienen **9 Requirements sin respaldo en el PRD**,
  seis sobre tareas sin hacer. OpenSpec las archiva como especificación canónica, así que si entran
  así van a **afirmar conducta que el sistema no tiene**.
- **C6** — la advertencia de que insertar `autorizaciones` por SQL rompe el alta de turnos de toda
  la base. Pasó en esta sesión.

### QA

- **Lote 2 de automatización**: los 63 casos P2/P3/OBS y los módulos DRS, SEC, INT y RGR.
- **Ejecutar la matriz**, que ahora **sí puede correrse en TEST**.
- **Ajustar los Page Objects** contra el DOM real: se construyeron sobre hipótesis de la matriz.
- **Datos para cerrar R-21**: dos traslados con la marca, uno espontáneo y otro con
  `requiere_revision`, ambos con estado de logística.
- **Configurar el MCP de Qase** — no está registrado y el token está vacío.
- **Revisar el `.gitignore` del repo de QA**: `tests/` y `src/` están ignorados, así que la
  automatización no se versiona.

### Infraestructura

- **La compresión del bundle en DEV**: se sirve sin gzip y se estanca (351 KB en 120 s). Ya provocó
  un fallo de login de cada cuatro. Si no se arregla, las fallas de arranque se van a reportar como
  defectos del producto.
- **`key_generator`** — decidir si se limpian las filas vestigiales (`ID_TURNO` e `ID_TRASLADO`, que
  quedaron desincronizadas porque esas columnas **sí** son `AUTO_INCREMENT`) o si `id_autorizacion`
  se pasa a `AUTO_INCREMENT`. Un `@TableGenerator` sobre tabla compartida es frágil y ya costó una
  caída del alta de turnos.

---

## 4. Antes de pushear

1. **Correr el script de A5 en DEV, dos veces**, y verificar `COUNT(*) = 1`.
2. **Revisar los dos commits** — están en `fix/INI-2-hallazgos-qa` de cada repo, sin pushear.
3. Recordar que **`wslogistica` ahora corre sus tests en el build**: si alguno resulta inestable en
   el runner, el pipeline va a fallar. Es el punto de tener tests, pero conviene verlo con margen.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

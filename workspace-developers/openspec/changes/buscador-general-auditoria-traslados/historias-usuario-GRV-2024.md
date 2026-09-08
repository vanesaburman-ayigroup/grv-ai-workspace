# GRV-2024 — Historias de Usuario (buscador general de Auditoría de Traslados)

> Subtareas de **GRV-2024** en formato HU con criterios de aceptación basados en los specs del change
> (`specs/busqueda-general-traslados/spec.md`). Pensadas para que QA las tome desde el workspace de specs.
> Criterios en formato **Dado / Cuando / Entonces** (Gherkin), trazables a los escenarios del spec.

---

## HU-1 — Búsqueda general server-side (SP unificado + índice)

**Contexto.** Hoy el buscador filtra en el cliente sobre las filas ya traídas en la página visible, así que "esconde" resultados que existen pero están en otra página, y el total no refleja la búsqueda. Se reemplaza por una búsqueda en backend dentro del SP unificado `consulta_traslados_unificada_sp` (modelo GRV-1794), sobre su tabla temporal `tmp_traslados`, antes del `COUNT`, por pestaña (`auditada` 0/1/2). Se agrega además un índice compuesto `(fecha_traslado, id_estado_traslado)` para que las ventanas de período anchas no degraden (medido: 1 mes ~0,68s, 1 año ~14s antes del índice).

**Historia.** Como **auditor de traslados**, quiero que el buscador busque sobre **todo el universo del período** (no solo la página cargada), para encontrar cualquier traslado sin tener que paginar ni filtrar antes.

**Criterios de aceptación.**
- **Dado** un término que coincide con una fila que no está en la página visible, **Cuando** busco, **Entonces** el resultado la incluye y el total se recalcula a la cantidad real de coincidencias.
- **Dado** que no apliqué ningún filtro previo, **Cuando** escribo un término, **Entonces** la búsqueda corre sobre el universo del período por defecto.
- **Dado** la pestaña activa, **Entonces** la búsqueda evalúa **solo las columnas visibles** de esa pestaña: No Auditados (nro traslado, denuncia, paciente, dni, fecha, proveedor, direcciones, estado), Auditados (+ factura, monto, responsable), Desimputados (denuncia, paciente, dni, factura, monto, fecha/responsable de desimputación; sin nro traslado).
- **Dado** un término "perez", **Cuando** existe "Pérez" o "PEREZ", **Entonces** la fila aparece (insensible a mayúsculas y acentos).
- **Dado** un término con `%` o `_`, **Entonces** se tratan como texto literal (no matchean todo).
- **Dado** un término vacío/nulo, **Entonces** el resultado es idéntico a no buscar.
- **(Performance)** **Dado** un período anual con el índice aplicado, **Entonces** el tiempo de respuesta mejora respecto del baseline sin índice (validar con `ANALYZE`).

**Notas técnicas.** SP unificado (005), `DELETE FROM tmp_traslados` por `auditada`, `COLLATE utf8mb4_general_ci`, escape de `\ % _` + `ESCAPE '\\'`. Migración `GRV-2024.sql` (índice idempotente `ADD INDEX IF NOT EXISTS`, `ALGORITHM=INPLACE, LOCK=NONE`). Desimputados (`auditada=2`) viaja por el mismo SP. Los 2 SP legacy quedan fuera de alcance (volumen marginal). _Spec: "Búsqueda... universo completo", "solo campos visibles", "insensible a mayúsculas y acentos"._

---

## HU-2 — Estrategia de búsqueda transportable (provider) + contrato

**Contexto.** Para que la solución sea transportable a otras pantallas/módulos y permita enchufar otra estrategia (p. ej. cache) sin reescribir, la búsqueda queda detrás de la interfaz `TrasladosSearchProvider` (patrón Strategy), seleccionable por configuración. El término viaja como campo `busquedaGeneral` del request, opcional (no rompe el contrato).

**Historia.** Como **desarrollador del ecosistema**, quiero que la estrategia de búsqueda esté detrás de una interfaz seleccionable por configuración, para cambiar la implementación (o llevar el patrón a otra pantalla) sin tocar el controller ni el front.

**Criterios de aceptación.**
- **Dado** `traslados.search.provider=direct` (o ausente), **Entonces** se usa la implementación directa (SP). **Cuando** se selecciona otra implementación por configuración, **Entonces** controller y front no cambian.
- **Dado** que se agrega una columna visible a una pestaña, **Entonces** habilitar su búsqueda requiere solo una línea en la rama del SP y un `<Highlight>` en esa columna.
- **Dado** un request sin `busquedaGeneral`, **Entonces** el endpoint responde igual que antes (campo opcional, backward-compatible).

**Notas técnicas.** `TrasladosSearchProvider` + `DirectSearchProvider` (`@ConditionalOnProperty matchIfMissing=true`); `findAllTraslados` delega en el provider; `busquedaGeneral` en `ObtenerTrasladoFiltrosDTO` y `ObtenerDesimputadosFiltrosDTO`. _Spec: "Estrategia de búsqueda transportable detrás de una interfaz"._

---

## HU-3 — Buscador server-side en el front (aplicación por submit)

**Contexto.** El front deja de filtrar en memoria. Como la pantalla ya tiene botón **Filtrar**, la búsqueda se aplica con acción explícita (botón o Enter), igual que el resto de los filtros — sin disparar mientras se tipea.

**Historia.** Como **auditor**, quiero aplicar la búsqueda con el botón Filtrar (o Enter), para controlar cuándo se ejecuta, igual que los demás filtros.

**Criterios de aceptación.**
- **Dado** que estoy escribiendo el término, **Entonces** no se dispara ninguna búsqueda al backend hasta una acción explícita.
- **Dado** que presiono "Filtrar" (o Enter en el campo), **Entonces** la búsqueda se ejecuta una vez, con `offset` reseteado a 0, y junto con los demás filtros del formulario.
- **Dado** que limpio los filtros, **Entonces** el término de búsqueda también se limpia (no queda `busquedaGeneral` viejo en el estado).

**Notas técnicas.** Hook `useBusquedaBackend` (modo `submit`, y modo `debounced` 600ms para pantallas sin botón). Tipo `busquedaGeneral: string | null` requerido en el estado. _Spec: "La búsqueda se aplica por acción explícita"._

---

## HU-4 — Resaltado de coincidencias en pantalla (Highlight)

**Contexto.** Para que el auditor vea por qué cada fila coincidió, se resaltan en amarillo las ocurrencias del término, solo en las columnas visibles de la pestaña activa (mismo set que el filtro del backend: invariante de oro).

**Historia.** Como **auditor**, quiero ver resaltado dónde coincide mi búsqueda en cada fila, para ubicar la coincidencia de un vistazo.

**Criterios de aceptación.**
- **Dado** un resultado con el término en un campo visible (p. ej. "CH484768"), **Entonces** la subcadena coincidente se muestra con fondo amarillo dentro de la celda.
- **Dado** un término "perez" y el texto "Pérez", **Entonces** se resalta sobre el texto original (conservando la tilde).
- **Dado** un término con caracteres especiales (`(`, `.`, `*`), **Entonces** el resaltado no rompe ni produce error.
- **Dado** que no hay término activo, **Entonces** las celdas se muestran sin ninguna marca.

**Notas técnicas.** Componente `Highlight` reutilizable (regex escapada, normalización NFD acento-insensible, `React.memo`). Aplicado por columna visible de cada pestaña. _Spec: "Resaltado de coincidencias en pantalla"._

---

## HU-5 — Sin parpadeo de la grilla durante la carga (fix del "flash")

**Contexto.** Bug aparte detectado: al disparar una consulta, la grilla se vacía y muestra el mensaje de "sin resultados" durante la carga, generando un parpadeo confuso. Se corrige conservando las filas previas y mostrando el overlay de carga.

**Historia.** Como **auditor**, quiero que la grilla no muestre "sin resultados" mientras está cargando, para no creer que no hay datos cuando en realidad están viniendo.

**Criterios de aceptación.**
- **Dado** que una consulta está en curso (cargando), **Entonces** la tabla mantiene las filas anteriores y muestra el overlay/spinner de carga.
- **Dado** que la consulta está en curso, **Entonces** NO se muestra el mensaje de tabla vacía / "sin resultados".
- **Dado** que llega la respuesta, **Entonces** la tabla se actualiza con el nuevo resultado.

**Notas técnicas.** En `AuditoriaTraslado.tsx`, actualizar `data` solo al llegar la respuesta (no vaciar durante `isFetching`); el overlay lo da la prop `loading`. Aplica a la grilla y a desimputados. _Spec: "Sin parpadeo de la tabla durante la carga"._

---

## HU-6 — Verificación QA (E2E de las 3 pestañas)

**Contexto.** Suite de aceptación end-to-end que valida el comportamiento completo en las 3 pestañas, incluyendo los casos límite de los specs.

**Historia.** Como **QA**, quiero un conjunto de casos E2E sobre las 3 pestañas, para certificar el buscador antes de release.

**Criterios de aceptación (casos de prueba).**
- Búsqueda por **denuncia**, **dni**, **paciente**, **proveedor** y **fecha** en No Auditados → devuelve y resalta solo esas columnas; factura/monto NO participan.
- Búsqueda por **factura** y **monto** en Auditados y en Desimputados → devuelve y resalta.
- Búsqueda con **tilde y sin tilde**, **mayúsculas y minúsculas** → mismos resultados.
- Búsqueda con `%` y `_` → no devuelve "todo"; trata literal.
- Término **vacío** → igual que sin búsqueda; total correcto.
- **Paginación**: el total y la cantidad de páginas reflejan la búsqueda (no el universo sin filtrar).
- **No flash**: al filtrar/buscar, la grilla no parpadea a "sin resultados".
- **Performance**: ventana ancha (1 año) responde en tiempo aceptable post-índice (`ANALYZE` de evidencia).

**Notas técnicas.** Verificación del SP en réplica/staging (el MCP read-only no ejecuta DDL/`ANALYZE`). Front cubierto por tests de `Highlight` y `useBusquedaBackend` (unitarios) + esta suite E2E manual/automatizada. _Spec: todos los escenarios de `busqueda-general-traslados`._

---

## HU-7 — El término de búsqueda se conserva al cambiar de pestaña

**Contexto.** Se detectó una inconsistencia: al cambiar de pestaña (No Auditados / Auditados / Desimputados) la búsqueda **seguía aplicada** (el listado se mostraba filtrado por el término), pero el **campo de texto del buscador quedaba vacío**. El auditor veía resultados filtrados sin entender por qué, y no tenía a la vista el término que estaba buscando. El campo de "apellido / filtros estructurales" sí conservaba su valor; solo el buscador general se limpiaba. Se corrige para que el campo y el filtro queden siempre alineados.

**Historia.** Como **auditor de traslados**, quiero que el término que escribí en el buscador siga visible en el campo cuando cambio de pestaña, para entender por qué el listado está filtrado y poder editar o limpiar la búsqueda con claridad.

**Criterios de aceptación.**
- **Dado** que busqué un término en una pestaña y obtuve resultados filtrados, **Cuando** cambio a otra pestaña, **Entonces** el campo del buscador sigue mostrando el mismo término y el listado de la nueva pestaña aparece filtrado por ese término.
- **Dado** que cambié de pestaña con un término activo, **Entonces** el resaltado de coincidencias se muestra sobre las columnas visibles de la nueva pestaña (según la matriz de la HU-1).
- **Dado** que limpio el buscador (o uso "Limpiar filtros"), **Entonces** el campo queda vacío en todas las pestañas y el listado vuelve al universo sin búsqueda.
- **Dado** que el campo del buscador muestra un término, **Entonces** ese término es siempre el que se está aplicando al listado (nunca un campo vacío con un filtro activo por detrás, ni un campo con texto que no se aplicó).

---

## HU-8 — Ubicación del buscador general y de los botones de filtro

**Contexto.** Ajuste de disposición de la pantalla: el buscador general y los botones **"Limpiar filtros"** y **"Aplicar filtros"** quedan en la **misma fila inferior** del bloque de filtros, de modo que los botones abarquen también al buscador general (y no solo a los filtros estructurales de arriba). Así queda visualmente claro que "Aplicar filtros" ejecuta también la búsqueda escrita.

**Historia.** Como **auditor**, quiero que el buscador general y los botones de filtro estén alineados en la misma zona, para entender de un vistazo que al aplicar filtros también se ejecuta lo que escribí en el buscador.

**Criterios de aceptación.**
- **Dado** el bloque de filtros, **Entonces** el buscador general aparece en la fila inferior, a la misma altura que los botones "Limpiar filtros" y "Aplicar filtros".
- **Dado** que escribo un término en el buscador y presiono "Aplicar filtros", **Entonces** la búsqueda se ejecuta junto con los demás filtros (consistente con la HU-3).
- **Dado** que presiono "Limpiar filtros", **Entonces** se limpian tanto los filtros estructurales como el término del buscador general.

---

## Matriz de columnas buscables y resaltadas por pestaña

> El conjunto de columnas **buscables** (backend) y **resaltadas** (pantalla) es el mismo en cada pestaña (invariante de la HU-1/HU-4). Esta tabla es la referencia única para QA.

| Columna visible | No Auditados | Auditados | Desimputados |
|---|:---:|:---:|:---:|
| Nº de traslado | ✅ | ✅ | — (no visible) |
| Fecha / hora del traslado | ✅ | ✅ | ✅ (fecha desimputación) |
| Nº de denuncia | ✅ | ✅ | ✅ |
| Paciente | ✅ | ✅ | ✅ |
| DNI | ✅ | ✅ | ✅ |
| Proveedor / prestador (ida / vuelta) | ✅ | ✅ | — |
| Direcciones (origen / destino) | ✅ | — | — |
| Estado | ✅ | — | — |
| Nº de factura (ida / vuelta) | — | ✅ | ✅ |
| Monto (ida / vuelta) | — | ✅ | ✅ |
| Responsable de auditoría / desimputación | — | ✅ | ✅ |

> Los datos que solo aparecen en el detalle/drawer (observaciones internas, localidad del tramo, etc.) **no** son buscables ni se resaltan.

---

## Matriz consolidada de casos de prueba para QA

| # | Caso | Pestaña(s) | Resultado esperado |
|---|---|---|---|
| CP-01 | Buscar por Nº de denuncia | Las 3 | Devuelve y resalta solo filas con esa denuncia; total recalculado |
| CP-02 | Buscar por DNI | Las 3 | Devuelve y resalta por DNI |
| CP-03 | Buscar por paciente | Las 3 | Devuelve y resalta por nombre/apellido |
| CP-04 | Buscar por proveedor | No Aud. / Aud. | Devuelve y resalta por prestador |
| CP-05 | Buscar por **fecha / hora** | Las 3 | Devuelve y **resalta la fecha/hora** (columna nueva resaltada) |
| CP-06 | Buscar por **monto** | Aud. / Desimp. | Devuelve y **resalta el monto** (columna nueva resaltada) |
| CP-07 | Buscar por Nº de factura | Aud. / Desimp. | Devuelve y resalta por factura |
| CP-08 | Buscar campo que solo está en el detalle/drawer | Las 3 | NO devuelve la fila (fuera del alcance del buscador) |
| CP-09 | Buscar con tilde vs sin tilde ("perez" / "Pérez") | Las 3 | Mismos resultados; resalta sobre el texto original |
| CP-10 | Buscar en MAYÚSCULAS vs minúsculas | Las 3 | Mismos resultados |
| CP-11 | Buscar usando `%` o `_` | Las 3 | Se tratan como texto literal; no devuelve "todo" |
| CP-12 | Término vacío / solo espacios | Las 3 | Igual que sin búsqueda; total correcto |
| CP-13 | Coincidencia en página no visible | Las 3 | La fila aparece igual; el total refleja el universo, no la página |
| CP-14 | Paginación con búsqueda activa | Las 3 | Total y cantidad de páginas reflejan la búsqueda |
| CP-15 | No flash al filtrar/buscar | Las 3 | La grilla no parpadea a "sin resultados" mientras carga |
| CP-16 | **Cambiar de pestaña con un término activo** | Las 3 | El campo conserva el término y el listado de la nueva pestaña queda filtrado y resaltado (HU-7) |
| CP-17 | **Limpiar filtros con término activo** | Las 3 | Se limpian filtros y término; el campo del buscador queda vacío |
| CP-18 | **Aplicar filtros con término escrito** | Las 3 | La búsqueda se ejecuta junto con los demás filtros desde la fila inferior (HU-8) |
| CP-19 | Performance: ventana de 1 año | No Aud. | Tiempo de respuesta aceptable con el índice aplicado |

# PRD — Buscador general de Auditoría de Traslados (GRV-2024)

| | |
|---|---|
| **Producto / Módulo** | Auditoría de Traslados (auditoría de facturación) |
| **Épica / Ticket** | GRV-2024 |
| **Estado** | Listo para QA |
| **Documentos relacionados** | `proposal.md` (resumen de cambio) · `design.md` (diseño técnico / SDD) · `historias-usuario-GRV-2024.md` (HU para QA) · `specs/busqueda-general-traslados/spec.md` |
| **Última actualización** | 18/06/2026 |
| **Responsables** | Vanesa Burman · Yanina Di Prima |

---

## 1. Objetivo

Que el auditor pueda encontrar **cualquier traslado del período** desde un único buscador, sin tener que paginar ni aplicar filtros antes, con el total y la paginación reflejando exactamente lo que buscó, y viendo **resaltado** dónde coincidió su término.

## 2. Contexto y problema

Hoy el buscador filtra **del lado del cliente**, solo sobre las filas ya cargadas en la página visible. Esto genera dos problemas:

- **Esconde resultados**: una coincidencia que existe pero está en otra página no aparece, y el auditor cree que "no hay".
- **Total y paginación engañosos**: el contador no refleja la búsqueda; el negocio cree que busca sobre todo el universo cuando en realidad solo refina la página actual.

Además se detectaron dos inconsistencias de experiencia: el listado quedaba con un mensaje de "sin resultados" parpadeando mientras cargaba, y al cambiar de pestaña el filtro seguía aplicado pero el campo del buscador se vaciaba.

## 3. Usuarios

- **Auditor de traslados** (usuario principal): busca y audita traslados de las pestañas No Auditados, Auditados y Desimputados.
- **QA**: certifica el comportamiento antes del release.

## 4. Alcance

**Incluye:**
- Búsqueda sobre **todo el universo del período** (no solo la página visible), resuelta del lado del servidor.
- **Total exacto** de coincidencias y paginación coherente con la búsqueda.
- Búsqueda **por pestaña**, evaluando únicamente las **columnas visibles** de cada una.
- **Resaltado** (marca amarilla) de las coincidencias en las columnas visibles, incluyendo **fecha/hora** y **monto**.
- Búsqueda **insensible a mayúsculas y acentos**; los caracteres `%` y `_` se tratan como texto literal.
- Aplicación **por acción explícita** (botón "Aplicar filtros" o Enter), consistente con el resto de los filtros.
- **Persistencia del término** al cambiar de pestaña (campo y filtro siempre alineados).
- **Ubicación** del buscador en la misma fila inferior que los botones "Limpiar / Aplicar filtros".
- Corrección del **parpadeo** de la grilla durante la carga.

**No incluye (fuera de esta entrega):**
- Aceleración por capa de caché del universo (diseñada pero no implementada; queda para una fase 2).
- Búsqueda sobre datos que solo aparecen en el detalle/drawer (observaciones internas, localidad del tramo, etc.).

## 5. Requisitos funcionales

| ID | Requisito | Detalle |
|---|---|---|
| RF-1 | Búsqueda sobre el universo del período | El término busca sobre todo el período acotado por los filtros estructurales, no sobre la página cargada. |
| RF-2 | Total exacto | El total y la cantidad de páginas reflejan la búsqueda. |
| RF-3 | Búsqueda por columnas visibles de la pestaña | Ver matriz en la sección 7. |
| RF-4 | Resaltado de coincidencias | Marca amarilla sobre la subcadena coincidente, incluyendo fecha/hora y monto. |
| RF-5 | Insensible a mayúsculas y acentos | "perez" encuentra "Pérez" / "PEREZ". |
| RF-6 | Wildcards literales | `%` y `_` no devuelven "todo"; se tratan como texto. |
| RF-7 | Término vacío = no buscar | Vacío o solo espacios equivale a no aplicar búsqueda. |
| RF-8 | Aplicación por acción explícita | Se ejecuta con "Aplicar filtros" o Enter; no mientras se tipea. |
| RF-9 | Persistencia entre pestañas | Al cambiar de pestaña el término permanece en el campo y el listado queda filtrado y resaltado. |
| RF-10 | Limpiar incluye el término | "Limpiar filtros" vacía también el buscador. |
| RF-11 | Sin parpadeo | La grilla conserva las filas anteriores y muestra el indicador de carga, sin mostrar "sin resultados". |
| RF-12 | Ubicación del buscador | El buscador y los botones "Limpiar / Aplicar filtros" quedan en la misma zona inferior. |

> El detalle en formato Historia de Usuario (Dado/Cuando/Entonces) está en `historias-usuario-GRV-2024.md` (HU-1 a HU-8).

## 6. Requisito no funcional — rendimiento

- En ventanas de período anchas (hasta 1 año) el tiempo de respuesta debe mantenerse **aceptable**; se incorporó una optimización de índice para que las ventanas grandes no degraden (baseline previo: ~14 s para 1 año; objetivo: reducción significativa, validada con evidencia).

## 7. Matriz de columnas buscables y resaltadas por pestaña

> Las columnas **buscables** y **resaltadas** son siempre el mismo conjunto en cada pestaña.

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

> Los datos que solo aparecen en el detalle/drawer no son buscables ni se resaltan.

## 8. Criterios de aceptación / casos de prueba (QA)

| # | Caso | Pestaña(s) | Resultado esperado |
|---|---|---|---|
| CP-01 | Buscar por Nº de denuncia | Las 3 | Devuelve y resalta solo filas con esa denuncia; total recalculado |
| CP-02 | Buscar por DNI | Las 3 | Devuelve y resalta por DNI |
| CP-03 | Buscar por paciente | Las 3 | Devuelve y resalta por nombre/apellido |
| CP-04 | Buscar por proveedor | No Aud. / Aud. | Devuelve y resalta por prestador |
| CP-05 | Buscar por fecha / hora | Las 3 | Devuelve y resalta la fecha/hora |
| CP-06 | Buscar por monto | Aud. / Desimp. | Devuelve y resalta el monto |
| CP-07 | Buscar por Nº de factura | Aud. / Desimp. | Devuelve y resalta por factura |
| CP-08 | Buscar campo que solo está en el detalle | Las 3 | NO devuelve la fila |
| CP-09 | Tilde vs sin tilde ("perez" / "Pérez") | Las 3 | Mismos resultados; resalta sobre el texto original |
| CP-10 | MAYÚSCULAS vs minúsculas | Las 3 | Mismos resultados |
| CP-11 | Usar `%` o `_` | Las 3 | Texto literal; no devuelve "todo" |
| CP-12 | Término vacío / solo espacios | Las 3 | Igual que sin búsqueda; total correcto |
| CP-13 | Coincidencia en página no visible | Las 3 | La fila aparece igual; el total refleja el universo |
| CP-14 | Paginación con búsqueda activa | Las 3 | Total y páginas reflejan la búsqueda |
| CP-15 | No flash al filtrar/buscar | Las 3 | La grilla no parpadea a "sin resultados" |
| CP-16 | Cambiar de pestaña con término activo | Las 3 | El campo conserva el término; el listado nuevo queda filtrado y resaltado |
| CP-17 | Limpiar filtros con término activo | Las 3 | Se limpian filtros y término |
| CP-18 | Aplicar filtros con término escrito | Las 3 | La búsqueda se ejecuta junto con los demás filtros |
| CP-19 | Ventana de 1 año (performance) | No Aud. | Tiempo de respuesta aceptable con el índice aplicado |

## 9. Supuestos y dependencias

- El comportamiento del buscador depende de los filtros estructurales del período ya existentes (fecha, estado, prestador, etc.).
- La pestaña Desimputados se resuelve por el mismo mecanismo unificado.
- La verificación de rendimiento sobre ventanas anchas se valida en réplica/staging.

## 10. Métrica de aporte IA vs intervención humana

> Estimación cualitativa del tramo de trabajo de este desarrollo.

| | | |
|---|---|---|
| 🤖 | **Ejecución automatizada (IA)** | **~85%** · redacción de PRD/HU/spec, contrato OpenAPI, colección Bruno, análisis del comportamiento, casos de prueba |
| 🧑‍💻 | **Decisiones / presencia humana** | **~100% de las decisiones** · alcance, reglas de negocio (qué columnas buscan por pestaña), detección de inconsistencias reportadas, validación en pantalla |
| ⚖️ | **Balance** | ✅ sano · las decisiones de negocio y la validación fueron humanas; la ejecución y la documentación, asistidas |

## Why

El buscador general de la pantalla de **Auditoría de Traslados** (MFE `auditoriafacturacion`) hoy filtra **del lado del cliente**, en memoria, sobre las filas ya traídas en la página visible (`hook/useBusquedaGeneral.ts`). Eso produce dos problemas: (1) el negocio cree que busca sobre todo el universo cuando en realidad solo refina la página actual, y (2) anda mal (resultados inconsistentes, "flash" de tabla vacía mientras carga). Auditoría no puede operar con un buscador que esconde resultados que existen pero no están en la página cargada.

La solución debe **buscar en backend, sobre el universo completo ya acotado por los filtros estructurales** (período/estado/prestador), sin exigir haber filtrado antes, devolviendo el total correcto para que la paginación sea exacta. Debe resaltar (marca amarilla) las coincidencias **solo en los campos visibles de cada pestaña** (no en los campos del detalle/drawer), ser **escalable** (agregar una columna a la pantalla = agregar una línea al mapeo) y **transportable** a otras pantallas y módulos cambiando el endpoint.

## What Changes

- **BREAKING (contrato de búsqueda):** el término de búsqueda deja de resolverse en el front y pasa a viajar al backend como filtro `busquedaGeneral` dentro del request del grid. El front ya no filtra en memoria.
- Se agrega el campo `busquedaGeneral` al request `ObtenerTrasladoFiltrosDTO` y al `filtersSlice` del front.
- El **SP unificado `consulta_traslados_unificada_sp`** (modelo GRV-1794) aplica el término como filtro sobre su tabla temporal `tmp_traslados`, **antes del `COUNT(*)`**, de modo que el total refleje la búsqueda. El filtro mapea **solo las columnas visibles según la pestaña** (`auditada` 0/1/2), con escape de wildcards y `COLLATE utf8mb4_general_ci`. (Los 2 SP legacy quedan fuera de alcance; los 3 SP pre-GRV-1794 están muertos.)
- La pestaña **Desimputados** en develop se resuelve por el mismo SP unificado con `auditada=2`; solo se modifica `buildDesimputadosSpRequest` para que **propague `busquedaGeneral`**.
- La estrategia de búsqueda queda detrás de una **interfaz `TrasladosSearchProvider`** (patrón Strategy) con una implementación directa por defecto, para que sea intercambiable por configuración y **transportable** a otros módulos.
- En el front se reemplaza `useBusquedaGeneral` (memoria) por un hook genérico `useBusquedaBackend` (debounce → setea `busquedaGeneral` + `offset:0` → refetch), se corrige el "flash" de tabla vacía, y se agrega un componente reutilizable `Highlight` que resalta las coincidencias en las columnas visibles de cada pestaña.
- El **resaltado** se completa sobre las columnas de **fecha/hora** (No Auditados y Auditados) y **monto** (Auditados y Desimputados), quedando alineado con el set de campos buscables de cada pestaña.
- Se corrige una inconsistencia de UX: al cambiar de pestaña, el **término de búsqueda se conserva** en el campo (antes el filtro seguía aplicado pero el campo quedaba vacío). El campo y el filtro quedan siempre alineados.
- Se reubica el **buscador general** en la misma fila inferior que los botones "Limpiar filtros" / "Aplicar filtros", de modo que aplicar/limpiar abarque también la búsqueda escrita.
- **Fuera de la primera entrega (Fase 2, diseñada pero no implementada):** capa de cache del universo con invalidación por contador de generación (mono-instancia, Caffeine) para atacar el costo real de construir la tabla temporal. Se documenta el diseño y queda detrás de la misma interfaz.

## Capabilities

### New Capabilities
- `busqueda-general-traslados`: búsqueda general server-side de la pantalla de auditoría de traslados — filtra el universo completo por pestaña, devuelve total exacto, resalta solo campos visibles, y queda detrás de una interfaz transportable a otros módulos.
- `cache-universo-traslados`: (Fase 2, diseño) cache del universo de traslados con invalidación instantánea por evento de auditoría, sin ventana de datos viejos, para acelerar la construcción de la consulta base.

### Modified Capabilities
<!-- No hay specs canónicas previas en openspec/specs/ para estas capacidades. -->

## Impact

**Backend** (`repos/grvx/backend/wsauditoriatraslados`):
- `dto/request/ObtenerTrasladoFiltrosDTO.java` — nuevo campo `busquedaGeneral`.
- `serviceDTO/search/TrasladosSearchProvider.java` (+ `DirectSearchProvider`) — nueva interfaz/estrategia.
- `serviceDTO/TrasladosServiceDTOImpl.java` — `findAllTraslados` delega en el provider; `findAllDesimputados*` aplica el término en su filtro Java.
- `resources/sql/consulta_traslados_internos_auditoria_sp.sql`, `consulta_traslados_remis_ambulancia_sp.sql`, `consulta_traslados_transporte_publico_sp.sql` — bloque de filtro de búsqueda por pestaña (migración DDL, un script por PR).

**Frontend** (`repos/grvx/frontend/auditoriafacturacion/.../grv-auditoria-facturacion`):
- `redux/slices/filtersSlice.ts` — campo `busquedaGeneral`.
- `hook/useBusquedaBackend.ts` (nuevo) + deprecación de `useBusquedaGeneral.ts`.
- `components/commons/Highlight/Highlight.tsx` (nuevo).
- `pages/AuditoriaTraslado.tsx` — fix del "flash" + wiring del hook.
- `components/AuditoriaTraslado/Tablas/{NoAuditados,Auditados,Desimputados}.tsx` — `Highlight` por columna visible.

**Base de datos** (esquema `cs`): solo cambian los 3 stored procedures (sin DDL de tablas). Tablas grandes involucradas vía vistas: `turnos` (~4.4M), `traslados` (~1.47M), `denuncias` (~450k). Sin nuevas dependencias en Fase 1; Caffeine solo en Fase 2.

**Sin cambios de API pública:** el endpoint `POST /traslado` mantiene su contrato; `busquedaGeneral` es un campo opcional del body.

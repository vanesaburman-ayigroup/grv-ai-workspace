## 1. Backend — contrato y estrategia

- [x] 1.1 Agregar el campo `busquedaGeneral` (String, opcional, con `@ApiModelProperty`) a `dto/request/ObtenerTrasladoFiltrosDTO.java`
- [x] 1.2 Agregar el campo `busquedaGeneral` a `dto/request/ObtenerDesimputadosFiltrosDTO.java`
- [x] 1.3 Crear la interfaz `serviceDTO/search/TrasladosSearchProvider.java` con `FindAllResults<ObtenerTrasladosResponseDTO> buscar(ObtenerTrasladoFiltrosDTO)`
- [x] 1.4 Crear `DirectSearchProvider` (`@ConditionalOnProperty(name="traslados.search.provider", havingValue="direct", matchIfMissing=true)`) que serializa filtros y delega en `ITrasladosService.findAllByTipoTransporte`
- [x] 1.5 Hacer que `TrasladosServiceDTOImpl.findAllTraslados` delegue en `trasladosSearchProvider.buscar(request)` y quitar los imports de Jackson que queden sin uso

## 2. Backend — SP unificado + Desimputados (migración DDL)

- [x] 2.1 `consulta_traslados_unificada_sp` (005): `DECLARE`/`SET` de `busquedaGeneral` + **escape de wildcards** (`\` `%` `_`) + bloque `DELETE FROM tmp_traslados WHERE NOT (...)` por pestaña (`auditada` 0/1/2, esta última = Desimputados), antes del `SELECT COUNT(*)`, con `COLLATE utf8mb4_general_ci` y `ESCAPE '\\'`
- [x] 2.2 **Desimputados**: `buildDesimputadosSpRequest` propaga `busquedaGeneral` (desimputados va por el unificado con `auditada=2`; SIN filtro Java in-memory). No tocar los 3 SP pre-GRV-1794 (muertos) ni los 2 SP legacy (fuera de alcance)
- [x] 2.3 `GRV-2024.sql`: índice compuesto `idx_traslados_fecha_estado (fecha_traslado, id_estado_traslado)` idempotente (`ADD INDEX IF NOT EXISTS`, `ALGORITHM=INPLACE, LOCK=NONE`) + evaluar drop del redundante `idx_traslados_fecha` (comentado). Nota: el índice acelera la rama remis del unificado; internos/TP usan otras tablas
- [x] 2.4 Revisar el SQL con el skill `mariadb-migration-review`
- [ ] 2.5 Ejecutar en la réplica read-only (MCP) y verificar: (a) total y filas reflejan la búsqueda por pestaña (0/1/2); (b) coincidencia con/sin tilde y mayúsculas; (c) `ANALYZE` post-índice de ventana ancha confirma mejora

## 4. Frontend — estado y hook

- [x] 4.1 Agregar `busquedaGeneral: null` al estado `traslados` de `redux/slices/filtersSlice.ts` (y al reset)
- [x] 4.2 Crear `hook/useBusquedaBackend.ts` genérico con modo `submit` (sin auto-fire) y modo `debounced` (retardo amplio 600ms para pantallas sin botón Filtrar); exportarlo desde `hook/index`
- [x] 4.3 Reemplazar `useBusquedaGeneral` por `useBusquedaBackend` en modo `submit` en `pages/AuditoriaTraslado.tsx`; pasar `searchTerm` a `TabsTraslados`
- [x] 4.4 Incorporar el término al submit de filtros: incluir `busquedaGeneral` en `FiltrosTraslados.handleSearch` (botón "Filtrar") y disparar también con Enter en el campo de búsqueda; resetear `offset:0`. NO auto-disparar mientras se tipea
- [x] 4.5 Asegurar que el request del grid incluye `busquedaGeneral` (`...filters`) en las 3 pestañas
- [x] 4.6 Deprecar `hook/useBusquedaGeneral.ts` si ningún otro módulo lo usa con lógica de memoria

## 5. Frontend — resaltado y fix del flash

- [x] 5.1 Crear el componente reutilizable `components/commons/Highlight/Highlight.tsx` (regex escapada, case- y acento-insensible vía normalización NFD; resalta sobre el texto original con tildes; `<mark>` amarillo)
- [x] 5.2 Corregir el "flash": en `AuditoriaTraslado.tsx` actualizar `data` solo al llegar la respuesta (no `setData([])` en `isFetching`)
- [x] 5.3 Envolver con `<Highlight>` las columnas visibles de `NoAuditados.tsx` (proveedor/direcciones/estado; NO factura ni monto)
- [x] 5.4 Envolver con `<Highlight>` las columnas visibles de `Auditados.tsx` (factura/monto/responsable)
- [x] 5.5 Envolver con `<Highlight>` las columnas visibles de `Desimputados.tsx` (factura/monto/desimputación; SIN nro traslado)
- [x] 5.6 Verificar el invariante de oro: set de columnas con `<Highlight>` = set de campos del `LIKE`/filtro de esa pestaña

## 6. Pruebas y verificación

- [ ] 6.1 Backend: N/A — el repo no tiene infra de tests (sin `src/test`/JUnit) y la búsqueda principal vive en SQL; se verifica por réplica/staging (2.6). No se introduce framework de test fuera de scope.
- [ ] 6.2 Backend: test de que cada pestaña busca solo sus campos visibles (no factura en No Auditados, etc.)
- [ ] 6.3 Backend: test de que término vacío/nulo equivale a no buscar
- [ ] 6.4 Backend: test de coincidencia case- y acento-insensible (busca "perez" → encuentra "Pérez"/"PEREZ")
- [x] 6.5 Frontend: test del hook `useBusquedaBackend` modo `submit` (no dispara al tipear, sí al confirmar; reset de offset) y test de integración MSW del flujo búsqueda + resaltado
- [ ] 6.6 Frontend: test de que no hay flash de tabla vacía durante la carga
- [ ] 6.7 Verificación E2E manual en STAGE de las 3 pestañas con términos representativos (denuncia, dni, monto, factura, proveedor)

## 7. Documentación y cierre

- [ ] 7.1 Documentar la deuda de paginación cross-SP y el plan de Fase 2 (cache, opcional) en el runbook del caso; registrar el resultado del `ANALYZE` post-índice
- [ ] 7.2 `mr-comments` para los MR de backend y frontend, con link cruzado entre ambos

## Context

La pantalla de Auditoría de Traslados vive en el MFE `auditoriafacturacion` (React 18 + Redux Toolkit Query + `sas-component-lib` 4.0.1) y consume el endpoint `POST /traslado` de `wsauditoriatraslados` (Spring Boot 2.x, Java 11, MariaDB, esquema `cs`).

> **Corrección de base (importante).** El análisis inicial se hizo sobre un `master` local desactualizado (42 commits viejo, **pre-GRV-1794**). El `develop`/`master` reales ya tienen el **modelo unificado GRV-1794**. Este diseño se ejecuta sobre `develop`. Lo que sigue describe la estructura real de develop.

**Estado actual relevante (develop / GRV-1794, verificado):**

- El grid se sirve por `TrasladosServiceDTOImpl.findAllTraslados` → `TrasladosServiceImpl.findAllByTipoTransporte`, que ejecuta el **SP unificado `consulta_traslados_unificada_sp`** (modelo GRV-1794, basado en `traslados_agencias_historico`) y, para traslados viejos sin entrada en esa tabla, los **2 SP legacy** `consulta_traslados_legacy_remis_sp` y `consulta_traslados_legacy_tp_sp`. (Los 3 SP pre-GRV-1794 —`consulta_traslados_remis_ambulancia_sp`/`_internos_`/`_transporte_publico_`— quedaron **muertos**, ya no se invocan.)
- El SP unificado arma `tmp_ids_candidatos` → **`tmp_traslados`** (pivotea ida+vuelta), **soporta `auditada` 0/1/2**, hace `SELECT COUNT(*) INTO total_records FROM tmp_traslados` y luego pagina con `LIMIT/OFFSET`.
- La pestaña **Desimputados** en develop NO filtra en memoria: `findAllDesimputados` arma un `spRequest` con **`auditada=2`** (`buildDesimputadosSpRequest`) y va por el **mismo SP unificado**.
- El buscador del front (`hook/useBusquedaGeneral.ts`) arma un índice en memoria sobre `data.objetos` (la página visible) → ese es el bug. Existe `isSearching` en `filtersSlice`; **no** existe `busquedaGeneral`. El "flash" sale de vaciar `data` durante `isFetching` en `pages/AuditoriaTraslado.tsx`.

**Dato clave (verificado):** las columnas visibles (denuncia, paciente, dni, fecha, monto, factura, estado, proveedor, direcciones) **ya están materializadas** en `tmp_traslados`. El filtro de búsqueda es un predicado barato sobre una tabla ya acotada por período; el costo real es construir la temp table, no buscar.

**Tamaños en prod (esquema `cs`):** `turnos` ~4.4M filas / 4.2GB, `traslados` ~1.59M / 2.7GB, `denuncias` ~450k / 1.3GB.

**Origen:** la propuesta previa (zip `opcion1-buscador-traslados`, codex/claude) estaba escrita **contra el modelo unificado** (`tmp_traslados` + nota legacy) — es decir, contra develop. Este diseño la reusa como base del SQL del SP unificado (provider, hook, Highlight incluidos).

## Goals / Non-Goals

**Goals:**
- Buscar en backend sobre el universo completo acotado por filtros, con total exacto, sin exigir filtrado previo.
- Buscar y resaltar solo los campos visibles de cada pestaña; escalable (agregar columna = agregar línea).
- Patrón transportable a otras pantallas/módulos cambiando endpoint y mapeo.
- Cubrir las 3 pestañas (incluida Desimputados).
- Entregar la Fase 1 sin agregar riesgo de infraestructura (sin cache).

**Non-Goals:**
- No se implementa la cache en Fase 1 (solo se diseña, ver capability `cache-universo-traslados`).
- No se libera la búsqueda en los 2 SP legacy (remis/tp) — volumen marginal, se documenta.
- No se refactorizan las vistas. El **índice compuesto SÍ entra** en esta entrega (ataca el acantilado de ventanas anchas, ver D7).
- No cambia el contrato del endpoint `POST /traslado` (`busquedaGeneral` es opcional).

## Decisions

### D1 — El filtro de búsqueda va en el SP unificado, sobre `tmp_traslados`, ANTES del `COUNT(*)`

Se inserta un bloque que elimina de `tmp_traslados` las filas que no coinciden, **después de poblarla y antes del `SELECT COUNT(*) INTO total_records`** (en `005_create_sp_consulta_traslados_unificada.sql`, ~L370), de modo que el total y el `SELECT` final paginado queden filtrados sin duplicar lógica. La búsqueda se libera **solo en el SP unificado**; los 2 SP legacy (remis/tp) quedan fuera de alcance (decisión de la arquitecta: volumen legacy marginal, se documenta).

Patrón (parametrizado por `auditada`, con escape de wildcards y collation acento-insensible):

```sql
-- DECLARE busquedaGeneral VARCHAR(255) CHARACTER SET utf8mb4;   (junto a los demás DECLARE)
-- SET busquedaGeneral = CONVERT(JSON_UNQUOTE(JSON_EXTRACT(filters,'$.busquedaGeneral')) USING utf8mb4);
-- Escape de wildcards (fix code-review): \ % _ tratados como literales.
-- SET busquedaGeneral = REPLACE(REPLACE(REPLACE(busquedaGeneral,'\\','\\\\'),'%','\\%'),'_','\\_');

IF busquedaGeneral IS NOT NULL AND busquedaGeneral <> '' THEN
  IF auditada = 0 THEN      -- No Auditados: identificación + paciente + proveedor/direcciones/estado
    DELETE FROM tmp_traslados WHERE NOT ( <columnas visibles> );
  ELSEIF auditada = 1 THEN  -- Auditados: identificación + paciente + FACTURA + MONTO + responsable
    DELETE FROM tmp_traslados WHERE NOT ( <columnas visibles> );
  ELSEIF auditada = 2 THEN  -- Desimputados: denuncia + paciente + dni + FACTURA + MONTO + fecha/responsable desimputación
    DELETE FROM tmp_traslados WHERE NOT ( <columnas visibles> );
  END IF;
END IF;

-- Cada comparación:
--   COALESCE(CONVERT(<col> USING utf8mb4),'') COLLATE utf8mb4_general_ci
--     LIKE CONCAT('%', busquedaGeneral, '%') ESCAPE '\\'
```

**Mapeo real de columnas de `tmp_traslados` por pestaña (implementado):**
- **auditada=0**: `nro_traslado`, `nro_denuncia`, `paciente`, `dni_paciente`, `fecha_traslado`, `hora_traslado`, `descripcion_proveedor_servicio_traslado_ida/vuelta`, `direccion_origen`, `direccion_regreso`, `direccion_regreso_vuelta`, `descripcion_estado_traslado`, `descripcion_estado_logistica_ida/vuelta`, `descripcion_etiqueta_agencia_ida/vuelta`.
- **auditada=1**: `nro_traslado`, `nro_denuncia`, `paciente`, `dni_paciente`, `fecha_traslado`, `nro_factura_ida/vuelta`, `monto_ida/vuelta`, `fecha_auditoria_ida/vuelta`, `responsable_auditoria_ida/vuelta`.
- **auditada=2 (Desimputados)**: `nro_denuncia`, `paciente`, `dni_paciente`, `nro_factura_ida/vuelta`, `monto_ida/vuelta`, `fecha_auditoria_ida/vuelta`, `responsable_auditoria_ida/vuelta`. (En desimputados, `mapSpToDesimputadosDto` renombra `fecha_auditoria_*`→`fechaDesimputacion*` y `responsable_auditoria_*`→`responsableDesimputacion*`; por eso esas columnas SÍ entran al filtro de esta pestaña. Sin `nro_traslado`.)

**Nota:** los 3 SP pre-GRV-1794 (`consulta_traslados_remis_ambulancia_sp`/`_internos_`/`_transporte_publico_`) están muertos en develop — NO se tocan.

**Alternativa descartada:** filtrar en el `SELECT` final con un `WHERE`. Se descartó porque habría que duplicar el predicado y recalcular el `COUNT` aparte; el `DELETE` previo sobre `tmp_traslados` lo resuelve una sola vez.

### D2 — Desimputados se resuelve por el mismo SP unificado (`auditada=2`)

En develop, `findAllDesimputados` arma un `ObtenerTrasladoFiltrosDTO` con `auditada=2` vía `buildDesimputadosSpRequest` y va por `consulta_traslados_unificada_sp` (no hay filtrado en memoria). Por lo tanto la búsqueda de desimputados se resuelve **dentro del SP** (rama `auditada=2` de D1) — **no** se agrega ningún filtro Java. La única modificación Java es que `buildDesimputadosSpRequest` **propague el término**: `sp.setBusquedaGeneral(r.getBusquedaGeneral())`. El término viaja en `ObtenerDesimputadosFiltrosDTO.busquedaGeneral`.

### D3 — Estrategia detrás de `TrasladosSearchProvider` (Strategy + ConditionalOnProperty)

`findAllTraslados` delega en `trasladosSearchProvider.buscar(request)`. La implementación por defecto `DirectSearchProvider` (`@ConditionalOnProperty(name="traslados.search.provider", havingValue="direct", matchIfMissing=true)`) serializa los filtros y llama al servicio de SP, igual que hoy. Esto deja el punto de extensión para la cache (Fase 2) **sin** tocar controller ni front. Es el mecanismo de transportabilidad: otra pantalla implementa su propio provider/endpoint reusando el patrón.

### D4 — Front: aplicación por submit explícito (no debounce en esta pantalla)

La pantalla de auditoría de traslados **tiene botón "Filtrar"** (`FiltrosTraslados.handleSearch`). Decisión de la arquitecta: el buscador general se comporta **como el resto de los filtros** — se aplica con acción explícita, NO auto-dispara mientras se tipea.

- El término del campo de búsqueda se incorpora al estado de filtros y se **envía con el submit** (`handleSearch` del botón "Filtrar") y también al confirmar con **Enter** en el campo. En ambos casos `updateFilter({ busquedaGeneral: term || null, offset: 0 })` + refetch (RTK Query lazy). **Sin debounce auto-fire.**
- `useBusquedaBackend(onSearch, { mode, delay })`: hook genérico **transportable**. En esta pantalla se usa en modo `submit` (sin auto-fire). Ofrece además un modo `debounced` con **retardo amplio (`delay=600ms`)** para pantallas que NO tengan botón de aplicar filtros. El valor grande es deliberado: en módulos sin submit, evita peticiones por tecla y da tiempo a terminar de tipear.
- `Highlight`: componente reutilizable que parte el texto por el término y envuelve la coincidencia en `<mark>` amarillo. La comparación es **case- y acento-insensible**: se normaliza término y texto con `String.normalize('NFD').replace(/\p{Diacritic}/gu,'')` + `toLowerCase` para decidir el match, pero **se resalta sobre el texto original** (con tildes). Regex escapada para caracteres especiales. Se aplica **solo** en las columnas visibles de cada pestaña; el set de columnas con `<Highlight>` debe coincidir exactamente con el set del filtro de esa pestaña (invariante de oro).
- Fix del flash: reemplazar `if(isFetching) setData([])` por actualizar `data` solo cuando llega la respuesta (`if(!isFetching && traslados) setData(traslados)`), dejando que la tabla muestre su overlay vía `loading`.
- `useBusquedaGeneral` (memoria) queda deprecado para traslados.

### D7 — Costo real de la query base medido (ANALYZE) → Fase 1 es suficiente, la cache es opcional

`ANALYZE FORMAT=JSON` sobre la consulta real del SP remis/ambulancia (la vista más pesada, contra `traslados` 1.59M) para un período de 1 mes (mayo 2026, 9.248 filas resultantes):

- **`r_total_time_ms` raíz = ~678 ms** (tiempo de ejecución real, no estimado). El `query.timeout=15000` es red de seguridad, no el caso normal.
- El filtro de período **baja a `traslados`** vía `rowid_filter` sobre `fecha_traslado` (estimadas 21.022 → reales 11.221 → 9.248 finales). **El costo es proporcional al período**, no a las 1,59M filas.
- El grueso del tiempo (~433 ms) está en el acceso a `traslados`; el join arranca por `proveedoresIda` (full scan de 352 filas, despreciable).
- El `ROW_NUMBER()` de "última auditoría" se computa como **derivada lateral/correlacionada por traslado** (`<derived2>`/`<derived5>`, ~0-1 fila de log por traslado, ~75 ms en total). **No** materializa global las 138k filas de log — se descartó el peor caso temido.
- La vista tiene un tope hardcodeado `fecha_traslado >= curdate() - INTERVAL 2 YEAR`, que acota el peor caso por diseño.

**Segundo punto de la curva — período ancho (todo 2026, ~48k filas):** `r_total_time_ms ≈ 14.049 ms (~14s)`, al borde del `timeout=15s`. El acantilado es **no lineal**: ~0,68s a 1 mes → ~14s a 1 año (20×, no 12×). Causa medida: con la ventana ancha el optimizer mantiene el plan que **drivea desde `proveedoresIda` (scan) → `traslados` por `idx_traslados_proveedor_servicio`** y usa `fecha_traslado` como `rowid_filter` poco selectivo (lee ~1,4M filas, descarta ~96%); el acceso a `traslados` consume 12.785 ms de los 14.049. El `ROW_NUMBER` además cambia a materializar todo el log (178k, filesort) una vez (~360 ms, no es el cuello).

**Implicación de diseño:**
- El buscador server-side **sin cache** responde **sub-segundo en ventanas normales** (semanas / 1 mes). La **Fase 1 es suficiente** para el caso de uso real y se entrega sin cache.
- Existe un **acantilado en ventanas anchas (~14s)**, independiente del buscador. **Decisión: se ataca en esta misma entrega (Fase 1)** con un **índice compuesto `(fecha_traslado, id_estado_traslado)`** sobre `traslados`, para que el optimizer pueda drivear por fecha en vez de por el scan de proveedores. Es la causa raíz; la cache solo enmascararía repeticiones (el primer hit ancho seguiría en 14s), por eso se prefiere el índice. **Validar con `ANALYZE` post-índice** que el plan cambia de driver y baja el tiempo de la ventana ancha.
- La cache con invalidación por generación sigue siendo válida como optimización opcional para instantaneidad en búsquedas/paginados repetidos sobre el mismo período (de ~0,7s a ~0ms), pero **no es necesidad** para habilitar el buscador.

**Hallazgos colaterales (fuera de scope, registrados):**
- Índice redundante: `fecha_traslado` e `idx_traslados_fecha` son idénticos sobre la misma columna → candidato a dropear uno.
- `proveedoresIda` se accede con `ALL` (scan de 352); inofensivo hoy, revisar si crece.
- Datos corruptos de fecha en `traslados` (`min 0019-06-01`, `max 2620-02-24`); el tope de 2 años los oculta del grid, pero es deuda de calidad de datos.

### D6 — Búsqueda insensible a acentos en SQL (MariaDB 10.5)

Prod corre **MariaDB 10.5.29** (sin las collations `uca1400_ai_ci` de 10.10+). La collation `utf8mb4_general_ci` ya es case-insensitive y pliega los acentos del español (á=a, é=e, í=i, ó=o, ú=u; `ñ` se mantiene distinta, que es lo correcto). El esquema `cs` tiene default `latin1`, pero las columnas de la temp table se manejan en `utf8mb4`. Para garantizar el comportamiento de forma determinística, la comparación fuerza la collation en ambos operandos:

```sql
... COALESCE(CONVERT(<col> USING utf8mb4), '') COLLATE utf8mb4_general_ci
        LIKE CONCAT('%', busquedaGeneral COLLATE utf8mb4_general_ci, '%') ...
```

`busquedaGeneral` se declara `CHARACTER SET utf8mb4`. **Validar en la réplica** un par de casos (con y sin tilde, mayúsculas) antes de cerrar el SP, porque la collation de origen de cada vista puede variar (`latin1_swedish_ci` también pliega vocales acentuadas, pero no es garantía uniforme).

### D5 — Fase 2 (cache) diseñada pero no implementada

Mono-instancia confirmado → Caffeine + contador de generación en memoria es seguro. Diseño detrás de `SearchCacheStore` (interfaz) + `CachedSearchProvider` (`havingValue="cached"`): cachea el universo por filtros estructurales (sin término ni paginación), resuelve búsqueda+paginación en memoria, e invalida con `SearchCacheGeneration.bump()` en cada escritura (auditar/desimputar/asociar). **Optimización opcional, no necesidad** (ver D7: la query base mide ~0,68s para 1 mes). Solo vale la pena si aparece dolor real con ventanas anchas o se busca instantaneidad en repetición. Si se activa, hacerlo con (a) memoria acotada por período y (b) validación de frescura tras auditar en STAGE. Si en el futuro hay N>1 instancias, migrar la generación a Redis/ElastiCache (`INCR`) sin cambiar el provider.

## Risks / Trade-offs

- **Divergencia de nombres de columna entre los 3 SP** → si se copia el mismo bloque a internos, falla por `nro_denuncia`/`direccion_*` inexistentes. **Mitigación:** bloque específico por SP, validado con `mariadb-migration-review` y prueba de ejecución en réplica.
- **`LIKE '%term%'` no usa índice** → no importa: corre sobre la temp table ya acotada por período (pocas filas), no sobre las tablas grandes. **Mitigación:** mantener el filtro como `DELETE` post-INSERT; no tocar las vistas en Fase 1.
- **Costo de construir la temp table** → medido en ~0,68s para 1 mes (D7), aceptable; el `timeout=15s` es red de seguridad para ventanas anchas. La Fase 1 no lo empeora. **Mitigación:** solo si auditan ventanas muy anchas, Fase 2 opcional (cache/índices); para uso normal no se requiere.
- **Paginación cross-SP rota (pre-existente)** → la búsqueda no la arregla; el daño real es chico porque internos son ~78 filas. **Mitigación:** documentar como deuda; resolver en Fase 2.
- **Cache (Fase 2) con período amplio** → riesgo de heap al materializar universos enormes. **Mitigación:** límite de filas cacheables por entrada; sobre el límite, modo directo.
- **Cache (Fase 2) y estado "en proceso"** → el universo cacheado podría incluir marcas volátiles de `marcarTrasladosEnProceso`. **Mitigación:** evaluar excluir esa marca del cache o invalidar también al encolar.

## Migration Plan

- **Fase 1 (esta entrega):** 1 script SQL con (a) el `CREATE OR REPLACE`/`DROP+CREATE PROCEDURE` de los 3 SP y (b) el `CREATE INDEX idx_traslados_fecha_estado ON traslados (fecha_traslado, id_estado_traslado)` (y opcionalmente dropear el `idx_traslados_fecha` redundante), revisado con `mariadb-migration-review`. El `CREATE INDEX` sobre `traslados` (1,59M filas) debe planificarse en ventana de bajo tráfico (en 10.5 puede ser online `ALGORITHM=INPLACE, LOCK=NONE`, validar). Cambios de Java/front en branches `feature/buscador-general-auditoria-traslados` por repo. El campo `busquedaGeneral` es opcional → backward-compatible; se puede desplegar backend antes que front sin romper.
- **Rollback:** restaurar la versión previa de los 3 SP (los SP son idempotentes vía recreación) y revertir los MR de Java/front. Sin cambios de datos → rollback limpio.
- **Fase 2 (posterior):** activar `traslados.search.provider=cached` en STAGE, validar frescura tras auditar y memoria, recién entonces PROD.

## Open Questions

_Resueltas por la arquitecta (2026-06-16):_

- **Desimputados — responsable/fecha de desimputación:** SÍ son columnas visibles → entran al mapeo de búsqueda de esa pestaña (ver D2).
- **Insensibilidad a acentos:** SÍ → comparación case- y acento-insensible en backend (`utf8mb4_general_ci`, ver D6) y front (normalización NFD, ver D4).
- **Disparo de la búsqueda:** como la pantalla tiene botón "Filtrar", la búsqueda se aplica por **acción explícita** (botón/Enter), sin debounce auto-fire (ver D4). El modo debounce queda solo para pantallas sin submit, con **retardo amplio (600ms)**.

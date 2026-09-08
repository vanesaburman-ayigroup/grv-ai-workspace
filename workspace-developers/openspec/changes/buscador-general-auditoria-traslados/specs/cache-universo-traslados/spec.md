## ADDED Requirements

### Requirement: Cache del universo con frescura instantánea ante auditoría

(Fase 2 — diseño aprobado, implementación diferida.) Cuando se active la estrategia con cache, el sistema SHALL servir la búsqueda y la paginación desde un universo cacheado por filtros estructurales, y SHALL invalidar ese universo de forma instantánea ante cualquier escritura de auditoría (auditar, desimputar, asociar factura), sin ventana de datos viejos. La frescura NO SHALL depender del TTL.

#### Scenario: Tras auditar, el grid refleja el cambio al instante
- **WHEN** un operador audita un traslado y vuelve a consultar el grid (mismo período/filtros)
- **THEN** el resultado refleja el nuevo estado inmediatamente, porque la escritura incrementó el contador de generación y dejó el universo cacheado anterior inalcanzable

#### Scenario: Búsqueda y paginación repetidas son instantáneas
- **WHEN** el universo de un período ya está cacheado y el usuario busca términos o cambia de página sin escrituras de por medio
- **THEN** las respuestas se resuelven en memoria sin reconsultar la base

#### Scenario: TTL no es el mecanismo de frescura
- **WHEN** existe un TTL configurado como red de seguridad de memoria
- **THEN** la correctitud no depende de él: aun con TTL largo, una escritura invalida el universo de inmediato

### Requirement: Cache seguro en topología mono-instancia

El sistema SHALL garantizar que, en la topología mono-instancia actual de `wsauditoriatraslados`, el contador de generación en memoria del proceso sea suficiente para la invalidación. El sistema SHALL acotar la memoria del cache (límite de entradas y de tamaño del universo por entrada) para evitar agotar el heap con períodos amplios.

#### Scenario: Una sola instancia ve siempre su propia invalidación
- **WHEN** la única instancia procesa una escritura y luego una lectura
- **THEN** la lectura ve el contador incrementado y recomputa contra dato vivo

#### Scenario: Período amplio no agota memoria
- **WHEN** un usuario solicita un universo cuyo tamaño superaría el límite configurado de filas cacheables
- **THEN** el sistema no cachea ese universo (lo resuelve en modo directo) en lugar de arriesgar el heap

#### Scenario: Migración futura a multi-instancia
- **WHEN** se agregue una segunda instancia del servicio
- **THEN** el cache local deja de ser seguro y SHALL migrarse a generación distribuida (p. ej. `INCR` en Redis/ElastiCache) detrás de la misma interfaz, sin cambiar el provider ni el mecanismo de invalidación

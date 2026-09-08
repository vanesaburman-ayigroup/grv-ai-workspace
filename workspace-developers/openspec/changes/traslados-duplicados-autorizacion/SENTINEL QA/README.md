# SENTINEL QA — `traslados-duplicados-autorizacion`

Revisión de calidad del change **INI-2** por QA Sentinel. Los artefactos de esta carpeta se
generan **contra** los documentos del change (`PRD`, `proposal`, `design`, `specs/`, `tasks`,
`SDD`) y contra los ambientes reales; no los reemplazan.

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Ticket** | INI-2 (triage inbox, no Jira) |
| **Ambientes** | `test.sas.colonia-suiza.com.ar` · `dev.sas.colonia-suiza.com.ar` |
| **Inicio de la revisión** | 18/08/2026 |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |

---

## Estado de la revisión

| # | Artefacto | Estado |
|---|---|---|
| 01 | Análisis estático de PRD y specs | **Completo** |
| 02 | Verificación de ambientes — base de datos | **Completo, con salvedad** |
| 02 | Verificación de ambientes — aplicación | **Completo** |
| 03 | Plan de pruebas | Pendiente |
| 04 | Matriz de casos | Pendiente |
| 05 | Evidencia de ejecución | Bloqueada — ver **VAP-01** |

---

## Contenido

### `01-analisis-estatico/`

`analisis-estatico-traslados-duplicados-autorizacion.md` · `.html` (imprimible)

**23 hallazgos propios: 5 bloqueantes, 10 altos, 5 medios, 3 bajos.** No repiten los `D-x`,
`R-x` ni `H-x` que el SDD ya se había auto-detectado; los citan sólo como contexto.

Incluye matriz de trazabilidad RF → Requirement → Scenario, cobertura de las casuísticas
C-01 a C-16, huecos de máquina de estados y checklist de datos de prueba.

### `02-verificacion-ambientes/`

`verificacion-base-de-datos.md`

Verificación por SQL. **El MCP de MariaDB resultó estar conectado a producción, no a TEST**,
así que las tareas 1.6 y 2.4 quedan sin verificación independiente. De la sesión salió un
bloqueante de despliegue: **el script del permiso colisiona en producción**.

`verificacion-aplicacion.md`

Sondas HTTP y navegación en TEST y DEV con los dos perfiles. **En TEST el frontend está
desplegado y el backend de `turnos` no** — el peor modo de falla del circuito, ya materializado.
Resuelve **EST-01**: la capability de devolución existe y el dictamen se muestra. Reverifica los
cinco defectos conocidos: **tres ya están corregidos**.

### `03-plan-de-pruebas/` · `04-matriz-de-casos/` · `05-evidencia/`

Pendientes. La ejecución sólo es posible hoy en **DEV** (ver **VAP-01**), y conviene cargar los
datos en **fechas futuras** para que el backend habilite las tres salidas.

---

## Lo bloqueante, consolidado

Los puntos que hoy impiden dar este desarrollo por probado.

| ID | Hallazgo | Origen |
|---|---|---|
| **VAP-01** | **En TEST el front está desplegado y el backend de `turnos` no.** Las pestañas se ven, los endpoints dan 404 y la grilla muestra turnos sin filtrar sin dar ningún error. Es el peor modo de falla que `design.md` advirtió, ya ocurrido. **La prueba funcional en TEST no puede empezar** | Verificación de aplicación |
| **VBD-02** | **El script del permiso colisiona en producción.** Inserta `id_permiso = 101`, que ya está ocupado por `editar_cie10_bloqueado` (GRV-2239). Falla la migración o pisa el permiso de CIE-10 | Verificación de base |
| ~~**EST-01**~~ | ~~No se sabe qué hay que probar — `devolucion-resultado-solicitante` en estado contradictorio~~ → **RESUELTO por VAP-03**: la capability existe, el dictamen se muestra, **H-1 y H-2 están cerrados**. Corregir el PRD §7.1 y el SDD §10 | Análisis estático + aplicación |
| **EST-02** | **El circuito no cierra el agujero que vino a cerrar.** El motivo autodeclarativo sigue habilitando el gate sin permiso ni pedido; los 2.156 casos anuales se pueden seguir generando igual | Análisis estático |
| **EST-03** | **Riesgo de impacto al asegurado, y es una regresión.** Un pedido pendiente no tiene SLA, vencimiento ni alerta. Hoy el modo de falla es pagar un viaje de más; con el circuito, **el paciente no viaja** y se descubre el día del turno | Análisis estático |
| **EST-04** | **El perfil supervisor está sin definir**, y es el actor de C-04 o C-05 — casos de resultado opuesto. Es además uno de los usuarios de prueba | Análisis estático |
| **EST-05** | **El resultado esperado depende de una property por ambiente** (`horas-minimas-anulacion`). Ningún artefacto normativo declara la política de salidas | Análisis estático |

### Además, del propio equipo (no son hallazgos de Sentinel, pero condicionan la prueba)

- **R-1** — Los endpoints de `wsturnos` **responden sin autenticación** y validan el permiso
  contra un `idAutorizante` que viaja **en el body**. Es el riesgo abierto de mayor severidad
  del change.
- **Despliegue en TEST** — `tasks.md` y `analisis/pool-datos-test.md` declaran que el código
  **no está desplegado en TEST** (endpoints en 404; el filtro de la grilla se descarta y
  devuelve 4.412.517 filas). En verificación.
- **`tasks.md` no es fuente de alcance confiable** — la tarea 7.3 está en `[x]` y la evidencia
  de campo del mismo día la desmiente (`useConflictoTraslado.js:44` toma sólo el primer
  conflicto). Ver **EST-15**.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026

# Revisión de consumidores — promoción a producción INI-2

**Change:** `traslados-duplicados-autorizacion` — autorización de traslados duplicados del mismo día
**Alcance de la promoción:** sólo INI-2. Cinco repos: `wsturnos`, `wslogistica`, `wstraslados`, `tramitadores`, `logistica`.
**Pregunta que responde este documento:** ¿algún módulo del SAS **fuera de esos cinco** consume algo que este change modifica?
**Método:** skill `consumers-of` (análisis de impacto inverso) aplicado una vez por artefacto, más verificación directa contra la base de DEV (conector de sólo lectura).

## Nota de procedimiento

El skill `consumers-of` vive en `workspace-developers/.claude/skills/consumers-of/`, que no está en el scope de skills de la sesión desde la que se corrió el análisis, así que el mecanismo `Skill` no pudo cargarlo. Se leyó `SKILL.md` y `references/patrones-grep.md` y se ejecutó su procedimiento (pasos 1 a 8) y sus patrones de grep de forma literal, artefacto por artefacto. Las reglas anti-alucinación del skill se aplican: **toda fila de las matrices tiene archivo y línea**; donde no hay evidencia, se dice que no hay consumidores.

## Alcance escaneado

| Grupo | Cantidad | Detalle |
|---|---|---|
| Backend | 60 directorios | `repos/grvx/backend/` — incluye 13 worktrees `*-wt-*`, que son copias de un mismo repo |
| Frontend | 19 directorios | `repos/grvx/frontend/` — incluye worktrees de `tramitadores` |
| SAS legacy | 1 | `repos/grvx/sas-1/sas_classic-main` — Java/JSP/EJB, 1.713 `.java` + 302 `.jsp` |
| Base de datos DEV | schema `cs` | 31 rutinas y 14 vistas que mencionan `traslados` |

Se verificó explícitamente que el barrido **alcanza** `sas_classic-main` (no queda excluido por `.gitignore`): un grep de control por `traslado` devuelve 16.868 ocurrencias en 420 archivos de ese repo.

## Veredicto por artefacto

| # | Artefacto | Veredicto |
|---|---|---|
| 1 | Los cuatro stored procedures que se reemplazan | 🟢 **SIN IMPACTO** |
| 2 | `cs.traslados`, `cs.traslados_transporte_publico`, tabla nueva | 🟢 **SIN IMPACTO** |
| 3a | `POST /wstraslados/traslado/cancelar-por-turno` | 🟢 **SIN IMPACTO** |
| 3b | `POST /wslogistica/traslados/cancelar-desde-modulo-externo` | 🟢 **SIN IMPACTO** |
| 3c | `POST /wsturnos/turnos/crear` — 409 nuevo | 🔴 **IMPACTO CONFIRMADO** — `wstramitador` |
| 3d | `PATCH /wsturnos/turnos/programar-turno` — 409 nuevo | 🟢 **SIN IMPACTO** |
| 4 | `TurnosTramitadoresResponseDTO` | 🟢 **SIN IMPACTO** |
| 5 | Permiso `autorizar_traslado_mismo_dia` | 🟢 **SIN IMPACTO** |

Un solo hallazgo bloqueante, y no está en el punto que más se temía. El cambio de contrato de `cancelar-por-turno` **no tiene consumidores externos**. El que sí los tiene es el 409 de `POST /turnos/crear`.

---

## 1. Los cuatro stored procedures que se reemplazan

Patrones aplicados (según `references/patrones-grep.md`, sección `sp`): `createStoredProcedureQuery("<sp>")`, `@Procedure(name="<sp>")`, `CALL <sp>(`, y el nombre literal en `.sql`. Búsqueda del nombre literal de cada SP sobre **todo** `repos/grvx/` (backend + frontend + sas_classic).

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| `Constantes.CONSULTA_TURNOS_TRAMITADORES_SP` | `wsturnos` ✔ en la promoción | `sp-call` | `src/main/java/ar/com/riovaradero/utils/Constantes.java` | 54 | Propietario. Se despliega junto al SP |
| `Constantes.SP_OBTENER_TRASLADOS_REMIS` | `wslogistica` ✔ en la promoción | `sp-call` | `src/main/java/ar/com/riovaradero/utils/constantes/Constantes.java` | 22 | Propietario |
| `Constantes.SP_OBTENER_TRASLADOS_AEREOS` | `wslogistica` ✔ | `sp-call` | `.../constantes/Constantes.java` | 23 | Propietario |
| `Constantes.SP_OBTENER_TRASLADOS_INTERNOS` | `wslogistica` ✔ | `sp-call` | `.../constantes/Constantes.java` | 27 | Propietario |

Definiciones (propietario según el skill): `wsturnos/src/main/resources/sql/consulta_turnos_tramitadores_sp.sql:2` y `wslogistica/src/main/resources/sql/storedProcedure/*.sql`.

**Consumidores externos: ninguno.** El nombre literal de los cuatro SP no aparece en ningún otro de los 60 repos backend, los 19 frontend, ni en `sas_classic-main`. Los únicos hits fuera de código son scripts y documentación de este mismo change, dentro de `wsturnos` y `wslogistica`.

Corolario sobre el riesgo que se quería descartar: **nadie externo mapea el resultset de estos SP**, ni por posición ni con `resultClasses`. El único `@SqlResultSetMapping` sobre `consulta_turnos_tramitadores_sp` es el de `wsturnos` (`dto/mapping/TurnosTramitadoresResponseDTO.java:30`), que viaja en la promoción. Agregar columnas al SELECT es invisible para el resto del ecosistema.

> 🟢 **SIN IMPACTO** — sin consumidores externos, verificado con búsqueda del nombre literal de los cuatro SP sobre los 80 repos y el SAS legacy.

---

## 2. Las tablas y columnas que se modifican

`cs.traslados` y `cs.traslados_transporte_publico` suman `es_duplicado_autorizado TINYINT(1) DEFAULT NULL`; se crea `cs.autorizaciones_traslado_duplicado`.

### 2.1 Quién mapea las tablas

Patrón `@Table(name = "<tabla>")` bajo `entities/`. **Tabla compartida** — el skill pide separar propietario de lectores.

| Consumidor | Repo | Tipo de uso | Archivo | Línea |
|---|---|---|---|---|
| `Traslados` | **`ws-sasconnect`** (Portal de Prestadores) | `mapping-table` + `query-write` | `src/main/java/ar/com/riovaradero/entities/Traslados.java` | 26 |
| `TrasladosTransportePublico` | **`ws-sasconnect`** | `mapping-table` | `.../entities/TrasladosTransportePublico.java` | 28 |
| `Traslado` | **`wsauditoria`** | `mapping-table` | `.../entities/Traslado.java` | 20 |
| `TrasladosTransportePublico` | **`wsauditoria`** | `mapping-table` | `.../entities/TrasladosTransportePublico.java` | 15 |
| `Traslado` | **`wsauditoriatraslados`** | `mapping-table` (`name = "TRASLADOS"`) | `.../entities/Traslado.java` | 22 |
| `TrasladoTransportePublico` | **`wsauditoriatraslados`** | `mapping-table` | `.../entities/TrasladoTransportePublico.java` | 21 |
| `Traslado` / `Traslados` | **`wstramitador`** | `mapping-table` | `.../entities/Traslado.java` :20 · `Traslados.java` :17 | 20 / 17 |
| `Traslado` | **`libdatabase`** (librería compartida) | `mapping-table` | `.../entities/Traslado.java` | 12 |
| `Traslados` | **`sas_classic`** (SAS legacy, EclipseLink/TopLink) | `mapping-table` | `Model/src/coloniasuiza/model/ejb/entity/Traslados.java` | 107 |
| `TrasladosTransportePublico` | **`sas_classic`** | `mapping-table` | `Model/src/coloniasuiza/model/ejb/entity/TrasladosTransportePublico.java` | 38 |

Dentro de la promoción, además: `wsturnos`, `wstraslados`, `wslogistica`.

Son **seis módulos externos** que mapean la tabla. Ninguno se rompe, y la razón es concreta, no un supuesto:

1. **El mapeo JPA/EclipseLink es por nombre de columna, no por posición.** Una columna nueva que la entidad no declara simplemente no se lee.
2. **Ningún servicio corre `ddl-auto=validate` sobre estas entidades.** Los únicos dos `validate` del ecosistema son `wsincapacidades/src/main/resources/application-prod.properties:7` y `wssapintegration/src/main/resources/application-prod.properties:8`, y ninguno de los dos mapea `traslados`. Aun así, `validate` falla por columna **faltante**, no por columna sobrante.
3. **La columna es `NULL`-able con `DEFAULT NULL`** (`INI-2-promocion-produccion.sql:149-155`), así que ningún `INSERT` existente se rompe por falta de valor.

### 2.2 `SELECT *` — verificación propia, no la del change

El change afirma haber revisado 19 stored procedures. La verificación directa contra DEV encontró **31 rutinas** (procedures + functions) en el schema `cs` cuya definición menciona `traslados`, más **14 vistas**. Se revisaron todas.

| Objeto | Total | Con `SELECT *` | Con `<alias>.*` | Impacto |
|---|---|---|---|---|
| Rutinas `cs` que mencionan `traslados` | 31 | 1 | 3 | Ninguno — ver abajo |
| Vistas `cs` que mencionan `traslados` | 14 | 0 | 0 | Ninguno |

Los cuatro casos con estrella, uno por uno:

| Objeto | Forma | Sobre qué | Por qué no rompe |
|---|---|---|---|
| `consulta_traslados_transporte_publico_sp` | `SELECT * FROM temp_traslados_filtrados` | Tabla temporal | La temporal se declara con **lista explícita de columnas** (`nro_traslado INT, id_tipo_traslado_ida INT, …`), no con `AS SELECT`. La forma del resultset no depende de `traslados` |
| `consulta_traslados_remis_ambulancia_sp` | `SELECT t.*` | **Vista** `cs.traslados_auditoria_remis_ambulancia_view` | Alimenta una temporal; el `SELECT` final del SP enumera columnas. Y la vista no usa estrella |
| `consulta_traslados_internos_auditoria_sp` | `SELECT t.*` | **Vista** `cs.traslados_auditoria_internos_view` | Ídem |
| `consulta_traslados_remis_ambulancia_sp_backup` | `SELECT t.*` | Vista | Es un backup, no está en ningún camino de ejecución |

Evidencia en repo de los dos primeros: `wsauditoriatraslados/src/main/resources/sql/consulta_traslados_remis_ambulancia_sp.sql:46` y `consulta_traslados_internos_auditoria_sp.sql:57`.

Dato clave: **las 14 vistas enumeran columnas explícitamente, ninguna usa `*`**. Y en MariaDB la lista de columnas de una vista queda fija al crearla, así que ni siquiera una vista con estrella recogería la columna nueva sin un `CREATE OR REPLACE`.

### 2.3 Código Java, `INSERT` posicionales y triggers

- **`SELECT *` sobre `traslados` en código:** cero. El único hit del patrón `SELECT * FROM (cs.)?traslados` en los 80 repos es una línea **comentada** sobre otra tabla: `wsauditoriatraslados/src/main/resources/sql/migracion_auditoria_agencia/explain_rama1_buscador.sql:60` (`-- SELECT * FROM cs.traslados_auditoria_agencia_view`).
- **`INSERT INTO traslados VALUES (...)` sin lista de columnas** (el patrón que sí rompería): cero hits, tanto en los repos como en las 31 rutinas de DEV.
- **Triggers:** uno solo, `generate_token_traslados` (`INSERT` sobre `traslados`). Asigna `NEW.token_ida` / `NEW.token_vuelta` por nombre. Sin impacto.
- **`createNativeQuery` con `resultClass` en `sas_classic`:** dos hits, y ninguno es de traslados — `SessionEJBBean.java:3875` usa `Ocupaciones.class` y `:11662` está comentado.

> 🟢 **SIN IMPACTO** — seis módulos externos mapean `traslados`, todos por nombre de columna. Cero `SELECT *` sobre la tabla en código, cero en las 14 vistas, y los 4 casos de estrella en las 31 rutinas de DEV operan sobre vistas o temporales de columnas explícitas. La afirmación del change se sostiene, y el alcance real (31 rutinas + 14 vistas) es mayor que los 19 SP declarados.

### 2.4 Hallazgo colateral, no bloqueante: `ws-sasconnect` esquiva el gate

No es un consumidor que se rompa, es un camino de alta que la validación nueva no cubre.

`ws-sasconnect` es el **Portal de Prestadores** (`ws-sasconnect/CLAUDE.md:7`: *"agendamiento de turnos y traslados"*) y **escribe `traslados` directo por JPA**, sin pasar por `wsturnos`:

- `src/main/java/ar/com/riovaradero/service/impl/TrasladoServiceImpl.java:172` — `trasladoRespository.save(newTraslado)`
- ídem líneas 293, 404, 449

No declara ninguna clave `wsrest.url.wsturnos.*`, así que no invoca `POST /turnos/crear` y por lo tanto **nunca ve el 409**. Consecuencia: un prestador puede seguir generando un segundo traslado del mismo día sin motivo declarado ni pedido de excepción, y la fila queda con `es_duplicado_autorizado = NULL` — es decir, logística la va a seguir cancelando por duplicado. Es la misma brecha que INI-2 cierra para los demás caminos, que en este queda abierta.

No bloquea la promoción. Sí conviene que el equipo del Portal de Prestadores lo sepa, porque los ~58 casos/mes que el change dice cerrar probablemente no bajen a cero.

---

## 3. Los endpoints cuyo contrato cambia

### 3a. `POST /wstraslados/traslado/cancelar-por-turno` — pasa de 200 vacío a 200 con cuerpo

Éste era el punto que más preocupaba. Patrones aplicados: `wsrest.url.*=<path>` en `application*.properties` de los 60 backends, path literal en `url/*.tsx` y `Urls/*.js` de los 19 frontends, y `@*Mapping("<path>")` bajo `client/**`.

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| Declaración del endpoint | `wstraslados` ✔ en la promoción | definición | `src/main/java/ar/com/riovaradero/controller/TrasladoController.java` | 267 | Propietario |
| `FETCH_URL_CANCELAR_TRASLADO` | `tramitadores` ✔ en la promoción | `consume-config` | `.../src/Urls/traslados.js` | 6 | Se despliega junto |
| `fetch(FETCH_URL_CANCELAR_TRASLADO, …)` | `tramitadores` ✔ | `consume-call` | `.../src/redux/actions/traslados.js` | 109 | Se despliega junto |

**Consumidores externos: ninguno.** Ningún `application*.properties` de los 60 backends declara una clave `wsrest.url.*` apuntando a `cancelar-por-turno`, y ningún otro MFE lo tiene en su carpeta de URLs. Los demás hits del path son worktrees del mismo repo `tramitadores` (`tramitadores-wt-anular`, `-wt-acciones`, `-wt-duplicados`, `-wt-master`, `-wt-grv2136fix`, `-wt-filtro3meses`) y documentación del change.

Y aun si apareciera un consumidor: el cambio es **aditivo sobre el mismo status**. `TrasladoController.java:272-274` sigue devolviendo `HttpStatus.OK`; lo único nuevo es que el body deja de venir vacío. Un cliente que ignora el cuerpo no cambia de comportamiento.

> 🟢 **SIN IMPACTO** — el único consumidor es el MFE `tramitadores`, que va en la misma promoción. Verificado con: `wsrest.url.*` en los 60 backends, path literal en los 19 frontends y en `sas_classic`, y `@*Mapping` bajo `client/**`.

### 3b. `POST /wslogistica/traslados/cancelar-desde-modulo-externo`

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| `wsrest.url.wslogistica.traslado.cancelarDesdeModuloExterno` | `wsturnos` ✔ | `consume-config` | `src/main/resources/application.properties` | 28 | En la promoción |
| `@Value("${…cancelarDesdeModuloExterno}")` | `wsturnos` ✔ | `consume-call` | `.../service/RestInvokeServiceImpl.java` | 110 | En la promoción |
| `wsrest.url.wslogistica.traslado.cancelarDesdeModuloExterno` | `wstraslados` ✔ | `consume-config` | `src/main/resources/application.properties` | 45 | En la promoción |
| `@Value("${…cancelarDesdeModuloExterno}")` | `wstraslados` ✔ | `consume-call` | `.../service/RestInvokeServiceImpl.java` | 142 | En la promoción |

Se revisó de paso **todo** `wsrest.url.(wsturnos|wstraslados|wslogistica).*` del ecosistema. Aparece un solo consumidor externo, y **no toca ninguno de los endpoints del change**:

| Consumidor externo | Qué consume | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|
| `wsauditoria` | `wslogistica` → `/traslados/traslado-desestimado` | `src/main/resources/application-prod.properties` | 25 | **No** — endpoint distinto, sin cambios en INI-2 |
| `wsauditoria` | `wsturnos` → `/autorizaciones/consumo-cie10` | `src/main/resources/application-prod.properties` | 27 | **No** — endpoint distinto, sin cambios en INI-2 |

Uso efectivo de ambos en `wsauditoria/src/main/java/ar/com/riovaradero/service/IRestInvokeImpl.java:83` y `:86`.

> 🟢 **SIN IMPACTO** — sólo lo consumen `wsturnos` y `wstraslados`, ambos en la promoción.

### 3c. `POST /wsturnos/turnos/crear` — ahora puede devolver 409 CONFLICT

🔴 **Acá está el hallazgo.**

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| `wsrest.url.turnos.crear.turno=turnos/turnos/crear` | **`wstramitador`** ✖ **fuera de la promoción** | `consume-config` | `src/main/resources/application.properties` | 39 | **Sí** |
| `@Value("${wsrest.url.turnos.crear.turno}")` | **`wstramitador`** ✖ | `consume-call` | `src/main/java/ar/com/riovaradero/service/RestInvokeServiceImpl.java` | 129 | **Sí** |
| `crearTurno(CreateTurnoDTO)` — `restTemplate.postForEntity` | **`wstramitador`** ✖ | `consume-call` | `.../service/RestInvokeServiceImpl.java` | 704-734 | **Sí** |
| `generarTurnoTrasladoOrtopedia(...)` — call site | **`wstramitador`** ✖ | `class-call` | `.../service/OrtopediasServiceImpl.java` | 1413 | **Sí** |
| `crearTurno` (declaración) | **`wstramitador`** ✖ | `class-import` | `.../service/interfaces/IRestInvokeService.java` | 79 | Sí |
| `turnosApi` — alta de turno | `tramitadores` ✔ | `consume-call` | `.../src/services/turnosApi.js` | — | En la promoción |

Ojo con el nombre: **`wstramitador` (backend) no es `tramitadores` (microfrontend)**. Son dos repos distintos y sólo el segundo entra en la promoción.

**Flujo de negocio afectado:** entrega de un pedido de ortopedia con traslado. El drawer *Gestión pendiente de entrega* del MFE `tramitadores` (`components/Ortopedias/GestionOrtopedia/DrawerGestionPendienteEntrega/components/StepTrasladoEntrega.jsx:131-141`, casilla *requiere traslado*) llega a `wstramitador`, que en `generarTurnoTrasladoOrtopedia` arma el turno y llama a `POST /turnos/turnos/crear`.

**Por qué rompe.** Tres hechos encadenados:

1. **El request cae dentro del gate.** `OrtopediasServiceImpl.java:1409` hace `createTurno.setGenerarTrasladoDTO(request.getTrasladoDTO())` con `requiereTraslado`, y `TrasladoDuplicadoValidator.contarConflictoSinResolver` sólo se abstiene si `requiereTraslado` no es `TRUE` (`wsturnos/.../service/TrasladoDuplicadoValidator.java:356`). Con la casilla marcada, el gate corre.

2. **`wstramitador` no puede satisfacer el gate: le faltan los dos campos.** La validación tiene tres escapes — motivo declarado, intención de pedido, o pedido de excepción existente. Ninguno está disponible:
   - `idMotivoTrasladoMismoDia`: **no existe** en `wstramitador/src/main/java/ar/com/riovaradero/dto/ortopedias/gestionPendienteEntrega/GenerarTrasladoDTO.java`. Ese DTO tiene `idSolicitaTrasladoMotivo` (línea 61) e `idMotivoTrasladoFueraHorario` (línea 72), que son otros campos.
   - `justificacionTrasladoDuplicado`: tampoco existe. Sin ella, `tieneIntencionDePedidoDuplicado()` (`wsturnos/.../dto/GenerarTrasladoDTO.java:569-571`) devuelve `false`.
   - `idAutorizacion`: `TurnosController.createTurno` le pasa `null` al validador (`wsturnos/.../controller/TurnosController.java:303`), así que `tienePedidoDeExcepcion` no encuentra nada.

   Resultado: si el paciente ya tiene un traslado vigente ese día, **el camino de ortopedias no tiene forma de pasar el gate**. Siempre 409.

3. **El 409 se degrada a un error opaco.** `RestInvokeServiceImpl.java:727-733`:

   ```java
   } catch (HttpClientErrorException | HttpServerErrorException e) {
     logger.error("HTTP error: {}", e.getMessage(), e);
     throw new RuntimeException(ERROR + e.getMessage(), e);
   }
   ```

   `RestTemplate` lanza `HttpClientErrorException` ante un 4xx, así que el 409 se vuelve un `RuntimeException` genérico. No hay rama que distinga 409 de 500 — exactamente el patrón «sólo distingue 200 de error» que había que buscar. El gestor de ortopedias ve un error técnico donde debería ver *«el paciente ya tiene un traslado ese día»*, y el pedido de entrega queda sin gestionar.

**Lo que no se pudo medir:** con qué frecuencia una entrega de ortopedia cae en un día que ya tiene traslado. Requiere datos de producción y el conector disponible es de sólo lectura sobre DEV. El change dice ~58 casos/mes de duplicado sin motivo en producción; **qué parte de esos 58 entra por el camino de ortopedias es el número que decide si esto es un incidente o una rareza**, y hay que pedirlo antes de promover.

> 🔴 **IMPACTO CONFIRMADO** — `wstramitador`, fuera de la promoción, consume `POST /turnos/crear` y convierte el 409 nuevo en un `RuntimeException` genérico. Su DTO no tiene ninguno de los dos campos que permiten pasar el gate, así que el bloqueo es inevitable, no evitable con datos.

### 3d. `PATCH /wsturnos/turnos/programar-turno` — ahora puede devolver 409 CONFLICT

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| Declaración | `wsturnos` ✔ | definición | `.../controller/TurnosController.java` | 223 | Propietario |
| `FETCH_URL_PROGRAMAR_TURNOS` | `tramitadores` ✔ | `consume-config` | `.../src/Urls/turnos.js` | 13 | En la promoción |
| `FETCH_URL_PROGRAMAR_TURNOS_REHABILITACION` | `tramitadores` ✔ | `consume-config` | `.../src/Urls/turnos.js` | 14 | En la promoción |
| `turnos-rehabilitacion/programar-turno` | `tramitadores` ✔ | `consume-call` | `.../src/services/turnosApi.js` | 110 | En la promoción |

**Consumidores externos: ninguno.** `wstramitador` consume `turnos/crear` pero **no** `programar-turno`: su `application.properties` tiene una sola clave hacia `wsturnos`, la de la línea 39. Verificado también que ningún otro backend declara una `wsrest.url.*` hacia este path y que ningún otro MFE lo referencia.

> 🟢 **SIN IMPACTO** — sólo el MFE `tramitadores`, que va en la promoción.

---

## 4. `TurnosTramitadoresResponseDTO` — campos nuevos al final del constructor

El riesgo declarado es real y está bien manejado: el mapping lee **por posición** (`@ConstructorResult` en `dto/mapping/TurnosTramitadoresResponseDTO.java:30`), y los campos nuevos van al final de los 24 parámetros. La pregunta es si alguien más depende de ese orden.

| Consumidor | Repo | Tipo de uso | Archivo | Línea | ¿Afecta? |
|---|---|---|---|---|---|
| `@SqlResultSetMapping` / `@ConstructorResult` | `wsturnos` ✔ | definición | `.../dto/mapping/TurnosTramitadoresResponseDTO.java` | 30 | Propietario |
| Constructor de 24 parámetros | `wsturnos` ✔ | definición | ídem | 156 | Propietario |
| Constructor vacío | `wsturnos` ✔ | definición | ídem | 216 | Propietario |
| `FindAllResult<TurnosTramitadoresResponseDTO>` | `wsturnos` ✔ | `class-call` | `.../serviceDTO/TurnosServiceDTO.java` | 240, 256 | En la promoción |
| `import` del DTO | `wsturnos` ✔ | `class-import` | `.../serviceDTO/TurnosServiceDTO.java` :21 · `.../serviceDTO/interfaces/ITurnosServiceDTO.java` :14, :36 | — | En la promoción |

La clase **sólo existe en `wsturnos`** y sólo se referencia en 3 archivos, todos de ese repo. Nadie más la construye, la importa, ni la extiende. Es coherente con el resultado del artefacto 1: como ningún servicio externo invoca `consulta_turnos_tramitadores_sp`, no hay dónde replicar ese mapping posicional.

> 🟢 **SIN IMPACTO** — el DTO no sale de `wsturnos`. Verificado con búsqueda del nombre de clase sobre los 80 repos.

---

## 5. El permiso nuevo `autorizar_traslado_mismo_dia`

### 5.1 Quién consulta el permiso

| Consumidor | Repo | Tipo de uso | Archivo | ¿Afecta? |
|---|---|---|---|---|
| `Constantes` — nombre del permiso | `wsturnos` ✔ | `class-call` | `src/main/java/ar/com/riovaradero/utils/Constantes.java` | En la promoción |
| `IPermisoSasRepository` — resuelve **por nombre** | `wsturnos` ✔ | `query-read` | `.../repositories/IPermisoSasRepository.java:35-36` | En la promoción |
| Documentación del campo | `wsturnos` ✔ | — | `.../dto/GenerarTrasladoDTO.java:100` | En la promoción |
| `permissionsConfig.js` | `tramitadores` ✔ | `consume-config` | `.../src/config/permissionsConfig.js` | En la promoción |
| Script DDL/DML | `wsturnos` ✔ | — | `.../sql/scripts/alter_autorizaciones_traslado_duplicado_mismo_dia.sql` | En la promoción |

**Consumidores externos: ninguno.** El literal `autorizar_traslado_mismo_dia` aparece en 7 archivos, todos de `wsturnos` o de worktrees de `tramitadores`.

### 5.2 ¿Alguien resuelve permisos por id en lugar de por nombre?

Era el riesgo de fondo, porque el script no fija el id: toma `MAX(id_permiso)+1` (`INI-2-promocion-produccion.sql:64-66`, con id esperado 102 en producción), y ese número difiere entre ambientes.

Se buscó el patrón peligroso en los 80 repos: `idPermiso == <número>`, `id_permiso = <número>`, `id_permiso IN (<números>)`, `findByIdPermiso`, `getIdPermiso() ==`. **Un único hit, y es un comentario** en un script del propio change (`wsturnos/.../sql/scripts/alter_autorizaciones_traslado_duplicado_mismo_dia.sql:120`).

Los consumidores reales de la cadena de permisos SAS resuelven **todos por la columna `permiso`** (el nombre), no por id:

| Consumidor | Repo | Archivo | Cómo resuelve |
|---|---|---|---|
| `PersonaPermisoRepository` | `wsincapacidades` ✖ externo | `.../repository/PersonaPermisoRepository.java:36-37` | Por nombre |
| `PermisoSasRepository` | `wsincapacidades` ✖ | `.../repository/PermisoSasRepository.java:39-41` | Por nombre |
| `PermisoGuard` | `wsincapacidades` ✖ | `.../security/PermisoGuard.java:37` — *"código del permiso en la tabla permisos_sas"* | Por nombre |
| `PermisoSasRepository` | `wscie10` ✖ | `.../security/PermisoSasRepository.java:21-23, 34` | Por nombre |
| `PermisoSasRepository` / `PermisoGuard` | `wsaccidentespersonales` ✖ | `.../repository/PermisoSasRepository.java:42-44` · `.../security/PermisoGuard.java:39, 55` | Por nombre |
| `AlcanceClienteRepository` | `wslogistica` ✔ | `.../repository/AlcanceClienteRepository.java:44-45` | Por nombre |
| `IPermisoSasRepository` | `wsturnos` ✔ | `.../repositories/IPermisoSasRepository.java:35-36` | Por nombre |

Un permiso nuevo, con el id que le toque, es invisible para todos ellos.

> 🟢 **SIN IMPACTO** — sin consumidores externos del permiso, y ningún módulo del ecosistema resuelve permisos por id. Verificado con los cinco patrones de id sobre los 80 repos y con la revisión de los 7 repositorios que consultan `permisos_sas`.

**Salvedad de coordinación, no de ruptura:** `wsaccidentespersonales/src/main/java/ar/com/riovaradero/utils/Constantes.java:70, 84, 101` documenta **tres permisos nuevos** que *"todavía no existen en `cs.permisos_sas` de ningún ambiente"*. Con `MAX+1`, el id que reciba `autorizar_traslado_mismo_dia` depende de qué promoción corra primero. No rompe nada — nadie resuelve por id — pero el 102 esperado del preflight puede no ser 102 si otra promoción se adelanta. El bloque 0.4 del script ya obliga a mirarlo antes de correr.

---

## Lo que hay que avisarle a otros equipos antes de promover

Un solo aviso bloqueante y dos informativos.

### 🔴 1. Equipo de `wstramitador` — Ortopedias. Antes de promover.

`POST /turnos/crear` empieza a devolver **409** y `wstramitador` lo convierte en un `RuntimeException` genérico (`RestInvokeServiceImpl.java:727-733`). Afecta la entrega de pedidos de ortopedia con traslado (`OrtopediasServiceImpl.generarTurnoTrasladoOrtopedia`, línea 1413).

Lo que hay que decidir con ellos, porque **no se arregla con datos**: su `GenerarTrasladoDTO` no tiene `idMotivoTrasladoMismoDia` ni `justificacionTrasladoDuplicado`, así que el camino de ortopedias no puede satisfacer el gate ni cargando bien el formulario. Tres opciones, de menor a mayor alcance:

1. **Medir primero.** Cuántas entregas de ortopedia con traslado caen en un día que ya tiene traslado, sobre datos de producción. Si es cero o casi, se promueve y se agenda el fix.
2. **Manejo del 409 en `wstramitador`.** Rama propia en el `catch` que propague el mensaje del gate al gestor en lugar de un error técnico. Es el cambio mínimo y no toca `wsturnos`.
3. **Agregar los campos al DTO de ortopedias** para que el camino pueda declarar el motivo o pedir la excepción. Es lo correcto a mediano plazo y no cabe en esta promoción quirúrgica.

Mínimo aceptable para promover: la medición del punto 1, y el punto 2 agendado.

### 🟡 2. Equipo del Portal de Prestadores — `ws-sasconnect`. Informativo.

`ws-sasconnect` escribe `traslados` directo por JPA (`TrasladoServiceImpl.java:172, 293, 404, 449`) sin pasar por `wsturnos`, así que **el gate nuevo no lo alcanza**. Los duplicados que entren por el portal van a seguir naciendo con `es_duplicado_autorizado = NULL` y logística los va a seguir cancelando por duplicado. No rompe nada y no bloquea, pero conviene que quede dicho: los ~58 casos/mes que INI-2 dice cerrar probablemente no bajen a cero, y la diferencia va a salir por acá.

### 🟡 3. DevOps / quien corra la ventana. Informativo.

Dos cosas, ambas ya contempladas en el script pero que dependen de gente:

- **Orden base → servicios, no negociable** (`INI-2-promocion-produccion.sql:18-21`). El mapeo por `resultClasses` exige que el SP devuelva todas las columnas mapeadas: código nuevo contra SP viejo **rompe la pantalla**. Al revés es seguro. Y el bloque 4 hace `DROP` + `CREATE` sobre `consulta_traslado_remis_amb_logistica`, el SP más caliente de logística, dejando unos segundos sin procedimiento: correr en horario de bajo tráfico.
- **Convivencia de contenedores.** `docs/post-mortems/2026-05-22-convivencia-contenedores-wsauditoria-wstraslados.md` documenta un SEV-2 de mayo por dos binarios del mismo servicio activos detrás del balanceador durante ~5 días, con `wstraslados` entre los servicios afectados. Si la ventana de esta promoción repite el patrón, un contenedor viejo de `wsturnos` no aplica el gate y los duplicados pasan silenciosamente mientras dure. Confirmar rollover atómico antes de empezar.

### Lo que **no** hay que avisar

- **El cambio de contrato de `cancelar-por-turno` no necesita aviso a nadie.** Su único consumidor es el MFE `tramitadores`, que va en la misma promoción, y el cambio es aditivo sobre el mismo 200. Era la hipótesis más temida y quedó descartada con evidencia.
- **Nadie externo invoca los cuatro SP** ni mapea sus resultsets, así que agregar columnas es invisible para el resto del ecosistema.
- **Ningún módulo se rompe por la columna nueva** en `traslados` / `traslados_transporte_publico`: 31 rutinas y 14 vistas revisadas contra DEV, cero `SELECT *` sobre la tabla, cero `INSERT` posicionales, y los seis módulos externos que la mapean lo hacen por nombre de columna.
- **`PATCH /programar-turno` no tiene consumidores externos**, así que su 409 nuevo no llega a nadie fuera de la promoción.

---

## Targets no resolubles

- **Frecuencia real del 409 en el camino de ortopedias.** Requiere datos de producción; el conector disponible es de sólo lectura sobre DEV. Es el dato que decide la severidad del hallazgo 🔴.
- **Consumidores no versionados.** El barrido cubre lo que está clonado en `repos/grvx/`. Un consumidor que no sea un repo del workspace — un job, un script de operaciones, una integración de un tercero contra la base — no aparece por definición. Para `traslados` esto importa poco (la columna es aditiva y nullable); para el 409 de `POST /turnos/crear` conviene confirmar con Operaciones que no haya automatizaciones apuntando a ese endpoint.
- **Worktrees.** Los 13 directorios `*-wt-*` de backend y los 6 de `tramitadores` son copias de repos ya contados. Sus hits no se reportan como consumidores independientes.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026

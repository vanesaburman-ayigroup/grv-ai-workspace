# Accidentes Personales — Costos y Topeo
## Especificación Técnica de Implementación (ETI)

> Complementa al `design.md` (decisiones de arquitectura) y a las `specs/` (qué debe hacer el sistema). Este documento define **cómo se escribe el código**: repos, versiones reales, estándares, contratos, performance, testing y criterios de aceptación técnica. Todo lo que dice sobre el estado actual está verificado contra el código de `repos/grvx` (julio 2026), no supuesto.

---

## 1. Mapa de repos y responsabilidad

### 1.1 Escritura (se modifican)

| Repo | Rol en AP | Alcance del cambio |
|---|---|---|
| **`wsmesacarga`** (backend) | Dueño de `polizas_ap` | Suma asegurada obligatoria en el alta, edición con historial, listado de pólizas sin tope |
| **`wsturnos`** (backend) | Autorizaciones y turnos | **Cambio quirúrgico**: disparar el valor estimado al autorizar. Nada más |
| **`wsaccidentespersonales`** (backend, **nuevo**) | Motor de consumo, semáforo, valor de venta, valores manuales | Todo el dominio AP nuevo |
| **`tramitadores`** (frontend) | Detalle del siniestro | Sección Costos y Topeo, cabecera, grilla, cartera, carga manual, consulta de saldo |
| **`mesadecarga`** (frontend) | Formulario de póliza | Campo de suma asegurada obligatorio/editable |

### 1.2 Lectura (no se tocan — se consumen)

| Repo | Qué se consume |
|---|---|
| `wsconvenio` | Honorarios de presupuestos (`POST /presupuestos`), valor NBU precomputado (vista `generar_pdf_no_nomencladas_nbu_view`) |
| `wscirugias` | Materiales por denuncia (`POST /pedido-materiales/findByDenuncia`, `GET /pedido-materiales/{id}/cotizaciones`) |
| `wsauditoriafacturacion` | Erogaciones (`POST /erogaciones`) |
| `wstraslados` / `wsauditoriatraslados` | Traslados por denuncia y montos de auditoría |

**Regla:** no se duplica lógica de otros dominios. Si el dato existe en otro ws, se lee; si no se puede leer, se pide el endpoint. Nunca se reimplementa la fórmula (precedente real: la multiplicación NBU ya está duplicada entre Java y un SP; no agregar una tercera copia).

### 1.3 Ramas y merge

- Rama por repo: `feature/ap-costos-topeo-etapa1` (trazabilidad 1:1 con el change de OpenSpec).
- Base: `develop` (no `master`, salvo hotfix).
- Commits en español, Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
- Orden de merge: migraciones → backend nuevo → hook de `wsturnos` → `wsmesacarga` → frontend. El frontend no se mergea antes que su backend.

---

## 2. Stack real por repo (medido, no declarado)

| Repo | Lenguaje | Framework | Tests hoy | Notas |
|---|---|---|---|---|
| `wsmesacarga` | Java 11 | Spring Boot **2.4.13** | **0** (no existe `src/test/`) | QueryDSL, Lombok, Bean Validation, springfox, log4j2, libInterceptor 2.0.0 |
| `wsturnos` | Java 11 | Spring Boot **2.1.2** (EOL 2019) | **0** | Hibernate 5.3.7 y spring-data-jpa pinneados a mano; springfox muerto (sin anotaciones); God services |
| `wsincapacidades` *(molde)* | **Java 21** | Spring Boot **3.2.10** | Unidad + **Testcontainers** | Virtual threads, springdoc, MapStruct, records, RBAC real |
| `tramitadores` (front) | JS | React 18.3.1 + webpack/single-spa | jest configurado, **0 tests** | RTK 2.12 híbrido: 21 APIs RTK Query + capa legacy de thunks |
| `mesadecarga` (front) | **TS** | React 18.3.1 + webpack/single-spa | 1 test | RTK con `createAsyncThunk` + `fetch` manual; typed hooks OK; **no** usa RTK Query |
| `auditoriafacturacion` *(molde front)* | **TS** | React 18.3.1 + **Vite** | 6 suites | RTK Query como capa HTTP única; único con `typecheck` |

> **Consecuencia práctica:** los dos repos backend que hay que tocar no tienen ni un test. Cualquier lógica de dinero que se escriba ahí nace sin red. Por eso la decisión de la sección 3.

---

## 3. Decisión de arquitectura: dónde vive el módulo AP

### 3.1 La decisión

**El dominio AP nuevo va en un servicio propio, `wsaccidentespersonales`, construido con el molde de `wsincapacidades` (Spring Boot 3.2.x / Java 21).** `wsturnos` recibe **solo** el hook del estimado.

### 3.2 Por qué

| Criterio | Servicio nuevo (Boot 3.2 / Java 21) | Dentro de `wsturnos` (Boot 2.1.2) |
|---|---|---|
| Tests | Testcontainers + JUnit 5 desde el día uno | Hay que crear `src/test/` y agregar dependencias; el pipeline no corre tests |
| RBAC server-side | `PermisoGuard` real (ya probado en producción en `wsincapacidades`) | No existe; habría que portarlo a Boot 2.1 |
| Documentación de API | springdoc + `openapi.yaml` versionado | springfox 3.0.0, abandonado upstream, incompatible con Boot 3 |
| Performance | Virtual threads, `Specification` + `withFetchJoins()` anti-N+1 | Hibernate 5.3.7 pinneado, `FetchType.EAGER` sembrado (9 usos) |
| Mantenibilidad | Paquete limpio, clases chicas, records | God services de 5.221 y 2.129 líneas; el propio relevamiento recomienda no sumar ahí |
| Riesgo de regresión | Nulo sobre lo existente | Alto: se toca el servicio más crítico del ecosistema |
| Costo | Repo + pipeline + ruta en el gateway | Cero infraestructura nueva |

El único costo real es de infraestructura (repo, Jenkinsfile, ruta), y es **una vez**. La contrapartida es que la lógica que decide **cuánta plata se le puede seguir gastando a un paciente** queda con tests, con permisos validados en el backend y en un stack soportado.

### 3.3 Plan B (si arquitectura no aprueba un servicio nuevo)

Alojar el motor en **`wsmesacarga`** (Boot 2.4.13, ya es dueño de `polizas_ap`, tiene `GlobalExceptionHandler`, QueryDSL y Bean Validation), en un paquete propio `accidentespersonales/`, y **crear `src/test/` como parte del trabajo**. Es peor que el plan A pero mucho mejor que `wsturnos`. En ningún escenario el motor va dentro de `TurnosServiceImpl` ni de `AutorizacionesServiceImpl`.

### 3.4 El hook en `wsturnos` (lo único que se toca ahí)

Hoy el valor por convenio se persiste en **un solo lugar**: `TurnosServiceImpl.setearValorTurnoConvenio` (línea ~4714), invocado **únicamente** desde `procesarTurnoRealizado` (~3518) — es decir, cuando el turno pasa a *realizado*. **Eso explica el 5,37% de cobertura: al autorizar nunca se calcula nada.**

El cálculo ya es reusable: `ConveniosService.calcularMontoTotalAutorizacion` (~144), expuesto en `IConveniosService`, resuelve el monto recorriendo `detalles_autorizacion` × cantidad contra el convenio vigente a la fecha del turno.

**Intervención:** inyectar `IConveniosService` y persistir el estimado en los tres puntos donde hoy nace un turno sin valor:

| Punto | Archivo:línea aprox. | Caso |
|---|---|---|
| Aprobación de autorización | `AutorizacionesServiceImpl` ~1263-1268 | El estado pasa a aprobada |
| Generación de turnos de rehabilitación | `AutorizacionesServiceImpl` ~1694 (`generarTurno`) | N turnos en estado no programado, sin valor |
| Alta directa de turno | `TurnosServiceImpl` ~1616 (`createTurno`) | Turno con autorización |

**Trampas a no heredar** (verificadas en el código):
- El guard por falta de valores está **comentado** (~4718-4722) y solo persiste si `totalPrestacion > 0`: si no hay convenio vigente, el turno queda en `NULL` **sin excepción ni log**. El hook nuevo **debe** loguear a nivel WARN con el id de autorización y el motivo, y dejar el turno operable (no frenar la autorización por falta de precio).
- No escribir el estimado si ya hay `valor_facturacion` (el facturado gana siempre).
- Marcar el origen: `id_tipo_origen_valor = 1` (CONVENIO).

---

## 4. Estándares de backend

### 4.1 Estructura de paquetes (molde `wsincapacidades`)

```
ar.com.riovaradero
├── config/          SecurityConfig, OpenApiConfig, (virtual threads por property)
├── controller/      thin: valida entrada, delega, arma ResponseDTO
├── dto/             records por dominio: request/, response/, filter/
├── entities/        entidades JPA (LAZY por defecto)
├── exception/       BusinessException (400), ConflictException (409), GlobalExceptionHandler
├── mapper/          MapStruct (@Mapper componentModel="spring")
├── repository/
│   └── specification/   Specifications composables + withFetchJoins()
├── security/        PermisoGuard, UsuarioAutenticado
├── service/         interfaces
│   └── impl/        implementaciones (una responsabilidad por clase)
└── utils/           Constantes.java, Swagger.java
```

Clases chicas. Si un service pasa de ~400 líneas, se parte por caso de uso. **Prohibido** replicar el patrón God service.

### 4.2 Contrato de respuesta (no negociable)

Todo endpoint devuelve el envelope del ecosistema, porque el frontend depende de ese shape:

```java
ResponseDTO<T> = { "status": int, "message": String, "body": T }
```

- Éxito: `ResponseDTO.general(HttpStatus.OK, body)`
- Error: `ResponseDTO.custom(HttpStatus.BAD_REQUEST, mensaje)`
- Listados: `ResponseDTO<FindAllResults<T>>` con `FindAllResults = { cantidadTotal: Long, objetos: List<T> }`

**Nunca** devolver la entidad JPA, ni un `Map` suelto, ni `Page<T>` de Spring crudo (el front no entiende `content/totalElements`).

### 4.3 Manejo de errores

Un único `@RestControllerAdvice GlobalExceptionHandler` en `exception/`, con el molde de `wsincapacidades`, que hace las dos cosas bien:

1. **Envuelve en `ResponseEntity`** para que el status HTTP coincida con el del body. *(Antipatrón real en el ecosistema: handlers que devuelven `ResponseDTO` pelado → HTTP 200 con `status: 500` en el cuerpo.)*
2. **No filtra el mensaje interno** en el 500: mensaje genérico al cliente, detalle completo al log. *(Antipatrón real: `ex.getMessage()` crudo devuelve nombres de tabla y SQL al cliente.)*

Mapeo mínimo: `BusinessException`→400, `MethodArgumentNotValidException`→400, `AccessDeniedException`→403, `ConflictException`→409, `Exception`→500 genérico.

**Prohibido** el `try/catch` por endpoint devolviendo `ResponseDTO.custom(500, e.getMessage())` — deja muerto al handler global y aplana todo a 500 (patrón presente en `wsturnos`, no replicarlo).

### 4.4 Validación

- **Bean Validation declarativa en el DTO** (`@NotNull`, `@NotBlank`, `@Positive`, `@Digits`), con `@Valid` en el controller. Mensajes desde `Constantes.VALIDATION_*`, nunca literales inline.
- Reglas cross-field con `@AssertTrue` en el propio record (molde: `isRangoFechasValido` de `PolizaApRequestDTO`).
- Reglas que requieren base de datos (¿el empleador es AP?, ¿ya existe el tope?) en el service, lanzando `BusinessException` / `ConflictException`.
- **La suma asegurada obligatoria se valida en el backend**, no solo en el formulario (requisito explícito de la spec `ap-tope-poliza`).

### 4.5 Montos: reglas duras

- **`BigDecimal` siempre.** Nunca `double`/`float` para dinero. En la base, `DECIMAL(16,2)`.
- Comparaciones con `compareTo`, no `equals`.
- Redondeo explícito: `setScale(2, RoundingMode.HALF_UP)` al persistir.
- El porcentaje de consumo se calcula con `BigDecimal` y se redondea a 2 decimales.
- **Nunca** dividir sin verificar que el tope sea `> 0` (caso `SIN_TOPE`).
- Toda suma de montos declara si es con IVA o sin IVA. El tope está **con IVA**: el numerador debe normalizarse antes de comparar (pendiente Q2 del design).

### 4.6 Transaccionalidad

- `@Transactional(readOnly = true)` en todas las consultas.
- `@Transactional` en escrituras, en el **service**, nunca en el controller.
- El hook del estimado no debe abortar la autorización si falla el cálculo del precio: se loguea y sigue (la autorización es la operación principal).

### 4.7 Seguridad y permisos

- **Chequeo server-side obligatorio** en cada endpoint nuevo, con el patrón `PermisoGuard` de `wsincapacidades` (valida contra `permisos_sas` y lanza `AccessDeniedException` → 403).
- Permisos nuevos: `ver_semaforo_ap`, `ver_indicadores_ap`, `cargar_valor_venta_prestacion`, `ver_margen_ap`, `ver_consolidado_cirugia`.
- Ocultar el botón en el front **no es** control de acceso. *(Precedente real del ecosistema: la caja de respuesta de Consultas y Reclamos se mostraba sin chequear permiso y un autoseguro podía mailear al paciente.)*
- Los permisos viajan en la cookie `datos_usuario`: **un permiso nuevo exige re-login** para verse. Documentarlo en la entrega.

---

## 5. Datos y migraciones

### 5.1 Convención (obligatoria)

No hay Flyway en el ecosistema: los scripts se aplican **a mano**, pero se versionan con nomenclatura tipo Flyway.

- Ubicación: `src/main/resources/sql/migrations/` (DDL/DML), `sql/data/` (seeds), `sql/queries/` (SPs y vistas).
- Nombre: `V<NNN>__<snake_case_descriptivo>.sql` — tres dígitos, **doble** underscore, descripción en español en infinitivo de acción (`crear_tabla_`, `agregar_columna_`, `backfill_`).
- **Verificar el último número usado en el repo antes de numerar**: hay repos con cuatro `V014` distintos porque nadie chequeó (no hay tabla de control que lo detecte).

### 5.2 Contenido de cada script

```sql
-- ================================================================
-- V001 - CREATE TABLE cs.polizas_ap_topes
-- Fecha: 2026-07-30
-- Descripción: persiste la suma asegurada por asegurado (con IVA).
--              polizas_ap no tiene ninguna columna de monto: sin esto
--              no hay denominador para el semáforo.
-- Ticket: <GRV-XXXX>
-- ================================================================
CREATE TABLE IF NOT EXISTS `cs`.`polizas_ap_topes` ( ... )
  ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Reglas: **idempotente** (`IF NOT EXISTS`, `INSERT ... ON DUPLICATE KEY`), `ENGINE=InnoDB`, `utf8mb4_unicode_ci` explícito, schema calificado (`cs`.`tabla`), y **un archivo por propósito**: DDL, backfill e índices separados.

> `polizas_ap` fue creada con `CHARSET=latin1` y todas las columnas nullable. Las tablas nuevas van en `utf8mb4` y con `NOT NULL` donde corresponde: no replicar ese origen.

### 5.3 Revisión previa obligatoria

Todo script pasa por el skill **`mariadb-migration-review`** antes de aplicarse. El backfill del estimado toca `turnos` (~4,3M filas): por lotes, en ventana de bajo tráfico, idempotente y con conteo antes/después.

### 5.4 Índices mínimos

| Tabla | Índice | Para qué |
|---|---|---|
| `polizas_ap_topes` | `UNIQUE (id_poliza, tipo_doc, nro_doc, ventana, activo)` | Unicidad del tope |
| `denuncia_poliza` | ya indexado por `id_denuncia` / `id_poliza` | Resolución del tope |
| `valores_venta_prestacion` | `(tipo_prestacion, id_prestacion, id_zona, estado, fecha_vigencia_desde)` | Resolver el valor vigente |
| `ap_valores_manuales` | `(id_denuncia, tipo)` | Consumo por siniestro |
| `ap_avisos_nivel_siniestro` | `UNIQUE (id_denuncia, nivel)` | Un aviso por nivel |

---

## 6. Performance

El universo AP es chico (**73 denuncias**, medición del 30/07) pero vive en tablas grandes (`turnos` ~4,3M, `erogaciones` ~1,15M). La estrategia es **acotar antes de cruzar**.

> **Medición real del universo (30/07/2026)** — ejecutada con `sql/00-diagnostico-datos-ap.sql`:
> 73 denuncias AP · 7 pólizas con siniestros (de 30 cargadas) · 70 afiliados + **3 denuncias sin afiliado** · **facturado AP $8.797.642** en 28 siniestros (38%) · **95,3% concentrado en la póliza 983320** · 761 turnos AP (148 con estimado = 19,4%) · 10 cirugías.
> La cadena para el filtro por cliente que pidió negocio es `polizas_ap.id_empleador → empleadores.id_cliente → clientes` (el cliente es la **aseguradora**; el tomador de la póliza es el club o la persona).

1. **Filtrar por el universo AP primero.** Toda consulta arranca por `denuncia_poliza` (activo = 1). Es lo que convierte el problema en trivial.
2. **Nada de `FetchType.EAGER`.** Default LAZY + `JOIN FETCH` / `@EntityGraph` / `Specification.withFetchJoins()` donde haga falta. *(Hay 9 usos de EAGER en `wsturnos`: N+1 garantizado y no desactivable por caso de uso.)*
3. **Paginación LIMIT/OFFSET** con `PageableFilter` (`limit`, `offset`, `sortField`, `ordenAsc`), y `sortField` pasado por **whitelist** (`mapSortField`) antes de armar el `Sort` — corta la inyección por ORDER BY.
4. **Vistas primero, materialización cuando se mida.** `ap_consumo_prestacion` y `ap_consumo_siniestro` como vistas; si la vista agregada de cartera pesa, materializar `ap_consumo_siniestro` con refresh por evento (auditar factura, autorizar) + batch nocturno. **No materializar antes de medir.**
5. **Agregados en la base, no en Java.** La distribución de cartera es `COUNT(*) GROUP BY nivel`, no traer 63 filas y contar en memoria (y menos cuando sean 6.300).
6. **`hibernate.jdbc.batch_size=100`** + `order_inserts/order_updates` (ya es el estándar del ecosistema) para el backfill.
7. **Virtual threads** (`spring.threads.virtual.enabled=true`) si se va con Boot 3.2 / Java 21.
8. **Sin caché.** No hay infraestructura de caché en todo el backend y este caso no la necesita: el consumo cambia por evento y el volumen es mínimo. Introducir Redis/Caffeine acá sería agregar un problema de invalidación sin beneficio medible.
9. **Prohibido el estado mutable en `static`** (colas o mapas de trabajo en memoria): rompe con más de una instancia detrás del gateway. *(Antipatrón real: `AuditoriaServiceDTOQueue`.)*

---

## 7. Eventos: ¿hace falta `wsnovedades`?

### 7.1 Qué es, en concreto

Relevado: es un canal **SSE** (`SseEmitter` sobre Spring MVC), en **Spring Boot 3.2.10 / Java 21** — uno de los servicios más modernos del ecosistema. Lo bueno es que es **genérico por diseño**: publicar un evento nuevo **no requiere tocar `wsnovedades`**, alcanza con hacer `POST /internal/eventos` (header `X-API-Token`, payload ≤ 64 KB, responde 202). Ya existe el molde de productor (`WsNovedadesClient` de `wsauditoriatraslados`, que difiere el POST a `afterCommit` para no retener la conexión de Hikari durante la llamada de red) y un hook de consumo en el front (`useNovedadesStream.ts`, con backoff exponencial). Capacidad medida: 3.000 conexiones concurrentes sin errores.

Y tiene dos límites que importan para esta decisión:

- **Entrega best-effort, sin outbox.** Si el cliente no está conectado en el instante del push, **el evento se pierde**. No hay replay ni snapshot para eventos de dominio genéricos.
- **No escala horizontalmente.** `SseHub.conexiones` es un `Set` en memoria local: con dos réplicas, un evento que entra por la instancia A no llega a los clientes de B. El propio código lo documenta ("para N réplicas se agregaría un backplane (Redis)"), y no hay Redis ni sticky sessions. Hoy corre mono-instancia con blue-green, así que funciona — pero es una dependencia con techo.

### 7.2 Veredicto: **no en la etapa 1**

Caso por caso, sobre los cuatro eventos que mueven el consumo de un siniestro AP:

| Evento | ¿Sirve el push? |
|---|---|
| Se autoriza un turno / se realiza | Le ahorraría un F5 a 2-3 personas. Con 63 siniestros, la grilla no es un tablero de pared: se abre, se mira, se cierra |
| Se audita una factura | Normalmente lo hace el mismo circuito que después mira el semáforo: ve el cambio en su propia navegación |
| **Cae una erogación tardía (batch mensual)** | **El push es inútil acá**: el batch corre desatendido, de noche, sin nadie conectado — y como el canal es best-effort sin outbox, **el evento se pierde**. Este caso solo lo resuelve el recálculo on-read |

Y hay un argumento de diseño que cierra la discusión: **el semáforo es un agregado derivado** (suma de consumo contra el tope de la póliza). Un evento del tipo "cambió el consumo del siniestro X" **no puede traer el número final confiable en el payload**, porque depende de un cruce de varias tablas: el front tendría que volver a pedir la fila igual. O sea, el push compra segundos de frescura sobre un dato **que se recalcula al leer de todos modos**.

El riesgo mayor no es técnico sino de producto: un semáforo que *parece* en vivo pero es best-effort genera **falsa confianza**. Un número de tope desactualizado que el usuario cree "en vivo" es peor que uno claramente marcado como *actualizado 14:32*.

### 7.3 Qué se hace en su lugar

- **Recálculo server-side on-read**: una sola fuente de verdad para el semáforo.
- **Refresco explícito**: botón de actualizar + leyenda **"última actualización HH:MM"** en la grilla, para que la frescura sea visible y honesta.
- **Invalidación por tags de RTK Query** tras las mutaciones del propio usuario (cargar un valor manual, editar el tope): la pantalla se actualiza sola después de su acción.
- **`refetchOnFocus`** en la vista de cartera: al volver a la pestaña, se refresca.

### 7.4 Cuándo sí valdría la pena (etapa 2+)

Si negocio pide una **notificación proactiva** — "avisame cuando un siniestro entre en Muy alto aunque no tenga la pantalla abierta" —, ese caso **no se resuelve con push a una pantalla abierta** (se perdería si no está conectada) sino con una **notificación persistente** (bandeja o mail). El terreno ya está preparado: el aviso por nivel **se persiste** en `ap_avisos_nivel_siniestro`, así que sumar el push después es agregar un productor (~medio día: una clase cliente de ~60 líneas, 4 properties y una env por ambiente), sin rediseñar nada ni tocar `wsnovedades`.

---

## 8. AWS: qué sí y qué no

### 8.1 Etapa 1: nada nuevo

El caso de uso no lo pide. Todo corre sobre la infraestructura que ya existe (contenedor detrás del gateway + MariaDB RDS). Agregar servicios administrados acá sería sumar superficie de operación sin ganancia funcional.

### 8.2 Donde sí encaja natural (etapa 2+)

| Necesidad | Servicio | Por qué |
|---|---|---|
| Ingesta del feed de precios de medicamentos | **Lambda + EventBridge Scheduler** | Es un batch periódico, sin estado, que no justifica un servicio siempre encendido |
| Guardar el archivo del feed y su historial | **S3** (+ lifecycle) | Auditoría de qué lista de precios se aplicó y cuándo |
| Sugerencias e IA asistiva | **Bedrock** (ya habilitado en la cuenta del SAS) | No hay que aprovisionar nada: el stack de agentes ya existe y se reusa |
| Métricas del semáforo | **CloudWatch** (métricas custom) | Solo si se necesita alarmar sobre datos de negocio; el `actuator` ya cubre salud |

**No** conviene: colas para el recálculo (no hay volumen), caché administrado (no hay caché), ni base de datos nueva (el dato vive en `cs` y debe cruzarse con turnos y erogaciones).

---

## 9. Observabilidad

- **Log4j2** (no SLF4J, no Lombok `@Slf4j`): `private static final Logger logger = LogManager.getLogger(X.class);`, con placeholders `{}`, nunca concatenando.
- Patrón de log pipe-delimited del ecosistema, con `%X{seguimientoServicios}` para que el `requestId` de **libInterceptor** correlacione el request entre servicios.
- **libInterceptor** (3.0.0 si se va a Boot 3) para propagar `requestId` y `Authorization` en las llamadas salientes a `wsconvenio` / `wscirugias`.
- `actuator/health` expuesto: el pipeline blue-green lo sondea antes de promover el candidato. Es contrato de deploy, no adorno.
- **Corregir el default heredado**: los `application.properties` del ecosistema traen `logging.level.org.hibernate.SQL=DEBUG` + `BasicBinder=TRACE`, que **loguea PII (DNI, nombres) en producción**. El servicio nuevo arranca con eso en `WARN`.
- Log de negocio obligatorio en tres puntos: cuando el estimado no se puede calcular (WARN con id de autorización), cuando un siniestro cambia de nivel (INFO), y cuando se carga o edita un tope (INFO con usuario).

---

## 10. Contratos de API

Todos con envelope `ResponseDTO`, permiso validado en backend y documentados en `openapi.yaml`.

### 10.1 `wsaccidentespersonales` (nuevo)

| Método | Path | Permiso | Devuelve |
|---|---|---|---|
| `GET` | `/ap/siniestros/{idDenuncia}/consumo` | `ver_semaforo_ap` | Facturado, devengado, estimado, proyección, tope, `pctProyeccion`, `nivel`, saldo, pendientes de valorizar por vía |
| `POST` | `/ap/siniestros/{idDenuncia}/impacto` | `ver_semaforo_ap` | `{ monto }` → `{ entra: boolean, consumoResultante, saldoRestante, nivelResultante }` |
| `GET` | `/ap/cartera/distribucion` | `ver_indicadores_ap` | Conteo y monto en riesgo por nivel (agregado) |
| `POST` | `/ap/cartera/siniestros` | `ver_semaforo_ap` | `FindAllResults` paginado, filtrable por cliente, nivel y período |
| `GET` | `/ap/siniestros/{idDenuncia}/cirugia/{idAutorizacion}` | `ver_consolidado_cirugia` | Consolidado por componentes (honorarios, materiales, ortopedia) |
| `POST` | `/ap/valores-manuales` | `ver_semaforo_ap` | Alta de valor de medicación / no convenida (descripción, precio, fuente, fecha) |
| `GET` | `/ap/valores-manuales/ultimo-precio` | `ver_semaforo_ap` | Último precio conocido de un medicamento |
| `POST` | `/ap/valores-venta` | `cargar_valor_venta_prestacion` | Alta con vigencia (copy-on-write) |
| `GET` | `/ap/valores-venta` | `cargar_valor_venta_prestacion` | Listado paginado con vigencias |
| `GET` | `/ap/valores-venta/{id}/historial` | `cargar_valor_venta_prestacion` | Versiones anteriores |
| `GET` | `/ap/parametros` / `PUT` | `ver_indicadores_ap` | Umbrales 40/70 y flags de aviso por nivel (rechaza mover 90/100) |

### 10.2 `wsmesacarga` (extensión)

| Método | Path | Cambio |
|---|---|---|
| `POST` | `/api/accidentes-personales/polizas` | **Suma asegurada obligatoria** (validación backend) |
| `PUT` | `/api/accidentes-personales/polizas/{id}/tope` | Edición con historial |
| `GET` | `/api/accidentes-personales/polizas/sin-tope` | Listado de pendientes de regularizar |

---

## 11. Frontend: estándares

### 11.1 Molde

**`auditoriafacturacion`** es la referencia: TypeScript + RTK Query como capa HTTP única + typed hooks + tests + `typecheck`. Estructura a copiar: `src/{pages,components,redux/{services,slices},hook,utils/urls,types,layout}/` con barrels `index.ts`.

Pero **el código nuevo se escribe en el repo donde vive la pantalla**, respetando su estilo:

| Repo | Qué usar |
|---|---|
| `tramitadores` (JS) | **RTK Query** (`src/services/*.js`, ya hay 21 APIs). No sumar thunks a la capa legacy |
| `mesadecarga` (TS) | TypeScript + typed hooks (`useAppDispatch`/`useAppSelector`). Es el momento de introducir su primer `createApi` RTK Query registrado, o seguir su patrón `createAsyncThunk` si se prefiere consistencia local |

### 11.2 Reglas transversales

- **El envelope**: la respuesta trae `{ status, body, message }`. Hay que chequear **`data.status`**, no el status HTTP (los caminos felices vienen con HTTP 200 y el status real en el cuerpo).
- **URLs** desde el archivo de constantes del MFE (`process.env.REACT_APP_API` + contexto del ws). Nunca hardcodear.
- **Permisos** con el hook `usePermissions` (`hasPermission`, `hasAnyPermission`), que lee el usuario de `getUser()` (customProps del shell, origen: cookie `datos_usuario`). Recordar: **permiso nuevo exige re-login**.
- **Nunca `useSelector` pelado** donde haya typed hooks.
- **Componentes de `sas-component-lib` primero**; si no existe, componente propio prop-driven. No reinventar tabla, drawer ni chip.
- **Montos**: formatear con el helper del repo; no `toFixed` a mano; siempre mostrar si el monto es con IVA.
- **Estados vacíos y de error explícitos**: `SIN_TOPE` no se muestra como 0% ni como semáforo verde, y "consumo incompleto" se ve.

### 11.3 Cómo se agrega la sección al detalle del siniestro (`tramitadores`)

El menú del detalle **no** es un `<Tabs>` de MUI: es el `MenuSecundario` de `sas-modules-features-lib`. Son 4 archivos:

1. `src/Routers/rutasInternas.js` — agregar el path en `rutasDenuncia` (el final queda `/home/editar/<path>`).
2. `src/Routers/useRoutes.js` — entrada con `path`, `title` y `headerTitle` (molde: la de traslados) + clave i18n en `src/Idiomas/es/tramitadores.json` (y `en/`).
3. `src/components/DenunciaCompleta/MenuDenuncia.js` — ítem en el objeto `data`. **Trampa verificada: el ícono sale de la CLAVE del objeto** (registro interno de la lib); si la clave no está registrada, el ícono queda roto. Reusar una clave conocida o coordinar el alta del ícono en la lib. Para secciones condicionadas por permiso, spread condicional (`...(puedeVerSemaforo && { COSTOS: {...} })`).
4. `src/components/DenunciaCompleta/RutasDenunciaCompleta.js` — `<Route>` con el componente contenedor.

> Cuidado con la colisión ya existente: hay claves repetidas en `MenuDenuncia.js` (`ESPECIALIDAD_MEDICA` e `INSUMO_MEDICACION` aparecen dos veces) y la segunda pisa a la primera cuando el usuario tiene ambos permisos. No agregar otra.

---

## 12. Testing

### 12.1 Backend

| Nivel | Qué se testea | Herramientas |
|---|---|---|
| Unidad de service | Clasificación de los 3 estados, doble vía, anti-doble-conteo, niveles y avisos, `SIN_TOPE`, división por cero, redondeo | JUnit 5 + Mockito + AssertJ |
| Unidad de mapper | MapStruct | JUnit 5 |
| Seguridad | `PermisoGuard`: sin permiso → 403 | `spring-security-test` |
| Integración | Vistas y queries reales contra MariaDB | **Testcontainers** (molde `IntegrationTestBase` de `wsincapacidades`, que además saltea la clase con `Assumptions.assumeTrue` si Docker no está) |
| Controller | Contrato del envelope y códigos HTTP | MockMvc |

Naming: el test **nombra el comportamiento**, no el método (`SemaforoServiceProyeccionSobreTopeTest`, no `calcularTest`). Si el service crece, se parte en varios archivos por escenario.

**Casos que no pueden faltar** (son los que la lógica de dinero se juega):
- Turno facturado que también tiene erogación → se cuenta **una** vez.
- Materiales con `monto_cotizacion` repetido por grupo → se suma una vez por grupo.
- Materiales con `grupo = 0/NULL` y montos distintos → se suman **por separado** (el bug verificado que perdía $33.000).
- Tope `NULL` o `0` → `SIN_TOPE`, sin dividir.
- Proyección sobre el tope con facturado por debajo → alerta sí, cierre no.
- Salto de dos niveles de una vez → avisa igual.

### 12.2 Frontend

`jest` + `@testing-library/react` ya están configurados en los cuatro MFEs. Se testea lo que tiene lógica: **hooks orquestadores y utils puros** (molde real: `hook/test/useBusquedaBackend.test.ts`, `utils/test/subtotalTraslado.test.ts` de `auditoriafacturacion`). Para flujos con HTTP, MSW.

Obligatorio antes de dar por terminado un MFE: **`npm run lint`** y, donde exista, **`npm run typecheck`**. Verificar con `git diff` que los archivos tocados no suman errores nuevos (varios repos ya arrastran lint roto: no hay que arreglar eso, pero tampoco sumarle).

---

## 13. Definition of Done (por entrega)

- [ ] Migraciones con la convención `V<NNN>__`, idempotentes, con cabecera, revisadas con `mariadb-migration-review` y con número verificado contra el repo.
- [ ] Endpoints con permiso validado **en el backend** y envelope `ResponseDTO`.
- [ ] `openapi.yaml` actualizado + colección Bruno de los endpoints nuevos.
- [ ] Tests: unidad de la lógica de montos + integración de las vistas + seguridad. Los seis casos de la sección 12.1 cubiertos.
- [ ] Sin `EAGER` nuevo, sin `static` mutable, sin `try/catch` que mate el handler global, sin magic numbers de catálogo (parametrizar en `cs.parametros` o constantes documentadas).
- [ ] `BigDecimal` en todo monto; nada de `double`.
- [ ] Frontend: `lint` y `typecheck` limpios en lo tocado; estados vacío/error/incompleto visibles.
- [ ] Log de negocio en los tres puntos de la sección 9.
- [ ] Review con `spring-boot-review` / `react-mfe-review` / `mariadb-migration-review` según lo tocado.
- [ ] Verificación funcional real: el consumo calculado **coincide con la planilla** para un cliente y un mes cerrado.

---

## 14. Antipatrones prohibidos (con su precedente real en el ecosistema)

| Prohibido | Precedente |
|---|---|
| God service | `TurnosServiceImpl` 5.221 líneas, `TrasladoServiceImpl` 3.557 |
| `try/catch` por endpoint devolviendo 500 con `e.getMessage()` | `wsturnos`: deja muerto el handler global y filtra internals |
| `GlobalExceptionHandler` sin `ResponseEntity` | HTTP 200 con `status: 500` en el body |
| `FetchType.EAGER` | 27 usos en `wsauditoriatraslados`, 9 en `wsturnos` → N+1 |
| Estado mutable en `static` | `AuditoriaServiceDTOQueue`: cada instancia con su propia cola |
| Lógica de negocio en stored procedures | `consulta_traslados_unificada_sp`: filtros JSON, temp tables y reglas de negocio en SQL |
| Magic numbers de catálogo en JPQL | `IN (1,2,10,11,12)` hardcodeado; cambiar un catálogo exige deploy |
| Duplicar entidades o fórmulas | `Denuncia` clonada en ~10 repos; la multiplicación NBU duplicada Java/SP |
| `logging.level.org.hibernate.SQL=DEBUG` en prod | Loguea PII (DNI, nombres) en el stdout del contenedor |
| springfox en algo nuevo | Abandonado en 2020, bloquea Boot 3 |
| Migraciones sin verificar el número | Cuatro `V014` distintos en un mismo repo |
| Confiar en el `CLAUDE.md` del repo sin verificar | Varios afirman cosas que el código no hace (springdoc que es springfox, Vite que es webpack, axios que es fetch) |

---

## 15. Orden de implementación

| # | Entrega | Repos | Depende de |
|---|---|---|---|
| 1 | Perfiles y permisos | SQL (`cs`) | Nombre del perfil confirmado |
| 2 | Migraciones DDL | SQL (`cs`) | Revisión del skill |
| 3 | Tope en la póliza | `wsmesacarga` + `mesadecarga` | 2 · ventana del tope (Q5) |
| 4 | Servicio AP: motor + semáforo | `wsaccidentespersonales` | 2 · decisión de la sección 3 |
| 5 | Hook del estimado + backfill | `wsturnos` | 4 (para medir el impacto) |
| 6 | Semáforo, avisos, saldo | `tramitadores` | 4 |
| 7 | Carga manual medicación/laboratorio | `wsaccidentespersonales` + `tramitadores` | 4 |
| 8 | Valor de venta y margen | `wsaccidentespersonales` + `tramitadores` | Mapa proveedor→zona (Q7 del docx) |

Cada entrega es desplegable por separado y no deja nada inconsistente si la siguiente se demora.

---

*Documento elaborado sobre relevamiento directo del código de `repos/grvx` (backend y frontend) y de la base `cs` — julio 2026. Las referencias `archivo:línea` son aproximadas al momento del relevamiento: verificar antes de editar.*

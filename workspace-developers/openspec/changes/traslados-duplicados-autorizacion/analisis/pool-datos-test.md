# INI-2 / GRV-2239 — Pool de datos en TEST

**Ambiente objetivo:** TEST (`db.test.sas.colonia-suiza.com.ar`, esquema `cs`; API `https://test.sas.colonia-suiza.com.ar`).
**Credenciales previstas:** las de `application-test.properties` del repo `wsturnos` (rama `release`).
**Fecha:** 2026-08-18. Primer intento ~18:30 ART (bloqueado); pool efectivamente cargado ~21:50 ART, con la VPN conectada.
**Autorización:** escritura en TEST y en DEV autorizada por la líder técnica. No se tocó producción ni stage. No se usó el MCP de MariaDB.

---

## 0. Resumen ejecutivo — el pool ya está armado

**Actualizado el 2026-08-18 a las ~21:50 ART.** Con la VPN conectada se destrabó el acceso a la base
y **el pool quedó cargado y verificado en TEST**: los cinco turnos con su traslado sobre la denuncia
999031 en la fecha de conflicto, y los tres pedidos (uno pendiente, uno aprobado, uno rechazado).
Los cinco controles del script dieron lo esperado y por eso se hizo `COMMIT`; ante cualquier desvío
el script hacía `ROLLBACK` sin dejar nada escrito.

También se aplicó el `UPDATE denuncias.id_auditor` de la sección 1.4, en TEST y en DEV, con su
rollback anotado.

**Cómo se armó, y qué implica:** por **SQL**, clonando desde un turno real de la misma denuncia que
ya tenía traslado, para heredar direcciones, prestador y tipo de viaje sin inventar ningún valor.
Eso deja las filas con el estado correcto, pero **no ejercita el código del circuito**: a diferencia
de DEV —donde los pedidos resueltos se generaron llamando al endpoint real, y por eso allí se puede
afirmar que aprobar, rechazar y cancelar con motivo 16 funcionan de verdad— acá sólo se puede afirmar
que los datos quedaron bien. La prueba funcional sigue pendiente del deploy.

| # | Estado | Qué falta |
|---|---|---|
| 1 | **RESUELTO (18/08 noche)** | El código **ya está desplegado en TEST**. El pipeline de `wsturnos` estaba **fallando** —no sin correr—: `release` no compilaba por un método faltante de **GRV-2189**, ajeno a este circuito (MR !850). Verificado: los endpoints responden y el filtro devuelve **1 fila** —el turno pendiente de este pool— en lugar de 4.412.517. |
| 2 | **RESUELTO** | El acceso a la base de TEST: la VPN está conectada y la escritura funcionó. |
| 3 | **RESUELTO** | El gestor de la denuncia: `id_auditor` aplicado en los dos ambientes. |

> ⚠️ **No desplegar el front solo a TEST.** Sin el backend, el filtro se descarta en silencio y la
> pestaña le muestra al supervisor los 4,4 millones de turnos como si fueran pedidos pendientes.

El detalle de qué quedó cargado está en la sección 2; el script que lo hizo y su rollback, en la 4.

---

## 1. La denuncia elegida: 999031

### 1.1 Por qué sirve

| Campo | Valor observado en TEST |
|---|---|
| `id_denuncia` | **999031** |
| `nro_provisorio` | `999031` (la grilla lo muestra así; `nro_asignado` viene en `null`) |
| Cliente | INST. AUTARQ. E.R. |
| `id_estado_medico` | **1 (ILT)** |
| `es_rechazado` | **0** |
| Analista que muestra la grilla | Marianela Capurro |

Es una **denuncia de QA ya usada para este circuito**: 57 turnos, varios cargados por
«Supervisor QA Tramitador» (1000008) y por «Mesa de Carga QA Ayi», con direcciones tipo
«Calle Test 100». No es un caso de negocio real, con lo cual ensuciarla no tiene costo.

### 1.2 SE-214 no bloquea — verificado por dato, no por deducción

La regla vive en `DenunciaTurnoValidator.permiteTurnosFuturos(...)` de `wsturnos`:

```java
if (esVerdadero(denuncia.getEsRechazado())) { return false; }
Long estado = denuncia.getIdEstadoMedico();
boolean ilt = EstadoMedicoEnum.ILT.getCodigo().equals(estado);
...
return ilt || sinBaja || borradorDescartada;
```

999031 tiene `id_estado_medico = 1` (ILT) y `es_rechazado = 0` → **`permiteTurnosFuturos` devuelve
`true`** y la validación de fecha ni se ejecuta.

Además hay **prueba empírica**, que es más fuerte que leer el código: la denuncia **ya tiene turnos
cargados con fecha futura** —25 al 31/08/2026 y 01 al 13/09/2026, varios con traslado en estado
Solicitado—. Si SE-214 la bloqueara, esos turnos no existirían. Verificado por API:
`POST /grv/turnos/turnos/por-denuncia` con `{"idDenuncia":999031,"findTraslados":true}` → 57 turnos.

### 1.3 La fecha elegida: 2026-09-08

Se descarta el 25/08 (es la fecha del pool de DEV, y encima 999031 ya tiene un turno con traslado
ese día). Del 01 al 07/09 y del 11 al 13/09 la denuncia **ya tiene turnos**, así que se usa un día
limpio:

> **Fecha del conflicto: `2026-09-08` (martes).** Sin turnos preexistentes en 999031, con lo cual
> todo lo que aparezca ese día es del pool y el conflicto no se contamina con datos de otras pruebas.

### 1.4 El gestor: hay que reasignarlo

Se consultó la grilla real de tramitadores contra TEST con la persona logueada de cada usuario de
prueba:

```
POST /grv/turnos/turnos/tramitadores  {"idTramitadorLogueado":1000007}  → cantidadTotal = 0
POST /grv/turnos/turnos/tramitadores  {"idTramitadorLogueado":1000008}  → cantidadTotal = 0
```

**Ninguna denuncia de TEST tiene a 1000007 ni a 1000008 como `id_auditor`.** El SP traduce
`idTramitadorLogueado` a `AND d.id_auditor = <id>`, así que sin reasignar el gestor el operador
1000007 no ve la denuncia y **la mitad de la prueba no arranca**. Es exactamente el mismo bloqueo
que quedó pendiente en DEV.

```sql
-- PASO 0, PREVIO A TODO (TEST). Anotar el valor viejo antes de pisarlo.
SELECT id_denuncia, id_auditor FROM denuncias WHERE id_denuncia = 999031;   -- anotar id_auditor

UPDATE denuncias SET id_auditor = 1000007 WHERE id_denuncia = 999031;
-- rollback:
-- UPDATE denuncias SET id_auditor = <el valor anotado> WHERE id_denuncia = 999031;
```

> El supervisor 1000008 **no** necesita este UPDATE: si tiene `consultar_grillas_supervisor`,
> el front le manda `idTramitadorLogueado: null` y ve la grilla sin filtrar por gestor.

---

## 2. Estado del pool — cargado

**Cargado y verificado el 18/08 por el script de la sección 4.1.** Los ids reales quedan fuera de este documento a propósito; cada fila es identificable por sus `observaciones`, que arrancan con `INI-2 POOL TEST`.

| Rol en la prueba | Turno | Fecha | Traslado | Estado traslado | `id_estado_logistica_ida` | `es_duplicado_autorizado` |
|---|---|---|---|---|---|---|
| (a) disparador del conflicto, **vigente y ya en logística** | T1 | 2026-09-08 09:00 | TR1 | 1 Solicitado | **1** | `NULL` |
| (b) **caso resuelto: cancelado el mismo día** | T2 | 2026-09-08 09:30 | TR2 | **4 Cancelado** (motivo 16) | `NULL` | `NULL` |
| (c) pedido **PENDIENTE** | T3 | 2026-09-08 10:00 | TR3 | 1 Solicitado | **`NULL`** ← invisible para logística | `NULL` |
| (d) pedido **APROBADO** | T4 | 2026-09-08 10:30 | TR4 | 1 Solicitado | **1** | **1** |
| (e) pedido **RECHAZADO** | T5 | 2026-09-08 11:00 | TR5 | **4 Cancelado** (motivo 16) | `NULL` | `NULL` |

Pedidos en `autorizaciones_traslado_duplicado` (la tabla estaba en **0 filas** antes de cargar el pool):

| # | `estado` | apunta a | `id_solicitante` | `id_autorizante` | `fecha_visto_solicitante` |
|---|---|---|---|---|---|
| 1 | **1 PENDIENTE** | T3 / TR3 | 1000007 | `NULL` | `NULL` |
| 2 | **2 APROBADA** | T4 / TR4 | 1000007 | **1000008** | **`NULL`** ← a propósito, sin ver |
| 3 | **3 RECHAZADA** | T5 / TR5 | 1000007 | **1000008** | **`NULL`** ← a propósito, sin ver |

Contadores esperados: **pendientes para 1000008 = 1**; **resueltos sin ver para 1000007 = 2**.
Los dos resueltos quedan sin marcar, así que la card del gestor entra con contador **2**.

---

## 3. Guion de prueba paso a paso

**Precondición innegociable:** que los cinco endpoints de la sección 6.1 dejen de dar 404. Con el
build que hoy corre en TEST, los pasos 1, 2, 3, 5 y 6 **no se pueden ejecutar**.

**Paso 0 — preparación.** Ejecutar el `UPDATE denuncias.id_auditor` de 1.4 y el script de la 4.1.

**Paso 1 — la card del gestor (la vuelta del circuito, lo nuevo de INI-2).**
- Usuario: **1000007** (`AyiOperador Tramitador QA`), el que pidió.
- Se espera: card «Traslados duplicados resueltos» con **contador = 2** (el aprobado y el rechazado).
- Verificación: `GET /grv/turnos/autorizaciones/mis-duplicados-resueltos?idSolicitante=1000007` → `body: 2`.

**Paso 2 — abrir la card y que el contador se apague.**
- Usuario: **1000007**. Clic en la card.
- Se espera: la grilla, pestaña «Mis duplicados resueltos», con **dos filas** —el aprobado y el
  rechazado, cada uno con su dictamen—; y al abrirla, el contador vuelve a **0** y la card desaparece.
- Verificación: `POST /grv/turnos/autorizaciones/marcar-duplicados-vistos {"idSolicitante":1000007}`
  → `body: 2` la primera vez y **`body: 0` la segunda** (es idempotente, no repisa la fecha del
  primer visto). Después, `mis-duplicados-resueltos` → `body: 0`.
- En base: `fecha_visto_solicitante` poblada en los pedidos 2 y 3, y no en el 1 (que sigue pendiente).

**Paso 3 — la card del supervisor.**
- Usuario: **1000008** (`Tramitador Supervisor QA`, perfil 2 `jefe_de_siniestros`).
- Se espera: card «Traslados duplicados a autorizar» con **contador = 1**. Si el contador da 0 o el
  usuario no tiene el permiso, la card no se renderiza: su sola presencia valida las dos cosas.
- Verificación: `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` → `body: 1`.

**Paso 4 — la grilla de pendientes (pestaña `trasladosDuplicadosPendientes`).**
- Usuario: **1000008**. Clic en la card.
- Se espera **una sola fila**: turno T3, denuncia 999031, fecha de turno 08/09/2026 10:00,
  solicitante «AyiOperador Tramitador QA», la justificación completa, y los botones Aprobar / Rechazar.
  El aprobado y el rechazado **no** tienen que aparecer: el SP filtra `ATD.estado = 1`.
- Verificación: `POST /grv/turnos/turnos/tramitadores {"trasladosDuplicadosPendientes":true,"limit":20,"offset":0}`.

**Paso 5 — resolver el pendiente.**
- Usuario: **1000008**. Botón Rechazar sobre la fila.
- Se espera: el dictamen es **obligatorio al rechazar** (no debe permitir confirmar vacío) y opcional
  al aprobar. Tras confirmar, la fila desaparece y la card del supervisor pasa a 0.
- Y del otro lado: **la card de 1000007 vuelve a aparecer con contador 1**, que es el punto entero de INI-2.
- Verificación en base: pedido 1 con `estado = 3`, `id_autorizante = 1000008`, `fecha_autorizacion`
  poblada, `dictamen` con el texto y `fecha_visto_solicitante` en `NULL`; y TR3 con
  `id_estado_traslado = 4`, `id_motivo_anulacion = 16`.
  Si en cambio se **aprueba**: `estado = 2` y TR3 pasa a `id_estado_logistica_ida = 1` y
  `es_duplicado_autorizado = 1`.
- Para reponer el pendiente sin rearmar el pool, la sección 4.4.

**Paso 6 — el bloque de conflicto en el alta del turno.**
- Usuario: **1000007** (sin el permiso).
- Denuncia 999031 → Turnos → turno nuevo con traslado, **fecha 08/09/2026**.
- Se espera el bloque de conflicto, porque ese día ya hay traslados vigentes (TR1, TR3 y TR4, todos
  en estado 1, que no está en el conjunto no vigente {4, 5}).
- «Declarar el motivo» debe estar **oculto o deshabilitado** (no tiene el permiso). Visibles:
  **pedir autorización** y **anular el traslado que ya existía**.
- Al elegir «pedir autorización», el pedido tiene que nacer apuntando al traslado **nuevo**, no al
  preexistente: es el defecto que `registrarPedidoDelAlta` arregló, y conviene verificarlo mirando
  `autorizaciones_traslado_duplicado.id_traslado` contra el `id_traslado` recién creado.

**Paso 7 — el atajo del que sí tiene el permiso.**
- Usuario: **1000008**. Mismo camino del paso 6.
- Se espera: el pedido **nace aprobado** (`estado = 2`, `id_autorizante = 1000008` = el solicitante) y
  el traslado baja a logística en el acto con la marca. No espera a nadie. Es la bifurcación
  `puedeAutorizarse` de `registrar(...)`.

**Paso 8 — casos de borde del autorizante (por API, los tres devuelven HTTP 200 con el resultado tipado).**

| Caso | Request a `resolver-traslado-duplicado` | Esperado |
|---|---|---|
| Sin permiso | `{"idAutorizacionTrasladoDuplicado":1,"aprobar":true,"idAutorizante":1000007}` | `SIN_PERMISO`, sin tocar nada |
| Ya resuelto | `{"idAutorizacionTrasladoDuplicado":2,"aprobar":false,"idAutorizante":1000008,"dictamen":"reintento"}` | `YA_RESUELTO` informando quién y cuándo; **no pisa** al primero |
| Inexistente | un id que no existe | `NO_ENCONTRADO` |

**Paso 9 — visibilidad para logística.**
- Usuario: logística.
- Se espera ver **TR1 y TR4**, y **NO** ver TR3 (pendiente) ni TR2/TR5 (cancelados).
- El criterio no es el estado del traslado: `consulta_traslado_remis_amb_logistica` exige
  `tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL`. **Que TR3 tenga
  `id_estado_logistica_ida` en `NULL` es el corazón del diseño**: el traslado existe pero el sector
  no lo ve hasta que alguien autoriza.
- TR4 además tiene que mostrar la marca de duplicado autorizado, para que logística no lo cancele.

---

## 4. Lo que hay que escribir, con su rollback

**Ejecutado el 18/08, con `COMMIT` tras verificar los controles.** Todo está acotado por id y marcado con
`observaciones = 'INI-2 POOL TEST …'`, así que es identificable sin depender de los ids.

### 4.1 El script del pool

```sql
-- =============================================================================================
-- INI-2 · Pool de datos en TEST · denuncia 999031 · fecha del conflicto 2026-09-08
-- EJECUTAR SOLO EN TEST. Requiere el UPDATE de id_auditor de la sección 1.4.
-- =============================================================================================
START TRANSACTION;

-- --- 0. Control previo: la denuncia admite turnos futuros (SE-214) y la tabla está vacía --------
SELECT id_denuncia, id_estado_medico, es_rechazado, id_tipo_prestacion_mantenimiento,
       fecha_alta_medica, id_auditor
  FROM denuncias WHERE id_denuncia = 999031;
-- ESPERADO: id_estado_medico = 1, es_rechazado = 0.  Si no, ABORTAR: el pool no sirve.

SELECT COUNT(1) AS pedidos_previos FROM autorizaciones_traslado_duplicado;   -- esperado 0

-- El turno base a clonar: uno de 999031 que YA tenga traslado, para heredar direcciones,
-- proveedor, tipo de traslado y tipo de viaje sin inventar nada.
SELECT t.id_turno, t.id_autorizacion, tr.id_traslado, tr.id_tipo_viaje
  FROM turnos t JOIN traslados tr ON tr.id_turno = t.id_turno
 WHERE t.id_denuncia = 999031
 ORDER BY t.id_turno DESC LIMIT 1;
-- Candidato conocido (visto por API): turno 4561064, autorización 2069038, traslado 2470608.

SET @T_BASE  = 4561064;
SET @A_BASE  = 2069038;
SET @TR_BASE = 2470608;

-- --- 1. Cinco autorizaciones clonadas ----------------------------------------------------------
-- OJO: `autorizaciones.id_autorizacion` es PK SIN auto_increment. Hay que asignar el id a mano.
SELECT MAX(id_autorizacion) INTO @A0 FROM autorizaciones;

-- MariaDB 10.5 no tiene SELECT * EXCEPT, así que se clona una por una listando las columnas.
-- Para obtener la lista:
--   SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION)
--     FROM INFORMATION_SCHEMA.COLUMNS
--    WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'autorizaciones'
--      AND COLUMN_NAME <> 'id_autorizacion';
-- Y después, con k de 1 a 5:
--   INSERT INTO autorizaciones (id_autorizacion, <esa lista>)
--   SELECT @A0 + k, <esa lista> FROM autorizaciones WHERE id_autorizacion = @A_BASE;
-- Es el mismo procedimiento que se usó en DEV.

-- --- 2. Cinco turnos clonados (id_turno SÍ es auto_increment) ----------------------------------
-- Mismo patrón: listar columnas desde INFORMATION_SCHEMA excluyendo id_turno, clonar @T_BASE y
-- después pisar lo que cambia, uno por cada fila de la tabla de la sección 2:
--   UPDATE turnos SET id_autorizacion = @A0 + k,
--                     fecha_turno      = '2026-09-08',
--                     fecha_hora_turno = '2026-09-08 09:00:00',
--                     hora_turno       = '09:00',
--                     observaciones    = 'INI-2 POOL TEST <ROL>'
--    WHERE id_turno = <el id recién creado>;
-- Horas: (a) 09:00  (b) 09:30  (c) 10:00  (d) 10:30  (e) 11:00.
-- ANTES de asumir los nombres de columna, confirmarlos contra el catálogo:
--   SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
--    WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'turnos'
--      AND (COLUMN_NAME LIKE '%%fecha%%' OR COLUMN_NAME LIKE '%%hora%%');
--   (en pymysql el %% es obligatorio: el % suelto se toma como placeholder)

-- --- 3. Cinco traslados clonados de @TR_BASE ---------------------------------------------------
-- `traslados` tiene un trigger BEFORE INSERT `generate_token_traslados` que genera el token de
-- cada clon. Es inocuo.
-- Después de clonar, pisar por cada uno:
--   UPDATE traslados
--      SET id_turno                   = <el turno correspondiente>,
--          fecha_traslado             = '2026-09-08',
--          hora_traslado              = '<la hora del turno>',
--          id_estado_traslado         = 1,      -- 4 en (b) y (e)
--          id_estado_logistica_ida    = NULL,   -- 1 en (a) y (d)
--          id_estado_logistica_vuelta = NULL,
--          es_duplicado_autorizado    = NULL,   -- 1 en (d)
--          id_motivo_anulacion        = NULL,   -- 16 en (b) y (e)
--          observaciones_anulacion    = NULL,   -- texto del rechazo en (e)
--          observaciones              = 'INI-2 POOL TEST <ROL>'
--    WHERE id_traslado = <el id recién creado>;
-- La columna de observaciones de anulación se llama `observaciones_anulacion`, SIN sufijo.
-- `id_estado_logistica_vuelta` queda en NULL salvo que el traslado base sea id_tipo_viaje = 2:
-- el servicio le da estado al tramo de vuelta sólo en ese caso.

-- --- 4. Los tres pedidos -----------------------------------------------------------------------
INSERT INTO autorizaciones_traslado_duplicado
  (id_autorizacion, id_traslado, estado, justificacion, id_solicitante,
   fecha_solicitud, id_autorizante, fecha_autorizacion, dictamen, fecha_visto_solicitante)
VALUES
  (@A0+3, <TR3>, 1,
   'INI-2 POOL TEST - Interconsulta con traumatologia el mismo dia de la kinesiologia.',
   1000007, NOW(), NULL, NULL, NULL, NULL),
  (@A0+4, <TR4>, 2,
   'INI-2 POOL TEST - Estudio de imagenes y control, paciente con inmovilizacion.',
   1000007, NOW(), 1000008, NOW(),
   'Aprobado: interconsulta justificada, paciente con inmovilizacion.', NULL),
  (@A0+5, <TR5>, 3,
   'INI-2 POOL TEST - Segunda consulta el mismo dia por demora del prestador.',
   1000007, NOW(), 1000008, NOW(),
   'Rechazado: los estudios se pueden agendar otro dia, no corresponde segundo traslado.', NULL);
-- fecha_visto_solicitante en NULL en los tres: es lo que deja la card del gestor en 2.

-- --- 5. Controles ------------------------------------------------------------------------------
SELECT COUNT(1) FROM autorizaciones_traslado_duplicado WHERE estado = 1;                    -- 1
SELECT COUNT(1) FROM autorizaciones_traslado_duplicado
 WHERE id_solicitante = 1000007 AND estado IN (2,3) AND fecha_visto_solicitante IS NULL;    -- 2
SELECT id_traslado, id_estado_traslado, id_estado_logistica_ida, es_duplicado_autorizado
  FROM traslados WHERE observaciones LIKE 'INI-2 POOL TEST%%';
-- ESPERADO: (a) 1/1/NULL  (b) 4/NULL/NULL  (c) 1/NULL/NULL  (d) 1/1/1  (e) 4/NULL/NULL

COMMIT;
-- ROLLBACK;  -- si algún control no da lo esperado
```

> **Cómo se hizo en DEV y por qué conviene repetirlo así:** los pedidos (d) y (e) **no** se
> insertaron ya resueltos, se cargaron como PENDIENTE y se resolvieron llamando al endpoint real
> `POST /autorizaciones/resolver-traslado-duplicado`. Eso es lo que permite afirmar que la
> aprobación, el rechazo, la cancelación con motivo 16 vía `wslogistica` y el guard de idempotencia
> **funcionan de verdad**, y no sólo que las filas quedaron con el valor correcto. En TEST **hoy no
> se puede** (el endpoint da 404); en cuanto se despliegue, hacerlo así y no con el INSERT de arriba.

### 4.2 Alternativa preferible, cuando el deploy esté

Con los endpoints arriba, el pool se arma casi entero ejercitando el código real:

1. **T1, T2, T3, T4, T5** por `POST /grv/turnos/turnos/crear` (multipart, part `dto` con
   `Content-Type: application/json`), con `idDenuncia: 999031` y `fechaTurno: 2026-09-08T…`.
   El primero pasa limpio; del segundo en adelante el gate server-side devuelve **409 CONFLICT**
   («El paciente ya tiene un traslado ese día…»), y ahí se elige el camino: `idMotivoTrasladoMismoDia`
   (1 Auditoría Médica / 2 Supervisión) o el pedido de excepción.
2. **Los tres pedidos** por `POST /grv/turnos/autorizaciones/pedir-traslado-duplicado`:
   ```json
   {"idAutorizacion": 0, "idTraslado": 0,
    "justificacion": "INI-2 POOL TEST - ...", "idSolicitante": 1000007}
   ```
   Con `idSolicitante: 1000007` nace **PENDIENTE**; con 1000008 nacería **APROBADA** de una
   (bifurcación `puedeAutorizarse`). `justificacion` es `@NotBlank` e `idAutorizacion`/`idSolicitante`
   son `@NotNull`; de las dos columnas de traslado se manda **una sola**: `idTraslado` para traslado
   normal, `idTrasladoTransportePublico` para transporte público.
3. **Resolver dos de ellos** por `POST /grv/turnos/autorizaciones/resolver-traslado-duplicado`:
   ```json
   {"idAutorizacionTrasladoDuplicado": 0, "aprobar": true,
    "idAutorizante": 1000008, "dictamen": "..."}
   ```
4. **No llamar** a `marcar-duplicados-vistos` al armar: hay que dejar los dos resueltos sin ver.

Contratos leídos de `PedirAutorizacionDuplicadoDTO`, `ResolverAutorizacionDuplicadoDTO` y
`MarcarDuplicadosVistosDTO` en `origin/release` de `wsturnos`. No hay adivinanza.

### 4.3 Rollback completo

```sql
-- ===== ROLLBACK INI-2 pool TEST · denuncia 999031 =====
-- EJECUTAR SOLO EN TEST. Hijos antes que padres.
START TRANSACTION;

-- 1. Los pedidos (la tabla estaba en 0 filas antes de la preparación)
DELETE FROM autorizaciones_traslado_duplicado
 WHERE id_autorizacion IN (@A0+1, @A0+2, @A0+3, @A0+4, @A0+5);

-- 2. Traslados clonados
DELETE FROM traslados WHERE observaciones LIKE 'INI-2 POOL TEST%%';

-- 3. Turnos clonados
DELETE FROM turnos WHERE observaciones LIKE 'INI-2 POOL TEST%%';

-- 4. Autorizaciones clonadas
DELETE FROM autorizaciones WHERE id_autorizacion IN (@A0+1, @A0+2, @A0+3, @A0+4, @A0+5);

COMMIT;
-- ROLLBACK;

-- ===== Paso manual, sólo si se ejecutó (sección 1.4) =====
-- UPDATE denuncias SET id_auditor = <el valor anotado> WHERE id_denuncia = 999031;

-- ===== Controles post-rollback =====
SELECT COUNT(1) FROM autorizaciones_traslado_duplicado;                              -- 0
SELECT COUNT(1) FROM turnos    WHERE observaciones LIKE 'INI-2 POOL TEST%%';         -- 0
SELECT COUNT(1) FROM traslados WHERE observaciones LIKE 'INI-2 POOL TEST%%';         -- 0
SELECT COUNT(1) FROM turnos WHERE id_denuncia = 999031;                              -- 57
```

> Si se rechazó algún pedido por API, `wslogistica` pudo escribir bitácora propia sobre ese
> traslado (`fetchLogisticaOnCancelacion`, motivo 16). En ese caso el `DELETE FROM traslados` puede
> fallar por FK: hay que borrar primero esos registros satélite. Todos son de traslados creados por
> el pool, así que no hay riesgo de arrastrar datos ajenos.
>
> Los turnos que la prueba manual cree desde la pantalla **no** llevan la marca `INI-2 POOL TEST`:
> anotar sus ids durante la prueba y borrarlos aparte.

### 4.4 Reponer el escenario PENDIENTE sin rearmar el pool

```sql
UPDATE autorizaciones_traslado_duplicado
   SET estado = 1, id_autorizante = NULL, fecha_autorizacion = NULL,
       dictamen = NULL, fecha_visto_solicitante = NULL
 WHERE id_autorizacion = @A0+3;

UPDATE traslados
   SET id_estado_traslado = 1, id_estado_logistica_ida = NULL, es_duplicado_autorizado = NULL,
       id_motivo_anulacion = NULL, observaciones_anulacion = NULL
 WHERE id_traslado = <TR3>;
```

Y para volver a levantar la card del gestor sin resolver nada nuevo:

```sql
UPDATE autorizaciones_traslado_duplicado
   SET fecha_visto_solicitante = NULL
 WHERE id_solicitante = 1000007 AND estado IN (2, 3);
```

---

## 5. Qué se verificó, con qué, y qué dio

### 5.1 Por endpoint, contra TEST

| Verificación | Request | Resultado |
|---|---|---|
| El servicio está arriba | `GET /grv/turnos/actuator/health` | **`{"status":"UP"}`** |
| El servicio llega a la base | `GET /grv/turnos/autorizaciones/consumo-cie10/1` | **200** con datos reales (topes CONSULTA/ESTUDIO/FKT) |
| Contador de pendientes | `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` | **404** |
| Contador de resueltos sin ver | `GET /grv/turnos/autorizaciones/mis-duplicados-resueltos?idSolicitante=1000007` | **404** |
| Pedir la excepción | `POST /grv/turnos/autorizaciones/pedir-traslado-duplicado` | **404** |
| Resolver | `POST /grv/turnos/autorizaciones/resolver-traslado-duplicado` | **404** |
| Marcar vistos | `POST /grv/turnos/autorizaciones/marcar-duplicados-vistos` | **404** |
| Pestaña de pendientes del SP | `POST /grv/turnos/turnos/tramitadores {"trasladosDuplicadosPendientes":true,"limit":5}` | **200 con `cantidadTotal = 4.412.512`** — el filtro se **ignora**: devolvió la grilla completa desde 2016 |
| Denuncia candidata / SE-214 | `POST /grv/turnos/turnos/por-denuncia {"idDenuncia":999031,"findTraslados":true}` | **200**, 57 turnos, con fechas futuras hasta 13/09/2026 y traslados en Solicitado |
| Grilla del operador | `POST /grv/turnos/turnos/tramitadores {"idTramitadorLogueado":1000007}` | **200**, `cantidadTotal = 0` |
| Grilla del supervisor filtrando por gestor | idem con 1000008 | **200**, `cantidadTotal = 0` |
| ILT candidatas | `POST .../tramitadores {"idEstadosMedico":"1","ordenIdTurno":true,"esOrdenarDesc":true}` | **200**, 112.645 turnos; los más recientes son de 999031 y de E464103 / B464139, todas con `idEstadoMedico = 1` y `esRechazado = 0` |

Ninguno de estos requests necesitó token: **los endpoints de `wsturnos` en TEST responden sin
autenticación**, igual que en DEV.

### 5.2 Por SQL

**Nada.** No hubo conexión a la base (sección 6.2). Los contadores de pendientes y de resueltos sin
ver, el SP en sus dos pestañas y el estado de logística de cada traslado **quedaron sin verificar**,
porque dependen o de los endpoints caídos o de la base inalcanzable.

### 5.3 Por código, en `origin/release` de `wsturnos`

- `AutorizacionesController`: los cinco `@Mapping` del circuito **existen en `release`**. El 404 no es
  un problema de ruta ni de gateway (el body del error muestra `path: /wsturnos/autorizaciones/…`,
  o sea que el gateway ruteó bien y la app respondió 404): es que **el build desplegado no es ese**.
- `AutorizacionTrasladoDuplicadoServiceImpl`: `pedir`, `registrarPedidoDelAlta`, `registrar`,
  `resolver`, `aprobar`, `rechazar`, `contarPendientes`, `contarResueltosSinVer`,
  `marcarResueltosComoVistos`. La bifurcación `puedeAutorizarse` y el guard de idempotencia están.
- `DenunciaTurnoValidator.permiteTurnosFuturos`: la regla de SE-214, transcripta en 1.2.
- `TramitadoresFilterDTO`: tiene `trasladosDuplicadosPendientes`, `misDuplicadosResueltos` y
  `idSolicitanteDuplicado`. Que la llamada con el filtro devuelva 4,4 millones de filas prueba que
  **el DTO desplegado no tiene esos campos** y Jackson los descarta.
- Schema de `autorizaciones_traslado_duplicado`: PK `id_autorizacion_traslado_duplicado`
  (`AUTO_INCREMENT`), FKs a `autorizaciones`, `traslados` y `traslados_transporte_publico`;
  `estado` 1/2/3; `justificacion` NOT NULL.
- Front: `turnosApi.js` de `tramitadores` en `origin/release` **y** en `origin/develop` ya define las
  llamadas a los tres endpoints nuevos.

---

## 6. Bloqueos

### 6.1 CRÍTICO — el código de INI-2 no está desplegado en TEST

**Los cinco endpoints del circuito devuelven 404 en TEST**, aunque están en `origin/release`:

```
GET  /grv/turnos/autorizaciones/traslados-duplicados-pendientes   → 404
GET  /grv/turnos/autorizaciones/mis-duplicados-resueltos          → 404
POST /grv/turnos/autorizaciones/pedir-traslado-duplicado          → 404
POST /grv/turnos/autorizaciones/resolver-traslado-duplicado       → 404
POST /grv/turnos/autorizaciones/marcar-duplicados-vistos          → 404

{"timestamp":"2026-08-18T21:33:29.843+0000","status":404,"error":"Not Found",
 "message":"No message available","path":"/wsturnos/autorizaciones/pedir-traslado-duplicado"}
```

No es un problema de ruteo: el mismo controller responde **200** en un endpoint viejo
(`/autorizaciones/consumo-cie10/1`, con datos reales de la base), `actuator/health` dice `UP`, y el
`path` del error muestra que el gateway reescribió bien. **La app está sana; le falta el código.**

La segunda evidencia es más contundente todavía, porque no depende de una ruta:

```
POST /grv/turnos/turnos/tramitadores {"trasladosDuplicadosPendientes":true,"limit":5,"offset":0}
→ 200, cantidadTotal = 4412512   (turnos desde 2016)
```

El filtro **se descarta en silencio** y devuelve la grilla completa. O sea que el
`TramitadoresFilterDTO` desplegado no tiene el campo: el build de TEST es **anterior a todo el
circuito**, no sólo al último commit. Es el peor modo de falla de este endpoint, porque no da error:
si el front nuevo se despliega contra este backend, la pestaña «Traslados duplicados» le muestra al
supervisor 4,4 millones de turnos como si fueran pedidos pendientes.

Del lado del front, el bundle que TEST está sirviendo hoy
(`https://test.sas.colonia-suiza.com.ar/static/js/main.64fe4179.js`, 11 MB, con los strings sin
ofuscar) **no contiene ninguna de las cadenas del circuito** —`pedir-traslado-duplicado`,
`mis-duplicados-resueltos`, `marcar-duplicados-vistos`, `trasladosDuplicadosPendientes`—. Eso apunta
a que en TEST **ni el front ni el back** tienen INI-2, lo que al menos evita el desajuste que sí
hubo en DEV (front adelante del backend). No es concluyente para el MFE de tramitadores, que se
carga en un chunk aparte y no se pudo enumerar desde afuera.

**Qué hace falta:** que CodePipeline efectivamente promueva `release` de `wsturnos` a TEST y
redespliegue. **La premisa del enunciado —«el código está promovido a `release`, así que TEST debería
tener los endpoints»— es falsa hoy.** Promovido a la rama no es desplegado: el webhook no corrió, o
corrió y falló, o el pipeline de TEST toma otra rama. No se pudo mirar el pipeline por lo de 6.2.

### 6.2 CRÍTICO — no hay acceso a la base de TEST desde esta máquina

Sin este acceso, la caída a SQL directo que el enunciado prevé como plan B **tampoco es ejecutable**,
y por eso no hay ni una fila escrita.

```
pymysql → db.test.sas.colonia-suiza.com.ar:3306
(2003, "Can't connect to MySQL server ... [Errno 11001] getaddrinfo failed")
```

El diagnóstico, en tres pasos:

1. `db.test.sas.colonia-suiza.com.ar` **es un CNAME** a
   `sas-test-rds-1.cp8myi00ytpg.us-west-2.rds.amazonaws.com`.
2. Ese endpoint de RDS **no resuelve a ninguna IP** desde un resolver público: la instancia **no es
   publicly accessible**. Sólo se llega desde dentro de la VPC.
3. Esta máquina **no tiene túnel a esa VPC**: no hay adaptador de VPN levantado, y los jump hosts
   que figuran en `known_hosts` (`local-vm.test.sas.colonia-suiza.com.ar`,
   `local-vm.dev.sas.colonia-suiza.com.ar`) **tampoco resuelven**, así que también son privados.

Lo mismo pasa con DEV (`sas-dev-rds-1` no resuelve), con lo cual **no es algo de TEST: es que la
estación no está conectada a la red del SAS**. La base de TEST está viva —`wsturnos` le consulta y
devuelve datos—; lo que falta es el camino desde acá.

Y el atajo por AWS también está cerrado:

```
aws rds describe-db-instances --profile grv-sas
aws: [ERROR]: Error when retrieving token from sso: Token has expired and refresh failed
```

**Para destrabarlo hacen falta dos cosas, ninguna de las cuales se puede hacer sin la persona
delante:**

```
! aws sso login --profile grv-sas
```

y levantar la VPN o el túnel al bastión de TEST. Con la sesión SSO viva se puede además confirmar
por qué el pipeline de 6.1 no desplegó, y si hiciera falta prender el ambiente:

```
python .claude/skills/ambientes-aws/ambientes_aws.py estado
```

> Se descartó que sea el scheduler nocturno: el intento fue un **martes 18:31 ART**, dentro de la
> franja 07:00–22:00 lun-vie, y de hecho el `wsturnos` de TEST está arriba y consultando la base.

### 6.3 IMPORTANTE — ninguna denuncia de TEST tiene como gestor a los usuarios de prueba

`idTramitadorLogueado` = 1000007 → 0 turnos. Con 1000008 → 0 también. El SP filtra por
`d.id_auditor`, así que **el operador no ve ninguna denuncia** y los pasos 6 y 7 del guion no
arrancan. Hay que ejecutar el `UPDATE denuncias.id_auditor` de la sección 1.4 —anotando antes el
valor viejo, porque el rollback lo necesita—. Es el mismo bloqueo que quedó abierto en DEV.

### 6.4 MENOR — no se pudo confirmar por base con qué usuario se loguea cada persona

`personas` no guarda el usuario del front (el mapeo vive en LDAP/Keycloak). Los ids 1000007 y
1000008 vienen dados y ya verificados por quien preparó la base de TEST, pero **QA tiene que
confirmar con qué usuario entra cada uno** antes de la prueba. Si alguno no existe, hay que cambiar
el `id_solicitante` de los tres pedidos y el `id_auditor` del paso 0.

### 6.5 NOTA — los endpoints de `wsturnos` en TEST responden sin autenticación

`consumo-cie10`, `turnos/tramitadores` y `turnos/por-denuncia` contestaron a `curl` **sin ningún
token**, igual que en DEV. Es lo que permitió elegir la denuncia y verificar el deploy sin
credenciales, pero conviene tenerlo presente: el permiso del circuito se valida contra el
`idAutorizante` que viene **en el body**, así que cualquiera que alcance el servicio puede resolver
un pedido pasando el id de una persona que sí tenga el permiso. En TEST es aceptable; **en stage y
prod el servicio tiene que estar detrás del gateway con autenticación**, porque la defensa de
permiso del backend no reemplaza a la de identidad.

### 6.6 NOTA — riesgo de orden entre migración y código, ya materializado en TEST

En TEST el SP `consulta_turnos_tramitadores_sp` **ya tiene las dos pestañas** (aplicado y verificado
antes de este trabajo) pero **el Java que lo usa no está desplegado**. Es el mismo patrón que se
anotó en DEV, sólo que acá está en el estado inverso y sostenido: la base va adelante del código. No
rompe nada hoy —el DTO viejo simplemente no manda los flags nuevos—, pero es la configuración en la
que el listado principal de tramitadores se rompe si el mapeo de resultados no tolera columnas
extra. Conviene no dejarla así más tiempo del necesario.

---

## 7. Anexo — constantes del circuito

Valores tomados del código en `origin/release` y de los scripts de migración. **Los ids de catálogo
pueden diferir entre DEV y TEST; los de esta tabla son de código o de script, no de base, salvo
donde se aclara.**

| Concepto | Valor |
|---|---|
| Estados del pedido | 1 PENDIENTE, 2 APROBADA, 3 RECHAZADA (`EstadoAutorizacionDuplicadoEnum`) |
| Estados de traslado no vigentes | 4 Cancelado, 5 Rechazado |
| Estado de logística al aprobar | 1 SOLICITADO (`Constantes.ESTADO_LOGISTICA_SOLICITADO`) |
| Marca de duplicado | `es_duplicado_autorizado = 1`, en `traslados` **y** en `traslados_transporte_publico` |
| Motivo de anulación al rechazar | 16 «Cancelado por alarma repetida» |
| Motivos del mismo día | 1 Auditoría Médica, 2 Supervisión |
| Tramo de vuelta | recibe estado de logística **sólo** si `id_tipo_viaje = 2` |
| Visibilidad para logística | `id_estado_logistica_ida IS NOT NULL` **y** `tu.fecha_turno IS NOT NULL` |
| Permiso | `autorizar_traslado_mismo_dia`, asignado en TEST a los perfiles 2, 3, 9 y 10 |
| Autorizante de la prueba | **1000008**, perfil 2 `jefe_de_siniestros`, con el permiso |
| Solicitante de la prueba | **1000007**, perfil 4 `analista_enfermedades_profesionales`, sin el permiso |
| Columna del visto | `autorizaciones_traslado_duplicado.fecha_visto_solicitante`, `NULL` = sin ver |
| PK del pedido | `id_autorizacion_traslado_duplicado`, `AUTO_INCREMENT` |
| `autorizaciones.id_autorizacion` | PK **sin** `auto_increment` → asignar con `MAX(id)+1` |
| Trigger en `traslados` | `BEFORE INSERT generate_token_traslados`, inocuo al clonar |
| Observaciones de anulación | `observaciones_anulacion`, **sin sufijo** |
| Denuncia elegida | **999031**, ILT (`id_estado_medico = 1`), `es_rechazado = 0` |
| Turno base a clonar | **4561064** (autorización **2069038**, traslado **2470608**) |
| Fecha del conflicto | **2026-09-08** (día sin turnos preexistentes en 999031) |
| Marca del pool | `observaciones = 'INI-2 POOL TEST <ROL>'` |

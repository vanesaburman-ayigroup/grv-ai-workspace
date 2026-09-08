# GRV-2239 — Pool de datos en DEV sobre la denuncia B464435

**Ambiente:** DEV únicamente (`db.dev.sas.colonia-suiza.com.ar`, esquema `cs`; API `https://dev.sas.colonia-suiza.com.ar`).
**Credenciales:** las de `application-dev.properties` del repo `wsturnos`.
**Fecha de preparación:** 2026-08-14.
**Autorización:** escritura en DEV autorizada por la líder técnica. No se tocó producción ni test. No se usó el MCP de MariaDB (apunta a la réplica de prod y es read-only); se operó con pymysql contra DEV.

---

## 0. Resumen ejecutivo

El pool quedó armado y **el tramo del autorizante se probó de punta a punta contra el código real desplegado en DEV**: se ejercitaron por API los cuatro resultados del endpoint de resolución (`APROBADA`, `RECHAZADA`, `SIN_PERMISO`, `YA_RESUELTO`) y se verificó en base cada efecto colateral.

**El circuito no se puede probar completo hoy.** El endpoint que registra el pedido —`POST /autorizaciones/pedir-traslado-duplicado`— **no está desplegado en DEV y devuelve 404**, mientras que el front de `develop` ya lo invoca. El tramo del operador que termina en «pedir autorización» queda cortado. El detalle está en la sección 6.

---

## 1. Estado en que quedó la denuncia B464435

### 1.1 Identificación

`B464435` **no es un `nro_asignado`**: es el **`nro_provisorio`**. La denuncia es:

| Campo | Valor |
|---|---|
| `id_denuncia` | **464435** |
| `nro_provisorio` | `B464435` |
| `nro_asignado` | `NULL` |
| Paciente | Ragnar Lothbrok (DNI 38401345) |
| Empleador / cliente | GCBA / PROVINCIA ART (`id_cliente` = 3) |
| Gestor (`id_auditor`) | **1892 — Agustina Lick Leal** |
| `id_estado_medico` | **1 (ILT)** |
| `es_rechazado` | 0 |
| `se_solicita_rechazo` | 0 |
| `id_tipo_prestacion_mantenimiento` | `NULL` |
| `fecha_rechazo` | `NULL` |
| `activo` | 1 |

### 1.2 SE-214 no bloquea la prueba

La validación de SE-214 (`DenunciaTurnoValidator.permiteTurnosFuturos`) admite turnos futuros cuando la denuncia está en **ILT (`id_estado_medico` = 1)** y **no está rechazada**. La denuncia cumple ambas condiciones, con lo cual **admite turnos con fecha futura y no interfiere**. No hace falta alternativa.

### 1.3 Turnos y traslados (estado final)

Fecha elegida para el conflicto: **2026-08-15** (mañana respecto de la preparación).

| `id_turno` | Fecha / hora | Estado turno | `id_autorizacion` | `id_traslado` | Estado traslado | `id_estado_logistica_ida` | `es_duplicado_autorizado` | Rol en la prueba |
|---|---|---|---|---|---|---|---|---|
| 4560360 | — | 16 Pend. Programación por Case | 2068736 | — | — | — | — | preexistente, sin traslado |
| 4560361 | 2026-07-06 10:00 | 23 Realizado | 2068737 | — | — | — | — | preexistente |
| 4560362 | 2026-07-07 10:00 | 24 No Realizado | 2068737 | — | — | — | — | preexistente |
| 4560363 | 2026-07-08 10:00 | 4 Prog. Sin Traslados | 2068737 | — | — | — | — | preexistente |
| **4560454** | **2026-08-15 10:44** | 13 Pend. Aprobación [PCT] | 2068782 | **1469807** | 1 Solicitado | **1** | `NULL` | **(a) disparador del conflicto** |
| **4560455** | **2026-08-15 11:15** | 13 Pend. Aprobación [PCT] | 2068783 | **1469808** | 1 Solicitado | `NULL` | `NULL` | **(b) pedido PENDIENTE** |
| **4560456** | **2026-08-15 12:30** | 13 Pend. Aprobación [PCT] | 2068784 | **1469809** | 1 Solicitado | **1** | **1** | **(c) pedido APROBADO** |
| **4560457** | **2026-08-15 13:45** | 13 Pend. Aprobación [PCT] | 2068785 | **1469810** | **4 Cancelado** (motivo anulación **16**) | `NULL` | `NULL` | **(d) pedido RECHAZADO** |

Todos los traslados son **tipo de viaje 1 (sólo ida)**, heredado del traslado base. Por eso `id_estado_logistica_vuelta` queda en `NULL` incluso en el aprobado: el servicio da estado de logística al tramo de vuelta sólo si `id_tipo_viaje = 2`.

### 1.4 Pedidos en `autorizaciones_traslado_duplicado`

La tabla estaba en **0 filas**. Quedó con 3:

| `id` | `estado` | `id_autorizacion` | `id_traslado` | `id_solicitante` | `id_autorizante` | `fecha_autorizacion` | Dictamen |
|---|---|---|---|---|---|---|---|
| **1** | **1 PENDIENTE** | 2068783 | 1469808 | 1000007 | `NULL` | `NULL` | `NULL` |
| **2** | **2 APROBADA** | 2068784 | 1469809 | 1000007 | 1000008 | 2026-08-14 09:29:28 | «Aprobado: interconsulta justificada, paciente con inmovilizacion.» |
| **3** | **3 RECHAZADA** | 2068785 | 1469810 | 1000007 | 1000008 | 2026-08-14 09:29:28 | «Rechazado: los estudios se pueden agendar otro dia, no corresponde segundo traslado.» |

**Contador de pendientes = 1.** Verificado por API: `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` → `{"status":200,"body":1}`.

---

## 2. Usuarios a usar

### 2.1 El que tiene el permiso (autorizante)

| Campo | Valor |
|---|---|
`id_persona` | **1000008** |
| Nombre | Tramitador Supervisor QA |
| Usuario del front | `tramitador.supervisor` |
| Perfil SAS | **2 — `jefe_de_siniestros`** (`personas_perfiles_sas.activo` = 1) |
| Permiso `autorizar_traslado_mismo_dia` | **SÍ** (`id_permiso` = 1000) |

Se verificó con la **misma query nativa que usa el backend** (`IPermisoSasRepository.contarPermisoDePersona`): devuelve 1 para 1000008.

Además cuenta con los permisos que la pantalla necesita:

- `consultar_home_supervisor` (5) → aterriza en `HomeReferenteSupervisor`, que es **donde vive la card**.
- `consultar_grillas_supervisor` (7) → activa `permisoRolesSuperiores` en `Turnos.js`, con lo cual **`idTramitadorLogueado` viaja en `null` y ve la grilla sin filtrar por gestor**. Por eso ve el pedido de B464435 aunque la denuncia no sea suya.

Otros perfiles con el permiso, si se quiere ampliar la prueba: 3 `referente_siniestros`, 9 `gerente_de_siniestros`, 10 `supervisor`.

### 2.2 El que NO tiene el permiso (operador / solicitante)

| Campo | Valor |
|---|---|
| `id_persona` | **1000007** |
| Nombre | AyiOperador Tramitador QA |
| Perfil SAS | **11 — `analista_requerimientos`** |
| Permiso `autorizar_traslado_mismo_dia` | **NO** (la query del backend no devuelve fila) |

Es el `id_solicitante` de los tres pedidos cargados, así que la grilla del supervisor ya muestra «AyiOperador Tramitador QA» como solicitante (verificado en la respuesta del listado).

**Advertencia sobre este usuario:** `personas` no guarda el nombre de usuario del front (el mapeo vive en LDAP/Keycloak), por lo que **no se pudo confirmar por base con qué usuario se ingresa como 1000007**. Confirmarlo con QA antes de la prueba. Si el usuario real de la persona 1000007 no existe, reemplazar 1000007 por la persona que efectivamente se use, en `autorizaciones_traslado_duplicado.id_solicitante` y en el paso 2.3.

### 2.3 Restricciones de alcance

- **No hay tabla de alcance por cuenta, cliente ni cartera para personas.** Las únicas tablas de scoping son `personas_perfiles_sas` (perfiles) y `personas_supervisores` (jerarquía). No hay nada que limite a estos usuarios a un cliente o cartera puntual.
- **Sí hay alcance por gestor, y afecta al operador.** `Turnos.js` arma el request con `idTramitadorLogueado: permisoRolesSuperiores ? null : usuarioActivo.id`, y el SP traduce eso a `AND d.id_auditor = <id>`. Como 1000007 **no** tiene ningún permiso de grillas superiores, sólo vería denuncias donde `d.id_auditor = 1000007`, y **B464435 tiene `id_auditor = 1892`**.

  Para que el operador vea y gestione la denuncia hay que **reasignarle el gestor**. Este UPDATE **no se ejecutó** (quedó bloqueado por el clasificador de permisos del entorno, y además reasignar el gestor de una denuncia es una decisión de negocio):

  ```sql
  -- PASO MANUAL PREVIO A LA PRUEBA (DEV)
  UPDATE denuncias SET id_auditor = 1000007 WHERE id_denuncia = 464435 AND id_auditor = 1892;
  -- rollback:
  -- UPDATE denuncias SET id_auditor = 1892 WHERE id_denuncia = 464435 AND id_auditor = 1000007;
  ```

- **Segundo detalle del operador:** el perfil 11 `analista_requerimientos` sólo aporta permisos de requerimientos (`consultar_home_perfil_requerimientos`, `consultar_grilla_perfil_requerimientos`, `crear_nuevo_requerimiento`, `crear_nuevo_seguimiento_requerimiento`). **No tiene ningún permiso de turnos ni de grillas de tramitador.** Si al ingresar aterriza en el home de requerimientos en lugar del home de gestor, dar de baja lógica ese vínculo para que quede como gestor «pelado»:

  ```sql
  -- OPCIONAL, sólo si el perfil 11 desvía el home del operador
  UPDATE personas_perfiles_sas SET activo = 0, fecha_baja = NOW(), usuario_baja = 'GRV-2239'
   WHERE id_persona = 1000007 AND id_perfil = 11 AND activo = 1;
  -- rollback:
  -- UPDATE personas_perfiles_sas SET activo = 1, fecha_baja = NULL, usuario_baja = NULL
  --  WHERE id_persona = 1000007 AND id_perfil = 11;
  ```

---

## 3. Guion de prueba paso a paso

### 3.A — Lo que se puede probar hoy

**Paso 0 (preparatorio, base).** Ejecutar el UPDATE de `d.id_auditor` de la sección 2.3. Sin esto los pasos 4 a 6 no son ejecutables.

---

**Paso 1 — La card del home del autorizante.**
- Usuario: **`tramitador.supervisor` (1000008)**.
- Pantalla: home de referente/supervisor.
- Se espera ver: una card «Traslados duplicados a autorizar» con **contador = 1**. La card no se renderiza si el contador da 0 ni si el usuario no tiene el permiso, así que su sola presencia valida las dos cosas.
- Verificación en base:
  ```sql
  SELECT COUNT(1) FROM autorizaciones_traslado_duplicado WHERE estado = 1;  -- espera 1
  ```
  Y por API: `GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes` → `body: 1`.

**Paso 2 — La grilla de pedidos pendientes.**
- Usuario: **1000008**. Clic en la card.
- Pantalla: Turnos, pestaña «Traslados duplicados» (`TAB_TURNOS.DUPLICADOS_PENDIENTES` = 5).
- Se espera ver **una sola fila**: turno **4560455**, denuncia `B464435`, paciente Ragnar Lothbrok, fecha de turno **2026-08-15 11:15**, solicitante **«AyiOperador Tramitador QA»**, fecha del pedido 2026-08-14, la justificación completa, y los botones **Aprobar** y **Rechazar**.
- La grilla debe mostrar **sólo el pendiente**: el aprobado (4560456) y el rechazado (4560457) **no** tienen que aparecer, porque el SP filtra `ATD.estado = 1`.
- Verificación por API (ya comprobada, devuelve exactamente esa fila):
  ```
  POST /grv/turnos/turnos/tramitadores
  {"trasladosDuplicadosPendientes": true, "limit": 20, "offset": 0}
  ```

**Paso 3 — Resolver el pedido pendiente desde la grilla.**
- Usuario: **1000008**. Botón **Rechazar** sobre la fila.
- Se espera: el drawer exige el **dictamen de forma obligatoria** (no debe permitir confirmar vacío). Al aprobar, en cambio, el dictamen es opcional.
- Tras confirmar: la fila desaparece de la grilla y **la card del home desaparece** (contador pasa a 0).
- Verificación en base:
  ```sql
  SELECT estado, id_autorizante, fecha_autorizacion, dictamen
    FROM autorizaciones_traslado_duplicado WHERE id_autorizacion_traslado_duplicado = 1;
  -- estado = 3, id_autorizante = 1000008, fecha_autorizacion poblada, dictamen con el texto

  SELECT id_estado_traslado, id_motivo_anulacion, id_estado_logistica_ida
    FROM traslados WHERE id_traslado = 1469808;
  -- 4 (Cancelado), 16, NULL
  ```
  Si en cambio se **aprueba**: `estado = 2`, y el traslado 1469808 pasa a `id_estado_logistica_ida = 1` y `es_duplicado_autorizado = 1`.

  > Este paso consume el único pendiente. Para repetirlo, ver la sección 5.4 (cómo volver a poner un pedido en PENDIENTE).

**Paso 4 — El bloque de conflicto en el drawer de carga de turno.**
- Usuario: **1000007** (operador, sin el permiso).
- Pantalla: denuncia `B464435` → Turnos → cargar turno nuevo con traslado, **fecha 2026-08-15**.
- Se espera ver el **bloque de conflicto** (`BloqueConflictoTraslado`), porque el paciente ya tiene traslados vigentes ese día (1469807 y 1469809, ambos en estado 1 «Solicitado», que no está en el conjunto no vigente {4, 5}).
- Se espera que la salida **«declarar el motivo»** esté **oculta o deshabilitada**, porque el operador no tiene `autorizar_traslado_mismo_dia`. Las salidas visibles deben ser **«pedir autorización»** y **«anular el traslado que ya existía»**.
- Verificación en base de qué cuenta como vigente:
  ```sql
  SELECT COUNT(1) FROM traslados tr JOIN turnos t ON t.id_turno = tr.id_turno
   WHERE t.id_denuncia = 464435 AND DATE(t.fecha_turno) = '2026-08-15'
     AND tr.id_estado_traslado NOT IN (4, 5);   -- espera 3 (1469807, 1469808, 1469809)
  ```

**Paso 5 — La validación server-side de 409 (verificada, funciona en DEV).**
- Este paso no pasa por pantalla: es un `POST` directo, y sirve para demostrar que el gate no vive sólo en el front.
- Ya se ejecutó contra DEV y devolvió lo esperado, **sin crear nada**:
  ```
  POST /grv/turnos/turnos/crear   (multipart, part "dto" con Content-Type application/json)
  {"idTipoTurno":3,
   "createTurnoDTO":{"idDenuncia":464435,"fechaTurno":"2026-08-15T16:00:00"},
   "generarTrasladoDTO":{"requiereTraslado":true}}
  ```
  Respuesta obtenida:
  ```json
  {"status":409,
   "message":"El paciente ya tiene un traslado ese día. Para cargar un segundo traslado hay que indicar el motivo, o pedir la autorización de un referente.",
   "body":"CONFLICT"}
  ```
- Contraprueba (**crea un turno, dejar para el final y anotar los ids para borrarlos**): el mismo request agregando `"idMotivoTrasladoMismoDia": 2` debe pasar el gate y devolver **201**. El catálogo `motivos_traslado_mismo_dia` tiene sólo dos opciones: `1 = Autorizado por Auditoria Medica`, `2 = Autorizado por Supervisión`.
- Y la regla de que **un pedido rechazado no habilita el duplicado**: repetir el request sin motivo pero con `idAutorizacion = 2068785` (el del pedido RECHAZADO) — tiene que seguir dando **409**. Con `idAutorizacion = 2068783` (PENDIENTE) o `2068784` (APROBADO) debe pasar.

**Paso 6 — Anular el traslado preexistente desde el bloque de conflicto.**
- Usuario: **1000007**. Tercera salida del bloque de conflicto.
- Se espera: el traslado que ya existía queda cancelado y el nuevo turno se puede cargar.
- Verificación: el traslado elegido pasa a `id_estado_traslado = 4` con su motivo de anulación.
- **Ojo:** la rama de front `feature/anular-desde-bloque-conflicto` **no está mergeada a develop**, así que este paso puede no estar disponible en el DEV actual. Confirmar antes de reportarlo como bug.

**Paso 7 — Casos de borde del autorizante (ya verificados por API; se pueden repetir).**

| Caso | Request | Resultado obtenido |
|---|---|---|
| Sin permiso | `{"idAutorizacionTrasladoDuplicado":1,"aprobar":true,"idAutorizante":1000007}` | `SIN_PERMISO` — «No tenés permiso para autorizar dos traslados el mismo día.» No modifica nada. |
| Ya resuelto (doble clic / dos referentes) | `{"idAutorizacionTrasladoDuplicado":2,"aprobar":false,"idAutorizante":1000008,"dictamen":"reintento"}` | `YA_RESUELTO`, informando `idAutorizante: 1000008` y `fechaAutorizacion: 2026-08-14T09:29:28`. **No pisa** al primero. |
| Inexistente | `idAutorizacionTrasladoDuplicado` de un id que no existe | `NO_ENCONTRADO` |

Los tres devuelven **HTTP 200** con el resultado tipado en el body, no un error. Es deliberado (el DTO documenta que el equivalente de Cirugías devuelve `null` y el llamador se come un NPE).

**Paso 8 — Visibilidad para logística.**
- Usuario: **logística** (por ejemplo `Ayi Logistica QA`, persona 1000015, perfil 18 `gestor_logistica`).
- Pantalla: grilla de traslados de logística.
- Se espera ver **los traslados 1469807 y 1469809**, y **NO** ver 1469808 (pendiente de autorización) ni 1469810 (rechazado y cancelado).
- El criterio no es el estado del traslado: el SP `consulta_traslado_remis_amb_logistica` exige `AND tu.fecha_turno IS NOT NULL AND t.id_estado_logistica_ida IS NOT NULL`. Verificado en el fuente de `wslogistica`.
- El traslado aprobado (1469809) además tiene que mostrar la marca de **duplicado autorizado**, para que logística no lo cancele por repetido.
- Verificación en base:
  ```sql
  SELECT id_traslado, id_estado_logistica_ida, es_duplicado_autorizado,
         (id_estado_logistica_ida IS NOT NULL) AS visible_logistica
    FROM traslados WHERE id_traslado IN (1469807, 1469808, 1469809, 1469810);
  ```
  Resultado actual (verificado): 1469807 → 1 / NULL / visible; **1469808 → NULL / NULL / NO visible**; 1469809 → 1 / **1** / visible; **1469810 → NULL / NULL / NO visible**.

### 3.B — Lo que NO se puede probar hoy

| Tramo | Por qué |
|---|---|
| **«Pedir autorización» desde el bloque de conflicto (paso del operador)** | `POST /autorizaciones/pedir-traslado-duplicado` devuelve **404** en DEV. Ver 6.1. |
| **Que quien tiene el permiso obtenga el pedido ya aprobado al pedirlo** | Misma causa: esa lógica vive en el service de la rama sin mergear. |
| **Anular el traslado existente desde el bloque de conflicto (paso 6)** | Rama de front sin mergear. Ver 6.2. |

Los pedidos (b), (c) y (d) están cargados justamente para que **el tramo del autorizante se pueda probar completo hoy**, sin depender del paso del operador.

---

## 4. Escenarios agregados por decisión propia

Además de los cuatro pedidos, se agregaron dos cosas y se ejercitaron dos casos de borde:

1. **`id_estado_logistica_ida = 1` en el traslado base 1469807.** Estaba en `NULL`, con lo cual el traslado «que ya existía» tampoco era visible para logística y el paso 8 no distinguía nada. Poniéndolo en 1 se representa un traslado ya coordinado, y el contraste con el pendiente (que sigue en `NULL`) se vuelve observable.
2. **Los tres pedidos apuntan a turnos distintos, todos el mismo día 2026-08-15.** Así el conflicto es real para cualquiera de ellos y la grilla no depende de un único registro.
3. **`SIN_PERMISO` y `YA_RESUELTO` ejercitados por API** (paso 7). Son los dos casos que el código documenta como aprendizaje del circuito de Cirugías; conviene que queden verificados y no sólo revisados en el diff.

Los pedidos (c) y (d) **no se insertaron ya resueltos**: se cargaron como PENDIENTE y se resolvieron llamando al endpoint real `POST /autorizaciones/resolver-traslado-duplicado` de DEV. Es lo que permite afirmar que la aprobación, el rechazo, la cancelación con motivo 16 vía `wslogistica` y el guard de idempotencia **funcionan de verdad**, y no sólo que las filas quedaron con el valor correcto.

---

## 5. Todo lo escrito en la base, con su rollback

### 5.1 Escrituras por SQL directo (pymysql, una sola transacción)

| # | Tabla | Operación | Filas / ids |
|---|---|---|---|
| 1 | `autorizaciones` | INSERT (clon de `id_autorizacion` = 2068782) | **2068783, 2068784, 2068785** |
| 2 | `turnos` | INSERT (clon de `id_turno` = 4560454) + UPDATE de `id_autorizacion`, `fecha_turno`, `fecha_hora_turno`, `hora_turno`, `observaciones` | **4560455, 4560456, 4560457** |
| 3 | `traslados` | INSERT (clon de `id_traslado` = 1469807) + UPDATE de `id_turno`, `fecha_traslado`, `hora_traslado`, `id_estado_traslado`=1, `id_estado_logistica_ida`=NULL, `es_duplicado_autorizado`=NULL, `observaciones` | **1469808, 1469809, 1469810** |
| 4 | `autorizaciones_traslado_duplicado` | INSERT, `estado`=1, `id_solicitante`=1000007 | **1, 2, 3** |
| 5 | `traslados` | UPDATE `id_estado_logistica_ida` = 1 (venía `NULL`) | **1469807** (1 fila) |

Los tres turnos y los tres traslados creados llevan `observaciones = 'GRV-2239 POOL DEV <PENDIENTE|APROBADA|RECHAZADA>'`, lo que los hace identificables sin depender de los ids.

Nota técnica: `autorizaciones.id_autorizacion` es PK **sin `auto_increment`**, así que los ids se asignaron con `MAX(id)+1`. `turnos.id_turno` y `traslados.id_traslado` sí son `auto_increment`. `traslados` tiene un trigger `BEFORE INSERT generate_token_traslados` que generó el token de cada clon; es inocuo.

### 5.2 Escrituras hechas por el código real, vía API de DEV

`POST https://dev.sas.colonia-suiza.com.ar/grv/turnos/autorizaciones/resolver-traslado-duplicado`

| Llamada | Body | Resultado | Efectos en base |
|---|---|---|---|
| Aprobar pedido 2 | `{"idAutorizacionTrasladoDuplicado":2,"aprobar":true,"idAutorizante":1000008,"dictamen":"Aprobado: interconsulta justificada, paciente con inmovilizacion."}` | `APROBADA` | pedido 2 → `estado`=2, `id_autorizante`=1000008, `fecha_autorizacion`, `dictamen`; traslado **1469809** → `id_estado_logistica_ida`=1, `es_duplicado_autorizado`=1 |
| Rechazar pedido 3 | `{"idAutorizacionTrasladoDuplicado":3,"aprobar":false,"idAutorizante":1000008,"dictamen":"Rechazado: los estudios se pueden agendar otro dia, no corresponde segundo traslado."}` | `RECHAZADA` | pedido 3 → `estado`=3, `id_autorizante`, `fecha_autorizacion`, `dictamen`; traslado **1469810** → `id_estado_traslado`=4, `id_motivo_anulacion`=16, `observaciones_anulacion` = «No se autorizó el segundo traslado del mismo día. » + dictamen |
| Sin permiso sobre pedido 1 | `idAutorizante: 1000007` | `SIN_PERMISO` | **ninguno** |
| Reintento sobre pedido 2 | `aprobar: false` | `YA_RESUELTO` | **ninguno** |

> El rechazo pasa por `wslogistica` (`fetchLogisticaOnCancelacion`, motivo 16 «Cancelado por alarma repetida»). La llamada se completó, así que **`wslogistica` pudo haber escrito bitácora propia sobre el traslado 1469810**. El rollback de abajo borra la fila de `traslados`, pero si hubiera registros en tablas satélite de logística referenciando ese `id_traslado`, el `DELETE` va a fallar por FK: en ese caso borrar primero esos registros (todos son del traslado 1469810, creado hoy, así que no hay riesgo de arrastrar datos ajenos).

### 5.3 SQL de rollback completo

Ejecutar **en este orden** (hijos antes que padres). Todo acotado por id, sin `WHERE` amplio.

```sql
-- ===== ROLLBACK GRV-2239 pool DEV B464435 =====
-- Ejecutar SOLO en DEV. Verificar antes con los SELECT de control.
START TRANSACTION;

-- 1. Pedidos de excepción (la tabla estaba en 0 filas antes de esta preparación)
DELETE FROM autorizaciones_traslado_duplicado
 WHERE id_autorizacion_traslado_duplicado IN (1, 2, 3);
-- Si no hubo otros pedidos cargados por terceros, equivale a:
-- DELETE FROM autorizaciones_traslado_duplicado WHERE id_autorizacion IN (2068783, 2068784, 2068785);

-- 2. Traslados clonados
DELETE FROM traslados WHERE id_traslado IN (1469808, 1469809, 1469810);

-- 3. Turnos clonados
DELETE FROM turnos WHERE id_turno IN (4560455, 4560456, 4560457);

-- 4. Autorizaciones clonadas
DELETE FROM autorizaciones WHERE id_autorizacion IN (2068783, 2068784, 2068785);

-- 5. Devolver el traslado base a su estado original (venía en NULL)
UPDATE traslados SET id_estado_logistica_ida = NULL WHERE id_traslado = 1469807;

COMMIT;
-- ROLLBACK;  -- usar si algún SELECT de control no da lo esperado

-- ===== Pasos manuales, sólo si se ejecutaron (ver sección 2.3) =====
-- UPDATE denuncias SET id_auditor = 1892 WHERE id_denuncia = 464435 AND id_auditor = 1000007;
-- UPDATE personas_perfiles_sas SET activo = 1, fecha_baja = NULL, usuario_baja = NULL
--  WHERE id_persona = 1000007 AND id_perfil = 11;

-- ===== Controles post-rollback =====
SELECT COUNT(1) AS pedidos          FROM autorizaciones_traslado_duplicado;             -- espera 0
SELECT COUNT(1) AS turnos_denuncia  FROM turnos WHERE id_denuncia = 464435;             -- espera 5
SELECT id_traslado, id_estado_logistica_ida FROM traslados WHERE id_traslado = 1469807; -- espera NULL
SELECT COUNT(1) AS residuos FROM turnos WHERE observaciones LIKE 'GRV-2239 POOL DEV%';  -- espera 0
SELECT COUNT(1) AS residuos FROM traslados WHERE observaciones LIKE 'GRV-2239 POOL DEV%'; -- espera 0
```

> Los `SELECT` de residuos también capturan cualquier turno o traslado que la prueba manual haya creado con esa marca. Los turnos creados por la prueba manual del **paso 5 contraprueba** **no** llevan la marca: anotar sus ids durante la prueba y borrarlos aparte.

### 5.4 Cómo reponer el escenario PENDIENTE sin rearmar el pool

Después de que el supervisor resuelva el pedido 1 en el paso 3, para volver a tener un pendiente:

```sql
UPDATE autorizaciones_traslado_duplicado
   SET estado = 1, id_autorizante = NULL, fecha_autorizacion = NULL, dictamen = NULL
 WHERE id_autorizacion_traslado_duplicado = 1;

-- y devolver el traslado a "sin coordinar" (si se había aprobado)
UPDATE traslados
   SET id_estado_traslado = 1, id_estado_logistica_ida = NULL,
       es_duplicado_autorizado = NULL, id_motivo_anulacion = NULL, observaciones_anulacion = NULL
 WHERE id_traslado = 1469808;
```

---

## 6. Bloqueos encontrados

### 6.1 CRÍTICO — `pedir-traslado-duplicado` no está desplegado en DEV: el front lo llama y recibe 404

**El circuito no se puede probar de punta a punta hoy.** La premisa de que «todo el código está mergeado a develop y desplegado en DEV» **no se cumple para el endpoint que registra el pedido**.

Evidencia contra DEV:

```
POST https://dev.sas.colonia-suiza.com.ar/grv/turnos/autorizaciones/pedir-traslado-duplicado
→ HTTP 404
{"status":404,"error":"Not Found","path":"/wsturnos/autorizaciones/pedir-traslado-duplicado"}
```

Evidencia en el repo (`wsturnos`):

- `origin/develop` **no** contiene ese `@PostMapping`. El controller desplegado expone únicamente `resolver-traslado-duplicado` y `traslados-duplicados-pendientes`.
- El endpoint vive en el commit `94a9aef` («feat(autorizaciones): pedir la excepción de traslado duplicado»), y ese commit está **sólo** en la rama `feature/autorizacion-duplicado-backend`, **no mergeada a develop**. Junto con él quedan afuera `PedirAutorizacionDuplicadoDTO` y el método `pedir(...)` del service.

Del otro lado, el **front de `develop` ya invoca ese endpoint**: `turnosApi.js` define `pedirTrasladoDuplicado` apuntando a `autorizaciones/pedir-traslado-duplicado`. Es un **desajuste de contratos entre front y backend en develop**: el front está mergeado y desplegado, el backend que lo sostiene no.

**Consecuencia concreta:** cuando el operador use la salida «pedir autorización» del bloque de conflicto, va a recibir un 404. Si el front no maneja ese error, el usuario ve un fallo genérico y el pedido no se registra.

**Qué hace falta:** mergear `feature/autorizacion-duplicado-backend` a `develop` de `wsturnos` y redesplegar DEV. Hasta entonces, los pedidos sólo se pueden crear por `INSERT` (que es exactamente lo que se hizo para armar este pool).

### 6.2 IMPORTANTE — «anular el traslado existente» puede no estar en DEV

La rama de front `feature/anular-desde-bloque-conflicto` **no está mergeada a `develop`**. La tercera salida del bloque de conflicto (paso 6) puede no estar disponible. Confirmar en la pantalla antes de reportarlo como defecto.

### 6.3 IMPORTANTE — El operador no ve la denuncia sin reasignar el gestor

Detallado en 2.3. `B464435` tiene `id_auditor = 1892` y el operador 1000007 no tiene permisos de grillas superiores, así que el listado le filtra por `d.id_auditor = 1000007` y la denuncia no aparece. **Sin el UPDATE de la sección 2.3, la mitad de la prueba correspondiente al operador no arranca.** Ese UPDATE quedó bloqueado por el clasificador de permisos del entorno y **hay que ejecutarlo a mano**.

### 6.4 MENOR — No se pudo confirmar por base el usuario de login del operador

`personas` no tiene columna de usuario; el mapeo persona ↔ usuario del front vive en LDAP/Keycloak, fuera de alcance de la base. Se eligió **1000007 «AyiOperador Tramitador QA»** por ser el par natural de 1000008 «Tramitador Supervisor QA» en la serie de usuarios QA, pero **QA tiene que confirmar con qué usuario se ingresa**. Si es otra persona, cambiar el `id_solicitante` de los tres pedidos y el `id_auditor` del paso 0.

### 6.5 MENOR — El perfil del operador puede desviarle el home

Detallado en 2.3: el perfil 11 `analista_requerimientos` no tiene ningún permiso de turnos ni de grillas de tramitador, y sí tiene `consultar_home_perfil_requerimientos`. Si eso lo lleva al home de requerimientos en lugar del de gestor, aplicar la baja lógica del vínculo (SQL y rollback en 2.3).

### 6.6 NOTA — La migración del SP se aplicó en DEV por fuera del merge

El SP `consulta_turnos_tramitadores_sp` en DEV **ya tiene** el filtro `trasladosDuplicadosPendientes` y las cuatro columnas del pedido. Cuando se relevó el estado, la rama `feature/filtro-duplicados-pendientes` todavía no estaba mergeada, es decir la migración se había aplicado a mano antes que su Java. Durante el trabajo, `develop` avanzó y ya incorpora el DTO y el mapping, y se verificó por API que **el listado funciona correctamente en los dos modos** (con y sin el filtro), así que hoy no hay desajuste. Se deja anotado porque el patrón —migración aplicada a mano por delante del código— es el que puede romper el listado principal de tramitadores si el mapeo de resultados no tolera columnas extra.

### 6.7 NOTA — Los endpoints del circuito no piden autenticación en DEV

`traslados-duplicados-pendientes`, `resolver-traslado-duplicado` y `turnos/crear` respondieron a `curl` **sin ningún token**. Fue lo que permitió armar el pool ejercitando el código real, pero **el permiso se valida contra el `idAutorizante` que viene en el body**: cualquiera que alcance el servicio puede resolver un pedido pasando el id de una persona que sí tenga el permiso. En DEV es aceptable; conviene confirmar que en stage y prod el servicio esté detrás del gateway con autenticación, porque la defensa de permiso del backend no reemplaza a la de identidad.

---

## 7. Anexo — Constantes verificadas

| Concepto | Valor en DEV |
|---|---|
| Permiso | `autorizar_traslado_mismo_dia`, `id_permiso` = **1000**, activo (no 101) |
| Perfiles con el permiso | 2 `jefe_de_siniestros`, 3 `referente_siniestros`, 9 `gerente_de_siniestros`, 10 `supervisor` |
| Estados del pedido | 1 PENDIENTE, 2 APROBADA, 3 RECHAZADA |
| Estados de traslado no vigentes | 4 Cancelado, 5 Rechazado |
| Estados de logística | 1 SOLICITADO, 2 ASIGNADO, 3 PROGRAMADO, 4 REALIZADO, 5 FALLIDO, 6 CANCELADO, 7 NO COORDINABLE, 8 NEGATIVO AUTORIZADO |
| Motivo de anulación al rechazar | 16 |
| Motivos del mismo día | 1 «Autorizado por Auditoria Medica», 2 «Autorizado por Supervisión» (sólo 2 opciones) |
| Tipo de viaje ida y vuelta | 2 (los traslados del pool son tipo 1, sólo ida) |
| Estado de turno de los turnos del pool | 13 «Pend. Aprobación [PCT]» |
| Visibilidad para logística | `id_estado_logistica_ida IS NOT NULL` **y** `tu.fecha_turno IS NOT NULL` |
| Tab de la grilla | `TAB_TURNOS.DUPLICADOS_PENDIENTES` = 5 |
| Motor | MariaDB 10.5.29, esquema `cs` |

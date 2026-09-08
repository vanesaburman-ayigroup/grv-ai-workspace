# Verificación funcional del fix — «Pedir autorización» en el alta de turno

**Ambiente:** TEST — https://test.sas.colonia-suiza.com.ar
**Usuario:** `ayioperadort` — persona **1000007**, tramitador SIN `autorizar_traslado_mismo_dia` (perfil que *pide*)
**Denuncia:** 999033 · **Fecha del conflicto:** 08/09/2026
**Defectos verificados:** MAN-G-01 (400 + salidas borradas) y MAN-G-02 (409 silencioso)
**Fecha de ejecución:** 21/08/2026 16:37–16:45

---

## Veredicto global

# ✅ EL ARREGLO FUNCIONA DE PUNTA A PUNTA

El circuito completo —alta de turno con conflicto de traslado, salida «Pedir autorización», justificación en el cuerpo del alta y registro del pedido en la misma transacción— **funciona correctamente**. Los cuatro puntos de verificación **CUMPLEN**. No se reprodujo ninguno de los dos síntomas: no hubo 400, no hubo 409, y el wizard **no falló en silencio**: mostró el mensaje de éxito y cerró.

| # | Verificación | Veredicto |
|---|---|---|
| 1 | Se creó el turno | ✅ **CUMPLE** |
| 2 | Se registró el pedido (estado pendiente, solicitante 1000007) | ✅ **CUMPLE** |
| 3 | **El pedido apunta al traslado NUEVO** | ✅ **CUMPLE** |
| 4 | El traslado nuevo quedó invisible para logística | ✅ **CUMPLE** |
| + | El contador de pendientes subió en uno | ✅ **CUMPLE** |

**Artefactos creados en TEST (quedan a propósito, como evidencia):**

- **Turno `4561104`** · autorización `2069069` · 08/09/2026 18:30
- **Traslado `2470636`**
- **Pedido de autorización `10`** — en estado **pendiente**, sin aprobar ni rechazar

Query para reencontrarlos:

```sql
SELECT t.id_turno, t.id_autorizacion, t.fecha_turno,
       tr.id_traslado, tr.id_estado_logistica_ida,
       a.id_autorizacion_traslado_duplicado, a.estado, a.id_solicitante, a.justificacion
  FROM turnos t
  JOIN traslados tr ON tr.id_turno = t.id_turno
  JOIN autorizaciones_traslado_duplicado a ON a.id_traslado = tr.id_traslado
 WHERE t.id_denuncia = 999033
   AND a.justificacion LIKE 'INI-2 VERIF%';
```

---

## Preparación: hard-reload y confirmación de que el fix está activo

La caché del harness (que replica la caché agresiva del navegador) se **borró por completo** antes de empezar, forzando la descarga del bundle nuevo. Comprobación de que efectivamente cambió:

| Bundle | Antes (09:50) | Después (16:41) |
|---|---|---|
| `grv-tramitadores.js` | 16.482.633 bytes | **16.483.234 bytes** (+601) |

**El fix está presente en la pantalla.** En la salida «Pedir autorización» del alta:

- Botones «Enviar el pedido» en el DOM: **0**
- Texto presente: *«El pedido se envía al guardar el turno. Hasta que alguien lo resuelva, el traslado no baja a logística.»*

📸 `capturas-fix-alta/03-pedir-autorizacion-sin-boton-enviar.png` — **evidencia de que el arreglo está activo**

> Nota: la cadena «Enviar el pedido» sigue existiendo *dentro* del bundle, pero **no se renderiza** en el alta. Es lo esperado: ese botón se sigue usando en el circuito de edición de un turno ya existente, donde sí hay id de autorización.

El bloque de conflicto apareció e informó correctamente los **3 traslados vigentes** (turnos 4561096, 4561097, 4561098) — comportamiento correcto, no un defecto.

📸 `capturas-fix-alta/02-bloque-conflicto-3-traslados.png`

---

## Qué pasó al confirmar (el corazón de la prueba)

**El turno se guardó, apareció el mensaje de éxito y el wizard se cerró.**

- Toast mostrado: **«Se ha generado el turno con éxito!»**
- El wizard se cerró y volvió a la grilla de Turnos
- La grilla muestra el turno **4561104** con su ícono de traslado

Request de alta (un solo POST, multipart):

```
POST /grv/turnos/turnos/crear  →  HTTP 200 / body 201 Created
```

Cuerpo enviado (extracto relevante):

```json
{
  "idTipoTurno": 3,
  "createTurnoDTO": {
    "fechaTurno": "2026-09-08T00:00:00", "horaTurno": "18:30",
    "idDenuncia": 999033, "idPersonaLogueada": "1000007"
  },
  "generarTrasladoDTO": {
    "requiereTraslado": true,
    "idTipoViaje": "1",
    "justificacionTrasladoDuplicado": "INI-2 VERIF fix del pedido en el alta",
    "idSolicitanteTrasladoDuplicado": "1000007"
  }
}
```

Respuesta:

```json
{"status":201,"message":"Created","body":{"idTurno":4561104}}
```

**Esto es exactamente el diseño del arreglo:** la justificación y el solicitante viajan **en el cuerpo del alta** (`justificacionTrasladoDuplicado`, `idSolicitanteTrasladoDuplicado`), no en una llamada previa aparte. No hubo ningún request al endpoint que exigía el id de autorización inexistente, y por lo tanto **no hubo 400**. El alta devolvió **201**, no 409.

📸 `capturas-fix-alta/06-paso3-resumen.png` · `07-post-confirmar.png` · `08-post-confirmar-full.png`

### ¿Volvió a fallar el wizard en silencio?

**No.** Explícitamente: el wizard **no** falló en silencio. Mostró el mensaje de éxito, cerró, y los datos quedaron persistidos en base — turno, traslado y pedido, los tres. El síntoma de MAN-G-02 (gestor cree que guardó y no queda nada) **no se reprodujo**.

---

## Verificación en base de datos (conector de sólo lectura a TEST)

### 1. Se creó el turno — ✅ CUMPLE

```sql
SELECT t.id_turno, t.id_autorizacion, t.fecha_turno, t.observaciones,
       tr.id_traslado, tr.id_estado_logistica_ida AS log_ida
  FROM turnos t
  LEFT JOIN traslados tr ON tr.id_turno = t.id_turno
 WHERE t.id_denuncia = 999033
   AND t.fecha_turno = '2026-09-08'
   AND (t.observaciones IS NULL OR t.observaciones NOT LIKE 'INI-2 POOL 999033%')
 ORDER BY t.id_turno
```

```
id_turno | id_autorizacion | fecha_turno         | observaciones | id_traslado | log_ida
---------+-----------------+---------------------+---------------+-------------+--------
4561102  | 2069067         | 2026-09-08 00:00:00 | NULL          | NULL        | NULL
4561103  | 2069068         | 2026-09-08 00:00:00 | NULL          | NULL        | NULL
4561104  | 2069069         | 2026-09-08 00:00:00 | NULL          | 2470636     | NULL
```

El turno **4561104** es el creado por esta prueba, con fecha 08/09/2026 y **con su traslado 2470636**. No es uno de los cuatro del pool (`INI-2 POOL 999033`).

> Los turnos 4561102 y 4561103 son **residuos de la sesión anterior** (previa al fix): existen sin traslado asociado, que es justamente la huella del defecto MAN-G-02. Baseline previo al inicio de esta prueba: `max(id_turno) = 4561103`, por lo que 4561104 es inequívocamente el turno nuevo.

### 2. Se registró el pedido, con la justificación — ✅ CUMPLE

```sql
SELECT id_autorizacion_traslado_duplicado AS id, id_autorizacion, estado,
       id_traslado, id_solicitante, fecha_solicitud, justificacion
  FROM autorizaciones_traslado_duplicado
 WHERE justificacion LIKE 'INI-2 VERIF%'
```

```
id | id_autorizacion | estado | id_traslado | id_solicitante | fecha_solicitud     | justificacion
---+-----------------+--------+-------------+----------------+---------------------+---------------------------------------
10 | 2069069         | 1      | 2470636     | 1000007        | 2026-08-21 16:44:11 | INI-2 VERIF fix del pedido en el alta
```

- Existe: **sí** (id 10)
- `estado = 1` → **pendiente** ✅
- `id_solicitante = 1000007` ✅
- Justificación exacta ✅

Además, `id_autorizacion = 2069069` **coincide con la autorización del turno 4561104**, lo que confirma que el pedido se registró vinculado al alta y dentro de la misma transacción.

### 3. CLAVE — el pedido apunta al traslado NUEVO — ✅ CUMPLE

El `id_traslado` del pedido es **2470636**, que es el traslado del turno recién creado (4561104).

**No** es ninguno de los del pool:

```
Traslados del pool: 2470632, 2470633, 2470634, 2470635
Traslado del pedido: 2470636   ← el nuevo
```

El defecto más profundo del circuito —el pedido quedaba asociado al traslado en conflicto, de modo que al aprobar se liberaba el traslado *viejo*— **está corregido**. El pedido apunta al traslado que el gestor acaba de cargar.

### 4. El traslado nuevo quedó invisible para logística — ✅ CUMPLE

```sql
SELECT id_traslado, id_turno, id_estado_logistica_ida, id_estado_logistica_vuelta
  FROM traslados WHERE id_traslado = 2470636
```

```
id_traslado | id_turno | id_estado_logistica_ida | id_estado_logistica_vuelta
------------+----------+-------------------------+---------------------------
2470636     | 4561104  | NULL                    | NULL
```

`id_estado_logistica_ida` en **NULL** mientras el pedido está pendiente. La llave del diseño se respeta: el traslado no baja a logística hasta que alguien resuelva el pedido.

### Contador de pendientes — ✅ CUMPLE (subió en uno)

```
GET /grv/turnos/autorizaciones/traslados-duplicados-pendientes

Antes:   {"status":200,"message":"OK","body":0}
Después: {"status":200,"message":"OK","body":1}
```

Delta **+1**, como se esperaba.

> **Desvío respecto del brief:** el brief indicaba que el contador estaba en **1** antes de la prueba; se midió en **0**. La causa está identificada y no afecta la verificación: el pedido pendiente del pool (id 7, `INI-2 POOL 999033 C-PENDIENTE`) **fue aprobado a las 13:20:09 del 21/08/2026** por la sesión exploratoria anterior (`fecha_autorizacion = 2026-08-21 13:20:09`, `estado = 2`), lo que consumió el único pendiente. El delta +1 es lo que importa y se cumple. Si se necesita el pool con un pendiente para futuras pruebas, **hay que reponerlo**.

---

## Cumplimiento de las reglas de la prueba

- ✅ **No se aprobó ni rechazó nada.** El pedido 10 quedó en `estado = 1` (pendiente), como evidencia.
- ✅ **No se tocaron los cuatro turnos del pool** (`INI-2 POOL 999033`) ni sus pedidos. Verificado post-ejecución: los pedidos 1, 2, 3, 7, 8, 9 y los traslados 2470632–2470635 quedaron **idénticos al baseline**.
- ✅ El turno creado queda en TEST, con su id y su query documentados arriba.

---

## Capturas

| Archivo | Qué muestra |
|---|---|
| `02-bloque-conflicto-3-traslados.png` | Bloque de conflicto informando los 3 traslados vigentes |
| `03-pedir-autorizacion-sin-boton-enviar.png` | **Evidencia del fix**: sin botón «Enviar el pedido», con la aclaración |
| `04-justificacion.png` | Justificación `INI-2 VERIF…` cargada |
| `05-paso2-completo.png` | Paso 2 completo, «Siguiente» habilitado |
| `06-paso3-resumen.png` | Paso 3 — resumen previo a confirmar |
| `07-post-confirmar.png` | Wizard cerrado, turno 4561104 en la grilla |
| `08-post-confirmar-full.png` | Igual, página completa |

---

## Observaciones para el equipo

1. **Ningún defecto funcional detectado** en el circuito verificado.
2. **Reponer el pool**: el escenario «pedido pendiente» del pool de 999033 fue consumido (aprobado) el 21/08 a las 13:20. Conviene regenerarlo antes de la próxima corrida.
3. **Residuos de datos**: los turnos 4561102 y 4561103 quedaron sin traslado asociado, huella del defecto MAN-G-02 previo al fix. Evaluar si conviene limpiarlos de TEST para no confundir corridas futuras.
4. **Caché del bundle**: se confirma que sin hard-reload se sirve la versión vieja. Se recomienda incorporar `ETag` o versionado en el nombre del bundle del front para evitar falsos negativos en QA.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026*

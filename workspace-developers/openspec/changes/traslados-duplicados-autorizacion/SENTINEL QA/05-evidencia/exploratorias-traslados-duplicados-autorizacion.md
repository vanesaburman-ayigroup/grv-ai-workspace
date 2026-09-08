# Pruebas exploratorias — Autorización de traslados duplicados del mismo día

| | |
|---|---|
| **Change OpenSpec** | `traslados-duplicados-autorizacion` |
| **Ticket** | **INI-2** (triage inbox — no hay Jira) |
| **Ambiente** | **DEV únicamente** — `https://dev.sas.colonia-suiza.com.ar` |
| **Fecha de ejecución** | 19/08/2026 |
| **Denuncia / paciente** | B464435 · Ragnar Lothbrok · DNI 38401345 · `id_denuncia = 464435` |
| **Usuarios** | `ayioperadort` (persona 1000007, **sin** `autorizar_traslado_mismo_dia`) · `tramitador.supervisor` (persona 1000008, perfil 2 `jefe_de_siniestros`, **con** el permiso) |
| **Fechas usadas** | 25/08/2026 (con conflicto real) · 27/08/2026 (limpia) · 01/09 y 02/09/2026 (pool resuelto) |
| **Base de datos** | conector de **sólo lectura** `python db_dev.py "SELECT ..."`. **No se usó el MCP de MariaDB** (apunta a producción — VBD-01) |
| **Escritura en DEV** | **ninguna.** Ver §«Datos que dejé en DEV» |
| **Total de hallazgos** | **13 defectos** · **6 huecos de regla** · **6 ajenos al change** |

---

## 0. Qué es esta sesión y qué no

Esto **no** es la ejecución de la matriz. La matriz de 98 casos scriptados existe y cubre el circuito caso por caso. Esta sesión buscó **lo que la matriz no cubre**: los bordes que su §14 declara sin caso, los puntos que su §15 declara no probables, y lo que aparece cuando se recorre el circuito completo con el criterio de quien conoce el flujo del SAS.

La matriz se usó como **mapa de lo ya cubierto**. Cuando un hallazgo coincide con un caso de la matriz o con un hallazgo previo, se dice explícitamente y se cita el ID.

**Se probó realmente sobre la aplicación**, no sobre el código: sesión de navegador con Playwright, panel de red completo, y verificación en base después de cada paso. Cada hallazgo de esta sesión tiene captura, o salida literal de red, o query de base — la mayoría las tres.

### 0.1 Cobertura efectiva de la sesión

| Superficie | Recorrida | Cómo |
|---|---|---|
| Home del autorizante — card y contador | ✅ | `tramitador.supervisor` → home, contador contra `E-PEND` y contra `COUNT(*) WHERE estado = 1` |
| Grilla de pendientes | ✅ | pestaña «Autorización Doble Traslado Pendiente», fila completa, tooltips, acciones, DOM |
| Drawer de resolución | ✅ | abierto y recorrido **sin resolver** (el único pendiente es del pool y está prohibido consumirlo) |
| Home y grilla del solicitante | ✅ | `ayioperadort` → home + pestaña «Autorización Doble Traslado Resuelta» |
| Devolución del resultado al solicitante | ✅ | las dos filas resueltas del pool, con dictamen y tooltips |
| Bloque de conflicto en el wizard | ✅ | wizard de nuevo turno completo hasta el paso 2, fecha 25/08/2026 con conflicto real |
| Las tres salidas y sus sub-formularios | ✅ | ANULAR, SIN_TRASLADO y AUTORIZACION, incluyendo el cambio de una a otra |
| Contrato de los endpoints del circuito | ✅ | `E-PEND`, `E-RES`, `E-CONF`, `E-PEDIR`, `E-RESOLVER`, `marcar-duplicados-vistos` |
| Permiso server-side | ✅ | los endpoints de resolución invocados desde la sesión **sin** el permiso |
| Responsive 1440 / 768 / 390 | ✅ | bloque de conflicto y drawer |
| Accesibilidad y teclado | ✅ | radiogroup de salidas, drawer, foco, nombres accesibles |
| Guardado del turno y creación de un pedido propio | ❌ | ver §«Lo que no pude explorar y por qué» |
| Concurrencia real y doble envío | ❌ | idem |
| Grilla de logística (franja, ícono, leyenda) | ❌ | idem |

---

## 1. Resumen ejecutivo

| Severidad | Cantidad | IDs |
|---|---|---|
| **BLOQUEANTE** | 0 | — |
| **ALTA** | 5 | EXP-01, EXP-02, EXP-03, EXP-04, EXP-05 |
| **MEDIA** | 6 | EXP-06, EXP-07, EXP-08, EXP-09, EXP-10, EXP-13 |
| **BAJA** | 2 | EXP-11, EXP-12 |
| **Huecos de regla (B)** | 6 | EXP-B1 … EXP-B6 |
| **Ajeno al change (C)** | 6 | EXP-C1 … EXP-C6 |

### 1.1 Los tres hallazgos que cambian la decisión de promover

**1 · El circuito registra sus anulaciones y rechazos como «Cancelado por alarma repetida» (EXP-04).**
El motivo de anulación 16 —el que el PRD llama *«el motivo específico de duplicado»*— es, en el catálogo de DEV, **«Cancelado por alarma repetida»**. No hay ningún motivo de duplicado en `motivos_anulacion`. Todas las anulaciones y todos los rechazos de este circuito quedan, para logística y para cualquier medición futura, indistinguibles de una cancelación por alarma repetida. El PRD §2.2 construye la justificación del desarrollo sobre exactamente este problema: *«el motivo que usa no permite medirlos»*. El change lo reproduce.

**2 · Un pedido pendiente sobre un traslado ya cancelado se ofrece a resolver sin ninguna señal (EXP-01).**
El pedido 1 del pool está PENDIENTE y su traslado (1469808) está **Cancelado, con motivo 16 y con estado de logística 6** — o sea que logística ya lo tuvo. La grilla lo lista y el drawer lo ofrece con los botones «Autorizar» y «Rechazar» habilitados, sin decir en ningún lado que el traslado ya no existe. Es EST-09 dejando de ser un riesgo documental y pasando a ser observable en pantalla, con el dato que hay hoy en el ambiente.

**3 · El permiso `autorizar_traslado_mismo_dia` vive sólo en el front (EXP-05).**
`POST /grv/turnos/autorizaciones/resolver-traslado-duplicado` responde **exactamente lo mismo** a la sesión del usuario sin el permiso que a la del jefe de siniestros. No hay 401 ni 403: la request llega hasta la búsqueda del pedido. El PRD §3 dice *«El permiso es el único discriminador»*; hoy ese discriminador es una condición de renderizado. Es el mismo patrón que D-4 (el dictamen obligatorio que sólo vive en el formulario), pero sobre la operación que concede la autorización.

### 1.2 Lo que funciona y conviene dejar asentado

No todo lo que se buscó estaba roto. Estos puntos se verificaron y **pasan**:

- **Cambiar de salida libera la anterior** (matriz CTM-07): ANULAR → AUTORIZACION funciona, el sub-formulario se reemplaza y el radio anterior se libera. Se buscó específicamente el defecto contrario y no está.
- **«Guardar el turno sin traslado» destilda «Requiere traslado»** por sí solo, hace desaparecer los campos del traslado y habilita «Siguiente» (matriz CTM-22, casuística C-03).
- **Responsive limpio** a 1440 / 768 / 390 px: sin desborde horizontal, sin superposición de botones (envuelven en dos filas), el bloque y las tres salidas legibles en los tres anchos. Confirma las correcciones de VAP-04.
- **`justificacion` es obligatoria del lado del servidor**: `POST E-PEDIR` con justificación vacía devuelve **400** `«justificacion: must not be blank»` (matriz ATD-02).
- **Sin el permiso no hay card ni pestaña de pendientes**: `ayioperadort` no ve ninguna de las dos, y sí ve la de resueltos (matriz ATD-06).
- **La devolución del resultado al solicitante existe y muestra el dictamen completo** (RF-2.9), con tooltip del texto entero tanto del dictamen como de la justificación propia. Esto **desmiente el PRD §7.1** — ver EXP-B3.
- **El grupo de salidas tiene semántica correcta**: `role="radiogroup"` con `aria-label="Elegí cómo resolverlo antes de guardar el turno"`, los tres radios dentro de su `<label>`.
- **Un traslado cancelado no genera conflicto**: en 25/08/2026 hay tres traslados (1469816 vigente, 1469807 y 1469808 cancelados) y el bloque enumera **sólo el vigente** (matriz CTM-03).
- **El foco queda atrapado en el drawer de resolución** y Escape lo cierra devolviendo el foco a un botón.

---

## 2. Bloque (A) — Defectos del circuito

### EXP-01 — Un pedido pendiente sobre un traslado ya cancelado se ofrece a resolver, sin ninguna señal · **ALTA**

**Confirma** EST-09 (ramas b y d) y lo convierte en observable. La matriz declara estas transiciones sin regla; acá se ve qué hace el sistema de hecho.

**Precondición** — el estado del pool, verificado en base:

```sql
SELECT a.id_autorizacion_traslado_duplicado id, a.estado, a.id_traslado,
       t.id_estado_traslado, t.id_estado_logistica_ida, t.id_motivo_anulacion
FROM autorizaciones_traslado_duplicado a
JOIN traslados t ON t.id_traslado = a.id_traslado
WHERE a.estado = 1;
```

```
id | estado | id_traslado | id_estado_traslado | id_estado_logistica_ida | id_motivo_anulacion
---+--------+-------------+--------------------+-------------------------+--------------------
1  | 1      | 1469808     | 4  (Cancelado)     | 6                       | 16
```

**Pasos**
1. Ingresar como `tramitador.supervisor`.
2. Home → card **«Autorización Doble Traslado Pendiente»** (muestra **1**).
3. Entrar a la grilla de pendientes.
4. En la fila de Ragnar Lothbrok, abrir el menú de acciones → **«Gestionar autorización»**.
5. Leer el drawer completo.

**Resultado observado** — literal del drawer:

```
Autorizar el segundo traslado del día
Justificación del gestor
  El paciente tiene FKT a la manana y consulta con traumatologia a la tarde
  en otro centro; no puede volver por sus medios.
El pedido
  Lo pidió: AyiOperador Tramitador QA
  Fecha del pedido: 14/08/2026 - 09:29
El turno
  Tipo de turno: Consulta
  FECHA TURNO: 25/08/2026 - 11:15
  ACCIDENTADO: Ragnar Lothbrok
  DENUNCIA: B464435
Dictamen
  Obligatorio para rechazar: es lo que le vuelve al gestor.
[Cancelar]  [Rechazar]  [Autorizar]
```

Ni la fila de la grilla ni el drawer dicen una palabra sobre el estado del traslado. **«Autorizar» y «Rechazar» están habilitados.** El autorizante decide una excepción sobre un traslado que está cancelado, que ya tuvo estado de logística 6 —o sea que logística lo vio y lo trabajó— y cuya fecha de turno es dentro de seis días.

**Resultado esperado y por qué.** RF-2.5 dice que la fila *«da el contexto para decidir»*. Decidir sobre un duplicado exige saber si el duplicado sigue existiendo. `aprobar()` no revalida nada (EST-09): al aprobar, escribiría estado de logística y la marca de duplicado autorizado **sobre un traslado cancelado**, rompiendo RF-3.2 y RF-3.5. Lo correcto es una de dos: que el pedido se invalide solo cuando desaparece el conflicto, o que el drawer muestre el estado del traslado y bloquee la aprobación con un mensaje explicativo. Hoy no hace ninguna de las dos.

**Por qué importa más de lo que parece.** No es un caso de laboratorio: es **el estado en que está el ambiente hoy**, y la matriz tuvo que escribir una advertencia entera (§0.5, punto 1) para que nadie apruebe ese pedido por error. Si un fixture de QA cae naturalmente en este estado, un pedido de producción también.

**Evidencia** · `capturas/C-drawer-resolucion.png` · `capturas/A-grilla-pendientes.png` · query de arriba.

---

### EXP-02 — El bloque de conflicto muestra el `id_turno` en pantalla · **ALTA**

**Nuevo** como evidencia de campo sobre el bloque; **hace fallar** el caso **CTM-05** (P1) de la matriz y la regla transversal **RF-5.1**.

**Pasos**
1. Ingresar como `ayioperadort`.
2. Grilla de Turnos → filtrar `Nro. Denuncia = B464435` → abrir la denuncia → pestaña **Turnos**.
3. **Nuevo turno** → **Consulta**.
4. Paso 1: Fecha **25/08/2026**, Hora **15:00**, Cantidad 1, Centro médico *CENTRO MEDICO NOGOYA SAN JUSTO [RKT]*, Prestación *[42.01.01] CONSULTA MEDICA (SIMPLE)*, Observaciones con el prefijo `INI-2 EXPLORATORIA`. → **Siguiente**.
5. Paso 2 «Traslado»: tildar **«Requiere traslado»**.

**Resultado observado** — literal del bloque:

```
El paciente ya tiene un traslado ese día
Turno 4560464 · Consulta · 00:10:00 · CENTRO MEDICO NOGOYA SAN JUSTO [RKT]
Elegí cómo resolverlo antes de guardar el turno
```

`4560464` es el `id_turno` de la tabla `turnos`, verbatim:

```sql
SELECT tu.id_turno, t.id_traslado, tu.fecha_turno, tu.hora_turno
FROM turnos tu JOIN traslados t ON t.id_turno = tu.id_turno
WHERE tu.id_denuncia = 464435 AND DATE(tu.fecha_turno) = '2026-08-25'
  AND t.id_estado_traslado NOT IN (4,5);
-- 4560464 | 1469816 | 2026-08-25 | 00:10
```

Y el `id_traslado` que el backend manda en el mismo payload (`"idTraslado":1469816`) no se muestra — o sea que la regla se aplicó a un identificador y no al otro.

**No es el único lugar.** El mismo `id_turno` aparece, en la misma sesión y dentro del circuito:

| Superficie | Qué muestra |
|---|---|
| Bloque de conflicto | `Turno 4560464` |
| Modal «Información de Traslado», que es una de las dos acciones de fila del circuito | `#Turno: 4560457` |
| Grilla de turnos de la denuncia, la pantalla previa al wizard | columna `#TURNO` con `4560360`, `4560457`, `4560456`, `4560455`, `4560454`, `4560464` |
| Filtros de la grilla donde viven las dos pestañas del circuito | campo **«ID Turno»** |

**Resultado esperado y por qué.** RF-5.1: *«Nunca se muestra un id al usuario. Ni de turno, ni de traslado, ni de autorización, ni de persona.»* CTM-05 lo instrumenta como caso P1 y pide explícitamente comparar los números de 6-7 dígitos de la pantalla con `id_turno` de Q1/Q2. La comparación da positiva. El bloque ya tiene todo lo que necesita para identificar el turno sin el id —tipo, hora, centro médico— y de hecho los muestra al lado.

> **Ver también EXP-B1:** RF-1.2 autoriza mostrar *«número de turno»* y RF-5.1 lo prohíbe. La contradicción es real y hay que resolverla antes de cerrar este hallazgo, porque decide si el arreglo es en el código o en el requisito.

**Evidencia** · `capturas/K-bloque-conflicto-oper-25082026-1500.png` · `capturas/F-ver-info-traslado.png` · `capturas/H-turnos-denuncia.png`.

---

### EXP-03 — El bloque no muestra el estado operativo del traslado en conflicto, aunque el backend lo manda · **ALTA**

**Nuevo.** Hace fallar **CTM-04** por una razón distinta de la prevista: la matriz declaró NP-3 sólo para la rama «agencia informada = true»; el problema es que **ninguna** de las dos ramas se renderiza.

**Pasos** — los mismos de EXP-02, con el panel de red abierto.

**Resultado observado.** `POST /grv/logistica/traslados/conflictos-mismo-dia` responde con el estado operativo completo:

```json
{"idDenuncia":464435,"fechas":["2026-08-25"]}
→
{"fecha":"2026-08-25","tieneConflicto":true,"traslados":[{
   "idTurno":4560464,"idTraslado":1469816,"esTransportePublico":false,
   "tipoTurno":"Consulta","horaTurno":"00:10:00",
   "centroMedico":"CENTRO MEDICO NOGOYA SAN JUSTO [RKT]","idRegionCuerpo":null,
   "estadoTraslado":"Solicitado","estadoLogisticaIda":null,"estadoLogisticaVuelta":null,
   "agencia":null,"agenciaInformada":false,"horasAlViaje":133,"mismaRegionCuerpo":null,
   "salidas":{"puedeAnular":true,"puedeDerivarALogistica":true,
              "puedeGuardarSinTraslado":true,"requiereAutorizacion":true,"detalle":null}}]}
```

El bloque muestra **cuatro** de esos campos: `idTurno`, `tipoTurno`, `horaTurno`, `centroMedico`. **No muestra** `estadoTraslado`, ni `estadoLogisticaIda`, ni `agencia`, ni `agenciaInformada`. El gestor elige entre anular y no anular sin saber si logística ya tiene el viaje ni si la agencia ya fue avisada.

**Resultado esperado y por qué.** RF-1.2 es explícito y hasta explica su propio motivo: *«Y su estado operativo: en qué estado de logística está y **si a la agencia ya se le avisó del viaje** — porque anular un viaje ya avisado no es lo mismo que anular uno que todavía no salió.»* El dato viaja en la respuesta. Lo único que falta es renderizarlo.

**Efecto colateral sobre la certificación.** CTM-04 no se puede cerrar «parcial por NP-3»: falla completo. Y el argumento de NP-3 —que la rama `agenciaInformada = true` no se puede producir desde la aplicación— pierde relevancia mientras la rama `false` tampoco se muestre.

**Evidencia** · `capturas/K-bloque-conflicto-oper-25082026-1500.png` · payload literal de arriba.

---

### EXP-04 — Las anulaciones y los rechazos del circuito se registran como «Cancelado por alarma repetida» · **ALTA**

**Nuevo.** Es el hallazgo con mayor impacto de negocio de la sesión y no está en ningún hallazgo previo.

**Pasos**
1. Reproducir el bloque de conflicto (EXP-02).
2. Elegir **«Anular ese traslado y usar el nuevo»**.
3. Leer el sub-formulario que se despliega, sin confirmar.
4. Contrastar con el catálogo de motivos en base.

**Resultado observado.** El sub-formulario aparece con el motivo **ya cargado**:

```
Anular ese traslado y usar el nuevo
  El paciente viaja con el traslado que estás cargando.
  El que ya existía se cancela con su motivo.
  Motivo *        Cancelado por alarma repetida
  Observación *   Quedan 112 caracteres.
  [Anular el traslado]
```

Y en base:

```sql
SELECT id_motivo_anulacion, descripcion FROM motivos_anulacion
WHERE id_motivo_anulacion IN (0, 16);
-- 0  | OTROS MOTIVOS
-- 16 | Cancelado por alarma repetida
```

No hay ningún motivo de duplicado en `motivos_anulacion`. **El 16 es «Cancelado por alarma repetida».** Los tres traslados anulados del pool lo confirman: 1469807, 1469808 y 1469810 tienen `id_motivo_anulacion = 16`.

Dos consecuencias, y las dos son del circuito:

- **En la anulación por el bloque**, el select de Motivo viene pre-cargado con «Cancelado por alarma repetida» —a diferencia del resto de los combos del wizard, que arrancan en «Seleccionar»— así que basta un clic en «Anular el traslado» para grabarlo. El gestor no eligió ese texto: se lo pusieron.
- **En el rechazo de un pedido**, RF-3.5 fija el motivo 16 sin intervención del usuario: *«El traslado se cancela con el motivo de anulación 16»*.

**Resultado esperado y por qué.** El PRD §2.2 dedica una sección entera a explicar que los motivos de anulación **no permiten medir el problema**: *««OTROS MOTIVOS» concentra 10.869 de ~15.900 anulaciones (68%)... El motivo específico de duplicado (16) subestima el volumen real, así que no sirve como línea de base.»* El PRD llama al 16 *«el motivo específico de duplicado»* y en el catálogo dice «alarma repetida». Entonces: o el PRD está equivocado sobre qué es el 16, o la implementación eligió el código equivocado. En cualquiera de los dos casos, para logística —que es quien lee `observaciones_anulacion` y el motivo en su grilla— **el resultado de este circuito es indistinguible de una cancelación por alarma repetida**, y NP-9/GO-15 («no hay métrica para saber si el change resolvió el problema que lo justifica») queda cerrado en negativo: no es que falte la métrica, es que el dato que la alimentaría está mal etiquetado en origen.

**Qué hay que decidir.** Un motivo nuevo en `motivos_anulacion` («Duplicado del mismo día no autorizado», o similar) usado por las dos vías, o una corrección del PRD que asuma el 16 y explique cómo se separan los dos usos. Es decisión de negocio, no de implementación, y va antes del GO.

**Evidencia** · `capturas/Q-elegido-ANULAR.png` · `capturas/S-ANULARAUTORIZACIONSIN_TRASLADO-ANULAR.png` · queries de arriba.

---

### EXP-05 — El permiso `autorizar_traslado_mismo_dia` sólo se valida en el front · **ALTA**

**Nuevo.** Mismo patrón que **D-4** y que el XF de **ATD-12** (la obligatoriedad del dictamen que vive en el formulario), pero sobre la operación que **concede** la autorización.

**Pasos** — sonda deliberadamente inocua: se usa un `idAutorizacionTrasladoDuplicado` **inexistente**, que no puede resolver ningún pedido real.

1. Ingresar como `ayioperadort` (persona 1000007, perfiles 4 y 11, **sin** el permiso — verificado con Q6/Q7).
2. Desde la consola de esa misma sesión:

```js
await fetch('/grv/turnos/autorizaciones/resolver-traslado-duplicado', {
  method: 'POST', headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({ idAutorizacionTrasladoDuplicado: 999999999,
                         aprobar: false, idAutorizante: 1000008 })
});
```

3. Repetir la misma llamada desde la sesión de `tramitador.supervisor` y comparar.

**Resultado observado** — las dos respuestas son **idénticas**:

```
sesión ayioperadort  (SIN permiso) :: 200 {"resultado":"NO_ENCONTRADO","resuelto":false,
                                           "mensaje":"No se encontró el pedido de autorización."}
sesión tramitador.supervisor (CON) :: 200 {"resultado":"NO_ENCONTRADO","resuelto":false,
                                           "mensaje":"No se encontró el pedido de autorización."}
```

No hay 401 ni 403. La request atravesó la validación de contrato —se comprueba que sí la hay, porque `pedir-traslado-duplicado` con `justificacion: ""` devuelve **400 `justificacion: must not be blank`**— y llegó hasta la búsqueda del pedido. Lo único que la detuvo fue que el id no existe.

El mismo comportamiento en el resto de los endpoints del circuito, desde la sesión **sin** el permiso:

| Endpoint | Respuesta con la sesión sin permiso |
|---|---|
| `GET traslados-duplicados-pendientes` (contador del autorizante) | **200** `body: 1` — devuelve el contador de pendientes a quien no puede resolver |
| `POST resolver-traslado-duplicado` | **200** `NO_ENCONTRADO` (idéntico al del autorizante) |
| `POST pedir-traslado-duplicado` | **200** `NO_ENCONTRADO` |
| `GET mis-duplicados-resueltos?idSolicitante=1000008` (ajeno) | **200** `body: 0` — acepta el id de otra persona sin rechazarlo |

**Resultado esperado y por qué.** PRD §3: *«**El permiso es el único discriminador.** No se usa el rol: la habilitación se resuelve con `hasPermission`»*, y RF-2.4 hace depender de él la card y la grilla. Un discriminador que sólo condiciona el renderizado no discrimina nada: hoy la habilitación es una decisión de UI. RF-4.4 exige que *«cualquier endpoint nuevo... debe invocar esta validación»* para el gate del turno; el mismo criterio falta acá.

**Alcance de lo demostrado, dicho con precisión.** Queda demostrado que **no hay control de permiso antes de la lógica de negocio**. **No** queda demostrado que una resolución real se complete desde la sesión sin permiso: eso exigía resolver un pedido, y el único pendiente es del pool y está prohibido consumirlo. La prueba concluyente es de una línea: crear un pedido propio y resolverlo desde `ayioperadort`. Se recomienda hacerla antes del GO.

**Evidencia** · salidas literales de arriba, reproducibles con el script de la sesión.

---

### EXP-06 — La grilla de pendientes tiene dos acciones y no las tres de RF-2.5, y «ver detalle» abandona la grilla sin vuelta · **MEDIA**

**Amplía** EST-23 (que ya notaba que «ver detalle» y «gestionar autorización» no tienen Scenario propio) con el comportamiento real.

**Pasos**
1. `tramitador.supervisor` → home → card → grilla de pendientes.
2. Inspeccionar la celda ACCIONES de la fila.
3. Hacer clic en el primer botón (icono).
4. Hacer clic en **«Cerrar»**.

**Resultado observado.**

La celda ACCIONES contiene exactamente **dos** `<button>`:

```html
<td class="MuiTableCell-root ...">
  <div class="MuiGrid-root ...">
    <button class="MuiIconButton-root ..."><img src="/tramitadores/9155602211b834268a49.svg" alt="icon"></button>
    <button class="MuiIconButton-root ..."><img src="/tramitadores/fea72d88025db424dd6e.svg" alt="Icon" style="height: 20px;"></button>
  </div>
</td>
```

El segundo abre un menú con **dos** ítems: «Gestionar autorización» y «Ver información de traslado». Sumado al primero, son **tres funciones** pero repartidas de una forma que no es la de RF-2.5, y **«ver detalle» del pedido no existe**: el primer botón no muestra el detalle del pedido, **navega a `/home/editar`** —la vista completa de la denuncia— y con eso la grilla desaparece.

Peor, **«Cerrar» no vuelve a la grilla**: la URL sigue en `/home/editar` y la pantalla queda en la denuncia. Para retomar la lista de pendientes el autorizante tiene que volver al home, encontrar la card otra vez y entrar de nuevo.

**Resultado esperado y por qué.** RF-2.5: *«Las acciones son: **ver detalle**, **gestionar autorización** y **ver información de traslado**.»* Ver detalle debería mostrar el detalle **del pedido**, no reemplazar la pantalla por la denuncia; y volver debería devolver a la grilla. En un flujo donde el autorizante resuelve varios pedidos seguidos, perder la lista en cada consulta de contexto es un costo real por pedido.

**Evidencia** · `capturas/B-menu-acciones.png` · `capturas/C-detalle-denuncia-desde-grilla.png` · `capturas/C-tras-cerrar-detalle.png`.

---

### EXP-07 — Los dos botones de acción de la fila no tienen nombre accesible · **MEDIA**

**Confirma** el punto ya conocido, con el detalle exacto para arreglarlo.

**Resultado observado.** Ninguno de los dos botones tiene `aria-label`, ni `title`, ni `data-testid`, ni texto. El nombre accesible que queda es el `alt` de la imagen: **`alt="icon"`** en uno y **`alt="Icon"`** en el otro. Un lector de pantalla anuncia «botón icon» y «botón Icon»; con teclado son indistinguibles. Los rótulos reales («Gestionar autorización», «Ver información de traslado») existen, pero sólo como ítems del menú que se abre después de accionar el segundo botón.

**Resultado esperado.** Nombre accesible por acción, y el mismo texto que ya está en el menú. Además hace la automatización de la matriz frágil: hoy los casos ATD-08 y ATD-09 sólo pueden localizar estos botones por índice.

**Nota de alcance.** El mismo defecto está en el resto de la grilla de Turnos (12 botones sin texto en la pantalla), así que es preexistente — pero cae de lleno sobre las dos pestañas que el change agrega.

**Evidencia** · HTML literal en EXP-06 · `capturas/A-grilla-pendientes.png`.

---

### EXP-08 — `mis-duplicados-resueltos` sin parámetro devuelve 500 · **MEDIA**

**Nuevo.**

**Pasos** — desde cualquiera de las dos sesiones:

```js
await fetch('/grv/turnos/autorizaciones/mis-duplicados-resueltos');
```

**Resultado observado**

```
500 {"status":500,"message":"Error interno del servidor. Contacte al administrador.",
     "body":"INTERNAL_SERVER_ERROR"}
```

Con el parámetro, el mismo endpoint responde `200 {"body":0}`. Y acepta cualquier valor sin validarlo: `idSolicitante=1`, `=273` o `=1000008` devuelven 200.

**Resultado esperado y por qué.** Un parámetro obligatorio ausente es un **400** con el nombre del parámetro — que es exactamente lo que este mismo servicio hace bien en `pedir-traslado-duplicado` (`400 justificacion: must not be blank`). Un 500 genérico sobre el endpoint que alimenta la card del solicitante confunde el diagnóstico: ante un error el front no puede distinguir «pedí mal» de «el servicio está caído», y la card simplemente no aparece — que es el modo de falla silencioso que EST-03 describe.

---

### EXP-09 — Las tres salidas no se pueden operar con el teclado · **MEDIA**

**Nuevo.**

**Pasos**
1. Reproducir el bloque de conflicto (EXP-02).
2. Llevar el foco al primer radio y pulsar **Space**.
3. Pulsar **ArrowDown**, **ArrowDown**, **ArrowUp**.

**Resultado observado**

```
foco en el radio ANULAR   -> checked: ninguno   | foco: INPUT[radio]:ANULAR
Space                     -> checked: ANULAR    | foco: INPUT[radio]:ANULAR
ArrowDown                 -> checked: ninguno   | foco: BODY
ArrowDown                 -> checked: ninguno   | foco: BODY
ArrowUp                   -> checked: ninguno   | foco: BODY
```

Space selecciona el primer radio. **Las flechas no mueven dentro del radiogroup**: la selección se pierde y el foco cae a `<body>`. Y con Tab el recorrido sale del grupo después del primer radio:

```
INPUT[radio]:ANULAR → DIV → DIV → BUTTON → BUTTON → BUTTON
```

O sea que **«Guardar el turno sin traslado» y «Pedir autorización» no son alcanzables con el teclado**, y la única salida que sí lo es se deselecciona en cuanto el usuario intenta navegar.

**Resultado esperado y por qué.** En un `role="radiogroup"` las flechas mueven el foco y la selección entre opciones, y sólo un radio del grupo entra en el orden de tabulación (patrón ARIA de radio group). RF-1.3 obliga al gestor a **elegir una** de tres salidas: si dos de las tres no se pueden alcanzar sin mouse, el paso obligatorio del wizard no se puede completar por teclado. La semántica del grupo está bien puesta (`role` y `aria-label` correctos), así que el arreglo es el manejo de teclas, no el marcado.

**Evidencia** · `capturas/N-teclado-space.png` · `capturas/N-teclado-radios.png`.

---

### EXP-10 — El drawer de resolución no tiene semántica de diálogo, y el dictamen no tiene label ni límite · **MEDIA**

**Nuevo.**

**Resultado observado** sobre el drawer de «Gestionar autorización»:

| Punto | Observado | Esperado |
|---|---|---|
| Semántica | el panel es un `div.MuiGrid-root` **sin `role`** y **sin `aria-modal`** | `role="dialog"` + `aria-modal="true"` + nombre accesible, para que se anuncie la apertura |
| Label del dictamen | **ningún `<label>`** en el panel y el textarea sin `aria-label` ni `aria-labelledby`; el único rótulo es el placeholder *«Escribí el motivo, sobre todo si rechazás»* | label asociado — el placeholder desaparece al escribir y no es nombre accesible (WCAG 3.3.2) |
| Límite del dictamen | `maxLength = -1` (sin atributo) | la columna es `dictamen VARCHAR(1000)` (PRD §7): sin límite en el cliente, un dictamen largo se pierde o falla en el servidor sin explicación |
| Trampa de foco | **correcta** — el foco cicla dentro del panel | ✅ |
| Escape | **cierra** el drawer y devuelve el foco a un botón | ✅ |

**Por qué importa el `maxlength`.** El dictamen es *«lo único que le explica por qué le dijeron que no»* (PRD §2.9) y es obligatorio para rechazar. Un rechazo cuyo dictamen se trunca o se rechaza sin aviso deja al gestor exactamente donde RF-2.6 no quiere que quede: sin saber qué hacer con el turno.

**Evidencia** · `capturas/C-drawer-resolucion.png` · volcado del DOM del panel en la sesión.

---

### EXP-13 — La observación de la anulación admite 112 caracteres, sin criterio documentado y sin `maxlength` · **MEDIA**

**Nuevo.**

**Resultado observado.** Al elegir «Anular ese traslado y usar el nuevo», el campo **Observación \*** muestra el contador **«Quedan 112 caracteres.»** con el campo vacío. El elemento no tiene atributo `maxlength` (`maxLength = -1`): el límite es de la aplicación, no del control.

**Por qué es un hallazgo y no un detalle.** `traslados.observaciones_anulacion` es `VARCHAR(500)` (PRD §7). El presupuesto que ve el gestor es de **112**, así que la aplicación está reservando ~388 caracteres para un texto que agrega sola —presumiblemente el «quién anuló y cuándo» y la referencia al turno que exige CTM-18—. Nada de eso está declarado en ningún artefacto: ni el límite, ni el texto automático, ni cómo se compone. Consecuencias concretas:

- **CTM-18 no es verificable como está escrito.** El caso pide comprobar que la observación *«nombra el turno por tipo y hora, dice quién anuló y cuándo, y no contiene ningún identificador interno ni secuencias de escapado HTML»*. Sin saber qué parte la escribe el sistema y qué parte el gestor, no hay resultado esperado objetivo.
- **112 caracteres es poco** para el único texto que logística va a leer sobre por qué se canceló un viaje que quizá ya coordinó (PRD §2.3: *«a veces con la agencia ya avisada»*).
- Combinado con **EXP-04**, el paquete que llega a logística es: motivo «Cancelado por alarma repetida» + 112 caracteres de contexto.

**Resultado esperado.** El límite declarado en el requisito, el `maxlength` puesto en el control, y la composición del texto automático especificada — con eso CTM-18 pasa a ser ejecutable.

**Evidencia** · `capturas/Q-elegido-ANULAR.png`.

---

### EXP-11 — La hora del traslado en conflicto se muestra con segundos · **BAJA**

**Nuevo.**

**Resultado observado.** El bloque muestra `Turno 4560464 · Consulta · **00:10:00** · CENTRO MEDICO NOGOYA SAN JUSTO [RKT]`. El backend manda `"horaTurno":"00:10:00"` y el front lo imprime tal cual. En base, `turnos.hora_turno` es `00:10`. Ningún otro lugar del circuito muestra segundos: el drawer dice `FECHA TURNO: 25/08/2026 - 11:15` y la grilla `14/08/2026 - 09:29`.

**Resultado esperado.** Hora sin segundos, como en el resto del circuito. Es el caso de un valor crudo del contrato llegando a la pantalla sin formatear — la misma clase de descuido que EXP-02, en versión inofensiva.

**Evidencia** · `capturas/K-bloque-conflicto-oper-25082026-1500.png`.

---

### EXP-12 — Tres formatos de fecha en la misma fila, y las columnas nuevas rompen la convención del encabezado · **BAJA**

**Nuevo.**

**Resultado observado** — fila de la grilla de pendientes, tal cual:

| Columna | Valor | Formato |
|---|---|---|
| `FECHA TURNO` | `2026-08-25 11:15` | ISO con hora |
| `FECHA SOLICITADA` | `2026-08-14` | ISO sin hora |
| `Fecha del pedido` | `14/08/2026 - 09:29` | dd/mm/aaaa con hora |

Y los encabezados mezclan dos convenciones. Las columnas preexistentes van en mayúsculas (`DENUNCIA`, `ACCIDENTADO`, `DOCUMENTO`, `EMPLEADOR`, `FECHA TURNO`, `SEVERIDAD`, `ANALISTA`, `ACCIONES`) y **las tres que agrega el change van en oración**: `Lo pidió`, `Fecha del pedido`, `Justificación`. Lo mismo en la pestaña del solicitante: `Resultado`, `Lo resolvió`, `Fecha de la respuesta`, `Dictamen`, `Mi justificación` junto a `DENUNCIA`, `ACCIDENTADO`, `FECHA TURNO`.

El mismo cruce dentro del drawer de resolución, donde conviven `Tipo de turno:`, `Lo pidió:`, `Fecha del pedido:` con `FECHA TURNO:`, `ACCIDENTADO:` y `DENUNCIA:` — rótulos de columna de grilla reutilizados como rótulos de campo.

**Resultado esperado.** Un formato de fecha y una convención de encabezado por grilla. Es cosmético, pero es la primera impresión de la única pantalla nueva del change, y es de arreglo trivial.

**Evidencia** · `capturas/A-grilla-pendientes.png` · `capturas/F-tab-resueltos-oper.png` · `capturas/C-drawer-resolucion.png`.

---

## 3. Bloque (B) — Huecos de regla de negocio

Acá el sistema no está necesariamente mal: **falta la decisión**. Cada uno bloquea escribir un resultado esperado objetivo.

### EXP-B1 — RF-1.2 y RF-5.1 se contradicen sobre el número de turno

RF-1.2 dice que el bloque identifica el traslado *«por sus datos, nunca por su id: **número de turno**, tipo de turno, hora, centro médico y agencia»*. RF-5.1 dice *«Nunca se muestra un id al usuario. **Ni de turno**, ni de traslado, ni de autorización, ni de persona»*.

En el SAS el «número de turno» **es** el `id_turno`: la grilla lo rotula `#TURNO`, el filtro lo llama «ID Turno» y el modal de traslado escribe `#Turno: 4560457`. No hay un número de turno de negocio distinto del id.

**Qué hay que decidir.** O existe un identificador de turno presentable al usuario y hay que definirlo, o RF-1.2 debe dejar de listar «número de turno» entre los datos permitidos. **De esto depende si EXP-02 es un defecto de código o de requisito**, y también si CTM-05 (P1) es ejecutable: hoy su resultado esperado contradice a RF-1.2.

### EXP-B2 — El front decide si preguntar por el conflicto, usando un pre-chequeo de otro servicio

Al tildar «Requiere traslado», el front **no llama primero a `E-CONF`**. Llama a `POST /grv/traslados/traslado/tiene-por-denuncia-y-fecha` (servicio `wstraslados`) y **sólo si ése responde `true`** invoca `POST /grv/logistica/traslados/conflictos-mismo-dia` (servicio `wslogistica`). Verificado en dos fechas:

| Fecha | `tiene-por-denuncia-y-fecha` | `conflictos-mismo-dia` invocado | Bloque |
|---|---|---|---|
| 25/08/2026 | `true` | **sí** | aparece |
| 27/08/2026 | `false` | **no** | no aparece |

RF-1.4 dice: *«**Qué salidas están habilitadas lo decide el backend**, caso por caso... El front sólo las renderiza.»* Eso se cumple para *qué* salidas. Lo que no está contemplado es que el front decida **si preguntar**, con un endpoint distinto, de otro servicio, con su propia noción de «tiene traslado». Son dos definiciones de vigencia que tienen que coincidir para siempre, y ninguna está declarada como contrato.

**Es el mecanismo concreto detrás de dos riesgos ya abiertos**: si el pre-chequeo dice «no» donde el gate diría «sí», el gestor **no ve el bloque** y el 409 le llega al guardar sin ninguna salida disponible (que es CTM-14 / `tasks 7.14`); y es exactamente donde se materializaría la asimetría de transporte público de EST-08 / R-8.

**No reproducido como divergencia.** Se compararon las dos definiciones en cuatro fechas (25/08, 27/08, 01/09, 02/09) y **coincidieron en las cuatro** — incluido 02/09, donde el único traslado está cancelado y los dos lo excluyen correctamente. No se demostró discrepancia; se documenta la arquitectura y el punto donde habría que buscarla, con transporte público como el candidato natural.

> Dato adicional del mismo experimento: `E-CONF` responde **401** a un `fetch` autenticado del mismo origen — necesita el JWT explícito (criterio de entrada CE-2). Es decir que el bloque de conflicto depende de un camino de token que, si falla, produce **silencio**, no un error. Es el refuerzo empírico de CTM-14.

### EXP-B3 — El PRD §7.1 está desactualizado: la devolución al solicitante existe y muestra el dictamen

El PRD §7.1 declara cuatro huecos como estado real:

- **H-1** *«El dictamen no se lee en ninguna parte... no viaja en ningún endpoint de lectura»*
- **H-2** *«El gestor nunca se entera del resultado»*
- **H-3** *«La justificación desaparece al resolverse»*

**Los tres están construidos y funcionando en DEV.** `ayioperadort` tiene en su grilla de Turnos la pestaña **«Autorización Doble Traslado Resuelta»**, con estas columnas y estos datos reales:

| Resultado | Lo resolvió | Fecha de la respuesta | Dictamen | Mi justificación |
|---|---|---|---|---|
| Rechazado | Tramitador Supervisor QA | 14/08/2026 - 09:29 | `Rechazado: los estudios se pueden agendar otro dia, no corre...` | `Solicito segundo traslado para estudios complementarios.` |
| Autorizado | Tramitador Supervisor QA | 14/08/2026 - 09:29 | `Aprobado: interconsulta justificada, paciente con inmoviliza...` | `Interconsulta con especialista el mismo dia que la sesion de...` |

Y el tooltip devuelve el texto **completo** de las dos columnas:

```
"Rechazado: los estudios se pueden agendar otro dia, no corresponde segundo traslado."
"Solicito segundo traslado para estudios complementarios."
```

Al entrar, se dispara `POST marcar-duplicados-vistos` y el contador `GET mis-duplicados-resueltos` queda en 0 — el mecanismo de RF-2.9 está entero.

**Esto resuelve EST-01** —la contradicción entre `tasks.md` («implementado») y el PRD §7.1 («inexistente»), ambos del mismo día— **a favor de `tasks.md`**. Y tiene consecuencia directa sobre el alcance: la matriz declara §3 (DRS-01…DRS-06) sobre el supuesto de que hay que verificar si existe. Hay que actualizar el PRD §7.1 antes de ejecutar, porque hoy el plan y la matriz apuntan a un estado del sistema que ya no es el real.

**Queda abierto H-4** (el tooltip de logística que nunca dice quién autorizó): no se pudo verificar, ver §«Lo que no pude explorar».

### EXP-B4 — El catálogo autodeclarativo sigue vivo y el bloque de conflicto lo sigue pidiendo

Cada vez que se tilda «Requiere traslado», el front llama a `GET /grv/listados/motivos-traslados/mismo-dia`, que devuelve:

```json
[{"codigo":1,"descripcion":"Autorizado por Auditoria Medica"},
 {"codigo":2,"descripcion":"Autorizado por Supervisión"}]
```

Son **los dos motivos autodeclarativos que el change existe para eliminar**. El PRD §1 los nombra como el problema: *«el catálogo tiene exactamente dos opciones... Pero **el campo es autodeclarativo**: lo completa el mismo gestor que carga el turno y no hay nada del otro lado»*, y cifra en **2.156** los duplicados de 2026 que declararon una autorización inexistente.

El catálogo se pide **incluso en fechas sin conflicto** (verificado en 27/08/2026). En el bloque de este circuito no se vio usado —las tres salidas no lo ofrecen—, así que probablemente sea el camino del usuario **con** permiso («Autorizar los dos», RF-2.2, que no se pudo ejercitar) o un resto de la vía anterior.

**Qué hay que decidir.** El PRD no dice qué pasa con la vía vieja: si se da de baja el catálogo, si el gate la sigue aceptando como motivo declarado —RF-4.2 dice que **sí**: *«Acepta: motivo declarado, pedido pendiente, o pedido aprobado»*— y en ese caso **cuál es la ganancia de control**, porque el motivo declarado sigue siendo autodeclarativo. Hoy el circuito nuevo convive con el que vino a reemplazar, y RF-4.2 lo bendice explícitamente.

### EXP-B5 — La card del solicitante no se pudo distinguir de «no hay nada que mostrar» · **no reproducido**

RF-2.9 y RF-2.10 exigen una card en el home del solicitante con la cantidad de resueltos no vistos. En el home de `ayioperadort` **no hay ninguna card del circuito**: se recorrieron las 30 cards y no aparece ni «Doble Traslado» ni «resuelt».

Pero el pool está en un estado que hace la observación **inconcluyente**: los dos pedidos resueltos tienen `fecha_visto_solicitante = 2026-08-18 18:26:20`, o sea que ya fueron vistos, y `GET mis-duplicados-resueltos?idSolicitante=1000007` devuelve `0`. Con 0 no vistos, RF-2.9 dice que la card **no debe aparecer** — *«sólo aparece cuando hay algo que mostrar»*. La ausencia es el comportamiento correcto para este dato.

**No se cuenta como defecto.** Distinguirlo exige un pedido resuelto y no visto, y `fecha_visto_solicitante` es irreversible desde la aplicación (RB-4), así que el pool actual no sirve y hay que crear el fixture. Es DP-4 de la matriz y DRS-01…DRS-05 lo cubren.

### EXP-B6 — `mis-duplicados-resueltos` acepta el id de otra persona · **fuga no demostrada**

Desde la sesión de `ayioperadort` el endpoint acepta `idSolicitante=1000008`, `=273` y `=1` con **200**, sin rechazar el id ajeno: el «mis» del nombre no lo impone el servidor, lo impone el cliente al pasar su propio id.

**No se demostró fuga:** las cuatro llamadas devolvieron `body: 0`, y el contador propio de 1000007 también es 0, así que no se puede distinguir «filtra bien» de «no filtra y no había nada». Se documenta como riesgo a cerrar junto con EXP-05 —es el mismo patrón, autorización delegada al cliente— y la prueba concluyente es la misma: un pedido propio no visto y una llamada cruzada. Lo que sí queda claro es que **el endpoint no valida que el `idSolicitante` sea el de la sesión**, y eso es verificable sin fixture.

---

## 4. Bloque (C) — Ajeno al change

Se cruzó con el circuito pero no es de este desarrollo. Se reporta aparte para que no ensucie la decisión de GO.

### EXP-C1 — El bundle del front se sirve sin compresión y se estanca · **ALTA (de ambiente)**

**Bloqueó el arranque de esta sesión** y merece arreglarse antes de cualquier certificación en DEV.

`GET /static/js/main.64fe4179.js` **sin** `Accept-Encoding: gzip` no termina: en tres intentos consecutivos devolvió 351 KB en 120 s, 82 KB en 116 s, y 0 bytes en 306 s. **Con** `--compressed`, el mismo recurso baja completo —1.720.694 bytes— en **8,1 s**.

Efecto en el navegador: `document.readyState` queda en `interactive`, el `<div id="root">` nunca se hidrata y la página de login se sirve como un shell de 652 bytes sin ningún input. No hay error: hay silencio.

```
t+ 5s  {"ready":"interactive","inputs":0,"html":652}
t+15s  {"ready":"interactive","inputs":0,"html":652}
t+30s  {"ready":"interactive","inputs":0,"html":652}
--- PENDIENTES ---
45130ms  https://dev.sas.colonia-suiza.com.ar/static/js/main.64fe4179.js
```

**Recomendación.** Habilitar compresión para `application/javascript` en el gateway. Sin eso, cualquier corrida de la matriz en DEV va a tener fallas intermitentes de arranque que se van a leer como defectos de la aplicación.

### EXP-C2 — El micro-front del chatbot da 404 y muere en cada pantalla · **MEDIA (de ambiente)**

En todas las pantallas, incluidas las dos del circuito:

```
CONSOLE[error]  Failed to load resource: the server responded with a status of 404 ()
PAGEERROR  Uncaught (in promise) Error: parcel 'parcel-0' died in status BOOTSTRAPPING:
           Error loading https://dev.sas.colonia-suiza.com.ar/coloniaChatbot/grv-colonia-chatbot.js
```

No afecta al circuito, pero **ensucia el criterio «la consola queda limpia»** que la matriz usa en ATD-09. Conviene desplegar el módulo en DEV o desregistrarlo, para que un error de consola vuelva a ser señal.

### EXP-C3 — Ruido permanente de consola en la grilla de Turnos · **BAJA**

En cada render de la grilla donde viven las dos pestañas del circuito:

- `Warning: findDOMNode is deprecated and will be removed in the next major release`
- `Warning: Each child in a list should have a unique "key" prop` (varias veces por render)
- `Warning: validateDOMNesting(...): <td> cannot appear as a child of <div>` — HTML de tabla inválido
- `Route path "/siniestros*" will be treated as if it were "/siniestros/*"`, ídem `/ortopedia*` y `/solicitudesGenericas*`

### EXP-C4 — `HEAD` sobre estáticos devuelve 404 de Kong · **BAJA**

`HEAD /static/js/main.64fe4179.js` → `HTTP/1.1 404 Not Found`, `Server: kong/2.4.1`, mientras el `GET` del mismo recurso devuelve 200. Es una inconsistencia del gateway; rompe cualquier chequeo de disponibilidad que use HEAD.

### EXP-C5 — Los filtros de la grilla no tienen label programático · **BAJA**

Los cuatro filtros de la grilla que hospeda las pestañas del circuito (**ID Turno**, **DNI**, **Nro. Denuncia**, **Nombre y Apellido**) son inputs **sin `name`, sin `id` estable** (React genera `:rb:`, `:rc:`, `:rd:`, `:re:`), **sin `aria-label`** y **sin `<label for>`**. El rótulo visible es un `<p>` hermano, no asociado. Tres de los cuatro comparten el placeholder **«Ingresar»**.

Para un lector de pantalla son cuatro campos de texto indistinguibles. Y para la automatización de la matriz sólo se pueden localizar por posición.

### EXP-C6 — Modal «Reasignaciones parcialmente aplicadas» abierto en el home del supervisor · **BAJA**

Al entrar como `tramitador.supervisor` aparece un modal:

```
Reasignaciones parcialmente aplicadas
Algunas reasignaciones no pudieron procesarse. A continuación se listan
Nro de siniestro => Nro de gestor nuevo:
-
[Aceptar]
```

La lista está vacía (`-`): el modal se muestra sin nada que mostrar. Es un aviso de otro módulo y se interpone en el camino a la card de pendientes.

---

## 5. Trazabilidad contra lo ya documentado

| Hallazgo | Estado | Contra qué |
|---|---|---|
| EXP-01 | **confirma en campo** | **EST-09** ramas b y d · advertencia §0.5.1 de la matriz · casos ATD-10, ATD-11 |
| EXP-02 | **nuevo (evidencia)** — hace fallar el caso | **CTM-05** (P1) · **RF-5.1**, D10 |
| EXP-03 | **nuevo** — hace fallar el caso por otra causa | **CTM-04** · **RF-1.2** · reencuadra **NP-3** |
| EXP-04 | **nuevo** | **RF-3.5** · PRD §2.2 · cierra **NP-9 / GO-15** en negativo |
| EXP-05 | **nuevo** | PRD §3, **RF-2.4**, **RF-4.4** · mismo patrón que **D-4** y el XF de **ATD-12** |
| EXP-06 | **amplía** | **EST-23** · **RF-2.5** |
| EXP-07 | **confirma** | punto ya conocido de la grilla · casos ATD-08, ATD-09 |
| EXP-08 | **nuevo** | contrato de `E-RES` · agrava **EST-03** |
| EXP-09 | **nuevo** | **RF-1.3** · plan §3.1 accesibilidad |
| EXP-10 | **nuevo** | **RF-2.6** · PRD §7 (`dictamen` 1000 car.) |
| EXP-11 | **nuevo** | **RF-1.2** |
| EXP-12 | **nuevo** | plan §3.1 consistencia visual |
| EXP-13 | **nuevo** — vuelve **CTM-18** no verificable | **RF-3.6**, **CTM-18** |
| EXP-B1 | **nuevo** | **RF-1.2** vs **RF-5.1** — bloquea el cierre de **CTM-05** |
| EXP-B2 | **nuevo (mecanismo)** | **RF-1.4** · explica **CTM-14 / `tasks 7.14`** y **EST-08 / R-8** |
| EXP-B3 | **resuelve** | **EST-01** a favor de `tasks.md` · deja el PRD §7.1 obsoleto |
| EXP-B4 | **nuevo** | PRD §1 vs **RF-4.2** |
| EXP-B5 | no reproducido | **RF-2.9**, **RF-2.10** · requiere **DP-4** |
| EXP-B6 | fuga no demostrada | mismo patrón que EXP-05 |
| CTM-07, CTM-22, CTM-03 | **pasan** | verificados en esta sesión |
| Responsive del bloque | **pasa** | confirma correcciones de **VAP-04** |
| ATD-02 (rama API), ATD-06 | **pasan** | verificados en esta sesión |
| **EST-16** | **confirmado** | `puedeDerivarALogistica: true` presente en el payload de `E-CONF` |

> **Sobre EST-16:** la cuarta bandera `puedeDerivarALogistica` está en la respuesta con valor `true`, y el bloque renderiza exactamente **tres** salidas. Se registra el valor observado, como pide CTM-13 (OBS): no tiene efecto visible en esta rama.

---

## 6. Recomendaciones, en orden

1. **Resolver EXP-04 antes del GO.** Es decisión de negocio: motivo de anulación propio para el duplicado, o corrección del PRD asumiendo el 16. Mientras no se resuelva, el change no puede medir su propio efecto y le entrega a logística un motivo que dice otra cosa.
2. **Cerrar EXP-05 con la prueba concluyente** (crear un pedido propio y resolverlo desde `ayioperadort`) y, con ese resultado, poner el control de permiso del lado del servidor en `resolver`, `pedir` y los dos contadores. Es una hora de trabajo y hoy el único discriminador del circuito es una condición de renderizado.
3. **Declarar la máquina de estados del pedido** (EXP-01 / EST-09): precondiciones de `aprobar()` y qué pasa cuando no se cumplen. Como mínimo, y ya: mostrar el estado del traslado en el drawer y no dejar aprobar sobre un traslado cancelado.
4. **Renderizar el estado operativo en el bloque** (EXP-03). El dato ya viaja; es sólo mostrarlo, y sin él la decisión de anular se toma a ciegas.
5. **Resolver la contradicción RF-1.2 / RF-5.1** (EXP-B1) y, según lo que se decida, quitar el `id_turno` de las cuatro superficies de EXP-02. Sin esa decisión, CTM-05 (P1) no se puede cerrar.
6. **Arreglar el ambiente antes de ejecutar la matriz** (EXP-C1 y EXP-C2): compresión del bundle y el micro-front del chatbot. Si no, la corrida va a tener fallas de arranque que se van a leer como defectos del producto.
7. **Actualizar el PRD §7.1** con lo de EXP-B3 antes de ejecutar §3 de la matriz, y decidir qué pasa con el catálogo autodeclarativo de EXP-B4.
8. **Accesibilidad del paso obligatorio** (EXP-09 y EXP-10): teclas de flecha en el radiogroup, `role="dialog"` en el drawer, label del dictamen y `maxlength` en los dos textos que se persisten (EXP-13).
9. **Nombre accesible en las acciones de fila** (EXP-07): el texto ya existe en el menú, y además hace robusta la automatización de ATD-08 y ATD-09.
10. **Formato de fechas y encabezados** (EXP-12) y la hora sin segundos (EXP-11): cosmético, trivial, y es lo primero que se ve de la única pantalla nueva.

---

## 7. Datos que dejé en DEV

**Ninguno.** La sesión no escribió una sola fila.

Se recorrió el wizard de nuevo turno hasta el paso 2 en varias corridas, se ejercitaron las tres salidas del bloque de conflicto y se abrió el drawer de resolución, pero **ningún turno se guardó, ningún pedido se creó y ningún pedido se resolvió**: todos los wizards se abandonaron antes de confirmar, y no se pulsó «Autorizar», «Rechazar», «Anular el traslado» ni «Enviar el pedido» en ningún momento.

Los pedidos preexistentes del pool (ids 1, 2, 3) **no se tocaron**, y ningún traslado preexistente se anuló.

### Verificación — línea de base contra estado final

```sql
-- V1 · Pedidos: los tres del pool, sin cambios, y sin filas nuevas
SELECT id_autorizacion_traslado_duplicado id, id_traslado, estado, id_solicitante,
       fecha_solicitud, id_autorizante, fecha_autorizacion, fecha_visto_solicitante
FROM autorizaciones_traslado_duplicado ORDER BY 1;
```

```
id | id_traslado | estado | id_solicitante | fecha_solicitud     | id_autorizante | fecha_autorizacion  | fecha_visto_solicitante
---+-------------+--------+----------------+---------------------+----------------+---------------------+------------------------
1  | 1469808     | 1      | 1000007        | 2026-08-14 09:29:07 | NULL           | NULL                | NULL
2  | 1469809     | 2      | 1000007        | 2026-08-14 09:29:10 | 1000008        | 2026-08-14 09:29:28 | 2026-08-18 18:26:20
3  | 1469810     | 3      | 1000007        | 2026-08-14 09:29:12 | 1000008        | 2026-08-14 09:29:28 | 2026-08-18 18:26:20
```

Idéntico a §0.5 de la matriz. `fecha_visto_solicitante` **no cambió** —importante, porque es irreversible (RB-4) y se abrió la pestaña «Resuelta» como `ayioperadort`: la abrió sobre pedidos que ya estaban vistos, así que `marcar-duplicados-vistos` no tuvo nada que marcar y devolvió `body: 0`.

```sql
-- V2 · Turnos de la denuncia: sin altas
SELECT COUNT(*) n, MAX(id_turno) maxid FROM turnos WHERE id_denuncia = 464435;
-- n = 9 | maxid = 4560464   (igual que al inicio de la sesión)

-- V3 · Traslados del paciente: sin altas y sin cambios de estado
SELECT t.id_traslado, tu.id_turno, tu.fecha_turno, tu.hora_turno, t.id_estado_traslado,
       t.id_estado_logistica_ida, t.es_duplicado_autorizado, t.id_motivo_anulacion
FROM traslados t JOIN turnos tu ON tu.id_turno = t.id_turno
WHERE tu.id_denuncia = 464435 ORDER BY t.id_traslado;
```

```
id_traslado | id_turno | fecha_turno | hora  | estado | log_ida | dup_aut | motivo
------------+----------+-------------+-------+--------+---------+---------+-------
1469807     | 4560454  | 2026-08-25  | 10:44 | 4      | 6       | NULL    | 16
1469808     | 4560455  | 2026-08-25  | 11:15 | 4      | 6       | NULL    | 16
1469809     | 4560456  | 2026-09-01  | 12:30 | 1      | 1       | 1       | NULL
1469810     | 4560457  | 2026-09-02  | 13:45 | 4      | NULL    | NULL    | 16
1469816     | 4560464  | 2026-08-25  | 00:10 | 1      | NULL    | NULL    | NULL
```

### Query para encontrar cualquier resto que se me haya pasado

Toda observación y toda justificación escrita en esta sesión llevaba el prefijo `INI-2 EXPLORATORIA`. Como nada se guardó, estas dos queries deben devolver **cero filas**; si alguna devuelve algo, es un resto de esta sesión:

```sql
-- R1 · Turnos con el marcado de la sesión
SELECT id_turno, id_denuncia, fecha_turno, hora_turno, observaciones
FROM turnos WHERE observaciones LIKE 'INI-2 EXPLORATORIA%';

-- R2 · Pedidos con el marcado de la sesión
SELECT id_autorizacion_traslado_duplicado, id_traslado, estado, justificacion, dictamen
FROM autorizaciones_traslado_duplicado
WHERE justificacion LIKE 'INI-2 EXPLORATORIA%' OR dictamen LIKE 'INI-2 EXPLORATORIA%';

-- R3 · Traslados anulados con el marcado de la sesión
SELECT id_traslado, id_turno, id_estado_traslado, id_motivo_anulacion, observaciones_anulacion
FROM traslados WHERE observaciones_anulacion LIKE 'INI-2 EXPLORATORIA%';
```

### SQL de reversión sugerido — **no ejecutado, y hoy innecesario**

Se deja escrito para el caso de que R1/R2/R3 devuelvan filas. **No hace falta correrlo con el estado actual del ambiente.** Y la vía correcta es la aplicación, no la base (RB-2): cancelar los turnos y traslados con el circuito de cancelación normal, y **no borrar pedidos** (RB-3).

```sql
-- SÓLO si R1/R2/R3 devuelven filas, y sólo como último recurso.
-- Preferir siempre la cancelación por la aplicación (RB-2).
-- Ejecutar dentro de una transacción y revisar el SELECT antes del DELETE.

-- START TRANSACTION;
--   DELETE FROM autorizaciones_traslado_duplicado
--    WHERE justificacion LIKE 'INI-2 EXPLORATORIA%' OR dictamen LIKE 'INI-2 EXPLORATORIA%';
--   DELETE t FROM traslados t JOIN turnos tu ON tu.id_turno = t.id_turno
--    WHERE tu.observaciones LIKE 'INI-2 EXPLORATORIA%';
--   DELETE FROM turnos WHERE observaciones LIKE 'INI-2 EXPLORATORIA%';
-- -- verificar que los conteos de V1, V2 y V3 volvieron a los de arriba
-- -- COMMIT;  /  ROLLBACK;
```

---

## 8. Lo que no pude explorar y por qué

Lo que sigue **no se probó**. Nada de esto se cuenta como hallazgo ni como verificado.

### 8.1 El guardado del turno y la creación de un pedido propio

**No alcanzado.** El paso 2 del wizard se completó hasta el bloque de conflicto y las tres salidas, pero el formulario de traslado sigue con más campos obligatorios encadenados —«Traslado solicitado por», «Tipo de viaje», «Medios de transporte» y, detrás de ése, los domicilios de origen y destino— cada uno de los cuales despliega el siguiente. Cada iteración sobre este ambiente cuesta 2-4 minutos (ver EXP-C1) y no se llegó a cerrar la cadena hasta el paso 3 de confirmación.

**Qué quedó sin cubrir por esta razón**, todo dependiente de tener un turno guardado y un pedido propio:

| Línea de exploración | Qué habría cerrado |
|---|---|
| **Conflicto múltiple** (heurística 3) | **EST-15** / `tasks 7.3` — el caso **CTM-06** (P1, XF). Exige dos traslados vigentes en la misma fecha; en 25/08/2026 hay **uno** (1469816) y los otros dos están cancelados. Se construye pidiendo autorización en una fecha limpia —el traslado queda vigente sin estado de logística— y volviendo a cargar. Se verificó que la fecha 27/08/2026 está limpia y sirve de base |
| **La prueba concluyente de EXP-05** | Resolver un pedido propio desde `ayioperadort`. Es lo único que falta para pasar EXP-05 de «no valida el permiso antes de la lógica» a «un usuario sin permiso resuelve» |
| **Doble clic y doble envío** (heurística 2) | **R-7** / **NP-2** — sin bloqueo optimista. Exige un pendiente propio: doble clic en «Autorizar», dos pestañas sobre el mismo pedido, y volver atrás con el navegador después de guardar |
| **El texto de la observación de anulación** (heurística 4) | **CTM-18** — si queda con segundos, si escapa la fecha (`&#x2F;`), si nombra algún id. Exige ejecutar una anulación real, y por EXP-13 hoy además no hay resultado esperado objetivo |
| **Coherencia UI ↔ base tras cada acción** (heurística 5) | Sobre qué traslado quedan `id_estado_logistica_ida` y `es_duplicado_autorizado` — **D3**, el defecto más profundo que tuvo el circuito, y los casos **ATD-03**, **ATD-10**, **ATD-11** |
| **La card del solicitante** (EXP-B5) | **RF-2.9 / RF-2.10** — exige un resuelto **no visto** (DP-4), y `fecha_visto_solicitante` es irreversible (RB-4) |
| **Auto-aprobación con permiso** | **RF-2.2**, casuística **C-05**, **ATD-04** — la tercera salida del bloque con `tramitador.supervisor`, que debería decir «Autorizar los dos» en lugar de «Pedir autorización». Es probablemente donde se usa el catálogo de EXP-B4 |

Todo esto es ejecutable en DEV con los usuarios y la denuncia de esta sesión. La única precondición es cerrar la cadena de campos del formulario de traslado una vez.

### 8.2 La grilla de logística

**No accesible.** No hay usuario del sector logística entre los dos disponibles, y el permiso no habilita esa pantalla. Quedan sin verificar:

- **RF-3.4** — franja de color, ícono con tooltip y entrada en la leyenda al pie. El pool tiene el dato ideal (`1469809` con `id_estado_logistica_ida = 1` y `es_duplicado_autorizado = 1`), pero no la pantalla.
- **R-21 / NP-10** (heurística 7) — la precedencia entre señales, y si una fila con `requiere_revision` + duplicado autorizado **oculta la marca**. En toda la denuncia B464435 `requiere_revision` es NULL en los cinco traslados, así que ni siquiera hay dato para la combinación: haría falta un traslado con las dos señales, que sólo se prepara por SQL de escritura — fuera de alcance.
- **H-4** del PRD §7.1 — el tooltip que nunca dice quién autorizó.

### 8.3 Divergencia del contador global vs. la grilla (heurística 6)

**No reproducido.** El riesgo **R-2** dice que el contador de la card es global (`countByEstado(1)`, sin filtro de alcance) y la grilla está acotada por el alcance del usuario. Se compararon los tres números y **coinciden**:

| Fuente | Valor |
|---|---|
| `SELECT COUNT(*) FROM autorizaciones_traslado_duplicado WHERE estado = 1` | **1** |
| `GET traslados-duplicados-pendientes` | `{"body":1}` |
| Card del home de `tramitador.supervisor` | **1** |
| Filas de la grilla de pendientes | **1** (`1–1 de 1`) |

Coinciden porque **hay un solo pendiente en toda la base y está dentro del alcance de `tramitador.supervisor`**. Con un pendiente de otra cartera —el escenario de R-2 y R-3— los números divergirían, y eso es justamente **NP-6**: no hay un usuario de otra cartera para armarlo. **El experimento no refuta R-2: no lo pone a prueba.**

### 8.4 Las ramas de la matriz de salidas que dependen del reloj o de datos que no existen

- **`sinAnular`** (menos de 3 h al viaje, **CTM-10**) y **`soloInformativo`** por viaje en curso (**CTM-11**, **CTM-15**): exigen un traslado vigente **de hoy** a hora ±2 h. No hay ninguno en la denuncia y crearlo depende de 8.1. Se verificó la rama contraria: con 25/08/2026 el backend devuelve `horasAlViaje: 133` y habilita **las tres** salidas — que es **CTM-09** pasando.
- **`soloInformativo`** por facturable (**CTM-12**, **CTM-20**): ningún traslado del paciente tiene `id_estado_logistica_ida ∈ {4,5,8}` ni monto. Sin el dato, y sin fabricarlo por SQL, el caso no se ejecuta.
- **Transporte público** (**NP-4**, **R-8**, **EST-08**): no hay traslado de TP en la denuncia y crearlo depende de 8.1. Es el candidato más probable para la divergencia que EXP-B2 describe.
- **Agencia informada = true** (**NP-3**): `agenciaInformada: false` en el payload y sin flujo de aplicación que lo produzca, tal como estaba declarado. **Se confirma NP-3 como correctamente declarado** — y ver EXP-03, que lo vuelve secundario.
- **Tanda de rehabilitación** (**CTM-08**, **C-13**): la pestaña «Turnos Rehabilitación» existe en la denuncia pero no se recorrió; depende de 8.1.
- **Perfiles 3, 9 y 10** (**NP-5**, **EST-04**, **R-22**): sin usuarios, tal como estaba declarado. Todo lo certificado con `tramitador.supervisor` vale para **jefe de siniestros**, no para supervisor ni gerente.
- **El gate del servidor** (**GST-\***, **RF-4.1** a **RF-4.4**): se probaron los endpoints de autorización, no los de alta y programación de turnos. `POST turnos/crear` y `PATCH programar-turno` no se invocaron: sondearlos con ids reales habría escrito o intentado escribir sobre datos ajenos.

### 8.5 TEST

**No aplica.** Se trabajó sólo en DEV, según la instrucción y **NP-1**: en TEST `wsturnos` no está desplegado y los cinco endpoints del circuito devuelven 404.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026*

# Hallazgo — El circuito del duplicado saltea a Auditoría Médica

**Autor:** Vanesa Burman — QA
**Fecha:** 24/08/2026
**Origen:** pruebas manuales en stage sobre la denuncia 140764/0, y la pregunta de negocio: *«si el turno no está autorizado, no debería aparecerle a logística hasta que audmed autorice»*.
**Severidad:** **BLOQUEANTE.** Logística puede despachar un remis de un traslado que Auditoría Médica rechazó.

---

## Resumen

`aprobar()` del pedido de duplicado pone el traslado en «Solicitado» para logística **sin mirar si Auditoría Médica autorizó, y sin mirar si el traslado está cancelado**. Con eso:

1. Un traslado se vuelve visible para logística **antes** de que audmed lo autorice.
2. Un traslado que audmed **rechazó** —y que quedó Cancelado— **vuelve a aparecer** en la grilla de logística como Solicitado.

Lo segundo es lo grave: **resucita un traslado cancelado.**

---

## Lo que hace producción hoy (y está bien)

Verificado sobre `origin/master`:

| momento | qué pasa con `id_estado_logistica_ida` |
|---|---|
| Alta del turno con traslado | `createNewTraslado` **no lo toca** → queda NULL → **invisible para logística** |
| Audmed **aprueba** el traslado | `cambiarEstadoTraslado` pone **SOLICITADO** si está NULL → visible |
| Audmed **rechaza** | pone el traslado en **Cancelado** y el estado de logística en **CANCELADO** |

**O sea: la hipótesis de negocio ya es el comportamiento de producción.** El traslado no le aparece a logística hasta que audmed autoriza. No hay que construirlo: hay que no romperlo.

---

## Lo que rompe nuestro desarrollo

`AutorizacionTrasladoDuplicadoServiceImpl.aprobar()` hace, sin condiciones previas:

```java
traslado.setIdEstadoLogisticaIda(Constantes.ESTADO_LOGISTICA_SOLICITADO);
...
traslado.setEsDuplicadoAutorizado(Constantes.UNO_LONG_DUPLICADO);
```

**No consulta** `autorizacion.getTrasladoAutorizado()`, ni el estado de la autorización, ni el estado del traslado. Cualquiera de las tres cosas alcanzaba para frenarlo.

## La evidencia, medida en stage

Denuncia 507360 (140764/0), fecha 19/10, después de las pruebas manuales:

| turno | traslado | estado traslado | **logística ida** | marca duplicado | **traslado_autorizado** | estado autorización |
|---|---|---|---|---|---|---|
| 5160674 | 1602698 | 4 Cancelado | 6 Cancelado | NULL | 1 | 2 APROBADA |
| 5160675 | 1602699 | 1 Solicitado | 1 Solicitado | NULL | 1 | 2 APROBADA |
| **5160676** | **1602700** | **4 Cancelado** | **1 Solicitado** | **1** | **NULL** | **3 RECHAZADA** |
| **5160677** | **1602701** | **4 Cancelado** | **1 Solicitado** | **1** | **NULL** | **3 RECHAZADA** |

Las dos últimas filas son el defecto, con las tres marcas juntas:

- **`traslado_autorizado` en NULL** → Auditoría Médica **nunca** autorizó ese traslado.
- **`id_estado_autorizacion = 3`** → audmed lo **rechazó**.
- **`id_estado_traslado = 4`** → el traslado está **Cancelado**.
- **Y aun así `id_estado_logistica_ida = 1`** → **visible y despachable en la grilla de logística.**

Los pedidos de duplicado correspondientes están en estado 2 (APROBADA), pedidos por 1000027:

| id | id_autorizacion | id_traslado | estado |
|---|---|---|---|
| 1 | 2340724 | 1602700 | 2 APROBADA |
| 2 | 2340725 | 1602701 | 2 APROBADA |

### La secuencia que produce el daño

1. El gestor carga el turno y pide la excepción → traslado invisible (NULL). **Correcto.**
2. Auditoría Médica **rechaza** la autorización → traslado Cancelado, logística CANCELADO. **Correcto.**
3. El referente aprueba el **pedido de duplicado** → `aprobar()` pisa el estado de logística con **SOLICITADO** y le pone la marca.
4. Logística ve un traslado **Solicitado, con marca de duplicado autorizado**, de un turno que audmed rechazó.

El paso 3 no sabe nada del paso 2. Son dos autorizaciones distintas, de gente distinta, y ninguna consulta a la otra.

> Esto explica lo que se observó en la prueba: *«pongo la autorización con rechazo, autorizo el segundo traslado del día, y me aparecen tres solicitados»*.

---

## Las cuatro preguntas, respondidas

**¿Qué pasa hoy en producción si audmed rechaza un traslado?** Lo cancela: `id_estado_traslado = Cancelado` y `id_estado_logistica_ida = CANCELADO`. Logística lo ve cancelado, no lo despacha.

**¿Le aparece a logística como solicitado?** No. Si audmed no autorizó, el campo está en NULL y las tres consultas de la grilla filtran `AND t.id_estado_logistica_ida IS NOT NULL`. Es invisible.

**¿Qué alteraciones introduce nuestro desarrollo?** Una, y es la del título: `aprobar()` destapa el traslado por su cuenta, salteando a audmed y pisando una cancelación.

**Si el gestor rechaza, ¿la autorización de audmed queda sin traslado?** Hay que definirlo, y hoy no pasa. `rechazar()` cancela el traslado, pero **no toca `autorizaciones.solicita_traslado` ni `traslado_autorizado`**, así que la autorización le sigue llegando a audmed pidiendo un traslado que ya no existe. Audmed va a autorizar o rechazar un traslado fantasma. Ver la propuesta más abajo.

---

## Cómo arreglarlo

### Lo primero: que `aprobar()` no destape nada

La solución no es agregarle condiciones: es **quitarle la responsabilidad**. `cambiarEstadoTraslado` **ya** pone SOLICITADO cuando audmed aprueba, y sólo si está en NULL. Si `aprobar()` deja de tocar el estado de logística y se limita a poner la marca:

- Referente aprueba el duplicado → `es_duplicado_autorizado = 1`, el estado de logística sigue NULL.
- Audmed aprueba el traslado → pone SOLICITADO. **Recién ahí se vuelve visible.**
- Audmed rechaza → Cancelado, y nadie lo resucita.

Queda el orden correcto sin coordinación entre los dos circuitos, y con una sola condición: **las dos aprobaciones tienen que estar.**

**⚠️ Lo que hay que verificar antes de aplicarlo:** si hay flujos donde el traslado **nunca** pasa por `cambiarEstadoTraslado` —autoaprobación por protocolo, turnos que no requieren autorización médica— entonces con este cambio esos traslados quedarían invisibles **para siempre**. Es el riesgo real de esta corrección y hay que medirlo antes de tocar el código. Si existen esos flujos, la alternativa es que `aprobar()` destape **sólo si** `traslado_autorizado = 1`, y que quede pendiente hasta que audmed resuelva.

### Lo segundo, en cualquier caso: no resucitar un traslado cancelado

Independiente de lo anterior, `aprobar()` no debería tocar un traslado en estado 4 (Cancelado) o 5 (Rechazado). Si el traslado ya no existe operativamente, aprobar la excepción no tiene efecto que aplicar: corresponde dejar el pedido resuelto y registrar que el traslado ya no estaba.

### Lo tercero: el rechazo del gestor y la autorización de audmed

Definición de negocio. Si el gestor rechaza el pedido y el traslado se cancela, la autorización que le llega a audmed debería reflejar que **ya no hay traslado que autorizar**. Hoy no lo refleja.

---

## Hallazgos secundarios de la misma prueba

Salieron de la misma sesión y están sin resolver:

1. **La card del gestor no se puede abrir.** En «Autorización Doble Traslado Resuelta» del home, al hacer clic no muestra el detalle. Hubo que buscar por número de denuncia.
2. **La justificación del gestor no se ve en ningún módulo.** No aparece en el tooltip de logística, ni en el drawer de asignar agencia, ni en verificar traslado. Se guarda en `autorizaciones_traslado_duplicado.justificacion` y no se muestra donde hace falta. Pedido concreto: que quede como observación del traslado, visible en todos los módulos.
3. **La marca no aparece en el traslado original**, sólo en el nuevo.
4. **Las observaciones del referente al aprobar tampoco se ven** en logística.

Los cuatro son de visibilidad de información, no de integridad de datos. Ninguno bloquea, pero el 2 afecta directamente a quien tiene que decidir con esa información.

---

## Qué probar para confirmarlo

Sobre una denuncia limpia, en este orden exacto:

1. Cargar un turno con traslado (queda invisible para logística: verificar `id_estado_logistica_ida` NULL).
2. Pedir la excepción de duplicado con el gestor sin permiso.
3. **Que audmed RECHACE la autorización del turno.** Verificar: traslado Cancelado, logística CANCELADO.
4. **Que el referente APRUEBE el pedido de duplicado.**
5. Mirar la grilla de logística.

**Hoy:** el traslado reaparece como Solicitado con la marca de duplicado autorizado, aunque esté cancelado y rechazado por audmed.
**Esperado:** no reaparece.

---

*Generado por Vanesa Burman — QA · 24/08/2026*

## Context

El circuito atraviesa **cinco servicios** con stacks distintos, y esa heterogeneidad condiciona casi todas las decisiones de abajo:

| Servicio | Stack | Rol en el circuito |
|---|---|---|
| `wsturnos` | Java 11, **Spring Boot 2.1.2 (EOL)**, `javax.*`, JUnit 4, sin Lombok en entidades | La tabla del pedido, la máquina de estados, los cinco endpoints y el gate |
| `wslogistica` | **Spring Boot 3.3.13**, `jakarta.*` | Decide qué salidas están habilitadas; cancela por motivo 16 |
| `wstraslados` | Spring Boot 2.1.2 | El circuito de cancelación que ya existía, reutilizado |
| `tramitadores` | React, JS **sin** RTK Query | Bloque de conflicto, grilla, drawer de resolución, dos cards |
| `logistica` | React + TypeScript | La marca del duplicado autorizado en la grilla |

Base **MariaDB 10.5**, esquema `cs`. Tablas grandes en juego: `turnos` (~4,4M), `traslados` (~1,47M).

> **Fuente de verdad funcional:** el PRD de este mismo change. El **detalle técnico exhaustivo** —modelo de datos, contratos de API, la matriz completa de salidas, el inventario de artefactos y las discrepancias detectadas entre PRD y código— vive en `SDD-traslados-duplicados-autorizacion.md`. Este documento registra sólo las **decisiones** y por qué se tomaron.
>
> **Evidencia de campo:** la carpeta `analisis/` contiene la evaluación de UI del drawer con capturas, los pools de datos de DEV y de TEST con su guion de prueba y su rollback, y la verificación de las correcciones en DEV. Es lo que respalda las decisiones de esta sección y los defectos abiertos.

## Goals / Non-Goals

**Goals**

- Que el segundo traslado del mismo día requiera una **decisión explícita** de alguien con autoridad, registrada con quién, cuándo y por qué.
- Que el gate **no dependa del frontend**.
- Que logística **no vea** lo que no está autorizado, y **vea marcado** lo que sí.
- Que el resultado **vuelva** a quien lo pidió.

**Non-Goals**

- **Solicitudes genéricas (SG)**: descartado a favor del patrón de **Cirugías**, que es el circuito de aprobación que el sistema ya tiene.
- **Doble instancia de autorización**: existe modelada en `autorizaciones` (estado 4 + segundo autorizante) y tiene **cero usos en 2026**. No se implementa.
- **Retroactividad**: no se toca ninguno de los 2.156 casos ya registrados.
- **El 68% de anulaciones sin motivo específico**: es un problema de calidad de datos de logística, anterior a este change.

## Decisions

### D1 — La llave de visibilidad es `id_estado_logistica_ida`, no el estado del traslado

**Decisión.** Un traslado pendiente de autorización se crea con el estado de logística **nulo** y **no** pasa a «Solicitado».

**Por qué.** Se verificó sobre el stored procedure del listado del sector: **no filtra por estado de traslado en ningún momento**. Si el traslado pendiente bajara como «Solicitado», logística lo vería, vería dos traslados el mismo día y cancelaría uno — exactamente el ruido que el circuito viene a evitar. Esto corrige la primera versión de la propuesta, que sí lo pasaba a Solicitado.

**Consecuencia buscada.** Quedan **dos redes independientes**: el estado del traslado es lo que ve el gestor, el estado de logística nulo es lo que lo mantiene fuera de la grilla. Si alguien toca el estado del traslado por error, el traslado sigue invisible para el sector.

### D2 — El backend decide qué salidas están habilitadas; el front sólo renderiza

**Decisión.** `wslogistica` devuelve, por cada conflicto, si se puede anular, si se puede guardar sin traslado y si requiere autorización. El frontend no evalúa la política.

**Por qué.** La política de qué se puede anular depende del estado operativo real —si el viaje ya empezó, si a la agencia ya se le avisó, si hay monto cargado, si un tramo ya es facturable— y va a cambiar. Con la decisión en el backend, cambiarla no toca el frontend.

**Alternativa descartada.** Que el front evalúe el estado del traslado. Habría duplicado la regla en dos lenguajes y garantizado que se desincronicen.

### D3 — El pedido se registra dentro de la transacción que crea el turno

**Decisión.** El pedido se registra **dentro de `createTurno`**, en la misma transacción, asociado al traslado **recién creado**, con `rollbackFor = Exception.class`.

**Por qué.** Es la corrección del defecto más profundo que tuvo el circuito. El pedido se registraba **antes** de que el traslado nuevo existiera —el wizard pide la autorización en el paso 2 de 3— y en un alta no hay `idAutorizacion` todavía, así que quedaba asociado al traslado **preexistente**. Al aprobar, se marcaba y se liberaba el traslado **viejo** mientras el nuevo no recibía nada.

**Efectos colaterales que cierra la misma decisión:** el transporte público pasa a recibir la marca (su entidad no mapeaba el campo), y dejan de quedar pedidos huérfanos cuando la creación del turno falla. Sin `rollbackFor = Exception.class` una excepción verificada no revertiría nada.

### D4 — No hay borradores del pedido

**Decisión.** El pedido existe sólo cuando el turno se guarda. No se persiste nada mientras el gestor está en el wizard.

**Por qué.** Decidido con la líder técnica: el proceso de creación del turno se puede abandonar a mitad de camino, y un borrador dejaría pedidos sin turno que alguien tendría que limpiar o resolver. Si el proceso falla, no queda rastro — que es el comportamiento correcto mientras no exista una necesidad concreta de retomar un pedido a medias.

### D5 — La anulación reutiliza el circuito de cancelación existente

**Decisión.** Anular el preexistente llama al circuito de `wstraslados` que ya usa el drawer de cancelar traslado, que cancela ida, vuelta y transporte público en una única transacción.

**Por qué.** Ese camino ya resuelve la parte difícil —los tres tipos de tramo, la facturabilidad, el aviso a la agencia— y está en producción. Escribir uno nuevo habría duplicado la regla de qué se puede cancelar.

**Lo que sí hubo que cambiar.** El endpoint devolvía un **200 vacío**, así que el frontend daba por cancelado un traslado que podía seguir vigente. Ahora devuelve el resultado real, y el bloque lo muestra **antes** de guardar, con las otras salidas todavía disponibles.

### D6 — Los stored procedures se aplican antes que el código

**Decisión.** Los cuatro SP van a la base **antes** de desplegar el servicio, en horario de bajo tráfico y con backup del cuerpo previo.

**Por qué.** El mapeo por `resultClasses` de Hibernate exige que el SP devuelva **todas** las columnas mapeadas: con el código nuevo contra el SP viejo, la pantalla rompe. Y MariaDB **no tiene** `CREATE OR REPLACE PROCEDURE`, así que el DROP+CREATE deja una ventana en la que el SP no existe — de ahí el horario y el backup.

**Riesgo asumido y ya materializado una vez:** en TEST la base quedó lista **antes** que el código, que es el orden seguro; el inverso es el que rompe.

### D7 — El permiso se resuelve por nombre, nunca por identificador

**Decisión.** `autorizar_traslado_mismo_dia` se resuelve por nombre en el backend y en el frontend, y el script de alta asigna los perfiles con `CROSS JOIN` por nombre.

**Por qué.** El permiso quedó dado de alta con **distinto identificador en DEV y en el script** original. Como ninguna punta lo resuelve por id, la divergencia no afecta el comportamiento — y el circuito no se rompe al pasar de ambiente. La única forma de romperlo es escribir SQL de soporte contra un id fijo, que es justamente lo que no hay que hacer.

### D8 — El pedido que vale es el último

**Decisión.** Un único criterio en todas las puntas: el último pedido del traslado.

**Por qué.** Había **tres criterios distintos** —el repositorio ordenaba por id descendente, el SP joineaba contra el máximo id, y el validador hacía `anyMatch` sobre toda la lista histórica—. Con `anyMatch`, un traslado con un pedido rechazado (el último) y otro aprobado (anterior) **no aparecía en la grilla pero pasaba el validador**: el rechazo se neutralizaba pidiendo la excepción dos veces.

### D9 — Un conflicto en la tanda corta todas las fechas

**Decisión.** Si al menos una fecha de una tanda de rehabilitación tiene conflicto no resuelto, no se programa **ninguna**.

**Por qué.** Confirmado con la líder técnica. Una tanda parcialmente cargada es peor que una tanda que no se cargó: obliga a reconstruir a mano qué entró y qué no, y el gestor no tiene forma de verlo desde la pantalla.

### D10 — Nunca se muestra un id, tampoco en lo que se persiste

**Decisión.** La regla aplica a la pantalla **y** a los textos que quedan guardados: la observación de anulación nombra el turno por **tipo y hora**.

**Por qué.** Un texto persistido lo va a leer alguien meses después, en auditoría, sin acceso a la pantalla que lo generó. Un identificador interno ahí no es información, es una búsqueda pendiente.

## Risks / Trade-offs

| Riesgo | Mitigación |
|---|---|
| **El frontend no se puede desplegar solo.** Sin el backend, el filtro de la grilla se descarta **en silencio** y la pestaña muestra ~4,4M de turnos como pedidos pendientes | Desplegar backend primero, siempre. Es el peor modo de falla del circuito porque no da error |
| **`wsturnos` corre sobre Spring Boot 2.1.2, EOL** | No es deuda que este change introduce, pero condiciona lo que se puede usar (`javax.*`, JUnit 4, sin records). Queda registrado como deuda del servicio, no del change |
| Los endpoints **responden sin autenticación en DEV** y validan el permiso contra un identificador que viaja en el cuerpo del pedido | Hay que **confirmar que en stage y prod quedan detrás del gateway** antes de promover. Es el riesgo abierto de mayor severidad |
| El DROP+CREATE de los SP deja una ventana sin procedimiento | Horario de bajo tráfico y backup del cuerpo previo (D6) |
| Dos personas resolviendo el mismo pedido a la vez podrían pisarse | Decidido con la líder técnica: **no se agrega bloqueo optimista**. El guard de «ya resuelto» cubre el caso secuencial, que es el real; la simultaneidad exacta no se espera en este volumen |

## Migration Plan

1. **Base primero, en cada ambiente**: tabla, columna `es_duplicado_autorizado`, columna `fecha_visto_solicitante`, permiso y asignación por perfil, y los **cuatro SP** (D6).
2. **Backend después**, los tres servicios: `wsturnos`, `wslogistica`, `wstraslados`.
3. **Frontend al final**: `tramitadores` y `logistica`. Nunca antes del backend.
4. **Datos de prueba**: los pools de DEV y de TEST están documentados en `analisis/`, con su guion paso a paso y su rollback completo. El pool de TEST se armó por SQL clonando un turno real, lo que garantiza el dato pero **no ejercita el código**; el de DEV se armó llamando a los endpoints reales, y es el que respalda que aprobar, rechazar y cancelar por motivo 16 funcionan de verdad.

**Rollback.** Todo lo escrito en los ambientes de prueba es identificable sin depender de identificadores: las filas del pool llevan `observaciones` que empiezan con `INI-2 POOL TEST`. El SQL de reversión completo está en `analisis/pool-datos-test.md` y `analisis/pool-datos-dev-B464435.md`.

## Open Questions

- **¿El supervisor entra o no?** El script marca ese perfil como «pendiente de confirmar». El gerente de siniestros tiene el permiso y ve la pestaña, pero no la card de pendientes — hay que cerrar si esa asimetría es la buscada.
- **¿Los endpoints quedan detrás del gateway en stage y prod?** Sin confirmarlo, el permiso es evitable pasando el identificador de otra persona en el cuerpo del pedido.

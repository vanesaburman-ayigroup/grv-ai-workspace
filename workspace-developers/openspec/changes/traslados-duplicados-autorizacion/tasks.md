> **Estado al 18/08/2026 (noche).** El circuito está **completo y mergeado en `develop`** (21 MRs, ninguna abierta), **operativo en DEV** y ya **desplegado y verificado en TEST** —base, SPs, pool de datos y los cinco servicios—. Lo que queda es stage, producción y los defectos abiertos de abajo. Ticket **INI-2** (triage inbox, no Jira).

## 1. Base de datos — esquema y permiso

- [x] 1.1 `CREATE TABLE cs.autorizaciones_traslado_duplicado` con FK a `autorizaciones` y a `traslados`, y el estado del pedido (pendiente / aprobada / rechazada)
- [x] 1.2 `ALTER TABLE cs.traslados ADD COLUMN es_duplicado_autorizado` — la marca que evita que logística lo cancele
- [x] 1.3 `ALTER TABLE cs.autorizaciones_traslado_duplicado ADD COLUMN fecha_visto_solicitante` — el apagado de la card del solicitante
- [x] 1.4 Alta del permiso `autorizar_traslado_mismo_dia` y asignación por perfil resuelta **por nombre** con `CROSS JOIN`, no por identificador fijo (D7)
- [x] 1.5 Aplicar en **DEV** y verificar
- [x] 1.6 Aplicar en **TEST** y verificar
- [x] 1.7 Aplicado en **STAGE** (19/08). Dos desvíos respecto del script, los dos sin consecuencia funcional: el permiso quedó con **id 109** porque en stage el 101 ya lo ocupa `cem_filtro_operador` —da igual, se resuelve por nombre (D7)— y los cuatro perfiles se resolvieron **por nombre** en lugar de por id. La tabla quedó **sin la FK a transporte público**: esa tabla es **MyISAM** en stage (InnoDB en TEST y en producción) y MyISAM no soporta claves foráneas; la columna y su índice sí están
- [ ] 1.8 Aplicar en **PROD**

## 2. Base de datos — stored procedures (van ANTES del código, D6)

- [x] 2.1 Reemplazar los **cuatro SP** del listado de turnos para que expongan los datos del pedido y soporten el filtro de pendientes
- [x] 2.2 Verificar que cada SP devuelve **todas** las columnas que mapea `resultClasses` — con el código nuevo contra el SP viejo la pantalla rompe
- [x] 2.3 Aplicar en DEV, con backup del cuerpo previo (MariaDB no tiene `CREATE OR REPLACE PROCEDURE`)
- [x] 2.4 Aplicar en TEST, con backup y en horario de bajo tráfico; verificado a nivel base (777 turnos, 530.027 traslados de remis)
- [x] 2.5a Aplicados en **STAGE** los **cuatro** SP (el del listado de turnos y los tres del listado de logística), con backup del cuerpo previo de cada uno en `sql/backups/`. Quedaron con `DEFINER=devgrv@%` en lugar de `admin@%` porque la conexión no tiene privilegio `SUPER`: se verificó que ejecutan igual
- [ ] 2.5b Aplicar en **PROD**, siempre antes del despliegue del servicio

## 3. `wsturnos` — el circuito

- [x] 3.1 Entidad, repositorio y enum de estados del pedido
- [x] 3.2 Servicio con la máquina de estados: `pedir`, `resolver`, `aprobar`, `rechazar` y la auto-aprobación de quien tiene el permiso
- [x] 3.3 Guard de idempotencia: un pedido resuelto no se vuelve a resolver, y el segundo que lo abra recibe un aviso con quién resolvió y cuándo
- [x] 3.4 `aprobar()` asigna el estado de logística, el del tramo de vuelta cuando el viaje es de ida y vuelta, y enciende la marca de duplicado autorizado
- [x] 3.5 `rechazar()` cancela con **motivo 16** e incluye el dictamen en la observación
- [x] 3.6 Los cinco endpoints del circuito: pedidos pendientes, mis resueltos, pedir, resolver y marcar vistos
- [x] 3.7 **Registrar el pedido dentro de `createTurno`**, en la misma transacción y contra el traslado recién creado, con `rollbackFor = Exception.class` (D3)
- [x] 3.8 Unificar el criterio del **último pedido** en las tres puntas: repositorio, SP y validador (D8)
- [ ] 3.9 Validar el **dictamen obligatorio al rechazar en el backend** — hoy la obligatoriedad vive sólo en la validación del formulario, y una llamada directa rechaza sin dictamen

## 4. `wsturnos` — el gate server-side

- [x] 4.1 Validador del duplicado: rechaza sin motivo ni pedido, acepta motivo declarado / pendiente / aprobado, y **rechaza explícitamente el pedido rechazado**
- [x] 4.2 Mapeo a **409 CONFLICT** en el `GlobalExceptionHandler`, con mensaje explicativo
- [x] 4.3 Invocarlo desde el alta y desde la programación de turno
- [x] 4.4 Que `generar-autorizacion` no acepte la intención declarada en el request, porque por ese camino no se registra ningún pedido
- [ ] 4.5 Invocarlo desde **`PUT /turnos/editar`** — hoy no lo invoca, y sí invoca SE-214. **Tampoco está en stage**: vive en `TurnosController`, mezclado con SE-268 y SE-273
- [ ] 4.6 Invocarlo desde la **programación en tanda de rehabilitación**, cortando **todas** las fechas si alguna tiene conflicto (D9) — hoy la tanda esquiva el gate
- [ ] 4.7 Detectar los duplicados **dentro de la misma operación**, no sólo contra los traslados ya persistidos

## 5. `wslogistica` — salidas y cancelación

- [x] 5.1 Endpoint de conflictos del mismo día: devuelve el traslado preexistente con su estado operativo y **qué salidas están habilitadas** (D2)
- [x] 5.2 Matriz de salidas por estado operativo: viaje en curso, realizado, con monto cargado, tramo facturable, agencia ya informada, ida realizada con vuelta pendiente
- [x] 5.3 Cancelación por motivo 16 al rechazar
- [ ] 5.4 Resolver la asimetría de **transporte público** en el conteo de traslados vigentes en la fecha
- [ ] 5.5 Enviar el nombre del autorizante para que el tooltip de la grilla pueda nombrarlo — hoy el backend no lo manda
- [ ] 5.6 Eliminar (o reescribir con el criterio de D10) la constante de observación de anulación que nombra el traslado por su número: **no tiene ningún llamador**, pero cualquiera que la lea va a creer que ese es el texto que se guarda

## 6. `wstraslados` — la anulación del preexistente

- [x] 6.1 Reutilizar el circuito de cancelación existente, que cancela ida, vuelta y transporte público en una sola transacción (D5)
- [x] 6.2 Que `cancelar-por-turno` devuelva el **resultado real** en lugar de un 200 vacío

## 7. `tramitadores` — bloque de conflicto y resolución

- [x] 7.1 Bloque de conflicto en el wizard de nuevo turno, con el traslado identificado por sus datos operativos y **nunca** por su identificador (D10)
- [x] 7.2 Las tres salidas excluyentes, habilitadas por lo que responde el backend
- [ ] 7.3 Exponer **todos** los conflictos de la fecha y aplicar la salida elegida sobre todos — antes sólo se resolvía el primero y el resto quedaba en pie. **Desmarcada el 19/08 por la revisión de QA:** estaba en `[x]` y la evidencia de campo del **mismo día** la desmiente. `useConflictoTraslado.js:44` sigue haciendo `const primerConflicto = fechasConConflicto[0]?.traslados?.[0] ?? null`, y en DEV la API devolvió **tres** traslados en conflicto para una fecha mientras el bloque resolvía **uno**. Quien elige «anular ese traslado» anula el primero y **deja los otros dos duplicados en pie**, sin enterarse de que existen. Es el hallazgo EST-15
- [x] 7.4 Dirigir el pedido de autorización al traslado que efectivamente la requiere
- [x] 7.5 Mostrar el resultado real de la anulación antes de guardar, con las otras salidas todavía disponibles
- [x] 7.6 Observación de anulación que nombra el turno por **tipo y hora**, con el usuario y la fecha, sin escapado HTML (`interpolation: { escapeValue: false }`) y recalculada cuando llega el conflicto
- [x] 7.7 Pestaña y grilla de pedidos pendientes, con solicitante, fecha y justificación, y las acciones de ver detalle, gestionar autorización y ver información de traslado
- [x] 7.8 Drawer de resolución con dictamen
- [x] 7.9 Card de pedidos **pendientes** para quien autoriza
- [x] 7.10 Card de resultados **resueltos** para quien pidió, con marcado de vistos idempotente
- [x] 7.11 Que las pestañas que no corresponden al perfil **no se rendericen vacías** — la librería crea un `<Tab>` por elemento, así que el título nulo no ocultaba nada
- [x] 7.12 Nomenclatura unificada en las cards y las pestañas de ambos perfiles: «Autorización Doble Traslado Pendiente» / «Autorización Doble Traslado Resuelta», en los dos idiomas
- [x] 7.13 Resetear el formulario cuando cambia el turno objetivo, para que no arrastre datos del anterior
- [ ] 7.14 Renderizar el select de motivo **suelto** cuando el endpoint de conflictos falla: hoy el bloque desaparece y con él la única forma de declarar el motivo, y el backend rechaza al guardar. El hook ya expone el flag de error
- [ ] 7.15 Corregir el copy contradictorio: «Estado del traslado: SOLICITADO» junto a «el viaje ya empezó, así que no hay traslado duplicado que evitar»
- [ ] 7.16 Responsive: a 390 px «Atrás» y «Cancelar» se superponen ~50 px, y cruzar los ~900 px remonta el drawer y borra lo cargado

## 8. `logistica` — la marca del duplicado autorizado

- [x] 8.1 Franja, ícono con tooltip y entrada en la leyenda al pie
- [x] 8.2 Que la marca **convivan** con la señal de «requiere revisión» sin taparla, con iconos distintos y `alt` traducido

## 9. Pruebas

- [x] 9.1 Tests de la matriz de salidas del conflicto (18), del validador del gate (9), del enum de estados (5), del filtro de la grilla (4), del parseo de las JPQL (3), del recorte de la observación (5) y de la cancelación por tramo (7)
- [x] 9.2 Pool de datos en **DEV** sobre la denuncia B464435, armado **llamando a los endpoints reales** — es lo que respalda que aprobar, rechazar y cancelar por motivo 16 funcionan
- [x] 9.3 Pool de datos en **TEST** sobre la denuncia 999031, armado por SQL clonando un turno real: cinco turnos con traslado y tres pedidos (pendiente, aprobado, rechazado)
- [x] 9.4 Alinear los perfiles de los usuarios de prueba de TEST con los de DEV
- [ ] 9.5 **Tests de la máquina de estados**, que hoy no tiene ninguno: `pedir`, `resolver`, la auto-aprobación, el guard de «ya resuelto», `aprobar()` —donde se enciende la marca— y `rechazar()` —donde se fija el motivo 16
- [ ] 9.6 Tests de los endpoints: contrato, códigos y validación. Hoy son cero
- [ ] 9.7 Test del mapeo a 409, que hoy se verifica sólo a mano
- [ ] 9.8 Ejecutar el JPQL de conteo de traslados vigentes contra una base real: está mockeado en los nueve tests del validador, así que **nunca se ejecuta**
- [ ] 9.9 Correr el guion de prueba completo en TEST, **cuando el código esté desplegado**

## 10. Despliegue

- [x] 10.1 DEV: los cinco servicios desplegados y el circuito verificado end-to-end
- [x] 10.2 TEST: base y SP aplicados; los cinco servicios promovidos a `release`
- [x] 10.3 **Investigado y resuelto (18/08 noche).** **El pipeline no estaba «sin correr»: estaba fallando.** El webhook disparó las tres veces; `wslogistica` y `wstraslados` desplegaron bien y **`wsturnos` falló en la fase BUILD** porque `release` **no compilaba**: `crearCirugia()` llamaba a `existsByAutorizacionIdAutorizacion` y esa declaración no estaba en `CirugiaRepository` de esa rama. Nada que ver con INI-2 — es **GRV-2189** (cirugías duplicadas), cuyo merge se revirtió el 13/08 **sólo en `release`**; el 18/08 a las 11:01 el commit «fixeo conflictos» volvió a traer la llamada sin la declaración. La promoción de INI-2 de las 17:47 llegó a una rama **ya rota** (el fallo de las 11:03 lo prueba). Repuesta la línea en la MR !850, `release` compila (`mvn compile`: BUILD SUCCESS, 384 fuentes) y **TEST quedó desplegado**. Verificado de punta a punta: los endpoints responden y el filtro de la grilla devuelve **1 fila** —el turno pendiente del pool— en lugar de las 4.412.517 de la grilla completa
- [ ] 10.4 **Confirmar que los endpoints quedan detrás del gateway en STAGE y PROD.** Hoy responden sin autenticación en DEV y validan el permiso contra un identificador que viaja en el cuerpo del pedido — es el riesgo abierto de mayor severidad
- [x] 10.5 Promovido a **STAGE** (19/08): base y SP primero, los tres backend después y el front al final. Cinco MRs mergeadas —wsturnos !851, wslogistica !643, wstraslados !308, tramitadores !1813, logistica !452—. **No fue `release → stage`**: stage estaba 149 commits atrás y sólo el circuito estaba confirmado, así que se separó con cherry-pick de los commits de INI-2 (21 en tramitadores, 10 en wslogistica, 8 en wsturnos, 3 en logistica, 1 en wstraslados), dejando afuera once desarrollos ajenos. Ver §15.6 del SDD
- [ ] 10.5b **Verificar en STAGE cuando el ambiente esté encendido.** Al promover, stage no respondía (`HTTP 000` incluso en `actuator/health`), así que el despliegue no se pudo comprobar
- [ ] 10.6 Promover a PROD por Jenkins, en el mismo orden
- [ ] 10.7 Cerrar la pregunta abierta del **supervisor**: el script lo marca como «pendiente de confirmar»

## 11. Documentación

- [x] 11.1 PRD y SDD del change
- [x] 11.2 Estructura OpenSpec: `proposal.md`, `tasks.md`, `design.md` y los deltas de spec de las cinco capabilities
- [x] 11.3 Evidencia de campo consolidada en `analisis/`: evaluación de UI con capturas, pools de DEV y TEST con guion y rollback, y verificación de correcciones en DEV
- [ ] 11.4 Runbook post-fix en `docs/runbooks/INI-2.md`, para que `/similar-cases` encuentre el precedente la próxima vez

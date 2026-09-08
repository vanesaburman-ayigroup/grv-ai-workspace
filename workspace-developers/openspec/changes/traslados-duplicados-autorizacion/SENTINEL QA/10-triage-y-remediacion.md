# Triage y plan de remediación — traslados duplicados (INI-2)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Fecha** | 19/08/2026 |
| **Entrada** | Los hallazgos de las siete fuentes de la revisión Sentinel |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |

---

## Cómo leer esto

La revisión produjo del orden de **60 hallazgos**. Tratarlos como una lista plana garantiza
que no se haga ninguno. Están agrupados en **cinco grupos con destino distinto**, y sólo
los dos primeros bloquean la promoción.

| Grupo | Qué es | Quién lo resuelve | ¿Bloquea? |
|---|---|---|---|
| **A** | Defectos que rompen un requisito o dejan datos inconsistentes | Desarrollo | **Sí — STAGE y PROD** |
| **B** | Decisiones de negocio sin tomar | Negocio / Producto | **Sí — la certificación** |
| **C** | Arreglos baratos de alto retorno | Desarrollo | No, pero hacerlos ya |
| **D** | Documentación desactualizada respecto del código | Quien mantiene el change | No |
| **E** | Deuda registrada, que no bloquea | Desarrollo, cuando haya margen | No |

**Recomendación de secuencia:** cerrar **B** primero. Son cinco preguntas, no cuestan
desarrollo, y **dos de ellas cambian qué hay que programar en A**. Arrancar por A sin cerrar
B es programar sobre arena.

---

---

## ⚠️ Agregado el 21/08/2026 — dos bloqueantes nuevos, del frontend

Salieron del recorrido completo del circuito en TEST (25 hallazgos, ver
`08-manual-usuario/`). **Los dos tienen la misma causa raíz**, y es una sola: **el front y el
backend no se pusieron de acuerdo sobre cómo se pide la autorización en un alta.**

### La causa raíz, en tres líneas

El backend resolvió el alta con un camino propio —`registrarPedidoDelAlta`, que registra el
pedido **dentro de la misma transacción que crea el turno**— y lo activa con dos campos en el
cuerpo de `turnos/crear`:

```
justificacionTrasladoDuplicado
idSolicitanteTrasladoDuplicado
```

**El front no conoce ninguno de los dos: cero ocurrencias en todo el repositorio de
`tramitadores` (`origin/release`).** Y sigue llamando al endpoint viejo,
`pedir-traslado-duplicado`, que en un alta no puede funcionar.

### A6 · «Enviar el pedido» no registra nada y deja al gestor sin salida · **BLOQUEANTE**

`MAN-G-01`. El botón llama a `pedir-traslado-duplicado`, que **exige `idAutorizacion`** — y en
un alta esa autorización todavía no existe. El backend responde **400 «must not be null»**
(verificado con `curl`). La pantalla muestra «No se pudo registrar el pedido» **y además borra
los tres radios de salida y deshabilita «Siguiente»**: no hay forma de continuar ni de elegir
otra opción. Hay que cancelar el wizard y perder lo cargado.

Reproducido **2 de 2 veces**, con el ambiente sondeado sano (6/6 en 200) antes y después.

> Es exactamente el defecto que el javadoc de `AutorizacionesController` ya declaraba:
> *«Alcance: edición y programación únicamente. En un alta este endpoint no sirve y nunca
> sirvió… **FIX PENDIENTE DEL LADO DEL FRONT, no de acá**»*.

### A7 · «Confirmar» falla en silencio y el turno no se crea · **BLOQUEANTE**

`MAN-G-02`. Con la salida «Pedir autorización» elegida, el front postea `turnos/crear`
**sin los dos campos**. El backend ve un segundo traslado del mismo día sin motivo ni pedido y
hace lo correcto: **409 CONFLICT**. Pero el wizard **no muestra ningún mensaje** y se queda en
el paso 3. **El gestor cree que guardó.**

Verificado en base: no se creó el turno ni el pedido.

**Es el peor de los dos, y por eso va primero.** Un error visible es molesto pero seguro: el
gestor sabe que no guardó y reintenta. Un 409 que la pantalla se come es otra cosa — el gestor
sigue trabajando convencido de que el turno quedó cargado, el paciente no tiene turno, nadie
pidió la autorización, y **nadie se entera hasta el día del traslado**. Es el mismo modo de
falla que **EST-03**, pero disparado por un defecto y no por una demora.

### Por qué bloquean

**Porque la tercera salida no se puede usar.** «Pedir autorización» es la razón de ser del
desarrollo: el circuito existe para que un gestor **sin** permiso pueda pedir la excepción.
Hoy, desde el alta, no funciona por ninguna de las dos vías.

### El arreglo, y es chico

**Todo del frontend. Cero backend.** El camino correcto ya está construido, probado y
desplegado:

1. **No llamar a `pedir-traslado-duplicado` en un alta.** Ese endpoint es para edición y
   programación, donde la autorización sí existe.
2. **Mandar `justificacionTrasladoDuplicado` e `idSolicitanteTrasladoDuplicado` en el payload
   de `turnos/crear`.** El backend registra el pedido solo, en la misma transacción, apuntando
   al traslado nuevo — y si el gestor tiene el permiso, lo auto-aprueba.
3. **Mostrar el 409** cuando venga, en lugar de comérselo.

El backend ya valida que la justificación no venga vacía
(`tieneIntencionDePedidoDuplicado()`) y corta el alta si falta el solicitante, así que no hace
falta duplicar esas validaciones en el front.

### Y una corrección a un hallazgo previo

**EST-15 no se reproduce.** El bloque informa correctamente los **tres** conflictos: el aviso
dice «El paciente tiene 3 traslados vigentes ese día», lista los tres, pluraliza la salida de
anulación con la cantidad real y los nombra a los tres en la observación. La tarea **7.3
—desmarcada el 19/08— habría que volver a marcarla**: la evidencia en que me basé era del
18/08 y el front cambió desde entonces. **Queda pendiente** confirmar que la anulación
efectivamente alcance a los tres, que no se ejecutó por ser traslados del pool compartido.

---

## Grupo A — Bloquean la promoción · 5 ítems

| # | Hallazgo | Qué rompe | Costo |
|---|---|---|---|
| **A1** | **La identidad se resuelve del cuerpo del pedido, no del token** (REV-04 · R-1). Los endpoints de `wsturnos` responden sin autenticación, y `pedir()` decide la auto-aprobación con el `idSolicitante` que viaja en el body. Mandando el id de un supervisor, el pedido **nace aprobado a su nombre** y no deja ningún pendiente que alguien revise | Hace **evitable** el permiso, y con él el circuito entero | Medio | DEJARLO COMO ESTÁ, WSTURNOS NO PUEDE TENER TOKEN JWT AUN
| **A2** | **El rechazo se neutraliza volviendo a pedir** (API-02). `tienePedidoDeExcepcion()` usa `anyMatch` sobre toda la lista histórica en lugar del último pedido: basta un pedido *pendiente* posterior a un rechazo | **RF-4.3**, que el PRD justifica así: *«si esto no valiera, alcanzaría con pedir la excepción y que te la nieguen para cargar el traslado igual»*. Hoy alcanza | **Bajo** | 
| **A3** | **Un pedido se aprueba aunque su traslado no exista** (REV-02). `aprobar()` usa `.ifPresent()` y devuelve `aprobada(...)` igual, sin log. Queda APROBADA sin estado de logística ni marca, en un estado **indistinguible del correcto** desde cualquier pantalla | La aprobación deja de ser confiable | **Bajo** | 
| **A4** | **El rechazo no comprueba que la cancelación ocurrió** (REV-01). `fetchLogisticaOnCancelacion` devuelve `void`. Si falla sin excepción, el traslado queda **vivo, sin cancelar e invisible para logística** | **RF-3.5**. Ya hay divergencia real en DEV | Medio | 
| **A5** | **El script del permiso colisiona** (VBD-02). Inserta `id_permiso = 101`, ocupado en PROD por `editar_cie10_bloqueado` y en DEV por `log_cirugias`: el espacio de ids **divergió entre ambientes** | La migración falla, o **pisa el permiso de CIE-10** en silencio | **Bajo** | GENERA EL CAMBIO CON EL ID DE PERMISO QUE NECESITE PROD

**A2, A3 y A5 son de costo bajo y cierran dos requisitos incumplidos.** Son el mejor primer
sprint. OK VAMOS CON ESTO AHORA, NO PODEMOS TARDAR MÁS DE HOY6 EN ENTREGAR, ASI QUE LA SOLUCION TIENE QUE SER SIMPLE, Y POR FAVOR VERIFICAR QUE NO ROMPAMOS ABSOLUTAMENTE NINGUN CIRCUITO

---

## Grupo B — Decisiones de negocio · 5 preguntas

Ninguna cuesta desarrollo. **Dos cambian el alcance de A y C.**

| # | Pregunta | Por qué bloquea | Quién |
|---|---|---|---|
| **B1** | **¿Cuándo se retira el motivo autodeclarativo?** Hoy sigue habilitando el duplicado **sin permiso ni pedido** (EST-02), así que los ~2.156 casos anuales se pueden seguir generando igual | El circuito no cierra el agujero que vino a cerrar. Y define si A1 alcanza | Producto | NO SE, DEJEMOSLO ASI
| **B2** | **¿Qué pasa con un pedido que nadie resuelve?** No hay SLA, vencimiento ni alerta (EST-03). Es una **regresión con impacto al asegurado**: hoy se paga un viaje de más; con el circuito **el paciente no viaja** y se descubre el día del turno | Define si hay que construir un vencimiento, y eso es desarrollo nuevo | Negocio + Logística | ETAPA 2
| **B3** | **¿Cómo se va a medir si el circuito funciona?** El rechazo cancela con el motivo 16, el mismo que el sector ya usa a mano ~130 veces por mes, así que **no se pueden separar**. El PRD justifica el proyecto con la imposibilidad de medir, y el circuito la reproduce | Sin esto no se puede responder «¿bajaron los 2.156 casos?» | Negocio | NO HACE FALTA MEDIR HOY, ETAPA 2
| **B4** | **¿El perfil supervisor autoriza?** DEV **ya se lo asignó de hecho** (perfiles 2, 3, 9 y 10) mientras el script dice «PENDIENTE DE CONFIRMAR» y cuatro documentos lo declaran distinto (EST-04) | Es el actor de C-04 o C-05, casos de resultado **opuesto**. Y falta el usuario de prueba | Negocio | SUPERVIUSORES, REFERENTES, JEFES
| **B5** | **¿Se muestra el número de turno?** RF-1.2 lo permite y RF-5.1 lo prohíbe | Define si se arregla el código o el requisito | Producto | EL REQUISITO

> **B3 tiene una salida barata.** No hace falta un motivo de anulación nuevo: el conteo por
> estado de `autorizaciones_traslado_duplicado` ya distingue perfectamente los rechazos del
> circuito. Alcanza con exponerlo como métrica — que es la recomendación 7 del propio
> SDD §12.4. ETAPA 2

---

## Grupo C — Arreglos baratos, alto retorno · hacer sin discutir OK A TODOS SIN CEREMONIAS

| # | Arreglo | Costo | Por qué conviene ya |
|---|---|---|---|
| **C1** | Sacar `<skipTests>true</skipTests>` del `pom.xml` de `wslogistica` | **1 línea** | Activa **47 tests ya escritos** que el pipeline no ejecuta. Nada en toda la lista tiene esta relación costo/beneficio |
| **C2** | `@Size(max = 1000)` en los dos DTO de justificación y `length` en el `@Column` (REV-03) | **2 líneas** | Hoy 1.001 caracteres **revierten el alta completa del turno** y el gestor pierde el wizard de tres pasos con un 500 crudo de JDBC |
| **C3** | Cambiar el color y el glifo del ícono de duplicado autorizado (LOG-01) | Bajo | Usa el **mismo naranja `#F29423`** que «Requiere revisión» y un octógono de advertencia: comunica peligro para una excepción **concedida**. Cumple RF-3.4 y trabaja contra su propósito |
| **C4** | `aria-label` en los botones de la grilla de logística (LOG-04) | Bajo | **9 de 9 botones** del `tbody` sin nombre accesible, incluida la acción de **cancelar** |
| **C5** | Manejar `MissingServletRequestParameterException` (API-03) | Bajo | `mis-duplicados-resueltos` sin parámetro devuelve **500** en lugar de 400 |
| **C6** | Documentar en la guía de datos de prueba que **insertar `autorizaciones` por SQL rompe el alta** | Bajo | `id_autorizacion` no es `AUTO_INCREMENT`: lo asigna un `@TableGenerator` sobre `key_generator`. Ocurrió en esta sesión y no lo advierte ningún documento |

**C1 y C2 son tres líneas en total.** Deberían entrar en el próximo commit, sin ceremonia.

---

## Grupo D — Documentación desactualizada · corregir el change

La revisión encontró, **cuatro veces**, que la documentación describe como faltante algo que
ya está hecho. Es el hallazgo de proceso más importante: **`tasks.md`, el PRD y el SDD no son
fuente confiable de alcance**. ARREGLAR LA DOCUMENTACION

| # | Documento dice | Realidad | Corregir |
|---|---|---|---|
| **D1** | PRD §7.1 y SDD §10: huecos **H-1, H-2 y H-3** abiertos (el dictamen no se lee, el gestor nunca se entera, la justificación desaparece) | **Los tres están cerrados.** La pestaña «Autorización Doble Traslado Resuelta» muestra resultado, autorizante por nombre, fecha, **dictamen** y justificación propia | PRD y SDD |
| **D2** | SDD §11 **R-8**: «la marca nunca se escribe para transporte público» | **Está implementado**: `aprobar()` tiene su bloque de transporte público con estado, tramo de vuelta y marca | SDD |
| **D3** | SDD §11 **R-21**: la marca se pierde de la franja **y** del ícono | Sólo de la **franja**. El ícono es aditivo en el build desplegado. Describía un commit anterior | SDD |
| **D4** | `tasks.md` 10.3: el código **no está desplegado en TEST** | **Ya está desplegado y el filtro funciona** (4.412.529 sin filtro → 1 con filtro) | `tasks.md` |
| **D5** | `tasks.md` 7.3 `[x]`: el bloque resuelve **todos** los conflictos | Toma **sólo el primero** (`useConflictoTraslado.js:44`) | `tasks.md` y el código |
| **D6** | PRD §2.2 y §7: «el motivo específico de duplicado (16)» | Es **«Cancelado por alarma repetida»**. El código lo nombra bien; el PRD lo rebautizó | PRD |
| **D7** | Las specs OpenSpec tienen **9 Requirements sin respaldo en el PRD**, **6 sobre tareas sin hacer** | Si se archivan así, las capabilities canónicas **afirman conducta inexistente** | `specs/` |

**D7 es el más importante a futuro**: OpenSpec archiva estos deltas como la especificación
canónica. Si entra con requisitos que el código no cumple, el próximo que lea la spec va a
creer que el sistema hace cosas que no hace.

---

## Grupo E — Deuda registrada, no bloquea 

| # | Deuda | Nota |
|---|---|---|
| **E1** | `resolver()` sin `@Version` (R-7) | RF-2.8 es **probable, no garantizado**. Cerrarlo cuesta un `@Version` en la entidad |
| **E2** | Llamada REST dentro de `@Transactional` (R-10) | Se agrava con A4: la transacción queda tomada esperando a `wslogistica` |
| **E3** | Contador de la card **global**, sin alcance (R-2) | El contador y las filas de la grilla pueden no coincidir |
| **E4** | Los seis resultados de `resolver` viajan en **HTTP 200** (R-9) | `SIN_PERMISO` no es 403, `YA_RESUELTO` no es 409 |
| **E5** | `key_generator` desincronizado en `ID_TURNO` e `ID_TRASLADO` | Vestigial: esas columnas **sí** son `AUTO_INCREMENT`. Decidir si se limpian o si `id_autorizacion` pasa a `AUTO_INCREMENT` |
| **E6** | Spring Boot 2.1.2 **EOL** en `wsturnos`, en producción como `SNAPSHOT` | Preexistente, no lo introduce el change |

---

## Lo transversal, que no es un ítem sino la causa

**La máquina de estados del circuito no tiene un solo test.** Ni `pedir`, ni `resolver`, ni
la auto-aprobación, ni el guard de «ya resuelto», ni `aprobar()` —donde se enciende la
marca—, ni `rechazar()` —donde se fija el motivo—.

**Cuatro de los cinco hallazgos de la revisión de código los habría atrapado un test de
`aprobar()` y uno de `rechazar()`.**

La prioridad 3 del SDD §12.4 ya lo pedía. Es la inversión que evita que la próxima revisión
encuentre lo mismo.

---

## Plan sugerido, en tres pasos

**Paso 1 — esta semana, sin desarrollo.** Cerrar las cinco preguntas del grupo **B** en una
reunión, y corregir el grupo **D** en los documentos del change. Nada de esto compite por
tiempo de desarrollo, y B2 y B3 pueden cambiar el alcance.

**Paso 2 — próximo commit.** El grupo **C** completo: son unas diez líneas y activan 47
tests. Más **A2, A3 y A5**, que son de costo bajo y cierran RF-4.3.

**Paso 3 — antes de promover a STAGE.** **A1** y **A4**, que son los dos de costo medio, más
los tests de `aprobar()` y `rechazar()`. Recién con eso el circuito es promovible.

**No promover a STAGE ni PROD antes del paso 3.** A1 hace evitable el permiso y A5 puede
romper una funcionalidad ajena en producción.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

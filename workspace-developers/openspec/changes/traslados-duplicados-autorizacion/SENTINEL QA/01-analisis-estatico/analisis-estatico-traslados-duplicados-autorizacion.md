# Análisis Estático — `traslados-duplicados-autorizacion`

**Change OpenSpec:** `traslados-duplicados-autorizacion` · Ticket **INI-2**
**Sistema:** SAS de siniestros laborales — Colonia Suiza (ART)
**Artefactos revisados:** `PRD-traslados-duplicados-autorizacion.md`, `proposal.md`, `design.md` (D1–D10), los 5 `specs/*/spec.md`, `tasks.md`, `SDD` §10–§13, `analisis/verificacion-correcciones-dev.md`
**Fecha de revisión:** 18/08/2026
**Revisor:** QE Senior (ISTQB CTFL v4.0 · CTFL-ATT · CT-MAT)
**Total de hallazgos propios:** 23 — 5 BLOQUEANTES · 10 ALTA · 5 MEDIA · 3 BAJA

---

## 0. Alcance de este análisis y qué se toma como contexto

El equipo de desarrollo ya autoauditó su propio código y dejó documentadas **21 discrepancias (D-1..D-21)**, **22 riesgos técnicos (R-1..R-23)** y **4 huecos de trazabilidad (H-1..H-4)** en el SDD, más una verificación de campo en DEV con 10 defectos de UI. **Nada de eso se repite acá como hallazgo propio**: se cita como contexto cuando refuerza o cambia la severidad de un hallazgo nuevo.

Lo que aporta este documento, desde la mirada de QA de dominio:

1. Trazabilidad **RF del PRD → Requirement de spec → Scenario**, en las dos direcciones (RF sin spec y spec sin PRD).
2. Cobertura de las **16 casuísticas C-01..C-16** contra los Scenario.
3. **Testabilidad**: criterios sin umbral, sin predicado verificable o sin dato reproducible desde la aplicación.
4. **Contradicciones entre documentos** (PRD ↔ proposal ↔ design ↔ specs ↔ tasks ↔ evidencia de campo), no PRD ↔ código.
5. **Huecos de máquina de estados** que el PRD no cubre, pensados desde el ciclo de vida real de una denuncia.
6. **Riesgo de negocio con impacto al asegurado** no declarado en ningún documento.
7. **Checklist de datos de prueba** para poder ejecutar las 16 casuísticas.

---

## 1. Matriz de trazabilidad RF → spec → Scenario

Capabilities: **CTM** `conflicto-traslado-mismo-dia` · **ATD** `autorizacion-traslado-duplicado` · **DRS** `devolucion-resultado-solicitante` · **VDL** `visibilidad-duplicado-logistica` · **GST** `gate-servidor-traslado-duplicado`.

| RF | Requirement de spec | Cap. | Scenarios | Cobertura | Observación |
|---|---|---|---|---|---|
| RF-1.1 | Detección del conflicto por traslado vigente en la misma fecha | CTM | 4 | ✅ | El 3.º y 4.º Scenario (región, varios vigentes) **no tienen origen en el PRD** → EST-12, EST-15 |
| RF-1.2 | El conflicto se identifica por datos operativos, nunca por identificadores | CTM | 2 | ⚠️ | «Si a la agencia ya se le avisó» sin criterio declarado ni dato reproducible → EST-11 |
| RF-1.3 | Tres salidas excluyentes decididas por el backend | CTM | 4 | ⚠️ | El DTO expone **cuatro** flags; `puedeDerivarALogistica` no está en ningún documento → EST-16 |
| RF-1.4 | (mismo Requirement) | CTM | 1 | ❌ | La política que «decide el backend» no está declarada en ningún artefacto normativo → EST-05 |
| RF-1.5 | La tanda de rehabilitación informa en cuántas fechas hay conflicto | CTM | 1 | ⚠️ | El corte total de la tanda (D9) vive en `design` y en GST, no en el PRD → EST-14 |
| RF-2.1 | Pedido de autorización con justificación obligatoria | ATD | 2 | ✅ | — |
| RF-2.2 | Quien tiene el permiso resuelve en el acto | ATD | 1 | ⚠️ | Ni justificación ni dictamen obligatorios en este camino → EST-07 |
| RF-2.3 | Caso pendiente de autorización — logística no lo ve | VDL | 1 | ✅ | Cubierto en otra capability; sin referencia cruzada declarada |
| RF-2.4 | Card de pedidos pendientes para quien autoriza | ATD | 3 | ⚠️ | El código agrega una tercera condición (`!isGerente`) que la spec niega explícitamente (contexto D-18/R-22) → EST-04 |
| RF-2.5 | La grilla muestra solicitante, fecha y justificación | ATD | 2 | ⚠️ | «Ver detalle» y «gestionar autorización» sin Scenario propio → EST-23 |
| RF-2.6 | Resolución con dictamen obligatorio al rechazar | ATD | 2 | ⚠️ | La spec exige enforcement **server-side**; `tasks 3.9` está **`[ ]`** → spec ADDED de conducta no implementada |
| RF-2.7 | Un pedido resuelto no se vuelve a resolver | ATD | 2 | ✅ | — |
| RF-2.8 | (mismo Requirement) | ATD | 2 | ✅ | — |
| RF-2.9 | Quien pidió la autorización se entera del resultado + La card se apaga al leer | DRS | 6 | ❌ | El propio PRD §7.1 (H-2) y el SDD §10 declaran que **no existe**. Estado indeterminado → EST-01 |
| RF-2.10 | La card del resultado la ve quien pide, no quien aprueba | DRS | 2 | ⚠️ | Audiencia definida por una capacidad, no por un predicado → EST-19 |
| RF-3.1 | La llave de visibilidad es el estado de logística | VDL | 2 | ✅ | — |
| RF-3.2 | Caso pendiente — logística no lo ve | VDL | 1 | ✅ | — |
| RF-3.3 | Caso aprobado — baja a logística y llega marcado | VDL | 4 | ⚠️ | El Scenario de ida y vuelta no contempla la ida ya realizada → EST-09 |
| RF-3.4 | (mismo Requirement) | VDL | 4 | ❌ | Sin criterio de precedencia visual → sin resultado esperado objetivo → EST-17 |
| RF-3.5 | Caso rechazado — logística nunca se enteró | VDL | 1 | ⚠️ | Es un supuesto, no una garantía → EST-10 |
| RF-3.6 | Caso anular el preexistente — logística sí participa | VDL + CTM | 4 | ⚠️ | Ningún Scenario verifica **qué ve logística** después de la cancelación |
| RF-3.7 | El resultado de la anulación se muestra antes de guardar | CTM | 3 | ✅ | — |
| RF-3.8 | Dos redes independientes | VDL | 1 | ✅ | — |
| RF-4.1 | El backend rechaza el duplicado sin motivo ni pedido | GST | 2 | ✅ | — |
| RF-4.2 | Qué acepta el gate | GST | 4 | ❌ | La spec agrega «motivo declarado **por quien tiene el permiso**», restricción que no está en el PRD ni en el código → EST-02 |
| RF-4.3 | El gate rechaza explícitamente un pedido RECHAZADO | GST | 2 | ⚠️ | No cubre el reintento posterior al rechazo → EST-06 |
| RF-4.4 | Todo endpoint que cree o programe turnos invoca la validación | GST | 3 | ⚠️ | La spec amplía a **edición**, que ni crea ni programa; `tasks 4.5/4.6` **`[ ]`** |
| RF-5.1 | Ningún identificador interno llega a la pantalla | CTM | 1 | ✅ | — |

**RFs sin ningún Requirement de spec: ninguno.** La cobertura nominal es completa; el problema no es de omisión sino de **specs que declaran conducta no implementada** y de **RFs sin criterio verificable**.

### 1.1 Requirements de spec **sin respaldo en el PRD** (spec inventando alcance)

| Requirement / Scenario | Cap. | ¿Está en el PRD? | Riesgo |
|---|---|---|---|
| Scenario «Traslados de regiones distintas no son duplicado» | CTM | **No**, en ningún RF ni casuística | Regla de exclusión de conflicto invisible para negocio → EST-12 |
| Scenario «Varios traslados vigentes en la misma fecha» (se aplican todos) | CTM | **No** (RF-1.1 habla en singular) | El PRD no declara el caso que la evidencia de DEV muestra roto → EST-15 |
| Scenarios «traslado ya realizado» / «viaje en curso es sólo informativo» | CTM | **No** (la matriz de salidas sólo existe en el SDD) | RF-1.4 sin política declarada → EST-05 |
| Requirement «El pedido se registra en la misma transacción que el turno» | ATD | No — es D3 de `design`, decisión técnica | Requisito técnico en un delta funcional; no genera caso de negocio |
| Requirement «Nomenclatura consistente entre las dos caras» (textos literales) | DRS | **No** | Fija copy exacto sin fuente funcional |
| «La marca SHALL aplicarse también a transporte público» | VDL | **No** (PRD §7 sólo declara `traslados.es_duplicado_autorizado`) | Spec ADDED de algo que `tasks 5.4` deja `[ ]` |
| Requirement «Los duplicados dentro de la misma operación también se detectan» | GST | **No** | `tasks 4.7` `[ ]` — spec ADDED de conducta inexistente |
| «Alcanza explícitamente a la **edición** de turno» | GST | **No** (RF-4.4 dice «cree o programe») | `tasks 4.5` `[ ]` |
| «La obligatoriedad del dictamen SHALL estar garantizada en el backend» | ATD | **No** (RF-2.6 no dice dónde) | `tasks 3.9` `[ ]` (contexto D-4) |

> **Patrón transversal.** Los cinco deltas de spec están escritos en modo **normativo aspiracional**: describen el circuito que se quiso, no el que está en `develop`. Al menos **6 Requirements/Scenarios corresponden a tareas abiertas en `tasks.md`**. Si este change se archiva, las capabilities canónicas de `openspec/specs/` quedan afirmando conducta que el sistema no tiene, y toda auditoría posterior parte de una base falsa.

---

## 2. Cobertura de las casuísticas C-01 a C-16

| # | Casuística | Scenario que la cubre | Estado |
|---|---|---|---|
| C-01 | Paciente sin traslado ese día | *(sólo el inverso: «un traslado cancelado no genera conflicto»)* | ⚠️ **Parcial** — no hay Scenario del camino feliz sin traslado previo |
| C-02 | Anular el preexistente | CTM «La anulación alcanza todos los tramos» + VDL «Se cancelan todos los tramos» | ⚠️ **Parcial** — ningún Scenario verifica la columna «Logística **ve la cancelación**» |
| C-03 | Guardar el turno sin traslado | *(ninguno)* | ❌ **HUÉRFANA** — la salida figura enumerada en el Requirement de las tres salidas, pero **no tiene un solo Scenario** que verifique el destildado de «requiere traslado» ni que el turno se guarde solo |
| C-04 | Pedir autorización sin permiso | ATD «El gestor sin permiso pide» + VDL «El traslado pendiente no baja al sector» | ✅ |
| C-05 | Autorizar los dos, con permiso | ATD «Auto-aprobación de quien tiene el permiso» | ✅ |
| C-06 | Aprobar pedido pendiente | VDL «Al aprobar, el traslado baja marcado» | ✅ |
| C-07 | Rechazar con dictamen | VDL «Al rechazar, el traslado se cancela» | ✅ |
| C-08 | Rechazar sin dictamen | ATD «Rechazo sin dictamen» | ✅ *(conducta no implementada — `tasks 3.9`)* |
| C-09 | Pedido ya resuelto por otro | ATD «Dos personas abren el mismo pedido» | ✅ |
| C-10 | Alta por API sin motivo ni pedido | GST «Alta de un duplicado sin motivo ni pedido» | ✅ |
| C-11 | Alta con pedido rechazado | GST «Un pedido rechazado no habilita el traslado» | ✅ |
| C-12 | Alta con pedido pendiente | GST «Pedido pendiente habilita el guardado» | ⚠️ *(contexto D-5: en `/turnos/crear` nunca se ejercita)* |
| C-13 | Tanda con varias fechas en conflicto | CTM «Tanda con conflicto en varias fechas» | ⚠️ **Parcial** — informa, pero el corte total (D9) sólo aparece en GST y no como casuística |
| C-14 | Anulación rechazada (tramo facturable) | CTM «La anulación falla y el gestor lo ve» | ✅ |
| C-15 | Turno sin fecha (plan de rehabilitación) | GST «Sin traslado o sin fecha no hay nada que validar» | ⚠️ **Parcial** — cubre el «no valida al crear», **no** el «sí valida al programar» |
| C-16 | Denuncia cerrada o rechazada (SE-214) | *(ninguno)* | ❌ **HUÉRFANA** — ninguna spec menciona SE-214 ni la precedencia entre los dos gates |

**Resultado: 8 cubiertas, 6 parciales, 2 huérfanas.**

Y una omisión mayor: **la funcionalidad incorporada el 18/08 (RF-2.9 y RF-2.10, la devolución del resultado al solicitante) no tiene ninguna casuística en §8**. La tabla de casuísticas quedó congelada en la versión del 14/08 mientras §6 creció. Ver EST-13.

---

## 3. Hallazgos

### BLOQUEANTES

---

**EST-01 — El estado de la capability `devolucion-resultado-solicitante` es indeterminado: dos artefactos de la misma fecha se contradicen sobre si existe.**
`BLOQUEANTE` · *Tipo: Contradicción / Requisito incompleto* · *Afecta: RF-2.9, RF-2.10, PRD §4.1, §7.1*

| Artefacto (todos del 18/08/2026) | Qué dice |
|---|---|
| PRD §4.1 «Incluido» | «**Card en el home de quien pide**, con el resultado de sus pedidos y el dictamen» |
| PRD §6, RF-2.9 / RF-2.10 | Requisito redactado en presente, como conducta del sistema |
| PRD §7 (cuadro «estado real hoy, no el deseado») | Dictamen → **«Lo ve: NADIE / Ninguna pantalla»** |
| PRD §7.1 H-1 y H-2 | «El dictamen **no viaja en ningún endpoint de lectura**» · «**No hay** notificación, ni card, ni indicador» |
| SDD §10 H-2 | «**No hay ningún mecanismo de vuelta**» y lista la card como *«qué falta para cerrarlo»*, con costo estimado |
| `tasks.md` 3.6 y 7.10 | **`[x]`** — «los cinco endpoints» y «Card de resultados resueltos para quien pidió, con marcado de vistos idempotente» |
| `specs/devolucion-resultado-solicitante` | 3 Requirements, 8 Scenarios, todos en `## ADDED Requirements` |

No es una imprecisión de redacción: es una capability entera —el 20 % del alcance funcional y la razón declarada de la revisión del 18/08— cuyo estado no se puede determinar leyendo los artefactos. Un QA no puede decidir si la incluye en el plan, si los 8 Scenarios son casos ejecutables o expectativas, ni si un «la card no aparece» es defecto o comportamiento esperado.

> **Recomendación.** Antes de cualquier planificación: declarar en `tasks.md` y en el PRD si la devolución está implementada en `develop`. Si no lo está, mover sus Requirements a una sección explícitamente no entregada, porque hoy `H-1`/`H-2` y `tasks 7.10 [x]` no pueden ser ciertos a la vez.

---

**EST-02 — El motivo autodeclarativo sigue habilitando el gate, así que el circuito completo es evitable por diseño. La spec del gate afirma una restricción de permiso que no existe en ningún otro artefacto.**
`BLOQUEANTE` · *Tipo: Contradicción / Hueco de regla de negocio* · *Afecta: RF-4.1, RF-4.2, PRD §1, §11 pregunta 1*

RF-4.2 acepta el duplicado con **motivo declarado**, y el Scenario de la spec lo remata: *«con motivo declarado **no se consulta el estado de los pedidos**»*. El PRD §11 pregunta 1 confirma que el motivo se conserva «para que sigan funcionando las versiones del MFE que todavía no tienen el circuito», sin fecha de retiro.

Consecuencia: **cualquier consumidor que envíe `idMotivoTrasladoMismoDia` pasa el gate sin pedido, sin autorizante y sin registro de nada.** Los 2.156 casos anuales que el §1 identifica como el problema —*«el campo es autodeclarativo: lo completa el mismo gestor y no hay nada del otro lado»*— se siguen pudiendo generar exactamente igual, ahora con el gate server-side dando el visto bueno. El Bloque 4 no cierra la brecha que dice cerrar.

Y sobre eso, la spec `gate-servidor-traslado-duplicado` escribe: **«1. Motivo declarado *por quien tiene el permiso*»**. Esa calificación **no está en el PRD** (RF-4.2 dice sólo «motivo declarado») **ni la verifica ninguno de sus propios Scenarios** (el Scenario que la acompaña dice literalmente que no se consulta nada). Es la diferencia entre «el gate distingue quién declara» y «el gate acepta cualquier declaración»: si la spec fuese cierta, el circuito estaría cerrado; como no lo es, está abierto de par en par.

> **Recomendación.** Decidir y declarar una de dos: (a) el motivo declarado sólo lo acepta el gate si el llamante tiene `autorizar_traslado_mismo_dia`, y entonces hay que implementarlo y probarlo; o (b) el motivo se acepta de cualquiera hasta la fecha X, y entonces hay que **borrar la calificación de la spec** y aceptar explícitamente que la brecha sigue abierta hasta esa fecha. Sin esto, no hay resultado esperado para C-10 ni para el criterio de éxito del change.

---

**EST-03 — Un pedido pendiente no tiene vencimiento, SLA ni alerta. El traslado queda invisible para logística de forma indefinida y el paciente puede quedarse sin viaje sin que nadie se entere.**
`BLOQUEANTE` · *Tipo: Omisión / Riesgo de negocio no declarado* · *Afecta: RF-2.3, RF-3.2, D1, PRD §5 momento 2*

El circuito construye deliberadamente un estado en el que el traslado **existe, el gestor cree que lo pidió, y logística no lo ve** (`id_estado_logistica_ida` nulo). Ese estado no tiene salida automática: ni el PRD, ni `design.md`, ni ninguna de las cinco specs declaran qué pasa si nadie lo resuelve. No hay vencimiento, no hay escalamiento, no hay recordatorio, no hay reporte de pendientes antiguos y —según SDD §12.1— **no hay ninguna métrica**, ni siquiera de tiempo hasta la resolución.

Los tres riesgos ya declarados por el equipo convergen justo acá y se potencian entre sí:

- **R-3** — con el filtro de alcance, *«un pedido de otra cartera puede quedar sin quien lo resuelva»*. O sea: existen pedidos que estructuralmente **nadie ve**.
- **R-2** — el contador de la card es global y la grilla está filtrada por alcance: quien autoriza puede ver «3 pendientes» y una grilla vacía, y concluir que no hay nada que hacer.
- **R-22 / D-18** — el gerente de siniestros, uno de los cuatro perfiles habilitados, **nunca ve la card**. Sin card no hay disparador.

**Este es el único hallazgo del análisis con impacto directo sobre el asegurado, y además es una regresión.** Hoy el segundo traslado se pide igual: el paciente viaja y la aseguradora paga un remis que quizá no correspondía —un problema de costo—. Con el circuito, si el pedido no se resuelve, **el paciente no viaja**, no hay traslado que cancelar ni cancelación que avisar, y el defecto se manifiesta el día del turno médico, en la puerta del centro, sin que ningún actor del sistema haya recibido una señal. El costo se transformó en riesgo asistencial y el modo de falla es silencioso.

> **Recomendación.** Antes de promover: (a) definir un SLA de resolución y qué pasa al vencerlo (auto-rechazo con dictamen del sistema, escalamiento al perfil superior, o baja a logística por defecto); (b) un reporte o filtro de «pendientes con fecha de traslado próxima»; (c) cerrar R-2/R-3/R-22, porque son los que hacen que el pendiente sea *invisible* y no sólo *lento*. Mientras tanto, este es un riesgo abierto que debe figurar en la decisión de go/no-go, no en la lista de deuda.

---

**EST-04 — El perfil 10 (supervisor) queda «pendiente de confirmar» y los cuatro documentos lo declaran distinto. La matriz de permisos no se puede cerrar, y sin ella C-04 y C-05 no tienen resultado esperado.**
`BLOQUEANTE` · *Tipo: Requisito incompleto / Inconsistencia* · *Afecta: PRD §3, §11 pregunta 3, proposal, design, ATD*

| Artefacto | Qué dice del supervisor |
|---|---|
| PRD §3 tabla | Lo nombra entre los roles con permiso |
| PRD §3 nota 18/08 | *«Queda **pendiente confirmar** si el supervisor (perfil 10) entra»* |
| PRD §11 pregunta 3 | *«¿El referente también autoriza, o sólo supervisor y jefe de siniestros?»* — pregunta abierta, y con otro recorte que el de §3 |
| `proposal.md` | *«asignado a los perfiles de referente, jefe de siniestros, gerente de siniestros **y supervisor**»* — **afirmativo, sin salvedad** |
| `design.md` Open Questions | *«¿El supervisor entra o no? El script marca ese perfil como pendiente de confirmar»* |
| Script SQL | **«PENDIENTE DE CONFIRMAR»** |

Cuatro documentos, tres estados distintos de la misma decisión, y el `proposal.md` —que es el documento que un lector externo abre primero— la da por cerrada.

El impacto es directamente operativo, no documental: **la diferencia entre tener y no tener el permiso decide qué card ve el usuario, qué pestaña, si su duplicado se auto-aprueba o queda pendiente, y si recibe la devolución del resultado.** Un usuario supervisor es, según cuál de las cuatro versiones valga, el actor de C-05 o el actor de C-04 — casos con resultado esperado opuesto. No se puede armar el pool de usuarios de TEST sin resolverlo, ni se puede clasificar como «pasa» o «falla» la corrida de ese usuario.

Se agrava con la contradicción ya conocida del gerente (`!isGerente`, D-18/R-22): la spec `autorizacion-traslado-duplicado` declara **«NO SHALL usar el rol ni el perfil como criterio»** y el código evalúa `hasProfile(ROLES.GERENTE_DE_SINIESTROS)`. El aporte nuevo acá no es la discrepancia —el SDD ya la tiene— sino que **la spec normativa no la registra como excepción**: al archivar el change, la capability canónica quedaría afirmando una regla que el sistema viola en uno de sus cuatro perfiles habilitados, y ninguna auditoría futura tendría cómo saberlo.

> **Recomendación.** Cerrar la pregunta 3 con el referente funcional antes de armar el pool de TEST, unificar los cuatro documentos, y —si `!isGerente` se mantiene— declarar la excepción **en la spec**, no sólo en el SDD.

---

**EST-05 — RF-1.4 delega la política al backend y ningún artefacto normativo la declara: la matriz de salidas y el umbral de horas viven en el SDD y en un `application.properties`. Las tres salidas no tienen criterio de aceptación verificable.**
`BLOQUEANTE` · *Tipo: No testable / Omisión* · *Afecta: RF-1.3, RF-1.4, C-02, C-13, C-14*

RF-1.4 dice: *«Qué salidas están habilitadas lo decide el backend, caso por caso, según el estado operativo. El front sólo las renderiza.»* Y ahí termina. El PRD **nunca declara la política**. Ninguna de las cinco specs la declara tampoco: CTM sólo enuncia dos casos sueltos («ya realizado», «viaje en curso»).

La política real es una cascada de siete guardas que sólo existe en el SDD §5.4, con un umbral que ni siquiera es código:

```
wslogistica.conflicto-traslado.horas-minimas-anulacion = 3
```

Consecuencias concretas para la prueba:

1. **El resultado esperado de un caso depende de una property por ambiente.** El mismo dato de prueba produce `resoluble` en un ambiente y `sinAnular` en otro. Un caso escrito contra «3 horas» no es reproducible y no se puede automatizar contra el requisito, sólo contra la configuración.
2. **El umbral no está declarado en ningún documento que el negocio haya validado.** «Falta muy poco para el viaje» no es un criterio de aceptación: es una frase. Nadie firmó que 3 horas sea el número correcto para una ART.
3. **Los casos borde no tienen fuente normativa.** `horasAlViaje == 0`, exactamente en el umbral, `horaTurno` nula (se asume medianoche), monto en cero, ida facturable con vuelta pendiente: los 18 tests de `wslogistica` los cubren, pero **derivados del código**, no del requisito. Un test derivado del código no puede detectar que el código está mal.
4. Cambiar la política —el propósito declarado de la decisión D2— **no deja rastro en ningún documento**, porque no hay documento que la contenga.

> **Recomendación.** Subir la matriz de salidas de SDD §5.4 al PRD como tabla de reglas de negocio con el umbral explícito y validado, y agregarla a la spec `conflicto-traslado-mismo-dia` como Requirement con un Scenario por rama. Sin eso, RF-1.3 y RF-1.4 no son verificables y C-02/C-14 no tienen resultado esperado.

---

### ALTA

---

**EST-06 — El rechazo se neutraliza volviendo a pedir. RF-4.3 cierra la puerta de adelante y deja abierta la de atrás.**
`ALTA` · *Tipo: Hueco de regla de negocio* · *Afecta: RF-4.2, RF-4.3, D8*

RF-4.3 existe con un argumento explícito: *«si esto no valiera, alcanzaría con pedir la excepción y que te la nieguen para cargar el traslado igual»*. D8 refuerza con «el pedido que vale es el último», y cubre el caso *aprobado viejo + rechazo nuevo*.

**Nadie cubre el caso inverso: rechazo viejo + pedido nuevo pendiente.** Ni el PRD, ni `design`, ni ATD, ni GST declaran que un traslado con un pedido rechazado no pueda volver a pedirse. Y por RF-4.2 un pedido **pendiente** habilita el guardado. Entonces la secuencia es:

1. El gestor pide → se lo rechazan → el traslado se cancela con motivo 16 (RF-3.5).
2. El gestor carga el turno de nuevo y vuelve a pedir → nuevo pedido **pendiente** → el gate lo acepta → el traslado se guarda y espera.
3. Repetir hasta que alguien lo apruebe, o hasta que nadie lo resuelva y caiga en EST-03.

El rechazo no es firme: es un obstáculo de un intento. Y como la justificación desaparece al resolverse (H-3) y no hay historial del pedido, **quien reciba el segundo pedido no tiene forma de saber que ya fue rechazado una vez, ni por qué**. El circuito pierde precisamente la trazabilidad que venía a construir.

> **Recomendación.** Definir la regla: o el reintento se prohíbe, o se permite mostrando al autorizante el rechazo anterior con su dictamen (lo que exige el endpoint de consulta histórica de H-3). Elegir «no decidimos» equivale a la opción permisiva sin control.

---

**EST-07 — La auto-aprobación no exige justificación ni dictamen: reproduce el problema autodeclarativo que el change viene a resolver, ahora con un permiso.**
`ALTA` · *Tipo: Hueco de regla de negocio / Objetivo no cumplido* · *Afecta: PRD §1, RF-2.1, RF-2.2, RF-2.6, C-05*

El objetivo del §1 es doble: *«que un segundo traslado exista sólo si alguien con autoridad lo autorizó, **y que esa autorización quede registrada**»*.

En el camino de auto-aprobación (RF-2.2, C-05) queda registrado el **quién** y el **cuándo**, y nada más:

- La **justificación** es obligatoria sólo para quien **pide** (RF-2.1). Quien tiene el permiso no pide: declara.
- El **dictamen** es **opcional al aprobar** (RF-2.6, decisión cerrada del 14/08).
- Lo único que se registra es «el motivo declarado», del mismo catálogo de dos opciones —«Autorizado por Supervisión» / «Autorizado por Auditoría Médica»— que el §1 describe como el campo autodeclarativo que originó el problema.

Resultado: **para el perfil que más va a usar el circuito, el registro del *por qué* es exactamente el mismo que había antes.** La diferencia con los 2.156 casos históricos es que ahora quien tilda tiene un permiso. Es una mejora real, pero no la que el §1 promete, y el PRD no lo dice en ninguna parte.

Se agrava con el volumen: si los cuatro perfiles habilitados incluyen a quienes hoy cargan turnos, la mayor parte de los ~285 casos mensuales va a resolverse por auto-aprobación silenciosa y el circuito de pedido/resolución —donde vive toda la trazabilidad— va a ver una fracción marginal.

> **Recomendación.** Exigir justificación también en la auto-aprobación (mismo campo, misma tabla, costo casi nulo), o declarar explícitamente en el PRD que la auto-aprobación no registra motivación y asumir la consecuencia sobre el objetivo. Y prever la métrica que separe pedidos resueltos de auto-aprobaciones, porque es el indicador que dice si el circuito funciona o si se está esquivando por dentro.

---

**EST-08 — «Traslado vigente» tiene dos universos distintos según quién pregunte: `wslogistica` cuenta el transporte público y `wsturnos` no. La detección y el gate pueden discrepar sobre el mismo día.**
`ALTA` · *Tipo: Inconsistencia / Requisito incompleto* · *Afecta: RF-1.1, RF-4.1, RF-4.2*

RF-1.1 define vigente como «cualquier estado excepto Cancelado (4) y Rechazado (5)», y la spec CTM lo blinda: *«el sistema NO SHALL usar ningún otro criterio de vigencia»*. Los dos definen el **estado**; **ninguno define el universo de entidades**.

Y el universo difiere: `wslogistica` mergea `traslados` **y** `traslados_transporte_publico` para armar el conflicto, mientras que `tasks 5.4` deja abierta —`[ ]`— la *«asimetría de transporte público en el conteo de traslados vigentes en la fecha»*.

Los dos escenarios que produce esa asimetría no están en ninguna casuística:

- Paciente con un traslado de **transporte público** vigente + turno nuevo con traslado de agencia → el bloque de conflicto lo muestra y exige resolverlo, pero el gate no lo bloquea (o al revés). El gestor ve un conflicto que el backend no reconoce, o guarda un duplicado que la pantalla le había marcado.
- La marca `es_duplicado_autorizado` **nunca se escribe para transporte público** (R-8): un duplicado de TP autorizado queda sin marca *y* sin estado de logística — invisible para el sector y, si alguna vez baja, cancelable como duplicado.

Para una ART el transporte público no es un caso de borde: es el traslado más barato y el más frecuente en tratamientos largos de rehabilitación, que es justo el escenario de conflicto por excelencia (misma persona, muchas fechas, muchos turnos).

> **Recomendación.** Definir en el PRD el universo de «traslado vigente» —¿incluye transporte público?— y agregar dos casuísticas (TP preexistente + agencia nueva, y agencia preexistente + TP nueva). Sin la definición, `tasks 5.4` no tiene criterio para cerrarse.

---

**EST-09 — La máquina de estados del pedido no contempla que el mundo cambie mientras está pendiente: cinco transiciones sin regla declarada.**
`ALTA` · *Tipo: Omisión* · *Afecta: RF-2.3, RF-3.3, C-04, C-06*

El pedido pendiente es un estado que puede durar días. En el ciclo de vida de una denuncia de ART, en esos días pasan cosas. Ningún artefacto declara qué hacer con ninguna de ellas:

| # | Evento mientras el pedido está pendiente | Qué dice el PRD / las specs | Consecuencia si se aprueba igual |
|---|---|---|---|
| a | **La fecha del traslado ya pasó** | Nada | Se asigna estado de logística `Solicitado` a un viaje de ayer: logística recibe un pedido imposible de coordinar. El pool de DEV ya está exactamente en esa situación |
| b | **El turno se cancela o se reprograma** | Nada. La FK del pedido apunta a `autorizaciones`/`traslados`, no al turno | Queda un pedido pendiente de un turno que no existe; al aprobarlo se enciende la marca sobre un traslado sin turno |
| c | **El paciente recibe el alta médica** o **la denuncia se cierra/rechaza** | Nada. SE-214 se evalúa en el **alta del turno**, no en la aprobación — y según el SDD fue reescrito por SE-268 con «fecha límite = alta médica o fecha de rechazo» | Se libera un traslado para un paciente que ya no tiene cobertura del siniestro. Es gasto que la ART no debería pagar, generado *por* el circuito de control |
| d | **El traslado preexistente se cancela por otra vía** (logística, drawer de cancelar) | Nada | Ya no hay duplicado, pero el pedido sigue pendiente. El autorizante autoriza una excepción a una regla que dejó de aplicar, sin dato para saberlo |
| e | **El traslado pendiente recibe estado de logística por otro camino** (edición de turno, que no invoca el gate — `tasks 4.5 [ ]`) | Nada | Ver EST-10 |

`aprobar()` no revalida nada: toma el pedido, escribe el estado de logística y enciende la marca (SDD §12.3 confirma que no tiene un solo test). El único caso de invalidación que sí se pensó —el guard de «ya resuelto»— cubre a las personas, no al tiempo.

> **Recomendación.** Declarar la máquina de estados completa en `design.md`, con al menos: precondiciones de `aprobar()` (fecha futura, turno vigente, denuncia abierta, conflicto todavía existente) y qué pasa cuando no se cumplen (rechazo automático con dictamen del sistema, o error explicativo al autorizante). Cada fila de esa tabla es una casuística faltante.

---

**EST-10 — RF-3.5 «logística nunca se enteró» está redactado como garantía y es un supuesto que el propio `tasks.md` deja sin cerrar.**
`ALTA` · *Tipo: Requisito incorrecto* · *Afecta: RF-3.5, RF-4.4, C-07*

RF-3.5 afirma en pasado y en absoluto: *«El traslado se cancela con el motivo 16 y **nunca tuvo** estado de logística»*. La spec VDL lo repite: *«el traslado NO SHALL haber tenido nunca estado de logística»*.

Eso no es una regla que el sistema imponga: es la descripción de lo que pasa **si nada más toca el traslado entre el pedido y el rechazo**. Y hay al menos un camino documentado que sí lo toca: **`PUT /turnos/editar` no invoca el gate** (`tasks 4.5 [ ]`, contexto D-6), aunque sí invoca SE-214.

Si el traslado pendiente recibe un estado de logística por cualquier vía, el rechazo posterior **cancela con motivo 16 un traslado que logística ya vio y quizá ya coordinó con la agencia** — que es el escenario que el PRD §2.3 describe como el más caro: *«a veces con la agencia ya avisada»*. Y como el circuito no notifica a nadie (H-2), la cancelación aparece en la grilla del sector sin contexto.

Ningún Scenario verifica la invariante. No hay ningún «GIVEN un traslado pendiente de autorización, THEN su estado de logística permanece nulo ante cualquier operación».

> **Recomendación.** Convertir el enunciado descriptivo en una invariante verificable —el traslado con pedido pendiente no puede recibir estado de logística por ningún camino— y agregar el Scenario. Es, además, la única forma de que D1 («dos redes independientes») sea comprobable.

---

**EST-11 — «Si a la agencia ya se le avisó» no se puede reproducir desde la aplicación: es dato que sólo se genera fuera del sistema y sólo se prepara por SQL.**
`ALTA` · *Tipo: No testable* · *Afecta: RF-1.2, C-02, C-14*

RF-1.2 lo pone como uno de los dos datos que justifican el bloque entero: *«y si a la agencia ya se le avisó del viaje — porque anular un viaje ya avisado no es lo mismo que anular uno que todavía no salió»*. Es también la guarda 5 de la matriz de salidas, la que decide si la cancelación queda para revisión de logística.

El PRD no define cómo se determina. El SDD sí (D-14): existe un `TrasladoAgenciaHistorico` con `agenciaInformada = true` y etiqueta **no** en (5 CANCELADO, 6 DESESTIMADO). Y aclara algo decisivo para la prueba: el campo obvio, `traslados.mail_agencia_enviado`, **da 0 en todos los casos porque el aviso a la agencia no está automatizado**.

Traducido a QA: **no hay ningún flujo de la aplicación que produzca el estado «agencia informada».** No hay pantalla, no hay acción, no hay botón. Para probar RF-1.2 y la guarda 5 hay que insertar filas en `traslados_agencia_historico` por SQL, con la etiqueta correcta, y ese detalle no está en ningún guion de prueba: los pools de DEV y TEST documentados no lo mencionan.

> **Recomendación.** Documentar en el PRD el criterio funcional de «agencia informada», y agregar al pool de TEST el SQL de preparación de ese estado, con y sin las etiquetas 5/6 (que es un caso borde real: agencia informada de un viaje después cancelado **no** cuenta como informada).

---

**EST-12 — La regla de región no está en el PRD, y la spec la enuncia más amplia que la implementación: como está escrita, deja pasar duplicados reales.**
`ALTA` · *Tipo: Requisito incorrecto / Omisión* · *Afecta: RF-1.1, C-13*

La spec CTM incorpora un Requirement y un Scenario: *«NO SHALL considerar duplicado un traslado de otra región cuando el dato de región está informado en ambos»*.

Dos problemas:

1. **No tiene origen en el PRD.** No aparece en ningún RF, en ninguna casuística ni en ninguna decisión de §12. Es una regla de negocio que excluye conflictos —o sea, que **permite duplicados**— y llegó a la spec normativa desde el código, sin pasar por el negocio.
2. **La spec es más amplia que el código.** El SDD §5.4 es explícito: `compararRegion` devuelve `null` —y por lo tanto no filtra— *«si no es plan de rehabilitación»*. La exclusión aplica **sólo a planes de rehabilitación**. La spec no menciona esa condición, así que enuncia una regla general: *cualquier* par de traslados de regiones distintas no es duplicado.

Si alguien implementa contra la spec (o si un test la toma como fuente), el sistema dejará de detectar duplicados de consulta y de cirugía por región del cuerpo, que **sí** son duplicados: el mismo paciente puede tener una consulta traumatológica de rodilla y una de hombro el mismo día y necesitar un solo viaje. La regla tiene sentido en rehabilitación (dos tandas, dos regiones, dos centros); fuera de rehabilitación es un agujero.

> **Recomendación.** Llevar la regla al PRD con su condición completa («sólo en planes de rehabilitación, y sólo si la región del cuerpo está informada en ambos») y corregir el Requirement de la spec. Agregar la casuística: dos traslados de regiones distintas **que no son rehabilitación** → sí son duplicado.

---

**EST-13 — La tabla de casuísticas §8 quedó congelada en la versión del 14/08: dos casos huérfanos y todo el alcance agregado el 18/08 sin una sola casuística.**
`ALTA` · *Tipo: Omisión / Requisito incompleto* · *Afecta: PRD §8 completo*

§8 se presenta como el set de referencia: *«Cada fila es un caso a probar»*. Es lo que un equipo de QA usa como línea de base de cobertura. Está incompleta en tres frentes:

- **C-03 huérfana.** «Guardar el turno sin traslado» es una de las tres salidas del circuito y **no tiene un solo Scenario** en ninguna de las cinco specs. La evidencia de DEV la verificó a mano (punto 6: destilda solo, quita los obligatorios, habilita «Siguiente») y encontró comportamiento no trivial —que ninguna spec fija.
- **C-16 huérfana.** «Denuncia cerrada o rechazada → puede bloquearse antes, por SE-214.» Ninguna spec menciona SE-214 ni la **precedencia entre los dos gates**. No hay resultado esperado para «denuncia cerrada *y* traslado duplicado»: ¿qué mensaje ve el gestor, cuál de los dos 409 gana? Y con SE-268 reescribiendo SE-214 (fecha límite = alta médica), la interacción cambió y nadie la revisó.
- **RF-2.9 y RF-2.10 sin ninguna casuística.** La devolución del resultado al solicitante —card, contador, dictamen, marcado de vistos, apagado idempotente, exclusión de quien tiene el permiso— es el agregado del 18/08 y **§8 no lo registra**. La spec DRS aporta 8 Scenarios; §8 aporta cero. Quien planifique desde §8, como el propio PRD invita a hacer, deja fuera una capability entera.

También falta la casuística del **conflicto múltiple en la misma fecha** (varios traslados vigentes), que la spec CTM sí exige resolver «sobre todos ellos» — ver EST-15.

> **Recomendación.** Regenerar §8 a partir de §6 (no al revés) y mantener la trazabilidad RF ↔ C-xx explícita en la tabla. Mínimo a agregar: C-17 devolución al solicitante, C-18 exclusión de quien autoriza, C-19 precedencia SE-214 vs. gate de duplicado, C-20 conflicto múltiple en la misma fecha, C-21 transporte público preexistente.

---

**EST-14 — El corte total de la tanda (D9) es una regla de negocio de alto impacto operativo que no está en el PRD.**
`ALTA` · *Tipo: Omisión* · *Afecta: RF-1.5, C-13*

RF-1.5 dice sólo que el bloque *«informa en cuántas de las fechas hay conflicto»*. La regla que realmente decide el resultado está en `design.md` D9 y en la spec GST: **si al menos una fecha de la tanda tiene conflicto no resuelto, no se programa ninguna.**

Una tanda de rehabilitación en una ART son típicamente 10, 15 o 20 sesiones. La regla significa que **un conflicto en la sesión 14 impide programar las 20**, incluidas las que no tienen ningún problema. El argumento de D9 es razonable —una tanda parcial es peor que ninguna—, pero es exactamente el tipo de decisión que el negocio tiene que conocer, porque cambia el trabajo diario del gestor: pasa de «cargá la tanda y resolvé lo que salte» a «resolvé todo primero o no cargás nada».

Y el PRD, que es la fuente de verdad funcional declarada, **no la contiene**. Además RF-1.5 no dice qué se hace después de informar: ¿el gestor elige **una salida por fecha** o **una salida para toda la tanda**? La spec CTM resuelve la ambigüedad para varios traslados en *la misma* fecha («la salida se aplica sobre todos ellos») y la deja abierta para varias *fechas*. Con 14 conflictos en 20 fechas, la diferencia entre las dos lecturas es entre una interacción y catorce.

> **Recomendación.** Subir D9 al PRD como RF, y definir explícitamente el modelo de resolución multi-fecha. `tasks 4.6` —invocar el gate desde la tanda— está `[ ]`, así que la regla hoy no existe en ninguna capa: se puede definir bien antes de implementarla.

---

**EST-15 — `tasks.md` 7.3 está `[x]` y la evidencia de campo del mismo día documenta lo contrario: el front resuelve sólo el primer conflicto.**
`ALTA` · *Tipo: Contradicción* · *Afecta: tasks 7.3, spec CTM, RF-1.1*

- `tasks.md` 7.3 — **`[x]`** *«Exponer todos los conflictos de la fecha y aplicar la salida elegida sobre todos — antes sólo se resolvía el primero y el resto quedaba en pie»*.
- Spec CTM — *«el bloque expone **todos** los traslados en conflicto, y la salida elegida se aplica sobre todos ellos — el sistema NO SHALL resolver sólo el primero»*.
- `analisis/verificacion-correcciones-dev.md`, defecto 3, **misma fecha (18/08)**: *«La API devolvió **tres** traslados en conflicto para el 15/08 y el front toma sólo uno: `useConflictoTraslado.js:44` → `const primerConflicto = fechasConConflicto[0]?.traslados?.[0] ?? null`. Quien resuelve “anular ese traslado” anula uno y deja los otros dos duplicados en pie, **sin enterarse de que existen**.»*

Un `[x]` que la evidencia del mismo día desmiente no es un detalle de prolijidad: **`tasks.md` es el insumo con el que se decide qué entra al alcance de prueba y qué se da por hecho.** Si este `[x]` está mal, el resto de los `[x]` pierde valor como fuente y hay que verificar los 40 a mano.

El impacto funcional además es directo: el escenario que el defecto describe —anular uno y dejar dos duplicados en pie— produce exactamente el gasto que el change viene a evitar, con el agravante de que el gestor **cree** haberlo resuelto.

> **Recomendación.** Revertir 7.3 a `[ ]`, y auditar los `[x]` de la sección 7 contra la evidencia de campo antes de usar `tasks.md` como base del alcance. Convertir el defecto 3 en caso obligatorio de la matriz.

---

### MEDIA

---

**EST-16 — Hay una cuarta salida, `puedeDerivarALogistica`, que no aparece en ningún documento funcional.**
`MEDIA` · *Tipo: Omisión / Contradicción* · *Afecta: RF-1.3*

RF-1.3 y la spec CTM son categóricos: *«exactamente una de tres salidas excluyentes»*. La respuesta real del endpoint —capturada en la verificación de DEV— trae **cuatro** flags:

```json
"salidas": { "puedeAnular": …, "puedeDerivarALogistica": …,
             "puedeGuardarSinTraslado": …, "requiereAutorizacion": … }
```

`puedeDerivarALogistica` no está en el PRD, ni en `design.md`, ni en ninguna spec, ni en la tabla de salidas de RF-1.3. Según SDD §5.3 acompaña a `resoluble` y a `sinAnular` y se apaga en `soloInformativo`, pero **qué significa funcionalmente y qué ve el usuario cuando está en `true` no está escrito en ningún lado**. Un caso de prueba que valide «se ofrecen exactamente las salidas que el backend habilita» no puede escribirse sin saber si esa cuarta es una salida, un permiso interno o un residuo.

> **Recomendación.** Documentarla o eliminarla del contrato. Si es una salida, RF-1.3 dice mal «tres».

---

**EST-17 — RF-3.4 no define precedencia visual, así que el caso que el propio requisito quiere evitar no tiene resultado esperado.**
`MEDIA` · *Tipo: Requisito incompleto / No testable* · *Afecta: RF-3.4, C-06*

RF-3.4 pide *«franja de color propia, ícono con tooltip y su entrada en la leyenda al pie»* y justifica: *«sin la marca, logística vería dos traslados el mismo día y cancelaría uno, deshaciendo la autorización»*. No declara **qué color**, ni **qué pasa cuando la fila ya tiene otra señal**.

La spec VDL agrega un Scenario («las dos señales se muestran juntas y distinguibles») y el código no lo cumple (contexto D-17/R-21: con `requiereRevision`, la marca desaparece de las dos capas). El aporte nuevo acá es de testabilidad: **aunque el código estuviera bien, no hay criterio para decir si está bien.** «Distinguibles» no es verificable; el sistema tiene al menos tres señales concurrentes (duplicado autorizado, requiere revisión, espontáneo) y el requisito no ordena ninguna.

> **Recomendación.** Declarar la tabla de precedencia de señales de la grilla de logística, con el resultado esperado de cada combinación de a dos y de a tres. Son 7 combinaciones, y son 7 casos de prueba que hoy no se pueden escribir.

---

**EST-18 — El change no tiene criterio de éxito medible: se justifica con un número que después no se puede volver a medir.**
`MEDIA` · *Tipo: No testable / Trazabilidad* · *Afecta: PRD §1, §2*

Todo el PRD se apoya en un dato: **2.156 autorizaciones inexistentes en 2026, ~285 por mes.** Es la justificación de negocio y el §2.2 explica con detalle por qué los números de logística no sirven como línea de base.

No hay ningún requisito que permita verificar que ese número baje. SDD §12.1 lo confirma: *«ninguna métrica. No hay contador de 409 emitidos, ni de pedidos por estado, ni de tiempo hasta la resolución»*, y remata: *«para un circuito cuya justificación es un número, no poder medir si el número baja es un hueco de diseño»*.

Desde QA, la consecuencia es concreta: **no hay criterio de aceptación de negocio.** Se puede certificar que las 16 casuísticas funcionan y aun así no saber si el change resolvió el problema — sobre todo con EST-02 (el motivo autodeclarativo sigue habilitando) y EST-07 (la auto-aprobación no registra motivación) abiertos, que son justamente los dos caminos por donde el número puede no moverse.

> **Recomendación.** Definir el criterio de éxito post-producción con su fuente de datos y su fecha de corte (p. ej. «a 60 días, ≥ 70 % de los duplicados del mes tienen un pedido resuelto, y los declarados sin pedido bajan de 285 a X mensuales»), y exponer el conteo por estado del pedido.

---

**EST-19 — RF-2.10 define su audiencia por una capacidad («los que puedan cargar un turno con traslado»), no por un predicado verificable.**
`MEDIA` · *Tipo: No testable / Ambigüedad* · *Afecta: RF-2.10, C-04*

RF-2.10: *«La ven todos los tramitadores que puedan cargar un turno con traslado y no tengan el permiso `autorizar_traslado_mismo_dia`.»* La spec DRS lo copia igual.

La segunda mitad es verificable (negación de un permiso con nombre). La primera no: «poder cargar un turno con traslado» no es un permiso, un perfil ni una condición nombrada en ningún artefacto. Para escribir el caso hay que responder preguntas que ningún documento responde: ¿un usuario de **logística** sin el permiso ve la card? ¿Un auditor médico? ¿Un usuario nuevo sin ningún pedido —cubierto por «sólo aparece cuando hay algo que mostrar», pero no por la definición de audiencia?

Además choca con el propio principio del change: la spec ATD declara que **el permiso es el único discriminador**, y RF-2.10 introduce un segundo discriminador que no es un permiso.

> **Recomendación.** Expresar la audiencia como predicado: «tiene pedidos propios resueltos sin ver **y** no tiene `autorizar_traslado_mismo_dia`». Eso además resuelve sola la pregunta de logística y auditoría, y mantiene la coherencia con «el permiso es el único discriminador».

---

**EST-20 — Los datos de DEV están en fecha pasada: dos de las tres salidas son inalcanzables y la única evidencia que existe de ellas se obtuvo con la respuesta del backend interceptada.**
`MEDIA` · *Tipo: Testabilidad del ambiente* · *Afecta: C-02, C-04, C-05, C-14*

La verificación de campo lo dice sin rodeos: el pool de DEV tiene los traslados al **15/08/2026**, hoy pasado, y el backend devuelve `horasAlViaje: -73` con `puedeAnular: false`, `requiereAutorizacion: false`. *«Con los datos tal como están hoy, el bloque de conflicto sólo ofrece UNA salida»*. Los puntos 1 a 4 y 7 a 8 se verificaron **con un stub en el navegador** que devolvía `horasAlViaje: 20`.

Es decir: **el flujo de «anular el preexistente» y el de «pedir autorización» nunca se ejercitaron end-to-end desde la interfaz**, en ningún ambiente. El pool de TEST, según `design.md`, se armó por SQL clonando un turno real, lo que *«garantiza el dato pero no ejercita el código»* — y TEST no tiene el código desplegado (`tasks 10.3`, endpoints 404).

Además, un pool en fecha pasada activa directamente EST-09.a: son pedidos pendientes de traslados que ya vencieron.

> **Recomendación.** Reconstruir los pools con **fechas futuras móviles** (p. ej. `CURDATE() + 3` para el caso `resoluble`, `CURDATE()` + 1 hora para `sinAnular`, `CURDATE() - 1` para `soloInformativo`), documentar el SQL de re-fechado en el guion, y no dar por verificado ningún punto obtenido con stub.

---

### BAJA

---

**EST-21 — Inconsistencias residuales de la nota de revisión del 18/08.**
`BAJA` · *Tipo: Inconsistencia*

- El PRD §9 sigue diciendo *«`wsturnos` y `wslogistica` corren sobre Spring Boot 2.1.2, EOL»*, que **D-1 ya identificó como falso** (`wslogistica` está en 3.3.13). La nota de revisión del 18/08 declara haber aplicado las correcciones de SDD §13 al PRD y aplicó dos de las tres que le correspondían; D-1 quedó sin aplicar.
- La portada del PRD habla de **«dos de los cuatro servicios»** en TEST; `proposal.md`, `design.md` y `tasks.md` hablan de **cinco** servicios y de «los cinco servicios promovidos». No se puede saber cuántos faltan.

> **Recomendación.** Cerrar D-1 en §9 y unificar el conteo de servicios. Importa poco funcionalmente y mucho para la confianza en el documento.

---

**EST-22 — El marcado de vistos no define su alcance frente a la paginación.**
`BAJA` · *Tipo: Ambigüedad* · *Afecta: RF-2.9*

*«Al entrar, los pedidos quedan marcados como vistos y la card se apaga sola.»* Si la lista pagina, no está definido si se marcan **todos** los resueltos del solicitante o sólo los de la página visible. Con la primera lectura, la card se apaga y el gestor nunca ve el dictamen de los pedidos que quedaron en la página 2; con la segunda, la card sigue encendida después de entrar, que es lo que el requisito dice que no pasa. Son dos resultados esperados opuestos para el mismo caso.

---

**EST-23 — «Ver detalle» y «gestionar autorización» figuran como acciones de RF-2.5 y no tienen Scenario; «ver información de traslado», que sí lo tiene, está roto en DEV.**
`BAJA` · *Tipo: Omisión* · *Afecta: RF-2.5*

De las tres acciones que RF-2.5 enumera, la spec ATD sólo escribe un Scenario para una — y es justamente la que la verificación de campo encontró rota (`TypeError: E.resetTurnosTablaDetalle is not a function`, con causa raíz identificada: falta el re-export en el barrel de acciones). Las otras dos, incluida **«gestionar autorización»** que es la puerta de entrada a la resolución, no tienen criterio de aceptación propio.

---

## 4. Resumen por severidad y tipo

| Severidad | Cantidad | IDs |
|---|---|---|
| **BLOQUEANTE** | 5 | EST-01, EST-02, EST-03, EST-04, EST-05 |
| **ALTA** | 10 | EST-06 … EST-15 |
| **MEDIA** | 5 | EST-16 … EST-20 |
| **BAJA** | 3 | EST-21, EST-22, EST-23 |
| **TOTAL** | **23** | |

| Tipo de defecto | Total |
|---|---|
| Omisión | 7 |
| Contradicción / Inconsistencia | 6 |
| No testable / Ambigüedad | 5 |
| Requisito incompleto | 3 |
| Requisito incorrecto | 2 |
| **TOTAL** | **23** |

---

## 5. Checklist de datos de prueba para las 16 casuísticas

### 5.1 Precondiciones de ambiente (bloqueantes)

| # | Precondición | Estado hoy | Bloquea |
|---|---|---|---|
| A-1 | Los 5 servicios desplegados en TEST (`wsturnos`, `wslogistica`, `wstraslados`, `tramitadores`, `logistica`) | ❌ `tasks 10.3` — endpoints 404, CodePipeline no desplegó `release` | **todo** |
| A-2 | Tabla `autorizaciones_traslado_duplicado` + columnas `es_duplicado_autorizado` y `fecha_visto_solicitante` | ✅ `tasks 1.6` | C-04..C-12 |
| A-3 | Los **4 stored procedures** reemplazados **antes** del código | ✅ `tasks 2.4` | grilla de pendientes |
| A-4 | Permiso `autorizar_traslado_mismo_dia` dado de alta y asignado a los perfiles **confirmados** | ⚠️ perfil 10 sin confirmar (EST-04) | C-04, C-05 |
| A-5 | `personas_perfiles_sas` verificada contra la base | ❌ R-16 — sin confirmar; si el nombre difiere, **nadie puede autorizar** | C-05..C-09 |
| A-6 | `wslogistica.conflicto-traslado.horas-minimas-anulacion` conocido y fijado en TEST | ⚠️ EST-05 — no declarado en ningún doc funcional | C-02, C-14 |
| A-7 | Los endpoints **detrás del gateway** (o el riesgo aceptado por escrito) | ❌ `tasks 10.4` / R-1 | C-05..C-09 |
| A-8 | `<skipTests>true</skipTests>` removido de `wslogistica/pom.xml` | ❌ R-18 | — (calidad del build) |

### 5.2 Usuarios

| ID | Usuario | Perfil | Permiso `autorizar_traslado_mismo_dia` | Para |
|---|---|---|---|---|
| U-1 | Gestor / operador de tramitadores | tramitador estándar | **NO** | C-02, C-03, C-04, C-13, C-14 y la card de resultados (RF-2.9) |
| U-2 | Referente de siniestros | 3 | **SÍ** | C-05, C-06, C-07, C-08 |
| U-3 | Jefe de siniestros | 2 | **SÍ** | C-09 (segundo resolutor) |
| U-4 | Gerente de siniestros | 9 | **SÍ** | Verificar D-18/R-22: ve la tab, **no** la card |
| U-5 | Supervisor | 10 | **A CONFIRMAR** | EST-04 — sin la decisión no hay resultado esperado |
| U-6 | Usuario de **otra cartera / cuenta** | cualquiera con permiso | SÍ | R-3: pedido fuera de alcance, ¿queda sin resolutor? |
| U-7 | Usuario de logística | logística | NO | RF-3.x y control de EST-19 (¿ve la card de resultados?) |
| U-8 | Cliente API sin sesión (Postman) | — | — | C-10, C-11, C-12, RF-4.x, y el rechazo sin dictamen (D-4) |

> U-2 y U-3 deben poder resolver **el mismo** pedido para C-09. U-1 y U-2 deben pertenecer a la **misma cartera** para que el pedido sea visible; U-6 a una distinta, a propósito.

### 5.3 Denuncias y pacientes

| ID | Dato | Requisito | Para |
|---|---|---|---|
| D-A | Denuncia **abierta**, con paciente con traslados habilitados, dentro del alcance de U-1 y U-2 | activa, sin alta médica, fecha de siniestro reciente | C-01..C-14 |
| D-B | Denuncia **cerrada o rechazada** | debe disparar SE-214 | C-16 y la precedencia de gates (EST-13) |
| D-C | Denuncia con **plan de rehabilitación** activo y tanda de ≥ 5 fechas | con ≥ 3 fechas en conflicto | C-13, D9 (EST-14) |
| D-D | Denuncia con plan de rehabilitación con **dos regiones del cuerpo** informadas | ambas regiones no nulas | Regla de región (EST-12) |
| D-E | Denuncia de **otra cartera/cuenta** que la de U-2 | fuera del alcance de U-2 | R-3 (EST-03) |
| D-F | Denuncia con **alta médica** cargada | para simular EST-09.c | Hueco de estados |

### 5.4 Traslados preexistentes — uno por rama de la matriz de salidas

Todos sobre D-A, mismo paciente, **fechas relativas para que no venzan** (EST-20):

| ID | Estado del traslado | Estado logística ida | Monto | Tipo viaje | Fecha/hora | `agenciaInformada` | Salida esperada |
|---|---|---|---|---|---|---|---|
| T-1 | Solicitado (1) | 1 Solicitado | 0 | Ida | `hoy + 3 d`, 10:00 | no | `resoluble` (todas las salidas) |
| T-2 | Solicitado (1) | 1 | 0 | Ida | `hoy`, `+2 h` | no | `sinAnular` (bajo el umbral de 3 h) |
| T-3 | Solicitado (1) | 1 | 0 | Ida | `hoy`, `+3 h` exactas | no | **Borde**: en el umbral **sí** se puede anular |
| T-4 | Programado (2) | 3 | 0 | Ida | `hoy`, `-1 h` | no | `soloInformativo` («el viaje ya empezó») |
| T-5 | cualquiera | **4 Realizado** | > 0 | Ida | `hoy + 2 d` | no | `soloInformativo` (facturable) |
| T-6 | cualquiera | 1 | **0,00** | Ida | `hoy + 2 d` | no | **Borde**: monto en cero **no** bloquea |
| T-7 | Solicitado | ida **4 Realizado**, vuelta 1 | ida > 0 | **Ida y vuelta** | `hoy + 2 d` | no | `resoluble` parcial: sólo el tramo pendiente |
| T-8 | Solicitado | 1 | 0 | Ida y vuelta | `hoy + 2 d` | **sí** | `resoluble` con aclaración de revisión de logística |
| T-9 | Solicitado | 1 | 0 | Ida | `hoy + 2 d` | histórico con etiqueta **5/6** | **Borde**: NO cuenta como informada |
| T-10 | **Cancelado (4)** | — | — | — | `hoy + 2 d` | — | **No** genera conflicto (C-01) |
| T-11 | **Rechazado (5)** | — | — | — | `hoy + 2 d` | — | **No** genera conflicto |
| T-12 | **Transporte público** vigente | — | 0 | Ida | `hoy + 2 d` | — | EST-08: ¿lo detecta el gate? |
| T-13 | Tres traslados vigentes **en la misma fecha** | 1 | 0 | Ida | `hoy + 2 d` | no | EST-15: la salida debe aplicarse a los tres |

> **T-8 y T-9 requieren SQL directo** sobre `traslados_agencia_historico` (`agencia_informada = 1`, etiqueta ∉ {5,6} para T-8, ∈ {5,6} para T-9). No hay flujo de aplicación que los produzca — EST-11.

### 5.5 Pedidos de autorización precargados

| ID | Estado | Solicitante | Autorizante | Justificación | Dictamen | Para |
|---|---|---|---|---|---|---|
| P-1 | **Pendiente (1)** | U-1 | — | texto de ≥ 20 car. | — | C-06, C-07, C-08, C-09 |
| P-2 | **Aprobado (2)** | U-1 | U-2 | sí | vacío | C-12, verificar marca y estado de logística |
| P-3 | **Rechazado (3)** | U-1 | U-2 | sí | sí | C-11, y **el reintento** de EST-06 |
| P-4 | Aprobado (2) **y luego** rechazado (3) sobre el mismo traslado | U-1 | U-2 | sí | sí | D8 / «el pedido que vale es el último» |
| P-5 | Pendiente de **U-6** (otra cartera) | U-6 | — | sí | — | R-3: ¿lo ve alguien? (EST-03) |
| P-6 | Pendiente con **fecha de traslado pasada** | U-1 | — | sí | — | EST-09.a: ¿se puede aprobar? |
| P-7 | Pendiente cuyo **turno fue cancelado** después | U-1 | — | sí | — | EST-09.b |
| P-8 | Resuelto y **no visto** por U-1 | U-1 | U-2 | sí | sí | RF-2.9 / card de resultados (si existe — EST-01) |
| P-9 | Pendiente sobre **transporte público** | U-1 | — | sí | — | R-8 / EST-08: marca y estado de logística |
| P-10 | Justificación de **> 1000 caracteres** vía API | U-8 | — | sí | — | R-11: hoy explota en el INSERT como 500 |

### 5.6 Datos que se generan durante la ejecución (verificar, no precargar)

- `autorizaciones_traslado_duplicado`: `estado`, `id_solicitante`, `fecha_solicitud`, `id_autorizante`, `fecha_autorizacion`, `dictamen`, `fecha_visto_solicitante`.
- `traslados`: `id_estado_logistica_ida` (**nulo** mientras pendiente, `1` al aprobar), `id_estado_logistica_vuelta` (sólo si ida y vuelta), `es_duplicado_autorizado`, `id_motivo_anulacion = 16` al rechazar, `observaciones_anulacion` (**sin sufijo `_ida`** — D-2) conteniendo el dictamen.
- `traslados_transporte_publico.es_duplicado_autorizado` — **se espera que quede sin escribir** (R-8): confirmarlo como defecto, no como paso.
- Contador de la card vs. filas de la grilla — **comparar los dos números** (R-2).
- Códigos HTTP: **409** para el gate; y verificar que `SIN_PERMISO`/`YA_RESUELTO`/`NO_ENCONTRADO` viajan en **200** (R-9), que es contrato a confirmar o a corregir.

### 5.7 Rollback

Los pools deben ser identificables sin depender de identificadores (patrón ya usado: `observaciones` que empiezan con `INI-2 POOL TEST`) y traer su SQL de reversión completo. Verificar que el re-fechado móvil de 5.4 esté incluido en ese SQL.

---

## 6. Lo ultra bloqueante

Los cinco puntos que, hoy, impiden dar por probado este desarrollo. En orden de severidad.

### 1. No hay ambiente donde probarlo

El código no está desplegado en TEST: los endpoints devuelven **404** y CodePipeline no promovió `release` (`tasks 10.3`, pendiente de `aws sso login`). El pool de TEST se cargó por SQL, lo que —según el propio `design.md`— *«garantiza el dato pero no ejercita el código»*. Y en DEV, las fechas del pool ya pasaron: **dos de las tres salidas del bloque de conflicto nunca se ejecutaron contra el backend real**; la única evidencia que existe se obtuvo interceptando la respuesta en el navegador (EST-20).

Cero de las 16 casuísticas está verificada end-to-end en un ambiente de certificación. Todo lo demás de esta lista es secundario mientras esto no se resuelva.

### 2. El alcance funcional no está definido: no se sabe qué hay que probar

Una capability entera —la devolución del resultado al solicitante, RF-2.9 y RF-2.10— está declarada como **implementada** en `tasks.md` (`[x]` en 3.6 y 7.10) y como **inexistente** en el PRD §7.1 y en el SDD §10, todos del mismo día (EST-01). A eso se suma que `tasks.md` ya falló al menos una vez como fuente: el `[x]` de 7.3 lo desmiente la evidencia de campo de esa misma fecha (EST-15).

Sin saber qué está construido, no se puede armar el plan, no se puede clasificar un hallazgo como defecto o como alcance no entregado, y no hay criterio de salida.

### 3. El circuito es evitable por diseño, y la spec afirma que no lo es

El gate acepta el **motivo autodeclarativo** sin exigir permiso ni pedido, y el propio Scenario aclara que en ese caso *«no se consulta el estado de los pedidos»* (EST-02). O sea: los 2.156 casos anuales que justifican el desarrollo se siguen pudiendo generar por el mismo camino, ahora validados por el gate server-side.

La spec `gate-servidor-traslado-duplicado` escribe *«motivo declarado **por quien tiene el permiso**»* — una restricción que **no está en el PRD, no la verifica ninguno de sus propios Scenarios y no está en el código**. Certificar contra esa spec sería certificar un control que no existe.

### 4. Un pedido sin resolver deja al paciente sin traslado, y nadie se entera

El circuito crea deliberadamente un estado invisible para logística, y **no declara ningún vencimiento, escalamiento, alerta ni métrica** para salir de él (EST-03). Sobre eso se apilan tres riesgos ya reconocidos que lo hacen estructural, no accidental: hay pedidos que **nadie puede ver** (R-3, alcance por cartera), el contador puede mostrar pendientes que la grilla no lista (R-2), y uno de los cuatro perfiles habilitados **nunca ve la card** que es el único disparador (R-22).

Es el único hallazgo con impacto sobre el asegurado, y es una **regresión**: hoy el problema es que se paga un viaje de más; con el circuito, el modo de falla es que el paciente no viaja, se descubre el día del turno y ningún actor del sistema recibió una señal. Necesita decisión de negocio antes de promover, no después.

### 5. No hay criterios de aceptación verificables para el corazón del change

Tres cosas, que juntas impiden escribir la matriz:

- **La política de las tres salidas no está en ningún artefacto normativo** (EST-05). Vive en el SDD y en un `application.properties` con un umbral de 3 horas que ningún referente funcional validó. El resultado esperado de un caso depende de una property configurable por ambiente.
- **El perfil supervisor está sin confirmar**, y los cuatro documentos lo declaran distinto (EST-04). Como el permiso decide si el duplicado se auto-aprueba o queda pendiente, ese usuario es el actor de C-05 o el de C-04 —resultados opuestos— según qué versión valga.
- **Dos casuísticas están huérfanas y el alcance del 18/08 no tiene ninguna** (EST-13): C-03 «guardar sin traslado» no tiene un solo Scenario, C-16 no define la precedencia con SE-214, y la devolución del resultado no figura en §8.

---

## Notas metodológicas

- Revisión estática realizada bajo criterios ISTQB de calidad de requisitos: claridad, completitud, consistencia, corrección, testabilidad y trazabilidad.
- Las 21 discrepancias (D-x), los 22 riesgos técnicos (R-x) y los 4 huecos de trazabilidad (H-x) documentados por el equipo de desarrollo en el SDD se tomaron como **contexto**, no como hallazgos propios. Cuando se citan, se los identifica con su código de origen.
- No se generaron casos de prueba: este reporte es exclusivamente de revisión estática. La §5 es un checklist de datos y precondiciones, no una matriz de casos.
- No se ejecutó código ni se consultó base de datos: el análisis se basa exclusivamente en los artefactos documentales del change.

---

*Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026*

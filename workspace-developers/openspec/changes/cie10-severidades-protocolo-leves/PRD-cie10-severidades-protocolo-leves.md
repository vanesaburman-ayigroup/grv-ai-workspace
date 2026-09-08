# PRD — Severidad de CIE-10 trazadores y autorización automática de protocolo en leves

| | |
|---|---|
| **Change** | `cie10-severidades-protocolo-leves` |
| **Fecha** | 05/08/2026 |
| **Tickets** | GRV-2239 (CIE-10 trazadoras) · pedido de protocolo por mail del 13/07, reclamado el 29/07 |
| **Referente funcional** | Desireé Romero — Coordinadora de Auditoría Médica, Colonia Suiza |
| **Validado con** | Reunión del 05/08 (Desireé Romero, Vanesa Burman, Yanina Di Prima) · comentario de Ignacio Zumbo y Desireé del 04/08 en GRV-2239 |
| **Objetivo de salida** | Semana del 05/08 |

---

## 1. Objetivo

Dos cambios que deben aplicarse **en este orden** porque el segundo depende del primero:

1. **Alinear la severidad y los días de ILT** de los cuatro CIE-10 de patologías trazadoras que hoy están cargados como leves, y **bloquear su edición** para el auditor médico.
2. **Reponer la autorización automática de las prestaciones de protocolo** en el ingreso de siniestros leves, acotada a lo que Auditoría Médica definió y **agregando la severidad de la denuncia como condición**, que hoy no se evalúa.

El propósito funcional del punto 2, en palabras de la referente, es «ayudar al auditor con la cantidad de trabajo que tiene» sin sacarle de las manos lo que sí debe auditar.

---

## 2. Contexto y problema

La autorización automática de prestaciones de protocolo **existió y fue desactivada** hace unos dos meses por una cuestión operativa. La lógica sigue implementada; lo que está vacío es la configuración: hoy hay **una sola** prestación nomenclada marcada para autoaprobación (`CONSULTA MEDICA (SIMPLE)`, cupo 1) y **ninguna de FKT ni de primera asistencia**.

Al analizar la reposición se detectó que **cinco CIE-10 asociados a patologías trazadoras están habilitados para autoaprobación**, cuatro de ellos catalogados como **Leve con 10 días de baja** aunque describen cuadros graves. Reponer la automatización sobre ese catálogo haría que un politraumatismo grave o una herida por arma de fuego pasaran prestaciones sin intervención del auditor.

Auditoría Médica confirmó el problema y definió la corrección el 04/08. La reunión del 05/08 cerró las definiciones que quedaban ambiguas.

---

## 3. Usuarios

| Rol | Cómo lo afecta |
|---|---|
| **Gestor de mesa** | Carga las primeras prestaciones al ingreso del siniestro. Es quien dispara la autoaprobación; no cambia su pantalla, cambia el estado con el que nace la autorización. |
| **Auditor médico** (Colonia Suiza) | Deja de recibir para dictamen la primera asistencia y las tres sesiones de FKT de protocolo. Sigue auditando la consulta de control y todos los estudios. Pierde la posibilidad de editar el CIE-10 en los cuatro códigos trazadores. |
| **Equipo SAS** | Único habilitado para modificar el CIE-10 de los casos bloqueados. |
| **Tramitadores y auditoría de facturación** | Consumidores del cálculo de topes que alimenta el widget previo al dictamen: cambia lo que ven, no cómo lo ven. |

---

## 4. Alcance

### 4.1 Incluido

- Ajuste de catálogo de los cuatro CIE-10 trazadores: severidad y días de baja.
- Apagado del flag de autoaprobación en esos cuatro códigos.
- Bloqueo de edición del CIE-10 para el perfil de auditor médico en esos casos.
- Reposición de la autoaprobación de protocolo en el ingreso del siniestro, para primera asistencia y FKT.
- Incorporación de la severidad de la denuncia como condición de la autoaprobación.
- Registro que permita distinguir una aprobación automática de una manual (propuesto por el equipo técnico, no pedido por el cliente — ver RF-8).

### 4.2 Excluido explícitamente

| Fuera de alcance | Motivo |
|---|---|
| **Recalcular denuncias ya existentes** — fecha probable de fin de ILT, severidad o días de casos ya enviados a la SRT o a Provincia ART | Definición de la referente: «lo que ya se hizo se queda así, porque ya se registró en la SRT, para no romper nada. Nosotros ya sabemos que fue un error; con que lo futuro salga». **El cambio aplica sólo hacia adelante.** |
| **Cotejo completo del catálogo de severidades contra el Excel de Colonia Suiza** | Depende de que Mesa de Ayuda de Colonia Suiza entregue el archivo. Change aparte. |
| **Equivalencias de CIE-10 con Provincia ART** (GRV-2207) | Bloqueante independiente, espera definición médica. Change aparte. |
| **Autorización automática después del ingreso del siniestro** | Definición de la referente: el protocolo automático corre «solamente cuando el siniestro ingresa, la primera vez». |
| **Consulta de control y estudios** | Excluidos por decisión clínica (ver RF-6). |
| Campo «excedido revisado / no revisado», aprobación del flujo de traslado por referentes, topes que sumen prestaciones de todos los CIE-10, asignación auditor/gestor, módulo de recalificación | Pendientes distintos relevados en la misma reunión; no son parte de este change. |

---

## 5. Requisitos funcionales

### Bloque 1 — Catálogo de CIE-10 trazadores

**RF-1 · Severidad y días de los cuatro códigos.**
Los siguientes CIE-10 pasan a **severidad Grave** y **120 días de baja**:

| CIE-10 | Descripción | Patología trazadora | Hoy | Definido |
|---|---|---|---|---|
| `S31.8` | Heridas de otras partes y de las no especificadas del abdomen | Herida abdominal transperitoneal | Leve · 10 días | **Grave · 120 días** |
| `T14.1` | Herida de región no especificada del cuerpo | Lesiones por arma de fuego o arma blanca (con internación) | Leve · 10 días | **Grave · 120 días** |
| `T06.8` | Otros traumatismos especificados que afectan múltiples regiones del cuerpo | Politraumatismo grave | Leve · 10 días | **Grave · 120 días** |
| `S61.8` | Herida de otras partes de la muñeca y de la mano | Herida y/o traumatismo de mano con internación | Leve · 10 días | **Grave · 120 días** |

Los 120 días aplican a los tres campos de días de baja del catálogo, para que el valor no dependa de la severidad con la que se evalúe el caso.

**RF-2 · Apagado de la autoaprobación en esos códigos.**
En los mismos cuatro códigos, el flag que habilita la autoaprobación de prestaciones queda **apagado**.

> Fundamento técnico: la clasificación de «leve común» que habilita la autoaprobación **no evalúa la severidad** — evalúa si la denuncia es reingreso, enfermedad profesional o salud mental. Cambiar la severidad a Grave **no impide por sí solo** que se autoaprueben prestaciones. Debe apagarse el flag de forma explícita, en la misma transacción que RF-1.

**RF-3 · Bloqueo de edición del CIE-10.**
En toda denuncia marcada con **patología trazadora** (las diecinueve configuradas, no sólo los cuatro códigos de RF-1), el CIE-10 **no puede ser modificado por el perfil de auditor médico**. Definición de la referente: «bloquear para el uso interno de los auditores; ningún auditor médico nuestro puede hacer eso, solamente el equipo del SAS».

**RF-3.1 · Vía de corrección para el equipo SAS.**
El bloqueo debe venir con una forma operable de corregir el CIE-10 desde el equipo SAS, y con un interruptor para desactivar la restricción completa.

> No es opcional. GRV-2207 es el precedente exacto de qué ocurre sin esa válvula: una denuncia con trazadora «Muerte» quedó con el único código admitido para esa trazadora, sin equivalencia con Provincia ART, **sin poder corregirse desde la pantalla y sin poder migrar**. Ampliar el bloqueo a las diecinueve trazadoras multiplica la superficie de ese riesgo.
>
> Se suma lo advertido en GRV-2239: la restricción ya existe en el código, hoy no está actuando y quedó sin interruptor para apagarla.

### Bloque 2 — Autorización automática de protocolo

**RF-4 · Momento de aplicación.**
La autoaprobación se evalúa **únicamente en el ingreso del siniestro**, en la primera carga de prestaciones que hace el gestor. No se aplica a prestaciones solicitadas posteriormente.

**RF-5 · Prestaciones alcanzadas.**

| Prestación | Comportamiento | Cupo |
|---|---|---|
| Consulta de **primera asistencia** (la primera consulta del paciente, por guardia) | Sale **aprobada** sin dictamen | 1 |
| **FKT de protocolo** | Sale **aprobada** sin dictamen | **3 sesiones** |

El cupo de FKT es de **tres** sesiones. Se detectó configuración previa de cinco: debe quedar en tres.

**Candidatas identificadas en la base** — uso real en julio de 2026, para que Auditoría Médica confirme cuál corresponde a cada concepto:

| Concepto | Código | Prestación | Clase | ID | Usos jul. |
|---|---|---|---|---|---|
| Primera asistencia · candidata A | `42.03.05` | CONSULTA EN GUARDIA | no nomenclada | 1693 | 694 |
| Primera asistencia · candidata B | `42.01.01` | CONSULTA MEDICA (SIMPLE) | nomenclada | 6031 | 4.366 |
| FKT · candidata principal | `25.01.01` | AGENTES FISICOS, FISIOTERAPIA, HORNO DE BIER | nomenclada | 5665 | 5.179 |
| FKT · módulo | `25.01.07` | MODULO FKT | ambas clases | 5498 / 2230 | 240 |
| FKT · terapia física | `25.01.02` | TERAPIA FISICA O KINESITERAPIA | nomenclada | 5666 | 151 |

> **Lectura del equipo técnico.** Para primera asistencia, `CONSULTA EN GUARDIA` es la que coincide con la descripción funcional —Carolina Cuneo señaló que «la primera consulta es por guardia»— pero `CONSULTA MEDICA (SIMPLE)` es la que hoy tiene el flag de autoaprobación encendido y la que más se usa. **Son dos definiciones distintas y hay que elegir una.**
>
> Para FKT, `AGENTES FISICOS, FISIOTERAPIA` concentra el 94 % del volumen y es la candidata natural. Queda por definir si el cupo de tres sesiones se cuenta por prestación o abarca a todo el grupo de FKT: si sólo se marca `25.01.01`, una solicitud cargada como `TERAPIA FISICA` o `MODULO FKT` no se autoaprobaría.

**RF-6 · Prestaciones excluidas, siempre.**

| Prestación | Motivo funcional |
|---|---|
| **Consulta de control** | «No sabemos qué gravedad real tiene el siniestro. Un siniestro puede ingresar como moderado, pero cuando recibimos el estudio el paciente tiene una lesión que amerita el cambio de CIE-10 y pasa a grave; de ahí en adelante tenemos que definir con qué especialista concurre el paciente.» |
| **Estudios** (radiografías incluidas) | «El estudio tiene que ser sí o sí auditado.» |
| Cualquier prestación que **requiera traslado** | Regla vigente del mecanismo; se mantiene. |

**RF-7 · Severidad de la denuncia como condición.**
La autoaprobación **sólo procede si la denuncia es de severidad Leve**. Es un requisito nuevo: el mecanismo anterior evaluaba el CIE-10 pero no la severidad de la denuncia, de modo que un cambio futuro de catálogo podía volver a dejar cuadros graves dentro del universo autoaprobable.

> La referente se refirió explícitamente a «la gravedad real del siniestro, no al CIE-10».

**RF-8 · Trazabilidad de la aprobación automática.** *(propuesto por el equipo técnico)*
Toda autorización aprobada de forma automática debe quedar registrada como tal, de manera distinguible de una aprobación manual y de las excepciones ya existentes.

> Hoy no es posible: el sistema asigna el auditor médico del usuario como autorizante **también** en las aprobaciones automáticas, y el flag existente se enciende en todo caso que salga aprobado directo, incluidas las denuncias de un cliente que se aprueban por otro motivo. Sin esto no hay forma de medir cuánto trabajo manual se ahorró ni de auditar el comportamiento.

---

## 6. Hallazgos técnicos que condicionan la implementación

Verificados sobre la base productiva y el código, en modo de sólo lectura.

**HT-1 · Existen dos escalas de severidad y no son compatibles.**

| id | `severidades` (catálogo CIE-10) | `severidades_denuncias` (denuncia) |
|---|---|---|
| 1 | Leve | Leve |
| 2 | **Grave** | **Moderado sin internación** |
| 3 | Muerte | Moderado con internación |
| 4 | Crónico | Grave |
| 5 | Moderado | Mortal |
| 6 | No Informado | — |

El mismo identificador significa **Grave** en una tabla y **Moderado sin internación** en la otra. Cualquier comparación entre `denuncias.id_severidad` y `denuncias.id_severidad_denuncia`, o entre catálogo y denuncia, debe traducir escalas. El cálculo de topes vigente evalúa gravedad contra la escala del **catálogo** (id 2).

**HT-2 · La severidad se carga ANTES de que la denuncia pase a protocolo completo — verificado, y habilita RF-7.**

Una primera lectura por antigüedad sugería que el dato se completaba tarde: el porcentaje de denuncias sin severidad crecía del 4,6 % en ene–mar al 9,3 % en agosto. Cruzado contra el estado del protocolo, se ve que esas denuncias son simplemente las que **todavía no llegaron a protocolo completo**, y que ésas no emiten autorizaciones.

Denuncias con fecha desde el 01/06/2026:

| `protocolo_completa` | Denuncias | Sin severidad | Con autorizaciones | **Sin severidad Y con autorizaciones** |
|---|---|---|---|---|
| 0 — en carga | 123 | 26 | 13 | **1** |
| **1 — completo** | **10.614** | 279 | 6.831 | **0** |
| 2 — sin avance | 281 | 277 (98,6 %) | 0 | **0** |

Conclusión: **en el universo donde se emiten autorizaciones, la severidad ya está cargada.** De 10.614 denuncias con protocolo completo, ninguna que tenga autorizaciones está sin severidad. El único caso de borde es una denuncia en dos meses, en estado de carga.

El estado `2` concentra las denuncias sin severidad (98,6 %) y **no genera ninguna autorización**, por lo que es irrelevante para este change. Queda por confirmar con Mesa qué representa ese estado; 276 de sus 281 casos tampoco tienen número asignado.

**Consecuencia de diseño:** RF-7 puede exigir severidad Leve sin desactivar la funcionalidad. La condición correcta no es «al ingreso del siniestro» en abstracto, sino **la primera carga de prestaciones sobre una denuncia con `protocolo_completa = 1`**, que es el momento en que el dato existe.

**HT-3 · «Grave» implica «sin tope de prestaciones».**
El cálculo de topes deja las cantidades de FKT, consultas y estudios **sin límite** cuando alguno de los CIE-10 de la denuncia es grave. Al aplicar RF-1, los cuatro códigos pasan a consumir prestaciones sin techo. Puede ser el comportamiento deseado para un politraumatismo, pero es un efecto de RF-1 que el cliente no evaluó y debe quedar aceptado por escrito.

**HT-4 · La decisión se implementa en el SAS nuevo. La única implementación conocida está en el SAS clásico, que está fuera de uso.**
La cadena de condiciones descrita en la sección 2 está implementada en el módulo legacy, que **ya no se usa**: opera únicamente el SAS actual, con sus servicios y microfrontends. El clásico comparte las mismas tablas, de modo que **la configuración en base (RF-1, RF-2 y los flags de prestaciones) afecta a los dos sistemas por igual**, pero la lógica de decisión de RF-4 a RF-7 debe escribirse en el servicio de turnos del SAS nuevo, que es donde nacen las autorizaciones.

En el SAS nuevo ya existen los campos mapeados y un cálculo de consumo de topes por CIE-10 reutilizable, que hoy sólo se usa para mostrar el semáforo previo al dictamen. Ese cálculo es la base sobre la que construir la decisión.

**HT-5 · Hay un escritor no identificado del flag de preaprobación — a resolver antes de implementar.**
Tres autorizaciones de FKT quedaron marcadas como preaprobadas por CIE-10 el 04/08 y el **05/08 a las 09:00**, todas del mismo solicitante (Agustín Gergic) y con el mismo autorizante, con cupo de 5 sesiones.

No se encontró quién las escribe: no hay procedimiento almacenado ni trigger que toque ese campo, y **ninguna rama de los repositorios del SAS nuevo lo setea**. La única implementación localizada está en el módulo clásico, que se da por fuera de uso.

Antes de escribir la lógica nueva hay que determinar cuál de estas es la explicación, porque cada una cambia el trabajo:

- el módulo clásico sigue recibiendo tráfico para este flujo concreto;
- existe un servicio o rama que no está clonada o actualizada localmente;
- el flag se escribe por una vía distinta de la que se supone.

> Dato relacionado: en el clásico ese campo **no significa «preaprobada por CIE-10»**. Se enciende en toda autorización que sale aprobada directo, incluidos los casos de rol que aprueba todo y las denuncias de un cliente que se aprueban por otro motivo. Refuerza RF-8: hace falta un registro que sí signifique lo que dice.

---

## 7. Criterios de aceptación / casos de prueba

| # | Caso | Resultado esperado |
|---|---|---|
| CP-01 | Denuncia leve ingresa y el gestor carga la consulta de primera asistencia | Autorización **aprobada** sin dictamen |
| CP-02 | Misma denuncia, el gestor carga 3 sesiones de FKT de protocolo | Autorización **aprobada** sin dictamen |
| CP-03 | Misma denuncia, el gestor carga una 4ª sesión de FKT | Queda **pendiente de aprobación** — no se rechaza |
| CP-04 | Denuncia leve, se solicita una consulta de control | Queda **pendiente de aprobación** |
| CP-05 | Denuncia leve, se solicita una radiografía | Queda **pendiente de aprobación** |
| CP-06 | Denuncia con severidad Moderado o Grave, se carga primera asistencia | Queda **pendiente de aprobación** |
| CP-07 | Denuncia con CIE-10 `T06.8` (ya corregido a Grave) | Ninguna prestación se autoaprueba |
| CP-08 | Prestación de protocolo que además requiere traslado | Queda **pendiente de aprobación** |
| CP-09 | Prestación de protocolo solicitada días después del ingreso, fuera de la primera carga | Queda **pendiente de aprobación** |
| CP-10 | Auditor médico intenta editar el CIE-10 en un caso con trazadora alcanzada | La edición se **rechaza** con mensaje claro |
| CP-11 | Usuario del equipo SAS corrige el CIE-10 en el mismo caso | La edición **se permite** |
| CP-12 | Denuncia ya existente, anterior al cambio, con alguno de los cuatro códigos | **No se altera**: ni días, ni severidad, ni fecha probable de fin de ILT |
| CP-13 | Autorización aprobada automáticamente | Queda registrada como automática y distinguible de una manual |
| CP-14 | Denuncia sin severidad cargada, en estado de carga, con prestaciones solicitadas | Queda **pendiente de aprobación** — sin severidad confirmada no se autoaprueba |
| CP-15 | Auditor médico intenta editar el CIE-10 en una denuncia con cualquiera de las 19 trazadoras | La edición se **rechaza** |
| CP-16 | Denuncia con trazadora cuyo CIE-10 no tiene equivalencia con Provincia ART | El equipo SAS puede corregirlo y la denuncia migra — regresión de GRV-2207 |

---

## 8. Supuestos y dependencias

- **Supuesto:** el ajuste de catálogo (RF-1, RF-2) se aplica antes de habilitar la autoaprobación (RF-4 a RF-7). Invertir el orden expone a autoaprobar prestaciones de cuadros graves.
- **Supuesto:** los cuatro códigos de RF-1 son los únicos a corregir en este change. El cotejo completo contra el catálogo de Colonia Suiza puede sumar más, y va por otro change.
- **Decidido:** la lógica se implementa en el SAS nuevo. El módulo clásico está fuera de uso, y la configuración en base alcanza a ambos sistemas por igual (HT-4).
- **Decidido:** el bloqueo de RF-3 alcanza a las diecinueve patologías trazadoras, no sólo a los cuatro códigos corregidos.
- **Dependencia:** confirmación de las prestaciones de RF-5 sobre las candidatas identificadas.
- **Dependencia bloqueante:** resolver HT-5 —quién escribe hoy el flag de preaprobación— antes de escribir la lógica nueva. Si el módulo clásico sigue operando ese flujo, hay un camino que la implementación nueva no cubriría.
- **Riesgo:** el cambio de severidad mueve el cálculo de días de ILT, que se resuelve en tiempo de ejecución. Aunque no se recalculen datos históricos, **conviene medir cuántas denuncias activas tienen alguno de los cuatro códigos** antes de aplicar, para anticipar el efecto sobre casos en curso.

---

## 9. Preguntas abiertas

**1 · ¿Cuál es la prestación de «consulta de primera asistencia»?** *(bloquea RF-5)*
`CONSULTA EN GUARDIA` coincide con la descripción funcional; `CONSULTA MEDICA (SIMPLE)` es la que hoy tiene el flag encendido y ocho veces más volumen. Y para FKT, si el cupo de tres sesiones se marca sólo en `AGENTES FISICOS, FISIOTERAPIA` o abarca todo el grupo de prestaciones de FKT.

**2 · ¿Aplica a todos los clientes o sólo a Colonia Suiza?** *(no consultado)*
No se habló en ninguna de las reuniones. El sistema ya discrimina comportamiento de autorizaciones por cliente, así que la restricción es posible si se la quiere.

**3 · ¿Qué representa `protocolo_completa = 2`?** *(no bloquea)*
281 denuncias desde junio, el 98,6 % sin severidad y ninguna con autorizaciones. No afecta a este change, pero conviene saberlo para descartar que sea un estado del que una denuncia pueda volver al circuito.

---

## 10. Decisiones cerradas

| Punto | Definición | Fuente |
|---|---|---|
| Retroactividad | **No.** Lo ya enviado a la SRT o a Provincia ART no se recalcula | Desireé Romero, 05/08 |
| Momento de la autoaprobación | Primera carga de prestaciones, con la denuncia en protocolo completo | Desireé Romero, 05/08 + HT-2 |
| Cupo de FKT | **3 sesiones** (estaba en 5) | Desireé Romero, 05/08 |
| Consulta de control | **Excluida** del protocolo automático | Desireé Romero, 05/08 |
| Estudios y radiografías | **Excluidos**, auditoría obligatoria | Desireé Romero y Carolina Cuneo |
| Severidad de los 4 códigos | Grave, 120 días | Ignacio Zumbo y Desireé Romero, 04/08 |
| Alcance del bloqueo de CIE-10 | Las **19 patologías trazadoras** | GRV-2239 |
| Dónde vive la lógica | **SAS nuevo.** El módulo clásico está fuera de uso | Definición interna, 05/08 |
| Severidad como condición | Sí, exigir Leve. El dato está disponible en el momento en que se evalúa | HT-2 |

---

## 11. Métrica de aporte IA vs intervención humana

Se completa al cerrar el desarrollo, junto con las MRs, indicando modelo y nivel de esfuerzo utilizados.

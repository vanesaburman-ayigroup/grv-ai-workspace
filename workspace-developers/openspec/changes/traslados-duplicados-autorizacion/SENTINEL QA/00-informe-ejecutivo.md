# Informe ejecutivo — QA Sentinel · `traslados-duplicados-autorizacion` (INI-2)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Ticket** | INI-2 (triage inbox, no Jira) |
| **Revisión** | 18–19/08/2026 |
| **Ambientes evaluados** | DEV (funcional) · TEST (despliegue) · PROD (sólo lectura, base) |
| **Fuentes** | Análisis estático · verificación de base · verificación de aplicación · API testing · exploratorias |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |

---

> ## Actualización del 19/08/2026 — al cierre de la jornada
>
> Este informe se escribió con siete bloqueantes. **Al cierre del día quedan dos**, y los dos son
> decisiones tomadas, no defectos abiertos. Lo que cambió:
>
> | Antes | Ahora |
> |---|---|
> | **VAP-01** — TEST sin backend | **Resuelto**: `wsturnos` se desplegó y el filtro funciona (4.412.529 sin filtro → 1 con filtro). TEST es ambiente válido |
> | **A1 / R-1** — identidad por el cuerpo del pedido | **Riesgo aceptado con decisión registrada**: `wsturnos` no puede tener JWT todavía. No es un hallazgo abierto |
> | **API-02** — el rechazo se neutraliza | **Corregido y commiteado** (`wsturnos` `9e74f0e`) |
> | **REV-02** — se aprueba sin traslado | **Corregido y commiteado** |
> | **VBD-02** — el script del permiso colisiona | **Corregido y commiteado** |
> | **EST-02** — el motivo autodeclarativo sigue habilitando | **Decisión de negocio: se deja como está** |
> | **EST-03** — el pedido sin SLA | **Diferido a etapa 2** por decisión de negocio |
> | **EXP-04** — la medición | **Diferida a etapa 2**: no hace falta medir hoy |
> | **EST-04** — el perfil supervisor | **Cerrado**: entran supervisor, referente, jefe y gerente |
> | **EST-05 / B5** — el número de turno | **Cerrado a favor de RF-1.2**: se corrigió el requisito, no el código |
>
> **Queda abierto y sin decidir un solo ítem: A4** — que el rechazo compruebe si la cancelación
> ocurrió. Y el detalle completo del triage está en `10-triage-y-remediacion.md`.
>
> ## Segunda actualización — 21/08/2026 · dos bloqueantes NUEVOS, del frontend
>
> El recorrido completo del circuito en TEST, con los tres perfiles, produjo **25 hallazgos**
> (ver `08-manual-usuario/`). Dos son **bloqueantes**, y **los dos tienen la misma causa**:
>
> **El front y el backend no se pusieron de acuerdo sobre cómo se pide la autorización en un
> alta.** El backend lo resolvió con `registrarPedidoDelAlta`, que se activa con dos campos en
> el cuerpo de `turnos/crear` — `justificacionTrasladoDuplicado` e
> `idSolicitanteTrasladoDuplicado` —. **El front no conoce ninguno de los dos: cero ocurrencias
> en todo el repositorio de `tramitadores`.** Y sigue llamando al endpoint viejo.
>
> | ID | Bloqueante |
> |---|---|
> | **A6** · `MAN-G-01` | **«Enviar el pedido» no registra nada y deja al gestor sin salida.** Llama a `pedir-traslado-duplicado`, que exige una autorización que en un alta no existe → **400**. La pantalla borra los tres radios y deshabilita «Siguiente». Reproducido 2 de 2 |
> | **A7** · `MAN-G-02` | **«Confirmar» falla en silencio y el turno no se crea.** Postea `turnos/crear` sin los dos campos → el gate responde **409**, correcto — y el wizard **no muestra nada**. El gestor cree que guardó. Verificado en base: sin turno y sin pedido |
>
> **La tercera salida del circuito no se puede usar desde el alta.** Es la razón de ser del
> desarrollo: existe para que un gestor **sin** permiso pueda pedir la excepción.
>
> **A7 es el más grave, porque falla en silencio.** El gestor sigue trabajando convencido de que
> guardó; el paciente no tiene turno, nadie pidió la autorización, y nadie se entera hasta el
> día del traslado.
>
> **El arreglo es del frontend y es chico.** El camino correcto ya está construido, probado y
> desplegado: dejar de llamar al endpoint viejo en el alta, mandar los dos campos en
> `turnos/crear`, y mostrar el 409 en lugar de comérselo. **Cero backend.**
>
> **Corrección a un hallazgo previo:** **EST-15 no se reproduce** — el bloque informa
> correctamente los tres conflictos y pluraliza el copy. La tarea 7.3 que desmarqué el 19/08
> habría que volver a marcarla; la evidencia en que me basé era del 18/08 y el front cambió.

## 1. Veredicto

**NO GO para promover a STAGE o PROD.** El circuito **funciona** en DEV y su diseño es sólido, pero hay
**siete bloqueantes**, y dos de ellos no son defectos de código sino de premisa: el motivo de anulación
con el que el circuito cancela **no es un motivo de duplicado**, y el gate **sigue siendo evitable** por
el mismo camino autodeclarativo que el change vino a cerrar.

La prueba funcional **no puede ejecutarse en TEST**: el frontend está desplegado y su backend no.

> **Las tres afirmaciones de arriba quedaron superadas el mismo 19/08** — ver la actualización al
> comienzo del documento. Se conservan sin editar porque son el estado en que se tomó la decisión, y
> porque la trazabilidad de por qué se decidió cada cosa vale más que un documento prolijo.

### Lo que sí está bien, y conviene decirlo

- El circuito **funciona end-to-end en DEV**: bloque de conflicto con las tres salidas, pedido,
  resolución con dictamen, y devolución al solicitante.
- **La devolución al solicitante está implementada** y muestra el dictamen completo. Los huecos H-1,
  H-2 y H-3 que el PRD y el SDD declaran abiertos **están cerrados**: esos documentos quedaron
  obsoletos respecto de su propio código.
- **Tres de los cinco defectos** reportados en la evidencia de campo del 18/08 **ya están corregidos**.
- El caso de negocio **se valida contra producción**: 2.381 autorizaciones declaradas contra un
  circuito que no existe. El número del PRD no estaba inflado.
- La calidad documental del change es muy alta: el SDD se auditó a sí mismo y retiró tres hallazgos
  falsos propios.

---

## 2. Los siete bloqueantes

| # | ID | Bloqueante | Fuente |
|---|---|---|---|
| 1 | **EXP-04** | **El motivo 16 no es un motivo de duplicado.** En el catálogo es «Cancelado por alarma repetida», y ninguno de los 23 motivos refiere a duplicados. El circuito va a cancelar todo bajo ese motivo, volviendo sus anulaciones **indistinguibles** de cancelaciones ajenas — el mismo problema de medibilidad que el change venía a resolver | Exploratorias + base |
| 2 | **VAP-01** | **En TEST el front está desplegado y el backend de `wsturnos` no.** Las pestañas se ven, los endpoints dan 404 y la grilla muestra turnos sin filtrar **sin dar ningún error**. Es el peor modo de falla que `design.md` advirtió, ya materializado | Aplicación |
| 3 | **API-02** | **El rechazo es neutralizable en las dos direcciones.** `tienePedidoDeExcepcion()` usa `anyMatch` sobre toda la lista histórica: basta con un pedido *pendiente* posterior para pasar el gate. Rompe RF-4.3 | API + código |
| 4 | **VBD-02** | **El script del permiso colisiona.** Inserta `id_permiso = 101`, ocupado en PROD por `editar_cie10_bloqueado` y en DEV por `log_cirugias`. El espacio de ids **divergió entre ambientes** | Base |
| 5 | **R-1 / SEC** | **Los endpoints de `wsturnos` responden sin autenticación** y validan el permiso contra el `idAutorizante` que viaja **en el body**. Se puede aprobar el propio duplicado con el id de un supervisor | Aplicación + API + exploratorias |
| 6 | **EST-02** | **El gate sigue siendo evitable por el motivo autodeclarativo**, que no exige permiso ni pedido. Los ~2.156 casos anuales se pueden seguir generando igual | Estático |
| 7 | **EST-03** | **Un pedido pendiente no tiene SLA, vencimiento ni alerta.** Es una **regresión con impacto al asegurado**: hoy se paga un viaje de más; con el circuito, **el paciente no viaja** y se descubre el día del turno | Estático |

### Por qué el primero es el más grave

Los bloqueantes 2 a 5 son defectos: se arreglan. El 1, el 6 y el 7 son de **premisa**, y los tres
comparten la misma forma — **el circuito construye el control y deja abierta la puerta de al lado**:

- Se registra quién autoriza y por qué… y el motivo autodeclarativo sigue habilitando sin autorizar.
- Se cancela con un motivo trazable… que en realidad dice «alarma repetida».
- Se garantiza que el duplicado no baje sin autorización… y no hay nada que garantice que alguien
  resuelva.

Ninguno se arregla con código solo: requieren una decisión de negocio.

---

## 3. Lo que hay que decidir, no programar

| Pregunta | Quién | Por qué bloquea |
|---|---|---|
| **¿Se da de alta un motivo de anulación propio de duplicado?** | Negocio + Logística | Sin eso el circuito no es medible y EXP-04 queda abierto |
| **¿Cuándo se retira el motivo autodeclarativo?** | Negocio | Es la puerta que deja pasar lo que el gate frena (EST-02) |
| **¿Qué pasa con un pedido que nadie resuelve?** | Negocio | Define si hay SLA, vencimiento o alerta (EST-03) |
| **¿El perfil supervisor autoriza?** | Negocio | **DEV ya lo asignó de hecho** (perfiles 2, 3, 9 y 10) mientras el script dice «pendiente de confirmar» y cuatro documentos lo declaran distinto (EST-04) |
| **¿Se muestra el número de turno?** | Producto | RF-1.2 lo permite y RF-5.1 lo prohíbe. Define si EXP-02 se arregla en código o en el requisito |

---

## 3.bis Verificación de la grilla de logística (19/08, con el usuario `ayi.logistica`)

Los tres requisitos que estaban sin verificar por falta de usuario del sector quedaron cerrados.

| Punto | Veredicto | Evidencia |
|---|---|---|
| **RF-3.4** — el aprobado llega marcado | **CONFIRMADO — cumple** | Las tres capas están: franja `#0B8F8A` exclusiva de la fila, ícono con tooltip **«Segundo traslado del día autorizado»**, y entrada propia en la leyenda con el mismo color |
| **H-4** — el tooltip nombra al autorizante | **CONFIRMADO — no lo nombra** | `POST /grv/logistica/traslados/listar` trae `esDuplicadoAutorizado: true` y **ningún** campo con el autorizante entre sus 53 campos. El bundle sí tiene la rama `duplicadoAutorizadoPor ? … : …`: es **texto muerto** |
| **R-21 / NP-10** — la marca se pierde | **Mecanismo CONFIRMADO · la parte grave REFUTADA** | La **franja** es un ternario excluyente (`isEspontaneo > requiereRevision > esDuplicadoAutorizado`) y el **ícono es aditivo**: divergen. Pero en el build desplegado el ícono de duplicado **sí se renderiza** junto al de revisión, así que la marca se pierde **sólo de la franja**, no de las dos capas |

> **La documentación estaba desactualizada, otra vez en dirección favorable.** R-21 describía el commit
> `f865c52`, donde el ícono también era excluyente. Lo desplegado es posterior y mejor.

Los escenarios (a) y (b) de R-21 son **no reproducibles por datos**: en todo DEV hay **una sola** fila
con `es_duplicado_autorizado = 1`, y no tiene ninguna de las otras banderas. El mecanismo se demostró
sobre otro par de banderas (traslados 1468984 y 1469005).

### Hallazgos nuevos del sector

| ID | Hallazgo | Severidad |
|---|---|---|
| **LOG-01** | **El ícono de «duplicado autorizado» está pintado con `fill="#F29423"` — el mismo naranja que la leyenda asigna a «Requiere revisión»** — sobre una fila de franja teal. Y el glifo es un **octógono de advertencia con «!»**: iconografía de peligro para comunicar una excepción **concedida**, que es justo la lectura que empuja a cancelar. Sin hover, los dos íconos son indistinguibles | **MEDIA-ALTA** |
| **LOG-02** | La marca de duplicado es **la última de la cola** del ternario de la franja. Escala del problema: 34.460 espontáneos contra 1 duplicado en DEV | MEDIA |
| **LOG-03** | Dentro de la denuncia (`isDetalleSiniestro=true`) la **columna del ícono se suprime**: queda la franja teal sin ningún tooltip que la explique | BAJA-MEDIA |
| **LOG-04** | Los dos íconos del change **sí** tienen nombre accesible. El resto no: `alt="icon"`, y **9 de 9 botones del `tbody` sin `aria-label` ni `title`** — incluida la acción destructiva de **cancelar** | MEDIA |

**LOG-01 importa más de lo que parece.** RF-3.4 justifica la marca así: *«sin la marca, logística vería
dos traslados el mismo día y cancelaría uno, deshaciendo la autorización»*. La marca existe, pero está
pintada con el color y el glifo de un problema. Cumple la letra del requisito y **trabaja contra su
propósito**.

**Dos extras verificados:** el traslado **rechazado** (1469810) **no aparece** en la grilla — correcto.
El **anómalo** (1469808, cancelado con estado de logística 6) **sí aparece**, visible pero inerte, y el
sector no puede distinguir «cancelado porque la autorización quedó pendiente» de cualquier otra
cancelación.

---

## 4. Correcciones a la documentación del change

La revisión encontró que **la documentación está desactualizada respecto de su propio código**, en
dirección favorable: describe como faltante lo que ya está hecho.

| Documento | Dice | Realidad |
|---|---|---|
| PRD §7.1 · SDD §10 — **H-1** | «El dictamen no se lee en ninguna parte» | **Se lee**, completo, en la pestaña de resueltas |
| PRD §7.1 · SDD §10 — **H-2** | «El gestor nunca se entera del resultado» | **Se entera**: contador + pestaña + marcado de vistos |
| PRD §7.1 · SDD §10 — **H-3** | «La justificación desaparece al resolverse» | **Sobrevive** |
| PRD §2.2 y §7 | «el motivo específico de duplicado (16)» | Es **«Cancelado por alarma repetida»**. El código lo nombra bien: `MOTIVO_ANULACION_ALARMA_REPETIDA` |
| `tasks.md` 7.3 `[x]` | El bloque resuelve todos los conflictos | Toma **sólo el primero** (`useConflictoTraslado.js:44`) — EST-15 |
| Specs OpenSpec | 9 Requirements sin respaldo en el PRD, **6 de ellos sobre tareas sin hacer** | Si se archivan así, las capabilities canónicas **afirman conducta inexistente** |

> **`tasks.md` no es fuente confiable de alcance.** Tiene tareas en `[x]` desmentidas por la evidencia
> del mismo día, y tareas cuyo estado real es mejor que el declarado.

---

## 5. Riesgo de método detectado en la propia revisión

Dos veces, en esta sesión, la misma trampa:

1. **El MCP de MariaDB apunta a producción**, no a TEST. Cualquier verificación de «¿está aplicada la
   migración?» hecha por ahí responde por PROD y **da un falso negativo**. Se resolvió conectando a
   DEV por Python, leyendo las credenciales del `application-dev.properties`.
2. **El clon local de `wsturnos` estaba 23 commits atrás** de `origin/develop`, y la primera pasada de
   API testing concluyó que dos endpoints «no existían». Existen.

Es exactamente el error que el propio SDD se señaló al retirar su discrepancia D-16: *«el error fue de
método — corrió `git branch --contains` sobre un clon sin fetch»*. **Volvió a pasar dos veces.**

**Recomendación permanente:** leer siempre contra `origin/<rama>` con `fetch` previo, y declarar rama,
commit **y fecha**. Y no usar el MCP de MariaDB para verificar ambientes bajos.

---

## 6. Cobertura producida

| Artefacto | Contenido |
|---|---|
| **Análisis estático** | 23 hallazgos (5 bloqueantes, 10 altos). Trazabilidad RF → spec → Scenario; cobertura de C-01 a C-16 |
| **Verificación de base** | 5 hallazgos. PROD confirmada limpia; colisión del permiso; DDL verificado en DEV |
| **Verificación de aplicación** | 6 hallazgos. Estado de despliegue TEST vs DEV; los 5 defectos previos reverificados |
| **Plan de pruebas** | 89 casos (47 P1), 17 XF, 12 NP, 16 criterios de GO |
| **Matriz de casos** | **98 casos** (49 P1 / 32 P2 / 17 P3), 17 XF, 10 OBS. **63 Scenarios de spec trazados**, 5 huecos declarados |
| **API testing** | 40 requests Bruno sobre 7 endpoints, con los tests de seguridad de R-1 |
| **Exploratorias** | 13 defectos, 6 huecos de regla, 6 ajenos. 49 capturas. **Sin dejar datos en DEV** |

| **Verificación de logística** | 4 hallazgos. RF-3.4 y H-4 cerrados; R-21 acotado y en parte refutado |
| **Automatización (Fase 2)** | **35 de 49 casos P1** (CTM 11/11, ATD 12/12, GST 6/6, VDL 6/6), 7 Page Objects, 1 componente, smoke de 5 tests |

### Estado de la prueba funcional

**Matriz aprobada el 19/08. Fase 2 iniciada y parcial.**

Lo ejecutado de verdad contra DEV: **el login de los tres perfiles pasa** (`ayioperadort`,
`tramitador.supervisor`, `ayi.logistica`). En el camino se encontró y corrigió un defecto del propio
instrumental: `LoginPage.ingresar()` colgaba 30 s porque `waitForURL` esperaba el evento `load`, que el
SAS en DEV **nunca dispara** (SPA con módulos federados). Corregido a `domcontentloaded`.

La mayoría de los specs P1 quedaron en `test.fixme` / `test.skip`: **escriben en DEV de forma
irreversible** (aprobar, rechazar, anular) o dependen de datos que la matriz exige construir por la
aplicación. No se corrieron sin supervisión humana. Los XF del lote llevan `test.fail()` con el assert
correcto según spec, para que la suite **se ponga roja cuando arreglen el defecto**.

Condiciones para completar:

1. **Desplegar `wsturnos` en TEST**, o asumir DEV como ambiente de certificación.
2. **Crear los usuarios faltantes**: perfiles **3, 9 y 10**. El de logística ya está resuelto
   (`ayi.logistica`, persona 1000015, perfil 18).
3. **Arreglar la compresión del bundle en DEV**: se sirve sin gzip y se estanca (351 KB en 120 s), lo
   que deja el login como un shell vacío. Ya provocó 1 fallo de login de cada 4. Si no se arregla, las
   fallas de arranque se van a leer como defectos del producto.
4. **Datos en fechas futuras.** Con fecha pasada el backend habilita una sola salida.
5. **Construir los datos que faltan** para cerrar R-21: dos traslados con `es_duplicado_autorizado = 1`,
   uno espontáneo y otro con `requiere_revision = 1`, ambos con estado de logística asignado.
6. **Configurar el MCP de Qase** — no está registrado y `QASE_API_TOKEN` está vacío, así que la suite y
   el Test Run quedaron pendientes.
7. **Revisar el `.gitignore` del repo de QA**: `tests/` y `src/` están ignorados, así que la
   automatización **no se versiona**. Decisión del equipo.
8. **Lote 2 de automatización**: los 63 casos P2/P3/OBS y los módulos DRS (diferido por la
   irreversibilidad de `fecha_visto_solicitante`), SEC, INT y RGR.

> **Advertencia sobre los Page Objects.** `LogisticaGrillaPage` y parte de los demás se construyeron
> sobre hipótesis de la matriz, no sobre DOM confirmado. Es esperable ajustar selectores en la primera
> corrida completa. Un test del smoke —el de la pestaña de pendientes— **falló** por eso y está
> documentado.

---

## 7. Contenido de esta carpeta

| Ruta | Qué es |
|---|---|
| `00-informe-ejecutivo.md` | Este documento |
| `01-analisis-estatico/` | 23 hallazgos, trazabilidad y checklist de datos |
| `02-verificacion-ambientes/` | Verificación de base y de aplicación |
| `03-plan-de-pruebas/` | Plan con criterios de entrada y de GO |
| `04-matriz-de-casos/` | 98 casos ejecutables con queries de verificación |
| `05-evidencia/` | Exploratorias y 49 capturas |
| `06-api-testing/` | Resumen de la colección Bruno |

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

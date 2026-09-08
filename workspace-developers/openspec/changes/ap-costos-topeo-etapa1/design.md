## Context

El control de consumo de las pólizas de Accidentes Personales se hace hoy en Excel, a mano, paciente por paciente. La automatización estuvo bloqueada por un hecho de modelo: **`cs.polizas_ap` no tiene ninguna columna de monto** (verificado por INFORMATION_SCHEMA con 6 patrones LIKE → 0 resultados), por lo que no existe denominador para topear.

Estado real relevado (réplica read-only de `cs` + `repos/grvx/backend`, julio 2026):

| Dato | Valor |
|---|---|
| Pólizas AP / denuncias AP vinculadas | 30 / 63 |
| Clientes AP (`tipo_cliente=3`) / empleadores habilitados | 5 / 31 |
| Consumo real acumulado (`erogaciones.monto_facturado`) | aprox. $27.321 millones |
| Turnos realizados **con** estimado (`turnos.valor_prestacion`) | **5,37%** (159.384 de 2.967.213) |
| `turnos.costo` | muerto (>0 en 4 filas) |
| Precio de medicamento en el sistema | inexistente (`consumo_medicamentos` es código muerto) |

Restricciones que condicionan el diseño:

- **Universo chico, tablas grandes.** Solo 63 denuncias AP, pero el consumo vive en `turnos` (aprox. 4,3M) y `erogaciones` (1,15M). Filtrar por AP primero es lo que hace viable la consulta.
- **Cada dueño mantiene su dominio.** La póliza es de `wsmesacarga`; turnos/autorizaciones de `wsturnos`; erogaciones y auditoría de factura de `wsauditoriafacturacion`; tarifario/NBU y presupuestos de `wsconvenio`; materiales quirúrgicos de `wscirugias`; traslados de `wstraslados`/`wsauditoriatraslados`.
- **Contrataciones está separado por módulo, no por permiso.** `modulos_sas` id 8 no tiene perfiles colgados y `permisos_sas` no tiene permisos de presupuesto: AP no ve el consolidado de cirugía porque la pieza vive en otro MFE, no porque le falte un permiso.
- **Ya hay anclajes de topeo en el código.** `wsturnos` expone `POST /autorizaciones/dictaminar-autorizacion` (que invoca `persistirJustificacionTopeo`) y `GET /autorizaciones/consumo-cie10/{idDenuncia}`.

Interesados: **Verónica Marelli + Gabriel Centeno** (gestión y facturación: vigilan consumo, cierran y debitan) e **Iván + Bruno** (comercial y costos: definen el valor de venta por prestación y zona).

### Operatoria actual, según el relevamiento con negocio (reunión "Topeo AP", 16/07/2026)

- **El tope es por paciente, no grupal.** Cada asegurado de la póliza tiene su propia suma asegurada (el ejemplo dado: una empresa con 10 empleados asegura a cada uno por 5 millones). Un cliente puede tener **varias pólizas** (Suite Medical) o una sola (Woranz). Clientes AP actuales: **Colón, Suite Medical (dos razones sociales), Woranz**. La suma asegurada **incluye IVA** y la provee **comercial** (Bruno).
- **El control es manual y en planilla.** Facturación mantiene un archivo por cliente, con una hoja por paciente: gestión carga las prestaciones y facturación agrega el **valor unitario** y calcula el porcentaje consumido a mano.
- **Se factura mensualmente, mes vencido**, pero la vigilancia es continua: "voy a estar facturando lo del mes pasado, pero voy a estar mirando de que no se pase".
- **El excedente lo debita el cliente.** Si se factura por encima de la suma asegurada, el cliente paga hasta el tope y debita la diferencia: la pérdida la absorbe la empresa. Es el costo que este trabajo evita.
- **Secuencia al llegar al tope:** se avisa al cliente, el cliente pide que se avise al paciente, se lo llama, y **se cierra el siniestro**.
- **El riesgo se concentra en los quirúrgicos.** "El paciente que se opera llega en un abrir y cerrar de ojos al monto asegurado"; los de rehabilitación prolongada prácticamente nunca llegan.
- **Antes de aprobar una cirugía, el cliente pide el consumo acumulado** del paciente para ver si el presupuesto entra en el tope.
- **Erogaciones tardías:** los prestadores del interior facturan hasta dos meses después del alta (típicamente medicación), y ahí el consumo puede pasarse. Hoy se detecta cruzando a mano por documento contra un historial propio.
- **Turno no realizado no se factura.**
- **Zonas:** el valor depende de la zona **del prestador que atiende**, no del domicilio del paciente. Son cuatro: Buenos Aires/Santa Fe/Entre Ríos/Córdoba · Mendoza/San Juan/San Luis · Río Negro/Neuquén · centros propios. **El agrupamiento no existe todavía**: los prestadores están en el sistema, hay que clasificarlos.
- **Vigencias de la grilla:** comercial envía incrementos cada tres o cuatro meses; el valor que se aplica es el vigente **a la fecha de la prestación**.
- **Medicación:** el precio se consulta a mano en un portal externo que **no guarda historial**. Además la erogación llega con la leyenda genérica "medicación", sin detalle: cuando el cliente pide saber qué se entregó, hay que buscar en las facturas del portal.
- **Laboratorio y radiografías:** ya se valorizan por **multiplicador de la determinación × precio**; el multiplicador está cargado en el sistema de contratos y "lo único que hacemos es ponerle el precio". Laboratorio tiene muchísimas determinaciones; radiografías, unas diez.
- **Cirugías por presupuesto:** las que no están convenidas se acuerdan por mail entre comercial y el cliente, y su valor **no está en la grilla** — hay que poder cargarlo a mano.
- **Pedido explícito de negocio para facturar:** filtro por **cliente + período (desde/hasta)** y **marcado de lo ya rendido/prefacturado**, para no volver a facturarlo y evitar débitos por duplicado.

Fuente de diseño detallada: `docs/ap-costos/AP-Costos-SDD.md` (SDD de 16 secciones con el DDL completo).

## Goals / Non-Goals

**Goals:**

- Persistir el tope (suma asegurada con IVA, por paciente) y resolverlo al vincular denuncia con póliza.
- Agregar el consumo de las vías de prácticas/turnos, traslados y cirugía por siniestro, clasificado en Facturado / Devengado / Estimado.
- Exponer las **dos cifras** que gobiernan decisiones distintas: facturado (tope oficial → cierre y débito) y proyección (vigilancia → alerta de no autorizar más).
- Semáforo de 5 niveles con umbrales intermedios parametrizables, presente en el detalle del siniestro, en la vista agregada de cartera y en la grilla.
- Disparar el estimado al autorizar y completar el histórico por backfill, para que la proyección no sea ciega.
- Habilitar el perfil de gestor comercial de AP y la tabla de valor de venta por prestación y zona.
- Dejar medicación y laboratorio NBU visibles como **EN CONSTRUCCIÓN**, sin funcionalidad.

**Non-Goals:**

- Modificar el modelo de costo: `convenios` y `convenios_prestaciones_nomencladas` quedan read-only.
- Ingerir precios de medicamentos (feed Alfabeta) y valorizar laboratorio NBU: etapa 2.
- Facturación mensual completa, margen operativo y capa de IA asistiva.
- Cualquier presentación a la SRT: AP se rige por SSN / Ley 17.418.
- Duplicar el circuito de Contrataciones: el consolidado de cirugía se **expone**, no se reimplementa.

## Decisions

### D1 — Tope en tabla propia por paciente, con denormalización en el vínculo

**Decisión:** crear `polizas_ap_topes` con grano (póliza, documento del asegurado, ventana) y copiar la suma asegurada resuelta a `denuncia_poliza` al asociar.

**Por qué:** negocio confirmó que la suma asegurada es **por paciente** (cada asegurado tiene su tope) y se carga **con IVA**. Una columna en `polizas_ap` obligaría a un tope uniforme por póliza, que no representa la realidad. La denormalización en el vínculo evita resolver el documento del afiliado en cada consulta del semáforo, que es la operación más frecuente.

**Alternativas consideradas:** (a) `ALTER TABLE polizas_ap ADD suma_asegurada` — más simple, pero pierde el grano por paciente; queda documentada como fallback si negocio revierte el criterio. (b) Tabla de coberturas con sublímites por tipo de prestación — más expresiva, pero no hay requerimiento hoy y agrega complejidad sin uso.

### D2 — El semáforo se calcula por proyección; el cierre se decide por facturado

**Decisión:** el nivel del semáforo se computa sobre la **proyección** (F+D+E); la acción de cierre y débito se habilita por el **facturado**.

**Por qué:** son decisiones distintas con tolerancias distintas. La proyección puede incluir gasto que se cancele (un turno futuro), así que no puede gatillar un débito al cliente; pero es la única cifra que llega a tiempo para frenar autorizaciones. El facturado es la verdad contable y llega 1–2 meses tarde. Usar una sola cifra obliga a elegir entre avisar tarde o debitar de más.

**Alternativas consideradas:** un único total "mejor esfuerzo" (COALESCE de real y estimado) sin distinguir estados — es lo que insinuaba el diseño previo, pero mezcla certezas y no permite explicar al cliente por qué se debita.

### D3 — Anti-doble-conteo por origen del dato, no por conciliación posterior

**Decisión:** el facturado se toma **solo** de `erogaciones`; los turnos aportan únicamente mientras no tengan valor de facturación. Los materiales quirúrgicos se suman por cotización ganadora, una vez por grupo real, y por línea cuando el grupo es el centinela 0/nulo.

**Por qué:** `erogaciones` no tiene FK a la autorización (se ancla a `id_denuncia`), así que no se puede deduplicar por clave. Excluir por estado del dato es determinista y no requiere una tabla de reconciliación. En materiales, `monto_cotizacion` se repite en cada línea del mismo grupo: agrupar por grupo a secas **sub-cuenta** cuando el grupo es 0/nulo y conviven materiales distintos (caso verificado: un pedido perdía $33.000).

**Riesgo asumido:** la exclusión por `valor_facturacion IS NULL` supone que la auditoría estampa el valor y crea la erogación de forma atómica. Queda como pregunta abierta (Q1).

### D4 — El estimado se dispara al autorizar, reusando el patrón que ya existe

**Decisión:** poblar `turnos.valor_prestacion` con origen "convenio" en el alta/aprobación del turno, dentro de `wsturnos`, más un backfill idempotente por convenio vigente a la fecha del turno.

**Por qué:** es la precondición dura de todo el diseño: con 5,37% de cobertura, la proyección no ve el gasto en vuelo, que es justamente lo que hay que frenar. `wsturnos` ya tiene el patrón de seteo desde convenio y los anclajes de topeo, así que no hay que inventar un mecanismo nuevo.

**Alternativa considerada:** calcular el estimado al vuelo en la vista, resolviendo convenio por fecha en cada consulta. Se descartó: multiplica el costo de la consulta sobre 4,3M de turnos y deja el dato sin trazabilidad histórica (si el convenio cambia, el estimado pasado se reescribe solo).

### D5 — Vistas primero, materialización cuando el volumen lo pida

**Decisión:** implementar el motor como vistas SQL (`ap_consumo_prestacion`, `ap_consumo_siniestro`), acotadas por el universo AP; materializar `ap_consumo_siniestro` en tabla con refresh por evento y batch solo para la vista agregada de cartera si la medición lo justifica.

**Por qué:** con 63 denuncias el filtro por `denuncia_poliza` reduce el problema a un tamaño trivial; una tabla materializada desde el día uno agrega un mecanismo de refresco (y su riesgo de desincronización) sin beneficio medible. La vista se escribe con `GROUP BY` explícito para ser compatible con `ONLY_FULL_GROUP_BY` en cualquier ambiente.

### D6 — Medicación y laboratorio: carga manual en etapa 1, automatización en etapa 2

**Decisión:** las dos vías entran en la etapa 1 con **carga manual del valor**. Medicación: precio + descripción del medicamento, registrando fuente y fecha del precio usado. Laboratorio: se calcula por **multiplicador de la determinación × precio de la unidad**, con el precio cargable a mano. Los ítems sin valor se muestran como **pendientes de valorizar** y el consumo se marca "incompleto" mientras existan. Lo que se difiere a etapa 2 es la **automatización** (feed de precios y sincronización), no la funcionalidad.

**Por qué:** es exactamente lo que negocio hace hoy, y lo hace por fuera del sistema. Verónica consulta el precio en el portal externo y lo escribe en la planilla; el portal **no conserva historial**, así que registrar el precio usado en el sistema ya es una mejora por sí misma. En laboratorio el mecanismo del multiplicador **ya existe** en el sistema de contratos y solo falta el precio: replicarlo es barato y evita un mundo de determinaciones cargadas a mano. Dejar las dos vías fuera del total hubiera obligado a seguir con la planilla en paralelo justamente para los ítems que más se repiten.

**Alternativa considerada:** mantenerlas como sección "en construcción" sin funcionalidad (planteo inicial). Se descartó porque no elimina el trabajo manual actual: la persona seguiría cargando esos valores en la planilla, y el consumo del sistema nunca sería comparable con el real.

**Consecuencia asumida:** el consumo puede quedar incompleto si nadie carga los valores pendientes. Se mitiga mostrando el conteo de pendientes por vía y marcando el total como incompleto, en lugar de presentarlo como definitivo.

### D7bis — Suma asegurada obligatoria en el alta y editable después

**Decisión:** la suma asegurada es **dato obligatorio** para dar de alta una póliza AP (validado en backend, no solo en el formulario) y **editable** en la póliza vigente, con historial del cambio y propagación a los siniestros vinculados. Las pólizas AP preexistentes sin tope se exponen en un listado de pendientes.

**Por qué:** una póliza AP sin tope deja al siniestro sin control de consumo, que es justamente el problema que este trabajo resuelve; permitir el alta sin el dato reproduce el estado actual. Al mismo tiempo, el dato llega de comercial y puede corregirse, así que bloquear la edición sería peor. El listado de pendientes evita frenar la operación de las 30 pólizas ya cargadas.

### D7 — Perfil comercial como copia de permisos del analista, por SQL idempotente

**Decisión:** crear el perfil de gestor comercial de AP replicando exactamente los permisos activos de `analista_accidentes_personales` (13 y 18), con script transaccional y verificaciones previa/posterior.

**Por qué:** es el mismo criterio con el que ya se creó `gestor_accidentes_personales` (id 25), que hoy tiene esos mismos dos permisos: mantiene la paridad y evita discutir el conjunto de permisos base en esta etapa. Los permisos específicos de AP (semáforo, valor de venta, margen, consolidado de cirugía) se agregan como permisos nuevos, no alterando los heredados.

### D8 — Una sola escala: los niveles definidos, y los avisos en sus mismos cortes

**Decisión:** la escala del semáforo es la ya definida — **Bajo <40 · Medio 40-70 · Alto 70-90 · Muy alto 90-100 · Excedido >100**, con 40 y 70 parametrizables y 90 y 100 fijos. Los **avisos** se disparan al **cambiar de nivel hacia arriba** (ingreso a Alto, a Muy alto y a Excedido), y no en una serie separada de porcentajes. El aviso de cada nivel se puede habilitar o deshabilitar, y se registra una sola vez por nivel y siniestro.

**Por qué:** en el relevamiento negocio mencionó avisar al 80% y al 90%. Sostener dos escalas en paralelo (niveles de color por un lado, avisos por otro) obliga al usuario a razonar con dos criterios distintos sobre el mismo número, y produce situaciones confusas: un caso en nivel Alto que todavía no avisó porque no llegó al 80, y un aviso al 90 que coincide con un cambio de nivel. Con una sola escala, el color y el aviso dicen siempre lo mismo. El 80% que mencionó negocio queda cubierto: cae dentro del nivel **Alto** (70-90), que ya genera aviso — y de hecho avisa antes.

**Alternativa considerada:** mantener los cinco niveles y agregar hitos independientes en 80/90 (planteo intermedio). Se descartó por la duplicidad de criterios; si en la validación con Verónica resultara imprescindible el corte exacto en 80, se resuelve moviendo el corte parametrizable de Alto a 80 en lugar de sumar una escala nueva.

## Risks / Trade-offs

- **Backfill del estimado sobre tabla grande** → ejecutar por lotes en ventana de bajo tráfico, idempotente y reversible; revisar el script con el skill `mariadb-migration-review` antes de aplicar.
- **La atomicidad entre `valor_facturacion` y la erogación no está confirmada** → si no fuera atómica, una práctica podría contarse como devengada y facturada a la vez; mitigación: verificar el flujo de auditoría y, si hace falta, excluir también por existencia de erogación asociada al turno.
- **Semántica de IVA heterogénea entre vías** → el tope se carga con IVA; el consumo puede venir con o sin. Mitigación: documentar la regla por vía antes de codificar el numerador y dejar `iva_incluido` explícito en el tope.
- **Estimado de traslados sin motor vivo** → `convenios_traslados_valorizaciones` está dormida (última fila 2024-10-03, cero referencias en el backend): se recalcula por convenio (zona / monto fijo provincial / km) en lugar de leerla; la fórmula exacta debe confirmarse con negocio.
- **Cifras que se leen como completas cuando no lo son** → mientras medicación y laboratorio estén diferidas, la UI debe aclarar el alcance del total; sin ese aviso, un caso podría parecer lejos del tope estando cerca.
- **Universo de prueba muy chico y concentrado** → 63 denuncias, con una póliza concentrando la mayor parte del consumo: los tableros pueden verse vacíos o sesgados en ambientes bajos. Mitigación: casos de prueba sintéticos marcados y borrables.
- **Materialización prematura** → se posterga a propósito (D5); el riesgo inverso (consulta lenta en la vista agregada) se acota midiendo antes de optimizar.

## Migration Plan

1. **Perfiles** — script idempotente del perfil comercial + permisos nuevos de AP. Reversible por baja lógica (`activo=0`).
2. **DDL aditivo** — `polizas_ap_topes`, `valores_venta_prestacion`, `ap_semaforo_parametros` (con seed de umbrales 40/70) y las dos columnas nuevas en `denuncia_poliza`. Revisar con `mariadb-migration-review`. Rollback: `DROP` de lo nuevo y `DROP COLUMN` de lo agregado, sin pérdida de datos preexistentes.
3. **Carga del tope** — CRUD en `wsmesacarga` y carga de los topes reales de las pólizas vigentes por negocio. Hasta que un tope exista, el siniestro se informa `SIN_TOPE` (degradación explícita, no error).
4. **Estimado** — primero el disparo al autorizar (afecta solo turnos nuevos), después el backfill por lotes del histórico. Este orden deja verificar el mecanismo nuevo antes de tocar el histórico.
5. **Vistas y endpoints** — crear las vistas, exponer los endpoints con chequeo de permisos en backend.
6. **Frontend** — sección de costos y topeo, cabecera, vista agregada, grilla y pantallas del perfil comercial; secciones diferidas marcadas EN CONSTRUCCIÓN.

Cada paso es independiente y desplegable por separado; nada de lo anterior queda inconsistente si el paso siguiente se demora.

## Open Questions

Las preguntas de operatoria que estaban abiertas quedaron **respondidas en el relevamiento del 16/07** y están incorporadas al Context (grano del tope, IVA, secuencia de aviso y cierre, débito del excedente, erogaciones tardías, zonas, vigencias, laboratorio por multiplicador, presupuestos, filtro por cliente y período). Lo que sigue abierto:

**Técnicas (no requieren a negocio):**

- **Q1** — ¿La auditoría estampa `turnos.valor_facturacion` y crea la erogación en la misma transacción? Define si la regla anti-doble-conteo de D3 alcanza o hay que reforzarla.
- **Q2** — ¿Qué fuentes traen el consumo con IVA y cuáles sin? El tope se carga con IVA, así que el numerador debe normalizarse; hay que documentar la regla por vía antes de codificar.
- **Q3** — ¿Dónde vive el motor de consumo: un ws nuevo o `wsturnos` (que ya tiene el topeo y `consumo-cie10`)? Recomendación: `wsturnos` para consumo/semáforo, dominio propio para el valor de venta. A validar con arquitectura.
- **Q4** — Fórmula exacta del estimado de traslados (zona / monto fijo provincial / km) dado que el motor de valorización está dormido. Negocio confirmó que hoy, cuando el traslado no tiene monto, se estima por convenio con la agencia más un porcentaje.

**De negocio, todavía sin respuesta:**

- **Q5** — **Ventana del tope:** ¿la suma asegurada aplica por siniestro/evento, o es un límite anual o por vigencia de póliza? Si un asegurado tiene dos siniestros en la misma vigencia, ¿cada uno cuenta con el tope completo? Define el campo `ventana` de `polizas_ap_topes`.
- **Q6** — **¿El tope se puede ampliar** durante la vida del siniestro (cliente que autoriza excederlo)? ¿Quién lo aprueba y cómo se registra?
- **Q7** — **¿El sistema debe impedir autorizar** cuando la proyección supera el tope, o solo avisar y dejar la decisión en la persona? Negocio describió el cierre del siniestro, pero no si el sistema debe bloquear.
- ~~**Q8** — Hitos de aviso en 80/90 vs niveles de la maqueta.~~ **RESUELTA (30/07):** se mantiene **una sola escala**, la de los niveles ya definidos (Bajo <40 · Medio 40-70 · Alto 70-90 · Muy alto 90-100 · Excedido >100). Los avisos se disparan **en los cortes de esa escala** (ingreso a Alto, Muy alto y Excedido), no en una segunda serie de porcentajes. Ver decisión D8. Queda para comentarle a Verónica que el 80% que mencionó cae dentro del nivel Alto (70-90), que ya avisa.
- **Q9** — **¿El valor de venta varía por cliente**, además de por prestación y zona? Negocio mencionó "lo que yo acordé con el cliente", lo que sugiere que sí; la grilla mostrada era por zona. Define si `valores_venta_prestacion` necesita cliente como dimensión (se puede prever la columna sin usarla).
- **Q10** — **Cómo llegan los topes desde comercial** (planilla, mail) y si hace falta **importación masiva** o alcanza la carga en la pantalla de la póliza. Para Suite Medical existe además una nómina que administra el CEM.
- **Q11** — ¿Qué **reportes** le piden a gestión desde jefatura o gerencia, y con qué periodicidad? Para que el módulo los genere en lugar de armarlos a mano.

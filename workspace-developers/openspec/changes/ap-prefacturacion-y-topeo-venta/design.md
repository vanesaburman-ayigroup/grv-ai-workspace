## Context

La etapa 1 de AP (change `ap-costos-topeo-etapa1`) dejó andando el control del tope: el servicio `wsaccidentespersonales`, el motor de consumo con las nueve vías, el semáforo de cinco niveles, la resolución del tope en vivo (`EXCEPCION → GENERAL → SIN_TOPE`), los ABM de topes y de valores manuales, y la sección "Costos y Topeo" en el detalle del siniestro. En stage hay 61 denuncias AP activas, 57 con tope y 4 sin ninguno; en producción todavía no hay nada (`polizas_ap` sigue con sus diez columnas originales, sin ninguna de monto).

La reunión del 20/08/2026 con comercial y facturación de AP corrigió el modelo en dos puntos que no son de detalle.

### Lo que cambió, en una tabla

| | Etapa 1 (implementado) | Definición del 20/08/2026 |
|---|---|---|
| Base del consumo | **costo**: convenio con el prestador, cotización, factura del prestador | **valor de venta** del contrato con el cliente |
| IVA | consumo normalizado a "con IVA" por fuente (ya hecho el 20/08) | igual: venta **+ 21%**, sin exentas |
| Factura del prestador | **es** el facturado (numerador oficial) | es **costo** (margen) y **detector de erogaciones tardías**; se convierte a venta al entrar |
| Devengado vs. prefacturado | no existe el concepto de prefacturado | **la misma categoría**: el lote es un atributo, no un estado de confianza |
| Facturado | la erogación del prestador | lo que **se le facturó al cliente** |
| Avisos | uno por cada cambio de nivel hacia arriba (Alto / Muy alto / Excedido) | **uno, al 90%**, a los tramitadores que cargan autorizaciones y a auditoría médica |
| Al 100% | avisa y no bloquea; bloqueo activable por parámetro | **cierra el siniestro y bloquea autorizaciones nuevas** |
| Valor de venta | por prestación × zona, **sin** cliente | por **cliente** × prestación × **zona opcional** |
| Prefacturación al cliente | fuera de alcance | **es el corazón de este change** |

### Estado verificado del código

El numerador actual, tal como está en `MotorConsumoSql.MOTOR` (transcripción exacta de `sql/queries/motor-consumo-ap.sql`; los dos son el mismo contrato):

```sql
facturado AS (
    ...  SUM(COALESCE(e.monto_facturado, 0) - COALESCE(e.monto_debitado, 0)) AS monto
```

y las vías de convenio entran multiplicadas por el factor de IVA que liga el repositorio:

```sql
CAST(COALESCE(dt.monto, 0) * :factorIva AS DECIMAL(16,2)) AS devengado_turnos,
```

Es decir: **costo × 1,21**. Ninguna de las nueve vías lee un valor de venta, y no puede: `grep -ril "valores_venta\|valorVenta\|valor_venta"` sobre `repos/grvx/backend/wsaccidentespersonales/src` no devuelve nada, y la tabla no existe en ninguno de los dos ambientes.

Del lado de la prefacturación al cliente, el estado es "no existe":

- Las 29 tablas de `cs` con "factur" en el nombre son del lado del proveedor. `erogaciones` no tiene columna de cliente; `facturas` cuelga de `id_proveedor_servicio_traslado`.
- El catálogo de estados de facturación tiene cuatro filas: No Aplicable, No Facturado, Facturado, Facturado Pendiente Revisión. **Ninguna es "prefacturado"**, y las cuatro hablan de la factura *del prestador*.
- Las tres tablas de prefacturación (`traslados_prefacturaciones` 31, `convenios_traslados_prefacturaciones_traslados` 573, `convenios_traslados_prefacturacion_peajes` 0) son de traslados, hacia el proveedor, y la última fila es del 3/10/2024.
- `consumo_medicamentos.id_pre_facturacion` apunta a una tabla que no existe.
- `grep -ril prefactur` sobre `repos/grvx/backend` devuelve exactamente esas dos cosas.

Del lado del front ya construido, las constantes son fijas y este change las respeta: `CORTE_AVISO = 90`, `CORTE_TOPE = 100`, colores por estado (`FACTURADO #2e7d32`, `DEVENGADO #e07a00`, `ESTIMADO #d32f2f`), los seis niveles y los cuatro `MOTIVOS_HABILITACION_CIERRE`, de los cuales **solo `FACTURADO_ALCANZA_TOPE` habilita**.

### La operatoria real, según la reunión del 20/08/2026

- **La facturación al cliente es mensual, mes vencido, y hoy es manual.** Planeamiento exporta de la base las prestaciones del mes y la persona de facturación de AP arma la factura en Excel: *"me saca todas las consultas que tienen fecha de julio y me la mando el cinco de agosto seis de agosto y yo trabajo sobre eso"*.
- **La fecha que manda es la de realización, no la de carga.** Textual: *"no con fecha de carga, porque la fecha de carga cambia. Sería con fecha de realización de la consulta. Y ahí facturo"*. El caso que lo obliga: el gestor se entera el 15 de una consulta del 1° y la carga con fecha de realización del 1°.
- **No espera la factura del prestador para facturarle al cliente.** *"No obligatoriamente yo no espero eso para facturar"*. La factura del prestador llega uno, dos o tres meses después.
- **La factura del prestador sirve para descubrir lo que nadie informó.** *"Me factura tres veces tres consultas pero me agrega dos RX dos radiografías y que le dieron medicación. Entonces yo ahora tengo que comparar lo que yo facturé con lo que me llegó la erogación y decir che me faltó facturar esto... porque el centro médico nunca me avisó"*. Y después: *"ahí facturo lo que me faltó"* — se factura aparte.
- **Las masivas llegan sueltas.** *"Presentamos un proyecto para que deje de ser libre la masiva y esté asociado... a una autorización"*. Para medicación no hay a qué colgarse: *"me parece que no cargan autorizaciones de la medicación... el centro médico no le pide che autorizame un ibuprofeno, no lo hace"*, y a lo sumo hay una orden médica en la evolución.
- **El presupuesto aprobado suma al consumo y la cancelación lo saca.** *"Alguna instancia donde Bruno o el gestor o quien sea le ponga que está aprobado para que pueda sumar ese valor del presupuesto... al cambiarle el estado a esa autorización tendría que volar ese precio"*.
- **Al llegar al tope se cierra el siniestro.** *"Se cierra directamente el siniestro. Estaría bueno bloquear las autorizaciones... cuando llegó al monto asegurado o cuando está en un 90% tipo que tira algún cartel"*.
- **El tope es con IVA y el contrato sin IVA.** *"El tope asegurado es cinco millones es cinco millones con el IVA"*; *"para hacer el topeo tenés que vos sumarle a todas las prestaciones el 21"*; *"no se incluye el valor del IVA. El IVA después lo ponen"*; y sobre exentas, *"no, no, no, en este caso no"*.
- **El valor de venta se pacta por cliente y la zona no siempre aplica.** *"Tenemos distintos valores de venta para distintos clientes de acuerdo a lo que tengamos pactado"*; *"puede ser que no esté separada por zona"*. Los aumentos son lineales por porcentaje sobre toda la grilla del cliente, con excepciones puntuales negociadas, y el criterio habitual es IPC acumulado.
- **Los contratos vencen y hay que salir a renegociar.** *"Si yo pongo que es hasta el mes nueve, me avisa un mes antes"*, y el canal es el home: *"en el home directamente lo vemos ahí cuáles son los contratos que tenemos que actualizar"*.
- **La medicación se mira en Kairos con descuento propio.** *"Nosotros hacemos más fácil el menos 20 menos 15 y ya está"*, y hoy la revisión es manual y sin historial.
- **Laboratorio se valoriza por multiplicador, pero contra la grilla del cliente.** *"Debería tomar el valor que está en la grilla del valor venta de acuerdo al cliente... finalmente va a decir laboratorio por NBU y va a decir no sé 340, y eso después tiene que multiplicarlo por todas las unidades"*.
- **La persona que hace todo esto es una.** *"Es ella, Vivi, es Viviana, que hace todas las AP"*. El diseño no puede suponer un equipo repartiendo lotes.
- **El cliente entra al portal a buscar el respaldo.** *"Los clientes de AP tienen el usuario para poder ver información y hay veces que nosotros vemos que tenemos que facturar algo que no está el informe y sabemos que podemos reclamarle al gestor"*.

## Goals / Non-Goals

**Goals:**

- Cambiar la base de valorización de las tres instancias del consumo a **valor de venta del contrato del cliente + 21% de IVA**, dejando el costo donde sirve: margen y detección de erogaciones tardías.
- Modelar la **prefacturación al cliente** de punta a punta hasta el marcado de facturado: listado por fecha de realización, lote de un solo cliente, totales con subtotal sin IVA + IVA + total, reversibilidad, trazabilidad y descargas.
- Hacer explícitas las **tres vías de entrada** de una prestación al siniestro y el concepto de **erogación tardía**, con su lote aparte.
- Dejar un solo criterio de alerta y cierre: **90% avisa, 100% cierra y bloquea**, con el cierre habilitado únicamente por facturado.
- Dar al perfil de prefacturación un **home** que le diga qué hacer cuando entra a la mañana, y un panel de pacientes a vigilar.
- Resolver el precio de venta de la **medicación** con el criterio que negocio ya usa (Kairos menos su descuento), con la antigüedad del precio como dato visible.
- Extender el **valor de venta** a cliente × prestación × zona opcional, con duplicación de estructura entre clientes y aumento masivo con exclusiones.

**Non-Goals:**

- **Emitir la factura fiscal.** El módulo termina en el detalle prefacturado y el marcado de facturado; la emisión se hace por ARCA fuera del sistema.
- **Cerrar la denuncia desde este ws.** El cierre es de `wstramitador`; AP aporta el hecho de que el facturado alcanzó el tope.
- **El circuito de presupuestos de cirugía con adjuntos seleccionables.** Pedido de la misma reunión, alcance propio, change aparte.
- **El mapa prestador → zona.** Sigue pendiente de definición de comercial; el modelo lo prevé, el dato no se inventa.
- **Alícuotas de IVA diferenciadas.** Negocio confirmó 21% sin exentas.
- **Rehacer el modelo de costo.** `convenios`, `erogaciones` y la auditoría de facturación siguen siendo de sus dueños y se leen, no se modifican.
- **Reutilizar la prefacturación de traslados.** Es del lado del proveedor y de otro dominio.

## Decisions

### D1 — El numerador pasa a valor de venta; el costo no desaparece, cambia de rol

**Decisión:** las tres instancias (estimado, devengado y prefacturado, facturado al cliente) se valorizan con el **valor de venta vigente del contrato del cliente a la fecha de realización**, más 21% de IVA. El costo (convenio, cotización, factura del prestador) deja de ser el numerador del semáforo y queda como (a) término del margen y (b) fuente de descubrimiento de erogaciones tardías.

**Por qué:** el tope que el cliente contrató está expresado en lo que se le cobra, no en lo que nos cuesta. Comparar costo contra un tope de venta es comparar dos monedas distintas: el error no tiene signo fijo —depende del margen de cada prestación— así que no se puede corregir con un coeficiente. Y el excedente que el cliente debita se calcula sobre lo facturado, que es venta.

**Consecuencia asumida:** cuando no hay valor de venta cargado para la prestación y el cliente, el ítem **no se puede valorizar**. Se informa como pendiente de valorizar y se cuenta en `consumoIncompleto`, con el mismo criterio que ya usa el motor: nunca cero, porque un cero se lee como verde. Esto va a ser el estado inicial de casi todo hasta que comercial cargue las grillas.

**Alternativa considerada:** mantener el costo como numerador y exponer la venta solo para margen. Se descartó: deja el semáforo midiendo la pregunta equivocada, que es exactamente el problema que este change corrige.

### D2 — La conversión de la factura del prestador a valor de venta se persiste al entrar, no se calcula al vuelo

**Decisión:** cuando una erogación aporta una prestación al siniestro (asociada por número de autorización, o libre por DNI), su conversión a valor de venta se resuelve y **se guarda** en el ítem de consumo del siniestro, con la referencia al valor de venta aplicado y su vigencia. El motor lee ese ítem; no re-resuelve el contrato en cada consulta.

**Por qué:** el valor de venta tiene vigencias y la resolución es por fecha de realización. Si se calcula al vuelo, un aumento de grilla reescribe hacia atrás el consumo de meses ya facturados, y el número que la pantalla muestra deja de coincidir con el que se le cobró al cliente. Además el motor ya paga el costo de cruzar `turnos` (~4,3M) y `erogaciones` (~1,15M): agregarle la resolución de contrato por fila lo empeora sin beneficio.

**Alternativa considerada:** resolver en la vista con un `LEFT JOIN` al contrato vigente por fecha. Es el mismo error que se descartó en la etapa 1 para el estimado de turnos (D4 de ese design), por las mismas dos razones: costo de consulta y pérdida de trazabilidad histórica.

### D3 — Devengado y prefacturado son la misma categoría; el lote es un atributo, no un estado de confianza

**Decisión:** los estados de confianza siguen siendo **tres**. "Estar en un lote de prefacturado" es un atributo del ítem (en qué lote está, con qué estado de prefacturación), ortogonal al estado de confianza. Un ítem devengado puede estar suelto o dentro de un lote, y en los dos casos suma al devengado.

**Por qué:** el estado de confianza responde "¿cuán seguro es que esta plata se gastó?" y el lote responde "¿ya lo presentamos al cliente?". Son dos preguntas independientes: meter el lote en la escala de confianza produciría cuatro capas en el gráfico, una de ellas sin significado propio, y obligaría a mover un ítem de capa por una acción administrativa que no cambió nada del gasto. El front ya tiene tres colores fijos por estado y una escala de tres capas: agregar una cuarta rompe una decisión de diseño ya tomada.

**Alternativa considerada:** cuatro capas (estimado / devengado / prefacturado / facturado). Se descartó por lo anterior, y porque el propio pedido de negocio distingue solo dos momentos que cambian la certeza: se realizó, y se le cobró al cliente.

### D4 — Estados de prefacturación en modelo propio, no sobre el catálogo del proveedor

**Decisión:** los tres estados (**pendiente de facturar → prefacturado → facturado al cliente**) viven en el modelo nuevo de prefacturación. **No** se agregan filas al catálogo de estados de facturación existente ni se reutiliza `traslados_prefacturaciones`.

**Por qué:** el catálogo de cuatro filas describe la factura *del prestador* y lo consume la auditoría de facturación, que es de otro ws. Agregarle un quinto estado que significa algo del lado del cliente convierte una lista de valores con un significado en una lista con dos, y el primer consumidor que la lea sin saberlo va a mezclar direcciones de plata opuestas. Ese error ya tiene precedente en el dominio: es la razón por la que la palabra "facturación" en una reunión de AP significa dos cosas incompatibles. La prefacturación de traslados, por su lado, tiene `id_proveedor_servicio_traslado` como contraparte: no es reutilizable ni conceptual ni estructuralmente.

### D5 — Un lote, un cliente; las tardías van en lote aparte

**Decisión:** un lote de prefacturado pertenece a **exactamente un cliente**, y filtrar por cliente es **precondición** para poder generarlo (el botón no se habilita sin cliente elegido). Las erogaciones tardías de ese cliente van en un **lote separado**, marcado como tal.

**Por qué:** el lote es el borrador de una factura, y una factura tiene un solo destinatario. Mezclar clientes en un lote produce un documento que no se puede emitir y un total que no significa nada. Y las tardías se facturan aparte porque corresponden a períodos ya cerrados: si se meten en el lote del mes corriente, el cliente ve un período que no coincide con el detalle y la discusión termina en un débito.

### D6 — Un valor mal cargado se corrige en el contrato, no en el ítem

**Decisión:** cuando prefacturación detecta un valor equivocado, la corrección se hace en el **contrato** (perfil comercial) y baja automáticamente a **todo lo no facturado**. Lo ya facturado al cliente **no** se re-valoriza: queda con el valor que se le cobró. El ítem no se edita a mano.

**Por qué:** es el circuito real —*"tendría que hablar con Bruno para decirle mirá que me trajo dieciocho mil y..."*— y es el único que no crea dos fuentes de verdad. Si el ítem se pudiera editar suelto, el mismo error se arreglaría caso por caso para siempre, el contrato seguiría mal, y no habría forma de explicar por qué dos prestaciones iguales del mismo mes se cobraron distinto. Congelar lo facturado es igual de importante: la factura ya salió y el cliente la tiene.

**Consecuencia asumida:** la corrección depende de otra persona y de otro perfil. Se mitiga con el aviso en el home y con la reversibilidad del lote (se saca el ítem, se corrige el contrato, se vuelve a incluir).

### D7 — Prefacturación se avisa; al gestor no se lo bloquea

**Decisión:** si un gestor cancela una prestación ya prefacturada o cambia su valor, la operación del gestor **sigue**, y prefacturación **recibe un aviso** con qué cambió y sobre qué lote. Desde ahí decide: sacar el ítem del lote o aceptar el valor nuevo.

**Por qué:** el gestor cancela porque la prestación no se hizo, o porque se equivocó de paciente. Bloquearlo para proteger un borrador administrativo deja el dato mal en el sistema, que es peor. Y el pedido de negocio fue de aviso, no de bloqueo: *"de las prefacturadas hay cinco consultas que se cancelaron"*. El antecedente que se quiere evitar es el del sistema anterior, donde el bloqueo obligaba a pedir permiso: *"ya tiene una prefactura, no puedo modificarte nada y los chicos me piden permiso"*.

**Alternativa considerada:** advertencia bloqueante con override, como se hace con los datos que ya viajaron a la SRT. Se descartó: ahí lo que se protege es un dato presentado a un organismo regulador, no un borrador interno reversible.

### D8 — Un solo corte de aviso (90%) y el cierre al 100%, que este ws no ejecuta

**Decisión:** el aviso se dispara **al 90%** de la proyección, una vez por siniestro y por tope vigente, dirigido a los **tramitadores que cargan autorizaciones** y a **auditoría médica**. Al **100%** se cierra el siniestro y se bloquean autorizaciones nuevas. El **cierre por facturado** se habilita solo con `FACTURADO_ALCANZA_TOPE`; con `PROYECCION_SOBRE_TOPE_FACTURADO_POR_DEBAJO` no habilita y la pantalla explica que esa plata todavía no se facturó. El ws **no cierra la denuncia**: expone el hecho, y el cierre lo ejecuta `wstramitador`.

**Por qué:** reemplaza el criterio de la etapa 1 (un aviso por cada cambio de nivel hacia arriba, D8 de ese design) por el que negocio pidió textualmente, y que además ya está escrito en el front como `CORTE_AVISO = 90` / `CORTE_TOPE = 100`. Un aviso por nivel produce ruido en los tramos bajos —entrar a "Alto" con el 71% no es una noticia— y el destinatario importa: el aviso sirve si llega a quien está a punto de autorizar. Que el cierre viva en `wstramitador` no es una elección de este change: es dónde está el proceso que escribe `cs.cierres_denuncias_log`, dispara el proceso de incapacidad y notifica a Mulesoft.

**Consecuencia asumida:** los niveles del semáforo siguen siendo cinco y siguen sirviendo para leer la cartera, pero dejan de ser el disparador del aviso. `ap_avisos_nivel_siniestro` pasa a registrar el aviso del 90%, no uno por nivel.

### D9 — Kairos: el precio de referencia con descuento, con la antigüedad como dato de primera clase

**Decisión:** el valor de venta de un medicamento se construye como **precio de referencia de Kairos menos el descuento propio** (habitualmente 15% o 20%, cargable y con historial), y eso es el valor de venta **sin IVA**. Se registra siempre la fecha del precio de referencia, y el sistema avisa a los **30** y a los **90** días. La **integración con la API de Kairos es un spike**: se investiga la viabilidad y, si sale, reemplaza la carga manual sin cambiar el modelo.

**Por qué:** es exactamente lo que se hace hoy (*"nosotros hacemos más fácil el menos 20 menos 15 y ya está"*), y hacerlo dentro del sistema ya aporta lo que hoy falta: el historial del precio usado. El aviso por antigüedad es el sustituto honesto de la integración mientras la integración no exista, y funciona igual si nunca existe. Comprometer la API en el alcance sería comprometer una dependencia de un tercero sobre la que no hay contrato ni documentación verificada.

### D10 — El valor de venta agrega cliente y la zona pasa a ser opcional

**Decisión:** la clave del valor de venta es **cliente + prestación + zona opcional + vigencia**. Un contrato puede tener valores zonificados o un único valor sin zona. Se suman: cargar la grilla por cliente, **duplicar la estructura** de un contrato a otro cliente, **aumento masivo por porcentaje con exclusiones**, y descarga del contrato en Excel.

**Por qué:** revierte la decisión de la etapa 1 (*"el valor de venta no varía por cliente"*, en las notas de tasks de ese change) contra lo que negocio dijo el 20/08: *"tenemos distintos valores de venta para distintos clientes de acuerdo a lo que tengamos pactado"* y *"puede ser que no esté separada por zona"*. La duplicación existe porque las prestaciones son casi siempre las mismas y tipearlas de nuevo por cliente es el trabajo que se quiere eliminar. El aumento masivo con exclusiones es el flujo real: porcentaje lineal a toda la grilla, con algún ítem negociado aparte.

**Anotado:** el redondeo quedó como opción a evaluar, no como requisito, porque negocio señaló su efecto acumulativo entre aumentos sucesivos y prefirió tenerlo disponible antes que decidido.

### D11 — La fecha de realización es la que manda

**Decisión:** el listado, el armado del lote y la definición de erogación tardía se apoyan en la **fecha de realización** de la prestación. La fecha de carga existe como filtro adicional, nunca como criterio de período.

**Por qué:** *"no con fecha de carga, porque la fecha de carga cambia"*. El caso que lo obliga es cotidiano: una consulta del 1° de julio cargada el 15 con fecha de realización del 1°. Si el período se define por fecha de carga, esa prestación cae en el mes equivocado y aparece como faltante en un mes y como duplicada en el otro.

### D12 — Antes de tocar el numerador, se congela la línea base

**Decisión:** el primer paso del trabajo de backend es **regenerar la foto de paridad de stage** (`src/test/resources/fixtures/motor-consumo-stage.json`, vía `generar-motor-consumo-stage.py`) y dejar registrado el consumo actual de las 61 filas AP. El cambio de numerador se mide contra esa foto, fila por fila, y el delta se documenta antes de mergear.

**Por qué:** es el procedimiento que ya se usó con el fix de IVA del 20/08, y ahí se pudo afirmar con números que el cambio movía la magnitud del excedente (+42,2%) sin mover la clasificación de ningún caso. Sin la foto previa, el cambio de numerador es un cambio a ciegas sobre la cifra que decide cuánta plata se le puede seguir gastando a un paciente. Y hay un detalle operativo: `MotorConsumoParidadStageTest` queda **inválido por definición** el día que el numerador cambie, así que hay que regenerarlo a propósito y no descubrirlo como un test rojo.

## Risks / Trade-offs

- **El numerador cambia para todos los siniestros AP a la vez.** Es el riesgo principal. Mitigación: la secuencia de D12 (foto previa, delta medido fila por fila, comparación de niveles antes/después), y desplegar el motor nuevo con las grillas de venta ya cargadas al menos para el cliente con más consumo. La cartera de stage está polarizada (48 de 61 casos por debajo del 5% del tope, 3 ya excedidos, el caso más cerca de un corte a 3,67 puntos), así que el delta medido en stage **subestima** el riesgo en producción: no se puede concluir "no cambia ningún nivel" y quedarse tranquilo.
- **Sin grilla de venta cargada no hay consumo valorizable.** Casi todo el universo va a arrancar como pendiente de valorizar. Mitigación: reusar el mecanismo que ya existe (`consumoIncompleto` + `itemsPendientesDeValorizar` por vía) y **no** rellenar con el costo como aproximación: un número plausible y falso es peor que un pendiente visible.
- **Doble conteo entre la erogación convertida y la prestación ya cargada.** Es el mismo riesgo que resuelven las reglas R1..R5 del motor, pero con una vuelta nueva: una erogación libre pegada solo al DNI puede corresponder a una prestación que el gestor sí cargó. Mitigación: el match por número de autorización (cuando exista) es la vía prolija; mientras no exista, la conversión de una erogación libre se marca como tal y la revisión es explícita, no automática. El precedente está en `ap_valores_manuales`, donde `computa_consumo` se apaga cuando llega `idErogacion` y un `CHECK` de base lo garantiza.
- **La regla anti-doble-conteo asume atomicidad que no está confirmada.** Sigue abierta de la etapa 1: si la auditoría no estampa `turnos.valor_facturacion` y crea la erogación en la misma transacción, una práctica puede contarse como devengada y facturada a la vez.
- **La carga masiva resta el débito dos veces.** El SP de `wsauditoriafacturacion` graba `monto_facturado` **ya neto del débito** y además graba `monto_debitado`, así que la CTE `facturado` se lo resta de nuevo en las filas con `carga_masiva = 1`. Hoy no mueve ningún número AP (las 41 masivas del universo AP de stage tienen débito en cero), pero empuja el facturado hacia abajo. La corrección es del lado del SP, que es de otro ws.
- **Traslados sigue siendo la vía floja.** Cero traslados en el universo AP de stage, y sus montos los escribe el circuito de facturación, no una tabla de convenio: no está verificado que vengan netos. Con el cambio a valor de venta el problema se traslada igual: hay que definir si un traslado se vende por contrato o se factura al costo con recargo.
- **El margen exige costo y venta al mismo grano.** Si la venta se resuelve por prestación del contrato y el costo llega agregado en una línea de factura, el margen solo se puede calcular al nivel al que los dos existan. Conviene decir a qué nivel se promete antes de dibujar la pantalla.
- **Una sola persona opera todo el módulo.** No hay reparto de lotes ni segunda revisión: cualquier flujo que dependa de "que otro lo confirme" no tiene quién lo haga. El diseño tiene que ser recuperable por la misma persona (todo reversible hasta facturar).
- **Kairos es una dependencia de un tercero.** Si la API no existe o no se consigue acceso, el módulo sigue funcionando con carga manual y avisos de antigüedad: eso es deliberado, no un plan de contingencia improvisado.
- **Alícuota única de IVA.** Negocio confirmó 21% sin exentas, y la constante es una sola. Pero el dato dice otra cosa en un rincón: `pedidos_materiales_quirurgicos_cotizaciones.iva_seleccionado` tiene 1.856 filas en 21,00, **8 en 10,00 y 1 en 4,00** (ninguna toca el universo AP hoy). Si esto se vuelve material, la salida es leer la tasa de la fuente, nunca un segundo número mágico.
- **El fixture de paridad y el mapeo posicional.** `ConsumoApRepository.aConsumoCrudo` mapea la fila del motor **por posición**: agregar una columna al SELECT sin agregarla ahí, en la misma posición, corre todo el resto. Es la trampa más fácil de pisar en este change.

## Migration Plan

1. **Línea base.** Regenerar la foto de paridad de stage y documentar el consumo actual de las 61 filas AP (D12). Sin este paso no arranca nada del motor.
2. **Modelo del valor de venta con cliente.** DDL de la grilla (cliente + prestación + zona opcional + vigencia + versionado copy-on-write) y su historial. Aditivo, sin `ALTER` sobre tablas grandes. Revisión con `mariadb-migration-review`.
3. **Carga de grillas.** ABM del valor de venta, duplicación de estructura entre clientes, aumento masivo con exclusiones y descarga en Excel. Hasta que haya grillas, el paso 5 no tiene con qué valorizar.
4. **Modelo de prefacturación.** DDL del lote, sus ítems, la marca de tardía y la bitácora de movimientos. Independiente del paso 5: se puede desplegar antes.
5. **Motor con numerador de venta.** Cambio en `MotorConsumoSql.MOTOR` y en `sql/queries/motor-consumo-ap.sql` **a la vez** (son el mismo contrato), más `ResolucionTopeApServiceImpl` si toca la resolución. Delta medido contra la foto del paso 1, fila por fila, con la comparación de niveles antes/después.
6. **Conversión de la erogación a venta.** Persistencia del ítem convertido con su referencia de valor de venta, y el marcado de tardía.
7. **Avisos y cierre.** Cablear el aviso del 90% a los destinatarios definidos (hoy `registrarAvisoSiCorresponde` está implementado y testeado y **no lo invoca nadie**), y el bloqueo de autorizaciones nuevas al 100% en el punto donde nace la autorización.
8. **Endpoints y permisos.** Los endpoints nuevos con `permisoGuard.requerir(...)` como primera línea, más el alta de los permisos en `cs.permisos_sas` de cada ambiente por `/configurar-sas`. Recordar que los permisos viajan en la cookie `datos_usuario`: **exigen re-login**.
9. **Frontend.** Listado, lote y home del módulo de prefacturación; ajuste del copy de la sección "Costos y Topeo" para decir que el consumo está expresado en valor de venta; `npm run lint` y typecheck del MFE.
10. **Medicación.** Precio de referencia con descuento y avisos de antigüedad; el spike de la API de Kairos, en paralelo y sin bloquear.

Cada paso es desplegable por separado y ninguno deja inconsistente al anterior. El orden 2 → 3 → 5 no es negociable: cambiar el numerador antes de tener grillas cargadas convierte todo el universo en pendiente de valorizar de golpe.

## Open Questions

**Cerradas en la reunión del 20/08/2026** (quedan en el Context, no acá): base de valorización, IVA del tope y del contrato, ausencia de exentas, fecha de realización como criterio de período, un lote por cliente, tardías aparte, aviso al 90% y cierre al 100%, aviso sin bloqueo hacia el gestor, corrección por contrato, cliente como dimensión del valor de venta, zona opcional, descuento de Kairos, aviso un mes antes del vencimiento de contrato.

**De negocio, abiertas:**

- **Q1 — ¿Qué es "un período ya facturado" con precisión?** La definición de erogación tardía depende de eso. Candidatos: el período del último lote facturado de ese cliente, o el último mes cerrado. Cambia qué se marca como tardía y qué entra en el lote corriente.
- **Q2 — ¿La medicación se vende por grilla o al costo con recargo?** Kairos menos el descuento da un precio, pero no está dicho si ese precio ES el valor de venta al cliente o si además pasa por la grilla del contrato. Define si la medicación necesita fila en la grilla o no.
- **Q3 — ¿Los traslados se venden por contrato?** Hoy no hay valor de venta de traslados y el costo lo escribe el circuito de facturación. Sin definición, la vía queda sin poder valorizarse en venta.
- **Q4 — ¿Laboratorio: el valor de la unidad NBU de venta sale de la grilla del cliente?** Negocio dijo que sí (*"debería tomar el valor que está en la grilla del valor venta de acuerdo al cliente"*), pero falta confirmar si la unidad NBU es una fila más de la grilla o una tabla propia, y qué pasa con las determinaciones sin multiplicador.
- **Q5 — ¿A quién exactamente llega el aviso del 90%?** "Los tramitadores que cargan autorizaciones" y "auditoría médica" son roles, no destinatarios: hay que resolverlos a perfiles o permisos concretos, y definir el canal (aviso en pantalla, novedad, mail).
- **Q6 — ¿El bloqueo al 100% admite override con justificación?** El topeo que ya existe en el sistema lo admite. Si acá no, es la primera vez que el bloqueo es duro, y conviene decirlo explícitamente.
- **Q7 — ¿Qué pasa con un ítem ya facturado al cliente cuya prestación después se cancela?** No se puede sacar de una factura emitida. ¿Nota de crédito, ajuste en el lote siguiente, o queda como está?
- **Q8 — ¿El margen se mide a qué nivel?** Por prestación, por siniestro, por cliente, por mes. Define el grano al que hay que tener costo y venta juntos.
- **Q9 — ¿Cómo llegan las grillas de venta desde comercial?** Sigue abierta de la etapa 1 y ahora bloquea más: sin grilla no hay valorización. Si es un Excel, la estructura de ese archivo define el modelo y hace falta verlo.
- **Q10 — ¿El redondeo se aplica o no?** Queda disponible por decisión de la reunión, sin definición de uso. Conviene cerrarlo antes del primer aumento masivo, porque los redondeos se acumulan entre aumentos sucesivos.
- **Q11 — ¿Quién marca "facturado al cliente"?** ¿Lo marca la misma persona a mano después de emitir en ARCA, o hay algún dato de la emisión que vuelva al sistema? Define si el estado final es una acción o un evento.

- **Q17 — ¿Los módulos de cirugía se venden por grilla de valor de venta?** Apareció al escribir el DDL del grupo 2 (21/08/2026). Hay tres listas de tipos de prestación que no coinciden entre sí: `tasks.md` 2.2 dice "nomenclada / no nomenclada / **módulo**", el brief de implementación decía "nomenclada / no nomenclada / **NUN**", y `autorizaciones` tiene **las cuatro** columnas (`id_prestacion`, `id_prestacion_no_nomenclada`, `id_prestacion_nun`, `id_modulo`). El DDL modeló las cuatro con exclusión mutua, con este criterio: si la grilla no puede valorizar una vía que las autorizaciones admiten, esa vía queda sin valorizar para siempre. Si negocio confirma que los módulos no se venden por grilla, sobra un valor del dominio — el error barato; al revés faltaría una columna en una tabla ya cargada. **En AP hoy hay 0 autorizaciones con módulo**, así que no urge, pero conviene cerrarlo antes de que se cargue la primera grilla que incluya cirugías.

**Técnicas, abiertas:**

- **Q12 — Atomicidad de `turnos.valor_facturacion` y la erogación** (heredada, Q1 del design de la etapa 1). Define si la regla anti-doble-conteo alcanza.
- **Q13 — ¿La conversión persistida del ítem convertido vive en el modelo de prefacturación o en uno propio de ítems de consumo?** Hoy el motor no tiene tabla de ítems: agrega desde las nueve vías. Persistir la conversión introduce la primera tabla de ítems del consumo AP, y conviene decidir a propósito si es eso o si se apoya en `ap_valores_manuales`.
- **Q14 — El SP de carga masiva que resta el débito dos veces.** Es de otro ws y hay que coordinarlo; hasta entonces el facturado de las filas masivas queda subestimado.
- **Q15 — ¿La API de Kairos existe y es accesible?** Spike, sin compromiso de alcance.
- **Q16 — ¿El permiso de escritura de los parámetros del semáforo merece ser propio?** Heredada: hoy el PUT de `/ap/parametros` pide `ver_indicadores_ap`, o sea que quien puede ver los indicadores puede mover los umbrales.

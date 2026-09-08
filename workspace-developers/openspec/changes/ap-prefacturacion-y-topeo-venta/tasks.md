> **Orden de ejecución.** El grupo 2 → 3 → 5 no es negociable: cambiar el numerador antes de tener grillas de venta cargadas convierte todo el universo AP en "pendiente de valorizar" de golpe. Y el grupo 1 va **antes que todo**: sin la foto previa, el cambio de numerador es un cambio a ciegas sobre la cifra que decide cuánta plata se le puede seguir gastando a un paciente. Secuencia: **1 (línea base) → 2 (DDL venta) → 3 (contratos) → 4 (DDL prefacturación) → 5 (motor) → 6 (vías y tardías) → 7 (prefacturación) → 8 (avisos y cierre) → 9 (medicación) → 10/11 (front) → 12 (permisos) → 13 (entregables)**. Los grupos 4, 9 y 12 son desplegables en paralelo.
>
> **Decisiones de negocio ya cerradas (reunión 20/08/2026):** las tres instancias se miden en **valor de venta + 21%**, nunca sobre costo · **devengado y prefacturado son la misma categoría** · la factura del prestador es **costo** y detector de tardías, **no** una cuarta capa · la **fecha de realización** es la que manda · **un lote = un cliente**, tardías en lote aparte · contratos **sin IVA**, tope **con IVA**, **sin exentas** · **90% avisa** (tramitadores que cargan autorizaciones + auditoría médica), **100% cierra y bloquea** · el cierre se decide sobre el **facturado** · prefacturación **se avisa, no bloquea al gestor** · el valor se corrige **en el contrato** y baja a todo lo **no facturado** · valor de venta **por cliente**, **zona opcional** · medicación = **Kairos − 15/20%** sin IVA.
>
> **Lo que NO está decidido y hay que resolver antes de codificar el grupo que lo usa:** las preguntas Q1 a Q16 del `design.md`. Las bloqueantes están anotadas en la tarea que las necesita.

## 1. Línea base y verificación previa (no toca código)

- [x] 1.1 Regenerar la foto de paridad de stage con `src/test/resources/fixtures/generar-motor-consumo-stage.py` y commitear el `motor-consumo-stage.json` resultante como **línea base del numerador de costo**, con la fecha en el commit
- [x] 1.2 Dejar registrado, sobre esa foto, el estado de las 61 filas AP de stage: facturado / devengado / estimado / proyección / porcentaje / nivel / origen de tope, y la distribución por nivel. Es contra esto que se mide el cambio del grupo 5
- [x] 1.3 Confirmar en la réplica read-only que sigue sin existir ninguna tabla de valor de venta ni de prefacturación al cliente (a hoy: `grep -ril "valores_venta\|valorVenta\|valor_venta"` sobre el ws → 0 resultados; `grep -ril prefactur` sobre `repos/grvx/backend` → solo `ConsumoMedicamento` y un SQL de `wslogistica`)
- [x] 1.4 Verificar el estado real de los estados de facturación (`No Aplicable` / `No Facturado` / `Facturado` / `Facturado Pendiente Revisión`) y dejar por escrito que **no se toca ese catálogo** (decisión D4)
- [x] 1.5 Medir en la réplica cuántas prestaciones AP quedarían **sin valor de venta** con las grillas vacías, por cliente y por prestación. Es el tamaño real del trabajo de carga del grupo 3 y el argumento para no desplegar el grupo 5 antes
- [x] 1.6 Verificar la cadena `polizas_ap.id_empleador → empleadores.id_cliente → clientes` para el filtro por cliente, que es el filtro obligatorio del lote (el cliente es la aseguradora; el tomador de la póliza es el club o la persona)
- [x] 1.7 Confirmar contra `wsauditoriafacturacion` si la carga masiva ya exige número de autorización o sigue admitiendo la línea pegada solo al DNI, y con qué columnas viaja el número cuando viene (define el match del grupo 6)

## 2. Base de datos — DDL del valor de venta por cliente

- [x] 2.1 Verificar el último número de migración usado en `src/main/resources/sql/migrations/` **antes** de numerar (el directorio está hoy con solo `.gitkeep`; las migraciones de la etapa 1 viven en `openspec/changes/ap-costos-topeo-etapa1/sql/migrations/wsaccidentespersonales/V001..V003`)
- [x] 2.2 DDL de la tabla de valor de venta: **cliente obligatorio**, prestación (nomenclada / no nomenclada / módulo, excluyentes), **zona nullable**, `monto_venta DECIMAL(16,2)` **sin IVA**, versión/estado, vigencia desde/hasta, auditoría de carga. Índice por `(id_cliente, tipo_prestacion, id_prestacion, id_zona, estado, fecha_vigencia_desde)`
- [x] 2.3 DDL del historial del valor de venta (valor anterior, valor nuevo, motivo, tipo de cambio, usuario, fecha) para poder explicar un aumento y un ajuste individual
- [x] 2.4 DDL de la vigencia de la grilla por cliente (desde / hasta) para el aviso de contrato por vencer
- [x] 2.5 Definir la unicidad con cuidado: la unicidad de la etapa 1 en `polizas_ap_topes` dejó **`activo` fuera** porque incluirlo solo tolera una fila con `activo = 0` y la segunda baja falla con Duplicate entry, y dejó `tipo_doc` fuera porque los NULL no colisionan en un UNIQUE. **La zona nullable tiene exactamente el mismo problema**: dos filas con zona NULL para el mismo cliente y prestación no colisionan. Resolver antes de escribir el DDL, no después
- [x] 2.6 Revisar todos los scripts con el skill `mariadb-migration-review` y ajustar lo que objete
- [x] 2.7 Aplicar en dev y verificar charset (`utf8mb4_unicode_ci` explícito), engine (`InnoDB`), schema calificado (`cs`.`tabla`), índices y constraints
- [x] 2.8 Documentar el rollback de cada script y verificar que no afecta datos preexistentes. Recordar que `IF NOT EXISTS` es idempotente **por nombre y no por forma**

## 3. Backend — contratos de valor de venta (perfil comercial)

- [x] 3.1 Entidad + repositorio del valor de venta, con la clave cliente + prestación + zona opcional + vigencia
- [x] 3.2 Resolución del valor aplicable **por fecha de realización** (no por fecha actual), con soporte de vigencias futuras y comportamiento explícito cuando no hay valor (devolver ausencia, nunca cero)
- [x] 3.3 Endpoints de alta / consulta paginada / histórico del valor de venta, con permiso de escritura propio del perfil comercial validado con `permisoGuard.requerir(...)` como primera línea del método
- [x] 3.4 Versionado copy-on-write: al cargar un importe nuevo para cliente + prestación + zona vigente, cerrar la vigencia anterior y activar la nueva conservando el histórico
- [x] 3.5 **Aumento masivo por porcentaje** sobre la grilla de un cliente, con **previsualización** de cuántos valores se afectan y sus importes resultantes antes de confirmar, y **exclusiones** por prestación
- [x] 3.6 **Redondeo como opción, apagado por defecto** (el efecto se acumula entre aumentos sucesivos porque el siguiente se calcula sobre el importe ya redondeado)
- [x] 3.7 **Duplicación de la estructura** del contrato de un cliente hacia otro, con exclusiones e importes editables en el destino, y conflicto informado cuando el destino ya tiene valores vigentes
- [x] 3.8 Exportación de la grilla de un cliente a Excel (prestación, zona cuando aplica, importe sin IVA, vigencia)
- [x] 3.9 Vigencia de la grilla por cliente y **aviso un mes antes** del vencimiento; contrato vencido sin vigencia nueva ⇒ las prestaciones que resuelven contra él quedan **pendientes de valorizar**, no toman el valor vencido
- [ ] 3.10 **Q9 bloqueante:** conseguir el Excel o la fuente de la que salen hoy los valores de venta. Sin eso el modelo se diseña a ciegas y la carga inicial no arranca
- [ ] 3.11 Carga inicial de la grilla de al menos el cliente con más consumo, para que el grupo 5 tenga con qué valorizar cuando se despliegue
- [x] 3.12 Tests funcionales: resolución por fecha de realización, vigencia futura, versionado, aumento masivo con y sin exclusiones, duplicación con conflicto, ausencia de valor (no cero) y contrato vencido

## 4. Base de datos — DDL de prefacturación al cliente

- [ ] 4.1 DDL del **lote de prefacturado**: cliente (obligatorio), período desde/hasta, tipo (`período` / `tardías`), cantidad de prestaciones, subtotal sin IVA, IVA, total, estado (prefacturado / facturado), número y fecha de factura, auditoría de generación
- [ ] 4.2 DDL de los **ítems del lote**, con la referencia a la prestación, la fecha de realización, la fecha de carga, el valor de venta aplicado **y la referencia a la versión de valor de venta** que se usó (para poder explicar el importe años después)
- [ ] 4.3 DDL del **estado de prefacturación por prestación** y la marca de **erogación tardía**, con su motivo cuando la prestación sale de un lote o se anula. **No** se agregan filas al catálogo de estados de facturación existente (D4)
- [ ] 4.4 DDL de la **bitácora de movimientos** sobre prestaciones ya prefacturadas: qué prestación, qué lote, tipo de movimiento (cancelación / cambio de valor), valor anterior, valor nuevo, usuario, fecha, y si fue revisado y cómo se resolvió
- [ ] 4.5 DDL de la **vía de entrada** de la prestación (autorización / erogación asociada / erogación libre) y de la marca de **no matcheada**
- [ ] 4.6 DDL o extensión para el **costo por prestación** (sin IVA), que es el término del margen. Resolver **Q13**: si vive acá, en el modelo de prefacturación, o si se apoya en lo existente. Hoy el motor **no tiene tabla de ítems**: agrega desde las nueve vías, así que esta es la primera tabla de ítems del consumo AP y conviene decidirlo a propósito
- [ ] 4.7 Revisar todos los scripts con `mariadb-migration-review`, aplicar en dev y verificar
- [ ] 4.8 Documentar el rollback de cada script

## 5. Backend — motor de consumo con numerador de valor de venta

- [ ] 5.1 **Leer el `MotorConsumoSql` completo antes de tocarlo.** Dos trampas verificadas: (a) `MotorConsumoSql.MOTOR` y `sql/queries/motor-consumo-ap.sql` son **el mismo contrato** y hay que tocar los dos; (b) el mapeo de la fila cruda es **posicional** (`ConsumoApRepository.aConsumoCrudo`): agregar una columna al SELECT sin agregarla ahí, en la misma posición, corre todo el resto
- [ ] 5.2 Reemplazar la base de las vías de costo por el **valor de venta del contrato del cliente vigente a la fecha de realización**: `devengadoTurnos` / `estimadoTurnos` (hoy `turnos.valor_prestacion`), `estimadoQxHonorarios` (hoy `pedidos_presupuesto_prestaciones.valor_convenido`), `estimadoQxMateriales` (hoy `..._detalles.monto_cotizacion`), `estimadoQxOrtopedia` (hoy `pedidos_ortopedia_detalle.valor`)
- [ ] 5.3 Reemplazar la vía `facturadoErogaciones`: el **facturado** pasa a ser **lo facturado al cliente** (lote con factura registrada) y deja de ser `erogaciones.monto_facturado - monto_debitado`. La erogación pasa a la vía de costo y a la detección de tardías (grupo 6)
- [ ] 5.4 Mantener el IVA **normalizado por fuente** con la constante única y el helper existentes (`Constantes.ALICUOTA_IVA_GENERAL`, `utils/Iva`, parámetro `:factorIva` ligado por `ConsumoApRepository`). **No** escribir un `1.21` en el SQL: `MotorConsumoIvaPorFuenteTest` falla el build si alguien lo hace. Actualizar ese test al mapa de fuentes nuevo
- [ ] 5.5 Definir y documentar el caso **sin valor de venta cargado**: la prestación va a `itemsPendientesDeValorizar` y prende `consumoIncompleto`. **Prohibido** sustituirla por el costo ni por cero (un cero se lee como verde, y un costo se lee como un número cierto que no lo es)
- [ ] 5.6 Actualizar `DesgloseConsumoDTO`: las nueve vías tienen que seguir sumando la proyección, y ahora además hay que poder decir **si cada vía se valorizó por contrato de venta o por costo convertido**. Revisar si eso entra como campo del desglose o como marca por vía
- [ ] 5.7 Actualizar `ConsumoSiniestroDTO` y su documentación: `pctProyeccion` / `pctFacturado` siguen separados, `montosConIvaIncluido` sigue siendo invariante `true`, y la semántica de `facturado` cambia (es al cliente). El javadoc del DTO es la doc de negocio del contrato: actualizarlo es parte de la tarea, no un extra
- [ ] 5.8 Ajustar `ConsumoApEnsamblador` y `SemaforoApServiceImpl` (aritmética `BigDecimal`, `compareTo`, `setScale(2, HALF_UP)`, nunca dividir sin verificar que el tope sea `> 0`)
- [ ] 5.9 Revisar si `ResolucionTopeApServiceImpl` queda afectado (la resolución del tope vive en **tres** lugares: el SQL del motor, el archivo de queries y este service)
- [ ] 5.10 **Regenerar `MotorConsumoParidadStageTest`**: queda inválido por definición al cambiar el numerador. Regenerar la foto a propósito y no descubrirlo como test rojo
- [ ] 5.11 **Medir el delta contra la línea base del grupo 1, fila por fila**: proyección total, excedente total, y sobre todo **cuántos siniestros cambian de nivel**. Documentar el resultado en el change antes de mergear, como se hizo con el fix de IVA (que movió la proyección +10,8% y el excedente +42,2% sin mover ninguna clasificación)
- [ ] 5.12 Anotar la limitación de la medición: la cartera de stage está **polarizada** (48 de 61 casos por debajo del 5% del tope, 3 ya excedidos, el caso más cerca de un corte a 3,67 puntos). "No cambia ningún nivel en stage" **no** autoriza a concluir lo mismo en producción
- [ ] 5.13 Correr los tests de integración **de verdad**: `MotorConsumoAntiDobleConteoTest` se saltea solo si Testcontainers no habla con Docker y el build igual dice BUILD SUCCESS con 0 tests. Usar `-Dit.required=true` o el escape hatch de `IntegrationTestBase`, y **verificar el `Tests run:`**
- [ ] 5.14 Tests funcionales del numerador nuevo: prestación valorizada por contrato, aumento posterior que no re-valoriza lo facturado, prestación sin valor de venta, declaración de IVA en la respuesta, y costo conservado junto a la venta

## 6. Backend — vías de entrada, conversión y erogaciones tardías

- [ ] 6.1 Registrar y exponer la **vía de entrada** de cada prestación: autorización / erogación asociada / erogación libre
- [ ] 6.2 **Match por número de autorización** de las líneas de la carga masiva de erogaciones, cuando el número viene (depende de 1.7)
- [ ] 6.3 **Erogación libre**: vincular por documento del paciente al siniestro, incorporar la prestación y dejarla marcada como **no matcheada** para revisión explícita
- [ ] 6.4 **Conversión a valor de venta al entrar**, persistida con la referencia a la versión de valor de venta aplicada (decisión D2). No resolver el contrato al vuelo en la consulta del motor
- [ ] 6.5 Conservar el **importe de costo** de la erogación junto a la prestación, sin IVA, para el margen
- [ ] 6.6 **Anti-doble-conteo de la conversión**: una erogación que corresponde a una prestación ya cargada no genera prestación nueva. Seguir el precedente de `ap_valores_manuales`, donde `computa_consumo` se apaga cuando llega `idErogacion` y el `CHECK` `chk_ap_val_man_no_doble_conteo` lo garantiza en la base
- [ ] 6.7 **Q1 bloqueante:** definir con negocio qué es "un período ya facturado" con precisión (el período del último lote facturado de ese cliente, o el último mes cerrado). De eso depende qué se marca como tardía
- [ ] 6.8 Marcado de **erogación tardía** según esa definición, con su conteo por cliente y por período
- [ ] 6.9 Indicador de **erogaciones tardías sin facturar** (cantidad y monto sin IVA) para el home
- [ ] 6.10 Elevar y seguir el pedido a **auditoría de facturación** (con Nacho, responsable de erogaciones masivas) para que la carga masiva **exija número de autorización**. Es una dependencia externa a este change: mientras no esté, la vía C es la norma en medicación y la revisión es manual
- [ ] 6.11 Anotar y coordinar el bug del SP de carga masiva: graba `monto_facturado` **ya neto del débito** y además graba `monto_debitado`, así que el cálculo `monto_facturado - monto_debitado` le resta el débito dos veces a las filas `carga_masiva = 1`. Hoy no mueve números AP (las 41 masivas del universo AP de stage tienen débito en cero). La corrección es del lado del SP, que es de otro ws
- [ ] 6.12 Tests funcionales: las tres vías, medicación sin autorización, erogación matcheable, erogación no matcheable, tardía y no tardía, y conversión sin valor de venta disponible

## 7. Backend — prefacturación al cliente

- [ ] 7.1 Endpoint del **listado de prestaciones a prefacturar**, paginado (`FindAllResults` con `cantidadTotal` + `objetos`), filtrable por fecha de realización (principal), fecha de carga, cliente, DNI o paciente, estado y "solo tardías", con orden por whitelist
- [ ] 7.2 Totales del filtro: cantidad, subtotal sin IVA y total con IVA
- [ ] 7.3 **Selección sobre todo el filtro** y no solo sobre la página visible, con los totales correspondientes al conjunto seleccionado
- [ ] 7.4 **Generación de lote**: cliente obligatorio, un lote por cliente, **lote aparte para las tardías**, con la previsualización de cuántos lotes se van a crear y por qué antes de confirmar
- [ ] 7.5 Validaciones de negocio del armado, con error claro: sin selección, estados mezclados, prestaciones ya prefacturadas o facturadas, sin cliente elegido, prestación sin valor de venta
- [ ] 7.6 **Reversión**: devolver prestaciones de un lote a pendiente de facturar, y deshacer un lote completo, con el recálculo del total y el informe de cuántas volvieron y por qué monto
- [ ] 7.7 **Registro de la factura emitida**: número (obligatorio) y fecha; las prestaciones pasan a facturado al cliente y el lote queda **congelado** (no vuelve atrás, no recibe correcciones de valor)
- [ ] 7.8 **Bitácora de movimientos** sobre prestaciones prefacturadas: registrar la cancelación y el cambio de valor con usuario y fecha, contarlos **solo** sobre lotes sin facturar, y exponerlos para resolución
- [ ] 7.9 Resolución de un movimiento: **sacar del lote** (la prestación sale con motivo) o **aceptar el estado nuevo** marcándolo revisado, con el recálculo del total del lote
- [ ] 7.10 Advertencia al registrar la factura de un lote con movimientos sin revisar (advierte, no bloquea)
- [ ] 7.11 **Propagación de la corrección del contrato** a las prestaciones pendientes y prefacturadas del cliente, sin tocar las facturadas
- [ ] 7.12 **Aviso de valor incorrecto** hacia comercial desde prefacturación, sin permitirle a prefacturación editar el valor
- [ ] 7.13 Endpoint del **respaldo de una prestación**: informe médico, imagen o estudio, y autorización del cliente, con estado cargado / falta / no corresponde, y el reclamo de lo que falta. La falta de respaldo **advierte, no bloquea**
- [ ] 7.14 **Descargas**: detalle del lote y detalle de una selección, en **PDF** y **Excel**, con el detalle prestación por prestación y los tres importes
- [ ] 7.15 **Q11:** definir quién y cómo marca "facturado al cliente" — si es una acción manual después de emitir, o si vuelve algún dato de la emisión. Define si el estado final es una acción o un evento
- [ ] 7.16 **Q7:** definir qué pasa con un ítem ya facturado cuya prestación después se cancela (nota de crédito, ajuste en el lote siguiente, o queda como está)
- [ ] 7.17 Tests funcionales: fecha de carga posterior a la de realización, lote por cliente, tardías en lote aparte, estados mezclados rechazados, reversión, congelamiento de lo facturado, movimientos sobre lote sin facturar y sobre lote facturado, y propagación de la corrección del contrato

## 8. Backend — aviso del 90% y cierre/bloqueo al 100%

- [ ] 8.1 **Cablear el aviso**, que es lo que falta: `registrarAvisoSiCorresponde` está implementado y testeado y **no lo invoca nadie** — está deliberadamente fuera de los GET porque un aviso es un hecho del circuito de autorización o de auditoría de facturas, no de alguien mirando una pantalla. Mientras no se cablee, `ap_avisos_nivel_siniestro` queda vacía
- [ ] 8.2 Cambiar el criterio de emisión: **un corte, en 90%**, en lugar de un aviso por cada cambio de nivel hacia arriba (que es lo que definió la etapa 1)
- [ ] 8.3 **Q5 bloqueante:** resolver "los tramitadores que cargan autorizaciones" y "auditoría médica" a perfiles o permisos concretos, y definir el canal (aviso en pantalla, novedad, mail)
- [ ] 8.4 Idempotencia del aviso por siniestro y **por tope vigente**: una ampliación de tope habilita un aviso nuevo. La UNIQUE de la etapa 1 quedó `(id_denuncia, nivel, id_tope_uk)` con columna generada justamente por eso — revisar si sigue sirviendo con un corte único
- [ ] 8.5 Marcar el aviso como visto: `AvisoSemaforoApServiceImpl.marcarVisto` existe, **no está en la interfaz y no tiene endpoint**
- [ ] 8.6 **Bloqueo de autorizaciones nuevas al superar el tope**, en el punto donde nace la autorización (no en este ws), informando consumo, tope y excedente
- [ ] 8.7 **Q6:** definir si el bloqueo admite override con justificación registrada. El topeo que ya existe en el sistema lo admite; si acá no, es la primera vez que el bloqueo es duro y conviene decirlo
- [ ] 8.8 Revisar el parámetro `bloquear_autorizacion_al_exceder` de `ap_semaforo_parametros`, que hoy arranca en 0 ("solo avisa"): con la definición nueva el bloqueo es la regla, así que hay que decidir si el parámetro se elimina, se invierte o queda como escape hatch
- [ ] 8.9 Mantener `HabilitacionCierreApDTO` y los cuatro valores de `MotivoHabilitacionCierre` (`FACTURADO_ALCANZA_TOPE`, `FACTURADO_POR_DEBAJO_DEL_TOPE`, `PROYECCION_SOBRE_TOPE_FACTURADO_POR_DEBAJO`, `SIN_TOPE_DEFINIDO`), ahora evaluados sobre el facturado **al cliente**. `GET /ap/siniestros/{idDenuncia}/habilitacion-cierre` no cambia de forma
- [ ] 8.10 Confirmar que este ws **sigue sin cerrar denuncias**: el cierre es el proceso de `wstramitador` (`POST /siniestros/cerrar-siniestro`, escribe `cs.cierres_denuncias_log`, dispara el proceso de incapacidad y notifica a Mulesoft). AP aporta el hecho, no la autorización a cerrar por otra vía
- [ ] 8.11 Tests funcionales: cruce del 90% que avisa una sola vez, ampliación que habilita un aviso nuevo, autorización posible después del aviso, bloqueo al superar el tope, y los cuatro motivos de habilitación de cierre

## 9. Backend — precios de medicación (Kairos)

- [ ] 9.1 Modelo del medicamento con nombre, presentación y troquel, y su precio de referencia con fecha
- [ ] 9.2 **Descuento por medicamento** (habitualmente 15% o 20%) y cálculo del **valor de venta sin IVA** como precio de referencia menos descuento
- [ ] 9.3 Registro del precio de referencia usado, el descuento y la fecha en cada carga (el portal externo no conserva historial: ese historial es parte del valor de esta tarea)
- [ ] 9.4 **Antigüedad del precio** como dato de primera clase, con marca a los **30** días y severidad mayor a los **90**
- [ ] 9.5 Indicador de **medicamentos sin revisar** (más de 30 días) para el home
- [ ] 9.6 Exportación del listado de medicamentos con precio de referencia, descuento, valor de venta sin IVA y fecha de actualización
- [ ] 9.7 **Q15 — spike de la API de Kairos**: investigar si existe, si es accesible y con qué contrato. **No compromete alcance**: si no sale, la carga manual con avisos por antigüedad es el camino completo
- [ ] 9.8 **Q2:** definir si el valor que sale de Kairos menos descuento **es** el valor de venta al cliente o si además pasa por la grilla del contrato. Define si la medicación necesita fila en la grilla
- [ ] 9.9 Tests funcionales: cálculo del valor de venta, actualización que conserva el precio anterior, marcas de 30 y 90 días, y el mensaje explícito cuando se intenta sincronizar sin integración disponible

## 10. Frontend — módulo de prefacturación

> **Estado al 07/09/2026 (MR !1890, en `feat/ap-nav-y-paneles`).** El módulo ya tiene
> **navegación, permiso propio y las cuatro pantallas creadas**, pero **ninguna con datos**: la
> prefactura no existe como entidad (grupo 4) y no hay endpoint de líneas (grupo 7). Lo que hay es
> el andamio honesto — cliente y período funcionando contra el endpoint real, y
> `PanelProximamente` con el motivo escrito donde iría la grilla.
>
> Lo que **sí** quedó terminado y no vuelve a tocarse:
>
> - el ítem de menú `PRELIQUIDACIONES` con los cuatro subítems (Prefacturar el mes · Prefacturas ·
>   Medicamentos · Cómo funciona) y dos subítems nuevos bajo `CONTRATACIONES`. Son subítems y no
>   ítems top-level a propósito: el menú lateral lo comparte todo el ecosistema del SAS
> - el permiso `ver_prefacturacion_ap` / `administrar_prefacturacion_ap`, que **no existía**: estas
>   pantallas quedaban gateadas por `ver_indicadores_ap`, el permiso del tablero de **gerencia**
> - el home de los dos perfiles de AP. Estaban cayendo al tablero del **tramitador** porque
>   `RutasTramitadores.js` resuelve el home con `user.perfiles[0]` contra `HOME_COMPONENTS` y
>   ninguno de los dos perfiles estaba en ese objeto
> - **la pantalla "Cómo funciona", completa** — ver 10.17
>
> Y un cambio de patrón transversal: el ABM de valores de venta pasó de **drawer vertical a panel
> en página** con grid `xs:12 / sm:6 / md:3`. Medido sobre la maqueta aprobada: **26 paneles en
> página y 1 solo drawer**. `DrawerValorVenta.jsx` se eliminó; lo reemplaza `PanelValorVenta.jsx`,
> que conserva los cinco fixes del drawer (la conversión DD/MM/YYYY → ISO, la comparación de
> vigencias sobre la fecha convertida y no lexicográfica, la race del buscador, el `errors` como
> objeto indexado del autocomplete, y el patrón `intentado` con el botón que no se apaga).

- [ ] 10.1 Pantalla de **inicio** con las cinco métricas (pendiente de facturar, movimientos sobre prefacturadas, erogaciones tardías sin facturar, margen de lo facturado, medicamentos sin revisar), cada una navegable, y con el caso "nada sin revisar" escrito y no solo en cero
- [ ] 10.2 **Panel de pacientes a vigilar** ordenado por porcentaje de proyección, con suma asegurada (con IVA), facturado, proyección y su porcentaje, y el nivel **escrito** (nunca solo por color). Sin tope ⇒ no dibujar semáforo ni porcentaje
- [ ] 10.3 Aviso de **contratos por vencer** (un mes antes) en el inicio
- [ ] 10.4 **Listado de prestaciones a prefacturar** con los filtros (fecha de realización como principal, fecha de carga, cliente, DNI o paciente, estado, solo tardías), el atajo al mes anterior, y el paginado — **ANDAMIO EN `PrefacturarMesAp.jsx`** (MR !1890). Cliente y período funcionan de verdad contra `listados/cliente/activos`, con los tres estados distinguidos (cargando / error con "Reintentar" / vino vacía, que no es un error). Van **arriba y desplegados**, no dentro de filtros colapsables: no son filtros, son definitorios. El período ofrece los 12 meses **cerrados** y preselecciona el anterior — el corriente no se ofrece porque el corte es por fecha de realización y un mes abierto sigue recibiendo prestaciones. La grilla misma es `PanelProximamente`, con las 5 solapas, los 7 filtros y la columna Origen enumerados **en texto**: sin tabs clickeables y sin contadores en cero, porque un cero se lee como un dato. Falta 7.1
- [ ] 10.5 Marca visual de **erogación tardía** en la fila, con el conteo de tardías del filtro
- [ ] 10.6 Selección con **checkbox**, incluida la selección de todo el filtro, con la barra de totales (cantidad, subtotal sin IVA, IVA, total) siempre visible
- [ ] 10.7 **Generación del lote** con la previsualización de los lotes a crear, el aviso de tardías en lote aparte y el aviso de respaldo incompleto
- [ ] 10.8 **Registro de la factura emitida** con número y fecha, y la advertencia previa si hay movimientos sin revisar
- [ ] 10.9 **Panel de movimientos** sobre prefacturadas, con las dos salidas por caso (sacar del lote / aceptar el estado nuevo)
- [ ] 10.10 **Respaldo de la prestación** consultable sin salir del listado, con los tres documentos, el reclamo de lo que falta y el aviso de valor incorrecto hacia comercial
- [ ] 10.11 **Listado de lotes** con cliente, contenido (período o tardías), cantidad, subtotal, IVA, total, estado con número de factura, y las acciones por lote (ver prestaciones, descargar PDF, descargar Excel, registrar factura, deshacer) — **ANDAMIO EN `PrefacturasAp.jsx`** (MR !1890). El circuito de tres estados (borrador → cerrada → facturada, y que **facturada es el único que no vuelve atrás**) va construido con chips: es la definición del circuito, no instancias inventadas. Incluye el argumento del congelado con el dato medido: los 226 detalles de julio dieron **dos números distintos con 4 días de diferencia**, porque hoy la valorización se recalcula en cada consulta. Falta 4.1
- [ ] 10.12 **Descargas** PDF y Excel por lote y por selección
- [ ] 10.13 Pantalla de **medicamentos** con precio de referencia, descuento, valor de venta sin IVA, antigüedad con su color, edición del valor y exportación — **ANDAMIO EN `MedicamentosAp.jsx`** (MR !1890). Deja escritos los **dos bloqueos, separados porque son de naturaleza distinta**: Kairos no está integrado (es una integración) y el descuento por cliente no tiene catálogo (es una definición de negocio más una tabla). Y el motivo por el que esta pantalla existe aparte y no es una solapa de "Prefacturar el mes": **la medicación no tiene autorización a la que colgarse** (reunión 20/08). Falta el grupo 9
- [ ] 10.14 Mantener el patrón del sistema: **las acciones no se deshabilitan**; si falta algo, se avisa al intentar ejecutarlas
- [ ] 10.15 Reemplazar el `PanelProximamente` de `FacturacionMensualAp.jsx` (`/home/cartera-ap/facturacion`) cuando el módulo esté, y **borrar los textos de "todavía no está modelado"** de `Idiomas/es/carteraAp.json` en la misma entrega, para que no quede una pantalla diciendo que lo que ya existe no existe
- [x] 10.16 `npm run lint` y typecheck del MFE tocado, confirmando con `git diff` que los archivos modificados no suman errores nuevos — **HECHO** para la MR !1890: `npx eslint` sobre los 19 archivos js/jsx tocados da **0 errores y 0 warnings**; `webpack --mode production` compila (los 2 warnings son de tamaño de asset y preexisten en `develop`); `npx jest` de AP da **76/76** (28 de valores de venta + 11 nuevos de `constantesPrefacturarMes` + 37 de cartera). Nota del camino: `prettier --check` falla en los archivos nuevos **y también en los 10 `CarteraAp/*.jsx` ya mergeados** — el `.prettierrc` del repo (`semi: false`, `useTabs: false`) contradice a todo el codebase. Es rot preexistente y correrle `--write` divergiría del resto; se deja como está a propósito
- [x] 10.17 Pantalla **"Cómo funciona"** (`/home/prefacturacion-ap/como-funciona`) — **HECHA Y COMPLETA**, la única de las cinco sin ningún `PanelProximamente`. **31 reglas de negocio en 7 secciones** (a quién se le factura · cómo entra una prestación · de dónde sale el número · cuando falta el precio · las cuatro fechas · el tope y el cierre · cómo se lee la pantalla), con **tres destacadas arriba** (el circuito de estados existe para no facturar dos veces · el valor no se tipea acá, sale del contrato del cliente · prefacturación no bloquea al gestor, se entera) y el resto plegado.
	**Por qué importa más de lo que parece:** esas reglas vivían en **javadoc de DTOs y en `COMMENT` de migraciones**, donde la usuaria no las puede leer, y la maqueta se iteró con los usuarios reales. Esta pantalla es donde las decisiones sobreviven al archivado de la maqueta. El contenido vive en `contenidoComoFunciona.js` (estructura) + `Idiomas/es/comoFuncionaAp.json` (texto), separados para que el copy sea revisable sin leer JSX.
	Presentación según la preferencia declarada de la usuaria: una idea por bloque, orden fijo, **máximo tres estados a la vez**, detalle plegado y el siguiente paso marcado (`paso: true`)
- [ ] 10.18 Pantalla de **Presupuestos** (`/home/valores-venta-ap/presupuestos`) — **ANDAMIO EN `PresupuestosAp.jsx`** (MR !1890). La usuaria la nombró explícitamente ("falta presupuestos"). Deja la **forma del documento** en paneles con grid, tal como la definió `maqueta/presupuesto.content.html` (Paciente y práctica · Ítems del presupuesto · El documento), **sin inputs falsos que no guardan nada**. Y el hecho que cambia cómo se lee: que un presupuesto aprobado **ya suma como estimado** en el motor está implementado; lo que **no** está verificado es que la cancelación lo reste. No hay entidad ni endpoint de presupuesto: es el paso 15 del plan, atrás de definiciones abiertas

## 11. Frontend — ajustes en Costos y Topeo y consulta de siniestros

- [ ] 11.1 Actualizar el copy de la sección para decir que el consumo está expresado en **valor de venta más IVA**: `costosTopeo.subtitulo` ("Los montos se muestran con IVA") y `grafico.piePagina` ("Marcas: aviso 90% · tope 100% · los montos se muestran con IVA") ya no alcanzan, porque no dicen sobre **qué** base
- [ ] 11.2 Conservar intactas las definiciones aprobadas de `costosTopeo.definiciones` y del gráfico: Facturado "real · tope oficial", Devengado "realizado, sin factura", Estimado "autorizado, sin realizar", Proyección "vigilancia · facturado + devengado + estimado". Lo que cambia es la base, no las definiciones
- [ ] 11.3 Revisar si el rótulo de **Facturado** necesita decir "al cliente", que es el punto que más se confunde en el dominio
- [ ] 11.4 Respetar las constantes fijas de `constantesTopeo.js`: `CORTE_AVISO = 90`, `CORTE_TOPE = 100`, `COLORES_ESTADO_TOPEO` (`#2e7d32` / `#e07a00` / `#d32f2f`), `COLORES_NIVEL_TOPEO` (con los contrastes ya medidos: BAJO 4,63 / MEDIO 4,67 / ALTO 4,65 / MUY_ALTO 4,64 / EXCEDIDO 12,63 / SIN_TOPE 5,59 sobre fondo al 10%) y los cuatro `MOTIVOS_HABILITACION_CIERRE`. **No aclararlos ni recalcularlos sin volver a medir**
- [ ] 11.5 **Vía de entrada** e **instancia** por prestación en `TablaPrestaciones.jsx`, con el costo del prestador y la venta al cliente como columnas distintas
- [ ] 11.6 Indicación de que el aviso del **90%** ya se emitió, en el detalle y en los listados
- [ ] 11.7 **Consulta de siniestros** disponible en los dos perfiles, filtrable por denuncia, paciente o documento, cliente, estado del siniestro, nivel del semáforo y "solo los que ya avisaron al 90%"
- [ ] 11.8 Verificar que la sección sigue entrando por el **menú secundario real** de la denuncia (`MenuDenuncia.js`, `rutas.COSTOS_TOPEO`, label "Costos y Topeo", gateada por `PERMISOS.VER_SEMAFORO_AP`) y **no** por un menú paralelo de AP. Nota heredada: la clave del ítem es `SINIESTRALIDAD` porque la clave define el icono y la librería no publicó todavía uno propio de costos
- [ ] 11.9 `npm run lint` y typecheck del MFE tocado

## 12. Permisos y configuración

- [~] 12.1 Definir los permisos nuevos del módulo (prefacturación: listado y armado de lote; registro de factura; administración de medicamentos) y agregarlos a `utils/Constantes.java`, sin literales inline — **PARCIAL**. Hecho el par de prefacturación: `ver_prefacturacion_ap` y `administrar_prefacturacion_ap`, dados de alta en `cs.permisos_sas` de dev (ids 1012/1013, perfil 39) con `sql/04-permisos-prefacturacion-ap.sql`, idempotencia probada, y declarados en el front en `config/permissionsConfig.js`.
	**Falta el lado backend**: agregarlos a `utils/Constantes.java` del ws. Hoy ningún endpoint los consume porque la entidad prefactura no existe (grupo 4), así que el permiso todavía no gatea nada server-side — **esconder la ruta en el front no es autorización**, y esto queda anotado para que no se confunda una cosa con la otra.
	Faltan también los de medicamentos, que esperan el grupo 9.
	Decisión tomada de paso: los dos permisos **NO** van al perfil comercial (dev id 40). Comercial pacta y carga los valores de venta, no prefactura. La consecuencia es que "Cómo funciona" —que le sirve a los tres perfiles— no le aparece en el menú, y por eso su **ruta** se gatea con `hasAnyPermission(VER_PREFACTURACION_AP, VER_VALORES_VENTA_AP, VER_INDICADORES_AP)`: comercial llega por link. No se resuelve dándole el permiso de prefacturación
- [x] 12.2 Definir el permiso de escritura del **valor de venta** para el perfil comercial, separado de la lectura — **HECHO**: el par es `ver_valores_venta_ap` (lectura de la grilla, los historiales y los vencimientos) y `administrar_valores_venta_ap` (alta, anulación, aumento masivo, duplicación, export). Los nombres salen de `Constantes.java` y no son opinables: `PermisoGuard` compara por string contra lo que viaja en la cookie
- [x] 12.3 Script idempotente de alta de los permisos en `cs.permisos_sas` y su asociación a los perfiles, con el skill `/configurar-sas` (START TRANSACTION + verificación previa + INSERT + verificación posterior + COMMIT/ROLLBACK comentados) — **HECHO**: `sql/02-permisos-ap-completos-dev.sql`. Resuelve perfiles y permisos **por nombre**, no por id: en dev son 38/39/40, en stage 28/29 y en la réplica de prod 22/25. **Idempotencia probada contra dev**: la segunda corrida insertó 0 filas
- [x] 12.4 Dar de alta los permisos **pendientes de la etapa 1** que hoy dejan endpoints en 403: `ver_semaforo_ap`, `ver_indicadores_ap`, `administrar_topes_ap` y `ver_consolidado_cirugia` no existen todavía en `cs.permisos_sas` de todos los ambientes — **APLICADO EN DEV** el 07/09/2026 con COMMIT y verificado releyendo la base: los 6 permisos (ids 1006-1011), el perfil `gestor_comercial_accidentes_personales` (id 40, que **tampoco existía** en dev) y 6 vínculos activos sin duplicados. **Falta stage y test.** Hallazgo del camino: los permisos 103-107 de la tarea 1.6 de la etapa 1 se cargaron **sólo en stage**, a mano, y ese script nunca quedó en el repo — por eso dev nunca los tuvo y **las pantallas de Costos y Topeo ya mergeadas a develop no funcionaban ahí**
- [x] 12.5 Documentar en la entrega que **un permiso nuevo exige re-login**: los permisos viajan en la cookie `datos_usuario` — **HECHO**: está en la cabecera y en el cierre de `sql/02-permisos-ap-completos-dev.sql`, junto con los tres endpoints concretos con los que se comprueba que quedó bien
- [ ] 12.6 **Q16:** definir si el PUT de `/ap/parametros` merece un permiso propio de escritura. Hoy pide `ver_indicadores_ap`, o sea que quien puede ver los indicadores puede mover los umbrales
- [ ] 12.7 Validar el login y el menú de un usuario de prueba con cada perfil en un ambiente bajo (los usuarios de stage de la etapa 1 son `qa.tramitadores.rbpi` perfil 28 gestión y `qa.tramitadores.hn8p` perfil 29 comercial)

## 13. Entregables obligatorios

- [ ] 13.1 `docs/openApi.yaml` del ws actualizado con los endpoints nuevos, validado con el skill `openapi-validator`
- [ ] 13.2 Colección Bruno regenerada (`/bruno-sync --ws wsaccidentespersonales`)
- [ ] 13.3 Actualizar `CLAUDE.md` de `wsaccidentespersonales` (`/claudemd --actualizar`): el bloque del modelo de negocio, la tabla de IVA por fuente y el bloque "Qué falta" quedan desactualizados con este change, y ese archivo es la primera cosa que lee cualquiera que entre al repo
- [ ] 13.4 `CHANGELOG.md` del ws
- [ ] 13.5 Documentar el **delta medido del cambio de numerador** (tarea 5.11) en este change, con la comparación de niveles antes y después
- [ ] 13.6 `/code-review` antes de subir la MR, y `/mr-comments` para el título, la descripción y los comentarios técnicos
- [ ] 13.7 `/runbook` post-deploy: el cambio de numerador es exactamente el tipo de cambio que alguien va a tener que entender seis meses después cuando un porcentaje no cierre

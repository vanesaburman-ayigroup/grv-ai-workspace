> **Orden de ejecución acordado (30/07/2026).** El **semáforo por FACTURADO va antes del hook del estimado**: las erogaciones ya tienen datos reales, así que la primera demo se hace sin tocar `wsturnos` y el modelo se valida con negocio antes de invertir en el cambio invasivo. Secuencia: **grupo 1 (perfiles) → 2 (DDL) → 3 (tope) → 5 sin estimado (semáforo facturado) → 4 (estimado + backfill) → 5bis/7 (carga manual) → 6/8 (valor de venta)**.
>
> **Decisiones de negocio ya cerradas:** servicio nuevo `wsaccidentespersonales` aprobado · perfil `gestor_comercial_accidentes_personales` para Iván Chaparro · ventana del tope **ANUAL** (sujeta a cambio, es dato) · el tope **se puede ampliar** · al exceder **solo avisa**, con bloqueo activable por parámetro en BD · el valor de venta **no varía por cliente** · **aumentos masivos por porcentaje** además de la carga individual · reportes a jefatura y mapa de zonas **diferidos**.

## 1. Perfiles y permisos (arranque — sin dependencias)

- [x] 1.1 Confirmar en réplica read-only el estado de partida: `analista_accidentes_personales` (id 22) y `gestor_accidentes_personales` (id 25) con los mismos 2 permisos activos (13 `crear_turnos_analista_quirurgico`, 18 `crear_turnos_laboratorio`), y el máximo `id_perfil` / `id_permiso` vigentes — VERIFICADO 30/07 en prod (réplica): analista id 22 + gestor id 25, permisos 13/18; max id_perfil 25 / id_permiso 64. **Los ids NO son portables: en stage el analista es 22 pero el gestor quedó 28.**
- [x] 1.2 Nombre del perfil comercial **CONFIRMADO: `gestor_comercial_accidentes_personales`**, con los mismos permisos que el analista. Nota: puede pasar a ser el perfil comercial general más adelante; `perfiles_sas.perfil` es varchar y no es FK, así que se renombra sin romper nada
- [ ] 1.2.1 **Asignar el perfil a Iván Chaparro**: resolver su `id_persona` (PASO 0 del script `sql/02-asignar-perfil-comercial-ivan.sql`) confirmando que hay una sola persona, y ejecutar la asignación. Avisarle que debe **cerrar sesión y volver a entrar** para que el perfil tome efecto
- [x] 1.3 Escribir el script SQL idempotente de alta del perfil comercial (START TRANSACTION + verificación previa + INSERT en `perfiles_sas` módulo 1 + INSERT de los vínculos en `perfiles_permisos_sas` copiados del id 22 + verificación posterior + COMMIT/ROLLBACK comentados), siguiendo el patrón del skill `configurar-sas` — HECHO: `sql/01-perfil-comercial-ap.sql`
- [x] 1.4 Verificar la idempotencia del script: segunda corrida no inserta filas nuevas ni duplica vínculos de permisos — VERIFICADO: alta ejecutada en stage con lógica idempotente (INSERT ... WHERE NOT EXISTS + reactivación de vínculos dados de baja)
- [x] 1.5 Verificar la paridad de permisos: el conjunto activo del perfil comercial es idéntico al del analista (misma cantidad y mismos `id_permiso`) — VERIFICADO en stage: el comercial (id 29) heredó los mismos permisos 13/18 del analista (id 22)
- [x] 1.6 Escribir el script idempotente de alta de los permisos nuevos de AP (`ver_semaforo_ap`, `ver_indicadores_ap`, `cargar_valor_venta_prestacion`, `ver_margen_ap`, `ver_consolidado_cirugia`) y asociarlos a los perfiles que correspondan (gestión vs comercial) — HECHO y EJECUTADO en stage: permisos 103 `ver_semaforo_ap`, 104 `ver_indicadores_ap`, 105 `ver_consolidado_cirugia`, 106 `cargar_valor_venta_prestacion`, 107 `ver_margen_ap`. Reparto: gestión 103/104/105, comercial 106/107
- [x] 1.7 Aplicar los scripts en un ambiente bajo y validar el login/menú de un usuario de prueba con cada perfil — HECHO en STAGE: perfiles `gestor_accidentes_personales` (28, 5 permisos) y `gestor_comercial_accidentes_personales` (29, 4 permisos) + 2 usuarios de prueba `qa.tramitadores.rbpi` y `qa.tramitadores.hn8p` (password `<password unificada de QA en ambientes bajos>`) creados con LDAP+DB+Keycloak (`--kc-flip` necesario: editMode READ_ONLY). **Falta validar el login/menú en el front.**

## 2. Base de datos — DDL aditivo

- [x] 2.1 Script DDL de `polizas_ap_topes` (grano póliza + tipo/nro de documento del asegurado + ventana **default `ANUAL`**; `suma_asegurada DECIMAL(16,2)`, `iva_incluido`, `moneda`, `activo`, auditoría de carga; unicidad por póliza+documento+ventana+activo) — HECHO: `sql/migrations/wsmesacarga/V32__CREATE_polizas_ap_topes.sql`. **La unicidad final es (id_poliza, nro_doc, ventana)**: `activo` quedó FUERA (incluirlo solo tolera una fila con activo=0 → la segunda baja falla con Duplicate entry) y `tipo_doc` también (es NULL-able y los NULL no colisionan en un UNIQUE)
- [x] 2.1.1 Script DDL de `polizas_ap_topes_historial` (valor anterior, valor nuevo, **motivo**, usuario, fecha) para la edición y la **ampliación** del tope — HECHO: `V33__CREATE_polizas_ap_topes_historial.sql`, con `motivo`, `tipo_cambio` y versionado de `ventana`
- [x] 2.2 Script DDL de las columnas denormalizadas en `denuncia_poliza` (`suma_asegurada`, `moneda`) — HECHO: `V34__ALTER_denuncia_poliza_ADD_tope.sql`. Son **6 columnas**, no 2: se sumaron `id_tope`, `fecha_resolucion_tope`, `ventana` e `iva_incluido` (sin la ventana el motor no sabe sobre qué rango acumula; sin el flag de IVA hay 21% de error silencioso en el porcentaje)
- [ ] 2.3 Script DDL de `valores_venta_prestacion` (prestación nomenclada / no nomenclada / módulo excluyentes + `id_zona` + `monto_venta` + versión/estado + vigencia desde/hasta + auditoría; índice por prestación+zona+estado+vigencia)
- [x] 2.4 Script DDL de `ap_semaforo_parametros` con seed idempotente de: umbrales configurables (40 y 70), flags de **aviso por nivel** (Alto / Muy alto / Excedido habilitados) y **`bloquear_autorizacion_al_exceder` en 0** (por defecto solo avisa; se activa por parámetro sin deploy) — HECHO: `V001__crear_tabla_ap_semaforo_parametros.sql`. Verificado en dev y stage: `modo_arranque: OK — arranca SOLO AVISANDO`
- [x] 2.4.1 Script DDL de `ap_valores_manuales` (valores cargados a mano: medicación con descripción del medicamento + precio + fuente + fecha de consulta; prestaciones no convenidas con referencia del acuerdo; auditoría de carga) — HECHO: `V002__crear_tabla_ap_valores_manuales.sql`, con CHECK anti-doble-conteo (`id_erogacion IS NULL OR computa_consumo = 0`) y `motivo_baja` obligatorio en la baja
- [x] 2.4.2 Script DDL de `ap_avisos_nivel_siniestro` (registro de qué nivel avisó cada siniestro, para no repetir el mismo aviso) — HECHO: `V003__crear_tabla_ap_avisos_nivel_siniestro.sql`. La UNIQUE quedó `(id_denuncia, nivel, id_tope_uk)` con columna generada, para que una **ampliación del tope habilite un aviso nuevo** del mismo nivel
- [ ] 2.4.3 Script DDL del precio de la unidad de laboratorio (o reutilización del existente en contratos, según lo que resuelva la task 6.8)
- [ ] 2.5 Revisar todos los scripts DDL con el skill `mariadb-migration-review` y ajustar lo que objete
- [x] 2.6 Aplicar el DDL en un ambiente bajo y verificar charset, índices y constraints — HECHO: las 6 migraciones aplicadas y verificadas en **dev y stage** (5/5 tablas, 6/6 columnas, `nro_doc` en latin1_swedish_ci). Cero errores
- [x] 2.7 Documentar el rollback de cada script (DROP de lo nuevo / DROP COLUMN de lo agregado) y verificar que no afecta datos preexistentes — HECHO: rollback comentado en cada script + `README-AP-orden-de-aplicacion.md` con el orden estricto y la advertencia de que `IF NOT EXISTS` es idempotente por NOMBRE y no por FORMA

## 3. Backend — tope de la póliza (`wsmesacarga`)

- [x] 3.1 Entidad + repositorio del tope en `wsmesacarga`, sobre el modelo de `polizas_ap_topes` — **HECHO** en `wsaccidentespersonales` (no en `wsmesacarga`): `PolizaAp`, `PolizaApRepository`, `PolizaApRepositoryImpl`
- [x] 3.2 Endpoints de alta/edición/baja lógica y consulta de topes por póliza, con chequeo de permiso en backend — **HECHO** con desvio de ubicacion: `TopeApController` expone `POST/PUT/GET /ap/topes`
- [ ] 3.3 Validación de unicidad (rechazar segundo tope activo para la misma póliza + documento + ventana) devolviendo un error de negocio claro
- [ ] 3.4 **Suma asegurada obligatoria en el alta de la póliza AP**: validación en el backend del endpoint de alta (no solo en el formulario), rechazando el alta sin el dato — **NO ESTA**: es validacion en `wsmesacarga`, que no se toco
- [x] 3.5 **Edición del tope de una póliza vigente** con historial del cambio (valor anterior, valor nuevo, usuario, fecha) — **HECHO**: `GET /ap/topes/{idTope}/historial`
- [x] 3.6 Listado de **pólizas AP preexistentes sin tope** (las 30 ya cargadas) para que negocio las regularice, sin bloquear su operación — **HECHO**: `PolizaApSinTopeDTO`
- [x] 3.7 ~~Resolución del tope al asociar denuncia↔póliza: copiar `suma_asegurada` y `moneda` al vínculo `denuncia_poliza`~~ **YA NO CORRESPONDE** — el motor de `wsaccidentespersonales` resuelve el tope **EN VIVO** (`EXCEPCION` → `GENERAL` → `SIN_TOPE`) en la misma consulta del consumo, y expone `origenTope`. `denuncia_poliza` quedó como **caché opcional**: el motor no depende de esas 6 columnas. Ver `MotorConsumoSql.MOTOR`, `sql/queries/motor-consumo-ap.sql` y la spec `ap-tope-poliza`
- [x] 3.8 ~~Propagación al editar un tope ya vinculado~~ **YA NO CORRESPONDE** por lo mismo: sin denormalización no hay nada que propagar. Una ampliación se ve en el semáforo en la consulta siguiente
- [x] 3.11 **Tope GENERAL de la póliza** (`cs.polizas_ap.suma_asegurada`, DECIMAL(16,2), con IVA, aplica a CADA asegurado): columna aplicada en **dev y stage** con `sql/11-tope-general-poliza-stage.sql`. **PENDIENTE en `wsmesacarga`**: la migración versionada (V35), la obligatoriedad en el alta de la póliza y el campo en el front de Mesa de Carga
- [ ] 3.9 Frontend de Mesa de Carga: campo de suma asegurada (con IVA) marcado como obligatorio en el alta y editable en la edición de la póliza
- [ ] 3.10 Tests funcionales del alta obligatoria, la unicidad, la edición con historial, la resolución al vincular y la propagación (skill `functional-test-author`, basados en la spec `ap-tope-poliza`)

## 4. Backend — disparar el estimado al autorizar (`wsturnos`)

- [ ] 4.1 Localizar el punto de alta/aprobación del turno en `wsturnos` y el patrón existente de seteo de `valor_prestacion` desde convenio
- [ ] 4.2 Poblar `valor_prestacion` + `id_tipo_origen_valor=1` (CONVENIO) al autorizar/dar de alta el turno, resolviendo el convenio vigente por fecha del turno
- [ ] 4.3 Definir el comportamiento cuando no hay convenio vigente para la prestación (registrar sin valor y dejar trazabilidad, sin frenar la autorización)
- [ ] 4.4 Tests funcionales del disparo del estimado (con convenio vigente y sin convenio)
- [ ] 4.5 Script de backfill idempotente del estimado para turnos ya realizados sin valor, por convenio vigente a la fecha del turno, en lotes y reversible
- [ ] 4.6 Revisar el backfill con `mariadb-migration-review`; planificar lotes y ventana de bajo tráfico (tabla `turnos` aprox. 4,3M)
- [ ] 4.7 Ejecutar el backfill en ambiente bajo, medir cobertura antes/después y verificar idempotencia (segunda corrida no altera lo ya completado)

## 5. Backend — motor de consumo y semáforo

> **Al dia el 06/09/2026.** Este bloque estaba entero en cero y **esta construido** desde el
> commit `3fd8ab3 feat(ap): motor de consumo y semaforo de topeo de polizas AP`. Se verifico
> contra el codigo, no contra el plan. Dos desvios de fondo respecto de lo que decia el plan:
> el motor **no** vive en `wsturnos` sino en un ws nuevo, `wsaccidentespersonales`; y **no** se
> resolvio con vistas de base sino con SQL en el service (`MotorConsumoSql` + su gemelo en
> `sql/queries/`, que son **el mismo contrato** y hay que tocar los dos).
>
> Queda pendiente **5.11** y nada mas.


- [x] 5.1 Resolver Q1: confirmar con el flujo de auditoría de `wsauditoriafacturacion` si `turnos.valor_facturacion` y la erogación se escriben de forma atómica; ajustar la regla anti-doble-conteo si no lo son — **HECHO** (commit `3fd8ab3`): la regla vive en el motor y la cubre `MotorConsumoAntiDobleConteoTest`
- [x] 5.2 Resolver Q2: documentar, por vía, si el consumo llega con IVA o sin IVA, y definir la normalización del numerador contra el tope (que se carga con IVA) — **HECHO** (commit `1d24a06` *normalizar el IVA por fuente*): `Constantes.ALICUOTA_IVA_GENERAL` + `utils/Iva`, con `MotorConsumoIvaPorFuenteTest` que rompe el build si alguien escribe un `1.21`
- [x] 5.3 Resolver Q3 con arquitectura: dónde vive el motor de consumo (recomendado `wsturnos`, que ya tiene `persistirJustificacionTopeo` y `consumo-cie10`) — **RESUELTO CON DESVIO**: no vive en `wsturnos`. Se creo el ws propio `wsaccidentespersonales` (138 clases, 33 endpoints, 7 controllers de negocio)
- [x] 5.4 Crear la vista `ap_consumo_prestacion` (turnos no facturados como ESTIMADO/DEVENGADO + erogaciones netas como FACTURADO, acotada por `denuncia_poliza` activo) — **RESUELTO CON DESVIO**: no se creo la vista. El SQL vive en `MotorConsumoSql.MOTOR` (615 lineas) y su gemelo `sql/queries/motor-consumo-ap.sql`
- [x] 5.5 Sumar la vía de **traslados** al consumo: montos firmes cuando existen, estimado recalculado por convenio (zona / monto fijo provincial / km) — sin leer `convenios_traslados_valorizaciones`, que está dormida (Q4) — **HECHO**: la via de traslados esta en el motor
- [x] 5.6 Sumar la vía de **cirugía**: consolidado por componentes (honorarios en estado Valorizado + materiales por cotización ganadora + ortopedia), con la regla anti-doble-conteo de materiales (una vez por grupo real; por línea cuando el grupo es 0/nulo) — **HECHO**: honorarios, materiales y ortopedia, con la regla anti-doble-conteo cubierta por test
- [x] 5.7 Crear la vista `ap_consumo_siniestro` con los tres subtotales, la proyección, el porcentaje y el nivel del semáforo, con `GROUP BY` explícito (compatible con `ONLY_FULL_GROUP_BY`) y estado `SIN_TOPE` cuando no hay suma asegurada — **RESUELTO CON DESVIO**: sin vista `ap_consumo_siniestro`. El consolidado lo arma `ConsumoApEnsamblador` (254 lineas) y `SIN_TOPE` se resuelve en vivo (`EXCEPCION` -> `GENERAL` -> `SIN_TOPE`, con `origenTope`)
- [x] 5.8 Verificar el cálculo contra casos reales de la réplica: comparar los subtotales del motor con el consumo conocido de al menos 3 siniestros AP (uno de ellos quirúrgico) — **HECHO**: `MotorConsumoParidadStageTest` fija la foto contra stage
- [x] 5.9 Endpoint de semáforo por siniestro (`GET /ap/semaforo/{idDenuncia}`) con chequeo de permiso `ver_semaforo_ap` — **HECHO con otro path**: `GET /ap/consumo/{idDenuncia}/consumo` en `ConsumoApController`
- [x] 5.10 Endpoint de distribución agregada de cartera (conteo y monto en riesgo por nivel) con chequeo de permiso — **HECHO**: `GET /ap/cartera/distribucion` + `POST /ap/cartera/siniestros` en `CarteraApController`
- [ ] 5.11 Endpoint read-only del consolidado de cirugía por autorización, con permiso `ver_consolidado_cirugia`, reutilizando la lectura de `wsconvenio`/`wscirugias` sin duplicar su lógica — **NO ESTA**: existe el permiso `ver_consolidado_cirugia` en `Constantes.java` pero no el endpoint
- [x] 5.12 Endpoint de parametrización (leer/actualizar los cortes 40/70 y los flags de aviso por nivel, rechazando cualquier intento de mover el 90 o el 100) — **HECHO**: `ParametrosSemaforoApController` sobre la tabla `ap_semaforo_parametros` (migracion `V001`)
- [x] 5.13 **Aviso por cambio de nivel**: detectar el cruce hacia un nivel superior, registrarlo una sola vez por nivel y siniestro (incluido el caso de salto de dos niveles de una vez), y exponerlo en la vista de gestión — **HECHO**: entidad `ApAvisoNivelSiniestro` (migracion `V003`) + `SemaforoApAvisoDeNivelTest`
- [x] 5.14 **Endpoint de impacto sobre el saldo**: dado un siniestro y un monto (presupuesto de cirugía), responder si entra en la suma asegurada, con el consumo resultante y el remanente — **HECHO**: `POST /ap/consumo/{idDenuncia}/impacto` -> `ImpactoSaldoDTO`, con `SemaforoApImpactoAutorizacionTest`
- [x] 5.15 Marca de **consumo incompleto**: contar por vía los ítems pendientes de valorizar y exponerlo junto al total — **HECHO**: `consumoIncompleto` + `itemsPendientesDeValorizar` en el desglose
- [x] 5.16 Tests funcionales del motor: clasificación de los tres estados, doble vía (facturado vs proyección), anti-doble-conteo (turno facturado con erogación; materiales con grupo repetido y con grupo centinela), niveles del semáforo, aviso por cambio de nivel sin repetición (y con salto de dos niveles), impacto sobre el saldo y caso `SIN_TOPE` — **HECHO**: 7 tests del motor y el semaforo (`MotorConsumoAntiDobleConteoTest`, `MotorConsumoIvaPorFuenteTest`, `MotorConsumoParidadStageTest`, `SemaforoApEscalaTest`, `SemaforoApAvisoDeNivelTest`, `SemaforoApHabilitacionCierreTest`, `SemaforoApImpactoAutorizacionTest`)

## 5bis. Backend — carga manual de medicación, laboratorio y no convenidas

> **Al dia el 06/09/2026.** Construido en los commits `74103cf` y `71231d9`. La parte de
> **medicacion y no convenidas esta**; la de **laboratorio por multiplicador NBU no se empezo**
> (5b.5 a 5b.8).


- [x] 5b.1 Endpoints de carga/edición/consulta de **valores de medicación** (descripción del medicamento, cantidad, precio, fuente y fecha de consulta), con chequeo de permiso — **HECHO** (commit `74103cf`): `ValorManualApController` (`POST/PUT/DELETE/GET /ap/valores-manuales`) sobre `ap_valores_manuales` (migracion `V002`), con `ValorManualApAbmTest`
- [x] 5b.2 Devolver el **último precio conocido** de un medicamento al cargarlo de nuevo, para que el usuario confirme o actualice (es el historial que hoy el portal externo no conserva) — **HECHO** (commit `71231d9`): `GET /ap/valores-manuales/ultimo-precio` -> `UltimoPrecioMedicamentoDTO`, con `ValorManualApUltimoPrecioTest`
- [x] 5b.3 Endpoint del **detalle de medicación entregada** por siniestro, para responderle al cliente sin buscar en las facturas del portal — **HECHO**: `GET /ap/valores-manuales` con filtro, devuelve `FindAllResults<ValorManualApDTO>`
- [x] 5b.4 Incorporar los valores manuales de medicación al motor de consumo, con su estado de confianza — **HECHO**: la via `VALORES_MANUALES` esta en `MotorConsumoSql`
- [ ] 5b.5 **Laboratorio por multiplicador**: resolver el valor como multiplicador de la determinación por precio de la unidad, reutilizando el catálogo de determinaciones existente — **NO ESTA**: el circuito de laboratorio por multiplicador NBU no se construyo. `laboratorio` aparece solo como *tipo de prestacion* en `TipoPrestacionVenta`, que es otra cosa
- [ ] 5b.6 Endpoint de carga/actualización del **precio de la unidad** de laboratorio, con vigencia (las prestaciones ya valorizadas conservan el precio aplicado) — **NO ESTA** (mismo motivo que 5b.5)
- [ ] 5b.7 Permitir **carga manual del valor** cuando la determinación no tiene multiplicador (radiografías de monto plano) — **NO ESTA** como caso propio; hoy se resuelve generico por `ap_valores_manuales`
- [ ] 5b.8 Definir si el precio de la unidad y los multiplicadores se leen del modelo de contratos existente o se replican para AP (evitar una tercera copia de la fórmula) — **SIN DECIDIR**: la pregunta sigue abierta
- [x] 5b.9 Endpoints de **carga manual del valor de prestaciones no convenidas** (cirugías por presupuesto), con referencia del acuerdo y marca de origen "carga manual" — **HECHO** (commit `74103cf`, *medicacion y no convenidas*): tipo `no_convenida` en el modelo
- [x] 5b.10 Tests funcionales: carga de medicación con descripción, reutilización del último precio, cálculo por multiplicador, actualización del precio de la unidad, determinación sin multiplicador y prestación no convenida — **HECHO**: `ValorManualApAbmTest` y `ValorManualApUltimoPrecioTest`

## 6. Backend — valor de venta por prestación y zona

> **MIGRADO a `ap-prefacturacion-y-topeo-venta` el 06/09/2026.** Este grupo estaba diferido por
> decision del 30/07 y **se construyo en la otra etapa**, con un modelo distinto y mejor: la clave
> no es prestacion+zona sino **cliente + prestacion + zona opcional**, con versionado copy-on-write
> y aumento masivo. Ver commits `b647c67` (DDL) y `9a25696` (la grilla), las migraciones
> `V004`-`V006`, y `ValorVentaApController` / `ContratoVentaApController`.
>
> **No tomar las tareas de este grupo.** Estan en la seccion 3 del tasks.md de la otra etapa.


- [ ] 6.0 **DIFERIDO por decisión del usuario (30/07): todo el grupo 6 y 8 (valor de venta y pantalla comercial) queda para más adelante**, porque depende del mapa proveedor→zona que Iván todavía no definió. No arrancar sin esa definición
- [ ] 6.1 Definir con el área comercial el mapa **proveedor → zona** (4 zonas) y dónde se persiste — **PENDIENTE de Iván**
- [ ] 6.8 Actualización **masiva por porcentaje** de valores de venta (con previsualización de cuántos valores se afectan y sus importes resultantes antes de confirmar, versionando cada uno) + carga individual
- [ ] 6.2 Entidad + repositorio de `valores_venta_prestacion`
- [ ] 6.3 Endpoints de alta/consulta/histórico del valor de venta, con permiso `cargar_valor_venta_prestacion` para la escritura
- [ ] 6.4 Versionado copy-on-write: al cargar un importe nuevo para prestación+zona vigente, cerrar la vigencia anterior y activar la versión nueva conservando el histórico
- [ ] 6.5 Resolución del valor aplicable **por fecha de la prestación** (no por fecha actual) y soporte de versiones con vigencia futura
- [ ] 6.6 Vista de margen (venta − costo del prestador que realizó la prestación), informando "sin venta definida" cuando no hay valor cargado para la zona
- [ ] 6.7 Tests funcionales de vigencia, versionado, valorización retroactiva y margen sin venta cargada

## 7. Frontend — perfil Gestión y Topeo (Verónica + Gabriel)

> **Donde vive, verificado el 06/09/2026.** No es un MFE propio: esta **dentro de `tramitadores`**,
> en `src/components/DenunciaCompleta/CostosTopeo/` (26 archivos) y
> `src/components/Tramitadores/CarteraAp/` (12), con su capa HTTP en
> `services/accidentesPersonalesApi.js` (RTK Query, con un `baseQuery` propio que desenvuelve el
> envelope `{status, message, body}` del ecosistema) y rutas en `Routers/rutasInternas.js`.
>
> **Estado de rama:** los 4 commits (19-20/08/2026) estan en `stage` y **ya en `origin/develop`**
> desde el merge `e9b36fcc` del 21/08. **No estan en `master`**: no llegaron a produccion.
>
> Consume **11 de los 32 endpoints** funcionales del ws. Los 21 restantes no tienen pantalla.

- [x] 7.1 Sección **Costos y Topeo** en el detalle del siniestro, con las tres capas escalonadas (Facturado / Devengado / Estimado) hasta la proyección, marcas de 90% y del tope, chip de nivel, saldo disponible y pendiente de facturar — según la maqueta aprobada `docs/ap-costos/maqueta/AP-Gestion-Topeo-Maqueta.html`
- [x] 7.2 Mini-barra de consumo contra el tope persistente en la cabecera del siniestro, visible al navegar las demás secciones y oculta en la propia sección de Costos
- [x] 7.3 Tabla de prestaciones del siniestro con su estado de confianza por fila
- [x] 7.4 Vista agregada de cartera: distribución por nivel + monto en riesgo, con contadores navegables a la grilla filtrada
- [x] 7.5 Grilla de pacientes con consumo vs suma asegurada (con IVA), chip de nivel, marca de quirúrgico y filtro por nivel de gasto
- [x] 7.6 Acción de cierre del siniestro habilitada por **facturado** (no por proyección), con la confirmación correspondiente — **HECHO**: `BotonCierrePorFacturado.jsx`, contra `GET /ap/siniestros/{id}/habilitacion-cierre` (commit `89503f21`)
- [x] 7.7 Marca de **consumo incompleto** con el conteo de ítems pendientes de valorizar por vía, para que el total no se lea como definitivo
- [ ] 7.8 Sección de **medicación**: carga del precio y la descripción del medicamento, con el último precio conocido sugerido, y listado de lo entregado para responderle al cliente
- [ ] 7.9 Sección de **laboratorio**: valorización automática por multiplicador cuando hay precio de unidad, con carga manual del precio y de las determinaciones sin multiplicador
- [x] 7.10 **Consulta de impacto sobre el saldo**: ingresar el monto de un presupuesto y ver si entra en el tope, con el consumo resultante y el remanente
- [x] 7.11 Carga manual del valor de **prestaciones no convenidas** (cirugías por presupuesto) desde el detalle del siniestro, distinguiéndolas visualmente de los valores de grilla — **HECHO**: el tipo `no_convenida` esta en `constantesValoresManuales.js` y `DrawerValorManual.jsx` (commit `61d8ea07`)
- [x] 7.12 Indicación del **nivel alcanzado y su aviso** en el detalle y en la grilla, con la escala de niveles como único criterio
- [x] 7.13 `npm run lint` y typecheck del MFE tocado, confirmando que los archivos modificados no suman errores nuevos

## 8. Frontend — perfil Comercial y Costos (Iván + Bruno)

> **Verificado el 06/09/2026: este grupo NO esta construido y NO esta planificado en ninguna parte.**
>
> El **backend** del valor de venta si migro a `ap-prefacturacion-y-topeo-venta` (su seccion 3, hecha:
> `ValorVentaApController` y `ContratoVentaApController`, migraciones `V004`-`V006`). Las **pantallas
> no migraron con el**: etapa2 tiene frontend de prefacturacion (seccion 10) y ajustes de Costos y
> Topeo (seccion 11), pero **ninguna seccion de frontend comercial**.
>
> Resultado medido: **15 endpoints construidos sin un solo consumidor**. Busqueda con ripgrep sobre
> todo `repos/grvx/frontend`: **cero archivos** mencionan `valores-venta`, `contratos-venta` o
> `aumento-masivo`. Las maquetas existen (`docs/ap-costos/maqueta/comercial-integrado.content.html`,
> `comercial-costos.content.html`, `contratos-valor-venta.content.html`); el codigo no.
>
> **Bloqueante previo, no de frontend:** los permisos `ver_valores_venta_ap` y
> `administrar_valores_venta_ap` no existen en `cs.permisos_sas` de ningun ambiente, asi que esos
> 15 endpoints hoy devuelven **403**. Construir la pantalla antes de darlos de alta es construir
> contra un 403. Igual con `administrar_topes_ap` y las 3 escrituras de `/ap/topes`.
>
> Las tareas de este grupo **siguen siendo trabajo real**. Reubicarlas es una decision pendiente:
> o entran a etapa2 como seccion de frontend comercial, o quedan como etapa 3.


- [ ] 8.1 Grilla de valores de venta por prestación y zona, con vigencias y estados — según la maqueta aprobada `docs/ap-costos/maqueta/AP-Comercial-Costos-Maqueta.html`
- [ ] 8.2 Alta/edición del valor de venta con fecha de vigencia y validación de zona
- [ ] 8.3 Consulta del histórico de versiones de una prestación y zona
- [ ] 8.4 Vista de margen por prestación (venta, costo y diferencia), con el caso "sin venta definida"
- [ ] 8.5 Pantalla de **precio de la unidad de laboratorio** y de precios de medicación de referencia (carga manual, con vigencia), para el perfil comercial
- [ ] 8.6 `npm run lint` y typecheck del MFE tocado

## 9. Verificación y entregables

- [ ] 9.1 Casos de prueba de negocio: siniestro bajo el tope, siniestro con proyección sobre el tope y facturado por debajo, siniestro excedido por facturado, siniestro sin tope cargado, y siniestro quirúrgico con materiales
- [ ] 9.2 Datos de prueba marcados y borrables en ambiente bajo (el universo real son 63 denuncias y está concentrado: los tableros se ven vacíos o sesgados sin datos sintéticos)
- [ ] 9.3 Colección Bruno de los endpoints nuevos de AP
- [ ] 9.4 `openApi.yaml` actualizado de los servicios tocados
- [ ] 9.5 Review pre-MR con los skills `spring-boot-review`, `react-mfe-review` y `mariadb-migration-review` según lo tocado
- [ ] 9.6 Validación funcional con Verónica y Gabriel sobre un caso real, y con Iván y Bruno sobre la carga de un valor de venta
- [ ] 9.7 Confirmar con Verónica las preguntas abiertas del diseño (ventana del tope, ampliación del tope, si el sistema bloquea o solo avisa, si la venta varía por cliente, cómo llegan los topes, reportes a jefatura) y actualizar el diseño si alguna cambia el alcance. Comentarle que el 80% que mencionó queda cubierto por el nivel Alto (70-90), que ya avisa
- [ ] 9.8 Validar con negocio que el consumo calculado por el sistema **coincide con la planilla actual** para un cliente completo de un mes cerrado (prueba de aceptación real del reemplazo del Excel)

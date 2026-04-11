# Onboarding para humanos del equipo

Este documento es la versión **larga y explicada** del workspace, pensada
para que la lea una persona del equipo cuando arranca a usarlo. Claude
NO la lee en cada sesión (a diferencia de `CLAUDE.md`). Está separada
para mantener el contexto operativo de Claude lo más liviano posible
sin perder explicaciones útiles para nosotros.

Si vos sos Claude y estás leyendo esto: lo lees solo si el usuario te
lo pide explícitamente o si te invocó el skill `onboarding`.

---

## Bienvenido al workspace

Si llegaste hasta acá es porque alguien te dijo "tenemos un workspace
de Claude para acelerar el desarrollo". Esto es eso. No es un producto,
no es un asistente genérico, no es un wrapper de ChatGPT. Es un sistema
interno que combina conocimiento del dominio GRV, prácticas de ingeniería
del equipo, y automatización de procesos, todo integrado a Claude Code.

La filosofía es simple: cualquiera puede instalar Claude Code, pero
**solo nosotros tenemos un Claude que sabe qué es un ATEP, qué tabla
es la fuente de verdad para SRT, o por qué `@Recover` silencioso es
peligroso en este código**. Eso es lo que hace al workspace valioso.

## Quiénes somos en detalle

### AYI

Somos una consultora argentina de software. Nuestro trabajo principal
es construir y mantener plataformas para nuestros clientes. El equipo
que armó este workspace y lo va a usar es el equipo de AYI que trabaja
sobre la plataforma de GRV.

### GRV (Grupo Río Varadero)

GRV es nuestro cliente principal. Es un grupo grande con varias unidades
de negocio. Nosotros tocamos solo algunas:

**Administración de siniestros laborales para clientes ART.** GRV
gestiona los siniestros que las ARTs (aseguradoras de riesgos del
trabajo) tienen que cubrir cuando un trabajador sufre un accidente
de trabajo o una enfermedad profesional. Esto es regulado por la Ley
24.557 y por las resoluciones de la SRT (Superintendencia de Riesgos
del Trabajo). Es la unidad más grande y la que más tiempo nos consume.

**Pólizas de accidentes personales.** Producto distinto del mundo ART:
cobertura individual de accidentes que no necesariamente tienen que ver
con el trabajo. Tiene su propio modelo de negocio, sus propias reglas y
su propia lógica en el sistema.

**Gerenciadora de empleadores autoasegurados.** Algunos empleadores en
Argentina, en lugar de contratar una ART, gestionan sus propios riesgos
del trabajo (con autorización regulatoria). GRV los "gerencia": les
ofrece la infraestructura, los procesos y el sistema para que cumplan
con sus obligaciones. Funciona parecido al mundo ART pero con diferencias
importantes que estamos aprendiendo a documentar.

GRV también tiene otras unidades de negocio sobre las que **no
trabajamos** (todavía o nunca). Si en algún momento alguien te pide
algo sobre esas otras unidades, no asumas que el workspace tiene
información — probablemente no.

## La plataforma

**Más de 30 microservicios en producción.** Esa cifra te dice dos cosas:
hay mucha superficie, y la coordinación entre servicios es un tema real.
No conocés todos los servicios la primera semana. Y eso está bien.

El workspace tiene un mapeo inicial de los servicios más tocados en
`context/microservices.yaml`. Si trabajás en uno que no está mapeado,
podés agregarlo via el skill `workspace-contribution` (ver más abajo).

## Stack en detalle

### Backend

- **Java** con versiones que varían según el servicio. Los más nuevos
  están en Java 21, los más viejos pueden estar en 17 (o más viejos
  todavía, hay que confirmar caso a caso).
- **Spring Boot** como framework principal.
- **Spring Data JPA** para persistencia.
- **HikariCP** como connection pool.
- **Spring Retry** con `@Retryable` y `@Recover` para retries declarativos.
  Cuidado con `@Recover`: hay un patrón histórico donde silenciaba errores
  sin propagarlos, causó al menos un bug grave en producción.

### Base de datos

- **MariaDB / MySQL** en **AWS RDS**.
- Mayoría InnoDB; **algunas tablas legacy en MyISAM** que arrastramos.
- **Migraciones SQL** versionadas en el repo, pero **no usamos Flyway**.
  La herramienta exacta que usamos para aplicar las migraciones está
  pendiente de documentar. Cuando lo confirmemos, lo agregamos al
  workspace.
- 30+ servicios comparten el límite total de conexiones de RDS, lo
  cual ya causó un incidente histórico de pool exhaustion. Los pool
  sizes están tunados ahora pero hay que tener cuidado al introducir
  queries lentas en servicios chicos.

### Frontend

- **React** en formato microfrontend.
- Los microfrontends se componen dentro de un **container-app** (shell).
  La tecnología exacta del shell está pendiente de documentar.
- **Stack heterogéneo**: algunos MFEs nuevos están en TypeScript con
  Redux Toolkit Query, otros más viejos en JavaScript sin RTK Query.
  Cuando vayas a tocar un MFE, primero confirmá su stack — no asumas.
- Los nombres de los MFEs están pendientes de documentar. En
  `context/microservices.yaml` tenemos placeholders tipo
  `[FRONTEND_NAME_MESADECARGA]` que hay que reemplazar con los nombres
  reales cuando los confirmemos.

### Infraestructura

- **Docker** en todos los servicios.
- **Jenkins** para CI/CD.
- **AWS** (EC2, RDS, S3, SQS).
- **Nginx** como reverse proxy.

### Observabilidad

- **Sentry** para error tracking en backend y frontend.
- **Microsoft Clarity** para session analytics en frontends.
- Logs estructurados.

### Mensajería asincrónica

- **SQS** (algunas colas FIFO).
- **Patrón outbox** en servicios donde la consistencia entre BD y
  mensajería es crítica.

## Sistemas de IA del cliente

GRV ya tiene algunos sistemas de IA en producción que usan internamente.
Es importante distinguirlos del workspace que estamos armando, porque son
cosas distintas:

- **ColonIA**: chatbot que provee información a CEM, tramitadores y
  mesa de carga. Está en producción.
- **Agente de informes médicos**: clasifica si un archivo subido a un
  turno médico es efectivamente un informe médico o si se subió otra
  cosa por error. Está en producción.
- **Análisis de métricas del call center**: análisis automatizado sobre
  llamadas de la mesa de atención. En producción.

Estos sistemas tienen sus propios referentes y stacks, parte de lo cual
todavía no está completamente documentado en `context/ai-systems.yaml`.

Aparte de eso, AYI tiene algún POC interno de agente de asistencia que
**no está en producción**. No confundir con el workspace — el workspace
es para el equipo de AYI, los sistemas de IA de GRV son para usuarios
del cliente.

## El dominio en una página

### Concepto base: siniestro laboral

Un trabajador sufre un evento (accidente o enfermedad relacionada con el
trabajo) y la ART tiene que cubrir las consecuencias: atención médica,
remuneración mientras no puede trabajar, indemnización si queda con
secuelas, etc. Todo esto está regulado y auditado por la SRT.

### Tipos de siniestro

- **AT (Accidente de Trabajo)**: evento súbito y violento, ocurrido en
  el trabajo o en ocasión del trabajo.
- **EP (Enfermedad Profesional)**: enfermedad incluida en el listado
  oficial, contraída por el ejercicio del trabajo.
- **In-itinere**: accidente ocurrido en el trayecto entre la casa y el
  trabajo (o viceversa). Cubierto por la misma ley.

### Flujo simplificado de una denuncia

1. **Ingreso**: la mesa de carga registra una denuncia inicial cuando
   el empleador, el trabajador o un tercero reporta el evento.
2. **Clasificación**: AT, EP o in-itinere. Esto define gran parte del
   flujo posterior.
3. **Primera atención médica**: se asigna un turno con un prestador
   (clínica, consultorio). Si el trabajador no puede trasladarse solo,
   se coordina un traslado con una agencia.
4. **Tratamiento**: prestaciones médicas y kinesiológicas según corresponda.
   Cada prestación pasa por autorización previa de la ART.
5. **ILT (Incapacidad Laboral Transitoria)**: durante todo el tratamiento,
   si el trabajador no puede trabajar, la ART le paga ILT. **Detalle
   importante**: el día del accidente NO cuenta como ILT, se considera
   trabajado (Res. SRT 237/96).
6. **Alta médica**: el trabajador se recupera y vuelve al trabajo.
7. **Envío a SRT**: la ART le manda a la SRT un archivo posicional con
   los datos del siniestro. Para AT es Res. 3326/14, para EP es Res. 3327/14.
   Estos archivos tienen reglas estrictas de formato (alineación, padding,
   ancho fijo). Equivocarse en una columna rebota el archivo entero.
8. **Auditoría de facturación**: los prestadores facturan a la ART por
   las prestaciones brindadas. Hay un proceso de auditoría que valida
   que todo esté en orden antes del pago.

Cada paso tiene flujos alternos (rechazos, observaciones, reaperturas)
que están documentados en los skills de dominio del workspace.

## Cómo usar el workspace en el día a día

### Primera vez

1. Cloná el repo.
2. `cp .env.example .env` y completá las credenciales de MariaDB dev.
3. Corré `chmod +x .claude/hooks/*.sh`.
4. Configurá tu git user.name si todavía no lo tenés:
   ```
   git config --global user.name "Tu Nombre"
   ```
5. Abrí Claude Code en la carpeta y pedí: "corré el skill de onboarding".

El skill de onboarding te hace un tour adaptado a tu rol (backend, frontend,
QA, PM, etc) y te sugiere una primera tarea para probar.

### Día a día

Ya en tu trabajo normal:

- **Si vas a tocar una migración SQL**, antes de commitear pedí:
  "revisá esta migración con el migration-guard".
- **Si terminaste un cambio de Java**, pedí:
  "revisá esto con grv-reviewer, es un cambio en wsXXXXX".
- **Si vas a escribir tests**, pedí:
  "armame tests para esto" y vas a ver que el agente te pide la fuente
  de verdad antes de escribir nada. **Eso es a propósito**, no es un bug.
- **Si tenés una duda de dominio**, pedí:
  "preguntale al domain-expert qué pasa cuando..."
- **Si tenés una transcripción de Granola**, pedí:
  "saca action items de la reunión".

### Cuando Claude no sepa algo

Esto va a pasar. El workspace tiene huecos a propósito porque preferimos
que Claude pregunte antes que invente. Cuando preguntes algo y Claude
te diga "no lo tengo documentado, ¿me lo explicás?", vos respondés con
la info real y al final Claude te va a ofrecer **capturarlo como
contribución**.

Si decís "sí", Claude crea una rama `contrib/<tu-nombre>/<slug>` con
el cambio listo para que las LTs revisen. No tenés que hacer un MR a
mano. Es la forma más rápida de mejorar el workspace mientras lo usás.

Si decís "esperar", Claude lo guarda en un buffer local y podés capturar
varias contribuciones juntas más tarde diciendo "armá las contribuciones
pendientes".

### Cosas a tener en cuenta

- **Ambiente por defecto: dev**. Si necesitás consultar prod (típicamente
  para diagnóstico de un bug real), tenés que pedirlo explícitamente y
  Claude te va a pedir confirmación antes de cambiar.
- **PII**: el workspace tiene una heurística que detecta posibles datos
  personales en queries y te advierte. No te bloquea, solo te recuerda
  que son sensibles.
- **Secretos**: hay un hook pre-commit que detecta credenciales obvias
  y bloquea el commit. Si te pasa un falso positivo, podés usar
  `--no-verify`, pero con criterio.

## Cosas que el workspace NO hace

- **No reemplaza el review humano.** Es complemento. Un MR sigue
  necesitando una persona que lo apruebe.
- **No aplica migraciones por su cuenta.** Solo revisa.
- **No mergea contribuciones.** Las propone como MRs en ramas `contrib/*`.
- **No conoce el código entero.** Conoce lo que está en `context/` más
  lo que vos le pasás en cada conversación.
- **No reemplaza la comunicación con el cliente** ni con el resto del
  equipo. Es una herramienta interna.
- **No es un secreto.** Si alguien del equipo pregunta qué es, mostralo
  y explicalo. Cuanto más se use, mejor se vuelve.

## Si encontrás un problema

Tres canales:

1. **Si es un bug del workspace** (un skill que patina, un hook que
   molesta, una validación que es demasiado agresiva), abrí un issue
   en el repo del workspace y mencionalo en la próxima retro.
2. **Si es un bug del código de la plataforma** (no del workspace),
   seguí el proceso normal del equipo: ticket en Jira, MR, etc.
3. **Si es una duda de uso** (no entendés cómo invocar algo, no sabés
   qué skill aplica), preguntale al `[OWNER_NAME]` o al `[COMAINTAINER_NAME]`.

## Para profundizar

- **`README.md`** — vista rápida del repo.
- **`CLAUDE.md`** — el contexto operativo que Claude usa en cada sesión.
  Lo leés si querés entender exactamente qué reglas sigue Claude.
- **`GOVERNANCE.md`** — flujo de cambios al workspace, ownership, ritual
  mensual.
- **`docs/mcp-setup.md`** — cómo configurar los MCPs (MariaDB, Granola, etc).
- **`docs/rollout-plan.md`** — el plan de adopción del workspace en el equipo.
- **`docs/case-studies/`** — ejemplos reales de uso (vacío al inicio,
  se va llenando con casos reales).

Y los YAMLs de `context/` son lectura interesante si querés entender qué
sabe el workspace sin tener que adivinar.

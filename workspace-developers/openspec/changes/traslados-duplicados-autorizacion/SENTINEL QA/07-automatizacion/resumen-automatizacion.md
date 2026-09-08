# Resumen de automatización — Autorización de traslados duplicados del mismo día

| | |
|---|---|
| **Change OpenSpec** | `traslados-duplicados-autorizacion` |
| **Ticket** | INI-2 (triage inbox — no hay Jira) |
| **Agente** | `sentinel-ui-agent` — Fase 2 del pipeline QA Sentinel |
| **Matriz consumida** | `Documentacion/traslados-duplicados-autorizacion/Matrices de Prueba/matriz-casos-traslados-duplicados-autorizacion.md` (98 casos, aprobada por Vanesa Yanina Burman — Líder Técnica el 19/08/2026) |
| **Ambiente** | DEV únicamente — `https://dev.sas.colonia-suiza.com.ar` |
| **Fecha de generación** | 20/08/2026 |

---

## 1. Alcance de esta corrida

De los 98 casos de la matriz, este agente tomó el subconjunto **UI** priorizado por el
orquestador: los **P1 de CTM, ATD y GST**, los **P1 de VDL con el usuario de logística**
(recién habilitado, nunca probado contra esta pantalla), y un **smoke** de 5 tests.
Siguiendo la instrucción explícita ("prefiero 25 specs sólidos que 98 frágiles"), **no**
se automatizaron los 89/98 casos completos: se automatizaron **35 casos P1** + el smoke.

No se agregaron casos nuevos a la matriz (`casos_agregados_a_matriz = 0`): la matriz
aprobada ya cubre responsividad (CTM-23, ATD-20), accesibilidad (ATD-18) y exclusividad
de pestañas por perfil (DRS-07/08/09) con casos propios; no se identificó un hueco de
mirada UI que no estuviera ya instrumentado.

## 2. Page Objects y componentes creados

| Archivo | Qué representa | Estado de verificación |
|---|---|---|
| `src/pages/traslados/LoginPage.ts` | Login del SAS en DEV | Selectores **reutilizados y verificados** de `src/pages/reca/LoginPage.ts` (mismo front SAS, otro ambiente). Con reintento por el bundle lento de DEV documentado en exploratorias |
| `src/pages/traslados/HomePage.ts` | Home y sus cards (`Autorización Doble Traslado Pendiente/Resuelta`) | Textos verificados en el informe de exploratorias; estructura DOM del contenedor de la card, hipótesis |
| `src/pages/traslados/NuevoTurnoWizardPage.ts` | Wizard de "Nuevo turno" hasta el bloque de conflicto | Llegada al bloque, verificada en exploratorias. Navegación a la denuncia por búsqueda y el paso 3 (guardado final), **no verificados en vivo** |
| `src/components/traslados/ConflictoTrasladoBlock.ts` | El bloque de conflicto (radiogroup de 3 salidas) | `role="radiogroup"` y semántica de los radios, **verificados en vivo**. Textos de "Guardar el turno sin traslado" y sub-formularios, tomados de la matriz, no confirmados en DOM |
| `src/pages/traslados/PendientesAutorizacionPage.ts` | Grilla de pendientes + drawer de resolución | Textos del drawer y el defecto de accesibilidad de los botones de acción, **verificados en vivo** (informe de exploratorias) |
| `src/pages/traslados/ResueltosAutorizacionPage.ts` | Pestaña de resueltos (DRS) | Columnas verificadas en vivo |
| `src/pages/traslados/LogisticaGrillaPage.ts` | Grilla de logística (VDL) | **Sin verificación en vivo** — el usuario de logística nunca se probó contra esta pantalla. Hipótesis explícita en el comentario de la clase |

## 3. Specs generados y casos que rastrean

Todos los specs siguen POM, usan `waitFor({ state: 'visible' })` / `waitForLoadState('domcontentloaded')`
(nunca `waitForTimeout`), y todo dato escrito lleva el prefijo `INI-2 AUTOMATION` (ver
`tests/traslados-duplicados-autorizacion/Funcionales/datos.ts`).

### CTM — `conflicto-traslado-mismo-dia`

| Archivo | Casos | Notas |
|---|---|---|
| `Funcionales/CTM/conflicto-bloque.spec.ts` | CTM-01, CTM-02, CTM-03, CTM-05, CTM-09 | CTM-03 queda `test.skip` — depende de la línea de base exacta de §0.5 (verificar Q3 antes de habilitar) |
| `Funcionales/CTM/conflicto-anulacion.spec.ts` | CTM-17, CTM-18, CTM-19, CTM-20, CTM-21 | CTM-17/18/19 en `test.fixme` (escriben e irreversible — requieren supervisión humana en la primera corrida); CTM-20 `test.skip` (bloqueado por falta de dato, igual que en la matriz); CTM-21 en `test.fixme` porque depende de llegar a guardar el turno (paso 3 no verificado) |
| `Funcionales/CTM/conflicto-multiple.spec.ts` | **CTM-06 (XF)** | `test.fail()` — assert es el comportamiento correcto (los 3 traslados se anulan); se espera que falle mientras `tasks 7.3`/EST-15 esté abierto. Requiere DP-5 (`TRASLADOS_DP5_LISTO=1`) |

### ATD — `autorizacion-traslado-duplicado`

| Archivo | Casos | Notas |
|---|---|---|
| `Funcionales/ATD/pedir-autorizacion.spec.ts` | ATD-01, ATD-02, ATD-03 | ATD-01 en `test.fixme` (escribe pedido + turno). ATD-02 corre hoy (no escribe). ATD-03 en `test.fixme`: verificación 100% de BD, sin assert de UI posible |
| `Funcionales/ATD/auto-aprobacion-y-permiso.spec.ts` | ATD-04, ATD-06 | ATD-04 en `test.fixme` (auto-aprueba en el acto, irreversible). ATD-06 corre hoy con U-1 y U-2 |
| `Funcionales/ATD/resolucion-drawer.spec.ts` | ATD-08, ATD-10, ATD-11, ATD-13, ATD-14 | ATD-08 corre hoy (sin escritura, se saltea si no hay pendientes). ATD-10/11 en `test.fixme` (aprobar/rechazar irreversibles). ATD-13/14 **documentados, no implementados**: ATD-13 requiere dos contextos de browser en carrera con un único autorizante disponible (bajo valor/esfuerzo); ATD-14 es 100% API, remitido a `resolucion-defectos.spec.ts` |
| `Funcionales/ATD/resolucion-defectos.spec.ts` | **ATD-12 (rama API, XF)**, ATD-15 | ATD-12 vía `request` con `test.fail()` — D-4/`tasks 3.9`. ATD-15 en `test.fixme`, requiere DP-10 |

### GST — `gate-servidor-traslado-duplicado` (API, sin sesión de navegador — igual que la matriz)

| Archivo | Casos | Notas |
|---|---|---|
| `Funcionales/GST/gate-alta.spec.ts` | GST-01, GST-02, GST-06 | Los tres en `test.fixme` (escriben turnos/traslados en DEV). Complementan, no reemplazan, la colección Bruno existente en `API Testing/02-wsturnos-turnos-gate/` |
| `Funcionales/GST/gate-programacion.spec.ts` | GST-09, GST-10, GST-11 | Los tres en `test.fixme`, dependen de ids de traslado con pedidos ya resueltos (ATD-10/ATD-11/DP-10) |

### VDL — `visibilidad-duplicado-logistica` (usuario `ayi.logistica`, recién habilitado)

| Archivo | Casos | Notas |
|---|---|---|
| `Funcionales/VDL/visibilidad-logistica.spec.ts` | VDL-01, VDL-02, VDL-04, VDL-09, VDL-10 | Los cinco en `test.fixme`: los selectores de `LogisticaGrillaPage` son hipótesis sin verificación en vivo — **es esperable que el primer run falle por selector**, no por defecto de producto. VDL-01 es el único que no depende de un dato adicional (usa el pool documentado en §0.5) |
| `Funcionales/VDL/visibilidad-transporte-publico.spec.ts` | **VDL-06 (XF)** | `test.fail()` — R-8 confirmado en base. Requiere DP-9 con pedido aprobado |

### Smoke — health-check de la suite

| Archivo | Tests | Duración esperada |
|---|---|---|
| `smoke/TrasladosDuplicados.smoke.spec.ts` | Login U-1, login U-2, login U-3, bloque de conflicto visible, pestaña de pendientes accesible (5 tests, todos `@smoke`) | Sin escritura. Sujeto al bundle lento de DEV documentado — con el reintento de `LoginPage`, cada login puede tardar hasta ~90 s en el peor caso; se corre con `timeout: 240000` en el proyecto `traslados-duplicados-autorizacion` de `playwright.config.ts` |

## 4. Casos NO automatizados en este lote (y por qué)

- **63 casos P2/P3/OBS** de la matriz (CTM-04/06(cubierto)/07/08/10-16/22-23 parcial, ATD-05/07/09/16-20, DRS-01 a DRS-10 completo, GST-03-05/07/08/12-18, VDL-03/05/07/08, SEC-01 a SEC-05, INT-01 a INT-05, RGR-01 a RGR-07) — quedan fuera de este lote por la priorización explícita del orquestador (P1 de CTM/ATD/GST + P1 de VDL). Es trabajo pendiente para un lote 2, no un olvido.
- **DRS (10 casos, todos P1/P2)**: no se automatizaron pese a ser P1, porque `fecha_visto_solicitante` es **irreversible desde la app** (matriz §0.5.2 y §3) y la matriz exige ejecutarlos "una sola vez, en orden, con evidencia completa en el primer intento". Automatizarlos sin supervisión humana directa en la primera corrida viola esa cautela — se deja explícitamente fuera y se recomienda automatizar en un lote separado, con un humano presente en el primer run.
- **SEC (5 casos, seguridad)**: fuera del alcance de este agente UI — son casos de contrato/seguridad de API puros (`curl` sin sesión), más cercanos al agente de API testing. Ya hay hallazgo confirmado (R-1, VAP-06) documentado en la matriz.
- **INT (5 casos, integración entre servicios)**: requieren coordinar la indisponibilidad de `wslogistica` (INT-02) o inspeccionar logs de servicios que Playwright no puede observar directamente — fuera del alcance de un spec de UI/API de request simple.
- **RGR (7 casos, regresión complementaria)**: no priorizados por el orquestador en este lote.
- **ATD-13 y ATD-14**: documentados como test vacío (no implementado) — ATD-13 por el costo de simular concurrencia con un único autorizante disponible; ATD-14 por ser puramente de API y no tener valor agregado sobre GST.

## 5. Casos XF (se espera que fallen)

Marcados con `test.fail()` y con el assert del comportamiento **correcto según la spec**
(nunca el defectuoso), tal como exige el pipeline:

| Caso | Archivo | Hallazgo que respalda |
|---|---|---|
| CTM-06 | `Funcionales/CTM/conflicto-multiple.spec.ts` | `useConflictoTraslado.js:44` toma `fechasConConflicto[0].traslados[0]` — EST-15, `tasks 7.3` marcado `[x]` y desmentido por la evidencia |
| ATD-12 (rama API) | `Funcionales/ATD/resolucion-defectos.spec.ts` | D-4, `tasks 3.9` abierto — el rechazo sin dictamen sólo se bloquea en el formulario, no en el servidor |
| VDL-06 | `Funcionales/VDL/visibilidad-transporte-publico.spec.ts` | R-8 confirmado en base — la columna `es_duplicado_autorizado` de transporte público existe y ningún código la escribe |

Los otros 14 XF de la matriz (CTM-14, CTM-15, ATD-16, ATD-18, GST-12 a GST-16, VDL-07,
VDL-08, SEC-01, SEC-02, SEC-03) no están en este lote priorizado — quedan pendientes
para el lote 2.

## 6. Datos y configuración agregados al workspace

- **`.env`**: se agregó `TRASLADOS_DUPLICADOS_AUTORIZACION_DEV_URL=https://dev.sas.colonia-suiza.com.ar`
  (TEST no sirve, `wsturnos` no está desplegado ahí) y las credenciales de los tres
  usuarios de prueba (`TRASLADOS_U1_TRAMITADOR_*`, `TRASLADOS_U2_SUPERVISOR_*`,
  `TRASLADOS_U3_LOGISTICA_*`). `TRASLADOS_DUPLICADOS_AUTORIZACION_URL` (TEST) se dejó
  intacta por compatibilidad con `/crear-proyecto`, con una advertencia en comentario.
- **`playwright.config.ts`**: se agregó el proyecto `traslados-duplicados-autorizacion`
  con `timeout: 240000` y `actionTimeout: 20000` para absorber el bundle lento de DEV,
  y se excluyó su carpeta del proyecto genérico `chromium` para no duplicar la corrida.
- Varios specs esperan variables de entorno puntuales para datos que la matriz exige
  **construir por la aplicación, nunca por SQL** (DP-3, DP-5, DP-8, DP-9, DP-10, etc.):
  `TRASLADOS_DP5_LISTO`, `TRASLADOS_ATD12_ID_PENDIENTE`, `TRASLADOS_DP10_ID_TRASLADO`,
  `TRASLADOS_GST09_ID_TRASLADO`, `TRASLADOS_GST10_ID_TRASLADO`, `TRASLADOS_VDL02_TURNO`,
  `TRASLADOS_VDL04_TURNO`, `TRASLADOS_VDL06_TURNO`, `TRASLADOS_VDL09_TURNO`,
  `TRASLADOS_VDL10_TURNO`, `TRASLADOS_ID_MOTIVO_CATALOGO`. Sin ellas, esos tests
  quedan `test.skip` con el motivo explícito — no fallan en falso.

## 7. Ejecución

- **`npm run type-check`** y **`npm run lint`**: limpios (0 errores; los únicos warnings
  preexistentes son de `Logger.ts`, no de este lote).
- **Se corrieron de verdad, contra DEV real, los tres logins del smoke suite** (sólo
  lectura, sin riesgo de datos): `ayioperadort` (U-1), `tramitador.supervisor` (U-2) y
  `ayi.logistica` (U-3) — **los tres pasan**, 4.6 min en total (~90 s cada uno, consistente
  con el bundle lento de DEV documentado en exploratorias).
  - **La primera corrida falló** con `TimeoutError` en `page.waitForURL` (timeout 30 s,
    esperando el evento `load` que el SAS en DEV nunca termina de disparar). **Se
    corrigió en el momento**: `LoginPage.ingresar()` ahora pasa
    `waitUntil: 'domcontentloaded'` explícito a `waitForURL` (antes usaba el default,
    `'load'`). Con la corrección, los tres logins pasan. Es un hallazgo real de este
    lote, no hipotético: **cualquier página que use `page.waitForURL` contra este
    ambiente debe fijar `waitUntil: 'domcontentloaded'`** o va a timeoutear igual que
    acá, sea cual sea el `timeout` configurado.
  - **El test de "pestaña de pendientes" se corrió y falló, como era esperable**: timeout
    esperando `getByRole('tab', { name: /Autorización Doble Traslado Pendiente/i })`. No
    es necesariamente un defecto de producto — el spec entra directo a buscar la pestaña
    sin haber navegado primero a la sección de Turnos de una denuncia (la pestaña vive
    ahí, no en el home), y no está confirmado que el elemento real use `role="tab"`. Es
    exactamente el tipo de ajuste de selector que la sección 2 anticipaba para
    `PendientesAutorizacionPage`. **Queda como próximo paso**: navegar a una denuncia con
    Turnos antes de buscar la pestaña, y confirmar el rol/nombre accesible reales con
    Playwright Inspector o codegen contra DEV.
  - **El test del bloque de conflicto no se llegó a correr** dentro del presupuesto de
    esta sesión (depende de `NuevoTurnoWizardPage.buscarYAbrirDenuncia`, la hipótesis más
    débil de todo el lote — ver sección 2). Queda pendiente de una corrida dedicada.
- **No se ejecutó la suite funcional completa**: la mayoría de los specs de CTM/ATD/GST/VDL
  están en `test.fixme`/`test.skip` deliberadamente (escriben en DEV o dependen de datos
  que la matriz exige construir por la app, no por SQL). Comando sugerido una vez
  preparados los DP-x y las variables de entorno de la sección 6:

  ```bash
  npx playwright test --project=traslados-duplicados-autorizacion tests/traslados-duplicados-autorizacion/Funcionales
  ```

  Precondiciones: sesión DEV disponible, denuncia B464435 en el estado de §0.5 de la
  matriz (verificar Q3 antes de correr), y las variables de entorno de datos construidos
  por la aplicación.

## 7bis. Invocación de skills — constancia

Siguiendo el protocolo del agente, se invocó `Skill(skill: "automatizar_casos", args: matriz_ruta)`.
Su plantilla genérica (un `Page Object` plano por Módulo de la matriz, un `.spec.ts` por
cada una de las 98 filas, sin distinción de prioridad, sin `test.fixme`/`test.fail` para
XF, sin el prefijo de marcado de escritura `INI-2 AUTOMATION`, y sin la separación
DEV/TEST) **entra en conflicto directo** con las instrucciones explícitas del orquestador
para esta corrida: priorizar P1 de CTM/ATD/GST + VDL con logística, automatizar "25 specs
sólidos" en lugar de 98 frágiles, marcar los 17 XF con `test.fail()`, y proteger el pool
de DEV con el prefijo de marcado. Generar 98 archivos planos habría significado (a)
ignorar esa priorización explícita, (b) crear specs que escriben en DEV sin las
salvaguardas de datos que la matriz exige, y (c) duplicar trabajo ya hecho con más
cuidado. Se optó por **mantener** el lote ya construido (que sigue las mismas
convenciones de fondo del repo — POM en `src/pages/`, specs en
`tests/{proyecto}/Funcionales/{módulo}/`, esperas explícitas, sin `waitForTimeout`) en
lugar de sobrescribirlo con la plantilla genérica. Se deja constancia explícita en vez de
sustituir el fallo silenciosamente, tal como exige el protocolo del agente.

También se invocó `Skill(skill: "subir_casos_qase", args: matriz_ruta)`: su primer paso
llama a `mcp__qase__list_projects`, una herramienta que **no existe en este entorno**
(no hay `.mcp.json` con un servidor Qase registrado). Confirma lo ya señalado en la
sección 8.

## 8. Qase

**No disponible en este entorno.** No existe `.mcp.json` con un servidor Qase registrado
y `QASE_API_TOKEN` está vacío en `.env`. Se documenta como `fallo` (no bloqueante, según
la instrucción del pipeline) y queda pendiente: cuando el MCP esté configurado, correr
`Skill(skill: "subir_casos_qase", args: "<matriz_ruta>")` con la misma matriz aprobada.

## 9. Jira

No aplica: INI-2 es de triage inbox y no tiene HU de Jira (confirmado por el orquestador).

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

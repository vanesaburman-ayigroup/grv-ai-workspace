# Auditoría del entregable — Manual de usuario "Traslados duplicados" (SAS Colonia Suiza)

**Alcance:** control de calidad **del material** entregado en `08-manual-usuario/` y de los specs de Playwright agregados. No se audita el comportamiento del software.

**Fecha de auditoría:** 19/08/2026

---

## 1. Tabla de verificaciones

| # | Punto auditado | Método de verificación | Resultado |
|---|----------------|------------------------|-----------|
| 1.1 | `Manual-...docx` — existen las tres etapas (gestor, autorizante, logística) | `python-docx`, recorrido de estilos `Heading` | **APROBADO** — Heading 1 «4. Etapa 1 – El gestor…», «5. Etapa 2 – El autorizante…», «6. Etapa 3 – Logística…» |
| 1.2 | `Manual-...docx` — imágenes embebidas | `len(d.inline_shapes)` + inspección del paquete OOXML (`word/media/`) | **APROBADO** — 36 `inline_shapes`, 39 partes en `word/media/` (5,8 MB), ninguna de 0 bytes, todas con ancho > 0. Sin enlaces externos a imagen |
| 1.3 | `Manual-...docx` — preguntas frecuentes | Sección «7. Preguntas frecuentes» | **APROBADO** — 12 preguntas con respuesta (P1 a P12) |
| 1.4 | `Manual-...docx` — glosario | Sección «8. Glosario» | **APROBADO** — tabla de 20 filas (`Término` / `Qué significa en este circuito`) |
| 1.5 | `Manual-...docx` — sin identificadores internos, tablas de BD, endpoints ni código | Volcado de los 378 párrafos + 10 tablas y barrido con patrones (`id_*`, `*_id`, SQL, `/api/`, `http`, `localhost`, rutas de archivo, extensiones `.ts/.php/.sql/.json`, `data-testid`, tags HTML, tokens `MAYUS_MAYUS`) | **APROBADO** — 0 coincidencias. Ver nota (a) sobre los códigos `MAN-*` |
| 2.1 | `infografia-...html` — autocontenida | Búsqueda de `src="http`, `<link`, `@import`, `<script src>`, `url(...)` no-data y cualquier `http(s)://` | **APROBADO** — 0 coincidencias en todas las categorías. Sin CDN, sin Google Fonts, sin hojas externas, sin scripts |
| 2.2 | `infografia-...html` — `@page` y `@media print` | Búsqueda directa | **APROBADO** — ambas reglas presentes |
| 2.3 | `infografia-...html` — logos en base64 | Inspección de los `<img>` | **APROBADO** — 5 imágenes, todas `data:image/png;base64`, incluido el logo negativo (`class="logo-neg"`) |
| 2.4 | `infografia-...html` — tres etapas visibles | Volcado de texto | **APROBADO** — bloque «El circuito, en tres etapas» con GESTOR / AUTORIZANTE / LOGÍSTICA numeradas 1-2-3 |
| 2.5 | `infografia-...html` — cuatro resultados con lo que ve logística | Volcado de texto | **APROBADO** — bloque «Los cuatro resultados, y qué ve logística en cada uno»: Pendiente (NO lo ve), Aprobado (SÍ, y llega marcado), Rechazado (nunca lo vio), Anulado (salida A); cada fila con columna «¿Lo ve logística?» y «Qué se espera del sector» |
| 3 | Capturas — toda imagen referenciada existe y pesa > 0 | Extracción de las referencias `![](capturas/…)` de los 5 `.md` y validación en disco | **APROBADO** — **0 referencias rotas**, 0 archivos vacíos. 36 referencias únicas ↔ 36 PNG en `capturas/`, sin huérfanas |
| 4.1 | `seccion-*.md` — sin marcadores `{ALGO}` sin resolver | Búsqueda de llaves con contenido alfanumérico en los 3 archivos | **APROBADO** — 0 coincidencias (también 0 en `manual-usuario-traslados-duplicados.md`) |
| 4.2 | `seccion-*.md` — sin rutas absolutas de Windows en el cuerpo | Búsqueda de `C:\`, `letra:/Users`, `/c/Users`, `Documents/Proyectos` | **APROBADO** — 0 coincidencias |
| 5.1 | Specs de Playwright — cantidad agregada | Listado con fecha de modificación | **APROBADO** — 14 specs en `Funcionales/`, de los cuales **3 nuevos** de esta entrega: `CTM/manual-gestor.spec.ts` (6 tests), `ATD/manual-autorizante.spec.ts` (8 tests), `VDL/manual-logistica.spec.ts` (12 tests) = **26 tests nuevos**. `Funcionales/datos.ts` también actualizado el 21/08 |
| 5.2 | Specs de Playwright — compilan | `npx tsc --noEmit` en `QA_Sentinel` | **APROBADO** — salida vacía, **0 errores**. `tsc --listFiles` confirma que los 3 archivos nuevos entran al programa (16 archivos del proyecto incluidos; `include: ["src/**/*","tests/**/*","*.ts"]`, `strict: true`) |

---

## 2. Notas y observaciones (no bloqueantes)

**(a) Códigos `MAN-G-*`, `MAN-A-*`, `MAN-L-*` en el manual.** Aparecen 23 veces. No se computan como filtración técnica porque el propio manual los introduce como convención dirigida al usuario final: «Cada uno trae un código (por ejemplo MAN-G-01) que podés mencionar si tenés que reportarlo a mesa de ayuda». Son códigos de mesa de ayuda, no identificadores de repositorio, ticket, tabla ni endpoint. Se deja registrado para que la decisión quede explícita y no a criterio del lector.

**(b) Sigla `FKT`** (párrafo del Paso 5 de la Etapa 2). Es una sigla del sistema, pero el manual la expone *explicándola* («por ejemplo FKT por kinesiología») y en el contexto de un defecto cosmético reportado (`MAN-A-07`). Correcto como está. Ídem `RAR` y `SAS`, que son rótulos de pantalla y nombre de producto, no artefactos técnicos.

**(c) Archivos intermedios de trabajo dentro de la carpeta del entregable.** Conviven con el material publicable:

- `_gen_docx_manual.py` (17,7 KB)
- `_prep_md_docx.py` (4,0 KB)
- `_manual-docx.md` (55,5 KB, insumo del generador)
- `_descartadas-deploy-1032/` (capturas de una corrida anterior, con nomenclatura distinta a la vigente)

No afectan ninguna verificación —no están referenciados por el material entregado—, pero si la carpeta se comparte tal cual, el destinatario recibe scripts y capturas descartadas junto al manual.

**(d) Salto en la numeración de capturas.** En la serie del autorizante falta el número 06 (`02-autorizante-05-…` → `02-autorizante-07-…`) y existe una captura fuera de serie, `02-autorizante-defecto-ver-info.png`. **No genera referencia rota**: nada apunta al 06 y la captura fuera de serie sí está referenciada. Es sólo una discontinuidad de nomenclatura.

---

## 3. Correcciones necesarias

**Bloqueantes: ninguna.** No se detectaron referencias rotas, marcadores sin resolver, contenido faltante, filtraciones técnicas al material de usuario ni errores de compilación.

Correcciones opcionales, de higiene del entregable:

1. Mover `_gen_docx_manual.py`, `_prep_md_docx.py`, `_manual-docx.md` y `_descartadas-deploy-1032/` fuera de la carpeta de entrega (o a un subdirectorio `_fuentes/` excluido de la distribución), para que lo que se comparte sean sólo el `.docx`, la infografía, los `.md` y `capturas/`.
2. Cerrar el salto del 06 en la serie del autorizante, renumerando o renombrando `02-autorizante-defecto-ver-info.png` dentro de la serie, de modo que el orden de lectura quede evidente para quien mantenga el material.

---

## 4. Veredicto final

# APROBADO

Las 16 verificaciones del alcance dieron APROBADO. El `.docx` tiene las tres etapas, 36 imágenes embebidas en el paquete, 12 preguntas frecuentes y un glosario de 20 términos, sin una sola filtración técnica al material de usuario. La infografía es estrictamente autocontenida —ningún recurso externo, logos en base64— y es imprimible (`@page` + `@media print`), cubriendo las tres etapas y los cuatro resultados con lo que ve logística en cada uno. Las 36 referencias a capturas resuelven a archivos existentes y no vacíos. Los tres `seccion-*.md` no tienen marcadores sin resolver ni rutas absolutas. Los 3 specs nuevos (26 tests) compilan sin errores bajo `strict`.

Las dos correcciones listadas son de higiene de carpeta y no condicionan la publicación del material.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026

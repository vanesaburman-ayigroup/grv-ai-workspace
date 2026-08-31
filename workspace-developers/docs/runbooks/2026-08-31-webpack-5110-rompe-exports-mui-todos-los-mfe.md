---
ticket: null
fecha-deploy: 2026-08-31
ws-afectado: grv-frontend, auditoriamedica, tramitadores, mesadecarga, solicitudesgenericas
version-ws: n/a
mr: https://gitlab.com/grvx/frontend/frontend/-/merge_requests/2061
tickets-relacionados: [SE-199]
tipo-fix: hotfix-operativo
---

# 2026-08-31 — webpack 5.110 rompió el build de todos los MFE con MUI 7

## Síntoma reportado

El build de los microfrontends empezó a fallar **solo**, sin que nadie tocara el código. Decenas de errores de webpack, todos con la misma forma:

```
ERROR in ./node_modules/@mui/material/esm/Accordion/Accordion.js 7:0-55
export 'default' (imported as 'chainPropTypes') was not found in
'@mui/utils/chainPropTypes' (module has no exports)
```

Cantidades: `grv-frontend` 75 errores, `auditoriamedica` 59, `tramitadores` 59, `mesadecarga` 59.

**Cero errores en `./src` en todos los casos.** El código propio nunca estuvo involucrado.

Los MFE fueron cayendo **de a uno, en distintos momentos**, lo que hizo parecer que era culpa de cada cambio que se estaba subiendo.

## Diagnóstico

Lo que lo delató fue comparar dos builds del **mismo proyecto**:

| Build | webpack | Resultado |
|---|---|---|
| verde, 26/08 | **5.109.2** | `compiled with 2 warnings` |
| rojo, 31/08 | **5.110.2** | `compiled with 75 errors` |

Mismo commit de configuración, mismo Node (v18.18.0), **mismo árbol de dependencias** (1633 paquetes, los mismos 33 `deprecated`). Lo único distinto era la versión de webpack.

Comando que da la respuesta en un paso:

```bash
aws logs get-log-events --log-group-name GRV-SAS-dev-<mfe> --log-stream-name <stream> \
  --profile grv-sas --region us-west-2 --output text --query 'events[].message' \
  | grep -oE "webpack 5\.[0-9.]+ compiled.*"
```

Y para descartar que sea código propio:

```bash
... | grep -c 'ERROR in ./src'     # 0 = el problema no es del repo
```

> ⚠️ El CLI de AWS **revienta** al imprimir estos logs en consola Windows (`'charmap' codec can't encode character '✖'`, el ✖ de ESLint). Hay que forzarle UTF-8 por entorno:
> ```python
> env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
> subprocess.run([...], env=env, capture_output=True)
> ```

### Callejones sin salida (para no repetirlos)

Antes de dar con webpack se descartaron, en este orden:

1. **La versión de `@mui/utils`.** Se probó un `overrides` fijándola en 7.3.11 y **fue un no-op**: el árbol instalado resultó idéntico con y sin él (1633 paquetes), porque ya se resolvía en 7.3.11. Ese intento se revirtió.
2. **Integridad del paquete.** El tarball de `@mui/utils@7.3.11` en Nexus tiene el mismo `shasum` que npmjs (`493f46f0…`). No hubo republicación.
3. **Caché de CodeBuild.** `grv-frontend` corre con `NO_CACHE`.
4. **El entorno.** Node idéntico; ni `webpack.config.js`, ni `pom.xml`, ni `.npmrc`, ni babel cambiaron entre el verde y el rojo.
5. **El fallback Nexus → npmjs.** Aparece incluso en builds verdes y no intervino en los fallidos.

## Causa raíz

Son **dos cosas que se combinan**, y ninguna es un cambio de nadie del equipo:

**1. El build no es reproducible.** El `package.json` declara rangos abiertos (`"webpack": "^5.89.0"`) y el `package-lock.json` **está desincronizado** con él — por ejemplo, en `grv-frontend` el package pide `sas-component-lib` 7.9.0 y el lock tiene 7.7.1. Con el lock inconsistente npm lo descarta, y CodeBuild encima corre `npm install --force`, que desactiva las protecciones de peer dependencies. Resultado: **cada build baja la última versión publicada de cada dependencia**. Dos builds del mismo commit, en días distintos, instalan cosas distintas.

**2. webpack 5.110 cambió la resolución de `exports`.** Se publicó `5.110.0` y `5.110.1` el **27/08** y `5.110.2` el **30/08**. Esa serie endureció cómo se resuelve el campo `exports` de los paquetes. Y `@mui/utils@7.3.11` publica sus subpaths con un wildcard:

```json
"./*": {
  "require": { "default": "./*/index.js" },
  "default": { "default": "./esm/*/index.js" }
}
```

Con 5.110 ese wildcard deja de resolverse. Como el bundle ESM de `@mui/material` 7.x importa `chainPropTypes`, `exactProp`, `elementTypeAcceptingRef`, `HTMLElementType`, `integerPropType` y `elementAcceptingRef` desde esos subpaths, todos fallan a la vez.

**Por qué caen de a uno:** cada MFE rompe recién cuando alguien dispara su build. Los que nadie tocó desde el 26/08 se ven verdes, pero es una foto vieja: van a romper en su próxima corrida.

## Fix aplicado

Pin de `webpack` en **5.109.2** — la última versión con la que estos MFE compilaban — en el `package.json` de cada MFE:

```diff
-  "webpack": "^5.89.0",
+  "webpack": "5.109.2",
```

| MFE | MR | Resultado |
|---|---|---|
| `grv-frontend` | !2061 | ✅ verde |
| `auditoriamedica` | !783 | ✅ verde |
| `tramitadores` | !1867 | ✅ verde |
| `mesadecarga` | !561 | ✅ verde |
| `solicitudesgenericas` | !252 | preventivo |

**Es un parche, no la solución.** Mientras el build siga corriendo `npm install --force` con los lockfiles desincronizados, la próxima publicación de cualquier dependencia puede repetir esto con otro paquete.

## Reproducción para futuros casos

Para saber si un MFE está en riesgo, mirar su `package.json` en `develop`:

```bash
git show origin/develop:<ruta>/package.json | python -c "
import json,sys
j=json.load(sys.stdin)
d={**j.get('dependencies',{}), **j.get('devDependencies',{})}
w=d.get('webpack'); m=d.get('@mui/material')
print('EN RIESGO' if (w and w.startswith('^') and m and '7.' in m) else 'ok', w, m)"
```

Estado al 31/08/2026:

| MFE | webpack | MUI | Estado |
|---|---|---|---|
| `grv-frontend`, `auditoriamedica`, `mesadecarga`, `tramitadores` | 5.109.2 | 7.x | pineado |
| `solicitudesgenericas` | 5.109.2 | 7.3.11 | pineado (MR abierta) |
| **`containerapp`** | `^5.89.0` | 7.3.11 | ⚠️ **en riesgo** |
| `contrataciones` | `^5.89.0` | 7.3.11 | ⚠️ en riesgo |
| `logistica` | `^5.94.0` | 7.3.2 | ⚠️ en riesgo |

**`containerapp` es el más delicado**: es el shell single-spa que monta a todos los demás. Si rompe, no se cae un módulo, se cae la aplicación entera.

## Tickets y MRs relacionados

- Issue de plataforma: `grvx/arquitectura/workspace-architech#1` — build no reproducible, con las decisiones pendientes.
- Se detectó desplegando **SE-199** (relación CIE-10 ↔ naturaleza ↔ zona) a DEV. El ticket no tiene relación con la causa: fue el primer build que la pisó.
- `tramitadores` empezó a fallar el 31/08 a las **08:45**, más de dos horas antes del primer merge de SE-199. Fue la prueba de que el disparador era externo.

## Lecciones / TODO

- [ ] **Regenerar y commitear los lockfiles.** Es el prerrequisito de todo lo demás: hoy el lock no describe lo que se instala.
- [ ] **Pasar a `npm ci`** en el buildspec. Instala exactamente el lock y falla si está desincronizado, en vez de inventar un árbol nuevo en cada corrida. ⚠️ Con los locks como están hoy **falla de entrada** — por eso primero lo anterior.
- [ ] **Quitar `--force`**, que hoy oculta conflictos reales de peer dependencies.
- [ ] Definir una **política de pineo para dependencias de build** (`webpack`, `babel`, loaders): exacto o `~`, para que una publicación de terceros no pueda cambiar el resultado.
- [ ] Pinear `containerapp`, `contrataciones` y `logistica` antes de que alguien los toque.
- **Ante un build que se rompe solo**: lo primero es contar `ERROR in ./src`. Si da 0, no perder tiempo revisando el código propio — comparar la versión de las herramientas contra el último build verde.

# GLPI 2738 - Consumidores de getLogoCliente / nombreLogo / LogosClientes / clientes.logo_img

Escaneo local sobre `repos/grvx/` (backend 107 carpetas, frontend 36, incluidas worktrees `-wt-` que se ignoran). Solo lectura. Lib leida desde `origin/master` (a1941e9, 4.23.1, 18/09/2026), sin cambiar de rama.
Versiones de `sas-modules-features-lib` leidas del `package.json` del checkout actual de cada MFE (cada uno esta en una rama distinta, ver columna rama).

## Veredicto

- **Backend: no hay que tocar nada.** `nombreLogo` ya llega bien (nombre del cliente sin espacios ni puntos). El problema es solo de cobertura en el front (14 logos para 44 clientes).
- **Se toca**: `libreriamodulosgrv` (utils + assets + DatosDenuncia), y bump de version en los 6 MFE que usan `CabeceraDenuncia` de la lib. Ademas hay **3 copias propias del switch** (grv-frontend, contrataciones, portalclientes) que NO se arreglan con la lib y requieren su propio cambio si tambien deben mostrar logo nuevo.
- `cs.clientes.logo_img` (`LOGO_IMG`, `USA_LOGO`): mapeado en `libdatabase/.../entities/Cliente.java:32,35`, **sin ningun consumidor** (solo getter/setter). En BD solo 2 clientes lo tienen (PROVINCIA ART `images/provart.gif`, COLONIA SUIZA SALUD `images/colonialogo.gif`); es legado, no sirve de fuente.

## Backend (productores de nombreLogo)

| Archivo:linea | Que hace |
|---|---|
| `backend/wsdocumento/.../serviceDTO/DenunciaSuperServiceDTOImp.java:545,1600-1603` | `nombreLogo = cliente.getNombre()` sin " " ni "." (denuncia completa). Es el que alimenta el detalle de denuncia |
| `backend/wsdocumento/.../dto/denuncias/DenunciaCompletaDTO.java:100,853-858` | campo DTO |
| `backend/wspersona/.../services/PersonaService.java:392,453-463` | idem con `cliente.getNombre()` (vigencia empleador) |
| `backend/wsempleador/.../service/EmpleadorPolizaSearchServiceImpl.java:324,391,428-435` | **inconsistente**: usa `cliente.getRazonSocial()` en vez de `getNombre()`. Alimenta busquedas de empleador (grv-frontend `busquedaEmpleador.js:46`) |
| `backend/wsempleador/.../dto/EmpleadorEmbeddedDTO.java:15`, `wspersona/.../ResponseVigenciaEmpleadorDTO.java:14` | DTOs |
| `backend/libdatabase/.../entities/Cliente.java:32,89-93` | `logoImg` sin uso |

(`wsdocumento-wt-hotfix-1958` es copia, ignorada.) Nota: los nombres con acento (`COLONCOMPAÑIA...`) conservan la tilde; el switch del front depende de eso.

## Frontend - lib `sas-modules-features-lib` (libreriamodulosgrv, origin/master)

| Archivo:linea | Rol |
|---|---|
| `src/utils/utils.tsx:2-15,82-112` | `Utils.getLogoCliente`: switch de 14 cases, `default: undefined` |
| `src/assets/LogosClientes/*.png` | 14 PNG |
| `src/components/Cabeceras/CabeceraDenuncia.tsx:157-158` | muestra logo o "-" si undefined (correcto) |
| `src/components/DetalleSiniestroPrimeraPantalla/DatosDenuncia/DatosDenuncia.tsx:153` | `<img src={getLogoCliente(...)}>` **sin guardia**: imagen rota si undefined |
| `src/components/Cabeceras/utils/types.ts:38`, `src/types/DenunciaTypes.d.ts:209` | tipo `nombreLogo: string \| null` |
| `src/components/Cabeceras/utils/dataMock.ts:39` | mock |

`DetalleSiniestroPrimeraPantalla` (que contiene DatosDenuncia) esta exportado en `src/index.ts:20` pero **no encontre ningun MFE que lo renderice** (`<DetalleSiniestroPrimeraPantalla` solo aparece en la lib y su story). Verificar con Mesa en que pantalla se ve el img roto; si es una de las 6 de abajo, entra por otra via.

## Frontend - MFE que usan `CabeceraDenuncia` de la lib (requieren bump)

| MFE | Uso (archivo:linea) | lib fijada | Rama del checkout |
|---|---|---|---|
| atencioncliente | `src/layout/DenunciaLayout/DenunciaLayout.tsx:17,145` | 4.11.0 | master |
| auditoriafacturacion | `src/layout/LayoutSecundario.tsx:8,166` | 4.18.1 | promocion/satapp-master |
| auditoriamedica | `src/components/DenunciaCompleta/RutasDenunciaCompleta.tsx:24,147`; `commons/EvolucionesDrawer/EvolucionesDrawer.tsx:27,122` | 4.18.1 | feature/SE-199-aviso-terna-audmed-v2 |
| logistica | `src/layout/LayoutSecundario.tsx:8,181` | 4.11.0 | promo/INI-2-prod |
| mesadecarga | `src/components/DenunciaCompleta/DenunciaCompletaLayout.tsx:18,201` | 4.18.1 | promo/GRV-2309-a-release |
| tramitadores | `src/components/DenunciaCompleta/RutasDenunciaCompleta.js:7,194` | 4.23.1 | promo/ap-iconos-a-release |

Riesgo: atencioncliente y logistica estan en 4.11.0 y los de 4.18.1 estan lejos de 4.23.x; el bump a la version nueva arrastra todos los cambios intermedios de la lib. Revisar CHANGELOG 4.11->4.23 antes (en especial logistica/atencioncliente). Los `.d.ts` locales (`types/sas-modules-features-lib.d.ts`) solo declaran tipos, no hay que cambiarlos.

## Frontend - copias propias (NO usan la lib para el logo)

| MFE | Archivo:linea | Detalle |
|---|---|---|
| grv-frontend (`frontend/frontend`) | `Utils/icons.js:16-50` (`getImage`, 14 cases, PNG en `commons/assets/LogoCliente/`); usos: `components/DenunciaCompleta/cabeceraCompleta.js:406-407`, `Form/Secciones/DatosDenuncia/DatosDenuncia.js:403`, `Form/Cabecera/cabecera.js:258,472-474`, `Autosuggest/busquedaEmpleador.js:46` | `DatosDenuncia.js:403` sin guardia (img roto) |
| contrataciones | `Utils/icons.js:13` (`getImage`); usos: `Form/Secciones/DatosDenuncia/DatosDenuncia.js:298` (sin guardia), `Form/Cabecera/cabecera.js:218,389-391`, `DenunciaCompleta/CabeceraCompleta.js:341-342` | idem |
| portalclientes | `grv-portal-ui/src/utils/utils.js:53-62` (`Utils.getLogoCliente`, **solo 7 cases**: PROVINCIAART, UCAPP, PREVENCION, PLUSART, ISPRO, GALENOART, EXPERTAART); usos `DenunciaCompleta/common/CabeceraDenuncia.js:83-85`, `PrimeraPantalla/DatosDenuncia.js:206-207` (ambos con guardia) | lib fijada 3.4.1 pero no se usa para esto |

Sin hits: containerapp, login, incapacidad, solicitudesgenericas, chatbotcolonia. `auditoriamedica`/`auditoriafacturacion` solo tienen tipos `nombreLogo` en `.d.ts`.

## Hallazgo extra: rama `feature/logos-clientes-portables`

Commit 153d0f2 (4.15.0, autor Vanesa Yanina Burman, 07/08/2026): agrega `src/assets/LogosClientes/catalogo.json` (clave nombreLogo -> PNG), `scripts/generar-logos.mjs` y subpath export `logos/` para SAS Mobile; NO toca `getLogoCliente`. Parte de una base vieja (develop 9e5942a) y no esta en master (master ya va por 4.23.1). Conviene que el fix reutilice el catalogo para no duplicar la fuente de verdad: agregar un cliente = PNG + una linea en `catalogo.json`. Coordinar para no generar conflicto en `package.json`/CHANGELOG.

## Fetch

`git fetch` falla con "repository not found" por **token, no por URL**: la URL `gitlab.com/grvx/frontend/libreriamodulosgrv.git` es correcta (API 200 con el `GITLAB_TOKEN` del `.env`, project id 59815822; `ls-remote` OK con ese token y `origin/master` ya coincide con remoto). El PAT embebido en el `origin` de la copia local autentica (`/user` 200) pero devuelve 404 sobre el proyecto: sin acceso/membresia al grupo. Ojo: ese PAT esta en texto plano en la URL del remote (`git remote -v`); conviene rotarlo/sacarlo. No se modifico la config.

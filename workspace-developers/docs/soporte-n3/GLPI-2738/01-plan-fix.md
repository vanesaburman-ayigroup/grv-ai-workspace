# GLPI 2738 - Plan de fix (diff conceptual, sin aplicar)

Causa: el front resuelve el logo con un switch cerrado de 14 clientes; el resto devuelve `undefined` (la cabecera muestra "-", `DatosDenuncia` muestra un `<img>` roto). Los 14 nombres del switch coinciden exactamente con `REPLACE(REPLACE(clientes.nombre,' ',''),'.','')` en BD, o sea que el backend esta bien. Faltan logos de ~30 clientes (lista al final) y falta una guardia.

## 1. Lib `libreriamodulosgrv` (base origin/master 4.23.1; trabajar en un worktree nuevo, NO en el checkout con feature/corrector-texto-ia)

### a) `src/utils/utils.tsx`: mapeo robusto en lugar de cases

```ts
const normalizarClave = (s?: string | null) =>
  (s ?? '')
    .normalize('NFD').replace(/[̀-ͯ]/g, '')   // sin tildes (backend manda COMPAÑIA)
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '')                           // sin espacios, puntos, guiones, parentesis

const LOGOS: Record<string, string> = {                 // clave normalizada -> asset
  PROVINCIAART, UCAPP, PREVENCION, PLUSART, ISPRO, GALENOART, EXPERTAART,
  SMGLIFESEGUROSDEVIDASA, NACIONSEGUROS, INSTAUTARQER, PRODDEFRUTAS,
  HORIZONTECIAARGDESEGUROSGENERALESSA: HORIZONTE,
  COLONCOMPANIADESEGUROSSA: COLON,                       // ahora con N
  LOGRARCOMPANIADESEGUROSDEPERSONASSA: LOGRARCOMPANIADESEGUROSDEPERSONASSA,
  // NUEVOS cuando haya PNG: IAPSERSEGUROSAP, GOBIERNODELACIUDADDEBUENOSAIRES, ...
}

static getLogoCliente = (nombreLogo?: string | null) => LOGOS[normalizarClave(nombreLogo)]
```

Si se adopta `catalogo.json` de `feature/logos-clientes-portables` (clave -> PNG), que sea la fuente unica y el mapa se genere de ahi: agregar cliente = PNG + una linea.

Alias de sub-marcas (decidido: las "Seguridad e Higiene - X" usan el logo de la marca madre; GALENO usa el de GALENO ART), como entradas extra en `LOGOS`:
- `SEGURIDADEHIGIENEIAPSER`, `SEGURIDADEHIGIENEIAPSERNOGERENCIADO` -> logo IAPSER
- `SEGURIDADEHIGIENEHORIZONTE`, `HORIZONTE...INACTIVO`, `CDCUENTASGERENCIADASHORIZONTE` -> HORIZONTE (ya existe)
- `SEGURIDADEHIGIENEGOBCHUBUT` -> Chubut
- `SEGURIDADEHIGIENEAUTOSEGUROGCBA`, `CDCUENTAGERENCIADAAUTOSEGUROGCBA` -> GCBA
- `GALENO` (id 10, 10 denuncias) -> logo de `GALENOART` (id 17); misma marca

### b) `src/assets/LogosClientes/`
Agregar los PNG nuevos (mismo estilo y tamano que los existentes; los provee Mesa/Comercial) y un `import` por cada uno.

### c) `DetalleSiniestroPrimeraPantalla/DatosDenuncia/DatosDenuncia.tsx:153`: fallback

Hoy: `<img src={Utils.getLogoCliente(denunciaReq?.nombreLogo)} style={{width:'200px'}}/>` (roto si undefined). Propuesta, igual criterio que `CabeceraDenuncia.tsx:157-160`:

```tsx
<Grid size={3}>
  {Utils.getLogoCliente(denunciaReq?.nombreLogo)
    ? <img src={Utils.getLogoCliente(denunciaReq?.nombreLogo)} alt="logoCliente" style={{ width: '200px' }} />
    : <Typography>{/* nombre del cliente en texto si el tipo lo trae; si no, t('primeraPantalla.caracter.-') */}</Typography>}
</Grid>
```
Confirmar en `src/types/DenunciaTypes.d.ts` si existe un campo con el nombre del cliente; si no, mostrar "-".

### d) `CabeceraDenuncia.tsx:157-160`
Sin cambio funcional (opcional: mostrar el nombre en texto en vez de "-").

### e) Cierre
Tests/story: cliente sin logo, con tilde, y sub-marca. Bump a 4.23.2 (patch) con changeset/CHANGELOG. `npm run lint` y `npm run typecheck` (confirmar que lo tocado no suma errores).

## 2. MFE consumidores (solo bump de `sas-modules-features-lib`)

atencioncliente (4.11.0), logistica (4.11.0), auditoriafacturacion (4.18.1), auditoriamedica (4.18.1), mesadecarga (4.18.1), tramitadores (4.23.1) -> 4.23.2. En los de 4.11.0 y 4.18.1 revisar el CHANGELOG de la lib antes (el salto arrastra todos los cambios intermedios). Lint y typecheck en cada uno.

## 3. Copias propias (decidir alcance)

- grv-frontend `Utils/icons.js` y contrataciones `Utils/icons.js`: mismo patron (switch de 14, `default: null`) y `<img>` sin guardia en `DatosDenuncia.js` (grv-frontend:403, contrataciones:298). Replicar normalizacion + PNG nuevos en `commons/assets/LogoCliente/` + guardia. Alternativa: no tocarlas si esas pantallas son legado.
- portalclientes `utils/utils.js:53`: solo 7 logos; agregar los otros 7 existentes y los nuevos si el portal debe mostrarlos (sus usuarios son justamente ART/aseguradoras, probablemente conviene).

## 4. Backend

Nada obligatorio. Higiene opcional en otro ticket: `wsempleador` `EmpleadorPolizaSearchServiceImpl.java:428-435` usa `razonSocial` en vez de `nombre` (distinto de wsdocumento/wspersona). Alternativa estructural futura: exponer `idCliente` en el DTO y mapear por id en vez de por nombre (los nombres en BD cambian, ej. "(INACTIVO)").

## 5. Clientes que necesitan logo

Fuente: tabla `cs.clientes` + `cs.denuncias` (SELECT, MCP MariaDB; @@hostname = ip-172-19-1-132, es PROD). Ordenado por volumen total de denuncias; entre parentesis las de 2026 (lo que se ve hoy en pantalla). Los 14 con logo resuelto no figuran.

| # | id | Cliente | Denuncias totales | 2026 |
|---|---|---|---|---|
| 1 | 4 | INTERACCION ART | 32004 | 4 |
| 2 | 33 | IAPSER SEGUROS (AP) | 15509 | 14280 |
| 3 | 2 | MAPFRE | 13697 | 0 |
| 4 | 42 | GOBIERNO DE LA CIUDAD DE BUENOS AIRES | 7936 | 7936 |
| 5 | 23 | CORREDORES VIALES | 5562 | 0 |
| 6 | 20 | WORANZ | 2980 | 23 |
| 7 | 24 | CONSEJO DE LA MAGISTRATURA DE LA CIUDAD DE BUENOS AIRES | 2615 | 315 |
| 8 | 38 | AUTOSEGURO PUBLICO PROVINCIAL CHUBUT | 2312 | 1415 |
| 9 | 8 | GOBIERNO DE CORDOBA | 2258 | 0 |
| 10 | 1 | COLONIA SUIZA SALUD (tiene `logo_img` legado .gif) | 1664 | 10 |
| 11 | 14 | HORIZONTE ... (INACTIVO) (reusar HORIZONTE) | 1632 | 29 |
| 12 | 25 | MINISTERIO PUBLICO DE LA DEFENSA | 1601 | 195 |
| 13 | 36 | SEGURIDAD E HIGIENE - IAPSER | 1530 | 1431 |
| 14 | 13 | MEOPP ART MUTUAL | 1132 | 0 |
| 15 | 40 | SMG COMPANIA ARGENTINA DE SEGUROS S.A | 431 | 413 |
| 16 | 35 | BAPRO MEDIOS DE PAGO S.A. | 406 | 163 |
| 17 | 31 | SEGURIDAD E HIGIENE - HORIZONTE (reusar HORIZONTE) | 115 | 74 |
| 18 | 39 | SEGURIDAD E HIGIENE - GOB. CHUBUT | 46 | 45 |
| 19 | 9 | LA SEGUNDA | 24 | 0 |
| 20 | 43 | SEGURIDAD E HIGIENE - AUTOSEGURO GCBA | 20 | 20 |
| 21 | 41 | SEGURIDAD E HIGIENE - IAPSER (NO GERENCIADO) | 14 | 1 |
| 22 | 10 | GALENO | 10 | 0 |
| 23 | 27 | RIVADAVIA | 7 | 5 |
| 24 | 28 | CALL CENTER | 6 | 0 |
| 25 | 29 | GRV | 3 | 0 |
| 26 | 44 | CD CUENTA GERENCIADA AUTOSEGURO GCBA | 2 | 2 |
| 27 | 32 | PROTOCOLO DE DISFONIA MENDOZA | 1 | 0 |
| 28 | 34 | CD CUENTAS GERENCIADAS HORIZONTE | 1 | 0 |
| 29-30 | 7, 12 | EL COMERCIO, NOGOYA | 0 | 0 |

Pedido minimo a Mesa/Comercial (impacto real hoy, por denuncias 2026): IAPSER (14.280, mas 1.431 de Seguridad e Higiene), GCBA (7.936, mas 20), Autoseguro Chubut (1.415, mas 45), SMG Compania Argentina de Seguros (413), Consejo de la Magistratura (315), Ministerio Publico de la Defensa (195), BAPRO (163). Decisiones: las sub-marcas "Seguridad e Higiene - X" usan el logo de la marca madre (no se piden aparte), y GALENO comparte el logo de GALENO ART. Se piden tambien los logos de los historicos MAPFRE, Interaccion ART y Corredores Viales (sin actividad 2026) por las dudas; sumar el resto de la tabla (Woranz, Gobierno de Cordoba, Meopp, La Segunda, Rivadavia) si estan disponibles.

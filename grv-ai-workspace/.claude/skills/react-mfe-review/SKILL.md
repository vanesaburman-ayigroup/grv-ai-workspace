---
name: react-mfe-review
version: v1
maturity: beta
owner: "[FRONTEND_REFERENT]"
category: engineering
related_skills: [grv-arquitectura-plataforma, grv-bugs-conocidos]
related_agents: [grv-reviewer]
triggers:
  - "usuario pide revisar código React/JS/TS"
  - "aparece cambio en microfrontend en el diff"
  - "usuario dice 'revisá este componente'"
---

# Skill: react-mfe-review

## Propósito

Hacer code review de cambios en los microfrontends React de la plataforma
de GRV. Los MFEs se componen dentro del container-app y el stack no es
uniforme: **algunos frontends más nuevos están en TypeScript con Redux
Toolkit Query, otros más viejos en JavaScript sin RTK Query**. El skill
tiene que adaptarse a ambos sin imponer patrones que no aplican.

## Fuente de verdad

- `context/microservices.yaml` — qué MFE es y qué stack usa (cuando esté documentado).
- `context/known-bugs.yaml` — patterns conocidos de falla en frontend.

## Antes de revisar, aclaramos el stack

El skill **pregunta** al usuario si no puede determinar el stack del MFE:

- ¿Es TypeScript o JavaScript?
- ¿Usa Redux Toolkit Query o no?
- ¿Usa hooks modernos o clases legacy?
- ¿Qué versión de React?

Esto evita que sugiera refactors que no aplican al código real (ej: sugerir
un patrón de RTK Query en un MFE que usa fetch/axios directo).

## Cuándo usarme

- Review de un MR de frontend.
- Validación de un componente nuevo antes de integrarlo.
- Detección de anti-patterns al tocar código legacy.

## Checklist

### 1. Rules of Hooks (React)

- [ ] **Hooks en conditionals**: ⚠️ ver `bug-hook-in-switch` en `known-bugs.yaml`. Hooks **jamás** dentro de `if`, `switch`, `for`, early return. Son llamadas ordenadas.
- [ ] **Hooks solo en componentes o custom hooks**: no en funciones comunes.
- [ ] **Custom hooks con prefijo `use`**.

### 2. Estado y rendering

- [ ] **`useEffect` con dependencias correctas**: ni de más ni de menos. Lint regla `react-hooks/exhaustive-deps` activa.
- [ ] **Dependencias circulares**: ⚠️ ver `bug-maxdatehasta-circular`. `useEffect`/`useMemo` con dependencias que se actualizan mutuamente son bomba de tiempo.
- [ ] **`useMemo`/`useCallback` justificados**: no agregar por ceremonial, solo cuando hay costo real.
- [ ] **Renders innecesarios**: props que cambian cada render por identidad de referencia (objetos/arrays inline).

### 3. Redux / state management

- [ ] **Estado serializable**: ⚠️ ver `bug-non-serializable-redux`. Nada de `Date`, `Map`, `Set`, instancias de clase, Moment.js en el store.
- [ ] **Selectors memoizados**: usar `createSelector` cuando el selector deriva datos.
- [ ] **Actions tipadas** (si el MFE es TS).
- [ ] **Inmutabilidad**: no mutar el estado directamente.
- [ ] **(Si usa RTK Query)** Cache keys correctos, invalidación explícita, no abusar de `refetchOnFocus`.

### 4. TypeScript (cuando aplica)

- [ ] **`any` injustificado**: bandera roja. Usar `unknown` o tipos concretos.
- [ ] **Type assertions**: `as X` solo cuando no hay alternativa, con comentario de por qué.
- [ ] **Interfaces de props**: toda prop tipada.
- [ ] **Genéricos correctos** en custom hooks.
- [ ] **Strict mode habilitado**: sabemos que el compilador aplica reglas estrictas.

### 5. JavaScript legacy (cuando aplica)

- [ ] **PropTypes** o comentarios JSDoc si no hay TypeScript.
- [ ] **`var` → `const`/`let`**.
- [ ] **Funciones flecha donde corresponde** para preservar `this`.

### 6. Microfrontends y container-app

- [ ] **No pisar estilos globales**: scoping de CSS (CSS modules, styled-components, etc).
- [ ] **No contaminar `window`**: cuidado con globales que colisionan con otros MFEs.
- [ ] **Carga lazy** de chunks pesados.
- [ ] **Comunicación con container-app**: si hay que pasar data entre MFEs, usar el mecanismo definido por el container (y documentarlo si aún no está en `context/`).

### 7. Bundle size y performance

- [ ] **Imports específicos**: `import { x } from 'lodash'` ❌ vs `import x from 'lodash/x'` ✅. Mata tree-shaking.
- [ ] **Dependencias pesadas justificadas**: Moment.js → considerar date-fns o dayjs si es feature nueva.
- [ ] **Externals en webpack** para libs compartidas entre MFEs. Ver el historial del MFE de solicitudes genéricas (bundle >6MB).
- [ ] **Code splitting** en rutas/componentes grandes.

### 8. Accesibilidad (a11y)

- [ ] **Etiquetas semánticas**: `<button>` no `<div onClick>`.
- [ ] **Labels de inputs**: `<label htmlFor>` o `aria-label`.
- [ ] **Focus management** en modales y drawers.
- [ ] **Contraste** suficiente (ojo con temas dark).

### 9. Credenciales y env vars

- [ ] **API keys no hardcodeadas**: el equipo tiene historial con Google Maps API key inyectada via `credentials.js` en vez de build-time env vars. Verificar que el pattern correcto esté en uso.
- [ ] **Nada de secretos** (el hook de secretos debería atraparlo, pero doble check).

### 10. Testing

- [ ] **¿Hay tests?** Si el componente es no trivial y no tiene tests, alertar.
- [ ] **¿Tests de comportamiento o de implementación?** Review completa con `functional-test-author`.

## Flujo

1. Preguntar por el stack si no está claro (TS/JS, con/sin RTK Query).
2. Identificar el MFE y consultar `microservices.yaml`.
3. Aplicar las secciones del checklist que correspondan al stack real.
4. Cruzar con `known-bugs.yaml` buscando patterns.
5. Reportar con severidad.

## Output

Similar a `spring-boot-review`. Formato:

```
===========================================================
CODE REVIEW — React MFE
MFE: <nombre o pendiente>
Stack: <TS+RTK Query | TS | JS con React | otro>
===========================================================

RESUMEN
  🟢 ... 🟡 ... 🔴 ...

HALLAZGOS
  ...

BUGS CONOCIDOS POTENCIALMENTE RELACIONADOS
  ...

PREGUNTAS AL AUTOR
  ...
```

## Ejemplo

**Usuario**: Revisame este hook:
```js
function useOpciones(tipo) {
  switch (tipo) {
    case 'A':
      const { data } = useQuery('opcionesA');
      return data;
    case 'B':
      return useStaticOptions();
    default:
      return [];
  }
}
```

**Respuesta**:
```
🔴 BLOQUEANTE

1. Violación de Rules of Hooks.
   Hooks (useQuery, useStaticOptions) dentro de un switch. React llama
   hooks en el mismo orden cada render; switch rompe ese contrato y
   vas a tener comportamiento impredecible o errores del tipo
   "Rendered fewer hooks than expected".

   Patrón conocido: bug-hook-in-switch en context/known-bugs.yaml.

   Fix: llamar ambos hooks incondicionalmente y decidir qué devolver
   después:

   function useOpciones(tipo) {
     const queryA = useQuery('opcionesA', { enabled: tipo === 'A' });
     const staticB = useStaticOptions();
     if (tipo === 'A') return queryA.data;
     if (tipo === 'B') return staticB;
     return [];
   }

PREGUNTAS AL AUTOR
  - ¿El hook useQuery es de RTK Query o de react-query? Confirmame para
    ajustar el fix exacto (la API de enabled varía).
```

## Límites

- No ejecuta el código ni los tests.
- Los sugerencias se basan en el stack que el usuario reporta; si el
  stack real es distinto, los sugerencias pueden no aplicar.
- No reemplaza un review humano con conocimiento del MFE específico.

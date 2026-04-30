---
name: grv-provincia-art
version: v1
maturity: alpha
owner: "[INTEGRATIONS_REFERENT]"
category: domain
related_skills: [grv-siniestros, grv-arquitectura-plataforma]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona Provincia ART"
  - "usuario debe integrar, debugear o modificar integración con Provincia ART"
---

# Skill: grv-provincia-art

## Propósito

Conocer la integración con el sistema de Provincia ART. Este skill es
el placeholder con el conocimiento actual; pendiente de expandir con
detalles de API, endpoints y patterns.

## Fuente de verdad

**`context/integrations.yaml`** → entry `Provincia ART`.

## Qué sabemos hoy

- Tipo: data-exchange, bidireccional
- Protocolo: REST API
- Consumers conocidos: `wssiniestralidad`, `wsprestaciones`
- Es un sistema externo que intercambia datos de siniestros.

## Qué NO sabemos todavía (TODO)

- Endpoints específicos y sus contratos
- Frecuencia de sincronización
- Manejo de errores y reintentos
- Autenticación/autorización (API key, OAuth, mTLS?)
- Rate limits del lado del proveedor
- Casos de incidentes históricos

## Cuándo usarme

- Usuario pregunta por Provincia ART y necesita contexto inicial.
- Usuario reporta bug en la integración → usar este skill para identificar
  servicios involucrados, pero derivar al referente para detalles técnicos.
- Onboarding: mencionarlo como integración existente.

## Flujo

1. Reconocer que la pregunta es sobre Provincia ART.
2. Devolver el conocimiento disponible (limitado).
3. **Si el usuario necesita más detalle**: decir explícitamente "este skill
   está en alpha, no tengo los detalles técnicos de la integración. Referente:
   `[INTEGRATIONS_REFERENT]`. Si sabés más, podemos agregar el conocimiento
   al skill para futuros casos."
4. Ofrecer buscar en el código de los servicios consumers si hace falta.

## Ofrecer captura como contribución

Cuando el usuario aporta detalles que no teníamos documentados (endpoints,
auth, formatos, casos históricos), al cierre del flujo ofrecer invocar
`workspace-contribution` con `type: integrations`. Ver
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` debe formarse como entry YAML siguiendo el formato
de `context/integrations.yaml` (name, type, direction, protocol,
consumers, notes, gotchas si aplica).

## Promoción a beta — TODO

- [ ] Documentar endpoints principales
- [ ] Documentar auth
- [ ] Listar al menos 2 casos reales de uso / problemas
- [ ] Cross-link con posibles resoluciones regulatorias que rigen la
      interoperabilidad

## Límites

Este skill es consciente de que sabe poco. Prefiere admitirlo a inventar.

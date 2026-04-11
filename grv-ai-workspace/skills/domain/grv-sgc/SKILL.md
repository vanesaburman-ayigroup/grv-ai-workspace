---
name: grv-sgc
version: v1
maturity: alpha
owner: "[INTEGRATIONS_REFERENT]"
category: domain
related_skills: [grv-siniestros, grv-arquitectura-plataforma]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona SGC"
  - "usuario debe integrar, debugear o modificar integración con SGC"
---

# Skill: grv-sgc

## Propósito

Conocer la integración con el Sistema de Gestión de Casos (SGC). Este
skill es el placeholder con el conocimiento actual; pendiente de expandir.

## Fuente de verdad

`context/integrations.yaml` → entry `SGC`.

## Qué sabemos hoy

- SGC = Sistema de Gestión de Casos.
- Es una integración bidireccional con un sistema externo.
- Consumer identificado: `wssiniestralidad`.

## Qué NO sabemos todavía

- Endpoints y contratos.
- Autenticación.
- Frecuencia y patrón de sincronización.
- Dueño del sistema del lado del cliente/partner.
- Casos históricos de incidentes.

## Cuándo usarme

- Alguien pregunta "¿qué es SGC?" y necesita el contexto mínimo.
- Alguien reporta un problema con la integración y hay que identificar
  servicios involucrados.
- Onboarding: mencionar SGC como integración existente.

## Flujo

1. Reconocer que la pregunta es sobre SGC.
2. Devolver el conocimiento documentado (limitado).
3. **Decir explícitamente que el skill está en alpha** y pedir al usuario
   los detalles que falten para agregarlos al contexto.
4. No inventar endpoints, nombres de métodos, ni flujos.

## Ofrecer captura como contribución

Cuando el usuario aporta detalles sobre SGC que no tenemos documentados,
al cierre del flujo ofrecer invocar `workspace-contribution` con
`type: integrations`. Ver
`skills/engineering/workspace-contribution/helper.md`.

## Límites

Este skill sabe que sabe poco. Prefiere admitirlo a inventar.

## Promoción a beta — TODO

- [ ] Documentar endpoints principales
- [ ] Documentar auth
- [ ] Listar al menos 2 casos reales de uso o problemas
- [ ] Confirmar referente del lado de AYI

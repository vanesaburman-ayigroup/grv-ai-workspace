---
name: grv-autorizaciones-medicas
version: v1
maturity: alpha
owner: "[BACKEND_REFERENT]"
category: domain
related_skills: [grv-prestaciones, grv-siniestros, grv-arquitectura-plataforma]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona autorización médica, autorización de prestación"
  - "usuario pregunta sobre el flujo de autorizaciones"
  - "usuario diseña feature de autorizaciones"
---

# Skill: grv-autorizaciones-medicas

## Propósito

Conocer el dominio de autorizaciones de prestaciones médicas para siniestros
laborales. Una autorización es el proceso por el cual la ART aprueba (o no)
una prestación específica solicitada por el trabajador siniestrado o el
prestador tratante.

## Modelo conceptual

```
Siniestro abierto
  → Prestador solicita autorización para prestación X (estudio, cirugía, medicamento)
  → Sistema valida pertinencia (cobertura, tipo de siniestro, antecedentes)
  → Auditor médico revisa (humano, a veces asistido)
  → Decisión: AUTORIZADA | RECHAZADA | OBSERVADA (pide más info)
  → Si AUTORIZADA: se habilita la prestación → se ejecuta → se factura
  → Si RECHAZADA: notificación y posible reclamo
  → Si OBSERVADA: vuelve al prestador con pedido de info adicional
```

## Tipos de autorización típicos

- **Estudios complementarios** (RMN, TAC, laboratorio, etc.)
- **Prácticas kinesiológicas** (cantidad de sesiones, tipo)
- **Cirugías** (con o sin internación)
- **Medicamentos especiales**
- **Prótesis y ortesis**
- **Rehabilitación compleja** (psicológica, ocupacional)

## Servicios involucrados (pendiente de mapear a fondo)

- `wsautorizaciones` — servicio principal (pendiente de documentar en `microservices.yaml`)
- `wsprestaciones` — prestaciones asociadas
- `wssiniestralidad` — para validar estado del siniestro
- Microfrontend de mesa de carga — frontend. *[TODO: confirmar nombre real del MFE en `context/microservices.yaml`.]*

## Cuándo usarme

- Diseño de features sobre autorizaciones.
- Diagnóstico de flujos donde una autorización quedó trabada.
- Explicación del concepto a alguien nuevo.
- Review de cambios que tocan el flujo de autorizaciones.

## Consideraciones críticas

1. **Tiempo importa**: los plazos de respuesta de autorización están
   regulados y hacen al cumplimiento. Una autorización demorada es un
   problema de compliance.

2. **Trazabilidad**: cada cambio de estado de una autorización debe quedar
   auditado (quién, cuándo, por qué).

3. **Reclamos**: toda decisión de rechazo debe ser reclamable. El sistema
   no puede "perder" el historial.

4. **Prestador tratante vs ART**: hay flujos donde el prestador propone y
   la ART valida; hay flujos donde la ART dirige directamente a un prestador
   de la red. Distinto contrato, distinto flujo.

5. **Relación con ILT**: autorizaciones de tratamiento prolongado impactan
   en el cálculo de días de ILT.

## Flujo del skill

1. Entender qué parte del ciclo consulta el usuario.
2. Referenciar el servicio/código relevante (dato pendiente de completar
   en `context/microservices.yaml`).
3. Remitir a `grv-prestaciones` si la pregunta es sobre qué se puede
   solicitar, no sobre el flujo de autorización.
4. Remitir a `grv-regulaciones-srt` si hay implicancia regulatoria.

## Límites conocidos

- **Alpha**: este skill tiene menos contenido que otros porque el flujo
  de autorizaciones aún no está completamente documentado en el workspace.
- Los plazos exactos regulatorios necesitan revisión con el cliente.
- El mapeo a código exacto de `wsautorizaciones` requiere completar
  `context/microservices.yaml`.

## TODO para promover a beta

- [ ] Documentar `wsautorizaciones` en `microservices.yaml`.
- [ ] Agregar tabla maestra de tipos de autorización con plazos.
- [ ] Documentar al menos 2 casos reales (ej: una autorización rechazada
      y su flujo de reclamo; una autorización demorada por datos faltantes).
- [ ] Linkear a las regulaciones específicas que rigen plazos.

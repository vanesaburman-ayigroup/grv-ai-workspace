## ADDED Requirements

### Requirement: Reutilización de la validación de denuncia obligatoria en el alta externa
El punto de entrada de alta de Solicitudes Genéricas para sistemas externos (a través del Orquestador
de Integraciones) SHALL invocar la validación existente de denuncia obligatoria por tipo de solicitud
(GRV-1929, `validarDenunciaRequerida`) antes de crear la SG, de la misma forma en que lo hace hoy el
entry-point clásico del SAS (`SolicitudesGenericasServiceCompose.altaSolicitudGenerica`). Esta
validación NO es nueva: ya existe y protege el alta clásica; lo que agrega esta capability es que
también se ejecute en el camino nuevo, que llama directamente a `crearSolicitudGenerica` sin pasar por
el compose.

#### Scenario: Alta externa rechazada por falta de denuncia
- **WHEN** un sistema externo solicita el alta de una SG con un tipo de solicitud que tiene
  `requiereDenuncia = true` y no informa `idDenuncia`
- **THEN** el alta se rechaza con el mismo error que usaría el SAS, sin crear la SG

#### Scenario: Alta externa aceptada con denuncia informada
- **WHEN** un sistema externo solicita el alta de una SG con un tipo de solicitud que tiene
  `requiereDenuncia = true` y un `idDenuncia` válido
- **THEN** la SG se crea normalmente, igual que en el SAS

#### Scenario: Alta externa de un tipo que no requiere denuncia no se ve afectada
- **WHEN** un sistema externo solicita el alta de una SG con un tipo de solicitud que tiene
  `requiereDenuncia = false` (por ejemplo, un tipo del área Logística)
- **THEN** el alta se crea con o sin `idDenuncia`, sin exigir la asociación — el comportamiento es por
  tipo de solicitud, no por área

#### Scenario: El comportamiento del SAS no cambia
- **WHEN** un operador del SAS da de alta una SG desde la pantalla interna
- **THEN** la validación se sigue ejecutando exactamente como hoy (GRV-1929), sin ningún cambio de
  comportamiento

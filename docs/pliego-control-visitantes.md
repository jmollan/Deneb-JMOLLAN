# Pliego funcional: Control de visitantes en condominios

## 1. Alcance funcional (User Stories)
- **US1 – Registro en garita.** El guardián busca o elige la casa destino, registra datos básicos del visitante, captura foto obligatoria del DNI (excepto propietario o inquilino) y crea la visita.
- **US2 – Pase QR único.** Al crear la visita, el sistema genera un QR único con vigencia configurable y control de usos (una o múltiples lecturas según política).
- **US3 – Ingreso/Egreso.**
  - *Ingreso:* el guardián escanea el QR o valida por documento/placa y marca el check-in.
  - *Egreso:* al salir, escanea o busca la visita y marca el check-out.
- **US4 – Excepciones.** Los visitantes registrados como propietario o inquilino (pre-registrados) no requieren foto de DNI y cuentan con QR permanente o validación por documento.
- **US5 – Pre-autorización (opcional).** Los residentes pueden pre-registrar visitas con fecha y ventana horaria; al llegar el visitante el guardián solo valida y emite el pase.
- **US6 – Backoffice.** Administradores o jefes de seguridad gestionan casas, residentes, guardias, listas blanca/negra, reportes y auditoría.
- **US7 – Reportes.** Consultas de entradas/salidas por rango de fechas, por casa, visitante, guardián y visitas activas vencidas (sin check-out).
- **US8 – Auditoría.** Todo evento de alta/baja/modificación, check-in/out y acceso a datos queda registrado con trazas forenses.

## 2. Reglas clave
- Foto de DNI obligatoria para visitantes no residentes, salvo pre-autorizados con documento verificado (política configurable).
- Residentes (propietarios o inquilinos) se identifican por registro interno; no requieren foto de DNI y disponen de QR permanente por persona y opcionalmente por vehículo.
- Vigencia del pase de visitante: una visita dentro de una ventana horaria (por defecto 08:00–22:00 del día) configurable.
- Vehículos: captura opcional de placa vinculada a la visita.
- Listas:
  - **Lista blanca:** invitados frecuentes; puede eximir la captura de foto en cada visita (configurable).
  - **Lista negra:** deniega el acceso y genera alertas.
- Privacidad: no se exponen datos sensibles en el QR; el código contiene solo una URL con `shortId`.
- Retención de datos personales y fotos según política (ej. 12–18 meses) con procesos de borrado o anonimización.
- Trazabilidad completa: `created_at`, `check_in_at`, `check_out_at`, guardián, garita, IP y user agent.
- Validaciones de ingreso: bloqueo por ventana vencida, documento/placa en lista negra, QR revocado o expirado; registro de motivo en caso de denegación.

## 3. Campos del formulario (garita)
### Casa destino
- `casa_id` (selector rápido por número o dirección interna).

### Visitante
- `tipo_visitante` (enum: visitante, propietario, inquilino).
- `nombres`.
- `apellidos`.
- `tipo_documento` (DNI/CE/Pasaporte).
- `numero_documento`.
- `telefono` (opcional).
- `foto_dni` (obligatoria si `tipo_visitante = visitante` y no está en lista blanca).

### Visita
- `motivo` (texto corto).
- `fecha_visita` (por defecto: ahora).
- `ventana_inicio` / `ventana_fin` (si es pre-autorizada).
- `vehiculo_placa` (opcional).
- `observaciones` (opcional).
- `consentimiento_datos` (checkbox con timestamp de aceptación).

## 4. Modelo de datos mínimo
- **casa:** `id`, `codigo`, `direccion_interna`, `estado`.
- **residente:** `id`, `casa_id`, `tipo_residente` (propietario|inquilino), `nombres`, `apellidos`, `tipo_documento`, `numero_documento`, `telefono`, `qr_permanente_id` (FK), `activo`.
- **guardian:** `id`, `nombres`, `apellidos`, `usuario`, `rol` (guardia|jefe|admin), `activo`.
- **visitante:** `id`, `nombres`, `apellidos`, `tipo_documento`, `numero_documento`, `telefono` (opcional), `frecuente` (bool).
- **visita:** `id` (ULID), `short_id`, `casa_id`, `visitante_id` (nullable si residente), `residente_id` (nullable), `tipo_visitante`, `motivo`, `ventana_inicio`, `ventana_fin`, `vehiculo_placa`, `estado` (creada|check_in|check_out|anulada|rechazada), `created_at`, `check_in_at`, `check_in_by`, `check_out_at`, `check_out_by`, `observaciones`, `denegada_por`, `denegada_detalle`.
- **foto:** `id`, `visita_id`, `tipo` (dni_frente|dni_dorso|selfie|otro), `path`, `mime_type`, `size_bytes`, `created_at`.
- **qr:** `id`, `owner_type` (visita|residente|vehiculo), `owner_id`, `short_id`, `status` (activo|revocado), `expires_at` (nullable para residentes), `created_at`.
- **lista_blanca:** `id`, `casa_id` (nullable), `numero_documento`, `motivo`, `vigencia_inicio`, `vigencia_fin`.
- **lista_negra:** `id`, `numero_documento` o `vehiculo_placa`, `motivo`, `vigencia_fin`.
- **audit_log:** `id`, `actor_id`, `accion`, `entidad`, `entidad_id`, `detalles`, `created_at`, `ip`, `user_agent`.

## 5. API REST esencial
- `POST /api/visitas` (multipart) → crea visita y QR de pase. **201**: `{ id, shortId, qrPngUrl, detailUrl }`.
  - Errores: 400 datos inválidos, 401 sin autenticación, 403 visitante en lista negra, 409 ventana vencida o QR duplicado.
- `POST /api/visitas/:id/check-in` → valida ventana/listas y marca ingreso.
  - Errores: 400 falta de foto DNI, 403 lista negra, 409 fuera de ventana, 410 QR expirado/revocado.
- `POST /api/visitas/:id/check-out` → marca salida (idempotente: repetir devuelve mismo estado).
- `GET /s/:shortId` → vista pública del pase (datos mínimos, documento enmascarado).
- `POST /api/residentes` / `GET /api/residentes` → CRUD de residentes y QR permanente.
- `GET /api/casas` → listado/búsqueda rápida.
- `POST /api/listas/blanca` / `POST /api/listas/negra` → administración de listas.
- `GET /api/reportes/visitas?desde&hasta&casa_id&guardia_id&estado` → exporta CSV o PDF.

### Consideraciones de API
- Todas las operaciones autenticadas usan JWT/OAuth2 con scopes por rol.
- Rate limit en garitas y backoffice; bloquear IP tras múltiples fallos.
- Los QR contienen solo la URL corta (`/s/:shortId`); los detalles se obtienen server-side tras autorización.

## 6. UI y flujo en garita
1. Buscar casa (teclado grande y favoritos).
2. Seleccionar tipo (visitante, propietario, inquilino).
3. Capturar documento, foto de DNI (si aplica) y placa opcional; validar listas en línea y mostrar alertas tempranas.
4. Crear visita → mostrar QR generado y botón «Check-in ahora» si el visitante ya está presente.
5. Check-out: listado de visitas dentro con botón de salida, escaneo o búsqueda manual; soporte para check-out masivo si es un grupo.
6. Modo contingencia offline: cola local para envíos y reintento automático.

## 7. Seguridad y privacidad
- Autenticación JWT/OAuth en backoffice; usuarios gestionados por rol.
- Garitas con sesiones de guardián protegidas (PIN o credenciales simplificadas) y rate limiting.
- Controles de CSP, CORS, anti-XSS y CSRF en formularios.
- PII cifrada en base de datos y almacenamiento con URLs firmadas; eliminar metadatos EXIF.
- En vistas públicas, enmascarar documentos (ej. `*******123`).
- Auditoría completa de altas/bajas/cambios/ingresos/salidas.
- Retención configurable con procesos de borrado/anonimización programados; bitácora de purgas.
- Firma y sellado de tiempo en eventos de check-in/out para no repudio.

## 8. Opciones de arquitectura
- **Implementación rápida:** Supabase (Postgres + Auth + Storage) con Next.js (API Routes), n8n para webhooks y despliegue en Vercel/Render.
- **Escalable en GCP:** Cloud Run, Cloud SQL, Cloud Storage y Cloud CDN.
- **Operación offline:** PWA para garitas con cola de envíos y sincronización diferida.
- **Monitorización:** métricas (p95 búsqueda < 1.5 s), logs centralizados y alertas por latencia o tasa de errores.

## 9. Criterios de aceptación (QA)
- Creación de visita de invitado con foto de DNI → respuesta 201 con QR.
- Ingreso de residente (propietario o inquilino) sin foto → check-in permitido.
- Intento de ingreso fuera de ventana → acceso bloqueado con mensaje.
- Documento en lista negra → acceso denegado y alerta.
- Reporte de visitas activas sin salida (> N horas) lista todos los casos.
- Búsquedas por casa o placa < 1.5 s (p95).
- Exportación CSV (≥ 1000 filas) correcta.
- Auditoría registra autor, check-in/out y sellos de tiempo.
- Reintento offline sube eventos pendientes cuando vuelve la conexión y preserva sellos de tiempo originales.

## 10. Entregables requeridos para CODEX
1. OpenAPI (YAML) de los endpoints definidos, incluyendo errores y esquemas.
2. Esquema SQL (migraciones) con índices en `short_id`, `numero_documento`, `casa_id`, `estado`, `check_in_at`.
3. Front de garita optimizado para móvil (teclas grandes, escáner QR integrado).
4. Backoffice con RBAC, filtros, exportaciones, gestión de listas y residentes.
5. Módulo de generación de QR (PNG/SVG) con expiración para visitas y permanente para residentes.
6. Jobs de retención/anonimización y backup.
7. Plan de pruebas (unitarias, integración, e2e) más scripts de seed (casas, residentes).
8. Guía operativa (rotación de claves, reseteo de QR permanente, recuperación).

## 11. Extras futuros (opcionales)
- Pre-registro por residente mediante portal o app (enlace mágico por SMS/WhatsApp).
- LPR/ANPR para lectura automática de placas y control de barrera.
- Gestión de múltiples garitas y zonas con control de aforo.
- Impresión de stickers con QR para visitantes.
- Integración con CCTV (almacenamiento de hash de clip asociado al check-in).
- Geocercas para visitas de delivery y cálculo de tiempos de permanencia.
- Integraciones con mensajería (WhatsApp/SMS) para enviar pases y recordatorios de vencimiento.

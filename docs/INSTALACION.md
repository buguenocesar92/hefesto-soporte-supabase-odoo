# Hefesto Soporte — instalación y traspaso

## Supabase / Coolify
1. Crea o selecciona un proyecto Supabase.
2. Ejecuta `supabase/migrations/202610130001_hefesto_taller.sql`. El nombre heredado no afecta las tablas exclusivas: hefesto_soporte_states y hefesto_soporte_sessions.
3. Copia `.env.example` a `.env`. Completa SUPABASE_URL, SUPABASE_SECRET_KEY (sb_secret o service_role), WORKSHOP_ID, ADMIN_PASSWORD (16 caracteres mínimo), PUBLIC_ORIGIN (dominio HTTPS), COOKIE_SECURE=true.
4. `docker compose -f compose.supabase.yaml up -d --build`. El compose expone el puerto interno `3000` con `expose` (sin publicar al host): en Coolify selecciona ese Compose y Traefik asigna el dominio al servicio `taller`. Para inspección local, publica con `docker compose -f compose.supabase.yaml run --service-ports -p 127.0.0.1:3080:3000 taller`.
5. Inicia sesión con la contraseña de administración. La clave Supabase se usa solo en servidor.

El servicio Compose conserva el nombre técnico `taller` por compatibilidad del adaptador. Las tablas son exclusivas de Soporte. Si despliegas varios productos en un servidor, asigna dominios propios.

## SQLite
`docker compose -f compose.yaml up -d --build`. Usa volumen persistente. Para prueba local PUBLIC_ORIGIN=http://localhost:3080 y COOKIE_SECURE=false; en producción HTTPS. La instalación portable comienza sin clientes, responsables, contratos, tickets ni artículos. Revisa los plazos predeterminados y crea tus registros.

## Migrar y respaldar
Exporta JSON desde Portabilidad. El ZIP contiene código y ejemplos, no datos de producción.

```
docker compose -f compose.supabase.yaml cp hefesto-soporte.json taller:/data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs validate /data/import.json
docker compose -f compose.supabase.yaml exec taller node portable/tools/transfer.mjs import /data/import.json
```

Preserva IDs y rechaza sobrescribir destinos con registros. Usa WORKSHOP_ID nuevo o volumen vacío. Pausa operaciones durante migración. Para exportar: ejecuta `node portable/tools/transfer.mjs export /data/respaldo.json` dentro del servicio y copia fuera con docker compose cp. Guarda copias independientes protegidas: el JSON incluye conversaciones y notas internas.

## Traspaso Odoo u otra mesa de ayuda
`python3 migration/prepare_odoo.py hefesto-soporte.json salida-odoo`

Genera clientes, responsables, contratos, tickets, horas y artículos en CSV, más JSON completo. Mapear usuarios, estados, prioridades, relaciones, unidades de tiempo y campos según plataforma, edición y módulos disponibles. Responsables no son cuentas de usuario. No incluye addon ni sincronización. Mensajes e historial completos se preservan en JSON. Probar primero en base de ensayo y revisar visibilidad de notas internas. No crea asientos ni facturas.

## Flujo
Crear cliente, responsable y contrato opcional. Al crear ticket se asocia contrato vigente y fija plazos. Asignar responsable, iniciar atención, registrar notas/respuestas, tiempo y solución con verificación. Resolver y cerrar. Reabrir requiere motivo; el historial conserva la resolución anterior.

Una nota interna no cuenta como primera respuesta. «Respuesta entregada» exige confirmar entrega previa y referencia; no envía mensajes. La fecha registrada es el momento de guardado, no una fecha retroactiva del canal externo. El informe imprimible excluye las notas internas, pero incluye descripciones del trabajo: revísalo antes de compartir.

Los plazos son horas corridas 24/7, sin calendarios hábiles, festivos ni pausas al esperar cliente. Cambiar prioridad, configuración o reabrir no reinicia vencimientos. El indicador se recalcula al abrir y cada minuto mientras la app está abierta; no hay avisos en segundo plano.

## Contratos y horas
Un contrato por cliente y período sin superposición. Condiciones fijas; renovar creando un período nuevo. La bolsa se aplica por mes calendario, sin prorrateo ni arrastre. Contrato asociado al crear ticket, sin reasignación retroactiva. Tickets anteriores a un contrato conservan su condición sin contrato.

Tiempo entero en minutos, manual, máximo 24 horas por responsable y fecha entre creación y hoy (Santiago). Solo entradas marcadas bolsa/facturable descuentan minutos. Las no facturables se registran aparte. Anular conserva descripción, minutos originales y motivo; consume cero minutos. Ticket cerrado no admite tiempo nuevo sin reapertura. Entradas facturables de tickets con contrato requieren fecha dentro de ese contrato.

Excedente estimado = redondeo a peso de minutos extra × tarifa/hora ÷ 60. Valor mensual es referencia independiente. Sin contrato no se estima una tarifa. No emite facturas, cobros, ni liquidación tributaria.

## Alcance y validación
- Administración privada única. Responsables son registros; sin roles o login independiente, portal público de clientes ni recepción de correo.
- Sin correo/WhatsApp real, archivos adjuntos, cronómetro automático, alertas en segundo plano ni integraciones externas conectadas.
- Supabase: JSON por instancia y sesiones, RLS, clave exclusiva servidor; no Supabase Auth ni tablas normalizadas por entidad.
- API GET/POST /api/service con revisión contra sobrescritura concurrente.
- Siete pruebas automáticas de dominio y servidor portable aprobadas. Tipos y compilaciones verificados.
- No se ejecutó Docker ni se conectó un proyecto Supabase real. Requieren prueba en destino. Revisión visual y paginación del informe pendientes por falta de control de navegador.

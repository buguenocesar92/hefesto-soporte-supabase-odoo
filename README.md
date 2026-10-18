# Hefesto Soporte
Mesa de ayuda privada con tickets, clientes, responsables, plazos de primera respuesta y resolución, conversaciones registradas, notas internas, contratos con bolsas mensuales de horas, registro/anulación de tiempo, procedimientos e informes imprimibles.

[Instalación, migración y límites](docs/INSTALACION.md).

Incluye código, Docker/Coolify, migración Supabase, persistencia SQLite/Supabase, importador/exportador y preparación CSV para Odoo u otra mesa de ayuda. El sitio publicado usa D1; la instalación portable usa administración propia sin depender de ChatGPT.

## Despliegue en Coolify (MVP Hefesto)

Coolify publica `compose.supabase.yaml` desde la rama `coolify`. El servicio se llama `taller`
(conserva el nombre del adaptador portable) y Coolify le asigna el dominio público: enruta
Traefik al puerto interno `3000` que el compose expone con `expose`.

Antes del primer deploy:

1. Aplicar `supabase/migrations/202610130001_hefesto_taller.sql` en el SQL Editor del proyecto
   Supabase (crea `hefesto_soporte_states` y `hefesto_soporte_sessions`, ambas con RLS y acceso
   solo para `service_role`).
2. Definir las variables en Coolify a partir de `.env.example`:
   - `ADMIN_PASSWORD` (16+ caracteres), `PUBLIC_ORIGIN` (URL HTTPS del dominio asignado),
     `COOKIE_SECURE=true`.
   - `STORAGE_BACKEND=supabase`, `SUPABASE_URL`, `SUPABASE_SECRET_KEY` (clave `sb_secret_…`
     o `service_role`), `WORKSHOP_ID` (un valor por instancia, por defecto `main`).
3. Smoke test local del compose antes del deploy:
   ```sh
   bash scripts/coolify-check.sh
   ```
   Debe terminar con `Coolify check OK` y `exit=0`. Falla si algún servicio sin `profiles`
   expone `ports:`, `container_name`, `privileged`, `cap_add`, `devices`, `network_mode: host`,
   `pid`/`ipc: host`, `security_opt: unconfined`, `docker.sock` o un bind fuera del repo.

El compose portable no publica puertos al host: Traefik (de Coolify) hace de gateway TLS.

## Verificar
Node 24: `node --test tests/*.test.mjs`. package.json raíz corresponde a Sites. Para compilar portable en una copia separada usa portable/package.json como package.json raíz, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso. Cliente ya compilado en portable/dist.

## Oferta comercial
Una instancia por empresa para administrar contratos de soporte y sus horas. Comercializar instalación, configuración, carga de clientes y soporte mensual. Esta aplicación no factura ni cobra automáticamente esas suscripciones.

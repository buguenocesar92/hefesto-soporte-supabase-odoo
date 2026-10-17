# Hefesto Soporte
Mesa de ayuda privada con tickets, clientes, responsables, plazos de primera respuesta y resolución, conversaciones registradas, notas internas, contratos con bolsas mensuales de horas, registro/anulación de tiempo, procedimientos e informes imprimibles.

[Instalación, migración y límites](docs/INSTALACION.md).

Incluye código, Docker/Coolify, migración Supabase, persistencia SQLite/Supabase, importador/exportador y preparación CSV para Odoo u otra mesa de ayuda. El sitio publicado usa D1; la instalación portable usa administración propia sin depender de ChatGPT.

## Verificar
Node 24: `node --test tests/*.test.mjs`. package.json raíz corresponde a Sites. Para compilar portable en una copia separada usa portable/package.json como package.json raíz, instala dependencias y ejecuta `npm run build`. Docker realiza ese proceso. Cliente ya compilado en portable/dist.

## Oferta comercial
Una instancia por empresa para administrar contratos de soporte y sus horas. Comercializar instalación, configuración, carga de clientes y soporte mensual. Esta aplicación no factura ni cobra automáticamente esas suscripciones.

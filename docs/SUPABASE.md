# Hefesto Soporte + Supabase

Este paquete usa Supabase PostgreSQL para los datos y las sesiones de la version
desplegada en Docker/Coolify. La interfaz no recibe claves de Supabase: el
servidor usa la clave secreta y el navegador habla solo con la API de Hefesto.

## 1. Preparar tu proyecto

Crea o elige un proyecto Supabase y, en el SQL Editor, ejecuta el contenido de
`supabase/migrations/202610130001_hefesto_taller.sql`.

El script crea dos tablas dedicadas:

| Tabla | Que guarda |
| --- | --- |
| `hefesto_soporte_states` | Estado del kit y numero de revision (optimista) |
| `hefesto_soporte_sessions` | Hashes de sesion y vencimiento |

RLS queda habilitado en las dos y el acceso a `anon` y `authenticated` queda
revocado: solo `service_role`, que usa el servidor, puede leer y escribir. No
se crean politicas publicas.

## 2. Variables del servicio en Coolify

```dotenv
SUPABASE_URL=https://TU-PROYECTO.supabase.co
SUPABASE_SECRET_KEY=TU_CLAVE_SECRETA
ADMIN_PASSWORD=UNA_CONTRASENA_LARGA_Y_ALEATORIA
PUBLIC_ORIGIN=https://TU-DOMINIO
```

La clave secreta tiene privilegios de servidor: nunca va en variables `VITE_`,
`NEXT_PUBLIC_` ni en el codigo del frontend.

## 3. Coherencia de nombres

El kit **no** levanta ningun contenedor de Odoo ni de PostgreSQL propio: el
compose del repositorio (`compose.supabase.yaml`) solo publica la API. La base
de datos es la de Supabase y la integracion con Odoo es de preparacion CSV
(`migration/prepare_odoo.py`), sin cliente ni sincronizacion. Si en el futuro se
anaden contenedores, sus nombres deberan quedar fijados en `compose.supabase.yaml`
y referenciados desde `.env.example` con el **mismo** nombre: un `.env.example`
que diga `odoo` apuntando a un contenedor `odoo18` es un despliegue roto.

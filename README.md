# TuKios

SaaS multi-tenant de gestión para kioscos, almacenes y minimarkets argentinos. Cada local tiene su catálogo público con checkout propio, y un panel de gestión de stock y ventas.

## Stack

- Next.js (App Router) + TypeScript
- Tailwind CSS
- Drizzle ORM + Postgres (Supabase)
- Supabase Auth + Supabase Storage
- Netlify (hosting)

## Setup

1. Cloná el repo e instalá las dependencias:

   ```bash
   git clone <url-del-repo>
   cd TuKios
   npm install
   ```

2. Copiá `.env.local.example` a `.env.local` y completá las variables. Salen del dashboard de tu proyecto en Supabase (Project Settings → API y → Database):

   ```bash
   cp .env.local.example .env.local
   ```

3. Corré las migraciones:

   ```bash
   npx drizzle-kit migrate
   ```

   Si la conexión se cuelga indefinidamente (sin tirar error), es un problema conocido de resolución IPv6 en algunas redes contra la conexión directa (puerto 5432) de Supabase. Solución: en el dashboard de Supabase, usá el connection string de **Session pooler** en vez de **Direct connection** para `DATABASE_URL`.

4. Levantá el proyecto:

   ```bash
   npm run dev
   ```

## Estructura de carpetas

```
app/
  (marketing)/   landing institucional del software (tukios.com)
  (panel)/       panel de gestión de stock/ventas (panel.tukios.com)
  (tienda)/      catálogo público + checkout de cada local (sulocal.tukios.com)
db/              schema de Drizzle y cliente de conexión
drizzle/         migraciones SQL generadas/aplicadas con drizzle-kit
sql/             scripts de verificación manual (no son migraciones)
```

## Más allá de esto

Para entender el porqué de las decisiones de arquitectura y de producto (no solo cómo levantar el proyecto), ver [`claude.md`](./claude.md).

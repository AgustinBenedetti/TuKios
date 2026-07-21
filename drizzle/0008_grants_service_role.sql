-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- GRANT de tabla para el rol "service_role", faltante desde el scaffolding
-- -- mismo problema que ya se había diagnosticado y resuelto para
-- "authenticated" en 0002_grants_authenticated.sql, pero para ese rol nunca
-- se hizo el mismo fix.
--
-- Encontrado en la práctica al construir el flujo de onboarding
-- (feat/onboarding-tienda): el primer INSERT real hecho con el cliente de
-- Supabase usando la service_role key falló con
-- "permission denied for table tiendas" (código 42501), pese a que
-- service_role tiene BYPASSRLS = true. Bypasear RLS no alcanza: Postgres
-- primero chequea privilegios de tabla (GRANT), y recién después evalúa
-- RLS -- sin GRANT, ni siquiera se llega a esa segunda instancia. Es
-- exactamente el mismo diagnóstico que 0002, aplicado a otro rol:
--
--   select grantee, table_name, privilege_type
--   from information_schema.role_table_grants
--   where grantee = 'service_role' and table_schema = 'public';
--
-- devolvía únicamente REFERENCES/TRIGGER/TRUNCATE en las 6 tablas -- igual
-- que "authenticated" antes de 0002.
--
-- A diferencia de "authenticated" (que solo recibió SELECT/INSERT/UPDATE,
-- sin DELETE, porque ninguna policy de RLS lo permite y no tiene sentido
-- otorgar un privilegio que RLS igual bloquearía), acá SÍ se incluye
-- DELETE: service_role bypasea RLS por diseño y es el rol que usa el
-- backend de la app para operaciones administrativas de confianza (por
-- ejemplo, revertir el alta de una tienda si falla la creación de su
-- dueño -- ver app/(admin)/admin/actions.ts). No tiene las restricciones
-- de un usuario final, así que no hay razón para no darle DELETE.
--
-- No se incluye la vista productos_publicos a propósito: service_role no
-- la necesita (bypasea RLS y ya tiene acceso completo a "productos"
-- directamente), y esa vista existe específicamente para el acceso
-- limitado de "anon" -- no tiene sentido sumarle otro grantee.
-- ============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  tiendas,
  usuarios,
  categorias,
  productos,
  ventas,
  venta_items
TO service_role;
--> statement-breakpoint

-- ============================================================================
-- ALTER DEFAULT PRIVILEGES, mismo motivo que en 0002: para que esto no se
-- repita con cada tabla nueva creada por migración de acá en adelante.
-- A diferencia del caso de "authenticated" + vistas (ver 0004), acá no hay
-- riesgo de "regalar" un bypass de aislamiento: service_role ya bypasea
-- RLS en cualquier tabla o vista a la que tenga GRANT, así que no hay una
-- policy que este default privilege pueda saltear -- es exactamente el
-- nivel de acceso que se espera que tenga.
-- ============================================================================

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO service_role;

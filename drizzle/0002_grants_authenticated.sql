-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- GRANT de tabla para el rol "authenticated", faltante desde el scaffolding.
--
-- Diagnóstico: las 6 tablas se crearon con una migración de Drizzle (SQL
-- crudo), no con el editor de tablas de Supabase. El editor de Supabase
-- aplica automáticamente GRANT SELECT/INSERT/UPDATE/DELETE a "anon" y
-- "authenticated" al crear una tabla; una migración de Drizzle no. El
-- resultado, verificado con una query directa a
-- information_schema.role_table_grants: "authenticated" solo tenía
-- REFERENCES/TRIGGER/TRUNCATE en estas 6 tablas -- ni SELECT, ni INSERT, ni
-- UPDATE. Postgres corta en el chequeo de privilegios de tabla ANTES de
-- evaluar las policies de RLS, así que sin este GRANT las policies de
-- 0001_rls_policies_aislamiento_tienda.sql no tenían ningún efecto
-- práctico: cualquier request autenticado fallaba con
-- "permission denied for table ..." en vez de simplemente filtrar filas.
--
-- Solo se otorga a "authenticated" (no a "anon"): no hay ningún acceso
-- anónimo en alcance hoy (la vista pública de productos es un feature
-- aparte). Solo SELECT/INSERT/UPDATE, sin DELETE, para que el GRANT quede
-- alineado con las policies existentes -- no tiene sentido otorgar DELETE
-- a nivel tabla cuando no hay ninguna policy de RLS que lo permita (RLS
-- seguiría bloqueando cualquier DELETE de todos modos, pero mejor no dejar
-- un privilegio de tabla más amplio del que las policies respaldan).
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON TABLE
  tiendas,
  usuarios,
  categorias,
  productos,
  ventas,
  venta_items
TO authenticated;
--> statement-breakpoint

-- ============================================================================
-- ALTER DEFAULT PRIVILEGES: para que este mismo problema no se repita con
-- cada tabla nueva creada por migración de acá en adelante. Aplica solo a
-- objetos que cree el rol "postgres" (el que corren las migraciones de
-- Drizzle) dentro del schema "public" -- si en algún momento se vuelve a
-- crear una tabla desde el editor de Supabase, ese GRANT automático de
-- Supabase sigue aplicando en paralelo sin conflicto.
-- ============================================================================

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE ON TABLES TO authenticated;

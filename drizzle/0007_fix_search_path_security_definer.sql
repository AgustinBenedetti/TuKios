-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- Fix: falta "pg_temp" explícito en el search_path de las funciones
-- SECURITY DEFINER del proyecto (mi_tienda_id(), mi_rol(),
-- handle_new_auth_user()).
--
-- Las tres ya fijaban "SET search_path = public" al crearse -- eso ya
-- mitiga el caso más obvio de search_path injection (alguien creando un
-- objeto con el mismo nombre en OTRO schema para que el planner lo
-- resuelva antes que el de "public"). Pero deja un caso sin cubrir: Postgres
-- antepone el schema temporal de la sesión (pg_temp) al search_path de
-- forma IMPLÍCITA, en la primera posición, salvo que pg_temp aparezca
-- explícitamente en la lista -- en cuyo caso se busca en la posición en la
-- que se lo haya puesto, no antes que todo lo demás.
--
-- Confirmado contra esta base que el caso es explotable, no solo teórico:
--   select has_database_privilege('authenticated', current_database(), 'TEMP');
--   select has_database_privilege('anon', current_database(), 'TEMP');
-- Ambas devuelven true -- cualquier usuario autenticado (o incluso anon)
-- puede crear una tabla temporal propia llamada, por ejemplo, "usuarios" o
-- "tiendas" en su propia sesión. Sin "pg_temp" explícito en el
-- search_path, esa tabla temporal se resolvería ANTES que
-- "public.usuarios"/"public.tiendas" dentro de estas funciones -- que
-- corren con privilegios de "postgres" (SECURITY DEFINER) y hacen
-- referencias sin calificar (SELECT tienda_id FROM usuarios ...). Alguien
-- podría crear una tabla temporal "usuarios" con una fila fabricada para
-- hacer que mi_tienda_id()/mi_rol() devuelvan lo que el atacante quiera,
-- rompiendo el aislamiento por tienda y la protección de escalación de rol
-- que dependen de esas dos funciones.
--
-- Fix: agregar ", pg_temp" al final del search_path de las tres. No lo
-- saca de la búsqueda (no se puede evitar del todo que exista), pero lo
-- pasa a ser la ÚLTIMA opción en vez de la implícita primera -- así
-- "public.usuarios"/"public.tiendas" reales siempre se resuelven antes que
-- cualquier objeto temporal con el mismo nombre.
--
-- No hace falta CREATE OR REPLACE FUNCTION (no cambia el cuerpo de
-- ninguna): ALTER FUNCTION ... SET alcanza para tocar solo la config de
-- search_path.
-- ============================================================================

ALTER FUNCTION mi_tienda_id() SET search_path = public, pg_temp;
--> statement-breakpoint

ALTER FUNCTION mi_rol() SET search_path = public, pg_temp;
--> statement-breakpoint

ALTER FUNCTION handle_new_auth_user() SET search_path = public, pg_temp;

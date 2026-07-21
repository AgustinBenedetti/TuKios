-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- Trigger de sincronización: auth.users -> public.usuarios.
--
-- Hoy, cuando alguien se registra vía Supabase Auth (supabase.auth.signUp),
-- se crea una fila en auth.users pero nada crea la fila correspondiente en
-- public.usuarios -- la app quedaría con un usuario "fantasma" que puede
-- loguearse pero no tiene tienda_id/nombre/rol en nuestro modelo. Este
-- trigger cierra ese hueco.
--
-- Problema de fondo: usuarios.tienda_id es NOT NULL, pero al momento del
-- signup todavía no existe ningún flujo que decida a qué tienda pertenece
-- ese usuario -- eso es el onboarding, que es un feature aparte (no esta
-- rama). Entonces, ¿de dónde sale el tienda_id en el momento exacto en que
-- se crea la fila de auth.users?
--
-- Enfoque elegido: leerlo de raw_user_meta_data (jsonb), que es el campo
-- que Supabase Auth llena automáticamente con lo que se pase en
-- `options.data` al llamar signUp() en el cliente. Es decir, el flujo
-- esperado es que quien dispare el signup (el futuro onboarding, o un
-- alta de empleado hecha por el dueño) mande tienda_id (y nombre, y rol)
-- como parte de ese `options.data`, no que este trigger los invente.
--
-- Por qué esto y no las alternativas obvias:
--   - Insertar con tienda_id NULL y arreglarlo después: no se puede,
--     tienda_id es NOT NULL -- y aunque lo fuera, dejaría una ventana
--     real donde existe un usuario autenticado sin tienda, con acceso
--     de lectura/escritura ambiguo hasta que "alguien" complete el dato.
--   - Un tienda_id "placeholder"/tienda por defecto: inventaría membresía
--     a una tienda que el usuario nunca eligió -- un problema de
--     integridad de datos, no solo estético.
--   - Resolver tienda_id con una query a otra tabla (p. ej. por dominio
--     del email): no hay ninguna regla de negocio así en este proyecto;
--     inventarla acá acoplaría este trigger a una decisión de producto
--     que no está definida.
--
-- raw_user_meta_data es la única señal que ya viaja junto con el INSERT en
-- auth.users al momento exacto en que este trigger corre, así que es el
-- único lugar de donde este trigger puede sacar el dato sin inventarlo.
--
-- Si no viene: el trigger falla el INSERT (RAISE EXCEPTION), en vez de
-- crear un usuario huérfano en public.usuarios (o dejar que auth.users
-- quede con una fila sin contraparte). Como esto corre en un trigger
-- AFTER INSERT dentro de la misma transacción con la que Supabase Auth
-- crea el usuario, la excepción revierte TODO -- el INSERT en auth.users
-- también se deshace. No queda ni un auth.users huérfano ni un usuarios
-- huérfano: o se crean los dos, o no se crea ninguno.
--
-- Mismo criterio para nombre y rol (también NOT NULL / obligatorios en
-- usuarios): se piden explícitos en el metadata y se falla si faltan, en
-- vez de inventar un nombre (p. ej. a partir del email) o asumir un rol
-- por default. rol en particular es un campo de seguridad (define
-- permisos) -- un default silencioso ahí sería una decisión de producto
-- tomada a ciegas dentro de un trigger, no algo que debamos inventar acá.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tienda_id uuid;
  v_nombre text;
  v_rol text;
BEGIN
  v_tienda_id := NULLIF(NEW.raw_user_meta_data->>'tienda_id', '')::uuid;
  v_nombre := NULLIF(NEW.raw_user_meta_data->>'nombre', '');
  v_rol := NULLIF(NEW.raw_user_meta_data->>'rol', '');

  IF v_tienda_id IS NULL THEN
    RAISE EXCEPTION
      'No se puede crear el usuario: falta tienda_id en el metadata de signup (raw_user_meta_data). auth.users.id = %', NEW.id;
  END IF;

  IF v_nombre IS NULL THEN
    RAISE EXCEPTION
      'No se puede crear el usuario: falta nombre en el metadata de signup (raw_user_meta_data). auth.users.id = %', NEW.id;
  END IF;

  IF v_rol IS NULL OR v_rol NOT IN ('dueño', 'empleado') THEN
    RAISE EXCEPTION
      'No se puede crear el usuario: falta rol (o no es "dueño"/"empleado") en el metadata de signup (raw_user_meta_data). auth.users.id = %', NEW.id;
  END IF;

  INSERT INTO public.usuarios (id, tienda_id, nombre, email, rol)
  VALUES (NEW.id, v_tienda_id, v_nombre, NEW.email, v_rol);

  RETURN NEW;
END;
$$;
--> statement-breakpoint

-- Por qué SECURITY DEFINER: este trigger corre en el contexto del rol que
-- hace el INSERT en auth.users, que es "supabase_auth_admin" (el rol
-- interno de Supabase Auth/GoTrue) -- no "postgres" ni "authenticated".
-- Ese rol no tiene GRANT sobre public.usuarios, y aunque lo tuviera, la
-- policy de INSERT "usuarios_insert_propia_tienda" exige
-- tienda_id = mi_tienda_id() -- que para un usuario que recién se está
-- creando siempre da NULL (todavía no existe su fila en usuarios). Es el
-- mismo problema de bootstrap ya documentado en
-- 0001_rls_policies_aislamiento_tienda.sql para el alta manual del primer
-- usuario/tienda. SECURITY DEFINER hace que el INSERT interno corra con
-- los privilegios del owner de la función (postgres, que además tiene
-- BYPASSRLS), evitando ese problema para este camino específico de alta
-- (vía signup), sin abrir la policy de INSERT en sí. Mismo patrón y misma
-- mitigación de search_path que mi_tienda_id() (ver 0001) -- fijar
-- search_path explícitamente evita que alguien hijackee la función
-- creando un objeto con el mismo nombre en otro schema.
--
-- Por qué AFTER INSERT (no BEFORE): no necesitamos modificar la fila de
-- auth.users que se está insertando, solo reaccionar a su creación. AFTER
-- también dispara sobre la fila ya persistida (aunque igual dentro de la
-- misma transacción, revertible), evitando cualquier duda sobre si
-- NEW.id ya es válido al momento de insertar en usuarios.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

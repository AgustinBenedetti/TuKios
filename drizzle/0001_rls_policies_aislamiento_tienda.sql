-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- Policies de Row Level Security: aislamiento por tienda_id.
--
-- RLS ya está habilitado (ALTER TABLE ... ENABLE ROW LEVEL SECURITY) en las
-- 6 tablas desde la creación del proyecto en Supabase. Sin policies, el
-- comportamiento por defecto de Postgres es denegar todo acceso, así que
-- esta migración es la que habilita lectura/escritura real.
--
-- Fuera de alcance a propósito (quedan para features aparte):
--   - Distinción de permisos dueño/empleado dentro de una misma tienda.
--   - La vista productos_publicos (acceso público de solo lectura).
--   - DELETE en cualquier tabla.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Función auxiliar: mi_tienda_id()
--
-- Devuelve el tienda_id del usuario autenticado actual, buscándolo en
-- "usuarios" por auth.uid(). Se usa como condición en todas las policies
-- de aislamiento de abajo.
--
-- Por qué SECURITY DEFINER: la tabla "usuarios" tiene RLS habilitado, y una
-- de sus propias policies (más abajo) también llama a mi_tienda_id() para
-- decidir qué filas puede ver un usuario. Si esta función corriera con los
-- privilegios del invocador (comportamiento por defecto), su SELECT interno
-- sobre "usuarios" quedaría sujeto a esa misma policy de RLS — que a su vez
-- depende de esta función para evaluarse. Esa referencia circular hace que
-- la función nunca resuelva nada (0 filas visibles) y el usuario quede
-- bloqueado incluso para leer su propia fila. SECURITY DEFINER hace que el
-- SELECT interno corra con los privilegios del owner de la función
-- (bypasseando RLS), rompiendo el ciclo. Por eso también se fija search_path
-- explícitamente: es la mitigación estándar contra hijacking de search_path
-- en funciones SECURITY DEFINER (alguien podría crear un objeto con el mismo
-- nombre en otro schema para alterar su comportamiento).
--
-- STABLE (no VOLATILE) porque, dentro de una misma sentencia SQL, el
-- resultado no cambia para el mismo usuario — permite al planner
-- evaluarla una sola vez en vez de por cada fila evaluada por la policy.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mi_tienda_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tienda_id FROM usuarios WHERE id = auth.uid()
$$;
--> statement-breakpoint

-- ============================================================================
-- productos
-- ============================================================================

-- Permite ver únicamente los productos de la propia tienda.
CREATE POLICY "productos_select_propia_tienda" ON productos
  FOR SELECT
  USING (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite crear productos solo con el tienda_id de la propia tienda (evita
-- que un usuario cree productos "para" otra tienda).
CREATE POLICY "productos_insert_propia_tienda" ON productos
  FOR INSERT
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite modificar solo productos de la propia tienda, y evita que la
-- edición reasigne el producto a otro tienda_id (USING valida la fila
-- existente, WITH CHECK valida la fila resultante).
CREATE POLICY "productos_update_propia_tienda" ON productos
  FOR UPDATE
  USING (tienda_id = mi_tienda_id())
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- ============================================================================
-- categorias
-- ============================================================================

-- Permite ver únicamente las categorías de la propia tienda.
CREATE POLICY "categorias_select_propia_tienda" ON categorias
  FOR SELECT
  USING (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite crear categorías solo con el tienda_id de la propia tienda.
CREATE POLICY "categorias_insert_propia_tienda" ON categorias
  FOR INSERT
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite modificar solo categorías de la propia tienda, sin poder
-- reasignarlas a otro tienda_id.
CREATE POLICY "categorias_update_propia_tienda" ON categorias
  FOR UPDATE
  USING (tienda_id = mi_tienda_id())
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- ============================================================================
-- ventas
-- ============================================================================

-- Permite ver únicamente las ventas de la propia tienda.
CREATE POLICY "ventas_select_propia_tienda" ON ventas
  FOR SELECT
  USING (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite registrar ventas solo con el tienda_id de la propia tienda.
CREATE POLICY "ventas_insert_propia_tienda" ON ventas
  FOR INSERT
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite modificar solo ventas de la propia tienda (p. ej. cambiar
-- estado), sin poder reasignarlas a otro tienda_id.
CREATE POLICY "ventas_update_propia_tienda" ON ventas
  FOR UPDATE
  USING (tienda_id = mi_tienda_id())
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- ============================================================================
-- venta_items
--
-- Esta tabla no tiene tienda_id propio: el aislamiento se resuelve
-- indirectamente a través de la venta a la que pertenece cada item.
-- ============================================================================

-- Permite ver únicamente los items de ventas que pertenecen a la propia
-- tienda (join implícito vía subquery sobre ventas).
CREATE POLICY "venta_items_select_propia_tienda" ON venta_items
  FOR SELECT
  USING (
    venta_id IN (SELECT id FROM ventas WHERE tienda_id = mi_tienda_id())
  );
--> statement-breakpoint

-- Permite agregar items solo a ventas que pertenecen a la propia tienda.
CREATE POLICY "venta_items_insert_propia_tienda" ON venta_items
  FOR INSERT
  WITH CHECK (
    venta_id IN (SELECT id FROM ventas WHERE tienda_id = mi_tienda_id())
  );
--> statement-breakpoint

-- Permite modificar solo items de ventas de la propia tienda, y evita
-- reasignar el item a una venta de otra tienda.
CREATE POLICY "venta_items_update_propia_tienda" ON venta_items
  FOR UPDATE
  USING (
    venta_id IN (SELECT id FROM ventas WHERE tienda_id = mi_tienda_id())
  )
  WITH CHECK (
    venta_id IN (SELECT id FROM ventas WHERE tienda_id = mi_tienda_id())
  );
--> statement-breakpoint

-- ============================================================================
-- usuarios
--
-- mi_tienda_id() ya es SECURITY DEFINER (ver arriba), así que reutilizarla
-- acá no genera un problema nuevo de referencia circular: su SELECT interno
-- sobre "usuarios" bypasea RLS sin importar qué tabla esté evaluando la
-- policy que la invoca. No hace falta una segunda función.
-- ============================================================================

-- Permite ver a todos los usuarios de la propia tienda (no solo la propia
-- fila), para que el dueño pueda listar a sus empleados. La distinción de
-- qué puede ver/hacer un empleado vs. un dueño queda para el feature de
-- permisos aparte; por ahora el aislamiento es únicamente por tienda_id.
CREATE POLICY "usuarios_select_propia_tienda" ON usuarios
  FOR SELECT
  USING (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite crear una fila de usuario solo con el tienda_id de la propia
-- tienda (p. ej. un dueño invitando a un empleado). Nota: esto NO cubre el
-- alta del primer usuario de una tienda nueva -- en ese momento todavía no
-- existe una fila en "usuarios" para esa persona, así que mi_tienda_id()
-- devuelve NULL y el check falla. Ese bootstrap inicial (alta de tienda +
-- primer usuario dueño) tiene que hacerse con una clave con privilegios
-- (service_role), que bypasea RLS -- no a través de esta policy.
CREATE POLICY "usuarios_insert_propia_tienda" ON usuarios
  FOR INSERT
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- Permite modificar solo usuarios de la propia tienda, sin poder
-- reasignarlos a otro tienda_id. Igual que en SELECT, todavía no distingue
-- si quien edita es dueño o empleado ni qué campos puede tocar (p. ej. nada
-- impide hoy que un empleado se autoasigne rol = 'dueño'); eso se resuelve
-- en el feature de permisos dueño/empleado.
CREATE POLICY "usuarios_update_propia_tienda" ON usuarios
  FOR UPDATE
  USING (tienda_id = mi_tienda_id())
  WITH CHECK (tienda_id = mi_tienda_id());
--> statement-breakpoint

-- ============================================================================
-- tiendas
--
-- Solo SELECT y UPDATE: no se crea policy de INSERT acá. Crear una tienda
-- es siempre una operación de bootstrap (todavía no existe ningún usuario
-- apuntando a esa tienda), así que id = mi_tienda_id() nunca puede ser
-- verdadero para un INSERT hecho por un usuario autenticado normal -- ese
-- caso, igual que el alta del primer usuario arriba, tiene que resolverse
-- con service_role fuera de RLS, no con una policy de este tipo.
-- ============================================================================

-- Permite ver únicamente la propia tienda.
CREATE POLICY "tiendas_select_propia" ON tiendas
  FOR SELECT
  USING (id = mi_tienda_id());
--> statement-breakpoint

-- Permite modificar únicamente la propia tienda, sin poder tocar otras.
CREATE POLICY "tiendas_update_propia" ON tiendas
  FOR UPDATE
  USING (id = mi_tienda_id())
  WITH CHECK (id = mi_tienda_id());

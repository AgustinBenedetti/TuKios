-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- Resuelve el issue #2 de GitHub: "Empleado puede auto-asignarse el rol de
-- dueño (falta policy de UPDATE en usuarios)".
--
-- La policy "usuarios_update_propia_tienda" de
-- 0001_rls_policies_aislamiento_tienda.sql solo aísla por tienda_id -- dentro
-- de la misma tienda, cualquier usuario autenticado puede editar la fila de
-- CUALQUIER otro usuario, incluido el campo rol. Un empleado podía llamar la
-- API directo y ponerse rol = 'dueño'. Esta migración la reemplaza por una
-- que además distingue dueño/empleado y protege específicamente el campo rol.
--
-- Reglas a implementar:
--   1. Cualquier usuario puede editar su propia fila, EXCEPTO el campo rol.
--   2. Un usuario con rol 'dueño' puede editar cualquier fila de su tienda,
--      incluido el rol de otros.
--   3. Un usuario con rol 'empleado' no puede modificar el rol de nadie, ni
--      el propio ni el de otros (implícito: tampoco puede editar ninguna
--      otra columna de la fila de otro usuario -- solo dueño edita filas
--      ajenas).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Función auxiliar: mi_rol()
--
-- Mismo patrón que mi_tienda_id() (ver 0001): devuelve el rol del usuario
-- autenticado actual, buscándolo en "usuarios" por auth.uid(). SECURITY
-- DEFINER por la misma razón -- la policy de abajo la usa para evaluarse a
-- sí misma sobre la propia tabla "usuarios", así que sin SECURITY DEFINER
-- el SELECT interno quedaría sujeto a la policy que la está evaluando
-- (referencia circular, 0 filas siempre). STABLE por la misma razón de
-- rendimiento (el planner la evalúa una vez por sentencia, no por fila).
-- search_path fijado explícitamente, misma mitigación de hijacking.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mi_rol()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rol FROM usuarios WHERE id = auth.uid()
$$;
--> statement-breakpoint

-- ============================================================================
-- ¿Una sola policy con WITH CHECK, o hacen falta varias?
--
-- Se puede hacer con una sola policy (la de abajo). La alternativa -- dos
-- policies permissive separadas, una para "dueño edita cualquier fila" y
-- otra para "cualquiera edita su propia fila sin tocar rol" -- también
-- cubriría los tres casos, PERO tiene una trampa: cuando Postgres evalúa
-- varias policies PERMISSIVE para el mismo comando, combina con OR el
-- USING de todas entre sí, y por separado combina con OR el WITH CHECK de
-- todas entre sí -- el emparejamiento NO es "policy por policy". Con dos
-- policies, para que una fila sea aceptada alcanza con que pase el USING de
-- CUALQUIERA de las dos y el WITH CHECK de CUALQUIERA de las dos, no
-- necesariamente los de la misma policy. En este caso puntual da igual (se
-- puede verificar que ningún combinamiento cruzado abre un agujero), pero
-- es un modo fácil de introducir un bug sutil de seguridad si mañana se
-- agrega una tercera policy o se edita alguna de las dos sin tener en
-- cuenta la otra. Con una sola policy, todo el OR está escrito a la vista,
-- en un solo lugar, sin depender de entender cómo Postgres combina policies
-- entre sí -- más fácil de auditar para algo tan sensible como escalación
-- de rol. Por eso se eligió una sola policy acá.
--
-- Cómo compara la fila NUEVA con la VIEJA dentro de la misma policy:
-- WITH CHECK solo ve la fila resultante (NEW), no tiene una referencia
-- directa a la fila anterior (OLD). El truco es reutilizar mi_rol(): esa
-- función hace su propio SELECT contra "usuarios", que --por las reglas
-- de visibilidad de Postgres dentro de una misma sentencia-- ve la fila
-- como estaba ANTES de este UPDATE, no el valor nuevo que se está por
-- escribir (una sentencia no ve sus propios cambios en curso sobre la
-- misma fila). Entonces, cuando la fila que se edita es la propia
-- (id = auth.uid(), que es justo la condición bajo la que se compara),
-- "mi_rol()" es exactamente el rol viejo de esa fila. Comparar
-- "rol = mi_rol()" en el WITH CHECK es, en ese caso, comparar el rol nuevo
-- contra el rol viejo -- "el UPDATE no cambió el rol". Esto se verificó
-- de forma empírica (no solo por lectura de la documentación) con la query
-- de sql/verificacion_policy_update_usuarios.sql antes de dar esto por
-- bueno.
-- ============================================================================

DROP POLICY "usuarios_update_propia_tienda" ON usuarios;
--> statement-breakpoint

CREATE POLICY "usuarios_update_propia_fila_o_dueño" ON usuarios
  FOR UPDATE
  USING (
    tienda_id = mi_tienda_id()
    AND (
      mi_rol() = 'dueño'      -- el dueño puede apuntar a cualquier fila de su tienda
      OR id = auth.uid()      -- cualquiera puede apuntar a su propia fila
    )
  )
  WITH CHECK (
    tienda_id = mi_tienda_id()  -- nadie puede reasignar la fila a otra tienda
    AND (
      mi_rol() = 'dueño'
      -- el dueño puede dejar la fila resultante como quiera (incluido rol)
      OR (id = auth.uid() AND rol = mi_rol())
      -- cualquier otro solo puede editar su propia fila, y solo si el rol
      -- resultante es igual al que ya tenía (no lo puede cambiar)
    )
  );

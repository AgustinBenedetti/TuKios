-- ============================================================================
-- Verificación MANUAL de la policy de UPDATE en "usuarios" (issue #2:
-- escalación de rol). Correr esto a mano en el SQL Editor de Supabase. No
-- es una migración, no lo ejecuta drizzle-kit, y no está pensado para
-- correr en CI.
--
-- Mismo motivo que en las otras verificaciones manuales del proyecto: el
-- SQL Editor corre como "postgres", que bypasea RLS. Para probar de
-- verdad qué puede hacer "authenticated" hace falta SET LOCAL ROLE +
-- request.jwt.claims (así resuelve auth.uid() Supabase internamente).
--
-- Nota: los INSERT de acá van directo a auth.users con raw_user_meta_data,
-- lo que dispara el trigger on_auth_user_created (ver
-- 0005_trigger_sync_auth_users.sql) y crea la fila de "usuarios"
-- automáticamente -- no hace falta insertarla a mano.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Paso 0: datos de prueba descartables -- una tienda con un dueño y un
-- empleado. Corre como postgres (sin simular sesión). Se deja committeado
-- para poder simular sesiones distintas en los pasos siguientes.
-- ----------------------------------------------------------------------------
begin;

insert into tiendas (id, nombre, subdominio) values
  ('88888888-8888-8888-8888-888888888888', 'Tienda Verif Rol (test)', 'tienda-verif-rol-test');

insert into auth.users (id, email, raw_user_meta_data) values
  ('d0000000-0000-0000-0000-000000000001', 'dueno-verif-test@example.com',
    '{"tienda_id": "88888888-8888-8888-8888-888888888888", "nombre": "Dueño Test", "rol": "dueño"}'::jsonb),
  ('e0000000-0000-0000-0000-000000000002', 'empleado-verif-test@example.com',
    '{"tienda_id": "88888888-8888-8888-8888-888888888888", "nombre": "Empleado Test", "rol": "empleado"}'::jsonb);

commit;

-- Confirmá acá que el trigger creó las dos filas en usuarios, con los
-- roles correctos, antes de seguir:
select id, tienda_id, nombre, rol from usuarios
where tienda_id = '88888888-8888-8888-8888-888888888888';

-- ----------------------------------------------------------------------------
-- Paso 1: EL CASO DEL ISSUE. El empleado intenta hacer UPDATE sobre su
-- propia fila cambiando rol a 'dueño'. Tiene que ser rechazado.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "e0000000-0000-0000-0000-000000000002", "role": "authenticated"}';

  -- Esperado: ERROR - new row violates row-level security policy for table "usuarios"
  update usuarios set rol = 'dueño'
  where id = 'e0000000-0000-0000-0000-000000000002';
rollback;

-- ----------------------------------------------------------------------------
-- Paso 2: el empleado SÍ puede editar su propia fila mientras no toque rol.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "e0000000-0000-0000-0000-000000000002", "role": "authenticated"}';

  -- Esperado: 1 fila afectada, rol sigue en 'empleado'
  update usuarios set nombre = 'Empleado Editado'
  where id = 'e0000000-0000-0000-0000-000000000002'
  returning id, nombre, rol;
rollback;

-- ----------------------------------------------------------------------------
-- Paso 3: el empleado NO puede editar la fila de otro usuario (ni rol ni
-- ningún otro campo) -- eso es exclusivo del dueño.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "e0000000-0000-0000-0000-000000000002", "role": "authenticated"}';

  -- Esperado: 0 filas (RLS filtra, no tira error)
  update usuarios set nombre = 'Hackeado'
  where id = 'd0000000-0000-0000-0000-000000000001'
  returning id;
rollback;

-- ----------------------------------------------------------------------------
-- Paso 4: el dueño SÍ puede editar el rol de otro usuario de su tienda.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "d0000000-0000-0000-0000-000000000001", "role": "authenticated"}';

  -- Esperado: 1 fila afectada, rol pasa a 'dueño'
  update usuarios set rol = 'dueño'
  where id = 'e0000000-0000-0000-0000-000000000002'
  returning id, rol;
rollback;

-- ----------------------------------------------------------------------------
-- Paso 5 (extra): el trigger de sincronización rechaza un signup sin
-- tienda_id en el metadata -- confirma que no queda un usuario huérfano.
-- ----------------------------------------------------------------------------
begin;
  -- Esperado: ERROR - No se puede crear el usuario: falta tienda_id...
  insert into auth.users (id, email, raw_user_meta_data) values
    (gen_random_uuid(), 'sin-tienda-verif-test@example.com', '{"nombre": "Sin Tienda", "rol": "empleado"}'::jsonb);
rollback;

-- ----------------------------------------------------------------------------
-- Paso 6 (limpieza): borrar los datos de prueba del Paso 0. Corre como
-- postgres (sin sesión simulada). Borrar de auth.users basta -- si algo
-- salió mal en la limpieza de "usuarios", no hay FK que lo fuerce, así que
-- se borra explícitamente también por las dudas.
-- ----------------------------------------------------------------------------
begin;

delete from usuarios where tienda_id = '88888888-8888-8888-8888-888888888888';
delete from auth.users where id in (
  'd0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002'
);
delete from tiendas where id = '88888888-8888-8888-8888-888888888888';

commit;

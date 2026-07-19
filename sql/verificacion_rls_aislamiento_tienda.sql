-- ============================================================================
-- Verificación MANUAL de las policies de RLS (aislamiento por tienda_id).
-- Correr esto a mano en el SQL Editor de Supabase. No es una migración,
-- no lo ejecuta drizzle-kit, y no está pensado para correr en CI.
--
-- Por qué hace falta simular una sesión: el SQL Editor de Supabase corre
-- como un rol con privilegios (postgres), que bypasea RLS por completo.
-- Para que las policies realmente se apliquen hay que simular una sesión
-- autenticada con SET LOCAL ROLE + request.jwt.claims (así es como
-- Supabase resuelve auth.uid() internamente). Cada bloque va envuelto en
-- BEGIN/ROLLBACK para no dejar nada modificado.
--
-- Reemplazá los UUIDs de ejemplo por dos usuarios reales de dos tiendas
-- distintas, o corré el Paso 0 para crear datos de prueba descartables.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Paso 0 (opcional): datos de prueba mínimos, si todavía no tenés dos
-- tiendas con datos para comparar. Corre como postgres (sin simular sesión).
-- Los UUIDs de "usuarios" acá son inventados: para esta prueba no hace
-- falta que existan en auth.users, alcanza con que auth.uid() simulado
-- coincida con usuarios.id.
-- ----------------------------------------------------------------------------
begin;

insert into tiendas (id, nombre, subdominio) values
  ('11111111-1111-1111-1111-111111111111', 'Tienda A (test)', 'tienda-a-test'),
  ('22222222-2222-2222-2222-222222222222', 'Tienda B (test)', 'tienda-b-test');

insert into usuarios (id, tienda_id, nombre, email, rol) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Usuario A', 'usuario-a-test@example.com', 'dueño'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Usuario B', 'usuario-b-test@example.com', 'dueño');

insert into productos (tienda_id, nombre, costo, porcentaje_ganancia, precio_final) values
  ('11111111-1111-1111-1111-111111111111', 'Producto de Tienda A', 100, 30, 130),
  ('22222222-2222-2222-2222-222222222222', 'Producto de Tienda B', 100, 30, 130);

commit; -- dejamos los datos de prueba insertados para poder consultarlos abajo

-- ----------------------------------------------------------------------------
-- Paso 1: simular sesión del Usuario A (dueño de Tienda A).
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "role": "authenticated"}';

  -- Esperado: 11111111-1111-1111-1111-111111111111
  select mi_tienda_id();

  -- Esperado: solo el producto de Tienda A (nunca el de Tienda B)
  select id, tienda_id, nombre from productos;

  -- Esperado: solo el usuario de Tienda A (nunca el de Tienda B)
  select id, tienda_id, nombre from usuarios;

  -- Esperado: solo la fila de Tienda A
  select id, nombre from tiendas;

  -- Intento explícito de leer datos de la otra tienda por id: RLS filtra
  -- (no tira error), así que esperado = 0 filas.
  select * from productos where tienda_id = '22222222-2222-2222-2222-222222222222';
rollback; -- no modificamos nada, solo lecturas

-- ----------------------------------------------------------------------------
-- Paso 2: Usuario A intenta escribir "para" la otra tienda -> debe fallar.
-- Este bloque termina en error a propósito (viola el WITH CHECK); el
-- ROLLBACK automático de Postgres al fallar la sentencia ya deja todo como
-- estaba, pero lo hacemos explícito igual.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "role": "authenticated"}';

  -- Esperado: ERROR - new row violates row-level security policy
  insert into productos (tienda_id, nombre, costo, porcentaje_ganancia, precio_final)
  values ('22222222-2222-2222-2222-222222222222', 'Intento cruzado', 10, 10, 11);
rollback;

-- ----------------------------------------------------------------------------
-- Paso 3: repetir con el Usuario B y confirmar que ve el espejo exacto
-- (solo datos de Tienda B, cero filas de Tienda A).
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "role": "authenticated"}';

  -- Esperado: 22222222-2222-2222-2222-222222222222
  select mi_tienda_id();

  select id, tienda_id, nombre from productos; -- solo Tienda B
  select id, tienda_id, nombre from usuarios;  -- solo Tienda B
  select id, nombre from tiendas;              -- solo Tienda B
rollback;

-- ----------------------------------------------------------------------------
-- Paso 4 (limpieza): borrar los datos de prueba del Paso 0. Corre como
-- postgres (sin sesión simulada), así que no depende de las policies.
-- ----------------------------------------------------------------------------
begin;

delete from productos where tienda_id in (
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'
);
delete from usuarios where id in (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);
delete from tiendas where id in (
  '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'
);

commit;

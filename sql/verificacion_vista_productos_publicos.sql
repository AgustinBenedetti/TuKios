-- ============================================================================
-- Verificación MANUAL de la vista productos_publicos y sus permisos.
-- Correr esto a mano en el SQL Editor de Supabase. No es una migración,
-- no lo ejecuta drizzle-kit, y no está pensado para correr en CI.
--
-- Mismo motivo que en sql/verificacion_rls_aislamiento_tienda.sql: el SQL
-- Editor corre como "postgres", que bypasea RLS y tiene todos los GRANT.
-- Para probar de verdad qué puede hacer "anon" (o "authenticated") hace
-- falta SET LOCAL ROLE. Cada bloque va en BEGIN/ROLLBACK para no dejar
-- nada modificado.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Paso 0 (opcional): un producto de prueba descartable, si no tenés datos
-- reales todavía. Corre como postgres (sin simular sesión).
-- ----------------------------------------------------------------------------
begin;

insert into tiendas (id, nombre, subdominio) values
  ('99999999-9999-9999-9999-999999999999', 'Tienda Verif Vista (test)', 'tienda-verif-vista-test');

insert into productos (
  tienda_id, nombre, foto_url, codigo_barras, costo, porcentaje_ganancia, precio_final, disponible
) values (
  '99999999-9999-9999-9999-999999999999', 'Producto Verif Vista', 'http://ejemplo/foto.jpg',
  '7791234567890', 100, 30, 130, true
);

commit; -- dejamos los datos insertados para poder consultarlos abajo

-- ----------------------------------------------------------------------------
-- Paso 1: anon puede leer productos_publicos, y ni costo ni
-- porcentaje_ganancia aparecen en el resultado (no forman parte de la
-- vista, así que ni siquiera es necesario filtrarlas a mano: si algún día
-- alguien agrega esas columnas a la vista por error, este SELECT * las
-- va a mostrar y la revisión visual del resultado lo va a delatar).
-- ----------------------------------------------------------------------------
begin;
  set local role anon;

  -- Esperado: la fila del producto de prueba, con exactamente estas
  -- columnas: id, tienda_id, categoria_id, nombre, foto_url, precio_final,
  -- disponible, codigo_barras. Sin costo. Sin porcentaje_ganancia.
  select * from productos_publicos
  where tienda_id = '99999999-9999-9999-9999-999999999999';
rollback;

-- ----------------------------------------------------------------------------
-- Paso 2: anon NO puede leer la tabla productos directamente (ni siquiera
-- las columnas no sensibles) -- solo tiene GRANT sobre la vista, no sobre
-- la tabla. Este bloque termina en error a propósito.
-- ----------------------------------------------------------------------------
begin;
  set local role anon;

  -- Esperado: ERROR - permission denied for table productos
  select id, nombre from productos
  where tienda_id = '99999999-9999-9999-9999-999999999999';
rollback;

-- ----------------------------------------------------------------------------
-- Paso 3 (extra, no pedido explícitamente pero relevante): confirmar que
-- "authenticated" tampoco puede leer productos_publicos. Esto prueba que
-- el REVOKE de 0004_revoke_authenticated_productos_publicos.sql funcionó --
-- sin él, "authenticated" heredaría GRANT automático por
-- ALTER DEFAULT PRIVILEGES (ver 0002) y, como la vista es dueña de
-- "postgres" (bypasea RLS), vería productos de TODAS las tiendas a través
-- de ella. Reemplazá el UUID por un usuario autenticado real si querés
-- probarlo con sesión real; alcanza con simular el rol para este chequeo.
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;

  -- Esperado: ERROR - permission denied for table productos_publicos
  select * from productos_publicos
  where tienda_id = '99999999-9999-9999-9999-999999999999';
rollback;

-- ----------------------------------------------------------------------------
-- Paso 4: confirmar que "authenticated" sigue viendo la tabla productos
-- completa (con costo y porcentaje_ganancia), sin cambios respecto a antes
-- de esta migración. Reemplazá el sub por un usuario autenticado real de
-- una tienda con productos cargados para un chequeo end-to-end completo;
-- este bloque solo prueba el GRANT de tabla (no depende de mi_tienda_id()).
-- ----------------------------------------------------------------------------
begin;
  set local role authenticated;

  -- Esperado: no falla por permisos (puede devolver 0 filas si la tienda
  -- del usuario simulado no tiene productos -- lo que importa acá es que
  -- no tire "permission denied", y que costo/porcentaje_ganancia estén
  -- presentes en las columnas devueltas).
  select id, tienda_id, nombre, costo, porcentaje_ganancia, precio_final
  from productos
  limit 1;
rollback;

-- ----------------------------------------------------------------------------
-- Paso 5 (limpieza): borrar los datos de prueba del Paso 0. Corre como
-- postgres (sin sesión simulada).
-- ----------------------------------------------------------------------------
begin;

delete from productos where tienda_id = '99999999-9999-9999-9999-999999999999';
delete from tiendas where id = '99999999-9999-9999-9999-999999999999';

commit;

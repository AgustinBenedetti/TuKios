-- Custom SQL migration file, put your code below! --

-- ============================================================================
-- Vista productos_publicos: acceso de solo lectura para el catálogo público
-- (rol anon, sin login), exponiendo únicamente columnas no sensibles de
-- "productos". Explícitamente NUNCA expone "costo" ni "porcentaje_ganancia"
-- (esas dos columnas son la razón de ser de esta vista: son la estrategia de
-- precios del dueño, no algo que un visitante del catálogo deba poder ver).
--
-- Sobre "codigo_barras": se decide incluirlo. Es un identificador asignado
-- por el fabricante (EAN/UPC) impreso en el empaque físico del producto —
-- cualquiera que tenga el producto en la mano ya lo puede leer. No revela
-- nada de la operación interna de la tienda (a diferencia de costo/margen),
-- así que no hay razón de seguridad para ocultarlo, y puede ser útil a
-- futuro (buscar por código, integraciones). Si más adelante surge un caso
-- de uso donde sí convenga ocultarlo, se saca de acá sin tocar el resto.
--
-- Sobre el filtrado por tienda: esta vista NO filtra por tienda_id. El
-- catálogo público de cada subdominio es responsabilidad de la capa de
-- aplicación, que arma la query con "WHERE tienda_id = <tienda resuelta por
-- el proxy>" -- igual que cualquier catálogo público, el listado de
-- productos de una tienda no es un secreto que haya que ocultarle a otras
-- tiendas (a diferencia de costo/ganancia, que sí lo es). Ver el comentario
-- sobre GRANT más abajo para el análisis de por qué esto no compromete el
-- aislamiento de RLS que ya existe para "authenticated".
-- ============================================================================

CREATE VIEW productos_publicos AS
SELECT
  id,
  tienda_id,
  categoria_id,
  nombre,
  foto_url,
  precio_final,
  disponible,
  codigo_barras
FROM productos;
--> statement-breakpoint

-- ============================================================================
-- GRANT: solo "anon" puede leer esta vista. A propósito, NO se le otorga
-- nada a "authenticated" acá (ver investigación sobre RLS + vistas abajo).
-- ============================================================================

GRANT SELECT ON TABLE productos_publicos TO anon;
--> statement-breakpoint

-- ============================================================================
-- Investigación: ¿las vistas heredan las policies de RLS de la tabla base?
--
-- Corta: NO automáticamente, y el mecanismo real es distinto al que uno
-- esperaría. Verificado contra esta base (Postgres 17.6, Supabase) con
-- queries a pg_roles / pg_class / information_schema antes de escribir esto:
--
-- 1. Una vista, por default, accede a sus tablas de base con los privilegios
--    de su DUEÑO, no de quien la consulta (esto es anterior a RLS: así
--    funcionan los permisos de vistas en Postgres desde siempre, similar a
--    una función SECURITY DEFINER). RLS se apoya en ese mismo mecanismo: la
--    policy se evalúa usando la identidad del dueño de la vista, no la de
--    quien hizo la query -- salvo que la vista tenga la opción
--    "security_invoker = true" (Postgres 15+), que fuerza a usar los
--    privilegios y las policies de RLS de quien invoca en vez de las del
--    dueño.
--
-- 2. En esta base, TODAS las tablas (incluida "productos") son dueño de
--    "postgres" -- el rol con el que corren las migraciones de Drizzle.
--    Confirmado con:
--      select relname, relowner::regrole::text from pg_class
--      where relname = 'productos';  -- devuelve "postgres"
--
-- 3. Y "postgres" tiene el atributo BYPASSRLS = true. Confirmado con:
--      select rolname, rolbypassrls from pg_roles
--      where rolname in ('postgres','anon','authenticated','service_role');
--    -- postgres = true, service_role = true, anon = false,
--    -- authenticated = false.
--
-- Conclusión de 1+2+3: una vista nueva creada por esta migración queda
-- dueña de "postgres", que bypasea RLS por completo. Eso significa que
-- CUALQUIER rol que tenga permiso para consultar productos_publicos vería
-- TODAS las filas de "productos" (de todas las tiendas) al pasar por la
-- vista, sin que la policy "productos_select_propia_tienda" (que depende de
-- mi_tienda_id()) se evalúe -- ni siquiera para un usuario autenticado.
--
-- Esto es exactamente el riesgo que preguntaste: si le diéramos GRANT
-- SELECT sobre esta vista a "authenticated", esa policy quedaría
-- efectivamente salteada y cualquier usuario autenticado de cualquier
-- tienda vería (los campos no sensibles de) los productos de TODAS las
-- tiendas a través de la vista -- rompiendo el aislamiento que
-- 0001_rls_policies_aislamiento_tienda.sql construyó para la tabla.
--
-- Por qué NO usamos "security_invoker = true" para arreglar esto:
-- esa opción hace que la vista use los privilegios y las policies de RLS
-- de quien la invoca en vez de los del dueño -- pero eso exige que ese rol
-- tenga GRANT directo sobre la tabla de base "productos" (no alcanza con
-- el GRANT sobre la vista), y que exista una policy de RLS que le permita
-- ver filas. "anon" no tiene (ni debería tener) ningún GRANT sobre
-- "productos", así que con security_invoker=true la vista le devolvería
-- 0 filas siempre (RLS deniega por default sin policy aplicable) o, si le
-- diéramos GRANT column-level sobre "productos" para que funcione, "anon"
-- pasaría a poder leer la tabla base directamente -- justo lo que el punto
-- 4 de la verificación pide confirmar que NO puede pasar.
--
-- La solución elegida es más simple y ataca la causa real: en vez de
-- intentar que la vista "herede" RLS, cerramos la puerta a nivel de GRANT.
-- "authenticated" nunca recibe GRANT sobre productos_publicos (arriba solo
-- se le da a "anon"), así que no tiene ningún camino legal para consultar
-- esta vista -- el bypass de RLS del dueño de la vista es irrelevante si
-- "authenticated" ni siquiera puede ejecutar el SELECT. El acceso completo
-- de "authenticated" a la tabla "productos" (con costo y
-- porcentaje_ganancia, filtrado por su propia tienda vía RLS) sigue
-- exactamente igual que antes de esta migración -- no se tocó ningún
-- GRANT ni policy de la tabla.
--
-- Nota para el futuro: si algún día hace falta que "authenticated" también
-- consulte productos_publicos, NO alcanza con agregar el GRANT -- hay que
-- volver a este análisis, porque el bypass de RLS seguiría aplicando. La
-- forma correcta en ese momento sería usar security_invoker=true en la
-- vista + GRANT column-level sobre "productos" a "authenticated" (que ya
-- tiene, ver 0002_grants_authenticated.sql) + confiar en que la policy
-- "productos_select_propia_tienda" ya filtra por tienda_id -- ahora sí
-- evaluada como el usuario real, no como "postgres".
-- ============================================================================

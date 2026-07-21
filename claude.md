# TuKios — Brief del proyecto para Claude Code

SaaS multi-tenant de gestión para kioscos/almacenes/minimarkets argentinos. Cada local tiene catálogo público + checkout propio, y un panel de gestión de stock/ventas.

## Stack

- Next.js (App Router) + TypeScript, un solo proyecto (público + panel + API routes)
- Tailwind CSS
- Drizzle ORM + Postgres (Supabase)
- Supabase Auth (dueño/empleados) + Supabase Storage (imágenes)
- Mercado Pago (Checkout Pro)
- Hosting: Netlify + Supabase (planes gratuitos, ambos permiten uso comercial)

## Arquitectura multi-tenant

- Cada tienda vive en `sulocal.tukios.com`. Proxy de Next.js (`proxy.ts`, función `proxy` — reemplaza a `middleware.ts`, deprecado desde Next.js 16) lee el header `Host`, extrae el subdominio, resuelve la tienda y sirve su catálogo.
- Panel de gestión en subdominio fijo separado: `panel.tukios.com`.
- Landing institucional del software en `tukios.com` (raíz).
- **Regla de oro:** casi toda query está filtrada por `tienda_id`. RLS en Postgres en cada tabla (no confiar solo en validación de la app). `tienda_id` siempre como primera columna en índices compuestos.
- Vista `productos_publicos` para el catálogo público: nunca expone `costo` ni `porcentaje_ganancia`.
- **Cualquier vista nueva del proyecto necesita revisar sus grants explícitamente después de crearla**, con una query contra `information_schema.role_table_grants` (filtrando por esa vista). El `ALTER DEFAULT PRIVILEGES` de `drizzle/0002_grants_authenticated.sql` le otorga SELECT/INSERT/UPDATE a `authenticated` automáticamente sobre cualquier tabla o vista nueva que cree el rol `postgres` en `public` — no asumir que una vista queda protegida solo porque no se le dio ningún GRANT explícito. Si la vista no debe ser visible para `authenticated` (por ejemplo porque, como `productos_publicos`, oculta columnas sensibles de la tabla base y además su dueño bypasea RLS), hace falta un `REVOKE` dirigido después de crearla — ver `drizzle/0004_revoke_authenticated_productos_publicos.sql` para el caso real que disparó esto.

### Estado de implementación

- **RLS (Row Level Security):** implementado y verificado — función `mi_tienda_id()` (SECURITY DEFINER) + policies de SELECT/INSERT/UPDATE (sin DELETE) por `tienda_id` en las 6 tablas, más los GRANT correspondientes al rol `authenticated`. Ver `drizzle/0001_rls_policies_aislamiento_tienda.sql` y `drizzle/0002_grants_authenticated.sql`.
  - ✅ **Resuelto** (antes prioritario, [issue #2](https://github.com/AgustinBenedetti/TuKios/issues/2) — "Empleado puede auto-asignarse el rol de dueño"): la policy de UPDATE en `usuarios` ya distingue dueño/empleado. Cualquier usuario puede editar su propia fila excepto el campo `rol`; solo un usuario con `rol = 'dueño'` puede editar filas ajenas de su tienda (incluido el `rol` de otros). Función auxiliar `mi_rol()` (mismo patrón SECURITY DEFINER que `mi_tienda_id()`). Ver `drizzle/0006_policy_update_usuarios_restringe_rol.sql` (incluye el análisis de por qué se resolvió con una sola policy en vez de varias) y `sql/verificacion_policy_update_usuarios.sql` para probarlo a mano.
  - Pendiente, no bloqueante: la creación de la `tienda` en sí (fila en `tiendas`) sigue sin policy de INSERT — no hay ninguna definida a propósito (ver 0001), así que ese paso del onboarding todavía necesita `service_role`. Lo que sí queda resuelto es la fila de `usuarios`: el trigger de sincronización (ver abajo) la crea automáticamente al hacer signup, sin pasar por la policy de INSERT de `usuarios` ni necesitar `service_role` para ese paso puntual.
- **Trigger de sincronización `auth.users` → `usuarios`:** implementado — función `handle_new_auth_user()` (SECURITY DEFINER) + trigger `on_auth_user_created` (`AFTER INSERT ON auth.users`). Al hacer signup, crea automáticamente la fila correspondiente en `usuarios`, leyendo `tienda_id`, `nombre` y `rol` desde `raw_user_meta_data` (el `options.data` que se pasa a `supabase.auth.signUp()`). Si falta alguno de esos tres campos en el metadata, el trigger rechaza el INSERT completo (revierte también la fila de `auth.users`, misma transacción) — no permite usuarios huérfanos. El flujo de onboarding (feature aparte, todavía sin construir) es responsable de mandar ese metadata correcto al llamar `signUp()`. Ver `drizzle/0005_trigger_sync_auth_users.sql`.
- **Vista `productos_publicos`:** implementada — expone `id, tienda_id, categoria_id, nombre, foto_url, precio_final, disponible, codigo_barras` de `productos`, sin `costo` ni `porcentaje_ganancia`. Solo `anon` tiene GRANT SELECT sobre ella; `authenticated` no tiene ningún privilegio ahí (sigue usando la tabla `productos` completa, sin cambios). Ver `drizzle/0003_vista_productos_publicos.sql` y `drizzle/0004_revoke_authenticated_productos_publicos.sql` para el detalle y el porqué (vistas + RLS + bypass del dueño son un caso no obvio, vale la pena leer los comentarios antes de tocar esto). No filtra por `tienda_id`: eso queda para la query de la app (páginas del catálogo público, feature aparte, todavía no implementado).

## Modelo de datos (resumen — ver documento completo para detalle de tipos/índices)

- **tiendas**: subdominio (unique), nombre, logo_url, whatsapp, ubicacion, redes_sociales (jsonb), horario_atencion (jsonb), horario_delivery (jsonb, independiente del anterior), plan, activo
- **usuarios**: tienda_id, nombre, email, rol (`dueño` | `empleado`)
- **categorias**: tienda_id, nombre
- **productos**: tienda_id, categoria_id, nombre, foto_url, codigo_barras (unique compuesto con tienda_id), costo, porcentaje_ganancia, precio_final (auto-calculado, editable a mano recalculando el % hacia atrás), stock, disponible
- **ventas**: tienda_id, usuario_id (nullable), origen (`mostrador`|`online`), metodo_pago (`digital`|`efectivo`), metodo_entrega (`retiro`|`delivery`), cliente_nombre, cliente_apellido, cliente_telefono (obligatorios en ventas online, no en mostrador), cliente_calle/numero/barrio (solo si delivery), total, estado, creado_en
- **venta_items**: venta_id, producto_id, cantidad, precio_unitario (copiado al momento de la venta, no referenciado — es un registro histórico)

## Reglas de negocio clave

- Precio final = costo + costo×%ganancia. Si se edita el precio a mano, se recalcula el % hacia atrás. Sincronizados siempre entre sí.
- Checkout bloqueado fuera del horario de atención del local.
- Delivery puede tener su propio horario, más acotado que el del local.
- Costo/zona de envío no se gestiona en la app: se coordina por WhatsApp con el teléfono cargado en la compra.
- Sin seguimiento de estado de pedido en tiempo real en el MVP.
- Empleado puede: cargar stock, vender (caja básica), marcar pedidos online como completados, ver historial de ventas (sin reportes). Empleado NO puede: tocar precios/costos, ver reportes, cambiar configuración.
- Notificación de pedido nuevo: dashboard en tiempo real (Supabase Realtime) + email. WhatsApp pospuesto a v1.1 (Meta cobra por mensaje utility desde jul. 2025, no es $0).
- **Pendiente:** las columnas `cliente_nombre`, `cliente_apellido`, `cliente_telefono` (obligatorias en ventas online, no en mostrador) y `cliente_calle`, `cliente_numero`, `cliente_barrio` (obligatorias solo si `metodo_entrega` es `'delivery'`) hoy son nullable en el schema sin ningún enforcement — la base de datos permite cualquier combinación. Falta decidir, cuando se construya la lógica de ventas, si esto se garantiza con un CHECK constraint en Postgres o con validación en la capa de aplicación, y luego implementarlo.

## Alcance del MVP

Incluye: un local por cuenta, catálogo + checkout completo, carga de productos manual + escaneo de código de barras (NO importación masiva todavía), ventas de mostrador y online sobre el mismo stock, roles dueño/empleado, reportes básicos (ventas por período, más vendidos, stock bajo).

Explícitamente fuera del MVP: multi-sucursal, reportes de ganancia/margen, WhatsApp automatizado, zonas de delivery configurables, importación masiva, caja fiscal.

## Cómo trabajar conmigo en este proyecto

Agustín está aprendiendo mientras construye esto. Explicá el porqué de cada decisión técnica antes o junto con la implementación (patrones, trade-offs, qué revisar). El objetivo es que pueda supervisar y entender el código con criterio, no que lo escriba él.
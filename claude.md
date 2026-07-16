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

### Estado de implementación

Las siguientes reglas están **documentadas** como decisión de arquitectura pero **aún no implementadas** (son lógica de seguridad/negocio, fuera del alcance del scaffolding inicial):

- **RLS (Row Level Security):** no hay ninguna policy creada todavía en ninguna tabla.
- **Vista `productos_publicos`:** no existe todavía. El catálogo público sigue sin tener una forma de leer productos sin exponer `costo` y `porcentaje_ganancia`.

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
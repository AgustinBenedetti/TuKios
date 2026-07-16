import {
  pgTable,
  uuid,
  text,
  boolean,
  timestamp,
  jsonb,
  numeric,
  integer,
  uniqueIndex,
  index,
} from "drizzle-orm/pg-core";

export const tiendas = pgTable("tiendas", {
  id: uuid("id").primaryKey().defaultRandom(),
  nombre: text("nombre").notNull(),
  subdominio: text("subdominio").notNull().unique(),
  logoUrl: text("logo_url"),
  whatsapp: text("whatsapp"),
  ubicacion: text("ubicacion"),
  redesSociales: jsonb("redes_sociales"),
  horarioAtencion: jsonb("horario_atencion"),
  horarioDelivery: jsonb("horario_delivery"),
  plan: text("plan"),
  activo: boolean("activo").notNull().default(true),
  creadoEn: timestamp("creado_en", { withTimezone: true }).notNull().defaultNow(),
});

export const usuarios = pgTable(
  "usuarios",
  {
    // mismo id que auth.users de Supabase, no autogenerado acá
    id: uuid("id").primaryKey(),
    tiendaId: uuid("tienda_id")
      .notNull()
      .references(() => tiendas.id),
    nombre: text("nombre").notNull(),
    email: text("email").notNull().unique(),
    rol: text("rol", { enum: ["dueño", "empleado"] }).notNull(),
  },
  (table) => [index("usuarios_tienda_id_idx").on(table.tiendaId)]
);

export const categorias = pgTable(
  "categorias",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tiendaId: uuid("tienda_id")
      .notNull()
      .references(() => tiendas.id),
    nombre: text("nombre").notNull(),
  },
  (table) => [index("categorias_tienda_id_idx").on(table.tiendaId)]
);

export const productos = pgTable(
  "productos",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tiendaId: uuid("tienda_id")
      .notNull()
      .references(() => tiendas.id),
    categoriaId: uuid("categoria_id").references(() => categorias.id),
    nombre: text("nombre").notNull(),
    fotoUrl: text("foto_url"),
    codigoBarras: text("codigo_barras"),
    costo: numeric("costo", { precision: 10, scale: 2 }).notNull(),
    porcentajeGanancia: numeric("porcentaje_ganancia", {
      precision: 5,
      scale: 2,
    }).notNull(),
    precioFinal: numeric("precio_final", { precision: 10, scale: 2 }).notNull(),
    stock: integer("stock").notNull().default(0),
    disponible: boolean("disponible").notNull().default(true),
  },
  (table) => [
    index("productos_tienda_disponible_idx").on(table.tiendaId, table.disponible),
    index("productos_tienda_categoria_idx").on(table.tiendaId, table.categoriaId),
    uniqueIndex("productos_tienda_codigo_barras_idx").on(
      table.tiendaId,
      table.codigoBarras
    ),
  ]
);

export const ventas = pgTable(
  "ventas",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tiendaId: uuid("tienda_id")
      .notNull()
      .references(() => tiendas.id),
    usuarioId: uuid("usuario_id").references(() => usuarios.id),
    origen: text("origen", { enum: ["mostrador", "online"] }).notNull(),
    metodoPago: text("metodo_pago", { enum: ["digital", "efectivo"] }).notNull(),
    metodoEntrega: text("metodo_entrega", {
      enum: ["retiro", "delivery"],
    }).notNull(),
    clienteNombre: text("cliente_nombre"),
    clienteApellido: text("cliente_apellido"),
    clienteTelefono: text("cliente_telefono"),
    clienteCalle: text("cliente_calle"),
    clienteNumero: text("cliente_numero"),
    clienteBarrio: text("cliente_barrio"),
    total: numeric("total", { precision: 10, scale: 2 }).notNull(),
    estado: text("estado").notNull(),
    creadoEn: timestamp("creado_en", { withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    index("ventas_tienda_creado_en_idx").on(table.tiendaId, table.creadoEn.desc()),
  ]
);

export const ventaItems = pgTable(
  "venta_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    ventaId: uuid("venta_id")
      .notNull()
      .references(() => ventas.id),
    productoId: uuid("producto_id")
      .notNull()
      .references(() => productos.id),
    cantidad: integer("cantidad").notNull(),
    precioUnitario: numeric("precio_unitario", {
      precision: 10,
      scale: 2,
    }).notNull(),
  },
  (table) => [index("venta_items_venta_id_idx").on(table.ventaId)]
);

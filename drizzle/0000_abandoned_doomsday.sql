CREATE TABLE "categorias" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tienda_id" uuid NOT NULL,
	"nombre" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "productos" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tienda_id" uuid NOT NULL,
	"categoria_id" uuid,
	"nombre" text NOT NULL,
	"foto_url" text,
	"codigo_barras" text,
	"costo" numeric(10, 2) NOT NULL,
	"porcentaje_ganancia" numeric(5, 2) NOT NULL,
	"precio_final" numeric(10, 2) NOT NULL,
	"stock" integer DEFAULT 0 NOT NULL,
	"disponible" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "tiendas" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"nombre" text NOT NULL,
	"subdominio" text NOT NULL,
	"logo_url" text,
	"whatsapp" text,
	"ubicacion" text,
	"redes_sociales" jsonb,
	"horario_atencion" jsonb,
	"horario_delivery" jsonb,
	"plan" text,
	"activo" boolean DEFAULT true NOT NULL,
	"creado_en" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "tiendas_subdominio_unique" UNIQUE("subdominio")
);
--> statement-breakpoint
CREATE TABLE "usuarios" (
	"id" uuid PRIMARY KEY NOT NULL,
	"tienda_id" uuid NOT NULL,
	"nombre" text NOT NULL,
	"email" text NOT NULL,
	"rol" text NOT NULL,
	CONSTRAINT "usuarios_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "venta_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"venta_id" uuid NOT NULL,
	"producto_id" uuid NOT NULL,
	"cantidad" integer NOT NULL,
	"precio_unitario" numeric(10, 2) NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ventas" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tienda_id" uuid NOT NULL,
	"usuario_id" uuid,
	"origen" text NOT NULL,
	"metodo_pago" text NOT NULL,
	"metodo_entrega" text NOT NULL,
	"cliente_nombre" text,
	"cliente_apellido" text,
	"cliente_telefono" text,
	"cliente_calle" text,
	"cliente_numero" text,
	"cliente_barrio" text,
	"total" numeric(10, 2) NOT NULL,
	"estado" text NOT NULL,
	"creado_en" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "categorias" ADD CONSTRAINT "categorias_tienda_id_tiendas_id_fk" FOREIGN KEY ("tienda_id") REFERENCES "public"."tiendas"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "productos" ADD CONSTRAINT "productos_tienda_id_tiendas_id_fk" FOREIGN KEY ("tienda_id") REFERENCES "public"."tiendas"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "productos" ADD CONSTRAINT "productos_categoria_id_categorias_id_fk" FOREIGN KEY ("categoria_id") REFERENCES "public"."categorias"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "usuarios" ADD CONSTRAINT "usuarios_tienda_id_tiendas_id_fk" FOREIGN KEY ("tienda_id") REFERENCES "public"."tiendas"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venta_items" ADD CONSTRAINT "venta_items_venta_id_ventas_id_fk" FOREIGN KEY ("venta_id") REFERENCES "public"."ventas"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "venta_items" ADD CONSTRAINT "venta_items_producto_id_productos_id_fk" FOREIGN KEY ("producto_id") REFERENCES "public"."productos"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ventas" ADD CONSTRAINT "ventas_tienda_id_tiendas_id_fk" FOREIGN KEY ("tienda_id") REFERENCES "public"."tiendas"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ventas" ADD CONSTRAINT "ventas_usuario_id_usuarios_id_fk" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "categorias_tienda_id_idx" ON "categorias" USING btree ("tienda_id");--> statement-breakpoint
CREATE INDEX "productos_tienda_disponible_idx" ON "productos" USING btree ("tienda_id","disponible");--> statement-breakpoint
CREATE INDEX "productos_tienda_categoria_idx" ON "productos" USING btree ("tienda_id","categoria_id");--> statement-breakpoint
CREATE UNIQUE INDEX "productos_tienda_codigo_barras_idx" ON "productos" USING btree ("tienda_id","codigo_barras");--> statement-breakpoint
CREATE INDEX "usuarios_tienda_id_idx" ON "usuarios" USING btree ("tienda_id");--> statement-breakpoint
CREATE INDEX "venta_items_venta_id_idx" ON "venta_items" USING btree ("venta_id");--> statement-breakpoint
CREATE INDEX "ventas_tienda_creado_en_idx" ON "ventas" USING btree ("tienda_id","creado_en" DESC NULLS LAST);
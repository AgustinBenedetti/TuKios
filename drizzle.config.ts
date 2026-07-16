import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    // Conexión directa (no pooled) — drizzle-kit necesita esta para migraciones.
    url: process.env.DATABASE_URL!,
  },
});

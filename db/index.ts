import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema";

// Conexión pooled vía PgBouncer (puerto 6543) — la que usa la app en runtime.
// prepare: false porque PgBouncer en modo transaction pooling no soporta
// prepared statements.
const client = postgres(process.env.DATABASE_URL_POOLED!, { prepare: false });

export const db = drizzle(client, { schema });

import "server-only";
import { createClient } from "@supabase/supabase-js";

// Cliente de Supabase con la service_role key -- bypasea RLS y tiene acceso
// al Admin API de Auth (auth.admin.*). Por eso el import de "server-only"
// arriba: si algún día alguien importa este módulo desde un componente
// cliente por error, el build de Next falla en vez de terminar mandando la
// service_role key al navegador.
//
// Se crea un cliente nuevo por llamada en vez de un singleton a nivel de
// módulo: evita que un import accidental en el momento equivocado (build,
// lint) reviente por falta de variables de entorno, y el costo de crear el
// cliente es despreciable para el volumen de uso de este flujo (altas
// manuales de tienda, no una ruta de alto tráfico).
export function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error(
      "Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en el entorno."
    );
  }

  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

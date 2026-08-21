import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { leerEnvSupabase } from "@/lib/supabase/env";

// Cliente de Supabase para Server Components, Server Actions y Route
// Handlers -- lee/escribe la sesión vía cookies (paquete oficial @supabase/ssr,
// que reemplazó a los viejos "auth-helpers"; ver lib/supabase/proxy.ts para
// la contraparte que corre en proxy.ts).
//
// Un detalle no obvio: Server Components no pueden escribir cookies (Next.js
// lo bloquea), así que el `setAll` de más abajo puede tirar. Está bien que
// eso se ignore silenciosamente ACÁ porque proxy.ts ya se encarga de refrescar
// y reescribir la cookie de sesión en cada request antes de que el Server
// Component se renderice -- si no hubiera proxy.ts haciendo eso, este catch
// escondería sesiones vencidas sin avisar.
export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  const { url, anonKey } = leerEnvSupabase();

  return createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        } catch {
          // Llamado desde un Server Component sin capacidad de escribir
          // cookies -- ver comentario arriba.
        }
      },
    },
  });
}

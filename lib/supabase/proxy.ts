import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { leerEnvSupabase } from "@/lib/supabase/env";

export type SesionPanel = {
  usuarioId: string;
  nombre: string;
  debeCambiarPassword: boolean;
};

export type LecturaSesionPanel = {
  sesion: SesionPanel | null;
  // Respuesta "portadora" de las cookies de sesión ya refrescadas (si
  // getClaims() renovó el access token). Quien llame a esta función tiene
  // que copiar estas cookies a la respuesta final que efectivamente
  // devuelva (rewrite o redirect) -- si no, browser y server quedan
  // desincronizados sobre qué token es el vigente.
  cookiesActualizadas: NextResponse;
};

// Contraparte de lib/supabase/server.ts para usar dentro de proxy.ts, que no
// tiene acceso a next/headers `cookies()` -- acá se trabaja directo con las
// cookies del NextRequest/NextResponse. Mismo paquete (@supabase/ssr), mismo
// patrón getAll/setAll que recomienda la documentación oficial de Supabase.
//
// Se usa getClaims() en vez de getSession() a propósito: getSession() decodifica
// el JWT de la cookie sin verificarlo, así que un token adulterado o vencido
// podría pasar. getClaims() valida la firma (localmente, contra el JWKS
// cacheado del proyecto) y de paso refresca el access token si está por
// vencer -- por eso puede haber cookies nuevas para propagar.
export async function leerSesionPanel(
  request: NextRequest
): Promise<LecturaSesionPanel> {
  let cookiesActualizadas = NextResponse.next({ request });
  const { url, anonKey } = leerEnvSupabase();

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        // Se actualiza el request en curso (para que el resto de este
        // request -- el rewrite hacia el Server Component -- ya vea la
        // cookie nueva) y se reconstruye la respuesta portadora con esas
        // mismas cookies para propagarlas de vuelta al browser.
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value)
        );
        cookiesActualizadas = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          cookiesActualizadas.cookies.set(name, value, options)
        );
      },
    },
  });

  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims) {
    return { sesion: null, cookiesActualizadas };
  }

  const claims = data.claims;
  const userMetadata = (claims.user_metadata ?? {}) as Record<string, unknown>;

  return {
    sesion: {
      usuarioId: claims.sub,
      nombre:
        typeof userMetadata.nombre === "string" ? userMetadata.nombre : "",
      debeCambiarPassword: userMetadata.debe_cambiar_password === true,
    },
    cookiesActualizadas,
  };
}

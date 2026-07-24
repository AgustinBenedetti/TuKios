import "server-only";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export type SesionUsuarioPanel = {
  usuarioId: string;
  email: string;
  nombre: string;
  debeCambiarPassword: boolean;
};

async function obtenerSesionActual(): Promise<SesionUsuarioPanel | null> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims) return null;

  const claims = data.claims;
  const userMetadata = (claims.user_metadata ?? {}) as Record<string, unknown>;

  return {
    usuarioId: claims.sub,
    email: typeof claims.email === "string" ? claims.email : "",
    nombre: typeof userMetadata.nombre === "string" ? userMetadata.nombre : "",
    debeCambiarPassword: userMetadata.debe_cambiar_password === true,
  };
}

// Chequeo autoritativo para cualquier página o Server Action del panel que
// requiera sesión activa Y contraseña ya cambiada (todo excepto /login y
// /cambiar-password). proxy.ts ya resuelve esto de forma optimista (sin
// tocar la base) en la enorme mayoría de los casos, pero no hay que
// depender solo de eso -- incluso la doc oficial de Next.js sobre Proxy lo
// advierte: un cambio futuro en el matcher podría dejar de cubrir una ruta
// sin que sea obvio (mismo problema ya documentado para el admin, ver
// lib/admin-auth.ts). Tampoco alcanza con un layout compartido: React no
// re-ejecuta un layout ya montado en navegaciones client-side entre rutas
// que lo comparten, así que un chequeo puesto ahí puede no correr en cada
// cambio de página. Por eso cada página protegida llama a esto
// explícitamente -- mismo patrón que "todo query filtra por tienda_id" en
// el resto del proyecto: la regla se aplica en el punto de uso, no se
// asume heredada de un padre.
export async function requerirSesionPanel(): Promise<SesionUsuarioPanel> {
  const sesion = await obtenerSesionActual();
  if (!sesion) redirect("/login");
  if (sesion.debeCambiarPassword) redirect("/cambiar-password");
  return sesion;
}

// Para la página de cambio de contraseña: exige sesión activa, pero -- a
// diferencia de requerirSesionPanel() -- no exige debeCambiarPassword en
// false, porque esta es justamente la página que lo pone en false. Si ya
// está en false no hace falta pasar por acá, así que se manda al panel.
export async function requerirSesionParaCambiarPassword(): Promise<SesionUsuarioPanel> {
  const sesion = await obtenerSesionActual();
  if (!sesion) redirect("/login");
  if (!sesion.debeCambiarPassword) redirect("/");
  return sesion;
}

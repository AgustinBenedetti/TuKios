"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requerirSesionParaCambiarPassword } from "@/lib/panel-auth";

export type EstadoCambiarPassword =
  | { status: "idle" }
  | { status: "error"; mensaje: string }
  | { status: "ok"; destino: string };

const LARGO_MINIMO = 8;

export async function cambiarPassword(
  _estadoPrevio: EstadoCambiarPassword,
  formData: FormData
): Promise<EstadoCambiarPassword> {
  // Chequeo autoritativo, no solo el de proxy.ts -- ver lib/panel-auth.ts.
  // Si no hay sesión o ya no hace falta cambiar la contraseña, esto redirige
  // y no vuelve acá.
  await requerirSesionParaCambiarPassword();

  const nuevaPassword = String(formData.get("nuevaPassword") ?? "");
  const confirmacion = String(formData.get("confirmacion") ?? "");

  if (nuevaPassword.length < LARGO_MINIMO) {
    return {
      status: "error",
      mensaje: `La contraseña tiene que tener al menos ${LARGO_MINIMO} caracteres.`,
    };
  }
  if (nuevaPassword !== confirmacion) {
    return { status: "error", mensaje: "Las contraseñas no coinciden." };
  }

  const supabase = await createSupabaseServerClient();

  // Una sola llamada: cambia la contraseña y apaga el flag en el mismo
  // request. `data` hace merge con el user_metadata existente (no lo
  // reemplaza), así que tienda_id/nombre/rol cargados en el onboarding
  // quedan intactos.
  const { error } = await supabase.auth.updateUser({
    password: nuevaPassword,
    data: { debe_cambiar_password: false },
  });

  if (error) {
    return {
      status: "error",
      mensaje: `No se pudo cambiar la contraseña: ${error.message}`,
    };
  }

  // Detalle no obvio: updateUser() cambia la contraseña y el metadata en el
  // servidor de Auth, pero el access token (JWT) ya emitido para esta
  // sesión sigue siendo el viejo -- sus claims (incluido user_metadata,
  // de donde proxy.ts y requerirSesionPanel() leen debe_cambiar_password)
  // quedan fijados en el momento en que se firmó, no se actualizan solos.
  // Sin este refresh explícito, el usuario queda en loop: cada request
  // siguiente sigue viendo debe_cambiar_password=true en el JWT viejo y lo
  // manda de vuelta acá, aunque en la base ya esté en false. refreshSession()
  // fuerza a pedir un token nuevo (ya con el metadata actualizado) y lo
  // persiste en la cookie a través del storage adapter de @supabase/ssr.
  const { error: errorRefresh } = await supabase.auth.refreshSession();
  if (errorRefresh) {
    return {
      status: "error",
      mensaje: `La contraseña se cambió pero no se pudo refrescar la sesión: ${errorRefresh.message}. Volvé a intentar ingresar.`,
    };
  }

  // No usamos redirect() de Next.js acá a propósito. redirect() en un
  // server action dispara una transición client-side (soft navigation)
  // manejada por el router de React -- y ese router no tiene ninguna noción
  // del rewrite por hostname que hace proxy.ts (panel.tukios.com/ -> /panel
  // internamente). revalidatePath("/panel") tampoco alcanza: la propia doc
  // de Next.js aclara que la re-renderización automática al escribir una
  // cookie, y el "Updates the UI immediately", aplican a la página que
  // ESTÁS viendo (acá, /cambiar-password), no al destino del redirect --
  // confirmado con un bug real reproducido en el navegador (no solo
  // teórico). La única vía confiable es una recarga dura del navegador
  // (window.location.href, en el Client Component que llama a esta action),
  // que siempre vuelve a pasar por proxy.ts desde cero -- exactamente lo que
  // ya hace un F5 manual, pero automático. Esto es aceptable acá porque son
  // transiciones de auth (login/cambio de password/logout), no un hot path
  // de UX: priorizamos correctitud sobre velocidad.
  return { status: "ok", destino: "/" };
}

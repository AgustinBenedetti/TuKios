"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

export type EstadoLogout =
  | { status: "ok"; destino: string }
  | { status: "error"; mensaje: string };

export async function logout(): Promise<EstadoLogout> {
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.signOut();

  if (error) {
    return {
      status: "error",
      mensaje: `No se pudo cerrar la sesión: ${error.message}`,
    };
  }

  // Recarga dura en el Client Component que llama a esto, no redirect() --
  // ver el comentario largo en cambiar-password/actions.ts para el porqué.
  return { status: "ok", destino: "/login" };
}

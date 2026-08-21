"use server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

export type EstadoLogin =
  | { status: "idle" }
  | { status: "error"; mensaje: string }
  | { status: "ok"; destino: string };

export async function login(
  _estadoPrevio: EstadoLogin,
  formData: FormData
): Promise<EstadoLogin> {
  const email = String(formData.get("email") ?? "")
    .trim()
    .toLowerCase();
  const password = String(formData.get("password") ?? "");

  if (!email || !password) {
    return { status: "error", mensaje: "Completá email y contraseña." };
  }

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error || !data.user) {
    return { status: "error", mensaje: "Email o contraseña incorrectos." };
  }

  const debeCambiarPassword =
    data.user.user_metadata?.debe_cambiar_password === true;

  // Recarga dura en el Client Component en vez de redirect() acá -- ver el
  // comentario largo en cambiar-password/actions.ts para el porqué (el
  // router client-side no sabe del rewrite por hostname de proxy.ts, y ni
  // redirect() ni revalidatePath() garantizan datos frescos en el destino).
  return {
    status: "ok",
    destino: debeCambiarPassword ? "/cambiar-password" : "/",
  };
}

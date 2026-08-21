"use server";

import { randomBytes } from "node:crypto";
import { headers } from "next/headers";
import { verificarBasicAuth } from "@/lib/admin-auth";
import { supabaseAdmin } from "@/lib/supabase-admin";

export type EstadoAltaTienda =
  | { status: "idle" }
  | { status: "error"; mensaje: string }
  | {
      status: "ok";
      tiendaId: string;
      nombreTienda: string;
      subdominio: string;
      emailDueno: string;
      passwordGenerada: string;
    };

const SUBDOMINIO_REGEX = /^[a-z0-9]+(-[a-z0-9]+)*$/;

function generarPassword(): string {
  // 15 bytes de entropía random en base64url -> 20 caracteres, sin
  // caracteres ambiguos entre mayúscula/minúscula/símbolo que compliquen
  // pasarla de forma manual al cliente (WhatsApp, en persona, etc).
  return randomBytes(15).toString("base64url");
}

export async function crearTiendaYDueno(
  _estadoPrevio: EstadoAltaTienda,
  formData: FormData
): Promise<EstadoAltaTienda> {
  // Defensa en profundidad: esta acción ya está detrás del Basic Auth de
  // proxy.ts para admin.tukios.com, pero la doc de Next.js sobre Proxy
  // advierte explícitamente que un cambio de matcher a futuro podría dejar
  // de cubrir la ruta de un Server Function sin que sea evidente -- así que
  // no confiamos solo en eso para una acción que crea usuarios reales con
  // privilegios de dueño.
  const headersList = await headers();
  if (!verificarBasicAuth(headersList.get("authorization"))) {
    return { status: "error", mensaje: "No autorizado." };
  }

  const nombreTienda = String(formData.get("nombreTienda") ?? "").trim();
  const subdominio = String(formData.get("subdominio") ?? "")
    .trim()
    .toLowerCase();
  const nombreDueno = String(formData.get("nombreDueno") ?? "").trim();
  const emailDueno = String(formData.get("emailDueno") ?? "")
    .trim()
    .toLowerCase();

  if (!nombreTienda || !subdominio || !nombreDueno || !emailDueno) {
    return { status: "error", mensaje: "Completá los cuatro campos." };
  }
  if (!SUBDOMINIO_REGEX.test(subdominio)) {
    return {
      status: "error",
      mensaje:
        "El subdominio solo puede tener minúsculas, números y guiones (no al principio/final).",
    };
  }

  const admin = supabaseAdmin();

  // Paso a: crear la tienda. Sin usuario autenticado todavía en este flujo
  // (es literalmente el alta del primer usuario), así que la única forma de
  // escribir es con la service_role key, que bypasea RLS.
  const { data: tienda, error: errorTienda } = await admin
    .from("tiendas")
    .insert({ nombre: nombreTienda, subdominio })
    .select("id")
    .single();

  if (errorTienda || !tienda) {
    const esSubdominioDuplicado = errorTienda?.code === "23505";
    return {
      status: "error",
      mensaje: esSubdominioDuplicado
        ? `El subdominio "${subdominio}" ya está en uso.`
        : `No se pudo crear la tienda: ${errorTienda?.message ?? "error desconocido"}`,
    };
  }

  const passwordGenerada = generarPassword();

  // Paso b: crear el usuario dueño vía Admin API. El metadata acá es lo que
  // el trigger on_auth_user_created (ver drizzle/0005) lee para crear la
  // fila en public.usuarios -- no se inserta a mano a propósito, así
  // confirmamos que el trigger funciona con datos reales del flujo de la
  // app, no solo con inserts manuales de prueba en el SQL Editor.
  const { error: errorUsuario } = await admin.auth.admin.createUser({
    email: emailDueno,
    password: passwordGenerada,
    email_confirm: true,
    user_metadata: {
      tienda_id: tienda.id,
      nombre: nombreDueno,
      rol: "dueño",
      // La contraseña recién generada es temporal -- el panel obliga a
      // cambiarla antes de dejar entrar (ver app/(panel)/panel/cambiar-password).
      debe_cambiar_password: true,
    },
  });

  if (errorUsuario) {
    // Paso c: si esto falla, la tienda ya quedó creada en el paso a -- un
    // local sin ningún dueño que pueda operarlo. Se revierte para no dejar
    // ese estado huérfano: mejor que el alta falle entera y se pueda
    // reintentar, a tener que ir a buscar manualmente tiendas sin usuarios
    // más adelante. No hay ninguna otra fila que dependa de esta tienda
    // todavía (se crea recién acá, nada más la referencia todavía), así
    // que el DELETE es seguro sin arrastrar nada más.
    await admin.from("tiendas").delete().eq("id", tienda.id);
    return {
      status: "error",
      mensaje: `No se pudo crear el usuario dueño (se revirtió la tienda creada): ${errorUsuario.message}`,
    };
  }

  return {
    status: "ok",
    tiendaId: tienda.id,
    nombreTienda,
    subdominio,
    emailDueno,
    passwordGenerada,
  };
}

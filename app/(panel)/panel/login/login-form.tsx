"use client";

import { useActionState, useEffect } from "react";
import { login, type EstadoLogin } from "./actions";

const ESTADO_INICIAL: EstadoLogin = { status: "idle" };

export function LoginForm() {
  const [estado, formAction, pendiente] = useActionState(
    login,
    ESTADO_INICIAL
  );

  // Recarga dura (no router de Next) para que la siguiente página se pida
  // de cero al servidor -- ver el comentario en cambiar-password/actions.ts.
  useEffect(() => {
    if (estado.status === "ok") {
      window.location.href = estado.destino;
    }
  }, [estado]);

  return (
    <form action={formAction} className="space-y-4">
      {estado.status === "error" && (
        <p className="rounded-md bg-red-50 p-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-200">
          {estado.mensaje}
        </p>
      )}

      <div className="space-y-1">
        <label htmlFor="email" className="block text-sm font-medium">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="password" className="block text-sm font-medium">
          Contraseña
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <button
        type="submit"
        disabled={pendiente || estado.status === "ok"}
        className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
      >
        {pendiente || estado.status === "ok" ? "Entrando..." : "Entrar"}
      </button>
    </form>
  );
}

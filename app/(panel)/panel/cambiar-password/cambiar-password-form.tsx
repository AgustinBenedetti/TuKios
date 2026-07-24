"use client";

import { useActionState, useEffect } from "react";
import { cambiarPassword, type EstadoCambiarPassword } from "./actions";

const ESTADO_INICIAL: EstadoCambiarPassword = { status: "idle" };

export function CambiarPasswordForm() {
  const [estado, formAction, pendiente] = useActionState(
    cambiarPassword,
    ESTADO_INICIAL
  );

  // Recarga dura (no router de Next) -- ver el comentario en actions.ts.
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
        <label htmlFor="nuevaPassword" className="block text-sm font-medium">
          Nueva contraseña
        </label>
        <input
          id="nuevaPassword"
          name="nuevaPassword"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="confirmacion" className="block text-sm font-medium">
          Confirmá la nueva contraseña
        </label>
        <input
          id="confirmacion"
          name="confirmacion"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <button
        type="submit"
        disabled={pendiente || estado.status === "ok"}
        className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
      >
        {pendiente || estado.status === "ok" ? "Guardando..." : "Cambiar contraseña"}
      </button>
    </form>
  );
}

"use client";

import { useState, useTransition } from "react";
import { logout } from "./logout-actions";

export function LogoutButton() {
  const [pendiente, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="space-y-2">
      {error && (
        <p className="rounded-md bg-red-50 p-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-200">
          {error}
        </p>
      )}
      <button
        type="button"
        disabled={pendiente}
        onClick={() => {
          setError(null);
          startTransition(async () => {
            const estado = await logout();
            if (estado.status === "ok") {
              // Recarga dura (no router de Next) -- ver el comentario en
              // cambiar-password/actions.ts.
              window.location.href = estado.destino;
            } else {
              setError(estado.mensaje);
            }
          });
        }}
        className="text-sm underline underline-offset-2"
      >
        {pendiente ? "Cerrando sesión..." : "Cerrar sesión"}
      </button>
    </div>
  );
}

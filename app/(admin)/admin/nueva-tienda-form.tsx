"use client";

import { useActionState } from "react";
import { crearTiendaYDueno, type EstadoAltaTienda } from "./actions";

const ESTADO_INICIAL: EstadoAltaTienda = { status: "idle" };

export function NuevaTiendaForm() {
  const [estado, formAction, pendiente] = useActionState(
    crearTiendaYDueno,
    ESTADO_INICIAL
  );

  if (estado.status === "ok") {
    return (
      <div className="space-y-4 rounded-md border border-neutral-300 p-6 dark:border-neutral-700">
        <p className="font-medium">
          Tienda &quot;{estado.nombreTienda}&quot; creada correctamente.
        </p>
        <dl className="space-y-1 text-sm">
          <div className="flex gap-2">
            <dt className="text-neutral-500">Subdominio:</dt>
            <dd>{estado.subdominio}.tukios.com</dd>
          </div>
          <div className="flex gap-2">
            <dt className="text-neutral-500">Email del dueño:</dt>
            <dd>{estado.emailDueno}</dd>
          </div>
        </dl>
        <div className="rounded-md bg-amber-50 p-4 text-sm dark:bg-amber-950">
          <p className="font-medium">Contraseña generada:</p>
          <p className="mt-1 font-mono text-base">{estado.passwordGenerada}</p>
          <p className="mt-2 text-neutral-600 dark:text-neutral-400">
            Copiala ahora y pasásela al dueño por un canal seguro (WhatsApp,
            en persona). No queda guardada en ningún lado ni se vuelve a
            mostrar.
          </p>
        </div>
        <a
          href="."
          className="inline-block text-sm underline underline-offset-2"
        >
          Dar de alta otra tienda
        </a>
      </div>
    );
  }

  return (
    <form action={formAction} className="space-y-4">
      {estado.status === "error" && (
        <p className="rounded-md bg-red-50 p-3 text-sm text-red-800 dark:bg-red-950 dark:text-red-200">
          {estado.mensaje}
        </p>
      )}

      <div className="space-y-1">
        <label htmlFor="nombreTienda" className="block text-sm font-medium">
          Nombre de la tienda
        </label>
        <input
          id="nombreTienda"
          name="nombreTienda"
          type="text"
          required
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="subdominio" className="block text-sm font-medium">
          Subdominio
        </label>
        <div className="flex items-center gap-1">
          <input
            id="subdominio"
            name="subdominio"
            type="text"
            required
            pattern="[a-z0-9]+(-[a-z0-9]+)*"
            placeholder="mi-kiosco"
            className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
          />
          <span className="whitespace-nowrap text-sm text-neutral-500">
            .tukios.com
          </span>
        </div>
      </div>

      <div className="space-y-1">
        <label htmlFor="nombreDueno" className="block text-sm font-medium">
          Nombre del dueño
        </label>
        <input
          id="nombreDueno"
          name="nombreDueno"
          type="text"
          required
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="emailDueno" className="block text-sm font-medium">
          Email del dueño
        </label>
        <input
          id="emailDueno"
          name="emailDueno"
          type="email"
          required
          className="w-full rounded-md border border-neutral-300 px-3 py-2 dark:border-neutral-700 dark:bg-transparent"
        />
      </div>

      <button
        type="submit"
        disabled={pendiente}
        className="rounded-md bg-neutral-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50 dark:bg-neutral-100 dark:text-neutral-900"
      >
        {pendiente ? "Creando..." : "Crear tienda"}
      </button>
    </form>
  );
}

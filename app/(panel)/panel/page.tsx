import { requerirSesionPanel } from "@/lib/panel-auth";
import { LogoutButton } from "./logout-button";

export default async function PanelPage() {
  // Chequeo autoritativo (ver lib/panel-auth.ts): sin esto, esta página
  // (y cualquier página futura del panel) queda protegida únicamente por
  // proxy.ts.
  const sesion = await requerirSesionPanel();

  return (
    <main className="flex min-h-full flex-1 flex-col items-center justify-center gap-4 p-8">
      <p className="text-lg">
        Bienvenido, estás logueado como {sesion.nombre || sesion.email}
      </p>
      <p className="text-sm text-neutral-500">
        Placeholder -- el contenido real del panel es otro feature.
      </p>
      <LogoutButton />
    </main>
  );
}

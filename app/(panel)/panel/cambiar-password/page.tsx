import { requerirSesionParaCambiarPassword } from "@/lib/panel-auth";
import { CambiarPasswordForm } from "./cambiar-password-form";

export default async function CambiarPasswordPage() {
  // Chequeo autoritativo (ver lib/panel-auth.ts): si no hay sesión, redirige
  // a /login; si la contraseña ya fue cambiada, redirige al panel.
  await requerirSesionParaCambiarPassword();

  return (
    <main className="flex min-h-full flex-1 items-start justify-center p-8">
      <div className="w-full max-w-sm space-y-6">
        <div>
          <h1 className="text-xl font-semibold">Elegí una nueva contraseña</h1>
          <p className="text-sm text-neutral-500">
            Es tu primer ingreso -- tenés que cambiar la contraseña temporal
            antes de seguir.
          </p>
        </div>
        <CambiarPasswordForm />
      </div>
    </main>
  );
}

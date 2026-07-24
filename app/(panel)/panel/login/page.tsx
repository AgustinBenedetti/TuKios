import { LoginForm } from "./login-form";

export default function LoginPage() {
  return (
    <main className="flex min-h-full flex-1 items-start justify-center p-8">
      <div className="w-full max-w-sm space-y-6">
        <div>
          <h1 className="text-xl font-semibold">Ingresar al panel</h1>
          <p className="text-sm text-neutral-500">panel.tukios.com</p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}

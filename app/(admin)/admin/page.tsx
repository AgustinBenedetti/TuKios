import { NuevaTiendaForm } from "./nueva-tienda-form";

export default function AdminPage() {
  return (
    <main className="flex min-h-full flex-1 items-start justify-center p-8">
      <div className="w-full max-w-md space-y-6">
        <div>
          <h1 className="text-xl font-semibold">Alta de tienda</h1>
          <p className="text-sm text-neutral-500">
            Route group: <code>(admin)</code> — admin.tukios.com
          </p>
        </div>
        <NuevaTiendaForm />
      </div>
    </main>
  );
}

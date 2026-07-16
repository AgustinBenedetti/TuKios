import { headers } from "next/headers";

export default async function TiendaPage() {
  const headersList = await headers();
  const subdominio = headersList.get("x-tukios-subdominio");

  return (
    <main className="flex min-h-full flex-1 items-center justify-center p-8">
      <p className="text-lg">
        Route group: <code>(tienda)</code> — catálogo público
        {subdominio ? ` (subdominio detectado: "${subdominio}")` : ""}
      </p>
    </main>
  );
}

import { NextRequest, NextResponse } from "next/server";
import { verificarBasicAuth } from "@/lib/admin-auth";

const ROOT_DOMAIN = "tukios.com";
const SUBDOMINIO_HEADER = "x-tukios-subdominio";

function respuestaNoAutorizada() {
  return new NextResponse("Autenticación requerida.", {
    status: 401,
    headers: {
      // Header que hace que el navegador muestre el popup nativo de Basic Auth.
      "WWW-Authenticate": 'Basic realm="TuKios Admin"',
    },
  });
}

export function proxy(request: NextRequest) {
  const host = request.headers.get("host") ?? "";
  const hostname = host.split(":")[0];
  const { pathname } = request.nextUrl;

  const esDominioRaiz =
    hostname === ROOT_DOMAIN ||
    hostname === `www.${ROOT_DOMAIN}` ||
    hostname === "localhost";

  // (marketing) vive en "/" directamente, no hace falta rewrite.
  if (esDominioRaiz) {
    return NextResponse.next();
  }

  // admin.tukios.com (o admin.localhost en dev): herramienta interna para
  // dar de alta tiendas a mano, sin login de Supabase Auth todavía -- se
  // protege con HTTP Basic Auth en vez de dejarla abierta. Se resuelve
  // antes que cualquier otro subdominio para no caer en el catch-all de
  // "tienda" de más abajo.
  const esAdmin = hostname === `admin.${ROOT_DOMAIN}` || hostname === "admin.localhost";
  if (esAdmin) {
    if (!verificarBasicAuth(request.headers.get("authorization"))) {
      return respuestaNoAutorizada();
    }
    const url = request.nextUrl.clone();
    url.pathname = `/admin${pathname === "/" ? "" : pathname}`;
    return NextResponse.rewrite(url);
  }

  const esPanel = hostname.startsWith("panel.");
  const url = request.nextUrl.clone();

  if (esPanel) {
    url.pathname = `/panel${pathname === "/" ? "" : pathname}`;
    return NextResponse.rewrite(url);
  }

  // Cualquier otro subdominio -> catálogo de tienda.
  // La resolución de subdominio -> tienda_id contra la base queda para más adelante;
  // acá solo se detecta y se pasa como header interno.
  const subdominio = hostname.split(".")[0];
  url.pathname = `/tienda${pathname === "/" ? "" : pathname}`;

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set(SUBDOMINIO_HEADER, subdominio);

  return NextResponse.rewrite(url, {
    request: { headers: requestHeaders },
  });
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};

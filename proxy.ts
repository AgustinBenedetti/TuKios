import { NextRequest, NextResponse } from "next/server";

const ROOT_DOMAIN = "tukios.com";
const SUBDOMINIO_HEADER = "x-tukios-subdominio";

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

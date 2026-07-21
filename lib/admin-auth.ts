// Verificación de HTTP Basic Auth para admin.tukios.com. Se usa en dos
// lugares que NO comparten runtime request object (proxy.ts recibe un
// NextRequest, el server action de /admin lee headers() de next/headers),
// así que esta función toma directamente el valor del header
// "authorization" en vez de un request completo, para poder llamarse desde
// los dos.
//
// Por qué se revalida también dentro del server action y no solo acá:
// la doc de Next.js 16 sobre Proxy lo advierte explícitamente -- un cambio
// futuro en el matcher de proxy.ts podría dejar de cubrir la ruta de un
// Server Function sin que sea obvio, así que server actions sensibles no
// deberían depender solo del proxy para su autorización. Ver
// app/(admin)/admin/actions.ts.
export function verificarBasicAuth(authorizationHeader: string | null): boolean {
  const usuarioEsperado = process.env.ADMIN_BASIC_AUTH_USER;
  const passwordEsperada = process.env.ADMIN_BASIC_AUTH_PASSWORD;

  // Si las credenciales no están configuradas en el entorno, no hay forma
  // válida de autenticarse -- fallar cerrado, nunca dejar pasar por default.
  if (!usuarioEsperado || !passwordEsperada) return false;
  if (!authorizationHeader || !authorizationHeader.startsWith("Basic ")) {
    return false;
  }

  let decodificado: string;
  try {
    decodificado = Buffer.from(
      authorizationHeader.slice("Basic ".length),
      "base64"
    ).toString("utf-8");
  } catch {
    return false;
  }

  const separador = decodificado.indexOf(":");
  if (separador === -1) return false;

  const usuario = decodificado.slice(0, separador);
  const password = decodificado.slice(separador + 1);

  return usuario === usuarioEsperado && password === passwordEsperada;
}

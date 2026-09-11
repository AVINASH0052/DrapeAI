/**
 * Edge proxy for https://api.sugatai.com → local FastAPI via public tunnel (ngrok/cloudflared).
 */
export interface Env {
  ORIGIN: string
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = (env.ORIGIN || "").replace(/\/$/, "")
    if (!origin) {
      return Response.json(
        { detail: "API edge proxy misconfigured: ORIGIN is empty" },
        { status: 503 },
      )
    }

    const incoming = new URL(request.url)
    const target = `${origin}${incoming.pathname}${incoming.search}`

    const headers = new Headers(request.headers)
    headers.delete("host")
    headers.set("host", new URL(origin).host)
    headers.set("ngrok-skip-browser-warning", "1")

    try {
      return await fetch(target, {
        method: request.method,
        headers,
        body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
        redirect: "manual",
      })
    } catch (err) {
      return Response.json(
        {
          detail: `Upstream API tunnel unreachable (${origin}). Keep ngrok/cloudflared running against localhost:8000.`,
          error: String(err),
        },
        { status: 502 },
      )
    }
  },
}

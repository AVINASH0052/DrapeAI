/**
 * Sugatai landing Worker: static assets + waitlist API.
 */
export interface Env {
  ASSETS: Fetcher
  WAITLIST: KVNamespace
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const SECURITY_HEADERS: Record<string, string> = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Frame-Options': 'DENY',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Content-Security-Policy':
    "default-src 'self'; img-src 'self' https: data:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; script-src 'self'; connect-src 'self' https://api.sugatai.com",
}

function withSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers)
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    headers.set(key, value)
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  })
}

function json(data: unknown, status = 200): Response {
  return withSecurityHeaders(
    new Response(JSON.stringify(data), {
      status,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    }),
  )
}

async function handleWaitlist(request: Request, env: Env): Promise<Response> {
  if (request.method === 'OPTIONS') {
    return json({ ok: true }, 204)
  }
  if (request.method !== 'POST') {
    return json({ detail: 'Method not allowed.' }, 405)
  }

  let body: { email?: string; source?: string }
  try {
    body = (await request.json()) as { email?: string; source?: string }
  } catch {
    return json({ detail: 'Invalid JSON body.' }, 400)
  }

  const ip = request.headers.get('CF-Connecting-IP') || 'unknown'
  const rlKey = `rl:waitlist:${ip}`
  const hits = Number((await env.WAITLIST.get(rlKey)) || '0')
  if (hits >= 10) {
    return json({ detail: 'Too many requests. Try again later.' }, 429)
  }
  await env.WAITLIST.put(rlKey, String(hits + 1), { expirationTtl: 3600 })

  const email = (body.email || '').trim().toLowerCase()
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
    return json({ detail: 'Enter a valid email address.' }, 400)
  }

  const source = ((body.source || 'landing').trim() || 'landing').slice(0, 64)
  const key = `email:${email}`

  const existing = await env.WAITLIST.get(key)
  if (existing) {
    return json({
      ok: true,
      already_joined: true,
      message: 'You are already on the early list.',
    })
  }

  await env.WAITLIST.put(
    key,
    JSON.stringify({
      email,
      source,
      created_at: new Date().toISOString(),
    }),
  )

  return json({
    ok: true,
    already_joined: false,
    message: 'You are on the early list. We will reach out soon.',
  })
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    // Prefer www as the indexed host (matches canonical).
    if (url.hostname === 'sugatai.com') {
      url.hostname = 'www.sugatai.com'
      return Response.redirect(url.toString(), 301)
    }

    if (url.pathname === '/waitlist') {
      return handleWaitlist(request, env)
    }

    // Google Search Console HTML-file verification must keep the .html suffix.
    if (url.pathname === '/googlefaabd15657505ad0.html') {
      return withSecurityHeaders(
        new Response('google-site-verification: googlefaabd15657505ad0.html\n', {
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'public, max-age=300',
          },
        }),
      )
    }

    // Legal routes are the SPA; Assets not_found_handling serves index.html.
    return withSecurityHeaders(await env.ASSETS.fetch(request))
  },
}

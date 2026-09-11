/**
 * Sugatai admin console at https://app.sugatai.com/workadmin/
 */
export interface Env {
  ASSETS: Fetcher
  /** Optional origin for FastAPI, e.g. https://api.sugatai.com */
  API_ORIGIN?: string
}

const ADMIN_PREFIX = '/workadmin'

const SECURITY_HEADERS: Record<string, string> = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Frame-Options': 'DENY',
  'X-Robots-Tag': 'noindex, nofollow',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
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

function withPath(request: Request, pathname: string): Request {
  const url = new URL(request.url)
  url.pathname = pathname
  return new Request(url.toString(), request)
}

async function serveAdminAsset(request: Request, env: Env, assetPath: string): Promise<Response> {
  const assetRequest = withPath(request, assetPath)
  const assetResponse = await env.ASSETS.fetch(assetRequest)

  // SPA fallback for client routes like /workadmin/login
  if (assetResponse.status === 404 && !assetPath.includes('.')) {
    return withSecurityHeaders(await env.ASSETS.fetch(withPath(request, '/index.html')))
  }
  return withSecurityHeaders(assetResponse)
}

function apiUnavailable(detail: string, status = 503): Response {
  return withSecurityHeaders(
    new Response(JSON.stringify({ detail, code: 'api_origin_unreachable' }), {
      status,
      headers: { 'Content-Type': 'application/json' },
    }),
  )
}

const PROXY_METHODS = new Set(['GET', 'HEAD', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'])

async function proxyApi(request: Request, env: Env): Promise<Response> {
  if (!PROXY_METHODS.has(request.method)) {
    return withSecurityHeaders(new Response('Method not allowed', { status: 405 }))
  }
  const origin = (env.API_ORIGIN || 'https://api.sugatai.com').replace(/\/$/, '')
  const url = new URL(request.url)
  const target = `${origin}${url.pathname}${url.search}`

  const headers = new Headers(request.headers)
  headers.delete('host')

  let upstream: Response
  try {
    upstream = await fetch(target, {
      method: request.method,
      headers,
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : request.body,
      redirect: 'manual',
    })
  } catch {
    return apiUnavailable(
      `Cannot reach API origin ${origin}. Create DNS for api.sugatai.com (or set Worker var API_ORIGIN) and deploy the FastAPI stack.`,
      502,
    )
  }

  // Cloudflare origin DNS / connection failures often surface as 5xx on the proxied host.
  if ([520, 521, 522, 523, 524, 525, 526, 530].includes(upstream.status)) {
    return apiUnavailable(
      `API origin ${origin} returned Cloudflare ${upstream.status}. api.sugatai.com has no live origin — deploy FastAPI + point DNS A/CNAME at your server, then retry.`,
      503,
    )
  }

  return withSecurityHeaders(upstream)
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    // Same-origin API proxy so the SPA can call /admin/* (and /uploads in
    // development mode) without CORS or broken relative media URLs.
    if (
      url.pathname === '/admin' ||
      url.pathname.startsWith('/admin/') ||
      url.pathname === '/uploads' ||
      url.pathname.startsWith('/uploads/')
    ) {
      return proxyApi(request, env)
    }

    if (url.pathname === '/' || url.pathname === '') {
      return Response.redirect(new URL(`${ADMIN_PREFIX}/`, url.origin).toString(), 302)
    }

    if (url.pathname === ADMIN_PREFIX) {
      return Response.redirect(new URL(`${ADMIN_PREFIX}/`, url.origin).toString(), 302)
    }

    if (url.pathname.startsWith(`${ADMIN_PREFIX}/`)) {
      const stripped = url.pathname.slice(ADMIN_PREFIX.length) || '/'
      return serveAdminAsset(request, env, stripped)
    }

    return withSecurityHeaders(new Response('Not found', { status: 404 }))
  },
}

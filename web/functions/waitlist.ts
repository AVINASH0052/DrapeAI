type WaitlistEnv = {
  WAITLIST?: {
    get: (key: string) => Promise<string | null>
    put: (key: string, value: string) => Promise<void>
  }
}

type JsonBody = {
  email?: string
  source?: string
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    },
  })
}

export async function onRequestOptions(): Promise<Response> {
  return json({ ok: true }, 204)
}

export async function onRequestPost(context: {
  request: Request
  env: WaitlistEnv
}): Promise<Response> {
  let body: JsonBody
  try {
    body = (await context.request.json()) as JsonBody
  } catch {
    return json({ detail: 'Invalid JSON body.' }, 400)
  }

  const email = (body.email || '').trim().toLowerCase()
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
    return json({ detail: 'Enter a valid email address.' }, 400)
  }

  const source = ((body.source || 'landing').trim() || 'landing').slice(0, 64)
  const key = `email:${email}`
  const store = context.env.WAITLIST

  if (!store) {
    return json(
      {
        detail:
          'Waitlist storage is not configured yet. Bind a KV namespace named WAITLIST in Cloudflare Pages.',
      },
      503,
    )
  }

  const existing = await store.get(key)
  if (existing) {
    return json({
      ok: true,
      already_joined: true,
      message: 'You are already on the early list.',
    })
  }

  await store.put(
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

import { useEffect } from 'react'

type Kind = 'privacy' | 'terms' | 'support'

const titles: Record<Kind, string> = {
  privacy: 'Privacy Policy · Sugatai',
  terms: 'Terms of Service · Sugatai',
  support: 'Support · Sugatai',
}

const canonical: Record<Kind, string> = {
  privacy: 'https://www.sugatai.com/privacy',
  terms: 'https://www.sugatai.com/terms',
  support: 'https://www.sugatai.com/support',
}

function Section({ title, children }: { title: string; children: string }) {
  return (
    <section className="legal-section">
      <h2>{title}</h2>
      <p>{children}</p>
    </section>
  )
}

function Privacy() {
  return (
    <>
      <h1>Privacy Policy</h1>
      <p className="legal-updated">Last updated: September 2026</p>
      <Section
        title="What we collect"
        children="Phone number or Google/Apple sign-in identifiers, the full-body photo you choose for private try-on, wardrobe photos you upload, optional style preferences, outfit feedback, and a push notification token if you opt in. We do not sell your images."
      />
      <Section
        title="How we use AI"
        children="Clothing photos may be sent to configured AI providers for tagging. Your body photo and selected garments are processed to create private try-on renders. The avatar is a visual preview, not a medical scan or measurement tool."
      />
      <Section
        title="Storage and subprocessors"
        children="Source and derived images are stored on Cloudflare R2 (private bucket). Profile and wardrobe data live in PostgreSQL. Firebase (Google) handles authentication and optional push. AI processing may use Google Gemini/Vertex, and optionally Cloudflare Workers AI or RunPod. Weather uses Open-Meteo. We do not use a public image CDN for closets or body photos."
      />
      <Section
        title="Retention"
        children="Account data and photos are kept until you delete the account. Deletion removes wardrobe items, outfits, try-on history, push tokens, and associated images. Object cleanup is attempted immediately; retries are safe if a previous attempt was partial."
      />
      <Section
        title="Your rights"
        children="Delete your account anytime from Profile → Delete account in the app. Contact privacy@sugatai.com for privacy requests. Sugatai is not intended for children under 13."
      />
      <Section title="Contact" children="privacy@sugatai.com" />
    </>
  )
}

function Terms() {
  return (
    <>
      <h1>Terms of Service</h1>
      <p className="legal-updated">Last updated: September 2026</p>
      <Section
        title="The deal"
        children="Sugatai is an AI styling assistant. We suggest outfits from your wardrobe and provide visual previews. Previews are not a guarantee of real-world fit or appearance."
      />
      <Section
        title="Your content"
        children="You own your wardrobe and body photos. By uploading, you grant us a license to process, tag, and display them back to you in the app."
      />
      <Section
        title="Acceptable use"
        children="No illegal content, harassment, or attempts to abuse AI systems. We may suspend accounts that violate these terms."
      />
      <Section
        title="Early access"
        children="Sugatai is in early access and is free for invited users. Paid plans are not offered yet. We will not charge you without a separate, explicit billing agreement."
      />
      <Section
        title="Disclaimer"
        children='AI suggestions are probabilistic, not professional styling advice. The service is provided "as is" without warranty.'
      />
      <Section title="Contact" children="help@sugatai.com" />
    </>
  )
}

function Support() {
  return (
    <>
      <h1>Support</h1>
      <p className="legal-updated">Last updated: September 2026</p>
      <Section
        title="App help"
        children="Email help@sugatai.com for account, wardrobe, or try-on issues. Include the email or phone on the account. Do not send body or wardrobe photos unless we ask."
      />
      <Section
        title="Privacy"
        children="Privacy requests and account-deletion questions: privacy@sugatai.com."
      />
      <Section
        title="Press and waitlist"
        children="General contact: hello@sugatai.com."
      />
    </>
  )
}

export function LegalPage({ kind }: { kind: Kind }) {
  useEffect(() => {
    document.title = titles[kind]
    let link = document.querySelector<HTMLLinkElement>('link[rel="canonical"]')
    if (!link) {
      link = document.createElement('link')
      link.rel = 'canonical'
      document.head.appendChild(link)
    }
    link.href = canonical[kind]
  }, [kind])

  return (
    <main className="legal-page">
      <nav className="nav shell" aria-label="Legal navigation">
        <a className="wordmark" href="/" aria-label="Sugatai home">
          sugatai
          <span>.</span>
        </a>
        <div className="nav-links">
          <a href="/privacy">Privacy</a>
          <a href="/terms">Terms</a>
          <a href="/support">Support</a>
        </div>
      </nav>
      <article className="legal-body shell">
        {kind === 'privacy' ? <Privacy /> : kind === 'terms' ? <Terms /> : <Support />}
      </article>
    </main>
  )
}

export function pageKindFromPath(pathname: string): Kind | null {
  const path = pathname.replace(/\/$/, '') || '/'
  if (path === '/privacy') return 'privacy'
  if (path === '/terms') return 'terms'
  if (path === '/support') return 'support'
  return null
}

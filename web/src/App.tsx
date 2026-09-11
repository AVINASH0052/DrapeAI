import { useEffect, useRef, useState } from 'react'
import type { CSSProperties, FormEvent } from 'react'
import {
  ArrowRight,
  Camera,
  Check,
  ChevronRight,
  CloudSun,
  AtSign,
  ScanSearch,
  Sparkles,
} from 'lucide-react'
import './App.css'

const looks = [
  {
    src: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=900&q=85',
    alt: 'Modern street style shopping',
    label: 'City day',
  },
  {
    src: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=900&q=85',
    alt: 'Woman in a contemporary sari',
    label: 'Occasion night',
  },
  {
    src: 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=900&q=85',
    alt: 'Clean modern fashion editorial',
    label: 'Work to dinner',
  },
]

const heroCapsules = [
  {
    src: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=600&q=80',
    alt: 'Street style look',
  },
  {
    src: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=600&q=80',
    alt: 'Contemporary sari look',
  },
]

const rotatingWords = ['work', 'festivals', 'dates', 'travel', 'monsoon']

const API_BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(
  /\/$/,
  '',
) ?? ''

type WaitlistStatus = 'idle' | 'loading' | 'success' | 'exists' | 'error'

function WaitlistForm() {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<WaitlistStatus>('idle')
  const [message, setMessage] = useState('')

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const value = email.trim()
    if (!value || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      setStatus('error')
      setMessage('Enter a valid email address.')
      return
    }

    setStatus('loading')
    setMessage('')
    try {
      const response = await fetch(`${API_BASE}/waitlist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: value, source: 'landing' }),
      })
      const data = (await response.json().catch(() => null)) as
        | { message?: string; already_joined?: boolean; detail?: string }
        | null
      if (!response.ok) {
        const detail =
          typeof data?.detail === 'string'
            ? data.detail
            : 'Could not join right now. Try again.'
        setStatus('error')
        setMessage(detail)
        return
      }
      setStatus(data?.already_joined ? 'exists' : 'success')
      setMessage(
        data?.message ??
          (data?.already_joined
            ? 'You are already on the early list.'
            : 'You are on the early list.'),
      )
      if (!data?.already_joined) setEmail('')
    } catch {
      setStatus('error')
      setMessage('Could not reach Sugatai. Check your connection and try again.')
    }
  }

  if (status === 'success' || status === 'exists') {
    return (
      <div className="waitlist-done" role="status">
        <Check size={18} aria-hidden="true" />
        <p>{message}</p>
      </div>
    )
  }

  return (
    <form className="waitlist-form" onSubmit={onSubmit} noValidate>
      <label className="sr-only" htmlFor="waitlist-email">
        Email address
      </label>
      <div className="waitlist-row">
        <input
          id="waitlist-email"
          type="email"
          name="email"
          autoComplete="email"
          placeholder="you@email.com"
          value={email}
          onChange={(event) => {
            setEmail(event.target.value)
            if (status === 'error') {
              setStatus('idle')
              setMessage('')
            }
          }}
          disabled={status === 'loading'}
          required
        />
        <button
          className="button button-light"
          type="submit"
          disabled={status === 'loading'}
        >
          {status === 'loading' ? 'Joining…' : 'Join the early list'}
          {status !== 'loading' ? (
            <ArrowRight size={18} aria-hidden="true" />
          ) : null}
        </button>
      </div>
      {message ? (
        <p className="waitlist-error" role="alert">
          {message}
        </p>
      ) : (
        <p className="waitlist-hint">No spam. Launch updates only.</p>
      )}
    </form>
  )
}

const appLooks = [
  {
    kicker: 'WEEKEND PLAN',
    title: 'Clean & easy',
    note: '3 pieces from your closet',
    image: looks[2],
  },
  {
    kicker: 'CITY DAY',
    title: 'Street & simple',
    note: '4 pieces from your closet',
    image: looks[0],
  },
  {
    kicker: 'OCCASION NIGHT',
    title: 'Modern classic',
    note: 'One sari, styled your way',
    image: looks[1],
  },
]

const marqueeItems = [
  'See your look',
  'before you wear it',
  'Street',
  'Work',
  'Occasion',
  'Mumbai',
  'Delhi',
  'Bengaluru',
]

const features = [
  {
    icon: Camera,
    title: 'Your closet, digitized',
    copy: 'Snap it once. Every piece tagged, jeans to kurtas.',
  },
  {
    icon: Sparkles,
    title: 'Looks for real life',
    copy: 'Outfits that fit your calendar, not a trend feed.',
  },
  {
    icon: ScanSearch,
    title: 'See it on you',
    copy: 'Preview any look on your photo before you buy or wear.',
  },
  {
    icon: CloudSun,
    title: 'Weather smart',
    copy: 'Built for heat, rain and humidity.',
  },
]

const reveal = (seconds = 0): CSSProperties =>
  ({ '--rd': `${seconds}s` }) as CSSProperties

const prefersReducedMotion = () =>
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

function useScrollReveal() {
  useEffect(() => {
    const targets = document.querySelectorAll('[data-reveal]')
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-in')
            observer.unobserve(entry.target)
          }
        }
      },
      { threshold: 0.15, rootMargin: '0px 0px -40px 0px' },
    )
    targets.forEach((target) => observer.observe(target))
    return () => observer.disconnect()
  }, [])
}

function useCycle(length: number, ms: number) {
  const [index, setIndex] = useState(0)

  useEffect(() => {
    if (prefersReducedMotion()) return
    const id = window.setInterval(
      () => setIndex((current) => (current + 1) % length),
      ms,
    )
    return () => window.clearInterval(id)
  }, [length, ms])

  return index
}

function usePreloadLooks() {
  useEffect(() => {
    looks.forEach((look) => {
      const img = new Image()
      img.src = look.src
    })
  }, [])
}

function useHeroParallax() {
  const heroRef = useRef<HTMLElement>(null)

  useEffect(() => {
    const hero = heroRef.current
    if (!hero || prefersReducedMotion()) return

    const onMove = (event: MouseEvent) => {
      const rect = hero.getBoundingClientRect()
      const x = (event.clientX - rect.left) / rect.width - 0.5
      const y = (event.clientY - rect.top) / rect.height - 0.5
      hero.style.setProperty('--mx', x.toFixed(3))
      hero.style.setProperty('--my', y.toFixed(3))
    }
    const onLeave = () => {
      hero.style.setProperty('--mx', '0')
      hero.style.setProperty('--my', '0')
    }

    hero.addEventListener('mousemove', onMove)
    hero.addEventListener('mouseleave', onLeave)
    return () => {
      hero.removeEventListener('mousemove', onMove)
      hero.removeEventListener('mouseleave', onLeave)
    }
  }, [])

  return heroRef
}

function App() {
  useScrollReveal()
  usePreloadLooks()
  const heroRef = useHeroParallax()
  const wordIndex = useCycle(rotatingWords.length, 2400)
  const lookIndex = useCycle(appLooks.length, 4500)
  const appLook = appLooks[lookIndex]

  return (
    <main>
      <nav className="nav shell" aria-label="Primary navigation">
        <a className="wordmark" href="#top" aria-label="Sugatai home">
          sugatai
          <span>.</span>
        </a>
        <div className="nav-links">
          <a href="#how">How it works</a>
          <a href="#features">Features</a>
          <a className="nav-cta" href="#early-access">
            Join early access <ArrowRight size={16} aria-hidden="true" />
          </a>
        </div>
      </nav>

      <section className="hero shell" id="top" ref={heroRef}>
        <h1>
          <span className="hero-line">
            <span className="hero-line-inner">
              Your
              <span className="cap cap-1" aria-hidden="true">
                <img src={heroCapsules[0].src} alt="" />
              </span>
              clothes.
            </span>
          </span>
          <span className="hero-line">
            <span className="hero-line-inner">
              Your
              <span className="cap cap-2" aria-hidden="true">
                <img src={heroCapsules[1].src} alt="" />
              </span>
              <em>look.</em>
            </span>
          </span>
        </h1>
        <div className="hero-foot">
          <p className="hero-lede">
            One closet, styled for{' '}
            <span className="rotator">
              {rotatingWords.map((word, index) => (
                <span
                  key={word}
                  className={index === wordIndex ? 'active' : undefined}
                >
                  {word}.
                </span>
              ))}
            </span>
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#early-access">
              Get early access <ArrowRight size={18} aria-hidden="true" />
            </a>
            <a className="text-link" href="#how">
              See how it works <ChevronRight size={17} aria-hidden="true" />
            </a>
          </div>
          <p className="microcopy">
            <Check size={15} aria-hidden="true" />
            Free during early access
          </p>
        </div>
      </section>

      <div className="marquee" aria-hidden="true">
        <div className="marquee-track">
          {[0, 1].map((copy) => (
            <div className="marquee-group" key={copy}>
              {marqueeItems.map((item, index) => (
                <span
                  key={item}
                  className={index % 2 ? 'marquee-serif' : undefined}
                >
                  {item}
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>

      <section className="statement">
        <div className="shell statement-grid">
          <p className="section-index" data-reveal>
            01 · THE PROBLEM
          </p>
          <h2 data-reveal style={reveal(0.1)}>
            A full wardrobe.
            <br />
            <em>Still nothing to wear.</em>
          </h2>
          <p data-reveal style={reveal(0.22)}>
            Sugatai knows what you own and builds real looks for real days.
          </p>
        </div>
      </section>

      <section className="looks shell" id="how">
        <div className="section-heading">
          <p className="section-index" data-reveal>
            02 · HOW YOU LIVE
          </p>
          <h2 data-reveal style={reveal(0.1)}>
            One wardrobe. Street to occasion.
          </h2>
        </div>
        <div className="look-grid">
          {looks.map((look, index) => (
            <article
              className={`editorial-card editorial-card-${index + 1}`}
              key={look.label}
              data-reveal
              style={reveal(index * 0.14)}
            >
              <img src={look.src} alt={look.alt} loading="lazy" />
              <div>
                <span>0{index + 1}</span>
                <h3>{look.label}</h3>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="features shell" id="features">
        <div className="section-heading">
          <p className="section-index" data-reveal>
            03 · WHY SUGATAI
          </p>
          <h2 data-reveal style={reveal(0.1)}>
            Modern product. Local sense.
          </h2>
        </div>
        <div className="feature-grid">
          {features.map(({ icon: Icon, title, copy }, index) => (
            <article
              className="feature-card"
              key={title}
              data-reveal
              style={reveal(index * 0.1)}
            >
              <Icon size={24} strokeWidth={1.7} aria-hidden="true" />
              <h3>{title}</h3>
              <p>{copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="early-access" id="early-access">
        <div className="shell early-grid">
          <div className="early-copy" data-reveal>
            <p className="section-index">PRIVATE BETA</p>
            <h2>
              Style that travels
              <br />
              with your life.
            </h2>
            <WaitlistForm />
          </div>
          <div className="early-phone" data-reveal style={reveal(0.15)}>
            <div className="phone">
              <div className="phone-island" />
              <div className="phone-screen">
                <div className="app-top">
                  <span className="app-brand">sugatai</span>
                  <span className="avatar">S</span>
                </div>
                <p className="app-kicker">SATURDAY · 31°</p>
                <h3>Today's look</h3>
                <div className="look-card" key={lookIndex}>
                  <img src={appLook.image.src} alt={appLook.image.alt} />
                  <div className="look-card-copy">
                    <span>{appLook.kicker}</span>
                    <strong>{appLook.title}</strong>
                    <small>{appLook.note}</small>
                  </div>
                </div>
                <button type="button" className="app-button">
                  See it on me
                </button>
                <div className="app-dots" aria-hidden="true">
                  {appLooks.map((look, index) => (
                    <span
                      key={look.title}
                      className={index === lookIndex ? 'active' : undefined}
                    />
                  ))}
                </div>
              </div>
              <div className="phone-home" />
            </div>
          </div>
        </div>
      </section>

      <footer className="footer shell">
        <a className="wordmark" href="#top">
          sugatai<span>.</span>
        </a>
        <p>See your look, before you wear it.</p>
        <div>
          <a href="/privacy">Privacy</a>
          <a href="/terms">Terms</a>
          <a href="/support">Support</a>
          <a href="mailto:hello@sugatai.com">Contact</a>
          <a href="https://instagram.com" aria-label="Sugatai on Instagram">
            <AtSign size={18} aria-hidden="true" />
          </a>
        </div>
      </footer>
    </main>
  )
}

export default App

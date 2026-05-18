// screens-flow.jsx — splash, auth, OTP, onboarding, demo choice

// ─── 1. Splash ──────────────────────────────────────────────
function ScreenSplash({ onDone }) {
  React.useEffect(() => { const t = setTimeout(onDone, 1400); return () => clearTimeout(t); }, []);
  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', overflow:'hidden' }}>
      {/* subtle ambient blobs */}
      <div style={{ position:'absolute', top:'18%', left:'-10%', width:220, height:220, borderRadius:'50%', background:'var(--orange-soft)', filter:'blur(40px)', opacity:.7 }}/>
      <div style={{ position:'absolute', bottom:'14%', right:'-12%', width:240, height:240, borderRadius:'50%', background:'var(--lavender-soft)', filter:'blur(40px)', opacity:.6 }}/>
      <div style={{ position:'relative', display:'flex', flexDirection:'column', alignItems:'center', gap: 10 }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 56, lineHeight:1, letterSpacing:'-0.03em' }}>
          drape<span style={{ color:'var(--orange)' }}>.</span><span style={{ fontWeight: 600, fontFamily:'var(--f-sans)', fontSize: 44, marginLeft: -2 }}>ai</span>
        </div>
        <div className="sub" style={{ letterSpacing:'0.08em', textTransform:'uppercase', fontSize: 11 }}>
          your ai outfit assistant
        </div>
      </div>
      <div style={{ position:'absolute', bottom:46, display:'flex', alignItems:'center', gap: 6, opacity:.5 }}>
        <span className="caption mono" style={{ fontSize: 10 }}>v1.0</span>
      </div>
    </div>
  );
}

// ─── 2. Login ───────────────────────────────────────────────
function ScreenLogin({ onPhone, onGoogle }) {
  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding:'0 24px' }}>
      <div style={{ flex: 1 }}>
        <div style={{ marginTop: 60, fontFamily:'var(--f-serif)', fontSize: 36, lineHeight: 1, letterSpacing:'-0.02em' }}>
          drape<span style={{ color:'var(--orange)' }}>.</span><span style={{ fontWeight: 600, fontFamily:'var(--f-sans)', fontSize: 28 }}>ai</span>
        </div>
      </div>
      <div style={{ paddingBottom: 40 }}>
        <h1 className="h-display" style={{ fontSize: 38, marginBottom: 6 }}>
          Welcome to <span className="squiggle">drape</span>.
        </h1>
        <div className="sub" style={{ marginBottom: 28 }}>
          AI styling, made for your wardrobe — wherever you are.
        </div>
        <button className="btn secondary" onClick={onGoogle} style={{ marginBottom: 10 }}>
          <IcGoogle/> Continue with Google
        </button>
        <button className="btn primary" onClick={onPhone}>
          <IcPhone size={18}/> Continue with Phone
        </button>
        <div className="caption" style={{ marginTop: 18, textAlign:'center', lineHeight: 1.5 }}>
          By continuing you agree to our <u>Terms</u> and <u>Privacy Policy</u>.
        </div>
      </div>
    </div>
  );
}

// ─── 3a. OTP — phone ────────────────────────────────────────
function ScreenOtpPhone({ onBack, onSend, country, setCountry }) {
  const [num, setNum] = React.useState('98765 43210');
  const ready = num.replace(/\D/g,'').length >= 8;
  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding:'4px 20px 20px' }}>
      <div style={{ marginBottom: 24 }}><BackBtn onClick={onBack}/></div>
      <h1 className="h-large" style={{ fontSize: 26, fontFamily:'var(--f-serif)', fontWeight: 400 }}>Enter your phone</h1>
      <div className="sub" style={{ marginTop: 6, marginBottom: 28 }}>We'll text you a 6-digit code to verify.</div>

      <div style={{ display:'flex', gap: 8 }}>
        <select className="input" value={country} onChange={e => setCountry(e.target.value)} style={{ width: 96, padding:'0 12px', textAlign:'center', fontWeight: 500 }}>
          <option value="+91">🇮🇳 +91</option>
          <option value="+1">🇺🇸 +1</option>
          <option value="+44">🇬🇧 +44</option>
          <option value="+971">🇦🇪 +971</option>
          <option value="+65">🇸🇬 +65</option>
        </select>
        <input className="input" value={num} onChange={e => setNum(e.target.value)} placeholder="98765 43210" style={{ flex: 1 }} inputMode="numeric"/>
      </div>

      <button className="btn primary" disabled={!ready} onClick={onSend} style={{ marginTop: 18 }}>
        Send code
      </button>

      <div style={{ flex: 1 }}/>
      <div className="caption" style={{ textAlign:'center', marginBottom: 12 }}>
        We never share your number.
      </div>
    </div>
  );
}

// ─── 3b. OTP — code ─────────────────────────────────────────
function ScreenOtpCode({ onBack, onVerify, phone }) {
  const [code, setCode] = React.useState(['', '', '', '', '', '']);
  const [t, setT] = React.useState(28);
  const refs = React.useRef([]);

  React.useEffect(() => {
    refs.current[0]?.focus();
  }, []);
  React.useEffect(() => {
    if (t <= 0) return;
    const id = setInterval(() => setT(x => x - 1), 1000);
    return () => clearInterval(id);
  }, [t]);

  const set = (i, v) => {
    if (!/^\d?$/.test(v)) return;
    const nc = [...code]; nc[i] = v; setCode(nc);
    if (v && i < 5) refs.current[i + 1]?.focus();
    if (!v && i > 0) { /* leave focus */ }
    if (nc.every(c => c)) setTimeout(onVerify, 240);
  };
  const onKey = (i, e) => {
    if (e.key === 'Backspace' && !code[i] && i > 0) refs.current[i - 1]?.focus();
  };
  const filled = code.every(c => c);

  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding:'4px 20px 20px' }}>
      <div style={{ marginBottom: 24 }}><BackBtn onClick={onBack}/></div>
      <h1 className="h-large" style={{ fontSize: 26, fontFamily:'var(--f-serif)', fontWeight: 400 }}>Verify your number</h1>
      <div className="sub" style={{ marginTop: 6, marginBottom: 28 }}>
        We sent a code to <span style={{ color:'var(--ink)', fontWeight: 500 }}>{phone}</span>.
      </div>
      <div className="otp-grid">
        {code.map((c, i) => (
          <input key={i} ref={el => refs.current[i] = el} value={c}
            onChange={e => set(i, e.target.value)} onKeyDown={e => onKey(i, e)}
            inputMode="numeric" maxLength={1}
            className="otp-cell"
            data-focus={!c && (i === 0 || code[i-1])}
            style={{ textAlign:'center', outline:'none' }}/>
        ))}
      </div>
      <button className="btn primary" disabled={!filled} onClick={onVerify} style={{ marginTop: 20 }}>Verify</button>
      <div className="caption mono" style={{ textAlign:'center', marginTop: 16 }}>
        {t > 0 ? `Resend code in 0:${String(t).padStart(2,'0')}` : <span style={{ color:'var(--orange)', cursor:'pointer' }} onClick={() => setT(28)}>Resend code</span>}
      </div>
    </div>
  );
}

// ─── 4. Onboarding quiz ─────────────────────────────────────

const QUIZ_GENDER = [
  { k:'w',   name:'Women',  hint:'Dresses, skirts, more', icon:'dress',  tone:'pink' },
  { k:'m',   name:'Men',    hint:'Shirts, jeans, more',   icon:'shirt',  tone:'neutral' },
  { k:'all', name:'Both',   hint:'Mix it up',             icon:'jacket', tone:'lav' },
];

const QUIZ_STYLE = [
  { k:'min',   name:'Minimalist', hint:'clean lines', tone:'neutral', icon: 'tshirt' },
  { k:'street',name:'Streetwear', hint:'bold & loose', tone:'ink', icon: 'hoodie' },
  { k:'class', name:'Classic',    hint:'timeless',     tone:'neutral', icon: 'blazer' },
  { k:'ethnic',name:'Ethnic',     hint:'rooted',       tone:'orange', icon: 'kurta' },
  { k:'boho',  name:'Bohemian',   hint:'relaxed',      tone:'lav', icon: 'dress' },
  { k:'sport', name:'Sporty',     hint:'on the move',  tone:'lime', icon: 'sneaker' },
];
const QUIZ_OCC = [
  { k:'casual', name:'Casual',  icon:'tshirt', tone:'neutral' },
  { k:'work',   name:'Work',    icon:'shirt',  tone:'neutral' },
  { k:'party',  name:'Party',   icon:'blazer', tone:'pink' },
  { k:'gym',    name:'Gym',     icon:'sneaker',tone:'lime' },
  { k:'date',   name:'Date',    icon:'shirt',  tone:'lav' },
  { k:'festive',name:'Festive', icon:'kurta',  tone:'orange' },
  { k:'travel', name:'Travel',  icon:'jacket', tone:'neutral' },
];
const QUIZ_COLORS = [
  { k:'neutral',name:'Neutrals',  swatch:['#D6CFC2','#9C9486'] },
  { k:'earth',  name:'Earth',     swatch:['#7A4A2A','#A6532A'] },
  { k:'pastel', name:'Pastels',   swatch:['#F3D5DD','#D9CCE6'] },
  { k:'bold',   name:'Bold',      swatch:['#C81E3A','#2049A6'] },
  { k:'mono',   name:'Mono',      swatch:['#0B0B0B','#F4F2EC'] },
  { k:'jewel',  name:'Jewel',     swatch:['#066E5C','#7E1A35'] },
];
const QUIZ_FIT = [
  { k:'slim',     name:'Slim',     desc:'Tailored, close to the body' },
  { k:'regular',  name:'Regular',  desc:'A safe middle ground' },
  { k:'relaxed',  name:'Relaxed',  desc:'Easy, room to move' },
  { k:'oversize', name:'Oversized', desc:'Big, intentional, boxy' },
];
const QUIZ_CITIES = [
  ['Mumbai','tropical'], ['Delhi','subtropical'], ['Bangalore','temperate'],
  ['Chennai','tropical'], ['Hyderabad','subtropical'], ['Pune','subtropical'],
  ['London','temperate'], ['New York','temperate'], ['Dubai','arid'], ['Singapore','tropical'],
];

function ProgressTop({ value }) {
  return <div className="progress" style={{ margin:'0 20px' }}><i style={{ width:`${value}%` }}/></div>;
}

function TileWithIcon({ active, onClick, item, tone }) {
  const sil = Silhouettes[item.icon] || Silhouettes.tshirt;
  const tones = { neutral:'#F2F0EA', ink:'#1F1D1A', orange:'#FFE9D6', pink:'#FCE7F3', lime:'#ECFCCB', lav:'#EDE9FE' };
  const bg = tones[item.tone] || tones[tone] || '#F2F0EA';
  const dark = item.tone === 'ink';
  return (
    <div className="tile" data-active={active} onClick={onClick} style={{ position:'relative', overflow:'hidden' }}>
      <div style={{ width: 56, height: 56, borderRadius: 12, background: bg, display:'grid', placeItems:'center' }}>
        <svg viewBox="0 0 104 104" width={42} height={42}>
          <g fill="none" stroke={dark? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.5)'} strokeWidth="2.2" strokeLinejoin="round" strokeLinecap="round">{sil}</g>
        </svg>
      </div>
      <div>
        <div className="label">{item.name}</div>
        {item.hint && <div className="hint">{item.hint}</div>}
      </div>
    </div>
  );
}

function ScreenQuiz({ step, data, setData, onNext, onBack }) {
  const progress = Math.round(step * (100 / 6));
  const heads = [
    'Who are we styling?',
    'What\u2019s your style?',
    'What do you dress for?',
    'Your go-to colors?',
    'How do you like the fit?',
    'Where are you based?',
  ];
  const subs  = [
    'Pick one — we\u2019ll tailor the closet to you.',
    'Pick up to 3 that match you.',
    'Multi-select — these power your daily outfits.',
    'Tones you reach for again and again.',
    'Pick one — you can change it later.',
    'We use this for weather + occasion calls.',
  ];

  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding: '12px 0 24px' }}>
      <ProgressTop value={progress}/>
      <div style={{ padding:'24px 20px 0' }}>
        <BackBtn onClick={onBack}/>
        <h1 className="h-display" style={{ marginTop: 22, fontSize: 30 }}>{heads[step - 1]}</h1>
        <div className="sub" style={{ marginTop: 6, marginBottom: 18 }}>{subs[step - 1]}</div>
      </div>

      <div style={{ flex:1, overflowY:'auto' }} className="hide-sb">
        {step === 1 && (
          <div style={{ padding: '0 20px', display:'flex', flexDirection:'column', gap: 10 }}>
            {QUIZ_GENDER.map(g => {
              const sel = data.gender === g.k;
              const tones = { neutral:'#F2F0EA', orange:'#FFE9D6', pink:'#FCE7F3', lime:'#ECFCCB', lav:'#EDE9FE' };
              const bg = tones[g.tone] || tones.neutral;
              return (
                <div key={g.k} onClick={() => setData({ ...data, gender: g.k })}
                  className="card"
                  style={{
                    display:'flex', alignItems:'center', gap: 16,
                    cursor:'pointer', padding: 16,
                    background: sel ? 'var(--orange-soft)' : 'var(--card)',
                    border: sel ? '2px solid var(--orange)' : '1px solid var(--border)',
                  }}>
                  <div style={{ width: 64, height: 76, borderRadius: 12, background: bg, display:'grid', placeItems:'center', flexShrink: 0 }}>
                    <svg viewBox="0 0 104 104" width={48} height={56}>
                      <g fill="none" stroke="rgba(0,0,0,0.55)" strokeWidth="2.2" strokeLinejoin="round" strokeLinecap="round">{Silhouettes[g.icon]}</g>
                    </svg>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily:'var(--f-serif)', fontSize: 22, lineHeight: 1, letterSpacing:'-0.01em' }}>{g.name}</div>
                    <div className="caption" style={{ marginTop: 4 }}>{g.hint}</div>
                  </div>
                  {sel && <div style={{ width: 28, height: 28, borderRadius:999, background:'var(--orange)', color:'#fff', display:'grid', placeItems:'center', flexShrink: 0 }}><IcCheck size={16} stroke={2.4}/></div>}
                </div>
              );
            })}
            <div className="caption" style={{ marginTop: 10, textAlign:'center', padding: '0 8px' }}>
              You can change this later from your profile.
            </div>
          </div>
        )}
        {step === 2 && (
          <div className="tile-grid">
            {QUIZ_STYLE.map(s => {
              const sel = (data.style || []).includes(s.k);
              return <TileWithIcon key={s.k} item={s} active={sel} onClick={() => {
                const cur = data.style || [];
                const ns = sel ? cur.filter(x => x !== s.k) : (cur.length < 3 ? [...cur, s.k] : cur);
                setData({ ...data, style: ns });
              }}/>;
            })}
          </div>
        )}
        {step === 3 && (
          <div className="tile-grid">
            {QUIZ_OCC.map(s => {
              const sel = (data.occ || []).includes(s.k);
              return <TileWithIcon key={s.k} item={s} active={sel} onClick={() => {
                const cur = data.occ || [];
                const ns = sel ? cur.filter(x => x !== s.k) : [...cur, s.k];
                setData({ ...data, occ: ns });
              }}/>;
            })}
          </div>
        )}
        {step === 4 && (
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap: 14, padding:'8px 20px' }}>
            {QUIZ_COLORS.map(c => {
              const sel = (data.colors || []).includes(c.k);
              return (
                <div key={c.k} style={{ display:'flex', flexDirection:'column', alignItems:'center', gap:8 }}>
                  <div className="swatch" data-active={sel} onClick={() => {
                    const cur = data.colors || [];
                    setData({ ...data, colors: sel ? cur.filter(x => x !== c.k) : [...cur, c.k] });
                  }} style={{ background:`linear-gradient(135deg, ${c.swatch[0]} 0%, ${c.swatch[0]} 50%, ${c.swatch[1]} 50%, ${c.swatch[1]} 100%)`, border: '1px solid var(--border)' }}/>
                  <div style={{ fontSize: 12, fontWeight: 500, color: sel ? 'var(--orange)' : 'var(--ink-2)' }}>{c.name}</div>
                </div>
              );
            })}
          </div>
        )}
        {step === 5 && (
          <div style={{ display:'flex', flexDirection:'column', gap: 10, padding:'0 20px' }}>
            {QUIZ_FIT.map(f => {
              const sel = data.fit === f.k;
              return (
                <div key={f.k} onClick={() => setData({ ...data, fit: f.k })}
                  className="card"
                  style={{ display:'flex', alignItems:'center', gap: 14, cursor:'pointer',
                    borderLeft: sel ? '3px solid var(--orange)' : `1px solid var(--border)`,
                    background: sel ? 'var(--orange-soft)' : 'var(--card)' }}>
                  <div style={{ width: 56, height: 72, borderRadius: 10, background:'#F2F0EA', display:'grid', placeItems:'center' }}>
                    <svg viewBox="0 0 104 104" width={46} height={56}>
                      <g fill="none" stroke="rgba(0,0,0,0.5)" strokeWidth="2" strokeLinejoin="round">
                        {f.k === 'slim' && <path d="M44 18 L60 18 L62 88 L42 88 Z"/>}
                        {f.k === 'regular' && <path d="M40 18 L64 18 L68 88 L36 88 Z"/>}
                        {f.k === 'relaxed' && <path d="M36 18 L68 18 L74 88 L30 88 Z"/>}
                        {f.k === 'oversize' && <path d="M30 18 L74 18 L82 88 L22 88 Z"/>}
                      </g>
                    </svg>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15, fontWeight: 600 }}>{f.name}</div>
                    <div className="caption">{f.desc}</div>
                  </div>
                  {sel && <div style={{ color: 'var(--orange)' }}><IcCheck size={20}/></div>}
                </div>
              );
            })}
          </div>
        )}
        {step === 6 && <QuizCity data={data} setData={setData}/>}
      </div>

      <div style={{ padding:'14px 20px 0' }}>
        <button className="btn primary" onClick={onNext} disabled={step === 1 && !data.gender}>
          {step === 6 ? 'Finish' : 'Next'}
        </button>
      </div>
    </div>
  );
}

function QuizCity({ data, setData }) {
  const [q, setQ] = React.useState(data.city || '');
  const matches = q ? QUIZ_CITIES.filter(([c]) => c.toLowerCase().includes(q.toLowerCase())) : QUIZ_CITIES;
  return (
    <div style={{ padding:'0 20px' }}>
      <input className="input" value={q} onChange={e => setQ(e.target.value)} placeholder="Search city…" style={{ marginBottom: 10 }}/>
      <div className="card hide-sb" style={{ padding: 4, maxHeight: 180, overflowY:'auto' }}>
        {matches.map(([c, cl]) => {
          const sel = data.city === c;
          return (
            <div key={c} onClick={() => setData({ ...data, city: c, climate: cl })}
              style={{ padding:'10px 12px', borderRadius: 10, cursor:'pointer', display:'flex', justifyContent:'space-between',
                background: sel ? 'var(--orange-soft)' : 'transparent', color: sel ? 'var(--orange)' : 'var(--ink)' }}>
              <span style={{ fontWeight: 500, fontSize: 14 }}>{c}</span>
              <span className="caption mono" style={{ textTransform:'uppercase', fontSize: 10 }}>{cl}</span>
            </div>
          );
        })}
      </div>
      {data.climate && (
        <>
          <div className="caption" style={{ marginTop: 22, marginBottom: 8, textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 11 }}>Climate · auto-detected</div>
          <ChipRow items={[['tropical','Tropical'],['subtropical','Subtropical'],['temperate','Temperate'],['arid','Arid'],['cold','Cold']]}
                   value={data.climate} onChange={k => setData({ ...data, climate: k })}/>
        </>
      )}
    </div>
  );
}

// ─── 4.6 Quiz completion ────────────────────────────────────
function ScreenQuizDone({ data, onContinue }) {
  const labels = {
    gender: { w:'Women', m:'Men', all:'Both' },
    style: { min:'Minimalist', street:'Streetwear', class:'Classic', ethnic:'Ethnic', boho:'Boho', sport:'Sporty' },
    occ: { casual:'Casual', work:'Work', party:'Party', gym:'Gym', date:'Date', festive:'Festive', travel:'Travel' },
    colors: { neutral:'Neutrals', earth:'Earth', pastel:'Pastels', bold:'Bold', mono:'Mono', jewel:'Jewel' },
    fit: { slim:'Slim', regular:'Regular', relaxed:'Relaxed', oversize:'Oversized' },
  };
  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding:'40px 20px 24px', position:'relative', overflow:'hidden' }}>
      <Sparkles count={22}/>
      <div style={{ position:'relative', flex: 1 }}>
        <div className="sticker orange" style={{ animation:'pop .5s' }}>✶ all set</div>
        <h1 className="h-display" style={{ fontSize: 36, marginTop: 16 }}>
          You're <span style={{ fontStyle:'italic' }}>ready</span>.
        </h1>
        <div className="sub" style={{ marginTop: 6, marginBottom: 24 }}>Here's the profile we'll style for.</div>

        <div className="card" style={{ padding: 18 }}>
          <SummaryRow label="Styling" chips={data.gender ? [labels.gender[data.gender]] : []}/>
          <div className="divider" style={{ margin:'12px -18px' }}/>
          <SummaryRow label="Style" chips={(data.style || []).map(k => labels.style[k])}/>
          <div className="divider" style={{ margin:'12px -18px' }}/>
          <SummaryRow label="Occasions" chips={(data.occ || []).map(k => labels.occ[k])}/>
          <div className="divider" style={{ margin:'12px -18px' }}/>
          <SummaryRow label="Colors" chips={(data.colors || []).map(k => labels.colors[k])}/>
          <div className="divider" style={{ margin:'12px -18px' }}/>
          <SummaryRow label="Fit" chips={data.fit ? [labels.fit[data.fit]] : []}/>
          <div className="divider" style={{ margin:'12px -18px' }}/>
          <SummaryRow label="Based in" chips={data.city ? [data.city] : []}/>
        </div>
      </div>
      <button className="btn primary" onClick={onContinue}>Start exploring →</button>
    </div>
  );
}
function SummaryRow({ label, chips }) {
  return (
    <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start', gap: 12 }}>
      <div className="caption" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 11, paddingTop: 4, minWidth: 78 }}>{label}</div>
      <div style={{ display:'flex', flexWrap:'wrap', gap: 6, justifyContent:'flex-end', flex: 1 }}>
        {chips.length ? chips.map(c => <span key={c} className="chip sm" data-active={false}>{c}</span>)
          : <span className="caption" style={{ fontStyle:'italic' }}>none</span>}
      </div>
    </div>
  );
}

// ─── 5. Demo choice ─────────────────────────────────────────
function ScreenDemoChoice({ onAdd, onDemo }) {
  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', padding:'32px 20px 24px' }}>
      <div style={{ flex: 1, display:'flex', flexDirection:'column', justifyContent:'center', alignItems:'center', textAlign:'center', gap: 18 }}>
        <FabricBlock tone="neutral" h={180} style={{ width:'100%', display:'grid', placeItems:'center' }}>
          <div style={{ position:'relative', display:'flex', gap: -6 }}>
            <ItemCircle item={WARDROBE[0]} size={86}/>
            <div style={{ width: -22 }}/>
            <ItemCircle item={WARDROBE[3]} size={86}/>
          </div>
          <div style={{ position:'absolute', top: 12, right: 12 }}>
            <span className="sticker pink">step 2</span>
          </div>
        </FabricBlock>
        <div>
          <h1 className="h-display" style={{ fontSize: 32 }}>Let's build your <span style={{ fontStyle:'italic' }}>closet</span>.</h1>
          <div className="sub" style={{ marginTop: 8 }}>Add real clothes for true recommendations, or try a sample wardrobe first.</div>
        </div>
      </div>
      <div style={{ display:'flex', flexDirection:'column', gap: 10 }}>
        <button className="btn primary" onClick={onAdd}>
          <IcPlus size={18}/> Add my clothes
        </button>
        <button className="btn secondary" onClick={onDemo}>Try a demo wardrobe</button>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenSplash, ScreenLogin, ScreenOtpPhone, ScreenOtpCode,
  ScreenQuiz, ScreenQuizDone, ScreenDemoChoice,
  QUIZ_GENDER, QUIZ_STYLE, QUIZ_OCC, QUIZ_COLORS, QUIZ_FIT, QUIZ_CITIES,
});

// components.jsx — shared UI primitives

function TopBar({ title, serif = true, left, right, sub }) {
  return (
    <div className="topbar">
      <div style={{ display:'flex', alignItems:'center', gap: 10, flex: 1, minWidth: 0 }}>
        {left}
        <div style={{ minWidth: 0 }}>
          <h1 style={{ fontFamily: serif ? 'var(--f-serif)' : 'var(--f-sans)', fontWeight: serif ? 400 : 700 }}>{title}</h1>
          {sub && <div className="caption" style={{ marginTop: 2 }}>{sub}</div>}
        </div>
      </div>
      {right && <div className="topbar-actions">{right}</div>}
    </div>
  );
}

function BackBtn({ onClick }) {
  return (
    <button className="icon-btn" onClick={onClick} aria-label="back" style={{ width:36, height:36 }}>
      <IcBack size={20}/>
    </button>
  );
}

function ChipRow({ items, value, onChange, multi = false }) {
  const sel = multi ? new Set(value || []) : value;
  const isActive = (k) => multi ? sel.has(k) : sel === k;
  return (
    <div className="chip-row">
      {items.map(([k, label]) => (
        <button key={k} className="chip" data-active={isActive(k)} onClick={() => {
          if (multi) {
            const ns = new Set(sel);
            ns.has(k) ? ns.delete(k) : ns.add(k);
            onChange?.([...ns]);
          } else { onChange?.(k); }
        }}>{label}</button>
      ))}
    </div>
  );
}

function BottomNav({ active, onChange }) {
  const Tabs = [
    ['wardrobe', 'Wardrobe', IcHanger],
    ['outfits',  'Outfits',  IcSparkle],
    ['looks',    'Lookbooks',IcBookmark],
    ['profile',  'Profile',  IcUser],
  ];
  return (
    <nav className="bottomnav">
      {Tabs.map(([k, label, I]) => (
        <button key={k} data-active={active === k} onClick={() => onChange(k)}>
          <I size={22} stroke={active === k ? 1.9 : 1.6}/>
          <span>{label}</span>
        </button>
      ))}
    </nav>
  );
}

// ─── Generic full-screen scaffolds ───────────────────────────

function Screen({ children, withNav = false, scrollable = true, style }) {
  return (
    <div className={`screen ${withNav?'with-nav':''}`} style={style}>
      {children}
    </div>
  );
}

// Full-bleed colored splash/illustration block
function FabricBlock({ tone = 'orange', children, h = 140, style }) {
  const tones = {
    orange:   ['#FFE9D6', '#FFD3AE'],
    pink:     ['#FCE7F3', '#FBCFE8'],
    lime:     ['#ECFCCB', '#D9F99D'],
    lav:      ['#EDE9FE', '#DDD6FE'],
    neutral:  ['#F2F0EA', '#E7E5DD'],
    ink:      ['#1F1D1A', '#2A2724'],
  };
  const [a, b] = tones[tone] || tones.orange;
  return (
    <div style={{
      height: h, borderRadius: 18, position: 'relative', overflow: 'hidden',
      background: `linear-gradient(135deg, ${a}, ${b})`,
      ...style,
    }}>
      <div className="fabric"/>
      {children}
    </div>
  );
}

// Confetti / sparkle overlay element
function Sparkles({ count = 14, color = 'var(--orange)' }) {
  const dots = React.useMemo(() => Array.from({ length: count }).map((_, i) => ({
    x: Math.random() * 100,
    y: Math.random() * 100,
    s: 3 + Math.random() * 6,
    r: Math.random() * 360,
    c: [color, 'var(--pink)', 'var(--lime)', 'var(--lavender)'][i % 4],
  })), [count]);
  return (
    <div style={{ position:'absolute', inset:0, pointerEvents:'none' }}>
      {dots.map((d, i) => (
        <svg key={i} width={d.s} height={d.s} viewBox="0 0 10 10" style={{
          position:'absolute', left:`${d.x}%`, top:`${d.y}%`, transform:`rotate(${d.r}deg)`,
          color: d.c, animation:`pop .8s ${i*0.04}s both ease-out`,
        }}>
          <path d="M5 0 L6 4 L10 5 L6 6 L5 10 L4 6 L0 5 L4 4 Z" fill="currentColor"/>
        </svg>
      ))}
    </div>
  );
}

// ─── Generated outfits ─────────────────────────────────────

const OCCASIONS = [
  ['casual', 'Casual'], ['work', 'Work'], ['party', 'Party'],
  ['festive', 'Festive'], ['date', 'Date Night'],
];

const OUTFITS = [
  {
    id: 'o1', occasion: 'casual', score: 87, weather: '28° Clear',
    items: ['i1','i3','i5','i14'],
    reason: 'Navy polo with beige chinos — a timeless warm-weather combo. Sneakers keep it easy.',
  },
  {
    id: 'o2', occasion: 'work', score: 92, weather: '24° Mild',
    items: ['w5','w4','w13','w22'],
    reason: 'Silk blouse + pleated midi reads sharp. Ankle boots ground it; a tote pulls it together.',
  },
  {
    id: 'o3', occasion: 'date', score: 95, weather: '22° Cool',
    items: ['w1','w15','w14','w23'],
    reason: 'Slip dress under a denim jacket — soft meets edge. Strappy sandals + silk scarf finish.',
  },
  {
    id: 'o4', occasion: 'casual', score: 81, weather: '28° Clear',
    items: ['w2','w8','i5'],
    reason: 'White tee, mom jeans, white sneakers. The off-duty classic.',
  },
  {
    id: 'o5', occasion: 'party', score: 89, weather: '20° Cool',
    items: ['w10','w16','w6','w11'],
    reason: 'Crop top + mini skirt, leather jacket thrown on, heels. Main-character energy.',
  },
  {
    id: 'o6', occasion: 'work', score: 88, weather: '26° Clear',
    items: ['i2','i7','i12','i21'],
    reason: 'Linen shirt + indigo denim, loafers, steel watch — quiet confidence.',
  },
  {
    id: 'o7', occasion: 'festive', score: 93, weather: '26° Clear',
    items: ['w20','w14','w23'],
    reason: 'Rose lehenga, strappy sandals, silk scarf — ready for an evening event.',
  },
  {
    id: 'o8', occasion: 'casual', score: 84, weather: '18° Cool',
    items: ['w17','w8','w13','w7'],
    reason: 'Knit tank, mom jeans, ankle boots — a cropped cardigan when the breeze picks up.',
  },
  {
    id: 'o9', occasion: 'date', score: 91, weather: '24° Mild',
    items: ['w9','w14','w22'],
    reason: 'Wrap dress + strappy sandals — effortless and considered.',
  },
  {
    id: 'o10', occasion: 'party', score: 90, weather: '22° Cool',
    items: ['i18','i6','i16','i12'],
    reason: 'Pinstripe blazer over a black tee. Black on black with a glint of leather.',
  },
];

function getItem(id) { return WARDROBE.find(i => i.id === id); }

// Outfit card — used in Today's Outfits and Lookbook Detail
function OutfitCard({ outfit, onLike, onDislike, onSave, liked, disliked, saved, variant = 'default' }) {
  const items = outfit.items.map(getItem).filter(Boolean);

  if (variant === 'magazine') {
    return (
      <div className="card ai" style={{ padding: 0, overflow: 'hidden' }}>
        <FabricBlock tone="neutral" h={150} style={{ borderRadius: 0 }}>
          <div style={{ position:'absolute', inset:0, display:'flex', justifyContent:'center', alignItems:'center', gap: 8 }}>
            {items.map(it => <ItemCircle key={it.id} item={it} size={88}/>)}
          </div>
          <div style={{ position:'absolute', top:12, left:12 }}>
            <span className="sticker ink">{outfit.occasion}</span>
          </div>
          <div style={{ position:'absolute', top:12, right:12 }}>
            <span className="score-pill">{outfit.score}</span>
          </div>
        </FabricBlock>
        <div style={{ padding: 16 }}>
          <div className="sub" style={{ fontFamily:'var(--f-serif)', fontSize: 17, color: 'var(--ink)', lineHeight: 1.3 }}>
            "{outfit.reason}"
          </div>
          <div style={{ display:'flex', gap:6, marginTop:14, justifyContent: 'flex-end' }}>
            <CardAction icon={IcThumbUp} active={liked} color="var(--lime)" onClick={onLike}/>
            <CardAction icon={IcThumbDown} active={disliked} color="var(--red)" onClick={onDislike}/>
            <CardAction icon={IcBookmark} active={saved} color="var(--orange)" onClick={onSave}/>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="card ai">
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom: 12 }}>
        <div style={{ display:'flex', gap:6, alignItems:'center' }}>
          <span className="sticker outline" style={{ textTransform: 'capitalize' }}>{outfit.occasion}</span>
          <span className="caption">· {outfit.weather}</span>
        </div>
        <span className="score-pill">
          <svg width="11" height="11" viewBox="0 0 12 12"><path d="M6 1 L7.5 4.5 L11 5 L8.5 7.5 L9 11 L6 9.3 L3 11 L3.5 7.5 L1 5 L4.5 4.5 Z" fill="currentColor"/></svg>
          {outfit.score}
        </span>
      </div>
      <div style={{ display:'flex', gap:8, justifyContent:'center', marginBottom: 14 }}>
        {items.map(it => <ItemCircle key={it.id} item={it} size={64}/>)}
      </div>
      <div style={{ fontSize:13.5, color:'var(--ink-2)', fontStyle:'italic', lineHeight:1.45, marginBottom: 14, textAlign:'center', padding:'0 4px' }}>
        "{outfit.reason}"
      </div>
      <div className="divider" style={{ margin: '0 -16px 12px' }}/>
      <div style={{ display:'flex', justifyContent:'space-around' }}>
        <CardAction icon={IcThumbUp} active={liked} color="var(--lime)" onClick={onLike} label="Love"/>
        <CardAction icon={IcThumbDown} active={disliked} color="var(--red)" onClick={onDislike} label="Pass"/>
        <CardAction icon={IcBookmark} active={saved} color="var(--orange)" onClick={onSave} label="Save"/>
      </div>
    </div>
  );
}

function CardAction({ icon: I, active, color, onClick, label }) {
  return (
    <button onClick={(e) => { e.stopPropagation(); onClick?.(); }} style={{
      background: 'transparent', border: 0, cursor: 'pointer',
      display: 'flex', alignItems: 'center', gap: 6,
      padding: '6px 12px', borderRadius: 10,
      color: active ? color : 'var(--ink-3)',
      fontSize: 12, fontWeight: 600,
      transition: 'color .2s',
    }}>
      <I size={20} stroke={active ? 2 : 1.7} fill={active ? color : 'none'}/>
      {label && <span>{label}</span>}
    </button>
  );
}

Object.assign(window, {
  TopBar, BackBtn, ChipRow, BottomNav, Screen, FabricBlock, Sparkles,
  OCCASIONS, OUTFITS, getItem, OutfitCard, CardAction,
});

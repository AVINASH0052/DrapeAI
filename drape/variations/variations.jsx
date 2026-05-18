// variations.jsx — design canvas with multi-direction explorations

// Reusable mini-screen frame inside an artboard (no device chrome — DC supplies that)
function ScreenFrame({ children, bg = 'var(--bg)' }) {
  return (
    <div style={{
      width: 393, height: 800,
      background: bg, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      fontFamily: 'var(--f-sans)',
      color: 'var(--ink)',
      borderRadius: 12,
      border: '1px solid var(--border)',
    }}>
      <div style={{ height: 36 }}/>
      {children}
    </div>
  );
}

// ─── Wardrobe variations ──────────────────────────────

function WardrobeGrid3Col() {
  return (
    <ScreenFrame>
      <TopBar title="Wardrobe" right={<>
        <button className="icon-btn"><IcSearch size={20}/></button>
        <button className="icon-btn"><IcBell size={20}/></button>
      </>}/>
      <ChipRow items={[['all','All'],['top','Tops'],['bottom','Bottoms'],['ethnic','Ethnic'],['footwear','Footwear']]} value="all" onChange={()=>{}}/>
      <div style={{ padding: '0 20px 10px' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 11 }}>24 items</div>
      </div>
      <div className="wardrobe-grid">
        {WARDROBE.slice(0, 15).map(it => <ItemTile key={it.id} item={it} label={false}/>)}
      </div>
    </ScreenFrame>
  );
}

function WardrobeBento() {
  // Bento: items sized by category importance
  const sizes = [
    { item: WARDROBE[3], span: 'col 1 / 3 / row 1 / 3' }, // big — featured (kurta)
    { item: WARDROBE[4] },
    { item: WARDROBE[6], span: 'col 3 / 4 / row 2 / 4' },
    { item: WARDROBE[8] },
    { item: WARDROBE[10] },
    { item: WARDROBE[11] },
    { item: WARDROBE[1] },
    { item: WARDROBE[17] },
  ];
  return (
    <ScreenFrame>
      <TopBar title="Wardrobe" right={<><button className="icon-btn"><IcSearch size={20}/></button></>}/>
      <ChipRow items={[['all','All'],['top','Tops'],['ethnic','Ethnic']]} value="all" onChange={()=>{}}/>
      <div style={{ padding: '0 20px 10px', display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 22 }}>Most worn</div>
        <div className="caption mono">this week</div>
      </div>
      <div style={{ padding: '0 20px', display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gridAutoRows:'94px', gap: 8 }}>
        <div style={{ gridColumn: '1 / 3', gridRow: '1 / 3', background: WARDROBE[3].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[3]} radius={14}/>
          <div style={{ position:'absolute', bottom:8, left:10, color:'#fff', fontFamily:'var(--f-serif)', fontSize: 18, mixBlendMode:'difference' }}>{WARDROBE[3].name}</div>
        </div>
        <div style={{ background: WARDROBE[4].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[4]} radius={14}/>
        </div>
        <div style={{ background: WARDROBE[6].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[6]} radius={14}/>
        </div>
        <div style={{ gridColumn:'1 / 2', background: WARDROBE[8].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[8]} radius={14}/>
        </div>
        <div style={{ background: WARDROBE[10].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[10]} radius={14}/>
        </div>
        <div style={{ background: WARDROBE[11].color, borderRadius: 14, position:'relative', overflow:'hidden' }}>
          <ItemSvg item={WARDROBE[11]} radius={14}/>
        </div>
      </div>
      <div style={{ padding: '20px 20px 8px', display:'flex', alignItems:'baseline', justifyContent:'space-between' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 22 }}>All items</div>
        <div className="caption mono">24 total</div>
      </div>
      <div className="wardrobe-grid">
        {WARDROBE.slice(12, 18).map(it => <ItemTile key={it.id} item={it} label={false}/>)}
      </div>
    </ScreenFrame>
  );
}

function WardrobeEditorial() {
  // Editorial: large hero, bold serif numbers, magazine-style
  return (
    <ScreenFrame>
      <div style={{ padding:'14px 20px 0', display:'flex', justifyContent:'space-between', alignItems:'center' }}>
        <div style={{ display:'flex', alignItems:'baseline', gap: 10 }}>
          <span style={{ fontFamily:'var(--f-serif)', fontSize: 32, fontStyle:'italic' }}>The</span>
          <span style={{ fontFamily:'var(--f-sans)', fontSize: 30, fontWeight: 700, letterSpacing:'-0.03em' }}>WARDROBE</span>
        </div>
        <button className="icon-btn"><IcSearch size={20}/></button>
      </div>
      <div style={{ padding:'4px 20px 16px', display:'flex', justifyContent:'space-between', alignItems:'center', borderBottom:'1px solid var(--border)' }}>
        <div className="caption mono" style={{ fontSize: 10, letterSpacing:'0.12em' }}>VOL. 01 · MAR 2026</div>
        <div className="caption mono" style={{ fontSize: 10, letterSpacing:'0.12em' }}>24 PIECES</div>
      </div>
      <div style={{ padding:'18px 20px 12px' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', fontSize: 10, letterSpacing:'0.12em' }}>Cover piece · 01</div>
        <div style={{ marginTop: 6, position:'relative', borderRadius: 14, overflow:'hidden', height: 280, background: WARDROBE[3].color }}>
          <ItemSvg item={WARDROBE[3]} radius={14}/>
          <div style={{ position:'absolute', bottom:14, left:14, right:14, color:'#fff', mixBlendMode:'difference' }}>
            <div style={{ fontFamily:'var(--f-serif)', fontSize: 28, lineHeight: 1 }}>{WARDROBE[3].name}</div>
            <div className="mono" style={{ fontSize: 10, marginTop:6, opacity:.9, letterSpacing:'0.1em', textTransform:'uppercase' }}>Ethnic · in 4 outfits</div>
          </div>
        </div>
      </div>
      <div style={{ padding:'12px 20px', display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 20 }}>The Edit.</div>
        <div className="caption mono" style={{ fontSize: 10, letterSpacing:'0.12em' }}>SEE ALL ›</div>
      </div>
      <div style={{ padding:'0 20px', display:'grid', gridTemplateColumns:'1fr 1fr', gap: 8 }}>
        {[WARDROBE[8], WARDROBE[6], WARDROBE[17], WARDROBE[18]].map((it, i) => (
          <div key={it.id} style={{ position:'relative' }}>
            <div style={{ aspectRatio: '4 / 5', borderRadius: 12, background: it.color, position:'relative', overflow:'hidden' }}>
              <ItemSvg item={it} radius={12}/>
            </div>
            <div style={{ display:'flex', justifyContent:'space-between', marginTop:6, alignItems:'baseline' }}>
              <div style={{ fontFamily:'var(--f-serif)', fontSize: 14, fontStyle:'italic' }}>{it.name}</div>
              <div className="mono" style={{ fontSize: 10, color:'var(--ink-3)' }}>0{i+2}</div>
            </div>
          </div>
        ))}
      </div>
    </ScreenFrame>
  );
}

// ─── Outfit Card variations ──────────────────────────────

function OutfitCardWrapper({ children }) {
  return (
    <ScreenFrame bg="#F0EDE7">
      <div style={{ padding:'14px 20px 8px' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.12em', fontSize: 10, color:'var(--ink-3)' }}>outfit card</div>
      </div>
      <div style={{ padding: '8px 20px 24px' }}>{children}</div>
    </ScreenFrame>
  );
}

function OutfitCardDefault() {
  const o = OUTFITS[0];
  return (
    <OutfitCardWrapper>
      <OutfitCard outfit={o} liked saved={false} variant="default" onLike={()=>{}} onDislike={()=>{}} onSave={()=>{}}/>
    </OutfitCardWrapper>
  );
}

function OutfitCardEditorial() {
  const o = OUTFITS[2];
  return (
    <OutfitCardWrapper>
      <OutfitCard outfit={o} saved variant="magazine" onLike={()=>{}} onDislike={()=>{}} onSave={()=>{}}/>
    </OutfitCardWrapper>
  );
}

function OutfitCardSticker() {
  const o = OUTFITS[4];
  const items = o.items.map(getItem).filter(Boolean);
  return (
    <OutfitCardWrapper>
      <div className="card" style={{ padding: 0, position:'relative', overflow:'hidden', border:'2px solid var(--ink)', borderRadius: 18 }}>
        <div style={{ position:'absolute', top: 12, right: -8, transform:'rotate(8deg)', zIndex: 2 }}>
          <span style={{ display:'inline-block', background:'var(--orange)', color:'#fff', padding:'6px 14px 4px', fontFamily:'var(--f-serif)', fontSize: 22, fontStyle:'italic', borderRadius: 999, boxShadow:'0 2px 8px rgba(0,0,0,0.15)' }}>
            {o.score}
          </span>
        </div>
        <div style={{ position:'absolute', top: 14, left: 14, zIndex: 2 }}>
          <span className="sticker pink">night out</span>
        </div>
        <div style={{ background:'#1A1A1A', padding:'40px 20px 28px', position:'relative' }}>
          <div style={{ display:'flex', justifyContent:'center', gap: 14 }}>
            {items.map((it, i) => (
              <div key={it.id} style={{
                width: 80, height: 90, borderRadius: 12, background: it.color, position:'relative', overflow:'hidden',
                transform:`rotate(${(i - 1.5) * 4}deg) translateY(${Math.abs(i - 1.5) * 4}px)`,
                boxShadow:'0 6px 16px rgba(0,0,0,0.3)',
              }}>
                <ItemSvg item={it} radius={12}/>
              </div>
            ))}
          </div>
        </div>
        <div style={{ padding:'16px 18px 14px', background:'var(--card)' }}>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 22, lineHeight: 1.15, letterSpacing:'-0.01em' }}>
            "{o.reason}"
          </div>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginTop: 14 }}>
            <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.08em' }}>{o.weather}</div>
            <div style={{ display:'flex', gap: 4 }}>
              <CardAction icon={IcThumbUp} color="var(--lime)"/>
              <CardAction icon={IcBookmark} active color="var(--orange)"/>
            </div>
          </div>
        </div>
      </div>
    </OutfitCardWrapper>
  );
}

// ─── Onboarding step 1 variations ────────────────────────

function OnboardDefault() {
  return (
    <ScreenFrame>
      <div style={{ padding:'10px 0 0' }}><div className="progress" style={{ margin:'0 20px' }}><i style={{ width:'20%' }}/></div></div>
      <div style={{ padding: '20px 20px 0' }}>
        <BackBtn/>
        <h1 className="h-display" style={{ marginTop: 22, fontSize: 30 }}>What's your style?</h1>
        <div className="sub" style={{ marginTop: 6, marginBottom: 18 }}>Pick up to 3 that match you.</div>
      </div>
      <div className="tile-grid">
        {QUIZ_STYLE.map((s, i) => <TileWithIcon key={s.k} item={s} active={i < 2}/>)}
      </div>
      <div style={{ padding:'18px 20px' }}><button className="btn primary">Next</button></div>
    </ScreenFrame>
  );
}

function OnboardFullBleed() {
  return (
    <ScreenFrame bg="#F0EDE7">
      <div style={{ padding:'10px 0 0' }}><div className="progress" style={{ margin:'0 20px' }}><i style={{ width:'20%' }}/></div></div>
      <div style={{ padding: '22px 20px 0', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <BackBtn/>
        <span className="caption mono">1 / 5</span>
      </div>
      <div style={{ padding: '24px 20px 12px' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 40, lineHeight: 1.02, letterSpacing:'-0.02em' }}>
          What's your <span style={{ fontStyle:'italic' }}>aesthetic</span>?
        </div>
        <div className="sub" style={{ marginTop: 8 }}>Tap to pick — up to three.</div>
      </div>
      <div style={{ flex: 1, overflowY:'auto', padding: '8px 20px 0' }}>
        {QUIZ_STYLE.slice(0, 4).map((s, i) => {
          const tones = { neutral:'#F2F0EA', ink:'#1F1D1A', orange:'#FFE9D6', pink:'#FCE7F3', lime:'#ECFCCB', lav:'#EDE9FE' };
          const bg = tones[s.tone];
          const sel = i < 2;
          return (
            <div key={s.k} style={{
              background: bg, borderRadius: 18, padding: 16, marginBottom: 10,
              display:'flex', alignItems:'center', gap: 14, position:'relative',
              border: sel ? '2px solid var(--orange)' : '2px solid transparent',
              minHeight: 84,
            }}>
              <svg viewBox="0 0 104 104" width={56} height={64} style={{ flexShrink:0 }}>
                <g fill="none" stroke="rgba(0,0,0,0.55)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round">{Silhouettes[s.icon] || Silhouettes.tshirt}</g>
              </svg>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily:'var(--f-serif)', fontSize: 22 }}>{s.name}</div>
                <div className="caption" style={{ marginTop: 2 }}>{s.hint}</div>
              </div>
              {sel && <div style={{ width: 28, height: 28, borderRadius:999, background:'var(--orange)', color:'#fff', display:'grid', placeItems:'center' }}><IcCheck size={16} stroke={2.4}/></div>}
            </div>
          );
        })}
      </div>
      <div style={{ padding:'12px 20px' }}><button className="btn primary">Continue →</button></div>
    </ScreenFrame>
  );
}

function OnboardScroller() {
  const items = [...QUIZ_STYLE, ...QUIZ_STYLE]; // duplicate for visual length
  return (
    <ScreenFrame>
      <div style={{ padding:'10px 0 0' }}><div className="progress" style={{ margin:'0 20px' }}><i style={{ width:'20%' }}/></div></div>
      <div style={{ padding: '22px 20px 0' }}><BackBtn/></div>
      <div style={{ padding: '14px 20px 0' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.1em', fontSize: 10 }}>your style</div>
        <h1 className="h-display" style={{ marginTop: 4, fontSize: 32 }}>Pick three.</h1>
      </div>
      <div style={{ marginTop: 18, flex: 1, overflowX:'auto', display:'flex', gap: 14, padding:'12px 20px', alignItems:'center' }}>
        {QUIZ_STYLE.map((s, i) => {
          const tones = { neutral:'#F2F0EA', ink:'#1F1D1A', orange:'#FFE9D6', pink:'#FCE7F3', lime:'#ECFCCB', lav:'#EDE9FE' };
          const bg = tones[s.tone];
          const isFocus = i === 2;
          return (
            <div key={s.k} style={{
              width: 220, height: 320, flexShrink:0,
              background: bg, borderRadius: 22, padding: 18,
              display:'flex', flexDirection:'column', justifyContent:'space-between',
              transform: isFocus ? 'scale(1.02)' : 'scale(0.94)',
              opacity: isFocus ? 1 : 0.7,
              boxShadow: isFocus ? '0 14px 30px rgba(0,0,0,0.08)' : 'none',
              border: isFocus ? '2px solid var(--orange)' : '1px solid var(--border)',
            }}>
              <span className="sticker outline" style={{ width:'fit-content' }}>0{i+1}</span>
              <svg viewBox="0 0 104 104" width={120} height={140} style={{ alignSelf:'center' }}>
                <g fill="none" stroke="rgba(0,0,0,0.5)" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round">{Silhouettes[s.icon] || Silhouettes.tshirt}</g>
              </svg>
              <div>
                <div style={{ fontFamily:'var(--f-serif)', fontSize: 28, lineHeight: 1 }}>{s.name}</div>
                <div className="caption" style={{ marginTop: 6 }}>{s.hint}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{ padding:'10px 20px', display:'flex', justifyContent:'center', gap: 6 }}>
        {[0,1,2,3,4,5].map(i => <span key={i} style={{ width: i === 2 ? 24 : 6, height: 6, borderRadius: 999, background: i === 2 ? 'var(--orange)' : 'var(--border-strong)' }}/>)}
      </div>
      <div style={{ padding:'8px 20px 16px' }}><button className="btn primary">Next →</button></div>
    </ScreenFrame>
  );
}

// ─── Splash variations ───────────────────────────────────

function SplashA() {
  return (
    <ScreenFrame>
      <div style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', position:'relative', overflow:'hidden' }}>
        <div style={{ position:'absolute', top:'18%', left:'-10%', width:220, height:220, borderRadius:'50%', background:'var(--orange-soft)', filter:'blur(40px)', opacity:.7 }}/>
        <div style={{ position:'absolute', bottom:'14%', right:'-12%', width:240, height:240, borderRadius:'50%', background:'var(--lavender-soft)', filter:'blur(40px)', opacity:.6 }}/>
        <div style={{ position:'relative', display:'flex', flexDirection:'column', alignItems:'center', gap: 10 }}>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 56, lineHeight:1, letterSpacing:'-0.03em' }}>
            drape<span style={{ color:'var(--orange)' }}>.</span><span style={{ fontWeight: 600, fontFamily:'var(--f-sans)', fontSize: 44, marginLeft: -2 }}>ai</span>
          </div>
          <div className="sub" style={{ letterSpacing:'0.08em', textTransform:'uppercase', fontSize: 11 }}>your ai outfit assistant</div>
        </div>
      </div>
    </ScreenFrame>
  );
}

function SplashB() {
  return (
    <ScreenFrame bg="#1A1A1A">
      <div style={{ flex:1, position:'relative', color:'#fff', padding:'40px 28px' }}>
        <div style={{ position:'absolute', top:40, left:28, right:28, display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
          <span className="mono" style={{ fontSize: 11, letterSpacing:'0.1em', opacity:.6 }}>2026 · V1</span>
          <span className="mono" style={{ fontSize: 11, letterSpacing:'0.1em', opacity:.6 }}>READY</span>
        </div>
        <div style={{ position:'absolute', inset: 0, display:'flex', alignItems:'center', justifyContent:'center' }}>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 96, lineHeight: 0.85, letterSpacing:'-0.04em', textAlign:'center' }}>
            <span style={{ fontStyle:'italic' }}>drape</span><span style={{ color:'var(--orange)' }}>.</span>
            <div style={{ fontFamily:'var(--f-sans)', fontWeight: 700, fontSize: 88, marginTop: -10 }}>ai</div>
          </div>
        </div>
        <div style={{ position:'absolute', bottom:40, left:28, right:28, textAlign:'center' }}>
          <div style={{ fontSize: 13, opacity:.8, fontFamily:'var(--f-serif)', fontStyle:'italic' }}>An AI stylist for your closet.</div>
        </div>
      </div>
    </ScreenFrame>
  );
}

function SplashC() {
  // Wardrobe peek: show a layered preview
  return (
    <ScreenFrame bg="#F0EDE7">
      <div style={{ flex:1, position:'relative', overflow:'hidden' }}>
        <div style={{ position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center' }}>
          {[WARDROBE[3], WARDROBE[11], WARDROBE[4]].map((it, i) => (
            <div key={it.id} style={{
              width: 130, height: 150, borderRadius: 14, background: it.color,
              position:'absolute', overflow:'hidden',
              transform: `translate(${(i-1)*60}px, ${(i%2?16:-12)}px) rotate(${(i-1)*8}deg)`,
              boxShadow:'0 10px 28px rgba(0,0,0,0.12)',
            }}>
              <ItemSvg item={it} radius={14}/>
            </div>
          ))}
        </div>
        <div style={{ position:'absolute', bottom: 60, left: 24, right: 24, textAlign:'center' }}>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 48, letterSpacing:'-0.02em', lineHeight: 1 }}>
            drape<span style={{ color:'var(--orange)' }}>.</span><span style={{ fontFamily:'var(--f-sans)', fontWeight:700, fontSize: 38 }}>ai</span>
          </div>
          <div className="sub" style={{ marginTop: 8 }}>Style your closet — anywhere in the world.</div>
        </div>
      </div>
    </ScreenFrame>
  );
}

// ─── Today's Outfits screen variations ─────────────────

function TodayDefault() {
  return (
    <ScreenFrame>
      <TopBar title="Today" sub="Mumbai · 28° clear" right={<button className="icon-btn"><IcShuffle size={20}/></button>}/>
      <ChipRow items={[['casual','Casual'],['work','Work'],['party','Party']]} value="casual" onChange={()=>{}}/>
      <div style={{ padding:'0 20px', display:'flex', flexDirection:'column', gap: 14 }}>
        <OutfitCard outfit={OUTFITS[0]} variant="default" liked saved={false} onLike={()=>{}} onDislike={()=>{}} onSave={()=>{}}/>
      </div>
    </ScreenFrame>
  );
}

function TodayHero() {
  // Single hero "today's pick" + smaller alternates
  const o = OUTFITS[0]; const items = o.items.map(getItem);
  return (
    <ScreenFrame>
      <div style={{ padding:'12px 20px 4px', display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
        <div>
          <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.12em', fontSize: 10 }}>thursday · march 20</div>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 30, lineHeight: 1, marginTop: 2 }}>Today's <span style={{ fontStyle:'italic' }}>pick</span>.</div>
        </div>
        <div className="weather-pill"><IcSun size={14}/> 28°</div>
      </div>
      <div style={{ padding:'14px 20px' }}>
        <div style={{ borderRadius: 22, overflow:'hidden', background:'#F0EDE7', position:'relative', padding: 16, border:'1px solid var(--border)' }}>
          <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between' }}>
            <span className="sticker ink">#1 today</span>
            <span className="score-pill lg">{o.score}</span>
          </div>
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap: 8, marginTop: 14 }}>
            {items.slice(0,4).map(it => (
              <div key={it.id} style={{ aspectRatio:'1/1', borderRadius:12, background:it.color, position:'relative', overflow:'hidden' }}>
                <ItemSvg item={it} radius={12}/>
              </div>
            ))}
          </div>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 20, lineHeight: 1.2, marginTop: 14 }}>"{o.reason}"</div>
          <div style={{ display:'flex', gap: 8, marginTop: 12 }}>
            <button className="btn primary sm" style={{ flex: 1 }}>Wear this</button>
            <button className="btn secondary sm" style={{ flex: 1 }}><IcShuffle size={16}/> Shuffle</button>
          </div>
        </div>
      </div>
      <div style={{ padding:'0 20px', display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 18 }}>Other ideas</div>
        <span className="caption mono">5 more</span>
      </div>
      <div style={{ padding:'10px 20px', display:'flex', gap: 10, overflowX:'auto' }}>
        {OUTFITS.slice(1, 4).map(oo => (
          <div key={oo.id} style={{ width: 140, flexShrink:0, borderRadius: 14, border:'1px solid var(--border)', padding: 10 }}>
            <div style={{ display:'flex', gap: 4 }}>
              {oo.items.slice(0,3).map(id => {
                const it = getItem(id);
                return <div key={id} style={{ flex:1, aspectRatio:'1/1.2', borderRadius:8, background: it.color, position:'relative', overflow:'hidden' }}><ItemSvg item={it} radius={8}/></div>;
              })}
            </div>
            <div style={{ marginTop: 8, display:'flex', justifyContent:'space-between', alignItems:'baseline' }}>
              <div style={{ fontFamily:'var(--f-serif)', fontSize: 13, textTransform:'capitalize' }}>{oo.occasion}</div>
              <span className="score-pill" style={{ height: 20, fontSize: 11, padding:'0 8px' }}>{oo.score}</span>
            </div>
          </div>
        ))}
      </div>
    </ScreenFrame>
  );
}

// ─── The canvas ─────────────────────────────────────────

function Variations() {
  return (
    <DesignCanvas>
      <DCSection id="splash" title="01 · Splash" subtitle="The first frame — three takes">
        <DCArtboard id="splash-a" label="A · Ambient" width={393} height={800}><SplashA/></DCArtboard>
        <DCArtboard id="splash-b" label="B · Editorial dark" width={393} height={800}><SplashB/></DCArtboard>
        <DCArtboard id="splash-c" label="C · Wardrobe peek" width={393} height={800}><SplashC/></DCArtboard>
      </DCSection>

      <DCSection id="onboard" title="04 · Onboarding — Style step" subtitle="Three patterns for picking aesthetic tags">
        <DCArtboard id="onb-a" label="A · Tile grid (spec)" width={393} height={800}><OnboardDefault/></DCArtboard>
        <DCArtboard id="onb-b" label="B · Full-bleed cards" width={393} height={800}><OnboardFullBleed/></DCArtboard>
        <DCArtboard id="onb-c" label="C · Horizontal scroller" width={393} height={800}><OnboardScroller/></DCArtboard>
      </DCSection>

      <DCSection id="wardrobe" title="06 · Wardrobe" subtitle="Grid density vs. editorial hierarchy">
        <DCArtboard id="w-a" label="A · 3-col grid (spec)" width={393} height={800}><WardrobeGrid3Col/></DCArtboard>
        <DCArtboard id="w-b" label="B · Bento — most worn" width={393} height={800}><WardrobeBento/></DCArtboard>
        <DCArtboard id="w-c" label="C · Editorial cover" width={393} height={800}><WardrobeEditorial/></DCArtboard>
      </DCSection>

      <DCSection id="outfit-card" title="12 · Outfit card" subtitle="Three card directions">
        <DCArtboard id="oc-a" label="A · Default — chip + circles" width={393} height={680}><OutfitCardDefault/></DCArtboard>
        <DCArtboard id="oc-b" label="B · Editorial magazine" width={393} height={680}><OutfitCardEditorial/></DCArtboard>
        <DCArtboard id="oc-c" label="C · Sticker / chunky" width={393} height={680}><OutfitCardSticker/></DCArtboard>
      </DCSection>

      <DCSection id="today" title="12 · Today's outfits" subtitle="Default vs hero-pick treatment">
        <DCArtboard id="t-a" label="A · Stacked cards (spec)" width={393} height={800}><TodayDefault/></DCArtboard>
        <DCArtboard id="t-b" label="B · Hero + alternates" width={393} height={800}><TodayHero/></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<Variations/>);

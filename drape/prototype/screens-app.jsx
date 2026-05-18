// screens-app.jsx — wardrobe, camera flow, outfits, lookbooks, profile, sheets, search

// ─── 6. Wardrobe Grid ───────────────────────────────────────
function ScreenWardrobe({ filter, setFilter, onItem, onAdd, onSearch, onAddItem, items, gender }) {
  let filtered = filter === 'all' ? items : items.filter(i => i.cat === filter);
  if (gender && gender !== 'all') filtered = filtered.filter(i => i.g === gender || i.g === 'u');
  const cats = [['all','All'], ['top','Tops'], ['bottom','Bottoms'], ['dress','Dresses'], ['outer','Outerwear'], ['ethnic','Ethnic'], ['footwear','Footwear'], ['accessory','Accessories']];
  return (
    <>
      <TopBar title="Wardrobe" right={<>
        <button className="icon-btn" onClick={onSearch}><IcSearch size={20}/></button>
        <button className="icon-btn" onClick={() => {}}><IcBell size={20}/></button>
      </>}/>
      <ChipRow items={cats} value={filter} onChange={setFilter}/>
      <div style={{ padding:'0 20px 10px', display:'flex', justifyContent:'space-between', alignItems:'center', flexShrink: 0, gap: 12 }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 11, whiteSpace: 'nowrap' }}>
          {filtered.length} items
        </div>
        <div className="caption" style={{ whiteSpace: 'nowrap' }}>Last added · Mar 20</div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', paddingBottom: 100 }} className="hide-sb">
        <div className="wardrobe-grid">
          {filtered.map(it => <ItemTile key={it.id} item={it} onClick={() => onItem(it)} label={false}/>)}
        </div>
      </div>
      <button className="fab" onClick={onAddItem} aria-label="add"><IcPlus size={24}/></button>
    </>
  );
}

// ─── 7. Wardrobe Empty ──────────────────────────────────────
function ScreenWardrobeEmpty({ onAddItem }) {
  return (
    <>
      <TopBar title="Wardrobe" right={
        <button className="icon-btn"><IcBell size={20}/></button>
      }/>
      <div style={{ flex: 1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'0 32px', textAlign:'center', gap: 18 }}>
        <div style={{ width: 88, height: 88, borderRadius: 999, background:'var(--bg-warm)', display:'grid', placeItems:'center', color:'var(--ink-3)' }}>
          <IcHanger size={44} stroke={1.4}/>
        </div>
        <div>
          <h2 className="h-display" style={{ fontSize: 26 }}>An empty closet.</h2>
          <div className="sub" style={{ marginTop: 6 }}>Add your first item and we'll start suggesting outfits.</div>
        </div>
        <button className="btn primary" style={{ maxWidth: 220 }} onClick={onAddItem}>
          <IcPlus size={18}/> Add an item
        </button>
      </div>
    </>
  );
}

// ─── 18. Wardrobe Search ────────────────────────────────────
function ScreenSearch({ onBack, items }) {
  const [q, setQ] = React.useState('kurta');
  const filtered = items.filter(i =>
    i.name.toLowerCase().includes(q.toLowerCase()) ||
    i.sub.toLowerCase().includes(q.toLowerCase()) ||
    i.cat.toLowerCase().includes(q.toLowerCase())
  );
  return (
    <>
      <div style={{ padding:'8px 16px', display:'flex', alignItems:'center', gap: 10 }}>
        <BackBtn onClick={onBack}/>
        <div style={{ flex: 1, position:'relative' }}>
          <IcSearch size={18} style={{ position:'absolute', left: 12, top: '50%', transform:'translateY(-50%)', color:'var(--ink-3)' }}/>
          <input className="input" autoFocus value={q} onChange={e => setQ(e.target.value)}
            placeholder="Search your wardrobe" style={{ paddingLeft: 38, paddingRight: 38, height: 44 }}/>
          {q && <button onClick={() => setQ('')} style={{ position:'absolute', right:6, top:'50%', transform:'translateY(-50%)', background:'transparent', border:0, color:'var(--ink-3)', cursor:'pointer' }}><IcClose size={18}/></button>}
        </div>
      </div>
      <div style={{ padding:'0 20px 10px' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 11 }}>
          {filtered.length} matches for "{q}"
        </div>
      </div>
      {filtered.length === 0 ? (
        <div style={{ flex: 1, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', padding:'0 32px', textAlign:'center' }}>
          <div className="h-med">No items match "{q}"</div>
          <div className="sub" style={{ marginTop: 6 }}>Try a category or color.</div>
        </div>
      ) : (
        <div className="wardrobe-grid">
          {filtered.map(it => <ItemTile key={it.id} item={it} onClick={() => {}} label={false}/>)}
        </div>
      )}
    </>
  );
}

// ─── 8. Camera ──────────────────────────────────────────────
function ScreenCamera({ onBack, onShoot }) {
  const tips = [
    'Lay flat on a plain surface',
    'Soft natural light works best',
    'Fill the frame, leave a little margin',
    'No hangers — just the item',
  ];
  const [t, setT] = React.useState(0);
  React.useEffect(() => { const id = setInterval(() => setT(x => (x + 1) % tips.length), 2400); return () => clearInterval(id); }, []);
  return (
    <div style={{ flex:1, position:'relative', background:'#0E0D0C', display:'flex', flexDirection:'column' }}>
      {/* simulated camera preview */}
      <div style={{ position:'absolute', inset:0, background:'radial-gradient(circle at 50% 40%, #2a2724 0%, #0E0D0C 70%)' }}>
        <div style={{ position:'absolute', inset:0, opacity:.2, background:'repeating-linear-gradient(0deg, transparent 0 3px, rgba(255,255,255,0.04) 3px 4px)' }}/>
      </div>
      <div className="cam-frame"/>

      {/* faint silhouette behind dashed frame to suggest item */}
      <div style={{ position:'absolute', left:'30%', right:'30%', top:'34%', bottom:'40%', display:'grid', placeItems:'center', opacity:.18 }}>
        <svg viewBox="0 0 104 104" style={{ width:'100%', height:'100%' }}>
          <g fill="none" stroke="#fff" strokeWidth="2">{Silhouettes.kurta}</g>
        </svg>
      </div>

      <div style={{ position:'absolute', top:14, left:16, right:16, display:'flex', justifyContent:'space-between', alignItems:'center', color:'#fff' }}>
        <button className="icon-btn" onClick={onBack} style={{ background:'rgba(255,255,255,0.1)', border:0, color:'#fff' }}>
          <IcClose size={20}/>
        </button>
        <div style={{ display:'flex', gap: 8 }}>
          <button className="icon-btn" style={{ background:'rgba(255,255,255,0.1)', border:0, color:'#fff' }}>
            <IcFlash size={18}/>
          </button>
        </div>
      </div>

      <div style={{ position:'absolute', bottom: 140, left: 0, right: 0, textAlign:'center', color:'#fff' }}>
        <div style={{ display:'inline-flex', alignItems:'center', gap: 8, padding:'6px 14px', borderRadius: 999, background:'rgba(0,0,0,0.4)', backdropFilter:'blur(8px)', fontSize: 12 }}>
          <span style={{ width: 6, height: 6, borderRadius: 999, background:'var(--orange)' }}/>
          {tips[t]}
        </div>
      </div>

      <div style={{ position:'absolute', bottom: 36, left: 0, right: 0, display:'flex', alignItems:'center', justifyContent:'center', gap: 28 }}>
        <button style={{ background:'rgba(255,255,255,0.1)', border:0, color:'#fff', width: 44, height: 44, borderRadius: 12, display:'grid', placeItems:'center' }}>
          <IcImage size={22}/>
        </button>
        <button onClick={onShoot} aria-label="shoot" style={{
          width: 72, height: 72, borderRadius: 999, background:'#fff',
          border:'4px solid rgba(255,255,255,0.3)', backgroundClip:'padding-box',
          cursor:'pointer',
        }}/>
        <div style={{ width: 44 }}/>
      </div>
    </div>
  );
}

// ─── 9. Photo Preview ───────────────────────────────────────
function ScreenPhotoPreview({ photoOf, onUse, onRetake }) {
  // We don't actually have a photo. Show the selected item as a "preview".
  const it = photoOf || WARDROBE[3]; // olive kurta default
  return (
    <div style={{ flex:1, position:'relative', background:'#0E0D0C', display:'flex', flexDirection:'column' }}>
      <div style={{ position:'absolute', inset:0, display:'flex', alignItems:'center', justifyContent:'center', padding: 40 }}>
        <div style={{ width:'80%', aspectRatio:'4 / 5', borderRadius: 18, overflow: 'hidden', position:'relative', background: it.color }}>
          <ItemSvg item={it} radius={18}/>
        </div>
      </div>
      <div style={{ position:'absolute', top:14, left:16 }}>
        <button className="icon-btn" onClick={onRetake} style={{ background:'rgba(255,255,255,0.1)', border:0, color:'#fff' }}><IcClose size={20}/></button>
      </div>
      <div className="sheet" style={{ animation: 'slideUp .3s' }}>
        <div className="sheet-handle"/>
        <div style={{ display:'flex', alignItems:'center', gap: 10, marginBottom: 14 }}>
          <div style={{ width: 36, height: 36, borderRadius: 999, background:'var(--lime-soft)', display:'grid', placeItems:'center', color:'#4d7c0f' }}>
            <IcCheck size={20} stroke={2}/>
          </div>
          <div>
            <div style={{ fontWeight: 600, fontSize: 15 }}>Looks good</div>
            <div className="caption">Sharp, well-lit, plain background.</div>
          </div>
        </div>
        <div style={{ display:'flex', gap: 10 }}>
          <button className="btn secondary" onClick={onRetake} style={{ flex: 1 }}>Retake</button>
          <button className="btn primary" onClick={onUse} style={{ flex: 1.4 }}>Use this photo</button>
        </div>
      </div>
    </div>
  );
}

// ─── 10. AI Tag Review ──────────────────────────────────────
function ScreenAITagReview({ photoOf, onBack, onSave }) {
  const it = photoOf || WARDROBE[3];
  const [tags, setTags] = React.useState({
    cat: it.cat, sub: it.sub.toLowerCase(),
    color: 'navy', pattern: 'solid', fabric: 'cotton',
    formality: it.formality, season: ['all'],
  });
  const set = (k, v) => setTags({ ...tags, [k]: v });
  const toggleSeason = (s) => {
    const cur = tags.season || [];
    set('season', cur.includes(s) ? cur.filter(x => x !== s) : [...cur, s]);
  };
  return (
    <>
      <TopBar title="Review Tags" left={<BackBtn onClick={onBack}/>} serif={false} sub="AI tagged this — tap to override."/>
      <div className="screen" style={{ paddingBottom: 100 }}>
        <div style={{ padding:'4px 20px 18px', display:'flex', justifyContent:'center', position:'relative' }}>
          <div style={{ width: 200, height: 220, borderRadius: 16, background: it.color, position:'relative', overflow:'hidden' }}>
            <ItemSvg item={it} radius={16}/>
          </div>
          <div style={{ position:'absolute', top: 14, right: 30 }}>
            <span className="sticker orange">✶ AI · 92%</span>
          </div>
        </div>

        <TagSection label="Category">
          <ChipRow items={[['top','Top'],['bottom','Bottom'],['ethnic','Ethnic'],['footwear','Footwear'],['accessory','Accessory'],['outer','Outerwear']]}
                   value={tags.cat} onChange={v => set('cat', v)}/>
        </TagSection>
        <TagSection label="Sub-category">
          <ChipRow items={[['kurta','Kurta'],['shirt','Shirt'],['polo','Polo'],['t-shirt','T-Shirt'],['hoodie','Hoodie']]}
                   value={tags.sub} onChange={v => set('sub', v)}/>
        </TagSection>
        <TagSection label="Color">
          <div className="chip-row" style={{ flexWrap:'nowrap' }}>
            {[['navy','#1E3A5F'],['black','#1A1A1A'],['white','#F4F1E8'],['beige','#D6CFC2'],['olive','#6B7A4F'],['rust','#A6532A']].map(([k,c]) => (
              <button key={k} className="chip" data-active={tags.color===k} onClick={() => set('color', k)}>
                <span style={{ width:12, height:12, borderRadius:999, background:c, border:'1px solid rgba(0,0,0,0.1)' }}/>
                <span style={{ textTransform:'capitalize' }}>{k}</span>
              </button>
            ))}
          </div>
        </TagSection>
        <TagSection label="Pattern">
          <ChipRow items={[['solid','Solid'],['striped','Striped'],['floral','Floral'],['checked','Checked'],['printed','Printed']]}
                   value={tags.pattern} onChange={v => set('pattern', v)}/>
        </TagSection>
        <TagSection label="Fabric">
          <ChipRow items={[['cotton','Cotton'],['silk','Silk'],['denim','Denim'],['linen','Linen'],['wool','Wool']]}
                   value={tags.fabric} onChange={v => set('fabric', v)}/>
        </TagSection>
        <TagSection label="Formality">
          <div style={{ display:'flex', gap: 8, padding:'0 20px 14px' }}>
            {[1,2,3,4,5].map(n => (
              <button key={n} className="chip" data-active={tags.formality===n} onClick={() => set('formality', n)}
                style={{ flex:1, height: 44, fontSize: 14, fontFamily:'var(--f-mono)', justifyContent:'center' }}>{n}</button>
            ))}
          </div>
          <div className="caption" style={{ padding:'0 20px 8px', display:'flex', justifyContent:'space-between' }}>
            <span>Casual</span><span>Formal</span>
          </div>
        </TagSection>
        <TagSection label="Season">
          <ChipRow items={[['summer','Summer'],['winter','Winter'],['monsoon','Monsoon'],['all','All season']]}
                   value={tags.season} onChange={v => set('season', v)} multi/>
        </TagSection>

        <div style={{ padding:'10px 20px 0' }}>
          <button className="btn primary" onClick={() => onSave(tags)}>Save to wardrobe</button>
        </div>
      </div>
    </>
  );
}
function TagSection({ label, children }) {
  return (
    <div>
      <div className="caption" style={{ padding:'10px 20px 8px', textTransform:'uppercase', letterSpacing:'0.07em', fontSize: 11, fontWeight: 600, color:'var(--ink-2)' }}>{label}</div>
      {children}
    </div>
  );
}

// ─── 11. Item Detail ────────────────────────────────────────
function ScreenItemDetail({ item, onBack, onEdit, onDelete }) {
  return (
    <div style={{ flex:1, position:'relative', overflow:'hidden', display:'flex', flexDirection:'column' }}>
      <div style={{ position:'relative', height: '52%', background: item.color, overflow:'hidden' }}>
        <ItemSvg item={item} radius={0}/>
        <div style={{ position:'absolute', top: 14, left: 16 }}>
          <button className="icon-btn" onClick={onBack} style={{ background:'rgba(255,255,255,0.6)', backdropFilter:'blur(8px)', borderColor:'transparent' }}>
            <IcBack size={20}/>
          </button>
        </div>
        <div style={{ position:'absolute', top: 14, right: 16, display:'flex', gap: 6 }}>
          <button className="icon-btn" style={{ background:'rgba(255,255,255,0.6)', backdropFilter:'blur(8px)', borderColor:'transparent' }}>
            <IcShare size={18}/>
          </button>
        </div>
      </div>
      <div style={{ flex: 1, padding:'18px 20px 24px', overflowY:'auto' }}>
        <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.08em', fontSize: 11 }}>{item.cat} · {item.sub}</div>
        <h1 className="h-display" style={{ marginTop: 4, fontSize: 30 }}>{item.name}</h1>

        <div style={{ display:'flex', flexWrap:'wrap', gap: 6, marginTop: 14 }}>
          <span className="sticker outline">cotton</span>
          <span className="sticker outline">solid</span>
          <span className="sticker outline">f · {item.formality}/5</span>
          <span className="sticker outline" style={{ textTransform:'capitalize' }}>{item.season}</span>
        </div>

        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap: 10, marginTop: 18 }}>
          <div className="card" style={{ padding: 14 }}>
            <div className="caption" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 10 }}>Worn</div>
            <div style={{ fontFamily:'var(--f-serif)', fontSize: 26, marginTop: 4 }}>3<span style={{ fontSize: 12, color:'var(--ink-3)' }}> times</span></div>
          </div>
          <div className="card" style={{ padding: 14 }}>
            <div className="caption" style={{ textTransform:'uppercase', letterSpacing:'0.06em', fontSize: 10 }}>Cost / wear</div>
            <div style={{ fontFamily:'var(--f-serif)', fontSize: 26, marginTop: 4, color:'var(--orange)' }}>₹833</div>
          </div>
        </div>

        <div className="caption" style={{ marginTop: 18 }}>Added Mar 20, 2026 · in 0 outfits</div>

        <div style={{ display:'flex', gap: 10, marginTop: 18 }}>
          <button className="btn secondary" onClick={onEdit} style={{ flex: 1 }}><IcEdit size={18}/> Edit</button>
          <button className="btn ghost danger" onClick={onDelete} style={{ flex: 1 }}><IcTrash size={18}/> Delete</button>
        </div>
      </div>
    </div>
  );
}

// ─── 12. Today's Outfits ────────────────────────────────────
function ScreenOutfits({ onShuffle, onSave, savedSet, likes, setLikes, dislikes, setDislikes, occasion, setOccasion, region, cardVariant }) {
  const list = OUTFITS.filter(o => o.occasion === occasion);
  return (
    <>
      <TopBar title="Today" sub={`${region} · light breeze, 28°`} right={
        <button className="icon-btn" onClick={onShuffle}><IcShuffle size={20}/></button>
      }/>
      <ChipRow items={[['casual','Casual'],['work','Work'],['party','Party'],['festive','Festive'],['date','Date Night']]}
        value={occasion} onChange={setOccasion}/>
      <div style={{ padding: '0 20px 24px', display:'flex', flexDirection:'column', gap: 16 }}>
        {list.length === 0 && (
          <div className="card" style={{ textAlign:'center', padding: 28, color:'var(--ink-3)' }}>
            Nothing yet for <b style={{ color:'var(--ink-2)' }}>{occasion}</b>. Try another occasion or shuffle.
          </div>
        )}
        {list.map(o => (
          <OutfitCard key={o.id} outfit={o}
            liked={likes.has(o.id)} disliked={dislikes.has(o.id)} saved={savedSet.has(o.id)}
            variant={cardVariant}
            onLike={() => {
              const n = new Set(likes); n.has(o.id) ? n.delete(o.id) : n.add(o.id); setLikes(n);
              const d = new Set(dislikes); d.delete(o.id); setDislikes(d);
            }}
            onDislike={() => {
              const n = new Set(dislikes); n.has(o.id) ? n.delete(o.id) : n.add(o.id); setDislikes(n);
              const l = new Set(likes); l.delete(o.id); setLikes(l);
            }}
            onSave={() => onSave(o.id)}
          />
        ))}
      </div>
    </>
  );
}

// ─── 13. Shuffle (Swipe) ────────────────────────────────────
function ScreenShuffle({ onBack, onSave }) {
  const [idx, setIdx] = React.useState(0);
  const [drag, setDrag] = React.useState({ x: 0, y: 0, active: false });
  const [exit, setExit] = React.useState(null); // 'left' | 'right' | null
  const startRef = React.useRef({ x: 0, y: 0 });

  const o = OUTFITS[idx % OUTFITS.length];
  const items = o.items.map(getItem).filter(Boolean);

  const advance = (dir) => {
    setExit(dir);
    if (dir === 'right') onSave(o.id);
    setTimeout(() => { setExit(null); setDrag({ x: 0, y: 0, active: false }); setIdx(i => i + 1); }, 280);
  };

  const onPointerDown = (e) => { startRef.current = { x: e.clientX, y: e.clientY }; setDrag({ x: 0, y: 0, active: true }); e.currentTarget.setPointerCapture(e.pointerId); };
  const onPointerMove = (e) => { if (!drag.active) return; setDrag(d => ({ ...d, x: e.clientX - startRef.current.x, y: e.clientY - startRef.current.y })); };
  const onPointerUp = () => {
    if (Math.abs(drag.x) > 80) advance(drag.x > 0 ? 'right' : 'left');
    else setDrag({ x: 0, y: 0, active: false });
  };

  const tx = exit === 'right' ? 600 : exit === 'left' ? -600 : drag.x;
  const ty = exit ? -40 : drag.y * 0.4;
  const rot = (exit === 'right' ? 18 : exit === 'left' ? -18 : drag.x * 0.06);
  const opacity = exit ? 0 : 1;
  const next = OUTFITS[(idx + 1) % OUTFITS.length];
  const nextItems = next.items.map(getItem).filter(Boolean);

  return (
    <div style={{ flex:1, display:'flex', flexDirection:'column', background:'var(--bg)' }}>
      <div style={{ padding:'8px 20px 0', display:'flex', alignItems:'center', gap: 12 }}>
        <BackBtn onClick={onBack}/>
        <div>
          <h1 style={{ fontFamily:'var(--f-serif)', fontSize: 22, margin: 0, fontWeight: 400 }}>Shuffle</h1>
          <div className="caption">Swipe right to save, left to skip</div>
        </div>
      </div>

      <div style={{ flex: 1, position:'relative', padding:'14px 20px' }}>
        {/* peek card */}
        <div style={{ position:'absolute', left: 32, right: 32, top: 24, bottom: 90, opacity: .5, transform:'scale(0.94)' }}>
          <ShuffleCard outfit={next} items={nextItems}/>
        </div>

        {/* top card */}
        <div
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          style={{
            position:'absolute', left: 20, right: 20, top: 14, bottom: 80,
            transform: `translate(${tx}px, ${ty}px) rotate(${rot}deg)`,
            transition: drag.active && !exit ? 'none' : 'transform .28s, opacity .25s',
            opacity, touchAction:'none', cursor:'grab',
          }}
        >
          <ShuffleCard outfit={o} items={items}/>
          {/* drag indicators */}
          {drag.x > 30 && (
            <div style={{ position:'absolute', top: 24, left: 24, transform:'rotate(-12deg)', padding:'6px 14px', border:'2px solid var(--lime)', color:'var(--lime)', borderRadius: 10, fontFamily:'var(--f-mono)', fontWeight: 600, letterSpacing:'0.06em', textTransform:'uppercase' }}>save</div>
          )}
          {drag.x < -30 && (
            <div style={{ position:'absolute', top: 24, right: 24, transform:'rotate(12deg)', padding:'6px 14px', border:'2px solid var(--red)', color:'var(--red)', borderRadius: 10, fontFamily:'var(--f-mono)', fontWeight: 600, letterSpacing:'0.06em', textTransform:'uppercase' }}>skip</div>
          )}
        </div>
      </div>

      <div style={{ display:'flex', alignItems:'center', justifyContent:'center', gap: 24, padding:'0 0 28px' }}>
        <button onClick={() => advance('left')} aria-label="skip" style={{ width: 60, height: 60, borderRadius: 999, background:'var(--card)', border:'1px solid var(--border)', color:'var(--red)', cursor:'pointer', display:'grid', placeItems:'center', boxShadow:'0 4px 14px rgba(0,0,0,0.06)' }}>
          <IcClose size={26}/>
        </button>
        <button onClick={() => advance('right')} aria-label="save" style={{ width: 72, height: 72, borderRadius: 999, background:'var(--orange)', border:0, color:'#fff', cursor:'pointer', display:'grid', placeItems:'center', boxShadow:'0 8px 24px rgba(249,115,22,0.35)' }}>
          <IcHeart size={30} fill="#fff"/>
        </button>
        <button onClick={() => setIdx(i => i + 1)} aria-label="next" style={{ width: 60, height: 60, borderRadius: 999, background:'var(--card)', border:'1px solid var(--border)', cursor:'pointer', display:'grid', placeItems:'center', boxShadow:'0 4px 14px rgba(0,0,0,0.06)' }}>
          <IcShuffle size={24}/>
        </button>
      </div>
    </div>
  );
}

function ShuffleCard({ outfit, items }) {
  return (
    <div className="swipe-card" style={{ padding: 0, overflow:'hidden' }}>
      <FabricBlock tone="neutral" h={120} style={{ borderRadius: 0 }}>
        <div style={{ position:'absolute', top: 12, left: 12 }}>
          <span className="sticker ink" style={{ textTransform:'capitalize' }}>{outfit.occasion}</span>
        </div>
        <div style={{ position:'absolute', top: 12, right: 12 }}>
          <span className="score-pill lg">{outfit.score}</span>
        </div>
      </FabricBlock>
      <div style={{ flex: 1, padding:'10px 18px 20px', display:'flex', flexDirection:'column', justifyContent:'space-between' }}>
        <div style={{ display:'flex', flexDirection:'column', gap: 10, alignItems:'center', paddingTop: 8 }}>
          {items.map((it, i) => (
            <div key={it.id} style={{ width: 100, height: 110, borderRadius: 14, background: it.color, position:'relative', overflow:'hidden', boxShadow:'0 6px 18px rgba(0,0,0,0.08)' }}>
              <ItemSvg item={it} radius={14}/>
            </div>
          ))}
        </div>
        <div>
          <div className="caption mono" style={{ textTransform:'uppercase', letterSpacing:'0.06em' }}>
            {outfit.weather}
          </div>
          <div style={{ fontFamily:'var(--f-serif)', fontSize: 18, lineHeight: 1.3, marginTop: 4 }}>
            "{outfit.reason}"
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── 14. Lookbooks Grid ─────────────────────────────────────
const LOOKBOOKS = [
  { id:'lb1', name:'Work Fits',    count: 12, items:['i19','i11','i12','i21'], tone:'neutral' },
  { id:'lb2', name:'Weekend',      count: 8,  items:['i1','i3','i5','i24'],    tone:'lime' },
  { id:'lb3', name:'Party Ready',  count: 6,  items:['i18','i6','i16','i12'],  tone:'ink' },
  { id:'lb4', name:'Festive',      count: 4,  items:['i9','i11','i12','i21'],  tone:'orange' },
  { id:'lb5', name:'Travel',       count: 7,  items:['i2','i23','i20','i14'],  tone:'lav' },
];

function ScreenLookbooks({ onOpen, onCreate }) {
  return (
    <>
      <TopBar title="Lookbooks" sub="Outfit collections, your way" right={
        <button className="icon-btn solid" onClick={onCreate}><IcPlus size={18}/></button>
      }/>
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap: 14, padding:'10px 20px 28px' }}>
        {LOOKBOOKS.map(lb => <LookbookCard key={lb.id} lb={lb} onClick={() => onOpen(lb)}/>)}
        <div className="dashed-card" onClick={onCreate} style={{ aspectRatio: '3 / 4' }}>
          <IcPlus size={26}/>
          <div style={{ marginTop: 8, fontSize: 13 }}>New lookbook</div>
        </div>
      </div>
    </>
  );
}
function LookbookCard({ lb, onClick }) {
  const items = lb.items.map(getItem).filter(Boolean);
  return (
    <div onClick={onClick} style={{ aspectRatio: '3 / 4', borderRadius: 18, overflow:'hidden', position:'relative', cursor:'pointer', background:'var(--card)', border:'1px solid var(--border)' }}>
      <div style={{ position:'absolute', inset: 0, display:'grid', gridTemplateColumns:'1fr 1fr', gridTemplateRows:'1fr 1fr' }}>
        {items.slice(0,4).map(it => (
          <div key={it.id} style={{ background: it.color, position:'relative', overflow:'hidden' }}>
            <ItemSvg item={it} radius={0}/>
          </div>
        ))}
      </div>
      <div style={{ position:'absolute', inset:'auto 0 0', height:'48%', background:'linear-gradient(to top, rgba(20,18,16,0.85), transparent)' }}/>
      <div style={{ position:'absolute', bottom: 12, left: 14, right: 14, color:'#fff' }}>
        <div style={{ fontFamily:'var(--f-serif)', fontSize: 22, lineHeight: 1, letterSpacing:'-0.01em' }}>{lb.name}</div>
        <div className="mono" style={{ fontSize: 10, opacity: 0.8, marginTop: 4, textTransform:'uppercase', letterSpacing:'0.08em' }}>{lb.count} outfits</div>
      </div>
    </div>
  );
}

// ─── 15. Lookbook Detail ────────────────────────────────────
function ScreenLookbookDetail({ lb, onBack, savedSet, onSave, likes, setLikes, dislikes, setDislikes, cardVariant }) {
  const list = OUTFITS.slice(0, lb.count > OUTFITS.length ? OUTFITS.length : Math.min(lb.count, OUTFITS.length));
  return (
    <>
      <TopBar title={lb.name} left={<BackBtn onClick={onBack}/>} sub={`${lb.count} outfits · curated`} right={
        <button className="icon-btn"><IcShare size={18}/></button>
      }/>
      <div style={{ padding:'0 20px 28px', display:'flex', flexDirection:'column', gap: 14 }}>
        {list.map(o => (
          <OutfitCard key={o.id} outfit={o}
            variant={cardVariant}
            liked={likes.has(o.id)} disliked={dislikes.has(o.id)} saved={savedSet.has(o.id)}
            onLike={() => { const n = new Set(likes); n.has(o.id) ? n.delete(o.id) : n.add(o.id); setLikes(n); }}
            onDislike={() => { const n = new Set(dislikes); n.has(o.id) ? n.delete(o.id) : n.add(o.id); setDislikes(n); }}
            onSave={() => onSave(o.id)}
          />
        ))}
      </div>
    </>
  );
}

// ─── 16. Profile ────────────────────────────────────────────
function ScreenProfile({ items, savedCount, onRetake, name = 'Avinash', plan = 'Free', region, setRegion, gender }) {
  const [notif, setNotif] = React.useState(true);
  const genderLabel = { w: 'Women', m: 'Men', all: 'Both' }[gender] || 'Both';
  return (
    <>
      <TopBar title="Profile" right={
        <button className="icon-btn"><IcEdit size={18}/></button>
      }/>
      <div style={{ padding: '0 20px 28px' }}>
        <div style={{ display:'flex', alignItems:'center', gap: 14 }}>
          <div className="avatar" style={{ width: 72, height: 72, fontSize: 28 }}>A</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily:'var(--f-serif)', fontSize: 24, lineHeight: 1 }}>{name}</div>
            <div style={{ display:'flex', alignItems:'center', gap: 8, marginTop: 6 }}>
              <span className="sticker orange">{plan}</span>
              <span className="caption">·  member since Mar 2026</span>
            </div>
          </div>
        </div>

        <SectionHead>Style profile</SectionHead>
        <div className="card">
          <div style={{ display:'flex', flexWrap:'wrap', gap: 6 }}>
            {[genderLabel,'Minimalist','Classic','Casual','Neutrals','Regular',region].filter(Boolean).map(c => (
              <span key={c} className="chip sm">{c}</span>
            ))}
          </div>
          <div className="divider" style={{ margin:'12px -16px' }}/>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center' }}>
            <div className="caption">Want different suggestions?</div>
            <button onClick={onRetake} style={{ background:'transparent', border:0, color:'var(--orange)', fontWeight: 600, fontSize: 13, cursor:'pointer' }}>Retake quiz</button>
          </div>
        </div>

        <SectionHead>Wardrobe</SectionHead>
        <div className="card">
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', textAlign:'center' }}>
            <Stat n={items.length} label="Items"/>
            <Stat n={savedCount} label="Saved"/>
            <Stat n="73%" label="In rotation"/>
          </div>
        </div>

        <SectionHead>Preferences</SectionHead>
        <div className="card" style={{ padding: 0 }}>
          <SettingRow label="Morning outfit notification" right={<div className="toggle" data-on={notif} onClick={() => setNotif(x => !x)}/>}/>
          <SettingRow label="Region" right={
            <select value={region} onChange={e => setRegion(e.target.value)} style={{ border:0, background:'transparent', fontFamily:'inherit', fontSize: 14, color:'var(--ink-2)', textAlign:'right' }}>
              <option>India</option><option>US</option><option>UK</option><option>Global</option>
            </select>
          }/>
          <SettingRow label="Appearance" right={<span className="caption" style={{ color:'var(--ink-2)' }}>Light</span>}/>
          <SettingRow label="About drape.ai" right={<IcChev size={16}/>} last/>
        </div>

        <SectionHead>Help & legal</SectionHead>
        <div className="card" style={{ padding: 0 }}>
          <SettingRow label="Terms & Privacy" right={<IcChev size={16}/>}/>
          <SettingRow label="Help & feedback" right={<IcChev size={16}/>} last/>
        </div>

        <div style={{ marginTop: 20, display:'flex', flexDirection:'column', gap: 4 }}>
          <button className="btn ghost">Sign out</button>
          <button className="btn ghost danger">Delete account</button>
        </div>

        <div className="caption mono" style={{ textAlign:'center', marginTop: 16, opacity:.5 }}>drape.ai · v1.0.0</div>
      </div>
    </>
  );
}
function SectionHead({ children }) {
  return <div className="caption" style={{ textTransform:'uppercase', letterSpacing:'0.08em', fontSize: 11, margin:'24px 0 8px', fontWeight: 600, color:'var(--ink-2)' }}>{children}</div>;
}
function Stat({ n, label }) {
  return (
    <div>
      <div style={{ fontFamily:'var(--f-serif)', fontSize: 28, lineHeight: 1 }}>{n}</div>
      <div className="caption" style={{ marginTop: 4 }}>{label}</div>
    </div>
  );
}
function SettingRow({ label, right, last }) {
  return (
    <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'14px 16px', borderBottom: last ? 'none' : '1px solid var(--border)', gap: 12 }}>
      <div style={{ fontSize: 14 }}>{label}</div>
      <div style={{ color:'var(--ink-3)' }}>{right}</div>
    </div>
  );
}

// ─── 17. Three-Upload Sheet ─────────────────────────────────
function SheetFirstOutfit({ onClose, onSee }) {
  return (
    <>
      <div className="sheet-backdrop" onClick={onClose}/>
      <div className="sheet">
        <div className="sheet-handle"/>
        <div style={{ display:'flex', justifyContent:'center', marginBottom: 14 }}>
          <div style={{ width: 60, height: 60, borderRadius: 999, background:'var(--orange-soft)', display:'grid', placeItems:'center', color:'var(--orange)', position:'relative' }}>
            <Sparkles count={8} color="var(--orange)"/>
            <IcSparkle size={28} stroke={2}/>
          </div>
        </div>
        <h2 className="h-display" style={{ fontSize: 24, textAlign:'center' }}>Your first outfit is <span style={{ fontStyle:'italic' }}>ready</span>.</h2>
        <div className="sub" style={{ textAlign:'center', margin:'6px 0 18px' }}>
          We've put together 3 suggestions from what you added.
        </div>
        <div style={{ display:'flex', gap: 8, justifyContent:'center', marginBottom: 18 }}>
          {OUTFITS.slice(0,3).map(o => (
            <div key={o.id} style={{ display:'flex', gap: -8 }}>
              {o.items.slice(0,3).map((id, i) => {
                const it = getItem(id);
                return it ? (
                  <div key={id} style={{ marginLeft: i ? -10 : 0 }}>
                    <ItemCircle item={it} size={40}/>
                  </div>
                ) : null;
              })}
            </div>
          ))}
        </div>
        <button className="btn primary" onClick={onSee}>See my outfits</button>
      </div>
    </>
  );
}

Object.assign(window, {
  ScreenWardrobe, ScreenWardrobeEmpty, ScreenSearch,
  ScreenCamera, ScreenPhotoPreview, ScreenAITagReview, ScreenItemDetail,
  ScreenOutfits, ScreenShuffle, ScreenLookbooks, ScreenLookbookDetail,
  ScreenProfile, SheetFirstOutfit, LOOKBOOKS,
});

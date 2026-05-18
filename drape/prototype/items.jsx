// items.jsx — global wardrobe + improved silhouettes + photo fallback

// ─── Silhouettes ──────────────────────────────────────────
// Each silhouette is drawn in a 104×104 viewBox, recognizable at small size.
// Strokes use currentColor so we can recolor based on item luminance.
const Silhouettes = {
  // ── Tops ──
  tshirt: <path d="M30 30 L42 18 Q50 16 60 16 Q70 16 78 18 L90 30 L82 40 L74 34 L74 86 Q60 90 46 86 L46 34 L38 40 Z"/>,
  polo: <path d="M30 30 L42 18 Q50 16 60 16 Q70 16 78 18 L90 30 L82 40 L74 34 L74 86 L46 86 L46 34 L38 40 Z M52 22 L52 38 L60 32 L68 38 L68 22"/>,
  shirt: <path d="M30 28 L42 16 L48 22 Q60 24 72 22 L78 16 L90 28 L82 38 L74 32 L74 90 L46 90 L46 32 L38 38 Z M60 22 L60 84 M58 36 L62 36 M58 50 L62 50 M58 64 L62 64 M58 76 L62 76"/>,
  hoodie: <path d="M28 34 L40 22 Q44 14 60 14 Q76 14 80 22 L92 34 L84 46 L76 40 L76 90 L44 90 L44 40 L36 46 Z M44 22 Q60 32 76 22 M50 50 L70 50"/>,
  sweater: <path d="M26 32 L40 18 Q50 16 60 16 Q70 16 80 18 L94 32 L86 44 L76 38 L76 90 L44 90 L44 38 L34 44 Z M46 26 Q60 30 74 26 M44 52 H76 M44 66 H76"/>,
  croptop: <path d="M32 28 L42 18 Q50 16 60 16 Q70 16 78 18 L88 28 L82 36 L74 32 L74 58 L46 58 L46 32 L38 36 Z"/>,
  blouse: <path d="M34 32 Q40 18 60 18 Q80 18 86 32 L82 42 L74 38 L74 88 L46 88 L46 38 L38 42 Z M46 38 Q60 50 74 38"/>,
  tanktop: <path d="M44 18 L48 24 Q60 28 72 24 L76 18 L74 36 L74 88 L46 88 L46 36 Z"/>,
  jacket: <path d="M28 30 L40 18 Q44 14 50 14 L52 24 L52 90 L34 90 Z M70 14 Q76 14 80 18 L92 30 L86 90 L68 90 L68 24 Z M52 24 L60 30 L68 24 L60 36 Z"/>,
  blazer: <path d="M30 30 L42 18 L52 22 L48 36 L52 90 L34 90 Z M88 90 L70 90 L72 36 L68 22 L78 18 L90 30 Z M52 22 L60 28 L68 22 L60 38 L52 28"/>,
  coat: <path d="M26 28 L40 16 L60 20 L80 16 L94 28 L92 94 L28 94 Z M60 20 L60 92 M52 30 L52 90 M68 30 L68 90 M40 38 H44 M76 38 H80 M40 60 H44 M76 60 H80"/>,
  trench: <path d="M28 30 L42 18 L48 22 L48 92 L32 92 Z M88 92 L72 92 L72 22 L78 18 L92 30 Z M48 22 L60 24 L72 22 L66 36 L54 36 Z M52 50 L68 50 M52 70 L68 70"/>,
  cardigan: <path d="M28 32 L40 20 L48 22 L48 90 L34 90 Z M86 90 L72 90 L72 22 L80 20 L92 32 Z M48 22 L60 26 L72 22 M58 30 L58 88 M62 30 L62 88"/>,
  // ── Bottoms ──
  jeans: <path d="M36 18 L84 18 L88 28 L80 92 L66 92 L60 40 L54 92 L40 92 L32 28 Z M40 28 H80 M52 60 L48 88 M68 60 L72 88"/>,
  trouser: <path d="M40 18 L80 18 L82 28 L76 92 L66 92 L60 38 L54 92 L44 92 L38 28 Z"/>,
  chino: <path d="M38 18 L82 18 L84 26 L78 92 L66 92 L60 38 L54 92 L42 92 L36 26 Z"/>,
  shorts: <path d="M38 22 L82 22 L84 30 L78 64 L66 64 L60 38 L54 64 L42 64 L36 30 Z"/>,
  miniskirt: <path d="M40 22 L80 22 L88 60 L32 60 Z M42 32 L78 32"/>,
  skirt: <path d="M40 22 L80 22 L88 80 L32 80 Z M44 32 L76 32 M40 50 L80 50"/>,
  maxiskirt: <path d="M42 22 L78 22 L94 98 L26 98 Z M44 30 L76 30"/>,
  pleated: <path d="M42 22 L78 22 L88 84 L32 84 Z M50 22 L46 84 M58 22 L56 84 M62 22 L64 84 M70 22 L74 84"/>,
  // ── Dresses ──
  dress: <path d="M40 22 L48 16 Q60 12 72 16 L80 22 L74 34 L74 38 L88 92 L32 92 L46 38 L46 34 Z"/>,
  maxidress: <path d="M44 22 L50 16 Q60 14 70 16 L76 22 L72 36 L86 98 L34 98 L48 36 Z"/>,
  bodycon: <path d="M44 18 L48 22 Q60 24 72 22 L76 18 L74 38 L74 90 L46 90 L46 38 Z"/>,
  // ── Indian / ethnic (kept as options for global users) ──
  kurta: <path d="M30 24 L42 16 Q50 14 60 14 Q70 14 78 16 L90 24 L82 32 L74 28 L74 98 L46 98 L46 28 L38 32 Z M60 16 L60 90 M55 22 L60 18 L65 22 M52 50 H68 M52 62 H68"/>,
  saree: <path d="M30 18 Q44 14 60 16 Q76 14 84 22 L78 36 L72 30 L72 98 L48 98 L48 30 L42 36 Z M48 38 Q34 60 28 96 M72 38 Q86 60 92 96 M48 56 L40 80 M72 56 L80 80"/>,
  lehenga: <path d="M44 18 L76 18 L78 30 L60 32 L42 30 Z M60 32 L26 98 L94 98 Z M50 56 L42 88 M70 56 L78 88 M60 32 L60 96"/>,
  // ── One-pieces ──
  jumpsuit: <path d="M34 24 L42 16 Q50 14 60 14 Q70 14 78 16 L86 24 L80 32 L74 28 L74 52 L70 96 L60 96 L60 56 L54 96 L46 96 L42 52 L46 28 L40 32 Z"/>,
  romper: <path d="M36 24 L42 18 Q50 16 60 16 Q70 16 78 18 L84 24 L78 32 L74 28 L74 56 L66 70 L60 70 L60 48 L54 70 L46 70 L46 28 L42 32 Z"/>,
  // ── Footwear ──
  sneaker: <path d="M14 60 Q14 50 26 48 L46 44 Q56 42 64 48 L78 56 Q88 58 92 64 L92 72 L14 72 Z M26 48 L30 60 M40 46 L42 58 M52 46 L52 60 M64 50 L66 62"/>,
  loafer: <path d="M16 58 Q16 48 30 46 L52 44 Q74 44 86 56 L90 64 L90 70 L16 70 Z M38 50 Q48 56 60 50"/>,
  boot: <path d="M30 28 L52 28 L52 56 L80 56 Q90 58 90 66 L90 76 L30 76 L30 28 Z M30 50 L52 50"/>,
  heel: <path d="M18 50 Q18 42 30 40 L60 38 Q82 38 86 50 L90 56 L80 60 L80 80 L76 80 L76 60 L18 60 Z"/>,
  sandal: <path d="M18 60 L86 60 L86 70 L18 70 Z M28 50 L28 60 M42 46 L42 60 M58 46 L58 60 M74 48 L74 60 M52 36 Q60 44 52 60"/>,
  flats: <path d="M16 58 Q16 50 32 48 L60 46 Q82 46 88 58 L88 68 L16 68 Z"/>,
  // ── Accessories ──
  watch: <path d="M44 18 L76 18 L72 36 Q78 40 78 50 Q78 60 72 64 L76 82 L44 82 L48 64 Q42 60 42 50 Q42 40 48 36 Z M50 50 H70 M60 42 L60 50"/>,
  bag: <path d="M28 38 L92 38 L88 92 L32 92 Z M44 38 Q44 18 60 18 Q76 18 76 38"/>,
  tote: <path d="M26 36 L94 36 L90 96 L30 96 Z M40 36 L40 22 L52 22 L52 36 M68 36 L68 22 L80 22 L80 36"/>,
  clutch: <path d="M20 44 L100 44 L96 72 L24 72 Z M58 50 Q60 56 62 50"/>,
  cap: <path d="M14 60 Q14 38 60 36 Q90 36 90 60 L90 68 L14 68 Z M60 36 Q60 28 90 32"/>,
  beanie: <path d="M22 60 Q22 24 60 24 Q98 24 98 60 L98 68 L22 68 Z M22 60 L98 60"/>,
  shades: <path d="M14 44 H44 Q50 44 50 52 V60 Q50 70 38 70 H26 Q14 70 14 60 Z M56 44 H86 Q92 44 92 52 V60 Q92 70 80 70 H68 Q56 70 56 60 Z M44 50 Q50 48 56 50"/>,
  belt: <path d="M10 50 H94 V60 H10 Z M52 50 V60 M68 50 V60 M44 55 H50 V58 H44 Z"/>,
  scarf: <path d="M30 22 Q60 18 86 28 L80 44 Q60 38 36 44 Z M36 44 L30 96 M80 44 L86 88 M40 60 L72 60 M42 76 L70 76"/>,
  necklace: <path d="M30 22 Q60 80 90 22 M55 60 L55 70 L65 70 L65 60 Z M50 70 Q60 84 70 70"/>,
  earrings: <path d="M36 24 Q42 24 42 30 Q42 38 36 38 Q30 38 30 30 Q30 24 36 24 M36 38 Q34 50 36 58 Q40 60 40 64 Q40 70 34 70 Q28 70 28 64 Q28 60 32 58 M84 24 Q90 24 90 30 Q90 38 84 38 Q78 38 78 30 Q78 24 84 24 M84 38 Q82 50 84 58 Q88 60 88 64 Q88 70 82 70 Q76 70 76 64 Q76 60 80 58"/>,
};

// ─── Wardrobe — global, gender-balanced, ~40 items ──────────
// w=women, m=men, u=unisex
const WARDROBE = [
  // Men
  { id: 'i1',  g:'m', name: 'Navy Polo',           cat:'top',       sub:'Polo',     color:'#1E3A5F', sil:'polo',     formality:2, season:'all',
    photo: 'photo-1586790170083-2f9ceadc732d' },
  { id: 'i2',  g:'m', name: 'Cream Linen Shirt',   cat:'top',       sub:'Shirt',    color:'#E8DCC4', sil:'shirt',    formality:3, season:'summer',
    photo: 'photo-1620012253295-c15cc3e65df4' },
  { id: 'i3',  g:'m', name: 'Beige Chinos',        cat:'bottom',    sub:'Chinos',   color:'#C9B391', sil:'chino',    formality:3, season:'all',
    photo: 'photo-1473966968600-fa801b869a1a' },
  { id: 'i5',  g:'u', name: 'White Sneakers',      cat:'footwear',  sub:'Sneakers', color:'#F2F0EA', sil:'sneaker',  formality:2, season:'all',
    photo: 'photo-1542291026-7eec264c27ff' },
  { id: 'i6',  g:'u', name: 'Black Tee',           cat:'top',       sub:'T-Shirt',  color:'#1A1A1A', sil:'tshirt',   formality:1, season:'all',
    photo: 'photo-1583743814966-8936f5b7be1a' },
  { id: 'i7',  g:'u', name: 'Indigo Denim',        cat:'bottom',    sub:'Jeans',    color:'#2E4863', sil:'jeans',    formality:2, season:'all',
    photo: 'photo-1542272604-787c3835535d' },
  { id: 'i8',  g:'m', name: 'Camel Overshirt',     cat:'outer',     sub:'Jacket',   color:'#B08560', sil:'jacket',   formality:3, season:'winter',
    photo: 'photo-1591047139829-d91aecb6caea' },
  { id: 'i11', g:'m', name: 'Charcoal Trousers',   cat:'bottom',    sub:'Trousers', color:'#383634', sil:'trouser',  formality:4, season:'all',
    photo: 'photo-1473966968600-fa801b869a1a' },
  { id: 'i12', g:'m', name: 'Brown Loafers',       cat:'footwear',  sub:'Loafers',  color:'#5A3A24', sil:'loafer',   formality:4, season:'all',
    photo: 'photo-1582897085656-c636d006a246' },
  { id: 'i15', g:'u', name: 'Sand Hoodie',         cat:'top',       sub:'Hoodie',   color:'#D4C5A0', sil:'hoodie',   formality:1, season:'winter',
    photo: 'photo-1556821840-3a63f95609a7' },
  { id: 'i16', g:'u', name: 'Black Jeans',         cat:'bottom',    sub:'Jeans',    color:'#15161A', sil:'jeans',    formality:2, season:'all',
    photo: 'photo-1604176354204-9268737828e4' },
  { id: 'i18', g:'m', name: 'Pinstripe Blazer',    cat:'outer',     sub:'Blazer',   color:'#2A2A30', sil:'blazer',   formality:5, season:'all',
    photo: 'photo-1594938298603-c8148c4dae35' },
  { id: 'i22', g:'u', name: 'Wool Sweater',        cat:'top',       sub:'Sweater',  color:'#7B4F38', sil:'sweater',  formality:3, season:'winter',
    photo: 'photo-1576566588028-4147f3842f27' },

  // Women — global modern
  { id: 'w1',  g:'w', name: 'Slip Dress',          cat:'dress',     sub:'Slip',     color:'#0E1116', sil:'bodycon',  formality:4, season:'all',
    photo: 'photo-1572804013309-59a88b7e92f1' },
  { id: 'w2',  g:'w', name: 'White Tee',           cat:'top',       sub:'T-Shirt',  color:'#F4F1E8', sil:'tshirt',   formality:1, season:'all',
    photo: 'photo-1521572163474-6864f9cf17ab' },
  { id: 'w3',  g:'w', name: 'Linen Maxi',          cat:'dress',     sub:'Maxi',     color:'#D2BFA0', sil:'maxidress',formality:3, season:'summer',
    photo: 'photo-1539008835657-9e8e9680c956' },
  { id: 'w4',  g:'w', name: 'Pleated Midi Skirt',  cat:'bottom',    sub:'Skirt',    color:'#4A5347', sil:'pleated',  formality:3, season:'all',
    photo: 'photo-1577900232427-18219b9166a0' },
  { id: 'w5',  g:'w', name: 'Silk Blouse',         cat:'top',       sub:'Blouse',   color:'#EDD4B5', sil:'blouse',   formality:4, season:'all',
    photo: 'photo-1564257631407-4deb1f99d992' },
  { id: 'w6',  g:'w', name: 'Black Heels',         cat:'footwear',  sub:'Heels',    color:'#0F0F12', sil:'heel',     formality:5, season:'all',
    photo: 'photo-1543163521-1bf539c55dd2' },
  { id: 'w7',  g:'w', name: 'Crop Cardigan',       cat:'top',       sub:'Cardigan', color:'#C9A78B', sil:'cardigan', formality:2, season:'winter',
    photo: 'photo-1620799140188-3b2a02fd9a77' },
  { id: 'w8',  g:'w', name: 'Mom Jeans',           cat:'bottom',    sub:'Jeans',    color:'#7E97B2', sil:'jeans',    formality:2, season:'all',
    photo: 'photo-1582418702059-97ebafb35d09' },
  { id: 'w9',  g:'w', name: 'Wrap Dress',          cat:'dress',     sub:'Dress',    color:'#8B4A3E', sil:'dress',    formality:4, season:'all',
    photo: 'photo-1595777457583-95e059d581b8' },
  { id: 'w10', g:'w', name: 'Crop Top',            cat:'top',       sub:'Crop',     color:'#E9C0BD', sil:'croptop',  formality:1, season:'summer',
    photo: 'photo-1503342217505-b0a15ec3261c' },
  { id: 'w11', g:'w', name: 'Leather Jacket',      cat:'outer',     sub:'Jacket',   color:'#1B1A18', sil:'jacket',   formality:3, season:'winter',
    photo: 'photo-1551028719-00167b16eac5' },
  { id: 'w12', g:'w', name: 'Wool Coat',           cat:'outer',     sub:'Coat',     color:'#9C8770', sil:'coat',     formality:4, season:'winter',
    photo: 'photo-1539533018447-63fcce2678e3' },
  { id: 'w13', g:'w', name: 'Ankle Boots',         cat:'footwear',  sub:'Boots',    color:'#3A2A20', sil:'boot',     formality:3, season:'all',
    photo: 'photo-1551107696-a4b0c5a0d9a2' },
  { id: 'w14', g:'w', name: 'Strappy Sandals',     cat:'footwear',  sub:'Sandals',  color:'#C9A678', sil:'sandal',   formality:3, season:'summer',
    photo: 'photo-1603487742131-4160ec999306' },
  { id: 'w15', g:'w', name: 'Denim Jacket',        cat:'outer',     sub:'Jacket',   color:'#5C7BA0', sil:'jacket',   formality:2, season:'all',
    photo: 'photo-1551488831-00ddcb6c6bd3' },
  { id: 'w16', g:'w', name: 'Mini Skirt',          cat:'bottom',    sub:'Skirt',    color:'#1A1A1A', sil:'miniskirt',formality:2, season:'summer',
    photo: 'photo-1554412933-514a83d2f3c8' },
  { id: 'w17', g:'w', name: 'Knit Tank',           cat:'top',       sub:'Tank',     color:'#E6D8C0', sil:'tanktop',  formality:2, season:'summer',
    photo: 'photo-1554568218-0f1715e72254' },
  { id: 'w18', g:'w', name: 'Jumpsuit',            cat:'dress',     sub:'Jumpsuit', color:'#3D4A5E', sil:'jumpsuit', formality:3, season:'all',
    photo: 'photo-1517445312882-bc9910d016b7' },
  { id: 'w19', g:'w', name: 'Trench Coat',         cat:'outer',     sub:'Trench',   color:'#C2A57A', sil:'trench',   formality:4, season:'all',
    photo: 'photo-1591047139756-eb1f8c4d8d65' },

  // Ethnic (kept — global ethnic options for those who want them)
  { id: 'i4',  g:'m', name: 'Olive Kurta',         cat:'ethnic',    sub:'Kurta',    color:'#6B7A4F', sil:'kurta',    formality:4, season:'all',
    photo: 'photo-1622112543049-bafc36a18b50' },
  { id: 'i9',  g:'m', name: 'Ivory Kurta',         cat:'ethnic',    sub:'Kurta',    color:'#EDE3CF', sil:'kurta',    formality:4, season:'all',
    photo: 'photo-1610030469983-98e550d6193c' },
  { id: 'w20', g:'w', name: 'Rose Lehenga',        cat:'ethnic',    sub:'Lehenga',  color:'#A83753', sil:'lehenga',  formality:5, season:'all',
    photo: 'photo-1610030469983-98e550d6193c' },
  { id: 'w21', g:'w', name: 'Silk Saree',          cat:'ethnic',    sub:'Saree',    color:'#7E1A35', sil:'saree',    formality:5, season:'all',
    photo: 'photo-1551489186-cf8726f514f8' },

  // Accessories
  { id: 'i13', g:'u', name: 'Tan Crossbody',       cat:'accessory', sub:'Bag',      color:'#B98E5F', sil:'bag',      formality:3, season:'all',
    photo: 'photo-1548036328-c9fa32d4ba2b' },
  { id: 'i14', g:'u', name: 'Black Shades',        cat:'accessory', sub:'Glasses',  color:'#1A1A1A', sil:'shades',   formality:2, season:'summer',
    photo: 'photo-1572635196237-14b3f281503f' },
  { id: 'i21', g:'u', name: 'Steel Watch',         cat:'accessory', sub:'Watch',    color:'#D4D2CC', sil:'watch',    formality:3, season:'all',
    photo: 'photo-1524592094714-0f0654e20314' },
  { id: 'w22', g:'w', name: 'Leather Tote',        cat:'accessory', sub:'Tote',     color:'#5B3A24', sil:'tote',     formality:3, season:'all',
    photo: 'photo-1548036328-c9fa32d4ba2b' },
  { id: 'w23', g:'w', name: 'Silk Scarf',          cat:'accessory', sub:'Scarf',    color:'#D17B6B', sil:'scarf',    formality:3, season:'all',
    photo: 'photo-1601924994987-69e26d50dc26' },
];

const CATS = {
  all: 'All', top: 'Tops', bottom: 'Bottoms', dress: 'Dresses',
  ethnic: 'Ethnic', footwear: 'Footwear', accessory: 'Accessories', outer: 'Outerwear',
};

const isDark = (hex) => {
  const c = hex.replace('#','');
  const r = parseInt(c.slice(0,2),16), g = parseInt(c.slice(2,4),16), b = parseInt(c.slice(4,6),16);
  return (0.299*r + 0.587*g + 0.114*b) < 130;
};

// ─── Image mode (silhouette / photo) ─────────────────────
// A simple context-free module-level setting. We expose a setter so the
// Tweaks panel can toggle it. Components read window.__imgMode each render
// via a small subscription helper.
const ImgModeCtx = React.createContext('silhouette');
function ImgModeProvider({ value, children }) {
  return <ImgModeCtx.Provider value={value}>{children}</ImgModeCtx.Provider>;
}
function useImgMode() { return React.useContext(ImgModeCtx); }

// ─── ItemSvg — the silhouette card content (always renders) ────
function ItemSvg({ item, radius = 14, accent = false }) {
  const dark = isDark(item.color);
  const sil  = Silhouettes[item.sil] || Silhouettes.tshirt;
  const stroke = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.42)';
  return (
    <svg viewBox="0 0 104 104" preserveAspectRatio="xMidYMid meet"
         style={{ position:'absolute', inset:0, width:'100%', height:'100%' }}>
      <defs>
        <pattern id={`weave-${item.id}`} patternUnits="userSpaceOnUse" width="8" height="8" patternTransform="rotate(45)">
          <line x1="0" y1="0" x2="0" y2="8" stroke={dark?'rgba(255,255,255,0.05)':'rgba(0,0,0,0.04)'} strokeWidth="1"/>
        </pattern>
      </defs>
      <rect width="104" height="104" rx={radius} fill={item.color}/>
      <rect width="104" height="104" rx={radius} fill={`url(#weave-${item.id})`}/>
      <g fill="none" stroke={stroke} strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round">
        {sil}
      </g>
    </svg>
  );
}

// ItemPhoto — tries to load real photo from Unsplash, falls back to silhouette
function ItemPhoto({ item, radius = 14 }) {
  const [failed, setFailed] = React.useState(false);
  if (!item.photo || failed) return <ItemSvg item={item} radius={radius}/>;
  const url = `https://images.unsplash.com/${item.photo}?w=400&h=400&fit=crop&q=80&auto=format`;
  return (
    <>
      <div style={{ position:'absolute', inset:0, borderRadius: radius, overflow:'hidden', background: item.color }}>
        <img src={url} alt={item.name} loading="lazy" onError={() => setFailed(true)}
             style={{ width:'100%', height:'100%', objectFit:'cover', display:'block' }}/>
      </div>
    </>
  );
}

// Smart picker
function ItemMedia({ item, radius }) {
  const mode = useImgMode();
  return mode === 'photo' ? <ItemPhoto item={item} radius={radius}/> : <ItemSvg item={item} radius={radius}/>;
}

// ─── Tiles ────────────────────────────────────────────────
function ItemTile({ item, onClick, label = true, badge }) {
  return (
    <div onClick={onClick} style={{ cursor: 'pointer' }}>
      <div className="item-tile" style={{ background: item.color }}>
        <ItemMedia item={item} radius={14}/>
        {badge && <div style={{ position:'absolute', top:8, left:8, zIndex:2 }}>{badge}</div>}
      </div>
      {label && <div className="name" style={{ marginTop:8, fontSize:12, color:'var(--ink-2)', fontWeight:500 }}>
        {item.name}
      </div>}
    </div>
  );
}

function ItemCircle({ item, size = 70 }) {
  return (
    <div className="outfit-circle" style={{ width: size, height: size, background: item.color }}>
      <ItemMedia item={item} radius={999}/>
    </div>
  );
}

Object.assign(window, {
  Silhouettes, WARDROBE, CATS, ItemSvg, ItemPhoto, ItemMedia,
  ItemTile, ItemCircle, isDark, ImgModeProvider, useImgMode, ImgModeCtx,
});

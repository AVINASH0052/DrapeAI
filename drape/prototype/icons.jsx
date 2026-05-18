// icons.jsx — Outlined icon set for DrapeAI
// Single-stroke, 24×24 viewBox, currentColor stroke

const Icon = ({ d, size = 22, stroke = 1.6, fill = 'none', children, ...rest }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill}
       stroke="currentColor" strokeWidth={stroke}
       strokeLinecap="round" strokeLinejoin="round" {...rest}>
    {d ? <path d={d}/> : children}
  </svg>
);

const IcHanger = (p) => <Icon {...p}><path d="M12 3.5a2 2 0 1 0 2 2c0 .9-.5 1.5-1.5 2L4 12.5c-1 .5-1 1.5 0 2h16c1 0 1-1.5 0-2l-8.5-5"/></Icon>;
const IcSparkle = (p) => <Icon {...p}><path d="M12 3 13.7 9.3 20 11l-6.3 1.7L12 19l-1.7-6.3L4 11l6.3-1.7z"/><path d="M19 4l.5 1.5L21 6l-1.5.5L19 8l-.5-1.5L17 6l1.5-.5z"/></Icon>;
const IcBookmark = (p) => <Icon {...p}><path d="M6 3.5h12v17l-6-4-6 4z"/></Icon>;
const IcUser = (p) => <Icon {...p}><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.5 4.5-7 8-7s7 2.5 8 7"/></Icon>;
const IcSearch = (p) => <Icon {...p}><circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/></Icon>;
const IcBell = (p) => <Icon {...p}><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2H4.5z"/><path d="M10 19a2 2 0 0 0 4 0"/></Icon>;
const IcPlus = (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>;
const IcBack = (p) => <Icon {...p}><path d="M15 5l-7 7 7 7"/></Icon>;
const IcClose = (p) => <Icon {...p}><path d="M6 6l12 12M18 6 6 18"/></Icon>;
const IcCheck = (p) => <Icon {...p}><path d="M5 12.5 10 17 19 7.5"/></Icon>;
const IcShuffle = (p) => <Icon {...p}><path d="M3 7h3l11 10h4M3 17h3l4-3.5M14 9l3-2.5h4M18 4l3 2.5L18 9M18 14.5 21 17l-3 2.5"/></Icon>;
const IcThumbUp = (p) => <Icon {...p}><path d="M7 11v9H4v-9zM7 11l4-7c2 0 3 1 3 3v3h5a2 2 0 0 1 2 2.4l-1.4 5.6A2 2 0 0 1 17.6 20H7"/></Icon>;
const IcThumbDown = (p) => <Icon {...p}><path d="M7 13V4H4v9zM7 13l4 7c2 0 3-1 3-3v-3h5a2 2 0 0 0 2-2.4L19.6 6A2 2 0 0 0 17.6 4H7"/></Icon>;
const IcHeart = (p) => <Icon {...p}><path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.7A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/></Icon>;
const IcCamera = (p) => <Icon {...p}><path d="M4 8h3l2-2.5h6L17 8h3v11H4z"/><circle cx="12" cy="13" r="3.5"/></Icon>;
const IcImage = (p) => <Icon {...p}><rect x="3.5" y="4.5" width="17" height="15" rx="2"/><circle cx="9" cy="10" r="1.5"/><path d="m4 18 5-5 4 4 3-3 4 4"/></Icon>;
const IcFlash = (p) => <Icon {...p}><path d="M13 3 5 13h6l-1 8 8-10h-6z"/></Icon>;
const IcEdit = (p) => <Icon {...p}><path d="M14 5 19 10 8.5 20.5 3 21l.5-5.5z"/></Icon>;
const IcTrash = (p) => <Icon {...p}><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></Icon>;
const IcChev = (p) => <Icon {...p}><path d="M9 6l6 6-6 6"/></Icon>;
const IcSun = (p) => <Icon {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.5 4.5 6 6M18 18l1.5 1.5M19.5 4.5 18 6M6 18l-1.5 1.5"/></Icon>;
const IcPhone = (p) => <Icon {...p}><rect x="7" y="2.5" width="10" height="19" rx="2.5"/><circle cx="12" cy="18" r=".8" fill="currentColor"/></Icon>;
const IcGoogle = (p) => (
  <svg width={p.size||22} height={p.size||22} viewBox="0 0 24 24">
    <path fill="#4285F4" d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4c-.2 1.2-1 2.3-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z"/>
    <path fill="#34A853" d="M12 22c2.7 0 5-.9 6.7-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.7-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z"/>
    <path fill="#FBBC05" d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z"/>
    <path fill="#EA4335" d="M12 5.9c1.5 0 2.8.5 3.8 1.5L18.6 4.6A10 10 0 0 0 12 2 10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.6 9.4 5.9 12 5.9z"/>
  </svg>
);
const IcConfetti = (p) => <Icon {...p}><path d="M4 20l3-9 6 6zM12 11l4-6M16 5l3 3M19 8l-1 4M14 3v3M20 14l2 1M9 4l1 2"/></Icon>;
const IcShare = (p) => <Icon {...p}><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="18" cy="18" r="2.5"/><path d="m8.2 11 7.6-4M8.2 13l7.6 4"/></Icon>;

Object.assign(window, {
  Icon, IcHanger, IcSparkle, IcBookmark, IcUser, IcSearch, IcBell, IcPlus, IcBack,
  IcClose, IcCheck, IcShuffle, IcThumbUp, IcThumbDown, IcHeart, IcCamera, IcImage,
  IcFlash, IcEdit, IcTrash, IcChev, IcSun, IcPhone, IcGoogle, IcConfetti, IcShare,
});

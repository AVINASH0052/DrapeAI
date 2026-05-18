// app.jsx — main router / state machine

const ROUTES = {
  splash: 'splash',
  login: 'login',
  otpPhone: 'otpPhone',
  otpCode: 'otpCode',
  quiz: 'quiz',
  quizDone: 'quizDone',
  demo: 'demo',
  wardrobe: 'wardrobe',
  wardrobeEmpty: 'wardrobeEmpty',
  search: 'search',
  camera: 'camera',
  photoPreview: 'photoPreview',
  aiTag: 'aiTag',
  itemDetail: 'itemDetail',
  outfits: 'outfits',
  shuffle: 'shuffle',
  lookbooks: 'lookbooks',
  lookbookDetail: 'lookbookDetail',
  profile: 'profile',
};

// Tabs that show bottom nav + the route to start each tab on
const TAB_ROUTES = {
  wardrobe: 'wardrobe',
  outfits: 'outfits',
  looks: 'lookbooks',
  profile: 'profile',
};

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "device": "ios",
  "startScreen": "wardrobe",
  "cardVariant": "default",
  "imageMode": "silhouette",
  "showAllSections": false
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  // Route state — initialize from tweak so users can jump to a starting screen
  const initRoute = t.startScreen === 'splash' ? 'splash' :
                    t.startScreen === 'login' ? 'login' :
                    t.startScreen === 'quiz' ? 'quiz' :
                    t.startScreen === 'wardrobe' ? 'wardrobe' :
                    t.startScreen === 'outfits' ? 'outfits' :
                    t.startScreen === 'lookbooks' ? 'lookbooks' :
                    'splash';
  const [route, setRoute] = React.useState(initRoute);
  const [history, setHistory] = React.useState([initRoute]);

  // Auth / quiz / app state
  const [phone, setPhone] = React.useState('98765 43210');
  const [country, setCountry] = React.useState('+91');
  const [quizStep, setQuizStep] = React.useState(1);
  const [quizData, setQuizData] = React.useState({ gender: 'w', style: ['min'], occ: ['casual'], colors: ['neutral'], fit: 'regular', city: 'Mumbai', climate: 'tropical' });
  const [region, setRegion] = React.useState('India');

  // Wardrobe
  const [items, setItems] = React.useState(WARDROBE);
  const [filter, setFilter] = React.useState('all');
  const [activeItem, setActiveItem] = React.useState(null);
  const [photoOf, setPhotoOf] = React.useState(null);

  // Outfits state
  const [occasion, setOccasion] = React.useState('casual');
  const [savedSet, setSavedSet] = React.useState(new Set());
  const [likes, setLikes] = React.useState(new Set());
  const [dislikes, setDislikes] = React.useState(new Set());

  // Sheets
  const [sheet, setSheet] = React.useState(null);
  const [activeLookbook, setActiveLookbook] = React.useState(null);

  // Tab tracking — keep highlight in sync
  const [activeTab, setActiveTab] = React.useState('wardrobe');

  // Reset starting screen back to wardrobe so future toggles work cleanly
  React.useEffect(() => {
    if (t.startScreen !== 'wardrobe') setTweak('startScreen', 'wardrobe');
  }, []);

  // Navigation helpers
  const go = (r, push = true) => {
    setRoute(r);
    if (push) setHistory(h => [...h, r]);
  };
  const back = () => {
    setHistory(h => {
      const n = h.slice(0, -1);
      const prev = n[n.length - 1] || 'wardrobe';
      setRoute(prev);
      return n;
    });
  };
  const switchTab = (tab) => {
    const r = TAB_ROUTES[tab];
    setActiveTab(tab);
    setRoute(r);
    setHistory([r]);
  };

  const onSave = (oid) => {
    setSavedSet(s => {
      const n = new Set(s); n.has(oid) ? n.delete(oid) : n.add(oid); return n;
    });
  };

  // Render the current route
  const renderRoute = () => {
    switch (route) {
      case 'splash':       return <ScreenSplash onDone={() => go('login')}/>;
      case 'login':        return <ScreenLogin onPhone={() => go('otpPhone')} onGoogle={() => { setQuizStep(1); go('quiz'); }}/>;
      case 'otpPhone':     return <ScreenOtpPhone onBack={back} onSend={() => go('otpCode')} country={country} setCountry={setCountry}/>;
      case 'otpCode':      return <ScreenOtpCode onBack={back} onVerify={() => { setQuizStep(1); go('quiz'); }} phone={`${country} ${phone}`}/>;
      case 'quiz':         return <ScreenQuiz step={quizStep} data={quizData} setData={setQuizData}
                                   onBack={() => { if (quizStep > 1) setQuizStep(quizStep - 1); else back(); }}
                                   onNext={() => { if (quizStep < 6) setQuizStep(quizStep + 1); else go('quizDone'); }}/>;
      case 'quizDone':     return <ScreenQuizDone data={quizData} onContinue={() => go('demo')}/>;
      case 'demo':         return <ScreenDemoChoice
                                   onAdd={() => { setItems([]); setActiveTab('wardrobe'); go('wardrobeEmpty'); }}
                                   onDemo={() => { setItems(WARDROBE); setActiveTab('wardrobe'); go('wardrobe'); setTimeout(() => setSheet('firstOutfit'), 600); }}/>;
      case 'wardrobe':     return <ScreenWardrobe items={items} filter={filter} setFilter={setFilter}
                                   gender={quizData.gender}
                                   onItem={(it) => { setActiveItem(it); go('itemDetail'); }}
                                   onSearch={() => go('search')}
                                   onAddItem={() => go('camera')}/>;
      case 'wardrobeEmpty': return <ScreenWardrobeEmpty onAddItem={() => go('camera')}/>;
      case 'search':       return <ScreenSearch items={items} onBack={back}/>;
      case 'camera':       return <ScreenCamera onBack={back} onShoot={() => { setPhotoOf(WARDROBE[3]); go('photoPreview'); }}/>;
      case 'photoPreview': return <ScreenPhotoPreview photoOf={photoOf} onRetake={back} onUse={() => go('aiTag')}/>;
      case 'aiTag':        return <ScreenAITagReview photoOf={photoOf} onBack={back} onSave={() => {
                                    // pretend save — add a new item if wardrobe was empty
                                    if (items.length === 0) { setItems([photoOf || WARDROBE[3]]); setActiveTab('wardrobe'); setRoute('wardrobe'); setHistory(['wardrobe']); }
                                    else { setActiveTab('wardrobe'); setRoute('wardrobe'); setHistory(['wardrobe']); }
                                  }}/>;
      case 'itemDetail':   return activeItem && <ScreenItemDetail item={activeItem} onBack={back}
                                   onEdit={() => { setPhotoOf(activeItem); go('aiTag'); }}
                                   onDelete={back}/>;
      case 'outfits':      return <ScreenOutfits region={region}
                                   savedSet={savedSet} onSave={onSave}
                                   likes={likes} setLikes={setLikes}
                                   dislikes={dislikes} setDislikes={setDislikes}
                                   occasion={occasion} setOccasion={setOccasion}
                                   onShuffle={() => go('shuffle')}
                                   cardVariant={t.cardVariant}/>;
      case 'shuffle':      return <ScreenShuffle onBack={back} onSave={onSave}/>;
      case 'lookbooks':    return <ScreenLookbooks onOpen={(lb) => { setActiveLookbook(lb); go('lookbookDetail'); }}
                                   onCreate={() => {}}/>;
      case 'lookbookDetail': return activeLookbook && <ScreenLookbookDetail lb={activeLookbook} onBack={back}
                                   savedSet={savedSet} onSave={onSave}
                                   likes={likes} setLikes={setLikes}
                                   dislikes={dislikes} setDislikes={setDislikes}
                                   cardVariant={t.cardVariant}/>;
      case 'profile':      return <ScreenProfile items={items} savedCount={savedSet.size} region={region} setRegion={setRegion}
                                   gender={quizData.gender}
                                   onRetake={() => { setQuizStep(1); go('quiz'); }}/>;
      default: return <div style={{ padding: 40 }}>Unknown route: {route}</div>;
    }
  };

  // Determine if bottom nav shows — only for the 4 main tabs
  const showNav = ['wardrobe', 'wardrobeEmpty', 'outfits', 'lookbooks', 'profile'].includes(route);
  // Determine which tab to highlight
  const navTab = ['wardrobe','wardrobeEmpty'].includes(route) ? 'wardrobe'
              : route === 'outfits' ? 'outfits'
              : route === 'lookbooks' ? 'looks'
              : route === 'profile' ? 'profile'
              : null;

  // Status bar text color — light on dark camera screens
  const darkStatusBar = ['camera','photoPreview'].includes(route);

  const DeviceFrame = t.device === 'android' ? AndroidDevice : IOSDevice;
  const frameProps = t.device === 'android'
    ? { width: 412, height: 892 }
    : { width: 393, height: 852 };

  return (
    <ImgModeProvider value={t.imageMode}>
      <div style={{ minHeight: '100vh', display:'grid', placeItems:'center', padding: '40px 20px' }}>
        <DeviceFrame {...frameProps} statusBar={false}>
          <div className="app" key={t.device}>
            {/* fake status bar inside app — we draw our own to control color */}
            <FakeStatusBar dark={darkStatusBar}/>
            <div key={route} style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0, animation: 'fadeIn .2s ease' }}>
              {renderRoute()}
            </div>
            {showNav && <BottomNav active={navTab} onChange={switchTab}/>}
            {sheet === 'firstOutfit' && <SheetFirstOutfit onClose={() => setSheet(null)} onSee={() => { setSheet(null); switchTab('outfits'); }}/>}
          </div>
        </DeviceFrame>
      </div>

      <TweaksPanel>
        <TweakSection label="Device"/>
        <TweakRadio label="Platform" value={t.device}
          options={[{value:'ios',label:'iOS'},{value:'android',label:'Android'}]}
          onChange={(v) => setTweak('device', v)}/>

        <TweakSection label="Imagery"/>
        <TweakRadio label="Style" value={t.imageMode}
          options={[{value:'silhouette',label:'Silhouette'},{value:'photo',label:'Photos'}]}
          onChange={(v) => setTweak('imageMode', v)}/>

        <TweakSection label="Jump to screen"/>
        <TweakSelect label="Screen" value={route}
          options={[
            { value: 'splash', label: '01 · Splash' },
            { value: 'login', label: '02 · Login' },
            { value: 'otpPhone', label: '03a · OTP Phone' },
            { value: 'otpCode', label: '03b · OTP Code' },
            { value: 'quiz', label: '04 · Quiz (step 1)' },
            { value: 'quizDone', label: '04f · Quiz complete' },
            { value: 'demo', label: '05 · Demo choice' },
            { value: 'wardrobe', label: '06 · Wardrobe' },
            { value: 'wardrobeEmpty', label: '07 · Wardrobe empty' },
            { value: 'camera', label: '08 · Camera' },
            { value: 'photoPreview', label: '09 · Photo preview' },
            { value: 'aiTag', label: '10 · AI tag review' },
            { value: 'itemDetail', label: '11 · Item detail' },
            { value: 'outfits', label: '12 · Today\u2019s outfits' },
            { value: 'shuffle', label: '13 · Shuffle' },
            { value: 'lookbooks', label: '14 · Lookbooks' },
            { value: 'lookbookDetail', label: '15 · Lookbook detail' },
            { value: 'profile', label: '16 · Profile' },
            { value: 'search', label: '18 · Search' },
          ]}
          onChange={(v) => {
            if (v === 'itemDetail') setActiveItem(WARDROBE[0]);
            if (v === 'lookbookDetail') setActiveLookbook(LOOKBOOKS[0]);
            if (v === 'wardrobeEmpty') setItems([]);
            else if (v === 'wardrobe') setItems(WARDROBE);
            if (v === 'photoPreview' || v === 'aiTag') setPhotoOf(WARDROBE[3]);
            setRoute(v); setHistory([v]);
          }}/>

        <TweakSection label="Variations"/>
        <TweakRadio label="Outfit card" value={t.cardVariant}
          options={[{value:'default',label:'Default'},{value:'magazine',label:'Editorial'}]}
          onChange={(v) => setTweak('cardVariant', v)}/>

        <TweakSection label="Sheets"/>
        <TweakButton label="Trigger first-outfit sheet" onClick={() => { setRoute('wardrobe'); setHistory(['wardrobe']); setSheet('firstOutfit'); }}/>
      </TweaksPanel>
    </ImgModeProvider>
  );
}

// A more minimal in-app status bar so we can control color
function FakeStatusBar({ dark }) {
  const c = dark ? '#fff' : '#181715';
  return (
    <div style={{
      display:'flex', alignItems:'center', justifyContent:'space-between',
      padding:'14px 24px 6px', flexShrink: 0,
      color: c,
    }}>
      <span style={{ fontFamily: '-apple-system, "SF Pro", system-ui', fontWeight: 600, fontSize: 15 }}>9:41</span>
      <span style={{ display:'flex', alignItems:'center', gap: 6 }}>
        <svg width="17" height="11" viewBox="0 0 17 11"><g fill={c}>
          <rect x="0" y="7" width="2.5" height="4" rx="0.6"/>
          <rect x="4" y="5" width="2.5" height="6" rx="0.6"/>
          <rect x="8" y="2.5" width="2.5" height="8.5" rx="0.6"/>
          <rect x="12" y="0" width="2.5" height="11" rx="0.6"/>
        </g></svg>
        <svg width="14" height="10" viewBox="0 0 14 10" fill="none" stroke={c} strokeWidth="1.4"><path d="M1 4Q7 -1, 13 4 M3 6Q7 3, 11 6 M5.5 8Q7 7, 8.5 8" strokeLinecap="round"/></svg>
        <svg width="24" height="11" viewBox="0 0 24 11"><rect x="0.5" y="0.5" width="20" height="10" rx="2.5" fill="none" stroke={c} strokeOpacity=".4"/><rect x="2" y="2" width="17" height="7" rx="1.5" fill={c}/><rect x="21" y="4" width="1.5" height="3" rx="0.7" fill={c} opacity=".4"/></svg>
      </span>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App/>);

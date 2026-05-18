import { useState, useEffect, useRef } from "react";
import { ChevronRight, Search, SlidersHorizontal, Camera, Image, Plus, Sun, Shuffle, X, ArrowLeft, Lightbulb, Check, Edit3, User, Bell, Info, LogOut, BookOpen, Heart, Shirt, ChevronDown } from "lucide-react";

// ─── Design Tokens ───────────────────────────────────────────────
const T = {
  bg: "#FAFAF9",
  stone: "#E8E4DF",
  stoneMid: "#D5CFC8",
  accent: "#C4603A",
  accentLight: "#F5E6DF",
  accentDark: "#A34E2E",
  gray900: "#1A1A1A",
  gray700: "#3D3D3D",
  gray500: "#6B7280",
  gray400: "#9CA3AF",
  gray200: "#E5E7EB",
  gray100: "#F3F4F6",
  gray50: "#F9FAFB",
  white: "#FFFFFF",
  red: "#EF4444",
  green: "#22C55E",
  amber: "#F59E0B",
  radius: { card: 14, input: 8, pill: 999, button: 999 },
  font: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
};

// ─── Reusable Styles ─────────────────────────────────────────────
const pill = (active, accent = T.accent) => ({
  display: "inline-flex", alignItems: "center", gap: 6,
  padding: "8px 18px", borderRadius: T.radius.pill, cursor: "pointer",
  fontSize: 13, fontWeight: 500, fontFamily: T.font, border: "none",
  transition: "all 0.2s ease",
  background: active ? accent : T.stone,
  color: active ? T.white : T.gray700,
});

const btnPrimary = (disabled) => ({
  width: "100%", padding: "15px 0", borderRadius: T.radius.pill,
  background: disabled ? T.stoneMid : T.accent, color: T.white,
  border: "none", fontSize: 16, fontWeight: 600, fontFamily: T.font,
  cursor: disabled ? "not-allowed" : "pointer",
  transition: "all 0.15s ease", opacity: disabled ? 0.6 : 1,
  letterSpacing: "0.01em",
});

const btnOutline = {
  width: "100%", padding: "15px 0", borderRadius: T.radius.pill,
  background: "transparent", color: T.gray900,
  border: `1.5px solid ${T.gray200}`, fontSize: 16, fontWeight: 500,
  fontFamily: T.font, cursor: "pointer", transition: "all 0.15s ease",
  display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
};

const heading = (size = 28) => ({
  fontFamily: T.font, fontSize: size, fontWeight: 700, color: T.gray900,
  letterSpacing: "-0.02em", lineHeight: 1.15, margin: 0,
});

const body = (color = T.gray500) => ({
  fontFamily: T.font, fontSize: 15, fontWeight: 400, color, lineHeight: 1.5, margin: 0,
});

const label = (color = T.gray700) => ({
  fontFamily: T.font, fontSize: 14, fontWeight: 500, color, margin: 0,
});

const caption = (color = T.gray500) => ({
  fontFamily: T.font, fontSize: 12, fontWeight: 400, color, margin: 0,
});

// iPhone frame
const PHONE = { w: 375, h: 812 };

// ─── Phone Frame Wrapper ─────────────────────────────────────────
function PhoneFrame({ children, title }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
      {title && <p style={{ ...caption(T.gray500), marginBottom: 8, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>{title}</p>}
      <div style={{
        width: PHONE.w, height: PHONE.h, borderRadius: 40,
        background: T.bg, overflow: "hidden", position: "relative",
        boxShadow: "0 25px 60px rgba(0,0,0,0.12), 0 4px 16px rgba(0,0,0,0.06)",
        border: `1px solid ${T.gray200}`,
      }}>
        {/* Status bar */}
        <div style={{ height: 54, padding: "14px 28px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontFamily: T.font, fontSize: 15, fontWeight: 600, color: T.gray900 }}>9:41</span>
          <div style={{ display: "flex", gap: 5, alignItems: "center" }}>
            <div style={{ width: 17, height: 11, borderRadius: 2, border: `1.5px solid ${T.gray900}`, position: "relative" }}>
              <div style={{ position: "absolute", top: 2, left: 2, right: 3, bottom: 2, background: T.gray900, borderRadius: 1 }} />
              <div style={{ position: "absolute", right: -4, top: 3, width: 2, height: 5, background: T.gray900, borderRadius: "0 1px 1px 0" }} />
            </div>
          </div>
        </div>
        <div style={{ height: PHONE.h - 54, overflow: "hidden", display: "flex", flexDirection: "column" }}>
          {children}
        </div>
      </div>
    </div>
  );
}

// ─── 1. Auth Screen ──────────────────────────────────────────────
function AuthScreen() {
  const [phone, setPhone] = useState("");
  const [otpSent, setOtpSent] = useState(false);
  const [otp, setOtp] = useState("");
  const [focused, setFocused] = useState(null);

  return (
    <PhoneFrame title="Login / Auth">
      <div style={{ flex: 1, padding: "0 24px", overflow: "auto" }}>
        <div style={{ height: 48 }} />
        <h1 style={{ ...heading(32), marginBottom: 8 }}>DrapeAI</h1>
        <p style={{ ...body(), marginBottom: 48 }}>Your AI-powered personal stylist</p>

        {!otpSent ? (
          <>
            <p style={{ ...label(), marginBottom: 8 }}>Phone number</p>
            <div style={{ display: "flex", gap: 8, marginBottom: 20 }}>
              <div style={{
                padding: "13px 14px", background: T.gray50, border: `1.5px solid ${T.gray200}`,
                borderRadius: T.radius.input, fontFamily: T.font, fontSize: 16, color: T.gray900,
                display: "flex", alignItems: "center", gap: 4,
              }}>
                <span>+91</span>
                <ChevronDown size={14} color={T.gray400} />
              </div>
              <input
                value={phone} onChange={e => setPhone(e.target.value)}
                onFocus={() => setFocused("phone")} onBlur={() => setFocused(null)}
                placeholder="10-digit mobile number"
                maxLength={10}
                style={{
                  flex: 1, padding: "13px 16px", background: T.gray50,
                  border: `1.5px solid ${focused === "phone" ? T.accent : T.gray200}`,
                  borderRadius: T.radius.input, fontFamily: T.font, fontSize: 16,
                  outline: "none", transition: "border-color 0.2s ease", color: T.gray900,
                }}
              />
            </div>
            <button style={btnPrimary(phone.length !== 10)} onClick={() => phone.length === 10 && setOtpSent(true)}>
              Send OTP
            </button>
          </>
        ) : (
          <>
            <p style={{ ...label(), marginBottom: 8 }}>Enter OTP</p>
            <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
              {[0,1,2,3,4,5].map(i => (
                <input key={i} maxLength={1}
                  value={otp[i] || ""}
                  onChange={e => {
                    const v = otp.split("");
                    v[i] = e.target.value;
                    setOtp(v.join(""));
                    if (e.target.value && e.target.nextElementSibling) e.target.nextElementSibling.focus();
                  }}
                  style={{
                    width: 44, height: 52, textAlign: "center", fontSize: 20, fontWeight: 600,
                    fontFamily: T.font, background: T.gray50, border: `1.5px solid ${T.gray200}`,
                    borderRadius: T.radius.input, outline: "none", color: T.gray900,
                  }}
                />
              ))}
            </div>
            <p style={{ ...caption(), marginBottom: 20 }}>Sent to +91 {phone}</p>
            <button style={btnPrimary(otp.length !== 6)}>Verify</button>
            <button onClick={() => { setOtpSent(false); setOtp(""); }}
              style={{ ...body(T.accent), background: "none", border: "none", cursor: "pointer", marginTop: 12, fontWeight: 500, padding: 0 }}>
              Change number
            </button>
          </>
        )}

        <div style={{ display: "flex", alignItems: "center", gap: 16, margin: "28px 0" }}>
          <div style={{ flex: 1, height: 1, background: T.gray200 }} />
          <span style={caption()}>or</span>
          <div style={{ flex: 1, height: 1, background: T.gray200 }} />
        </div>

        <button style={btnOutline}>
          <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#FFC107" d="M43.6 20.1H42V20H24v8h11.3a12 12 0 01-4.7 5.6l6.5 5A20 20 0 0044 24c0-1.3-.2-2.7-.4-3.9z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8A12 12 0 0124 12c3 0 5.7 1.1 7.8 2.9l6-6A20 20 0 004 24c0 4 1.2 7.7 3.2 10.8l7.5-5.3A12 12 0 0112 24c0-1.7.4-3.3 1-4.8"/><path fill="#4CAF50" d="M24 44c5 0 9.5-1.8 13-4.9l-6.5-5a12 12 0 01-18.3-6.3l-6.6 4.7A20 20 0 0024 44z"/><path fill="#1976D2" d="M43.6 20.1H42V20H24v8h11.3a12 12 0 01-4.7 5.6l6.5 5c-.5.4 7-5 7-14.6 0-1.3-.2-2.7-.4-3.9z"/></svg>
          Continue with Google
        </button>

        <p style={{ ...caption(), textAlign: "center", marginTop: 32, lineHeight: 1.6 }}>
          By continuing, you agree to our <span style={{ color: T.accent, fontWeight: 500 }}>Terms</span> and <span style={{ color: T.accent, fontWeight: 500 }}>Privacy Policy</span>
        </p>
      </div>
    </PhoneFrame>
  );
}

// ─── 2. Onboarding ───────────────────────────────────────────────
function OnboardingScreen() {
  const [step, setStep] = useState(0);
  const [gender, setGender] = useState(null);
  const [age, setAge] = useState(null);
  const [styles, setStyles] = useState([]);
  const [colors, setColors] = useState([]);
  const [city, setCity] = useState("");
  const totalSteps = 5;

  const genderOptions = [
    { val: "male", label: "Male", icon: "👔" },
    { val: "female", label: "Female", icon: "👗" },
    { val: "non_binary", label: "Non-binary", icon: "✨" },
  ];
  const ageOptions = ["18-24", "25-34", "35-44", "45+"];
  const styleOptions = ["Casual Upgrade", "Work Ready", "Ethnic Modern", "Minimal", "Streetwear", "Classic"];
  const colorOptions = [
    { name: "Earth Tones", colors: ["#8B6914", "#6B4226", "#A0522D"] },
    { name: "Pastels", colors: ["#FFB5C2", "#B5D8FF", "#C5FFB5"] },
    { name: "Bold & Bright", colors: ["#FF2D55", "#FFCC00", "#007AFF"] },
    { name: "Monochrome", colors: ["#000", "#666", "#CCC"] },
    { name: "Jewel Tones", colors: ["#6B21A8", "#065F46", "#92400E"] },
    { name: "Neutrals", colors: ["#D4C5B0", "#B8A99A", "#E8DDD0"] },
  ];

  const canProceed = step === 0 ? gender : step === 1 ? age : step === 2 ? styles.length > 0 : step === 3 ? colors.length > 0 : city.length > 0;

  return (
    <PhoneFrame title="Onboarding">
      <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 20px" }}>
        {/* Progress */}
        <div style={{ padding: "8px 0 4px" }}>
          <div style={{ height: 3, background: T.stone, borderRadius: 2, overflow: "hidden" }}>
            <div style={{
              height: "100%", background: T.accent, borderRadius: 2,
              width: `${((step + 1) / totalSteps) * 100}%`,
              transition: "width 0.4s ease",
            }} />
          </div>
          <p style={{ ...caption(), textAlign: "center", marginTop: 6 }}>{step + 1} of {totalSteps}</p>
        </div>

        <div style={{ flex: 1, overflow: "auto", paddingTop: 16 }}>
          {step === 0 && (
            <>
              <h2 style={heading(24)}>How do you identify?</h2>
              <p style={{ ...body(), marginTop: 8, marginBottom: 28 }}>This helps us personalize recommendations</p>
              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                {genderOptions.map(g => (
                  <div key={g.val} onClick={() => setGender(g.val)}
                    style={{
                      padding: "20px", borderRadius: T.radius.card, cursor: "pointer",
                      background: gender === g.val ? T.accentLight : T.white,
                      border: `2px solid ${gender === g.val ? T.accent : T.gray200}`,
                      transition: "all 0.2s ease",
                      display: "flex", alignItems: "center", gap: 16,
                      boxShadow: gender === g.val ? "0 4px 16px rgba(196,96,58,0.12)" : "none",
                    }}>
                    <span style={{ fontSize: 32 }}>{g.icon}</span>
                    <span style={{ ...label(T.gray900), fontSize: 17 }}>{g.label}</span>
                    {gender === g.val && <Check size={20} color={T.accent} style={{ marginLeft: "auto" }} />}
                  </div>
                ))}
              </div>
            </>
          )}

          {step === 1 && (
            <>
              <h2 style={heading(24)}>What is your age range?</h2>
              <p style={{ ...body(), marginTop: 8, marginBottom: 28 }}>We tailor suggestions for your stage of life</p>
              <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
                {ageOptions.map(a => (
                  <div key={a} onClick={() => setAge(a)}
                    style={{
                      padding: "18px 20px", borderRadius: T.radius.card, cursor: "pointer",
                      background: age === a ? T.accentLight : T.white,
                      border: `2px solid ${age === a ? T.accent : T.gray200}`,
                      transition: "all 0.2s ease",
                      display: "flex", alignItems: "center", justifyContent: "space-between",
                    }}>
                    <span style={{ ...label(T.gray900), fontSize: 16 }}>{a}</span>
                    {age === a && <Check size={18} color={T.accent} />}
                  </div>
                ))}
              </div>
            </>
          )}

          {step === 2 && (
            <>
              <h2 style={heading(24)}>What are your style goals?</h2>
              <p style={{ ...body(), marginTop: 8, marginBottom: 24 }}>Pick up to 3</p>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                {styleOptions.map(s => {
                  const active = styles.includes(s);
                  return (
                    <button key={s} onClick={() => {
                      if (active) setStyles(styles.filter(x => x !== s));
                      else if (styles.length < 3) setStyles([...styles, s]);
                    }} style={pill(active)}>
                      {active && <Check size={14} />} {s}
                    </button>
                  );
                })}
              </div>
            </>
          )}

          {step === 3 && (
            <>
              <h2 style={heading(24)}>Color palettes you love?</h2>
              <p style={{ ...body(), marginTop: 8, marginBottom: 24 }}>Select all that appeal to you</p>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 12 }}>
                {colorOptions.map(c => {
                  const active = colors.includes(c.name);
                  return (
                    <div key={c.name} onClick={() => {
                      if (active) setColors(colors.filter(x => x !== c.name));
                      else setColors([...colors, c.name]);
                    }} style={{
                      width: "calc(50% - 6px)", padding: 16, borderRadius: T.radius.card, cursor: "pointer",
                      background: active ? T.accentLight : T.white,
                      border: `2px solid ${active ? T.accent : T.gray200}`,
                      transition: "all 0.2s ease", textAlign: "center",
                    }}>
                      <div style={{ display: "flex", justifyContent: "center", gap: 6, marginBottom: 10 }}>
                        {c.colors.map((col, i) => (
                          <div key={i} style={{ width: 28, height: 28, borderRadius: 99, background: col, border: `2px solid ${T.white}`, boxShadow: "0 1px 3px rgba(0,0,0,0.15)" }} />
                        ))}
                      </div>
                      <span style={label(active ? T.accent : T.gray700)}>{c.name}</span>
                    </div>
                  );
                })}
              </div>
            </>
          )}

          {step === 4 && (
            <>
              <h2 style={heading(24)}>Which city are you in?</h2>
              <p style={{ ...body(), marginTop: 8, marginBottom: 28 }}>We use this for weather-based outfit suggestions</p>
              <input value={city} onChange={e => setCity(e.target.value)}
                placeholder="e.g. Mumbai, Delhi, Bangalore"
                style={{
                  width: "100%", padding: "15px 16px", background: T.white,
                  border: `1.5px solid ${city ? T.accent : T.gray200}`,
                  borderRadius: T.radius.input, fontFamily: T.font, fontSize: 16,
                  outline: "none", transition: "border-color 0.2s", color: T.gray900,
                  boxSizing: "border-box",
                }}
              />
            </>
          )}
        </div>

        <div style={{ padding: "16px 0 24px" }}>
          <button style={btnPrimary(!canProceed)} onClick={() => canProceed && step < 4 && setStep(step + 1)}>
            {step === 4 ? "Get Started" : "Next"}
          </button>
        </div>
      </div>
    </PhoneFrame>
  );
}

// ─── 3. Wardrobe Screen ──────────────────────────────────────────
function WardrobeScreen() {
  const categories = ["All", "Tops", "Bottoms", "Footwear", "Ethnic", "Outerwear", "Accessories"];
  const [active, setActive] = useState("All");
  const items = [
    { brand: "Zara", color: "Navy", cat: "Tops", bg: "#2C3E6B" },
    { brand: "Uniqlo", color: "White", cat: "Tops", bg: "#E8E4DF" },
    { brand: "Levi's", color: "Indigo", cat: "Bottoms", bg: "#3B4D6B" },
    { brand: "Nike", color: "Black", cat: "Footwear", bg: "#2A2A2A" },
    { brand: "H&M", color: "Olive", cat: "Tops", bg: "#5C6B4E" },
    { brand: "FabIndia", color: "Cream", cat: "Ethnic", bg: "#D4C5B0" },
    { brand: "Adidas", color: "Grey", cat: "Footwear", bg: "#8B8B8B" },
    { brand: "Gap", color: "Beige", cat: "Bottoms", bg: "#C8B99A" },
    { brand: "Muji", color: "Brown", cat: "Accessories", bg: "#7B5B3A" },
  ];

  const filtered = active === "All" ? items : items.filter(i => i.cat === active);

  return (
    <PhoneFrame title="Wardrobe">
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        {/* Header */}
        <div style={{ padding: "4px 20px 12px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h1 style={heading(24)}>My Wardrobe</h1>
          <div style={{ display: "flex", gap: 4 }}>
            <div style={{ width: 40, height: 40, borderRadius: 99, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
              <Search size={20} color={T.gray700} />
            </div>
          </div>
        </div>

        {/* Category chips */}
        <div style={{ padding: "0 20px 12px", display: "flex", gap: 8, overflowX: "auto" }}>
          {categories.map(c => (
            <button key={c} onClick={() => setActive(c)} style={{
              ...pill(c === active), whiteSpace: "nowrap", flexShrink: 0,
            }}>{c}</button>
          ))}
        </div>

        {/* Grid */}
        <div style={{ flex: 1, overflow: "auto", padding: "0 20px 80px" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
            {filtered.map((item, i) => (
              <div key={i} style={{
                borderRadius: T.radius.card, overflow: "hidden", cursor: "pointer",
                background: T.white, border: `1px solid ${T.gray200}`,
                transition: "transform 0.15s ease",
              }}>
                <div style={{
                  aspectRatio: "3/4", background: item.bg, position: "relative",
                  display: "flex", alignItems: "flex-end",
                }}>
                  <div style={{
                    width: "100%", padding: "8px 8px 6px",
                    background: "linear-gradient(transparent, rgba(0,0,0,0.5))",
                  }}>
                    <p style={{ fontFamily: T.font, fontSize: 11, fontWeight: 600, color: T.white, margin: 0 }}>{item.brand}</p>
                    <p style={{ fontFamily: T.font, fontSize: 10, color: "rgba(255,255,255,0.8)", margin: 0 }}>{item.color}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* FAB */}
        <div style={{
          position: "absolute", bottom: 90, right: 24, width: 56, height: 56,
          borderRadius: 99, background: T.accent, display: "flex",
          alignItems: "center", justifyContent: "center", cursor: "pointer",
          boxShadow: "0 6px 20px rgba(196,96,58,0.35)",
        }}>
          <Camera size={22} color={T.white} />
        </div>

        {/* Bottom Nav */}
        <BottomNav active="wardrobe" />
      </div>
    </PhoneFrame>
  );
}

// ─── 4. Camera / Add Item ────────────────────────────────────────
function CameraAddScreen() {
  const [tipIdx, setTipIdx] = useState(0);
  const tips = [
    "Lay item flat on a plain surface",
    "Use natural lighting for best results",
    "Capture the full garment in frame",
    "Avoid shadows and wrinkles",
  ];

  useEffect(() => {
    const t = setInterval(() => setTipIdx(i => (i + 1) % tips.length), 3000);
    return () => clearInterval(t);
  }, []);

  return (
    <PhoneFrame title="Add Item">
      <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "0 20px" }}>
        {/* Top bar */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "4px 0 12px" }}>
          <div style={{ width: 40, height: 40, borderRadius: 99, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
            <X size={22} color={T.gray700} />
          </div>
          <span style={{ ...label(T.gray900), fontSize: 17, fontWeight: 600 }}>Add Item</span>
          <div style={{ width: 40 }} />
        </div>

        {/* Viewfinder area */}
        <div style={{
          flex: 1, borderRadius: 20, border: `2px dashed ${T.stoneMid}`,
          background: T.white, display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center", gap: 16,
          margin: "0 0 16px",
        }}>
          <div style={{ width: 72, height: 72, borderRadius: 99, background: T.accentLight, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Shirt size={32} color={T.accent} />
          </div>
          <p style={{ ...body(), textAlign: "center", padding: "0 32px" }}>Take a photo or choose from your gallery</p>
        </div>

        {/* Tip */}
        <div style={{
          padding: "12px 14px", borderRadius: T.radius.input,
          background: "#FFFBEB", display: "flex", alignItems: "center", gap: 10,
          marginBottom: 20,
        }}>
          <Lightbulb size={18} color={T.amber} />
          <span style={{ ...caption(T.gray700), flex: 1 }}>{tips[tipIdx]}</span>
        </div>

        {/* Buttons */}
        <div style={{ display: "flex", gap: 12, paddingBottom: 32 }}>
          <button style={{ ...btnPrimary(false), flex: 1, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <Camera size={18} /> Camera
          </button>
          <button style={{ ...btnOutline, flex: 1 }}>
            <Image size={18} /> Gallery
          </button>
        </div>
      </div>
    </PhoneFrame>
  );
}

// ─── 5. Tag Review ───────────────────────────────────────────────
function TagReviewScreen() {
  const tags = [
    { key: "Category", value: "Top" },
    { key: "Sub-category", value: "T-shirt" },
    { key: "Color", value: "Navy" },
    { key: "Pattern", value: "Solid" },
    { key: "Fabric", value: "Cotton" },
    { key: "Formality", value: "3" },
  ];
  const confidence = 87;

  return (
    <PhoneFrame title="Tag Review">
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        {/* Top bar */}
        <div style={{ display: "flex", alignItems: "center", padding: "4px 20px 12px", gap: 12 }}>
          <ArrowLeft size={22} color={T.gray700} style={{ cursor: "pointer" }} />
          <span style={{ ...label(T.gray900), fontSize: 17, fontWeight: 600 }}>Review Tags</span>
        </div>

        <div style={{ flex: 1, overflow: "auto", padding: "0 20px" }}>
          {/* Image */}
          <div style={{
            height: 260, borderRadius: 16, background: "#2C3E6B",
            marginBottom: 16, display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <Shirt size={64} color="rgba(255,255,255,0.3)" />
          </div>

          {/* Confidence */}
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 4 }}>
            <span style={label()}>AI Confidence: {confidence}%</span>
            <div style={{ flex: 1, height: 6, background: T.gray100, borderRadius: 3, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${confidence}%`, background: T.green, borderRadius: 3, transition: "width 0.5s ease" }} />
            </div>
          </div>
          <p style={{ ...caption(), marginBottom: 24 }}>Tap any tag to correct it</p>

          {/* Tags */}
          {tags.map(t => (
            <div key={t.key} style={{ display: "flex", alignItems: "center", marginBottom: 12 }}>
              <span style={{ ...caption(), width: 100, flexShrink: 0 }}>{t.key}</span>
              <div style={{
                display: "inline-flex", alignItems: "center", gap: 6,
                padding: "8px 14px", background: T.gray50, border: `1px solid ${T.gray200}`,
                borderRadius: T.radius.input, cursor: "pointer",
              }}>
                <span style={label()}>{t.value}</span>
                <Edit3 size={13} color={T.gray400} />
              </div>
            </div>
          ))}
        </div>

        <div style={{ padding: "16px 20px 32px" }}>
          <button style={btnPrimary(false)}>Confirm and Add to Wardrobe</button>
        </div>
      </div>
    </PhoneFrame>
  );
}

// ─── 6. Today's Outfits ─────────────────────────────────────────
function TodayScreen() {
  const occasions = ["Casual", "Work", "Party", "Date", "Festive", "Gym", "Travel"];
  const [active, setActive] = useState("Casual");
  const [shuffleRotation, setShuffleRotation] = useState(0);

  const outfitItems = [
    { type: "Zara Henley", color: "#2C3E6B" },
    { type: "Levi's 511", color: "#3B4D6B" },
    { type: "Nike Air Max", color: "#2A2A2A" },
  ];

  return (
    <PhoneFrame title="Today's Outfits">
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        <div style={{ padding: "4px 20px 8px" }}>
          <h1 style={heading(24)}>Today's Outfits</h1>
        </div>

        {/* Occasion chips */}
        <div style={{ padding: "0 20px 16px", display: "flex", gap: 8, overflowX: "auto" }}>
          {occasions.map(o => (
            <button key={o} onClick={() => setActive(o)} style={{ ...pill(o === active), flexShrink: 0 }}>{o}</button>
          ))}
        </div>

        {/* Generate button */}
        <div style={{ padding: "0 20px 16px" }}>
          <button style={btnPrimary(false)}>Generate Outfits</button>
        </div>

        <div style={{ flex: 1, overflow: "auto", padding: "0 20px 80px" }}>
          {/* Outfit Card */}
          <div style={{
            borderRadius: 20, background: T.white, border: `1px solid ${T.gray200}`,
            overflow: "hidden", boxShadow: "0 4px 20px rgba(0,0,0,0.06)",
          }}>
            {/* Date + Weather */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "16px 18px 0" }}>
              <span style={{ ...label(T.gray900), fontSize: 15 }}>Monday, Apr 21</span>
              <div style={{
                display: "flex", alignItems: "center", gap: 5, padding: "5px 12px",
                background: "#FFF8ED", borderRadius: 99,
              }}>
                <Sun size={14} color={T.amber} />
                <span style={{ fontFamily: T.font, fontSize: 13, fontWeight: 500, color: T.gray700 }}>28°C</span>
              </div>
            </div>

            {/* Flat-lay items */}
            <div style={{ padding: "20px 18px", display: "flex", gap: 10 }}>
              {outfitItems.map((item, i) => (
                <div key={i} style={{
                  flex: 1, aspectRatio: "1", borderRadius: 12, background: item.color,
                  display: "flex", alignItems: "flex-end", padding: 8,
                }}>
                  <span style={{ fontFamily: T.font, fontSize: 10, color: "rgba(255,255,255,0.8)", fontWeight: 500 }}>{item.type}</span>
                </div>
              ))}
            </div>

            {/* Actions */}
            <div style={{ display: "flex", gap: 10, padding: "0 18px 18px" }}>
              <button style={{ ...btnPrimary(false), flex: 1, padding: "12px 0", fontSize: 14 }}>
                Wear This
              </button>
              <button onClick={() => setShuffleRotation(r => r + 360)} style={{
                ...btnOutline, flex: 1, padding: "12px 0", fontSize: 14, width: "auto",
              }}>
                <Shuffle size={16} style={{ transition: "transform 0.6s cubic-bezier(0.34, 1.56, 0.64, 1)", transform: `rotate(${shuffleRotation}deg)` }} />
                Shuffle
              </button>
            </div>
          </div>
        </div>

        <BottomNav active="today" />
      </div>
    </PhoneFrame>
  );
}

// ─── 7. Lookbooks Screen ─────────────────────────────────────────
function LookbooksScreen() {
  const lookbooks = [
    { name: "Work Essentials", count: 8, h: 180, bg: "#C4603A" },
    { name: "Weekend Vibes", count: 5, h: 220, bg: "#5C6B4E" },
    { name: "Date Night", count: 3, h: 200, bg: "#6B21A8" },
    { name: "Festive Picks", count: 6, h: 160, bg: "#D4A56A" },
    { name: "Travel Light", count: 4, h: 190, bg: "#2C3E6B" },
  ];

  return (
    <PhoneFrame title="Lookbooks">
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        <div style={{ padding: "4px 20px 16px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h1 style={heading(24)}>Lookbooks</h1>
          <button style={{
            display: "flex", alignItems: "center", gap: 6, padding: "8px 16px",
            borderRadius: 99, border: `1.5px solid ${T.gray200}`, background: "transparent",
            fontFamily: T.font, fontSize: 13, fontWeight: 500, color: T.gray700, cursor: "pointer",
          }}>
            <Plus size={16} /> New
          </button>
        </div>

        <div style={{ flex: 1, overflow: "auto", padding: "0 20px 80px" }}>
          {/* Masonry layout */}
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 12 }}>
              {lookbooks.filter((_, i) => i % 2 === 0).map((lb, i) => (
                <div key={i} style={{
                  borderRadius: T.radius.card, overflow: "hidden", cursor: "pointer",
                  background: T.white, border: `1px solid ${T.gray200}`,
                }}>
                  <div style={{ height: lb.h, background: lb.bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <BookOpen size={32} color="rgba(255,255,255,0.3)" />
                  </div>
                  <div style={{ padding: "12px 14px" }}>
                    <p style={{ ...label(T.gray900), marginBottom: 2 }}>{lb.name}</p>
                    <p style={caption()}>{lb.count} outfits</p>
                  </div>
                </div>
              ))}
            </div>
            <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 12, paddingTop: 24 }}>
              {lookbooks.filter((_, i) => i % 2 === 1).map((lb, i) => (
                <div key={i} style={{
                  borderRadius: T.radius.card, overflow: "hidden", cursor: "pointer",
                  background: T.white, border: `1px solid ${T.gray200}`,
                }}>
                  <div style={{ height: lb.h, background: lb.bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <BookOpen size={32} color="rgba(255,255,255,0.3)" />
                  </div>
                  <div style={{ padding: "12px 14px" }}>
                    <p style={{ ...label(T.gray900), marginBottom: 2 }}>{lb.name}</p>
                    <p style={caption()}>{lb.count} outfits</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <BottomNav active="lookbooks" />
      </div>
    </PhoneFrame>
  );
}

// ─── 8. Profile Screen ───────────────────────────────────────────
function ProfileScreen() {
  const stats = [
    { label: "Items", count: 24 },
    { label: "Outfits", count: 12 },
    { label: "Lookbooks", count: 5 },
  ];
  const settings = [
    { icon: <SlidersHorizontal size={20} />, title: "Style Preferences", sub: "Update your style quiz answers" },
    { icon: <Bell size={20} />, title: "Notifications", sub: "Daily outfit reminders" },
    { icon: <Info size={20} />, title: "About DrapeAI", sub: "Version 1.0.0" },
  ];

  return (
    <PhoneFrame title="Profile">
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        {/* Gradient header */}
        <div style={{
          padding: "12px 20px 28px", textAlign: "center",
          background: `linear-gradient(to bottom, ${T.stone}, ${T.bg})`,
        }}>
          <div style={{
            width: 80, height: 80, borderRadius: 99, background: T.white,
            margin: "0 auto 14px", display: "flex", alignItems: "center", justifyContent: "center",
            border: `3px solid ${T.accentLight}`,
          }}>
            <User size={36} color={T.gray400} />
          </div>
          <p style={{ ...heading(20), marginBottom: 4 }}>Avi</p>
          <p style={caption()}>Member since Apr 2026</p>
        </div>

        {/* Stats */}
        <div style={{
          display: "flex", margin: "0 20px", padding: "16px 0",
          borderTop: `1px solid ${T.gray200}`, borderBottom: `1px solid ${T.gray200}`,
        }}>
          {stats.map((s, i) => (
            <div key={s.label} style={{
              flex: 1, textAlign: "center",
              borderRight: i < stats.length - 1 ? `1px solid ${T.gray200}` : "none",
            }}>
              <p style={{ fontFamily: T.font, fontSize: 22, fontWeight: 700, color: T.gray900, margin: "0 0 2px" }}>{s.count}</p>
              <p style={caption()}>{s.label}</p>
            </div>
          ))}
        </div>

        {/* Settings */}
        <div style={{ flex: 1, overflow: "auto", padding: "8px 20px 80px" }}>
          {settings.map(s => (
            <div key={s.title} style={{
              display: "flex", alignItems: "center", gap: 14, padding: "16px 0",
              borderBottom: `1px solid ${T.gray100}`, cursor: "pointer",
            }}>
              <div style={{ color: T.gray500 }}>{s.icon}</div>
              <div style={{ flex: 1 }}>
                <p style={label()}>{s.title}</p>
                <p style={{ ...caption(), marginTop: 2 }}>{s.sub}</p>
              </div>
              <ChevronRight size={18} color={T.gray400} />
            </div>
          ))}

          <div style={{
            display: "flex", alignItems: "center", gap: 14, padding: "16px 0",
            cursor: "pointer",
          }}>
            <LogOut size={20} color={T.accent} />
            <p style={{ ...label(T.accent), margin: 0 }}>Sign Out</p>
          </div>
        </div>

        <BottomNav active="profile" />
      </div>
    </PhoneFrame>
  );
}

// ─── Bottom Navigation ───────────────────────────────────────────
function BottomNav({ active }) {
  const tabs = [
    { id: "wardrobe", label: "Wardrobe", icon: <Shirt size={22} /> },
    { id: "today", label: "Today", icon: <Sun size={22} /> },
    { id: "shuffle", label: "Shuffle", icon: <Shuffle size={22} /> },
    { id: "lookbooks", label: "Lookbooks", icon: <BookOpen size={22} /> },
    { id: "profile", label: "Profile", icon: <User size={22} /> },
  ];

  return (
    <div style={{
      display: "flex", borderTop: `1px solid ${T.gray200}`,
      background: T.bg, padding: "8px 0 20px",
    }}>
      {tabs.map(t => (
        <div key={t.id} style={{
          flex: 1, display: "flex", flexDirection: "column", alignItems: "center",
          gap: 2, cursor: "pointer",
          color: active === t.id ? T.accent : T.gray400,
          transition: "color 0.2s ease",
        }}>
          {t.icon}
          <span style={{
            fontFamily: T.font, fontSize: 10, fontWeight: 500,
            opacity: active === t.id ? 1 : 0, height: active === t.id ? 14 : 0,
            overflow: "hidden", transition: "all 0.25s ease",
          }}>{t.label}</span>
        </div>
      ))}
    </div>
  );
}

// ─── Component Legend ─────────────────────────────────────────────
function ComponentLegend() {
  return (
    <div style={{
      background: T.white, borderRadius: 20, padding: "32px 28px",
      border: `1px solid ${T.gray200}`, maxWidth: 760,
      boxShadow: "0 4px 20px rgba(0,0,0,0.04)",
    }}>
      <h3 style={{ ...heading(20), marginBottom: 24 }}>Component Legend</h3>

      {/* Buttons */}
      <p style={{ ...label(), marginBottom: 12, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>Buttons</p>
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginBottom: 24 }}>
        <button style={{ ...btnPrimary(false), width: "auto", padding: "12px 28px" }}>Primary CTA</button>
        <button style={{ ...btnPrimary(true), width: "auto", padding: "12px 28px" }}>Disabled</button>
        <button style={{ ...btnOutline, width: "auto", padding: "12px 28px" }}>Outlined</button>
        <button style={{ background: "none", border: "none", fontFamily: T.font, fontSize: 14, fontWeight: 500, color: T.accent, cursor: "pointer" }}>Text Link</button>
      </div>

      {/* Chips */}
      <p style={{ ...label(), marginBottom: 12, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>Chips</p>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 24 }}>
        <span style={pill(true)}>Active Chip</span>
        <span style={pill(false)}>Inactive Chip</span>
        <span style={{
          display: "inline-flex", alignItems: "center", gap: 4, padding: "5px 12px",
          borderRadius: 99, background: "#FFF8ED", fontFamily: T.font, fontSize: 12, color: T.gray700,
        }}>
          <Sun size={12} color={T.amber} /> 28°C
        </span>
      </div>

      {/* Inputs */}
      <p style={{ ...label(), marginBottom: 12, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>Input States</p>
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginBottom: 24 }}>
        <input readOnly placeholder="Default input" style={{
          padding: "12px 16px", background: T.gray50, border: `1.5px solid ${T.gray200}`,
          borderRadius: T.radius.input, fontFamily: T.font, fontSize: 14, width: 160, outline: "none", color: T.gray900,
        }} />
        <input readOnly placeholder="Focused input" style={{
          padding: "12px 16px", background: T.gray50, border: `1.5px solid ${T.accent}`,
          borderRadius: T.radius.input, fontFamily: T.font, fontSize: 14, width: 160, outline: "none", color: T.gray900,
        }} />
        <input readOnly value="Filled input" style={{
          padding: "12px 16px", background: T.white, border: `1.5px solid ${T.accent}`,
          borderRadius: T.radius.input, fontFamily: T.font, fontSize: 14, width: 160, outline: "none", color: T.gray900,
        }} />
      </div>

      {/* Cards */}
      <p style={{ ...label(), marginBottom: 12, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>Card Types</p>
      <div style={{ display: "flex", gap: 12 }}>
        <div style={{ width: 100, borderRadius: T.radius.card, overflow: "hidden", border: `1px solid ${T.gray200}` }}>
          <div style={{ height: 120, background: "#2C3E6B" }} />
          <div style={{ padding: 8 }}>
            <p style={{ ...caption(), fontSize: 11 }}>Wardrobe Item</p>
          </div>
        </div>
        <div style={{ width: 140, borderRadius: T.radius.card, overflow: "hidden", border: `1px solid ${T.gray200}` }}>
          <div style={{ height: 90, background: T.accent }} />
          <div style={{ padding: 10 }}>
            <p style={{ ...label(), fontSize: 13, marginBottom: 2 }}>Lookbook</p>
            <p style={caption()}>8 outfits</p>
          </div>
        </div>
        <div style={{
          padding: "18px 20px", borderRadius: T.radius.card, background: T.accentLight,
          border: `2px solid ${T.accent}`,
        }}>
          <p style={{ fontFamily: T.font, fontSize: 13, fontWeight: 500, color: T.accent }}>Selected Option Card</p>
        </div>
      </div>

      {/* Colors */}
      <p style={{ ...label(), marginBottom: 12, marginTop: 24, textTransform: "uppercase", letterSpacing: "0.08em", fontSize: 11 }}>Color Palette</p>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        {[
          { name: "Background", hex: T.bg },
          { name: "Stone", hex: T.stone },
          { name: "Terracotta", hex: T.accent },
          { name: "Text Primary", hex: T.gray900 },
          { name: "Text Secondary", hex: T.gray500 },
          { name: "Border", hex: T.gray200 },
          { name: "Success", hex: T.green },
          { name: "Warning", hex: T.amber },
          { name: "Error", hex: T.red },
        ].map(c => (
          <div key={c.name} style={{ textAlign: "center" }}>
            <div style={{ width: 48, height: 48, borderRadius: 12, background: c.hex, border: `1px solid ${T.gray200}`, marginBottom: 4 }} />
            <p style={{ fontFamily: T.font, fontSize: 10, color: T.gray500 }}>{c.name}</p>
            <p style={{ fontFamily: T.font, fontSize: 9, color: T.gray400, textTransform: "uppercase" }}>{c.hex}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Main App ────────────────────────────────────────────────────
export default function DrapeAIPrototype() {
  const [view, setView] = useState("all");

  const views = [
    { id: "all", label: "All Screens" },
    { id: "auth", label: "Login" },
    { id: "onboarding", label: "Onboarding" },
    { id: "wardrobe", label: "Wardrobe" },
    { id: "camera", label: "Add Item" },
    { id: "tags", label: "Tag Review" },
    { id: "today", label: "Today" },
    { id: "lookbooks", label: "Lookbooks" },
    { id: "profile", label: "Profile" },
    { id: "legend", label: "Components" },
  ];

  const screens = {
    auth: <AuthScreen />,
    onboarding: <OnboardingScreen />,
    wardrobe: <WardrobeScreen />,
    camera: <CameraAddScreen />,
    tags: <TagReviewScreen />,
    today: <TodayScreen />,
    lookbooks: <LookbooksScreen />,
    profile: <ProfileScreen />,
  };

  return (
    <div style={{ minHeight: "100vh", background: "#F0EDEA", fontFamily: T.font }}>
      {/* Top nav */}
      <div style={{
        position: "sticky", top: 0, zIndex: 100, background: "rgba(240,237,234,0.9)",
        backdropFilter: "blur(12px)", WebkitBackdropFilter: "blur(12px)",
        borderBottom: `1px solid ${T.stone}`, padding: "16px 24px",
      }}>
        <div style={{ maxWidth: 1400, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
            <div>
              <h1 style={{ ...heading(22), display: "flex", alignItems: "center", gap: 10 }}>
                <span style={{ color: T.accent }}>DrapeAI</span>
                <span style={{ fontWeight: 400, color: T.gray400, fontSize: 16 }}>UI Prototype</span>
              </h1>
            </div>
            <p style={caption()}>375 x 812pt — iPhone 14</p>
          </div>
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {views.map(v => (
              <button key={v.id} onClick={() => setView(v.id)} style={{
                padding: "6px 14px", borderRadius: 99, border: "none",
                fontFamily: T.font, fontSize: 12, fontWeight: 500, cursor: "pointer",
                background: view === v.id ? T.accent : T.white,
                color: view === v.id ? T.white : T.gray700,
                transition: "all 0.15s ease",
              }}>{v.label}</button>
            ))}
          </div>
        </div>
      </div>

      {/* Content */}
      <div style={{ maxWidth: 1400, margin: "0 auto", padding: "40px 24px 60px" }}>
        {view === "all" ? (
          <>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 36, justifyContent: "center", marginBottom: 48 }}>
              {Object.entries(screens).map(([key, screen]) => (
                <div key={key} onClick={() => setView(key)} style={{ cursor: "pointer" }}>
                  {screen}
                </div>
              ))}
            </div>
            <div style={{ display: "flex", justifyContent: "center" }}>
              <ComponentLegend />
            </div>
          </>
        ) : view === "legend" ? (
          <div style={{ display: "flex", justifyContent: "center" }}>
            <ComponentLegend />
          </div>
        ) : (
          <div style={{ display: "flex", justifyContent: "center" }}>
            {screens[view]}
          </div>
        )}
      </div>
    </div>
  );
}
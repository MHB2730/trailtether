// Trailtether — Welcome / Onboarding screen
// Auto-rotating hero with per-pillar custom animation.

const FEATURES = [
{
  id: 'tether',
  eyebrow: 'STAY TETHERED',
  title: 'Someone at home, always watching.',
  body: 'Your phone broadcasts live position to a base-camp PC at home. No surveillance — just a tether.',
  color: '#ff6a2c'
},
{
  id: 'plan',
  eyebrow: 'PLAN',
  title: 'Know what you walk into.',
  body: 'Curated routes with distance, elevation, and live weather scored for hiking — not just temperature.',
  color: '#ff8a4d'
},
{
  id: 'navigate',
  eyebrow: 'NAVIGATE OFFLINE',
  title: '2D, 3D, and signal-dead.',
  body: 'Topographic, satellite, and terrain layers. Downloaded for offline. Speed-coloured trail recording.',
  color: '#ff6a2c'
},
{
  id: 'aware',
  eyebrow: 'STAY AWARE',
  title: 'Weather, hazards, and shelter.',
  body: 'Multi-source forecasts, community hazard reports, 125 surveyed Drakensberg caves and shelters built in.',
  color: '#f2a93b'
},
{
  id: 'sos',
  eyebrow: 'ACT FAST',
  title: 'One tap. Help on the way.',
  body: 'SOS shares your live location. Compass, flashlight, native emergency contacts — all one tap deep.',
  color: '#e63d2e'
}];


function ScreenWelcome() {
  const [idx, setIdx] = React.useState(0);
  const [paused, setPaused] = React.useState(false);

  React.useEffect(() => {
    if (paused) return;
    const t = setTimeout(() => setIdx((idx + 1) % FEATURES.length), 5200);
    return () => clearTimeout(t);
  }, [idx, paused]);

  const feat = FEATURES[idx];

  return (
    <div className="phone">
      <div className="punchhole" />
      <div className="screen">
        <StatusBar
          time="10:09"
          right={<span style={{ color: 'var(--tt-text-2)', fontSize: 10.5, fontWeight: 700, letterSpacing: '0.08em', marginRight: 4 }}>LTE</span>} />
        

        {/* Brand mark — top-left */}
        <div className="tt-appbar anim-in" style={{ paddingBottom: 6 }}>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 10 }}>
            <TTLogo size={26} />
            <span style={{ font: '800 14px var(--tt-font)', letterSpacing: '0.16em' }}>
              TRAIL<span style={{ color: 'var(--tt-ember)' }}>TETHER</span>
            </span>
          </div>
          <button className="pressable" style={{
            background: 'transparent', border: 'none', color: 'var(--tt-text-2)',
            font: '700 11px var(--tt-font)', letterSpacing: '0.1em', cursor: 'pointer',
            padding: '6px 4px'
          }}>SKIP</button>
        </div>

        {/* Hero illustration zone */}
        <div style={{ flex: '0 0 auto', position: 'relative', height: 340, overflow: 'hidden' }}>
          {/* topo backdrop */}
          <TopoBackdrop opacity={0.35} />
          {/* radial ember glow following the scene color */}
          <div style={{
            position: 'absolute', inset: 0,
            background: `radial-gradient(ellipse 80% 60% at 50% 55%, ${feat.color}22, transparent 70%)`,
            transition: 'background 700ms ease',
            pointerEvents: 'none'
          }} />

          {/* Scenes (only one visible at a time) */}
          {FEATURES.map((f, i) =>
          <div key={f.id} style={{
            position: 'absolute', inset: 0,
            opacity: i === idx ? 1 : 0,
            transform: i === idx ? 'scale(1)' : 'scale(0.98)',
            transition: 'opacity 700ms ease, transform 700ms ease',
            pointerEvents: i === idx ? 'auto' : 'none'
          }}>
              {i === idx && <Scene id={f.id} />}
            </div>
          )}
        </div>

        {/* Tagline + copy + indicator + CTAs */}
        <div className="tt-body" style={{ padding: '4px 22px 0', background: 'var(--tt-bg)' }}>
          {/* Tagline — never changes */}
          <div className="anim-up" style={{ textAlign: 'center', marginTop: 6, animationDelay: '180ms' }}>
            <h1 style={{ margin: 0, font: '800 26px/1.15 var(--tt-font)', letterSpacing: '-0.02em' }}>
              Plan smarter.<br />
              Hike safer.<br />
              <span style={{ color: 'var(--tt-ember)' }}>Stay connected on the trail.</span>
            </h1>
          </div>

          {/* Rotating eyebrow + title + body */}
          <div
            onMouseEnter={() => setPaused(true)}
            onMouseLeave={() => setPaused(false)}
            style={{ marginTop: 20, minHeight: 96, position: 'relative' }}>
            
            {FEATURES.map((f, i) =>
            <div key={f.id} style={{
              position: i === idx ? 'relative' : 'absolute',
              inset: 0,
              opacity: i === idx ? 1 : 0,
              transform: i === idx ? 'translateY(0)' : 'translateY(8px)',
              transition: 'opacity 500ms ease, transform 500ms ease',
              pointerEvents: i === idx ? 'auto' : 'none',
              textAlign: 'center'
            }}>
                <div style={{
                display: 'inline-flex', alignItems: 'center', gap: 6,
                padding: '4px 10px', borderRadius: 999,
                background: `${f.color}1f`, border: `1px solid ${f.color}55`,
                font: '800 9.5px var(--tt-mono)', color: f.color, letterSpacing: '0.18em'
              }}>
                  <span style={{ width: 5, height: 5, borderRadius: '50%', background: f.color, boxShadow: `0 0 5px ${f.color}` }} />
                  {f.eyebrow}
                </div>
                <div style={{ font: '700 15px/1.35 var(--tt-font)', color: 'var(--tt-text)', marginTop: 10, letterSpacing: '-0.005em' }}>{f.title}</div>
                <div style={{ font: '500 12px/1.5 var(--tt-font)', color: 'var(--tt-text-2)', marginTop: 6, padding: '0 4px' }}>{f.body}</div>
              </div>
            )}
          </div>

          {/* Dot indicator */}
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, marginTop: 18 }}>
            {FEATURES.map((f, i) =>
            <button
              key={f.id}
              onClick={() => setIdx(i)}
              style={{
                width: i === idx ? 22 : 6,
                height: 6,
                borderRadius: 3,
                background: i === idx ? 'var(--tt-ember)' : 'var(--tt-line-3)',
                border: 'none',
                padding: 0,
                cursor: 'pointer',
                transition: 'width 400ms cubic-bezier(0.2,0.7,0.2,1), background 400ms ease',
                boxShadow: i === idx ? '0 0 10px rgba(255,106,44,0.55)' : 'none'
              }} />

            )}
          </div>

          {/* CTAs */}
          <div style={{ marginTop: 'auto', paddingBottom: 14 }}>
            <button className="pressable" style={{
              width: '100%', height: 54, borderRadius: 14,
              border: 'none',
              background: 'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
              color: '#1a0d04',
              font: '900 13px var(--tt-font)', letterSpacing: '0.14em',
              cursor: 'pointer',
              boxShadow: 'var(--tt-shadow-ember)',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10,
              position: 'relative', overflow: 'hidden',
              marginTop: 22
            }}>
              {/* Inner shimmer band */}
              <span style={{
                position: 'absolute', inset: 0,
                background: 'linear-gradient(120deg, transparent 30%, rgba(255,255,255,0.32) 50%, transparent 70%)',
                backgroundSize: '200% 100%',
                animation: 'shimmer 3.5s infinite linear',
                pointerEvents: 'none'
              }} />
              <span style={{ position: 'relative' }}>GET STARTED</span>
              <Icon name="chevron-right" size={16} color="#1a0d04" strokeWidth={2.6} />
            </button>

            <div style={{ textAlign: 'center', marginTop: 14, font: '600 12px var(--tt-font)', color: 'var(--tt-text-3)' }}>
              Already have an account?
              <span style={{ color: 'var(--tt-ember)', fontWeight: 700, marginLeft: 6, cursor: 'pointer' }}>Sign in</span>
            </div>

            <div style={{ textAlign: 'center', marginTop: 16, font: '700 9.5px var(--tt-mono)', color: 'var(--tt-text-4)', letterSpacing: '0.16em' }}>FREE · NO ADS · BUILT IN SOUTH AFRICA, FOR SOUTH AFRICANS

            </div>
          </div>
        </div>
      </div>
    </div>);

}

/* ---------------------------------------------------------------- */
/* Scene illustrations — one per feature pillar                     */
/* ---------------------------------------------------------------- */
function Scene({ id }) {
  switch (id) {
    case 'tether':return <SceneTether />;
    case 'plan':return <ScenePlan />;
    case 'navigate':return <SceneNavigate />;
    case 'aware':return <SceneAware />;
    case 'sos':return <SceneSOS />;
    default:return null;
  }
}

/* === SCENE 1 · TETHER — phone on mountain ↔ basecamp PC === */
function SceneTether() {
  // The signature scene — phone connected to home PC over a glowing dashed tether
  return (
    <svg viewBox="0 0 412 340" preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <defs>
        <linearGradient id="mountainG" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#2a2f38" />
          <stop offset="100%" stopColor="#0d1116" />
        </linearGradient>
        <linearGradient id="emberArc" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.05" />
          <stop offset="50%" stopColor="#ff8a4d" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0.05" />
        </linearGradient>
        <filter id="tetherGlow"><feGaussianBlur stdDeviation="2.4" /></filter>
      </defs>

      {/* Mountain silhouette (left) */}
      <path d="M -10 280 L 60 180 L 100 220 L 140 140 L 180 200 L 220 250 L 220 340 L -10 340 Z"
      fill="url(#mountainG)" />
      <path d="M -10 280 L 60 180 L 100 220 L 140 140 L 180 200 L 220 250"
      fill="none" stroke="#3a4150" strokeWidth="1.2" strokeLinejoin="round" />
      {/* Snow caps */}
      <path d="M 55 188 L 60 180 L 65 190 Z" fill="#eef1f4" opacity="0.85" />
      <path d="M 135 148 L 140 140 L 146 152 L 142 150 Z" fill="#eef1f4" opacity="0.85" />

      {/* House silhouette (right) — base camp */}
      <g transform="translate(310,210)">
        <rect x="-30" y="0" width="60" height="46" fill="#1a2029" stroke="#3a4150" strokeWidth="1.2" />
        <path d="M -36 0 L 0 -28 L 36 0 Z" fill="#22293a" stroke="#3a4150" strokeWidth="1.2" strokeLinejoin="round" />
        <rect x="-10" y="14" width="20" height="32" fill="#0a0c0f" stroke="#3a4150" strokeWidth="0.8" />
        {/* Window glow */}
        <rect x="-22" y="10" width="10" height="10" fill="#ff8a4d" opacity="0.85">
          <animate attributeName="opacity" values="0.6;1;0.6" dur="2.2s" repeatCount="indefinite" />
        </rect>
        <rect x="12" y="10" width="10" height="10" fill="#ff8a4d" opacity="0.85">
          <animate attributeName="opacity" values="0.85;0.5;0.85" dur="2.2s" begin="0.4s" repeatCount="indefinite" />
        </rect>
        <text x="0" y="62" textAnchor="middle" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700" letterSpacing="0.2em">BASE  CAMP</text>
      </g>

      {/* Tether — dashed arc connecting phone-on-mountain ↔ house */}
      <path
        d="M 145 130 C 200 60, 270 60, 310 200"
        fill="none" stroke="url(#emberArc)" strokeWidth="2" strokeLinecap="round"
        strokeDasharray="4 6"
        style={{ filter: 'url(#tetherGlow)' }}>
        
        <animate attributeName="stroke-dashoffset" from="0" to="-100" dur="3s" repeatCount="indefinite" />
      </path>
      <path
        d="M 145 130 C 200 60, 270 60, 310 200"
        fill="none" stroke="#ff8a4d" strokeWidth="0.9" strokeLinecap="round"
        strokeDasharray="3 5">
        
        <animate attributeName="stroke-dashoffset" from="0" to="-80" dur="3s" repeatCount="indefinite" />
      </path>

      {/* Data packet pulses traveling the arc */}
      {[0, 1.5].map((d, i) =>
      <circle key={i} r="3.5" fill="#ff8a4d" filter="url(#tetherGlow)">
          <animateMotion path="M 145 130 C 200 60, 270 60, 310 200" dur="3s" begin={`${d}s`} repeatCount="indefinite" />
          <animate attributeName="opacity" values="0;1;1;0" dur="3s" begin={`${d}s`} repeatCount="indefinite" />
        </circle>
      )}

      {/* Phone on mountain peak */}
      <g transform="translate(140,130)">
        <rect x="-12" y="-22" width="24" height="44" rx="4" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="1.5" />
        <rect x="-9" y="-18" width="18" height="36" rx="2" fill="#1a0d04" />
        {/* Tiny screen content */}
        <circle r="1.5" cx="0" cy="-10" fill="#ff8a4d">
          <animate attributeName="opacity" values="0.5;1;0.5" dur="1.5s" repeatCount="indefinite" />
        </circle>
        <rect x="-6" y="-5" width="12" height="1.5" fill="#ff6a2c" opacity="0.7" />
        <rect x="-6" y="-1" width="9" height="1.5" fill="#ff6a2c" opacity="0.5" />
        <rect x="-6" y="3" width="11" height="1.5" fill="#ff6a2c" opacity="0.6" />

        {/* Pulse ring around phone */}
        <circle r="22" fill="none" stroke="#ff6a2c" strokeWidth="1.2" opacity="0.5">
          <animate attributeName="r" values="18;34;18" dur="2.4s" repeatCount="indefinite" />
          <animate attributeName="opacity" values="0.7;0;0.7" dur="2.4s" repeatCount="indefinite" />
        </circle>
      </g>

      {/* Floating data labels */}
      <g transform="translate(218,80)" opacity="0">
        <animate attributeName="opacity" values="0;1;1;0" dur="3s" begin="0.6s" repeatCount="indefinite" />
        <rect x="-30" y="-9" width="60" height="18" rx="4" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="0.7" />
        <text x="0" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700">GPS · 3m</text>
      </g>
      <g transform="translate(252,55)" opacity="0">
        <animate attributeName="opacity" values="0;1;1;0" dur="3s" begin="1.6s" repeatCount="indefinite" />
        <rect x="-30" y="-9" width="60" height="18" rx="4" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="0.7" />
        <text x="0" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700">+2° SE</text>
      </g>
    </svg>);

}

/* === SCENE 2 · PLAN — animated route + elevation profile === */
function ScenePlan() {
  const routeLen = 600;
  return (
    <svg viewBox="0 0 412 340" preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <defs>
        <linearGradient id="planFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </linearGradient>
        <filter id="planGlow"><feGaussianBlur stdDeviation="2.2" /></filter>
      </defs>

      {/* Map base */}
      <rect x="36" y="32" width="340" height="180" rx="14" fill="#0b1015" stroke="#1c2127" strokeWidth="1" />

      {/* Contours */}
      <g fill="none" stroke="#222a33" strokeWidth="0.6" opacity="0.8" clipPath="inset(32px 36px 128px 36px)">
        {['M40,180 Q120,160 200,170 T380,165',
        'M40,150 Q120,120 200,130 T380,125',
        'M40,120 Q120,85 200,95 T380,90',
        'M40,90  Q120,55 200,65 T380,60',
        'M40,60  Q120,40 200,40 T380,40'].map((d, i) => <path key={i} d={d} />)}
      </g>

      {/* Route */}
      <path d="M 70 180 Q 130 150 170 130 Q 220 100 280 85 L 340 50"
      fill="none" stroke="#ff6a2c" strokeWidth="5" strokeLinecap="round" filter="url(#planGlow)" opacity="0.7"
      className="draw-line" style={{ ['--len']: routeLen }} />
      <path d="M 70 180 Q 130 150 170 130 Q 220 100 280 85 L 340 50"
      fill="none" stroke="#ff8a4d" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"
      className="draw-line" style={{ ['--len']: routeLen, animationDelay: '80ms' }} />

      {/* Start + summit */}
      <g transform="translate(70,180)">
        <rect x="-5" y="-5" width="10" height="10" transform="rotate(45)" fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1.2" />
      </g>
      <g transform="translate(340,50)">
        <circle r="7" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="1.8" />
        <path d="M 0 -3 L -3 2 L 3 2 Z" fill="#ff6a2c" />
      </g>

      {/* Map title */}
      <g transform="translate(206,52)">
        <rect x="-66" y="-12" width="132" height="22" rx="5" fill="rgba(10,12,15,0.92)" stroke="rgba(255,255,255,0.15)" strokeWidth="0.5" />
        <text x="0" y="3" textAnchor="middle" fill="#eef1f4" fontFamily="Manrope" fontSize="10.5" fontWeight="800" letterSpacing="0.14em">WONDERLAND LOOP</text>
      </g>

      {/* Elevation card */}
      <g transform="translate(36,232)">
        <rect x="0" y="0" width="340" height="86" rx="12" fill="#131820" stroke="#1c2127" />
        <text x="14" y="20" fill="#5a6470" fontFamily="Manrope" fontSize="9.5" fontWeight="800" letterSpacing="0.16em">ELEVATION</text>

        {/* Animated elev fill + line */}
        <path d="M 14 70 Q 50 60 80 55 Q 120 40 160 28 Q 200 22 240 30 Q 280 40 320 32 L 326 32 L 326 78 L 14 78 Z"
        fill="url(#planFill)" className="anim-in" style={{ animationDelay: '500ms' }} />
        <path d="M 14 70 Q 50 60 80 55 Q 120 40 160 28 Q 200 22 240 30 Q 280 40 320 32"
        fill="none" stroke="#ff6a2c" strokeWidth="2" strokeLinecap="round"
        className="draw-line" style={{ ['--len']: 420, animationDelay: '400ms' }} />

        {/* Peak marker */}
        <line x1="220" y1="22" x2="220" y2="78" stroke="rgba(255,255,255,0.28)" strokeDasharray="2 2" />
        <circle cx="220" cy="22" r="3.5" fill="#fff" stroke="#ff6a2c" strokeWidth="1.5"
        className="anim-pop" style={{ animationDelay: '1100ms', transformOrigin: '220px 22px' }} />

        {/* Weather chip */}
        <g transform="translate(326,18)" className="anim-up" style={{ animationDelay: '700ms' }}>
          <rect x="-46" y="-10" width="46" height="20" rx="5" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="0.7" />
          <text x="-23" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="9" fontWeight="800">8/10 ☀</text>
        </g>
      </g>
    </svg>);

}

/* === SCENE 3 · NAVIGATE — compass + 3D terrain === */
function SceneNavigate() {
  return (
    <svg viewBox="0 0 412 340" preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <defs>
        <linearGradient id="terrainTop" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#3a4150" />
          <stop offset="100%" stopColor="#1a1f28" />
        </linearGradient>
        <linearGradient id="terrainSide" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#22293a" />
          <stop offset="100%" stopColor="#0a0c0f" />
        </linearGradient>
      </defs>

      {/* 3D isometric terrain block */}
      <g transform="translate(206,180)">
        {/* base shadow */}
        <ellipse cx="0" cy="100" rx="160" ry="22" fill="#000" opacity="0.6" />

        {/* Right face */}
        <path d="M 140 -20 L 140 50 L 0 100 L 0 30 Z" fill="url(#terrainSide)" />
        {/* Left face */}
        <path d="M -140 -20 L -140 50 L 0 100 L 0 30 Z" fill="#171c25" />
        {/* Top (mountains) */}
        <path d="M -140 -20 L -90 -65 L -55 -30 L -20 -85 L 20 -45 L 60 -90 L 100 -55 L 140 -20 L 0 30 Z"
        fill="url(#terrainTop)" stroke="#3a4150" strokeWidth="0.8" strokeLinejoin="round" />
        {/* Ridge highlights */}
        <path d="M -90 -65 L -20 -85" fill="none" stroke="#5a6470" strokeWidth="1" opacity="0.6" />
        <path d="M  20 -45 L  60 -90" fill="none" stroke="#5a6470" strokeWidth="1" opacity="0.6" />
        <path d="M -55 -30 L  20 -45" fill="none" stroke="#5a6470" strokeWidth="1" opacity="0.4" />

        {/* Snow on top peak */}
        <path d="M 56 -82 L 60 -90 L 64 -82 Z" fill="#eef1f4" opacity="0.85" />
        <path d="M -23 -78 L -20 -85 L -16 -78 Z" fill="#eef1f4" opacity="0.85" />

        {/* Trail traced over terrain */}
        <path d="M -110 20 Q -60 -10 -20 -10 Q 30 -20 60 -50 L 60 -85"
        fill="none" stroke="#ff6a2c" strokeWidth="2.2" strokeLinecap="round"
        className="draw-line" style={{ ['--len']: 280 }} />
        {/* Speed-coloured segments (faster blue, slower orange) — small dots */}
        {[
        { x: -90, y: 14, c: '#5aa1d6' },
        { x: -50, y: -3, c: '#5aa1d6' },
        { x: -15, y: -9, c: '#ff8a4d' },
        { x: 25, y: -25, c: '#ff6a2c' },
        { x: 55, y: -65, c: '#ff6a2c' }].
        map((d, i) =>
        <circle key={i} cx={d.x} cy={d.y} r="2.4" fill={d.c} className="anim-pop"
        style={{ animationDelay: `${800 + i * 80}ms`, transformOrigin: `${d.x}px ${d.y}px` }} />
        )}
      </g>

      {/* Compass — top-right */}
      <g transform="translate(330,80)">
        <circle r="44" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="1.4" opacity="0.95" />
        <circle r="38" fill="none" stroke="#1c2127" strokeWidth="1" />
        {/* Tick marks */}
        {Array.from({ length: 24 }).map((_, i) => {
          const a = i * 15 * Math.PI / 180;
          const r1 = 32,r2 = i % 6 === 0 ? 26 : 30;
          return <line key={i}
          x1={Math.sin(a) * r1} y1={-Math.cos(a) * r1}
          x2={Math.sin(a) * r2} y2={-Math.cos(a) * r2}
          stroke={i % 6 === 0 ? '#ff8a4d' : '#5a6470'} strokeWidth={i % 6 === 0 ? 1.5 : 0.8} />;
        })}
        <text x="0" y="-18" textAnchor="middle" fill="#ff8a4d" fontFamily="Manrope" fontSize="9" fontWeight="800" letterSpacing="0.12em">N</text>
        <text x="18" y="3" textAnchor="middle" fill="#5a6470" fontFamily="Manrope" fontSize="8" fontWeight="700">E</text>
        <text x="0" y="22" textAnchor="middle" fill="#5a6470" fontFamily="Manrope" fontSize="8" fontWeight="700">S</text>
        <text x="-18" y="3" textAnchor="middle" fill="#5a6470" fontFamily="Manrope" fontSize="8" fontWeight="700">W</text>
        {/* Needle */}
        <g style={{ transformOrigin: 'center', animation: 'compassSpin 8s ease-in-out infinite' }}>
          <path d="M 0 -22 L 4 0 L 0 4 L -4 0 Z" fill="#ff6a2c" />
          <path d="M 0 22 L 4 0 L 0 -4 L -4 0 Z" fill="#3a4150" />
        </g>
        <circle r="2.5" fill="#1a0d04" stroke="#ff8a4d" strokeWidth="1" />
      </g>

      {/* Layer toggle chip — bottom-left */}
      <g transform="translate(62,272)" className="anim-up" style={{ animationDelay: '600ms' }}>
        <rect x="0" y="0" width="170" height="36" rx="10" fill="#131820" stroke="#1c2127" />
        {['2D', '3D', 'SAT'].map((s, i) =>
        <g key={s} transform={`translate(${10 + i * 53},6)`}>
            <rect width="48" height="24" rx="7" fill={i === 1 ? 'var(--tt-ember-dim)' : 'transparent'} stroke={i === 1 ? 'rgba(255,106,44,0.4)' : 'transparent'} strokeWidth="1" />
            <text x="24" y="16" textAnchor="middle" fill={i === 1 ? '#ff8a4d' : '#98a1ac'} fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.12em">{s}</text>
          </g>
        )}
      </g>

      <style>{`@keyframes compassSpin {
        0%,100% { transform: rotate(-12deg); }
        50%     { transform: rotate(18deg); }
      }`}</style>
    </svg>);

}

/* === SCENE 4 · STAY AWARE — weather + hazard pin + shelter === */
function SceneAware() {
  return (
    <svg viewBox="0 0 412 340" preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <defs>
        <radialGradient id="sunG" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#ffb486" />
          <stop offset="100%" stopColor="#ff6a2c" />
        </radialGradient>
        <linearGradient id="cloudG" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#3a4150" />
          <stop offset="100%" stopColor="#1c2127" />
        </linearGradient>
      </defs>

      {/* Weather card — centered */}
      <g transform="translate(50,40)">
        <rect x="0" y="0" width="312" height="120" rx="14" fill="#131820" stroke="#1c2127" />

        {/* Sun */}
        <g transform="translate(60,60)">
          <circle r="22" fill="url(#sunG)" />
          {Array.from({ length: 8 }).map((_, i) => {
            const a = i * Math.PI / 4;
            return <line key={i}
            x1={Math.cos(a) * 28} y1={Math.sin(a) * 28}
            x2={Math.cos(a) * 38} y2={Math.sin(a) * 38}
            stroke="#ff8a4d" strokeWidth="2" strokeLinecap="round" opacity="0.7">
                <animate attributeName="opacity" values="0.4;1;0.4" dur="2.4s" begin={`${i * 0.1}s`} repeatCount="indefinite" />
              </line>;
          })}
        </g>

        {/* Cloud — animated drift */}
        <g style={{ animation: 'cloudDrift 6s ease-in-out infinite' }}>
          <ellipse cx="135" cy="58" rx="22" ry="14" fill="url(#cloudG)" />
          <ellipse cx="155" cy="62" rx="18" ry="12" fill="url(#cloudG)" />
          <ellipse cx="145" cy="50" rx="14" ry="10" fill="url(#cloudG)" />
        </g>

        {/* Wind lines */}
        <g stroke="#5a6470" strokeWidth="1.3" fill="none" strokeLinecap="round">
          {[0, 1, 2].map((i) =>
          <path key={i} d={`M 110 ${82 + i * 8} h ${24 - i * 4}`} opacity="0.7">
              <animate attributeName="stroke-dashoffset" values="20;0" dur="1.8s" begin={`${i * 0.2}s`} repeatCount="indefinite" />
              <animate attributeName="opacity" values="0.3;0.8;0.3" dur="1.8s" begin={`${i * 0.2}s`} repeatCount="indefinite" />
            </path>
          )}
        </g>

        {/* Right side stats */}
        <text x="200" y="36" fill="#5a6470" fontFamily="Manrope" fontSize="9" fontWeight="800" letterSpacing="0.16em">CONDITIONS</text>
        <text x="200" y="62" fill="#eef1f4" fontFamily="JetBrains Mono" fontSize="22" fontWeight="800">14°</text>
        <text x="200" y="80" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="10" fontWeight="700">WIND 18 KM/H</text>
        <text x="200" y="96" fill="#f2a93b" fontFamily="JetBrains Mono" fontSize="10" fontWeight="800" letterSpacing="0.06em">HIKE SCORE  8/10</text>
      </g>

      {/* Hazard pin row */}
      <g transform="translate(50,180)">
        <rect x="0" y="0" width="150" height="64" rx="12" fill="#131820" stroke="rgba(242,169,59,0.35)" />
        <rect x="0" y="0" width="3" height="64" fill="#f2a93b" />
        <g transform="translate(20,18)">
          <circle r="13" fill="rgba(242,169,59,0.15)" stroke="rgba(242,169,59,0.4)" strokeWidth="1">
            <animate attributeName="r" values="11;15;11" dur="2.4s" repeatCount="indefinite" />
          </circle>
          <path d="M 0 -6 L 6 6 L -6 6 Z" fill="none" stroke="#f2a93b" strokeWidth="1.5" strokeLinejoin="round" />
          <line x1="0" y1="-2" x2="0" y2="2" stroke="#f2a93b" strokeWidth="1.5" />
          <circle cx="0" cy="4" r="0.8" fill="#f2a93b" />
        </g>
        <text x="44" y="22" fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="800">Loose rock</text>
        <text x="44" y="38" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700">320m ahead</text>
        <text x="44" y="52" fill="#f2a93b" fontFamily="JetBrains Mono" fontSize="8" fontWeight="800" letterSpacing="0.12em">REPORTED 18m</text>
      </g>

      {/* Shelter pin */}
      <g transform="translate(212,180)">
        <rect x="0" y="0" width="150" height="64" rx="12" fill="#131820" stroke="rgba(76,195,138,0.32)" />
        <rect x="0" y="0" width="3" height="64" fill="#4cc38a" />
        <g transform="translate(20,18)">
          <circle r="13" fill="rgba(76,195,138,0.13)" stroke="rgba(76,195,138,0.35)" strokeWidth="1" />
          {/* shelter glyph */}
          <path d="M -7 5 L 0 -6 L 7 5 L 5 5 L 5 8 L -5 8 L -5 5 Z" fill="none" stroke="#4cc38a" strokeWidth="1.4" strokeLinejoin="round" />
        </g>
        <text x="44" y="22" fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="800">Shelter</text>
        <text x="44" y="38" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700">Cave · 1.2 km</text>
        <text x="44" y="52" fill="#4cc38a" fontFamily="JetBrains Mono" fontSize="8" fontWeight="800" letterSpacing="0.12em">DRAKENSBERG #47</text>
      </g>

      {/* Floating notifications */}
      <g transform="translate(50,272)" className="anim-up" style={{ animationDelay: '400ms' }}>
        <rect x="0" y="0" width="312" height="34" rx="10" fill="#131820" stroke="rgba(255,106,44,0.32)" />
        <circle cx="18" cy="17" r="5" fill="#ff6a2c">
          <animate attributeName="r" values="4;7;4" dur="1.6s" repeatCount="indefinite" />
          <animate attributeName="opacity" values="1;0.4;1" dur="1.6s" repeatCount="indefinite" />
        </circle>
        <text x="34" y="14" fill="#eef1f4" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.02em">Storm in 90 min</text>
        <text x="34" y="26" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="8.5" fontWeight="700">Consider shelter at km 5.8</text>
      </g>

      <style>{`@keyframes cloudDrift {
        0%,100% { transform: translateX(0); }
        50%     { transform: translateX(12px); }
      }`}</style>
    </svg>);

}

/* === SCENE 5 · SOS — rippling beacon === */
function SceneSOS() {
  return (
    <svg viewBox="0 0 412 340" preserveAspectRatio="xMidYMid meet"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
      <defs>
        <radialGradient id="sosOrb" cx="35%" cy="30%" r="70%">
          <stop offset="0%" stopColor="#ff6a4d" />
          <stop offset="60%" stopColor="#d6291f" />
          <stop offset="100%" stopColor="#82120c" />
        </radialGradient>
        <filter id="sosBlur"><feGaussianBlur stdDeviation="3" /></filter>
      </defs>

      {/* Concentric ripple rings */}
      {[0, 1, 2].map((i) =>
      <circle key={i} cx="206" cy="160" r="60"
      fill="rgba(230,61,46,0.06)"
      stroke="rgba(255,106,44,0.4)" strokeWidth="2">
          <animate attributeName="r" values="60;160;60" dur="3s" begin={`${i}s`} repeatCount="indefinite" />
          <animate attributeName="opacity" values="0.9;0;0.9" dur="3s" begin={`${i}s`} repeatCount="indefinite" />
        </circle>
      )}

      {/* Glow under orb */}
      <circle cx="206" cy="160" r="80" fill="#ff6a2c" opacity="0.45" filter="url(#sosBlur)" />

      {/* The orb */}
      <g className="anim-pop" style={{ transformOrigin: '206px 160px', animationDelay: '120ms' }}>
        <circle cx="206" cy="160" r="58" fill="url(#sosOrb)" stroke="#ff966c" strokeWidth="2.5" />
        <text x="206" y="165" textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="32" fontWeight="900" letterSpacing="0.1em">SOS</text>
        <text x="206" y="184" textAnchor="middle" fill="#ffd5c4" fontFamily="Manrope" fontSize="8.5" fontWeight="800" letterSpacing="0.24em">ACTIVE</text>
      </g>

      {/* Dispatch label — incoming responder */}
      <g transform="translate(206,278)" className="anim-up" style={{ animationDelay: '700ms' }}>
        <rect x="-92" y="-16" width="184" height="32" rx="9" fill="#131820" stroke="rgba(242,169,59,0.4)" />
        <g transform="translate(-72,0)">
          <circle r="9" fill="rgba(242,169,59,0.16)" stroke="rgba(242,169,59,0.45)" strokeWidth="1" />
          <path d="M 0 -4 L 5 -1 V 4 C 5 6 3 7 0 8 C -3 7 -5 6 -5 4 V -1 Z" fill="none" stroke="#f2a93b" strokeWidth="1.3" strokeLinejoin="round" />
        </g>
        <text x="-58" y="-2" fill="#eef1f4" fontFamily="Manrope" fontSize="10.5" fontWeight="800">Rescue Team #4 dispatched</text>
        <text x="-58" y="10" fill="#f2a93b" fontFamily="JetBrains Mono" fontSize="9" fontWeight="800" letterSpacing="0.12em">ETA 4 MIN · 620 m NW</text>
      </g>

      {/* Top — coordinates */}
      <g transform="translate(206,40)" className="anim-in" style={{ animationDelay: '300ms' }}>
        <text x="0" y="0" textAnchor="middle" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="9" fontWeight="800" letterSpacing="0.18em">TRANSMITTING · 00:14</text>
        <text x="0" y="16" textAnchor="middle" fill="#eef1f4" fontFamily="JetBrains Mono" fontSize="13" fontWeight="800">N 47.6062° · W 122.3321°</text>
      </g>
    </svg>);

}

window.ScreenWelcome = ScreenWelcome;
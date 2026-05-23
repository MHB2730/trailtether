// Trailtether — Tools tab (compass focus by default)

function ScreenTools() {
  const [tool, setTool] = React.useState('compass');
  return (
    <div className="phone">
      <div className="punchhole" />
      <div className="screen">
        <StatusBar
          time="10:09"
          right={<span style={{ color: 'var(--tt-text-2)', fontSize: 10.5, fontWeight: 700, letterSpacing: '0.08em', marginRight: 4 }}>LTE</span>} />
        

        <div className="tt-appbar anim-in" style={{ paddingBottom: 8 }}>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 4 }}>
              <TTLogo size={18} />
              <span style={{ font: '800 12px var(--tt-font)', letterSpacing: '0.16em' }}>
                TRAIL<span style={{ color: 'var(--tt-ember)' }}>TETHER</span>
              </span>
            </div>
            <h1 style={{ margin: 0, font: '800 24px var(--tt-font)', letterSpacing: '-0.02em' }}>Hiking Tools</h1>
          </div>
          <button className="icon-btn"><Icon name="settings" size={16} color="var(--tt-text-2)" /></button>
        </div>

        {/* Tool picker — horizontal scroll */}
        <ToolPicker active={tool} onChange={setTool} />

        <div className="tt-scroll" style={{ padding: '14px 18px 24px' }}>
          {tool === 'compass' && <CompassTool />}
          {tool === 'level' && <LevelTool />}
          {tool === 'torch' && <TorchTool />}
          {tool === 'altitude' && <AltimeterTool />}
          {tool === 'sun' && <SunTool />}
          {tool === 'info' && <InfoTool />}
        </div>

        <BottomNav active="tools" />
      </div>
    </div>);

}

function ToolPicker({ active, onChange }) {
  const tools = [
  { id: 'compass', label: 'Compass', icon: 'compass' },
  { id: 'level', label: 'Level', icon: 'crosshair' },
  { id: 'torch', label: 'Torch', icon: 'flame' },
  { id: 'altitude', label: 'Altimeter', icon: 'mountain' },
  { id: 'sun', label: 'Sun', icon: 'eye' },
  { id: 'info', label: 'Info', icon: 'alert' }];

  return (
    <div className="anim-in" style={{
      display: 'flex', gap: 8, padding: '4px 18px',
      overflowX: 'auto', flex: '0 0 auto',
      scrollbarWidth: 'none'
    }}>
      {tools.map((t) => {
        const a = t.id === active;
        return (
          <button key={t.id}
          className="pressable"
          onClick={() => onChange(t.id)}
          style={{
            display: 'inline-flex', alignItems: 'center', gap: 7,
            padding: '8px 13px', borderRadius: 10,
            background: a ? 'var(--tt-ember-dim)' : 'var(--tt-surf)',
            border: `1px solid ${a ? 'rgba(255,106,44,0.36)' : 'var(--tt-line)'}`,
            color: a ? 'var(--tt-ember)' : 'var(--tt-text-2)',
            font: '800 11px var(--tt-font)', letterSpacing: '0.1em',
            cursor: 'pointer', flex: '0 0 auto',
            whiteSpace: 'nowrap'
          }}>
            <Icon name={t.icon} size={14} color="currentColor" />
            {t.label.toUpperCase()}
          </button>);

      })}
    </div>);

}

/* ---------- COMPASS ---------- */
function CompassTool() {
  // Animated needle that wiggles
  return (
    <div>
      <div className="card anim-up" style={{ padding: '24px 18px', textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        {/* ambient ember glow behind */}
        <div style={{
          position: 'absolute', inset: '-30%',
          background: 'radial-gradient(circle at 50% 50%, rgba(255,106,44,0.12), transparent 60%)',
          pointerEvents: 'none'
        }} />
        <div style={{ position: 'relative' }}>
          <CompassDial />
          <div style={{ marginTop: 18 }}>
            <div className="num count-up" style={{ font: '800 38px var(--tt-mono)', color: 'var(--tt-text)', letterSpacing: '-0.025em' }}>142°</div>
            <div style={{ font: '800 12px var(--tt-font)', color: 'var(--tt-ember)', letterSpacing: '0.2em', marginTop: 4 }}>SOUTHEAST · SE</div>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <Stagger base={250} delay={80}>
          <MetricTile icon="navigation" label="Heading" value="142°" unit="SE" ember />
          <MetricTile icon="layers" label="Magnetic" value="−3.2°" unit="DEC" />
          <MetricTile icon="mountain" label="Altitude" value="1,842" unit="m" />
          <MetricTile icon="crosshair" label="GPS Acc" value="± 3" unit="m" />
        </Stagger>
      </div>

      <div className="anim-up" style={{
        marginTop: 14, padding: '12px 14px',
        background: 'rgba(90,161,214,0.08)',
        border: '1px solid rgba(90,161,214,0.25)',
        borderRadius: 11,
        display: 'flex', alignItems: 'center', gap: 10,
        animationDelay: '550ms'
      }}>
        <Icon name="alert" size={14} color="var(--tt-blue)" />
        <span style={{ font: '600 11px var(--tt-font)', color: 'var(--tt-text-2)', lineHeight: 1.4 }}>
          Hold flat. Calibrate by drawing a figure-8 if values feel off.
        </span>
      </div>
    </div>);

}

function CompassDial() {
  const heading = 142;
  return (
    <svg width={240} height={240} viewBox="0 0 240 240" style={{ display: 'block', margin: '0 auto', overflow: 'visible' }}>
      <defs>
        {/* Outer metal bezel — brushed graphite */}
        <radialGradient id="bezelOuter" cx="50%" cy="35%" r="65%">
          <stop offset="0%" stopColor="#454c58" />
          <stop offset="55%" stopColor="#1c2127" />
          <stop offset="100%" stopColor="#06080b" />
        </radialGradient>
        {/* Bezel top highlight */}
        <linearGradient id="bezelHi" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="rgba(255,255,255,0.22)" />
          <stop offset="40%" stopColor="rgba(255,255,255,0.02)" />
          <stop offset="100%" stopColor="rgba(0,0,0,0.4)" />
        </linearGradient>
        {/* Inner dial face — deep black, slight radial */}
        <radialGradient id="faceG" cx="50%" cy="45%" r="60%">
          <stop offset="0%" stopColor="#11161c" />
          <stop offset="55%" stopColor="#07090c" />
          <stop offset="100%" stopColor="#03060a" />
        </radialGradient>
        {/* Glass reflection over face */}
        <linearGradient id="glassRefl" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="rgba(255,255,255,0.14)" />
          <stop offset="50%" stopColor="rgba(255,255,255,0.02)" />
          <stop offset="100%" stopColor="rgba(255,255,255,0)" />
        </linearGradient>
        {/* North needle gradient */}
        <linearGradient id="needleN" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ffe0c7" />
          <stop offset="25%" stopColor="#ff8a4d" />
          <stop offset="100%" stopColor="#a83812" />
        </linearGradient>
        <linearGradient id="needleNShade" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="rgba(0,0,0,0.5)" />
          <stop offset="50%" stopColor="rgba(0,0,0,0)" />
          <stop offset="100%" stopColor="rgba(0,0,0,0.5)" />
        </linearGradient>
        {/* South needle gradient */}
        <linearGradient id="needleS" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#5a6470" />
          <stop offset="100%" stopColor="#1c2127" />
        </linearGradient>
        {/* Radar sweep cone */}
        <linearGradient id="sweep" x1="0.5" y1="1" x2="0.5" y2="0">
          <stop offset="0%" stopColor="rgba(255,106,44,0)" />
          <stop offset="70%" stopColor="rgba(255,106,44,0.18)" />
          <stop offset="100%" stopColor="rgba(255,138,77,0.5)" />
        </linearGradient>
        <filter id="dialBlur"><feGaussianBlur stdDeviation="1.8" /></filter>
        <filter id="needleGlow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>

      {/* Ambient ember glow behind the dial */}
      <circle cx="120" cy="120" r="125" fill="rgba(255,106,44,0.07)" filter="url(#dialBlur)" />

      {/* OUTER BEZEL — brushed metal ring */}
      <circle cx="120" cy="120" r="118" fill="url(#bezelOuter)" />
      <circle cx="120" cy="120" r="118" fill="none" stroke="rgba(0,0,0,0.7)" strokeWidth="1" />
      <circle cx="120" cy="120" r="116" fill="none" stroke="url(#bezelHi)" strokeWidth="1.2" />
      {/* Subtle machined groove */}
      <circle cx="120" cy="120" r="111" fill="none" stroke="#3a4150" strokeWidth="0.7" />
      <circle cx="120" cy="120" r="109" fill="none" stroke="rgba(0,0,0,0.7)" strokeWidth="0.8" />

      {/* Bezel bolts at NE/SE/SW/NW */}
      {[45, 135, 225, 315].map((a, i) => {
        const rad = (a - 90) * Math.PI / 180;
        const cx = 120 + Math.cos(rad) * 113;
        const cy = 120 + Math.sin(rad) * 113;
        return (
          <g key={i}>
            <circle cx={cx} cy={cy} r="3.2" fill="#0a0c0f" />
            <circle cx={cx} cy={cy} r="3.2" fill="none" stroke="#5a6470" strokeWidth="0.5" />
            <line x1={cx - 1.8} y1={cy} x2={cx + 1.8} y2={cy} stroke="#3a4150" strokeWidth="0.6" />
          </g>);

      })}

      {/* OUTER MIL-TICK RING (tactical detail) */}
      <g>
        {Array.from({ length: 64 }).map((_, i) => {
          const a = (i * 5.625 - 90) * Math.PI / 180;
          const r1 = 107;
          const r2 = i % 8 === 0 ? 102 : 104.5;
          return <line key={i}
          x1={120 + Math.cos(a) * r1} y1={120 + Math.sin(a) * r1}
          x2={120 + Math.cos(a) * r2} y2={120 + Math.sin(a) * r2}
          stroke={i % 8 === 0 ? '#98a1ac' : '#3d454d'} strokeWidth="0.6" />;
        })}
      </g>

      {/* TOP LUBBER LINE */}
      <g>
        <path d="M 120 -2 L 113 12 L 127 12 Z" fill="#ff6a2c" filter="url(#needleGlow)" />
        <path d="M 120 2 L 116 11 L 124 11 Z" fill="#ff8a4d" />
      </g>

      {/* INNER DIAL FACE */}
      <circle cx="120" cy="120" r="96" fill="url(#faceG)" />
      <circle cx="120" cy="120" r="96" fill="none" stroke="rgba(0,0,0,0.7)" strokeWidth="1.5" />
      <circle cx="120" cy="120" r="94" fill="none" stroke="rgba(255,255,255,0.04)" strokeWidth="0.6" />

      {/* Subtle reticle inside the face */}
      <g stroke="rgba(255,106,44,0.12)" strokeWidth="0.6" fill="none">
        <line x1="50" y1="120" x2="92" y2="120" />
        <line x1="148" y1="120" x2="190" y2="120" />
        <line x1="120" y1="50" x2="120" y2="92" />
        <line x1="120" y1="148" x2="120" y2="190" />
      </g>
      {/* tiny degree micro-arc markers in face */}
      <g stroke="rgba(255,255,255,0.06)" strokeWidth="0.5" fill="none">
        <circle cx="120" cy="120" r="56" strokeDasharray="2 4" />
        <circle cx="120" cy="120" r="40" strokeDasharray="1 5" />
      </g>

      {/* COMPASS ROSE — fixed (cardinal letters stay put) */}
      {/* Degree tick marks every 5° */}
      {Array.from({ length: 72 }).map((_, i) => {
        const a = (i * 5 - 90) * Math.PI / 180;
        const major = i % 6 === 0; // every 30°
        const mid = !major && i % 2 === 0; // every 10°
        const r1 = 90;
        const r2 = major ? 76 : mid ? 82 : 86;
        return <line key={i}
        x1={120 + Math.cos(a) * r1} y1={120 + Math.sin(a) * r1}
        x2={120 + Math.cos(a) * r2} y2={120 + Math.sin(a) * r2}
        stroke={major ? '#ff8a4d' : mid ? '#98a1ac' : '#3d454d'}
        strokeWidth={major ? 1.8 : mid ? 1 : 0.7} strokeLinecap="round" />;
      })}

      {/* Cardinal letters — bold tactical */}
      {[
      { deg: 0, l: 'N', main: true },
      { deg: 90, l: 'E' },
      { deg: 180, l: 'S' },
      { deg: 270, l: 'W' }].
      map(({ deg, l, main }, i) => {
        const a = (deg - 90) * Math.PI / 180;
        const r = 64;
        const x = 120 + Math.cos(a) * r;
        const y = 120 + Math.sin(a) * r + 4.5;
        return (
          <g key={i}>
            <text x={x} y={y} textAnchor="middle"
            fill={main ? '#ff6a2c' : '#cfd5dd'}
            fontFamily="Manrope" fontSize="14" fontWeight="900"
            letterSpacing="0.04em">{l}</text>
            {main &&
            <circle cx={x} cy={y - 12} r="2.4" fill="#ff6a2c" filter="url(#needleGlow)" />
            }
          </g>);

      })}

      {/* Intercardinal micro labels */}
      {[
      { deg: 45, l: 'NE' },
      { deg: 135, l: 'SE' },
      { deg: 225, l: 'SW' },
      { deg: 315, l: 'NW' }].
      map(({ deg, l }, i) => {
        const a = (deg - 90) * Math.PI / 180;
        const r = 68;
        const x = 120 + Math.cos(a) * r;
        const y = 120 + Math.sin(a) * r + 3;
        return (
          <text key={i} x={x} y={y} textAnchor="middle"
          fill="#5a6470" fontFamily="Manrope" fontSize="8" fontWeight="700"
          letterSpacing="0.1em">{l}</text>);

      })}

      {/* HEADING WEDGE — orange sector showing the bearing direction */}
      <g style={{ transformOrigin: '120px 120px', transform: `rotate(${heading}deg)` }}>
        <path d="M 120 120 L 108 28 A 95 95 0 0 1 132 28 Z" fill="rgba(255,106,44,0.12)" />
        <path d="M 120 120 L 114 28 A 95 95 0 0 1 126 28 Z" fill="rgba(255,106,44,0.18)" />
      </g>

      {/* RADAR SWEEP — continuously rotating */}
      <g style={{ transformOrigin: '120px 120px', animation: 'compassRadar 4.2s linear infinite' }}>
        <path d="M 120 120 L 120 24 A 96 96 0 0 1 200 84 Z" fill="url(#sweep)" />
        <line x1="120" y1="120" x2="120" y2="24" stroke="#ff8a4d" strokeWidth="0.8" opacity="0.55" />
      </g>

      {/* Glass reflection band — sits above radar */}
      <ellipse cx="120" cy="80" rx="78" ry="32" fill="url(#glassRefl)" opacity="0.8" />

      {/* THE NEEDLE — 3D, rotates to heading with subtle wiggle */}
      <g style={{ transformOrigin: '120px 120px', animation: 'compassNeedle 6s ease-in-out infinite' }}>
        <g style={{ transform: `rotate(${heading}deg)`, transformOrigin: '120px 120px' }}>
          {/* Drop shadow */}
          <path d="M 120 28 L 132 122 L 120 132 L 108 122 Z" fill="rgba(0,0,0,0.7)" filter="url(#dialBlur)" />
          {/* North half — filled gradient + shading overlay */}
          <path d="M 120 28 L 130 120 L 120 124 Z" fill="url(#needleN)" />
          <path d="M 120 28 L 110 120 L 120 124 Z" fill="#a83812" />
          <path d="M 120 28 L 130 120 L 110 120 Z" fill="url(#needleNShade)" opacity="0.5" />
          {/* Highlight on left edge */}
          <path d="M 120 30 L 121 122" stroke="rgba(255,255,255,0.55)" strokeWidth="0.7" fill="none" />

          {/* South half — dim grey */}
          <path d="M 120 212 L 130 120 L 120 124 Z" fill="url(#needleS)" />
          <path d="M 120 212 L 110 120 L 120 124 Z" fill="#1c2127" />
          <path d="M 120 122 L 130 120 L 110 120 Z" fill="rgba(0,0,0,0.3)" />

          {/* Tip glow */}
          <circle cx="120" cy="28" r="2.4" fill="#ffd5c4" filter="url(#needleGlow)" />
        </g>
      </g>

      {/* CENTER HUB — 3D gem */}
      <circle cx="120" cy="120" r="12" fill="#0a0c0f" />
      <circle cx="120" cy="120" r="12" fill="none" stroke="#3a4150" strokeWidth="1" />
      <circle cx="120" cy="120" r="9" fill="url(#bezelOuter)" />
      <circle cx="120" cy="120" r="6" fill="#1a0d04" stroke="#ff8a4d" strokeWidth="1.2" />
      <circle cx="120" cy="120" r="2.4" fill="#ff6a2c" />
      <ellipse cx="118" cy="117" rx="3.2" ry="1.4" fill="rgba(255,255,255,0.35)" />

      {/* HUD heading badge near top of bezel */}
      <g transform="translate(120, 18)">
        <rect x="-22" y="-9" width="44" height="16" rx="3.5" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="0.9" />
        <text x="0" y="2.5" textAnchor="middle" fill="#ff8a4d"
        fontFamily="JetBrains Mono" fontSize="10" fontWeight="900" letterSpacing="0.08em">{heading}°</text>
      </g>

      {/* HUD CORNER BRACKETS (tactical reticle frame) */}
      {[
      { x: 8, y: 8, dx: 1, dy: 1 },
      { x: 232, y: 8, dx: -1, dy: 1 },
      { x: 8, y: 232, dx: 1, dy: -1 },
      { x: 232, y: 232, dx: -1, dy: -1 }].
      map((b, i) =>
      <g key={i} stroke="#ff8a4d" strokeWidth="1.3" fill="none" opacity="0.9" strokeLinecap="round">
          <line x1={b.x} y1={b.y} x2={b.x + 12 * b.dx} y2={b.y} />
          <line x1={b.x} y1={b.y} x2={b.x} y2={b.y + 12 * b.dy} />
        </g>
      )}

      <style>{`
        @keyframes compassRadar {
          from { transform: rotate(0deg); }
          to   { transform: rotate(360deg); }
        }
        @keyframes compassNeedle {
          0%, 100% { transform: rotate(-1.5deg); }
          50%      { transform: rotate(1.5deg); }
        }
      `}</style>
    </svg>);

}

function MetricTile({ icon, label, value, unit, ember }) {
  return (
    <div className="card" style={{ padding: '12px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <Icon name={icon} size={12} color={ember ? 'var(--tt-ember)' : 'var(--tt-text-3)'} />
        <span style={{ font: '700 9.5px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-3)' }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 8 }}>
        <span className="num" style={{ font: '800 20px var(--tt-mono)', color: ember ? 'var(--tt-ember)' : 'var(--tt-text)', letterSpacing: '-0.02em' }}>{value}</span>
        {unit && <span className="num" style={{ fontSize: 10, color: 'var(--tt-text-2)', fontWeight: 600 }}>{unit}</span>}
      </div>
    </div>);

}

/* ---------- LEVEL ---------- */
function LevelTool() {
  return (
    <div className="card anim-up" style={{ padding: '30px 18px', position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: '-30%',
        background: 'radial-gradient(circle, rgba(76,195,138,0.08), transparent 65%)'
      }} />
      <div style={{ position: 'relative', textAlign: 'center' }}>
        <svg width="240" height="240" viewBox="0 0 240 240" style={{ display: 'block', margin: '0 auto' }}>
          <circle cx="120" cy="120" r="110" fill="#06080b" stroke="var(--tt-line-2)" />
          {/* concentric rings */}
          {[90, 70, 50, 30].map((r, i) =>
          <circle key={r} cx="120" cy="120" r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="1" />
          )}
          {/* crosshair */}
          <line x1="20" y1="120" x2="220" y2="120" stroke="rgba(255,255,255,0.1)" />
          <line x1="120" y1="20" x2="120" y2="220" stroke="rgba(255,255,255,0.1)" />
          {/* center */}
          <circle cx="120" cy="120" r="22" fill="none" stroke="var(--tt-ember)" strokeWidth="1.5" strokeDasharray="3 3" />
          {/* bubble */}
          <circle cx="138" cy="108" r="18" fill="rgba(76,195,138,0.25)" stroke="#4cc38a" strokeWidth="2">
            <animate attributeName="cx" values="138;134;140;136;138" dur="3.4s" repeatCount="indefinite" />
            <animate attributeName="cy" values="108;112;106;110;108" dur="3.4s" repeatCount="indefinite" />
          </circle>
        </svg>
        <div className="num count-up" style={{ font: '800 32px var(--tt-mono)', color: 'var(--tt-text)', marginTop: 14, letterSpacing: '-0.02em' }}>2.4° <span style={{ fontSize: 14, color: 'var(--tt-text-2)' }}>tilt</span></div>
        <div style={{ font: '800 11px var(--tt-font)', color: 'var(--tt-green)', letterSpacing: '0.16em', marginTop: 4 }}>NEARLY LEVEL</div>
      </div>
    </div>);

}

/* ---------- TORCH ---------- */
function TorchTool() {
  const [on, setOn] = React.useState(true);
  return (
    <div>
      <div className="card anim-up" style={{ padding: '24px 18px', textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        {/* Beam */}
        {on &&
        <div style={{
          position: 'absolute', top: '50%', left: '50%',
          width: 280, height: 280, transform: 'translate(-50%,-50%)',
          background: 'radial-gradient(circle, rgba(255,239,170,0.45), rgba(255,138,77,0.15) 40%, transparent 75%)',
          filter: 'blur(8px)',
          pointerEvents: 'none',
          animation: 'torchFlicker 2.4s ease-in-out infinite'
        }} />
        }

        <div style={{ position: 'relative' }}>
          <button onClick={() => setOn((o) => !o)} className="pressable" style={{
            width: 140, height: 140, borderRadius: '50%',
            background: on ?
            'radial-gradient(circle at 35% 30%, #ffefaa 0%, #ff8a4d 60%, #d6291f 100%)' :
            'radial-gradient(circle at 35% 30%, #2a313c, #0a0c0f)',
            border: `3px solid ${on ? '#ffd5a0' : '#2a313c'}`,
            cursor: 'pointer',
            boxShadow: on ? '0 0 50px rgba(255,138,77,0.7)' : 'none',
            display: 'grid', placeItems: 'center',
            margin: '0 auto',
            transition: 'box-shadow 350ms ease, background 350ms ease'
          }}>
            <Icon name="flame" size={56} color={on ? '#1a0d04' : '#5a6470'} />
          </button>
          <div style={{ font: '800 13px var(--tt-font)', color: on ? 'var(--tt-ember)' : 'var(--tt-text-3)', letterSpacing: '0.2em', marginTop: 18 }}>
            TORCH · {on ? 'ON' : 'OFF'}
          </div>
          <div style={{ font: '600 11px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 6, letterSpacing: '0.04em' }}>Tap to toggle</div>
        </div>
      </div>

      <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <Stagger base={200} delay={70}>
          <MetricTile icon="flame" label="Mode" value="Steady" />
          <MetricTile icon="alert" label="Strobe" value="OFF" />
        </Stagger>
      </div>

      <style>{`@keyframes torchFlicker {
        0%,100% { opacity: 0.9; }
        50%     { opacity: 1; }
      }`}</style>
    </div>);

}

/* ---------- ALTIMETER ---------- */
function AltimeterTool() {
  return (
    <div>
      <div className="card anim-up" style={{ padding: '24px 18px', position: 'relative', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute', inset: '-20%',
          background: 'radial-gradient(circle at 50% 100%, rgba(255,106,44,0.12), transparent 65%)'
        }} />
        <div style={{ textAlign: 'center', position: 'relative' }}>
          <div style={{ font: '800 11px var(--tt-font)', color: 'var(--tt-text-3)', letterSpacing: '0.18em' }}>CURRENT ELEVATION</div>
          <div className="num count-up" style={{ font: '900 56px/1 var(--tt-mono)', color: 'var(--tt-ember)', marginTop: 10, letterSpacing: '-0.03em' }}>
            1,842<span style={{ fontSize: 20, color: 'var(--tt-text-2)', marginLeft: 6, fontWeight: 600 }}>m</span>
          </div>
          <div style={{ font: '600 11px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 8, letterSpacing: '0.04em' }}>
            6,043 m · BAROMETER 845 hPa
          </div>

          {/* Mini altitude trace */}
          <svg width="100%" height="80" viewBox="0 0 320 80" style={{ marginTop: 18 }} preserveAspectRatio="none">
            <defs>
              <linearGradient id="altFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.5" />
                <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
              </linearGradient>
            </defs>
            <path d="M 0 70 Q 50 60 90 50 Q 140 40 180 30 Q 220 25 260 20 Q 290 22 320 18 L 320 80 L 0 80 Z" fill="url(#altFill)" />
            <path d="M 0 70 Q 50 60 90 50 Q 140 40 180 30 Q 220 25 260 20 Q 290 22 320 18"
            fill="none" stroke="#ff6a2c" strokeWidth="2" strokeLinecap="round"
            className="draw-line" style={{ ['--len']: 400, animationDelay: '400ms' }} />
            <circle cx="320" cy="18" r="3" fill="#fff" stroke="#ff6a2c" strokeWidth="1.5"
            className="anim-pop" style={{ animationDelay: '1100ms', transformOrigin: '320px 18px' }} />
          </svg>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, font: '600 9px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.06em' }}>
            <span>06:00</span><span>08:00</span><span>10:00</span><span>NOW</span>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <Stagger base={250} delay={80}>
          <MetricTile icon="arrow-up" label="Ascent" value="+842" unit="m" ember />
          <MetricTile icon="chevron-down" label="Descent" value="−210" unit="m" />
          <MetricTile icon="mountain" label="Max" value="1,842" unit="m" />
          <MetricTile icon="layers" label="Min" value="1,210" unit="m" />
        </Stagger>
      </div>
    </div>);

}

/* ---------- SUN ---------- */
function SunTool() {
  return (
    <div>
      <div className="card anim-up" style={{ padding: '22px 18px', position: 'relative', overflow: 'hidden' }}>
        <div style={{
          position: 'absolute', inset: '-20%',
          background: 'radial-gradient(circle at 50% 100%, rgba(255,138,77,0.18), transparent 70%)'
        }} />
        <div style={{ position: 'relative', textAlign: 'center' }}>
          {/* Sun arc */}
          <svg width="100%" height="160" viewBox="0 0 320 160" preserveAspectRatio="none">
            <defs>
              <linearGradient id="sunArcG" x1="0" y1="0" x2="1" y2="0">
                <stop offset="0%" stopColor="#ff8a4d" stopOpacity="0" />
                <stop offset="50%" stopColor="#ff8a4d" stopOpacity="0.9" />
                <stop offset="100%" stopColor="#ff8a4d" stopOpacity="0" />
              </linearGradient>
            </defs>
            {/* Horizon */}
            <line x1="0" y1="130" x2="320" y2="130" stroke="rgba(255,255,255,0.1)" />
            {/* Arc */}
            <path d="M 20 130 Q 160 -20 300 130" fill="none" stroke="url(#sunArcG)" strokeWidth="2"
            className="draw-line" style={{ ['--len']: 500 }} />
            {/* Current sun (at ~ midway) */}
            <g transform="translate(170,38)" className="anim-pop" style={{ animationDelay: '700ms', transformOrigin: '170px 38px' }}>
              <circle r="14" fill="#ff8a4d" />
              {Array.from({ length: 8 }).map((_, i) => {
                const a = i * Math.PI / 4;
                return <line key={i}
                x1={Math.cos(a) * 18} y1={Math.sin(a) * 18}
                x2={Math.cos(a) * 24} y2={Math.sin(a) * 24}
                stroke="#ff8a4d" strokeWidth="1.6" strokeLinecap="round" opacity="0.7">
                  <animate attributeName="opacity" values="0.4;1;0.4" dur="2.4s" begin={`${i * 0.1}s`} repeatCount="indefinite" />
                </line>;
              })}
            </g>
            {/* Sunrise + sunset markers */}
            <circle cx="20" cy="130" r="3" fill="#ffb486" />
            <circle cx="300" cy="130" r="3" fill="#5aa1d6" />
          </svg>

          <div className="num count-up" style={{ font: '900 38px var(--tt-mono)', color: 'var(--tt-text)', marginTop: 6, letterSpacing: '-0.025em' }}>10:09 <span style={{ fontSize: 16, color: 'var(--tt-text-2)' }}>AM</span></div>
          <div style={{ font: '800 11px var(--tt-font)', color: 'var(--tt-ember)', letterSpacing: '0.18em', marginTop: 6 }}>SUN IS UP · 4h 22m TO PEAK</div>
        </div>
      </div>

      <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <Stagger base={300} delay={80}>
          <MetricTile icon="arrow-up" label="Sunrise" value="05:47" ember />
          <MetricTile icon="arrow-up" label="Sunset" value="18:23" />
          <MetricTile icon="clock" label="Daylight" value="12h 36m" />
          <MetricTile icon="layers" label="UV Index" value="6" unit="HIGH" />
        </Stagger>
      </div>
    </div>);

}

/* ---------- INFO ---------- */
function InfoTool() {
  const tips = [
  { ic: 'pin', t: 'Tell someone your route', s: 'Share trail name + expected return.' },
  { ic: 'flame', t: 'Pack layers, not weight', s: 'Mountain temps drop 6°C per 1,000m.' },
  { ic: 'wind', t: 'Watch the wind shift', s: 'A sudden change often precedes a front.' },
  { ic: 'heart', t: 'Hydrate before you\'re thirsty', s: 'Thirst lags 1–2 hours behind dehydration.' }];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <Stagger base={150} delay={80}>
        {tips.map((tip, i) =>
        <div key={i} className="card pressable" style={{ padding: '14px 16px', display: 'flex', gap: 14, alignItems: 'flex-start' }}>
            <div style={{
            width: 36, height: 36, borderRadius: 10,
            background: 'var(--tt-ember-dim)', border: '1px solid rgba(255,106,44,0.32)',
            display: 'grid', placeItems: 'center', flex: '0 0 auto'
          }}>
              <Icon name={tip.ic} size={16} color="var(--tt-ember)" />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ font: '800 13.5px var(--tt-font)', color: 'var(--tt-text)' }}>{tip.t}</div>
              <div style={{ font: '500 11.5px/1.45 var(--tt-font)', color: 'var(--tt-text-2)', marginTop: 4 }}>{tip.s}</div>
            </div>
          </div>
        )}
      </Stagger>
    </div>);

}

window.ScreenTools = ScreenTools;
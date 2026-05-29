// Trailtether PC — Welcome / Sign-In screen
// Left half: rotating animated infographic showing what Base Camp does.
// Right half: auth (sign-in via magic link OR pair this PC).

const PC_SCENES = [
  { id:'tether', eyebrow:'STAY TETHERED',     title:'Your phone, on your watch.',          sub:"While they're out, the tether keeps an eye open at home.",     render: SceneTether },
  { id:'watch',  eyebrow:'WATCH LIVE',        title:'Every step, every minute.',           sub:'Live position, pace, elevation, battery — at 1-Hz.',           render: SceneWatch  },
  { id:'alert',  eyebrow:'ALERT BEFORE LATE', title:"You'll know before they're late.",    sub:'Configurable rules across desktop, SMS, and phone calls.',     render: SceneAlert  },
  { id:'sos',    eyebrow:'ACT FAST',          title:'One tap to mountain rescue.',         sub:'SOS reaches the right service with the right coordinates.',    render: SceneSOS    },
];

function PCScreenWelcome() {
  const [mode, setMode] = React.useState('signin'); // 'signin' | 'pair'
  const [sceneIdx, setSceneIdx] = React.useState(0);

  // Auto-rotate scenes
  React.useEffect(() => {
    const id = setInterval(() => setSceneIdx(i => (i + 1) % PC_SCENES.length), 6200);
    return () => clearInterval(id);
  }, []);

  const scene = PC_SCENES[sceneIdx];
  const SceneRender = scene.render;

  return (
    <PCWindow>
      <PCTitleBar title="Trailtether · Base Camp"/>
      <div style={{ flex:1, display:'grid', gridTemplateColumns:'1.25fr 1fr',
        background:'#06080b', minHeight:0, overflow:'hidden' }}>

        {/* ============================================
            LEFT — animated infographic
            ============================================ */}
        <div style={{ position:'relative', overflow:'hidden',
          background:'radial-gradient(ellipse 80% 60% at 30% 30%, rgba(255,106,44,0.10), transparent 70%), linear-gradient(180deg, #0a0e14 0%, #06080b 100%)' }}>
          <PCTopoBack opacity={0.35}/>

          {/* Brand */}
          <div style={{
            position:'absolute', top:36, left:40, zIndex:3,
            display:'flex', alignItems:'center', gap:12,
          }}>
            <img src="assets/logo.png" alt="" width="40" height="40"
              style={{ filter:'drop-shadow(0 0 12px rgba(255,106,44,0.55))' }}/>
            <div>
              <div style={{ font:'900 22px var(--tt-font)', letterSpacing:'0.22em' }}>
                TRAIL<span style={{ color:'var(--tt-ember)' }}>TETHER</span>
              </div>
              <div style={{ font:'700 10px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.22em', marginTop:2 }}>
                BASE CAMP · v2.0
              </div>
            </div>
          </div>

          {/* Top-right reticle */}
          <div style={{ position:'absolute', top:32, right:24, zIndex:3,
            font:'700 9.5px var(--tt-mono)', color:'rgba(255,255,255,0.4)',
            letterSpacing:'0.2em', display:'flex', alignItems:'center', gap:8 }}>
            <span style={{ width:6, height:6, borderRadius:'50%', background:'var(--tt-green)',
              boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.6s infinite' }}/>
            RELAY · AFRICA-SOUTH-1 · ONLINE
          </div>

          {/* Scene stage */}
          <div style={{
            position:'absolute', top:108, left:40, right:40, height:360,
            display:'flex', alignItems:'center', justifyContent:'center',
            zIndex:2,
          }}>
            <div key={scene.id} style={{ width:'100%', height:'100%', animation:'fadeIn 600ms ease' }}>
              <SceneRender/>
            </div>
          </div>

          {/* Tagline + subtitle (changes per scene) */}
          <div key={`text-${scene.id}`} style={{
            position:'absolute', left:40, right:40, bottom:172, zIndex:3,
            animation:'fadeIn 600ms ease 80ms both',
          }}>
            <div style={{ font:'700 11px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.24em', marginBottom:9 }}>
              {scene.eyebrow}
            </div>
            <h1 style={{
              margin:0, font:'900 36px/1.05 var(--tt-font)',
              letterSpacing:'-0.022em', color:'#fff',
              maxWidth:560, textShadow:'0 2px 24px rgba(0,0,0,0.55)',
            }}>
              {scene.title}
            </h1>
            <div style={{ font:'500 13.5px/1.5 var(--tt-font)', color:'#cfd5dd',
              maxWidth:540, marginTop:8 }}>{scene.sub}</div>
          </div>

          {/* Scene navigation dots */}
          <div style={{ position:'absolute', left:40, bottom:120, zIndex:3,
            display:'flex', gap:8 }}>
            {PC_SCENES.map((s, i) => (
              <button key={s.id} onClick={() => setSceneIdx(i)} style={{
                padding:0, background:'transparent', border:'none', cursor:'pointer',
                display:'inline-flex', alignItems:'center', gap:6,
              }}>
                <span style={{
                  width: i === sceneIdx ? 24 : 6, height: 6, borderRadius: 3,
                  background: i === sceneIdx ? 'var(--tt-ember)' : 'var(--tt-line-3)',
                  boxShadow: i === sceneIdx ? '0 0 8px rgba(255,106,44,0.6)' : 'none',
                  transition: 'width 350ms cubic-bezier(0.2,0.7,0.2,1), background 250ms',
                }}/>
              </button>
            ))}
          </div>

          {/* Bottom pillars */}
          <div style={{ position:'absolute', left:40, right:40, bottom:36, zIndex:3,
            display:'flex', gap:10 }}>
            <WelcomePillar ic="eye"    title="Live tether"     sub="1-Hz position from every paired phone"/>
            <WelcomePillar ic="alert"  title="Alert before late" sub="Configurable rules · multi-channel"/>
            <WelcomePillar ic="shield" title="SOS routing"     sub="Direct to rescue services"/>
          </div>
        </div>

        {/* ============================================
            RIGHT — auth card (unchanged structure)
            ============================================ */}
        <div style={{
          background:'linear-gradient(180deg, #0b0e12 0%, #06080b 100%)',
          display:'flex', flexDirection:'column',
          padding:'40px 56px', minWidth:0,
        }}>
          <div style={{ marginBottom:24, marginTop:18 }}>
            <PCPill ember>{mode === 'signin' ? 'SIGN IN' : 'PAIR THIS BASE CAMP'}</PCPill>
            <h2 style={{ margin:'14px 0 6px', font:'900 28px var(--tt-font)',
              letterSpacing:'-0.02em', color:'var(--tt-text)' }}>
              {mode === 'signin' ? 'Welcome back, watcher.' : 'Make this PC a base camp.'}
            </h2>
            <div style={{ font:'500 13px/1.5 var(--tt-font)', color:'var(--tt-text-2)', maxWidth:440 }}>
              {mode === 'signin'
                ? 'Sign in to resume watching your tethered hikers. No password — we send a one-tap link.'
                : 'Tether this computer to an existing Trailtether account. Enter the 8-digit code from your phone.'}
            </div>
          </div>

          <div style={{ display:'flex', gap:4, padding:4, marginBottom:22,
            background:'rgba(255,255,255,0.03)', border:'1px solid var(--tt-line)', borderRadius:11 }}>
            <ToggleSeg active={mode==='signin'} onClick={() => setMode('signin')} icon="user"   label="SIGN IN"/>
            <ToggleSeg active={mode==='pair'}   onClick={() => setMode('pair')}   icon="tether" label="PAIR FROM PHONE"/>
          </div>

          {mode === 'signin' ? <SignInForm/> : <PairForm/>}

          {mode === 'signin' && (
            <>
              <div style={{ display:'flex', alignItems:'center', gap:12, margin:'22px 0' }}>
                <div style={{ flex:1, height:1, background:'var(--tt-line)' }}/>
                <span style={{ font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.2em' }}>OR</span>
                <div style={{ flex:1, height:1, background:'var(--tt-line)' }}/>
              </div>
              <div style={{ display:'grid', gridTemplateColumns:'1fr', gap:9 }}>
                <SocialButton label="Continue with Google" glyph="G"/>
              </div>
            </>
          )}

          <div style={{ flex:1 }}/>

          <div style={{ marginTop:24, font:'500 11.5px/1.5 var(--tt-font)', color:'var(--tt-text-3)',
            display:'flex', alignItems:'center', justifyContent:'space-between' }}>
            <span>
              {mode === 'signin'
                ? <>New to Trailtether? <a style={{ color:'var(--tt-ember)', textDecoration:'none', fontWeight:700 }}>Create an account →</a></>
                : <>Need help pairing? <a style={{ color:'var(--tt-ember)', textDecoration:'none', fontWeight:700 }}>Open the docs →</a></>}
            </span>
            <span style={{ font:'700 9px var(--tt-mono)', letterSpacing:'0.16em', color:'var(--tt-text-4)' }}>
              v2.0.4 · BUILD 9842
            </span>
          </div>
        </div>
      </div>
    </PCWindow>
  );
}

/* =================================================================
   ANIMATED SCENES — each fills the stage area at ~720×360
   ================================================================= */

/* ---- Scene 1: TETHER — phone broadcasting to base-camp PC ---- */
function SceneTether() {
  return (
    <svg viewBox="0 0 720 360" width="100%" height="100%" preserveAspectRatio="xMidYMid meet"
         style={{ display:'block' }}>
      <defs>
        <linearGradient id="tetherLine" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%"  stopColor="#ff6a2c" stopOpacity="0"/>
          <stop offset="20%" stopColor="#ff6a2c" stopOpacity="0.9"/>
          <stop offset="80%" stopColor="#4cc38a" stopOpacity="0.9"/>
          <stop offset="100%" stopColor="#4cc38a" stopOpacity="0"/>
        </linearGradient>
        <radialGradient id="emberHalo" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor="#ff8a4d" stopOpacity="0.7"/>
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0"/>
        </radialGradient>
        <radialGradient id="greenHalo" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor="#4cc38a" stopOpacity="0.55"/>
          <stop offset="100%" stopColor="#4cc38a" stopOpacity="0"/>
        </radialGradient>
      </defs>

      {/* Phone (left) */}
      <g transform="translate(120,80)">
        <ellipse cx="55" cy="200" rx="80" ry="14" fill="url(#emberHalo)" opacity="0.5"/>
        {/* Phone body */}
        <rect x="0" y="0" width="110" height="200" rx="18" fill="#0a0c0f" stroke="#ff6a2c" strokeWidth="2"/>
        <rect x="6" y="6" width="98" height="188" rx="13" fill="#11161e"/>
        {/* Status bar */}
        <rect x="14" y="14" width="20" height="3" rx="1.5" fill="#5a6470"/>
        <rect x="84" y="14" width="14" height="3" rx="1.5" fill="#ff6a2c"/>
        {/* Mini map content */}
        <g transform="translate(14,28)">
          <rect width="82" height="100" rx="6" fill="#0a1218"/>
          <g stroke="#1a2820" strokeWidth="0.4" fill="none">
            <path d="M-2,30 Q40,24 84,30"/>
            <path d="M-2,50 Q40,44 84,50"/>
            <path d="M-2,70 Q40,64 84,70"/>
          </g>
          {/* Trail */}
          <path d="M 8,90 Q 30,70 44,52 Q 56,36 74,18"
                fill="none" stroke="#ff8a4d" strokeWidth="1.6"
                strokeLinecap="round"/>
          {/* GPS pulse */}
          <circle cx="44" cy="52" r="3" fill="#ff6a2c">
            <animate attributeName="opacity" values="0.6;1;0.6" dur="1.6s" repeatCount="indefinite"/>
          </circle>
          <circle cx="44" cy="52" r="8" fill="none" stroke="#ff6a2c" strokeWidth="0.8" opacity="0.4">
            <animate attributeName="r" values="5;14;5" dur="2.4s" repeatCount="indefinite"/>
            <animate attributeName="opacity" values="0.7;0;0.7" dur="2.4s" repeatCount="indefinite"/>
          </circle>
        </g>
        {/* Stats below map */}
        <g transform="translate(14,134)">
          <rect width="82" height="14" rx="2.5" fill="#1a2029"/>
          <text x="6" y="9.5" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="6.5" fontWeight="800" letterSpacing="0.1em">KM 8.4 · 1850m</text>
        </g>
        <g transform="translate(14,152)">
          <rect width="82" height="14" rx="2.5" fill="#1a2029"/>
          <text x="6" y="9.5" fill="#4cc38a" fontFamily="JetBrains Mono" fontSize="6.5" fontWeight="800" letterSpacing="0.1em">TETHERED</text>
        </g>
        {/* Home indicator */}
        <rect x="40" y="180" width="30" height="3" rx="1.5" fill="#98a1ac"/>
      </g>

      {/* Label PHONE */}
      <text x="175" y="60" textAnchor="middle" fill="#ff8a4d"
        fontFamily="Manrope" fontSize="11" fontWeight="900" letterSpacing="0.24em">PHONE · KM 8.4</text>

      {/* Tether line — data packets */}
      <g>
        <line x1="240" y1="180" x2="480" y2="180" stroke="url(#tetherLine)" strokeWidth="1.5"/>
        {/* Travelling packets */}
        {[0, 0.7, 1.4, 2.1].map((d, i) => (
          <circle key={i} cx="0" cy="180" r="3.5" fill="#ff8a4d" filter="drop-shadow(0 0 4px #ff8a4d)">
            <animate attributeName="cx" from="245" to="475" dur="2.8s" begin={`${d}s`} repeatCount="indefinite"/>
            <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.1;0.85;1" dur="2.8s" begin={`${d}s`} repeatCount="indefinite"/>
          </circle>
        ))}
        {/* Range markers */}
        <text x="360" y="170" textAnchor="middle" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="8.5" fontWeight="700" letterSpacing="0.22em">LIVE · 1 Hz · TLS</text>
        <text x="360" y="200" textAnchor="middle" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="8.5" fontWeight="700" letterSpacing="0.22em">via relay · africa-south-1</text>
      </g>

      {/* PC (right) */}
      <g transform="translate(490,90)">
        <ellipse cx="80" cy="210" rx="100" ry="14" fill="url(#greenHalo)" opacity="0.5"/>
        {/* Monitor */}
        <rect x="0" y="0" width="160" height="110" rx="6" fill="#0a0c0f" stroke="#4cc38a" strokeWidth="2"/>
        <rect x="6" y="6" width="148" height="98" rx="3" fill="#11161e"/>
        {/* Mini PC dashboard content */}
        <g transform="translate(10,10)">
          {/* Header bar */}
          <rect width="140" height="9" rx="1.5" fill="#0b0e12"/>
          <circle cx="5"  cy="4.5" r="1.5" fill="#ff5f56"/>
          <circle cx="11" cy="4.5" r="1.5" fill="#ffbd2e"/>
          <circle cx="17" cy="4.5" r="1.5" fill="#27c93f"/>
          <text x="70" y="6.5" textAnchor="middle" fill="#5a6470" fontFamily="Manrope" fontSize="4.5" fontWeight="700" letterSpacing="0.18em">BASE CAMP</text>
          {/* Map area */}
          <rect x="0" y="14" width="90" height="76" rx="2.5" fill="#0a1218"/>
          <g stroke="#1a2820" strokeWidth="0.4" fill="none">
            <path d="M 0,40 Q 45,32 90,38"/>
            <path d="M 0,55 Q 45,48 90,52"/>
            <path d="M 0,70 Q 45,62 90,68"/>
          </g>
          {/* Trail + pin */}
          <path d="M 6,82 Q 30,60 50,46 Q 70,30 86,18" fill="none" stroke="#ff8a4d" strokeWidth="1.2"/>
          <circle cx="50" cy="46" r="2.5" fill="#fff" stroke="#ff6a2c" strokeWidth="1"/>
          <circle cx="50" cy="46" r="6" fill="none" stroke="#ff6a2c" strokeWidth="0.6" opacity="0.5">
            <animate attributeName="r" values="4;9;4" dur="2.4s" repeatCount="indefinite"/>
            <animate attributeName="opacity" values="0.7;0;0.7" dur="2.4s" repeatCount="indefinite"/>
          </circle>
          {/* Side rail */}
          <g transform="translate(95,14)">
            <rect width="45" height="22" rx="2" fill="#1a2029"/>
            <text x="3" y="7" fill="#5a6470" fontFamily="Manrope" fontSize="3.5" fontWeight="800" letterSpacing="0.16em">JOHN D.</text>
            <text x="3" y="13" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="4" fontWeight="800">8.4 km</text>
            <text x="3" y="19" fill="#4cc38a" fontFamily="Manrope" fontSize="3" fontWeight="700" letterSpacing="0.12em">● LIVE</text>

            <rect y="26" width="45" height="22" rx="2" fill="#1a2029"/>
            <text x="3" y="33" fill="#5a6470" fontFamily="Manrope" fontSize="3.5" fontWeight="800" letterSpacing="0.16em">MIKE K.</text>
            <text x="3" y="39" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="4" fontWeight="800">8.1 km</text>
            <text x="3" y="45" fill="#4cc38a" fontFamily="Manrope" fontSize="3" fontWeight="700" letterSpacing="0.12em">● LIVE</text>

            <rect y="52" width="45" height="22" rx="2" fill="#1a2029"/>
            <text x="3" y="59" fill="#5a6470" fontFamily="Manrope" fontSize="3.5" fontWeight="800" letterSpacing="0.16em">EMILY R.</text>
            <text x="3" y="65" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="4" fontWeight="800">8.5 km</text>
            <text x="3" y="71" fill="#f2a93b" fontFamily="Manrope" fontSize="3" fontWeight="700" letterSpacing="0.12em">⚠ FLAGGED</text>
          </g>
        </g>
        {/* Monitor stand */}
        <rect x="62"  y="110" width="36" height="6" fill="#1a1d22"/>
        <rect x="48"  y="116" width="64" height="4" rx="2" fill="#1a1d22"/>
      </g>

      {/* Label PC */}
      <text x="570" y="74" textAnchor="middle" fill="#4cc38a"
        fontFamily="Manrope" fontSize="11" fontWeight="900" letterSpacing="0.24em">BASE CAMP · HOME</text>
    </svg>
  );
}

/* ---- Scene 2: WATCH LIVE — aerial map with walking hiker ---- */
function SceneWatch() {
  return (
    <svg viewBox="0 0 720 360" width="100%" height="100%" preserveAspectRatio="xMidYMid meet"
         style={{ display:'block' }}>
      <defs>
        <radialGradient id="watchTerr" cx="50%" cy="50%" r="65%">
          <stop offset="0%" stopColor="#1a2820" stopOpacity="0.9"/>
          <stop offset="100%" stopColor="#06090c" stopOpacity="0.4"/>
        </radialGradient>
        <filter id="watchTrailGlow"><feGaussianBlur stdDeviation="3"/></filter>
      </defs>

      {/* Map background card */}
      <g transform="translate(40,30)">
        <rect width="500" height="300" rx="14" fill="url(#watchTerr)" stroke="rgba(255,255,255,0.05)" strokeWidth="1"/>
        {/* Contours */}
        <g stroke="#1a2820" strokeWidth="0.5" fill="none" opacity="0.7">
          {[
            'M-10,260 Q120,250 240,245 T520,260',
            'M-10,220 Q120,200 240,205 T520,215',
            'M-10,180 Q120,150 250,160 T520,180',
            'M0,140 Q130,110 250,120 T520,140',
            'M20,100 Q140,70 250,82 T510,108',
            'M50,70 Q160,42 250,55 T490,78',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>
        {/* Lake */}
        <ellipse cx="100" cy="260" rx="35" ry="11" fill="#152a3c" opacity="0.7"/>
        {/* Trail (full) */}
        <path id="watchTrailPath" d="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"
              fill="none" stroke="#ff6a2c" strokeOpacity="0.35"
              strokeWidth="6" strokeLinecap="round" filter="url(#watchTrailGlow)"/>
        <path d="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"
              fill="none" stroke="#ff8a4d" strokeWidth="2" strokeLinecap="round"/>
        {/* Travelled (dashed bright) */}
        <path d="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"
              fill="none" stroke="#fff" strokeWidth="1" strokeDasharray="2 6"
              strokeOpacity="0.5"/>

        {/* Start + summit markers */}
        <g transform="translate(50,270)">
          <rect x="-5" y="-5" width="10" height="10" transform="rotate(45)" fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1"/>
        </g>
        <g transform="translate(430,60)">
          <circle r="7" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="1.6"/>
          <path d="M 0 -3 L 3 2 L -3 2 Z" fill="#ff6a2c"/>
        </g>

        {/* Animated hiker moving along trail */}
        <g>
          <circle r="26" fill="rgba(255,106,44,0.10)">
            <animate attributeName="r" values="22;32;22" dur="3s" repeatCount="indefinite"/>
            <animateMotion dur="9s" repeatCount="indefinite" path="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"/>
          </circle>
          <circle r="14" fill="#1a1d22" stroke="#ff6a2c" strokeWidth="2.4">
            <animateMotion dur="9s" repeatCount="indefinite" path="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"/>
          </circle>
          <text y="4" textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="11" fontWeight="900">J</text>
          <animateMotion dur="9s" repeatCount="indefinite" path="M 50,270 Q 120,240 170,200 Q 230,160 290,120 Q 360,90 430,60"/>
        </g>
      </g>

      {/* Vitals readouts — right rail */}
      <g transform="translate(560,30)">
        <text x="0" y="14" fill="#5a6470" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.2em">LIVE · 1Hz</text>

        {[
          { label:'POSITION',  value:'8.4', unit:'km',     y:30,  color:'#ff8a4d' },
          { label:'ELEVATION', value:'1,850', unit:'m',    y:74,  color:'#ff8a4d' },
          { label:'PACE',      value:'2.8',  unit:'km/hr', y:118, color:'#eef1f4' },
          { label:'BATTERY',   value:'84',   unit:'%',     y:162, color:'#4cc38a' },
          { label:'LAST PING', value:'2',    unit:'min',   y:206, color:'#eef1f4' },
          { label:'STREAK',    value:'4h 12m', unit:'',    y:250, color:'#4cc38a' },
        ].map((v, i) => (
          <g key={i} transform={`translate(0,${v.y})`}>
            <rect width="124" height="36" rx="6" fill="rgba(13,17,22,0.65)" stroke="rgba(255,255,255,0.06)"/>
            <text x="9" y="11" fill="#5a6470" fontFamily="Manrope" fontSize="7" fontWeight="800" letterSpacing="0.18em">{v.label}</text>
            <text x="9" y="27" fill={v.color} fontFamily="JetBrains Mono" fontSize="14" fontWeight="800" letterSpacing="-0.02em">
              {v.value}
              {v.unit && <tspan dx="3" fill="#98a1ac" fontSize="8" fontWeight="600">{v.unit}</tspan>}
            </text>
            <circle cx="115" cy="12" r="2" fill={v.color}>
              <animate attributeName="opacity" values="0.5;1;0.5" dur={`${1.6 + i*0.2}s`} repeatCount="indefinite"/>
            </circle>
          </g>
        ))}
      </g>
    </svg>
  );
}

/* ---- Scene 3: ALERT — clock + bell + threshold ---- */
function SceneAlert() {
  return (
    <svg viewBox="0 0 720 360" width="100%" height="100%" preserveAspectRatio="xMidYMid meet"
         style={{ display:'block' }}>
      <defs>
        <radialGradient id="alertGlow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#f2a93b" stopOpacity="0.4"/>
          <stop offset="100%" stopColor="#f2a93b" stopOpacity="0"/>
        </radialGradient>
        <linearGradient id="alertProgress" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%"  stopColor="#4cc38a"/>
          <stop offset="60%" stopColor="#f2a93b"/>
          <stop offset="100%" stopColor="#e63d2e"/>
        </linearGradient>
      </defs>

      {/* Big clock face on left */}
      <g transform="translate(180,180)">
        <circle r="110" fill="url(#alertGlow)" opacity="0.7"/>
        <circle r="92" fill="#0a0c0f" stroke="rgba(255,255,255,0.06)" strokeWidth="1.5"/>
        <circle r="88" fill="none" stroke="rgba(255,106,44,0.15)" strokeWidth="0.8" strokeDasharray="3 3"/>
        {/* Tick marks */}
        {Array.from({ length: 12 }).map((_, i) => {
          const a = (i * 30 - 90) * Math.PI / 180;
          const r1 = i % 3 === 0 ? 72 : 78;
          const r2 = 86;
          return (
            <line key={i}
              x1={Math.cos(a)*r1} y1={Math.sin(a)*r1}
              x2={Math.cos(a)*r2} y2={Math.sin(a)*r2}
              stroke={i % 3 === 0 ? '#ff8a4d' : '#5a6470'}
              strokeWidth={i % 3 === 0 ? 2 : 1} strokeLinecap="round"/>
          );
        })}
        {/* Expected return arc (green to red) */}
        <path d="M 0,-70 A 70 70 0 0 1 70,0" fill="none" stroke="url(#alertProgress)" strokeWidth="6" strokeLinecap="round" opacity="0.85"/>
        {/* Hour hand */}
        <line x1="0" y1="0" x2="0" y2="-45" stroke="#eef1f4" strokeWidth="3" strokeLinecap="round" transform="rotate(60)"/>
        {/* Minute hand — sweeps */}
        <line x1="0" y1="0" x2="0" y2="-65" stroke="#ff6a2c" strokeWidth="2.4" strokeLinecap="round"
          style={{ transformOrigin: '0px 0px', animation: 'pcMinuteHand 6s linear infinite' }}/>
        {/* Center pivot */}
        <circle r="5" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="1.5"/>
        <circle r="1.8" fill="#ff8a4d"/>

        {/* Big time readout */}
        <text y="-110" textAnchor="middle" fill="#5a6470" fontFamily="Manrope" fontSize="9" fontWeight="800" letterSpacing="0.24em">NOW</text>
        <text y="125" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="13" fontWeight="900" letterSpacing="0.06em">10:09 / EXPECTED 13:30</text>
        <text y="140" textAnchor="middle" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700" letterSpacing="0.16em">GRACE 30 min · ALERT AT 14:00</text>
      </g>

      <style>{`@keyframes pcMinuteHand {
        from { transform: rotate(180deg); }
        to   { transform: rotate(540deg); }
      }`}</style>

      {/* Right side — channels stack */}
      <g transform="translate(370,60)">
        <text fill="#5a6470" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.22em">WHEN THRESHOLD CROSSES</text>

        {[
          { y:30,  ic:'M 4,2 H 16 V 14 H 4 Z M 4,2 L 10,8 L 16,2',  label:'DESKTOP NOTIFICATION', sub:'instant',                color:'#4cc38a', glyph:'desktop' },
          { y:90,  ic:'',  label:'SMS',                  sub:'+27 82 123 4567',         color:'#5aa1d6', glyph:'message' },
          { y:150, ic:'',  label:'PHONE CALL',           sub:'auto-dial after 4 missed pings', color:'#ff8a4d', glyph:'phone' },
          { y:210, ic:'',  label:'EMERGENCY CONTACT',    sub:'James Carter · partner',  color:'#e63d2e', glyph:'shield' },
        ].map((c, i) => (
          <g key={i} transform={`translate(0,${c.y})`}>
            <rect width="320" height="48" rx="9" fill="rgba(13,17,22,0.7)"
              stroke={`${c.color}55`} strokeWidth="1"/>
            <rect x="0" y="0" width="3" height="48" fill={c.color}/>
            {/* icon block */}
            <g transform="translate(14,12)">
              <rect width="22" height="22" rx="5" fill={`${c.color}1f`} stroke={`${c.color}66`} strokeWidth="1"/>
              <text x="11" y="17" textAnchor="middle" fill={c.color} fontFamily="JetBrains Mono" fontSize="13" fontWeight="900">
                {c.glyph === 'desktop' ? '⎕' : c.glyph === 'message' ? '✉' : c.glyph === 'phone' ? '☏' : '◆'}
              </text>
            </g>
            <text x="50" y="22" fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="800" letterSpacing="0.04em">{c.label}</text>
            <text x="50" y="36" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9" fontWeight="600" letterSpacing="0.04em">{c.sub}</text>
            {/* Animated dot on the right */}
            <circle cx="306" cy="24" r="3.2" fill={c.color} opacity="0.85">
              <animate attributeName="opacity" values="0.4;1;0.4" dur="2s" begin={`${i*0.3}s`} repeatCount="indefinite"/>
            </circle>
          </g>
        ))}
      </g>
    </svg>
  );
}

/* ---- Scene 4: SOS — orb pulsing + radial connections to services ---- */
function SceneSOS() {
  return (
    <svg viewBox="0 0 720 360" width="100%" height="100%" preserveAspectRatio="xMidYMid meet"
         style={{ display:'block' }}>
      <defs>
        <radialGradient id="sosGlow" cx="50%" cy="50%" r="50%">
          <stop offset="0%"  stopColor="#ff6a4d" stopOpacity="0.7"/>
          <stop offset="100%" stopColor="#82120c" stopOpacity="0"/>
        </radialGradient>
        <radialGradient id="sosOrb" cx="35%" cy="30%" r="65%">
          <stop offset="0%"  stopColor="#ff8a6a"/>
          <stop offset="50%" stopColor="#d6291f"/>
          <stop offset="100%" stopColor="#82120c"/>
        </radialGradient>
      </defs>

      {/* Center SOS orb */}
      <g transform="translate(360,180)">
        {/* Ripple rings */}
        {[0, 1.2, 2.4].map((d, i) => (
          <circle key={i} r="60" fill="none" stroke="#ff6a2c" strokeWidth="1" opacity="0.7">
            <animate attributeName="r" values="55;130;55" dur="3.6s" begin={`${d}s`} repeatCount="indefinite"/>
            <animate attributeName="opacity" values="0.7;0;0.7" dur="3.6s" begin={`${d}s`} repeatCount="indefinite"/>
          </circle>
        ))}
        <circle r="80" fill="url(#sosGlow)"/>
        <circle r="56" fill="url(#sosOrb)" stroke="#ffb486" strokeWidth="2"/>
        <text y="-3" textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="22" fontWeight="900" letterSpacing="0.1em">SOS</text>
        <text y="15" textAnchor="middle" fill="#ffd5c4" fontFamily="Manrope" fontSize="8" fontWeight="800" letterSpacing="0.2em">INCIDENT-7731</text>
        <text y="80" textAnchor="middle" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="9" fontWeight="700" letterSpacing="0.16em">10:14:36 · LIVE LOCATION SENT</text>
      </g>

      {/* Service endpoints around the orb with connecting lines */}
      {[
        { angle: 160, label: 'ER24 AMBULANCE',  sub: '084 124',        color: '#f2a93b', glyph: '+' },
        { angle: 340, label: 'BASE CAMP · YOU', sub: 'home · paired',  color: '#4cc38a', glyph: '⌂' },
        { angle:  20, label: 'NEXT OF KIN',     sub: 'James Carter',   color: '#5aa1d6', glyph: '☏' },
      ].map((s, i) => {
        const rad = (s.angle - 90) * Math.PI / 180;
        const cx = 360 + Math.cos(rad) * 200;
        const cy = 180 + Math.sin(rad) * 130;
        const sx = 360 + Math.cos(rad) * 76;
        const sy = 180 + Math.sin(rad) * 76;
        return (
          <g key={i}>
            {/* Connection line + traveling packet */}
            <line x1={sx} y1={sy} x2={cx} y2={cy} stroke={s.color} strokeWidth="1.2" opacity="0.55" strokeDasharray="4 3"/>
            <circle r="3.5" fill={s.color}>
              <animate attributeName="cx" values={`${sx};${cx}`} dur="2.4s" begin={`${i*0.4}s`} repeatCount="indefinite"/>
              <animate attributeName="cy" values={`${sy};${cy}`} dur="2.4s" begin={`${i*0.4}s`} repeatCount="indefinite"/>
              <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.1;0.85;1" dur="2.4s" begin={`${i*0.4}s`} repeatCount="indefinite"/>
            </circle>
            {/* Service node */}
            <g transform={`translate(${cx},${cy})`}>
              <circle r="24" fill={`${s.color}22`} opacity="0.4">
                <animate attributeName="r" values="22;28;22" dur="2.6s" repeatCount="indefinite"/>
              </circle>
              <circle r="18" fill="#0a0c0f" stroke={s.color} strokeWidth="1.8"/>
              <text y="5" textAnchor="middle" fill={s.color} fontFamily="JetBrains Mono" fontSize="14" fontWeight="900">{s.glyph}</text>
            </g>
            {/* Label */}
            <g transform={`translate(${cx + (cx > 360 ? 30 : -30)},${cy})`}>
              <text x="0" y="-2" textAnchor={cx > 360 ? 'start' : 'end'} fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="800" letterSpacing="0.06em">{s.label}</text>
              <text x="0" y="12" textAnchor={cx > 360 ? 'start' : 'end'} fill={s.color} fontFamily="JetBrains Mono" fontSize="9" fontWeight="700" letterSpacing="0.06em">{s.sub}</text>
            </g>
          </g>
        );
      })}
    </svg>
  );
}

/* =================================================================
   Auth bits (form + helpers)
   ================================================================= */
function WelcomePillar({ ic, title, sub }) {
  return (
    <div style={{
      flex: 1,
      display:'flex', gap:10, alignItems:'center',
      padding:'10px 14px',
      background:'rgba(13,17,22,0.55)',
      backdropFilter:'blur(14px)',
      border:'1px solid var(--tt-line-2)',
      borderRadius:11,
    }}>
      <div style={{
        width:30, height:30, borderRadius:8,
        background:'var(--tt-ember-dim)', border:'1px solid rgba(255,106,44,0.36)',
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name={ic} size={14} color="var(--tt-ember)"/>
      </div>
      <div style={{ minWidth: 0 }}>
        <div style={{ font:'800 12.5px var(--tt-font)', color:'#fff' }}>{title}</div>
        <div style={{ font:'600 10px var(--tt-mono)', color:'#cfd5dd', marginTop:1, letterSpacing:'0.04em' }}>{sub}</div>
      </div>
    </div>
  );
}

function ToggleSeg({ active, onClick, icon, label }) {
  return (
    <button onClick={onClick} className="pressable" style={{
      flex:1, padding:'10px 12px', borderRadius:8,
      background: active ? 'var(--tt-ember-dim)' : 'transparent',
      border: active ? '1px solid rgba(255,106,44,0.32)' : '1px solid transparent',
      color: active ? 'var(--tt-ember)' : 'var(--tt-text-3)',
      font:'800 11px var(--tt-font)', letterSpacing:'0.14em',
      cursor:'pointer',
      display:'inline-flex', alignItems:'center', justifyContent:'center', gap:7,
    }}>
      <Icon name={icon} size={13} color="currentColor"/>
      {label}
    </button>
  );
}

function SignInForm() {
  const [remember, setRemember] = React.useState(true);
  return (
    <div>
      <WelcomeLabel>WORK EMAIL</WelcomeLabel>
      <input type="email" defaultValue="sarah@trailtether.app"
        style={inputStyle()}/>
      <div style={{ display:'flex', alignItems:'center', gap:9, marginTop:14 }}>
        <button onClick={() => setRemember(r => !r)} style={{
          width:18, height:18, borderRadius:5,
          background: remember ? 'var(--tt-ember)' : 'transparent',
          border:`1.5px solid ${remember ? 'var(--tt-ember)' : 'var(--tt-line-3)'}`,
          display:'grid', placeItems:'center',
          cursor:'pointer', padding:0,
          transition:'all 200ms ease',
          boxShadow: remember ? '0 0 8px rgba(255,106,44,0.4)' : 'none',
        }}>
          {remember && <Icon name="check" size={10} color="#1a0d04" strokeWidth={3}/>}
        </button>
        <span style={{ font:'600 12px var(--tt-font)', color:'var(--tt-text-2)' }}>Keep me signed in on this PC</span>
      </div>
      <button className="pressable" style={{
        width:'100%', marginTop:22,
        padding:'14px 18px', borderRadius:11,
        background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
        border:'none', color:'#1a0d04',
        font:'900 13px var(--tt-font)', letterSpacing:'0.18em',
        cursor:'pointer',
        boxShadow:'var(--tt-shadow-ember)',
        display:'inline-flex', alignItems:'center', justifyContent:'center', gap:10,
      }}>
        SEND ME A LINK
        <Icon name="arrow-up-right" size={14} color="#1a0d04" strokeWidth={2.4}/>
      </button>
    </div>
  );
}

function PairForm() {
  return (
    <div>
      <WelcomeLabel>PAIRING CODE FROM PHONE</WelcomeLabel>
      <div style={{ display:'flex', gap:8 }}>
        {['', '', '', '', '', '', '', ''].map((_, i) => (
          <div key={i} style={{
            flex:1, height:54, borderRadius:9,
            background:'rgba(255,255,255,0.03)',
            border: i < 4 ? '1px solid rgba(255,106,44,0.36)' : '1px solid var(--tt-line-2)',
            display:'grid', placeItems:'center',
            font:'900 22px var(--tt-mono)',
            color: i < 4 ? 'var(--tt-ember)' : 'var(--tt-text-3)',
          }}>{i < 4 ? ['K','7','9','X'][i] : '·'}</div>
        ))}
      </div>
      <div style={{ font:'600 11px/1.5 var(--tt-font)', color:'var(--tt-text-3)', marginTop:14 }}>
        Open Trailtether on your phone → <b style={{color:'var(--tt-ember)'}}>Settings → Tether → Pair this Base Camp</b>. The code expires in 9:47.
      </div>
      <button className="pressable" style={{
        width:'100%', marginTop:22,
        padding:'14px 18px', borderRadius:11,
        background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
        border:'none', color:'#1a0d04',
        font:'900 13px var(--tt-font)', letterSpacing:'0.18em',
        cursor:'pointer',
        boxShadow:'var(--tt-shadow-ember)',
        display:'inline-flex', alignItems:'center', justifyContent:'center', gap:10,
      }}>
        PAIR BASE CAMP
        <Icon name="tether" size={14} color="#1a0d04" strokeWidth={2.4}/>
      </button>
    </div>
  );
}

function SocialButton({ label, glyph }) {
  return (
    <button className="pressable" style={{
      padding:'12px 14px', borderRadius:11,
      background:'rgba(255,255,255,0.04)',
      border:'1px solid var(--tt-line-2)',
      color:'var(--tt-text)',
      font:'800 11px var(--tt-font)', letterSpacing:'0.12em',
      cursor:'pointer',
      display:'inline-flex', alignItems:'center', justifyContent:'center', gap:9,
    }}>
      <span style={{ font:'900 14px var(--tt-mono)', color:'var(--tt-ember)' }}>{glyph}</span>
      {label.toUpperCase()}
    </button>
  );
}

function WelcomeLabel({ children }) {
  return (
    <div style={{ font:'800 10px var(--tt-font)', letterSpacing:'0.2em',
      textTransform:'uppercase', color:'var(--tt-text-3)', marginBottom:7 }}>
      {children}
    </div>
  );
}

function inputStyle() {
  return {
    width:'100%', padding:'14px 16px', boxSizing:'border-box',
    background:'rgba(255,255,255,0.04)',
    border:'1px solid var(--tt-line-2)', borderRadius:11,
    color:'var(--tt-text)',
    font:'600 14px var(--tt-font)',
    outline:'none',
  };
}

window.PCScreenWelcome = PCScreenWelcome;

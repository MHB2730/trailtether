// Trailtether — Home tab

function ScreenHome() {
  return (
    <div className="phone">
      <div className="punchhole" />
      <div className="screen">
        <StatusBar
          time="10:09"
          right={
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--tt-green)', fontSize: 10.5, fontWeight: 700, letterSpacing: '0.1em', marginRight: 4 }}>
              <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'var(--tt-green)', boxShadow: '0 0 6px var(--tt-green)', animation: 'pulse 1.6s infinite' }} />
              TETHERED
            </span>
          } />
        

        <div className="tt-scroll" style={{ paddingBottom: 8 }}>
          <HomeHero />
          <HomeQuickActions />
          <UpcomingHikeCard />
          <WeatherCard />
          <LastHikeCard />
          <FieldIntelStrip />
        </div>

        <BottomNav active="home" />
      </div>
    </div>);

}

function HomeHero() {
  // Easter egg: when there's snow forecast for the Drakensberg, swap to
  // the snowed-in mountain hero. Otherwise the regular dusk shot.
  const [tt] = useTT();
  const snow = !!tt.snow;
  return (
    <div style={{ position: 'relative', height: 260, overflow: 'hidden' }}>
      <img
        key={snow ? 'snow' : 'normal'}
        src={snow ? 'assets/hero_snow.png' : 'assets/hero_mountain.png'}
        alt=""
        style={{
          position: 'absolute', inset: 0,
          width: '100%', height: '100%',
          objectFit: 'cover',
          objectPosition: snow ? 'center 50%' : 'center 58%',
          filter: snow ?
          'saturate(0.92) contrast(1.04) brightness(0.96)' :
          'saturate(1.06) contrast(1.06)',
          animation: 'fadeIn 600ms ease'
        }} />

      {/* Animated ember accents on top of the photographed trail */}
      <BurnAccents snow={snow} />

      {/* Subtle snowfall when snow is forecast */}
      {snow && <SnowfallOverlay />}

      {/* Bottom fade into app background for legibility */}
      <div style={{
        position: 'absolute', inset: 0,
        background: snow ?
        'linear-gradient(180deg, rgba(7,9,12,0.25) 0%, rgba(7,9,12,0.05) 32%, rgba(7,9,12,0.55) 72%, var(--tt-bg) 100%)' :
        'linear-gradient(180deg, rgba(7,9,12,0.35) 0%, rgba(7,9,12,0.05) 32%, rgba(7,9,12,0.55) 72%, var(--tt-bg) 100%)',
        pointerEvents: 'none'
      }} />

      {/* Top brand */}
      <div className="tt-appbar anim-in" style={{ position: 'absolute', top: 0, left: 0, right: 0, paddingTop: 14 }}>
        <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 9 }}>
          <TTLogo size={26} />
          <span style={{ font: '800 13px var(--tt-font)', letterSpacing: '0.16em' }}>
            TRAIL<span style={{ color: 'var(--tt-ember)' }}>TETHER</span>
          </span>
        </div>
        <button className="icon-btn"><Icon name="bell" size={16} color="var(--tt-text-2)" /></button>
        <div className="anim-pop" style={{
          width: 38, height: 38, borderRadius: '50%',
          border: '2px solid var(--tt-ember)',
          background: 'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
          display: 'grid', placeItems: 'center',
          color: '#fff', font: '800 13px var(--tt-font)',
          boxShadow: '0 0 14px rgba(255,106,44,0.45)',
          animationDelay: '150ms'
        }}>JD</div>
      </div>

      {/* Greeting overlay */}
      <div className="anim-up" style={{ position: 'absolute', left: 22, bottom: 22, right: 22, animationDelay: '220ms' }}>
        <div style={{ font: '800 11px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '0.2em', textShadow: '0 2px 8px rgba(0,0,0,0.55)' }}>WELCOME BACK,</div>
        <div style={{ font: '900 34px/1 var(--tt-font)', color: 'var(--tt-text)', letterSpacing: '-0.025em', marginTop: 6, textShadow: '0 2px 16px rgba(0,0,0,0.55)' }}>John D.</div>
      </div>
    </div>);

}

/* ----------- Burn accents -----------
   The hero photo already has the trail "burned" into the rock. We just
   add atmosphere on top: a fast comet riding the summit line + slowly
   drifting embers rising from the ridge. */
const HERO_TRAIL_D =
"M 205,255 " +
"C 220,240 195,225 200,210 " +
"S 170,185 195,170 " +
"S 215,150 200,130 " +
"S 175,108 198,90 " +
"S 215,68 204,46";

function BurnAccents({ snow = false }) {
  // Trail path differs between the two hero images:
  //   - normal: vertical-ish summit climb in the central peak
  //   - snow:   diagonal switchback descending from the central peak to lower-left
  const trailD = snow ?
  'M 410,30 C 380,45 360,50 340,75 S 300,110 270,130 ' +
  'S 240,145 215,160 S 175,180 160,200 S 130,225 100,240 S 80,250 60,256' :
  'M 205,255 C 220,240 195,225 200,210 S 170,185 195,170 ' +
  'S 215,150 200,130 S 175,108 198,90 S 215,68 204,46';
  return (
    <svg
      viewBox="0 0 412 260"
      width="100%" height="100%"
      preserveAspectRatio="xMidYMid slice"
      style={{ position: 'absolute', inset: 0, display: 'block', pointerEvents: 'none' }}
      aria-hidden="true">
      <defs>
        <radialGradient id="heroComet" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#fff4d6" stopOpacity="1" />
          <stop offset="35%" stopColor="#ff8a4d" stopOpacity="0.85" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="heroEmberDot" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#ffe9c2" stopOpacity="1" />
          <stop offset="55%" stopColor="#ff8a4d" stopOpacity="0.6" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </radialGradient>
        <radialGradient id="heroSummitGlow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#ff8a4d" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Summit halo — pulses gently. Position varies by hero. */}
      <g style={{ mixBlendMode: 'screen' }}>
        <ellipse
          cx={snow ? 396 : 204}
          cy={snow ? 34 : 46}
          rx="26" ry="16" fill="url(#heroSummitGlow)">
          <animate attributeName="opacity" values="0.6;1;0.6" dur="3.4s" repeatCount="indefinite" />
        </ellipse>
      </g>

      {/* Comet riding the trail line */}
      <g style={{ mixBlendMode: 'screen' }}>
        <circle r="6" fill="url(#heroComet)" opacity="0.95">
          <animateMotion dur="6.5s" repeatCount="indefinite" rotate="auto"
          path={trailD} keyTimes="0;1" calcMode="spline" keySplines="0.4 0 0.4 1" />
          <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.12;0.88;1" dur="6.5s" repeatCount="indefinite" />
        </circle>
        <circle r="2.4" fill="#fff4d6" opacity="1">
          <animateMotion dur="6.5s" repeatCount="indefinite" rotate="auto" path={trailD} />
          <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.12;0.88;1" dur="6.5s" repeatCount="indefinite" />
        </circle>
      </g>

      {/* Drifting embers (fewer + a touch cooler when there's snow) */}
      <g style={{ mixBlendMode: 'screen', opacity: snow ? 0.7 : 1 }}>
        {(snow ? [
        { x: 380, y: 60, dx: -4, dy: -32, delay: 0.4, dur: 4.2, r: 1.4 },
        { x: 340, y: 90, dx: 5, dy: -38, delay: 1.6, dur: 4.8, r: 1.2 },
        { x: 280, y: 130, dx: -6, dy: -42, delay: 2.4, dur: 5.0, r: 1.2 },
        { x: 220, y: 170, dx: 6, dy: -36, delay: 0.9, dur: 4.4, r: 1.4 },
        { x: 160, y: 200, dx: -3, dy: -32, delay: 3.0, dur: 4.2, r: 1.0 },
        { x: 100, y: 230, dx: 4, dy: -38, delay: 1.2, dur: 4.6, r: 1.2 }] :
        [
        { x: 200, y: 220, dx: -4, dy: -42, delay: 0.4, dur: 4.2, r: 1.6 },
        { x: 210, y: 200, dx: 5, dy: -50, delay: 1.6, dur: 4.8, r: 1.2 },
        { x: 188, y: 175, dx: -6, dy: -55, delay: 2.4, dur: 5.0, r: 1.4 },
        { x: 215, y: 155, dx: 6, dy: -48, delay: 0.9, dur: 4.4, r: 1.8 },
        { x: 195, y: 135, dx: -3, dy: -38, delay: 3.0, dur: 4.2, r: 1.2 },
        { x: 205, y: 110, dx: 4, dy: -45, delay: 1.2, dur: 4.6, r: 1.6 },
        { x: 200, y: 82, dx: -2, dy: -35, delay: 2.0, dur: 3.8, r: 1.4 },
        { x: 175, y: 240, dx: -7, dy: -38, delay: 0.2, dur: 4.0, r: 1.2 },
        { x: 230, y: 235, dx: 8, dy: -42, delay: 1.8, dur: 4.6, r: 1.4 },
        { x: 160, y: 195, dx: -9, dy: -35, delay: 2.8, dur: 4.2, r: 1.0 },
        { x: 245, y: 165, dx: 10, dy: -50, delay: 0.6, dur: 5.0, r: 1.6 },
        { x: 168, y: 130, dx: -8, dy: -42, delay: 1.4, dur: 4.4, r: 1.2 }]).
        map((e, i) =>
        <circle key={i} cx={e.x} cy={e.y} r={e.r} fill="url(#heroEmberDot)" opacity="0">
            <animate attributeName="cy" from={e.y} to={e.y + e.dy} dur={`${e.dur}s`} begin={`${e.delay}s`} repeatCount="indefinite" />
            <animate attributeName="cx" from={e.x} to={e.x + e.dx} dur={`${e.dur}s`} begin={`${e.delay}s`} repeatCount="indefinite" />
            <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.15;0.7;1" dur={`${e.dur}s`} begin={`${e.delay}s`} repeatCount="indefinite" />
            <animate attributeName="r" values={`${e.r};${e.r * 0.35}`} dur={`${e.dur}s`} begin={`${e.delay}s`} repeatCount="indefinite" />
          </circle>
        )}
      </g>
    </svg>);

}

/* Drifting snowflakes for the snow easter egg */
function SnowfallOverlay() {
  const flakes = React.useMemo(() => Array.from({ length: 36 }).map((_, i) => ({
    x: Math.random() * 100,
    delay: Math.random() * 6,
    dur: 4 + Math.random() * 5,
    size: 1 + Math.random() * 2.2,
    drift: (Math.random() - 0.5) * 30,
    opacity: 0.5 + Math.random() * 0.5
  })), []);
  return (
    <svg viewBox="0 0 100 100" preserveAspectRatio="none"
    style={{ position: 'absolute', inset: 0, width: '100%', height: '100%',
      pointerEvents: 'none', mixBlendMode: 'screen' }}>
      {flakes.map((f, i) =>
      <circle key={i} cx={f.x} cy={-2} r={f.size * 0.3} fill="#ffffff" opacity={f.opacity}>
          <animate attributeName="cy" from="-2" to="105" dur={`${f.dur}s`} begin={`${f.delay}s`} repeatCount="indefinite" />
          <animate attributeName="cx" from={f.x} to={f.x + f.drift} dur={`${f.dur}s`} begin={`${f.delay}s`} repeatCount="indefinite" />
          <animate attributeName="opacity" values={`0;${f.opacity};${f.opacity};0`} keyTimes="0;0.1;0.85;1" dur={`${f.dur}s`} begin={`${f.delay}s`} repeatCount="indefinite" />
        </circle>
      )}
    </svg>);

}


function HomeQuickActions() {
  const actions = [
  { id: 'start', icon: 'play', label: 'Start Hike', color: 'var(--tt-ember)', primary: true },
  { id: 'plan', icon: 'route', label: 'Plan Route', color: 'var(--tt-text-2)' },
  { id: 'track', icon: 'eye', label: 'Live Track', color: 'var(--tt-blue)' },
  { id: 'sos', icon: 'radio', label: 'SOS', color: 'var(--tt-red)' }];

  return (
    <div style={{ padding: '18px 18px 0' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
        <Stagger base={350} delay={70}>
          {actions.map((a) => <QuickActionTile key={a.id} {...a} />)}
        </Stagger>
      </div>
    </div>);

}

function QuickActionTile({ icon, label, color, primary }) {
  return (
    <button className="pressable" style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7,
      padding: '12px 6px 10px',
      background: primary ? 'var(--tt-ember-dim)' : 'var(--tt-surf)',
      border: `1px solid ${primary ? 'rgba(255,106,44,0.36)' : 'var(--tt-line)'}`,
      borderRadius: 14,
      cursor: 'pointer',
      color: primary ? 'var(--tt-ember)' : 'var(--tt-text)',
      boxShadow: primary ? 'inset 0 0 14px rgba(255,106,44,0.18)' : 'none'
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 11,
        background: primary ? 'rgba(255,106,44,0.18)' : `${color}10`,
        border: `1px solid ${primary ? 'rgba(255,106,44,0.5)' : 'var(--tt-line-2)'}`,
        display: 'grid', placeItems: 'center'
      }}>
        <Icon name={icon} size={17} color={color} strokeWidth={2} />
      </div>
      <span style={{ font: '800 9.5px var(--tt-font)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>{label}</span>
    </button>);

}

function UpcomingHikeCard() {
  return (
    <div style={{ padding: '16px 18px 0' }}>
      <div className="card pressable anim-up" style={{ padding: '16px 18px', animationDelay: '650ms', position: 'relative', overflow: 'hidden' }}>
        {/* Ambient ember corner */}
        <div style={{
          position: 'absolute', top: -30, right: -30,
          width: 120, height: 120, borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(255,106,44,0.22), transparent 70%)',
          pointerEvents: 'none'
        }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--tt-ember)', boxShadow: '0 0 6px var(--tt-ember)', animation: 'pulse 1.4s infinite' }} />
            <span style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '0.18em' }}>UPCOMING HIKE · IN 2 DAYS</span>
          </div>
          <span className="pill ember">4 GOING</span>
        </div>

        <div style={{ font: '800 19px var(--tt-font)', color: 'var(--tt-text)', marginTop: 10, letterSpacing: '-0.01em' }}>Mt. Marcy Summit</div>
        <div style={{ font: '600 11px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 3, letterSpacing: '0.04em' }}>OCT 28 · 06:00 START · 12.4 KM</div>

        {/* Avatar stack + countdown */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 14 }}>
          <div style={{ display: 'flex' }}>
            {[
            { i: 'J', c: '#ff6a2c' },
            { i: 'S', c: '#ff8a4d' },
            { i: 'M', c: '#4cc38a' },
            { i: 'E', c: '#f2a93b' }].
            map((a, idx) =>
            <div key={idx} style={{
              width: 30, height: 30, borderRadius: '50%',
              background: a.c,
              display: 'grid', placeItems: 'center',
              color: '#fff', font: '800 11px var(--tt-font)',
              border: '2px solid var(--tt-surf)',
              marginLeft: idx === 0 ? 0 : -10,
              zIndex: 10 - idx
            }}>
                {a.i}
              </div>
            )}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ textAlign: 'right' }}>
              <div style={{ font: '700 9px var(--tt-font)', color: 'var(--tt-text-3)', letterSpacing: '0.16em' }}>STARTS IN</div>
              <div className="num" style={{ font: '800 17px var(--tt-mono)', color: 'var(--tt-text)', letterSpacing: '-0.02em', marginTop: 2 }}>2d 19h</div>
            </div>
            <Icon name="chevron-right" size={16} color="var(--tt-text-3)" />
          </div>
        </div>
      </div>
    </div>);

}

function WeatherCard() {
  return (
    <div className="card anim-up" style={{
      margin: '14px 18px 0',
      padding: '14px 16px',
      animationDelay: '750ms',
      position: 'relative', overflow: 'hidden'
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
        <span style={{ font: '700 11px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-2)' }}>
          Conditions · <span style={{ color: 'var(--tt-text-3)' }}>Drakensberg N</span>
        </span>
        <span style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '0.1em' }}>7 DAYS →</span>
      </div>

      {/* Now reading */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        {/* Sun + cloud illustration */}
        <svg width="64" height="64" viewBox="0 0 64 64" style={{ flex: '0 0 auto' }}>
          <defs>
            <radialGradient id="homeWxSun" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#ffb486" />
              <stop offset="100%" stopColor="#ff6a2c" />
            </radialGradient>
          </defs>
          {/* Sun + rays */}
          <g transform="translate(24,24)">
            <circle r="14" fill="url(#homeWxSun)" />
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
          {/* Cloud */}
          <g style={{ animation: 'cloudDrift 5s ease-in-out infinite' }}>
            <ellipse cx="40" cy="44" rx="14" ry="9" fill="#2a313c" />
            <ellipse cx="50" cy="46" rx="11" ry="7" fill="#2a313c" />
            <ellipse cx="44" cy="38" rx="9" ry="6" fill="#2a313c" />
          </g>
        </svg>

        <div style={{ flex: 1 }}>
          <div className="num" style={{ font: '800 32px/1 var(--tt-mono)', color: 'var(--tt-text)', letterSpacing: '-0.025em' }}>14°<span style={{ fontSize: 14, color: 'var(--tt-text-2)', marginLeft: 4, fontWeight: 600 }}>C</span></div>
          <div style={{ font: '600 11px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 4, letterSpacing: '0.05em' }}>PART CLOUDY · WIND 18 km/hr</div>
        </div>

        <div style={{ textAlign: 'right' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '4px 8px', borderRadius: 6,
            background: 'rgba(76,195,138,0.14)',
            border: '1px solid rgba(76,195,138,0.32)'
          }}>
            <span className="num" style={{ font: '800 13px var(--tt-mono)', color: 'var(--tt-green)' }}>8</span>
            <span style={{ font: '600 9.5px var(--tt-font)', color: 'var(--tt-green)', letterSpacing: '0.08em', opacity: 0.85 }}>/10</span>
          </div>
          <div style={{ font: '700 9px var(--tt-font)', color: 'var(--tt-green)', marginTop: 4, letterSpacing: '0.14em' }}>HIKE SCORE</div>
        </div>
      </div>

      {/* 4-hour strip */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 4, marginTop: 14, padding: '10px 0 0', borderTop: '1px solid var(--tt-line)' }}>
        {[
        { h: '10', t: '14°', icon: 'sun' },
        { h: '13', t: '17°', icon: 'sun' },
        { h: '16', t: '15°', icon: 'cloud' },
        { h: '19', t: '11°', icon: 'cloud' },
        { h: '22', t: '8°', icon: 'moon' }].
        map((s, i) =>
        <div key={i} style={{ textAlign: 'center' }}>
            <div style={{ font: '700 9px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.06em' }}>{s.h}</div>
            <div style={{ marginTop: 5, height: 18, display: 'grid', placeItems: 'center' }}>
              <WxIcon kind={s.icon} />
            </div>
            <div className="num" style={{ font: '700 11px var(--tt-mono)', color: 'var(--tt-text)', marginTop: 4 }}>{s.t}</div>
          </div>
        )}
      </div>
    </div>);

}

function WxIcon({ kind }) {
  if (kind === 'sun') return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="3" fill="#ff8a4d" />
      {Array.from({ length: 8 }).map((_, i) => {
        const a = i * Math.PI / 4;
        return <line key={i} x1={8 + Math.cos(a) * 5} y1={8 + Math.sin(a) * 5} x2={8 + Math.cos(a) * 7} y2={8 + Math.sin(a) * 7} stroke="#ff8a4d" strokeWidth="1.4" strokeLinecap="round" />;
      })}
    </svg>);

  if (kind === 'cloud') return (
    <svg width="18" height="14" viewBox="0 0 18 14" fill="none">
      <ellipse cx="6" cy="10" rx="5" ry="3" fill="#5a6470" />
      <ellipse cx="12" cy="10" rx="4" ry="2.5" fill="#5a6470" />
      <ellipse cx="9" cy="7" rx="3.5" ry="2.5" fill="#5a6470" />
    </svg>);

  if (kind === 'moon') return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
      <path d="M11 8.5 a4.5 4.5 0 11-5.5-5.5 a3.5 3.5 0 105.5 5.5z" fill="#98a1ac" />
    </svg>);

  return null;
}

function LastHikeCard() {
  return (
    <div style={{ padding: '14px 18px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ font: '700 11px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-2)' }}>Last Hike</span>
        <span style={{ font: '800 10px var(--tt-font)', color: 'var(--tt-ember)', letterSpacing: '0.1em' }}>VIEW ALL →</span>
      </div>
      <div className="card pressable anim-up" style={{ padding: '14px 16px', animationDelay: '900ms' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ font: '800 14px var(--tt-font)', color: 'var(--tt-text)' }}>Mt. Marcy Trail</div>
            <div style={{ font: '600 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 3, letterSpacing: '0.04em' }}>OCT 26 · 5.8 km · 5:14:22</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <span style={{ padding: '3px 7px', borderRadius: 5, background: 'rgba(76,195,138,0.13)', border: '1px solid rgba(76,195,138,0.3)', font: '800 9px var(--tt-mono)', color: 'var(--tt-green)', letterSpacing: '0.12em' }}>SYNCED</span>
            <Icon name="chevron-right" size={15} color="var(--tt-text-3)" />
          </div>
        </div>
        <MiniLastHikeChart />
        <div style={{ display: 'flex', gap: 14, marginTop: 8, font: '700 11px var(--tt-mono)' }}>
          <span style={{ color: 'var(--tt-text-2)' }}>↑ <span style={{ color: 'var(--tt-ember)', fontWeight: 800 }}>3,950</span> m</span>
          <span style={{ color: 'var(--tt-line-3)' }}>|</span>
          <span style={{ color: 'var(--tt-text-2)' }}>🔥 <span style={{ color: 'var(--tt-text)', fontWeight: 800 }}>1,189</span> kcal</span>
          <span style={{ color: 'var(--tt-line-3)' }}>|</span>
          <span style={{ color: 'var(--tt-text-2)' }}>👣 <span style={{ color: 'var(--tt-text)', fontWeight: 800 }}>18,432</span></span>
        </div>
      </div>
    </div>);

}

function MiniLastHikeChart() {
  const w = 320,h = 50,pad = 4;
  const pts = [1500, 1620, 1850, 2100, 2380, 2740, 3120, 3500, 3850, 4200, 4340, 4180, 3900, 3600, 3300, 3000];
  const min = 1400,max = 4500;
  const stepX = (w - pad * 2) / (pts.length - 1);
  const top = pts.map((v, i) => `${i === 0 ? 'M' : 'L'}${pad + i * stepX},${h - pad - (v - min) / (max - min) * (h - pad * 2)}`).join(' ');
  const fill = top + ` L ${w - pad},${h - pad} L ${pad},${h - pad} Z`;
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', marginTop: 10 }} preserveAspectRatio="none">
      <defs>
        <linearGradient id="homeLastElev" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={fill} fill="url(#homeLastElev)" />
      <path d={top} fill="none" stroke="#ff6a2c" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round"
      className="draw-line" style={{ ['--len']: 380, animationDelay: '1100ms' }} />
    </svg>);

}

function FieldIntelStrip() {
  return (
    <div style={{ padding: '18px 18px 18px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ font: '700 11px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-2)' }}>Field Intel</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <Stagger base={1050} delay={80}>
          <IntelRow icon="alert" color="#f2a93b" title="Loose rock near km 4.8" sub="Wonderland Trail · reported 18m ago" />
          <IntelRow icon="wind" color="#5aa1d6" title="Storm forecast in 90 min" sub="Consider shelter at km 5.8 · Cave #47" />
          <IntelRow icon="people" color="#4cc38a" title="3 hikers ahead of you" sub="Last contact 11 min · Sunrise Camp" />
        </Stagger>
      </div>
    </div>);

}

function IntelRow({ icon, color, title, sub }) {
  return (
    <div className="pressable" style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '10px 12px',
      background: 'var(--tt-surf)',
      border: `1px solid ${color}33`,
      borderLeft: `3px solid ${color}`,
      borderRadius: 11,
      cursor: 'pointer'
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 9,
        background: `${color}1f`, border: `1px solid ${color}40`,
        display: 'grid', placeItems: 'center', flex: '0 0 auto'
      }}>
        <Icon name={icon} size={14} color={color} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '800 12px var(--tt-font)', color: 'var(--tt-text)' }}>{title}</div>
        <div style={{ font: '500 10px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 2, letterSpacing: '0.02em' }}>{sub}</div>
      </div>
      <Icon name="chevron-right" size={14} color="var(--tt-text-3)" />
    </div>);

}

window.ScreenHome = ScreenHome;
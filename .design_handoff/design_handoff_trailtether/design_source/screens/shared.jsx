// Shared phone components for Trailtether v2.0

function TTLogo({ size = 22 }) {
  // Original 3D pin-with-mountain mark
  return (
    <img
      src="assets/logo.png"
      alt="Trailtether"
      width={size}
      height={size}
      style={{
        width: size, height: size,
        objectFit: 'contain',
        display: 'block',
        filter: 'drop-shadow(0 0 6px rgba(255,106,44,0.35))',
      }}
    />
  );
}

function StatusBar({ time = "10:09", right = null }) {
  return (
    <div className="tt-status">
      <span className="left">{time}</span>
      <div className="right">
        {right}
        <Signal/>
        <WifiIcon/>
        <BattGlyph2 pct={84}/>
      </div>
    </div>
  );
}

function Signal() {
  return (
    <svg width="16" height="11" viewBox="0 0 16 11" fill="none">
      <rect x="0" y="8"  width="2.4" height="3" rx="0.6" fill="currentColor"/>
      <rect x="4" y="6"  width="2.4" height="5" rx="0.6" fill="currentColor"/>
      <rect x="8" y="4"  width="2.4" height="7" rx="0.6" fill="currentColor"/>
      <rect x="12" y="2" width="2.4" height="9" rx="0.6" fill="currentColor"/>
    </svg>
  );
}
function WifiIcon() {
  return (
    <svg width="15" height="11" viewBox="0 0 16 12" fill="none">
      <path d="M8 11 a1 1 0 100-2 1 1 0 000 2z" fill="currentColor"/>
      <path d="M4 7 a5 5 0 018 0"  stroke="currentColor" strokeWidth="1.4" fill="none" strokeLinecap="round"/>
      <path d="M2 4 a8 8 0 0112 0" stroke="currentColor" strokeWidth="1.4" fill="none" strokeLinecap="round"/>
    </svg>
  );
}
function BattGlyph2({ pct = 84 }) {
  return (
    <span style={{display:'inline-flex', alignItems:'center', gap:5}}>
      <span className="num" style={{fontSize:12, color:'var(--tt-text)', fontWeight:600}}>{pct}</span>
      <span style={{width:24, height:11, border:'1.4px solid var(--tt-text)', borderRadius:3.5, padding:1.2, position:'relative', display:'inline-block'}}>
        <span style={{display:'block', height:'100%', width:`${pct}%`, background:'var(--tt-text)', borderRadius:1}}/>
        <span style={{position:'absolute', right:-3.2, top:2.4, bottom:2.4, width:1.7, background:'var(--tt-text)', borderRadius:1}}/>
      </span>
    </span>
  );
}

function Icon({ name, size = 16, color = "currentColor", strokeWidth = 1.7 }) {
  const s = size, c = color;
  const sw = strokeWidth;
  const common = { width: s, height: s, viewBox: "0 0 24 24", fill: "none", stroke: c, strokeWidth: sw, strokeLinecap: "round", strokeLinejoin: "round" };
  switch (name) {
    case 'mountain': return <svg {...common}><path d="M3 20 L9 9 L13 15 L16 11 L21 20 Z"/></svg>;
    case 'layers': return <svg {...common}><path d="M12 3 L21 8 L12 13 L3 8 Z"/><path d="M3 12 L12 17 L21 12"/><path d="M3 16 L12 21 L21 16"/></svg>;
    case 'compass': return (
      <svg {...common}>
        {/* Pointy-top hexagonal dial — feels crystalline / topographic */}
        <path d="M12 2.6 L20.4 7.6 L20.4 16.4 L12 21.4 L3.6 16.4 L3.6 7.6 Z"/>
        {/* Cardinal hash marks */}
        <path d="M12 4.4 v1.5 M12 18.1 v1.5 M4.9 12 h1.5 M17.6 12 h1.5"/>
        {/* Sharp north needle — top half solid */}
        <path d="M12 6.4 L13.7 12 L12 11.1 L10.3 12 Z" fill={c} stroke="none"/>
        {/* South tail — outlined */}
        <path d="M12 12.9 L13.7 12 L12 17.6 L10.3 12 Z"/>
        {/* Center pivot */}
        <circle cx="12" cy="12" r="0.95" fill={c} stroke="none"/>
      </svg>
    );
    case 'plus': return <svg {...common}><path d="M12 5v14M5 12h14"/></svg>;
    case 'minus': return <svg {...common}><path d="M5 12h14"/></svg>;
    case 'crosshair': return <svg {...common}><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/></svg>;
    case 'route': return <svg {...common}><circle cx="6" cy="19" r="2.5"/><circle cx="18" cy="5" r="2.5"/><path d="M8 19 h6 a3 3 0 003-3 v-6 a3 3 0 013-3"/></svg>;
    case 'filter': return <svg {...common}><path d="M3 5h18 L14 13 v6 l-4 2 v-8 z"/></svg>;
    case 'search': return <svg {...common}><circle cx="11" cy="11" r="7"/><path d="M20 20 l-3.5 -3.5"/></svg>;
    case 'settings': return <svg {...common}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1A2 2 0 1 1 4.4 17l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1A2 2 0 1 1 7 4.4l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1A2 2 0 1 1 19.6 7l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/></svg>;
    case 'alert': return <svg {...common}><path d="M12 3 L22 20 H2 Z"/><path d="M12 10 v5"/><circle cx="12" cy="18" r="0.9" fill={c} stroke="none"/></svg>;
    case 'shield': return <svg {...common}><path d="M12 3 L20 6 v6 c0 5-4 8-8 9-4-1-8-4-8-9 V6 Z"/></svg>;
    case 'radio': return <svg {...common}><path d="M4 11 a8 8 0 0116 0"/><path d="M7 11 a5 5 0 0110 0"/><circle cx="12" cy="11" r="1.6" fill={c} stroke="none"/><path d="M9 17 h6 M10 21 h4"/></svg>;
    case 'pin': return <svg {...common}><path d="M12 22 s-7-7-7-12 a7 7 0 1114 0 c0 5-7 12-7 12z"/><circle cx="12" cy="10" r="2.5"/></svg>;
    case 'flame': return <svg {...common}><path d="M12 22 c-4 0-7-3-7-7 0-3 2-5 3-7 1 2 2 3 4 3 0-3-1-5 1-8 1 2 6 5 6 12 0 4-3 7-7 7z"/></svg>;
    case 'heart': return <svg {...common}><path d="M12 21 s-7-4.5-7-11 a4 4 0 017-2.7 a4 4 0 017 2.7 c0 6.5-7 11-7 11z"/></svg>;
    case 'check': return <svg {...common}><path d="M4 12 l5 5 L20 6"/></svg>;
    case 'chevron-right': return <svg {...common}><path d="M9 6 l6 6 -6 6"/></svg>;
    case 'chevron-down': return <svg {...common}><path d="M6 9 l6 6 6-6"/></svg>;
    case 'chevron-up': return <svg {...common}><path d="M6 15 l6 -6 6 6"/></svg>;
    case 'arrow-up-right': return <svg {...common}><path d="M7 17 L17 7 M9 7 h8 v8"/></svg>;
    case 'send-fill': return <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><path d="M22 2 L2 9 L11 13 L15 22 Z"/></svg>;
    case 'sos': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M9 10 c-1 0-2 .5-2 1.5 s1 1.5 2 1.5 s2 .5 2 1.5 s-1 1.5-2 1.5"/><path d="M14 10 v4"/><path d="M17 10 v4"/></svg>;
    case 'people': return <svg {...common}><circle cx="9" cy="9" r="3"/><path d="M3 20 c0-3 3-5 6-5 s6 2 6 5"/><circle cx="17" cy="8" r="2.5"/><path d="M21 19 c0-2-1.5-3.5-4-4"/></svg>;
    case 'eye': return <svg {...common}><path d="M2 12 s4-7 10-7 s10 7 10 7 s-4 7-10 7 s-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></svg>;
    case 'clock': return <svg {...common}><circle cx="12" cy="12" r="9"/><path d="M12 7 v5 l3 2"/></svg>;
    case 'arrow-up': return <svg {...common}><path d="M12 19 V5 M5 12 l7-7 7 7"/></svg>;
    case 'menu': return <svg {...common}><path d="M3 6 h18 M3 12 h18 M3 18 h18"/></svg>;
    case 'more': return <svg {...common}><circle cx="5"  cy="12" r="1.5" fill={c} stroke="none"/><circle cx="12" cy="12" r="1.5" fill={c} stroke="none"/><circle cx="19" cy="12" r="1.5" fill={c} stroke="none"/></svg>;
    case 'wind': return <svg {...common}><path d="M3 8 h12 a3 3 0 100-6 M3 12 h17 a3 3 0 110 6 M3 16 h8 a2.5 2.5 0 110 5"/></svg>;
    case 'rock': return <svg {...common}><path d="M3 18 L7 9 L13 6 L19 11 L21 18 Z"/></svg>;
    case 'home': return <svg {...common}><path d="M3 11 L12 3 L21 11 V20 a1 1 0 01-1 1 H4 a1 1 0 01-1-1 z"/></svg>;
    case 'history': return <svg {...common}><path d="M3 12 a9 9 0 109-9 v3"/><path d="M3 3 v6 h6"/><path d="M12 8 v4 l3 2"/></svg>;
    case 'user': return <svg {...common}><circle cx="12" cy="8" r="4"/><path d="M4 21 c0-4 3.5-7 8-7 s8 3 8 7"/></svg>;
    case 'phone': return <svg {...common}><path d="M22 17 v3 a2 2 0 01-2 2 c-10 0-18-8-18-18 a2 2 0 012-2 h3 a2 2 0 012 1.7 l.7 4 a2 2 0 01-.6 1.9 l-1.5 1.5 a16 16 0 006 6 l1.5-1.5 a2 2 0 011.9-.6 l4 .7 a2 2 0 011.7 2z"/></svg>;
    case 'map': return <svg {...common}><path d="M9 3 L3 5 V21 L9 19 L15 21 L21 19 V3 L15 5 Z"/><path d="M9 3 V19 M15 5 V21"/></svg>;
    case 'play': return <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><path d="M6 4 L20 12 L6 20 Z"/></svg>;
    case 'pause': return <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>;
    case 'stop': return <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><rect x="6" y="6" width="12" height="12" rx="2"/></svg>;
    case 'bell': return <svg {...common}><path d="M6 8 a6 6 0 0112 0 c0 7 3 9 3 9 H3 s3-2 3-9"/><path d="M10 21 a2 2 0 004 0"/></svg>;
    case 'message': return <svg {...common}><path d="M21 15 a2 2 0 01-2 2 H8 l-5 4 V5 a2 2 0 012-2 h14 a2 2 0 012 2 z"/></svg>;
    case 'navigation': return <svg width={s} height={s} viewBox="0 0 24 24" fill={c}><path d="M12 2 L21 21 L12 17 L3 21 Z"/></svg>;
    case 'tether': return <svg {...common}><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="12" r="2.5"/><path d="M8.5 12 h7"/><path d="M11 9 l2 3 -2 3"/></svg>;
    default: return null;
  }
}

// Phone app bar with title + subtitle and right slot
function PhoneAppBar({ title, sub, leftIcon, rightChildren, big = false }) {
  return (
    <div className="tt-appbar">
      {leftIcon && (
        <button className="icon-btn"><Icon name={leftIcon} size={18} color="var(--tt-text)"/></button>
      )}
      <div style={{flex:1, minWidth:0}}>
        {big ? (
          <>
            <h1>{title}</h1>
            {sub && <div className="sub">{sub}</div>}
          </>
        ) : (
          <>
            <div style={{display:'flex', alignItems:'center', gap:9}}>
              <TTLogo size={18}/>
              <span style={{font:'800 13px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            {sub && <div className="sub" style={{marginTop:3}}>{sub}</div>}
          </>
        )}
      </div>
      {rightChildren}
    </div>
  );
}

function BottomNav({ active = 'map' }) {
  // Matches the real app shell: 6 tabs
  const items = [
    { id:'home',      label:'Home',      icon:'home' },
    { id:'map',       label:'Map',       icon:'map' },
    { id:'tools',     label:'Tools',     icon:'compass' },
    { id:'community', label:'Community', icon:'message' },
    { id:'teams',     label:'Teams',     icon:'people' },
    { id:'profile',   label:'Profile',   icon:'user' },
  ];
  return (
    <div className="tt-bottomnav" style={{gridTemplateColumns: `repeat(${items.length}, 1fr)`}}>
      {items.map(i => (
        <div key={i.id} className={`item ${i.id === active ? 'active' : ''}`}>
          <Icon name={i.icon} size={19} color={i.id === active ? 'var(--tt-ember)' : 'currentColor'}/>
          <span style={{fontSize:8.5}}>{i.label}</span>
          <div className="pip"/>
        </div>
      ))}
      <div className="gesture"/>
    </div>
  );
}

// Battery row used in team list
function BattRow({ pct = 64 }) {
  const color = pct > 50 ? 'var(--tt-green)' : pct > 25 ? 'var(--tt-amber)' : 'var(--tt-red)';
  return (
    <span style={{display:'inline-flex', alignItems:'center', gap:4}}>
      <span style={{width:20, height:9, border:'1px solid var(--tt-text-3)', borderRadius:2, padding:1.2, position:'relative'}}>
        <span style={{display:'block', height:'100%', width:`${pct}%`, background:color, borderRadius:0.5}}/>
        <span style={{position:'absolute', right:-2.2, top:1.5, bottom:1.5, width:1.2, background:'var(--tt-text-3)'}}/>
      </span>
      <span className="num" style={{fontSize:10, color:'var(--tt-text-2)', fontWeight:600}}>{pct}</span>
    </span>
  );
}

// Topographic backdrop (subtle vector contours that loop on a screen)
function TopoBackdrop({ opacity = 0.7 }) {
  return <div className="topo-overlay" style={{opacity}}/>;
}

// --- Global app state (weather + other context shared across screens) ----
//
// In a real Trailtether build this would be hydrated from the forecast API
// — when the latest Drakensberg forecast contains snow above 1,800m, we
// flip TT_STATE.snow to true and the Home hero switches to the snow image
// as a little easter egg. Here we expose `setTT` + `useTT` so the Tweaks
// panel (or any other code) can toggle it live.
const TT_STATE = window.TT_STATE || (window.TT_STATE = { snow: false });
const TT_LISTENERS = window.TT_LISTENERS || (window.TT_LISTENERS = new Set());
function setTT(key, val) {
  TT_STATE[key] = val;
  TT_LISTENERS.forEach(fn => fn());
}
function useTT() {
  const [, force] = React.useState(0);
  React.useEffect(() => {
    const fn = () => force((n) => n + 1);
    TT_LISTENERS.add(fn);
    return () => { TT_LISTENERS.delete(fn); };
  }, []);
  return [TT_STATE, setTT];
}

// Stagger helper — wraps children with sequential animation delays
function Stagger({ delay = 60, base = 100, anim = 'anim-up', children }) {
  return React.Children.map(children, (ch, i) => {
    if (!ch) return null;
    const totalDelay = base + i * delay;
    return React.cloneElement(ch, {
      className: [ch.props.className, anim].filter(Boolean).join(' '),
      style: { ...(ch.props.style || {}), animationDelay: `${totalDelay}ms` },
    });
  });
}

Object.assign(window, {
  TTLogo, StatusBar, Signal, WifiIcon, BattGlyph2, Icon, PhoneAppBar, BottomNav,
  BattRow, TopoBackdrop, Stagger,
  setTT, useTT, TT_STATE,
});

// Trailtether — PC app shared chrome
// Dark graphite window with traffic lights, persistent sidebar, top bar.

/* ============================================================
   Window frame
   ============================================================ */
function PCWindow({ children }) {
  return (
    <div style={{
      width: 1440, height: 900,
      background: '#06080b',
      borderRadius: 14,
      boxShadow: '0 40px 120px -20px rgba(0,0,0,0.75), 0 0 0 1px rgba(255,255,255,0.06)',
      overflow: 'hidden',
      position: 'relative',
      display: 'flex', flexDirection: 'column',
      fontFamily: 'Manrope, -apple-system, BlinkMacSystemFont, system-ui, sans-serif',
      color: '#eef1f4',
    }}>
      {children}
    </div>
  );
}

/* ============================================================
   Title bar — traffic lights + window title + global search
   ============================================================ */
function PCTitleBar({ title = 'Trailtether · Base Camp' }) {
  return (
    <div style={{
      height: 44, flex: '0 0 auto',
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '0 14px',
      background: 'linear-gradient(180deg, #131820 0%, #0b0e12 100%)',
      borderBottom: '1px solid rgba(255,255,255,0.05)',
      position: 'relative',
    }}>
      <PCTrafficLights/>
      <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
        <span style={{ font: '600 12.5px var(--tt-font)', color: 'var(--tt-text-2)', letterSpacing: '0.04em' }}>{title}</span>
      </div>
      <div style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        padding: '5px 12px 5px 9px', borderRadius: 7,
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid var(--tt-line-2)',
        color: 'var(--tt-text-3)',
        font: '600 12px var(--tt-font)',
        minWidth: 220,
        cursor: 'text',
      }}>
        <Icon name="search" size={13} color="var(--tt-text-3)"/>
        <span style={{ flex: 1 }}>Search trails, hikers, plans…</span>
        <span style={{ font: '700 9.5px var(--tt-mono)', color: 'var(--tt-text-4)',
          padding: '2px 5px', borderRadius: 3, background: 'rgba(255,255,255,0.04)',
          border: '1px solid var(--tt-line)', letterSpacing: '0.06em' }}>⌘K</span>
      </div>
    </div>
  );
}

function PCTrafficLights() {
  const dot = (bg) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%', background: bg,
      border: '0.5px solid rgba(0,0,0,0.2)',
      boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.15)',
    }}/>
  );
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {dot('#ff5f56')}{dot('#ffbd2e')}{dot('#27c93f')}
    </div>
  );
}

/* ============================================================
   Layout — sidebar + main content area
   ============================================================ */
function PCLayout({ active, children }) {
  return (
    <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>
      <PCSidebar active={active}/>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0,
        background: 'var(--tt-bg)' }}>
        {children}
      </div>
    </div>
  );
}

function PCSidebar({ active = 'dashboard' }) {
  const nav = [
    { id: 'dashboard', icon: 'home',     label: 'Mission Control' },
    { id: 'watch',     icon: 'eye',      label: 'Hike Watch', live: true, badge: 1 },
    { id: 'hikers',    icon: 'people',   label: 'Hikers',     badge: 3 },
    { id: 'history',   icon: 'history',  label: 'History' },
    { id: 'alerts',    icon: 'alert',    label: 'Alerts',     badge: 2 },
    { id: 'pair',      icon: 'tether',   label: 'Pair Device' },
    { id: 'settings',  icon: 'settings', label: 'Settings' },
  ];
  return (
    <div style={{
      width: 232, flex: '0 0 auto',
      background: 'linear-gradient(180deg, #0b0e12 0%, #07090c 100%)',
      borderRight: '1px solid rgba(255,255,255,0.05)',
      display: 'flex', flexDirection: 'column',
      padding: '18px 14px 14px',
    }}>
      {/* Brand */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 8px 18px' }}>
        <img src="assets/logo.png" alt="" width="22" height="22"
          style={{ filter: 'drop-shadow(0 0 6px rgba(255,106,44,0.35))' }}/>
        <div>
          <div style={{ font: '900 12.5px var(--tt-font)', letterSpacing: '0.16em' }}>
            TRAIL<span style={{ color: 'var(--tt-ember)' }}>TETHER</span>
          </div>
          <div style={{ font: '700 8.5px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.18em', marginTop: 1 }}>
            BASE CAMP · v2.0
          </div>
        </div>
      </div>

      {/* Nav */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
        {nav.map(n => <PCSidebarItem key={n.id} {...n} active={active === n.id}/>)}
      </div>

      {/* Footer — current account */}
      <div style={{
        marginTop: 14, padding: '10px 10px',
        background: 'var(--tt-surf)',
        border: '1px solid var(--tt-line)',
        borderRadius: 11,
        display: 'flex', alignItems: 'center', gap: 9,
      }}>
        <div style={{
          width: 32, height: 32, borderRadius: '50%',
          background: 'linear-gradient(135deg, #5aa1d6, #2d6a98)',
          display: 'grid', placeItems: 'center',
          color: '#fff', font: '800 12px var(--tt-font)',
          border: '2px solid #5aa1d6',
        }}>SL</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: '800 12px var(--tt-font)', color: 'var(--tt-text)' }}>Sarah L.</div>
          <div style={{ font: '700 9px var(--tt-mono)', color: 'var(--tt-green)', letterSpacing: '0.1em', marginTop: 2 }}>
            <span style={{ display: 'inline-block', width: 5, height: 5, borderRadius: '50%', background: 'var(--tt-green)', boxShadow: '0 0 4px var(--tt-green)', marginRight: 4, verticalAlign: 'middle' }}/>
            WATCHING · 2 HIKERS
          </div>
        </div>
        <Icon name="more" size={14} color="var(--tt-text-3)"/>
      </div>
    </div>
  );
}

function PCSidebarItem({ icon, label, active, live, badge }) {
  return (
    <div className="pressable" style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '9px 10px',
      borderRadius: 9,
      background: active ? 'var(--tt-ember-dim)' : 'transparent',
      border: active ? '1px solid rgba(255,106,44,0.32)' : '1px solid transparent',
      color: active ? 'var(--tt-ember)' : 'var(--tt-text-2)',
      cursor: 'pointer',
      transition: 'background 200ms ease, border-color 200ms ease, color 200ms ease',
      position: 'relative',
    }}>
      <Icon name={icon} size={15} color={active ? 'var(--tt-ember)' : 'var(--tt-text-2)'} />
      <span style={{ flex: 1, font: '700 12.5px var(--tt-font)', letterSpacing: '0.01em' }}>{label}</span>
      {live && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: 'var(--tt-ember)', boxShadow: '0 0 6px var(--tt-ember)',
          animation: 'pulse 1.4s infinite',
        }}/>
      )}
      {badge !== undefined && badge > 0 && (
        <span style={{
          minWidth: 18, height: 18, padding: '0 5px', borderRadius: 9,
          background: active ? 'var(--tt-ember)' : 'rgba(255,255,255,0.06)',
          color: active ? '#1a0d04' : 'var(--tt-text-2)',
          font: '800 10px var(--tt-mono)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        }}>{badge}</span>
      )}
    </div>
  );
}

/* ============================================================
   Page header — used at top of main content area
   ============================================================ */
function PCPageHeader({ eyebrow, title, sub, actions }) {
  return (
    <div style={{
      flex: '0 0 auto',
      padding: '20px 26px 18px',
      borderBottom: '1px solid var(--tt-line)',
      display: 'flex', alignItems: 'flex-end', gap: 18,
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        {eyebrow && (
          <div style={{ font: '700 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.2em', marginBottom: 4 }}>
            {eyebrow}
          </div>
        )}
        <h1 style={{ margin: 0, font: '900 26px var(--tt-font)', letterSpacing: '-0.018em', color: 'var(--tt-text)' }}>{title}</h1>
        {sub && <div style={{ font: '600 12px var(--tt-mono)', color: 'var(--tt-text-2)', marginTop: 5, letterSpacing: '0.04em' }}>{sub}</div>}
      </div>
      {actions}
    </div>
  );
}

/* ============================================================
   Primitives — buttons, cards, pills, stat tiles
   ============================================================ */
function PCBtn({ children, primary, danger, ghost, leftIcon, onClick, style, ...rest }) {
  let bg = 'rgba(255,255,255,0.04)';
  let color = 'var(--tt-text)';
  let border = '1px solid var(--tt-line-2)';
  let shadow = 'none';
  if (primary) {
    bg = 'linear-gradient(135deg, #ff8a4d, #ff6a2c)';
    color = '#1a0d04';
    border = 'none';
    shadow = 'var(--tt-shadow-ember)';
  } else if (danger) {
    bg = 'rgba(230,61,46,0.12)';
    color = 'var(--tt-red)';
    border = '1px solid rgba(230,61,46,0.36)';
  } else if (ghost) {
    bg = 'transparent';
    color = 'var(--tt-text-2)';
    border = '1px solid transparent';
  }
  return (
    <button className="pressable" onClick={onClick} style={{
      display: 'inline-flex', alignItems: 'center', gap: 7,
      padding: '8px 14px', height: 36, borderRadius: 9,
      background: bg, color, border,
      font: '800 11.5px var(--tt-font)', letterSpacing: '0.08em',
      cursor: 'pointer', boxShadow: shadow,
      whiteSpace: 'nowrap',
      ...(style || {}),
    }} {...rest}>
      {leftIcon && <Icon name={leftIcon} size={13} color={color === '#1a0d04' ? '#1a0d04' : 'currentColor'} strokeWidth={2.2}/>}
      {children}
    </button>
  );
}

function PCCard({ children, padding = 18, style = {}, ...rest }) {
  return (
    <div style={{
      background: 'var(--tt-surf)',
      border: '1px solid var(--tt-line)',
      borderRadius: 14,
      padding,
      ...style,
    }} {...rest}>{children}</div>
  );
}

function PCStat({ label, value, unit, sub, icon, ember, danger, large }) {
  const color = danger ? 'var(--tt-red)' : ember ? 'var(--tt-ember)' : 'var(--tt-text)';
  return (
    <PCCard padding={16}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        {icon && <Icon name={icon} size={12} color={danger ? 'var(--tt-red)' : ember ? 'var(--tt-ember)' : 'var(--tt-text-3)'}/>}
        <span style={{ font: '700 10px var(--tt-font)', letterSpacing: '0.18em', textTransform: 'uppercase', color: 'var(--tt-text-3)' }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 8 }}>
        <span className="num" style={{ font: `900 ${large ? 36 : 26}px var(--tt-mono)`, color, letterSpacing: '-0.025em' }}>{value}</span>
        {unit && <span className="num" style={{ fontSize: 12, color: 'var(--tt-text-2)', fontWeight: 600 }}>{unit}</span>}
      </div>
      {sub && <div style={{ font: '600 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 6, letterSpacing: '0.04em' }}>{sub}</div>}
    </PCCard>
  );
}

function PCPill({ children, color = 'var(--tt-text-2)', bg, border, live, ember, danger, success }) {
  let pillBg = bg || 'rgba(255,255,255,0.04)';
  let pillBd = border || 'var(--tt-line-2)';
  let pillColor = color;
  if (ember)   { pillBg = 'var(--tt-ember-dim)';        pillBd = 'rgba(255,106,44,0.36)'; pillColor = 'var(--tt-ember)'; }
  if (success) { pillBg = 'rgba(76,195,138,0.13)';     pillBd = 'rgba(76,195,138,0.36)'; pillColor = 'var(--tt-green)'; }
  if (danger)  { pillBg = 'rgba(230,61,46,0.13)';      pillBd = 'rgba(230,61,46,0.36)';  pillColor = 'var(--tt-red)'; }
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '3px 8px', height: 22, borderRadius: 5,
      background: pillBg, border: `1px solid ${pillBd}`,
      font: '800 9.5px var(--tt-mono)', letterSpacing: '0.14em',
      color: pillColor,
      verticalAlign: 'middle',
    }}>
      {live && (
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: pillColor, boxShadow: `0 0 6px ${pillColor}`,
          animation: 'pulse 1.4s infinite',
        }}/>
      )}
      {children}
    </span>
  );
}

/* ============================================================
   Hikers — list of paired hikers (used everywhere in the PC app)
   ============================================================ */
const PC_HIKERS = [
  { id:'john', name:'John Davies',    initials:'JD', color:'#ff6a2c', status:'active',  trail:'Mt. Marcy Summit', region:'Drakensberg N',
    km:8.4, elevM:1850, speed:2.8, battery:84, signal:'4G', lastPing:'2m ago', startedAt:'06:14', plannedReturn:'13:30',
    avatarSrc:null },
  { id:'mike', name:'Mike Kowalski',  initials:'MK', color:'#4cc38a', status:'active',  trail:'Mt. Marcy Summit', region:'Drakensberg N',
    km:8.1, elevM:1750, speed:2.7, battery:71, signal:'3G', lastPing:'1m ago', startedAt:'06:18', plannedReturn:'13:30' },
  { id:'emily',name:'Emily Reyes',    initials:'ER', color:'#f2a93b', status:'late',    trail:'Mt. Marcy Summit', region:'Drakensberg N',
    km:8.5, elevM:1820, speed:1.4, battery:48, signal:'2G', lastPing:'18m ago', startedAt:'06:09', plannedReturn:'13:30' },
  { id:'lana', name:'Lana Ngubane',   initials:'LN', color:'#5aa1d6', status:'idle',    trail:null, region:null,
    km:0,   elevM:null, speed:0,   battery:null, signal:'—', lastPing:null,    startedAt:null, plannedReturn:null },
  { id:'tom',  name:'Tom Forrester',  initials:'TF', color:'#98a1ac', status:'paired',  trail:null, region:null,
    km:0,   elevM:null, speed:0,   battery:null, signal:'—', lastPing:'yesterday', startedAt:null, plannedReturn:null },
];

const PC_ALERTS = [
  { id:1, urgent:true, kind:'late',     who:'Emily R.',  title:'Behind schedule', sub:'Off pace by 18 minutes · slowed at km 4.5 stream', time:'2m ago' },
  { id:2,              kind:'battery',  who:'Emily R.',  title:'Low battery',     sub:'48% · ETA to summit 1h 20m',                       time:'12m ago' },
  { id:3,              kind:'weather',  who:'All',       title:'Wind advisory',   sub:'Gusts 28 km/h on Cathedral spine 12:30–14:00',     time:'34m ago' },
];

/* ============================================================
   Topographic backdrop — for hero panels
   ============================================================ */
function PCTopoBack({ opacity = 0.5 }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, pointerEvents: 'none', opacity,
      backgroundImage: `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='800' height='600' viewBox='0 0 800 600'><g fill='none' stroke='%23ffffff' stroke-opacity='0.03' stroke-width='1'><path d='M0,400 Q200,360 400,380 T800,360'/><path d='M0,440 Q200,420 400,430 T800,420'/><path d='M0,480 Q200,470 400,480 T800,470'/><path d='M0,360 Q200,300 400,330 T800,310'/><path d='M0,320 Q200,260 400,290 T800,270'/><path d='M0,280 Q200,220 400,250 T800,230'/><path d='M0,240 Q200,180 400,210 T800,190'/><path d='M0,200 Q200,140 400,170 T800,150'/></g></svg>")`,
      backgroundSize: '800px 600px',
    }}/>
  );
}

window.PCWindow = PCWindow;
window.PCTitleBar = PCTitleBar;
window.PCLayout = PCLayout;
window.PCPageHeader = PCPageHeader;
window.PCBtn = PCBtn;
window.PCCard = PCCard;
window.PCStat = PCStat;
window.PCPill = PCPill;
window.PCTopoBack = PCTopoBack;
window.PC_HIKERS = PC_HIKERS;
window.PC_ALERTS = PC_ALERTS;

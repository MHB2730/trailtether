// Trailtether PC — Mission Control / Dashboard

function PCScreenDashboard() {
  return (
    <PCWindow>
      <PCTitleBar/>
      <PCLayout active="dashboard">
        <PCPageHeader
          eyebrow="OVERVIEW"
          title="Mission Control"
          sub={<><b style={{color:'var(--tt-ember)'}}>2 active hikes</b> · 3 hikers tethered · UPDATED 10:09:14</>}
          actions={
            <div style={{ display:'flex', gap:8 }}>
              <PCBtn ghost leftIcon="layers">LAYERS</PCBtn>
              <PCBtn leftIcon="bell">ALERTS · 2</PCBtn>
              <PCBtn primary leftIcon="play">START WATCHING</PCBtn>
            </div>
          }
        />

        <div style={{ flex:1, padding:'18px 26px 22px', overflow:'auto', display:'flex', flexDirection:'column', gap:18 }}>
          {/* Stat row */}
          <div style={{ display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:14 }}>
            <PCStat label="ACTIVE NOW"     value="2"    unit="hikers" ember icon="people" sub="John · Mike · (Emily flagged)"/>
            <PCStat label="OUT TODAY"      value="3"    unit="hikers"        icon="navigation" sub="Mt. Marcy · 1 group"/>
            <PCStat label="ON-ROUTE KM"    value="24.7" unit="km"           icon="route"      sub="Combined live distance"/>
            <PCStat label="AVG BATTERY"    value="68"   unit="%"             icon="alert"      sub="Mike low (48%) · low-watt mode"
              danger={false}/>
          </div>

          {/* Map + side rail */}
          <div style={{ display:'grid', gridTemplateColumns:'1fr 360px', gap:14, flex:1, minHeight:0 }}>
            <PCDashboardMap/>
            <div style={{ display:'flex', flexDirection:'column', gap:14, minHeight:0, overflow:'hidden' }}>
              <PCActiveHikersPanel/>
              <PCAlertsPanel/>
            </div>
          </div>

          {/* Bottom — activity feed */}
          <PCActivityFeed/>
        </div>
      </PCLayout>
    </PCWindow>
  );
}

/* ============================================================
   Live overview map — all hikers + trails + topography
   ============================================================ */
function PCDashboardMap() {
  return (
    <div style={{ position:'relative', background:'#0a1218', borderRadius:14,
      border:'1px solid var(--tt-line)', overflow:'hidden' }}>
      <svg viewBox="0 0 820 600" preserveAspectRatio="xMidYMid slice"
           style={{ position:'absolute', inset:0, width:'100%', height:'100%' }}>
        <defs>
          <radialGradient id="dmTerr" cx="50%" cy="48%" r="65%">
            <stop offset="0%"  stopColor="#1a2820" stopOpacity="0.9"/>
            <stop offset="55%" stopColor="#11181e" stopOpacity="0.7"/>
            <stop offset="100%" stopColor="#06090c" stopOpacity="0.4"/>
          </radialGradient>
          <filter id="dmGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3"/>
            <feMerge><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
        </defs>
        <rect width="820" height="600" fill="url(#dmTerr)"/>

        {/* Contour lines — coarse */}
        <g fill="none" stroke="#1a2820" strokeWidth="0.7" opacity="0.7">
          {[
            'M-20,560 Q200,540 410,535 T860,548',
            'M-20,510 Q200,470 410,480 T860,500',
            'M-20,460 Q200,410 420,420 T860,450',
            'M0,410 Q220,340 420,360 T860,400',
            'M20,360 Q230,280 430,300 T860,340',
            'M50,310 Q260,220 440,250 T860,290',
            'M100,260 Q280,170 440,200 T820,250',
            'M150,210 Q310,130 440,170 T800,210',
            'M200,170 Q330,90 440,130 T740,160',
            'M240,130 Q360,70 440,100 T660,120',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>
        <g fill="none" stroke="#2a4036" strokeWidth="0.45" opacity="0.55">
          {[
            'M-20,580 Q200,560 410,555 T860,570',
            'M-20,540 Q200,510 410,515 T860,530',
            'M-20,490 Q200,450 410,460 T860,485',
            'M-20,440 Q220,380 420,395 T860,430',
            'M20,390 Q230,310 430,335 T860,370',
            'M60,340 Q260,250 440,275 T830,320',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>

        {/* Lakes */}
        <ellipse cx="180" cy="500" rx="48" ry="18" fill="#152a3c" opacity="0.7"/>
        <ellipse cx="640" cy="380" rx="28" ry="11" fill="#152a3c" opacity="0.55"/>

        {/* Forest patches */}
        <g opacity="0.5">
          {[
            { x:110, y:430, r:32 },
            { x:280, y:560, r:38 },
            { x:540, y:520, r:34 },
            { x:720, y:480, r:24 },
          ].map((c,i) => <circle key={i} cx={c.x} cy={c.y} r={c.r} fill="#1a2a1f"/>)}
        </g>

        {/* Region labels */}
        <text x="300" y="540" fill="#3d454d" fontFamily="Manrope" fontSize="11" fontWeight="700"
              letterSpacing="0.32em" textAnchor="middle">NISQUALLY  VALLEY</text>
        <text x="220" y="340" fill="#3d454d" fontFamily="Manrope" fontSize="10" fontWeight="700"
              letterSpacing="0.22em" textAnchor="middle">PARADISE  RIDGE</text>

        {/* Trail routes */}
        {/* Mt. Marcy (the active one) */}
        <path d="M 80,520 Q 180,470 240,420 Q 320,360 380,300 Q 450,240 510,200 Q 580,160 640,130"
              fill="none" stroke="#ff6a2c" strokeOpacity="0.4"
              strokeWidth="7" strokeLinecap="round" filter="url(#dmGlow)"/>
        <path d="M 80,520 Q 180,470 240,420 Q 320,360 380,300 Q 450,240 510,200 Q 580,160 640,130"
              fill="none" stroke="#ff8a4d" strokeWidth="2.4" strokeLinecap="round"/>
        {/* Travelled trace — dashed */}
        <path d="M 80,520 Q 180,470 240,420 Q 320,360 380,300 Q 450,240 510,200 Q 580,160 640,130"
              fill="none" stroke="#fff" strokeOpacity="0.4" strokeWidth="1.4"
              strokeDasharray="2 7"/>
        {/* Off-route trail — dim */}
        <path d="M 220,560 Q 320,500 380,460 Q 460,400 540,360 Q 620,330 700,310"
              fill="none" stroke="#5a6470" strokeOpacity="0.45" strokeWidth="2"
              strokeLinecap="round" strokeDasharray="4 6"/>

        {/* Trail labels */}
        <g transform="translate(450,260)">
          <rect x="-58" y="-12" width="116" height="22" rx="4" fill="rgba(10,12,15,0.92)" stroke="rgba(255,138,77,0.4)" strokeWidth="0.7"/>
          <text x="0" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="10" fontWeight="800"
                letterSpacing="0.08em">MT. MARCY · 12.4 KM</text>
        </g>

        {/* Trailhead + summit pins */}
        <g transform="translate(80,520)">
          <rect x="-6" y="-6" width="12" height="12" transform="rotate(45)"
                fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1.5"/>
          <text x="14" y="3" fill="#ffd6b0" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.1em">START</text>
        </g>
        <g transform="translate(640,130)">
          <circle r="9" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="2"/>
          <path d="M 0 -4 L 4 3 L -4 3 Z" fill="#ff6a2c"/>
          <g transform="translate(0,-18)">
            <rect x="-46" y="-9" width="92" height="18" rx="3" fill="rgba(10,12,15,0.92)" stroke="#ff6a2c" strokeWidth="0.7"/>
            <text x="0" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="Manrope" fontSize="9.5" fontWeight="800"
                  letterSpacing="0.1em">SUMMIT · 1,685 m</text>
          </g>
        </g>

        {/* Hiker pins — John, Mike, Emily */}
        <PCHikerPin cx={380} cy={300} initial="J" color="#ff6a2c" name="John D."   meta="8.4 km · 1,850 m"/>
        <PCHikerPin cx={350} cy={330} initial="M" color="#4cc38a" name="Mike K."   meta="8.1 km · 1,750 m"/>
        <PCHikerPin cx={400} cy={280} initial="E" color="#f2a93b" name="Emily R."  meta="8.5 km · 1,820 m"  flagged/>

        {/* Wind advisory shading at upper ridge */}
        <g opacity="0.18">
          <path d="M 480,230 Q 540,200 600,210 Q 660,225 700,260 Q 660,300 600,290 Q 540,275 480,260 Z"
                fill="#5aa1d6"/>
          <text x="600" y="255" textAnchor="middle" fill="#5aa1d6" fontFamily="Manrope" fontSize="9.5" fontWeight="800"
                letterSpacing="0.18em">WIND ADVISORY · 12:30</text>
        </g>
      </svg>

      {/* Top-floating glass cards */}
      <div style={{ position:'absolute', top:14, left:14, display:'flex', alignItems:'center', gap:9 }}>
        <PCPill ember live>LIVE · 1Hz GPS</PCPill>
        <PCPill>3 PINNED HIKERS</PCPill>
        <PCPill>NISQUALLY · DRAKENSBERG N</PCPill>
      </div>

      {/* Right-side floating zoom + layers */}
      <div style={{ position:'absolute', right:14, top:60, display:'flex', flexDirection:'column', gap:6 }}>
        <PCMapBtnGroup>
          <PCMapBtn icon="plus"/>
          <PCMapBtn icon="minus"/>
        </PCMapBtnGroup>
        <PCMapBtn icon="crosshair" ember/>
        <PCMapBtn icon="layers"/>
      </div>

      {/* Bottom legend + scale */}
      <div style={{ position:'absolute', bottom:14, left:14, display:'flex', alignItems:'center', gap:12 }}>
        <PCMapLegendDot color="#ff8a4d" label="ACTIVE TRAIL"/>
        <PCMapLegendDot color="#5a6470" label="ALT ROUTE" dashed/>
        <PCMapLegendDot color="#5aa1d6" label="WIND ZONE"/>
      </div>
      <div style={{ position:'absolute', bottom:14, right:14,
        display:'inline-flex', alignItems:'center', gap:6,
        padding:'5px 10px', background:'rgba(10,12,15,0.78)',
        backdropFilter:'blur(8px)', border:'1px solid var(--tt-line-2)', borderRadius:6 }}>
        <div style={{ display:'flex' }}>
          <div style={{ width:24, height:4, background:'#eef1f4' }}/>
          <div style={{ width:24, height:4, background:'#0a0c0f', border:'1px solid #eef1f4' }}/>
        </div>
        <span className="num" style={{ fontSize:9.5, color:'var(--tt-text)', fontWeight:700, letterSpacing:'0.04em' }}>1 km</span>
      </div>
    </div>
  );
}

function PCHikerPin({ cx, cy, initial, color, name, meta, flagged }) {
  return (
    <g transform={`translate(${cx},${cy})`}>
      {/* Halo */}
      <circle r="24" fill={color} opacity="0.10">
        <animate attributeName="r" values="20;30;20" dur="3s" repeatCount="indefinite"/>
        <animate attributeName="opacity" values="0.15;0;0.15" dur="3s" repeatCount="indefinite"/>
      </circle>
      {flagged && (
        <circle r="38" fill="none" stroke="var(--tt-amber)" strokeWidth="1.5" strokeDasharray="3 3" opacity="0.65">
          <animate attributeName="r" values="30;42;30" dur="2.2s" repeatCount="indefinite"/>
          <animate attributeName="opacity" values="0.4;0.8;0.4" dur="2.2s" repeatCount="indefinite"/>
        </circle>
      )}
      <path d={`M 0 22 L -7 11 L 7 11 Z`} fill={color}/>
      <circle r="15" fill="#1a1d22" stroke={color} strokeWidth="2.6"/>
      <text y="4.5" textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="13" fontWeight="800">{initial}</text>
      {/* Name tag */}
      <g transform="translate(20,-8)">
        <rect x="0" y="-12" width="120" height="32" rx="5" fill="rgba(10,12,15,0.95)"
              stroke={flagged ? 'var(--tt-amber)' : 'rgba(255,255,255,0.15)'} strokeWidth="0.7"/>
        <text x="9" y="0" fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="800">{name}</text>
        <text x="9" y="13" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9" fontWeight="600" letterSpacing="0.04em">{meta}</text>
      </g>
    </g>
  );
}

function PCMapBtnGroup({ children }) {
  return (
    <div style={{
      display:'flex', flexDirection:'column',
      background:'rgba(13,17,22,0.78)', backdropFilter:'blur(10px)',
      border:'1px solid var(--tt-line-2)', borderRadius:8, overflow:'hidden',
    }}>
      {children}
    </div>
  );
}
function PCMapBtn({ icon, ember }) {
  return (
    <button className="pressable" style={{
      width:34, height:34, padding:0,
      background: ember ? 'var(--tt-ember-dim)' : 'transparent',
      border: ember ? '1px solid rgba(255,106,44,0.32)' : 'none',
      borderRadius: ember ? 8 : 0,
      display:'grid', placeItems:'center', cursor:'pointer',
      backdropFilter: ember ? 'blur(10px)' : 'none',
    }}>
      <Icon name={icon} size={14} color={ember ? 'var(--tt-ember)' : 'var(--tt-text-2)'}/>
    </button>
  );
}
function PCMapLegendDot({ color, label, dashed }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap:7,
      padding:'5px 10px',
      background:'rgba(10,12,15,0.78)', backdropFilter:'blur(8px)',
      border:'1px solid var(--tt-line-2)', borderRadius:6,
      font:'800 9px var(--tt-mono)', color:'var(--tt-text-2)', letterSpacing:'0.14em',
    }}>
      <span style={{
        width:14, height:2, background: dashed ? 'transparent' : color,
        borderRadius:1,
        ...(dashed ? { borderTop:`2px dashed ${color}` } : {}),
      }}/>
      {label}
    </div>
  );
}

/* ============================================================
   Active hikers panel (right rail)
   ============================================================ */
function PCActiveHikersPanel() {
  const active = PC_HIKERS.filter(h => h.status === 'active' || h.status === 'late');
  return (
    <PCCard padding={0} style={{ flex:1, minHeight:0, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'14px 16px 10px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <span style={{ font:'800 11px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-2)' }}>ACTIVE HIKERS</span>
        <PCPill live ember>{active.length} LIVE</PCPill>
      </div>
      <div style={{ flex:1, overflowY:'auto', display:'flex', flexDirection:'column', gap:6, padding:'0 10px 12px' }}>
        {active.map(h => (
          <div key={h.id} className="pressable" style={{
            display:'flex', alignItems:'center', gap:10,
            padding:'10px 10px',
            background:'rgba(255,255,255,0.02)',
            border: h.status === 'late' ? '1px solid rgba(242,169,59,0.4)' : '1px solid var(--tt-line)',
            borderLeft: h.status === 'late' ? '3px solid var(--tt-amber)' : '3px solid var(--tt-ember)',
            borderRadius:9,
            cursor:'pointer',
          }}>
            <div style={{
              width:34, height:34, borderRadius:'50%',
              background:`linear-gradient(135deg, ${h.color}, ${h.color}aa)`,
              display:'grid', placeItems:'center',
              color:'#fff', font:'800 12px var(--tt-font)',
              border:`1.5px solid ${h.color}`,
              flex:'0 0 auto',
            }}>{h.initials}</div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ display:'flex', gap:6, alignItems:'center' }}>
                <span style={{ font:'800 12.5px var(--tt-font)', color:'var(--tt-text)' }}>{h.name.split(' ')[0]} {h.name.split(' ')[1][0]}.</span>
                {h.status === 'late' && <Icon name="alert" size={11} color="var(--tt-amber)"/>}
              </div>
              <div style={{ display:'flex', gap:8, marginTop:2, font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.06em' }}>
                <span>{h.km} km</span>
                <span style={{color:'var(--tt-line-3)'}}>·</span>
                <span style={{color:'var(--tt-ember)'}}>{h.elevM}m</span>
                <span style={{color:'var(--tt-line-3)'}}>·</span>
                <span>{h.lastPing}</span>
              </div>
            </div>
            <PCMiniBattery pct={h.battery}/>
          </div>
        ))}
      </div>
    </PCCard>
  );
}

function PCMiniBattery({ pct }) {
  const c = pct > 50 ? 'var(--tt-green)' : pct > 25 ? 'var(--tt-amber)' : 'var(--tt-red)';
  return (
    <div style={{ display:'flex', flexDirection:'column', alignItems:'center', gap:3, flex:'0 0 auto' }}>
      <div style={{ width:24, height:11, border:'1px solid var(--tt-text-3)', borderRadius:2, padding:1.2, position:'relative' }}>
        <div style={{ height:'100%', width:`${pct}%`, background:c, borderRadius:1 }}/>
        <span style={{ position:'absolute', right:-2.4, top:1.8, bottom:1.8, width:1.4, background:'var(--tt-text-3)' }}/>
      </div>
      <span className="num" style={{ fontSize:9, color:c, fontWeight:800, letterSpacing:'0.04em' }}>{pct}%</span>
    </div>
  );
}

/* ============================================================
   Alerts panel (right rail bottom)
   ============================================================ */
function PCAlertsPanel() {
  return (
    <PCCard padding={0} style={{ flex:'0 0 auto' }}>
      <div style={{ padding:'14px 16px 10px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <span style={{ font:'800 11px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-2)' }}>ALERTS</span>
        <span style={{ font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em' }}>VIEW ALL →</span>
      </div>
      <div style={{ display:'flex', flexDirection:'column', gap:5, padding:'0 10px 12px' }}>
        {PC_ALERTS.map(a => {
          const c = a.urgent ? 'var(--tt-red)' : a.kind === 'battery' ? 'var(--tt-amber)' : 'var(--tt-blue)';
          const iconName = a.kind === 'late' ? 'clock' : a.kind === 'battery' ? 'alert' : 'wind';
          return (
            <div key={a.id} className="pressable" style={{
              display:'flex', gap:10, alignItems:'flex-start',
              padding:'10px 10px',
              background:'rgba(255,255,255,0.02)',
              border:`1px solid ${c}44`,
              borderLeft:`3px solid ${c}`,
              borderRadius:8, cursor:'pointer',
            }}>
              <div style={{
                width:26, height:26, borderRadius:7,
                background:`${c}1f`, border:`1px solid ${c}55`,
                display:'grid', placeItems:'center', flex:'0 0 auto',
              }}>
                <Icon name={iconName} size={12} color={c}/>
              </div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ font:'800 11.5px var(--tt-font)', color:'var(--tt-text)' }}>{a.title}</div>
                <div style={{ font:'500 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em' }}>{a.who} · {a.sub}</div>
              </div>
              <span style={{ font:'700 9px var(--tt-mono)', color:'var(--tt-text-3)', whiteSpace:'nowrap' }}>{a.time}</span>
            </div>
          );
        })}
      </div>
    </PCCard>
  );
}

/* ============================================================
   Activity timeline / ribbon
   ============================================================ */
function PCActivityFeed() {
  const events = [
    { t:'10:09', who:'John D.', kind:'ping',     text:'Position update · km 8.4 · elev 1,850m', color:'var(--tt-ember)' },
    { t:'10:08', who:'Mike K.', kind:'milestone',text:'Reached Sunrise Camp · Cave #47', color:'var(--tt-green)' },
    { t:'10:02', who:'Emily R.',kind:'pace',     text:'Pace dropped to 1.4 km/hr', color:'var(--tt-amber)' },
    { t:'09:54', who:'System',  kind:'weather',  text:'Wind advisory issued · 12:30 onwards', color:'var(--tt-blue)' },
    { t:'09:42', who:'John D.', kind:'message',  text:'"At Shadow Lake. Going to push for Liberty Cap by 11."', color:'var(--tt-ember)' },
    { t:'06:18', who:'Mike K.', kind:'start',    text:'Started hike · Mt. Marcy Summit', color:'var(--tt-green)' },
    { t:'06:14', who:'John D.', kind:'start',    text:'Started hike · Mt. Marcy Summit', color:'var(--tt-ember)' },
  ];
  return (
    <PCCard padding={0}>
      <div style={{ padding:'14px 18px 6px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <div style={{ display:'flex', alignItems:'center', gap:9 }}>
          <span style={{ font:'800 11px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-2)' }}>ACTIVITY · LAST 4 HOURS</span>
          <PCPill live ember>STREAMING</PCPill>
        </div>
        <div style={{ display:'flex', alignItems:'center', gap:8 }}>
          <PCBtn ghost leftIcon="filter">FILTER</PCBtn>
          <PCBtn ghost leftIcon="arrow-up-right">EXPORT</PCBtn>
        </div>
      </div>
      <div style={{ padding:'2px 18px 16px' }}>
        <div style={{ position:'relative', paddingLeft:18 }}>
          {/* timeline rail */}
          <div style={{ position:'absolute', left:5, top:8, bottom:8, width:2, background:'var(--tt-line)' }}/>
          {events.map((e, i) => (
            <div key={i} style={{ position:'relative', padding:'7px 0', display:'flex', alignItems:'center', gap:14 }}>
              <span style={{ position:'absolute', left:-17, top:'50%', transform:'translateY(-50%)',
                width:8, height:8, borderRadius:'50%', background:e.color,
                boxShadow:`0 0 6px ${e.color}`, border:'2px solid var(--tt-surf)' }}/>
              <span className="num" style={{ font:'800 11px var(--tt-mono)', color:'var(--tt-text-2)',
                letterSpacing:'0.04em', minWidth:42 }}>{e.t}</span>
              <span style={{ font:'800 11.5px var(--tt-font)', color: e.color, minWidth:78 }}>{e.who}</span>
              <span style={{ flex:1, font:'500 11.5px var(--tt-font)', color:'var(--tt-text-2)' }}>{e.text}</span>
            </div>
          ))}
        </div>
      </div>
    </PCCard>
  );
}

window.PCScreenDashboard = PCScreenDashboard;

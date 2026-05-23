// Trailtether — Maps / Trail screen

function ScreenMaps() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar
          time="10:09"
          right={
            <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-ember)', fontSize:10.5, fontWeight:700, letterSpacing:'0.1em', marginRight:4}}>
              <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-ember)', boxShadow:'0 0 6px var(--tt-ember)', animation:'pulse 1.6s infinite'}}/>
              GPS
            </span>
          }
        />

        {/* Big page header */}
        <div className="tt-appbar anim-in" style={{paddingBottom:12, animationDelay:'80ms'}}>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', alignItems:'center', gap:9, marginBottom:4}}>
              <TTLogo size={18}/>
              <span style={{font:'800 12px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <h1 style={{margin:0, font:'800 24px var(--tt-font)', letterSpacing:'-0.02em'}}>Peak Tracker</h1>
          </div>
          <button className="icon-btn"><Icon name="search" size={16} color="var(--tt-text-2)"/></button>
          <button className="icon-btn"><Icon name="menu" size={16} color="var(--tt-text-2)"/></button>
        </div>

        <div className="tt-body">
          <MapView/>
          <RecordingPanel/>
        </div>

        <BottomNav active="map"/>
      </div>
    </div>
  );
}

function MapView() {
  // route path coords + computed length for animation
  const routeD = "M 70 410 Q 50 350 80 290 Q 120 240 170 230 Q 230 230 270 200 Q 320 170 340 130 L 340 100";
  return (
    <div style={{position:'relative', flex:1, minHeight:0, overflow:'hidden', background:'#0a0c0f'}}>
      {/* Topographic map */}
      <svg viewBox="0 0 412 460" preserveAspectRatio="xMidYMid slice"
           style={{position:'absolute', inset:0, width:'100%', height:'100%', display:'block'}}>
        <defs>
          <radialGradient id="terrPhone" cx="50%" cy="40%" r="70%">
            <stop offset="0%"  stopColor="#1d242c" stopOpacity="0.8"/>
            <stop offset="55%" stopColor="#11161c" stopOpacity="0.6"/>
            <stop offset="100%" stopColor="#06080b" stopOpacity="0"/>
          </radialGradient>
          <filter id="routeGlowP" x="-30%" y="-30%" width="160%" height="160%">
            <feGaussianBlur stdDeviation="3.2" result="blur"/>
            <feMerge>
              <feMergeNode in="blur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>
        <rect width="412" height="460" fill="#06080b"/>
        <rect width="412" height="460" fill="url(#terrPhone)"/>

        {/* Contour lines — multiple layered tones */}
        <g fill="none" stroke="#2a3038" strokeWidth="0.5" opacity="0.55">
          {[
            'M-20,400 Q100,380 200,380 T440,390',
            'M-20,360 Q100,330 200,335 T440,355',
            'M-20,320 Q100,260 220,270 T440,310',
            'M0,280 Q120,200 230,215 T440,260',
            'M30,240 Q140,160 240,175 T420,220',
            'M60,210 Q160,130 250,145 T400,200',
            'M90,180 Q190,110 250,130 T380,180',
            'M120,160 Q200,110 250,120 T360,150',
            'M150,140 Q210,110 250,115 T340,135',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>
        <g fill="none" stroke="#1c2127" strokeWidth="0.4" opacity="0.65">
          {[
            'M-20,420 Q100,400 200,398 T440,410',
            'M-20,380 Q100,360 200,358 T440,370',
            'M-20,340 Q100,300 200,305 T440,330',
            'M-20,300 Q120,230 220,245 T440,285',
            'M20,260 Q140,180 240,195 T430,240',
            'M50,225 Q150,150 250,165 T410,210',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>

        {/* Labels */}
        <text x="200" y="350" fill="#3d454d" fontFamily="Manrope" fontSize="9" fontWeight="700"
              letterSpacing="0.22em" textAnchor="middle">NISQUALLY  VALLEY</text>
        <text x="80" y="200" fill="#3d454d" fontFamily="Manrope" fontSize="8" fontWeight="700"
              letterSpacing="0.18em" textAnchor="middle">PARADISE  RIDGE</text>

        {/* Lakes (subtle) */}
        <ellipse cx="48"  cy="380" rx="22" ry="8" fill="#162a3c" opacity="0.7"/>
        <ellipse cx="360" cy="280" rx="14" ry="6" fill="#162a3c" opacity="0.55"/>

        {/* Route shadow */}
        <path d={routeD} fill="none" stroke="#000" strokeWidth="9" opacity="0.55"/>

        {/* Animated route — outer glow */}
        <path d={routeD} fill="none" stroke="#ff6a2c" strokeOpacity="0.4"
              strokeWidth="6" strokeLinecap="round" filter="url(#routeGlowP)"
              className="draw-line" style={{['--len']: 600}}/>
        {/* Animated route — sharp top stroke */}
        <path d={routeD} fill="none" stroke="#ff8a4d"
              strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"
              className="draw-line" style={{['--len']: 600, animationDelay:'80ms'}}/>

        {/* Animated travelled dot trace (uses dasharray to give a ticking effect) */}
        <path d={routeD} fill="none" stroke="#fff" strokeOpacity="0.45"
              strokeWidth="1.2" strokeDasharray="2 7"
              className="draw-line" style={{['--len']: 600, animationDelay:'200ms'}}/>

        {/* You marker */}
        <g transform="translate(170,230)" className="anim-pop" style={{animationDelay:'1400ms', transformOrigin:'170px 230px'}}>
          <circle r="26" fill="#ff6a2c" opacity="0.10"/>
          <circle r="16" fill="#ff6a2c" opacity="0.22"/>
          <circle r="10" fill="#fff" stroke="#ff6a2c" strokeWidth="3"/>
          <path d="M 0 -3 L 4 5 L 0 3 L -4 5 Z" fill="#ff6a2c"/>
        </g>

        {/* Summit marker */}
        <g transform="translate(340,100)" className="anim-pop" style={{animationDelay:'1600ms', transformOrigin:'340px 100px'}}>
          <circle r="8" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="2"/>
          <path d="M 0 -3 L -3 2 L 3 2 Z" fill="#ff6a2c"/>
          <g transform="translate(0,-18)">
            <rect x="-50" y="-10" width="100" height="20" rx="4" fill="rgba(10,12,15,0.92)" stroke="#ff6a2c" strokeWidth="1"/>
            <text x="0" y="4" textAnchor="middle" fill="#ff8a4d" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.08em">SUMMIT · 4,392 m</text>
          </g>
        </g>

        {/* Start marker */}
        <g transform="translate(70,410)" className="anim-pop" style={{animationDelay:'1700ms', transformOrigin:'70px 410px'}}>
          <rect x="-6" y="-6" width="12" height="12" transform="rotate(45)" fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1.5"/>
          <g transform="translate(28,0)">
            <rect x="-18" y="-9" width="46" height="18" rx="4" fill="rgba(10,12,15,0.92)" stroke="rgba(255,255,255,0.15)" strokeWidth="0.5"/>
            <text x="5" y="3" textAnchor="middle" fill="#eef1f4" fontFamily="Manrope" fontSize="9.5" fontWeight="700" letterSpacing="0.1em">START</text>
          </g>
        </g>

        {/* KM markers */}
        {[
          {x:80, y:320, label:'5 km',  delay: 1100},
          {x:225, y:230, label:'10 km', delay: 1300},
          {x:325, y:155, label:'15 km', delay: 1500},
        ].map((m,i) => (
          <g key={i} className="anim-in" style={{animationDelay:`${m.delay}ms`}}>
            <rect x={m.x-18} y={m.y-9} width="36" height="15" rx="3.5" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="0.8"/>
            <text x={m.x} y={m.y+2} textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="9.5" fontWeight="700">{m.label}</text>
          </g>
        ))}
      </svg>

      {/* Top-floating glass stat cards (à la Peak Tracker) */}
      <div style={{
        position:'absolute', top:12, left:14, right:14,
        display:'grid', gridTemplateColumns:'1fr 1fr', gap:10,
      }}>
        <FloatingStat icon="navigation" label="Distance" value="4.8" unit="km" sublabel="Completed" delay={120}/>
        <FloatingStat icon="clock"      label="Time"     value="2h 15m"      sublabel="Duration"   delay={220}/>
      </div>

      {/* Right-side floating controls */}
      <div style={{
        position:'absolute', right:14, top:152,
        display:'flex', flexDirection:'column', gap:8,
      }}>
        <MapZoomGroup/>
        <MapCircleBtn icon="crosshair" emberAccent delay={520}/>
        <MapCircleBtn icon="layers"    delay={580}/>
      </div>

      {/* Scale + heading */}
      <div className="anim-up" style={{
        position:'absolute', bottom:14, left:14,
        display:'inline-flex', alignItems:'center', gap:6,
        background:'rgba(10,12,15,0.78)', backdropFilter:'blur(8px)',
        border:'1px solid var(--tt-line-2)', borderRadius:6,
        padding:'5px 9px',
        animationDelay:'900ms',
      }}>
        <div style={{display:'flex'}}>
          <div style={{width:22, height:4, background:'#eef1f4'}}/>
          <div style={{width:22, height:4, background:'#0a0c0f', border:'1px solid #eef1f4'}}/>
        </div>
        <span className="num" style={{fontSize:9.5, color:'var(--tt-text)', fontWeight:600}}>500 m</span>
      </div>
    </div>
  );
}

function FloatingStat({ icon, label, value, unit, sublabel, delay = 100 }) {
  return (
    <div className="glass anim-up" style={{
      padding:'10px 12px',
      animationDelay:`${delay}ms`,
    }}>
      <div style={{display:'flex', alignItems:'center', gap:8}}>
        <div style={{
          width:28, height:28, borderRadius:8,
          background:'rgba(255,106,44,0.10)',
          border:'1px solid rgba(255,106,44,0.25)',
          display:'grid', placeItems:'center', flex:'0 0 auto',
        }}>
          <Icon name={icon} size={14} color="var(--tt-ember)"/>
        </div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{font:'600 10px var(--tt-font)', color:'var(--tt-text-3)', letterSpacing:'0.04em'}}>{label}</div>
          <div style={{display:'flex', alignItems:'baseline', gap:3, marginTop:1}}>
            <span className="num count-up" style={{font:'800 17px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.02em', animationDelay:`${delay+200}ms`}}>{value}</span>
            {unit && <span className="num" style={{fontSize:10, color:'var(--tt-text-2)', fontWeight:600}}>{unit}</span>}
          </div>
          {sublabel && <div style={{font:'500 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:1, letterSpacing:'0.02em'}}>{sublabel}</div>}
        </div>
      </div>
    </div>
  );
}

function MapZoomGroup() {
  return (
    <div className="glass anim-pop" style={{
      display:'flex', flexDirection:'column', padding:0, overflow:'hidden',
      animationDelay:'420ms',
    }}>
      <button className="pressable" style={mapBtnStyle}><Icon name="plus" size={16} color="var(--tt-text)"/></button>
      <div style={{height:1, background:'var(--tt-line-2)'}}/>
      <button className="pressable" style={mapBtnStyle}><Icon name="minus" size={16} color="var(--tt-text)"/></button>
    </div>
  );
}

function MapCircleBtn({ icon, emberAccent, delay = 300 }) {
  return (
    <button className="glass pressable anim-pop"
      style={{
        width:38, height:38, padding:0, display:'grid', placeItems:'center', border:'1px solid var(--tt-line-2)',
        animationDelay:`${delay}ms`,
      }}>
      <Icon name={icon} size={16} color={emberAccent ? 'var(--tt-ember)' : 'var(--tt-text-2)'}/>
    </button>
  );
}

const mapBtnStyle = {
  width:38, height:38, background:'transparent', border:'none', cursor:'pointer',
  display:'grid', placeItems:'center',
};

function RecordingPanel() {
  return (
    <div className="anim-up" style={{
      flex:'0 0 auto',
      background:'linear-gradient(180deg, rgba(15,19,24,0) 0%, rgba(11,14,18,0.95) 30%, var(--tt-bg-2) 100%)',
      padding:'12px 16px 18px',
      borderTop:'1px solid var(--tt-line)',
      position:'relative',
      animationDelay:'700ms',
    }}>
      <div style={{
        width:42, height:4, borderRadius:2,
        background:'var(--tt-line-3)', margin:'-4px auto 12px',
      }}/>

      <div style={{display:'flex', alignItems:'center', gap:12, marginBottom:6}}>
        <div style={{flex:1, minWidth:0}}>
          <div style={{font:'800 16px var(--tt-font)', color:'var(--tt-text)', letterSpacing:'-0.01em'}}>Mt. Elbert Summit Trail</div>
          <div style={{display:'flex', alignItems:'center', gap:6, marginTop:4, font:'500 11px var(--tt-mono)', color:'var(--tt-text-3)'}}>
            <span>Status:</span>
            <span style={{color:'var(--tt-ember)', fontWeight:700, display:'inline-flex', alignItems:'center', gap:5}}>
              <span style={{width:6, height:6, borderRadius:'50%', background:'var(--tt-ember)', boxShadow:'0 0 6px var(--tt-ember)', animation:'pulse 1.4s infinite'}}/>
              In Progress
            </span>
          </div>
        </div>
        <button className="pressable" style={{
          height:42, padding:'0 18px', borderRadius:11,
          background:'var(--tt-ember)', border:'none', color:'#1a0d04',
          font:'800 12px var(--tt-font)', letterSpacing:'0.12em',
          cursor:'pointer',
          boxShadow:'var(--tt-shadow-ember)',
          display:'inline-flex', alignItems:'center', gap:6,
        }}>
          <Icon name="pause" size={12} color="#1a0d04"/>
          PAUSE
        </button>
        <button className="pressable" style={{
          height:42, padding:'0 14px', borderRadius:11,
          background:'transparent',
          border:'1px solid var(--tt-line-3)',
          color:'var(--tt-text-2)',
          font:'800 12px var(--tt-font)', letterSpacing:'0.12em',
          cursor:'pointer',
        }}>STOP</button>
      </div>

      {/* Stat row */}
      <div style={{
        display:'grid', gridTemplateColumns:'1fr 1fr 1fr',
        gap:1, marginTop:14,
        background:'var(--tt-surf)',
        border:'1px solid var(--tt-line)',
        borderRadius:12,
        overflow:'hidden',
      }}>
        <MiniStat label="Elev"  value="3,950" unit="m"     ember/>
        <MiniStat label="Pace"  value="3.2"   unit="km/h"  />
        <MiniStat label="Time"  value="02:34" unit=":56"   />
      </div>

      {/* Mini elevation profile */}
      <div className="card" style={{marginTop:12, padding:'12px 14px'}}>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:8}}>
          <span style={{font:'700 10.5px var(--tt-font)', letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Elevation Profile</span>
          <span className="num" style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)'}}>0 → 17.5 km</span>
        </div>
        <MiniElevChart/>
      </div>
    </div>
  );
}

function MiniStat({ label, value, unit, ember }) {
  return (
    <div style={{padding:'10px 12px', background:'var(--tt-surf)'}}>
      <div style={{font:'700 9.5px var(--tt-font)', letterSpacing:'0.14em', textTransform:'uppercase', color:'var(--tt-text-3)'}}>{label}</div>
      <div style={{display:'flex', alignItems:'baseline', gap:3, marginTop:5}}>
        <span className="num count-up" style={{
          font:'800 19px var(--tt-mono)',
          color: ember ? 'var(--tt-ember)' : 'var(--tt-text)',
          letterSpacing:'-0.02em',
          animationDelay:'900ms',
        }}>{value}</span>
        {unit && <span className="num" style={{fontSize:10, color:'var(--tt-text-2)', fontWeight:600}}>{unit}</span>}
      </div>
    </div>
  );
}

function MiniElevChart() {
  const w = 348, h = 56, pad = 4;
  const pts = [1500, 1620, 1850, 2100, 2380, 2740, 3120, 3500, 3850, 4200, 4340, 4180, 3900, 3600, 3300, 3000];
  const min = 1400, max = 4500;
  const stepX = (w - pad*2) / (pts.length - 1);
  const top = pts.map((v,i) => `${i===0?'M':'L'}${pad + i*stepX},${h - pad - ((v - min)/(max-min)) * (h - pad*2)}`).join(' ');
  const fill = top + ` L ${w-pad},${h-pad} L ${pad},${h-pad} Z`;
  const peakIdx = pts.indexOf(Math.max(...pts));
  const peakX = pad + peakIdx * stepX;
  const peakY = h - pad - ((pts[peakIdx] - min) / (max - min)) * (h - pad*2);
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} style={{display:'block'}} preserveAspectRatio="none">
      <defs>
        <linearGradient id="miniElev" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%"   stopColor="#ff6a2c" stopOpacity="0.55"/>
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0"/>
        </linearGradient>
      </defs>
      <path d={fill} fill="url(#miniElev)" className="anim-in" style={{animationDelay:'1000ms'}}/>
      <path d={top} fill="none" stroke="#ff6a2c" strokeWidth="2"
            strokeLinejoin="round" strokeLinecap="round"
            className="draw-line" style={{['--len']: 380, animationDelay:'900ms'}}/>
      <line x1={peakX} y1={peakY} x2={peakX} y2={h-pad}
            stroke="rgba(255,255,255,0.3)" strokeDasharray="2 2"
            className="anim-in" style={{animationDelay:'1500ms'}}/>
      <circle cx={peakX} cy={peakY} r="3.5" fill="#fff" stroke="#ff6a2c" strokeWidth="2"
              className="anim-pop" style={{animationDelay:'1500ms', transformOrigin:`${peakX}px ${peakY}px`}}/>
    </svg>
  );
}

window.ScreenMaps = ScreenMaps;

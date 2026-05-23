// Trailtether — Plan Route screen (reached from Home → Plan Route)

function ScreenPlanRoute() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={
          <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-ember)', fontSize:10.5, fontWeight:700, letterSpacing:'0.1em', marginRight:4}}>
            <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-ember)', boxShadow:'0 0 6px var(--tt-ember)', animation:'pulse 1.6s infinite'}}/>
            PLANNING
          </span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>NEW PLAN</div>
            <h1 style={{margin:'2px 0 0', font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Plan Route</h1>
          </div>
          <button className="icon-btn"><Icon name="more" size={16} color="var(--tt-text-2)"/></button>
        </div>

        {/* Planning map */}
        <div style={{position:'relative', flex:'0 0 240px', overflow:'hidden', borderTop:'1px solid var(--tt-line)', borderBottom:'1px solid var(--tt-line)'}}>
          <PlanMap/>
          {/* Floating waypoint controls */}
          <div style={{position:'absolute', right:12, top:12, display:'flex', flexDirection:'column', gap:8}}>
            <button className="glass pressable" style={{width:38, height:38, padding:0, display:'grid', placeItems:'center', border:'1px solid var(--tt-line-2)'}}>
              <Icon name="plus" size={16} color="var(--tt-ember)"/>
            </button>
            <button className="glass pressable" style={{width:38, height:38, padding:0, display:'grid', placeItems:'center', border:'1px solid var(--tt-line-2)'}}>
              <Icon name="crosshair" size={16} color="var(--tt-text-2)"/>
            </button>
          </div>
        </div>

        <div className="tt-scroll" style={{padding:'14px 18px 24px'}}>
          {/* Waypoints */}
          <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10}}>
            <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Waypoints (4)</span>
            <span style={{font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em'}}>+ ADD STOP</span>
          </div>
          <div className="card" style={{padding:0, overflow:'hidden'}}>
            <Waypoint num="A" type="start" name="Cathedral Trailhead" sub="1,480 m · gate · parking" km="0.0"/>
            <Waypoint num="1" type="poi"   name="Stream Crossing"     sub="km 4.2 · use poles in rain"  km="4.2"/>
            <Waypoint num="2" type="shelter" name="Cave #47 · Sunrise" sub="km 5.8 · water · 6 sleepers" km="5.8"/>
            <Waypoint num="3" type="end" name="Mt. Marcy Summit"      sub="km 12.4 · 1,685 m" km="12.4" isLast/>
          </div>

          {/* Computed plan */}
          <div className="card anim-up" style={{padding:'14px 16px', marginTop:14, animationDelay:'250ms', position:'relative', overflow:'hidden'}}>
            <div style={{position:'absolute', top:-30, right:-30, width:140, height:140, borderRadius:'50%',
              background:'radial-gradient(circle, rgba(255,106,44,0.18), transparent 70%)', pointerEvents:'none'}}/>
            <span style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-3)'}}>COMPUTED · CATHEDRAL ROUTE</span>
            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:1, marginTop:10, background:'var(--tt-line)', borderRadius:10, overflow:'hidden'}}>
              <ComputedStat label="Distance" value="12.4" unit="km"/>
              <ComputedStat label="Ascent"   value="1,205" unit="m" ember/>
              <ComputedStat label="Estimate" value="5h 12m"/>
            </div>
            <div style={{marginTop:12, font:'500 11.5px/1.45 var(--tt-font)', color:'var(--tt-text-2)'}}>
              Difficult · Class 3 scramble at km 6.5. Best window: <b style={{color:'var(--tt-ember)'}}>06:00 start</b>, turn around by 13:00.
            </div>
          </div>

          {/* Plan info */}
          <div style={{marginTop:16}}>
            <FieldLabelPR>Plan name</FieldLabelPR>
            <FieldPR value="Cathedral Peak · solo · Saturday"/>
            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10, marginTop:14}}>
              <div>
                <FieldLabelPR>Date</FieldLabelPR>
                <FieldPR value="OCT 28, 2025" leading="●" leadingColor="var(--tt-ember)"/>
              </div>
              <div>
                <FieldLabelPR>Start time</FieldLabelPR>
                <FieldPR value="06:00" leading="◷" leadingColor="var(--tt-ember)"/>
              </div>
            </div>
            <div style={{marginTop:14}}>
              <FieldLabelPR>Tethered to</FieldLabelPR>
              <div className="pressable" style={{
                display:'flex', alignItems:'center', gap:12,
                padding:'12px 14px',
                background:'var(--tt-surf)', border:'1px solid rgba(76,195,138,0.32)', borderRadius:11,
              }}>
                <div style={{width:30, height:30, borderRadius:9, background:'rgba(76,195,138,0.13)',
                  border:'1px solid rgba(76,195,138,0.32)', display:'grid', placeItems:'center', flex:'0 0 auto'}}>
                  <Icon name="home" size={14} color="var(--tt-green)"/>
                </div>
                <div style={{flex:1, minWidth:0}}>
                  <div style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-text)'}}>Home · Sarah's PC</div>
                  <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>WILL BE ALERTED IF YOU'RE LATE</div>
                </div>
                <Icon name="chevron-right" size={14} color="var(--tt-text-3)"/>
              </div>
            </div>
          </div>

          {/* CTAs */}
          <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10, marginTop:22}}>
            <button className="pressable" style={{
              padding:'14px', borderRadius:12,
              background:'transparent', border:'1px solid var(--tt-line-3)',
              color:'var(--tt-text)', font:'800 11px var(--tt-font)', letterSpacing:'0.14em',
              cursor:'pointer',
            }}>SAVE DRAFT</button>
            <button className="pressable" style={{
              padding:'14px', borderRadius:12,
              background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)', border:'none',
              color:'#1a0d04', font:'900 11px var(--tt-font)', letterSpacing:'0.16em',
              cursor:'pointer', boxShadow:'var(--tt-shadow-ember)',
            }}>ARM TETHER →</button>
          </div>
        </div>

      </div>
    </div>
  );
}

function PlanMap() {
  return (
    <svg viewBox="0 0 412 240" preserveAspectRatio="xMidYMid slice"
         style={{position:'absolute', inset:0, width:'100%', height:'100%', background:'#0a1218'}}>
      <defs>
        <radialGradient id="pmTerr" cx="50%" cy="50%" r="65%">
          <stop offset="0%" stopColor="#1a2820" stopOpacity="0.9"/>
          <stop offset="100%" stopColor="#06090c" stopOpacity="0.4"/>
        </radialGradient>
      </defs>
      <rect width="412" height="240" fill="url(#pmTerr)"/>
      {/* Contours */}
      <g fill="none" stroke="#1a2820" strokeWidth="0.5" opacity="0.7">
        {['M-20,220 Q90,212 200,208 T440,216','M-20,190 Q100,170 220,180 T440,196','M0,160 Q120,134 230,148 T440,168','M40,128 Q140,98 240,116 T420,138','M90,98 Q170,70 240,86 T380,108','M130,68 Q200,46 250,62 T350,76'].map((d,i) => <path key={i} d={d}/>)}
      </g>
      {/* Trail (dashed = proposed) */}
      <path d="M 50 220 C 90 210 110 200 140 180 S 200 156 230 130 S 290 95 320 70 S 360 48 388 36"
            fill="none" stroke="#ff8a4d" strokeWidth="2.4" strokeLinecap="round"
            strokeDasharray="6 4" className="draw-line" style={{['--len']:500, animationDelay:'200ms'}}/>
      {/* Waypoints */}
      {[
        { x:50, y:220, l:'A', c:'#ff6a2c' },
        { x:160,y:172, l:'1', c:'#5aa1d6' },
        { x:240,y:124, l:'2', c:'#4cc38a' },
        { x:388,y:36,  l:'3', c:'#ff6a2c' },
      ].map((w, i) => (
        <g key={i} className="anim-pop" style={{animationDelay:`${500 + i*120}ms`, transformOrigin:`${w.x}px ${w.y}px`}}>
          <circle cx={w.x} cy={w.y} r="11" fill="#0a0c0f" stroke={w.c} strokeWidth="2"/>
          <text x={w.x} y={w.y+3.5} textAnchor="middle" fill={w.c} fontFamily="Manrope" fontSize="10" fontWeight="900">{w.l}</text>
        </g>
      ))}
    </svg>
  );
}

function Waypoint({ num, type, name, sub, km, isLast }) {
  const color = type === 'start' ? '#ff6a2c'
              : type === 'end' ? '#ff6a2c'
              : type === 'shelter' ? '#4cc38a'
              : '#5aa1d6';
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'12px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
      cursor:'grab',
      position:'relative',
    }}>
      <div style={{
        width:30, height:30, borderRadius:'50%',
        background:`${color}1f`, border:`2px solid ${color}`,
        display:'grid', placeItems:'center', flex:'0 0 auto',
        font:'900 12px var(--tt-mono)', color,
      }}>{num}</div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'800 13px var(--tt-font)', color:'var(--tt-text)'}}>{name}</div>
        <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>{sub}</div>
      </div>
      <span className="num" style={{font:'800 11px var(--tt-mono)', color:color, letterSpacing:'-0.01em', flex:'0 0 auto'}}>{km} km</span>
      <Icon name="menu" size={13} color="var(--tt-text-3)"/>
    </div>
  );
}

function ComputedStat({ label, value, unit, ember }) {
  return (
    <div style={{padding:'10px 12px', background:'var(--tt-surf)', textAlign:'center'}}>
      <div style={{font:'700 9px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-3)'}}>{label}</div>
      <div style={{display:'flex', alignItems:'baseline', gap:3, justifyContent:'center', marginTop:5}}>
        <span className="num count-up" style={{font:'800 17px var(--tt-mono)', color: ember ? 'var(--tt-ember)' : 'var(--tt-text)', letterSpacing:'-0.02em'}}>{value}</span>
        {unit && <span className="num" style={{fontSize:9, color:'var(--tt-text-2)', fontWeight:600}}>{unit}</span>}
      </div>
    </div>
  );
}

function FieldLabelPR({ children }) {
  return (
    <div style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em', textTransform:'uppercase', color:'var(--tt-text-3)', marginBottom:7}}>
      {children}
    </div>
  );
}

function FieldPR({ value, leading, leadingColor }) {
  return (
    <div style={{
      display:'flex', alignItems:'center', gap:8,
      padding:'12px 14px',
      background:'var(--tt-surf)', border:'1px solid var(--tt-line)',
      borderRadius:11,
    }}>
      {leading && <span style={{font:'700 12px var(--tt-font)', color: leadingColor || 'var(--tt-text-3)'}}>{leading}</span>}
      <input type="text" defaultValue={value}
        style={{flex:1, background:'transparent', border:'none', outline:'none',
          color:'var(--tt-text)', font:'600 13px var(--tt-font)'}}/>
    </div>
  );
}

window.ScreenPlanRoute = ScreenPlanRoute;

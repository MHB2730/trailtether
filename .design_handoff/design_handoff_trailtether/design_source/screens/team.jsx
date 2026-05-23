// Trailtether — Team Tracking screen

function ScreenTeam() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar
          time="10:09"
          right={
            <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-green)', fontSize:10.5, fontWeight:700, letterSpacing:'0.1em', marginRight:4}}>
              <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.4s infinite'}}/>
              LIVE
            </span>
          }
        />

        <div className="tt-appbar anim-in" style={{paddingBottom:12}}>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', alignItems:'center', gap:9, marginBottom:4}}>
              <TTLogo size={18}/>
              <span style={{font:'800 12px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <h1 style={{margin:0, font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Alpine Adventure</h1>
            <div className="sub" style={{marginTop:4}}>
              <b>DAY 3</b> · OCT 26 · 4 ACTIVE
            </div>
          </div>
          <button className="icon-btn"><Icon name="message" size={16} color="var(--tt-text-2)"/></button>
          <button className="icon-btn"><Icon name="settings" size={16} color="var(--tt-text-2)"/></button>
        </div>

        <div className="tt-body">
          {/* Team map */}
          <div style={{flex:'0 0 320px', position:'relative', overflow:'hidden', borderTop:'1px solid var(--tt-line)', borderBottom:'1px solid var(--tt-line)'}}>
            <TeamMap/>
          </div>

          {/* Team list */}
          <div className="tt-scroll" style={{padding:'16px 18px 24px', background:'var(--tt-bg-2)'}}>
            <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:14}}>
              <div style={{display:'flex', alignItems:'center', gap:8}}>
                <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-ember)'}}>Active Team</span>
                <span className="pill ember">4</span>
              </div>
              <span className="num" style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.04em'}}>UPDATED 10:09:11</span>
            </div>

            <div style={{display:'flex', flexDirection:'column', gap:10}}>
              <Stagger base={400} delay={90}>
                <TeamRow name="John D."  initial="J" color="#ff6a2c" loc="Sunrise Camp"  dist="8.4 km" elev="1,850 m" speed="2.8 km/hr" batt={84} lead/>
                <TeamRow name="Sarah L." initial="S" color="#ff6a2c" loc="Shadow Lake"   dist="8.2 km" elev="1,790 m" speed="2.5 km/hr" batt={64}/>
                <TeamRow name="Mike K."  initial="M" color="#4cc38a" loc="Berkeley Park" dist="8.1 km" elev="1,750 m" speed="2.7 km/hr" batt={71}/>
                <TeamRow name="Emily R." initial="E" color="#f2a93b" loc="Frozen Lake"   dist="8.5 km" elev="1,820 m" speed="2.9 km/hr" batt={48} alert/>
              </Stagger>
            </div>
          </div>
        </div>

        {/* FAB — START HIKE */}
        <button className="pressable" style={{
          position:'absolute', right:18, bottom:104,
          width:60, height:60, borderRadius:'50%',
          background:'linear-gradient(135deg, #ff8a4d 0%, #ff6a2c 70%, #e85a1f 100%)',
          border:'2px solid rgba(255,160,108,0.45)',
          display:'grid', placeItems:'center',
          color:'#1a0d04',
          boxShadow:'0 12px 28px -6px rgba(255,106,44,0.55), inset 0 1px 0 rgba(255,255,255,0.25)',
          cursor:'pointer',
          font:'800 9px var(--tt-font)', letterSpacing:'0.1em',
          zIndex:5,
          animation:'float 4s ease-in-out infinite',
        }}>
          <div style={{display:'flex', flexDirection:'column', alignItems:'center', gap:1}}>
            <Icon name="plus" size={22} color="#1a0d04" strokeWidth={2.3}/>
          </div>
          <span style={{position:'absolute', bottom:-22, left:'50%', transform:'translateX(-50%)', font:'700 9px var(--tt-font)', letterSpacing:'0.16em', color:'var(--tt-ember-2)', whiteSpace:'nowrap'}}>START HIKE</span>
        </button>

        <BottomNav active="teams"/>
      </div>
    </div>
  );
}

function TeamMap() {
  return (
    <>
      <svg viewBox="0 0 412 320" preserveAspectRatio="xMidYMid slice"
           style={{position:'absolute', inset:0, width:'100%', height:'100%', background:'#0d1a14'}}>
        <defs>
          <radialGradient id="teamTerr" cx="50%" cy="45%" r="65%">
            <stop offset="0%"  stopColor="#1f3327" stopOpacity="0.9"/>
            <stop offset="55%" stopColor="#152821" stopOpacity="0.7"/>
            <stop offset="100%" stopColor="#0a0c0f" stopOpacity="0.4"/>
          </radialGradient>
          <filter id="teamGlow">
            <feGaussianBlur stdDeviation="1.8" result="b"/>
            <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
        </defs>
        <rect width="412" height="320" fill="url(#teamTerr)"/>

        {/* Topo contours */}
        <g fill="none" stroke="#0a1a12" strokeWidth="0.7" opacity="0.6">
          {[
            'M-20,260 Q100,240 200,235 T440,250',
            'M-20,220 Q100,180 200,190 T440,215',
            'M-20,180 Q100,130 220,150 T440,180',
            'M0,150 Q120,90 230,115 T440,150',
            'M30,120 Q140,60 240,90 T420,125',
            'M70,95 Q160,40 250,75 T390,110',
            'M110,75 Q190,30 250,60 T350,95',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>
        <g fill="none" stroke="#2a4036" strokeWidth="0.45" opacity="0.55">
          {[
            'M-20,280 Q100,260 200,255 T440,270',
            'M-20,240 Q100,210 200,212 T440,232',
            'M-20,200 Q100,160 200,170 T440,200',
            'M-20,160 Q120,110 230,130 T440,160',
            'M10,130 Q140,75 240,100 T430,135',
          ].map((d,i) => <path key={i} d={d}/>)}
        </g>

        {/* Trail */}
        <path d="M 40 285 Q 100 220 150 180 Q 200 140 260 130 Q 320 130 360 80"
              stroke="#5aa1d6" strokeOpacity="0.4" strokeWidth="3.5" fill="none" strokeLinecap="round" filter="url(#teamGlow)"
              className="draw-line" style={{['--len']: 420}}/>
        <path d="M 40 285 Q 100 220 150 180 Q 200 140 260 130 Q 320 130 360 80"
              stroke="#5aa1d6" strokeWidth="1.8" fill="none" strokeLinecap="round"
              className="draw-line" style={{['--len']: 420, animationDelay:'80ms'}}/>

        {/* Peaks */}
        <PeakMarker x={350} y={75} name="Liberty Cap"/>
        <PeakMarker x={380} y={130} name="Tahoma Glacier" small/>
        <PeakMarker x={220} y={170} name="Peaks" small/>

        {/* Members */}
        <PersonAvatar cx={150} cy={170} initial="J" color="#ff6a2c" name="John"  delay={500}/>
        <PersonAvatar cx={250} cy={140} initial="S" color="#ff6a2c" name="Sarah" delay={600}/>
        <PersonAvatar cx={110} cy={250} initial="M" color="#4cc38a" name="Mike"  delay={700}/>
        <PersonAvatar cx={315} cy={155} initial="E" color="#f2a93b" name="Emily" delay={800}/>

        {/* Trail label tag */}
        <g transform="translate(206,232)" className="anim-pop" style={{animationDelay:'1100ms', transformOrigin:'206px 232px'}}>
          <rect x="-52" y="-12" width="104" height="26" rx="5" fill="rgba(10,12,15,0.93)" stroke="rgba(255,255,255,0.15)" strokeWidth="0.5"/>
          <text x="0" y="-1" textAnchor="middle" fill="#eef1f4" fontFamily="Manrope" fontSize="9.5" fontWeight="700" letterSpacing="0.06em">WONDERLAND TRAIL</text>
          <text x="0" y="9" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="8.5" fontWeight="700">8,450 m · Day 3</text>
        </g>
      </svg>

      {/* Top tag — TREK-WATCH */}
      <div className="glass anim-up" style={{
        position:'absolute', top:12, left:12,
        padding:'6px 11px', display:'inline-flex', alignItems:'center', gap:8,
        animationDelay:'120ms',
      }}>
        <span style={{display:'inline-flex', alignItems:'center', gap:5, font:'800 9.5px var(--tt-mono)', color:'var(--tt-green)', letterSpacing:'0.12em'}}>
          <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 5px var(--tt-green)', animation:'pulse 1.6s infinite'}}/>
          LIVE
        </span>
        <span style={{width:1, height:10, background:'var(--tt-line-3)'}}/>
        <span style={{font:'800 10px var(--tt-font)', letterSpacing:'0.18em'}}>
          TREK-<span style={{color:'var(--tt-ember)'}}>WATCH</span>
        </span>
      </div>

      {/* Center map control */}
      <button className="glass pressable anim-pop" style={{
        position:'absolute', right:12, bottom:12,
        width:38, height:38, padding:0,
        display:'grid', placeItems:'center',
        animationDelay:'1000ms',
      }}>
        <Icon name="crosshair" size={16} color="var(--tt-ember)"/>
      </button>
    </>
  );
}

function PeakMarker({ x, y, name, small }) {
  return (
    <g transform={`translate(${x},${y})`}>
      <path d="M -5 5 L 0 -5 L 5 5 Z" fill="#eef1f4" stroke="#0a0c0f" strokeWidth="0.8"/>
      <text x="0" y={-8} textAnchor="middle" fill="#98a1ac" fontFamily="Manrope" fontSize={small ? 8.5 : 9.5} fontWeight="600">{name}</text>
    </g>
  );
}

function PersonAvatar({ cx, cy, initial, color, name, delay = 500 }) {
  return (
    <g className="anim-pop" style={{animationDelay:`${delay}ms`, transformOrigin:`${cx}px ${cy}px`}}>
      {/* Pulsing halo */}
      <circle cx={cx} cy={cy+4} r="20" fill={color} opacity="0.10">
        <animate attributeName="r" values="18;26;18" dur="3s" repeatCount="indefinite"/>
        <animate attributeName="opacity" values="0.15;0;0.15" dur="3s" repeatCount="indefinite"/>
      </circle>
      {/* Pin tail */}
      <path d={`M ${cx} ${cy+22} L ${cx-6} ${cy+12} L ${cx+6} ${cy+12} Z`} fill={color}/>
      <circle cx={cx} cy={cy+4} r="14" fill="#1a1d22" stroke={color} strokeWidth="2.5"/>
      <circle cx={cx} cy={cy+4} r="11" fill={color} opacity="0.18"/>
      <text x={cx} y={cy+8} textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="12" fontWeight="800">{initial}</text>

      {/* Name tag */}
      <g transform={`translate(${cx}, ${cy+38})`}>
        <rect x="-22" y="-7" width="44" height="14" rx="3.5" fill="rgba(10,12,15,0.92)" stroke="rgba(255,255,255,0.12)" strokeWidth="0.5"/>
        <text x="0" y="3" textAnchor="middle" fill="#eef1f4" fontFamily="Manrope" fontSize="9" fontWeight="700">{name}</text>
      </g>

      {/* Directional badge */}
      <g transform={`translate(${cx+11},${cy-5})`}>
        <circle r="6" fill="#0a0c0f" stroke={color} strokeWidth="1.2"/>
        <path d="M -2 1 L 0 -2 L 2 1 L 0 0 Z" fill={color}/>
      </g>
    </g>
  );
}

function TeamRow({ name, initial, color, loc, dist, elev, speed, batt, lead, alert }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:14,
      padding:'12px 14px',
      background:'var(--tt-surf)',
      border:`1px solid ${alert ? 'rgba(242,169,59,0.32)' : 'var(--tt-line)'}`,
      borderRadius:14,
      cursor:'pointer',
      position:'relative',
      overflow:'hidden',
    }}>
      {/* left ember accent if lead */}
      {lead && (
        <div style={{position:'absolute', left:0, top:14, bottom:14, width:3,
          background:'var(--tt-ember)', borderRadius:'0 2px 2px 0',
          boxShadow:'0 0 8px rgba(255,106,44,0.5)'}}/>
      )}

      <div style={{position:'relative', flex:'0 0 auto'}}>
        <div style={{
          width:44, height:44, borderRadius:'50%',
          background:`linear-gradient(135deg, ${color}, ${color}aa)`,
          display:'grid', placeItems:'center',
          color:'#fff', font:'800 16px var(--tt-font)',
          border:`2.5px solid ${color}`,
          boxShadow: `0 0 14px ${color}55`,
        }}>
          {initial}
        </div>
        <div style={{
          position:'absolute', bottom:-2, right:-2,
          width:13, height:13, borderRadius:'50%',
          background:'var(--tt-green)',
          border:'2.5px solid var(--tt-surf)',
          boxShadow:'0 0 6px var(--tt-green)',
        }}/>
      </div>

      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:7}}>
          <span style={{font:'800 14.5px var(--tt-font)', color:'var(--tt-text)'}}>{name}</span>
          {lead && (
            <span style={{
              padding:'2px 6px', borderRadius:4,
              background:'var(--tt-ember-dim)',
              font:'800 8.5px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.12em',
            }}>LEAD</span>
          )}
          {alert && <Icon name="alert" size={13} color="var(--tt-amber)"/>}
        </div>
        <div style={{display:'flex', alignItems:'center', gap:8, marginTop:3, font:'500 10.5px var(--tt-mono)', color:'var(--tt-text-3)'}}>
          <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-green)', fontWeight:700}}>
            <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 5px var(--tt-green)'}}/>
            Online
          </span>
          <span style={{color:'var(--tt-line-3)'}}>·</span>
          <span>{loc}</span>
        </div>
        <div style={{display:'flex', gap:12, marginTop:6, font:'700 11px var(--tt-mono)', color:'var(--tt-text-2)'}}>
          <span><span style={{color:'var(--tt-text-3)', fontWeight:600, marginRight:2}}>D</span>{dist}</span>
          <span><span style={{color:'var(--tt-text-3)', fontWeight:600, marginRight:2}}>↑</span>{elev}</span>
          <span><span style={{color:'var(--tt-text-3)', fontWeight:600, marginRight:2}}>S</span>{speed}</span>
        </div>
      </div>

      <div style={{display:'flex', flexDirection:'column', alignItems:'flex-end', gap:8}}>
        <BattRow pct={batt}/>
        <Icon name="chevron-right" size={15} color="var(--tt-text-3)"/>
      </div>
    </div>
  );
}

window.ScreenTeam = ScreenTeam;

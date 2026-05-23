// Trailtether — Profile tab

function ScreenProfile() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <div style={{flex:1}}>
            <div style={{display:'flex', alignItems:'center', gap:9, marginBottom:4}}>
              <TTLogo size={18}/>
              <span style={{font:'800 12px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <h1 style={{margin:0, font:'800 24px var(--tt-font)', letterSpacing:'-0.02em'}}>Profile</h1>
          </div>
          <button className="icon-btn"><Icon name="settings" size={16} color="var(--tt-text-2)"/></button>
        </div>

        <div className="tt-scroll" style={{padding:'4px 18px 24px'}}>
          <ProfileHeader/>
          <ProfileStats/>
          <Achievements/>
          <SettingsList/>
        </div>

        <BottomNav active="profile"/>
      </div>
    </div>
  );
}

function ProfileHeader() {
  return (
    <div className="anim-up" style={{
      position:'relative', padding:'18px 16px',
      background:'linear-gradient(135deg, var(--tt-surf), var(--tt-bg-3))',
      border:'1px solid var(--tt-line)',
      borderRadius:18,
      marginTop:8, overflow:'hidden',
    }}>
      {/* Ember glow corner */}
      <div style={{
        position:'absolute', top:-40, right:-40,
        width:140, height:140, borderRadius:'50%',
        background:'radial-gradient(circle, rgba(255,106,44,0.22), transparent 70%)',
        pointerEvents:'none',
      }}/>

      <div style={{display:'flex', gap:16, alignItems:'center', position:'relative'}}>
        {/* Avatar */}
        <div style={{position:'relative', flex:'0 0 auto'}}>
          <div style={{
            width:78, height:78, borderRadius:'50%',
            border:'3px solid var(--tt-ember)',
            background:'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
            display:'grid', placeItems:'center',
            color:'#fff', font:'900 28px var(--tt-font)',
            boxShadow:'0 0 22px rgba(255,106,44,0.45)',
          }}>JD</div>
          {/* Online dot */}
          <div style={{
            position:'absolute', bottom:2, right:2,
            width:16, height:16, borderRadius:'50%',
            background:'var(--tt-green)',
            border:'3px solid var(--tt-bg-3)',
            boxShadow:'0 0 8px var(--tt-green)',
          }}/>
        </div>

        <div style={{flex:1, minWidth:0}}>
          <div style={{font:'900 22px var(--tt-font)', color:'var(--tt-text)', letterSpacing:'-0.01em'}}>John Davies</div>
          <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.04em'}}>john@trailtether.app</div>
          <div style={{display:'flex', gap:6, marginTop:8}}>
            <span style={{padding:'3px 8px', borderRadius:5, background:'rgba(242,169,59,0.15)', border:'1px solid rgba(242,169,59,0.4)', font:'800 9px var(--tt-mono)', color:'var(--tt-amber)', letterSpacing:'0.14em'}}>
              ADVANCED
            </span>
            <span style={{padding:'3px 8px', borderRadius:5, background:'var(--tt-ember-dim)', border:'1px solid rgba(255,106,44,0.36)', font:'800 9px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.14em'}}>
              TEAM LEAD
            </span>
          </div>
        </div>
      </div>

      {/* Bio */}
      <div style={{
        marginTop:14, padding:'10px 12px',
        background:'rgba(255,255,255,0.02)',
        border:'1px solid var(--tt-line)',
        borderRadius:10,
        font:'500 12px/1.5 var(--tt-font)', color:'var(--tt-text-2)',
      }}>
        Cape Town based. Drakensberg regular. Slow ascents, long descents, dawn starts.
      </div>
    </div>
  );
}

function ProfileStats() {
  const stats = [
    { label:'Hikes',    value:'47',     unit:'',    icon:'mountain' },
    { label:'Distance', value:'284',    unit:'km',  icon:'navigation', ember:true },
    { label:'Ascent',   value:'62,418', unit:'m',   icon:'arrow-up' },
    { label:'Teams',    value:'3',      unit:'',    icon:'people' },
  ];
  return (
    <div style={{marginTop:14, display:'grid', gridTemplateColumns:'1fr 1fr', gap:10}}>
      <Stagger base={250} delay={70}>
        {stats.map(s => (
          <div key={s.label} className="card pressable" style={{padding:'14px 14px'}}>
            <div style={{display:'flex', alignItems:'center', gap:6}}>
              <Icon name={s.icon} size={12} color={s.ember ? 'var(--tt-ember)' : 'var(--tt-text-3)'}/>
              <span style={{font:'700 9.5px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-3)'}}>{s.label}</span>
            </div>
            <div style={{display:'flex', alignItems:'baseline', gap:4, marginTop:8}}>
              <span className="num count-up" style={{font:'800 22px var(--tt-mono)', color: s.ember ? 'var(--tt-ember)' : 'var(--tt-text)', letterSpacing:'-0.02em', animationDelay:'500ms'}}>{s.value}</span>
              {s.unit && <span className="num" style={{fontSize:11, color:'var(--tt-text-2)', fontWeight:600}}>{s.unit}</span>}
            </div>
          </div>
        ))}
      </Stagger>
    </div>
  );
}

function Achievements() {
  // Each badge is a topographic survey medallion. Unlocked ones get the
  // full Trailtether visual treatment: rippling radar contours, an ember
  // trail that draws itself across a mountain silhouette to a pulsing
  // summit pin, with embers drifting upward. Locked ones show their
  // progress as ember "magma" rising from the base of the medallion.
  const all = [
    { id:'storm',    icon:'wind',     label:'Storm Survivor',  sub:'Hike through warning',  rarity:'epic',      progress:1.0, unlocked:true, newest:true,
      desc:'Completed a sustained hike through an active severe-weather warning. The mountain noticed.', earned:'OCT 24' },
    { id:'first',    icon:'play',     label:'First Steps',     sub:'Complete 1st hike',     rarity:'common',    progress:1.0, unlocked:true },
    { id:'highrise', icon:'mountain', label:'4K Club',         sub:'4,000m elevation',      rarity:'rare',      progress:1.0, unlocked:true },
    { id:'tether',   icon:'tether',   label:'Tethered',        sub:'Pair a base-camp PC',   rarity:'rare',      progress:1.0, unlocked:true },
    { id:'gpx',      icon:'route',    label:'Plan Maker',      sub:'Upload 5 GPX routes',   rarity:'common',    progress:1.0, unlocked:true },
    { id:'lead',     icon:'people',   label:'Team Lead',       sub:'Lead a group hike',     rarity:'rare',      progress:1.0, unlocked:true },
    { id:'cave',     icon:'rock',     label:'Caver',           sub:'Visit 10 shelters',     rarity:'rare',      progress:0.7, unlocked:false },
    { id:'sos',      icon:'shield',   label:'First Responder', sub:'Help in an incident',   rarity:'legendary', progress:0.0, unlocked:false },
  ];
  const unlocked = all.filter(a => a.unlocked).length;
  const newest = all.find(a => a.newest);

  return (
    <div style={{ marginTop:18 }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>
          Achievements <span style={{ color:'var(--tt-text-3)' }}>({unlocked}/{all.length})</span>
        </span>
        <span style={{ font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em' }}>VIEW ALL →</span>
      </div>

      {/* Hero — Latest unlock */}
      {newest && <LatestUnlock ach={newest} />}

      {/* Grid */}
      <div style={{ display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:8, marginTop:12 }}>
        <Stagger base={650} delay={70}>
          {all.filter(a => !a.newest).map(a => <AchievementBadge key={a.id} ach={a} />)}
        </Stagger>
      </div>

      {/* Local keyframes */}
      <style>{`
        @keyframes ach-spark-rise {
          0%   { transform: translate(0,0) scale(0.4); opacity: 0; }
          18%  { opacity: 1; }
          100% { transform: translate(var(--sx, 0), var(--sy, -28px)) scale(0.2); opacity: 0; }
        }
        @keyframes ach-scan {
          0%   { transform: translateY(-100%); opacity: 0; }
          20%  { opacity: 0.6; }
          80%  { opacity: 0.6; }
          100% { transform: translateY(140%); opacity: 0; }
        }
        @keyframes ach-flicker {
          0%, 100% { opacity: 1; }
          47% { opacity: 0.85; }
          53% { opacity: 1; }
        }
        @keyframes ach-fresh-flame {
          0%, 100% { transform: scale(1) rotate(-1deg); }
          50%      { transform: scale(1.06) rotate(1deg); }
        }
      `}</style>
    </div>
  );
}

const RARITY = {
  common:    { label:'COMMON',    ring:'#7a8390', fill:'#98a1ac', glow:'rgba(152,161,172,0.55)' },
  rare:      { label:'RARE',      ring:'#5aa1d6', fill:'#7fbceb', glow:'rgba(90,161,214,0.55)'  },
  epic:      { label:'EPIC',      ring:'#ff6a2c', fill:'#ff8a4d', glow:'rgba(255,106,44,0.75)'  },
  legendary: { label:'LEGENDARY', ring:'#f2a93b', fill:'#ffd07a', glow:'rgba(242,169,59,0.85)'  },
};

/* ------------------------------------------------------------------
   Latest unlock — the hero card with a larger medallion + sparks
   ------------------------------------------------------------------ */
function LatestUnlock({ ach }) {
  const r = RARITY[ach.rarity] || RARITY.common;
  return (
    <div className="anim-up" style={{
      position:'relative', marginTop:4,
      padding:'16px 14px',
      background:'linear-gradient(135deg, rgba(255,106,44,0.10) 0%, rgba(11,14,18,0.6) 60%)',
      border:'1px solid rgba(255,106,44,0.32)',
      borderRadius:16,
      overflow:'hidden',
      animationDelay:'480ms',
    }}>
      {/* Topo paper background bleed */}
      <div style={{
        position:'absolute', inset:0, opacity:0.20, pointerEvents:'none',
        backgroundImage:`url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='320' height='110' viewBox='0 0 320 110'><g fill='none' stroke='%23ff8a4d' stroke-width='0.5'><path d='M0,30 Q80,22 160,28 T320,32'/><path d='M0,50 Q80,42 160,48 T320,52'/><path d='M0,70 Q80,62 160,68 T320,72'/><path d='M0,90 Q80,82 160,88 T320,92'/></g></svg>")`,
        backgroundRepeat:'no-repeat', backgroundSize:'100% 100%',
      }} />

      <div style={{ display:'flex', alignItems:'center', gap:14, position:'relative' }}>
        <TopoMedallion ach={ach} rarity={ach.rarity} unlocked size={96} large />

        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ display:'flex', alignItems:'center', gap:5, marginBottom:4, flexWrap:'wrap' }}>
            <span style={{
              padding:'2px 7px', borderRadius:4,
              font:'800 8.5px var(--tt-mono)', letterSpacing:'0.2em',
              color:'#1a0d04', background:`linear-gradient(90deg, ${r.fill}, #ffd6b0)`,
            }}>{r.label}</span>
            <span style={{
              padding:'2px 7px', borderRadius:4,
              display:'inline-flex', alignItems:'center', gap:4,
              font:'800 8.5px var(--tt-mono)', letterSpacing:'0.18em', color:'var(--tt-ember)',
              background:'var(--tt-ember-dim)', border:'1px solid rgba(255,106,44,0.32)',
              animation:'ach-fresh-flame 1.6s ease-in-out infinite',
              transformOrigin:'left center',
            }}>
              <svg width="9" height="10" viewBox="0 0 9 10"><path d="M4.5 0 C 4 2 2 3 2 5.5 a2.5 2.5 0 005 0 c0-1.5-1-2.5-1.5-3.5 C 5.5 3 4 4 4.5 0z" fill="#ff8a4d"/></svg>
              FRESH BURN
            </span>
          </div>
          <div style={{ font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em' }}>LATEST UNLOCK</div>
          <div style={{ font:'900 18px var(--tt-font)', color:'var(--tt-text)', letterSpacing:'-0.015em', marginTop:3 }}>{ach.label}</div>
          <div style={{ font:'500 11.5px/1.4 var(--tt-font)', color:'var(--tt-text-2)', marginTop:6, maxWidth:'95%' }}>{ach.desc}</div>
          <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:8 }}>
            <span style={{ font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.12em' }}>EARNED {ach.earned}</span>
            <button className="pressable" style={{
              padding:'4px 9px', borderRadius:6,
              background:'rgba(255,106,44,0.10)',
              border:'1px solid rgba(255,106,44,0.32)',
              color:'var(--tt-ember)',
              font:'800 9px var(--tt-font)', letterSpacing:'0.16em',
              cursor:'pointer',
              display:'inline-flex', alignItems:'center', gap:4,
            }}>
              <Icon name="send-fill" size={9} color="var(--tt-ember)" />
              SHARE
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------
   Single badge in the grid
   ------------------------------------------------------------------ */
function AchievementBadge({ ach }) {
  const r = RARITY[ach.rarity] || RARITY.common;
  return (
    <div className="pressable" style={{
      position:'relative',
      display:'flex', flexDirection:'column', alignItems:'center', gap:7,
      padding:'10px 4px 9px',
      background:'var(--tt-surf)',
      border:`1px solid ${ach.unlocked ? r.ring + '55' : 'var(--tt-line)'}`,
      borderRadius:11,
      overflow:'hidden',
      cursor:'pointer',
    }}>
      {/* Subtle scan line for unlocked */}
      {ach.unlocked && (
        <div style={{
          position:'absolute', left:0, right:0, top:0, height:24,
          background:`linear-gradient(180deg, ${r.glow.replace(/0\.\d+/g, '0.55')}, transparent)`,
          mixBlendMode:'screen',
          animation:'ach-scan 4.5s ease-in-out infinite',
          pointerEvents:'none',
        }} />
      )}

      <TopoMedallion ach={ach} rarity={ach.rarity} unlocked={ach.unlocked} progress={ach.progress} size={56} />

      <span style={{
        font:'800 9.5px/1.2 var(--tt-font)',
        color: ach.unlocked ? 'var(--tt-text)' : 'var(--tt-text-3)',
        textAlign:'center', letterSpacing:'0.02em', position:'relative',
      }}>{ach.label}</span>

      <span style={{
        position:'relative',
        padding:'1px 6px', borderRadius:3,
        background: ach.unlocked ? `${r.ring}1f` : 'rgba(255,255,255,0.02)',
        border: `1px solid ${ach.unlocked ? r.ring + '55' : 'var(--tt-line-2)'}`,
        font:'800 8px var(--tt-mono)', letterSpacing:'0.14em',
        color: ach.unlocked ? r.fill : 'var(--tt-text-3)',
      }}>
        {ach.unlocked
          ? r.label
          : ach.progress > 0 ? `${Math.round(ach.progress * 100)}%` : 'LOCKED'}
      </span>
    </div>
  );
}

/* ------------------------------------------------------------------
   The medallion itself — a hexagonal topo survey marker.
   Drives every achievement visual. Used at size=56 in the grid and
   size=96 in the LatestUnlock hero.
   ------------------------------------------------------------------ */
function TopoMedallion({ ach, rarity, unlocked, progress = 0, size = 56, large = false }) {
  const r = RARITY[rarity] || RARITY.common;
  const uid = `tm-${ach.id}`;

  // The trail path inside the hex (viewBox 100×100). Climbs from
  // lower-left, switchbacks past a mid waypoint, ends at the summit pin.
  const TRAIL_D = 'M 18,82 C 28,76 34,68 38,64 S 50,58 46,50 S 54,42 60,40 S 70,36 70,32';
  const SUMMIT = { x: 70, y: 32 };

  return (
    <div style={{ position:'relative', width:size, height:size, flex:'0 0 auto' }}>
      <svg viewBox="0 0 100 100" width={size} height={size}
           style={{ display:'block', filter: unlocked ? `drop-shadow(0 0 ${large ? 14 : 8}px ${r.glow})` : 'none' }}>
        <defs>
          <clipPath id={`${uid}-clip`}>
            <path d="M 50,4 L 92,27 L 92,73 L 50,96 L 8,73 L 8,27 Z" />
          </clipPath>
          <linearGradient id={`${uid}-bg`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%"  stopColor={unlocked ? '#1a1010' : '#11161c'} />
            <stop offset="100%" stopColor={unlocked ? '#06080b' : '#06080b'} />
          </linearGradient>
          <linearGradient id={`${uid}-magma`} x1="0" y1="1" x2="0" y2="0">
            <stop offset="0%"  stopColor={r.ring} stopOpacity="0.85" />
            <stop offset="100%" stopColor={r.ring} stopOpacity="0" />
          </linearGradient>
          <linearGradient id={`${uid}-trail`} x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%"  stopColor={r.ring} stopOpacity="0" />
            <stop offset="30%" stopColor={r.fill} />
            <stop offset="100%" stopColor="#fff4d6" />
          </linearGradient>
          <radialGradient id={`${uid}-pin`} cx="50%" cy="50%" r="50%">
            <stop offset="0%"  stopColor="#fff4d6" />
            <stop offset="50%" stopColor={r.fill} />
            <stop offset="100%" stopColor={r.ring} stopOpacity="0" />
          </radialGradient>
          <filter id={`${uid}-glow`} x="-30%" y="-30%" width="160%" height="160%">
            <feGaussianBlur stdDeviation="1.6" />
          </filter>
        </defs>

        <g clipPath={`url(#${uid}-clip)`}>
          {/* base fill */}
          <rect width="100" height="100" fill={`url(#${uid}-bg)`} />

          {/* Topo contour lines */}
          <g stroke={unlocked ? `${r.fill}33` : 'rgba(255,255,255,0.06)'}
             fill="none" strokeWidth="0.5">
            <path d="M -10,40 Q 30,32 50,38 T 110,40" />
            <path d="M -10,52 Q 30,44 50,50 T 110,52" />
            <path d="M -10,64 Q 30,56 50,62 T 110,64" />
            <path d="M -10,76 Q 30,68 50,74 T 110,76" />
            <path d="M -10,88 Q 30,80 50,86 T 110,88" />
          </g>

          {/* Radar ping rings — only when unlocked */}
          {unlocked && (
            <g>
              {[0, 1.5].map((delay, i) => (
                <circle key={i} cx={SUMMIT.x} cy={SUMMIT.y}
                        fill="none" stroke={r.fill} strokeWidth="0.7" opacity="0.6">
                  <animate attributeName="r" from="3" to="46" dur="3.2s" begin={`${delay}s`} repeatCount="indefinite" />
                  <animate attributeName="opacity" values="0.7;0" dur="3.2s" begin={`${delay}s`} repeatCount="indefinite" />
                </circle>
              ))}
            </g>
          )}

          {/* Ember magma fill for locked-with-progress */}
          {!unlocked && progress > 0 && (
            <g>
              <rect x="0" y={100 - progress * 92}
                    width="100" height={progress * 92 + 8}
                    fill={`url(#${uid}-magma)`} opacity="0.7">
                <animate attributeName="opacity" values="0.55;0.85;0.55" dur="2.4s" repeatCount="indefinite" />
              </rect>
              {/* Glowing wavefront at the top of the magma */}
              <path d={`M 0 ${100 - progress * 92} Q 30 ${98 - progress*92} 50 ${100 - progress * 92} T 100 ${100 - progress*92}`}
                    fill="none" stroke={r.fill} strokeWidth="0.9" opacity="0.85">
                <animate attributeName="opacity" values="0.6;1;0.6" dur="2.4s" repeatCount="indefinite" />
              </path>
            </g>
          )}

          {/* Mountain silhouette */}
          <path d="M 5 92 L 22 70 L 32 78 L 44 60 L 56 70 L 70 32 L 84 64 L 95 92 Z"
                fill={unlocked ? '#05060a' : '#0d1218'}
                stroke={unlocked ? `${r.fill}66` : 'rgba(255,255,255,0.10)'}
                strokeWidth="0.7" strokeLinejoin="round" />

          {/* Switchback trail to summit — only when unlocked */}
          {unlocked && (
            <g>
              {/* under-glow */}
              <path d={TRAIL_D} fill="none" stroke={r.fill}
                    strokeWidth="3.2" strokeLinecap="round" opacity="0.5"
                    filter={`url(#${uid}-glow)`} />
              {/* dashed draw-in core */}
              <path d={TRAIL_D} fill="none"
                    stroke={`url(#${uid}-trail)`}
                    strokeWidth="1.4" strokeLinecap="round"
                    pathLength="1" strokeDasharray="1 1">
                <animate attributeName="stroke-dashoffset" from="1" to="0" dur="2.6s" repeatCount="indefinite" calcMode="spline" keySplines="0.35 0 0.5 1" keyTimes="0;1" />
              </path>
              {/* tracer that runs the trail */}
              <circle r="1.4" fill="#fff4d6">
                <animateMotion dur="2.6s" repeatCount="indefinite" path={TRAIL_D}
                               calcMode="spline" keySplines="0.35 0 0.5 1" keyTimes="0;1" />
                <animate attributeName="opacity" values="0;1;1;0" keyTimes="0;0.1;0.9;1" dur="2.6s" repeatCount="indefinite" />
              </circle>
            </g>
          )}

          {/* Summit pin — pulses on unlocked */}
          {unlocked ? (
            <g>
              <circle cx={SUMMIT.x} cy={SUMMIT.y} r="6" fill={`url(#${uid}-pin)`}>
                <animate attributeName="r" values="4;8;4" dur="2s" repeatCount="indefinite" />
                <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" repeatCount="indefinite" />
              </circle>
              <circle cx={SUMMIT.x} cy={SUMMIT.y} r="1.8" fill="#fff4d6">
                <animate attributeName="opacity" values="0.85;1;0.85" dur="2s" repeatCount="indefinite" />
              </circle>
            </g>
          ) : (
            <circle cx={SUMMIT.x} cy={SUMMIT.y} r="1.2" fill="rgba(255,255,255,0.18)" />
          )}

          {/* Reticle corner brackets — survey-marker vibe */}
          <g stroke={unlocked ? r.fill : 'rgba(255,255,255,0.18)'} strokeWidth="1" fill="none"
             strokeLinecap="round" opacity={unlocked ? 0.85 : 0.45}>
            <path d="M 10 28 L 16 25" />
            <path d="M 90 28 L 84 25" />
            <path d="M 10 72 L 16 75" />
            <path d="M 90 72 L 84 75" />
          </g>
        </g>

        {/* Hex border — last so it sits above content */}
        <path d="M 50,4 L 92,27 L 92,73 L 50,96 L 8,73 L 8,27 Z"
              fill="none"
              stroke={unlocked ? r.ring : 'var(--tt-line-2)'}
              strokeWidth={large ? 1.6 : 1.4}
              opacity={unlocked ? 1 : 0.7} />
      </svg>

      {/* Center icon over the medallion (positioned on the trail) */}
      <div style={{
        position:'absolute',
        left:'50%', top: large ? '54%' : '54%',
        transform:'translate(-50%, -50%)',
        width: large ? 22 : 14,
        height: large ? 22 : 14,
        display:'grid', placeItems:'center',
        background: unlocked ? '#0a0c0f' : 'transparent',
        borderRadius:'50%',
        boxShadow: unlocked ? `0 0 0 1.5px ${r.ring}, 0 0 8px ${r.glow}` : 'none',
      }}>
        <Icon name={ach.icon}
              size={large ? 13 : 9}
              color={unlocked ? r.fill : 'var(--tt-text-3)'}
              strokeWidth={2.2} />
      </div>

      {/* Lock chip for locked badges */}
      {!unlocked && (
        <div style={{
          position:'absolute', bottom:-2, right:-2,
          width:18, height:18, borderRadius:'50%',
          background:'var(--tt-bg-3)',
          border:'1.5px solid var(--tt-line-3)',
          display:'grid', placeItems:'center',
        }}>
          <svg width="9" height="10" viewBox="0 0 9 10">
            <rect x="1.6" y="4.4" width="5.8" height="4.6" rx="0.9" fill="#98a1ac"/>
            <path d="M2.6 4.4 v-1.6 a1.9 1.9 0 013.8 0 V4.4" stroke="#98a1ac" strokeWidth="1" fill="none"/>
          </svg>
        </div>
      )}

      {/* Drifting embers above the hero medallion */}
      {large && unlocked && (
        <>
          {[
            { sx:'10px',  sy:'-22px', d:0.0 },
            { sx:'-14px', sy:'-18px', d:0.7 },
            { sx:'18px',  sy:'-30px', d:1.4 },
            { sx:'-6px',  sy:'-26px', d:2.1 },
          ].map((s, i) => (
            <div key={i} style={{
              position:'absolute', top:'30%', left:'50%',
              width:5, height:5,
              background:`radial-gradient(circle, #ffe9c2, ${r.fill} 55%, transparent 75%)`,
              borderRadius:'50%',
              '--sx': s.sx, '--sy': s.sy,
              animation:`ach-spark-rise 2.6s ${s.d}s ease-out infinite`,
              pointerEvents:'none',
              filter:'blur(0.2px)',
            }}/>
          ))}
        </>
      )}
    </div>
  );
}

function SettingsList() {
  const groups = [
    {
      title: 'TETHER',
      items: [
        { icon:'tether',   label:'Base-camp pairing',   sub:'1 PC paired · 14 days', value:'Manage' },
        { icon:'eye',      label:'Live tracking',       sub:'Always-on when hiking',  toggle:true },
        { icon:'bell',     label:'Notifications',       sub:'Alerts, weather, hazards', value:'On' },
      ],
    },
    {
      title: 'DATA',
      items: [
        { icon:'heart',    label:'Health Connect',      sub:'Synced 2m ago',          synced:true },
        { icon:'route',    label:'Offline maps',        sub:'Drakensberg N · 312 MB', value:'Manage' },
        { icon:'history',  label:'Hike history',        sub:'47 hikes · 12.4 MB',     value:'Export' },
      ],
    },
    {
      title: 'ACCOUNT',
      items: [
        { icon:'user',     label:'Edit profile',        sub:'Name, bio, photo' },
        { icon:'shield',   label:'Privacy & data',      sub:'No data sold · No ads' },
        { icon:'phone',    label:'Emergency contacts',  sub:'3 contacts saved' },
      ],
    },
  ];
  return (
    <div style={{marginTop:20, display:'flex', flexDirection:'column', gap:18}}>
      {groups.map((g, gi) => (
        <div key={g.title} className="anim-up" style={{animationDelay:`${800 + gi*80}ms`}}>
          <div style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)', marginBottom:8, paddingLeft:2}}>{g.title}</div>
          <div className="card" style={{padding:0, overflow:'hidden'}}>
            {g.items.map((it, idx) => (
              <SettingRow key={it.label} {...it} isLast={idx === g.items.length-1}/>
            ))}
          </div>
        </div>
      ))}

      {/* Sign out */}
      <button className="pressable anim-up" style={{
        marginTop:6,
        padding:'14px',
        background:'transparent',
        border:'1px solid rgba(230,61,46,0.32)',
        borderRadius:12,
        color:'var(--tt-red)',
        font:'800 12px var(--tt-font)', letterSpacing:'0.16em',
        cursor:'pointer',
        animationDelay:'1100ms',
      }}>
        SIGN OUT
      </button>

      {/* Footer */}
      <div style={{textAlign:'center', padding:'10px 0', font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-4)', letterSpacing:'0.16em', lineHeight:1.6}}>
        TRAILTETHER v2.0.4<br/>
        FREE · NO ADS · BUILT IN SOUTH AFRICA, FOR SOUTH AFRICANS
      </div>
    </div>
  );
}

function SettingRow({ icon, label, sub, value, toggle, synced, isLast }) {
  const [on, setOn] = React.useState(true);
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'13px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
      cursor:'pointer',
    }}>
      <div style={{
        width:34, height:34, borderRadius:9,
        background:'rgba(255,255,255,0.03)',
        border:'1px solid var(--tt-line-2)',
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name={icon} size={14} color="var(--tt-ember)"/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'700 13px var(--tt-font)', color:'var(--tt-text)'}}>{label}</div>
        {sub && <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em'}}>{sub}</div>}
      </div>

      {toggle && (
        <button onClick={(e) => { e.stopPropagation(); setOn(o => !o); }} style={{
          width:44, height:24, borderRadius:14,
          background: on ? 'var(--tt-ember)' : 'var(--tt-surf-3)',
          border: 'none',
          cursor:'pointer',
          position:'relative',
          transition:'background 250ms ease',
          boxShadow: on ? 'inset 0 0 10px rgba(0,0,0,0.4)' : 'none',
          padding:0,
        }}>
          <div style={{
            position:'absolute',
            top:3, left: on ? 22 : 3,
            width:18, height:18, borderRadius:'50%',
            background:'#fff',
            transition:'left 250ms cubic-bezier(0.2,0.7,0.2,1)',
            boxShadow:'0 2px 4px rgba(0,0,0,0.3)',
          }}/>
        </button>
      )}

      {synced && (
        <span style={{display:'inline-flex', alignItems:'center', gap:5, padding:'4px 8px', borderRadius:6, background:'rgba(76,195,138,0.13)', border:'1px solid rgba(76,195,138,0.3)', font:'800 9px var(--tt-mono)', color:'var(--tt-green)', letterSpacing:'0.12em'}}>
          <Icon name="check" size={10} color="var(--tt-green)" strokeWidth={2.4}/>
          SYNCED
        </span>
      )}

      {value && !toggle && !synced && (
        <span style={{font:'700 11px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.04em'}}>{value}</span>
      )}

      {!toggle && !synced && (
        <Icon name="chevron-right" size={14} color="var(--tt-text-3)"/>
      )}
    </div>
  );
}

window.ScreenProfile = ScreenProfile;

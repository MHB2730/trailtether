// Trailtether — Trail Detail (interactive aerial map + synced elevation scrubber)

/* ========================================================================
   TRAIL DATA — the single source of truth for everything on this screen.
   ======================================================================== */
const TRAIL = {
  name: 'Mt. Marcy Summit Trail',
  region: 'Drakensberg N · Cathedral Peak',
  totalKm: 12.4,
  ascent: 1205,
  duration: '5–7 hrs',
  difficulty: 'Difficult',
  techGrade: 'Class 3',
  rating: 4.7,
  reports: 312,
  base: 480,

  // [km, elevation_m] — used to render the elevation profile and to
  // interpolate the readout while scrubbing.
  elev: [
    [0, 480], [0.4, 510], [0.8, 540], [1.2, 580], [1.6, 640], [2.1, 720],
    [2.5, 790], [3.0, 870], [3.5, 955], [4.0, 1040], [4.5, 1120],
    [5.0, 1180], [5.4, 1225], [5.8, 1280], [6.2, 1365], [6.5, 1440],
    [7.0, 1530], [7.2, 1580], [7.6, 1605], [8.0, 1620], [8.5, 1640],
    [9.2, 1685], [9.8, 1720], [10.5, 1740], [11.0, 1755], [11.4, 1710],
    [12.0, 1695], [12.4, 1685],
  ],

  // Trail broken into difficulty-banded sections (the elevation chart
  // colors each km-range according to these).
  segments: [
    { km0: 0,    km1: 2.1,  diff: 'easy', name: 'Pine Approach',
      body: 'Wide gravel path through pine forest. Gentle climb on a well-graded surface.' },
    { km0: 2.1,  km1: 4.5,  diff: 'mod',  name: 'Switchback Climb',
      body: 'Steady 8% grade over loose dirt. Two stream crossings — slippery after rain.' },
    { km0: 4.5,  km1: 5.8,  diff: 'mod',  name: 'Sunrise Camp Ridge',
      body: 'Exposed walking on a broad ridge. Cave #47 sits at km 5.8 — water + 6 sleepers.' },
    { km0: 5.8,  km1: 7.2,  diff: 'hard', name: 'Technical Scramble',
      body: 'Class 3 hands-on scramble across a granite spine. Helmet strongly recommended.' },
    { km0: 7.2,  km1: 9.2,  diff: 'mod',  name: 'Cathedral Spine',
      body: '1.5 km of narrow ridge with sustained exposure. Bail at Cave #62 if winds shift.' },
    { km0: 9.2,  km1: 12.4, diff: 'hard', name: 'Summit Push',
      body: 'Boulder field then summit cone. Loose scree above 2,500 m. Crampons in shoulder season.' },
  ],

  // Hazards and points-of-interest along the route. km drives the position
  // on both the aerial map (via the path) and the elevation chart.
  hazards: [
    { km: 4.2,  kind: 'water',   label: 'Stream crossing',         desc: 'Slippery in rain. Use poles.' },
    { km: 5.8,  kind: 'shelter', label: 'Cave #47 · Sunrise Camp', desc: '6 sleepers · water available · R30 use' },
    { km: 6.5,  kind: 'danger',  label: 'Class 3 scramble',         desc: 'Hands-on · 80 m exposure on right' },
    { km: 8.6,  kind: 'view',    label: 'Eagle Col viewpoint',      desc: 'Best photo spot · cellular signal' },
    { km: 9.2,  kind: 'shelter', label: 'Cave #62 · Cathedral',     desc: '4 sleepers · dry · no water' },
    { km: 11.4, kind: 'danger',  label: 'Loose scree section',      desc: 'Bad footing · keep wide spacing' },
    { km: 12.4, kind: 'summit',  label: 'Summit · Mt. Marcy',       desc: '1,685 m · 360° views' },
  ],

  // SVG path for the aerial map (viewBox 412×260) — the start of the path
  // is the trailhead, the end is the summit.
  mapPathD:
    'M 32,236 C 56,228 82,238 108,224 S 152,200 188,184 ' +
    'S 232,160 256,138 S 282,118 298,98 ' +
    'S 332,76 354,60 S 386,42 402,30',

  // Preparation guidance
  prep: {
    water:       '2.5 L minimum',
    food:        'Two meals + 4 trail snacks',
    layers:      'Rain shell, fleece, beanie',
    safety:      'First-aid + headlamp + whistle',
    permit:      'Day permit · R30 at the gate',
    startBy:     '06:00 · before the heat',
    turnAround:  '13:00 · weather window closes',
    cellSignal:  'Patchy · Cave #47 and Eagle Col only',
  },
};

const DIFF = {
  easy: { color: '#4cc38a', label: 'Easy',      glyph: '●' },
  mod:  { color: '#f2a93b', label: 'Moderate',  glyph: '◆' },
  hard: { color: '#ff6a2c', label: 'Difficult', glyph: '▲' },
};

const HAZARD_META = {
  water:   { color: '#5aa1d6', icon: 'wind',     glyph: '~' },
  shelter: { color: '#4cc38a', icon: 'rock',     glyph: '⌂' },
  danger:  { color: '#e63d2e', icon: 'alert',    glyph: '!' },
  view:    { color: '#f2a93b', icon: 'eye',      glyph: '◉' },
  summit:  { color: '#ff6a2c', icon: 'mountain', glyph: '▲' },
};

/* ========================================================================
   Helpers
   ======================================================================== */
function elevAtKm(km) {
  const e = TRAIL.elev;
  if (km <= e[0][0]) return e[0][1];
  if (km >= e[e.length - 1][0]) return e[e.length - 1][1];
  for (let i = 0; i < e.length - 1; i++) {
    if (km >= e[i][0] && km <= e[i + 1][0]) {
      const t = (km - e[i][0]) / (e[i + 1][0] - e[i][0]);
      return e[i][1] + (e[i + 1][1] - e[i][1]) * t;
    }
  }
  return 0;
}
function segmentAtKm(km) {
  return TRAIL.segments.find((s) => km >= s.km0 && km <= s.km1) || TRAIL.segments[0];
}

/* ========================================================================
   Screen
   ======================================================================== */
function ScreenTrailDetail() {
  return (
    <div className="phone">
      <div className="punchhole" />
      <div className="screen">
        <StatusBar
          time="10:09"
          right={<span style={{ color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4 }}>LTE</span>}
        />

        {/* Compact app bar with back */}
        <div className="tt-appbar anim-in" style={{ paddingBottom:8 }}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4} /></button>
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em' }}>TRAIL DETAIL</div>
          </div>
          <button className="icon-btn"><Icon name="heart" size={15} color="var(--tt-ember)" /></button>
          <button className="icon-btn"><Icon name="send-fill" size={14} color="var(--tt-text-2)" /></button>
        </div>

        <div className="tt-scroll">
          <TrailHeroImage />

          <div style={{ padding:'0 18px 24px' }}>
            <TrailTitleCard />
            <TrailStatsRow />
            <InteractiveTrailExplorer />
            <TrailSections />
            <TrailHazardsOnRoute />
            <TrailPrep />
            <TrailDescription />
            <TrailReviews />
            <TrailCaves />

            <div style={{ height:60 }} />
          </div>
        </div>

        {/* Sticky CTA */}
        <div style={{
          position:'absolute', left:0, right:0, bottom:0,
          padding:'14px 18px 16px',
          background:'linear-gradient(180deg, transparent 0%, rgba(7,9,12,0.85) 30%, var(--tt-bg) 70%)',
          zIndex:5,
        }}>
          <button className="pressable" style={{
            width:'100%', height:54, borderRadius:14, border:'none',
            background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
            color:'#1a0d04',
            font:'900 13px var(--tt-font)', letterSpacing:'0.16em',
            cursor:'pointer',
            boxShadow:'var(--tt-shadow-ember)',
            display:'inline-flex', alignItems:'center', justifyContent:'center', gap:10,
            position:'relative', overflow:'hidden',
          }}>
            <span style={{
              position:'absolute', inset:0,
              background:'linear-gradient(120deg, transparent 30%, rgba(255,255,255,0.32) 50%, transparent 70%)',
              backgroundSize:'200% 100%',
              animation:'shimmer 4s infinite linear',
              pointerEvents:'none',
            }} />
            <Icon name="play" size={14} color="#1a0d04" />
            <span style={{ position:'relative' }}>START HIKE · {TRAIL.totalKm} KM</span>
          </button>
        </div>
      </div>
    </div>
  );
}

/* ========================================================================
   Header bits
   ======================================================================== */
function TrailHeroImage() {
  return (
    <div style={{ position:'relative', height:180, overflow:'hidden' }}>
      <img
        src="assets/hero_mountain.png"
        alt=""
        style={{
          position:'absolute', inset:0, width:'100%', height:'100%',
          objectFit:'cover', objectPosition:'center 60%',
          filter:'saturate(1.05) contrast(1.06) brightness(0.92)',
        }}
      />
      <div style={{ position:'absolute', inset:0, background:'linear-gradient(180deg, rgba(7,9,12,0.45) 0%, rgba(7,9,12,0) 35%, rgba(7,9,12,0.85) 95%, var(--tt-bg) 100%)' }} />

      <div style={{ position:'absolute', top:14, left:14, display:'flex', gap:6 }}>
        <span className="pill ember" style={{ height:24, padding:'0 10px' }}>FEATURED</span>
        <span className="pill" style={{ height:24, padding:'0 10px', background:'rgba(10,12,15,0.7)', backdropFilter:'blur(8px)' }}>CAVES NEARBY</span>
      </div>
    </div>
  );
}

function TrailTitleCard() {
  return (
    <div className="anim-up" style={{ marginTop:-30, position:'relative' }}>
      <div style={{ flex:1 }}>
        <div style={{ display:'flex', alignItems:'center', gap:6, font:'600 10.5px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.12em' }}>
          <Icon name="pin" size={11} color="var(--tt-ember)" />
          {TRAIL.region.toUpperCase()}
        </div>
        <h2 style={{ margin:'6px 0 0', font:'900 26px var(--tt-font)', letterSpacing:'-0.025em', color:'var(--tt-text)' }}>{TRAIL.name}</h2>
        <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:8 }}>
          <span style={{ display:'inline-flex', alignItems:'center', gap:5, padding:'3px 9px', borderRadius:6,
            background:'rgba(255,106,44,0.15)', border:'1px solid rgba(255,106,44,0.4)',
            font:'800 9.5px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.14em' }}>
            ▲ {TRAIL.difficulty.toUpperCase()} · {TRAIL.techGrade.toUpperCase()}
          </span>
          <span style={{ display:'inline-flex', alignItems:'center', gap:4, font:'700 11px var(--tt-font)', color:'var(--tt-text-2)' }}>
            ★ <span className="num" style={{ color:'var(--tt-text)', fontWeight:800 }}>{TRAIL.rating}</span>
            <span style={{ color:'var(--tt-text-3)' }}>({TRAIL.reports})</span>
          </span>
        </div>
      </div>
    </div>
  );
}

function TrailStatsRow() {
  const stats = [
    { label:'Distance', value:TRAIL.totalKm.toString(), unit:'km',  icon:'navigation' },
    { label:'Ascent',   value:TRAIL.ascent.toLocaleString(), unit:'m', icon:'arrow-up', ember:true },
    { label:'Duration', value:TRAIL.duration.replace('hrs','').trim(), unit:'h', icon:'clock' },
    { label:'Grade',    value:TRAIL.techGrade.replace('Class ',''), unit:'class', icon:'rock' },
  ];
  return (
    <div style={{
      display:'grid', gridTemplateColumns:'repeat(4, 1fr)',
      marginTop:14, padding:'12px 0',
      background:'var(--tt-surf)',
      border:'1px solid var(--tt-line)',
      borderRadius:14,
    }}>
      <Stagger base={150} delay={60}>
        {stats.map((s, i) => (
          <div key={s.label} style={{ textAlign:'center', borderLeft: i === 0 ? 'none' : '1px solid var(--tt-line)', padding:'0 4px' }}>
            <div style={{ display:'inline-flex', alignItems:'center', gap:4,
              font:'700 9.5px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-3)' }}>
              <Icon name={s.icon} size={11} color={s.ember ? 'var(--tt-ember)' : 'var(--tt-text-3)'} />
              {s.label}
            </div>
            <div style={{ display:'flex', alignItems:'baseline', gap:3, justifyContent:'center', marginTop:6 }}>
              <span className="num count-up" style={{ font:'800 18px var(--tt-mono)', color:s.ember ? 'var(--tt-ember)' : 'var(--tt-text)', letterSpacing:'-0.02em' }}>{s.value}</span>
              <span className="num" style={{ fontSize:9, color:'var(--tt-text-2)', fontWeight:600, letterSpacing:'0.02em' }}>{s.unit}</span>
            </div>
          </div>
        ))}
      </Stagger>
    </div>
  );
}

/* ========================================================================
   Interactive Trail Explorer — the showpiece.
   Aerial map up top, elevation scrubber below. Drag (or tap) anywhere on
   the elevation chart and the marker walks along the trail on the map.
   ======================================================================== */
function InteractiveTrailExplorer() {
  const [progress, setProgress] = React.useState(0.42);
  const [dragging, setDragging] = React.useState(false);
  const mapPathRef = React.useRef(null);
  const elevRef = React.useRef(null);
  const [marker, setMarker] = React.useState({ x:0, y:0, angle:0 });

  // Recompute marker position whenever progress changes
  React.useEffect(() => {
    if (!mapPathRef.current) return;
    const L = mapPathRef.current.getTotalLength();
    const p = mapPathRef.current.getPointAtLength(progress * L);
    const ahead = Math.min(progress + 0.002, 1);
    const pa = mapPathRef.current.getPointAtLength(ahead * L);
    const angle = (Math.atan2(pa.y - p.y, pa.x - p.x) * 180) / Math.PI;
    setMarker({ x: p.x, y: p.y, angle });
  }, [progress]);

  // Initial mount — re-trigger once after refs are wired
  React.useEffect(() => { setProgress(p => p); }, []);

  const km = progress * TRAIL.totalKm;
  const elev = elevAtKm(km);
  const seg = segmentAtKm(km);
  const segMeta = DIFF[seg.diff];

  // Nearest hazard (within 0.3 km of current scrub position)
  const nearbyHazard = TRAIL.hazards
    .map(h => ({ ...h, dist: Math.abs(h.km - km) }))
    .filter(h => h.dist <= 0.4)
    .sort((a,b) => a.dist - b.dist)[0];

  const setFromEvent = (e) => {
    if (!elevRef.current) return;
    const rect = elevRef.current.getBoundingClientRect();
    const cx = (e.touches ? e.touches[0].clientX : e.clientX);
    const p = Math.max(0, Math.min(1, (cx - rect.left) / rect.width));
    setProgress(p);
  };

  return (
    <div className="card anim-up" style={{ marginTop:14, padding:'14px 14px 12px', animationDelay:'250ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>
          Trail Explorer
        </span>
        <span style={{ font:'800 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.14em' }}>
          DRAG TO PREVIEW
        </span>
      </div>

      {/* Aerial map */}
      <AerialMap mapPathRef={mapPathRef} marker={marker} />

      {/* Readout — what's at the scrub position */}
      <div style={{
        display:'flex', alignItems:'center', gap:10,
        marginTop:10, padding:'10px 12px',
        background:'var(--tt-bg-3)', border:'1px solid var(--tt-line)',
        borderRadius:10,
      }}>
        <div style={{
          width:34, height:34, borderRadius:9,
          background:`${segMeta.color}1f`, border:`1px solid ${segMeta.color}55`,
          display:'grid', placeItems:'center', flex:'0 0 auto',
          color:segMeta.color, font:'800 14px var(--tt-mono)',
        }}>{segMeta.glyph}</div>
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ display:'flex', alignItems:'baseline', gap:8 }}>
            <span className="num" style={{ font:'800 16px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.02em' }}>
              {km.toFixed(1)}<span style={{ fontSize:10, color:'var(--tt-text-2)', marginLeft:2, fontWeight:600 }}>km</span>
            </span>
            <span style={{ color:'var(--tt-line-3)' }}>·</span>
            <span className="num" style={{ font:'800 14px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'-0.01em' }}>
              {Math.round(elev).toLocaleString()}<span style={{ fontSize:10, color:'var(--tt-text-2)', marginLeft:2, fontWeight:600 }}>m</span>
            </span>
          </div>
          <div style={{ display:'flex', alignItems:'center', gap:6, marginTop:2,
            font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.08em' }}>
            <span style={{ color: segMeta.color, fontWeight:800 }}>{seg.name.toUpperCase()}</span>
            <span style={{ color:'var(--tt-line-3)' }}>·</span>
            <span>{segMeta.label.toUpperCase()}</span>
          </div>
        </div>
        {nearbyHazard && (
          <div style={{
            padding:'4px 8px', borderRadius:6,
            background:`${HAZARD_META[nearbyHazard.kind].color}1f`,
            border:`1px solid ${HAZARD_META[nearbyHazard.kind].color}55`,
            color:HAZARD_META[nearbyHazard.kind].color,
            font:'800 9px var(--tt-mono)', letterSpacing:'0.12em',
            flex:'0 0 auto',
          }}>
            {HAZARD_META[nearbyHazard.kind].glyph} {nearbyHazard.label.toUpperCase()}
          </div>
        )}
      </div>

      {/* Elevation scrubber */}
      <div
        ref={elevRef}
        onMouseDown={(e) => { setDragging(true); setFromEvent(e); }}
        onMouseMove={(e) => { if (dragging) setFromEvent(e); }}
        onMouseUp={() => setDragging(false)}
        onMouseLeave={() => setDragging(false)}
        onTouchStart={(e) => { setDragging(true); setFromEvent(e); }}
        onTouchMove={(e) => { setFromEvent(e); }}
        onTouchEnd={() => setDragging(false)}
        style={{
          marginTop:10, position:'relative',
          cursor: dragging ? 'grabbing' : 'grab',
          userSelect:'none', touchAction:'none',
        }}
      >
        <ElevationChart progress={progress} dragging={dragging} />
      </div>

      <div style={{ display:'flex', justifyContent:'space-between', marginTop:6,
        font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.06em' }}>
        <span>0 km</span>
        <span>{(TRAIL.totalKm/2).toFixed(1)} km</span>
        <span>{TRAIL.totalKm} km</span>
      </div>
    </div>
  );
}

/* ========================================================================
   Aerial map — stylized topographic view with terrain, contours, river,
   trail line, hazard pips, and the moving marker.
   ======================================================================== */
function AerialMap({ mapPathRef, marker }) {
  return (
    <div style={{ position:'relative', height:200, borderRadius:11, overflow:'hidden',
      background:'#0a1218', border:'1px solid var(--tt-line)' }}>
      <svg viewBox="0 0 412 260" preserveAspectRatio="xMidYMid slice"
        style={{ position:'absolute', inset:0, width:'100%', height:'100%', display:'block' }}>
        <defs>
          <radialGradient id="amTerr" cx="50%" cy="55%" r="70%">
            <stop offset="0%"  stopColor="#1a2820" stopOpacity="0.9" />
            <stop offset="60%" stopColor="#11181e" stopOpacity="0.7" />
            <stop offset="100%" stopColor="#06090c" stopOpacity="0.4" />
          </radialGradient>
          <linearGradient id="amRidge" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#1f2a24" />
            <stop offset="100%" stopColor="#0a0e10" />
          </linearGradient>
          <filter id="amTrailGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="2.2" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>
        <rect width="412" height="260" fill="url(#amTerr)" />

        {/* Contour lines */}
        <g fill="none" stroke="#1a2820" strokeWidth="0.5" opacity="0.7">
          {[
            'M-20,250 Q90,242 200,238 T440,246',
            'M-20,225 Q100,215 200,210 T440,222',
            'M-20,200 Q100,182 220,188 T440,200',
            'M0,175 Q120,150 230,162 T440,180',
            'M20,150 Q130,118 240,132 T440,156',
            'M40,125 Q140,90 250,108 T420,132',
            'M70,100 Q160,68 250,88 T400,110',
            'M100,80 Q190,52 250,72 T380,90',
            'M130,60 Q200,40 250,58 T360,70',
          ].map((d, i) => <path key={i} d={d} />)}
        </g>
        <g fill="none" stroke="#2a3a30" strokeWidth="0.45" opacity="0.5">
          {[
            'M-20,235 Q90,230 200,224 T440,232',
            'M-20,212 Q100,200 200,196 T440,210',
            'M-20,188 Q100,170 220,176 T440,188',
            'M0,160 Q120,138 230,148 T440,168',
            'M20,135 Q130,108 240,120 T440,144',
          ].map((d, i) => <path key={i} d={d} />)}
        </g>

        {/* Lakes / forest patches */}
        <ellipse cx="60"  cy="246" rx="18" ry="6" fill="#152a3c" opacity="0.7" />
        <ellipse cx="312" cy="84"  rx="10" ry="4" fill="#152a3c" opacity="0.6" />
        <g opacity="0.5">
          <circle cx="86"  cy="216" r="14" fill="#1a2a1f" />
          <circle cx="124" cy="200" r="11" fill="#1a2a1f" />
          <circle cx="46"  cy="200" r="9"  fill="#1a2a1f" />
        </g>

        {/* River */}
        <path d="M -10 250 C 40 246 80 252 124 248 S 196 244 240 230 S 312 196 360 178"
              fill="none" stroke="rgba(90,161,214,0.5)" strokeWidth="1.6"
              strokeLinecap="round" />

        {/* Ridge shading where the trail will run */}
        <path d="M 16 244 L 60 232 L 116 220 L 168 196 L 220 168 L 268 140 L 312 110 L 360 80 L 412 56 L 412 260 L 16 260 Z"
              fill="url(#amRidge)" opacity="0.55" />

        {/* Trail — wide glow + sharp top stroke */}
        <path d={TRAIL.mapPathD}
              fill="none" stroke="#ff6a2c" strokeOpacity="0.5"
              strokeWidth="5" strokeLinecap="round" filter="url(#amTrailGlow)" />
        <path
          ref={mapPathRef}
          d={TRAIL.mapPathD}
          fill="none" stroke="#ff8a4d"
          strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />

        {/* km labels along the trail */}
        {[2, 4, 6, 8, 10].map((kmVal) => {
          const t = kmVal / TRAIL.totalKm;
          const pos = pointAlongTrail(t);
          if (!pos) return null;
          return (
            <g key={kmVal} transform={`translate(${pos.x + 6},${pos.y - 2})`}>
              <circle r="3" fill="#0a0c0f" stroke="#ff8a4d" strokeWidth="1.2" />
              <text x="6" y="3" fill="#ff8a4d" fontFamily="JetBrains Mono"
                    fontSize="8" fontWeight="800" letterSpacing="0.04em">{kmVal}</text>
            </g>
          );
        })}

        {/* Hazard pips on the trail */}
        {TRAIL.hazards.map((h, i) => {
          const t = h.km / TRAIL.totalKm;
          const pos = pointAlongTrail(t);
          if (!pos) return null;
          const m = HAZARD_META[h.kind];
          return (
            <g key={i} transform={`translate(${pos.x},${pos.y})`}>
              <circle r="6" fill="#0a0c0f" stroke={m.color} strokeWidth="1.5" />
              <text y="2.5" textAnchor="middle" fill={m.color}
                    fontFamily="JetBrains Mono" fontSize="7.5" fontWeight="900">{m.glyph}</text>
            </g>
          );
        })}

        {/* Trailhead + summit */}
        <g transform="translate(32,236)">
          <rect x="-5" y="-5" width="10" height="10" transform="rotate(45)"
                fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1.5" />
        </g>
        <g transform="translate(402,30)">
          <path d="M 0 -8 L 7 6 L -7 6 Z" fill="#ff6a2c" stroke="#fff4d6" strokeWidth="1.2" />
        </g>

        {/* The walking marker — pulses + rotates with trail tangent */}
        <g transform={`translate(${marker.x},${marker.y})`}>
          <circle r="14" fill="rgba(255,255,255,0.10)">
            <animate attributeName="r" values="11;16;11" dur="2.4s" repeatCount="indefinite" />
          </circle>
          <circle r="9" fill="rgba(255,255,255,0.18)" />
          <circle r="6" fill="#fff" stroke="#ff6a2c" strokeWidth="2" />
          <g transform={`rotate(${marker.angle})`}>
            <path d="M 0 -1.6 L 3.4 4 L 0 2.2 L -3.4 4 Z" fill="#ff6a2c" />
          </g>
        </g>
      </svg>

      {/* North arrow + scale */}
      <div style={{
        position:'absolute', top:8, right:8,
        display:'inline-flex', alignItems:'center', gap:5,
        padding:'4px 7px', borderRadius:6,
        background:'rgba(10,12,15,0.78)', backdropFilter:'blur(6px)',
        border:'1px solid var(--tt-line-2)',
        font:'800 9px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'0.12em',
      }}>
        <svg width="9" height="11" viewBox="0 0 9 11">
          <path d="M 4.5 0 L 9 11 L 4.5 8 L 0 11 Z" fill="#ff6a2c" />
        </svg>
        N
      </div>
      <div style={{
        position:'absolute', bottom:8, left:8,
        display:'inline-flex', alignItems:'center', gap:6,
        background:'rgba(10,12,15,0.78)', backdropFilter:'blur(6px)',
        border:'1px solid var(--tt-line-2)', borderRadius:6,
        padding:'4px 7px',
      }}>
        <div style={{ display:'flex' }}>
          <div style={{ width:16, height:3, background:'#eef1f4' }} />
          <div style={{ width:16, height:3, background:'#0a0c0f', border:'1px solid #eef1f4' }} />
        </div>
        <span className="num" style={{ fontSize:9, color:'var(--tt-text)', fontWeight:700, letterSpacing:'0.04em' }}>500 m</span>
      </div>
    </div>
  );
}

// Helper to compute an approximate point along the trail without needing
// a DOM ref — used by static elements (km labels, hazard pips).
function pointAlongTrail(t) {
  // Sample the cubic path from TRAIL.mapPathD using a small parameter
  // marching scheme. We mirror the rough shape here to avoid having to
  // create a hidden DOM path.
  const samples = [
    { x: 32,  y: 236 }, { x: 60,  y: 230 }, { x: 92,  y: 224 },
    { x: 124, y: 216 }, { x: 156, y: 202 }, { x: 188, y: 184 },
    { x: 220, y: 168 }, { x: 252, y: 148 }, { x: 280, y: 122 },
    { x: 308, y: 96  }, { x: 340, y: 74  }, { x: 372, y: 52  },
    { x: 402, y: 30  },
  ];
  const idx = t * (samples.length - 1);
  const i = Math.floor(idx);
  const u = idx - i;
  const a = samples[Math.max(0, Math.min(samples.length - 1, i))];
  const b = samples[Math.max(0, Math.min(samples.length - 1, i + 1))];
  return { x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u };
}

/* ========================================================================
   Elevation chart — colored area by segment difficulty + hazard pips
   along the bottom + draggable thumb at progress position.
   ======================================================================== */
function ElevationChart({ progress, dragging }) {
  const W = 320, H = 110, padL = 4, padR = 4, padT = 4, padB = 22;
  const e = TRAIL.elev;
  const min = 400, max = 1800;
  const x = (km) => padL + (km / TRAIL.totalKm) * (W - padL - padR);
  const y = (el) => H - padB - ((el - min) / (max - min)) * (H - padT - padB);

  // Build the elevation polyline
  const linePath = e.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(p[0]).toFixed(1)},${y(p[1]).toFixed(1)}`).join(' ');
  const fillPath = linePath + ` L ${x(TRAIL.totalKm).toFixed(1)},${H - padB} L ${padL},${H - padB} Z`;

  // Difficulty band rects under the elevation line — color the chart by km range
  const bands = TRAIL.segments.map((s) => ({
    x: x(s.km0),
    w: x(s.km1) - x(s.km0),
    color: DIFF[s.diff].color,
  }));

  const cursorX = x(progress * TRAIL.totalKm);
  const cursorY = y(elevAtKm(progress * TRAIL.totalKm));

  return (
    <svg width="100%" height={H + 8} viewBox={`0 0 ${W} ${H + 8}`}
         style={{ display:'block', overflow:'visible' }} preserveAspectRatio="none">
      <defs>
        <linearGradient id="elArea" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"  stopColor="#ff6a2c" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </linearGradient>
      </defs>

      {/* Difficulty bands behind the area — colored strips at the bottom */}
      <g>
        {bands.map((b, i) => (
          <rect key={i} x={b.x} y={H - padB - 2} width={b.w} height={6}
                fill={b.color} opacity="0.85" />
        ))}
      </g>

      {/* Reference elevation grid */}
      {[800, 1200, 1600].map((v) => {
        const gy = y(v);
        return (
          <g key={v}>
            <line x1={padL} x2={W - padR} y1={gy} y2={gy} stroke="rgba(255,255,255,0.05)" />
            <text x={W - padR - 2} y={gy - 2} textAnchor="end" fill="#5a6470"
                  fontFamily="JetBrains Mono" fontSize="7.5" fontWeight="700">{v}m</text>
          </g>
        );
      })}

      {/* Elevation area + line */}
      <path d={fillPath} fill="url(#elArea)" />
      <path d={linePath} fill="none" stroke="#ff8a4d" strokeWidth="1.6"
            strokeLinejoin="round" strokeLinecap="round" />

      {/* Hazard pips along the bottom */}
      {TRAIL.hazards.map((h, i) => {
        const m = HAZARD_META[h.kind];
        const hx = x(h.km);
        return (
          <g key={i} transform={`translate(${hx}, ${H - padB + 14})`}>
            <circle r="4" fill="#0a0c0f" stroke={m.color} strokeWidth="1.1" />
            <text y="1.8" textAnchor="middle" fill={m.color}
                  fontFamily="JetBrains Mono" fontSize="5.5" fontWeight="900">{m.glyph}</text>
          </g>
        );
      })}

      {/* Vertical scrub indicator + thumb */}
      <g>
        <line x1={cursorX} x2={cursorX} y1={padT} y2={H - padB}
              stroke="rgba(255,255,255,0.55)" strokeWidth="0.8" strokeDasharray="2 2" />
        <line x1={cursorX} x2={cursorX} y1={padT} y2={cursorY}
              stroke="#fff" strokeWidth="1.2" />
        {/* Tag floating above */}
        <g transform={`translate(${cursorX}, ${Math.max(cursorY - 14, padT + 4)})`}>
          <rect x="-18" y="-10" width="36" height="14" rx="3"
                fill="#1a0d04" stroke="#ff6a2c" strokeWidth="0.9" />
          <text y="0.5" textAnchor="middle" fill="#ff8a4d"
                fontFamily="JetBrains Mono" fontSize="8" fontWeight="900"
                letterSpacing="0.04em">{Math.round(elevAtKm(progress * TRAIL.totalKm))}m</text>
        </g>
        {/* Thumb */}
        <circle cx={cursorX} cy={cursorY} r={dragging ? 6.5 : 5}
                fill="#fff" stroke="#ff6a2c" strokeWidth="2"
                style={{ filter: dragging ? 'drop-shadow(0 0 8px rgba(255,106,44,0.8))' : 'drop-shadow(0 0 4px rgba(255,106,44,0.5))', transition:'r 150ms ease' }} />
      </g>
    </svg>
  );
}

/* ========================================================================
   Trail sections — segment-by-segment breakdown
   ======================================================================== */
function TrailSections() {
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'350ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>
          Sections
        </span>
        <span style={{ font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)' }}>
          {TRAIL.segments.length} STAGES
        </span>
      </div>

      <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
        {TRAIL.segments.map((s, i) => {
          const m = DIFF[s.diff];
          return (
            <div key={i} className="pressable" style={{
              display:'flex', gap:12,
              padding:'12px 14px',
              background:'var(--tt-surf)',
              border:`1px solid ${m.color}33`,
              borderLeft:`3px solid ${m.color}`,
              borderRadius:11,
              cursor:'pointer',
            }}>
              <div style={{
                width:34, height:34, borderRadius:9,
                background:`${m.color}1f`, border:`1px solid ${m.color}55`,
                display:'grid', placeItems:'center', flex:'0 0 auto',
                font:'900 14px var(--tt-mono)', color:m.color,
              }}>{i + 1}</div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ display:'flex', alignItems:'center', gap:8, flexWrap:'wrap' }}>
                  <span style={{ font:'800 13.5px var(--tt-font)', color:'var(--tt-text)' }}>{s.name}</span>
                  <span style={{
                    padding:'2px 6px', borderRadius:4,
                    background:`${m.color}1f`, border:`1px solid ${m.color}55`,
                    font:'800 8.5px var(--tt-mono)', color:m.color, letterSpacing:'0.12em',
                  }}>{m.label.toUpperCase()}</span>
                </div>
                <div style={{ font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.08em' }}>
                  KM {s.km0.toFixed(1)} – {s.km1.toFixed(1)} · {(s.km1 - s.km0).toFixed(1)} KM
                </div>
                <div style={{ font:'500 11.5px/1.45 var(--tt-font)', color:'var(--tt-text-2)', marginTop:5 }}>
                  {s.body}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ========================================================================
   Hazards on route
   ======================================================================== */
function TrailHazardsOnRoute() {
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'450ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>
          On Route
        </span>
        <span style={{ font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)' }}>
          {TRAIL.hazards.length} POINTS
        </span>
      </div>
      <div style={{ display:'flex', flexDirection:'column', gap:6 }}>
        {TRAIL.hazards.map((h, i) => {
          const m = HAZARD_META[h.kind];
          return (
            <div key={i} className="pressable" style={{
              display:'flex', alignItems:'center', gap:11,
              padding:'10px 12px',
              background:'var(--tt-surf)',
              border:`1px solid ${m.color}33`,
              borderRadius:10,
              cursor:'pointer',
            }}>
              <div style={{
                width:28, height:28, borderRadius:8,
                background:`${m.color}1f`, border:`1px solid ${m.color}55`,
                display:'grid', placeItems:'center', flex:'0 0 auto',
                color:m.color, font:'900 12px var(--tt-mono)',
              }}>{m.glyph}</div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ font:'800 12.5px var(--tt-font)', color:'var(--tt-text)' }}>{h.label}</div>
                <div style={{ font:'500 10.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em' }}>{h.desc}</div>
              </div>
              <span className="num" style={{ font:'800 11px var(--tt-mono)', color:m.color, letterSpacing:'-0.01em', flex:'0 0 auto' }}>
                {h.km.toFixed(1)} km
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ========================================================================
   Preparation
   ======================================================================== */
function TrailPrep() {
  const items = [
    { icon:'wind',       label:'Water',       value:TRAIL.prep.water },
    { icon:'flame',      label:'Food',        value:TRAIL.prep.food },
    { icon:'layers',     label:'Layers',      value:TRAIL.prep.layers },
    { icon:'shield',     label:'Safety',      value:TRAIL.prep.safety },
    { icon:'check',      label:'Permit',      value:TRAIL.prep.permit },
    { icon:'clock',      label:'Start by',    value:TRAIL.prep.startBy, ember:true },
    { icon:'alert',      label:'Turn around', value:TRAIL.prep.turnAround, ember:true },
    { icon:'radio',      label:'Cell signal', value:TRAIL.prep.cellSignal },
  ];
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'550ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>
          Preparation
        </span>
        <span style={{ font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em' }}>
          ADD TO PLAN →
        </span>
      </div>
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:6 }}>
        {items.map((it, i) => (
          <div key={i} style={{
            display:'flex', gap:9, alignItems:'flex-start',
            padding:'9px 10px',
            background:'var(--tt-surf)',
            border:`1px solid ${it.ember ? 'rgba(255,106,44,0.25)' : 'var(--tt-line)'}`,
            borderRadius:9,
          }}>
            <div style={{
              width:24, height:24, borderRadius:7,
              background: it.ember ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
              border:`1px solid ${it.ember ? 'rgba(255,106,44,0.36)' : 'var(--tt-line-2)'}`,
              display:'grid', placeItems:'center', flex:'0 0 auto',
            }}>
              <Icon name={it.icon} size={11} color={it.ember ? 'var(--tt-ember)' : 'var(--tt-text-2)'} />
            </div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ font:'700 9px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.14em' }}>{it.label.toUpperCase()}</div>
              <div style={{ font:'700 11.5px var(--tt-font)', color: it.ember ? 'var(--tt-ember)' : 'var(--tt-text)', marginTop:2, lineHeight:1.3 }}>{it.value}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ========================================================================
   Existing legacy bits (description / reviews / caves) — preserved
   ======================================================================== */
function TrailDescription() {
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'650ms' }}>
      <div style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)', marginBottom:8 }}>About</div>
      <div style={{ font:'500 12.5px/1.55 var(--tt-font)', color:'var(--tt-text-2)' }}>
        Strenuous out-and-back along the Cathedral spine. Expect exposed ridges, fast-changing weather, and one
        technical scramble at km 6.5. Two cave shelters are available mid-route. Start before 06:00 to summit
        before the afternoon front.
      </div>
    </div>
  );
}

function TrailReviews() {
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'750ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>Trail Reports</span>
        <span style={{ font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em' }}>SEE ALL →</span>
      </div>

      <div className="card" style={{ padding:'14px 16px', display:'flex', gap:14, alignItems:'center' }}>
        <div style={{ textAlign:'center', flex:'0 0 auto' }}>
          <div className="num count-up" style={{ font:'900 38px/1 var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.025em' }}>{TRAIL.rating}</div>
          <div style={{ display:'flex', justifyContent:'center', gap:1, marginTop:4, color:'#ff8a4d', fontSize:11 }}>★★★★★</div>
        </div>
        <div style={{ flex:1 }}>
          {[5,4,3,2,1].map((n, i) => {
            const w = [85, 12, 2, 1, 0][i];
            return (
              <div key={n} style={{ display:'flex', alignItems:'center', gap:6, marginBottom:3 }}>
                <span style={{ font:'700 9px var(--tt-mono)', color:'var(--tt-text-3)', width:8 }}>{n}</span>
                <div style={{ flex:1, height:4, background:'var(--tt-surf-2)', borderRadius:2, overflow:'hidden' }}>
                  <div style={{ height:'100%', width:`${w}%`,
                    background:'linear-gradient(90deg, #ff6a2c, #ff8a4d)', borderRadius:2 }} />
                </div>
                <span style={{ font:'700 9px var(--tt-mono)', color:'var(--tt-text-3)', width:24, textAlign:'right' }}>{w}%</span>
              </div>
            );
          })}
        </div>
      </div>

      <div className="card pressable" style={{ padding:'14px 16px', marginTop:10 }}>
        <div style={{ display:'flex', gap:11, alignItems:'center' }}>
          <div style={{
            width:34, height:34, borderRadius:'50%',
            background:'linear-gradient(135deg, #4cc38a, #4cc38aaa)',
            display:'grid', placeItems:'center',
            color:'#fff', font:'800 12px var(--tt-font)',
            border:'2px solid #4cc38a',
          }}>MK</div>
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ display:'flex', alignItems:'center', gap:6, justifyContent:'space-between' }}>
              <span style={{ font:'800 12.5px var(--tt-font)', color:'var(--tt-text)' }}>Mike K.</span>
              <span style={{ color:'#ff8a4d', fontSize:11 }}>★★★★★</span>
            </div>
            <div style={{ font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.06em' }}>4 DAYS AGO · COMPLETED 4h 51m</div>
          </div>
        </div>
        <div style={{ font:'500 12px/1.5 var(--tt-font)', color:'var(--tt-text-2)', marginTop:10 }}>
          Bridge at km 4 is washed out — went around via the upper switchback. Adds about 30 min.
          Scramble at km 6.5 is dry and grippy right now. Solid trail.
        </div>
      </div>
    </div>
  );
}

function TrailCaves() {
  return (
    <div className="anim-up" style={{ marginTop:18, animationDelay:'850ms' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
        <span style={{ font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)' }}>Shelter & Caves</span>
        <span style={{ font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)' }}>2 ON ROUTE</span>
      </div>
      <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
        <CaveRow name="Cave #47 · Sunrise Camp"   km="5.8 km" cap="6 sleepers" water />
        <CaveRow name="Cave #62 · Cathedral Lower" km="9.2 km" cap="4 sleepers" />
      </div>
    </div>
  );
}

function CaveRow({ name, km, cap, water }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'12px 14px',
      background:'var(--tt-surf)',
      border:'1px solid rgba(76,195,138,0.2)',
      borderLeft:'3px solid #4cc38a',
      borderRadius:11,
      cursor:'pointer',
    }}>
      <div style={{
        width:34, height:34, borderRadius:9,
        background:'rgba(76,195,138,0.13)',
        border:'1px solid rgba(76,195,138,0.32)',
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name="rock" size={15} color="#4cc38a" />
      </div>
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ font:'800 12.5px var(--tt-font)', color:'var(--tt-text)' }}>{name}</div>
        <div style={{ display:'flex', gap:10, marginTop:3, font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.04em' }}>
          <span>{km}</span>
          <span style={{ color:'var(--tt-line-3)' }}>·</span>
          <span>{cap}</span>
          {water && <><span style={{ color:'var(--tt-line-3)' }}>·</span><span style={{ color:'#5aa1d6' }}>💧 WATER</span></>}
        </div>
      </div>
      <Icon name="chevron-right" size={14} color="var(--tt-text-3)" />
    </div>
  );
}

window.ScreenTrailDetail = ScreenTrailDetail;

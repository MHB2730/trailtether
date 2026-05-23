// Trailtether — Trails list (browse all trails)
// Tappable cards open the Trail Detail screen.

const TRAILS_LIST = [
  {
    id: 'mt-marcy',
    name: 'Mt. Marcy Summit',
    region: 'Drakensberg N · Cathedral',
    diff: 'hard',           // easy | mod | hard | xhard
    km: 12.4,
    ascent: 1205,
    hrs: '5–7',
    rating: 4.7,
    reports: 312,
    tags: ['FEATURED', 'CAVES'],
    live: 3,                // hikers on trail right now
    // Mini-map signature path (viewBox 80×54)
    miniD: 'M 6 44 C 18 40 24 46 32 38 S 48 26 58 18 S 72 8 76 6',
    // Terrain swatch hint
    accent: '#f2a93b',
  },
  {
    id: 'sunset-ridge',
    name: 'Sunset Ridge Loop',
    region: 'Drakensberg N · Cathkin',
    diff: 'mod',
    km: 8.6,
    ascent: 620,
    hrs: '3–4',
    rating: 4.5,
    reports: 184,
    tags: ['SUNSET'],
    live: 7,
    miniD: 'M 6 32 C 18 24 26 36 36 30 S 52 20 60 30 S 72 38 76 32',
    accent: '#ff8a4d',
  },
  {
    id: 'cave-circuit',
    name: 'Cave Circuit',
    region: 'Drakensberg N · Mlambonja',
    diff: 'easy',
    km: 5.2,
    ascent: 210,
    hrs: '2',
    rating: 4.3,
    reports: 96,
    tags: ['CAVES', 'WATER'],
    live: 1,
    miniD: 'M 6 40 C 18 36 22 28 30 32 S 48 42 58 36 S 70 22 76 28',
    accent: '#4cc38a',
  },
  {
    id: 'cathedral-spine',
    name: 'Cathedral Spine Traverse',
    region: 'Drakensberg N · Cathedral',
    diff: 'xhard',
    km: 18.1,
    ascent: 1980,
    hrs: '9–11',
    rating: 4.9,
    reports: 41,
    tags: ['TECHNICAL', 'PERMIT'],
    live: 0,
    miniD: 'M 6 44 L 18 30 L 26 42 L 34 22 L 44 36 L 52 14 L 62 28 L 70 10 L 76 18',
    accent: '#e63d2e',
  },
  {
    id: 'amphitheatre',
    name: 'Amphitheatre Approach',
    region: 'Drakensberg N · Royal Natal',
    diff: 'mod',
    km: 9.8,
    ascent: 740,
    hrs: '4',
    rating: 4.6,
    reports: 228,
    tags: ['CHAINS'],
    live: 4,
    miniD: 'M 6 40 C 14 30 22 38 32 28 S 46 14 56 16 S 68 28 76 22',
    accent: '#5aa1d6',
  },
  {
    id: 'gorge-trail',
    name: 'Tugela Gorge',
    region: 'Drakensberg N · Royal Natal',
    diff: 'easy',
    km: 6.4,
    ascent: 180,
    hrs: '2–3',
    rating: 4.4,
    reports: 142,
    tags: ['WATER', 'FAMILY'],
    live: 12,
    miniD: 'M 6 28 C 16 30 22 38 30 34 S 48 26 58 28 S 70 24 76 22',
    accent: '#5aa1d6',
  },
];

const DIFF_META = {
  easy:  { label: 'Easy',       color: '#4cc38a', glyph: '●' },
  mod:   { label: 'Moderate',   color: '#f2a93b', glyph: '◆' },
  hard:  { label: 'Difficult',  color: '#ff6a2c', glyph: '◆' },
  xhard: { label: 'Technical',  color: '#e63d2e', glyph: '▲' },
};

function ScreenTrails() {
  const [sort, setSort] = React.useState('popular');
  const [diffFilter, setDiffFilter] = React.useState('all');

  let list = TRAILS_LIST.filter(t => diffFilter === 'all' ? true : t.diff === diffFilter);
  if (sort === 'distance')   list = [...list].sort((a,b) => a.km - b.km);
  if (sort === 'ascent')     list = [...list].sort((a,b) => b.ascent - a.ascent);
  if (sort === 'rating')     list = [...list].sort((a,b) => b.rating - a.rating);
  if (sort === 'popular')    list = [...list].sort((a,b) => b.reports - a.reports);

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        {/* App bar */}
        <div className="tt-appbar anim-in" style={{paddingBottom:6}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1, minWidth:0}}>
            <h1 style={{margin:0, font:'900 22px var(--tt-font)', letterSpacing:'-0.015em'}}>Trails</h1>
            <div className="sub" style={{marginTop:3}}>
              <b>{TRAILS_LIST.length} nearby</b> · DRAKENSBERG REGION
            </div>
          </div>
          <button className="icon-btn"><Icon name="search" size={15} color="var(--tt-text-2)"/></button>
          <button className="icon-btn"><Icon name="filter" size={14} color="var(--tt-text-2)"/></button>
        </div>

        {/* Difficulty filter chips */}
        <div style={{padding:'4px 14px 0', display:'flex', gap:6, overflowX:'auto'}}>
          <DiffChip k="all"   active={diffFilter==='all'}   onClick={() => setDiffFilter('all')}/>
          <DiffChip k="easy"  active={diffFilter==='easy'}  onClick={() => setDiffFilter('easy')}/>
          <DiffChip k="mod"   active={diffFilter==='mod'}   onClick={() => setDiffFilter('mod')}/>
          <DiffChip k="hard"  active={diffFilter==='hard'}  onClick={() => setDiffFilter('hard')}/>
          <DiffChip k="xhard" active={diffFilter==='xhard'} onClick={() => setDiffFilter('xhard')}/>
        </div>

        {/* Sort row */}
        <div style={{padding:'10px 18px 4px', display:'flex', alignItems:'center', justifyContent:'space-between'}}>
          <span style={{font:'700 10px var(--tt-font)', letterSpacing:'0.16em', color:'var(--tt-text-3)'}}>
            SHOWING <span style={{color:'var(--tt-text)'}}>{list.length}</span> · SORTED BY
          </span>
          <select
            value={sort}
            onChange={(e) => setSort(e.target.value)}
            style={{
              appearance:'none', WebkitAppearance:'none',
              background:'rgba(255,255,255,0.03)',
              border:'1px solid var(--tt-line)',
              borderRadius:8,
              padding:'5px 22px 5px 10px',
              font:'700 10px var(--tt-mono)',
              color:'var(--tt-ember)',
              letterSpacing:'0.1em',
              cursor:'pointer',
              backgroundImage:`url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='10' height='6' viewBox='0 0 10 6' fill='none'><path d='M1 1 L5 5 L9 1' stroke='%23ff6a2c' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/></svg>")`,
              backgroundRepeat:'no-repeat',
              backgroundPosition:'right 8px center',
            }}
          >
            <option value="popular">POPULAR</option>
            <option value="rating">RATING</option>
            <option value="distance">DISTANCE</option>
            <option value="ascent">ASCENT</option>
          </select>
        </div>

        {/* List */}
        <div className="tt-scroll" style={{padding:'10px 14px 8px'}}>
          <Stagger base={120} delay={60}>
            {list.map(t => <TrailListCard key={t.id} trail={t}/>)}
          </Stagger>
          <div style={{height:8}}/>
        </div>

        <BottomNav active="tools"/>
      </div>
    </div>
  );
}

function DiffChip({ k, active, onClick }) {
  if (k === 'all') {
    return (
      <button onClick={onClick} style={{
        flex:'0 0 auto',
        padding:'7px 12px', borderRadius:999,
        border: active ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
        background: active ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
        color: active ? 'var(--tt-ember)' : 'var(--tt-text-2)',
        font:'800 10px var(--tt-mono)', letterSpacing:'0.16em',
        cursor:'pointer',
      }}>ALL</button>
    );
  }
  const m = DIFF_META[k];
  return (
    <button onClick={onClick} style={{
      flex:'0 0 auto',
      padding:'7px 12px', borderRadius:999,
      border: active ? `1px solid ${m.color}80` : '1px solid var(--tt-line-2)',
      background: active ? `${m.color}1f` : 'rgba(255,255,255,0.03)',
      color: active ? m.color : 'var(--tt-text-2)',
      font:'800 10px var(--tt-mono)', letterSpacing:'0.14em',
      cursor:'pointer',
      display:'inline-flex', alignItems:'center', gap:6,
    }}>
      <span style={{color: m.color}}>{m.glyph}</span>
      {m.label.toUpperCase()}
    </button>
  );
}

function TrailListCard({ trail }) {
  const m = DIFF_META[trail.diff];
  return (
    <div className="pressable" style={{
      display:'flex', gap:12,
      padding:10,
      background:'var(--tt-surf)',
      border:'1px solid var(--tt-line)',
      borderRadius:14,
      marginBottom:8,
      cursor:'pointer',
      position:'relative', overflow:'hidden',
    }}>
      {/* Live hikers badge */}
      {trail.live > 0 && (
        <div style={{
          position:'absolute', top:8, right:8,
          display:'inline-flex', alignItems:'center', gap:4,
          padding:'3px 7px', borderRadius:6,
          background:'rgba(76,195,138,0.13)',
          border:'1px solid rgba(76,195,138,0.32)',
          font:'800 9px var(--tt-mono)', color:'var(--tt-green)', letterSpacing:'0.12em',
        }}>
          <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.6s infinite'}}/>
          {trail.live} LIVE
        </div>
      )}

      {/* Mini aerial map */}
      <TrailMini trail={trail}/>

      <div style={{flex:1, minWidth:0, paddingTop:2}}>
        <div style={{display:'flex', alignItems:'center', gap:4, font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.1em'}}>
          <Icon name="pin" size={10} color="var(--tt-text-3)"/>
          {trail.region.toUpperCase()}
        </div>
        <div style={{font:'800 14.5px var(--tt-font)', color:'var(--tt-text)', marginTop:3, letterSpacing:'-0.01em'}}>
          {trail.name}
        </div>

        {/* difficulty + tags */}
        <div style={{display:'flex', alignItems:'center', gap:5, marginTop:6, flexWrap:'wrap'}}>
          <span style={{
            display:'inline-flex', alignItems:'center', gap:4,
            padding:'2px 7px', borderRadius:5,
            background:`${m.color}1f`, border:`1px solid ${m.color}55`,
            font:'800 9px var(--tt-mono)', color: m.color, letterSpacing:'0.12em',
          }}>
            <span>{m.glyph}</span>{m.label.toUpperCase()}
          </span>
          {trail.tags.map(t => (
            <span key={t} className="pill" style={{height:18, padding:'0 7px', fontSize:8.5, letterSpacing:'0.14em'}}>{t}</span>
          ))}
        </div>

        {/* stats row */}
        <div style={{display:'flex', gap:12, marginTop:8, font:'700 10.5px var(--tt-mono)', color:'var(--tt-text-2)'}}>
          <span><Icon name="navigation" size={10} color="var(--tt-text-3)"/> <b style={{color:'var(--tt-text)'}}>{trail.km}</b> km</span>
          <span style={{color:'var(--tt-line-3)'}}>·</span>
          <span><Icon name="arrow-up" size={10} color="var(--tt-ember)"/> <b style={{color:'var(--tt-ember)'}}>{trail.ascent}</b> m</span>
          <span style={{color:'var(--tt-line-3)'}}>·</span>
          <span><Icon name="clock" size={10} color="var(--tt-text-3)"/> <b style={{color:'var(--tt-text)'}}>{trail.hrs}</b>h</span>
        </div>

        {/* rating */}
        <div style={{display:'flex', alignItems:'center', gap:6, marginTop:8, font:'700 10.5px var(--tt-font)', color:'var(--tt-text-2)'}}>
          <span style={{color:'#ff8a4d'}}>★</span>
          <span className="num" style={{color:'var(--tt-text)', fontWeight:800}}>{trail.rating}</span>
          <span style={{color:'var(--tt-text-3)'}}>({trail.reports} reports)</span>
        </div>
      </div>
    </div>
  );
}

function TrailMini({ trail }) {
  // Compact aerial map signature — 80×80 stylized terrain + the trail line
  return (
    <div style={{
      width:84, height:84, flex:'0 0 auto',
      borderRadius:10,
      overflow:'hidden',
      position:'relative',
      background:'linear-gradient(135deg, #0d1218 0%, #161e22 100%)',
      border:'1px solid var(--tt-line)',
    }}>
      <svg viewBox="0 0 80 80" width="100%" height="100%" preserveAspectRatio="none">
        <defs>
          <linearGradient id={`tm-${trail.id}`} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%"   stopColor="#0f1820"/>
            <stop offset="100%" stopColor="#1a2229"/>
          </linearGradient>
        </defs>
        <rect width="80" height="80" fill={`url(#tm-${trail.id})`}/>
        {/* Topo contours */}
        <g stroke="rgba(255,255,255,0.07)" fill="none" strokeWidth="0.5">
          <path d="M -4 16 C 20 22 40 18 84 26"/>
          <path d="M -4 28 C 20 34 40 30 84 38"/>
          <path d="M -4 40 C 20 46 40 42 84 50"/>
          <path d="M -4 52 C 20 58 40 54 84 62"/>
          <path d="M -4 64 C 20 70 40 66 84 74"/>
        </g>
        {/* Forest patches */}
        <g opacity="0.55">
          <circle cx="14" cy="60" r="10" fill="#1a2a1f"/>
          <circle cx="64" cy="22" r="8"  fill="#1a2a1f"/>
        </g>
        {/* River */}
        <path d="M -4 56 C 16 52 32 62 50 56 S 70 50 84 54"
              fill="none" stroke="rgba(90,161,214,0.45)" strokeWidth="1.4" strokeLinecap="round"/>
        {/* Trail line */}
        <path d={trail.miniD}
              fill="none" stroke={trail.accent} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"
              filter={`drop-shadow(0 0 3px ${trail.accent})`}/>
        {/* Trailhead + summit dots */}
        <circle cx="6"  cy="44" r="2.2" fill="#0a0c0f" stroke={trail.accent} strokeWidth="1.4"/>
        <circle cx="76" cy="6"  r="2.4" fill={trail.accent}/>
      </svg>
    </div>
  );
}

window.ScreenTrails = ScreenTrails;
window.TRAIL_DIFF_META = DIFF_META;

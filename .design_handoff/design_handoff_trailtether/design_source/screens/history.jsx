// Trailtether — Hike History (list of past hikes, reached from Profile "Export")

function ScreenHistory() {
  const [filter, setFilter] = React.useState('all');

  const HIKES = [
    { id:1, name:'Mt. Marcy Summit',  date:'OCT 26', km:12.4, gain:1205, hrs:'5:14', score:'A', diff:'hard',  region:'Drakensberg N' },
    { id:2, name:'Sunset Ridge Loop', date:'OCT 22', km:8.6,  gain:620,  hrs:'3:42', score:'A', diff:'mod',   region:'Drakensberg N' },
    { id:3, name:'Cave Circuit',      date:'OCT 18', km:5.2,  gain:210,  hrs:'2:08', score:'B', diff:'easy',  region:'Drakensberg N' },
    { id:4, name:'Amphitheatre',      date:'OCT 11', km:9.8,  gain:740,  hrs:'4:36', score:'A', diff:'mod',   region:'Royal Natal'   },
    { id:5, name:'Tugela Gorge',      date:'OCT 05', km:6.4,  gain:180,  hrs:'2:55', score:'A', diff:'easy',  region:'Royal Natal'   },
    { id:6, name:'Mt. Marcy Summit',  date:'SEP 28', km:12.4, gain:1205, hrs:'5:48', score:'B', diff:'hard',  region:'Drakensberg N' },
    { id:7, name:'Champagne Castle',  date:'SEP 14', km:14.2, gain:1450, hrs:'7:12', score:'A', diff:'hard',  region:'Central Berg'  },
    { id:8, name:'Cathedral Spine',   date:'AUG 30', km:18.1, gain:1980, hrs:'10:24', score:'B', diff:'xhard', region:'Drakensberg N' },
  ];

  const filtered = filter === 'all' ? HIKES : HIKES.filter(h => h.diff === filter);
  const total = HIKES.reduce((acc, h) => ({ km: acc.km + h.km, gain: acc.gain + h.gain }), { km:0, gain:0 });

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:6}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <h1 style={{margin:0, font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Hike History</h1>
            <div className="sub" style={{marginTop:3}}>
              <b>{HIKES.length} hikes</b> · {total.km.toFixed(1)} KM · {total.gain.toLocaleString()} M ASCENT
            </div>
          </div>
          <button className="icon-btn"><Icon name="filter" size={13} color="var(--tt-text-2)"/></button>
          <button className="icon-btn"><Icon name="arrow-up-right" size={13} color="var(--tt-ember)"/></button>
        </div>

        {/* Stat hero */}
        <div className="anim-up" style={{padding:'4px 18px 0', animationDelay:'80ms'}}>
          <div className="card" style={{padding:'14px 16px', position:'relative', overflow:'hidden'}}>
            <div style={{position:'absolute', top:-30, right:-30, width:140, height:140, borderRadius:'50%',
              background:'radial-gradient(circle, rgba(255,106,44,0.18), transparent 70%)', pointerEvents:'none'}}/>
            <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
              <div>
                <div style={{font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>THIS YEAR</div>
                <div className="num count-up" style={{font:'900 32px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.025em', marginTop:4}}>
                  {total.km.toFixed(1)} <span style={{fontSize:14, color:'var(--tt-text-2)', fontWeight:600}}>km</span>
                </div>
                <div style={{font:'700 11px var(--tt-mono)', color:'var(--tt-ember)', marginTop:3}}>↑ {total.gain.toLocaleString()} m ascent</div>
              </div>
              {/* Sparkline of monthly km */}
              <svg width="120" height="64" viewBox="0 0 120 64">
                <defs>
                  <linearGradient id="histSpark" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.6"/>
                    <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0"/>
                  </linearGradient>
                </defs>
                <path d="M 0 50 L 15 42 L 30 38 L 45 26 L 60 22 L 75 14 L 90 18 L 105 10 L 120 8 L 120 64 L 0 64 Z" fill="url(#histSpark)"/>
                <path d="M 0 50 L 15 42 L 30 38 L 45 26 L 60 22 L 75 14 L 90 18 L 105 10 L 120 8"
                      fill="none" stroke="#ff8a4d" strokeWidth="1.6" strokeLinecap="round"
                      className="draw-line" style={{['--len']:200, animationDelay:'300ms'}}/>
                <circle cx="120" cy="8" r="2.4" fill="#fff" stroke="#ff6a2c" strokeWidth="1.5"
                        className="anim-pop" style={{animationDelay:'1000ms', transformOrigin:'120px 8px'}}/>
              </svg>
            </div>
          </div>
        </div>

        {/* Filter chips */}
        <div style={{padding:'10px 14px 0', display:'flex', gap:6}}>
          {[
            { k:'all', label:'ALL' },
            { k:'easy', label:'EASY' },
            { k:'mod',  label:'MODERATE' },
            { k:'hard', label:'DIFFICULT' },
            { k:'xhard',label:'TECHNICAL' },
          ].map(c => (
            <button key={c.k} onClick={() => setFilter(c.k)} style={{
              flex:'0 0 auto', padding:'6px 11px', borderRadius:999,
              background: filter===c.k ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
              border: filter===c.k ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
              color: filter===c.k ? 'var(--tt-ember)' : 'var(--tt-text-2)',
              font:'800 9.5px var(--tt-mono)', letterSpacing:'0.14em',
              cursor:'pointer', whiteSpace:'nowrap',
            }}>{c.label}</button>
          ))}
        </div>

        <div className="tt-scroll" style={{padding:'10px 18px 24px'}}>
          <Stagger base={150} delay={70}>
            {filtered.map(h => <HikeRow key={h.id} hike={h}/>)}
          </Stagger>
        </div>

        <BottomNav active="profile"/>
      </div>
    </div>
  );
}

function HikeRow({ hike }) {
  const diffMap = {
    easy:  { color:'#4cc38a', label:'EASY' },
    mod:   { color:'#f2a93b', label:'MOD'  },
    hard:  { color:'#ff6a2c', label:'DIFF' },
    xhard: { color:'#e63d2e', label:'TECH' },
  };
  const m = diffMap[hike.diff];
  const score = { A:'#4cc38a', B:'#f2a93b', C:'#e63d2e' };
  return (
    <div className="card pressable" style={{padding:'12px 14px', marginBottom:8}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:10}}>
        <div style={{flex:1, minWidth:0}}>
          <div style={{display:'flex', alignItems:'center', gap:6}}>
            <span style={{font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.12em'}}>{hike.date}</span>
            <span style={{padding:'1px 5px', borderRadius:3, background:`${m.color}1f`, border:`1px solid ${m.color}55`,
              font:'800 8.5px var(--tt-mono)', color:m.color, letterSpacing:'0.14em'}}>{m.label}</span>
          </div>
          <div style={{font:'800 14px var(--tt-font)', color:'var(--tt-text)', marginTop:4, letterSpacing:'-0.01em'}}>{hike.name}</div>
          <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.06em'}}>
            {hike.region.toUpperCase()}
          </div>
        </div>
        {/* Score grade */}
        <div style={{
          width:42, height:42, borderRadius:10,
          background:`${score[hike.score]}1f`, border:`1.5px solid ${score[hike.score]}55`,
          display:'grid', placeItems:'center',
          font:'900 18px var(--tt-mono)', color:score[hike.score],
          flex:'0 0 auto',
        }}>{hike.score}</div>
      </div>
      <div style={{display:'flex', gap:14, marginTop:10, font:'700 11px var(--tt-mono)', color:'var(--tt-text-2)'}}>
        <span><Icon name="navigation" size={10} color="var(--tt-text-3)"/> <b style={{color:'var(--tt-text)'}}>{hike.km}</b> km</span>
        <span style={{color:'var(--tt-line-3)'}}>·</span>
        <span><Icon name="arrow-up" size={10} color="var(--tt-ember)"/> <b style={{color:'var(--tt-ember)'}}>{hike.gain}</b> m</span>
        <span style={{color:'var(--tt-line-3)'}}>·</span>
        <span><Icon name="clock" size={10} color="var(--tt-text-3)"/> <b style={{color:'var(--tt-text)'}}>{hike.hrs}</b></span>
        <div style={{flex:1}}/>
        <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
      </div>
    </div>
  );
}

window.ScreenHistory = ScreenHistory;

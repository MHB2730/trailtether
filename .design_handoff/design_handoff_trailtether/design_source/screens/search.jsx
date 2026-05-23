// Trailtether — Search screen (reached from search icon anywhere)

function ScreenSearch() {
  const [q, setQ] = React.useState('cathedral');
  const [scope, setScope] = React.useState('all');

  const ALL = {
    trails: [
      { name:'Cathedral Spine Traverse', region:'Drakensberg N', km:18.1, diff:'TECH' },
      { name:'Cathedral Peak Summit',    region:'Drakensberg N', km:12.4, diff:'DIFF' },
      { name:'Cathedral Cave Loop',      region:'Drakensberg N', km:5.2,  diff:'EASY' },
    ],
    people: [
      { name:'Cathy Reynolds',  sub:'@cathy · 12 trails',     initials:'CR', color:'#4cc38a' },
      { name:'Cathedral Hike Club', sub:'58 members',         initials:'CH', color:'#5aa1d6' },
    ],
    caves: [
      { name:'Cathedral Lower Cave',   km:9.2,  cap:'4 sleepers' },
      { name:'Cathedral Upper Shelter', km:10.4, cap:'6 sleepers' },
    ],
    reports: [
      { title:'Cathedral spine — windy',  who:'Sarah L.', time:'18m ago' },
      { title:'Cathedral water source dry', who:'Mike K.', time:'2d ago' },
    ],
  };

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        {/* Search bar */}
        <div className="tt-appbar anim-in" style={{paddingBottom:8, gap:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{
            flex:1, display:'flex', alignItems:'center', gap:8,
            padding:'9px 12px',
            background:'var(--tt-surf)', border:'1px solid var(--tt-line-2)',
            borderRadius:11,
          }}>
            <Icon name="search" size={14} color="var(--tt-ember)"/>
            <input type="text" value={q} onChange={(e) => setQ(e.target.value)}
              style={{flex:1, background:'transparent', border:'none', outline:'none',
                color:'var(--tt-text)', font:'700 13px var(--tt-font)'}}/>
            {q && (
              <button onClick={() => setQ('')} style={{background:'transparent', border:'none', cursor:'pointer', padding:0, color:'var(--tt-text-3)'}}>×</button>
            )}
          </div>
          <button className="icon-btn"><Icon name="filter" size={14} color="var(--tt-text-2)"/></button>
        </div>

        {/* Scope chips */}
        <div style={{padding:'4px 14px 0', display:'flex', gap:6, overflowX:'auto'}}>
          {[
            { k:'all',     label:'ALL',     n:9 },
            { k:'trails',  label:'TRAILS',  n:3 },
            { k:'people',  label:'PEOPLE',  n:2 },
            { k:'caves',   label:'CAVES',   n:2 },
            { k:'reports', label:'REPORTS', n:2 },
          ].map(s => (
            <button key={s.k} onClick={() => setScope(s.k)} style={{
              flex:'0 0 auto', padding:'7px 12px', borderRadius:999,
              background: scope===s.k ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
              border: scope===s.k ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
              color: scope===s.k ? 'var(--tt-ember)' : 'var(--tt-text-2)',
              font:'800 10px var(--tt-mono)', letterSpacing:'0.14em',
              cursor:'pointer', whiteSpace:'nowrap',
              display:'inline-flex', alignItems:'center', gap:5,
            }}>
              {s.label}
              <span style={{font:'700 9px var(--tt-mono)', color: scope===s.k ? 'var(--tt-ember)' : 'var(--tt-text-3)'}}>{s.n}</span>
            </button>
          ))}
        </div>

        <div className="tt-scroll" style={{padding:'12px 18px 24px'}}>
          {/* Trails */}
          {(scope === 'all' || scope === 'trails') && (
            <SearchGroup title="TRAILS" count={ALL.trails.length} delay={120}>
              {ALL.trails.map((t, i) => (
                <SearchRow key={i} icon="mountain" iconColor="var(--tt-ember)"
                  title={t.name} sub={`${t.region} · ${t.km} km`}
                  meta={<span className="pill" style={{height:18, padding:'0 6px', fontSize:8.5, letterSpacing:'0.14em', color:'var(--tt-ember)', background:'var(--tt-ember-dim)', border:'1px solid rgba(255,106,44,0.32)'}}>{t.diff}</span>}
                  isLast={i === ALL.trails.length - 1}/>
              ))}
            </SearchGroup>
          )}
          {(scope === 'all' || scope === 'people') && (
            <SearchGroup title="PEOPLE & TEAMS" count={ALL.people.length} delay={200}>
              {ALL.people.map((p, i) => (
                <SearchRow key={i}
                  avatar={<div style={{
                    width:34, height:34, borderRadius:'50%',
                    background:`linear-gradient(135deg, ${p.color}, ${p.color}aa)`,
                    display:'grid', placeItems:'center',
                    color:'#fff', font:'800 12px var(--tt-font)',
                    border:`1.5px solid ${p.color}`,
                  }}>{p.initials}</div>}
                  title={p.name} sub={p.sub}
                  isLast={i === ALL.people.length - 1}/>
              ))}
            </SearchGroup>
          )}
          {(scope === 'all' || scope === 'caves') && (
            <SearchGroup title="CAVES & SHELTERS" count={ALL.caves.length} delay={280}>
              {ALL.caves.map((c, i) => (
                <SearchRow key={i} icon="rock" iconColor="#4cc38a"
                  title={c.name} sub={`km ${c.km} · ${c.cap}`}
                  isLast={i === ALL.caves.length - 1}/>
              ))}
            </SearchGroup>
          )}
          {(scope === 'all' || scope === 'reports') && (
            <SearchGroup title="TRAIL REPORTS" count={ALL.reports.length} delay={360}>
              {ALL.reports.map((r, i) => (
                <SearchRow key={i} icon="message" iconColor="#5aa1d6"
                  title={r.title} sub={`${r.who} · ${r.time}`}
                  isLast={i === ALL.reports.length - 1}/>
              ))}
            </SearchGroup>
          )}

          {/* Recent searches */}
          <div className="anim-up" style={{marginTop:22, animationDelay:'450ms'}}>
            <div style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-3)', marginBottom:8}}>RECENT</div>
            <div style={{display:'flex', flexWrap:'wrap', gap:6}}>
              {['Mt. Marcy','Sarah L.','cave #47','class 3','wonderland','Drakensberg'].map(t => (
                <span key={t} style={{
                  padding:'6px 10px', borderRadius:999,
                  background:'rgba(255,255,255,0.03)', border:'1px solid var(--tt-line-2)',
                  color:'var(--tt-text-2)', font:'700 11px var(--tt-font)',
                  display:'inline-flex', alignItems:'center', gap:6,
                }}>
                  <Icon name="history" size={11} color="var(--tt-text-3)"/>
                  {t}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SearchGroup({ title, count, delay = 100, children }) {
  return (
    <div className="anim-up" style={{marginBottom:14, animationDelay:`${delay}ms`}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:7, paddingLeft:2}}>
        <span style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-3)'}}>{title}</span>
        <span style={{font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.06em'}}>{count}</span>
      </div>
      <div className="card" style={{padding:0, overflow:'hidden'}}>
        {children}
      </div>
    </div>
  );
}

function SearchRow({ icon, iconColor, avatar, title, sub, meta, isLast }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'11px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
      cursor:'pointer',
    }}>
      {avatar ? avatar : (
        <div style={{
          width:30, height:30, borderRadius:9,
          background:`${iconColor}1f`, border:`1px solid ${iconColor}55`,
          display:'grid', placeItems:'center', flex:'0 0 auto',
        }}>
          <Icon name={icon} size={13} color={iconColor}/>
        </div>
      )}
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-text)'}}>{title}</div>
        <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em'}}>{sub}</div>
      </div>
      {meta}
      <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
    </div>
  );
}

window.ScreenSearch = ScreenSearch;

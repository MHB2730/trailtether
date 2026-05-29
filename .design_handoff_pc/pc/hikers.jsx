// Trailtether PC — Hikers list (all people paired to this base-camp PC)

function PCScreenHikers() {
  const [filter, setFilter] = React.useState('all');
  const list = filter === 'all' ? PC_HIKERS
             : filter === 'active' ? PC_HIKERS.filter(h => h.status === 'active' || h.status === 'late')
             : PC_HIKERS.filter(h => h.status === filter);

  return (
    <PCWindow>
      <PCTitleBar/>
      <PCLayout active="hikers">
        <PCPageHeader
          eyebrow="PAIRED DEVICES"
          title="Hikers"
          sub={<><b style={{color:'var(--tt-ember)'}}>{PC_HIKERS.length} paired</b> · 2 active · 1 flagged · UPDATED 10:09:14</>}
          actions={
            <div style={{ display:'flex', gap:8 }}>
              <PCBtn ghost leftIcon="filter">FILTER</PCBtn>
              <PCBtn ghost leftIcon="arrow-up-right">EXPORT</PCBtn>
              <PCBtn primary leftIcon="plus">PAIR NEW HIKER</PCBtn>
            </div>
          }
        />

        <div style={{ padding:'16px 26px 22px', flex:1, overflow:'auto' }}>
          {/* Filter chips */}
          <div style={{ display:'flex', gap:6, marginBottom:16 }}>
            {[
              { k:'all',    label:'ALL',     n:PC_HIKERS.length },
              { k:'active', label:'ACTIVE',  n:PC_HIKERS.filter(h => h.status==='active' || h.status==='late').length },
              { k:'idle',   label:'IDLE',    n:PC_HIKERS.filter(h => h.status==='idle').length },
              { k:'paired', label:'PAIRED',  n:PC_HIKERS.filter(h => h.status==='paired').length },
              { k:'late',   label:'FLAGGED', n:PC_HIKERS.filter(h => h.status==='late').length },
            ].map(c => (
              <button key={c.k} onClick={() => setFilter(c.k)} style={{
                padding:'7px 13px', borderRadius:999,
                background: filter===c.k ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
                border: filter===c.k ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
                color: filter===c.k ? 'var(--tt-ember)' : 'var(--tt-text-2)',
                font:'800 10px var(--tt-mono)', letterSpacing:'0.14em',
                cursor:'pointer', whiteSpace:'nowrap',
                display:'inline-flex', alignItems:'center', gap:7,
              }}>
                {c.label}
                <span style={{ font:'700 9px var(--tt-mono)', color: filter===c.k ? 'var(--tt-ember)' : 'var(--tt-text-3)' }}>{c.n}</span>
              </button>
            ))}
          </div>

          {/* Column header */}
          <div style={{ display:'grid', gridTemplateColumns:'2fr 1.5fr 1fr 1fr 1fr 1fr 1fr 60px',
            gap:14, padding:'0 16px 8px',
            font:'800 9.5px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-3)' }}>
            <span>HIKER</span><span>STATUS · TRAIL</span><span>POSITION</span>
            <span>ELEV</span><span>PACE</span><span>BATT</span><span>LAST PING</span><span></span>
          </div>

          <div style={{ display:'flex', flexDirection:'column', gap:6 }}>
            {list.map(h => <PCHikerRow key={h.id} hiker={h}/>)}
          </div>
        </div>
      </PCLayout>
    </PCWindow>
  );
}

function PCHikerRow({ hiker }) {
  const statusColor =
    hiker.status === 'active' ? 'var(--tt-green)'
    : hiker.status === 'late' ? 'var(--tt-amber)'
    : hiker.status === 'idle' ? 'var(--tt-text-3)'
    : 'var(--tt-text-3)';
  const statusLabel = hiker.status.toUpperCase();
  const isLive = hiker.status === 'active' || hiker.status === 'late';

  return (
    <div className="pressable" style={{
      display:'grid', gridTemplateColumns:'2fr 1.5fr 1fr 1fr 1fr 1fr 1fr 60px',
      gap:14, alignItems:'center',
      padding:'14px 16px',
      background:'var(--tt-surf)',
      border:`1px solid ${hiker.status === 'late' ? 'rgba(242,169,59,0.32)' : 'var(--tt-line)'}`,
      borderLeft: hiker.status === 'late' ? '3px solid var(--tt-amber)'
                : hiker.status === 'active' ? '3px solid var(--tt-green)'
                : '1px solid var(--tt-line)',
      borderRadius:11,
      cursor:'pointer',
    }}>
      {/* Hiker */}
      <div style={{ display:'flex', alignItems:'center', gap:10, minWidth:0 }}>
        <div style={{ position:'relative', flex:'0 0 auto' }}>
          <div style={{
            width:38, height:38, borderRadius:'50%',
            background:`linear-gradient(135deg, ${hiker.color}, ${hiker.color}aa)`,
            display:'grid', placeItems:'center',
            color:'#fff', font:'800 13px var(--tt-font)',
            border:`2px solid ${hiker.color}`,
          }}>{hiker.initials}</div>
          {isLive && (
            <div style={{
              position:'absolute', bottom:-2, right:-2,
              width:12, height:12, borderRadius:'50%',
              background:'var(--tt-green)',
              border:'2px solid var(--tt-surf)',
              boxShadow:'0 0 5px var(--tt-green)',
            }}/>
          )}
        </div>
        <div style={{ minWidth:0 }}>
          <div style={{ font:'800 13px var(--tt-font)', color:'var(--tt-text)' }}>{hiker.name}</div>
          <div style={{ font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:1, letterSpacing:'0.06em' }}>
            PAIRED · {hiker.signal} · {hiker.id === 'tom' ? 'INACTIVE 1 DAY' : 'TODAY'}
          </div>
        </div>
      </div>

      {/* Status + trail */}
      <div style={{ minWidth:0 }}>
        <div style={{ display:'inline-flex', alignItems:'center', gap:5,
          padding:'3px 8px', borderRadius:5,
          background:`${statusColor}1f`, border:`1px solid ${statusColor}55`,
          font:'800 9px var(--tt-mono)', color:statusColor, letterSpacing:'0.14em',
        }}>
          {isLive && <span style={{ width:5, height:5, borderRadius:'50%', background:statusColor,
            boxShadow:`0 0 4px ${statusColor}`, animation:'pulse 1.4s infinite' }}/>}
          {statusLabel}
        </div>
        <div style={{ font:'700 10.5px var(--tt-font)', color:'var(--tt-text-2)', marginTop:5 }}>
          {hiker.trail || <span style={{ color:'var(--tt-text-3)', fontStyle:'italic' }}>— not on a trail —</span>}
        </div>
      </div>

      {/* Position */}
      <div>
        {hiker.km > 0 ? (
          <div className="num" style={{ font:'800 13px var(--tt-mono)', color:'var(--tt-text)' }}>{hiker.km} km</div>
        ) : <Dash/>}
        {hiker.region && <div style={{ font:'600 9px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:1, letterSpacing:'0.06em' }}>{hiker.region.toUpperCase()}</div>}
      </div>

      {/* Elevation */}
      <div>
        {hiker.elevM ? (
          <div className="num" style={{ font:'800 13px var(--tt-mono)', color:'var(--tt-ember)' }}>{hiker.elevM} <span style={{fontSize:10, color:'var(--tt-text-2)'}}>m</span></div>
        ) : <Dash/>}
      </div>

      {/* Pace */}
      <div>
        {hiker.speed > 0 ? (
          <div className="num" style={{ font:'800 13px var(--tt-mono)', color:'var(--tt-text)' }}>{hiker.speed} <span style={{fontSize:10, color:'var(--tt-text-2)'}}>km/h</span></div>
        ) : <Dash/>}
      </div>

      {/* Battery */}
      <div>
        {hiker.battery ? (
          <BatteryGlyph pct={hiker.battery}/>
        ) : <Dash/>}
      </div>

      {/* Last ping */}
      <div className="num" style={{ font:'700 11px var(--tt-mono)',
        color: hiker.status === 'late' ? 'var(--tt-amber)' : hiker.lastPing ? 'var(--tt-text-2)' : 'var(--tt-text-3)' }}>
        {hiker.lastPing || '—'}
      </div>

      {/* Actions */}
      <div style={{ display:'flex', justifyContent:'flex-end', gap:6 }}>
        <button className="icon-btn" style={{ width:30, height:30 }}><Icon name="message" size={12} color="var(--tt-text-2)"/></button>
        <button className="icon-btn" style={{ width:30, height:30 }}><Icon name="more" size={12} color="var(--tt-text-2)"/></button>
      </div>
    </div>
  );
}

function Dash() { return <span style={{ color:'var(--tt-text-3)', fontSize:13 }}>—</span>; }

function BatteryGlyph({ pct }) {
  const c = pct > 50 ? 'var(--tt-green)' : pct > 25 ? 'var(--tt-amber)' : 'var(--tt-red)';
  return (
    <div style={{ display:'inline-flex', alignItems:'center', gap:6 }}>
      <div style={{ width:24, height:11, border:`1px solid ${c}99`, borderRadius:2, padding:1.2, position:'relative' }}>
        <div style={{ height:'100%', width:`${pct}%`, background:c, borderRadius:1 }}/>
        <span style={{ position:'absolute', right:-2.4, top:1.8, bottom:1.8, width:1.4, background:`${c}99` }}/>
      </div>
      <span className="num" style={{ fontSize:11, color:c, fontWeight:800 }}>{pct}%</span>
    </div>
  );
}

window.PCScreenHikers = PCScreenHikers;

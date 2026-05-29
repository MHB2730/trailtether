// Trailtether PC — History (past hikes archive)

function PCScreenHistory() {
  const HIKES = [
    { id:1, hiker:'John D.', color:'#ff6a2c', trail:'Mt. Marcy Summit', date:'OCT 26', km:12.4, gain:1205, hrs:'5:14', score:'A', diff:'hard',  status:'completed', region:'Drakensberg N' },
    { id:2, hiker:'Mike K.', color:'#4cc38a', trail:'Mt. Marcy Summit', date:'OCT 26', km:12.1, gain:1198, hrs:'5:48', score:'B', diff:'hard',  status:'completed', region:'Drakensberg N' },
    { id:3, hiker:'Emily R.',color:'#f2a93b', trail:'Mt. Marcy Summit', date:'OCT 26', km:9.2,  gain:802,  hrs:'4:22', score:'B', diff:'hard',  status:'bailed',    region:'Drakensberg N' },
    { id:4, hiker:'John D.', color:'#ff6a2c', trail:'Sunset Ridge Loop',date:'OCT 22', km:8.6,  gain:620,  hrs:'3:42', score:'A', diff:'mod',   status:'completed', region:'Drakensberg N' },
    { id:5, hiker:'Lana N.', color:'#5aa1d6', trail:'Cave Circuit',     date:'OCT 18', km:5.2,  gain:210,  hrs:'2:08', score:'B', diff:'easy',  status:'completed', region:'Drakensberg N' },
    { id:6, hiker:'John D.', color:'#ff6a2c', trail:'Amphitheatre',     date:'OCT 11', km:9.8,  gain:740,  hrs:'4:36', score:'A', diff:'mod',   status:'completed', region:'Royal Natal' },
    { id:7, hiker:'Mike K.', color:'#4cc38a', trail:'Tugela Gorge',     date:'OCT 05', km:6.4,  gain:180,  hrs:'2:55', score:'A', diff:'easy',  status:'completed', region:'Royal Natal' },
    { id:8, hiker:'John D.', color:'#ff6a2c', trail:'Cathedral Spine',  date:'AUG 30', km:18.1, gain:1980, hrs:'10:24',score:'B', diff:'xhard', status:'completed', region:'Drakensberg N' },
  ];
  const total = HIKES.reduce((a, h) => ({ km: a.km + h.km, gain: a.gain + h.gain, hrs: a.hrs + 1 }), { km:0, gain:0, hrs:0 });

  return (
    <PCWindow>
      <PCTitleBar/>
      <PCLayout active="history">
        <PCPageHeader
          eyebrow="ARCHIVE"
          title="History"
          sub={<>{HIKES.length} hikes · {total.km.toFixed(1)} KM TOTAL · {total.gain.toLocaleString()} m ascent · LAST 90 DAYS</>}
          actions={
            <div style={{ display:'flex', gap:8 }}>
              <PCBtn ghost leftIcon="filter">RANGE</PCBtn>
              <PCBtn ghost leftIcon="search">SEARCH</PCBtn>
              <PCBtn leftIcon="arrow-up-right">EXPORT CSV</PCBtn>
            </div>
          }
        />

        <div style={{ padding:'16px 26px 22px', flex:1, overflow:'auto' }}>
          {/* Aggregate stat row */}
          <div style={{ display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:14, marginBottom:16 }}>
            <PCStat label="HIKES"       value={HIKES.length}                   icon="mountain" sub="Across 4 hikers"/>
            <PCStat label="TOTAL KM"    value={total.km.toFixed(1)}  unit="km" icon="navigation"/>
            <PCStat label="TOTAL ASCENT" value={total.gain.toLocaleString()} unit="m" icon="arrow-up" ember/>
            <PCStat label="INCIDENTS"   value="0"                              icon="shield" sub="Clean record · 18 months"/>
          </div>

          {/* Monthly chart */}
          <PCCard padding={18} style={{ marginBottom:16 }}>
            <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
              <span style={{ font:'800 11px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-2)' }}>HIKES PER MONTH · LAST YEAR</span>
              <span style={{ font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)' }}>NOV ’24 → OCT ’25</span>
            </div>
            <PCMonthsChart/>
          </PCCard>

          {/* Column header */}
          <div style={{ display:'grid', gridTemplateColumns:'70px 1fr 1.5fr 1fr 1fr 1fr 60px 60px',
            gap:14, padding:'0 16px 8px',
            font:'800 9.5px var(--tt-font)', letterSpacing:'0.18em', color:'var(--tt-text-3)' }}>
            <span>DATE</span><span>HIKER</span><span>TRAIL</span>
            <span>DIST</span><span>ASCENT</span><span>TIME</span><span>STATUS</span><span>SCORE</span>
          </div>

          <div style={{ display:'flex', flexDirection:'column', gap:5 }}>
            {HIKES.map(h => <HistoryRow key={h.id} hike={h}/>)}
          </div>
        </div>
      </PCLayout>
    </PCWindow>
  );
}

function HistoryRow({ hike }) {
  const diffMap = {
    easy:  { color:'#4cc38a' },
    mod:   { color:'#f2a93b' },
    hard:  { color:'#ff6a2c' },
    xhard: { color:'#e63d2e' },
  };
  const score = { A:'#4cc38a', B:'#f2a93b', C:'#e63d2e' };
  const statusBg = hike.status === 'completed' ? 'var(--tt-green)' : hike.status === 'bailed' ? 'var(--tt-amber)' : 'var(--tt-red)';
  return (
    <div className="pressable" style={{
      display:'grid', gridTemplateColumns:'70px 1fr 1.5fr 1fr 1fr 1fr 60px 60px',
      gap:14, alignItems:'center',
      padding:'12px 16px',
      background:'var(--tt-surf)',
      border:'1px solid var(--tt-line)',
      borderLeft:`3px solid ${diffMap[hike.diff].color}`,
      borderRadius:10,
      cursor:'pointer',
    }}>
      <div className="num" style={{ font:'800 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.08em' }}>{hike.date}</div>
      <div style={{ display:'flex', alignItems:'center', gap:8 }}>
        <div style={{
          width:26, height:26, borderRadius:'50%',
          background:`linear-gradient(135deg, ${hike.color}, ${hike.color}aa)`,
          display:'grid', placeItems:'center',
          color:'#fff', font:'800 10px var(--tt-font)',
          border:`1.5px solid ${hike.color}`,
        }}>{hike.hiker.split(' ')[0][0]}{hike.hiker.split(' ')[1][0]}</div>
        <span style={{ font:'700 11.5px var(--tt-font)', color:'var(--tt-text)' }}>{hike.hiker}</span>
      </div>
      <div>
        <div style={{ font:'800 12px var(--tt-font)', color:'var(--tt-text)' }}>{hike.trail}</div>
        <div style={{ font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:1, letterSpacing:'0.06em' }}>{hike.region.toUpperCase()}</div>
      </div>
      <div className="num" style={{ font:'800 12px var(--tt-mono)', color:'var(--tt-text)' }}>{hike.km} <span style={{fontSize:9, color:'var(--tt-text-2)'}}>km</span></div>
      <div className="num" style={{ font:'800 12px var(--tt-mono)', color:'var(--tt-ember)' }}>{hike.gain.toLocaleString()} <span style={{fontSize:9, color:'var(--tt-text-2)'}}>m</span></div>
      <div className="num" style={{ font:'800 12px var(--tt-mono)', color:'var(--tt-text)' }}>{hike.hrs}</div>
      <div>
        <span style={{
          display:'inline-block', padding:'2px 6px', borderRadius:4,
          background:`${statusBg}1f`, border:`1px solid ${statusBg}55`,
          font:'800 8.5px var(--tt-mono)', color:statusBg, letterSpacing:'0.12em',
        }}>{hike.status.toUpperCase()}</span>
      </div>
      <div style={{
        width:34, height:34, borderRadius:9,
        background:`${score[hike.score]}1f`, border:`1.5px solid ${score[hike.score]}55`,
        display:'grid', placeItems:'center',
        font:'900 16px var(--tt-mono)', color:score[hike.score],
      }}>{hike.score}</div>
    </div>
  );
}

function PCMonthsChart() {
  const months = [
    { m:'NOV', n:3 }, { m:'DEC', n:5 }, { m:'JAN', n:4 }, { m:'FEB', n:7 },
    { m:'MAR', n:6 }, { m:'APR', n:9 }, { m:'MAY', n:8 }, { m:'JUN', n:12 },
    { m:'JUL', n:10 }, { m:'AUG', n:11 }, { m:'SEP', n:8 }, { m:'OCT', n:9 },
  ];
  const max = Math.max(...months.map(m => m.n));
  return (
    <svg width="100%" height="120" viewBox={`0 0 1200 120`} preserveAspectRatio="none" style={{ display:'block' }}>
      {months.map((mo, i) => {
        const w = 1200 / months.length;
        const h = (mo.n / max) * 90;
        const x = i * w + 8;
        const y = 96 - h;
        return (
          <g key={mo.m}>
            <rect x={x} y={y} width={w - 16} height={h} rx="3"
                  fill="url(#histBar)" opacity={mo.n >= 8 ? 1 : 0.7}/>
            <text x={x + (w-16)/2} y="114" textAnchor="middle" fill="#5a6470"
                  fontFamily="JetBrains Mono" fontSize="9.5" fontWeight="800" letterSpacing="0.08em">{mo.m}</text>
            <text x={x + (w-16)/2} y={y - 5} textAnchor="middle" fill="#eef1f4"
                  fontFamily="JetBrains Mono" fontSize="10" fontWeight="800">{mo.n}</text>
          </g>
        );
      })}
      <defs>
        <linearGradient id="histBar" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ff8a4d"/>
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0.55"/>
        </linearGradient>
      </defs>
    </svg>
  );
}

window.PCScreenHistory = PCScreenHistory;

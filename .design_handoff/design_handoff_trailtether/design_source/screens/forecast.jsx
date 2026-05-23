// Trailtether — Weather Forecast (reached from Home weather card "7 DAYS →")

function ScreenForecast() {
  const days = [
    { day:'TODAY',   date:'OCT 26', icon:'sun',   hi:14, lo:6,  wind:18, score:8, label:'Good window'    },
    { day:'TUE',     date:'OCT 27', icon:'sun',   hi:16, lo:7,  wind:12, score:9, label:'Perfect window' },
    { day:'WED',     date:'OCT 28', icon:'cloud', hi:13, lo:5,  wind:28, score:6, label:'Wind from 11am' },
    { day:'THU',     date:'OCT 29', icon:'rain',  hi:9,  lo:3,  wind:34, score:3, label:'Storm forecast' },
    { day:'FRI',     date:'OCT 30', icon:'rain',  hi:8,  lo:2,  wind:42, score:2, label:'Avoid summit'   },
    { day:'SAT',     date:'OCT 31', icon:'cloud', hi:11, lo:4,  wind:18, score:6, label:'Clearing'       },
    { day:'SUN',     date:'NOV 01', icon:'sun',   hi:15, lo:6,  wind:14, score:8, label:'Good again'     },
  ];
  const [pick, setPick] = React.useState(1);
  const sel = days[pick];

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>FORECAST</div>
            <h1 style={{margin:'2px 0 0', font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Drakensberg N</h1>
          </div>
          <button className="icon-btn"><Icon name="pin" size={14} color="var(--tt-ember)"/></button>
        </div>

        <div className="tt-scroll" style={{padding:'4px 18px 24px'}}>
          {/* Big day hero */}
          <div className="card anim-up" style={{position:'relative', overflow:'hidden', padding:'22px 18px', animationDelay:'100ms'}}>
            <div style={{position:'absolute', inset:0,
              background:`radial-gradient(ellipse 70% 60% at 80% 20%, ${heroGlow(sel.icon)}, transparent 60%)`}}/>
            <div style={{position:'relative', display:'flex', alignItems:'center', gap:16}}>
              <BigWxIcon kind={sel.icon}/>
              <div style={{flex:1}}>
                <div style={{font:'700 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.18em'}}>
                  {sel.day} · {sel.date}
                </div>
                <div className="num count-up" style={{font:'900 56px/1 var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.03em', marginTop:6}}>
                  {sel.hi}°<span style={{fontSize:18, color:'var(--tt-text-2)', marginLeft:4, fontWeight:600}}>C</span>
                </div>
                <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:4, letterSpacing:'0.04em'}}>
                  LO {sel.lo}° · WIND {sel.wind} km/h
                </div>
              </div>
              <ScoreOrb score={sel.score}/>
            </div>
            <div style={{marginTop:14, padding:'10px 12px', background:'var(--tt-bg-3)', borderRadius:10, border:'1px solid var(--tt-line)'}}>
              <div style={{font:'700 9.5px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.14em'}}>HIKE WINDOW</div>
              <div style={{font:'700 12.5px var(--tt-font)', color:'var(--tt-text)', marginTop:3}}>{sel.label}</div>
            </div>
          </div>

          {/* 7-day strip */}
          <div className="anim-up" style={{marginTop:14, animationDelay:'200ms'}}>
            <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>7-Day</span>
            <div style={{display:'grid', gridTemplateColumns:'repeat(7, 1fr)', gap:5, marginTop:10}}>
              {days.map((d, i) => (
                <button key={d.day} onClick={() => setPick(i)} style={{
                  display:'flex', flexDirection:'column', alignItems:'center', gap:5,
                  padding:'9px 4px',
                  background: pick === i ? 'var(--tt-ember-dim)' : 'var(--tt-surf)',
                  border: pick === i ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line)',
                  borderRadius:10,
                  cursor:'pointer',
                }}>
                  <span style={{font:'800 9.5px var(--tt-mono)', color: pick===i ? 'var(--tt-ember)' : 'var(--tt-text-3)', letterSpacing:'0.1em'}}>{d.day}</span>
                  <div style={{height:18, display:'grid', placeItems:'center'}}>
                    <WxIconSmall kind={d.icon}/>
                  </div>
                  <span className="num" style={{font:'800 11px var(--tt-mono)', color: pick===i ? 'var(--tt-ember)' : 'var(--tt-text)'}}>{d.hi}°</span>
                  <span style={{font:'700 8.5px var(--tt-mono)',
                    color: d.score >= 7 ? 'var(--tt-green)' : d.score >= 5 ? 'var(--tt-amber)' : 'var(--tt-red)',
                    letterSpacing:'0.06em',
                  }}>{d.score}/10</span>
                </button>
              ))}
            </div>
          </div>

          {/* Hourly graph */}
          <HourlyGraph delay={300}/>

          {/* Detail tiles */}
          <div style={{marginTop:14, display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
            <Stagger base={400} delay={80}>
              <FxTile icon="wind" label="Wind"    value="18" unit="km/h" sub="NE · gusting 28"/>
              <FxTile icon="layers" label="UV"    value="6"  unit="HIGH" sub="11:00 → 15:00"/>
              <FxTile icon="alert"  label="Visibility" value="14" unit="km" sub="High clouds"/>
              <FxTile icon="eye" label="Sunrise" value="05:47" sub="↑ 18:23"/>
            </Stagger>
          </div>

          {/* Alerts */}
          <div className="anim-up" style={{marginTop:14, animationDelay:'600ms'}}>
            <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Alerts (2)</span>
            <div style={{marginTop:10, display:'flex', flexDirection:'column', gap:8}}>
              <AlertRow color="var(--tt-amber)" icon="wind"  title="Wind advisory · Thursday" sub="Gusts 40 km/h on exposed ridges"/>
              <AlertRow color="var(--tt-red)"   icon="alert" title="Severe weather · Friday" sub="Lightning forecast above 1,800 m"/>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function heroGlow(kind) {
  if (kind === 'sun')   return 'rgba(255,138,77,0.30)';
  if (kind === 'cloud') return 'rgba(152,161,172,0.18)';
  if (kind === 'rain')  return 'rgba(90,161,214,0.30)';
  return 'rgba(255,255,255,0.08)';
}

function BigWxIcon({ kind }) {
  if (kind === 'sun') {
    return (
      <svg width="74" height="74" viewBox="0 0 74 74">
        <defs>
          <radialGradient id="bigSunG" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#ffe2c2"/>
            <stop offset="100%" stopColor="#ff6a2c"/>
          </radialGradient>
        </defs>
        <g transform="translate(37,37)">
          <circle r="20" fill="url(#bigSunG)"/>
          {Array.from({length:8}).map((_,i) => {
            const a = i * Math.PI/4;
            return <line key={i}
              x1={Math.cos(a)*26} y1={Math.sin(a)*26}
              x2={Math.cos(a)*32} y2={Math.sin(a)*32}
              stroke="#ff8a4d" strokeWidth="2" strokeLinecap="round" opacity="0.7">
              <animate attributeName="opacity" values="0.4;1;0.4" dur="2.4s" begin={`${i*0.1}s`} repeatCount="indefinite"/>
            </line>;
          })}
        </g>
      </svg>
    );
  }
  if (kind === 'cloud') {
    return (
      <svg width="74" height="64" viewBox="0 0 74 64">
        <ellipse cx="22" cy="42" rx="20" ry="13" fill="#3a4150"/>
        <ellipse cx="48" cy="44" rx="16" ry="10" fill="#3a4150"/>
        <ellipse cx="36" cy="32" rx="14" ry="9" fill="#5a6470"/>
      </svg>
    );
  }
  return (
    <svg width="74" height="74" viewBox="0 0 74 74">
      <ellipse cx="22" cy="34" rx="20" ry="12" fill="#3a4150"/>
      <ellipse cx="48" cy="36" rx="16" ry="9" fill="#3a4150"/>
      {[12,24,36,48,60].map((x,i) => (
        <line key={i} x1={x} y1={48} x2={x-2} y2={66}
          stroke="#5aa1d6" strokeWidth="1.8" strokeLinecap="round" opacity="0.7">
          <animate attributeName="opacity" values="0;0.8;0" dur={`${1.2 + i*0.2}s`} repeatCount="indefinite"/>
        </line>
      ))}
    </svg>
  );
}

function WxIconSmall({ kind }) {
  if (kind === 'sun')   return <svg width="14" height="14" viewBox="0 0 14 14"><circle cx="7" cy="7" r="3" fill="#ff8a4d"/>{Array.from({length:8}).map((_,i) => { const a = i*Math.PI/4; return <line key={i} x1={7+Math.cos(a)*4} y1={7+Math.sin(a)*4} x2={7+Math.cos(a)*6} y2={7+Math.sin(a)*6} stroke="#ff8a4d" strokeWidth="1.2" strokeLinecap="round"/>; })}</svg>;
  if (kind === 'cloud') return <svg width="16" height="12" viewBox="0 0 16 12"><ellipse cx="5" cy="8" rx="4" ry="2.5" fill="#5a6470"/><ellipse cx="10" cy="8" rx="3.5" ry="2" fill="#5a6470"/><ellipse cx="8" cy="6" rx="3" ry="2" fill="#7a8390"/></svg>;
  return <svg width="14" height="14" viewBox="0 0 14 14"><ellipse cx="4" cy="5" rx="3.5" ry="2" fill="#5a6470"/><ellipse cx="9" cy="6" rx="3" ry="1.8" fill="#5a6470"/><line x1="3" y1="9" x2="2" y2="13" stroke="#5aa1d6" strokeWidth="1.2"/><line x1="6" y1="9" x2="5" y2="13" stroke="#5aa1d6" strokeWidth="1.2"/><line x1="9" y1="9" x2="8" y2="13" stroke="#5aa1d6" strokeWidth="1.2"/></svg>;
}

function ScoreOrb({ score }) {
  const color = score >= 7 ? 'var(--tt-green)' : score >= 5 ? 'var(--tt-amber)' : 'var(--tt-red)';
  const dash = (score/10) * 100;
  return (
    <div style={{position:'relative', width:62, height:62, flex:'0 0 auto'}}>
      <svg width="62" height="62" viewBox="0 0 62 62">
        <circle cx="31" cy="31" r="26" fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="4"/>
        <circle cx="31" cy="31" r="26" fill="none" stroke={color} strokeWidth="4"
          strokeLinecap="round" strokeDasharray={`${dash*1.63} 1000`} transform="rotate(-90 31 31)"
          style={{filter:`drop-shadow(0 0 6px ${color})`}}/>
      </svg>
      <div style={{position:'absolute', inset:0, display:'grid', placeItems:'center'}}>
        <div style={{textAlign:'center'}}>
          <div className="num" style={{font:'900 20px var(--tt-mono)', color, letterSpacing:'-0.02em'}}>{score}</div>
          <div style={{font:'700 7.5px var(--tt-font)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>HIKE</div>
        </div>
      </div>
    </div>
  );
}

function HourlyGraph({ delay = 200 }) {
  const w = 320, h = 80, pad = 6;
  const t = [14,15,16,17,16,14,12,10,9,11,13,14];
  const min = 6, max = 18;
  const step = (w - pad*2) / (t.length - 1);
  const top = t.map((v,i) => `${i===0?'M':'L'}${pad + i*step},${h - pad - ((v-min)/(max-min))*(h - pad*2)}`).join(' ');
  const fill = top + ` L ${w-pad},${h-pad} L ${pad},${h-pad} Z`;
  const hours = ['10','12','14','16','18','20'];
  return (
    <div className="card anim-up" style={{marginTop:14, padding:'14px 16px', animationDelay:`${delay}ms`}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:6}}>
        <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Hourly · TODAY</span>
        <span style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)'}}>10:00 → 21:00</span>
      </div>
      <svg width="100%" height={h+10} viewBox={`0 0 ${w} ${h+10}`} preserveAspectRatio="none">
        <defs>
          <linearGradient id="fxHour" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.55"/>
            <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0"/>
          </linearGradient>
        </defs>
        <path d={fill} fill="url(#fxHour)"/>
        <path d={top} fill="none" stroke="#ff8a4d" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
          className="draw-line" style={{['--len']:500, animationDelay:`${delay+150}ms`}}/>
      </svg>
      <div style={{display:'flex', justifyContent:'space-between', marginTop:4, font:'600 9px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.08em'}}>
        {hours.map(h => <span key={h}>{h}</span>)}
      </div>
    </div>
  );
}

function FxTile({ icon, label, value, unit, sub }) {
  return (
    <div className="card" style={{padding:'12px 14px'}}>
      <div style={{display:'flex', alignItems:'center', gap:6}}>
        <Icon name={icon} size={11} color="var(--tt-ember)"/>
        <span style={{font:'700 9px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-3)'}}>{label}</span>
      </div>
      <div style={{display:'flex', alignItems:'baseline', gap:3, marginTop:6}}>
        <span className="num" style={{font:'800 19px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.02em'}}>{value}</span>
        {unit && <span className="num" style={{fontSize:9.5, color:'var(--tt-text-2)', fontWeight:600, letterSpacing:'0.06em'}}>{unit}</span>}
      </div>
      <div style={{font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.02em'}}>{sub}</div>
    </div>
  );
}

function AlertRow({ color, icon, title, sub }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:11,
      padding:'10px 12px',
      background:'var(--tt-surf)',
      border:`1px solid ${color}55`,
      borderLeft:`3px solid ${color}`,
      borderRadius:10,
      cursor:'pointer',
    }}>
      <div style={{width:28, height:28, borderRadius:8, background:`${color}1f`, border:`1px solid ${color}55`,
        display:'grid', placeItems:'center', flex:'0 0 auto'}}>
        <Icon name={icon} size={13} color={color}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-text)'}}>{title}</div>
        <div style={{font:'500 10.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em'}}>{sub}</div>
      </div>
      <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
    </div>
  );
}

window.ScreenForecast = ScreenForecast;

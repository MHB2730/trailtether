// Trailtether — SOS / Emergency screen

function ScreenSOS() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar
          time="10:14"
          right={
            <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-red)', fontSize:10.5, fontWeight:800, letterSpacing:'0.12em', marginRight:4}}>
              <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-red)', boxShadow:'0 0 6px var(--tt-red)', animation:'pulse 0.9s infinite'}}/>
              SOS
            </span>
          }
        />

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <div style={{flex:1, minWidth:0}}>
            <div style={{display:'flex', alignItems:'center', gap:9, marginBottom:4}}>
              <TTLogo size={18}/>
              <span style={{font:'800 12px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <h1 style={{margin:0, font:'800 22px var(--tt-font)', letterSpacing:'-0.02em', color:'var(--tt-text)'}}>Emergency</h1>
            <div className="sub" style={{marginTop:4}}>
              <b style={{color:'var(--tt-red)'}}>INCIDENT #7731</b> · BEACON ALPHA-7
            </div>
          </div>
          <button className="icon-btn" style={{borderColor:'rgba(230,61,46,0.4)', background:'rgba(230,61,46,0.10)'}}>
            <Icon name="phone" size={16} color="var(--tt-red)"/>
          </button>
        </div>

        <div className="tt-scroll">
          <SOSHero/>
          <SOSActions/>
          <Responder/>
          <Hazards/>
          <Timeline/>
        </div>

        <BottomNav active="home"/>
      </div>
    </div>
  );
}

function SOSHero() {
  return (
    <div style={{
      position:'relative',
      padding:'20px 18px 22px',
      background:'radial-gradient(ellipse 80% 70% at 50% 30%, rgba(230,61,46,0.14), transparent 70%)',
      textAlign:'center',
    }}>
      <div style={{position:'relative', width:240, height:240, margin:'0 auto', display:'grid', placeItems:'center'}}>
        {/* Concentric rippling rings */}
        <div style={ringStyle(240, 0)}/>
        <div style={ringStyle(240, 1)}/>
        <div style={ringStyle(240, 2)}/>

        {/* Glow under orb */}
        <div style={{
          position:'absolute', inset:30, borderRadius:'50%',
          background:'radial-gradient(circle, rgba(230,61,46,0.55), rgba(230,61,46,0) 70%)',
        }}/>

        {/* The SOS orb */}
        <div className="anim-pop" style={{
          width:148, height:148, borderRadius:'50%',
          background:'radial-gradient(circle at 35% 30%, #ff6a4d 0%, #d6291f 60%, #82120c 100%)',
          border:'3px solid rgba(255,150,108,0.55)',
          boxShadow:'0 0 50px rgba(230,61,46,0.7), inset 0 -10px 28px rgba(0,0,0,0.42), inset 0 10px 24px rgba(255,255,255,0.18)',
          display:'grid', placeItems:'center',
          position:'relative', zIndex:2,
          animationDelay:'150ms',
        }}>
          <div>
            <div style={{font:'900 40px/1 var(--tt-font)', color:'#fff', letterSpacing:'0.1em', textShadow:'0 2px 10px rgba(0,0,0,0.55)'}}>SOS</div>
            <div style={{font:'800 10px var(--tt-font)', color:'#ffd5c4', letterSpacing:'0.24em', marginTop:8, textAlign:'center'}}>ACTIVE</div>
          </div>
        </div>
      </div>

      <div className="anim-up" style={{marginTop:18, animationDelay:'350ms'}}>
        <div style={{font:'700 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.14em'}}>TRANSMITTING · 03:04:15</div>
        <div className="num count-up" style={{marginTop:8, font:'800 17px var(--tt-mono)', color:'var(--tt-text)', letterSpacing:'-0.01em', animationDelay:'500ms'}}>
          N 47.6062° · W 122.3321°
        </div>
        <div style={{marginTop:4, font:'600 10.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.04em'}}>
          ALT 14.5 m · ACC ± 3 m · WGS84
        </div>
      </div>
    </div>
  );
}

function ringStyle(size, idx) {
  return {
    position:'absolute',
    width: size, height: size,
    borderRadius:'50%',
    border:'2px solid rgba(255,106,44,0.4)',
    background:'rgba(230,61,46,0.06)',
    animation:`ringRipple 3s ${idx * 1}s infinite ease-out`,
    transformOrigin:'center',
  };
}

function SOSActions() {
  return (
    <div className="anim-up" style={{
      padding:'4px 18px 4px',
      display:'grid', gridTemplateColumns:'1fr 1fr', gap:10,
      animationDelay:'500ms',
    }}>
      <button className="pressable" style={{
        height:50, borderRadius:13,
        border:'1px solid var(--tt-line-3)',
        background:'var(--tt-surf-2)',
        color:'var(--tt-text)',
        font:'800 11.5px var(--tt-font)', letterSpacing:'0.12em',
        cursor:'pointer',
        display:'flex', alignItems:'center', justifyContent:'center', gap:7,
      }}>
        <Icon name="radio" size={14}/> SEND SITREP
      </button>
      <button className="pressable" style={{
        height:50, borderRadius:13,
        border:'none',
        background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
        color:'#1a0d04',
        font:'900 11.5px var(--tt-font)', letterSpacing:'0.12em',
        cursor:'pointer',
        display:'flex', alignItems:'center', justifyContent:'center', gap:7,
        boxShadow:'var(--tt-shadow-ember)',
      }}>
        <Icon name="alert" size={14} color="#1a0d04"/> REQUEST SUPPORT
      </button>
    </div>
  );
}

function Responder() {
  return (
    <div style={{padding:'14px 18px 0'}}>
      <div className="card anim-up" style={{padding:'14px 16px', display:'flex', alignItems:'center', gap:14, animationDelay:'650ms'}}>
        <div style={{
          width:42, height:42, borderRadius:11,
          background:'rgba(242,169,59,0.14)',
          border:'1px solid rgba(242,169,59,0.3)',
          display:'grid', placeItems:'center', flex:'0 0 auto',
          animation:'glowPulse 2.2s infinite',
        }}>
          <Icon name="shield" size={18} color="var(--tt-amber)"/>
        </div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{display:'flex', alignItems:'center', gap:8}}>
            <span style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-text)', letterSpacing:'0.02em'}}>RESCUE TEAM #4</span>
            <span style={{padding:'2px 6px', borderRadius:4, background:'rgba(242,169,59,0.18)', font:'800 8.5px var(--tt-mono)', color:'var(--tt-amber)', letterSpacing:'0.12em'}}>EN ROUTE</span>
          </div>
          <div style={{font:'600 10.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:4}}>ETA <span style={{color:'var(--tt-text)'}}>4 min</span> · 620 m NW</div>
        </div>
        <div style={{display:'flex', alignItems:'flex-end', gap:3}}>
          {[6,10,14,18].map((h,i) => (
            <div key={i} style={{width:3.5, height:h, background: i < 3 ? 'var(--tt-green)' : 'var(--tt-text-3)', borderRadius:1}}/>
          ))}
        </div>
      </div>
    </div>
  );
}

function Hazards() {
  return (
    <div style={{padding:'18px 18px 0'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10}}>
        <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>
          Nearby Hazards <span style={{color:'var(--tt-text-3)'}}>(3)</span>
        </span>
        <span style={{font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em'}}>SEE ALL →</span>
      </div>
      <div style={{display:'flex', flexDirection:'column', gap:8}}>
        <Stagger base={800} delay={80}>
          <HazardRow idx={1} icon="rock"  title="Structural Collapse" sub="98 m NW · Alaskan Way S"     risk="high"     color="var(--tt-red)"   time="10:09"/>
          <HazardRow idx={2} icon="flame" title="Fire / Smoke"        sub="140 m N · Elliot Bay Blvd"   risk="moderate" color="var(--tt-amber)" time="10:10"/>
          <HazardRow idx={3} icon="alert" title="Hazmat Spill"        sub="210 m E · S Washington St"   risk="info"     color="var(--tt-blue)"  time="10:12"/>
        </Stagger>
      </div>
    </div>
  );
}

function HazardRow({ idx, icon, title, sub, risk, color, time }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      background:'var(--tt-surf)',
      border:`1px solid ${color}33`,
      borderLeft:`3px solid ${color}`,
      borderRadius:12,
      padding:'12px 14px',
      cursor:'pointer',
    }}>
      <div style={{
        width:34, height:34, borderRadius:'50%',
        background:`${color}1f`,
        border:`1px solid ${color}40`,
        display:'grid', placeItems:'center', flex:'0 0 auto', position:'relative',
      }}>
        <Icon name={icon} size={15} color={color}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', gap:6}}>
          <span style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-text)', letterSpacing:'0.01em'}}>{title}</span>
          <span style={{font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)'}}>{time}</span>
        </div>
        <div style={{font:'500 10.5px/1.3 var(--tt-mono)', color:'var(--tt-text-2)', marginTop:3}}>{sub}</div>
        <span style={{display:'inline-block', marginTop:6, padding:'2px 6px', borderRadius:4, background:`${color}1f`, font:'800 8.5px var(--tt-mono)', color, letterSpacing:'0.12em'}}>
          {risk.toUpperCase()} RISK
        </span>
      </div>
    </div>
  );
}

function Timeline() {
  const events = [
    { time:'14:31', label:'SOS Received',             color:'var(--tt-red)',    done:true  },
    { time:'14:33', label:'Dispatch Confirmed',       color:'var(--tt-amber)',  done:true  },
    { time:'14:35', label:'Rescue Team #4 Dispatched',color:'var(--tt-ember)',  done:true  },
    { time:'14:39', label:'Awaiting On-Scene',        color:'var(--tt-text-3)', active:true },
  ];
  return (
    <div style={{padding:'18px 18px 24px'}}>
      <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Incident Timeline</span>
      <div className="card anim-up" style={{marginTop:10, padding:'16px', position:'relative', animationDelay:'1100ms'}}>
        <div style={{position:'absolute', left:31, top:22, bottom:22, width:2, background:'var(--tt-line)'}}/>
        <div style={{display:'flex', flexDirection:'column', gap:14}}>
          {events.map((e, i) => (
            <div key={i} className="anim-in" style={{display:'flex', alignItems:'center', gap:14, position:'relative', zIndex:1, animationDelay:`${1200 + i*100}ms`}}>
              <div style={{
                width:16, height:16, borderRadius:'50%',
                background: e.done ? e.color : '#0a0c0f',
                border: `2px solid ${e.color}`,
                boxShadow: e.active ? `0 0 12px ${e.color}, 0 0 0 4px rgba(255,106,44,0.08)` : 'none',
                display:'grid', placeItems:'center', flex:'0 0 auto',
                animation: e.active ? 'glowPulse 2s infinite' : 'none',
              }}>
                {e.active && <div style={{width:6, height:6, borderRadius:'50%', background:e.color, animation:'pulse 1.2s infinite'}}/>}
                {e.done && <Icon name="check" size={9} color="#1a0d04" strokeWidth={3}/>}
              </div>
              <span className="num" style={{font:'700 11px var(--tt-mono)', color: e.done ? 'var(--tt-text-2)' : 'var(--tt-text-3)', width:42}}>{e.time}</span>
              <span style={{
                font: e.active ? '800 12.5px var(--tt-font)' : '600 12.5px var(--tt-font)',
                color: e.done ? 'var(--tt-text)' : 'var(--tt-text-3)',
                flex:1,
              }}>{e.label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

window.ScreenSOS = ScreenSOS;

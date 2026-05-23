// Trailtether — Safety Center screen

function ScreenSafety() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar
          time="10:09"
          right={
            <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-green)', fontSize:10.5, fontWeight:700, letterSpacing:'0.1em', marginRight:4}}>
              <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.6s infinite'}}/>
              TETHERED
            </span>
          }
        />

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>SAFETY</div>
            <h1 style={{margin:'2px 0 0', font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Safety Center</h1>
          </div>
          <button className="icon-btn" style={{borderColor:'rgba(230,61,46,0.4)', background:'rgba(230,61,46,0.10)'}}>
            <Icon name="radio" size={15} color="var(--tt-red)"/>
          </button>
        </div>

        <div className="tt-scroll" style={{padding:'4px 18px 24px'}}>
          <ActivePlanCard/>
          <BigSosButton/>
          <EmergencyContacts/>
          <SafetyChecklist/>
          <BasecampPairing/>
        </div>

        <BottomNav active="profile"/>
      </div>
    </div>
  );
}

function ActivePlanCard() {
  return (
    <div className="card anim-up" style={{padding:'16px 18px', marginTop:10, position:'relative', overflow:'hidden'}}>
      <div style={{position:'absolute', top:-30, right:-30, width:140, height:140, borderRadius:'50%', background:'radial-gradient(circle, rgba(76,195,138,0.18), transparent 70%)', pointerEvents:'none'}}/>

      <div style={{display:'flex', alignItems:'center', gap:8}}>
        <span style={{width:6, height:6, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.4s infinite'}}/>
        <span style={{font:'800 10px var(--tt-mono)', color:'var(--tt-green)', letterSpacing:'0.18em'}}>ACTIVE PLAN · TETHERED</span>
      </div>
      <div style={{font:'800 17px var(--tt-font)', color:'var(--tt-text)', marginTop:10, letterSpacing:'-0.01em'}}>Mt. Marcy Summit Trail</div>
      <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.04em'}}>EXPECTED RETURN · OCT 28 · 19:00</div>

      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:10, marginTop:14}}>
        <PlanDetail label="Backpack"  value="Orange · 65L"/>
        <PlanDetail label="Tent"      value="—"/>
        <PlanDetail label="Watchers"  value="2 paired"/>
        <PlanDetail label="Last ping" value="2 min ago" green/>
      </div>

      <button className="pressable" style={{
        width:'100%', marginTop:14,
        padding:'10px 14px', borderRadius:10,
        background:'transparent', border:'1px solid var(--tt-line-3)',
        color:'var(--tt-ember)',
        font:'800 11px var(--tt-font)', letterSpacing:'0.14em',
        cursor:'pointer',
      }}>EDIT PLAN</button>
    </div>
  );
}

function PlanDetail({ label, value, green }) {
  return (
    <div>
      <div style={{font:'700 9.5px var(--tt-font)', color:'var(--tt-text-3)', letterSpacing:'0.16em', textTransform:'uppercase'}}>{label}</div>
      <div style={{font:'700 12.5px var(--tt-font)', color: green ? 'var(--tt-green)' : 'var(--tt-text)', marginTop:3}}>{value}</div>
    </div>
  );
}

function BigSosButton() {
  return (
    <div className="anim-up" style={{
      marginTop:14, padding:'20px 18px',
      background:'radial-gradient(ellipse 80% 70% at 50% 50%, rgba(230,61,46,0.16), transparent 75%)',
      borderRadius:18,
      animationDelay:'250ms',
    }}>
      <div style={{position:'relative', width:180, height:180, margin:'0 auto', display:'grid', placeItems:'center'}}>
        {/* Ripple rings */}
        {[0, 1.4].map((d, i) => (
          <div key={i} style={{
            position:'absolute', width:180, height:180, borderRadius:'50%',
            border:'2px solid rgba(255,106,44,0.4)',
            background:'rgba(230,61,46,0.05)',
            animation:`ringRipple 3s ${d}s infinite ease-out`,
          }}/>
        ))}
        {/* Glow */}
        <div style={{position:'absolute', inset:30, borderRadius:'50%', background:'radial-gradient(circle, rgba(230,61,46,0.5), transparent 70%)'}}/>
        {/* The orb */}
        <button className="pressable" style={{
          width:120, height:120, borderRadius:'50%',
          background:'radial-gradient(circle at 35% 30%, #ff6a4d, #d6291f 60%, #82120c)',
          border:'3px solid rgba(255,150,108,0.55)',
          cursor:'pointer',
          boxShadow:'0 0 40px rgba(230,61,46,0.65), inset 0 -8px 18px rgba(0,0,0,0.4), inset 0 8px 18px rgba(255,255,255,0.18)',
          display:'grid', placeItems:'center',
          position:'relative', zIndex:2,
        }}>
          <div>
            <div style={{font:'900 28px/1 var(--tt-font)', color:'#fff', letterSpacing:'0.1em'}}>SOS</div>
            <div style={{font:'800 8px var(--tt-font)', color:'#ffd5c4', letterSpacing:'0.22em', marginTop:6}}>HOLD 3s</div>
          </div>
        </button>
      </div>
      <div style={{textAlign:'center', marginTop:6, font:'600 11.5px/1.5 var(--tt-font)', color:'var(--tt-text-2)'}}>
        Press and hold to broadcast your location and trigger emergency response.
      </div>
    </div>
  );
}

function EmergencyContacts() {
  return (
    <div className="anim-up" style={{marginTop:18, animationDelay:'400ms'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10}}>
        <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Emergency Contacts</span>
        <span style={{font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em'}}>EDIT →</span>
      </div>
      <div className="card" style={{padding:0, overflow:'hidden'}}>
        <ContactRow name="MSAR · Mountain Rescue" sub="24/7 · Drakensberg" number="074 125 1385" type="rescue"/>
        <ContactRow name="National Emergency"     sub="ER24 · ambulance"    number="084 124"     type="ambulance" isLast/>
      </div>

      <div style={{marginTop:10, display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
        <Stagger base={500} delay={70}>
          <ContactRow name="Sarah Davies"  sub="Spouse"            number="+27 82 123 4567" tile/>
          <ContactRow name="James Carter" sub="Hiking partner"     number="+27 71 987 6543" tile/>
        </Stagger>
      </div>
    </div>
  );
}

function ContactRow({ name, sub, number, type, isLast, tile }) {
  const accent = type === 'rescue' ? 'var(--tt-red)' : type === 'ambulance' ? 'var(--tt-amber)' : 'var(--tt-ember)';
  if (tile) {
    return (
      <div className="card pressable" style={{padding:'12px 14px'}}>
        <div style={{display:'flex', alignItems:'center', gap:9}}>
          <div style={{
            width:32, height:32, borderRadius:'50%',
            background:'var(--tt-ember-dim)',
            border:'1px solid rgba(255,106,44,0.32)',
            display:'grid', placeItems:'center', flex:'0 0 auto',
          }}>
            <Icon name="phone" size={13} color="var(--tt-ember)"/>
          </div>
          <div style={{flex:1, minWidth:0}}>
            <div style={{font:'800 12px var(--tt-font)', color:'var(--tt-text)'}}>{name}</div>
            <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>{sub}</div>
          </div>
        </div>
        <div className="num" style={{font:'700 12px var(--tt-mono)', color:'var(--tt-ember)', marginTop:8, letterSpacing:'-0.005em'}}>{number}</div>
      </div>
    );
  }
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'13px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
    }}>
      <div style={{
        width:36, height:36, borderRadius:10,
        background:`${accent}1f`,
        border:`1px solid ${accent}40`,
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name={type === 'rescue' ? 'shield' : 'phone'} size={15} color={accent}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'800 13px var(--tt-font)', color:'var(--tt-text)'}}>{name}</div>
        <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>{sub}</div>
      </div>
      <div className="num" style={{font:'800 13px var(--tt-mono)', color: accent, letterSpacing:'-0.01em'}}>{number}</div>
    </div>
  );
}

function SafetyChecklist() {
  const items = [
    { id:'water',   label:'Water & hydration',  sub:'2L minimum · refill stop at km 5.8', done:true },
    { id:'layers',  label:'Layers',             sub:'Rain shell, fleece, beanie',         done:true },
    { id:'food',    label:'Food',               sub:'Trail snacks · 1 spare ration',      done:true },
    { id:'first',   label:'First aid',          sub:'Bandages, tape, blister kit',        done:false },
    { id:'light',   label:'Headlamp',           sub:'Charged · spare battery',            done:true },
    { id:'phone',   label:'Phone fully charged', sub:'Plus power bank',                   done:false },
  ];
  const completed = items.filter(i => i.done).length;
  return (
    <div className="anim-up" style={{marginTop:18, animationDelay:'500ms'}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10}}>
        <span style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)'}}>Gear Checklist <span style={{color:'var(--tt-text-3)'}}>({completed}/{items.length})</span></span>
        <div style={{flex:1, height:4, margin:'0 12px', background:'var(--tt-surf-2)', borderRadius:2, overflow:'hidden'}}>
          <div style={{
            height:'100%',
            width: `${(completed/items.length)*100}%`,
            background:'linear-gradient(90deg, #ff6a2c, #ff8a4d)',
            borderRadius:2, boxShadow:'0 0 6px rgba(255,106,44,0.4)',
            transition:'width 600ms ease',
          }}/>
        </div>
        <span className="num" style={{font:'800 12px var(--tt-mono)', color:'var(--tt-ember)'}}>{Math.round(completed/items.length*100)}%</span>
      </div>
      <div className="card" style={{padding:0, overflow:'hidden'}}>
        {items.map((it, idx) => (
          <ChecklistRow key={it.id} {...it} isLast={idx === items.length-1}/>
        ))}
      </div>
    </div>
  );
}

function ChecklistRow({ label, sub, done, isLast }) {
  const [v, setV] = React.useState(done);
  return (
    <div className="pressable" onClick={() => setV(x => !x)} style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'12px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
      cursor:'pointer',
    }}>
      <div style={{
        width:24, height:24, borderRadius:7,
        background: v ? 'var(--tt-ember)' : 'transparent',
        border:`2px solid ${v ? 'var(--tt-ember)' : 'var(--tt-line-3)'}`,
        display:'grid', placeItems:'center', flex:'0 0 auto',
        transition:'background 200ms ease, border-color 200ms ease',
        boxShadow: v ? '0 0 10px rgba(255,106,44,0.4)' : 'none',
      }}>
        {v && <Icon name="check" size={12} color="#1a0d04" strokeWidth={3}/>}
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{
          font:'700 13px var(--tt-font)',
          color: v ? 'var(--tt-text)' : 'var(--tt-text-2)',
          textDecoration: v ? 'line-through' : 'none',
          textDecorationColor: 'var(--tt-text-3)',
          transition:'color 200ms ease',
        }}>{label}</div>
        <div style={{font:'600 10.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.02em'}}>{sub}</div>
      </div>
    </div>
  );
}

function BasecampPairing() {
  return (
    <div className="anim-up" style={{marginTop:18, animationDelay:'650ms'}}>
      <div style={{font:'700 11px var(--tt-font)', letterSpacing:'0.16em', textTransform:'uppercase', color:'var(--tt-text-2)', marginBottom:10}}>Base Camp · Tether</div>

      <div className="card" style={{padding:'14px 16px', position:'relative', overflow:'hidden'}}>
        {/* tether glow */}
        <div style={{
          position:'absolute', inset:0,
          background:'radial-gradient(circle at 0% 50%, rgba(255,106,44,0.12), transparent 50%), radial-gradient(circle at 100% 50%, rgba(76,195,138,0.12), transparent 50%)',
          pointerEvents:'none',
        }}/>

        <div style={{display:'flex', alignItems:'center', gap:12, position:'relative'}}>
          {/* Phone */}
          <div style={{
            width:36, height:48, borderRadius:6, border:'2px solid var(--tt-ember)',
            background:'#0a0c0f', display:'grid', placeItems:'center', flex:'0 0 auto',
          }}>
            <div style={{width:4, height:4, borderRadius:'50%', background:'var(--tt-ember)', boxShadow:'0 0 6px var(--tt-ember)', animation:'pulse 1.6s infinite'}}/>
          </div>

          {/* Tether line with traveling dots */}
          <div style={{flex:1, position:'relative', height:24, display:'grid', placeItems:'center'}}>
            <div style={{position:'absolute', inset:'50% 0', height:2, background:'linear-gradient(90deg, var(--tt-ember) 0%, var(--tt-line-3) 50%, var(--tt-green) 100%)', borderRadius:1}}/>
            {[0, 1, 2].map(i => (
              <div key={i} style={{
                position:'absolute',
                width:5, height:5, borderRadius:'50%',
                background:'#ff8a4d',
                top:'50%', marginTop:-2.5,
                boxShadow:'0 0 6px #ff8a4d',
                animation: `tetherTravel 2.6s ${i*0.7}s infinite linear`,
              }}/>
            ))}
          </div>

          {/* Computer/house */}
          <div style={{
            width:44, height:42, borderRadius:6, border:'2px solid var(--tt-green)',
            background:'#0a0c0f', display:'grid', placeItems:'center', flex:'0 0 auto',
          }}>
            <Icon name="home" size={16} color="var(--tt-green)"/>
          </div>
        </div>

        <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginTop:14, position:'relative'}}>
          <div style={{flex:1, minWidth:0}}>
            <div style={{font:'800 13px var(--tt-font)', color:'var(--tt-text)'}}>Home · Sarah's PC</div>
            <div style={{font:'600 10.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.02em'}}>Paired 14 days · Last sync 2 min ago</div>
          </div>
          <span style={{display:'inline-flex', alignItems:'center', gap:5, padding:'4px 9px', borderRadius:6, background:'rgba(76,195,138,0.14)', border:'1px solid rgba(76,195,138,0.32)', font:'800 9px var(--tt-mono)', color:'var(--tt-green)', letterSpacing:'0.12em'}}>
            <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 4px var(--tt-green)', animation:'pulse 1.6s infinite'}}/>
            CONNECTED
          </span>
        </div>
      </div>

      <style>{`@keyframes tetherTravel {
        0%   { left: 0%; opacity: 0; }
        10%  { opacity: 1; }
        90%  { opacity: 1; }
        100% { left: 100%; opacity: 0; }
      }`}</style>
    </div>
  );
}

window.ScreenSafety = ScreenSafety;

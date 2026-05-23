// Trailtether — All Achievements (full grid view from Profile → "VIEW ALL")

function ScreenAchievements() {
  const [tab, setTab] = React.useState('all'); // all | unlocked | locked
  const all = [
    { id:'storm',    icon:'wind',       label:'Storm Survivor',  sub:'Hike through warning',  rarity:'epic',      progress:1.0, unlocked:true,  earned:'OCT 24' },
    { id:'first',    icon:'play',       label:'First Steps',     sub:'Complete 1st hike',     rarity:'common',    progress:1.0, unlocked:true,  earned:'JAN 06' },
    { id:'highrise', icon:'mountain',   label:'4K Club',         sub:'4,000m elevation',      rarity:'rare',      progress:1.0, unlocked:true,  earned:'MAR 14' },
    { id:'tether',   icon:'tether',     label:'Tethered',        sub:'Pair a base-camp PC',   rarity:'rare',      progress:1.0, unlocked:true,  earned:'JAN 09' },
    { id:'gpx',      icon:'route',      label:'Plan Maker',      sub:'Upload 5 GPX routes',   rarity:'common',    progress:1.0, unlocked:true,  earned:'FEB 22' },
    { id:'lead',     icon:'people',     label:'Team Lead',       sub:'Lead a group hike',     rarity:'rare',      progress:1.0, unlocked:true,  earned:'MAY 30' },
    { id:'dawn',     icon:'eye',        label:'Dawn Patrol',     sub:'Start before 05:00',    rarity:'rare',      progress:1.0, unlocked:true,  earned:'JUN 18' },
    { id:'rain',     icon:'wind',       label:'Rain Dancer',     sub:'Hike in heavy rain',    rarity:'common',    progress:1.0, unlocked:true,  earned:'AUG 04' },

    { id:'cave',     icon:'rock',       label:'Caver',           sub:'Visit 10 shelters',     rarity:'rare',      progress:0.7, unlocked:false },
    { id:'5k',       icon:'mountain',   label:'5K Club',         sub:'5,000m peak',           rarity:'epic',      progress:0.4, unlocked:false },
    { id:'navmaster',icon:'compass',    label:'Nav Master',      sub:'30 trails completed',   rarity:'rare',      progress:0.6, unlocked:false },
    { id:'sos',      icon:'shield',     label:'First Responder', sub:'Help in an incident',   rarity:'legendary', progress:0.0, unlocked:false },
    { id:'centurion',icon:'route',      label:'Centurion',       sub:'100 km in a month',     rarity:'epic',      progress:0.55, unlocked:false },
    { id:'allnight', icon:'flame',      label:'All-Night',       sub:'Sleep on a peak',       rarity:'legendary', progress:0.0, unlocked:false },
    { id:'winter',   icon:'crosshair',  label:'Winter Warrior',  sub:'Snow-line hike',        rarity:'epic',      progress:0.0, unlocked:false },
    { id:'guide',    icon:'people',     label:'Mountain Guide',  sub:'Lead 25 group hikes',   rarity:'legendary', progress:0.04, unlocked:false },
  ];

  const list = tab === 'all' ? all : tab === 'unlocked' ? all.filter(a => a.unlocked) : all.filter(a => !a.unlocked);
  const unlockedCount = all.filter(a => a.unlocked).length;

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:6}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <h1 style={{margin:0, font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Achievements</h1>
            <div className="sub" style={{marginTop:3}}>
              <b style={{color:'var(--tt-ember)'}}>{unlockedCount}/{all.length} unlocked</b> · {Math.round(unlockedCount/all.length*100)}% COMPLETE
            </div>
          </div>
          <button className="icon-btn"><Icon name="send-fill" size={13} color="var(--tt-ember)"/></button>
        </div>

        {/* Progress bar */}
        <div style={{padding:'2px 18px 0'}}>
          <div style={{height:6, background:'var(--tt-surf-2)', borderRadius:3, overflow:'hidden'}}>
            <div style={{
              height:'100%', width:`${(unlockedCount/all.length)*100}%`,
              background:'linear-gradient(90deg, #ff6a2c, #ff8a4d)',
              borderRadius:3, boxShadow:'0 0 10px rgba(255,106,44,0.45)',
              transition:'width 800ms cubic-bezier(0.2,0.7,0.2,1)',
            }}/>
          </div>
        </div>

        {/* Segmented */}
        <div style={{padding:'12px 18px 0'}}>
          <div className="segmented">
            <div className={`seg ${tab==='all'?'active':''}`}      onClick={()=>setTab('all')}>All</div>
            <div className={`seg ${tab==='unlocked'?'active':''}`} onClick={()=>setTab('unlocked')}>Unlocked</div>
            <div className={`seg ${tab==='locked'?'active':''}`}   onClick={()=>setTab('locked')}>Locked</div>
            <div className="indicator" style={{
              left: tab==='all' ? 4 : tab==='unlocked' ? '34%' : '67%',
              width: '32%',
            }}/>
          </div>
        </div>

        <div className="tt-scroll" style={{padding:'14px 18px 24px'}}>
          <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:10}}>
            <Stagger base={120} delay={50}>
              {list.map(a => <AchievementBadgeLarge key={a.id} {...a}/>)}
            </Stagger>
          </div>
        </div>

        <BottomNav active="profile"/>

        <style>{`
          @keyframes ach2-ring-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
          @keyframes ach2-breathe   { 0%,100% { transform: scale(1); } 50% { transform: scale(1.05); } }
          @keyframes ach2-sweep {
            0%   { background-position: -160% 0; }
            70%  { background-position: 260% 0; }
            100% { background-position: 260% 0; }
          }
        `}</style>
      </div>
    </div>
  );
}

const RARITY2 = {
  common:    { label:'COMMON',    ring:'#5a6470', glow:'rgba(152,161,172,0.5)',  fill:'#5a6470' },
  rare:      { label:'RARE',      ring:'#5aa1d6', glow:'rgba(90,161,214,0.55)',  fill:'#5aa1d6' },
  epic:      { label:'EPIC',      ring:'#ff6a2c', glow:'rgba(255,106,44,0.75)',  fill:'#ff8a4d' },
  legendary: { label:'LEGENDARY', ring:'#f2a93b', glow:'rgba(242,169,59,0.85)',  fill:'#f2a93b' },
};

function AchievementBadgeLarge({ icon, label, sub, rarity, progress, unlocked, earned }) {
  const r = RARITY2[rarity] || RARITY2.common;
  return (
    <div className="pressable" style={{
      position:'relative',
      display:'flex', flexDirection:'column', alignItems:'center', gap:7,
      padding:'14px 8px 12px',
      background:'var(--tt-surf)',
      border:`1px solid ${unlocked ? r.ring+'55' : 'var(--tt-line)'}`,
      borderRadius:12,
      overflow:'hidden',
      cursor:'pointer',
    }}>
      {unlocked && (
        <>
          <div style={{
            position:'absolute', inset:0,
            background:`radial-gradient(circle at 50% 18%, ${r.glow.replace(/0\.\d+/g, '0.18')}, transparent 70%)`,
            pointerEvents:'none',
          }}/>
          <div style={{
            position:'absolute', inset:0,
            background:'linear-gradient(110deg, transparent 40%, rgba(255,255,255,0.10) 50%, transparent 60%)',
            backgroundSize:'250% 100%',
            animation:'ach2-sweep 6s ease-in-out infinite',
            mixBlendMode:'overlay',
            pointerEvents:'none',
          }}/>
        </>
      )}

      {/* Coin */}
      <div style={{ position:'relative', width:56, height:56, display:'grid', placeItems:'center' }}>
        {unlocked && (
          <div style={{
            position:'absolute', inset:0, borderRadius:'50%',
            background:`conic-gradient(from 0deg, ${r.ring} 0%, transparent 30%, ${r.ring} 55%, transparent 80%, ${r.ring} 100%)`,
            animation:'ach2-ring-spin 8s linear infinite',
            filter:`drop-shadow(0 0 6px ${r.glow})`,
            mask:'radial-gradient(circle, transparent 62%, black 65%)',
            WebkitMask:'radial-gradient(circle, transparent 62%, black 65%)',
          }}/>
        )}
        {!unlocked && progress > 0 && (
          <div style={{
            position:'absolute', inset:0, borderRadius:'50%',
            background:`conic-gradient(var(--tt-ember) ${progress*360}deg, rgba(255,255,255,0.06) ${progress*360}deg)`,
            mask:'radial-gradient(circle, transparent 62%, black 65%)',
            WebkitMask:'radial-gradient(circle, transparent 62%, black 65%)',
          }}/>
        )}
        <div style={{
          width:46, height:46, borderRadius:'50%',
          background: unlocked
            ? `radial-gradient(circle at 30% 25%, #ffd6b0 0%, ${r.fill} 38%, #2a0d04 100%)`
            : 'linear-gradient(135deg, #1a2029, #0a0c0f)',
          border:`2px solid ${unlocked ? r.ring : 'var(--tt-line-2)'}`,
          display:'grid', placeItems:'center',
          boxShadow: unlocked
            ? `0 0 12px ${r.glow}, inset 0 -3px 6px rgba(0,0,0,0.4), inset 0 2px 5px rgba(255,255,255,0.25)`
            : 'inset 0 1px 0 rgba(255,255,255,0.04)',
          animation: unlocked ? 'ach2-breathe 3.4s ease-in-out infinite' : 'none',
        }}>
          <Icon name={icon} size={18} color={unlocked ? '#1a0d04' : 'var(--tt-text-3)'} strokeWidth={2.2}/>
        </div>
      </div>

      <span style={{font:'800 10.5px/1.2 var(--tt-font)', color: unlocked ? 'var(--tt-text)' : 'var(--tt-text-3)', textAlign:'center', letterSpacing:'0.02em', position:'relative'}}>{label}</span>
      <span style={{font:'500 9px/1.3 var(--tt-mono)', color:'var(--tt-text-3)', textAlign:'center', maxWidth:'95%', letterSpacing:'0.02em', position:'relative'}}>{sub}</span>

      {/* Rarity / progress badge */}
      <div style={{
        position:'relative',
        padding:'2px 7px', borderRadius:4,
        background: unlocked ? `${r.ring}1f` : 'rgba(255,255,255,0.03)',
        border: `1px solid ${unlocked ? r.ring+'55' : 'var(--tt-line-2)'}`,
        font:'800 8.5px var(--tt-mono)', letterSpacing:'0.14em',
        color: unlocked ? r.fill : 'var(--tt-text-3)',
      }}>
        {unlocked ? r.label : (progress > 0 ? `${Math.round(progress*100)}%` : 'LOCKED')}
      </div>

      {unlocked && earned && (
        <span style={{font:'700 8.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.12em', position:'relative'}}>
          {earned}
        </span>
      )}
    </div>
  );
}

window.ScreenAchievements = ScreenAchievements;

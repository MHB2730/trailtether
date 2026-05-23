// Trailtether — Notifications screen (bell icon throughout the app)

function ScreenNotifications() {
  const [filter, setFilter] = React.useState('all');
  const NOTIFS = [
    { id:1, kind:'weather', urgent:true,  time:'2m ago', title:'Storm warning · 90 min',
      sub:'Severe wind + lightning forecast for Cathedral Peak. Consider Cave #47.',
      action:'View forecast', read:false },
    { id:2, kind:'hazard',  time:'18m ago', title:'Loose rock reported',
      sub:'Wonderland Trail km 4.8 · reported by Sarah L.',
      action:'View report', read:false },
    { id:3, kind:'team',    time:'34m ago', title:'Mike K. shared their location',
      sub:'Sunrise Camp · 8.1 km · battery 71%',
      action:'Open map', read:false },
    { id:4, kind:'mention', time:'1h ago',  title:'Emily R. mentioned you',
      sub:'"@john — meet at the Wonderland junction. Bring the trekking pole."',
      action:'Reply', read:true },
    { id:5, kind:'achievement', time:'Yesterday', title:'Achievement unlocked',
      sub:'Storm Survivor · Completed hike through severe weather warning.',
      action:'Share', read:true },
    { id:6, kind:'team',    time:'Yesterday', title:'Sarah L. invited you to a hike',
      sub:'Alpine Adventure · Cathedral Peak · OCT 28 · 06:00',
      action:'RSVP', read:true },
    { id:7, kind:'system',  time:'2d ago',    title:'New region available offline',
      sub:'Drakensberg Central · 124 MB · download to use without signal.',
      action:'Download', read:true },
    { id:8, kind:'review',  time:'3d ago',    title:'Trail report submitted',
      sub:'Your report on Mt. Marcy is live. 12 hikers helped so far.',
      action:'View', read:true },
  ];
  const list = filter === 'all' ? NOTIFS : NOTIFS.filter(n => n.kind === filter);
  const unread = NOTIFS.filter(n => !n.read).length;

  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:6}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <h1 style={{margin:0, font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Notifications</h1>
            <div className="sub" style={{marginTop:3}}>
              <b style={{color:'var(--tt-ember)'}}>{unread} unread</b> · LAST CHECK 10:08
            </div>
          </div>
          <button className="icon-btn"><Icon name="check" size={14} color="var(--tt-ember)" strokeWidth={2.4}/></button>
          <button className="icon-btn"><Icon name="settings" size={14} color="var(--tt-text-2)"/></button>
        </div>

        {/* Filter chips */}
        <div style={{padding:'4px 14px 0', display:'flex', gap:6, overflowX:'auto', scrollbarWidth:'none'}}>
          {[
            { k:'all',         label:'ALL' },
            { k:'weather',     label:'WEATHER' },
            { k:'hazard',      label:'HAZARDS' },
            { k:'team',        label:'TEAM' },
            { k:'mention',     label:'MENTIONS' },
            { k:'achievement', label:'BADGES' },
          ].map(c => (
            <button key={c.k} onClick={() => setFilter(c.k)} style={{
              flex:'0 0 auto',
              padding:'7px 12px', borderRadius:999,
              background: filter===c.k ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
              border: filter===c.k ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
              color: filter===c.k ? 'var(--tt-ember)' : 'var(--tt-text-2)',
              font:'800 10px var(--tt-mono)', letterSpacing:'0.14em',
              cursor:'pointer', whiteSpace:'nowrap',
            }}>{c.label}</button>
          ))}
        </div>

        <div className="tt-scroll" style={{padding:'10px 18px 16px'}}>
          <Stagger base={120} delay={70}>
            {list.map(n => <NotifRow key={n.id} {...n}/>)}
          </Stagger>
          <div style={{textAlign:'center', padding:'14px 0', font:'700 10px var(--tt-mono)', color:'var(--tt-text-4)', letterSpacing:'0.16em'}}>
            END · {list.length} NOTIFICATIONS
          </div>
        </div>

        <BottomNav active="home"/>
      </div>
    </div>
  );
}

const NOTIF_META = {
  weather:     { color:'#5aa1d6', icon:'wind' },
  hazard:      { color:'#f2a93b', icon:'alert' },
  team:        { color:'#4cc38a', icon:'people' },
  mention:     { color:'#ff8a4d', icon:'message' },
  achievement: { color:'#ff6a2c', icon:'flame' },
  system:      { color:'#5a6470', icon:'settings' },
  review:      { color:'#4cc38a', icon:'check' },
};

function NotifRow({ kind, urgent, time, title, sub, action, read }) {
  const m = NOTIF_META[kind] || NOTIF_META.system;
  return (
    <div className="pressable" style={{
      display:'flex', gap:12, alignItems:'flex-start',
      padding:'12px 14px',
      background: read ? 'transparent' : 'var(--tt-surf)',
      border:`1px solid ${urgent ? 'rgba(230,61,46,0.36)' : (read ? 'var(--tt-line)' : 'var(--tt-line-2)')}`,
      borderLeft:`3px solid ${urgent ? 'var(--tt-red)' : m.color}`,
      borderRadius:11,
      marginBottom:8,
      cursor:'pointer',
      position:'relative',
    }}>
      {!read && (
        <div style={{
          position:'absolute', top:14, right:14,
          width:7, height:7, borderRadius:'50%',
          background:'var(--tt-ember)',
          boxShadow:'0 0 6px var(--tt-ember)',
          animation:'pulse 1.6s infinite',
        }}/>
      )}
      <div style={{
        width:32, height:32, borderRadius:9,
        background:`${m.color}1f`, border:`1px solid ${m.color}55`,
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name={m.icon} size={14} color={m.color}/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{display:'flex', alignItems:'center', gap:6}}>
          {urgent && <span style={{padding:'1px 5px', borderRadius:3, background:'rgba(230,61,46,0.18)', font:'900 8px var(--tt-mono)', color:'var(--tt-red)', letterSpacing:'0.14em'}}>URGENT</span>}
          <span style={{font:'800 12.5px var(--tt-font)', color: read ? 'var(--tt-text-2)' : 'var(--tt-text)'}}>{title}</span>
        </div>
        <div style={{font:'500 11.5px/1.45 var(--tt-font)', color:'var(--tt-text-2)', marginTop:4}}>{sub}</div>
        <div style={{display:'flex', alignItems:'center', gap:10, marginTop:8}}>
          <span style={{font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.04em'}}>{time}</span>
          {action && (
            <span style={{font:'800 10px var(--tt-font)', color:'var(--tt-ember)', letterSpacing:'0.1em'}}>{action.toUpperCase()} →</span>
          )}
        </div>
      </div>
    </div>
  );
}

window.ScreenNotifications = ScreenNotifications;

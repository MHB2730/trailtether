// Trailtether — Community tab

function ScreenCommunity() {
  const [tab, setTab] = React.useState(0); // 0 Feed, 1 Chat
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar
          time="10:09"
          right={
            <span style={{display:'inline-flex', alignItems:'center', gap:4, color:'var(--tt-green)', fontSize:10.5, fontWeight:700, letterSpacing:'0.1em', marginRight:4}}>
              <span style={{width:5, height:5, borderRadius:'50%', background:'var(--tt-green)', boxShadow:'0 0 6px var(--tt-green)', animation:'pulse 1.6s infinite'}}/>
              ONLINE
            </span>
          }
        />

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <div style={{flex:1}}>
            <div style={{display:'flex', alignItems:'center', gap:9, marginBottom:4}}>
              <TTLogo size={18}/>
              <span style={{font:'800 12px var(--tt-font)', letterSpacing:'0.16em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <h1 style={{margin:0, font:'800 24px var(--tt-font)', letterSpacing:'-0.02em'}}>Community</h1>
          </div>
          <button className="icon-btn"><Icon name="search" size={16} color="var(--tt-text-2)"/></button>
          <button className="icon-btn"><Icon name="bell" size={16} color="var(--tt-text-2)"/></button>
        </div>

        <div style={{padding:'4px 18px 0'}}>
          <CommunitySegmented active={tab} onChange={setTab}/>
        </div>

        {tab === 0
          ? <FeedView/>
          : <ChatView/>
        }

        <BottomNav active="community"/>
      </div>
    </div>
  );
}

function CommunitySegmented({ active, onChange }) {
  const segRef = React.useRef(null);
  const [ind, setInd] = React.useState({ left: 4, width: 0 });
  React.useLayoutEffect(() => {
    if (!segRef.current) return;
    const seg = segRef.current.querySelectorAll('.seg')[active];
    if (!seg) return;
    const c = segRef.current.getBoundingClientRect();
    const r = seg.getBoundingClientRect();
    setInd({ left: r.left - c.left, width: r.width });
  }, [active]);

  return (
    <div className="segmented" ref={segRef}>
      <div className="indicator" style={{ left: ind.left, width: ind.width }}/>
      {['Feed','Chat'].map((label, i) => (
        <div key={label} className={`seg ${i === active ? 'active' : ''}`} onClick={() => onChange(i)}>
          {label}
        </div>
      ))}
    </div>
  );
}

/* ---------- FEED ---------- */
function FeedView() {
  return (
    <div className="tt-scroll" style={{padding:'14px 18px 24px'}}>
      <ComposePrompt/>
      <div style={{display:'flex', flexDirection:'column', gap:12, marginTop:14}}>
        <Stagger base={350} delay={90}>
          <FeedPost
            user="Sarah L." initials="SL" color="#ff8a4d"
            time="14m ago" location="Wonderland Trail"
            text="Made it to the summit — Liberty Cap. Wind is brutal up here but visibility is unreal. 🏔️"
            stats={{dist:'8.4 km', gain:'+3,950 m', time:'5:42'}}
            likes={24} comments={6}
            attached="elev"
          />
          <FeedPost
            user="Mike K." initials="MK" color="#4cc38a"
            time="2h ago" location="Berkeley Park"
            text="Heads up — bridge at km 4 is washed out. Going around via the upper switchback. Adds ~30 min."
            hazard
            likes={42} comments={11}
          />
          <FeedPost
            user="John D." initials="JD" color="#ff6a2c"
            time="Yesterday" location="Mt. Marcy Trail"
            text="Sunday hike with the team. Perfect conditions, scored 9/10 on the weather. Posted the GPX if anyone wants it."
            stats={{dist:'5.8 km', gain:'+3,950 m', time:'5:14'}}
            likes={87} comments={19}
            attached="gpx"
          />
        </Stagger>
      </div>
    </div>
  );
}

function ComposePrompt() {
  return (
    <div className="anim-up" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'12px 14px',
      background:'var(--tt-surf)',
      border:'1px solid var(--tt-line)',
      borderRadius:14,
      cursor:'text',
    }}>
      <div style={{
        width:34, height:34, borderRadius:'50%',
        border:'2px solid var(--tt-ember)',
        background:'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
        display:'grid', placeItems:'center',
        color:'#fff', font:'800 12px var(--tt-font)',
        flex:'0 0 auto',
      }}>JD</div>
      <div style={{flex:1, font:'500 13px var(--tt-font)', color:'var(--tt-text-3)'}}>
        Share a trail report, hazard, or photo…
      </div>
      <button className="icon-btn" style={{width:32, height:32}}>
        <Icon name="send-fill" size={14} color="var(--tt-ember)"/>
      </button>
    </div>
  );
}

function FeedPost({ user, initials, color, time, location, text, stats, likes, comments, hazard, attached }) {
  return (
    <div className="card pressable" style={{padding:'14px 16px', position:'relative', overflow:'hidden'}}>
      {hazard && (
        <div style={{position:'absolute', top:0, left:0, bottom:0, width:3, background:'var(--tt-amber)'}}/>
      )}
      <div style={{display:'flex', gap:11, alignItems:'flex-start'}}>
        <div style={{
          width:38, height:38, borderRadius:'50%',
          background:`linear-gradient(135deg, ${color}, ${color}aa)`,
          display:'grid', placeItems:'center',
          color:'#fff', font:'800 13px var(--tt-font)',
          border:`2px solid ${color}`,
          flex:'0 0 auto',
        }}>
          {initials}
        </div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{display:'flex', alignItems:'center', gap:6, justifyContent:'space-between'}}>
            <span style={{font:'800 13px var(--tt-font)', color:'var(--tt-text)'}}>{user}</span>
            <span style={{font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.06em'}}>{time}</span>
          </div>
          <div style={{display:'flex', alignItems:'center', gap:5, marginTop:2, font:'600 10px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.06em'}}>
            <Icon name="pin" size={10} color="var(--tt-ember)"/>
            <span>{location}</span>
            {hazard && (
              <span style={{marginLeft:6, padding:'2px 5px', borderRadius:4, background:'rgba(242,169,59,0.18)', font:'800 8.5px var(--tt-mono)', color:'var(--tt-amber)', letterSpacing:'0.1em'}}>
                HAZARD
              </span>
            )}
          </div>
        </div>
      </div>

      <div style={{font:'500 13px/1.5 var(--tt-font)', color:'var(--tt-text)', marginTop:12}}>
        {text}
      </div>

      {stats && (
        <div style={{
          display:'grid', gridTemplateColumns:'1fr 1fr 1fr',
          marginTop:12, padding:'10px 12px',
          background:'var(--tt-bg-3)', border:'1px solid var(--tt-line)', borderRadius:10,
          gap:4,
        }}>
          <StatChip label="Dist" value={stats.dist}/>
          <StatChip label="Gain" value={stats.gain} ember/>
          <StatChip label="Time" value={stats.time}/>
        </div>
      )}

      {attached === 'elev' && (
        <div style={{marginTop:12, height:46, position:'relative'}}>
          <svg width="100%" height="46" viewBox="0 0 320 46" style={{display:'block'}} preserveAspectRatio="none">
            <defs>
              <linearGradient id="feedElev" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.5"/>
                <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0"/>
              </linearGradient>
            </defs>
            <path d="M 0 36 Q 40 28 80 22 Q 130 10 180 8 Q 220 14 260 20 Q 290 24 320 30 L 320 46 L 0 46 Z" fill="url(#feedElev)"/>
            <path d="M 0 36 Q 40 28 80 22 Q 130 10 180 8 Q 220 14 260 20 Q 290 24 320 30"
                  fill="none" stroke="#ff6a2c" strokeWidth="1.6" strokeLinecap="round"
                  className="draw-line" style={{['--len']: 380, animationDelay:'500ms'}}/>
          </svg>
        </div>
      )}

      {attached === 'gpx' && (
        <div style={{
          marginTop:12, padding:'10px 12px',
          background:'var(--tt-bg-3)', border:'1px solid var(--tt-line)', borderRadius:10,
          display:'flex', alignItems:'center', gap:10,
        }}>
          <div style={{
            width:30, height:30, borderRadius:8,
            background:'var(--tt-ember-dim)', border:'1px solid rgba(255,106,44,0.32)',
            display:'grid', placeItems:'center', flex:'0 0 auto',
          }}>
            <Icon name="route" size={14} color="var(--tt-ember)"/>
          </div>
          <div style={{flex:1, minWidth:0}}>
            <div style={{font:'800 11.5px var(--tt-font)', color:'var(--tt-text)'}}>mt-marcy-2023-10-26.gpx</div>
            <div style={{font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>5.8 km · 412 waypoints · 84 KB</div>
          </div>
          <button className="icon-btn" style={{width:30, height:30}}>
            <Icon name="arrow-up" size={12} color="var(--tt-ember)" strokeWidth={2}/>
          </button>
        </div>
      )}

      {/* Actions */}
      <div style={{display:'flex', gap:18, marginTop:12, paddingTop:10, borderTop:'1px solid var(--tt-line)'}}>
        <ActionBtn icon="heart"     value={likes}/>
        <ActionBtn icon="message"   value={comments}/>
        <ActionBtn icon="send-fill" value="Share"/>
        <div style={{flex:1}}/>
        <button className="icon-btn" style={{width:28, height:28, border:'none', background:'transparent'}}>
          <Icon name="more" size={14} color="var(--tt-text-3)"/>
        </button>
      </div>
    </div>
  );
}

function StatChip({ label, value, ember }) {
  return (
    <div>
      <div style={{font:'700 9px var(--tt-font)', color:'var(--tt-text-3)', letterSpacing:'0.14em', textTransform:'uppercase'}}>{label}</div>
      <div className="num" style={{font:'800 12.5px var(--tt-mono)', color: ember ? 'var(--tt-ember)' : 'var(--tt-text)', marginTop:2, letterSpacing:'-0.01em'}}>{value}</div>
    </div>
  );
}

function ActionBtn({ icon, value }) {
  return (
    <button className="pressable" style={{
      display:'inline-flex', alignItems:'center', gap:5,
      background:'transparent', border:'none', cursor:'pointer',
      color:'var(--tt-text-2)',
      font:'700 11px var(--tt-font)', letterSpacing:'0.04em',
      padding:0,
    }}>
      <Icon name={icon} size={14} color="currentColor"/>
      {value}
    </button>
  );
}

/* ---------- CHAT ---------- */
function ChatView() {
  return (
    <div className="tt-body">
      {/* Chat list channel — pinned */}
      <div className="anim-up" style={{
        margin:'12px 18px 6px',
        padding:'10px 14px',
        background:'var(--tt-ember-dim)',
        border:'1px solid rgba(255,106,44,0.32)',
        borderRadius:11,
        display:'flex', alignItems:'center', gap:10,
      }}>
        <div style={{
          width:30, height:30, borderRadius:9,
          background:'rgba(255,106,44,0.22)',
          border:'1px solid rgba(255,106,44,0.45)',
          display:'grid', placeItems:'center', flex:'0 0 auto',
        }}>
          <Icon name="people" size={14} color="var(--tt-ember)"/>
        </div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{font:'800 12.5px var(--tt-font)', color:'var(--tt-ember)'}}>Alpine Adventure · Team Chat</div>
          <div style={{font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em'}}>4 ACTIVE · TRAIL #DAY-3</div>
        </div>
      </div>

      <div className="tt-scroll" style={{padding:'8px 18px 12px', display:'flex', flexDirection:'column', gap:10}}>
        <Stagger base={180} delay={80}>
          <ChatMsg time="09:42" who="Sarah L." color="#ff8a4d" initials="SL" text="At Shadow Lake. Going to push for Liberty Cap by 11."/>
          <ChatMsg time="09:46" mine text="Copy. We're 20 min behind. Mike's pace dropped a bit, all good though."/>
          <ChatMsg time="09:48" who="Mike K."  color="#4cc38a" initials="MK" text="Took a bad step. Knee's stiff but walkable."/>
          <ChatMsg time="09:51" who="Emily R." color="#f2a93b" initials="ER" text="I'll wait at the Wonderland junction. Bring the trekking pole." reaction="🙏"/>
          <ChatMsg time="09:53" mine text="On our way. ETA 14 min." reaction="👍"/>
          <ChatMsg time="09:58" who="Sarah L." color="#ff8a4d" initials="SL" text="Storm moving in around 13:00. Let's tag the summit and head down."/>
          <ChatMsg time="10:08" mine system text="📍 You shared your location · Sunrise Camp"/>
        </Stagger>
      </div>

      <ChatComposer/>
    </div>
  );
}

function ChatMsg({ time, who, color, initials, text, mine, system, reaction }) {
  if (system) {
    return (
      <div style={{textAlign:'center', font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.06em', padding:'4px 0'}}>
        {text}
      </div>
    );
  }
  return (
    <div style={{display:'flex', gap:8, flexDirection: mine ? 'row-reverse' : 'row'}}>
      {!mine && (
        <div style={{
          width:30, height:30, borderRadius:'50%',
          background:`linear-gradient(135deg, ${color}, ${color}aa)`,
          display:'grid', placeItems:'center',
          color:'#fff', font:'800 11px var(--tt-font)',
          border:`1.5px solid ${color}`,
          flex:'0 0 auto',
        }}>
          {initials}
        </div>
      )}
      <div style={{maxWidth:'74%', display:'flex', flexDirection:'column', alignItems: mine ? 'flex-end' : 'flex-start'}}>
        {!mine && (
          <div style={{font:'700 10px var(--tt-mono)', color:'var(--tt-text-3)', marginBottom:3, letterSpacing:'0.04em'}}>
            {who} · {time}
          </div>
        )}
        <div style={{
          padding:'9px 12px',
          background: mine ? 'var(--tt-ember-dim)' : 'var(--tt-surf)',
          border: `1px solid ${mine ? 'rgba(255,106,44,0.36)' : 'var(--tt-line)'}`,
          color: mine ? 'var(--tt-ember-3)' : 'var(--tt-text)',
          borderRadius: mine ? '14px 14px 4px 14px' : '14px 14px 14px 4px',
          font:'500 12.5px/1.4 var(--tt-font)',
          position:'relative',
        }}>
          {text}
        </div>
        {mine && (
          <div style={{font:'600 9.5px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:3, letterSpacing:'0.04em'}}>
            {time} <span style={{color:'var(--tt-green)'}}>✓✓</span>
          </div>
        )}
        {reaction && (
          <div style={{
            marginTop:4, padding:'2px 8px',
            background:'var(--tt-surf-2)',
            border:'1px solid var(--tt-line)',
            borderRadius:14,
            fontSize:13,
          }}>{reaction}</div>
        )}
      </div>
    </div>
  );
}

function ChatComposer() {
  return (
    <div style={{
      flex:'0 0 auto',
      padding:'10px 18px 14px',
      background:'var(--tt-bg-2)',
      borderTop:'1px solid var(--tt-line)',
      display:'flex', alignItems:'center', gap:10,
    }}>
      <button className="icon-btn" style={{width:38, height:38}}>
        <Icon name="plus" size={18} color="var(--tt-text-2)"/>
      </button>
      <div style={{
        flex:1, display:'flex', alignItems:'center', gap:6,
        padding:'8px 14px',
        background:'var(--tt-surf)',
        border:'1px solid var(--tt-line)',
        borderRadius:22,
      }}>
        <span style={{flex:1, font:'500 13px var(--tt-font)', color:'var(--tt-text-3)'}}>Message…</span>
        <Icon name="eye" size={16} color="var(--tt-text-3)"/>
      </div>
      <button className="pressable" style={{
        width:42, height:42, borderRadius:'50%',
        background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)',
        border:'none', cursor:'pointer',
        display:'grid', placeItems:'center',
        boxShadow:'var(--tt-shadow-ember)',
      }}>
        <Icon name="send-fill" size={16} color="#1a0d04"/>
      </button>
    </div>
  );
}

window.ScreenCommunity = ScreenCommunity;

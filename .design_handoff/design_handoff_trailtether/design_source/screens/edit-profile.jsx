// Trailtether — Edit Profile screen (reached from Profile → Edit profile)

function ScreenEditProfile() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>EDIT</div>
            <h1 style={{margin:'2px 0 0', font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>Profile</h1>
          </div>
          <button className="pressable" style={{
            padding:'7px 14px', borderRadius:8,
            background:'var(--tt-ember)', border:'none',
            color:'#1a0d04', font:'900 11px var(--tt-font)', letterSpacing:'0.16em',
            cursor:'pointer', boxShadow:'var(--tt-shadow-ember)',
          }}>SAVE</button>
        </div>

        <div className="tt-scroll" style={{padding:'8px 18px 24px'}}>
          {/* Avatar editor */}
          <div className="anim-up" style={{textAlign:'center', padding:'20px 0 16px'}}>
            <div style={{position:'relative', width:118, height:118, margin:'0 auto'}}>
              <div style={{
                width:118, height:118, borderRadius:'50%',
                border:'3px solid var(--tt-ember)',
                background:'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
                display:'grid', placeItems:'center',
                color:'#fff', font:'900 44px var(--tt-font)',
                boxShadow:'0 0 28px rgba(255,106,44,0.45)',
              }}>JD</div>
              <button className="pressable" style={{
                position:'absolute', bottom:0, right:0,
                width:38, height:38, borderRadius:'50%',
                background:'var(--tt-ember)', border:'3px solid var(--tt-bg)',
                display:'grid', placeItems:'center', cursor:'pointer',
                boxShadow:'0 0 14px rgba(255,106,44,0.55)',
              }}>
                <Icon name="plus" size={16} color="#1a0d04" strokeWidth={2.6}/>
              </button>
            </div>
            <button className="pressable" style={{
              marginTop:14,
              padding:'7px 14px', borderRadius:8,
              background:'transparent', border:'1px solid var(--tt-line-3)',
              color:'var(--tt-ember)', font:'800 11px var(--tt-font)', letterSpacing:'0.14em',
              cursor:'pointer',
            }}>CHANGE PHOTO</button>
          </div>

          <Field label="Full name"  value="John Davies"/>
          <Field label="Username"   value="@johnd"   leading="@"/>
          <Field label="Email"      value="john@trailtether.app" disabled/>
          <Field label="Region"     value="Cape Town, ZA" rightIcon="pin"/>

          <div style={{marginTop:18}}>
            <FieldLabel>Bio</FieldLabel>
            <textarea
              defaultValue="Cape Town based. Drakensberg regular. Slow ascents, long descents, dawn starts."
              rows={3}
              style={{
                width:'100%', padding:'12px 14px',
                background:'var(--tt-surf)', border:'1px solid var(--tt-line)',
                borderRadius:11, color:'var(--tt-text)',
                font:'500 13px/1.5 var(--tt-font)', resize:'none', outline:'none',
                boxSizing:'border-box',
              }}/>
            <div style={{display:'flex', justifyContent:'space-between', marginTop:5}}>
              <span style={{font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.1em'}}>78/140</span>
              <span style={{font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.1em'}}>SHOWN ON PROFILE</span>
            </div>
          </div>

          {/* Skill / experience */}
          <div style={{marginTop:22}}>
            <FieldLabel>Experience level</FieldLabel>
            <div style={{display:'grid', gridTemplateColumns:'repeat(4, 1fr)', gap:6}}>
              {['Beginner','Intermediate','Advanced','Expert'].map((l, i) => (
                <button key={l} className="pressable" style={{
                  padding:'9px 0', borderRadius:9,
                  background: i === 2 ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
                  border: i === 2 ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line)',
                  color: i === 2 ? 'var(--tt-ember)' : 'var(--tt-text-2)',
                  font:'800 9.5px var(--tt-font)', letterSpacing:'0.1em',
                  cursor:'pointer', whiteSpace:'nowrap',
                }}>{l.toUpperCase()}</button>
              ))}
            </div>
          </div>

          {/* Tags */}
          <div style={{marginTop:20}}>
            <FieldLabel>Interests</FieldLabel>
            <div style={{display:'flex', gap:6, flexWrap:'wrap'}}>
              {[
                { l:'Day hikes', on:true },
                { l:'Multi-day', on:true },
                { l:'Caving', on:true },
                { l:'Scrambling', on:false },
                { l:'Photography', on:true },
                { l:'Trail running', on:false },
                { l:'Mountaineering', on:false },
              ].map(t => (
                <span key={t.l} style={{
                  padding:'6px 10px', borderRadius:999,
                  background: t.on ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
                  border: t.on ? '1px solid rgba(255,106,44,0.5)' : '1px solid var(--tt-line-2)',
                  color: t.on ? 'var(--tt-ember)' : 'var(--tt-text-2)',
                  font:'700 11px var(--tt-font)', letterSpacing:'0.04em',
                  cursor:'pointer',
                }}>{t.l}</span>
              ))}
            </div>
          </div>

          {/* Delete account */}
          <button className="pressable" style={{
            width:'100%', marginTop:28,
            padding:'13px', borderRadius:11,
            background:'transparent', border:'1px solid rgba(230,61,46,0.32)',
            color:'var(--tt-red)', font:'800 11px var(--tt-font)', letterSpacing:'0.16em',
            cursor:'pointer',
          }}>DELETE ACCOUNT</button>
        </div>
      </div>
    </div>
  );
}

function FieldLabel({ children }) {
  return (
    <div style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em', textTransform:'uppercase', color:'var(--tt-text-3)', marginBottom:7}}>
      {children}
    </div>
  );
}

function Field({ label, value, leading, disabled, rightIcon }) {
  return (
    <div style={{marginTop:14}}>
      <FieldLabel>{label}</FieldLabel>
      <div style={{
        display:'flex', alignItems:'center', gap:8,
        padding:'12px 14px',
        background: disabled ? 'rgba(255,255,255,0.02)' : 'var(--tt-surf)',
        border:'1px solid var(--tt-line)',
        borderRadius:11,
        opacity: disabled ? 0.7 : 1,
      }}>
        {leading && <span style={{font:'700 13px var(--tt-mono)', color:'var(--tt-text-3)'}}>{leading}</span>}
        <input type="text" defaultValue={value} disabled={disabled}
          style={{flex:1, background:'transparent', border:'none', outline:'none',
            color:'var(--tt-text)', font:'600 13px var(--tt-font)'}}/>
        {rightIcon && <Icon name={rightIcon} size={13} color="var(--tt-ember)"/>}
        {disabled && <span style={{font:'800 9px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.14em'}}>LOCKED</span>}
      </div>
    </div>
  );
}

window.ScreenEditProfile = ScreenEditProfile;

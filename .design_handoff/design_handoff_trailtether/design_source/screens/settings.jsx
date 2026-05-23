// Trailtether — Full Settings screen (reached from the gear icon in Profile)

function ScreenSettings() {
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        <div className="tt-appbar anim-in" style={{paddingBottom:8}}>
          <button className="icon-btn"><Icon name="chevron-up" size={16} color="var(--tt-text)" strokeWidth={2.4}/></button>
          <div style={{flex:1}}>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.16em'}}>SETTINGS</div>
            <h1 style={{margin:'2px 0 0', font:'800 22px var(--tt-font)', letterSpacing:'-0.02em'}}>App Settings</h1>
          </div>
          <button className="icon-btn"><Icon name="search" size={14} color="var(--tt-text-2)"/></button>
        </div>

        <div className="tt-scroll" style={{padding:'4px 18px 24px'}}>
          <SettingsGroup title="DISPLAY" delay={120}>
            <SettingRowS icon="layers" label="Theme"          value="Dark · Ember"     onChev/>
            <SettingRowS icon="navigation" label="Units"      value="Metric (km · m)"  onChev/>
            <SettingRowS icon="compass" label="Bearing"       value="True north"       onChev isLast/>
          </SettingsGroup>

          <SettingsGroup title="TRAIL RECORDING" delay={200}>
            <SettingRowS icon="route" label="GPS sample rate"  value="High · 1Hz"      onChev/>
            <SettingRowS icon="layers" label="Auto-pause"      toggle defaultOn/>
            <SettingRowS icon="mountain" label="Auto-altitude calibration" toggle defaultOn/>
            <SettingRowS icon="flame" label="Color trail by speed"          toggle defaultOn isLast/>
          </SettingsGroup>

          <SettingsGroup title="MAPS & DATA" delay={280}>
            <SettingRowS icon="route" label="Offline maps" value="312 MB · 1 region" onChev/>
            <SettingRowS icon="history" label="Cache lifetime" value="30 days" onChev/>
            <SettingRowS icon="layers" label="Default layer" value="Topographic" onChev/>
            <SettingRowS icon="eye"   label="Show contour shading" toggle defaultOn isLast/>
          </SettingsGroup>

          <SettingsGroup title="TETHER" delay={360}>
            <SettingRowS icon="tether" label="Base-camp pairing" value="1 paired" onChev badge="ACTIVE" badgeColor="var(--tt-green)"/>
            <SettingRowS icon="eye"    label="Live tracking when hiking" toggle defaultOn/>
            <SettingRowS icon="bell"   label="Auto-check in interval" value="20 min" onChev/>
            <SettingRowS icon="phone"  label="Emergency contacts" value="3 saved" onChev isLast/>
          </SettingsGroup>

          <SettingsGroup title="NOTIFICATIONS" delay={440}>
            <SettingRowS icon="bell"  label="Weather warnings" toggle defaultOn/>
            <SettingRowS icon="alert" label="Hazard reports nearby" toggle defaultOn/>
            <SettingRowS icon="people" label="Team activity" toggle defaultOn/>
            <SettingRowS icon="message" label="Community mentions" toggle isLast/>
          </SettingsGroup>

          <SettingsGroup title="PRIVACY" delay={520}>
            <SettingRowS icon="shield" label="Privacy policy" onChev/>
            <SettingRowS icon="eye"    label="Visible to community" toggle defaultOn/>
            <SettingRowS icon="user"   label="Profile visibility" value="Public" onChev isLast/>
          </SettingsGroup>

          <SettingsGroup title="ABOUT" delay={600}>
            <SettingRowS icon="alert" label="What's new" value="v2.0.4" onChev/>
            <SettingRowS icon="message" label="Send feedback" onChev/>
            <SettingRowS icon="heart" label="Rate Trailtether" onChev isLast/>
          </SettingsGroup>

          <div style={{textAlign:'center', padding:'18px 0 4px',
            font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-4)',
            letterSpacing:'0.16em', lineHeight:1.6}}>
            TRAILTETHER v2.0.4 · BUILD 2436<br/>
            FREE · NO ADS · BUILT IN SOUTH AFRICA
          </div>
        </div>

        <BottomNav active="profile"/>
      </div>
    </div>
  );
}

function SettingsGroup({ title, delay = 100, children }) {
  return (
    <div className="anim-up" style={{marginTop:18, animationDelay:`${delay}ms`}}>
      <div style={{font:'700 10px var(--tt-font)', letterSpacing:'0.18em',
        textTransform:'uppercase', color:'var(--tt-text-3)', marginBottom:7, paddingLeft:2}}>{title}</div>
      <div className="card" style={{padding:0, overflow:'hidden'}}>{children}</div>
    </div>
  );
}

function SettingRowS({ icon, label, value, toggle, defaultOn, onChev, isLast, badge, badgeColor }) {
  const [on, setOn] = React.useState(!!defaultOn);
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:12,
      padding:'12px 14px',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)',
      cursor:'pointer',
    }}>
      <div style={{
        width:30, height:30, borderRadius:8,
        background:'rgba(255,255,255,0.03)',
        border:'1px solid var(--tt-line-2)',
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name={icon} size={13} color="var(--tt-ember)"/>
      </div>
      <div style={{flex:1, minWidth:0}}>
        <div style={{font:'700 12.5px var(--tt-font)', color:'var(--tt-text)'}}>{label}</div>
      </div>
      {badge && (
        <span style={{
          padding:'2px 7px', borderRadius:5,
          background:`${badgeColor}1f`, border:`1px solid ${badgeColor}55`,
          font:'800 8.5px var(--tt-mono)', color:badgeColor, letterSpacing:'0.14em',
        }}>{badge}</span>
      )}
      {toggle && (
        <button onClick={(e) => { e.stopPropagation(); setOn(o => !o); }} style={{
          width:40, height:22, borderRadius:13,
          background: on ? 'var(--tt-ember)' : 'var(--tt-surf-3)',
          border:'none', cursor:'pointer',
          position:'relative', padding:0,
          transition:'background 250ms ease',
        }}>
          <div style={{
            position:'absolute', top:3, left: on ? 20 : 3,
            width:16, height:16, borderRadius:'50%',
            background:'#fff',
            transition:'left 250ms cubic-bezier(0.2,0.7,0.2,1)',
            boxShadow:'0 2px 4px rgba(0,0,0,0.3)',
          }}/>
        </button>
      )}
      {value && !toggle && (
        <span style={{font:'700 11px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.04em'}}>{value}</span>
      )}
      {(onChev || (!toggle && !badge && !value)) && (
        <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
      )}
    </div>
  );
}

window.ScreenSettings = ScreenSettings;

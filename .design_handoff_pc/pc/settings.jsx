// Trailtether PC — Settings

function PCScreenSettings() {
  return (
    <PCWindow>
      <PCTitleBar/>
      <PCLayout active="settings">
        <PCPageHeader
          eyebrow="PREFERENCES"
          title="Settings"
          sub="Configure how this base camp watches, alerts, and stores data."
          actions={
            <div style={{ display:'flex', gap:8 }}>
              <PCBtn ghost leftIcon="history">REVERT CHANGES</PCBtn>
              <PCBtn primary leftIcon="check">SAVE ALL</PCBtn>
            </div>
          }
        />

        <div style={{ flex:1, padding:'16px 26px 22px', overflow:'auto',
          display:'grid', gridTemplateColumns:'200px 1fr', gap:22 }}>

          {/* Left rail — section index */}
          <div style={{ display:'flex', flexDirection:'column', gap:2, alignSelf:'flex-start', position:'sticky', top:0 }}>
            {[
              { i:'home',     label:'General',          active:true },
              { i:'bell',     label:'Notifications' },
              { i:'shield',   label:'Alert Rules' },
              { i:'tether',   label:'Tether & Relay' },
              { i:'route',    label:'Data & Storage' },
              { i:'eye',      label:'Privacy' },
              { i:'user',     label:'Account' },
              { i:'alert',    label:'About' },
            ].map(s => (
              <div key={s.label} className="pressable" style={{
                display:'flex', alignItems:'center', gap:9,
                padding:'8px 11px',
                borderRadius:8,
                background: s.active ? 'rgba(255,106,44,0.10)' : 'transparent',
                border: s.active ? '1px solid rgba(255,106,44,0.32)' : '1px solid transparent',
                color: s.active ? 'var(--tt-ember)' : 'var(--tt-text-2)',
                font:'700 11.5px var(--tt-font)',
                cursor:'pointer',
              }}>
                <Icon name={s.i} size={12} color={s.active ? 'var(--tt-ember)' : 'var(--tt-text-3)'}/>
                {s.label}
              </div>
            ))}
          </div>

          {/* Right — actual settings */}
          <div style={{ display:'flex', flexDirection:'column', gap:18, minWidth:0 }}>
            <SettingsGroupPC title="GENERAL">
              <SettingsRowPC icon="layers" label="Theme"           value="Dark · Ember"           onChev/>
              <SettingsRowPC icon="navigation" label="Units"       value="Metric (km · m)"        onChev/>
              <SettingsRowPC icon="clock"      label="Time format" value="24-hour"                onChev/>
              <SettingsRowPC icon="compass"    label="Bearing"     value="True north"             onChev/>
              <SettingsRowPC icon="eye"        label="Map default" value="Topographic + Hybrid"   onChev/>
              <SettingsRowPC icon="play"       label="Start watching on app launch" toggle defaultOn isLast/>
            </SettingsGroupPC>

            <SettingsGroupPC title="NOTIFICATIONS">
              <SettingsRowPC icon="bell"    label="Desktop notifications"          toggle defaultOn/>
              <SettingsRowPC icon="phone"   label="SMS notifications"              value="074 125 ****" onChev/>
              <SettingsRowPC icon="message" label="Email notifications"            value="sarah@trailtether.app" onChev/>
              <SettingsRowPC icon="radio"   label="Phone-call alert on SOS"        toggle defaultOn/>
              <SettingsRowPC icon="flame"   label="Sound on critical alerts"       toggle defaultOn isLast/>
            </SettingsGroupPC>

            <SettingsGroupPC title="ALERT RULES">
              <AlertRulePC label="Hike runs past expected return" mins="30 minutes grace" channels="DESKTOP + SMS"/>
              <AlertRulePC label="Pings missed in a row"          mins="4 pings (4 minutes)" channels="DESKTOP + CALL"/>
              <AlertRulePC label="Battery falls below"            mins="25%"               channels="DESKTOP"/>
              <AlertRulePC label="Hiker leaves planned route by"  mins="500 m"             channels="DESKTOP + SMS"/>
              <AlertRulePC label="Weather warning issued en-route" mins="all severities"   channels="DESKTOP"/>
              <AlertRulePC label="Hiker triggers SOS"             mins="immediately"       channels="ALL CHANNELS" critical/>
            </SettingsGroupPC>

            <SettingsGroupPC title="TETHER & RELAY">
              <SettingsRowPC icon="tether"  label="Paired devices"               value="3 of 5" onChev badge="ACTIVE" badgeColor="var(--tt-green)"/>
              <SettingsRowPC icon="eye"     label="Receive live position"        toggle defaultOn/>
              <SettingsRowPC icon="route"   label="Mirror trail recording"       toggle defaultOn/>
              <SettingsRowPC icon="alert"   label="Relay region"                 value="Africa-South-1" onChev/>
              <SettingsRowPC icon="layers"  label="Connection log"               value="Last 30 days" onChev isLast/>
            </SettingsGroupPC>

            <SettingsGroupPC title="DATA & STORAGE">
              <SettingsRowPC icon="route"   label="Local cache" value="1.4 GB · 312 trails" onChev/>
              <SettingsRowPC icon="history" label="Hike history retention" value="Forever" onChev/>
              <SettingsRowPC icon="layers"  label="Auto-backup" value="iCloud Drive · weekly" onChev/>
              <SettingsRowPC icon="arrow-up-right" label="Export all data" onChev isLast/>
            </SettingsGroupPC>

            <div style={{ height:8 }}/>
            <button className="pressable" style={{
              padding:'13px', borderRadius:11,
              background:'transparent', border:'1px solid rgba(230,61,46,0.32)',
              color:'var(--tt-red)',
              font:'800 12px var(--tt-font)', letterSpacing:'0.16em',
              cursor:'pointer',
              alignSelf:'flex-start',
            }}>SIGN OUT OF BASE CAMP</button>

            <div style={{ font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-4)', letterSpacing:'0.16em', textAlign:'center', padding:'18px 0' }}>
              TRAILTETHER BASE CAMP v2.0.4 · BUILD 9842<br/>
              FREE · NO ADS · BUILT IN SOUTH AFRICA
            </div>
          </div>
        </div>
      </PCLayout>
    </PCWindow>
  );
}

function SettingsGroupPC({ title, children }) {
  return (
    <PCCard padding={0}>
      <div style={{ padding:'14px 18px 8px', borderBottom:'1px solid var(--tt-line)' }}>
        <span style={{ font:'800 11px var(--tt-font)', letterSpacing:'0.2em', color:'var(--tt-text-2)' }}>{title}</span>
      </div>
      <div>{children}</div>
    </PCCard>
  );
}

function SettingsRowPC({ icon, label, value, toggle, defaultOn, onChev, isLast, badge, badgeColor }) {
  const [on, setOn] = React.useState(!!defaultOn);
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:14,
      padding:'13px 18px',
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
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ font:'700 12.5px var(--tt-font)', color:'var(--tt-text)' }}>{label}</div>
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
          border:'none', cursor:'pointer', position:'relative', padding:0,
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
        <span style={{ font:'700 11px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.04em' }}>{value}</span>
      )}
      {(onChev || (!toggle && !badge && !value)) && (
        <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
      )}
    </div>
  );
}

function AlertRulePC({ label, mins, channels, critical }) {
  return (
    <div className="pressable" style={{
      display:'flex', alignItems:'center', gap:14,
      padding:'12px 18px',
      borderBottom:'1px solid var(--tt-line)',
      borderLeft: critical ? '3px solid var(--tt-red)' : '3px solid transparent',
      cursor:'pointer',
    }}>
      <span style={{
        width:18, height:18, borderRadius:'50%',
        border: critical ? '2px solid var(--tt-red)' : '2px solid var(--tt-ember)',
        background: critical ? 'rgba(230,61,46,0.18)' : 'var(--tt-ember-dim)',
        display:'grid', placeItems:'center', flex:'0 0 auto',
      }}>
        <Icon name="check" size={9} color={critical ? 'var(--tt-red)' : 'var(--tt-ember)'} strokeWidth={2.6}/>
      </span>
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ font:'700 12.5px var(--tt-font)', color:'var(--tt-text)' }}>{label}</div>
        <div style={{ font:'600 10px var(--tt-mono)', color:'var(--tt-text-3)', marginTop:2, letterSpacing:'0.04em' }}>{mins}</div>
      </div>
      <span style={{ font:'800 9px var(--tt-mono)',
        color: critical ? 'var(--tt-red)' : 'var(--tt-ember)',
        letterSpacing:'0.14em' }}>{channels}</span>
      <Icon name="chevron-right" size={13} color="var(--tt-text-3)"/>
    </div>
  );
}

window.PCScreenSettings = PCScreenSettings;

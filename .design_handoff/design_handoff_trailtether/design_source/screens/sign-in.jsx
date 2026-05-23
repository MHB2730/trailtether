// Trailtether — Sign In / Sign Up screen (entry point before authenticated app)

function ScreenSignIn() {
  const [mode, setMode] = React.useState('signin'); // 'signin' | 'signup'
  return (
    <div className="phone">
      <div className="punchhole"/>
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{color:'var(--tt-text-2)', fontSize:10.5, fontWeight:700, letterSpacing:'0.08em', marginRight:4}}>LTE</span>}/>

        {/* Atmospheric hero background */}
        <div style={{position:'absolute', top:0, left:0, right:0, height:380, overflow:'hidden', zIndex:0}}>
          <img src="assets/hero_mountain.png" alt=""
            style={{position:'absolute', inset:0, width:'100%', height:'100%',
              objectFit:'cover', objectPosition:'center 65%',
              filter:'saturate(1.1) contrast(1.05) brightness(0.65)'}}/>
          <div style={{position:'absolute', inset:0,
            background:'linear-gradient(180deg, rgba(7,9,12,0.4) 0%, rgba(7,9,12,0.2) 30%, var(--tt-bg) 95%)'}}/>
          <div style={{position:'absolute', inset:0,
            background:'radial-gradient(ellipse 60% 40% at 30% 30%, rgba(255,106,44,0.18), transparent 70%)'}}/>
        </div>

        <div style={{position:'relative', zIndex:1, padding:'24px 24px 24px',
          display:'flex', flexDirection:'column', flex:1, minHeight:0}}>
          {/* Logo + tagline */}
          <div className="anim-up" style={{textAlign:'center', marginTop:30}}>
            <div style={{display:'inline-flex', alignItems:'center', gap:10}}>
              <TTLogo size={32}/>
              <span style={{font:'900 18px var(--tt-font)', letterSpacing:'0.22em'}}>
                TRAIL<span style={{color:'var(--tt-ember)'}}>TETHER</span>
              </span>
            </div>
            <div style={{font:'600 11px var(--tt-mono)', color:'var(--tt-ember)', letterSpacing:'0.22em', marginTop:10}}>
              SOMEONE AT HOME, ALWAYS WATCHING
            </div>
          </div>

          {/* Card */}
          <div className="anim-up" style={{
            marginTop:'auto',
            padding:'22px 18px',
            background:'rgba(13,17,22,0.72)',
            backdropFilter:'blur(14px) saturate(140%)',
            border:'1px solid var(--tt-line-2)',
            borderRadius:18,
            animationDelay:'160ms',
          }}>
            {/* Mode toggle */}
            <div className="segmented" style={{marginBottom:18}}>
              <div className={`seg ${mode==='signin'?'active':''}`} onClick={()=>setMode('signin')}>Sign In</div>
              <div className={`seg ${mode==='signup'?'active':''}`} onClick={()=>setMode('signup')}>Create Account</div>
              <div className="indicator" style={{
                left: mode==='signin' ? 4 : '50%',
                width:'48%',
              }}/>
            </div>

            <h2 style={{margin:0, font:'900 22px var(--tt-font)', letterSpacing:'-0.015em', color:'var(--tt-text)'}}>
              {mode === 'signin' ? 'Welcome back.' : 'Pair the tether.'}
            </h2>
            <div style={{font:'500 11.5px/1.45 var(--tt-font)', color:'var(--tt-text-2)', marginTop:6}}>
              {mode === 'signin'
                ? 'No password? No problem. We send a one-tap link.'
                : 'A two-minute setup. We never share your position publicly.'}
            </div>

            {/* Inputs */}
            {mode === 'signup' && (
              <SignInField label="Full name" value="" placeholder="John Davies" delay={80}/>
            )}
            <SignInField label="Email" value="" placeholder="you@trail.app" delay={140}/>

            <button className="pressable" style={{
              width:'100%', marginTop:18,
              padding:'14px', borderRadius:12,
              background:'linear-gradient(135deg, #ff8a4d, #ff6a2c)', border:'none',
              color:'#1a0d04', font:'900 12px var(--tt-font)', letterSpacing:'0.18em',
              cursor:'pointer', boxShadow:'var(--tt-shadow-ember)',
              display:'inline-flex', alignItems:'center', justifyContent:'center', gap:8,
            }}>
              {mode === 'signin' ? 'SEND ME A LINK' : 'CREATE ACCOUNT'}
              <Icon name="arrow-up-right" size={13} color="#1a0d04" strokeWidth={2.4}/>
            </button>

            {/* Divider */}
            <div style={{display:'flex', alignItems:'center', gap:10, margin:'18px 0'}}>
              <div style={{flex:1, height:1, background:'var(--tt-line)'}}/>
              <span style={{font:'700 9px var(--tt-mono)', color:'var(--tt-text-3)', letterSpacing:'0.18em'}}>OR</span>
              <div style={{flex:1, height:1, background:'var(--tt-line)'}}/>
            </div>

            {/* Social providers */}
            <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
              <SocialBtn label="Google"   icon="G"/>
              <SocialBtn label="Apple"    icon="◆"/>
            </div>

            <div style={{textAlign:'center', marginTop:18, font:'500 10.5px/1.5 var(--tt-font)', color:'var(--tt-text-3)'}}>
              By continuing, you agree to our <span style={{color:'var(--tt-ember)'}}>Terms</span> and <span style={{color:'var(--tt-ember)'}}>Privacy Policy</span>.
            </div>
          </div>

          <div style={{textAlign:'center', marginTop:14, font:'700 9.5px var(--tt-mono)', color:'var(--tt-text-4)', letterSpacing:'0.18em'}}>
            FREE · NO ADS · BUILT IN SOUTH AFRICA
          </div>
        </div>
      </div>
    </div>
  );
}

function SignInField({ label, value, placeholder, delay = 100 }) {
  return (
    <div className="anim-up" style={{marginTop:14, animationDelay:`${delay}ms`}}>
      <div style={{font:'700 9.5px var(--tt-font)', letterSpacing:'0.18em', textTransform:'uppercase', color:'var(--tt-text-3)', marginBottom:6}}>
        {label}
      </div>
      <input type="text" defaultValue={value} placeholder={placeholder}
        style={{
          width:'100%', padding:'12px 14px', boxSizing:'border-box',
          background:'rgba(255,255,255,0.04)',
          border:'1px solid var(--tt-line-2)', borderRadius:11,
          color:'var(--tt-text)', font:'600 13px var(--tt-font)',
          outline:'none',
        }}/>
    </div>
  );
}

function SocialBtn({ label, icon }) {
  return (
    <button className="pressable" style={{
      padding:'12px', borderRadius:11,
      background:'rgba(255,255,255,0.04)',
      border:'1px solid var(--tt-line-2)',
      color:'var(--tt-text)',
      font:'800 12px var(--tt-font)', letterSpacing:'0.12em',
      cursor:'pointer',
      display:'inline-flex', alignItems:'center', justifyContent:'center', gap:8,
    }}>
      <span style={{font:'900 14px var(--tt-mono)', color:'var(--tt-ember)'}}>{icon}</span>
      {label.toUpperCase()}
    </button>
  );
}

window.ScreenSignIn = ScreenSignIn;

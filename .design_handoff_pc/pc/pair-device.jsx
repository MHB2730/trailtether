// Trailtether PC — Pair Device (onboard a new phone to this base camp)

function PCScreenPair() {
  return (
    <PCWindow>
      <PCTitleBar />
      <PCLayout active="pair">
        <PCPageHeader
          eyebrow="PAIRING"
          title="Pair a Device"
          sub="Tether a phone to this base camp. The hiker installs Trailtether and scans the code below."
          actions={
          <div style={{ display: 'flex', gap: 8 }}>
              <PCBtn ghost leftIcon="history">PAST PAIRINGS</PCBtn>
              <PCBtn ghost leftIcon="settings">PAIR SETTINGS</PCBtn>
            </div>
          } />
        

        <div style={{ flex: 1, padding: '22px 26px 22px', overflow: 'auto',
          display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 18 }}>

          {/* Left — the pairing card */}
          <PCCard padding={0} style={{ position: 'relative', overflow: 'hidden' }}>
            <PCTopoBack />
            {/* Ember corner glow */}
            <div style={{
              position: 'absolute', top: -60, right: -60,
              width: 240, height: 240, borderRadius: '50%',
              background: 'radial-gradient(circle, rgba(255,106,44,0.18), transparent 70%)',
              pointerEvents: 'none'
            }} />

            <div style={{ position: 'relative', padding: '28px 28px 24px' }}>
              <PCPill ember live>READY · WAITING FOR SCAN</PCPill>
              <h2 style={{ margin: '14px 0 6px', font: '900 28px var(--tt-font)', letterSpacing: '-0.02em' }}>
                Scan to tether
              </h2>
              <div style={{ font: '600 13px/1.45 var(--tt-font)', color: 'var(--tt-text-2)', maxWidth: 480 }}>
                Open Trailtether on the hiker's phone, tap <b style={{ color: 'var(--tt-ember)' }}>Settings → Tether → Pair</b>, and point the camera at this code. Pairing expires in <span className="num" style={{ color: 'var(--tt-ember)', fontWeight: 800 }}>9:47</span>.
              </div>

              <div style={{ display: 'flex', gap: 24, alignItems: 'center', marginTop: 26 }}>
                <PCFakeQR />
                <div style={{ flex: 1 }}>
                  <div style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.2em' }}>OR ENTER MANUALLY</div>
                  <div style={{
                    display: 'flex', gap: 8, marginTop: 10,
                    padding: '14px 16px',
                    background: 'rgba(255,106,44,0.08)',
                    border: '1px solid rgba(255,106,44,0.32)',
                    borderRadius: 11,
                    font: '900 30px var(--tt-mono)', color: 'var(--tt-ember)',
                    letterSpacing: '0.18em', justifyContent: 'center'
                  }}>
                    <span>K7</span>
                    <span style={{ color: 'var(--tt-line-3)' }}>·</span>
                    <span>9X</span>
                    <span style={{ color: 'var(--tt-line-3)' }}>·</span>
                    <span>R4</span>
                    <span style={{ color: 'var(--tt-line-3)' }}>·</span>
                    <span>2P</span>
                  </div>
                  <div style={{ display: 'flex', gap: 9, marginTop: 12 }}>
                    <PCBtn ghost leftIcon="layers">COPY CODE</PCBtn>
                    <PCBtn ghost leftIcon="message">SEND VIA SMS</PCBtn>
                  </div>
                  <div style={{ marginTop: 18, font: '500 11.5px/1.45 var(--tt-font)', color: 'var(--tt-text-3)' }}>
                    The hiker's phone and this PC don't need to be on the same network. Trailtether routes through our relay over LTE / 4G.
                  </div>
                </div>
              </div>
            </div>
          </PCCard>

          {/* Right — what gets tethered */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <PCCard>
              <div style={{ font: '800 11px var(--tt-font)', letterSpacing: '0.18em', color: 'var(--tt-text-2)', marginBottom: 14 }}>
                WHAT'S SHARED WHILE TETHERED
              </div>
              <SharedRow ic="pin" title="Live position" sub="1-Hz GPS · only during an active hike" defaultOn />
              <SharedRow ic="route" title="Planned route" sub="Trail, waypoints, expected return" defaultOn />
              <SharedRow ic="alert" title="Status events" sub="Started, milestones, paused, completed" defaultOn />
              <SharedRow ic="heart" title="Heart rate" sub="Sent every 30s · uses paired wearable" defaultOn />
              <SharedRow ic="message" title="Quick chat" sub="Short text only · for emergencies" defaultOn isLast />
            </PCCard>

            <PCCard>
              <div style={{ font: '800 11px var(--tt-font)', letterSpacing: '0.18em', color: 'var(--tt-text-2)', marginBottom: 10 }}>
                ALERT RULES
              </div>
              <RuleRow text="If hike runs 30 min past expected return" badge="DESKTOP + SMS" />
              <RuleRow text="If 4 consecutive pings are missed" badge="DESKTOP + CALL" />
              <RuleRow text="If hiker triggers SOS" badge="ALL CHANNELS" />
              <RuleRow text="If battery falls below 25%" badge="DESKTOP" />
            </PCCard>

            <div style={{ display: 'flex', gap: 9 }}>
              <PCBtn ghost leftIcon="alert" style={{ flex: 1 }}>CANCEL PAIRING</PCBtn>
              <PCBtn primary leftIcon="check" style={{ flex: 1 }}>I'LL DO IT LATER</PCBtn>
            </div>
          </div>
        </div>
      </PCLayout>
    </PCWindow>);

}

function PCFakeQR() {
  // A stylized QR-like pattern — purely decorative
  const size = 220,cells = 22,c = size / cells;
  const cellsOn = [];
  // pseudo-random pattern with finder squares
  for (let y = 0; y < cells; y++) {
    for (let x = 0; x < cells; x++) {
      const inFinder = x < 7 && y < 7 || x >= cells - 7 && y < 7 || x < 7 && y >= cells - 7;
      const finderBlack = inFinder && (
      Math.min(x, cells - 1 - x) === 0 || y === 0 || y === 6 || x === 6 || x === cells - 7 ||
      x >= 2 && x <= 4 && y >= 2 && y <= 4);

      // pseudo random
      const h = (x * 97 + y * 53 + 13) % 7;
      const on = finderBlack || !inFinder && h < 3;
      if (on) cellsOn.push([x, y]);
    }
  }
  return (
    <div style={{
      width: size, height: size, padding: 14,
      background: '#1a1d22', borderRadius: 14,
      border: '1px solid var(--tt-line-2)',
      boxShadow: '0 8px 24px -8px rgba(0,0,0,0.6)',
      flex: '0 0 auto', position: 'relative'
    }}>
      <svg width={size - 28} height={size - 28} viewBox={`0 0 ${size} ${size}`}>
        <rect width={size} height={size} fill="#eef1f4" />
        {cellsOn.map(([x, y], i) =>
        <rect key={i} x={x * c} y={y * c} width={c - 0.4} height={c - 0.4} fill="#06080b" />
        )}
        {/* ember logo in the center */}
        <rect x={size / 2 - 22} y={size / 2 - 22} width="44" height="44" fill="#eef1f4" />
        <circle cx={size / 2} cy={size / 2} r="14" fill="#ff6a2c" />
        <path d={`M ${size / 2 - 5} ${size / 2 + 2} L ${size / 2} ${size / 2 - 4} L ${size / 2 + 5} ${size / 2 + 2} Z`} fill="#1a0d04" />
      </svg>
      {/* finder ring overlay (corner brackets) */}
      <div style={{
        position: 'absolute', inset: 8,
        border: '2px solid var(--tt-ember)',
        borderRadius: 10, pointerEvents: 'none',
        animation: 'pulse 2.4s infinite'
      }} />
    </div>);

}

function SharedRow({ ic, title, sub, defaultOn, isLast }) {
  const [on, setOn] = React.useState(!!defaultOn);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 11,
      padding: '10px 0',
      borderBottom: isLast ? 'none' : '1px solid var(--tt-line)'
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 8,
        background: 'rgba(255,255,255,0.03)',
        border: '1px solid var(--tt-line-2)',
        display: 'grid', placeItems: 'center', flex: '0 0 auto'
      }}>
        <Icon name={ic} size={13} color="var(--tt-ember)" />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '800 12.5px var(--tt-font)', color: 'var(--tt-text)' }}>{title}</div>
        <div style={{ font: '600 10px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 2, letterSpacing: '0.04em' }}>{sub}</div>
      </div>
      <button onClick={() => setOn((o) => !o)} style={{
        width: 40, height: 22, borderRadius: 13,
        background: on ? 'var(--tt-ember)' : 'var(--tt-surf-3)',
        border: 'none', cursor: 'pointer',
        position: 'relative', padding: 0,
        transition: 'background 250ms ease'
      }}>
        <div style={{
          position: 'absolute', top: 3, left: on ? 20 : 3,
          width: 16, height: 16, borderRadius: '50%',
          background: '#fff',
          transition: 'left 250ms cubic-bezier(0.2,0.7,0.2,1)',
          boxShadow: '0 2px 4px rgba(0,0,0,0.3)'
        }} />
      </button>
    </div>);

}

function RuleRow({ text, badge }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '9px 0',
      borderBottom: '1px solid var(--tt-line)'
    }}>
      <span style={{
        width: 18, height: 18, borderRadius: '50%',
        border: '2px solid var(--tt-ember)',
        background: 'var(--tt-ember-dim)',
        display: 'grid', placeItems: 'center', flex: '0 0 auto'
      }}>
        <Icon name="check" size={9} color="var(--tt-ember)" strokeWidth={2.6} />
      </span>
      <span style={{ flex: 1, font: '600 12px var(--tt-font)', color: 'var(--tt-text-2)' }}>{text}</span>
      <span style={{ font: '800 8.5px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '0.14em' }}>{badge}</span>
    </div>);

}

window.PCScreenPair = PCScreenPair;
// Trailtether PC — Hike Watch (drill-down view of one active hike)
// The headline screen. Big live map + vitals stack + timeline + chat.

function PCScreenHikeWatch() {
  return (
    <PCWindow>
      <PCTitleBar />
      <PCLayout active="watch">
        <PCPageHeader
          eyebrow={<>WATCHING · INCIDENT-FREE FOR <b style={{ color: 'var(--tt-green)' }}>4h 12m</b></>}
          title={<><span style={{ color: 'var(--tt-text-2)', fontWeight: 600, marginRight: 8 }}>John Davies</span> · Mt. Marcy Summit</>}
          sub={
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
              <PCPill live ember>LIVE · 1 Hz</PCPill>
              <PCPill success>TETHERED · last ping 2m</PCPill>
              <span>· DAY HIKE · STARTED 06:14 · EXPECTED RETURN 13:30</span>
            </span>
          }
          actions={
          <div style={{ display: 'flex', gap: 8 }}>
              <PCBtn ghost leftIcon="message">CHAT</PCBtn>
              <PCBtn leftIcon="radio">PING</PCBtn>
              <PCBtn danger leftIcon="phone">CALL RESCUE</PCBtn>
            </div>
          } />
        

        <div style={{ flex: 1, display: 'grid',
          gridTemplateColumns: '1fr 360px',
          gridTemplateRows: '1fr auto',
          gap: 14, padding: '18px 26px 22px', minHeight: 0, overflow: 'hidden' }}>

          {/* Left top — the big map */}
          <div style={{ gridRow: '1 / 2', gridColumn: '1 / 2', minHeight: 0 }}>
            <PCHikeWatchMap />
          </div>

          {/* Right top — vitals stack */}
          <div style={{ gridRow: '1 / 2', gridColumn: '2 / 3', display: 'flex', flexDirection: 'column', gap: 14, minHeight: 0, overflow: 'auto' }}>
            <PCVitalsCard />
            <PCWatcherChat />
          </div>

          {/* Bottom full-width — elevation + timeline */}
          <div style={{ gridRow: '2 / 3', gridColumn: '1 / 3' }}>
            <PCWatchElevationCard />
          </div>
        </div>
      </PCLayout>
    </PCWindow>);

}

/* ============================================================
   Big live map — the trail with John's position + plan overlays
   ============================================================ */
function PCHikeWatchMap() {
  return (
    <div style={{ position: 'relative', background: '#0a1218', borderRadius: 14,
      border: '1px solid var(--tt-line)', overflow: 'hidden', height: '100%' }}>
      <svg viewBox="0 0 820 520" preserveAspectRatio="xMidYMid slice"
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <radialGradient id="hwTerr" cx="50%" cy="48%" r="65%">
            <stop offset="0%" stopColor="#1a2820" stopOpacity="0.9" />
            <stop offset="100%" stopColor="#06090c" stopOpacity="0.4" />
          </radialGradient>
          <filter id="hwGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3.2" />
            <feMerge><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>
        <rect width="820" height="520" fill="url(#hwTerr)" />

        {/* Dense contour lines */}
        <g fill="none" stroke="#1a2820" strokeWidth="0.7" opacity="0.7">
          {[
          'M-20,490 Q200,470 410,465 T860,478',
          'M-20,440 Q200,400 410,410 T860,430',
          'M-20,390 Q200,340 420,350 T860,380',
          'M0,340 Q220,270 420,290 T860,330',
          'M20,290 Q230,210 430,230 T860,270',
          'M50,240 Q260,150 440,180 T860,220',
          'M100,190 Q280,100 440,130 T820,180',
          'M150,140 Q310,60 440,100 T800,140',
          'M200,100 Q330,20 440,60 T740,90'].
          map((d, i) => <path key={i} d={d} />)}
        </g>
        <g fill="none" stroke="#2a4036" strokeWidth="0.4" opacity="0.5">
          {[
          'M-20,510 Q200,490 410,485 T860,500',
          'M-20,470 Q200,440 410,445 T860,460',
          'M-20,420 Q200,380 410,390 T860,415',
          'M-20,370 Q220,310 420,325 T860,360',
          'M20,320 Q230,240 430,265 T860,300',
          'M60,270 Q260,180 440,205 T830,250'].
          map((d, i) => <path key={i} d={d} />)}
        </g>

        {/* Forest + lakes + rivers */}
        <ellipse cx="190" cy="430" rx="42" ry="14" fill="#152a3c" opacity="0.7" />
        <ellipse cx="660" cy="290" rx="22" ry="9" fill="#152a3c" opacity="0.55" />
        <g opacity="0.5">
          <circle cx="130" cy="380" r="28" fill="#1a2a1f" />
          <circle cx="240" cy="470" r="32" fill="#1a2a1f" />
          <circle cx="500" cy="440" r="26" fill="#1a2a1f" />
        </g>
        <path d="M -10,460 C 80,450 160,470 240,460 S 380,440 460,410 S 600,360 720,330"
        fill="none" stroke="rgba(90,161,214,0.5)" strokeWidth="2"
        strokeLinecap="round" />

        {/* Region labels */}
        <text x="380" y="490" fill="#3d454d" fontFamily="Manrope" fontSize="11" fontWeight="700"
        letterSpacing="0.32em" textAnchor="middle">NISQUALLY  VALLEY</text>
        <text x="640" y="200" fill="#3d454d" fontFamily="Manrope" fontSize="10" fontWeight="700"
        letterSpacing="0.22em" textAnchor="middle">CATHEDRAL  SPINE</text>

        {/* Planned route — full path */}
        <path id="hwTrail" d="M 80,470 Q 180,420 240,370 Q 320,310 380,250 Q 450,190 510,150 Q 580,110 660,80"
        fill="none" stroke="#ff6a2c" strokeOpacity="0.35"
        strokeWidth="7" strokeLinecap="round" filter="url(#hwGlow)" />
        <path d="M 80,470 Q 180,420 240,370 Q 320,310 380,250 Q 450,190 510,150 Q 580,110 660,80"
        fill="none" stroke="#ff8a4d" strokeWidth="2.2" strokeLinecap="round" />

        {/* Travelled section — solid bright */}
        <path d="M 80,470 Q 180,420 240,370 Q 320,310 380,250"
        fill="none" stroke="#fff4d6" strokeWidth="2.4" strokeLinecap="round"
        filter="url(#hwGlow)" />
        <path d="M 80,470 Q 180,420 240,370 Q 320,310 380,250"
        fill="none" stroke="#ff6a2c" strokeWidth="3.2" strokeLinecap="round" />

        {/* Trail markers */}
        <g transform="translate(80,470)">
          <rect x="-7" y="-7" width="14" height="14" transform="rotate(45)" fill="#ff6a2c" stroke="#1a0d04" strokeWidth="1.5" />
          <g transform="translate(16,4)">
            <rect x="0" y="-10" width="52" height="20" rx="4" fill="rgba(10,12,15,0.92)" stroke="rgba(255,255,255,0.15)" strokeWidth="0.5" />
            <text x="26" y="3" textAnchor="middle" fill="#eef1f4" fontFamily="Manrope" fontSize="10" fontWeight="800" letterSpacing="0.12em">START · 06:14</text>
          </g>
        </g>
        <g transform="translate(660,80)">
          <circle r="10" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="2.2" />
          <path d="M 0 -4 L 5 4 L -5 4 Z" fill="#ff6a2c" />
          <g transform="translate(0,-22)">
            <rect x="-58" y="-12" width="116" height="22" rx="4" fill="rgba(10,12,15,0.95)" stroke="#ff6a2c" strokeWidth="0.8" />
            <text x="0" y="2" textAnchor="middle" fill="#ff8a4d" fontFamily="Manrope" fontSize="10.5" fontWeight="800" letterSpacing="0.1em">SUMMIT · 1,685 m</text>
          </g>
        </g>

        {/* Hazard pips along the route */}
        {[
        { d: 0.34, kind: 'water', color: '#5aa1d6', glyph: '~' },
        { d: 0.47, kind: 'shelter', color: '#4cc38a', glyph: '⌂' },
        { d: 0.56, kind: 'danger', color: '#e63d2e', glyph: '!' },
        { d: 0.74, kind: 'shelter', color: '#4cc38a', glyph: '⌂' },
        { d: 0.92, kind: 'danger', color: '#e63d2e', glyph: '!' }].
        map((h, i) => {
          const p = samplePath(h.d);
          return (
            <g key={i} transform={`translate(${p.x},${p.y})`}>
              <circle r="9" fill="#0a0c0f" stroke={h.color} strokeWidth="1.5" />
              <text y="3" textAnchor="middle" fill={h.color} fontFamily="JetBrains Mono" fontSize="11" fontWeight="900">{h.glyph}</text>
            </g>);

        })}

        {/* John's live position — pulsing big marker */}
        <g transform="translate(380,250)">
          <circle r="50" fill="rgba(255,106,44,0.10)">
            <animate attributeName="r" values="38;58;38" dur="3s" repeatCount="indefinite" />
          </circle>
          <circle r="32" fill="rgba(255,106,44,0.18)">
            <animate attributeName="r" values="24;38;24" dur="3s" repeatCount="indefinite" />
          </circle>
          <circle r="20" fill="#1a1d22" stroke="#ff6a2c" strokeWidth="3" />
          <text y="6" textAnchor="middle" fill="#fff" fontFamily="Manrope" fontSize="16" fontWeight="900">J</text>
          {/* heading arrow */}
          <path d="M 22 -8 L 36 -16 L 32 -6 L 38 -2 Z" fill="#ff8a4d" />
          {/* trailing dots — recent positions */}
          {[
          { x: -30, y: 8 }, { x: -58, y: 22 }, { x: -86, y: 38 }, { x: -110, y: 55 }].
          map((p, i) =>
          <circle key={i} cx={p.x} cy={p.y} r={3 - i * 0.4} fill="#ff8a4d" opacity={0.7 - i * 0.15} />
          )}
          {/* call-out card */}
          <g transform="translate(36,-58)">
            <rect x="0" y="0" width="200" height="84" rx="8"
            fill="rgba(10,12,15,0.96)" stroke="rgba(255,106,44,0.45)" strokeWidth="1" />
            <text x="14" y="22" fill="#ff8a4d" fontFamily="Manrope" fontSize="11.5" fontWeight="900" letterSpacing="0.12em">JOHN D. · LIVE</text>
            <text x="14" y="38" fill="#eef1f4" fontFamily="Manrope" fontSize="11" fontWeight="700">km 8.4 of 12.4 · 68%</text>
            <text x="14" y="55" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9.5" fontWeight="600" letterSpacing="0.04em">ELEV 1,850 m  ·  PACE 2.8 km/hr</text>
            <text x="14" y="70" fill="#98a1ac" fontFamily="JetBrains Mono" fontSize="9.5" fontWeight="600" letterSpacing="0.04em">HEADING NE 042°  ·  BATT 84%</text>
          </g>
        </g>

        {/* km markers */}
        {[
        { d: 0.20, label: '2' },
        { d: 0.40, label: '4' },
        { d: 0.62, label: '8' },
        { d: 0.82, label: '10' }].
        map((m, i) => {
          const p = samplePath(m.d);
          return (
            <g key={i} transform={`translate(${p.x + 14},${p.y - 4})`}>
              <rect x="-15" y="-10" width="30" height="16" rx="3" fill="#1a0d04" stroke="#ff8a4d" strokeWidth="0.7" />
              <text x="0" y="3" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="10" fontWeight="800">{m.label} km</text>
            </g>);

        })}
      </svg>

      {/* Top floating: hike score + weather */}
      <div style={{ position: 'absolute', top: 14, left: 14, display: 'flex', gap: 9 }}>
        <PCPill ember>HIKE SCORE · 8/10</PCPill>
        <PCPill>14°C · WIND 18 km/h</PCPill>
        <PCPill success>4h 12m INCIDENT-FREE</PCPill>
      </div>

      {/* Right floats */}
      <div style={{ position: 'absolute', right: 14, top: 14, display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
        <PCMapBtnGroup>
          <PCMapBtn icon="plus" />
          <PCMapBtn icon="minus" />
        </PCMapBtnGroup>
        <PCMapBtn icon="crosshair" ember />
        <PCMapBtn icon="layers" />
        <PCMapBtn icon="eye" />
      </div>

      {/* Bottom — progress + ETA */}
      <div style={{ position: 'absolute', bottom: 14, left: 14, right: 14,
        display: 'flex', alignItems: 'center', gap: 14,
        background: 'rgba(10,12,15,0.78)', backdropFilter: 'blur(10px)',
        border: '1px solid var(--tt-line-2)', borderRadius: 10, padding: '10px 14px' }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
            <span style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.18em' }}>PROGRESS</span>
            <span style={{ font: '800 11px var(--tt-mono)', color: 'var(--tt-ember)' }}>8.4 / 12.4 km · 68%</span>
          </div>
          <div style={{ height: 6, background: 'var(--tt-surf-2)', borderRadius: 3, overflow: 'hidden', position: 'relative' }}>
            <div style={{ height: '100%', width: '68%',
              background: 'linear-gradient(90deg, #ff6a2c, #ff8a4d, #fff4d6)',
              borderRadius: 3, boxShadow: '0 0 10px rgba(255,106,44,0.5)' }} />
            {/* hazard pip markers along the bar */}
            {[34, 47, 56, 74, 92].map((p) =>
            <span key={p} style={{ position: 'absolute', top: -2, left: `${p}%`, transform: 'translateX(-50%)',
              width: 4, height: 10, background: 'var(--tt-text-3)', borderRadius: 1 }} />
            )}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <div style={{ textAlign: 'right' }}>
            <div style={{ font: '700 9.5px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.16em' }}>ETA RETURN</div>
            <div className="num" style={{ font: '800 18px var(--tt-mono)', color: 'var(--tt-text)', letterSpacing: '-0.02em' }}>13:30</div>
          </div>
        </div>
      </div>
    </div>);

}

// Approximate the trail path by sampling — same shape as the SVG above.
function samplePath(t) {
  const pts = [
  { x: 80, y: 470 }, { x: 140, y: 440 }, { x: 200, y: 405 },
  { x: 260, y: 360 }, { x: 320, y: 320 }, { x: 380, y: 250 },
  { x: 440, y: 210 }, { x: 510, y: 150 }, { x: 580, y: 110 },
  { x: 620, y: 95 }, { x: 660, y: 80 }];

  const idx = t * (pts.length - 1);
  const i = Math.floor(idx);
  const u = idx - i;
  const a = pts[Math.max(0, Math.min(pts.length - 1, i))];
  const b = pts[Math.max(0, Math.min(pts.length - 1, i + 1))];
  return { x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u };
}

/* ============================================================
   Right-rail vitals card
   ============================================================ */
function PCVitalsCard() {
  return (
    <PCCard padding={0}>
      <div style={{ padding: '14px 18px 10px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <div style={{
            width: 46, height: 46, borderRadius: '50%',
            background: 'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
            border: '2px solid var(--tt-ember)',
            display: 'grid', placeItems: 'center',
            color: '#fff', font: '900 16px var(--tt-font)',
            boxShadow: '0 0 16px rgba(255,106,44,0.45)'
          }}>JD</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: '900 14px var(--tt-font)', color: 'var(--tt-text)' }}>John Davies</div>
            <div style={{ font: '700 9.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 2, letterSpacing: '0.1em' }}>
              ADVANCED · CAPE TOWN
            </div>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 1,
        background: 'var(--tt-line)', borderTop: '1px solid var(--tt-line)' }}>
        <VitalsCell label="ELEVATION" value="1,850" unit="m" icon="mountain" ember />
        <VitalsCell label="PACE" value="2.8" unit="km/hr" icon="route" />
        <VitalsCell label="HEADING" value="042°" unit="NE" icon="compass" />
        <VitalsCell label="HR" value="142" unit="bpm" icon="heart" />
        <VitalsCell label="BATTERY" value="84" unit="%" icon="alert" success />
        <VitalsCell label="SIGNAL" value="4G" unit="strong" icon="radio" />
        <VitalsCell label="LAST PING" value="2m" unit="ago" icon="clock" />
        <VitalsCell label="STREAK" value="4h 12m" unit="incident-free" icon="check" success />
      </div>

      {/* Plan summary */}
      <div style={{ padding: '12px 18px 16px', borderTop: '1px solid var(--tt-line)' }}>
        <div style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.18em', marginBottom: 6 }}>HIKE PLAN</div>
        <div style={{ display: 'flex', gap: 10, fontSize: 11, marginBottom: 5 }}>
          <span style={{ color: 'var(--tt-text-3)', font: '700 10px var(--tt-mono)', letterSpacing: '0.06em', minWidth: 90 }}>TRAIL</span>
          <span style={{ color: 'var(--tt-text)', fontWeight: 700 }}>Mt. Marcy Summit · 12.4 km</span>
        </div>
        <div style={{ display: 'flex', gap: 10, fontSize: 11, marginBottom: 5 }}>
          <span style={{ color: 'var(--tt-text-3)', font: '700 10px var(--tt-mono)', letterSpacing: '0.06em', minWidth: 90 }}>STARTED</span>
          <span style={{ color: 'var(--tt-text)', fontWeight: 700 }}>OCT 26 · 06:14</span>
        </div>
        <div style={{ display: 'flex', gap: 10, fontSize: 11, marginBottom: 5 }}>
          <span style={{ color: 'var(--tt-text-3)', font: '700 10px var(--tt-mono)', letterSpacing: '0.06em', minWidth: 90 }}>EXPECTED</span>
          <span style={{ color: 'var(--tt-text)', fontWeight: 700 }}>13:30 (in 3h 21m)</span>
        </div>
        <div style={{ display: 'flex', gap: 10, fontSize: 11 }}>
          <span style={{ color: 'var(--tt-text-3)', font: '700 10px var(--tt-mono)', letterSpacing: '0.06em', minWidth: 90 }}>ALERT IF LATE</span>
          <span style={{ color: 'var(--tt-ember)', fontWeight: 700 }}>14:00 · 30 min grace</span>
        </div>
      </div>
    </PCCard>);

}

function VitalsCell({ label, value, unit, icon, ember, success, danger }) {
  const color = danger ? 'var(--tt-red)' : success ? 'var(--tt-green)' : ember ? 'var(--tt-ember)' : 'var(--tt-text)';
  return (
    <div style={{ padding: '12px 14px', background: 'var(--tt-surf)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <Icon name={icon} size={10} color="var(--tt-text-3)" />
        <span style={{ font: '700 9px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-3)' }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 5 }}>
        <span className="num" style={{ font: '800 18px var(--tt-mono)', color, letterSpacing: '-0.02em' }}>{value}</span>
        {unit && <span className="num" style={{ fontSize: 9, color: 'var(--tt-text-2)', fontWeight: 600, letterSpacing: '0.04em' }}>{unit}</span>}
      </div>
    </div>);

}

/* ============================================================
   Watcher chat
   ============================================================ */
function PCWatcherChat() {
  return (
    <PCCard padding={0} style={{ display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '12px 16px 8px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ font: '800 11px var(--tt-font)', letterSpacing: '0.18em', color: 'var(--tt-text-2)' }}>DIRECT CHAT</span>
        <PCPill live success>ONLINE</PCPill>
      </div>
      <div style={{ flex: 1, padding: '4px 14px 4px', display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 200, overflowY: 'auto' }}>
        <WatcherMsg time="06:14" mine text="Have a good one. Tether is armed — return by 13:30 or I get a buzz." />
        <WatcherMsg time="09:42" name="John" color="#ff6a2c" initial="J" text="At Shadow Lake. Going to push for Liberty Cap by 11." />
        <WatcherMsg time="10:01" mine text="Roger. Wind advisory pinged in for 12:30 — keep an eye." />
        <WatcherMsg time="10:08" name="John" color="#ff6a2c" initial="J" text="Got it. Will turn around at the col if it picks up." />
      </div>
      <div style={{ padding: '10px 12px', borderTop: '1px solid var(--tt-line)', display: 'flex', gap: 8, alignItems: 'center' }}>
        <input type="text" placeholder="Send a message…" style={{
          flex: 1, padding: '8px 11px', borderRadius: 8,
          background: 'rgba(255,255,255,0.04)', border: '1px solid var(--tt-line-2)',
          color: 'var(--tt-text)', font: '500 12px var(--tt-font)', outline: 'none'
        }} />
        <button className="pressable" style={{
          width: 34, height: 34, borderRadius: 8,
          background: 'linear-gradient(135deg, #ff8a4d, #ff6a2c)', border: 'none',
          display: 'grid', placeItems: 'center', cursor: 'pointer'
        }}><Icon name="send-fill" size={13} color="#1a0d04" /></button>
      </div>
    </PCCard>);

}

function WatcherMsg({ time, name, color, initial, mine, text }) {
  return (
    <div style={{ display: 'flex', gap: 8, flexDirection: mine ? 'row-reverse' : 'row' }}>
      {!mine &&
      <div style={{
        width: 24, height: 24, borderRadius: '50%',
        background: `linear-gradient(135deg, ${color}, ${color}aa)`,
        color: '#fff', display: 'grid', placeItems: 'center',
        font: '800 10px var(--tt-font)', border: `1.5px solid ${color}`,
        flex: '0 0 auto'
      }}>{initial}</div>
      }
      <div style={{ maxWidth: '78%' }}>
        {!mine &&
        <div style={{ font: '700 9px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.06em', marginBottom: 2 }}>
            {name} · {time}
          </div>
        }
        <div style={{
          padding: '7px 10px',
          background: mine ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
          border: `1px solid ${mine ? 'rgba(255,106,44,0.36)' : 'var(--tt-line)'}`,
          color: mine ? 'var(--tt-ember-3)' : 'var(--tt-text)',
          borderRadius: mine ? '10px 10px 3px 10px' : '10px 10px 10px 3px',
          font: '500 11.5px/1.4 var(--tt-font)'
        }}>{text}</div>
        {mine &&
        <div style={{ font: '700 9px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 2, textAlign: 'right', letterSpacing: '0.06em' }}>
            {time} <span style={{ color: 'var(--tt-green)' }}>✓✓</span>
          </div>
        }
      </div>
    </div>);

}

/* ============================================================
   Bottom — elevation profile + segment readout
   ============================================================ */
function PCWatchElevationCard() {
  return (
    <PCCard padding={0}>
      <div style={{ padding: '12px 18px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <span style={{ font: '800 11px var(--tt-font)', letterSpacing: '0.18em', color: 'var(--tt-text-2)' }}>ELEVATION PROFILE</span>
          <PCPill ember>↑ 845m · ↓ 110m</PCPill>
        </div>
        <div style={{ display: 'flex', gap: 14, font: '700 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.08em' }}>
          <span>SECTION · <b style={{ color: 'var(--tt-text)' }}>SUNRISE RIDGE</b></span>
          <span style={{ color: 'var(--tt-line-3)' }}>·</span>
          <span>GRADE · <b style={{ color: 'var(--tt-amber)' }}>MODERATE</b></span>
          <span style={{ color: 'var(--tt-line-3)' }}>·</span>
          <span>NEXT · <b style={{ color: 'var(--tt-red)' }}>CLASS 3 SCRAMBLE in 0.7km</b></span>
        </div>
      </div>
      <div style={{ padding: '4px 18px 16px' }}>
        <PCWatchElevSVG />
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6,
          font: '700 9.5px var(--tt-mono)', color: 'var(--tt-text-3)', letterSpacing: '0.06em' }}>
          <span>0 km · 480 m</span>
          <span>3 km</span>
          <span>6 km</span>
          <span style={{ color: 'var(--tt-ember)' }}>8.4 km · 1,850 m  ◀ NOW</span>
          <span>9 km</span>
          <span>12 km</span>
          <span>12.4 km · 1,685 m</span>
        </div>
      </div>
    </PCCard>);

}

function PCWatchElevSVG() {
  const W = 1280,H = 130,padL = 30,padR = 30,padT = 8,padB = 14;
  const pts = [
  [0, 480], [1, 580], [2, 720], [3, 870], [4.5, 1120], [5.8, 1280], [6.5, 1440], [7.2, 1580], [8, 1620], [8.4, 1850],
  [9.2, 1685], [10.5, 1740], [11.4, 1710], [12.4, 1685]];

  const minE = 400,maxE = 1900;
  const total = 12.4;
  const x = (km) => padL + km / total * (W - padL - padR);
  const y = (e) => H - padB - (e - minE) / (maxE - minE) * (H - padT - padB);
  const line = pts.map((p, i) => `${i === 0 ? 'M' : 'L'}${x(p[0]).toFixed(1)},${y(p[1]).toFixed(1)}`).join(' ');
  const travelled = pts.filter((p) => p[0] <= 8.4).
  map((p, i) => `${i === 0 ? 'M' : 'L'}${x(p[0]).toFixed(1)},${y(p[1]).toFixed(1)}`).join(' ');
  const fill = line + ` L ${x(total)},${H - padB} L ${padL},${H - padB} Z`;
  const cx = x(8.4),cy = y(1850);

  const SEGMENTS = [
  { km0: 0, km1: 2.1, color: '#4cc38a' },
  { km0: 2.1, km1: 4.5, color: '#f2a93b' },
  { km0: 4.5, km1: 5.8, color: '#f2a93b' },
  { km0: 5.8, km1: 7.2, color: '#ff6a2c' },
  { km0: 7.2, km1: 9.2, color: '#f2a93b' },
  { km0: 9.2, km1: 12.4, color: '#ff6a2c' }];


  return (
    <svg width="100%" height={H + 16} viewBox={`0 0 ${W} ${H + 16}`} preserveAspectRatio="none"
    style={{ display: 'block' }}>
      <defs>
        <linearGradient id="hwElev" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0" />
        </linearGradient>
      </defs>

      {/* difficulty bands */}
      {SEGMENTS.map((s, i) =>
      <rect key={i} x={x(s.km0)} y={H - padB - 2} width={x(s.km1) - x(s.km0)} height={6}
      fill={s.color} opacity="0.85" />
      )}

      {/* grid lines */}
      {[800, 1200, 1600].map((v) =>
      <g key={v}>
          <line x1={padL} x2={W - padR} y1={y(v)} y2={y(v)} stroke="rgba(255,255,255,0.05)" />
          <text x={W - padR - 2} y={y(v) - 3} textAnchor="end" fill="#5a6470"
        fontFamily="JetBrains Mono" fontSize="9" fontWeight="700">{v}m</text>
        </g>
      )}

      {/* elev area + line */}
      <path d={fill} fill="url(#hwElev)" />
      <path d={line} fill="none" stroke="#ff8a4d" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" />
      {/* travelled portion in bright cream */}
      <path d={travelled} fill="none" stroke="#fff4d6" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />

      {/* hazard pips */}
      {[
      { km: 4.2, c: '#5aa1d6', g: '~' },
      { km: 5.8, c: '#4cc38a', g: '⌂' },
      { km: 6.5, c: '#e63d2e', g: '!' },
      { km: 9.2, c: '#4cc38a', g: '⌂' },
      { km: 11.4, c: '#e63d2e', g: '!' }].
      map((h, i) =>
      <g key={i} transform={`translate(${x(h.km)}, ${H - padB + 12})`}>
          <circle r="5" fill="#0a0c0f" stroke={h.c} strokeWidth="1.2" />
          <text y="2.5" textAnchor="middle" fill={h.c} fontFamily="JetBrains Mono" fontSize="7.5" fontWeight="900">{h.g}</text>
        </g>
      )}

      {/* current position marker */}
      <line x1={cx} x2={cx} y1={padT} y2={H - padB} stroke="rgba(255,255,255,0.55)" strokeWidth="0.8" strokeDasharray="2 2" />
      <line x1={cx} x2={cx} y1={padT} y2={cy} stroke="#fff" strokeWidth="1.4" />
      <g transform={`translate(${cx}, ${cy - 18})`}>
        <rect x="-26" y="-12" width="52" height="18" rx="4" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="1" />
        <text y="2" textAnchor="middle" fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="10" fontWeight="900" letterSpacing="0.04em">1,850 m</text>
      </g>
      <circle cx={cx} cy={cy} r="7" fill="#fff" stroke="#ff6a2c" strokeWidth="2.4"
      style={{ filter: 'drop-shadow(0 0 8px rgba(255,106,44,0.7))' }} />
    </svg>);

}

window.PCScreenHikeWatch = PCScreenHikeWatch;
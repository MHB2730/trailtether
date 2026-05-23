// Trailtether — Activity / Stats screen

function ScreenStats() {
  const [tab, setTab] = React.useState(1); // 0 My Hikes, 1 Overall Stats
  return (
    <div className="phone">
      <div className="punchhole" />
      <div className="screen">
        <StatusBar time="10:09" right={<span style={{ color: 'var(--tt-text-2)', fontSize: 10.5, fontWeight: 700, letterSpacing: '0.08em', marginRight: 4 }}>LTE</span>} />

        <div className="tt-appbar anim-in" style={{ paddingBottom: 6 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 4 }}>
              <TTLogo size={18} />
              <span style={{ font: '800 12px var(--tt-font)', letterSpacing: '0.16em' }}>
                TRAIL<span style={{ color: 'var(--tt-ember)' }}>TETHER</span>
              </span>
            </div>
            <h1 style={{ margin: 0, font: '800 24px var(--tt-font)', letterSpacing: '-0.02em' }}>Activity</h1>
          </div>
          <div style={{
            width: 38, height: 38, borderRadius: '50%',
            border: '2px solid var(--tt-ember)',
            background: 'linear-gradient(135deg, #6b3a1a, #ff8a4d)',
            position: 'relative', display: 'grid', placeItems: 'center',
            color: '#fff', font: '800 13px var(--tt-font)',
            boxShadow: '0 0 12px rgba(255,106,44,0.4)'
          }}>JD</div>
          <button className="icon-btn"><Icon name="settings" size={16} color="var(--tt-text-2)" /></button>
        </div>

        {/* Segmented tabs */}
        <div style={{ padding: '4px 18px 0' }} className="anim-in">
          <SegmentedTabs
            tabs={['My Hikes', 'Overall Stats']}
            active={tab}
            onChange={setTab} />
          
        </div>

        <div className="tt-scroll" style={{ padding: '14px 18px 24px' }}>
          {tab === 1 ? <OverallStats /> : <MyHikes />}
        </div>

        <BottomNav active="home" />
      </div>
    </div>);

}

function SegmentedTabs({ tabs, active, onChange }) {
  const segRef = React.useRef(null);
  const [ind, setInd] = React.useState({ left: 4, width: 0 });

  React.useLayoutEffect(() => {
    if (!segRef.current) return;
    const seg = segRef.current.querySelectorAll('.seg')[active];
    if (!seg) return;
    const container = segRef.current.getBoundingClientRect();
    const r = seg.getBoundingClientRect();
    setInd({ left: r.left - container.left, width: r.width });
  }, [active, tabs.length]);

  return (
    <div className="segmented" ref={segRef}>
      <div className="indicator" style={{ left: ind.left, width: ind.width }} />
      {tabs.map((label, i) =>
      <div key={label}
      className={`seg ${i === active ? 'active' : ''}`}
      onClick={() => onChange(i)}>
          {label}
        </div>
      )}
    </div>);

}

function OverallStats() {
  return (
    <>
      <FeaturedHike />
      <HealthSync />
      <StatGrid />
      <RecentActivity />
    </>);

}

function FeaturedHike() {
  return (
    <div className="card pressable anim-up" style={{ padding: '16px 18px', animationDelay: '120ms' }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8 }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--tt-ember)', boxShadow: '0 0 6px var(--tt-ember)' }} />
            <span style={{ font: '800 10px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '0.16em' }}>LAST HIKE</span>
          </div>
          <div style={{ font: '800 17px var(--tt-font)', color: 'var(--tt-text)', marginTop: 6, letterSpacing: '-0.01em' }}>Mt. Marcy Trail</div>
          <div style={{ font: '600 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 3, letterSpacing: '0.04em' }}>OCT 26, 2023 · 5.8 km · ↑ 3,950 M</div>
        </div>
        <button className="icon-btn" style={{ width: 32, height: 32 }}>
          <Icon name="chevron-right" size={14} color="var(--tt-text-2)" />
        </button>
      </div>
      <BigElevChart />
    </div>);

}

function HealthSync() {
  return (
    <div className="anim-up" style={{ marginTop: 12, animationDelay: '220ms' }}>
      <div style={{
        position: 'relative',
        background: 'linear-gradient(95deg, #ff6a2c 0%, #ff8a4d 100%)',
        borderRadius: 14,
        padding: '13px 16px',
        display: 'flex', alignItems: 'center', gap: 13,
        boxShadow: '0 10px 24px -8px rgba(255,106,44,0.55)',
        overflow: 'hidden'
      }}>
        {/* moving shimmer band */}
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.7,
          background: 'linear-gradient(120deg, transparent 30%, rgba(255,255,255,0.18) 50%, transparent 70%)',
          backgroundSize: '200% 100%',
          animation: 'shimmer 4s infinite linear',
          pointerEvents: 'none'
        }} />
        <div style={{ width: 38, height: 38, borderRadius: 11, background: 'rgba(26,13,4,0.32)', display: 'grid', placeItems: 'center', flex: '0 0 auto', zIndex: 1 }}>
          <Icon name="heart" size={19} color="#1a0d04" />
        </div>
        <div style={{ flex: 1, color: '#1a0d04', zIndex: 1 }}>
          <div style={{ font: '900 13px var(--tt-font)', letterSpacing: '0.01em' }}>Synced to Health Connect</div>
          <div style={{ font: '700 10px var(--tt-mono)', opacity: 0.7, marginTop: 3, letterSpacing: '0.08em' }}>SYNCED 2m AGO · 16:34</div>
        </div>
        <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'rgba(26,13,4,0.85)', display: 'grid', placeItems: 'center', flex: '0 0 auto', zIndex: 1 }}>
          <Icon name="check" size={15} color="#ff8a4d" strokeWidth={2.4} />
        </div>
      </div>
    </div>);

}

function StatGrid() {
  const tiles = [
  { icon: 'pin', label: 'Distance', value: '10.2', unit: 'km' },
  { icon: 'clock', label: 'Duration', value: '5:14:22' },
  { icon: 'compass', label: 'Avg Pace', value: '29:45', unit: '/km/hr' },
  { icon: 'arrow-up', label: 'Elev Gain', value: '3,944', unit: 'm', ember: true },
  { icon: 'flame', label: 'Calories', value: '1,189', unit: 'kcal' },
  { icon: 'people', label: 'Steps', value: '18,432' }];

  return (
    <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      <Stagger base={340} delay={70}>
        {tiles.map((t, i) =>
        <StatTile key={t.label} {...t} />
        )}
      </Stagger>
    </div>);

}

function StatTile({ icon, label, value, unit, ember }) {
  return (
    <div className="card pressable" style={{ padding: '14px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
        <div style={{
          width: 22, height: 22, borderRadius: 6,
          background: ember ? 'var(--tt-ember-dim)' : 'rgba(255,255,255,0.03)',
          border: `1px solid ${ember ? 'rgba(255,106,44,0.32)' : 'var(--tt-line-2)'}`,
          display: 'grid', placeItems: 'center'
        }}>
          <Icon name={icon} size={12} color={ember ? 'var(--tt-ember)' : 'var(--tt-text-2)'} />
        </div>
        <span style={{ font: '700 10.5px var(--tt-font)', letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--tt-text-3)' }}>{label}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 5, marginTop: 10 }}>
        <span className="num count-up" style={{ font: '800 23px var(--tt-mono)', color: ember ? 'var(--tt-ember)' : 'var(--tt-text)', letterSpacing: '-0.02em', animationDelay: '500ms' }}>{value}</span>
        {unit && <span className="num" style={{ fontSize: 11, color: 'var(--tt-text-2)', fontWeight: 600 }}>{unit}</span>}
      </div>
    </div>);

}

function RecentActivity() {
  const acts = [
  { name: 'Bear Creek', date: 'Oct 21', dist: '6.4 km', gain: '+1,250', pathIdx: 0 },
  { name: 'Cascade Mtn', date: 'Oct 18', dist: '5.1 km', gain: '+1,880', pathIdx: 1 },
  { name: 'Pinecrest Ridge', date: 'Oct 12', dist: '8.2 km', gain: '+2,140', pathIdx: 2 }];

  return (
    <div style={{ marginTop: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <span style={{ font: '700 11px var(--tt-font)', letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--tt-text-2)' }}>Recent Activity</span>
        <span style={{ font: '800 10px var(--tt-font)', color: 'var(--tt-ember)', letterSpacing: '0.1em' }}>VIEW ALL →</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <Stagger base={800} delay={80}>
          {acts.map((a) => <ActivityRow key={a.name} {...a} />)}
        </Stagger>
      </div>
    </div>);

}

function ActivityRow({ name, date, dist, gain, pathIdx }) {
  const paths = [
  'M 4 28 Q 12 18 20 22 Q 28 24 36 14',
  'M 4 26 L 10 14 L 18 22 L 26 10 L 36 18',
  'M 4 30 Q 14 8 24 18 Q 32 24 36 12'];

  return (
    <div className="pressable" style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 14px',
      background: 'var(--tt-surf)',
      border: '1px solid var(--tt-line)',
      borderRadius: 12,
      position: 'relative', overflow: 'hidden',
      cursor: 'pointer'
    }}>
      <div style={{ position: 'absolute', left: 0, top: 10, bottom: 10, width: 3, background: 'var(--tt-ember)', borderRadius: '0 2px 2px 0', boxShadow: '0 0 8px rgba(255,106,44,0.4)' }} />
      <div style={{
        width: 42, height: 42, borderRadius: 10,
        background: 'var(--tt-bg-3)',
        border: '1px solid var(--tt-line)', flex: '0 0 auto'
      }}>
        <svg width="42" height="42" viewBox="0 0 40 40">
          <g fill="none" stroke="#2a3038" strokeWidth="0.4">
            <path d="M0,18 Q12,12 20,18 T40,22" />
            <path d="M0,28 Q12,22 20,28 T40,30" />
          </g>
          <path d={paths[pathIdx]} stroke="#ff6a2c" strokeWidth="1.8" fill="none" strokeLinecap="round"
          className="draw-line" style={{ ['--len']: 80, animationDelay: '900ms' }} />
        </svg>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '800 13.5px var(--tt-font)', color: 'var(--tt-text)' }}>{name}</div>
        <div style={{ font: '600 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 3 }}>{date}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="num" style={{ font: '800 13px var(--tt-mono)', color: 'var(--tt-text)' }}>{dist}</div>
        <div className="num" style={{ font: '700 10.5px var(--tt-mono)', color: 'var(--tt-ember)', marginTop: 3 }}>{gain} m</div>
      </div>
    </div>);

}

function BigElevChart() {
  const w = 332,h = 140,padL = 38,padR = 8,padT = 10,padB = 22;
  const N = 60;
  const pts = [];
  for (let i = 0; i < N; i++) {
    const t = i / (N - 1);
    const bell = Math.pow(Math.sin(t * Math.PI), 1.4);
    const noise = Math.sin(t * 18) * 90 + Math.sin(t * 7) * 160;
    pts.push(500 + bell * 3500 + noise);
  }
  const min = 200,max = 4500;
  const stepX = (w - padL - padR) / (N - 1);
  const ptToXY = (v, i) => [padL + i * stepX, h - padB - (v - min) / (max - min) * (h - padT - padB)];
  const top = pts.map((v, i) => `${i === 0 ? 'M' : 'L'}${ptToXY(v, i).join(',')}`).join(' ');
  const fill = top + ` L ${w - padR},${h - padB} L ${padL},${h - padB} Z`;
  const peakIdx = pts.indexOf(Math.max(...pts));
  const [px, py] = ptToXY(pts[peakIdx], peakIdx);
  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', marginTop: 14 }} preserveAspectRatio="none">
      <defs>
        <linearGradient id="lastElev" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#ff6a2c" stopOpacity="0.55" />
          <stop offset="100%" stopColor="#ff6a2c" stopOpacity="0.02" />
        </linearGradient>
      </defs>
      {/* y gridlines */}
      {[3950, 2950, 1950, 950].map((v, i) => {
        const y = h - padB - (v - min) / (max - min) * (h - padT - padB);
        return <g key={v} className="anim-in" style={{ animationDelay: `${300 + i * 60}ms` }}>
          <line x1={padL} x2={w - padR} y1={y} y2={y} stroke="rgba(255,255,255,0.05)" />
          <text x={padL - 6} y={y + 3} textAnchor="end" fill="#5a6470" fontFamily="JetBrains Mono" fontSize="8.5">{v}ft</text>
        </g>;
      })}
      <path d={fill} fill="url(#lastElev)" className="anim-in" style={{ animationDelay: '600ms' }} />
      <path d={top} fill="none" stroke="#ff6a2c" strokeWidth="2"
      strokeLinejoin="round" strokeLinecap="round"
      className="draw-line" style={{ ['--len']: 900, animationDelay: '500ms' }} />
      {/* peak marker */}
      <line x1={px} y1={py} x2={px} y2={h - padB} stroke="rgba(255,255,255,0.28)" strokeDasharray="2 2"
      className="anim-in" style={{ animationDelay: '1300ms' }} />
      <circle cx={px} cy={py} r="4.5" fill="#fff" stroke="#ff6a2c" strokeWidth="2"
      className="anim-pop" style={{ animationDelay: '1300ms', transformOrigin: `${px}px ${py}px` }} />
      <g className="anim-up" style={{ animationDelay: '1400ms' }}>
        <rect x={px - 34} y={py - 24} width="68" height="18" rx="4" fill="#1a0d04" stroke="#ff6a2c" strokeWidth="0.8" />
        <text x={px} y={py - 12} fill="#ff8a4d" fontFamily="JetBrains Mono" fontSize="9.5" fontWeight="800" textAnchor="middle">5.8 km · 3,950 m</text>
      </g>
      {/* x labels */}
      {[0, 2, 4, 6, 8, 10].map((v) =>
      <text key={v} x={padL + v / 10 * (w - padL - padR)} y={h - 5} fill="#5a6470" fontFamily="JetBrains Mono" fontSize="8.5" textAnchor="middle">{v}</text>
      )}
    </svg>);

}

function MyHikes() {
  const hikes = [
  { name: 'Mt. Marcy Trail', date: 'Oct 26', dist: '5.8 km', gain: '+3,950', dur: '5:14:22', pathIdx: 1 },
  { name: 'Bear Creek', date: 'Oct 21', dist: '6.4 km', gain: '+1,250', dur: '3:42:08', pathIdx: 0 },
  { name: 'Cascade Mtn', date: 'Oct 18', dist: '5.1 km', gain: '+1,880', dur: '4:11:53', pathIdx: 1 },
  { name: 'Pinecrest Ridge', date: 'Oct 12', dist: '8.2 km', gain: '+2,140', dur: '6:02:11', pathIdx: 2 },
  { name: 'Wonderland Loop', date: 'Oct 04', dist: '12.5 km', gain: '+2,820', dur: '7:38:44', pathIdx: 0 },
  { name: 'Liberty Cap', date: 'Sep 29', dist: '4.6 km', gain: '+1,520', dur: '2:55:09', pathIdx: 2 }];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div className="anim-up" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '2px 2px 4px' }}>
        <div>
          <div className="num count-up" style={{ font: '800 30px var(--tt-mono)', color: 'var(--tt-text)', letterSpacing: '-0.02em' }}>47</div>
          <div style={{ font: '700 10.5px var(--tt-font)', letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--tt-text-3)', marginTop: 2 }}>Total Hikes</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="num count-up" style={{ font: '800 30px var(--tt-mono)', color: 'var(--tt-ember)', letterSpacing: '-0.02em' }}>284<span style={{ fontSize: 14, color: 'var(--tt-text-2)', marginLeft: 3 }}>km</span></div>
          <div style={{ font: '700 10.5px var(--tt-font)', letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--tt-text-3)', marginTop: 2 }}>Lifetime</div>
        </div>
      </div>

      <div style={{ height: 1, background: 'var(--tt-line)', margin: '4px 0 6px' }} />

      <Stagger base={250} delay={70}>
        {hikes.map((h) => <HikeRow key={h.name} {...h} />)}
      </Stagger>
    </div>);

}

function HikeRow({ name, date, dist, gain, dur, pathIdx }) {
  const paths = [
  'M 4 28 Q 12 18 20 22 Q 28 24 36 14',
  'M 4 26 L 10 14 L 18 22 L 26 10 L 36 18',
  'M 4 30 Q 14 8 24 18 Q 32 24 36 12'];

  return (
    <div className="pressable" style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 14px',
      background: 'var(--tt-surf)',
      border: '1px solid var(--tt-line)',
      borderRadius: 12,
      position: 'relative', overflow: 'hidden',
      cursor: 'pointer'
    }}>
      <div style={{ position: 'absolute', left: 0, top: 10, bottom: 10, width: 3, background: 'var(--tt-ember)', borderRadius: '0 2px 2px 0', boxShadow: '0 0 8px rgba(255,106,44,0.4)' }} />
      <div style={{
        width: 46, height: 46, borderRadius: 10,
        background: 'var(--tt-bg-3)',
        border: '1px solid var(--tt-line)', flex: '0 0 auto'
      }}>
        <svg width="46" height="46" viewBox="0 0 40 40">
          <g fill="none" stroke="#2a3038" strokeWidth="0.4">
            <path d="M0,18 Q12,12 20,18 T40,22" />
            <path d="M0,28 Q12,22 20,28 T40,30" />
          </g>
          <path d={paths[pathIdx]} stroke="#ff6a2c" strokeWidth="1.8" fill="none" strokeLinecap="round" />
        </svg>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '800 14px var(--tt-font)', color: 'var(--tt-text)' }}>{name}</div>
        <div style={{ font: '600 10.5px var(--tt-mono)', color: 'var(--tt-text-3)', marginTop: 3 }}>{date} · {dur}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="num" style={{ font: '800 13px var(--tt-mono)', color: 'var(--tt-text)' }}>{dist}</div>
        <div className="num" style={{ font: '700 10.5px var(--tt-mono)', color: 'var(--tt-ember)', marginTop: 3 }}>{gain} m</div>
      </div>
    </div>);

}

window.ScreenStats = ScreenStats;
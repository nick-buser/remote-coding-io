// iOS native screens for tmux-agent — focused, single-purpose views with a bottom tab bar.
// Each screen is sized to fit inside an IOSDevice frame (390 wide content area).

// ─── Tokens ─────────────────────────────────────────────────────────────────
const IOS = {
  bg: '#F2F2F7', // grouped bg
  bgDark: '#000',
  card: '#FFFFFF',
  cardDark: '#1C1C1E',
  fg: '#000',
  fgDark: '#FFF',
  fg2: 'rgba(60,60,67,0.6)',
  fg2Dark: 'rgba(235,235,245,0.6)',
  fg3: 'rgba(60,60,67,0.3)',
  sep: 'rgba(60,60,67,0.12)',
  sepDark: 'rgba(84,84,88,0.65)',
  blue: '#007AFF',
  green: '#34C759',
  orange: '#FF9500',
  red: '#FF3B30',
  yellow: '#FFCC00',
  ui: '-apple-system, "SF Pro Text", system-ui, sans-serif',
  display: '-apple-system, "SF Pro Display", system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace'
};

const ACCENT = {
  iris: 'oklch(60% 0.18 280)',
  amber: 'oklch(70% 0.16 60)',
  mint: 'oklch(64% 0.14 165)',
  rose: 'oklch(64% 0.18 15)',
  slate: 'oklch(58% 0.02 260)'
};

// ─── Tab bar (iOS 17/26 style with Liquid Glass feel) ──────────────────────
function IOSTabBar({ active = 'inbox', accent = 'iris' }) {
  const tabs = [
  { id: 'inbox', label: 'Inbox', icon: TabIcons.inbox, badge: 3 },
  { id: 'projects', label: 'Projects', icon: TabIcons.projects },
  { id: 'roadmap', label: 'Roadmap', icon: TabIcons.roadmap },
  { id: 'sessions', label: 'Sessions', icon: TabIcons.sessions, badge: 4 },
  { id: 'you', label: 'You', icon: TabIcons.you }];

  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 22, paddingTop: 6,
      background: 'rgba(249,249,249,0.86)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderTop: '0.5px solid rgba(60,60,67,0.18)',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-around',
      zIndex: 10
    }}>
      {tabs.map((t) => {
        const isActive = t.id === active;
        const color = isActive ? ACCENT[accent] : 'rgba(60,60,67,0.6)';
        return (
          <div key={t.id} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            gap: 4, padding: '4px 0', minWidth: 56, position: 'relative'
          }}>
            <div style={{ position: 'relative' }}>
              <t.icon color={color} active={isActive} />
              {t.badge &&
              <div style={{
                position: 'absolute', top: -3, right: -10,
                background: IOS.red, color: '#fff',
                fontFamily: IOS.ui, fontSize: 11, fontWeight: 600,
                minWidth: 16, height: 16, padding: '0 4px',
                borderRadius: 8, display: 'flex',
                alignItems: 'center', justifyContent: 'center',
                border: '1.5px solid rgba(249,249,249,0.95)'
              }}>{t.badge}</div>
              }
            </div>
            <div style={{
              fontFamily: IOS.ui, fontSize: 10, fontWeight: 500,
              color, letterSpacing: 0.1
            }}>{t.label}</div>
          </div>);

      })}
    </div>);

}

const TabIcons = {
  inbox: ({ color, active }) =>
  <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
      <path d="M5 5h16l-2.5 9H7.5L5 5z" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity="0.18" strokeLinejoin="round" />
      <path d="M3 14h6l1.5 2.5h5L17 14h6v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5z" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 1 : 0.12} strokeLinejoin="round" />
    </svg>,

  projects: ({ color, active }) =>
  <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
      <rect x="4" y="6" width="8" height="14" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0} />
      <rect x="14" y="6" width="8" height="6.5" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.5 : 0} />
      <rect x="14" y="14.5" width="8" height="5.5" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.3 : 0} />
    </svg>,

  roadmap: ({ color, active }) =>
  <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
      <rect x="3.5" y="6" width="11" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0} />
      <rect x="7" y="11.2" width="14" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.6 : 0} />
      <rect x="5" y="16.4" width="10" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.35 : 0} />
    </svg>,

  sessions: ({ color, active }) =>
  <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
      <rect x="3" y="5" width="20" height="16" rx="2.5" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.18 : 0} />
      <path d="M7 10l3 3-3 3M12 16h6" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>,

  you: ({ color, active }) =>
  <svg width="26" height="26" viewBox="0 0 26 26" fill="none">
      <circle cx="13" cy="9.5" r="4" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0} />
      <path d="M4.5 22c1.5-4.5 5-7 8.5-7s7 2.5 8.5 7" stroke={color} strokeWidth="1.6" strokeLinecap="round" fill={active ? color : 'none'} fillOpacity={active ? 0.4 : 0} />
    </svg>

};

// ─── Status bar (compact, light) ───────────────────────────────────────────
function StatusBar({ time = '9:41', dark = false }) {
  const c = dark ? '#fff' : '#000';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 32px 6px', height: 47, boxSizing: 'border-box',
      position: 'relative', zIndex: 20
    }}>
      <span style={{ fontFamily: IOS.display, fontSize: 17, fontWeight: 600, color: c, letterSpacing: -0.2 }}>{time}</span>
      <div style={{ width: 120, height: 36, background: '#000', borderRadius: 20 }} />
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="18" height="11" viewBox="0 0 18 11"><rect x="0" y="6.5" width="3" height="4.5" rx="0.7" fill={c} /><rect x="4.5" y="4.5" width="3" height="6.5" rx="0.7" fill={c} /><rect x="9" y="2" width="3" height="9" rx="0.7" fill={c} /><rect x="13.5" y="0" width="3" height="11" rx="0.7" fill={c} /></svg>
        <svg width="16" height="11" viewBox="0 0 17 12"><path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={c} /><path d="M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z" fill={c} /><circle cx="8.5" cy="10.5" r="1.5" fill={c} /></svg>
        <svg width="25" height="12" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} strokeOpacity="0.35" fill="none" /><rect x="2" y="2" width="17" height="9" rx="2" fill={c} /><path d="M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z" fill={c} fillOpacity="0.4" /></svg>
      </div>
    </div>);

}

// ─── Nav header (large title, iOS 17 style) ────────────────────────────────
function NavHeader({ title, subtitle, leading, trailing, accent = 'iris', large = true }) {
  return (
    <div style={{ padding: '4px 16px 6px', position: 'relative', zIndex: 5 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 32 }}>
        <div style={{ color: ACCENT[accent], fontFamily: IOS.ui, fontSize: 17, fontWeight: 400, display: 'flex', alignItems: 'center', gap: 4 }}>
          {leading}
        </div>
        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          {trailing}
        </div>
      </div>
      {large &&
      <div style={{ paddingTop: 4 }}>
          <div style={{
          fontFamily: IOS.display, fontSize: 34, fontWeight: 700,
          letterSpacing: -0.4, lineHeight: '41px', color: IOS.fg
        }}>{title}</div>
          {subtitle &&
        <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg2, marginTop: 2 }}>{subtitle}</div>
        }
        </div>
      }
    </div>);

}

function BackChevron({ accent = 'iris', label = 'Back' }) {
  return (
    <>
      <svg width="11" height="18" viewBox="0 0 11 18" fill="none"><path d="M9 1L1.5 9 9 17" stroke={ACCENT[accent]} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
      <span style={{ marginLeft: 2 }}>{label}</span>
    </>);

}

// ─── Reusable: pip, status dot ─────────────────────────────────────────────
function Pip({ accent = 'iris', size = 10, radius = 3 }) {
  return <span style={{ width: size, height: size, borderRadius: radius, background: ACCENT[accent], display: 'inline-block', flexShrink: 0 }} />;
}

function StatusDot({ state }) {
  const map = {
    active: { c: IOS.green, pulse: true },
    'awaiting-input': { c: IOS.orange, pulse: true },
    idle: { c: 'rgba(60,60,67,0.4)', pulse: false }
  };
  const s = map[state] || map.idle;
  return (
    <span style={{
      width: 8, height: 8, borderRadius: 4, background: s.c, display: 'inline-block',
      boxShadow: s.pulse ? `0 0 0 3px ${s.c}33` : 'none'
    }} />);

}

function StatusGlyph({ status, size = 14 }) {
  // iOS-circle status glyph for tickets/features
  const s = size;
  if (status === 'shipped' || status === 'done') {
    return <div style={{ width: s, height: s, borderRadius: s / 2, background: IOS.green, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: s * 0.6, fontWeight: 800 }}>✓</div>;
  }
  if (status === 'review') {
    return <div style={{ width: s, height: s, borderRadius: s / 2, border: `1.6px solid ${ACCENT.iris}`, background: ACCENT.iris + '33' }} />;
  }
  if (status === 'doing' || status === 'in-progress') {
    return <div style={{ width: s, height: s, borderRadius: s / 2, border: `1.6px solid ${IOS.orange}`, background: `conic-gradient(${IOS.orange} 0 60%, transparent 60%)` }} />;
  }
  if (status === 'planned') {
    return <div style={{ width: s, height: s, borderRadius: s / 2, border: `1.6px dashed ${IOS.fg3}` }} />;
  }
  return <div style={{ width: s, height: s, borderRadius: s / 2, border: `1.6px solid ${IOS.fg3}` }} />;
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 1 — INBOX (the home screen — agent activity that needs you)
// ────────────────────────────────────────────────────────────────────────────
function InboxScreen({ accent = 'iris' }) {
  // Curated from ACTIVITY: questions, reviews, decisions, recent work
  const needsAttention = [
  { kind: 'question', actor: 'session-07', target: 'TMX-0050', project: 'tmux-agent', accent: 'iris',
    summary: 'Use unified diff or split? Defaulting to split.', when: '2h' },
  { kind: 'review', actor: 'session-07', target: 'TMX-0050', project: 'tmux-agent', accent: 'iris',
    summary: 'Diff viewer ready for review · +412/−37 across 9 files', when: '32m' },
  { kind: 'review', actor: 'session-04', target: 'TMX-0044', project: 'tmux-agent', accent: 'iris',
    summary: 'Per-pane status badge stream — checklist 3/3', when: '1h' }];

  const recent = [
  { kind: 'commit', actor: 'session-04', target: 'TMX-0042', project: 'tmux-agent', accent: 'iris',
    summary: 'pushed 3 commits — pane registry skeleton + tests', when: '12m' },
  { kind: 'decision', actor: 'session-05', target: 'FEAT-019', project: 'tmux-agent', accent: 'iris',
    summary: 'use slug+sha as bundle key, not branch', when: '1h' },
  { kind: 'test', actor: 'session-04', target: 'TMX-0043', project: 'tmux-agent', accent: 'iris',
    summary: 'go test ./… — 142 passed, 0 failed', when: '3h' }];


  return (
    <Screen>
      <NavHeader
        title="Inbox"
        subtitle="3 need you · 4 sessions live"
        accent={accent}
        leading={<span style={{ fontWeight: 600 }}>tmux-agent</span>}
        trailing={<>
          <NavIcon name="filter" />
          <NavIcon name="compose" accent={accent} />
        </>} />
      

      {/* Filter chips */}
      <ScrollChips items={[
      { label: 'All', active: true, count: 7 },
      { label: 'Questions', count: 1 },
      { label: 'Reviews', count: 2 },
      { label: 'Decisions', count: 1 },
      { label: 'Mentions' }]
      } accent={accent} />

      {/* Needs attention */}
      <SectionHeader>Needs you</SectionHeader>
      <Card>
        {needsAttention.map((it, i) =>
        <InboxRow key={i} item={it} isLast={i === needsAttention.length - 1} accent={accent} />
        )}
      </Card>

      <SectionHeader>Earlier today</SectionHeader>
      <Card>
        {recent.map((it, i) =>
        <InboxRow key={i} item={it} isLast={i === recent.length - 1} accent={accent} />
        )}
      </Card>

      <Spacer h={120} />
    </Screen>);

}

function InboxRow({ item, isLast, accent }) {
  const kindMeta = {
    question: { icon: '?', bg: IOS.orange, label: 'Question' },
    review: { icon: '◐', bg: ACCENT.iris, label: 'Review' },
    commit: { icon: '↑', bg: IOS.green, label: 'Commit' },
    decision: { icon: '◆', bg: ACCENT.mint, label: 'Decision' },
    test: { icon: '✓', bg: 'rgba(60,60,67,0.4)', label: 'Tests' },
    doc: { icon: '✎', bg: ACCENT.amber, label: 'Doc' }
  }[item.kind];
  return (
    <div style={{
      display: 'flex', gap: 12, padding: '12px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: 8, background: kindMeta.bg,
        color: '#fff', fontFamily: IOS.ui, fontWeight: 600, fontSize: 16,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0
      }}>{kindMeta.icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 2 }}>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: ACCENT[item.accent], fontWeight: 500 }}>{item.target}</span>
          <span style={{ fontFamily: IOS.ui, fontSize: 12, color: IOS.fg2 }}>· {item.actor}</span>
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{item.when}</span>
        </div>
        <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg, lineHeight: 1.35 }}>{item.summary}</div>
        {item.kind === 'question' &&
        <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <PillBtn accent={accent} primary>Reply</PillBtn>
            <PillBtn>Open pane</PillBtn>
          </div>
        }
        {item.kind === 'review' &&
        <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
            <PillBtn accent={accent} primary>Approve</PillBtn>
            <PillBtn>Open diff</PillBtn>
          </div>
        }
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 2 — PROJECTS (workspace root)
// ────────────────────────────────────────────────────────────────────────────
function ProjectsScreen({ accent = 'iris' }) {
  const pinned = window.PROJECTS.filter((p) => p.pinned);
  const others = window.PROJECTS.filter((p) => !p.pinned);
  return (
    <Screen>
      <NavHeader
        title="Projects"
        subtitle="4 projects · 4 live sessions"
        accent={accent}
        leading={<span />}
        trailing={<><NavIcon name="search" /><NavIcon name="plus" accent={accent} /></>} />
      

      <SectionHeader>Pinned</SectionHeader>
      <Card>
        {pinned.map((p, i) =>
        <ProjectRow key={p.id} project={p} isLast={i === pinned.length - 1} />
        )}
      </Card>

      <SectionHeader>All projects</SectionHeader>
      <Card>
        {others.map((p, i) =>
        <ProjectRow key={p.id} project={p} isLast={i === others.length - 1} />
        )}
      </Card>

      <Spacer h={120} />
    </Screen>);

}

function ProjectRow({ project, isLast }) {
  const statusMap = {
    active: { c: IOS.green, label: 'Active' },
    maintenance: { c: IOS.orange, label: 'Maint.' },
    paused: { c: 'rgba(60,60,67,0.4)', label: 'Paused' }
  };
  const st = statusMap[project.status];
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <div style={{
        width: 38, height: 38, borderRadius: 9,
        background: ACCENT[project.accent], color: '#fff',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: IOS.display, fontSize: 18, fontWeight: 600, flexShrink: 0
      }}>{project.icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontFamily: IOS.ui, fontSize: 16, fontWeight: 600, color: IOS.fg }}>{project.name}</span>
          {project.pinned && <svg width="10" height="10" viewBox="0 0 12 12"><path d="M6 1l1.5 3.5L11 5l-2.5 2L9 10.5 6 8.5 3 10.5 3.5 7 1 5l3.5-.5L6 1z" fill={IOS.orange} /></svg>}
        </div>
        <div style={{ fontFamily: IOS.ui, fontSize: 13, color: IOS.fg2, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{project.tagline}</div>
        <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
          <MetaPill icon="●" iconColor={st.c} label={st.label} />
          {project.liveSessions > 0 && <MetaPill icon="◧" label={`${project.liveSessions} live`} />}
          <MetaPill label={`${project.activeFeatures}/${project.totalFeatures} features`} />
        </div>
      </div>
      <Chevron />
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 3 — PROJECT DETAIL (drilled into tmux-agent)
// ────────────────────────────────────────────────────────────────────────────
function ProjectDetailScreen({ accent = 'iris' }) {
  const project = window.PROJECTS[0]; // tmux-agent
  const features = window.FEATURES.filter((f) => f.project === project.id);
  const inProgress = features.filter((f) => f.status === 'in-progress');
  const review = features.filter((f) => f.status === 'review');
  const planned = features.filter((f) => f.status === 'planned');
  const shipped = features.filter((f) => f.status === 'shipped');
  return (
    <Screen>
      <NavHeader
        title={project.name}
        subtitle={project.tagline}
        accent={accent}
        large
        leading={<BackChevron accent={accent} label="Projects" />}
        trailing={<><NavIcon name="search" /><NavIcon name="dots" /></>} />
      

      {/* Stats strip */}
      <div style={{ padding: '4px 16px 12px' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
          background: '#fff', borderRadius: 14, overflow: 'hidden'
        }}>
          {[
          { n: project.activeFeatures, l: 'Active' },
          { n: project.openTickets, l: 'Open' },
          { n: project.liveSessions, l: 'Live' },
          { n: project.totalFeatures, l: 'Total' }].
          map((s, i, arr) =>
          <div key={i} style={{
            padding: '10px 8px', textAlign: 'center',
            borderRight: i < arr.length - 1 ? `0.5px solid ${IOS.sep}` : 'none'
          }}>
              <div style={{ fontFamily: IOS.display, fontSize: 22, fontWeight: 600, color: IOS.fg }}>{s.n}</div>
              <div style={{ fontFamily: IOS.ui, fontSize: 11, color: IOS.fg2, textTransform: 'uppercase', letterSpacing: 0.4 }}>{s.l}</div>
            </div>
          )}
        </div>
      </div>

      {/* Segmented control */}
      <div style={{ padding: '0 16px 12px' }}>
        <SegControl items={['Features', 'Tickets', 'Docs', 'Sessions']} active={0} />
      </div>

      {inProgress.length > 0 && <>
        <SectionHeader>In progress</SectionHeader>
        <Card>{inProgress.map((f, i) => <FeatureRow key={f.id} feature={f} isLast={i === inProgress.length - 1} />)}</Card>
      </>}
      {review.length > 0 && <>
        <SectionHeader>In review</SectionHeader>
        <Card>{review.map((f, i) => <FeatureRow key={f.id} feature={f} isLast={i === review.length - 1} />)}</Card>
      </>}
      {planned.length > 0 && <>
        <SectionHeader>Planned</SectionHeader>
        <Card>{planned.map((f, i) => <FeatureRow key={f.id} feature={f} isLast={i === planned.length - 1} />)}</Card>
      </>}
      {shipped.length > 0 && <>
        <SectionHeader>Shipped</SectionHeader>
        <Card>{shipped.map((f, i) => <FeatureRow key={f.id} feature={f} isLast={i === shipped.length - 1} />)}</Card>
      </>}
      <Spacer h={120} />
    </Screen>);

}

function FeatureRow({ feature, isLast }) {
  const pct = Math.round(feature.progress * 100);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '11px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <StatusGlyph status={feature.status} size={16} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{feature.id}</span>
          <Pip accent={feature.accent} size={6} radius={2} />
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{feature.milestone}</span>
        </div>
        <div style={{ fontFamily: IOS.ui, fontSize: 15, color: IOS.fg, lineHeight: 1.3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{feature.title}</div>
        <div style={{ display: 'flex', gap: 8, marginTop: 6, alignItems: 'center' }}>
          <div style={{ width: 60, height: 4, background: 'rgba(60,60,67,0.12)', borderRadius: 2, overflow: 'hidden' }}>
            <div style={{ width: pct + '%', height: '100%', background: ACCENT[feature.accent] }} />
          </div>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{feature.ticketsDone}/{feature.tickets}</span>
          {feature.sessions > 0 && <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.green }}>● {feature.sessions} live</span>}
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{feature.target}</span>
        </div>
      </div>
      <Chevron />
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 4 — FEATURE DETAIL (drilled into a feature)
// ────────────────────────────────────────────────────────────────────────────
function FeatureDetailScreen({ accent = 'iris' }) {
  const f = window.FEATURES.find((x) => x.id === 'FEAT-018');
  const tickets = window.TICKETS.filter((t) => t.feature === f.id);
  return (
    <Screen>
      <NavHeader
        title=""
        accent={accent}
        large={false}
        leading={<BackChevron accent={accent} label="tmux-agent" />}
        trailing={<><NavIcon name="share" /><NavIcon name="dots" /></>} />
      

      {/* Feature hero */}
      <div style={{ padding: '0 16px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <Pip accent={f.accent} size={10} radius={3} />
          <span style={{ fontFamily: IOS.mono, fontSize: 12, color: IOS.fg2 }}>{f.id}</span>
          <span style={{
            marginLeft: 4, fontFamily: IOS.ui, fontSize: 11, fontWeight: 600,
            padding: '2px 7px', borderRadius: 6,
            background: IOS.orange + '25', color: IOS.orange, textTransform: 'uppercase', letterSpacing: 0.5
          }}>In progress</span>
        </div>
        <div style={{ fontFamily: IOS.display, fontSize: 26, fontWeight: 700, letterSpacing: -0.4, lineHeight: 1.18, color: IOS.fg, marginBottom: 6 }}>{f.title}</div>
        <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg2, lineHeight: 1.45 }}>{f.vision}</div>
      </div>

      {/* Progress card */}
      <Card>
        <div style={{ padding: '12px 16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <span style={{ fontFamily: IOS.ui, fontSize: 13, color: IOS.fg2 }}>{f.milestone}</span>
            <span style={{ fontFamily: IOS.mono, fontSize: 13, color: IOS.fg, fontWeight: 600 }}>{Math.round(f.progress * 100)}%</span>
          </div>
          <div style={{ height: 6, background: 'rgba(60,60,67,0.12)', borderRadius: 3, overflow: 'hidden' }}>
            <div style={{ width: f.progress * 100 + '%', height: '100%', background: ACCENT[f.accent] }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: IOS.ui, fontSize: 12, color: IOS.fg2, marginTop: 8 }}>
            <span>{f.ticketsDone} of {f.tickets} tickets · {f.sessions} live</span>
            <span style={{ fontFamily: IOS.mono }}>Target {f.target}</span>
          </div>
        </div>
      </Card>

      {/* Tab bar */}
      <div style={{ padding: '14px 16px 10px' }}>
        <SegControl items={['Tickets', 'PRD', 'Decisions', 'Sessions']} active={0} />
      </div>

      {/* Tickets list */}
      <Card>
        {tickets.slice(0, 5).map((t, i) =>
        <TicketRow key={t.id} ticket={t} isLast={i === Math.min(tickets.length, 5) - 1} accent={accent} />
        )}
      </Card>

      <div style={{ padding: '10px 16px 0', display: 'flex', gap: 8 }}>
        <PillBtn accent={accent} primary wide>＋ New ticket</PillBtn>
        <PillBtn wide>Spawn session</PillBtn>
      </div>

      <Spacer h={120} />
    </Screen>);

}

function TicketRow({ ticket, isLast, accent }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '10px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <StatusGlyph status={ticket.status} size={14} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 2 }}>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{ticket.id}</span>
          {ticket.sessions > 0 && <span style={{ fontFamily: IOS.mono, fontSize: 10.5, color: IOS.green }}>● live</span>}
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 10.5, color: IOS.fg2 }}>{ticket.updated}</span>
        </div>
        <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{ticket.title}</div>
        <div style={{ display: 'flex', gap: 8, marginTop: 4, alignItems: 'center' }}>
          {/* Mini criteria dots */}
          <div style={{ display: 'flex', gap: 3 }}>
            {Array.from({ length: ticket.criteria }).map((_, i) =>
            <div key={i} style={{
              width: 8, height: 4, borderRadius: 2,
              background: i < ticket.criteriaDone ? IOS.green : 'rgba(60,60,67,0.18)'
            }} />
            )}
          </div>
          <span style={{ fontFamily: IOS.mono, fontSize: 10.5, color: IOS.fg2 }}>{ticket.criteriaDone}/{ticket.criteria}</span>
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 10, color: IOS.fg3, padding: '1px 5px', border: `0.5px solid ${IOS.sep}`, borderRadius: 4 }}>{ticket.estimate}</span>
        </div>
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 5 — ROADMAP (vertical milestone strips with feature cards)
// ────────────────────────────────────────────────────────────────────────────
function RoadmapScreen({ accent = 'iris' }) {
  return (
    <Screen>
      <NavHeader
        title="Roadmap"
        subtitle="All projects · 12 weeks"
        accent={accent}
        leading={<span />}
        trailing={<><NavIcon name="calendar" /><NavIcon name="filter" /></>} />
      

      {/* Project filter chips */}
      <ScrollChips items={[
      { label: 'All', active: true },
      { label: 'tmux-agent', dot: 'iris' },
      { label: 'sift', dot: 'amber' },
      { label: 'paper-cuts', dot: 'mint' }]
      } accent={accent} />

      {/* Vertical timeline */}
      <div style={{ padding: '4px 16px 0' }}>
        {window.MILESTONES.map((m, idx) => {
          const feats = window.FEATURES.filter((f) => f.milestone.startsWith(m.id));
          const stateColor = m.state === 'active' ? ACCENT[accent] : m.state === 'shipped' ? IOS.green : 'rgba(60,60,67,0.4)';
          return (
            <div key={m.id} style={{ display: 'flex', gap: 12, paddingBottom: 18 }}>
              {/* timeline rail */}
              <div style={{ width: 12, position: 'relative', flexShrink: 0 }}>
                <div style={{ position: 'absolute', left: 5, top: 8, bottom: -18, width: 2, background: 'rgba(60,60,67,0.12)' }} />
                <div style={{
                  position: 'absolute', left: 0, top: 6, width: 12, height: 12, borderRadius: 6,
                  background: stateColor,
                  boxShadow: m.state === 'active' ? `0 0 0 4px ${stateColor}33` : 'none'
                }} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 6 }}>
                  <span style={{ fontFamily: IOS.display, fontSize: 17, fontWeight: 600, color: IOS.fg }}>{m.label}</span>
                </div>
                <div style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2, marginBottom: 8 }}>{m.start} → {m.end}</div>
                {feats.length === 0 ?
                <div style={{ fontFamily: IOS.ui, fontSize: 13, color: IOS.fg3, fontStyle: 'italic', padding: 8 }}>No features yet</div> :

                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {feats.map((f) =>
                  <RoadmapFeatureCard key={f.id} feature={f} />
                  )}
                  </div>
                }
              </div>
            </div>);

        })}
      </div>

      <Spacer h={120} />
    </Screen>);

}

function RoadmapFeatureCard({ feature }) {
  const pct = Math.round(feature.progress * 100);
  return (
    <div style={{
      background: '#fff', borderRadius: 12, padding: '10px 12px',
      borderLeft: `3px solid ${ACCENT[feature.accent]}`
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <StatusGlyph status={feature.status} size={12} />
        <span style={{ fontFamily: IOS.mono, fontSize: 10.5, color: IOS.fg2 }}>{feature.id}</span>
        <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 10.5, color: IOS.fg2 }}>{feature.target}</span>
      </div>
      <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg, marginBottom: 6, lineHeight: 1.3 }}>{feature.title}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{ flex: 1, height: 3, background: 'rgba(60,60,67,0.12)', borderRadius: 2, overflow: 'hidden' }}>
          <div style={{ width: pct + '%', height: '100%', background: ACCENT[feature.accent] }} />
        </div>
        <span style={{ fontFamily: IOS.mono, fontSize: 10.5, color: IOS.fg2 }}>{pct}%</span>
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 6 — SESSIONS LIST (live agent panes)
// ────────────────────────────────────────────────────────────────────────────
function SessionsListScreen({ accent = 'iris' }) {
  const sessions = window.SESSIONS;
  return (
    <Screen>
      <NavHeader
        title="Sessions"
        subtitle="4 live · 1 awaiting input"
        accent={accent}
        leading={<span />}
        trailing={<><NavIcon name="search" /><NavIcon name="plus" accent={accent} /></>} />
      

      <ScrollChips items={[
      { label: 'All', active: true, count: 4 },
      { label: 'Active', count: 2, dot: 'green' },
      { label: 'Awaiting', count: 1, dot: 'orange' },
      { label: 'Idle', count: 1 }]
      } accent={accent} />

      <SectionHeader>Awaiting input</SectionHeader>
      <Card>
        <SessionRow session={sessions[1]} isLast accent={accent} />
      </Card>

      <SectionHeader>Active</SectionHeader>
      <Card>
        <SessionRow session={sessions[2]} accent={accent} />
        <SessionRow session={sessions[3]} isLast accent={accent} />
      </Card>

      <SectionHeader>Idle</SectionHeader>
      <Card>
        <SessionRow session={sessions[0]} isLast accent={accent} />
      </Card>

      <Spacer h={120} />
    </Screen>);

}

function SessionRow({ session, isLast, accent }) {
  const ticket = window.TICKETS.find((t) => t.id === session.ticket);
  const feature = window.FEATURES.find((f) => f.id === session.feature);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <StatusDot state={session.state} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 2 }}>
          <span style={{ fontFamily: IOS.mono, fontSize: 13, color: IOS.fg, fontWeight: 600 }}>{session.id}</span>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{session.pane}</span>
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{session.uptime}</span>
        </div>
        <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginBottom: 3 }}>
          {ticket && ticket.title}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <Pip accent={feature.accent} size={6} radius={2} />
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>{feature.id} · {ticket && ticket.id}</span>
          <span style={{ marginLeft: 'auto', fontFamily: IOS.mono, fontSize: 11, color: session.cpu > 10 ? IOS.green : IOS.fg2 }}>{session.cpu}% CPU</span>
        </div>
      </div>
      <Chevron />
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 7 — TERMINAL (Runestone-style, single session)
// ────────────────────────────────────────────────────────────────────────────
function TerminalScreen({ accent = 'iris' }) {
  return (
    <div style={{
      width: '100%', height: '100%', background: '#000', position: 'relative',
      display: 'flex', flexDirection: 'column'
    }}>
      <StatusBar dark />
      {/* Top context bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '4px 16px 8px',
        borderBottom: '0.5px solid rgba(255,255,255,0.1)'
      }}>
        <button style={{
          background: 'transparent', border: 'none', color: ACCENT[accent],
          fontFamily: IOS.ui, fontSize: 16, padding: 0,
          display: 'flex', alignItems: 'center', gap: 2
        }}>
          <svg width="11" height="18" viewBox="0 0 11 18" fill="none"><path d="M9 1L1.5 9 9 17" stroke={ACCENT[accent]} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          Sessions
        </button>
        <div style={{ flex: 1, textAlign: 'center', minWidth: 0 }}>
          <div style={{ fontFamily: IOS.ui, fontSize: 14, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>session-07</div>
          <div style={{ fontFamily: IOS.mono, fontSize: 10.5, color: 'rgba(235,235,245,0.5)' }}>tmux-agent · agent:2.0 · 47m</div>
        </div>
        <NavIcon name="dots" dark />
      </div>

      {/* Pane chip switcher */}
      <div style={{ padding: '8px 16px', overflowX: 'auto', whiteSpace: 'nowrap' }}>
        {[
        { id: 'session-04', state: 'idle' },
        { id: 'session-05', state: 'awaiting-input' },
        { id: 'session-07', state: 'active', active: true },
        { id: 'session-08', state: 'active' },
        { id: '+', plus: true }].
        map((p) =>
        <span key={p.id} style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '5px 11px', borderRadius: 999, marginRight: 6,
          background: p.active ? 'rgba(255,255,255,0.14)' : 'rgba(255,255,255,0.05)',
          border: p.active ? `0.5px solid ${ACCENT[accent]}` : '0.5px solid rgba(255,255,255,0.1)',
          fontFamily: IOS.mono, fontSize: 12, color: p.active ? '#fff' : 'rgba(235,235,245,0.7)'
        }}>
            {!p.plus && <StatusDot state={p.state} />}
            {p.id}
          </span>
        )}
      </div>

      {/* Terminal output (Runestone-style) */}
      <div style={{
        flex: 1, padding: '8px 14px',
        fontFamily: IOS.mono, fontSize: 12.5, lineHeight: 1.5,
        color: '#e7e7ea', overflow: 'hidden',
        whiteSpace: 'pre-wrap'
      }}>
{`> ${`pushed 3 commits to feat/tmx-0050-diff-viewer`}
${`  ${'a3f2c19'} chore: tighten gutter spacing`}
${`  ${'b7e1d44'} fix: split-view scroll sync`}
${`  ${'c01af2b'} test: add 12 cases for diff parser`}

`}<span style={{ color: ACCENT[accent] }}>{'agent ›'}</span>{` ran tests on TMX-0050
${`  go test ./diff/... -count=1`}
`}<span style={{ color: IOS.green }}>{`  PASS`}</span>{`  ./diff/parser    [142/142]
`}<span style={{ color: IOS.green }}>{`  PASS`}</span>{`  ./diff/renderer  [38/38]
${`  ok    git.io/tmux-agent/diff  0.218s`}

`}<span style={{ color: IOS.orange }}>{`agent ›`}</span>{` `}<span style={{ color: '#fff' }}>{`Use unified diff or split? Defaulting to split.`}</span>{`
${`        Reply 'unified', 'split', or 'auto'.`}

`}<span style={{ color: ACCENT[accent] }}>▎</span>
      </div>

      {/* Quick keys */}
      <div style={{
        display: 'flex', gap: 6, padding: '6px 12px',
        overflowX: 'auto', whiteSpace: 'nowrap',
        borderTop: '0.5px solid rgba(255,255,255,0.08)',
        background: 'rgba(28,28,30,0.6)'
      }}>
        {['esc', 'tab', '⌃C', '⌃D', '↑', '↓', '←', '→', '⏎'].map((k) =>
        <span key={k} style={{
          display: 'inline-flex', padding: '6px 10px', borderRadius: 6,
          background: 'rgba(255,255,255,0.08)', color: '#fff',
          fontFamily: IOS.mono, fontSize: 13, minWidth: 32, justifyContent: 'center'
        }}>{k}</span>
        )}
      </div>

      {/* Input bar */}
      <div style={{
        display: 'flex', gap: 8, padding: '8px 12px 10px',
        background: '#1c1c1e', borderTop: '0.5px solid rgba(255,255,255,0.08)',
        alignItems: 'center'
      }}>
        <div style={{
          flex: 1, background: '#2c2c2e', borderRadius: 18,
          padding: '8px 14px', fontFamily: IOS.mono, fontSize: 14,
          color: 'rgba(235,235,245,0.4)'
        }}>split</div>
        <button style={{
          width: 34, height: 34, borderRadius: 17, background: ACCENT[accent], border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center'
        }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2 8L14 2L9 14L7 9L2 8Z" fill="#fff" /></svg>
        </button>
      </div>

      {/* iOS keyboard hint area (home indicator) */}
      <div style={{ padding: '8px 0 10px', display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 134, height: 5, background: 'rgba(255,255,255,0.4)', borderRadius: 3 }} />
      </div>
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 8 — DOCS (per-feature)
// ────────────────────────────────────────────────────────────────────────────
function DocsScreen({ accent = 'iris' }) {
  return (
    <Screen>
      <NavHeader
        title=""
        accent={accent}
        large={false}
        leading={<BackChevron accent={accent} label="FEAT-018" />}
        trailing={<><NavIcon name="share" /><NavIcon name="dots" /></>} />
      

      {/* Doc tabs */}
      <div style={{ padding: '0 16px 14px' }}>
        <SegControl items={['PRD', 'Eng design', 'Decisions', 'Notes']} active={0} />
      </div>

      <div style={{ padding: '0 20px' }}>
        <div style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>FEAT-018 · PRD</div>
        <div style={{ fontFamily: IOS.display, fontSize: 26, fontWeight: 700, letterSpacing: -0.4, lineHeight: 1.18, color: IOS.fg, margin: '4px 0 16px' }}>
          Agent pane multiplexer
        </div>

        <DocBlock kind="h2">Problem</DocBlock>
        <DocBlock>
          Running multiple agent sessions today means juggling separate tmux windows.
          Switching context loses scrollback and breaks the mental model of which agent
          is on which ticket.
        </DocBlock>

        <DocBlock kind="callout" accent={accent}>
          <div style={{ fontFamily: IOS.ui, fontSize: 11, fontWeight: 600, color: ACCENT[accent], textTransform: 'uppercase', letterSpacing: 0.4, marginBottom: 4 }}>Goal</div>
          One window, N panes, each bound to a feature's context bundle, with persistent scrollback search and per-pane state badges.
        </DocBlock>

        <DocBlock kind="h2">Acceptance criteria</DocBlock>
        <DocBlock kind="checklist" items={[
        { done: true, text: 'Up to 6 panes per window with named splits' },
        { done: true, text: 'Scrollback persists across detach/reattach' },
        { done: false, text: 'Per-pane state badge: idle, active, awaiting' },
        { done: false, text: 'Scrollback regex search with hit-jump' }]
        } />

        <DocBlock kind="h2">Open questions</DocBlock>
        <DocBlock>
          Should pane layout be saved per-feature or per-workspace? Leaning per-feature
          so resuming a ticket restores the exact split.
        </DocBlock>

        <div style={{ height: 80 }} />
      </div>
    </Screen>);

}

function DocBlock({ kind = 'p', accent, children, items }) {
  if (kind === 'h2') return <div style={{ fontFamily: IOS.display, fontSize: 19, fontWeight: 600, letterSpacing: -0.2, color: IOS.fg, marginTop: 18, marginBottom: 8 }}>{children}</div>;
  if (kind === 'callout') return (
    <div style={{
      background: ACCENT[accent] + '15', borderLeft: `3px solid ${ACCENT[accent]}`,
      padding: '10px 14px', borderRadius: 8, margin: '8px 0',
      fontFamily: IOS.ui, fontSize: 14.5, color: IOS.fg, lineHeight: 1.45
    }}>{children}</div>);

  if (kind === 'checklist') return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, margin: '6px 0' }}>
      {items.map((it, i) =>
      <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <div style={{
          width: 18, height: 18, borderRadius: 4,
          border: it.done ? 'none' : `1.5px solid ${IOS.fg3}`,
          background: it.done ? IOS.green : 'transparent',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1,
          color: '#fff', fontSize: 12, fontWeight: 700
        }}>{it.done && '✓'}</div>
          <div style={{
          fontFamily: IOS.ui, fontSize: 14.5, color: it.done ? IOS.fg2 : IOS.fg, lineHeight: 1.4,
          textDecoration: it.done ? 'line-through' : 'none'
        }}>{it.text}</div>
        </div>
      )}
    </div>);

  return <div style={{ fontFamily: IOS.ui, fontSize: 14.5, color: IOS.fg, lineHeight: 1.5, margin: '4px 0 8px' }}>{children}</div>;
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 9 — REVIEW (diff + checklist on a tiny screen)
// ────────────────────────────────────────────────────────────────────────────
function ReviewScreen({ accent = 'iris' }) {
  return (
    <Screen>
      <NavHeader
        title=""
        accent={accent}
        large={false}
        leading={<BackChevron accent={accent} label="Inbox" />}
        trailing={<NavIcon name="dots" />} />
      
      <div style={{ padding: '0 16px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <span style={{ fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2 }}>TMX-0050</span>
          <span style={{
            fontFamily: IOS.ui, fontSize: 11, fontWeight: 600, padding: '2px 7px', borderRadius: 6,
            background: ACCENT.iris + '25', color: ACCENT.iris, textTransform: 'uppercase', letterSpacing: 0.5
          }}>In review</span>
        </div>
        <div style={{ ...{ fontFamily: IOS.display, fontSize: 22, fontWeight: 700, letterSpacing: -0.3, lineHeight: 1.18, color: IOS.fg }, fontFamily: "-apple-system" }}>Diff viewer component</div>
        <div style={{ fontFamily: IOS.mono, fontSize: 11.5, color: IOS.fg2, marginTop: 4 }}>
          session-07 · feat/tmx-0050-diff-viewer · +412 / −37 · 9 files
        </div>
      </div>

      {/* Sub-tabs */}
      <div style={{ padding: '0 16px 12px' }}>
        <SegControl items={['Diff', 'Checklist 6/6', 'Files']} active={0} />
      </div>

      {/* Diff snippet */}
      <div style={{ margin: '0 16px', background: '#fff', borderRadius: 12, overflow: 'hidden' }}>
        <div style={{
          padding: '8px 12px', borderBottom: `0.5px solid ${IOS.sep}`,
          fontFamily: IOS.mono, fontSize: 11, color: IOS.fg2
        }}>diff/renderer.go · split-view sync</div>
        <pre style={{
          margin: 0, padding: '10px 12px',
          fontFamily: IOS.mono, fontSize: 11.5, lineHeight: 1.55, color: IOS.fg,
          whiteSpace: 'pre', overflowX: 'auto'
        }}>
<span style={{ color: IOS.fg2 }}>{`@@ -88,6 +88,12 @@ func (r *Renderer) Render() {`}{'\n'}</span>
<span style={{ color: IOS.fg2 }}>{`     for i, line := range r.lines {`}{'\n'}</span>
<span style={{ display: 'block', background: '#FFEDED', color: '#A52525' }}>{`-      r.write(line)`}{'\n'}</span>
<span style={{ display: 'block', background: '#E8F8EC', color: '#1F7A2E' }}>{`+      l, r := r.split(line)`}{'\n'}</span>
<span style={{ display: 'block', background: '#E8F8EC', color: '#1F7A2E' }}>{`+      r.writePair(l, r)`}{'\n'}</span>
<span style={{ display: 'block', background: '#E8F8EC', color: '#1F7A2E' }}>{`+      r.syncScroll(i)`}{'\n'}</span>
<span style={{ color: IOS.fg2 }}>{`     }`}{'\n'}</span>
        </pre>
      </div>

      {/* Checklist condensed */}
      <SectionHeader>Acceptance · 6 / 6</SectionHeader>
      <Card>
        {[
        'Side-by-side renders without horizontal scroll lag',
        'Word-level highlight inside changed lines',
        'Scroll syncs across both panes',
        'Collapsible context with `…` markers',
        'Keyboard nav: j/k between hunks',
        'No regression in unified mode'].
        map((c, i, arr) =>
        <div key={i} style={{
          display: 'flex', gap: 10, padding: '10px 16px',
          borderBottom: i === arr.length - 1 ? 'none' : `0.5px solid ${IOS.sep}`
        }}>
            <div style={{
            width: 18, height: 18, borderRadius: 4, background: IOS.green,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 12, fontWeight: 700, flexShrink: 0
          }}>✓</div>
            <div style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg2, textDecoration: 'line-through', lineHeight: 1.35 }}>{c}</div>
          </div>
        )}
      </Card>

      {/* Action bar */}
      <div style={{ padding: '14px 16px 0', display: 'flex', gap: 8 }}>
        <PillBtn wide>Request changes</PillBtn>
        <PillBtn accent={accent} primary wide>Approve & merge</PillBtn>
      </div>
      <Spacer h={120} />
    </Screen>);

}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN 10 — YOU (workspace, accent, settings)
// ────────────────────────────────────────────────────────────────────────────
function YouScreen({ accent = 'iris' }) {
  return (
    <Screen>
      <NavHeader title="You" accent={accent} leading={<span />} trailing={<NavIcon name="dots" />} />

      {/* Workspace card */}
      <div style={{ padding: '0 16px 14px' }}>
        <div style={{
          background: '#fff', borderRadius: 14, padding: '14px 16px',
          display: 'flex', alignItems: 'center', gap: 12
        }}>
          <div style={{
            width: 48, height: 48, borderRadius: 12, background: ACCENT[accent],
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontFamily: IOS.display, fontSize: 22, fontWeight: 600
          }}>N</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: IOS.ui, fontSize: 16, fontWeight: 600, color: IOS.fg }}>Nick Buser</div>
            <div style={{ fontFamily: IOS.mono, fontSize: 12, color: IOS.fg2 }}>4 projects · 15 features · 4 sessions</div>
          </div>
          <Chevron />
        </div>
      </div>

      <SectionHeader>Workspace</SectionHeader>
      <Card>
        <SettingRow icon={IOS.blue} iconGlyph="◎" title="Default project" detail="tmux-agent" />
        <SettingRow icon={IOS.orange} iconGlyph="!" title="Notifications" detail="Reviews & questions" />
        <SettingRow icon={IOS.green} iconGlyph="◧" title="tmux server" detail="Connected" isLast />
      </Card>

      <SectionHeader>Appearance</SectionHeader>
      <Card>
        <div style={{ padding: '10px 16px', borderBottom: `0.5px solid ${IOS.sep}` }}>
          <div style={{ fontFamily: IOS.ui, fontSize: 16, color: IOS.fg, marginBottom: 8 }}>Accent color</div>
          <div style={{ display: 'flex', gap: 10 }}>
            {Object.keys(ACCENT).map((a) =>
            <div key={a} style={{
              width: 30, height: 30, borderRadius: 15, background: ACCENT[a],
              border: a === accent ? `2.5px solid ${IOS.fg}` : 'none',
              boxShadow: a === accent ? `0 0 0 2px #fff inset` : 'none'
            }} />
            )}
          </div>
        </div>
        <SettingRow icon="rgba(60,60,67,0.4)" iconGlyph="A" title="Text size" detail="Default" />
        <SettingRow icon={IOS.fg} iconGlyph="◐" title="Appearance" detail="Light" isLast />
      </Card>

      <SectionHeader>Agent</SectionHeader>
      <Card>
        <SettingRow icon={ACCENT.iris} iconGlyph="◇" title="Default model" detail="Claude Sonnet" />
        <SettingRow icon={ACCENT.amber} iconGlyph="◧" title="Pane budget" detail="6 per window" />
        <SettingRow icon={ACCENT.mint} iconGlyph="✎" title="Context bundle" detail="PRD + Decisions" isLast />
      </Card>

      <Spacer h={120} />
    </Screen>);

}

function SettingRow({ icon, iconGlyph, title, detail, isLast }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '11px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${IOS.sep}`
    }}>
      <div style={{
        width: 30, height: 30, borderRadius: 7, background: icon,
        color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: IOS.ui, fontWeight: 600, fontSize: 14, flexShrink: 0
      }}>{iconGlyph}</div>
      <div style={{ flex: 1, fontFamily: IOS.ui, fontSize: 16, color: IOS.fg }}>{title}</div>
      {detail && <span style={{ fontFamily: IOS.ui, fontSize: 14, color: IOS.fg2, marginRight: 4 }}>{detail}</span>}
      <Chevron />
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ────────────────────────────────────────────────────────────────────────────
function Screen({ children }) {
  return (
    <div style={{
      width: '100%', height: '100%', background: IOS.bg,
      overflowY: 'auto', position: 'relative',
      WebkitFontSmoothing: 'antialiased'
    }}>
      <StatusBar />
      {children}
    </div>);

}

function Card({ children }) {
  return (
    <div style={{ margin: '0 16px 14px' }}>
      <div style={{ background: '#fff', borderRadius: 14, overflow: 'hidden' }}>{children}</div>
    </div>);

}

function SectionHeader({ children }) {
  return (
    <div style={{
      padding: '6px 32px 6px', fontFamily: IOS.ui, fontSize: 13,
      color: IOS.fg2, textTransform: 'uppercase', letterSpacing: 0.4, fontWeight: 500
    }}>{children}</div>);

}

function Spacer({ h }) {return <div style={{ height: h }} />;}

function Chevron() {
  return (
    <svg width="7" height="12" viewBox="0 0 7 12" style={{ flexShrink: 0, marginLeft: 4 }}>
      <path d="M1 1l5 5-5 5" stroke="rgba(60,60,67,0.3)" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </svg>);

}

function NavIcon({ name, accent, dark }) {
  const c = dark ? '#fff' : '#000';
  const acc = accent ? ACCENT[accent] : c;
  if (name === 'plus') return <svg width="22" height="22" viewBox="0 0 22 22"><path d="M11 4v14M4 11h14" stroke={acc} strokeWidth="2" strokeLinecap="round" /></svg>;
  if (name === 'compose') return <svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M3 18l3.5-1L17 6.5l-2.5-2.5L4 14.5 3 18z" stroke={acc} strokeWidth="1.6" strokeLinejoin="round" /><path d="M14.5 7L16 8.5" stroke={acc} strokeWidth="1.6" /></svg>;
  if (name === 'search') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><circle cx="9" cy="9" r="6" stroke={c} strokeWidth="1.8" /><path d="M14 14l4 4" stroke={c} strokeWidth="1.8" strokeLinecap="round" /></svg>;
  if (name === 'filter') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3 5h14M5 10h10M8 15h4" stroke={c} strokeWidth="1.8" strokeLinecap="round" /></svg>;
  if (name === 'dots') return <svg width="22" height="6" viewBox="0 0 22 6"><circle cx="3" cy="3" r="2.5" fill={c} /><circle cx="11" cy="3" r="2.5" fill={c} /><circle cx="19" cy="3" r="2.5" fill={c} /></svg>;
  if (name === 'share') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M10 13V3M6 7l4-4 4 4" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" /><path d="M3 12v4a2 2 0 002 2h10a2 2 0 002-2v-4" stroke={c} strokeWidth="1.8" strokeLinecap="round" /></svg>;
  if (name === 'calendar') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="3" y="4" width="14" height="13" rx="1.6" stroke={c} strokeWidth="1.6" /><path d="M3 8h14M7 2v4M13 2v4" stroke={c} strokeWidth="1.6" strokeLinecap="round" /></svg>;
  return null;
}

function MetaPill({ icon, iconColor, label }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      fontFamily: IOS.ui, fontSize: 11.5, color: IOS.fg2
    }}>
      {icon && <span style={{ color: iconColor || IOS.fg2, fontSize: 9 }}>{icon}</span>}
      {label}
    </span>);

}

function PillBtn({ children, primary, wide, accent = 'iris' }) {
  return (
    <button style={{
      flex: wide ? 1 : 'none',
      padding: '9px 14px', borderRadius: 10,
      background: primary ? ACCENT[accent] : 'rgba(120,120,128,0.16)',
      color: primary ? '#fff' : IOS.fg,
      border: 'none', fontFamily: IOS.ui, fontSize: 14, fontWeight: 600,
      cursor: 'pointer'
    }}>{children}</button>);

}

function ScrollChips({ items, accent = 'iris' }) {
  return (
    <div style={{ padding: '4px 16px 12px', whiteSpace: 'nowrap', overflowX: 'auto' }}>
      {items.map((it, i) =>
      <span key={i} style={{
        display: 'inline-flex', alignItems: 'center', gap: 5,
        padding: '5px 11px', borderRadius: 999, marginRight: 6,
        background: it.active ? ACCENT[accent] : 'rgba(120,120,128,0.14)',
        color: it.active ? '#fff' : IOS.fg2,
        fontFamily: IOS.ui, fontSize: 13, fontWeight: 500,
        border: it.active ? 'none' : '0.5px solid rgba(60,60,67,0.06)'
      }}>
          {it.dot && <Pip accent={it.dot} size={6} radius={3} />}
          {it.label}
          {typeof it.count === 'number' &&
        <span style={{
          fontFamily: IOS.mono, fontSize: 11,
          color: it.active ? 'rgba(255,255,255,0.85)' : IOS.fg2,
          marginLeft: 1
        }}>{it.count}</span>
        }
        </span>
      )}
    </div>);

}

function SegControl({ items, active }) {
  return (
    <div style={{
      display: 'flex', background: 'rgba(120,120,128,0.16)', borderRadius: 9,
      padding: 2
    }}>
      {items.map((it, i) =>
      <div key={i} style={{
        flex: 1, padding: '6px 4px', textAlign: 'center',
        background: i === active ? '#fff' : 'transparent',
        borderRadius: 7,
        fontFamily: IOS.ui, fontSize: 13, fontWeight: i === active ? 600 : 500,
        color: IOS.fg, boxShadow: i === active ? '0 1px 2px rgba(0,0,0,0.1)' : 'none'
      }}>{it}</div>
      )}
    </div>);

}

// ────────────────────────────────────────────────────────────────────────────
// Phone wrapper — combines a screen with the bottom tab bar
// ────────────────────────────────────────────────────────────────────────────
function Phone({ children, activeTab, accent = 'iris', noTabs = false }) {
  return (
    <div style={{
      width: 390, height: 844, background: '#000', borderRadius: 48,
      padding: 4, boxShadow: '0 30px 60px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.18)',
      fontFamily: IOS.ui
    }}>
      <div style={{
        width: '100%', height: '100%', borderRadius: 44, overflow: 'hidden',
        position: 'relative', background: IOS.bg
      }}>
        {children}
        {!noTabs && <IOSTabBar active={activeTab} accent={accent} />}
        {/* Home indicator */}
        <div style={{
          position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
          width: 134, height: 5, background: 'rgba(0,0,0,0.35)', borderRadius: 3, zIndex: 11
        }} />
      </div>
    </div>);

}

Object.assign(window, {
  InboxScreen, ProjectsScreen, ProjectDetailScreen, FeatureDetailScreen,
  RoadmapScreen, SessionsListScreen, TerminalScreen, DocsScreen,
  ReviewScreen, YouScreen, Phone, IOS_ACCENT: ACCENT
});
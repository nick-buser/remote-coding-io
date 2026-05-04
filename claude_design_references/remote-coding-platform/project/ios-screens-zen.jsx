// iOS native screens v2 — "Apple-zen" simplification.
// Principles: one headline per screen, defer secondary info behind taps,
// quiet typography, monochrome surfaces, accent used sparingly as a single guide.

// ─── Tokens (light + dark) ─────────────────────────────────────────────────
const T = {
  light: {
    bg: '#F5F5F0', card: '#FFFFFF',
    fg: '#0A0A09', fg2: 'rgba(60,60,67,0.62)', fg3: 'rgba(60,60,67,0.32)',
    sep: 'rgba(60,60,67,0.10)',
    chip: 'rgba(120,120,128,0.12)',
    tabBg: 'rgba(245,245,240,0.86)',
    tabBd: 'rgba(60,60,67,0.14)',
    homeBar: 'rgba(0,0,0,0.4)',
    statusFg: '#000', isDark: false,
  },
  dark: {
    bg: '#000000', card: '#161617',
    fg: '#F5F5F7', fg2: 'rgba(235,235,245,0.6)', fg3: 'rgba(235,235,245,0.28)',
    sep: 'rgba(255,255,255,0.07)',
    chip: 'rgba(120,120,128,0.22)',
    tabBg: 'rgba(20,20,22,0.78)',
    tabBd: 'rgba(255,255,255,0.08)',
    homeBar: 'rgba(255,255,255,0.55)',
    statusFg: '#fff', isDark: true,
  },
};

const ACC = {
  iris:  { light: 'oklch(58% 0.18 280)', dark: 'oklch(72% 0.16 280)' },
  amber: { light: 'oklch(65% 0.16 60)',  dark: 'oklch(78% 0.15 60)' },
  mint:  { light: 'oklch(60% 0.13 165)', dark: 'oklch(74% 0.13 165)' },
  rose:  { light: 'oklch(60% 0.18 15)',  dark: 'oklch(74% 0.17 15)' },
};
const accentOf = (name, mode) => ACC[name][mode];

const FONT = {
  ui: '-apple-system, "SF Pro Text", system-ui, sans-serif',
  display: '-apple-system, "SF Pro Display", system-ui, sans-serif',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace',
};

// ─── Status bar ─────────────────────────────────────────────────────────────
function StatusBar2({ time = '9:41', mode }) {
  const c = T[mode].statusFg;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 32px 6px', height: 47, boxSizing: 'border-box',
      position: 'relative', zIndex: 20,
    }}>
      <span style={{ fontFamily: FONT.display, fontSize: 17, fontWeight: 600, color: c, letterSpacing: -0.2 }}>{time}</span>
      <div style={{ width: 120, height: 36, background: '#000', borderRadius: 20 }} />
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="18" height="11" viewBox="0 0 18 11"><rect x="0" y="6.5" width="3" height="4.5" rx="0.7" fill={c}/><rect x="4.5" y="4.5" width="3" height="6.5" rx="0.7" fill={c}/><rect x="9" y="2" width="3" height="9" rx="0.7" fill={c}/><rect x="13.5" y="0" width="3" height="11" rx="0.7" fill={c}/></svg>
        <svg width="16" height="11" viewBox="0 0 17 12"><path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={c}/><path d="M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z" fill={c}/><circle cx="8.5" cy="10.5" r="1.5" fill={c}/></svg>
        <svg width="25" height="12" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} strokeOpacity="0.35" fill="none"/><rect x="2" y="2" width="17" height="9" rx="2" fill={c}/></svg>
      </div>
    </div>
  );
}

// ─── Quiet tab bar — no badges. One small accent dot when work needs you. ─
function TabBar2({ active, mode, accent, needsYou = false }) {
  const t = T[mode];
  const tabs = [
    { id: 'inbox', label: 'Inbox', icon: TabIcons2.inbox },
    { id: 'projects', label: 'Projects', icon: TabIcons2.projects },
    { id: 'roadmap', label: 'Roadmap', icon: TabIcons2.roadmap },
    { id: 'sessions', label: 'Sessions', icon: TabIcons2.sessions },
    { id: 'you', label: 'You', icon: TabIcons2.you },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 22, paddingTop: 8,
      background: t.tabBg,
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderTop: `0.5px solid ${t.tabBd}`,
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-around',
      zIndex: 10,
    }}>
      {tabs.map((tab) => {
        const isActive = tab.id === active;
        const color = isActive ? accentOf(accent, mode) : t.fg2;
        const showDot = needsYou && tab.id === 'inbox' && !isActive;
        return (
          <div key={tab.id} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            gap: 4, padding: '4px 0', minWidth: 56, position: 'relative',
          }}>
            <div style={{ position: 'relative' }}>
              <tab.icon color={color} active={isActive} />
              {showDot && (
                <div style={{
                  position: 'absolute', top: 0, right: -1,
                  width: 7, height: 7, borderRadius: 4,
                  background: accentOf(accent, mode),
                }} />
              )}
            </div>
            <div style={{
              fontFamily: FONT.ui, fontSize: 10, fontWeight: 500,
              color, letterSpacing: 0.1,
            }}>{tab.label}</div>
          </div>
        );
      })}
    </div>
  );
}

const TabIcons2 = {
  inbox: ({ color, active }) => (
    <svg width="24" height="24" viewBox="0 0 26 26" fill="none">
      <path d="M5 5h16l-2.5 9H7.5L5 5z" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.18 : 0} strokeLinejoin="round"/>
      <path d="M3 14h6l1.5 2.5h5L17 14h6v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5z" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 1 : 0} strokeLinejoin="round"/>
    </svg>
  ),
  projects: ({ color, active }) => (
    <svg width="24" height="24" viewBox="0 0 26 26" fill="none">
      <rect x="4" y="6" width="8" height="14" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0}/>
      <rect x="14" y="6" width="8" height="6.5" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.5 : 0}/>
      <rect x="14" y="14.5" width="8" height="5.5" rx="1.6" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.3 : 0}/>
    </svg>
  ),
  roadmap: ({ color, active }) => (
    <svg width="24" height="24" viewBox="0 0 26 26" fill="none">
      <rect x="3.5" y="6" width="11" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0}/>
      <rect x="7" y="11.2" width="14" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.6 : 0}/>
      <rect x="5" y="16.4" width="10" height="3.6" rx="1.2" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.35 : 0}/>
    </svg>
  ),
  sessions: ({ color, active }) => (
    <svg width="24" height="24" viewBox="0 0 26 26" fill="none">
      <rect x="3" y="5" width="20" height="16" rx="2.5" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.15 : 0}/>
      <path d="M7 10l3 3-3 3M12 16h6" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
    </svg>
  ),
  you: ({ color, active }) => (
    <svg width="24" height="24" viewBox="0 0 26 26" fill="none">
      <circle cx="13" cy="9.5" r="4" stroke={color} strokeWidth="1.6" fill={active ? color : 'none'} fillOpacity={active ? 0.9 : 0}/>
      <path d="M4.5 22c1.5-4.5 5-7 8.5-7s7 2.5 8.5 7" stroke={color} strokeWidth="1.6" strokeLinecap="round" fill={active ? color : 'none'} fillOpacity={active ? 0.4 : 0}/>
    </svg>
  ),
};

// ─── Quiet header — small label only, no chips, no subtitle clutter ──────
function QuietHeader({ label, mode, accent, leading, trailing }) {
  const t = T[mode];
  return (
    <div style={{ padding: '6px 16px 0', position: 'relative', zIndex: 5 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 40 }}>
        <div style={{ color: accentOf(accent, mode), fontFamily: FONT.ui, fontSize: 17, fontWeight: 400, display: 'flex', alignItems: 'center', gap: 2 }}>
          {leading}
        </div>
        <div style={{
          fontFamily: FONT.ui, fontSize: 15, fontWeight: 600, color: t.fg, letterSpacing: -0.1,
          position: 'absolute', left: 0, right: 0, textAlign: 'center', pointerEvents: 'none',
        }}>{label}</div>
        <div style={{ display: 'flex', gap: 14, alignItems: 'center', color: t.fg }}>{trailing}</div>
      </div>
    </div>
  );
}

function BackChev2({ mode, accent, label }) {
  return (
    <>
      <svg width="11" height="18" viewBox="0 0 11 18" fill="none"><path d="M9 1L1.5 9 9 17" stroke={accentOf(accent, mode)} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
      <span style={{ marginLeft: 2 }}>{label}</span>
    </>
  );
}

function Dots({ mode }) {
  const c = T[mode].fg;
  return <svg width="22" height="6" viewBox="0 0 22 6"><circle cx="3" cy="3" r="2.5" fill={c}/><circle cx="11" cy="3" r="2.5" fill={c}/><circle cx="19" cy="3" r="2.5" fill={c}/></svg>;
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — INBOX (one hero card, "1 of 3 needs you", swipe through)
// ────────────────────────────────────────────────────────────────────────────
function InboxZen({ mode, accent }) {
  const t = T[mode];
  const a = accentOf(accent, mode);
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="Inbox"
        leading={<span />} trailing={<Dots mode={mode} />} />

      {/* Soft counter */}
      <div style={{ padding: '36px 24px 12px', textAlign: 'center' }}>
        <div style={{ fontFamily: FONT.mono, fontSize: 11, color: t.fg2, letterSpacing: 1.5, textTransform: 'uppercase' }}>1 of 3</div>
        <div style={{ fontFamily: FONT.display, fontSize: 24, fontWeight: 600, color: t.fg, letterSpacing: -0.3, marginTop: 6 }}>
          One question waiting
        </div>
      </div>

      {/* The single hero card */}
      <div style={{ padding: '24px 16px 0' }}>
        <div style={{
          background: t.card, borderRadius: 22,
          padding: '24px 22px 20px',
          boxShadow: mode === 'light' ? '0 1px 2px rgba(0,0,0,0.04)' : 'none',
          border: mode === 'dark' ? `0.5px solid ${t.sep}` : 'none',
        }}>
          {/* tiny breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 18 }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: a }} />
            <span style={{ fontFamily: FONT.mono, fontSize: 11, color: t.fg2 }}>tmux-agent</span>
            <span style={{ color: t.fg3 }}>·</span>
            <span style={{ fontFamily: FONT.mono, fontSize: 11, color: t.fg2 }}>TMX-0050</span>
          </div>

          {/* The actual question, given room */}
          <div style={{
            fontFamily: FONT.display, fontSize: 22, fontWeight: 500,
            color: t.fg, letterSpacing: -0.3, lineHeight: 1.32, marginBottom: 14,
          }}>
            "Use unified diff or split? Defaulting to split."
          </div>

          {/* Source line */}
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            fontFamily: FONT.mono, fontSize: 12, color: t.fg2,
          }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: '#FF9500' }} />
            session-07 · 2h ago
          </div>

          {/* One primary action. The other lives in dots menu. */}
          <button style={{
            width: '100%', marginTop: 22, padding: '14px',
            background: a, color: '#fff', border: 'none', borderRadius: 14,
            fontFamily: FONT.ui, fontSize: 16, fontWeight: 600,
          }}>Reply</button>

          <button style={{
            width: '100%', marginTop: 8, padding: '12px',
            background: 'transparent', color: a, border: 'none',
            fontFamily: FONT.ui, fontSize: 15, fontWeight: 500,
          }}>Open session</button>
        </div>
      </div>

      {/* "Next" hint — subtle */}
      <div style={{ textAlign: 'center', padding: '32px 0 0', fontFamily: FONT.ui, fontSize: 13, color: t.fg2 }}>
        Swipe for next  →
      </div>

      {/* Page dots */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: 6, padding: '14px 0' }}>
        <span style={{ width: 6, height: 6, borderRadius: 3, background: t.fg }} />
        <span style={{ width: 6, height: 6, borderRadius: 3, background: t.fg3 }} />
        <span style={{ width: 6, height: 6, borderRadius: 3, background: t.fg3 }} />
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — INBOX EMPTY (when nothing needs you — the goal state)
// ────────────────────────────────────────────────────────────────────────────
function InboxEmptyZen({ mode, accent }) {
  const t = T[mode];
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="Inbox"
        leading={<span />} trailing={<Dots mode={mode} />} />
      <div style={{
        position: 'absolute', inset: 0,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        padding: '0 40px',
      }}>
        <div style={{
          width: 72, height: 72, borderRadius: 36,
          border: `1.5px solid ${t.fg3}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          marginBottom: 22,
        }}>
          <svg width="32" height="24" viewBox="0 0 32 24" fill="none">
            <path d="M2 6l14 12L30 6" stroke={t.fg3} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
        <div style={{ fontFamily: FONT.display, fontSize: 22, fontWeight: 500, color: t.fg, letterSpacing: -0.3, marginBottom: 6 }}>
          All clear
        </div>
        <div style={{ fontFamily: FONT.ui, fontSize: 14, color: t.fg2, textAlign: 'center', lineHeight: 1.45 }}>
          Agents are working. They'll find you here when they need something.
        </div>
      </div>
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — PROJECTS (just names. dots indicate liveness. Tap to drill.)
// ────────────────────────────────────────────────────────────────────────────
function ProjectsZen({ mode, accent }) {
  const t = T[mode];
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="Projects"
        leading={<span />} trailing={<NavIconZ name="search" mode={mode} />} />

      <div style={{ padding: '18px 24px 10px' }}>
        {window.PROJECTS.map((p) => (
          <button key={p.id} style={{
            display: 'flex', alignItems: 'center', gap: 14,
            width: '100%', background: 'transparent', border: 'none',
            padding: '18px 0', borderBottom: `0.5px solid ${t.sep}`,
            textAlign: 'left',
          }}>
            <span style={{
              width: 8, height: 8, borderRadius: 4,
              background: p.liveSessions > 0 ? accentOf(p.accent, mode) : t.fg3,
              flexShrink: 0,
            }} />
            <span style={{
              fontFamily: FONT.display, fontSize: 22, fontWeight: 500,
              color: p.status === 'paused' ? t.fg2 : t.fg,
              letterSpacing: -0.3, flex: 1,
            }}>{p.name}</span>
            {p.liveSessions > 0 && (
              <span style={{ fontFamily: FONT.mono, fontSize: 12, color: t.fg2 }}>{p.liveSessions} live</span>
            )}
          </button>
        ))}
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — PROJECT DETAIL (one screen, one job: pick a feature)
// ────────────────────────────────────────────────────────────────────────────
function ProjectDetailZen({ mode, accent }) {
  const t = T[mode];
  const project = window.PROJECTS[0];
  const features = window.FEATURES.filter((f) => f.project === project.id && f.status !== 'shipped');
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent}
        label={project.name}
        leading={<BackChev2 mode={mode} accent={accent} label="Projects" />}
        trailing={<Dots mode={mode} />} />

      {/* Hero — just the project name + tagline. No stats strip. */}
      <div style={{ padding: '32px 24px 28px' }}>
        <div style={{
          fontFamily: FONT.display, fontSize: 34, fontWeight: 600,
          color: t.fg, letterSpacing: -0.5, lineHeight: 1.1, marginBottom: 8,
        }}>{project.name}</div>
        <div style={{
          fontFamily: FONT.ui, fontSize: 15, color: t.fg2, lineHeight: 1.45,
        }}>{project.tagline}</div>
      </div>

      {/* The single question this screen answers: which feature? */}
      <div style={{ padding: '0 24px 8px' }}>
        <div style={{
          fontFamily: FONT.ui, fontSize: 12, color: t.fg2,
          textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 12,
        }}>Active features</div>
        {features.map((f) => (
          <button key={f.id} style={{
            display: 'flex', alignItems: 'center', gap: 14,
            width: '100%', background: 'transparent', border: 'none',
            padding: '16px 0', borderBottom: `0.5px solid ${t.sep}`,
            textAlign: 'left',
          }}>
            <span style={{
              width: 8, height: 8, borderRadius: 4,
              background: f.sessions > 0 ? accentOf(f.accent, mode) : t.fg3,
              flexShrink: 0,
            }} />
            <span style={{
              fontFamily: FONT.ui, fontSize: 17, fontWeight: 500,
              color: t.fg, letterSpacing: -0.1, flex: 1,
            }}>{f.title}</span>
            {f.sessions > 0 && (
              <span style={{ fontFamily: FONT.mono, fontSize: 11.5, color: t.fg2 }}>{f.sessions} live</span>
            )}
          </button>
        ))}
      </div>

      {/* Demoted: secondary navigation lives in a row of small links — */}
      <div style={{ padding: '32px 24px 0', display: 'flex', gap: 22, justifyContent: 'center' }}>
        {['All tickets', 'Docs', 'Roadmap', 'Shipped'].map((l) => (
          <span key={l} style={{ fontFamily: FONT.ui, fontSize: 13, color: accentOf(accent, mode) }}>{l}</span>
        ))}
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — FEATURE DETAIL (name + vision. Tickets/PRD live one tap deeper.)
// ────────────────────────────────────────────────────────────────────────────
function FeatureDetailZen({ mode, accent }) {
  const t = T[mode];
  const a = accentOf(accent, mode);
  const f = window.FEATURES[0];
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent}
        label={f.id}
        leading={<BackChev2 mode={mode} accent={accent} label={window.PROJECTS[0].name} />}
        trailing={<Dots mode={mode} />} />

      {/* Vision is the headline, given full attention */}
      <div style={{ padding: '32px 24px 32px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 18 }}>
          <span style={{ width: 8, height: 8, borderRadius: 4, background: a }} />
          <span style={{ fontFamily: FONT.ui, fontSize: 13, color: t.fg2 }}>In progress · {f.milestone.replace(' — ', ' · ')}</span>
        </div>
        <div style={{
          fontFamily: FONT.display, fontSize: 28, fontWeight: 600,
          color: t.fg, letterSpacing: -0.4, lineHeight: 1.18, marginBottom: 14,
        }}>{f.title}</div>
        <div style={{
          fontFamily: FONT.ui, fontSize: 16, color: t.fg2, lineHeight: 1.5,
        }}>{f.vision}</div>
      </div>

      {/* Single line of progress, no chart, no chips */}
      <div style={{ padding: '0 24px 24px' }}>
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          fontFamily: FONT.mono, fontSize: 12, color: t.fg2, marginBottom: 10,
        }}>
          <span>{f.ticketsDone} of {f.tickets} tickets</span>
          <span>{f.target}</span>
        </div>
        <div style={{ height: 2, background: t.sep, borderRadius: 1, overflow: 'hidden' }}>
          <div style={{ width: (f.progress*100)+'%', height: '100%', background: a }} />
        </div>
      </div>

      {/* Three deep links. That's it. */}
      <div style={{ padding: '12px 16px 0' }}>
        {[
          { l: 'Tickets', sub: `${f.tickets - f.ticketsDone} open` },
          { l: 'PRD', sub: 'Edited 1h ago' },
          { l: f.sessions > 0 ? 'Live sessions' : 'Spawn session', sub: f.sessions > 0 ? `${f.sessions} active` : 'Start a new agent' },
        ].map((row, i, arr) => (
          <button key={i} style={{
            display: 'flex', alignItems: 'center',
            width: '100%', background: 'transparent', border: 'none',
            padding: '20px 8px', borderBottom: i === arr.length - 1 ? 'none' : `0.5px solid ${t.sep}`,
            textAlign: 'left',
          }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: FONT.ui, fontSize: 17, color: t.fg, fontWeight: 500 }}>{row.l}</div>
              <div style={{ fontFamily: FONT.ui, fontSize: 13, color: t.fg2, marginTop: 2 }}>{row.sub}</div>
            </div>
            <ChevZ mode={mode} />
          </button>
        ))}
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — ROADMAP (one milestone in focus, others as page-dot indicators)
// ────────────────────────────────────────────────────────────────────────────
function RoadmapZen({ mode, accent }) {
  const t = T[mode];
  const a = accentOf(accent, mode);
  const m = window.MILESTONES[1]; // active one
  const feats = window.FEATURES.filter((f) => f.milestone.startsWith(m.id));
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="Roadmap"
        leading={<span />} trailing={<NavIconZ name="calendar" mode={mode} />} />

      {/* Milestone label — the focus */}
      <div style={{ padding: '32px 24px 8px' }}>
        <div style={{ fontFamily: FONT.mono, fontSize: 11, color: t.fg2, letterSpacing: 1.5, textTransform: 'uppercase', marginBottom: 8 }}>
          Now · ends {m.end}
        </div>
        <div style={{ fontFamily: FONT.display, fontSize: 28, fontWeight: 600, color: t.fg, letterSpacing: -0.4 }}>
          {m.label.replace(/^v\d+\.\d+ — /, '')}
        </div>
        <div style={{ fontFamily: FONT.mono, fontSize: 12, color: t.fg2, marginTop: 4 }}>{m.id}</div>
      </div>

      {/* Just the features in this milestone — no progress bars */}
      <div style={{ padding: '24px 24px 0' }}>
        {feats.map((f) => (
          <button key={f.id} style={{
            display: 'flex', alignItems: 'center', gap: 14,
            width: '100%', background: 'transparent', border: 'none',
            padding: '16px 0', borderBottom: `0.5px solid ${t.sep}`,
            textAlign: 'left',
          }}>
            <span style={{
              width: 8, height: 8, borderRadius: 4,
              background: f.status === 'review' ? a : f.status === 'in-progress' ? '#FF9500' : t.fg3,
              flexShrink: 0,
            }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: FONT.ui, fontSize: 16, color: t.fg, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{f.title}</div>
              <div style={{ fontFamily: FONT.mono, fontSize: 11.5, color: t.fg2, marginTop: 2 }}>{f.target}</div>
            </div>
          </button>
        ))}
      </div>

      {/* Page dots — swipe between milestones */}
      <div style={{ display: 'flex', justifyContent: 'center', gap: 8, padding: '32px 0 0' }}>
        {window.MILESTONES.map((mi, i) => (
          <span key={mi.id} style={{
            width: 6, height: 6, borderRadius: 3,
            background: i === 1 ? t.fg : t.fg3,
          }} />
        ))}
      </div>
      <div style={{ textAlign: 'center', fontFamily: FONT.ui, fontSize: 12, color: t.fg2, marginTop: 10 }}>
        Swipe for next milestone
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — SESSIONS (only what's awaiting you. rest behind a single toggle)
// ────────────────────────────────────────────────────────────────────────────
function SessionsZen({ mode, accent }) {
  const t = T[mode];
  const a = accentOf(accent, mode);
  const awaiting = window.SESSIONS.filter((s) => s.state === 'awaiting-input');
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="Sessions"
        leading={<span />} trailing={<NavIconZ name="plus" mode={mode} accent={a} />} />

      <div style={{ padding: '36px 24px 12px', textAlign: 'center' }}>
        <div style={{ fontFamily: FONT.mono, fontSize: 11, color: t.fg2, letterSpacing: 1.5, textTransform: 'uppercase' }}>Awaiting you</div>
        <div style={{ fontFamily: FONT.display, fontSize: 24, fontWeight: 600, color: t.fg, letterSpacing: -0.3, marginTop: 6 }}>
          {awaiting.length} session
        </div>
      </div>

      {awaiting.map((s, i) => {
        const ticket = window.TICKETS.find((t) => t.id === s.ticket);
        const feature = window.FEATURES.find((f) => f.id === s.feature);
        return (
          <div key={s.id} style={{ padding: '16px 16px 0' }}>
            <div style={{
              background: t.card, borderRadius: 18, padding: '18px 20px',
              border: mode === 'dark' ? `0.5px solid ${t.sep}` : 'none',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                <span style={{ width: 7, height: 7, borderRadius: 4, background: '#FF9500' }} />
                <span style={{ fontFamily: FONT.mono, fontSize: 12, color: t.fg2 }}>{s.id}</span>
                <span style={{ marginLeft: 'auto', fontFamily: FONT.mono, fontSize: 11.5, color: t.fg2 }}>{s.uptime}</span>
              </div>
              <div style={{ fontFamily: FONT.ui, fontSize: 17, fontWeight: 500, color: t.fg, lineHeight: 1.32, marginBottom: 14 }}>
                {ticket && ticket.title}
              </div>
              <button style={{
                width: '100%', padding: '12px',
                background: a, color: '#fff', border: 'none', borderRadius: 12,
                fontFamily: FONT.ui, fontSize: 15, fontWeight: 600,
              }}>Open pane</button>
            </div>
          </div>
        );
      })}

      {/* Quiet footer — 'see all' */}
      <div style={{ padding: '40px 24px 0', textAlign: 'center' }}>
        <span style={{ fontFamily: FONT.ui, fontSize: 14, color: accentOf(accent, mode) }}>
          Show all 4 sessions
        </span>
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — TERMINAL (Runestone — already focused, kept; just dark + cleaner)
// ────────────────────────────────────────────────────────────────────────────
function TerminalZen({ mode, accent }) {
  const a = accentOf(accent, 'dark');
  return (
    <div style={{
      width: '100%', height: '100%', background: '#000', position: 'relative',
      display: 'flex', flexDirection: 'column',
    }}>
      <StatusBar2 mode="dark" />
      {/* Slim context bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '4px 16px 10px', borderBottom: '0.5px solid rgba(255,255,255,0.08)',
      }}>
        <button style={{
          background: 'transparent', border: 'none', color: a,
          fontFamily: FONT.ui, fontSize: 16, padding: 0,
          display: 'flex', alignItems: 'center', gap: 2,
        }}>
          <svg width="11" height="18" viewBox="0 0 11 18" fill="none"><path d="M9 1L1.5 9 9 17" stroke={a} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </button>
        <div style={{ flex: 1, textAlign: 'center', minWidth: 0 }}>
          <div style={{ fontFamily: FONT.ui, fontSize: 14, color: '#fff', fontWeight: 600 }}>session-07</div>
          <div style={{ fontFamily: FONT.mono, fontSize: 10.5, color: 'rgba(235,235,245,0.5)' }}>tmux-agent · agent:2.0</div>
        </div>
        <Dots mode="dark" />
      </div>

      {/* Terminal — the focus */}
      <div style={{
        flex: 1, padding: '14px 16px',
        fontFamily: FONT.mono, fontSize: 13, lineHeight: 1.55,
        color: '#e7e7ea', overflow: 'hidden', whiteSpace: 'pre-wrap',
      }}>
{`> pushed 3 commits to feat/tmx-0050-diff-viewer
  a3f2c19 chore: tighten gutter spacing
  b7e1d44 fix: split-view scroll sync
  c01af2b test: add 12 cases for diff parser

`}<span style={{ color: a }}>agent ›</span>{` ran tests on TMX-0050
  go test ./diff/... -count=1
`}<span style={{ color: '#34C759' }}>  PASS</span>{`  ./diff/parser    [142/142]
`}<span style={{ color: '#34C759' }}>  PASS</span>{`  ./diff/renderer  [38/38]

`}<span style={{ color: '#FF9500' }}>agent ›</span>{` `}<span style={{ color: '#fff' }}>Use unified diff or split? Defaulting to split.</span>{`
        Reply 'unified', 'split', or 'auto'.

`}<span style={{ color: a }}>▎</span>
      </div>

      {/* Quick keys */}
      <div style={{
        display: 'flex', gap: 6, padding: '6px 12px',
        overflowX: 'auto', whiteSpace: 'nowrap',
        background: 'rgba(28,28,30,0.6)',
        borderTop: '0.5px solid rgba(255,255,255,0.08)',
      }}>
        {['esc','tab','⌃C','⌃D','↑','↓','←','→','⏎'].map((k) => (
          <span key={k} style={{
            display: 'inline-flex', padding: '6px 10px', borderRadius: 6,
            background: 'rgba(255,255,255,0.08)', color: '#fff',
            fontFamily: FONT.mono, fontSize: 13, minWidth: 32, justifyContent: 'center',
          }}>{k}</span>
        ))}
      </div>

      {/* Input */}
      <div style={{
        display: 'flex', gap: 8, padding: '8px 12px 10px',
        background: '#1c1c1e', alignItems: 'center',
      }}>
        <div style={{
          flex: 1, background: '#2c2c2e', borderRadius: 18,
          padding: '8px 14px', fontFamily: FONT.mono, fontSize: 14,
          color: 'rgba(235,235,245,0.4)',
        }}>split</div>
        <button style={{
          width: 34, height: 34, borderRadius: 17, background: a, border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2 8L14 2L9 14L7 9L2 8Z" fill="#fff"/></svg>
        </button>
      </div>

      <div style={{ padding: '8px 0 10px', display: 'flex', justifyContent: 'center' }}>
        <div style={{ width: 134, height: 5, background: 'rgba(255,255,255,0.4)', borderRadius: 3 }} />
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────────────────────
// SCREEN — YOU (very quiet)
// ────────────────────────────────────────────────────────────────────────────
function YouZen({ mode, accent }) {
  const t = T[mode];
  const a = accentOf(accent, mode);
  return (
    <ScreenZen mode={mode}>
      <QuietHeader mode={mode} accent={accent} label="You"
        leading={<span />} trailing={<Dots mode={mode} />} />

      <div style={{ padding: '36px 24px 28px', textAlign: 'center' }}>
        <div style={{
          width: 64, height: 64, borderRadius: 32, background: a,
          color: '#fff', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: FONT.display, fontSize: 26, fontWeight: 600, marginBottom: 14,
        }}>N</div>
        <div style={{ fontFamily: FONT.display, fontSize: 22, fontWeight: 500, color: t.fg, letterSpacing: -0.3 }}>Nick Buser</div>
        <div style={{ fontFamily: FONT.mono, fontSize: 12, color: t.fg2, marginTop: 4 }}>4 projects · 4 sessions live</div>
      </div>

      {/* Just three groupings */}
      <div style={{ padding: '0 16px' }}>
        {[
          { l: 'Workspace', sub: 'tmux-agent server, notifications' },
          { l: 'Appearance', sub: `${mode === 'dark' ? 'Dark' : 'Light'} · ${accent}` },
          { l: 'Agent', sub: 'Claude Sonnet, 6 panes per window' },
        ].map((row, i, arr) => (
          <button key={i} style={{
            display: 'flex', alignItems: 'center',
            width: '100%', background: 'transparent', border: 'none',
            padding: '20px 8px', borderBottom: i === arr.length - 1 ? 'none' : `0.5px solid ${t.sep}`,
            textAlign: 'left',
          }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: FONT.ui, fontSize: 17, color: t.fg, fontWeight: 500 }}>{row.l}</div>
              <div style={{ fontFamily: FONT.ui, fontSize: 13, color: t.fg2, marginTop: 2 }}>{row.sub}</div>
            </div>
            <ChevZ mode={mode} />
          </button>
        ))}
      </div>

      <SpacerZ h={120} />
    </ScreenZen>
  );
}

// ─── primitives ─────────────────────────────────────────────────────────────
function ScreenZen({ children, mode }) {
  return (
    <div style={{
      width: '100%', height: '100%', background: T[mode].bg,
      overflowY: 'auto', position: 'relative',
      WebkitFontSmoothing: 'antialiased',
    }}>
      <StatusBar2 mode={mode} />
      {children}
    </div>
  );
}

function SpacerZ({ h }) { return <div style={{ height: h }} />; }

function ChevZ({ mode }) {
  return (
    <svg width="7" height="12" viewBox="0 0 7 12" style={{ flexShrink: 0 }}>
      <path d="M1 1l5 5-5 5" stroke={T[mode].fg3} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

function NavIconZ({ name, mode, accent }) {
  const c = T[mode].fg;
  if (name === 'plus') return <svg width="22" height="22" viewBox="0 0 22 22"><path d="M11 4v14M4 11h14" stroke={accent || c} strokeWidth="2" strokeLinecap="round"/></svg>;
  if (name === 'search') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><circle cx="9" cy="9" r="6" stroke={c} strokeWidth="1.8"/><path d="M14 14l4 4" stroke={c} strokeWidth="1.8" strokeLinecap="round"/></svg>;
  if (name === 'calendar') return <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="3" y="4" width="14" height="13" rx="1.6" stroke={c} strokeWidth="1.6"/><path d="M3 8h14M7 2v4M13 2v4" stroke={c} strokeWidth="1.6" strokeLinecap="round"/></svg>;
  return null;
}

// ─── Phone wrapper ──────────────────────────────────────────────────────────
function PhoneZ({ children, activeTab, accent, mode = 'light', noTabs = false, needsYou = false }) {
  return (
    <div style={{
      width: 390, height: 844, background: '#000', borderRadius: 48,
      padding: 4, boxShadow: '0 30px 60px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.18)',
      fontFamily: FONT.ui,
    }}>
      <div style={{
        width: '100%', height: '100%', borderRadius: 44, overflow: 'hidden',
        position: 'relative', background: T[mode].bg,
      }}>
        {children}
        {!noTabs && <TabBar2 active={activeTab} accent={accent} mode={mode} needsYou={needsYou} />}
        <div style={{
          position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
          width: 134, height: 5, background: T[mode].homeBar, borderRadius: 3, zIndex: 11,
        }} />
      </div>
    </div>
  );
}

Object.assign(window, {
  InboxZen, InboxEmptyZen, ProjectsZen, ProjectDetailZen, FeatureDetailZen,
  RoadmapZen, SessionsZen, TerminalZen, YouZen, PhoneZ,
});

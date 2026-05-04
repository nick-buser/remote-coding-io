// Linear-esque PM hub — dense, monochrome, keyboard-first.
// Hierarchy: Project ▸ Feature ▸ Ticket ▸ Session.
// Sidebar is project-scoped: switch project at the top, browse its features below.

const linearStyles = {
  shell: {
    width: '100%',
    height: '100%',
    background: 'var(--bg)',
    color: 'var(--fg)',
    fontFamily: 'var(--ui-font)',
    fontSize: 13,
    lineHeight: 1.45,
    display: 'grid',
    gridTemplateColumns: '244px 1fr',
    overflow: 'hidden',
  },
};

function LinearHub({ accent = 'iris', density = 'dense', listMode = 'row' }) {
  // view: 'projects' | 'project' | 'feature' | 'activity'
  const [view, setView] = React.useState('feature');
  const [openProject, setOpenProject] = React.useState('PRJ-01');
  const [openFeature, setOpenFeature] = React.useState('FEAT-018');
  const [projectSwitcherOpen, setProjectSwitcherOpen] = React.useState(false);

  const openFeatureFn = (fid) => {
    const f = window.FEATURES.find(x => x.id === fid);
    if (f) setOpenProject(f.project);
    setOpenFeature(fid);
    setView('feature');
  };
  const openProjectFn = (pid) => {
    setOpenProject(pid);
    setView('project');
  };

  return (
    <div className="lin-shell" style={linearStyles.shell} data-accent={accent} data-density={density}>
      <LinSidebar
        view={view}
        setView={setView}
        openProject={openProject}
        setOpenProject={openProjectFn}
        openFeature={openFeature}
        setOpenFeature={openFeatureFn}
        projectSwitcherOpen={projectSwitcherOpen}
        setProjectSwitcherOpen={setProjectSwitcherOpen}
      />
      <div className="lin-main">
        <LinTopbar view={view} setView={setView} openProject={openProject} openFeature={openFeature} />
        <div className="lin-body">
          {view === 'projects' && <LinProjectsList onOpen={openProjectFn} />}
          {view === 'project' && <LinProjectDetail id={openProject} onOpenFeature={openFeatureFn} listMode={listMode} />}
          {view === 'feature' && <LinFeatureDetail id={openFeature} />}
          {view === 'activity' && <LinActivity />}
        </div>
      </div>
    </div>
  );
}

// ── Sidebar ─────────────────────────────────────────────────────────────────
function LinSidebar({ view, setView, openProject, setOpenProject, openFeature, setOpenFeature, projectSwitcherOpen, setProjectSwitcherOpen }) {
  const projects = window.PROJECTS;
  const features = window.FEATURES.filter(f => f.project === openProject);
  const inFlight = features.filter(f => f.status === 'in-progress' || f.status === 'review');
  const planned = features.filter(f => f.status === 'planned');
  const shipped = features.filter(f => f.status === 'shipped');
  const proj = projects.find(p => p.id === openProject);

  const navItem = (key, label, kbd, count) => (
    <button key={key} className={`lin-nav-item ${view === key ? 'is-active' : ''}`} onClick={() => setView(key)}>
      <span className="lin-nav-label">{label}</span>
      {count != null && <span className="lin-nav-count">{count}</span>}
      <span className="lin-nav-kbd">{kbd}</span>
    </button>
  );

  return (
    <aside className="lin-sidebar">
      {/* Project switcher — at the very top, replaces the old static brand */}
      <div className="lin-projswitch-wrap">
        <button className={`lin-projswitch ${projectSwitcherOpen ? 'is-open' : ''}`} onClick={() => setProjectSwitcherOpen(!projectSwitcherOpen)}>
          <span className={`lin-projswitch-mark pip-${proj.accent}`}>{proj.icon}</span>
          <span className="lin-projswitch-name">{proj.name}</span>
          <span className="lin-projswitch-id">{proj.id}</span>
          <span className="lin-projswitch-caret">⌄</span>
        </button>
        {projectSwitcherOpen && (
          <div className="lin-projmenu">
            <div className="lin-projmenu-head">Switch project</div>
            {projects.map(p => (
              <button key={p.id} className={`lin-projmenu-row ${p.id === openProject ? 'is-active' : ''}`}
                      onClick={() => { setOpenProject(p.id); setProjectSwitcherOpen(false); }}>
                <span className={`lin-projswitch-mark pip-${p.accent}`}>{p.icon}</span>
                <span className="lin-projmenu-name">{p.name}</span>
                <span className="lin-projmenu-meta">{p.activeFeatures} active</span>
              </button>
            ))}
            <div className="lin-projmenu-divider" />
            <button className="lin-projmenu-row lin-projmenu-all" onClick={() => { setView('projects'); setProjectSwitcherOpen(false); }}>
              <span className="lin-projmenu-glyph">⊞</span>
              <span className="lin-projmenu-name">All projects</span>
              <span className="lin-projmenu-kbd">P</span>
            </button>
            <button className="lin-projmenu-row lin-projmenu-new" onClick={() => setProjectSwitcherOpen(false)}>
              <span className="lin-projmenu-glyph">+</span>
              <span className="lin-projmenu-name">New project…</span>
            </button>
          </div>
        )}
      </div>

      <div className="lin-nav-search">
        <span className="lin-search-icon">⌕</span>
        <input placeholder={`Jump in ${proj.name}…`} />
        <span className="lin-search-kbd">⌘K</span>
      </div>

      <nav className="lin-nav">
        {navItem('project', 'Overview', 'O')}
        {navItem('activity', 'Activity', 'A', proj.liveSessions + 14)}
      </nav>

      <div className="lin-side-section">
        <div className="lin-side-head">
          <span>In flight</span>
          <span className="lin-side-pill">{inFlight.length}</span>
        </div>
        {inFlight.map(f => (
          <button key={f.id} className={`lin-side-feat ${openFeature === f.id && view === 'feature' ? 'is-active' : ''}`}
                  onClick={() => setOpenFeature(f.id)}>
            <span className={`lin-status-glyph s-${f.status}`} />
            <span className="lin-feat-id">{f.id}</span>
            <span className="lin-feat-title">{f.title}</span>
            <span className="lin-feat-prog">{Math.round(f.progress * 100)}</span>
          </button>
        ))}
        {inFlight.length === 0 && <div className="lin-side-empty">No active features</div>}
      </div>

      <div className="lin-side-section">
        <div className="lin-side-head"><span>Planned</span><span className="lin-side-pill">{planned.length}</span></div>
        {planned.map(f => (
          <button key={f.id} className={`lin-side-feat ${openFeature === f.id && view === 'feature' ? 'is-active' : ''}`}
                  onClick={() => setOpenFeature(f.id)}>
            <span className={`lin-status-glyph s-${f.status}`} />
            <span className="lin-feat-id">{f.id}</span>
            <span className="lin-feat-title">{f.title}</span>
          </button>
        ))}
        {planned.length === 0 && <div className="lin-side-empty">—</div>}
      </div>

      {shipped.length > 0 && (
        <div className="lin-side-section">
          <div className="lin-side-head"><span>Shipped</span><span className="lin-side-pill">{shipped.length}</span></div>
          {shipped.map(f => (
            <button key={f.id} className={`lin-side-feat is-muted ${openFeature === f.id && view === 'feature' ? 'is-active' : ''}`}
                    onClick={() => setOpenFeature(f.id)}>
              <span className={`lin-status-glyph s-${f.status}`} />
              <span className="lin-feat-id">{f.id}</span>
              <span className="lin-feat-title">{f.title}</span>
            </button>
          ))}
        </div>
      )}

      <button className="lin-side-newfeat">+ New feature in {proj.name}</button>

      <div className="lin-side-section lin-sessions">
        <div className="lin-side-head">
          <span>Live sessions</span>
          <span className="lin-side-pill">{window.SESSIONS.filter(s => {
            const f = window.FEATURES.find(x => x.id === s.feature);
            return f && f.project === openProject;
          }).length}</span>
        </div>
        {window.SESSIONS.filter(s => {
          const f = window.FEATURES.find(x => x.id === s.feature);
          return f && f.project === openProject;
        }).map(s => (
          <div key={s.id} className="lin-side-session">
            <span className={`lin-sess-dot dot-${s.state}`} />
            <span className="lin-sess-id">{s.id}</span>
            <span className="lin-sess-tick">{s.ticket}</span>
          </div>
        ))}
      </div>
    </aside>
  );
}

// ── Topbar ──────────────────────────────────────────────────────────────────
function LinTopbar({ view, setView, openProject, openFeature }) {
  const proj = window.PROJECTS.find(p => p.id === openProject);
  const feat = window.FEATURES.find(f => f.id === openFeature);

  let crumb = null;
  if (view === 'projects') {
    crumb = <><span>Workspace</span><span className="lin-crumb-sep">/</span><span className="lin-crumb-active">All projects</span></>;
  } else if (view === 'project') {
    crumb = <><span className="lin-crumb-link" onClick={() => setView('projects')}>Projects</span><span className="lin-crumb-sep">/</span><span className="lin-crumb-active">{proj.name}</span></>;
  } else if (view === 'feature' && feat) {
    crumb = <>
      <span className="lin-crumb-link" onClick={() => setView('projects')}>Projects</span>
      <span className="lin-crumb-sep">/</span>
      <span className="lin-crumb-link" onClick={() => setView('project')}>{proj.name}</span>
      <span className="lin-crumb-sep">/</span>
      <span className="lin-crumb-active">{feat.id} {feat.title}</span>
    </>;
  } else if (view === 'activity') {
    crumb = <><span className="lin-crumb-link" onClick={() => setView('project')}>{proj.name}</span><span className="lin-crumb-sep">/</span><span className="lin-crumb-active">Activity</span></>;
  }

  return (
    <div className="lin-topbar">
      <div className="lin-topbar-left">
        <div className="lin-crumbs">{crumb}</div>
      </div>
      <div className="lin-topbar-right">
        <button className="lin-icon-btn" title="Filter">⏚</button>
        <button className="lin-icon-btn" title="Sort">≡</button>
        <button className="lin-icon-btn" title="View options">⊞</button>
        <div className="lin-divider" />
        {view === 'projects' ? (
          <button className="lin-primary-btn">+ New project <span className="lin-kbd">P</span></button>
        ) : (
          <button className="lin-primary-btn">+ New feature <span className="lin-kbd">N</span></button>
        )}
      </div>
    </div>
  );
}

// ── Projects list (workspace-level) ─────────────────────────────────────────
function LinProjectsList({ onOpen }) {
  const projects = window.PROJECTS;
  return (
    <div className="lin-projects">
      <div className="lin-projects-head">
        <h1 className="lin-projects-title">Projects</h1>
        <p className="lin-projects-sub">Each project owns its own features, milestones, and sessions. {projects.length} total.</p>
      </div>
      <div className="lin-projects-grid">
        {projects.map(p => {
          const features = window.FEATURES.filter(f => f.project === p.id);
          const active = features.filter(f => f.status === 'in-progress' || f.status === 'review');
          return (
            <button key={p.id} className="lin-proj-card" onClick={() => onOpen(p.id)}>
              <div className="lin-proj-card-head">
                <span className={`lin-proj-mark pip-${p.accent}`}>{p.icon}</span>
                <span className="lin-proj-name">{p.name}</span>
                <span className={`lin-proj-status pst-${p.status}`}>{p.status}</span>
              </div>
              <div className="lin-proj-id">{p.id} · {p.repo}</div>
              <div className="lin-proj-tagline">{p.tagline}</div>
              <div className="lin-proj-stats">
                <div className="lin-proj-stat">
                  <span className="lin-proj-stat-n">{p.activeFeatures}</span>
                  <span className="lin-proj-stat-l">active</span>
                </div>
                <div className="lin-proj-stat">
                  <span className="lin-proj-stat-n">{p.totalFeatures}</span>
                  <span className="lin-proj-stat-l">features</span>
                </div>
                <div className="lin-proj-stat">
                  <span className="lin-proj-stat-n">{p.openTickets}</span>
                  <span className="lin-proj-stat-l">tickets</span>
                </div>
                <div className="lin-proj-stat">
                  <span className="lin-proj-stat-n">{p.liveSessions}</span>
                  <span className="lin-proj-stat-l">sessions</span>
                </div>
              </div>
              <div className="lin-proj-feats">
                {active.slice(0, 3).map(f => (
                  <div key={f.id} className="lin-proj-featrow">
                    <span className={`lin-status-glyph s-${f.status}`} />
                    <span className="lin-feat-id">{f.id}</span>
                    <span className="lin-feat-title">{f.title}</span>
                    <span className="lin-feat-prog">{Math.round(f.progress * 100)}%</span>
                  </div>
                ))}
                {active.length === 0 && <div className="lin-proj-empty">No active features</div>}
              </div>
              <div className="lin-proj-foot">
                <span className="lin-proj-touched">Last touched {p.lastTouched}</span>
                {p.pinned && <span className="lin-proj-pin">★ pinned</span>}
              </div>
            </button>
          );
        })}
        <button className="lin-proj-card lin-proj-newcard">
          <span className="lin-proj-new-glyph">+</span>
          <span className="lin-proj-new-label">New project</span>
          <span className="lin-proj-new-sub">PRJ-## auto-assigned</span>
        </button>
      </div>
    </div>
  );
}

// ── Project detail ──────────────────────────────────────────────────────────
function LinProjectDetail({ id, onOpenFeature, listMode }) {
  const p = window.PROJECTS.find(x => x.id === id);
  if (!p) return null;
  const features = window.FEATURES.filter(f => f.project === id);
  const tickets = window.TICKETS.filter(t => {
    const f = window.FEATURES.find(x => x.id === t.feature);
    return f && f.project === id;
  });
  const sessions = window.SESSIONS.filter(s => {
    const f = window.FEATURES.find(x => x.id === s.feature);
    return f && f.project === id;
  });
  const activity = window.ACTIVITY.filter(a => {
    const targetIsFeat = window.FEATURES.find(f => f.id === a.target && f.project === id);
    const targetIsTicket = window.TICKETS.find(t => t.id === a.target && features.some(f => f.id === t.feature));
    return targetIsFeat || targetIsTicket;
  });

  const groups = [
    { id: 'in-progress', label: 'In progress' },
    { id: 'review', label: 'In review' },
    { id: 'planned', label: 'Planned' },
    { id: 'shipped', label: 'Shipped' },
  ];

  return (
    <div className="lin-pd">
      <div className="lin-pd-head">
        <div className="lin-pd-headline">
          <span className={`lin-proj-mark lin-proj-mark-lg pip-${p.accent}`}>{p.icon}</span>
          <div className="lin-pd-titles">
            <div className="lin-pd-name">{p.name} <span className="lin-pd-id">{p.id}</span></div>
            <div className="lin-pd-tag">{p.tagline}</div>
          </div>
        </div>
        <div className="lin-pd-actions">
          <button className="lin-ghost-btn">Open repo</button>
          <button className="lin-ghost-btn">Settings</button>
          <button className="lin-primary-btn">+ Feature</button>
        </div>
      </div>

      <div className="lin-pd-meta">
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Status</div>
          <div className="lin-meta-v"><span className={`lin-proj-status pst-${p.status}`}>{p.status}</span></div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Repo</div>
          <div className="lin-meta-v lin-mono-cell">{p.repo}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Features</div>
          <div className="lin-meta-v">{features.length} <span className="lin-meta-sub">({p.activeFeatures} active)</span></div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Open tickets</div>
          <div className="lin-meta-v">{tickets.filter(t => t.status !== 'done').length}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Live sessions</div>
          <div className="lin-meta-v">{sessions.length}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Last touched</div>
          <div className="lin-meta-v">{p.lastTouched}</div>
        </div>
      </div>

      <div className="lin-pd-body">
        <div className="lin-pd-col-main">
          <section className="lin-pane">
            <header className="lin-pane-head">
              <span className="lin-pane-title">About</span>
              <span className="lin-pane-meta">project description</span>
            </header>
            <div className="lin-pane-body lin-prose">
              <p>{p.description}</p>
            </div>
          </section>

          <section className="lin-pane">
            <header className="lin-pane-head">
              <span className="lin-pane-title">Features</span>
              <span className="lin-pane-meta">{features.length} total · grouped by status</span>
              <span className="lin-pane-spacer" />
              <button className="lin-mini-btn">+ New</button>
            </header>
            {groups.map(g => {
              const rows = features.filter(f => f.status === g.id);
              if (rows.length === 0) return null;
              return (
                <div key={g.id} className="lin-pd-fgroup">
                  <header className="lin-group-head">
                    <span className={`lin-status-glyph s-${g.id}`} />
                    <span className="lin-group-name">{g.label}</span>
                    <span className="lin-group-count">{rows.length}</span>
                  </header>
                  <div className="lin-rows">
                    {rows.map(f => {
                      const fTickets = window.TICKETS.filter(t => t.feature === f.id);
                      return (
                        <div key={f.id} className="lin-row lin-frow" onClick={() => onOpenFeature(f.id)}>
                          <span className={`lin-status-glyph s-${f.status}`} />
                          <span className="lin-tid">{f.id}</span>
                          <span className="lin-row-title">{f.title}</span>
                          <span className="lin-row-meta lin-meta-milestone">{f.milestone.split(' — ')[0]}</span>
                          <span className="lin-row-meta">
                            <span className="lin-progbar lin-progbar-inline"><span style={{ width: `${Math.round(f.progress * 100)}%` }} /></span>
                            <span className="lin-meta-num">{Math.round(f.progress * 100)}%</span>
                          </span>
                          <span className="lin-row-meta">{f.ticketsDone}/{f.tickets} tk</span>
                          <span className="lin-row-meta lin-meta-sess">
                            {f.sessions > 0 ? <span className="lin-sess-tag">● {f.sessions}</span> : ''}
                          </span>
                          <span className="lin-row-meta lin-meta-when">{f.lastTouched}</span>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </section>
        </div>

        <div className="lin-pd-col-side">
          <section className="lin-pane">
            <header className="lin-pane-head"><span className="lin-pane-title">Live sessions</span></header>
            <div className="lin-pane-body lin-pane-rows">
              {sessions.length === 0 && <div className="lin-empty">No live sessions in this project.</div>}
              {sessions.map(s => {
                const t = window.TICKETS.find(x => x.id === s.ticket);
                return (
                  <div key={s.id} className="lin-session-row">
                    <span className={`lin-sess-dot dot-${s.state}`} />
                    <div className="lin-sess-meta">
                      <div className="lin-sess-id">{s.id}</div>
                      <div className="lin-sess-sub">{s.ticket} · {s.pane} · {s.uptime}</div>
                    </div>
                    <button className="lin-mini-btn">Attach</button>
                  </div>
                );
              })}
            </div>
          </section>

          <section className="lin-pane">
            <header className="lin-pane-head"><span className="lin-pane-title">Recent activity</span></header>
            <div className="lin-pane-body lin-feed lin-feed-compact">
              {activity.slice(0, 7).map(a => (
                <div key={a.id} className="lin-feed-row">
                  <span className={`lin-feed-glyph k-${a.kind}`} />
                  <div className="lin-feed-line">
                    <span className={`lin-feed-actor ${a.actor}`}>{a.name}</span>{' '}
                    <span className="lin-feed-verb">{a.verb}</span>{' '}
                    <span className="lin-feed-target">{a.target}</span>
                  </div>
                  <span className="lin-feed-when">{a.when}</span>
                </div>
              ))}
              {activity.length === 0 && <div className="lin-empty">No recent activity.</div>}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

// ── Feature detail (unchanged spine; project crumb already handled in topbar) ──
function LinFeatureDetail({ id }) {
  const f = window.FEATURES.find(x => x.id === id);
  if (!f) return null;
  const proj = window.PROJECTS.find(p => p.id === f.project);
  const tickets = window.TICKETS.filter(t => t.feature === id);
  const sessions = window.SESSIONS.filter(s => s.feature === id);
  const activity = window.ACTIVITY.filter(a => a.target === id || tickets.some(t => t.id === a.target));
  const [tab, setTab] = React.useState('overview');

  return (
    <div className="lin-fd">
      <div className="lin-fd-head">
        <div className="lin-fd-headline">
          <span className={`lin-fd-pip pip-${f.accent}`} />
          <span className="lin-fd-id">{f.id}</span>
          <span className="lin-fd-title">{f.title}</span>
          <span className="lin-fd-projchip"><span className={`lin-projswitch-mark pip-${proj.accent}`}>{proj.icon}</span>{proj.name}</span>
        </div>
        <div className="lin-fd-actions">
          <button className="lin-ghost-btn">Spawn session</button>
          <button className="lin-ghost-btn">+ Ticket</button>
          <button className="lin-primary-btn">Mark for review</button>
        </div>
      </div>

      <div className="lin-fd-meta">
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Status</div>
          <div className="lin-meta-v"><span className={`lin-status-glyph s-${f.status}`} />{window.STATUS_LABEL[f.status]}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Project</div>
          <div className="lin-meta-v">{proj.name}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Milestone</div>
          <div className="lin-meta-v">{f.milestone}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Target</div>
          <div className="lin-meta-v">{f.target}</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Progress</div>
          <div className="lin-meta-v">
            <div className="lin-progbar"><span style={{ width: `${Math.round(f.progress * 100)}%` }} /></div>
            <span className="lin-meta-num">{Math.round(f.progress * 100)}%</span>
          </div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Tickets</div>
          <div className="lin-meta-v">{f.ticketsDone}/{f.tickets} done</div>
        </div>
        <div className="lin-meta-cell">
          <div className="lin-meta-k">Sessions</div>
          <div className="lin-meta-v">{f.sessions} live</div>
        </div>
      </div>

      <div className="lin-fd-tabs">
        {['overview', 'tickets', 'docs', 'sessions', 'review', 'decisions'].map(t => (
          <button key={t} className={`lin-fd-tab ${tab === t ? 'is-active' : ''}`} onClick={() => setTab(t)}>
            {t.charAt(0).toUpperCase() + t.slice(1)}
            {t === 'tickets' && <span className="lin-tab-count">{tickets.length}</span>}
            {t === 'sessions' && <span className="lin-tab-count">{sessions.length}</span>}
          </button>
        ))}
      </div>

      <div className="lin-fd-body">
        {tab === 'overview' && <LinFDOverview f={f} tickets={tickets} sessions={sessions} activity={activity} />}
        {tab === 'tickets' && <LinFDTickets tickets={tickets} f={f} />}
        {tab === 'docs' && <LinFDDocs f={f} />}
        {tab === 'sessions' && <LinFDSessions sessions={sessions} tickets={tickets} />}
        {tab === 'review' && <LinFDReview tickets={tickets.filter(t => t.status === 'review')} />}
        {tab === 'decisions' && <LinFDDecisions />}
      </div>
    </div>
  );
}

function LinFDOverview({ f, tickets, sessions, activity }) {
  return (
    <div className="lin-fd-overview">
      <div className="lin-fd-col lin-fd-col-main">
        <section className="lin-pane">
          <header className="lin-pane-head">
            <span className="lin-pane-title">Vision</span>
            <span className="lin-pane-meta">edited 1h ago · you</span>
          </header>
          <div className="lin-pane-body lin-prose">
            <p>{f.vision}</p>
          </div>
        </section>

        <section className="lin-pane">
          <header className="lin-pane-head">
            <span className="lin-pane-title">PRD</span>
            <span className="lin-pane-meta">2 sections · 480 words · session-05</span>
            <span className="lin-pane-spacer" />
            <button className="lin-mini-btn">Open</button>
          </header>
          <div className="lin-pane-body lin-prose">
            <h4>Problem</h4>
            <p>Sessions today lose context on resume. The agent can read the repo, but plan, intent, and prior decisions evaporate. The fix: bind every session to its feature's full context bundle (PRD, eng design, decisions, acceptance criteria) and re-inject on resume.</p>
            <h4>Goals</h4>
            <ul>
              <li>Resuming a session restores plan + decisions in one boot.</li>
              <li>Editing a doc updates all sessions still attached to the feature.</li>
              <li>No manual “paste this prompt” step.</li>
            </ul>
          </div>
        </section>

        <section className="lin-pane">
          <header className="lin-pane-head">
            <span className="lin-pane-title">Tickets</span>
            <span className="lin-pane-meta">{f.ticketsDone}/{f.tickets} done</span>
          </header>
          <div className="lin-pane-body lin-pane-rows">
            {tickets.map(t => (
              <div key={t.id} className="lin-row lin-row-compact">
                <span className={`lin-status-glyph s-${t.status}`} />
                <span className="lin-tid">{t.id}</span>
                <span className="lin-row-title">{t.title}</span>
                <span className="lin-row-meta">{t.criteriaDone}/{t.criteria}</span>
                <span className="lin-row-meta lin-meta-est">{t.estimate}</span>
                <span className="lin-row-meta lin-meta-when">{t.updated}</span>
              </div>
            ))}
          </div>
        </section>
      </div>

      <div className="lin-fd-col lin-fd-col-side">
        <section className="lin-pane">
          <header className="lin-pane-head"><span className="lin-pane-title">Live sessions</span></header>
          <div className="lin-pane-body lin-pane-rows">
            {sessions.length === 0 && <div className="lin-empty">No live sessions.</div>}
            {sessions.map(s => (
              <div key={s.id} className="lin-session-row">
                <span className={`lin-sess-dot dot-${s.state}`} />
                <div className="lin-sess-meta">
                  <div className="lin-sess-id">{s.id}</div>
                  <div className="lin-sess-sub">{s.ticket} · {s.pane} · {s.uptime}</div>
                </div>
                <button className="lin-mini-btn">Attach</button>
              </div>
            ))}
            <button className="lin-add-row">+ Spawn session for ticket</button>
          </div>
        </section>

        <section className="lin-pane">
          <header className="lin-pane-head"><span className="lin-pane-title">Recent activity</span></header>
          <div className="lin-pane-body lin-feed lin-feed-compact">
            {activity.slice(0, 6).map(a => (
              <div key={a.id} className="lin-feed-row">
                <span className={`lin-feed-glyph k-${a.kind}`} />
                <div className="lin-feed-line">
                  <span className={`lin-feed-actor ${a.actor}`}>{a.name}</span>{' '}
                  <span className="lin-feed-verb">{a.verb}</span>{' '}
                  <span className="lin-feed-target">{a.target}</span>
                </div>
                <span className="lin-feed-when">{a.when}</span>
              </div>
            ))}
          </div>
        </section>

        <section className="lin-pane">
          <header className="lin-pane-head"><span className="lin-pane-title">Decisions</span></header>
          <div className="lin-pane-body lin-prose-sm">
            <div className="lin-dec">
              <div className="lin-dec-when">today · session-05</div>
              <div className="lin-dec-text">Use slug+sha as bundle key, not branch name. Branches are derived; bundles must outlive them.</div>
            </div>
            <div className="lin-dec">
              <div className="lin-dec-when">2d ago · you</div>
              <div className="lin-dec-text">PRD lives in‐repo at <code>.tmx/&lt;feat-id&gt;/prd.md</code>. Single source of truth.</div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function LinFDTickets({ tickets, f }) {
  const groups = [
    { id: 'doing', label: 'In progress' },
    { id: 'review', label: 'In review' },
    { id: 'todo', label: 'Todo' },
  ];
  return (
    <div className="lin-fd-tickets">
      {groups.map(g => {
        const rows = tickets.filter(t => t.status === g.id);
        if (rows.length === 0) return null;
        return (
          <section key={g.id} className="lin-group">
            <header className="lin-group-head">
              <span className={`lin-status-glyph s-${g.id}`} />
              <span className="lin-group-name">{g.label}</span>
              <span className="lin-group-count">{rows.length}</span>
            </header>
            <div className="lin-rows">
              {rows.map(t => (
                <div key={t.id} className="lin-row">
                  <span className={`lin-status-glyph s-${t.status}`} />
                  <span className="lin-tid">{t.id}</span>
                  <span className="lin-row-title">{t.title}</span>
                  <span className="lin-row-meta lin-meta-est">{t.estimate}</span>
                  <span className="lin-row-meta">{t.criteriaDone}/{t.criteria}</span>
                  <span className="lin-row-meta lin-meta-sess">
                    {t.sessions > 0 ? <span className="lin-sess-tag">● {t.sessions}</span> : ''}
                  </span>
                  <span className="lin-row-meta lin-meta-when">{t.updated}</span>
                </div>
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}

function LinFDDocs({ f }) {
  const docs = [
    { name: 'Vision', kind: 'note', updated: '3d ago', words: 84 },
    { name: 'PRD', kind: 'prd', updated: '1h ago', words: 482 },
    { name: 'Eng design', kind: 'design', updated: '5h ago', words: 1408 },
    { name: 'Ideation scratch', kind: 'note', updated: 'yesterday', words: 220 },
    { name: 'Decisions', kind: 'log', updated: '1h ago', words: 96 },
  ];
  return (
    <div className="lin-fd-docs">
      <div className="lin-doctree">
        {docs.map(d => (
          <div key={d.name} className={`lin-doctree-row ${d.name === 'PRD' ? 'is-active' : ''}`}>
            <span className={`lin-doc-glyph d-${d.kind}`}>¶</span>
            <span className="lin-doc-name">{d.name}</span>
            <span className="lin-doc-meta">{d.words}w · {d.updated}</span>
          </div>
        ))}
        <button className="lin-add-row">+ New doc</button>
      </div>
      <div className="lin-doc-editor">
        <div className="lin-doc-toolbar">
          <span className="lin-doc-bcrumb">PRD</span>
          <span className="lin-doc-bcrumb-sep">·</span>
          <span className="lin-doc-saved">Saved · 1h ago</span>
          <span className="lin-spacer" />
          <button className="lin-mini-btn">Inject into session</button>
        </div>
        <div className="lin-doc-canvas">
          <h1>PRD — {f.title}</h1>
          <div className="lin-doc-block lin-doc-h">
            <span className="lin-doc-handle">⋮⋮</span>
            <h2>Problem</h2>
          </div>
          <div className="lin-doc-block">
            <span className="lin-doc-handle">⋮⋮</span>
            <p>Each agent session lives inside a tmux pane. Today the pane has the repo, but the <em>plan</em> — PRD, decisions, acceptance criteria — exists only in whatever was pasted into the prompt at boot. After a context reset, that's gone.</p>
          </div>
          <div className="lin-doc-block lin-doc-h">
            <span className="lin-doc-handle">⋮⋮</span>
            <h2>Goals</h2>
          </div>
          <div className="lin-doc-block">
            <span className="lin-doc-handle">⋮⋮</span>
            <ul>
              <li>Resuming a session restores plan + decisions in a single boot step.</li>
              <li>Editing a doc updates every session still attached to the feature.</li>
              <li>No manual “paste this prompt” step from the human.</li>
            </ul>
          </div>
          <div className="lin-doc-block lin-doc-callout">
            <span className="lin-doc-handle">⋮⋮</span>
            <div>
              <div className="lin-doc-callout-head">Open question</div>
              <div>Bundle on every prompt or only on resume? Token cost vs drift.</div>
            </div>
          </div>
          <div className="lin-doc-block lin-doc-empty">
            <span className="lin-doc-slash">/</span> type to insert a block
          </div>
        </div>
      </div>
    </div>
  );
}

function LinFDSessions({ sessions, tickets }) {
  return (
    <div className="lin-fd-sessions">
      <div className="lin-rows">
        {sessions.map(s => {
          const t = tickets.find(x => x.id === s.ticket);
          return (
            <div key={s.id} className="lin-row lin-session-tall">
              <span className={`lin-sess-dot dot-${s.state}`} />
              <span className="lin-tid">{s.id}</span>
              <span className="lin-row-title">{t ? t.title : '—'}</span>
              <span className="lin-row-meta">{s.ticket}</span>
              <span className="lin-row-meta">{s.pane}</span>
              <span className="lin-row-meta">{s.state}</span>
              <span className="lin-row-meta lin-meta-when">{s.uptime}</span>
              <button className="lin-mini-btn">Attach</button>
            </div>
          );
        })}
      </div>
      <button className="lin-add-row">+ Spawn session for ticket</button>
    </div>
  );
}

function LinFDReview({ tickets }) {
  return (
    <div className="lin-fd-review">
      {tickets.map(t => (
        <section key={t.id} className="lin-pane lin-review-card">
          <header className="lin-pane-head">
            <span className={`lin-status-glyph s-review`} />
            <span className="lin-tid">{t.id}</span>
            <span className="lin-pane-title">{t.title}</span>
            <span className="lin-pane-spacer" />
            <span className="lin-pane-meta">+412 / −37 · 9 files</span>
          </header>
          <div className="lin-review-body">
            <div className="lin-diff">
              <div className="lin-diff-head">internal/pane/registry.go</div>
              <pre className="lin-diff-pre">
<span className="d-ctx">  func (r *Registry) Attach(id string) (*Pane, error) &#123;</span>{'\n'}
<span className="d-ctx">    r.mu.Lock()</span>{'\n'}
<span className="d-ctx">    defer r.mu.Unlock()</span>{'\n'}
<span className="d-rem">-   if p, ok := r.byID[id]; ok &#123;</span>{'\n'}
<span className="d-rem">-     return p, nil</span>{'\n'}
<span className="d-rem">-   &#125;</span>{'\n'}
<span className="d-add">+   if p, ok := r.byID[id]; ok &amp;&amp; !p.Stale() &#123;</span>{'\n'}
<span className="d-add">+     return p, nil</span>{'\n'}
<span className="d-add">+   &#125;</span>{'\n'}
<span className="d-add">+   p, err := r.spawn(id)</span>{'\n'}
<span className="d-add">+   if err != nil &#123; return nil, err &#125;</span>{'\n'}
<span className="d-ctx">    return p, nil</span>{'\n'}
<span className="d-ctx">  &#125;</span>
              </pre>
            </div>
            <div className="lin-checklist">
              <div className="lin-checklist-head">Acceptance criteria</div>
              {[
                ['Stale panes are re-spawned, not reused', true],
                ['Concurrent attach is safe (TestRace passes)', true],
                ['Attach returns within 50ms p99', true],
                ['Telemetry event on respawn', false],
              ].map(([label, done], i) => (
                <label key={i} className={`lin-check ${done ? 'is-done' : ''}`}>
                  <span className="lin-check-box">{done ? '✓' : ''}</span>
                  <span>{label}</span>
                </label>
              ))}
              <div className="lin-review-actions">
                <button className="lin-ghost-btn">Send back</button>
                <button className="lin-ghost-btn">Comment</button>
                <button className="lin-primary-btn">Approve & merge</button>
              </div>
            </div>
          </div>
        </section>
      ))}
    </div>
  );
}

function LinFDDecisions() {
  const decisions = [
    { d: 'today · session-05', t: 'Use slug+sha as bundle key, not branch name', body: 'Branches are derived metadata; the bundle must survive renames, squash-merges, and worktree moves.' },
    { d: '2d ago · you', t: 'PRD lives in-repo at .tmx/<feat-id>/prd.md', body: 'Single source of truth. Editor writes through to the file. Sessions read from the same path.' },
    { d: '4d ago · you', t: 'Sessions are spawned FROM tickets, not features', body: 'Features can have N tickets; conflating them at session level made the pane multiplexer ambiguous.' },
  ];
  return (
    <div className="lin-fd-decisions">
      {decisions.map((d, i) => (
        <article key={i} className="lin-pane lin-dec-card">
          <header className="lin-pane-head">
            <span className="lin-pane-title">{d.t}</span>
            <span className="lin-pane-spacer" />
            <span className="lin-pane-meta">{d.d}</span>
          </header>
          <div className="lin-pane-body lin-prose-sm">{d.body}</div>
        </article>
      ))}
      <button className="lin-add-row">+ Log decision</button>
    </div>
  );
}

// ── Activity feed ───────────────────────────────────────────────────────────
function LinActivity() {
  const groups = [
    { label: 'Today', rows: window.ACTIVITY.slice(0, 6) },
    { label: 'Yesterday', rows: window.ACTIVITY.slice(6) },
  ];
  return (
    <div className="lin-activity">
      <div className="lin-filter-bar">
        <span className="lin-filter-chip is-active">All</span>
        <span className="lin-filter-chip">Agent</span>
        <span className="lin-filter-chip">You</span>
        <span className="lin-filter-chip">Reviews</span>
        <span className="lin-filter-chip">Decisions</span>
        <span className="lin-filter-spacer" />
        <span className="lin-filter-meta">{window.ACTIVITY.length} events · last 24h</span>
      </div>
      {groups.map(g => (
        <section key={g.label} className="lin-act-group">
          <header className="lin-act-day">{g.label}</header>
          <div className="lin-feed">
            {g.rows.map(a => (
              <div key={a.id} className="lin-feed-row lin-feed-row-tall">
                <span className={`lin-feed-glyph k-${a.kind}`} />
                <div className="lin-feed-body">
                  <div className="lin-feed-line">
                    <span className={`lin-feed-actor ${a.actor}`}>{a.name}</span>{' '}
                    <span className="lin-feed-verb">{a.verb}</span>{' '}
                    <span className="lin-feed-target">{a.target}</span>
                  </div>
                  {a.detail && <div className="lin-feed-detail">{a.detail}</div>}
                </div>
                <span className="lin-feed-when">{a.when} ago</span>
              </div>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}

Object.assign(window, { LinearHub });

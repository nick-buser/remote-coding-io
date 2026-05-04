// Notion-esque PM hub — doc-centric, roomier, generous whitespace.
// Same data, different organization: feature page is the spine, with sidebar tree
// and inline doc-style content blocks (PRD, tickets-as-database, decisions, activity).

const notionStyles = {
  shell: {
    width: '100%',
    height: '100%',
    background: 'var(--n-bg)',
    color: 'var(--n-fg)',
    fontFamily: 'var(--ui-font)',
    fontSize: 14,
    lineHeight: 1.55,
    display: 'grid',
    gridTemplateColumns: '260px 1fr',
    overflow: 'hidden',
  },
};

function NotionHub({ accent = 'iris', listMode = 'row' }) {
  const [view, setView] = React.useState('feature');
  const [openFeature, setOpenFeature] = React.useState('FEAT-019');

  return (
    <div className="not-shell" style={notionStyles.shell} data-accent={accent}>
      <NotSidebar view={view} setView={setView} openFeature={openFeature} setOpenFeature={setOpenFeature} />
      <main className="not-main">
        {view === 'backlog' && <NotBacklog listMode={listMode} onOpen={(f) => { setOpenFeature(f); setView('feature'); }} />}
        {view === 'roadmap' && <NotRoadmap onOpen={(f) => { setOpenFeature(f); setView('feature'); }} />}
        {view === 'feature' && <NotFeaturePage id={openFeature} />}
        {view === 'activity' && <NotActivity />}
      </main>
    </div>
  );
}

function NotSidebar({ view, setView, openFeature, setOpenFeature }) {
  const features = window.FEATURES;
  const inFlight = features.filter(f => f.status === 'in-progress' || f.status === 'review');
  const planned = features.filter(f => f.status === 'planned');
  const shipped = features.filter(f => f.status === 'shipped');

  return (
    <aside className="not-sidebar">
      <div className="not-workspace">
        <div className="not-ws-mark">◐</div>
        <div className="not-ws-name">tmux-agent</div>
        <span className="not-ws-sub">solo workspace</span>
      </div>

      <div className="not-search">
        <span>⌕</span>
        <input placeholder="Search docs, tickets…" />
      </div>

      <nav className="not-nav">
        <button className={`not-nav-row ${view === 'backlog' ? 'is-active' : ''}`} onClick={() => setView('backlog')}>
          <span className="not-nav-glyph">☰</span> Backlog
        </button>
        <button className={`not-nav-row ${view === 'roadmap' ? 'is-active' : ''}`} onClick={() => setView('roadmap')}>
          <span className="not-nav-glyph">◫</span> Roadmap
        </button>
        <button className={`not-nav-row ${view === 'activity' ? 'is-active' : ''}`} onClick={() => setView('activity')}>
          <span className="not-nav-glyph">⌁</span> Activity
        </button>
      </nav>

      <div className="not-tree">
        <div className="not-tree-head">Features</div>

        <div className="not-tree-group">
          <div className="not-tree-grouphead">▾ In flight</div>
          {inFlight.map(f => (
            <NotTreeFeature key={f.id} f={f} active={openFeature === f.id && view === 'feature'}
              onOpen={() => { setOpenFeature(f.id); setView('feature'); }} expanded={f.id === 'FEAT-019'} />
          ))}
        </div>

        <div className="not-tree-group">
          <div className="not-tree-grouphead">▸ Planned</div>
          {planned.map(f => (
            <NotTreeFeature key={f.id} f={f} active={openFeature === f.id && view === 'feature'}
              onOpen={() => { setOpenFeature(f.id); setView('feature'); }} />
          ))}
        </div>

        <div className="not-tree-group">
          <div className="not-tree-grouphead">▸ Shipped</div>
          {shipped.map(f => (
            <NotTreeFeature key={f.id} f={f} active={openFeature === f.id && view === 'feature'}
              onOpen={() => { setOpenFeature(f.id); setView('feature'); }} muted />
          ))}
        </div>
      </div>

      <div className="not-side-foot">
        <div className="not-foot-head">Live sessions</div>
        {window.SESSIONS.map(s => (
          <div key={s.id} className="not-foot-sess">
            <span className={`not-sess-dot dot-${s.state}`} />
            <span className="not-sess-id">{s.id}</span>
            <span className="not-sess-ticket">{s.ticket}</span>
          </div>
        ))}
      </div>
    </aside>
  );
}

function NotTreeFeature({ f, active, onOpen, expanded, muted }) {
  return (
    <div className={`not-tree-feat ${active ? 'is-active' : ''} ${muted ? 'is-muted' : ''}`}>
      <button className="not-tree-row" onClick={onOpen}>
        <span className="not-tree-toggle">{expanded ? '▾' : '▸'}</span>
        <span className={`not-feat-pip pip-${f.accent}`} />
        <span className="not-tree-name">{f.title}</span>
      </button>
      {expanded && (
        <div className="not-tree-children">
          <div className="not-tree-subrow">¶ Vision</div>
          <div className="not-tree-subrow">¶ PRD</div>
          <div className="not-tree-subrow">¶ Eng design</div>
          <div className="not-tree-subrow">⌗ Tickets <span className="not-tree-ct">{f.tickets}</span></div>
          <div className="not-tree-subrow">⌁ Decisions</div>
        </div>
      )}
    </div>
  );
}

// ── Feature page (the marquee) ──────────────────────────────────────────────
function NotFeaturePage({ id }) {
  const f = window.FEATURES.find(x => x.id === id);
  if (!f) return null;
  const tickets = window.TICKETS.filter(t => t.feature === id);
  const sessions = window.SESSIONS.filter(s => s.feature === id);
  const activity = window.ACTIVITY.filter(a => a.target === id || tickets.some(t => t.id === a.target));

  return (
    <div className="not-page">
      <div className="not-page-crumbs">
        <span>Features</span><span className="not-crumb-sep">›</span>
        <span>In flight</span><span className="not-crumb-sep">›</span>
        <span className="not-crumb-active">{f.title}</span>
      </div>

      <header className="not-page-head">
        <div className="not-page-cover">
          <div className={`not-page-cover-stripes cover-${f.accent}`} />
        </div>
        <div className="not-page-icon">◐</div>
        <h1 className="not-page-title">{f.title}</h1>
        <div className="not-page-id">{f.id}</div>
      </header>

      <div className="not-props">
        <div className="not-prop"><span className="not-prop-k">Status</span><span className="not-prop-v"><span className={`not-pill p-${f.status}`}>{window.STATUS_LABEL[f.status]}</span></span></div>
        <div className="not-prop"><span className="not-prop-k">Milestone</span><span className="not-prop-v">{f.milestone}</span></div>
        <div className="not-prop"><span className="not-prop-k">Target</span><span className="not-prop-v">{f.target}</span></div>
        <div className="not-prop"><span className="not-prop-k">Progress</span>
          <span className="not-prop-v">
            <div className="not-progbar"><span style={{ width: `${Math.round(f.progress * 100)}%` }} /></div>
            <span className="not-prog-num">{Math.round(f.progress * 100)}%</span>
          </span>
        </div>
        <div className="not-prop"><span className="not-prop-k">Tags</span><span className="not-prop-v">{f.tags.map(t => <span key={t} className="not-tag">{t}</span>)}</span></div>
        <div className="not-prop"><span className="not-prop-k">Sessions</span><span className="not-prop-v">{f.sessions} live</span></div>
      </div>

      {/* Vision callout */}
      <section className="not-block not-block-callout">
        <span className="not-block-handle">⋮⋮</span>
        <div>
          <div className="not-callout-head">Vision</div>
          <p>{f.vision}</p>
        </div>
      </section>

      {/* PRD section */}
      <NotPRDBlock />

      {/* Tickets database */}
      <NotTicketsDB tickets={tickets} f={f} />

      {/* Sessions block */}
      <NotSessionsBlock sessions={sessions} tickets={tickets} />

      {/* Decisions */}
      <NotDecisionsBlock />

      {/* Activity */}
      <NotActivityBlock activity={activity} />

      <div className="not-block not-add-block">
        <span>+ Add block · type / for commands</span>
      </div>
    </div>
  );
}

function NotPRDBlock() {
  return (
    <>
      <h2 className="not-h2">📄 PRD</h2>
      <section className="not-block">
        <span className="not-block-handle">⋮⋮</span>
        <div>
          <h3 className="not-h3">Problem</h3>
          <p>Each agent session lives inside a tmux pane. Today the pane has the repo, but the <em>plan</em> — PRD, decisions, acceptance criteria — exists only in whatever was pasted into the prompt at boot. After a context reset, that's gone.</p>
        </div>
      </section>
      <section className="not-block">
        <span className="not-block-handle">⋮⋮</span>
        <div>
          <h3 className="not-h3">Goals</h3>
          <ul className="not-list">
            <li>Resuming a session restores plan + decisions in a single boot step.</li>
            <li>Editing a doc updates every session still attached to the feature.</li>
            <li>No manual "paste this prompt" step from the human.</li>
          </ul>
        </div>
      </section>
      <section className="not-block not-block-toggle">
        <span className="not-block-handle">⋮⋮</span>
        <div>
          <div className="not-toggle-head">▾ Eng design — bundle resolution algorithm</div>
          <div className="not-toggle-body">
            <p>On session boot, walk <code>.tmx/&lt;feat-id&gt;/</code> in the active worktree. Hash content; cache by <code>slug+sha</code>. If cache miss, re-render from markdown. Inject as a system message preamble.</p>
          </div>
        </div>
      </section>
    </>
  );
}

function NotTicketsDB({ tickets, f }) {
  return (
    <>
      <h2 className="not-h2">⌗ Tickets <span className="not-h2-sub">{f.ticketsDone} / {f.tickets} done</span></h2>
      <div className="not-db">
        <div className="not-db-tabs">
          <span className="not-db-tab is-active">⊟ Table</span>
          <span className="not-db-tab">▤ Board</span>
          <span className="not-db-tab">⌁ Timeline</span>
          <span className="not-db-spacer" />
          <span className="not-db-filter">Filter</span>
          <span className="not-db-filter">Sort</span>
          <span className="not-db-new">+ New</span>
        </div>
        <div className="not-db-table">
          <div className="not-db-head">
            <span className="col-id">ID</span>
            <span className="col-title">Title</span>
            <span className="col-status">Status</span>
            <span className="col-crit">Criteria</span>
            <span className="col-est">Size</span>
            <span className="col-sess">Sessions</span>
            <span className="col-when">Updated</span>
          </div>
          {tickets.map(t => (
            <div key={t.id} className="not-db-row">
              <span className="col-id"><span className="not-tid">{t.id}</span></span>
              <span className="col-title">{t.title}</span>
              <span className="col-status"><span className={`not-pill p-${t.status}`}>{window.STATUS_LABEL[t.status]}</span></span>
              <span className="col-crit">
                <div className="not-crit-bar"><span style={{ width: `${(t.criteriaDone/t.criteria)*100}%` }} /></div>
                <span className="not-crit-num">{t.criteriaDone}/{t.criteria}</span>
              </span>
              <span className="col-est"><span className="not-chip">{t.estimate}</span></span>
              <span className="col-sess">{t.sessions > 0 ? <span className="not-sess-tag">● {t.sessions}</span> : <span className="not-muted">—</span>}</span>
              <span className="col-when">{t.updated}</span>
            </div>
          ))}
          <div className="not-db-row not-db-add">+ New ticket</div>
        </div>
      </div>
    </>
  );
}

function NotSessionsBlock({ sessions, tickets }) {
  return (
    <>
      <h2 className="not-h2">⌬ Sessions <span className="not-h2-sub">spawned from tickets</span></h2>
      <div className="not-sess-grid">
        {sessions.map(s => {
          const t = tickets.find(x => x.id === s.ticket);
          return (
            <div key={s.id} className="not-sess-card">
              <div className="not-sess-row">
                <span className={`not-sess-dot dot-${s.state}`} />
                <span className="not-sess-id">{s.id}</span>
                <span className="not-sess-state">{s.state}</span>
              </div>
              <div className="not-sess-tick">{t ? t.title : '—'}</div>
              <div className="not-sess-meta">
                <span>{s.ticket}</span><span>·</span><span>{s.pane}</span><span>·</span><span>up {s.uptime}</span>
              </div>
              <div className="not-sess-actions">
                <button className="not-mini-btn">Attach</button>
                <button className="not-mini-btn">Inject context</button>
              </div>
            </div>
          );
        })}
        <button className="not-sess-add">+ Spawn session</button>
      </div>
    </>
  );
}

function NotDecisionsBlock() {
  const decisions = [
    { d: 'today · session-05', t: 'Use slug+sha as bundle key, not branch name', body: 'Branches are derived metadata. The bundle must outlive renames, squash-merges, and worktree moves.' },
    { d: '2d ago · you', t: 'PRD lives in-repo at .tmx/<feat-id>/prd.md', body: 'Single source of truth. Editor writes through to the file; sessions read from the same path.' },
    { d: '4d ago · you', t: 'Sessions are spawned FROM tickets, not features', body: 'A feature can have N tickets; conflating them at session level made the pane multiplexer ambiguous.' },
  ];
  return (
    <>
      <h2 className="not-h2">⌁ Decisions</h2>
      <div className="not-dec-list">
        {decisions.map((d, i) => (
          <div key={i} className="not-block not-dec-block">
            <span className="not-block-handle">⋮⋮</span>
            <div>
              <div className="not-dec-head">
                <span className="not-dec-title">{d.t}</span>
                <span className="not-dec-when">{d.d}</span>
              </div>
              <p>{d.body}</p>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

function NotActivityBlock({ activity }) {
  return (
    <>
      <h2 className="not-h2">⌁ Activity <span className="not-h2-sub">last 24h</span></h2>
      <div className="not-act-list">
        {activity.slice(0, 6).map(a => (
          <div key={a.id} className="not-act-row">
            <span className={`not-act-glyph k-${a.kind}`} />
            <div className="not-act-body">
              <div className="not-act-line">
                <span className={`not-act-actor ${a.actor}`}>{a.name}</span>{' '}
                <span className="not-act-verb">{a.verb}</span>{' '}
                <span className="not-act-target">{a.target}</span>
              </div>
              {a.detail && <div className="not-act-detail">{a.detail}</div>}
            </div>
            <span className="not-act-when">{a.when} ago</span>
          </div>
        ))}
      </div>
    </>
  );
}

// ── Backlog (database table view) ───────────────────────────────────────────
function NotBacklog({ listMode, onOpen }) {
  const tickets = window.TICKETS;
  const featById = Object.fromEntries(window.FEATURES.map(f => [f.id, f]));
  return (
    <div className="not-page">
      <h1 className="not-page-title not-page-title-tight">Backlog</h1>
      <p className="not-lede">All tickets across every in-flight feature, grouped by status.</p>
      <div className="not-db">
        <div className="not-db-tabs">
          <span className="not-db-tab is-active">⊟ Table</span>
          <span className="not-db-tab">▤ Board</span>
          <span className="not-db-spacer" />
          <span className="not-db-filter">Filter: in flight</span>
          <span className="not-db-filter">Group by: status</span>
        </div>
        {['doing','review','todo'].map(st => {
          const rows = tickets.filter(t => t.status === st);
          return (
            <div key={st} className="not-db-section">
              <div className="not-db-secthead">
                <span className={`not-pill p-${st}`}>{window.STATUS_LABEL[st]}</span>
                <span className="not-db-secct">{rows.length}</span>
              </div>
              <div className="not-db-table">
                <div className="not-db-head">
                  <span className="col-id">ID</span>
                  <span className="col-title">Title</span>
                  <span className="col-feat">Feature</span>
                  <span className="col-crit">Criteria</span>
                  <span className="col-est">Size</span>
                  <span className="col-when">Updated</span>
                </div>
                {rows.map(t => {
                  const f = featById[t.feature];
                  return (
                    <div key={t.id} className="not-db-row" onClick={() => onOpen(t.feature)}>
                      <span className="col-id"><span className="not-tid">{t.id}</span></span>
                      <span className="col-title">{t.title}</span>
                      <span className="col-feat"><span className={`not-feat-tag pip-${f.accent}`}>{f.title}</span></span>
                      <span className="col-crit">
                        <div className="not-crit-bar"><span style={{ width: `${(t.criteriaDone/t.criteria)*100}%` }} /></div>
                        <span className="not-crit-num">{t.criteriaDone}/{t.criteria}</span>
                      </span>
                      <span className="col-est"><span className="not-chip">{t.estimate}</span></span>
                      <span className="col-when">{t.updated}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Roadmap (timeline page) ─────────────────────────────────────────────────
function NotRoadmap({ onOpen }) {
  const milestones = window.MILESTONES;
  const features = window.FEATURES;
  const cols = 16;
  const milestoneCol = {
    'v0.3 — Persistence': [0, 2],
    'v0.4 — Multi-agent': [2, 8],
    'v0.5 — Planning': [8, 12],
    'v0.6 — Polish': [12, 16],
  };
  const placed = features.map((f, idx) => {
    const range = milestoneCol[f.milestone] || [0, 2];
    const span = range[1] - range[0];
    const start = range[0] + (idx % 2 === 0 ? 0 : Math.max(1, Math.floor(span / 4)));
    const end = Math.min(range[1], start + Math.max(2, Math.floor(span * (f.progress > 0 ? 1 : 0.6))));
    return { ...f, _start: start, _end: end };
  });
  const monthLabels = ['Apr','Apr','Apr','Apr','May','May','May','May','Jun','Jun','Jun','Jun','Jul','Jul','Jul','Jul'];
  const weekLabels = ['W1','W2','W3','W4','W1','W2','W3','W4','W1','W2','W3','W4','W1','W2','W3','W4'];

  return (
    <div className="not-page">
      <h1 className="not-page-title not-page-title-tight">Roadmap</h1>
      <p className="not-lede">Features by milestone. Drag a bar to reschedule; click to open the feature page.</p>

      <div className="not-rm">
        <div className="not-rm-header">
          <div className="not-rm-corner" />
          <div className="not-rm-grid not-rm-grid-head">
            {monthLabels.map((m, i) => (
              <div key={i} className={`not-rm-cell ${i === 0 || monthLabels[i-1] !== m ? 'is-month-start' : ''}`}>
                <div className="not-rm-week">{weekLabels[i]}</div>
                {(i === 0 || monthLabels[i-1] !== m) && <div className="not-rm-month">{m}</div>}
              </div>
            ))}
            <div className="not-rm-today" style={{ left: `calc((100% / ${cols}) * 3.6)` }}>
              <div className="not-rm-today-line" />
              <div className="not-rm-today-pill">today</div>
            </div>
          </div>
        </div>

        {milestones.map(ms => {
          const msFeatures = placed.filter(f => f.milestone === ms.label);
          return (
            <div key={ms.id} className="not-rm-row">
              <div className="not-rm-rowhead">
                <div className={`not-rm-msdot ms-${ms.state}`} />
                <div>
                  <div className="not-rm-msname">{ms.label}</div>
                  <div className="not-rm-msrange">{ms.start} → {ms.end}</div>
                </div>
              </div>
              <div className="not-rm-grid">
                {Array.from({ length: cols }).map((_, i) => <div key={i} className="not-rm-cell" />)}
                {msFeatures.map((f, idx) => (
                  <div key={f.id} className={`not-rm-bar bar-${f.accent} bar-${f.status}`}
                       onClick={() => onOpen(f.id)}
                       style={{ gridColumn: `${f._start + 1} / ${f._end + 1}`, top: idx * 34 + 10 }}>
                    <span className="not-rm-bar-id">{f.id}</span>
                    <span className="not-rm-bar-title">{f.title}</span>
                    <span className="not-rm-bar-prog" style={{ width: `${Math.round(f.progress * 100)}%` }} />
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function NotActivity() {
  return (
    <div className="not-page">
      <h1 className="not-page-title not-page-title-tight">Activity</h1>
      <p className="not-lede">Everything the agent did across all features. You can ⌘-click to scope to a single feature.</p>
      <div className="not-act-list not-act-list-page">
        {window.ACTIVITY.map(a => (
          <div key={a.id} className="not-act-row">
            <span className={`not-act-glyph k-${a.kind}`} />
            <div className="not-act-body">
              <div className="not-act-line">
                <span className={`not-act-actor ${a.actor}`}>{a.name}</span>{' '}
                <span className="not-act-verb">{a.verb}</span>{' '}
                <span className="not-act-target">{a.target}</span>
              </div>
              {a.detail && <div className="not-act-detail">{a.detail}</div>}
            </div>
            <span className="not-act-when">{a.when} ago</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { NotionHub });

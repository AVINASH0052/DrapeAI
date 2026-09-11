import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, resolveMediaUrl } from '../services/api';
import {
  Badge,
  ConfirmModal,
  EmptyState,
  ErrorBanner,
  LoadingBlock,
  formatDate,
  formatDateTime,
} from '../components/ui';

const TABS = [
  'Overview',
  'Wardrobe',
  'Outfits',
  'Lookbooks',
  'Avatar & Try-on',
  'Activity',
  'Support',
];

function PrefRow({ label, value }) {
  if (value == null || value === '' || (Array.isArray(value) && value.length === 0)) {
    return null;
  }
  const display = Array.isArray(value) ? value.join(', ') : String(value);
  return (
    <div className="pref-row">
      <dt>{label}</dt>
      <dd>{display}</dd>
    </div>
  );
}

export default function UserDetail() {
  const { userId } = useParams();
  const navigate = useNavigate();
  const [tab, setTab] = useState('Overview');
  const [user, setUser] = useState(null);
  const [items, setItems] = useState([]);
  const [outfits, setOutfits] = useState([]);
  const [lookbooks, setLookbooks] = useState([]);
  const [activity, setActivity] = useState([]);
  const [tryOns, setTryOns] = useState({ jobs: [], sessions: [] });
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(true);
  const [tabLoading, setTabLoading] = useState(false);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [confirmModal, setConfirmModal] = useState(null);

  const loadUser = useCallback(async () => {
    const data = await api.getUser(userId);
    setUser(data);
    setNotes(data.admin_notes || '');
  }, [userId]);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError('');
        await loadUser();
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [loadUser]);

  useEffect(() => {
    if (!user) return undefined;
    let cancelled = false;
    (async () => {
      try {
        setTabLoading(true);
        if (tab === 'Wardrobe') {
          const data = await api.getUserItems(userId);
          if (!cancelled) setItems(data.items || []);
        } else if (tab === 'Outfits') {
          const data = await api.getUserOutfits(userId);
          if (!cancelled) setOutfits(data.outfits || []);
        } else if (tab === 'Lookbooks') {
          const data = await api.getUserLookbooks(userId);
          if (!cancelled) setLookbooks(data.lookbooks || []);
        } else if (tab === 'Activity') {
          const data = await api.getUserActivity(userId);
          if (!cancelled) setActivity(data.events || []);
        } else if (tab === 'Avatar & Try-on') {
          const data = await api.getUserTryOns(userId);
          if (!cancelled) setTryOns(data);
        }
      } catch (err) {
        if (!cancelled) setError(err.message);
      } finally {
        if (!cancelled) setTabLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [tab, user, userId]);

  const saveNotes = async () => {
    setSaving(true);
    try {
      const updated = await api.patchUser(userId, { admin_notes: notes });
      setUser(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggleAdmin = async () => {
    setSaving(true);
    try {
      const updated = await api.patchUser(userId, { is_admin: !user.is_admin });
      setUser(updated);
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const runSupport = async (fn) => {
    setSaving(true);
    try {
      await fn();
      await loadUser();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
      setConfirmModal(null);
    }
  };

  if (loading) return <LoadingBlock />;
  if (!user) {
    return (
      <div>
        <ErrorBanner message={error || 'User not found'} />
        <Link to="/users">Back to users</Link>
      </div>
    );
  }

  const prefs = user.preferences || {};

  return (
    <div>
      <div className="page-header detail-header">
        <div>
          <Link to="/users" className="breadcrumb">← Users</Link>
          <h1>{user.display_name || user.email || user.phone || user.id}</h1>
          <p className="mono">{user.id}</p>
          <div className="badge-row">
            {user.is_admin ? <Badge tone="accent">Admin</Badge> : <Badge>User</Badge>}
            {user.is_suspended ? <Badge tone="danger">Suspended</Badge> : <Badge tone="success">Active</Badge>}
            <Badge tone={user.onboarding_done ? 'success' : 'warning'}>
              Onboarding {user.onboarding_done ? 'done' : 'pending'}
            </Badge>
            <Badge>{user.avatar_status || 'missing'}</Badge>
          </div>
        </div>
        <div className="detail-stats">
          <div><strong>{user.item_count ?? 0}</strong><span>Items</span></div>
          <div><strong>{user.outfit_count ?? 0}</strong><span>Outfits</span></div>
          <div><strong>{user.lookbook_count ?? 0}</strong><span>Lookbooks</span></div>
          <div><strong>{user.try_on_job_count ?? 0}</strong><span>Try-ons</span></div>
          <div><strong>{user.push_token_count ?? 0}</strong><span>Push tokens</span></div>
        </div>
      </div>

      <ErrorBanner message={error} />

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t}
            type="button"
            className={`tab ${tab === t ? 'active' : ''}`}
            onClick={() => setTab(t)}
          >
            {t}
          </button>
        ))}
      </div>

      {tabLoading ? <LoadingBlock /> : null}

      {!tabLoading && tab === 'Overview' ? (
        <div className="detail-grid">
          <section className="panel">
            <h2>Identity</h2>
            <dl className="pref-list">
              <PrefRow label="Email" value={user.email} />
              <PrefRow label="Phone" value={user.phone} />
              <PrefRow label="Created" value={formatDateTime(user.created_at)} />
              <PrefRow label="Last login" value={formatDateTime(user.last_login_at)} />
              <PrefRow label="Suspended at" value={formatDateTime(user.suspended_at)} />
            </dl>
          </section>
          <section className="panel">
            <h2>Preferences</h2>
            <dl className="pref-list">
              <PrefRow label="Name" value={prefs.name} />
              <PrefRow label="Age" value={prefs.age} />
              <PrefRow label="Gender" value={prefs.gender} />
              <PrefRow label="Style goals" value={safeParseList(prefs.style_goals)} />
              <PrefRow label="Occasions" value={safeParseList(prefs.occasions)} />
              <PrefRow label="Colors" value={safeParseList(prefs.color_preferences)} />
              <PrefRow label="Fit" value={prefs.fit_preference} />
              <PrefRow label="City" value={prefs.location_city} />
              <PrefRow label="Climate" value={prefs.climate} />
              <PrefRow label="Body" value={prefs.body_type} />
              <PrefRow label="Undertone" value={prefs.skin_undertone} />
              <PrefRow label="Height cm" value={prefs.height_cm} />
              <PrefRow label="Budget" value={prefs.budget_tier} />
              <PrefRow label="Lifestyle" value={safeParseList(prefs.lifestyle)} />
              <PrefRow label="Style profile" value={prefs.style_profile} />
            </dl>
          </section>
        </div>
      ) : null}

      {!tabLoading && tab === 'Wardrobe' ? (
        items.length === 0 ? (
          <EmptyState title="No wardrobe items" />
        ) : (
          <div className="item-grid">
            {items.map((item) => (
              <div key={item.id} className={`item-card ${item.is_flagged ? 'flagged' : ''}`}>
                <div className="item-thumb">
                  {item.thumbnail_url_resolved || item.image_url_resolved ? (
                    <img
                      src={resolveMediaUrl(
                        item.thumbnail_url_resolved || item.image_url_resolved,
                      )}
                      alt=""
                    />
                  ) : (
                    <div className="thumb-fallback">{item.category}</div>
                  )}
                </div>
                <div className="item-meta">
                  <strong>{item.display_name || item.category}</strong>
                  <span>{item.primary_color} · {item.sub_category || '—'}</span>
                  <div className="badge-row">
                    {!item.is_active ? <Badge tone="warning">Inactive</Badge> : null}
                    {item.is_flagged ? <Badge tone="danger">Flagged</Badge> : null}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )
      ) : null}

      {!tabLoading && tab === 'Outfits' ? (
        outfits.length === 0 ? (
          <EmptyState title="No outfits" />
        ) : (
          <div className="outfit-list">
            {outfits.map((o) => (
              <div key={o.id} className="panel outfit-card">
                <div className="outfit-head">
                  <strong>{o.occasion || 'Outfit'}</strong>
                  <span>{formatDate(o.created_at)}</span>
                </div>
                <p className="muted">{o.llm_reason || o.generated_by}</p>
                <div className="thumb-row">
                  {(o.items || []).map((it) => (
                    <div key={it.id} className="mini-thumb">
                      {it.thumbnail_url_resolved || it.image_url_resolved ? (
                        <img
                          src={resolveMediaUrl(
                            it.thumbnail_url_resolved || it.image_url_resolved,
                          )}
                          alt=""
                        />
                      ) : (
                        <span>{it.category?.[0] || '?'}</span>
                      )}
                    </div>
                  ))}
                </div>
                <div className="badge-row">
                  {o.is_saved ? <Badge tone="success">Saved</Badge> : null}
                  {o.is_worn ? <Badge>Worn</Badge> : null}
                </div>
              </div>
            ))}
          </div>
        )
      ) : null}

      {!tabLoading && tab === 'Lookbooks' ? (
        lookbooks.length === 0 ? (
          <EmptyState title="No lookbooks" />
        ) : (
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Outfits</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {lookbooks.map((lb) => (
                  <tr key={lb.id}>
                    <td>{lb.name}</td>
                    <td>{lb.outfit_count}</td>
                    <td>{formatDate(lb.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      ) : null}

      {!tabLoading && tab === 'Avatar & Try-on' ? (
        <div className="detail-grid">
          <section className="panel">
            <h2>Avatar</h2>
            <dl className="pref-list">
              <PrefRow label="Status" value={user.avatar_status} />
              <PrefRow label="Base key" value={user.avatar_base_key} />
              <PrefRow label="Error" value={user.avatar_error} />
              <PrefRow label="Analyzed" value={formatDateTime(user.avatar_analyzed_at)} />
              <PrefRow label="Try-on photo" value={user.try_on_photo_key} />
            </dl>
          </section>
          <section className="panel">
            <h2>Try-on jobs ({tryOns.jobs?.length || 0})</h2>
            {(tryOns.jobs || []).length === 0 ? (
              <EmptyState title="No try-on jobs" />
            ) : (
              <ul className="timeline">
                {tryOns.jobs.map((j) => (
                  <li key={j.id}>
                    <strong>{j.status}</strong>
                    <span>{j.provider || '—'} · {formatDateTime(j.created_at)}</span>
                    {j.error_message ? <span className="danger-text">{j.error_message}</span> : null}
                  </li>
                ))}
              </ul>
            )}
            <h2 style={{ marginTop: 24 }}>Sessions ({tryOns.sessions?.length || 0})</h2>
            {(tryOns.sessions || []).length === 0 ? (
              <EmptyState title="No try-on sessions" />
            ) : (
              <ul className="timeline">
                {tryOns.sessions.map((s) => (
                  <li key={s.id}>
                    <strong>{s.status}</strong>
                    <span>{formatDateTime(s.created_at)}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      ) : null}

      {!tabLoading && tab === 'Activity' ? (
        activity.length === 0 ? (
          <EmptyState title="No recent activity" />
        ) : (
          <ul className="timeline panel">
            {activity.map((ev, i) => (
              <li key={`${ev.event_type}-${ev.ref_id}-${i}`}>
                <strong>{ev.event_type}</strong>
                <span>{ev.label}</span>
                <span className="muted">{formatDateTime(ev.at)}</span>
              </li>
            ))}
          </ul>
        )
      ) : null}

      {!tabLoading && tab === 'Support' ? (
        <div className="detail-grid">
          <section className="panel">
            <h2>Admin notes</h2>
            <textarea
              className="notes-input"
              rows={6}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Internal support notes…"
            />
            <button type="button" className="btn btn-primary" disabled={saving} onClick={saveNotes}>
              {saving ? 'Saving…' : 'Save notes'}
            </button>
          </section>
          <section className="panel">
            <h2>Lifecycle actions</h2>
            <div className="action-stack">
              <button
                type="button"
                className="btn btn-ghost"
                disabled={saving}
                onClick={toggleAdmin}
              >
                {user.is_admin ? 'Revoke admin' : 'Grant admin'}
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={saving}
                onClick={() =>
                  setConfirmModal({
                    title: 'Reset onboarding?',
                    message: 'The user will need to complete onboarding again.',
                    onConfirm: () => runSupport(() => api.resetOnboarding(userId)),
                  })
                }
              >
                Reset onboarding
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={saving}
                onClick={() =>
                  setConfirmModal({
                    title: user.is_suspended ? 'Unsuspend user?' : 'Suspend user?',
                    message: user.is_suspended
                      ? 'They will regain API access.'
                      : 'They will be blocked from the app.',
                    danger: !user.is_suspended,
                    confirmLabel: user.is_suspended ? 'Unsuspend' : 'Suspend',
                    onConfirm: () =>
                      runSupport(() => api.suspendUser(userId, !user.is_suspended)),
                  })
                }
              >
                {user.is_suspended ? 'Unsuspend' : 'Suspend'}
              </button>
              <button
                type="button"
                className="btn btn-danger"
                disabled={saving}
                onClick={() =>
                  setConfirmModal({
                    title: 'Delete user permanently?',
                    message: 'This cascades wardrobe, outfits, and related data. Cannot be undone.',
                    danger: true,
                    confirmLabel: 'Delete forever',
                    onConfirm: () =>
                      runSupport(async () => {
                        await api.deleteUser(userId);
                        navigate('/users');
                      }),
                  })
                }
              >
                Delete user
              </button>
            </div>
          </section>
        </div>
      ) : null}

      {confirmModal ? (
        <ConfirmModal
          title={confirmModal.title}
          message={confirmModal.message}
          danger={confirmModal.danger}
          confirmLabel={confirmModal.confirmLabel}
          onConfirm={confirmModal.onConfirm}
          onCancel={() => setConfirmModal(null)}
        />
      ) : null}
    </div>
  );
}

function safeParseList(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : value;
    } catch {
      return value;
    }
  }
  return value;
}

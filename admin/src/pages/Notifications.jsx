import { useEffect, useState } from 'react';
import { api } from '../services/api';
import { ErrorBanner, LoadingBlock, EmptyState } from '../components/ui';

export default function Notifications() {
  const [segments, setSegments] = useState([]);
  const [segmentId, setSegmentId] = useState('all_with_tokens');
  const [title, setTitle] = useState('Sugatai');
  const [body, setBody] = useState('');
  const [deepLink, setDeepLink] = useState('today_outfits');
  const [userIds, setUserIds] = useState('');
  const [mode, setMode] = useState('segment');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const data = await api.getPushSegments();
        setSegments(data.segments || []);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const send = async (e) => {
    e.preventDefault();
    setSending(true);
    setError('');
    setResult(null);
    try {
      const payload = {
        title,
        body,
        deep_link: deepLink || undefined,
      };
      if (mode === 'segment') {
        payload.segment_id = segmentId;
      } else {
        payload.user_ids = userIds
          .split(/[\s,]+/)
          .map((s) => s.trim())
          .filter(Boolean);
      }
      const res = await api.sendPush(payload);
      setResult(res);
    } catch (err) {
      setError(err.message);
    } finally {
      setSending(false);
    }
  };

  if (loading) return <LoadingBlock />;

  return (
    <div>
      <div className="page-header">
        <h1>Notifications</h1>
        <p>Compose and send push notifications to user segments</p>
      </div>
      <ErrorBanner message={error} />

      <div className="detail-grid">
        <section className="panel">
          <h2>Segments</h2>
          {segments.length === 0 ? (
            <EmptyState title="No segments" />
          ) : (
            <ul className="segment-list">
              {segments.map((s) => (
                <li key={s.id}>
                  <button
                    type="button"
                    className={`segment-btn ${segmentId === s.id && mode === 'segment' ? 'active' : ''}`}
                    onClick={() => {
                      setMode('segment');
                      setSegmentId(s.id);
                    }}
                  >
                    <strong>{s.label}</strong>
                    <span>{s.count.toLocaleString()} users</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="panel">
          <h2>Compose</h2>
          <form onSubmit={send} className="compose-form">
            <div className="form-group">
              <label htmlFor="push-mode">Audience</label>
              <select
                id="push-mode"
                value={mode}
                onChange={(e) => setMode(e.target.value)}
              >
                <option value="segment">Saved segment</option>
                <option value="ids">Explicit user IDs</option>
              </select>
            </div>
            {mode === 'ids' ? (
              <div className="form-group">
                <label htmlFor="push-ids">User IDs</label>
                <textarea
                  id="push-ids"
                  rows={4}
                  value={userIds}
                  onChange={(e) => setUserIds(e.target.value)}
                  placeholder="One Firebase UID per line"
                  required
                />
              </div>
            ) : null}
            <div className="form-group">
              <label htmlFor="push-title">Title</label>
              <input
                id="push-title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
              />
            </div>
            <div className="form-group">
              <label htmlFor="push-body">Body</label>
              <textarea
                id="push-body"
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                required
              />
            </div>
            <div className="form-group">
              <label htmlFor="push-link">Deep link screen</label>
              <input
                id="push-link"
                value={deepLink}
                onChange={(e) => setDeepLink(e.target.value)}
                placeholder="today_outfits"
              />
            </div>
            <div className="push-preview">
              <div className="push-preview-title">{title || 'Title'}</div>
              <div className="push-preview-body">{body || 'Notification body'}</div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={sending}>
              {sending ? 'Sending…' : 'Send push'}
            </button>
            {result ? (
              <p className="success-message">
                Sent to {result.sent} of {result.requested} users
              </p>
            ) : null}
          </form>
        </section>
      </div>
    </div>
  );
}

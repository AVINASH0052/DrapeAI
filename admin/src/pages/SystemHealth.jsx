import { useState, useEffect } from 'react';
import { api } from '../services/api';
import { ErrorBanner, LoadingBlock } from '../components/ui';

function formatUptime(seconds) {
  if (!seconds) return '—';
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);

  const parts = [];
  if (d > 0) parts.push(`${d}d`);
  if (h > 0) parts.push(`${h}h`);
  if (m > 0) parts.push(`${m}m`);
  parts.push(`${s}s`);
  return parts.join(' ');
}

function formatRowCount(count) {
  if (count == null) return '—';
  return Number(count).toLocaleString();
}

export default function SystemHealth() {
  const [health, setHealth] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchHealth = async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getSystemHealth();
      setHealth(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHealth();
  }, []);

  if (loading) return <LoadingBlock />;
  if (error && !health) {
    return <ErrorBanner message={`Failed to load system health: ${error}`} />;
  }

  const tables = health?.tables?.length
    ? health.tables
    : Object.entries(health?.table_counts || {}).map(([name, row_count]) => ({ name, row_count }));

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <h1>System Health</h1>
          <p>Database and infrastructure status</p>
        </div>
        <button type="button" className="btn btn-ghost" onClick={fetchHealth}>
          Refresh
        </button>
      </div>

      <ErrorBanner message={error} />

      <div className="health-grid">
        <div className="health-card">
          <div className="health-label">Database Connection</div>
          <div className="health-value">
            <div className="connection-indicator">
              <div
                className={`connection-dot ${health?.db_connected ? 'connected' : 'disconnected'}`}
              />
              <span>{health?.db_connected ? 'Connected' : 'Disconnected'}</span>
            </div>
          </div>
        </div>

        <div className="health-card">
          <div className="health-label">Database Version</div>
          <div className="health-value" style={{ fontSize: '1rem', fontFamily: 'monospace' }}>
            {health?.db_version || '—'}
          </div>
        </div>

        <div className="health-card">
          <div className="health-label">Uptime</div>
          <div className="health-value">
            {formatUptime(health?.uptime_seconds)}
          </div>
        </div>
      </div>

      {health?.providers?.length ? (
        <div className="table-container" style={{ marginBottom: 24 }}>
          <div className="table-header">
            <h2>AI providers</h2>
          </div>
          <table>
            <thead>
              <tr>
                <th>Provider</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {health.providers.map((p) => (
                <tr key={p.name}>
                  <td>{p.name}</td>
                  <td>{p.configured ? 'Configured' : 'Missing'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      {tables.length > 0 ? (
        <div className="table-container">
          <div className="table-header">
            <h2>Database Tables</h2>
            <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>
              {tables.length} tables
            </span>
          </div>
          <table>
            <thead>
              <tr>
                <th>Table Name</th>
                <th style={{ textAlign: 'right' }}>Row Count</th>
              </tr>
            </thead>
            <tbody>
              {tables.map((t) => (
                <tr key={t.name}>
                  <td>
                    <code className="table-code">{t.name}</code>
                  </td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>
                    {formatRowCount(t.row_count)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </div>
  );
}

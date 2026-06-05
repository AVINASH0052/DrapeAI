import { useState, useEffect } from 'react';
import { api } from '../services/api';

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

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner" />
      </div>
    );
  }

  if (error) {
    return <div className="error-message">Failed to load system health: {error}</div>;
  }

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <h1>System Health</h1>
          <p>Database and infrastructure status</p>
        </div>
        <button className="btn btn-ghost" onClick={fetchHealth}>
          ↻ Refresh
        </button>
      </div>

      {/* Health Cards */}
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

      {/* Table Row Counts */}
      {health?.tables && health.tables.length > 0 && (
        <div className="table-container">
          <div className="table-header">
            <h2>Database Tables</h2>
            <span style={{ color: 'var(--text-muted)', fontSize: '0.8125rem' }}>
              {health.tables.length} tables
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
              {health.tables.map((t) => (
                <tr key={t.name}>
                  <td>
                    <code style={{
                      background: 'rgba(129, 140, 248, 0.08)',
                      padding: '2px 8px',
                      borderRadius: 4,
                      fontSize: '0.8125rem',
                      color: 'var(--accent)',
                    }}>
                      {t.name}
                    </code>
                  </td>
                  <td style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>
                    {formatRowCount(t.row_count)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

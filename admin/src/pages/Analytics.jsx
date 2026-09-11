import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, Legend,
} from 'recharts';
import { api } from '../services/api';
import { ErrorBanner, LoadingBlock, EmptyState } from '../components/ui';

function formatCurrency(val) {
  if (val == null) return '$0.00';
  return `$${Number(val).toFixed(2)}`;
}

export default function Analytics() {
  const [overview, setOverview] = useState(null);
  const [costs, setCosts] = useState([]);
  const [usage, setUsage] = useState([]);
  const [topUsers, setTopUsers] = useState([]);
  const [metric, setMetric] = useState('items');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const [ov, costData, usageData, top] = await Promise.all([
          api.getAnalyticsOverview(30),
          api.getAnalyticsCosts(30),
          api.getAnalyticsUsage(30),
          api.getTopUsers(metric, 30),
        ]);
        setOverview(ov);
        setCosts(costData.series || []);
        setUsage(usageData.series || []);
        setTopUsers(top.users || []);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [metric]);

  if (loading) return <LoadingBlock />;

  const costKeys = Array.from(
    new Set(costs.flatMap((row) => Object.keys(row).filter((k) => k !== 'date')))
  );

  return (
    <div>
      <div className="page-header">
        <h1>Analytics</h1>
        <p>Usage, cost, and top accounts over the last 30 days</p>
      </div>
      <ErrorBanner message={error} />

      <div className="stats-grid">
        <div className="stat-card"><div className="stat-label">DAU</div><div className="stat-value">{overview?.dau ?? 0}</div></div>
        <div className="stat-card"><div className="stat-label">MAU</div><div className="stat-value">{overview?.mau ?? 0}</div></div>
        <div className="stat-card"><div className="stat-label">New users</div><div className="stat-value">{overview?.new_users ?? 0}</div></div>
        <div className="stat-card"><div className="stat-label">AI cost 30d</div><div className="stat-value">{formatCurrency(overview?.total_cost_usd)}</div></div>
        <div className="stat-card"><div className="stat-label">Items</div><div className="stat-value">{overview?.total_items ?? 0}</div></div>
        <div className="stat-card"><div className="stat-label">Avg items / user</div><div className="stat-value">{Number(overview?.avg_items_per_user || 0).toFixed(1)}</div></div>
      </div>

      <div className="charts-grid">
        <div className="chart-card">
          <h2>Cost by provider</h2>
          {costs.length === 0 ? (
            <EmptyState title="No cost data" />
          ) : (
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={costs}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e8ddd0" />
                <XAxis dataKey="date" fontSize={11} tickFormatter={(d) => new Date(d).getDate()} />
                <YAxis fontSize={11} />
                <Tooltip />
                <Legend />
                {costKeys.map((key, i) => (
                  <Bar key={key} dataKey={key} stackId="a" fill={['#ff5c00', '#00c9b7', '#ff006e', '#ffc947', '#7b2ff7'][i % 5]} />
                ))}
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
        <div className="chart-card">
          <h2>Usage trends</h2>
          {usage.length === 0 ? (
            <EmptyState title="No usage data" />
          ) : (
            <ResponsiveContainer width="100%" height={320}>
              <LineChart data={usage}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e8ddd0" />
                <XAxis dataKey="date" fontSize={11} tickFormatter={(d) => new Date(d).getDate()} />
                <YAxis fontSize={11} />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="uploads" stroke="#ff5c00" dot={false} />
                <Line type="monotone" dataKey="outfits_generated" stroke="#00c9b7" dot={false} />
                <Line type="monotone" dataKey="chat_refinements" stroke="#ff006e" dot={false} />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      <div className="panel" style={{ marginTop: 24 }}>
        <div className="table-header">
          <h2>Top users</h2>
          <select value={metric} onChange={(e) => setMetric(e.target.value)}>
            <option value="items">By items</option>
            <option value="outfits">By outfits</option>
          </select>
        </div>
        {topUsers.length === 0 ? (
          <EmptyState title="No ranked users yet" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th style={{ textAlign: 'right' }}>Value</th>
              </tr>
            </thead>
            <tbody>
              {topUsers.map((u) => (
                <tr key={u.id}>
                  <td>
                    <Link to={`/users/${u.id}`}>{u.display_name || u.email || u.id}</Link>
                  </td>
                  <td style={{ textAlign: 'right' }}>{u.value}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

import { useState, useEffect } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts';
import { api } from '../services/api';

const PIE_COLORS = ['#ff5c00', '#ff006e', '#00c9b7', '#ffc947', '#7b2ff7', '#ff7a33'];

function formatCurrency(val) {
  if (val == null) return '$0.00';
  return `$${Number(val).toFixed(2)}`;
}

function formatNumber(val) {
  if (val == null) return '0';
  return Number(val).toLocaleString();
}

function StatCard({ label, value, format = 'number' }) {
  const display = format === 'currency' ? formatCurrency(value) : formatNumber(value);
  return (
    <div className="stat-card">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{display}</div>
    </div>
  );
}

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: '#ffffff',
      border: '1px solid #e8ddd0',
      borderRadius: 10,
      padding: '12px 16px',
      fontSize: '0.8125rem',
      boxShadow: '0 8px 24px rgba(12,10,20,0.08)',
    }}>
      <div style={{ color: '#8a8299', marginBottom: 8, fontWeight: 700 }}>{label}</div>
      {payload.map((entry, i) => (
        <div key={i} style={{ color: entry.color, marginBottom: 2, fontWeight: 600 }}>
          {entry.name}: {entry.name === 'AI Cost' ? formatCurrency(entry.value) : entry.value}
        </div>
      ))}
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [timeseries, setTimeseries] = useState([]);
  const [aiUsage, setAiUsage] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function fetchData() {
      try {
        const [statsData, tsData, aiData] = await Promise.all([
          api.getStats(),
          api.getTimeseries(30),
          api.getAiUsage(),
        ]);
        setStats(statsData);
        const series = Array.isArray(tsData) ? tsData : (tsData?.series || []);
        setTimeseries(series);
        const usage = Array.isArray(aiData) ? aiData : (aiData?.usage || []);
        setAiUsage(usage);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner" />
      </div>
    );
  }

  if (error) {
    return <div className="error-message">Failed to load dashboard: {error}</div>;
  }

  const pieData = aiUsage.map((item) => ({
    name: `${item.provider} / ${item.model}`,
    value: Number(item.total_cost) || 0,
  }));

  return (
    <div>
      <div className="page-header">
        <h1>Dashboard</h1>
        <p>Overview of Sugatai platform metrics</p>
      </div>

      {/* KPI Cards */}
      <div className="stats-grid">
        <StatCard label="Total Users" value={stats?.total_users} />
        <StatCard label="Active (7d)" value={stats?.active_users_7d} />
        <StatCard label="Total Items" value={stats?.total_items} />
        <StatCard label="Total Outfits" value={stats?.total_outfits} />
        <StatCard label="AI Spend Today" value={stats?.ai_spend_today} format="currency" />
        <StatCard label="AI Spend Month" value={stats?.ai_spend_month} format="currency" />
      </div>

      {/* Charts */}
      <div className="charts-grid">
        {/* Timeseries Line Chart */}
        <div className="chart-card">
          <h2>30-Day Trends</h2>
          <ResponsiveContainer width="100%" height={320}>
            <LineChart data={timeseries} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e8ddd0" />
              <XAxis
                dataKey="date"
                stroke="#8a8299"
                fontSize={11}
                tickLine={false}
                tickFormatter={(d) => {
                  const dt = new Date(d);
                  return `${dt.getMonth() + 1}/${dt.getDate()}`;
                }}
              />
              <YAxis stroke="#8a8299" fontSize={11} tickLine={false} axisLine={false} />
              <Tooltip content={<CustomTooltip />} />
              <Legend
                wrapperStyle={{ fontSize: '0.75rem', color: '#8a8299' }}
                iconType="circle"
                iconSize={8}
              />
              <Line
                type="monotone"
                dataKey="new_users"
                name="New Users"
                stroke="#ff5c00"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, strokeWidth: 0 }}
              />
              <Line
                type="monotone"
                dataKey="outfits_generated"
                name="Outfits"
                stroke="#00c9b7"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, strokeWidth: 0 }}
              />
              <Line
                type="monotone"
                dataKey="ai_cost"
                name="AI Cost"
                stroke="#ff006e"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, strokeWidth: 0 }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* AI Usage Pie Chart */}
        <div className="chart-card">
          <h2>AI Cost by Provider</h2>
          {pieData.length > 0 ? (
            <ResponsiveContainer width="100%" height={320}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="45%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={3}
                  dataKey="value"
                  stroke="none"
                >
                  {pieData.map((_, i) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(val) => formatCurrency(val)}
                  contentStyle={{
                    background: '#ffffff',
                    border: '1px solid #e8ddd0',
                    borderRadius: 10,
                    fontSize: '0.8125rem',
                  }}
                />
                <Legend
                  wrapperStyle={{ fontSize: '0.7rem', color: '#8a8299' }}
                  iconType="circle"
                  iconSize={8}
                />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="empty-state">
              <p>No AI usage data yet</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

import { useCallback, useEffect, useState } from 'react';
import { api } from '../services/api';
import {
  EmptyState,
  ErrorBanner,
  LoadingBlock,
  Pagination,
  formatDateTime,
} from '../components/ui';

const PAGE_SIZE = 50;

export default function Waitlist() {
  const [entries, setEntries] = useState([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchEntries = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getWaitlist({
        search: search || undefined,
        limit: PAGE_SIZE,
        offset,
      });
      setEntries(data.entries || []);
      setTotal(data.total || 0);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [search, offset]);

  useEffect(() => {
    fetchEntries();
  }, [fetchEntries]);

  const exportCsv = () => {
    const rows = [['email', 'source', 'created_at'], ...entries.map((e) => [e.email, e.source, e.created_at])];
    const csv = rows.map((r) => r.map((c) => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'sugatai-waitlist.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div>
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
        <div>
          <h1>Waitlist</h1>
          <p>Early access emails from the marketing site</p>
        </div>
        <button type="button" className="btn btn-ghost" onClick={exportCsv} disabled={!entries.length}>
          Export page CSV
        </button>
      </div>

      <ErrorBanner message={error} />

      <div className="toolbar">
        <input
          className="search-input"
          type="search"
          placeholder="Search email…"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setOffset(0); }}
        />
        <span className="muted">{total.toLocaleString()} total</span>
      </div>

      {loading ? (
        <LoadingBlock />
      ) : entries.length === 0 ? (
        <EmptyState title="No waitlist entries" />
      ) : (
        <>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Source</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((e) => (
                  <tr key={e.id}>
                    <td>{e.email}</td>
                    <td>{e.source}</td>
                    <td>{formatDateTime(e.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination offset={offset} limit={PAGE_SIZE} total={total} onChange={setOffset} />
        </>
      )}
    </div>
  );
}

import { useState, useEffect, useCallback, useRef } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../services/api';
import {
  Badge,
  ConfirmModal,
  EmptyState,
  ErrorBanner,
  LoadingBlock,
  Pagination,
  formatDate,
} from '../components/ui';

const PAGE_SIZE = 25;

export default function Users() {
  const [users, setUsers] = useState([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [onboarding, setOnboarding] = useState('');
  const [suspended, setSuspended] = useState('');
  const [avatarStatus, setAvatarStatus] = useState('');
  const [inactiveDays, setInactiveDays] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState(null);
  const [confirmModal, setConfirmModal] = useState(null);
  const debounceTimer = useRef(null);

  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current);
    debounceTimer.current = setTimeout(() => {
      setDebouncedSearch(search);
      setOffset(0);
    }, 350);
    return () => clearTimeout(debounceTimer.current);
  }, [search]);

  const fetchUsers = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getUsers({
        search: debouncedSearch,
        onboarding: onboarding || undefined,
        suspended: suspended || undefined,
        avatar_status: avatarStatus || undefined,
        inactive_days: inactiveDays || undefined,
        limit: PAGE_SIZE,
        offset,
      });
      setUsers(data.users || []);
      setTotal(data.total || 0);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch, onboarding, suspended, avatarStatus, inactiveDays, offset]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const runAction = async (id, fn) => {
    setActionLoading(id);
    try {
      await fn();
      await fetchUsers();
    } catch (err) {
      setError(err.message);
    } finally {
      setActionLoading(null);
      setConfirmModal(null);
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1>Users</h1>
        <p>Search, filter, and manage every account lifecycle stage</p>
      </div>

      <ErrorBanner message={error} />

      <div className="toolbar">
        <input
          className="search-input"
          type="search"
          placeholder="Search email, phone, name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={onboarding} onChange={(e) => { setOnboarding(e.target.value); setOffset(0); }}>
          <option value="">Onboarding: any</option>
          <option value="done">Done</option>
          <option value="pending">Pending</option>
        </select>
        <select value={suspended} onChange={(e) => { setSuspended(e.target.value); setOffset(0); }}>
          <option value="">Status: any</option>
          <option value="false">Active</option>
          <option value="true">Suspended</option>
        </select>
        <select value={avatarStatus} onChange={(e) => { setAvatarStatus(e.target.value); setOffset(0); }}>
          <option value="">Avatar: any</option>
          <option value="missing">Missing</option>
          <option value="queued">Queued</option>
          <option value="processing">Processing</option>
          <option value="ready">Ready</option>
          <option value="failed">Failed</option>
        </select>
        <select value={inactiveDays} onChange={(e) => { setInactiveDays(e.target.value); setOffset(0); }}>
          <option value="">Activity: any</option>
          <option value="7">Inactive 7d+</option>
          <option value="30">Inactive 30d+</option>
          <option value="90">Inactive 90d+</option>
        </select>
      </div>

      {loading ? (
        <LoadingBlock />
      ) : users.length === 0 ? (
        <EmptyState title="No users match" message="Try clearing filters or widening search." />
      ) : (
        <>
          <div className="table-container">
            <table>
              <thead>
                <tr>
                  <th>User</th>
                  <th>Items</th>
                  <th>Outfits</th>
                  <th>Onboarding</th>
                  <th>Avatar</th>
                  <th>Last login</th>
                  <th>Flags</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>
                      <Link to={`/users/${u.id}`} className="user-link">
                        <div className="user-cell">
                          <strong>{u.display_name || u.email || u.phone || u.id}</strong>
                          <span>{u.email || u.phone || u.id}</span>
                        </div>
                      </Link>
                    </td>
                    <td>{u.item_count ?? 0}</td>
                    <td>{u.outfit_count ?? 0}</td>
                    <td>
                      <Badge tone={u.onboarding_done ? 'success' : 'warning'}>
                        {u.onboarding_done ? 'Done' : 'Pending'}
                      </Badge>
                    </td>
                    <td>
                      <Badge tone={u.avatar_status === 'ready' ? 'success' : 'neutral'}>
                        {u.avatar_status || 'missing'}
                      </Badge>
                    </td>
                    <td>{formatDate(u.last_login_at)}</td>
                    <td className="badge-row">
                      {u.is_admin ? <Badge tone="accent">Admin</Badge> : null}
                      {u.is_suspended ? <Badge tone="danger">Suspended</Badge> : null}
                    </td>
                    <td>
                      <div className="row-actions">
                        <Link className="btn btn-ghost btn-sm" to={`/users/${u.id}`}>
                          Open
                        </Link>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm"
                          disabled={actionLoading === u.id}
                          onClick={() =>
                            setConfirmModal({
                              title: u.is_suspended ? 'Unsuspend user?' : 'Suspend user?',
                              message: u.is_suspended
                                ? 'They will regain API access immediately.'
                                : 'They will be blocked from using the app.',
                              danger: !u.is_suspended,
                              confirmLabel: u.is_suspended ? 'Unsuspend' : 'Suspend',
                              onConfirm: () =>
                                runAction(u.id, () => api.suspendUser(u.id, !u.is_suspended)),
                            })
                          }
                        >
                          {u.is_suspended ? 'Unsuspend' : 'Suspend'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination
            offset={offset}
            limit={PAGE_SIZE}
            total={total}
            onChange={setOffset}
          />
        </>
      )}

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

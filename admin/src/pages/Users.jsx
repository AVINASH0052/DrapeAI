import { useState, useEffect, useCallback, useRef } from 'react';
import { api } from '../services/api';

const PAGE_SIZE = 50;

function formatDate(dateStr) {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

function ConfirmModal({ title, message, onConfirm, onCancel, danger }) {
  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h3>{title}</h3>
        <p>{message}</p>
        <div className="modal-actions">
          <button className="btn btn-ghost" onClick={onCancel}>
            Cancel
          </button>
          <button
            className={`btn ${danger ? 'btn-danger' : 'btn-primary'}`}
            onClick={onConfirm}
          >
            Confirm
          </button>
        </div>
      </div>
    </div>
  );
}

export default function Users() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [actionLoading, setActionLoading] = useState(null);
  const [confirmModal, setConfirmModal] = useState(null);
  const debounceTimer = useRef(null);

  // Debounce search input
  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current);
    debounceTimer.current = setTimeout(() => {
      setDebouncedSearch(search);
    }, 350);
    return () => clearTimeout(debounceTimer.current);
  }, [search]);

  // Fetch users when search changes
  const fetchUsers = useCallback(async (searchTerm, offset = 0, append = false) => {
    try {
      if (!append) setLoading(true);
      else setLoadingMore(true);

      const data = await api.getUsers(searchTerm, PAGE_SIZE, offset);
      const list = Array.isArray(data) ? data : data?.users || [];

      if (append) {
        setUsers((prev) => [...prev, ...list]);
      } else {
        setUsers(list);
      }
      setHasMore(list.length === PAGE_SIZE);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
      setLoadingMore(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers(debouncedSearch);
  }, [debouncedSearch, fetchUsers]);

  const handleLoadMore = () => {
    fetchUsers(debouncedSearch, users.length, true);
  };

  const handleSuspend = async (user) => {
    setActionLoading(user.id);
    const newState = !user.is_suspended;
    try {
      await api.suspendUser(user.id, newState);
      setUsers((prev) =>
        prev.map((u) =>
          u.id === user.id ? { ...u, is_suspended: newState } : u
        )
      );
    } catch (err) {
      setError(err.message);
    } finally {
      setActionLoading(null);
    }
  };

  const handleDelete = async (user) => {
    setConfirmModal({
      title: 'Delete User',
      message: `Are you sure you want to permanently delete "${user.display_name || user.email}"? This action cannot be undone.`,
      danger: true,
      onConfirm: async () => {
        setConfirmModal(null);
        setActionLoading(user.id);
        try {
          await api.deleteUser(user.id);
          setUsers((prev) => prev.filter((u) => u.id !== user.id));
        } catch (err) {
          setError(err.message);
        } finally {
          setActionLoading(null);
        }
      },
    });
  };

  return (
    <div>
      <div className="page-header">
        <h1>Users</h1>
        <p>Manage registered DrapeAI users</p>
      </div>

      {error && <div className="error-message">{error}</div>}

      <div className="table-container">
        <div className="table-header">
          <h2>All Users</h2>
          <input
            id="users-search"
            className="search-input"
            type="text"
            placeholder="Search by name, email, or phone…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {loading ? (
          <div className="loading-container">
            <div className="spinner" />
          </div>
        ) : users.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">👥</div>
            <p>No users found{search ? ` matching "${search}"` : ''}</p>
          </div>
        ) : (
          <>
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Email / Phone</th>
                  <th>Items</th>
                  <th>Outfits</th>
                  <th>Status</th>
                  <th>Joined</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <div style={{ fontWeight: 500 }}>
                        {user.display_name || '—'}
                        {user.is_admin && (
                          <span
                            className="badge badge-muted"
                            style={{ marginLeft: 8, fontSize: '0.65rem' }}
                          >
                            ADMIN
                          </span>
                        )}
                      </div>
                    </td>
                    <td>
                      <div style={{ color: '#e5e7eb' }}>{user.email || '—'}</div>
                      {user.phone && (
                        <div style={{ color: '#6b7280', fontSize: '0.8rem' }}>{user.phone}</div>
                      )}
                    </td>
                    <td>{user.items_count ?? 0}</td>
                    <td>{user.outfits_count ?? 0}</td>
                    <td>
                      {user.is_suspended ? (
                        <span className="badge badge-danger">
                          <span className="badge-dot" />
                          Suspended
                        </span>
                      ) : (
                        <span className="badge badge-success">
                          <span className="badge-dot" />
                          Active
                        </span>
                      )}
                    </td>
                    <td style={{ color: '#6b7280', fontSize: '0.8125rem' }}>
                      {formatDate(user.created_at)}
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <button
                          className={`btn btn-sm ${user.is_suspended ? 'btn-primary' : 'btn-warning'}`}
                          disabled={actionLoading === user.id}
                          onClick={() => handleSuspend(user)}
                        >
                          {user.is_suspended ? 'Unsuspend' : 'Suspend'}
                        </button>
                        <button
                          className="btn btn-sm btn-danger"
                          disabled={actionLoading === user.id}
                          onClick={() => handleDelete(user)}
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {hasMore && (
              <div className="load-more-container">
                <button
                  className="btn btn-ghost"
                  onClick={handleLoadMore}
                  disabled={loadingMore}
                >
                  {loadingMore ? 'Loading…' : 'Load More'}
                </button>
              </div>
            )}
          </>
        )}
      </div>

      {confirmModal && (
        <ConfirmModal
          title={confirmModal.title}
          message={confirmModal.message}
          danger={confirmModal.danger}
          onConfirm={confirmModal.onConfirm}
          onCancel={() => setConfirmModal(null)}
        />
      )}
    </div>
  );
}

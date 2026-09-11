import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, resolveMediaUrl } from '../services/api';
import {
  Badge,
  ConfirmModal,
  EmptyState,
  ErrorBanner,
  LoadingBlock,
  Pagination,
  formatDate,
} from '../components/ui';

const PAGE_SIZE = 40;

export default function Items({ flaggedOnly = false }) {
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [confirmModal, setConfirmModal] = useState(null);

  const fetchItems = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const data = await api.getItems({
        search: search || undefined,
        category: category || undefined,
        flagged: flaggedOnly ? 'true' : undefined,
        limit: PAGE_SIZE,
        offset,
      });
      setItems(data.items || []);
      setTotal(data.total || 0);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [search, category, flaggedOnly, offset]);

  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  const run = async (fn) => {
    try {
      await fn();
      await fetchItems();
    } catch (err) {
      setError(err.message);
    } finally {
      setConfirmModal(null);
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1>{flaggedOnly ? 'Flagged items' : 'Items'}</h1>
        <p>
          {flaggedOnly
            ? 'Moderation queue for inappropriate or reported wardrobe uploads'
            : 'Browse wardrobe items across all users'}
        </p>
      </div>

      <ErrorBanner message={error} />

      <div className="toolbar">
        <input
          className="search-input"
          type="search"
          placeholder="Search name, category, brand…"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setOffset(0); }}
        />
        <select value={category} onChange={(e) => { setCategory(e.target.value); setOffset(0); }}>
          <option value="">Category: any</option>
          <option value="top">Top</option>
          <option value="bottom">Bottom</option>
          <option value="dress">Dress</option>
          <option value="outerwear">Outerwear</option>
          <option value="footwear">Footwear</option>
          <option value="accessory">Accessory</option>
        </select>
      </div>

      {loading ? (
        <LoadingBlock />
      ) : items.length === 0 ? (
        <EmptyState title={flaggedOnly ? 'No flagged items' : 'No items found'} />
      ) : (
        <>
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
                  <span>
                    <Link to={`/users/${item.user_id}`}>
                      {item.user_display_name || item.user_email || item.user_id}
                    </Link>
                  </span>
                  <span className="muted">{formatDate(item.created_at)}</span>
                  {item.flagged_reason ? (
                    <span className="danger-text">{item.flagged_reason}</span>
                  ) : null}
                  <div className="badge-row">
                    {!item.is_active ? <Badge tone="warning">Inactive</Badge> : null}
                    {item.is_flagged ? <Badge tone="danger">Flagged</Badge> : null}
                  </div>
                  <div className="row-actions">
                    {item.is_flagged ? (
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() => run(() => api.unflagItem(item.id))}
                      >
                        Unflag
                      </button>
                    ) : (
                      <button
                        type="button"
                        className="btn btn-ghost btn-sm"
                        onClick={() =>
                          setConfirmModal({
                            title: 'Flag item?',
                            message: 'Marks this upload for moderation review.',
                            onConfirm: () => run(() => api.flagItem(item.id, 'admin review')),
                          })
                        }
                      >
                        Flag
                      </button>
                    )}
                    <button
                      type="button"
                      className="btn btn-danger btn-sm"
                      onClick={() =>
                        setConfirmModal({
                          title: 'Soft-delete item?',
                          message: 'Sets is_active=false. The upload stays for audit.',
                          danger: true,
                          confirmLabel: 'Deactivate',
                          onConfirm: () => run(() => api.deleteItem(item.id)),
                        })
                      }
                    >
                      Deactivate
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <Pagination offset={offset} limit={PAGE_SIZE} total={total} onChange={setOffset} />
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

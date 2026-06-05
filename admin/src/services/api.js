const BASE_URL = import.meta.env.VITE_API_BASE_URL || '';

function getAuthHeaders() {
  const token = localStorage.getItem('admin_token');
  const headers = { 'Content-Type': 'application/json' };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
}

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    headers: getAuthHeaders(),
    ...options,
  });

  if (res.status === 401 || res.status === 403) {
    localStorage.removeItem('admin_token');
    window.location.href = '/login';
    throw new Error('Unauthorized');
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail || body.message || `HTTP ${res.status}`);
  }

  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  // KPIs
  getStats: () => request('/admin/stats'),

  // Time-series
  getTimeseries: (days = 30) => request(`/admin/stats/timeseries?days=${days}`),

  // Users
  getUsers: (search = '', limit = 50, offset = 0) =>
    request(`/admin/users?search=${encodeURIComponent(search)}&limit=${limit}&offset=${offset}`),

  getUser: (id) => request(`/admin/users/${id}`),

  suspendUser: (id) =>
    request(`/admin/users/${id}/suspend`, { method: 'PUT' }),

  deleteUser: (id) =>
    request(`/admin/users/${id}`, { method: 'DELETE' }),

  // AI Usage
  getAiUsage: () => request('/admin/ai-usage'),

  // System Health
  getSystemHealth: () => request('/admin/system-health'),
};

function adminPath(path) {
  const base = (import.meta.env.BASE_URL || '/workadmin/').replace(/\/$/, '');
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}

const BASE_URL = import.meta.env.VITE_API_BASE_URL || '';

/** Resolve API-relative media paths (e.g. /uploads/...) for <img src>. */
export function resolveMediaUrl(url) {
  if (!url) return '';
  if (/^https?:\/\//i.test(url) || url.startsWith('data:')) return url;
  // Dev: Vite proxies /uploads → API. Prod Worker also proxies /uploads.
  // If VITE_API_BASE_URL is set (absolute), prefix so images hit the API origin.
  if (url.startsWith('/') && BASE_URL) {
    return `${BASE_URL.replace(/\/$/, '')}${url}`;
  }
  return url;
}

function getAuthHeaders() {
  const token = localStorage.getItem('admin_token');
  const headers = { 'Content-Type': 'application/json' };
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }
  return headers;
}

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      ...getAuthHeaders(),
      ...(options.headers || {}),
    },
  });

  if (res.status === 401 || res.status === 403) {
    localStorage.removeItem('admin_token');
    window.location.href = adminPath('/login');
    throw new Error(res.status === 403 ? 'Admin access required' : 'Unauthorized');
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    const detail = body.detail;
    let message =
      typeof detail === 'string'
        ? detail
        : Array.isArray(detail)
          ? detail.map((d) => d.msg || d).join(', ')
          : body.message || `HTTP ${res.status}`;
    if (
      !body.detail &&
      [520, 521, 522, 523, 524, 530, 502, 503].includes(res.status)
    ) {
      message =
        `API origin unreachable (HTTP ${res.status}). Deploy api.sugatai.com / set Worker API_ORIGIN, then refresh.`;
    }
    throw new Error(message);
  }

  if (res.status === 204) return null;
  return res.json();
}

function qs(params = {}) {
  const sp = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') sp.set(k, String(v));
  });
  const s = sp.toString();
  return s ? `?${s}` : '';
}

export const api = {
  getStats: () => request('/admin/stats'),

  getTimeseries: async (days = 30) => {
    const data = await request(`/admin/stats/timeseries?days=${days}`);
    return data.series || data;
  },

  getUsers: (params = {}) =>
    request(`/admin/users${qs({ limit: 50, offset: 0, ...params })}`),

  getUser: (id) => request(`/admin/users/${id}`),

  patchUser: (id, body) =>
    request(`/admin/users/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),

  resetOnboarding: (id) =>
    request(`/admin/users/${id}/reset-onboarding`, { method: 'POST' }),

  suspendUser: (id, suspended) =>
    request(`/admin/users/${id}/suspend`, {
      method: 'PUT',
      body: JSON.stringify({ suspended }),
    }),

  deleteUser: (id) => request(`/admin/users/${id}`, { method: 'DELETE' }),

  getUserItems: (id, params = {}) =>
    request(`/admin/users/${id}/items${qs({ limit: 40, offset: 0, ...params })}`),

  getUserOutfits: (id, params = {}) =>
    request(`/admin/users/${id}/outfits${qs({ limit: 20, offset: 0, ...params })}`),

  getUserLookbooks: (id) => request(`/admin/users/${id}/lookbooks`),

  getUserActivity: (id, limit = 50) =>
    request(`/admin/users/${id}/activity?limit=${limit}`),

  getUserTryOns: (id, params = {}) =>
    request(`/admin/users/${id}/try-ons${qs({ limit: 30, offset: 0, ...params })}`),

  getItems: (params = {}) =>
    request(`/admin/items${qs({ limit: 40, offset: 0, ...params })}`),

  flagItem: (id, reason) =>
    request(`/admin/items/${id}/flag`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    }),

  unflagItem: (id) =>
    request(`/admin/items/${id}/unflag`, { method: 'POST' }),

  deleteItem: (id) => request(`/admin/items/${id}`, { method: 'DELETE' }),

  getAiUsage: async (days = 30) => {
    const data = await request(`/admin/ai-usage?days=${days}`);
    return data.usage || data;
  },

  getAnalyticsOverview: (days = 30) =>
    request(`/admin/analytics/overview?days=${days}`),

  getAnalyticsCosts: (days = 30) =>
    request(`/admin/analytics/costs?days=${days}`),

  getAnalyticsUsage: (days = 30) =>
    request(`/admin/analytics/usage?days=${days}`),

  getTopUsers: (metric = 'items', days = 30) =>
    request(`/admin/analytics/top-users?metric=${metric}&days=${days}`),

  getWaitlist: (params = {}) =>
    request(`/admin/waitlist${qs({ limit: 50, offset: 0, ...params })}`),

  getPushSegments: () => request('/admin/push/segments'),

  sendPush: (body) =>
    request('/admin/push/send', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  getSystemHealth: () => request('/admin/system-health'),
};

export { adminPath, BASE_URL };

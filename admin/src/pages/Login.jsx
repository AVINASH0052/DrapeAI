import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { isFirebaseConfigured, signInAdmin } from '../services/firebase';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const isDev = import.meta.env.DEV || import.meta.env.VITE_ENV === 'development';
  const firebaseReady = isFirebaseConfigured();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!email || !password) {
      setError('Please enter both email and password.');
      return;
    }

    setLoading(true);
    try {
      let token;
      if (firebaseReady) {
        token = await signInAdmin(email, password);
      } else if (isDev) {
        // Local bypass when Firebase web config is not set
        token = 'test-token';
      } else {
        throw new Error('Admin login is not configured. Set VITE_FIREBASE_* env vars.');
      }

      localStorage.setItem('admin_token', token);

      // Verify admin privileges against the API before entering the console
      const base = import.meta.env.VITE_API_BASE_URL || '';
      const verify = await fetch(`${base}/admin/stats`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (verify.status === 403) {
        localStorage.removeItem('admin_token');
        throw new Error('This account is not an admin. Ask an operator to set is_admin=true.');
      }
      if (verify.status === 401) {
        localStorage.removeItem('admin_token');
        throw new Error('Invalid credentials or token.');
      }
      if (!verify.ok) {
        // Allow entering the UI when API origin is down (e.g. HTTP 530) so ops can still navigate;
        // data screens will surface the error.
        if (verify.status >= 500 || verify.status === 530) {
          // keep token
        } else {
          localStorage.removeItem('admin_token');
          const body = await verify.json().catch(() => ({}));
          throw new Error(body.detail || `Could not verify admin access (HTTP ${verify.status})`);
        }
      }

      navigate('/', { replace: true });
    } catch (err) {
      setError(err.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-brand">
          <img src={`${import.meta.env.BASE_URL}brand/sugatai-wordmark.svg`} alt="Sugatai" />
        </div>
        <p className="login-subtitle">Admin console · Sign in to continue</p>

        {error && <div className="error-message">{error}</div>}

        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="login-email">Email</label>
            <input
              id="login-email"
              type="email"
              placeholder="admin@sugatai.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              autoFocus
            />
          </div>

          <div className="form-group">
            <label htmlFor="login-password">Password</label>
            <input
              id="login-password"
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
            />
          </div>

          <button
            type="submit"
            className="btn btn-primary"
            disabled={loading}
          >
            {loading ? 'Signing in…' : 'Sign In'}
          </button>
        </form>
        <p className="login-footnote">
          {firebaseReady
            ? 'Firebase Auth · admin accounts only'
            : isDev
              ? 'Dev mode · any credentials use test-token'
              : 'see your look, before you wear it'}
        </p>
      </div>
    </div>
  );
}

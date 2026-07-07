import { Routes, Route, NavLink, Navigate } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import SystemHealth from './pages/SystemHealth';
import Login from './pages/Login';

function ProtectedRoute({ children }) {
  const token = localStorage.getItem('admin_token');
  if (!token) return <Navigate to="/login" replace />;
  return children;
}

function Sidebar() {
  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    window.location.href = '/login';
  };

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <h1>DrapeAI</h1>
        <span>Admin Console</span>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/" end className={({ isActive }) => isActive ? 'active' : ''}>
          <span className="nav-icon">📊</span>
          <span>Dashboard</span>
        </NavLink>
        <NavLink to="/users" className={({ isActive }) => isActive ? 'active' : ''}>
          <span className="nav-icon">👥</span>
          <span>Users</span>
        </NavLink>
        <NavLink to="/system" className={({ isActive }) => isActive ? 'active' : ''}>
          <span className="nav-icon">🖥️</span>
          <span>System Health</span>
        </NavLink>
      </nav>

      <div className="sidebar-footer">
        <button onClick={handleLogout}>Sign Out</button>
      </div>
    </aside>
  );
}

function AppLayout() {
  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/users" element={<Users />} />
          <Route path="/system" element={<SystemHealth />} />
        </Routes>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/*"
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      />
    </Routes>
  );
}

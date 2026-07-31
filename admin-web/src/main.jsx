import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter, NavLink, Navigate, Route, Routes } from 'react-router-dom';
import axios from 'axios';
import './styles.css';

const api = axios.create({ baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8080/api' });
const Auth = createContext(null);
const useAuth = () => useContext(Auth);

function AuthProvider({ children }) {
  const [session, setSession] = useState(() => sessionStorage.getItem('admin-session') ? JSON.parse(sessionStorage.getItem('admin-session')) : null);
  useEffect(() => {
    const id = api.interceptors.request.use((config) => {
      if (session?.token) config.headers.Authorization = `Bearer ${session.token}`;
      return config;
    });
    return () => api.interceptors.request.eject(id);
  }, [session]);
  const value = useMemo(() => ({ session, signIn(next) { sessionStorage.setItem('admin-session', JSON.stringify(next)); setSession(next); }, signOut() { sessionStorage.removeItem('admin-session'); setSession(null); } }), [session]);
  return <Auth.Provider value={value}>{children}</Auth.Provider>;
}

function Login() {
  const { signIn } = useAuth(); const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [error, setError] = useState('');
  async function submit(event) { event.preventDefault(); try { const { data } = await api.post('/auth/login', { email, password }); if (data.role !== 'ADMIN') throw new Error('This account is not an administrator.'); signIn(data); } catch (err) { setError(err.response?.data?.message || err.message || 'Sign in failed'); } }
  return <main className="login"><form onSubmit={submit}><span className="eyebrow">MAIDITQUICK</span><h1>Admin command center</h1><p>Use your existing MaidItQuick administrator account.</p><label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label><label>Password<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required /></label>{error && <p className="error">{error}</p>}<button>Sign in</button></form></main>;
}

const navigation = [['/', 'Overview'], ['/users', 'Users']];
function Layout() { const { session, signOut } = useAuth(); return <div className="shell"><aside><div className="brand">Maid<span>It</span>Quick<small>ADMIN</small></div><nav>{navigation.map(([path, label]) => <NavLink end={path === '/'} to={path} key={path}>{label}</NavLink>)}</nav><button className="quiet" onClick={signOut}>Sign out</button></aside><section className="content"><header><span className="eyebrow">OPERATIONS</span><h2>Welcome, {session.name}</h2></header><Routes><Route path="/" element={<Dashboard />} /><Route path="/users" element={<Users />} /><Route path="*" element={<Navigate to="/" replace />} /></Routes></section></div>; }

function Dashboard() { const [data, setData] = useState(null); const [error, setError] = useState(''); useEffect(() => { api.get('/admin/dashboard/summary').then(({ data: value }) => setData(value)).catch(() => setError('Dashboard data is unavailable.')); }, []); const cards = [['Active users', 'totalUsers'], ['Workers', 'totalWorkers'], ['All bookings', 'totalBookings'], ['Requested', 'requestedBookings'], ['In progress', 'activeBookings'], ['Completed', 'completedBookings']]; return <><div className="page-title"><h1>Business at a glance</h1><p>Shared, live MySQL data used by the mobile applications.</p></div>{error && <p className="error">{error}</p>}<div className="cards">{cards.map(([label, key]) => <article className="card" key={key}><span>{label}</span><strong>{data?.[key] ?? '—'}</strong></article>)}</div></>; }

function Users() { const [result, setResult] = useState({ items: [] }); const [query, setQuery] = useState(''); const [error, setError] = useState(''); async function search(event) { event?.preventDefault(); try { setResult((await api.get('/admin/users', { params: { query } })).data); } catch { setError('Users could not be loaded.'); } } useEffect(() => { search(); }, []); async function toggle(user) { try { await api.patch(`/admin/users/${user.id}/status`, { enabled: user.status !== 'ACTIVE' }); await search(); } catch { setError('User status could not be changed.'); } } return <><div className="page-title"><h1>User management</h1><p>Customer, worker, and administrator accounts from the shared identity store.</p></div><form className="filters" onSubmit={search}><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search name or email" /><button>Search</button></form>{error && <p className="error">{error}</p>}<section className="panel"><table><thead><tr><th>User</th><th>Role</th><th>Status</th><th>Joined</th><th /></tr></thead><tbody>{result.items.map((user) => <tr key={user.id}><td>{user.name}<small>{user.email}</small></td><td>{user.role}</td><td>{user.status}</td><td>{new Date(user.createdAt).toLocaleDateString()}</td><td><button className="secondary" onClick={() => toggle(user)}>{user.status === 'ACTIVE' ? 'Suspend' : 'Activate'}</button></td></tr>)}{!result.items.length && <tr><td colSpan="5">No accounts found.</td></tr>}</tbody></table></section></>; }

function App() { const { session } = useAuth(); return session ? <Layout /> : <Login />; }
createRoot(document.getElementById('root')).render(<BrowserRouter><AuthProvider><App /></AuthProvider></BrowserRouter>);

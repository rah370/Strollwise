import { useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link, NavLink, Navigate, Outlet, useNavigate } from 'react-router-dom'
import { ApiError, API_URL, apiDocsUrl, fetchMe, getToken, legalUrl, setToken } from '../api/client'
import { AdminLiveProvider, useAdminLiveConnected } from '../hooks/useAdminLiveUpdates'
import { BrandLogo } from './BrandLogo'

const nav = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/moderation', label: 'Review tags' },
  { to: '/zones', label: 'Places' },
  { to: '/users', label: 'Users' },
  { to: '/catalog', label: 'Place list' },
  { to: '/analytics', label: 'Export' },
  { to: '/settings', label: 'Settings' },
  { to: '/audit', label: 'Activity' },
]

function navClass({ isActive }: { isActive: boolean }) {
  return [
    'px-3 py-2.5 rounded-xl text-sm font-semibold block transition-colors',
    isActive
      ? 'bg-sw-primary text-white shadow-sm'
      : 'text-sw-secondary hover:bg-white/10 hover:text-white',
  ].join(' ')
}

/** Shell: sidebar nav + JWT gate. Non-admins are sent back to login. */
export function AppLayout() {
  const token = getToken()
  if (!token) return <Navigate to="/login" replace />
  return (
    <AdminLiveProvider>
      <AppLayoutInner />
    </AdminLiveProvider>
  )
}

function AppLayoutInner() {
  const navigate = useNavigate()
  const token = getToken()
  const { data: me, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['auth', 'me'],
    queryFn: fetchMe,
    enabled: Boolean(token),
    retry: false,
  })
  const connected = useAdminLiveConnected()
  const authDenied =
    (isError && error instanceof ApiError && (error.status === 401 || error.status === 403)) ||
    Boolean(me && !me.is_admin)

  useEffect(() => {
    if (authDenied) setToken(null)
  }, [authDenied])

  if (!token) return <Navigate to="/login" replace />
  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-sw-bg text-sw-muted">
        Checking admin access…
      </div>
    )
  }
  if (authDenied) {
    return <Navigate to="/login" replace state={{ reason: 'admin_required' }} />
  }
  if (isError) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-sw-bg text-sw-muted p-6">
        <div className="max-w-md text-center space-y-3">
          <p className="font-semibold text-sw-ink">Cannot reach the StrollWise API.</p>
          <p className="text-sm">
            Wake{' '}
            <a className="underline" href={`${API_URL || 'https://strollwise-api.onrender.com'}/health`}>
              /health
            </a>{' '}
            and retry. Your session was kept.
          </p>
          <button
            type="button"
            className="px-4 py-2 rounded-xl bg-sw-primary text-white text-sm font-semibold"
            onClick={() => refetch()}
          >
            Retry
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen flex bg-sw-bg">
      <aside className="w-60 bg-sw-map-ink text-white p-4 flex flex-col gap-1 shrink-0">
        <Link to="/" className="mb-5 px-1 block">
          <BrandLogo size="sm" subtitle="Admin Console" variant="dark" />
        </Link>

        <nav className="flex flex-col gap-0.5 flex-1">
          {nav.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.end} className={navClass}>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="mt-4 pt-4 border-t border-white/10 space-y-2">
          <div className="px-3 flex items-center gap-2 text-[10px] font-bold uppercase tracking-wide">
            <span
              className={`w-2 h-2 rounded-full ${connected ? 'bg-sw-primary animate-pulse' : 'bg-white/30'}`}
              aria-hidden
            />
            <span className={connected ? 'text-sw-primary' : 'text-white/40'}>
              {connected ? 'Live — mobile sync' : 'Polling fallback'}
            </span>
          </div>
          {apiDocsUrl() ? (
            <a
              href={apiDocsUrl()!}
              target="_blank"
              rel="noreferrer"
              className="block px-3 py-2 text-xs font-semibold text-sw-secondary hover:text-white"
            >
              API docs ↗
            </a>
          ) : null}
          <a
            href={legalUrl('/privacy')}
            target="_blank"
            rel="noreferrer"
            className="block px-3 py-2 text-xs font-semibold text-sw-secondary hover:text-white"
          >
            Privacy
          </a>
          <a
            href={legalUrl('/terms')}
            target="_blank"
            rel="noreferrer"
            className="block px-3 py-2 text-xs font-semibold text-sw-secondary hover:text-white"
          >
            Terms
          </a>
          <p className="px-3 text-[10px] text-white/40 leading-relaxed">
            Paired with the StrollWise mobile app for crowd-sourced zone intelligence in Metro Cebu.
          </p>
          <button
            type="button"
            className="w-full px-3 py-2 text-left text-sm font-semibold text-white/60 hover:text-white rounded-xl hover:bg-white/5"
            onClick={() => {
              setToken(null)
              navigate('/login', { replace: true })
            }}
          >
            Sign out
          </button>
        </div>
      </aside>
      <main className="flex-1 p-6 lg:p-8 overflow-auto min-w-0">
        <Outlet />
      </main>
    </div>
  )
}

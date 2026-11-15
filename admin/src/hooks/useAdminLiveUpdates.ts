import { createContext, createElement, useContext, useEffect, useState, type ReactNode } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { API_URL, getToken } from '../api/client'

function invalidateForEvent(qc: ReturnType<typeof useQueryClient>, type: string) {
  switch (type) {
    case 'report.created':
    case 'report.approved':
    case 'report.rejected':
    case 'report.flagged':
      qc.invalidateQueries({ queryKey: ['moderation'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['audit'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
      qc.invalidateQueries({ queryKey: ['analytics-overview'] })
      qc.invalidateQueries({ queryKey: ['users'] })
      break
    case 'zones.updated':
      qc.invalidateQueries({ queryKey: ['zones'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
      qc.invalidateQueries({ queryKey: ['analytics-overview'] })
      break
    case 'dashboard.refresh':
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['analytics-overview'] })
      break
    case 'catalog.updated':
      qc.invalidateQueries({ queryKey: ['catalog'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      break
    default:
      break
  }
}

const AdminLiveContext = createContext(false)

/**
 * Server-Sent Events from `/api/v1/admin/events?token=...`.
 *
 * EventSource cannot send Authorization headers, so the JWT is a query
 * param (`verify_admin_token`). The stream must not hold a DB session.
 */
export function useAdminLiveUpdates() {
  const qc = useQueryClient()
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    const token = getToken()
    if (!token) return

    const url = `${API_URL}/api/v1/admin/events?token=${encodeURIComponent(token)}`
    let stopped = false
    let retryMs = 1000
    let timer: ReturnType<typeof setTimeout> | undefined
    let es: EventSource | null = null

    const connect = () => {
      if (stopped) return
      es = new EventSource(url)
      es.onopen = () => {
        setConnected(true)
        retryMs = 1000
      }
      es.onerror = () => {
        setConnected(false)
        es?.close()
        es = null
        if (stopped) return
        const wait = retryMs
        retryMs = Math.min(retryMs * 2, 30_000)
        timer = setTimeout(connect, wait)
      }
      es.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data) as { type?: string }
          if (msg.type && msg.type !== 'connected') {
            invalidateForEvent(qc, msg.type)
          }
        } catch {
          /* ignore malformed events */
        }
      }
    }

    connect()
    return () => {
      stopped = true
      if (timer) clearTimeout(timer)
      es?.close()
      setConnected(false)
    }
  }, [qc])

  return { connected }
}

export function AdminLiveProvider({ children }: { children: ReactNode }) {
  const { connected } = useAdminLiveUpdates()
  return createElement(AdminLiveContext.Provider, { value: connected }, children)
}

export function useAdminLiveConnected() {
  return useContext(AdminLiveContext)
}

/** Poll only when SSE is down so live mode does not double-fetch. */
export function useAdminPollInterval(ms: number): number | false {
  const connected = useAdminLiveConnected()
  return connected ? false : ms
}

/** Fallback polling when SSE is unavailable (same data the mobile app writes). */
export const LIVE_POLL_MS = {
  dashboard: 30_000,
  moderation: 15_000,
  zones: 30_000,
  audit: 30_000,
  users: 60_000,
  catalog: 60_000,
  analytics: 60_000,
} as const

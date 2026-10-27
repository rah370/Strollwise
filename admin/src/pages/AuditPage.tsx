import { Link, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { api, downloadExport } from '../api/client'
import type { AdminAuditEntry } from '../api/types'
import { Badge } from '../components/Badge'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { useEffect, useState } from 'react'
import { auditLabel, categoryLabel, manilaWhen } from '../lib/copy'

type AuditList = {
  items: AdminAuditEntry[]
  total: number
  page?: number
  page_size?: number
}

const PAGE_SIZE = 20
const tabs = [
  { id: 'admin', label: 'Admin decisions' },
  { id: 'travelers', label: 'Tags travelers sent' },
] as const

export function AuditPage() {
  const navigate = useNavigate()
  const [exportError, setExportError] = useState('')
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [page, setPage] = useState(1)
  const [scope, setScope] = useState<(typeof tabs)[number]['id']>('admin')
  const [since, setSince] = useState('')
  const [until, setUntil] = useState('')

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  useEffect(() => {
    setPage(1)
  }, [debounced, scope, since, until])

  const poll = useAdminPollInterval(LIVE_POLL_MS.audit)
  const query = new URLSearchParams({
    page: String(page),
    page_size: String(PAGE_SIZE),
    scope,
  })
  if (debounced) query.set('q', debounced)
  if (since) query.set('since', since)
  if (until) query.set('until', until)

  const { data, isLoading } = useQuery({
    queryKey: ['audit', query.toString()],
    queryFn: () => api<AuditList>(`/admin/audit?${query}`),
    refetchInterval: poll,
  })

  const items = data?.items ?? []

  async function exportAudit() {
    setExportError('')
    try {
      await downloadExport('/admin/analytics/export/audit?fmt=csv', 'strollwise-activity.csv')
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Export failed')
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Activity"
        description="A diary of admin decisions and tags travelers sent. Times are Asia/Manila. No IDs or emails."
        actions={
          <>
            <Button variant="secondary" onClick={exportAudit}>Download spreadsheet</Button>
            <Link to="/analytics">
              <Button variant="ghost">Back to export</Button>
            </Link>
          </>
        }
      />

      {exportError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {exportError}
        </div>
      ) : null}

      <div className="flex gap-2 flex-wrap">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setScope(t.id)}
            className={`px-4 py-2 rounded-xl text-sm font-bold border ${
              scope === t.id
                ? 'bg-sw-primary text-white border-sw-primary'
                : 'bg-sw-surface text-sw-muted border-sw-border'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap gap-3">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search what happened…"
          className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface w-full md:w-80"
        />
        <label className="text-sm text-sw-muted flex items-center gap-2">
          From
          <input
            type="date"
            value={since}
            onChange={(e) => setSince(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
        </label>
        <label className="text-sm text-sw-muted flex items-center gap-2">
          To
          <input
            type="date"
            value={until}
            onChange={(e) => setUntil(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
        </label>
      </div>

      <Card className="p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-sw-bg-alt text-left sticky top-0">
            <tr>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">When</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">What happened</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Place</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Kind of tag</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Who</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Result</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr><td colSpan={6} className="p-6 text-sw-muted">Loading activity…</td></tr>
            ) : items.length === 0 ? (
              <tr><td colSpan={6} className="p-6 text-sw-muted">No activity in this view.</td></tr>
            ) : (
              items.map((e) => (
                <tr
                  key={e.id}
                  className={`border-t border-sw-border ${e.entity_type === 'report' && e.entity_id ? 'cursor-pointer hover:bg-sw-bg-alt/40' : ''}`}
                  onClick={() => {
                    if (e.entity_type === 'report' && e.entity_id) {
                      navigate(`/moderation?focus=${e.entity_id}`)
                    }
                  }}
                >
                  <td className="p-3 text-xs whitespace-nowrap">{manilaWhen(e.created_at)}</td>
                  <td className="p-3">
                    <Badge variant="default" value={e.action_type} label={auditLabel(e.action_type)} />
                  </td>
                  <td className="p-3 font-semibold">{e.area_name || '—'}</td>
                  <td className="p-3 text-sw-muted">{e.category ? categoryLabel(e.category) : '—'}</td>
                  <td className="p-3 text-sw-muted">{e.actor_label || '—'}</td>
                  <td className="p-3 font-semibold">
                    {e.result || '—'}
                    {e.reason ? <div className="text-[11px] text-sw-muted font-normal">{e.reason.replace(/_/g, ' ')}</div> : null}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
        <Pagination
          page={page}
          pageSize={PAGE_SIZE}
          total={data?.total ?? 0}
          onPageChange={setPage}
          noun="events"
        />
      </Card>
    </div>
  )
}

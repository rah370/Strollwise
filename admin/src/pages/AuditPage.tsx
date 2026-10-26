import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { api, downloadExport } from '../api/client'
import { Badge } from '../components/Badge'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { useEffect, useState } from 'react'
import { auditLabel } from '../lib/copy'

type AuditList = {
  items: {
    id: string
    action_type: string
    entity_type: string
    entity_id?: string | null
    created_at: string
  }[]
  total: number
  page?: number
  page_size?: number
}

const PAGE_SIZE = 20

export function AuditPage() {
  const [exportError, setExportError] = useState('')
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [page, setPage] = useState(1)

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim().toLowerCase()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  const poll = useAdminPollInterval(LIVE_POLL_MS.audit)
  const { data, isLoading } = useQuery({
    queryKey: ['audit', page],
    queryFn: () => api<AuditList>(`/admin/audit?page=${page}&page_size=${PAGE_SIZE}`),
    refetchInterval: poll,
  })

  const items = (data?.items ?? []).filter((e) => {
    if (!debounced) return true
    return (
      e.action_type.toLowerCase().includes(debounced) ||
      e.entity_type.toLowerCase().includes(debounced) ||
      auditLabel(e.action_type).toLowerCase().includes(debounced)
    )
  })

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
        description="A simple diary of what happened: tags sent, approved, flagged, or rejected. No traveler emails."
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

      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search this page (approved, flagged, tag…)"
        className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface w-full md:w-80"
      />

      <Card className="p-0 overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-sw-bg-alt text-left sticky top-0">
            <tr>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">When</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">What happened</th>
              <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">What it applied to</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr><td colSpan={3} className="p-6 text-sw-muted">Loading activity…</td></tr>
            ) : items.length === 0 ? (
              <tr><td colSpan={3} className="p-6 text-sw-muted">No activity on this page.</td></tr>
            ) : (
              items.map((e) => (
                <tr key={e.id} className="border-t border-sw-border hover:bg-sw-bg-alt/40">
                  <td className="p-3 text-xs whitespace-nowrap">
                    {new Date(e.created_at).toLocaleString()}
                  </td>
                  <td className="p-3">
                    <Badge variant="default" value={e.action_type} label={auditLabel(e.action_type)} />
                  </td>
                  <td className="p-3 font-semibold capitalize">{e.entity_type.replace(/_/g, ' ')}</td>
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

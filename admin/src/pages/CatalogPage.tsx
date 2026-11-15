import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { api } from '../api/client'
import type { AdminCatalogEntry } from '../api/types'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { travelerMixStyles } from '../theme/colors'

const PAGE_SIZE = 20

/** Named Cebu place list (the 14 catalog footprints researchers can inspect). */
export function CatalogPage() {
  const [exportError, setExportError] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const poll = useAdminPollInterval(LIVE_POLL_MS.catalog)

  const { data, isLoading } = useQuery({
    queryKey: ['catalog'],
    queryFn: () => api<AdminCatalogEntry[]>('/admin/catalog/zones'),
    refetchInterval: poll,
  })

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return data ?? []
    return (data ?? []).filter(
      (e) =>
        e.zone_name.toLowerCase().includes(q) ||
        e.city.toLowerCase().includes(q) ||
        e.zone_type.toLowerCase().includes(q) ||
        e.characteristics.some((c) => c.toLowerCase().includes(q)),
    )
  }, [data, search])

  const paged = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  function download(fmt: 'json' | 'csv') {
    setExportError('')
    const rows = filtered
    if (rows.length === 0) {
      setExportError('Nothing to export for this search.')
      return
    }
    try {
      const blob =
        fmt === 'json'
          ? new Blob([JSON.stringify(rows, null, 2)], { type: 'application/json' })
          : new Blob([catalogToCsv(rows)], { type: 'text/csv' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = fmt === 'csv' ? 'strollwise-place-list.csv' : 'strollwise-place-list.json'
      a.click()
      URL.revokeObjectURL(url)
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Export failed')
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Place list"
        description="The named Cebu places researchers assigned. Search a city or place so the table stays short."
        actions={
          <>
            <Button variant="secondary" onClick={() => download('csv')}>Download spreadsheet</Button>
            <Button variant="ghost" onClick={() => download('json')}>JSON</Button>
          </>
        }
      />

      {exportError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {exportError}
        </div>
      ) : null}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-2">
        <Card padding="p-4">
          <div className="text-[11px] font-bold uppercase text-sw-muted">Places in the list</div>
          <div className="text-2xl font-black mt-1">{data?.length ?? '—'}</div>
        </Card>
        <Card padding="p-4">
          <div className="text-[11px] font-bold uppercase text-sw-muted">Mostly locals</div>
          <div className="text-2xl font-black mt-1 text-green-700">
            {data?.filter((e) => e.zone_type === 'LOCAL').length ?? '—'}
          </div>
        </Card>
        <Card padding="p-4">
          <div className="text-[11px] font-bold uppercase text-sw-muted">Mostly visitors</div>
          <div className="text-2xl font-black mt-1 text-blue-700">
            {data?.filter((e) => e.zone_type === 'INTERNATIONAL').length ?? '—'}
          </div>
        </Card>
      </div>

      <input
        value={search}
        onChange={(e) => {
          setSearch(e.target.value)
          setPage(1)
        }}
        placeholder="Search place, city, or type…"
        className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface w-full md:w-80"
      />

      <Card className="p-0 overflow-hidden">
        <div className="overflow-auto max-h-[60vh]">
          <table className="w-full text-sm">
            <thead className="bg-sw-bg-alt sticky top-0">
              <tr>
                <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Place</th>
                <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">City</th>
                <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Who visits</th>
                <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Size</th>
                <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Local share</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr><td colSpan={5} className="p-6 text-sw-muted">Loading place list…</td></tr>
              ) : paged.length === 0 ? (
                <tr><td colSpan={5} className="p-6 text-sw-muted">No places match this search.</td></tr>
              ) : (
                paged.map((e) => {
                  const mixKey = e.zone_type.toLowerCase()
                  const mixStyle = travelerMixStyles[mixKey === 'local' ? 'local' : mixKey === 'international' ? 'international' : 'mixed']
                  return (
                    <tr key={e.zone_id} className="border-t border-sw-border hover:bg-sw-bg-alt/40">
                      <td className="p-3 font-bold">{e.zone_name}</td>
                      <td className="p-3 text-sw-muted">{e.city}</td>
                      <td className="p-3">
                        <span
                          className="text-[11px] font-bold uppercase px-2 py-0.5 rounded-full"
                          style={{ backgroundColor: mixStyle?.bg, color: mixStyle?.text }}
                        >
                          {e.zone_type === 'LOCAL'
                            ? 'Mostly locals'
                            : e.zone_type === 'INTERNATIONAL'
                              ? 'Mostly visitors'
                              : e.zone_type}
                        </span>
                      </td>
                      <td className="p-3">{e.radius_km} km</td>
                      <td className="p-3">{(e.default_local_ratio * 100).toFixed(0)}%</td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
        <Pagination
          page={page}
          pageSize={PAGE_SIZE}
          total={filtered.length}
          onPageChange={setPage}
          noun="places"
        />
      </Card>
    </div>
  )
}

function catalogToCsv(rows: AdminCatalogEntry[]): string {
  const headers = ['Place name', 'City', 'Who visits', 'Size in km', 'Local share', 'On the list']
  const lines = [headers.join(',')]
  for (const row of rows) {
    const who =
      row.zone_type === 'LOCAL'
        ? 'Mostly locals'
        : row.zone_type === 'INTERNATIONAL'
          ? 'Mostly visitors'
          : row.zone_type
    lines.push(
      [
        JSON.stringify(row.zone_name),
        JSON.stringify(row.city),
        JSON.stringify(who),
        String(row.radius_km),
        `${Math.round(row.default_local_ratio * 100)}%`,
        row.is_active ? 'Yes' : 'No',
      ].join(','),
    )
  }
  return `${lines.join('\n')}\n`
}

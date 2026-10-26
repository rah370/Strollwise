import { useQuery } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import { api } from '../api/client'
import type { AdminZone, AdminZoneValidation } from '../api/types'
import { Badge } from '../components/Badge'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { lifecycleLabel, liveStatusLabel, mixLabel } from '../lib/copy'
import { colors } from '../theme/colors'

const PAGE_SIZE = 20

export function ZonesPage() {
  const [filter, setFilter] = useState<'all' | 'defined' | 'emerging' | 'unthreshold'>('all')
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)

  const poll = useAdminPollInterval(LIVE_POLL_MS.zones)
  const { data, isLoading } = useQuery({
    queryKey: ['zones'],
    queryFn: () => api<AdminZone[]>('/admin/zones'),
    refetchInterval: poll,
  })

  const { data: validation } = useQuery({
    queryKey: ['zone-validation', selectedId],
    queryFn: () => api<AdminZoneValidation>(`/admin/zones/${selectedId}/validation`),
    enabled: !!selectedId,
  })

  const filtered = useMemo(() => {
    let rows = data ?? []
    if (filter !== 'all') rows = rows.filter((z) => z.lifecycle_state === filter)
    const q = search.trim().toLowerCase()
    if (q) {
      rows = rows.filter(
        (z) =>
          z.display_name.toLowerCase().includes(q) ||
          (z.function_type ?? '').toLowerCase().includes(q) ||
          (z.traveler_mix ?? '').toLowerCase().includes(q),
      )
    }
    return rows.sort((a, b) => b.confidence_score - a.confidence_score)
  }, [data, filter, search])

  const paged = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  const counts = useMemo(() => {
    const all = data ?? []
    return {
      all: all.length,
      defined: all.filter((z) => z.lifecycle_state === 'defined').length,
      emerging: all.filter((z) => z.lifecycle_state === 'emerging').length,
      unthreshold: all.filter((z) => z.lifecycle_state === 'unthreshold').length,
    }
  }, [data])

  return (
    <div className="space-y-4">
      <PageHeader
        title="Places"
        description="How sure we are about each place on the traveler map. Search a location so you are not working through the whole city at once."
      />

      <div className="flex flex-col sm:flex-row gap-3">
        <div className="flex gap-2 flex-wrap">
          {([
            ['all', 'All'],
            ['defined', 'Established'],
            ['emerging', 'Growing'],
            ['unthreshold', 'Just starting'],
          ] as const).map(([f, label]) => (
            <button
              key={f}
              type="button"
              onClick={() => {
                setFilter(f)
                setPage(1)
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold border ${
                filter === f
                  ? 'bg-sw-map-ink text-white border-sw-map-ink'
                  : 'bg-sw-surface border-sw-border text-sw-muted'
              }`}
            >
              {label} ({counts[f]})
            </button>
          ))}
        </div>
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
          placeholder="Search place or location…"
          className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface sm:ml-auto w-full sm:w-64"
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2 p-0 overflow-hidden">
          <div className="overflow-auto max-h-[65vh]">
            <table className="w-full text-sm">
              <thead className="bg-sw-bg-alt sticky top-0">
                <tr>
                  <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Place</th>
                  <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Who visits</th>
                  <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Stage</th>
                  <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">How sure</th>
                  <th className="p-3 text-left text-[11px] uppercase font-bold text-sw-muted">Tags</th>
                </tr>
              </thead>
              <tbody>
                {isLoading ? (
                  <tr><td colSpan={5} className="p-6 text-sw-muted">Loading places…</td></tr>
                ) : paged.length === 0 ? (
                  <tr><td colSpan={5} className="p-6 text-sw-muted">No places match this search.</td></tr>
                ) : (
                  paged.map((z) => (
                    <tr
                      key={z.zone_id}
                      className={`border-t border-sw-border cursor-pointer hover:bg-sw-bg-alt/50 ${
                        selectedId === z.zone_id ? 'bg-sw-secondary/10' : ''
                      }`}
                      onClick={() => setSelectedId(z.zone_id)}
                    >
                      <td className="p-3">
                        <div className="font-bold text-sw-ink">{z.display_name}</div>
                        <div className="text-xs text-sw-muted">{liveStatusLabel(z.live_status)}</div>
                      </td>
                      <td className="p-3 text-sw-muted">{mixLabel(z.traveler_mix)}</td>
                      <td className="p-3">
                        <Badge variant="lifecycle" value={z.lifecycle_state} label={lifecycleLabel(z.lifecycle_state)} />
                      </td>
                      <td className="p-3">
                        <div className="flex items-center gap-2">
                          <div className="w-16 h-2 rounded-full bg-sw-border overflow-hidden">
                            <div
                              className="h-full rounded-full"
                              style={{
                                width: `${Math.min(z.confidence_score, 100)}%`,
                                backgroundColor: colors.primary,
                              }}
                            />
                          </div>
                          <span className="font-bold">{z.confidence_score.toFixed(0)}%</span>
                        </div>
                      </td>
                      <td className="p-3 font-semibold">{z.report_count}</td>
                    </tr>
                  ))
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

        <Card className="h-fit sticky top-6">
          <h2 className="font-black text-sw-ink mb-3">Why this place looks this way</h2>
          {!selectedId || !validation ? (
            <p className="text-sm text-sw-muted">
              Select a place to see a short explanation you can share with a non-technical reviewer.
            </p>
          ) : (
            <div className="space-y-4 text-sm">
              <p className="text-sw-secondary leading-relaxed">
                {validation.plain_summary || `${validation.display_name} has ${validation.total_signals} tags.`}
              </p>
              <dl className="grid grid-cols-2 gap-3">
                <ValidationTile label="Tags sent here" value={validation.total_signals} />
                <ValidationTile label="Tags that agree" value={validation.matching_signals} />
                <ValidationTile label="How sure we are" value={`${validation.confidence.toFixed(0)}%`} />
                <ValidationTile
                  label="Last update"
                  value={
                    validation.last_updated
                      ? new Date(validation.last_updated).toLocaleDateString()
                      : '—'
                  }
                />
              </dl>
              <div className="bg-sw-bg rounded-xl p-3">
                <div className="text-[10px] font-bold uppercase text-sw-muted">Who visits</div>
                <div className="font-bold mt-1">{mixLabel(validation.traveler_mix)}</div>
              </div>
              <div className="bg-sw-bg rounded-xl p-3">
                <div className="text-[10px] font-bold uppercase text-sw-muted">Right now</div>
                <div className="font-bold mt-1">{liveStatusLabel(validation.live_status)}</div>
              </div>
              <Badge variant="lifecycle" value={validation.lifecycle_state} label={lifecycleLabel(validation.lifecycle_state)} />
            </div>
          )}
        </Card>
      </div>
    </div>
  )
}

function ValidationTile({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-sw-bg rounded-xl p-3">
      <dt className="text-[10px] font-bold uppercase text-sw-muted">{label}</dt>
      <dd className="text-lg font-black text-sw-ink mt-0.5">{value}</dd>
    </div>
  )
}

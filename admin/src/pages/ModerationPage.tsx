import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useMemo, useState } from 'react'
import { api } from '../api/client'
import type { AdminReportDetail, AdminReportList } from '../api/types'
import { Badge } from '../components/Badge'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { colors } from '../theme/colors'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { REPORT_CATEGORIES, categoryLabel, statusLabel } from '../lib/copy'

const PAGE_SIZE = 20

const queues = [
  { id: 'pending', label: 'Waiting', hint: 'Need a yes or no' },
  { id: 'flagged', label: 'Flagged', hint: 'Someone asked for a closer look' },
  { id: 'duplicates', label: 'Repeats', hint: 'Similar tags in the same area' },
  { id: 'near_threshold', label: 'Almost ready', hint: 'A few more matching tags would publish this' },
] as const

export function ModerationPage() {
  const qc = useQueryClient()
  const [queue, setQueue] = useState<(typeof queues)[number]['id']>('pending')
  const [selected, setSelected] = useState<string[]>([])
  const [focusedId, setFocusedId] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [category, setCategory] = useState('')
  const [tag, setTag] = useState('')
  const [page, setPage] = useState(1)
  const [actionError, setActionError] = useState('')

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  useEffect(() => {
    setPage(1)
    setSelected([])
  }, [queue, debounced, category, tag])

  const poll = useAdminPollInterval(LIVE_POLL_MS.moderation)
  const params = new URLSearchParams({
    queue,
    page: String(page),
    page_size: String(PAGE_SIZE),
  })
  if (debounced) params.set('search', debounced)
  if (category) params.set('category', category)
  if (tag.trim()) params.set('tag', tag.trim())

  const { data, isLoading } = useQuery({
    queryKey: ['moderation', params.toString()],
    queryFn: () => api<AdminReportList>(`/admin/moderation/reports?${params}`),
    refetchInterval: poll,
  })

  const { data: detail } = useQuery({
    queryKey: ['moderation-detail', focusedId],
    queryFn: () => api<AdminReportDetail>(`/admin/moderation/reports/${focusedId}`),
    enabled: !!focusedId,
  })

  const items = data?.items ?? []
  const visibleIds = useMemo(() => items.map((r) => r.id), [items])
  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selected.includes(id))

  const action = useMutation({
    mutationFn: async ({
      id,
      kind,
    }: {
      id: string
      kind: 'approve' | 'reject' | 'flag'
    }) => api(`/admin/moderation/reports/${id}/${kind}`, { method: 'POST' }),
    onSuccess: () => {
      setActionError('')
      qc.invalidateQueries({ queryKey: ['moderation'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['zones'] })
      setSelected([])
    },
    onError: (err: Error) => setActionError(err.message),
  })

  const bulk = useMutation({
    mutationFn: (kind: 'approve' | 'reject' | 'flag') =>
      api('/admin/moderation/reports/bulk', {
        method: 'POST',
        body: JSON.stringify({ report_ids: selected, action: kind }),
      }),
    onSuccess: () => {
      setActionError('')
      qc.invalidateQueries({ queryKey: ['moderation'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      setSelected([])
    },
    onError: (err: Error) => setActionError(err.message),
  })

  function toggleAll(checked: boolean) {
    setSelected(checked ? visibleIds : [])
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Review tags"
        description="Decide which traveler tags should appear on the public map. Search a place or tag so you are not scrolling through everything at once."
      />

      {actionError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {actionError}
        </div>
      ) : null}

      <div className="flex flex-col lg:flex-row gap-2">
        <div className="flex gap-2 flex-wrap flex-1">
          {queues.map((q) => (
            <button
              key={q.id}
              type="button"
              onClick={() => setQueue(q.id)}
              title={q.hint}
              className={`px-4 py-2 rounded-xl text-sm font-bold border transition-colors ${
                queue === q.id
                  ? 'bg-sw-primary text-white border-sw-primary'
                  : 'bg-sw-surface text-sw-muted border-sw-border hover:border-sw-primary/40'
              }`}
            >
              {q.label}
            </button>
          ))}
        </div>
      </div>

      <Card className="p-4">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input
            placeholder="Search place, tag, or note…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          >
            <option value="">All kinds of tags</option>
            {REPORT_CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {categoryLabel(c)}
              </option>
            ))}
          </select>
          <input
            placeholder="Filter by a specific tag word…"
            value={tag}
            onChange={(e) => setTag(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
        </div>
        <p className="text-xs text-sw-muted mt-2">
          Example: type “IT Park” or “lahug” to only see tags from that area.
        </p>
      </Card>

      {selected.length > 0 ? (
        <div className="flex gap-2 flex-wrap items-center">
          <Button onClick={() => bulk.mutate('approve')}>
            Approve selected ({selected.length})
          </Button>
          <Button variant="warning" onClick={() => bulk.mutate('flag')}>
            Flag selected
          </Button>
          <Button variant="danger" onClick={() => bulk.mutate('reject')}>
            Reject selected
          </Button>
          <button
            type="button"
            className="text-sm font-bold text-sw-muted"
            onClick={() => setSelected([])}
          >
            Clear selection
          </button>
        </div>
      ) : null}

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2 p-0 overflow-hidden">
          <div className="overflow-auto max-h-[65vh]">
            <table className="w-full text-sm">
              <thead className="bg-sw-bg-alt text-left sticky top-0">
                <tr>
                  <th className="p-3 w-10">
                    <input
                      type="checkbox"
                      aria-label="Select all on this page"
                      checked={allSelected}
                      onChange={(e) => toggleAll(e.target.checked)}
                    />
                  </th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Place or area</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Kind</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Tags</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Agreement</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Status</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Actions</th>
                </tr>
              </thead>
              <tbody>
                {isLoading ? (
                  <tr><td colSpan={7} className="p-6 text-sw-muted">Loading tags…</td></tr>
                ) : items.length === 0 ? (
                  <tr><td colSpan={7} className="p-6 text-sw-muted">Nothing in this list. Try another filter.</td></tr>
                ) : (
                  items.map((r) => (
                    <tr
                      key={r.id}
                      className={`border-t border-sw-border cursor-pointer hover:bg-sw-bg-alt/60 ${
                        focusedId === r.id ? 'bg-sw-primary/5' : ''
                      }`}
                      onClick={() => setFocusedId(r.id)}
                    >
                      <td className="p-3" onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selected.includes(r.id)}
                          onChange={(e) =>
                            setSelected((prev) =>
                              e.target.checked
                                ? [...prev, r.id]
                                : prev.filter((x) => x !== r.id),
                            )
                          }
                        />
                      </td>
                      <td className="p-3">
                        <div className="font-semibold">{r.area_name || 'Unnamed area'}</div>
                        <div className="text-[11px] text-sw-muted">
                          {r.contributor_count} people tagged this area
                        </div>
                      </td>
                      <td className="p-3 font-semibold">{categoryLabel(r.category)}</td>
                      <td className="p-3 text-sw-muted max-w-[160px] truncate">{r.tags.join(', ') || '—'}</td>
                      <td className="p-3">{Math.round(r.confidence_score)}%</td>
                      <td className="p-3">
                        <Badge variant="status" value={r.visibility_status} label={statusLabel(r.visibility_status)} />
                      </td>
                      <td className="p-3 space-x-1" onClick={(e) => e.stopPropagation()}>
                        <button type="button" className="text-sw-primary-dark font-bold text-xs" onClick={() => action.mutate({ id: r.id, kind: 'approve' })}>Approve</button>
                        <button type="button" className="text-amber-700 font-bold text-xs" onClick={() => action.mutate({ id: r.id, kind: 'flag' })}>Flag</button>
                        <button type="button" className="text-sw-alert font-bold text-xs" onClick={() => action.mutate({ id: r.id, kind: 'reject' })}>Reject</button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Pagination
            page={page}
            pageSize={PAGE_SIZE}
            total={data?.total ?? 0}
            onPageChange={setPage}
            noun="tags"
          />
        </Card>

        <Card className="h-fit sticky top-6">
          <h2 className="font-black text-sw-ink mb-3">Should this go on the map?</h2>
          {!focusedId || !detail ? (
            <p className="text-sm text-sw-muted">
              Select a tag to see how many other people described this area the same way.
            </p>
          ) : (
            <div className="space-y-4 text-sm">
              <p className="text-sw-secondary leading-relaxed">
                {detail.area_name || 'This area'} was tagged as{' '}
                <strong>{categoryLabel(detail.category)}</strong>
                {detail.tags.length ? ` (${detail.tags.join(', ')})` : ''}.{' '}
                {detail.cell_context.threshold_met
                  ? 'Enough people already agree, so approving it will publish it to the traveler map.'
                  : `${Math.max(detail.cell_context.threshold - detail.cell_context.distinct_contributors, 0)} more person(s) tagging the same thing would auto-publish this area.`}
              </p>
              {detail.note_text ? (
                <div>
                  <div className="text-[11px] font-bold uppercase text-sw-muted">Note from the traveler</div>
                  <p className="mt-1 text-sw-secondary">{detail.note_text}</p>
                </div>
              ) : null}
              <div className="grid grid-cols-2 gap-3">
                <Metric label="People in this area" value={detail.cell_context.distinct_contributors} />
                <Metric label="Needed to auto-publish" value={detail.cell_context.threshold} />
                <Metric label="Waiting here" value={detail.cell_context.pending_count} />
                <Metric label="How much they agree" value={`${Math.round(detail.cell_context.category_agreement * 100)}%`} />
              </div>
              <div>
                <div className="text-[11px] font-bold uppercase text-sw-muted">Most common tag here</div>
                <div className="font-semibold mt-1">{categoryLabel(detail.cell_context.top_category)}</div>
              </div>
              <div
                className="rounded-xl p-3 text-xs font-semibold"
                style={{
                  backgroundColor: detail.cell_context.threshold_met ? '#DDF5E8' : '#FFF4CC',
                  color: detail.cell_context.threshold_met ? colors.primaryDark : '#A16207',
                }}
              >
                {detail.cell_context.threshold_met
                  ? 'Ready for the map — approve if this looks right.'
                  : 'Not enough matching tags yet. Approve only if you personally know this place.'}
              </div>
              <div className="flex gap-2 pt-2 flex-wrap">
                <Button className="flex-1 min-w-[6rem]" onClick={() => action.mutate({ id: detail.id, kind: 'approve' })}>Approve</Button>
                <Button variant="warning" onClick={() => action.mutate({ id: detail.id, kind: 'flag' })}>Flag</Button>
                <Button variant="danger" onClick={() => action.mutate({ id: detail.id, kind: 'reject' })}>Reject</Button>
              </div>
            </div>
          )}
        </Card>
      </div>
    </div>
  )
}

function Metric({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="bg-sw-bg rounded-xl p-3">
      <div className="text-[10px] font-bold uppercase text-sw-muted">{label}</div>
      <div className="text-lg font-black text-sw-ink mt-0.5">{value}</div>
    </div>
  )
}

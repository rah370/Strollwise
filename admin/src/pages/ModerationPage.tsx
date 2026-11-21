/**
 * Review queue for pending/flagged tags.
 *
 * Approve publishes the cell (same rebuild path as auto-threshold).
 * Reject/remove keeps it off the traveler map. Reasons are audited.
 */
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import type { AdminReportDetail, AdminReportList } from '../api/types'
import { Badge } from '../components/Badge'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { colors } from '../theme/colors'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import {
  MODERATION_REASONS,
  MODERATION_REASON_HINTS,
  REPORT_CATEGORIES,
  categoryLabel,
  moderationReasonLabel,
  statusLabel,
} from '../lib/copy'

const PAGE_SIZE = 20

const queues = [
  { id: 'pending', label: 'Waiting', hint: 'Need a yes or no' },
  { id: 'flagged', label: 'Hold', hint: 'Needs a reason before it can go on the map' },
  { id: 'near_threshold', label: 'Almost ready', hint: 'A few more matching tags would publish this' },
  { id: 'mixed_agreement', label: 'Mixed', hint: 'People described this area differently' },
  { id: 'duplicates', label: 'Repeats', hint: 'Similar tags in the same area' },
  { id: 'all', label: 'All', hint: 'Every tag, including published ones' },
] as const

type QueueId = (typeof queues)[number]['id']
type ActionKind = 'approve' | 'reject' | 'flag'

export function ModerationPage() {
  const qc = useQueryClient()
  const [params] = useSearchParams()
  const [queue, setQueue] = useState<QueueId>('pending')
  const [selected, setSelected] = useState<string[]>([])
  const [focusedId, setFocusedId] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [category, setCategory] = useState('')
  const [tag, setTag] = useState('')
  const [contributorId, setContributorId] = useState('')
  const [page, setPage] = useState(1)
  const [actionError, setActionError] = useState('')
  const [pendingAction, setPendingAction] = useState<{ kind: ActionKind; ids: string[] } | null>(null)
  const [reason, setReason] = useState<(typeof MODERATION_REASONS)[number] | ''>('')

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  useEffect(() => {
    setPage(1)
    setSelected([])
  }, [queue, debounced, category, tag, contributorId])

  useEffect(() => {
    const focus = params.get('focus')
    const person = params.get('contributor')
    if (focus) {
      setFocusedId(focus)
      setQueue('all')
    }
    if (person) setContributorId(person)
  }, [params])

  const poll = useAdminPollInterval(LIVE_POLL_MS.moderation)
  const query = new URLSearchParams({
    queue,
    page: String(page),
    page_size: String(PAGE_SIZE),
  })
  if (debounced) query.set('search', debounced)
  if (category) query.set('category', category)
  if (tag.trim()) query.set('tag', tag.trim())
  if (contributorId) query.set('contributor_id', contributorId)

  const { data, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['moderation', query.toString()],
    queryFn: () => api<AdminReportList>(`/admin/moderation/reports?${query}`),
    refetchInterval: poll,
  })

  const { data: detail, isError: detailError, error: detailErr, refetch: refetchDetail } = useQuery({
    queryKey: ['moderation-detail', focusedId],
    queryFn: () => api<AdminReportDetail>(`/admin/moderation/reports/${focusedId}`),
    enabled: !!focusedId,
  })

  const items = data?.items ?? []
  const visibleIds = useMemo(() => items.map((r) => r.id), [items])
  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selected.includes(id))
  const selectedRows = items.filter((r) => selected.includes(r.id))
  const canBulkPublish =
    selectedRows.length > 0 && selectedRows.every((r) => r.confidence_score >= 60)

  const action = useMutation({
    mutationFn: async ({
      id,
      kind,
      reasonCode,
    }: {
      id: string
      kind: ActionKind
      reasonCode?: string
    }) =>
      api(`/admin/moderation/reports/${id}/${kind}`, {
        method: 'POST',
        body: JSON.stringify(reasonCode ? { reason: reasonCode } : {}),
      }),
    onSuccess: () => {
      setActionError('')
      setPendingAction(null)
      qc.invalidateQueries({ queryKey: ['moderation'] })
      qc.invalidateQueries({ queryKey: ['moderation-detail'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['zones'] })
      qc.invalidateQueries({ queryKey: ['audit'] })
      setSelected([])
    },
    onError: (err: Error) => setActionError(err.message),
  })

  const bulk = useMutation({
    mutationFn: ({ kind, reasonCode }: { kind: ActionKind; reasonCode?: string }) =>
      api('/admin/moderation/reports/bulk', {
        method: 'POST',
        body: JSON.stringify({
          report_ids: selected,
          action: kind,
          reason: reasonCode,
        }),
      }),
    onSuccess: () => {
      setActionError('')
      setPendingAction(null)
      qc.invalidateQueries({ queryKey: ['moderation'] })
      qc.invalidateQueries({ queryKey: ['moderation-detail'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['audit'] })
      setSelected([])
    },
    onError: (err: Error) => setActionError(err.message),
  })

  function toggleAll(checked: boolean) {
    setSelected(checked ? visibleIds : [])
  }

  function requestAction(kind: ActionKind, ids: string[]) {
    if (ids.length === 0) return
    setActionError('')
    if (kind === 'approve') {
      if (ids.length === 1) action.mutate({ id: ids[0], kind })
      else bulk.mutate({ kind })
      return
    }
    // Hold and Wrong need an audit reason. Production used to POST with
    // an empty body, which 422'd "Choose a reason" and never rejected.
    setFocusedId(ids[0])
    setReason('')
    setPendingAction({ kind, ids })
  }

  function confirmReasonedAction() {
    if (!pendingAction || !reason) return
    if (pendingAction.ids.length === 1) {
      action.mutate({ id: pendingAction.ids[0], kind: pendingAction.kind, reasonCode: reason })
    } else {
      bulk.mutate({ kind: pendingAction.kind, reasonCode: reason })
    }
  }

  const actionBusy = action.isPending || bulk.isPending

  return (
    <div className="space-y-4">
      <PageHeader
        title="Review tags"
        description="Publish what belongs on the map, mark wrong tags, or hold anything that still needs a look. Waiting tags open first."
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
        {contributorId ? (
          <p className="text-xs text-sw-muted mt-2">
            Showing tags from this person.{' '}
            <button type="button" className="font-bold text-sw-primary-dark" onClick={() => setContributorId('')}>
              Clear
            </button>
          </p>
        ) : (
          <p className="text-xs text-sw-muted mt-2">
            Example: type “IT Park” or “lahug” to only see tags from that area.
          </p>
        )}
      </Card>

      {selected.length > 0 ? (
        <div className="flex gap-2 flex-wrap items-center">
          <Button
            onClick={() => requestAction('approve', selected)}
            disabled={!canBulkPublish}
            title={canBulkPublish ? undefined : 'Bulk publish is only for areas where people already agree'}
          >
            Publish selected ({selected.length})
          </Button>
          <Button variant="warning" onClick={() => requestAction('flag', selected)}>
            Hold selected
          </Button>
          <Button variant="danger" onClick={() => requestAction('reject', selected)}>
            Mark wrong
          </Button>
          <button type="button" className="text-sm font-bold text-sw-muted" onClick={() => setSelected([])}>
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
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Who</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Agreement</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Status</th>
                  <th className="p-3 font-bold text-sw-muted text-[11px] uppercase">Actions</th>
                </tr>
              </thead>
              <tbody>
                {isError ? (
                  <tr>
                    <td colSpan={8} className="p-6">
                      <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-red-800">
                        <div className="font-bold">Could not load this list</div>
                        <p className="text-sm mt-1">{error instanceof Error ? error.message : 'Unknown error'}</p>
                        <button
                          type="button"
                          className="mt-3 text-sm font-bold text-sw-primary-dark"
                          onClick={() => refetch()}
                        >
                          Try again
                        </button>
                      </div>
                    </td>
                  </tr>
                ) : isLoading ? (
                  <tr><td colSpan={8} className="p-6 text-sw-muted">Loading tags…</td></tr>
                ) : items.length === 0 ? (
                  <tr><td colSpan={8} className="p-6 text-sw-muted">Nothing in this list. Try another filter.</td></tr>
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
                              e.target.checked ? [...prev, r.id] : prev.filter((x) => x !== r.id),
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
                      <td className="p-3 text-sw-muted">{r.contributor_label || 'Traveler'}</td>
                      <td className="p-3">{Math.round(r.confidence_score)}%</td>
                      <td className="p-3">
                        <Badge variant="status" value={r.visibility_status} label={statusLabel(r.visibility_status)} />
                      </td>
                      <td className="p-3 space-x-1" onClick={(e) => e.stopPropagation()}>
                        <button type="button" className="text-sw-primary-dark font-bold text-xs" onClick={() => requestAction('approve', [r.id])}>Publish</button>
                        <button type="button" className="text-amber-700 font-bold text-xs" onClick={() => requestAction('flag', [r.id])}>Hold</button>
                        <button type="button" className="text-sw-alert font-bold text-xs" onClick={() => requestAction('reject', [r.id])}>Wrong</button>
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
          {detailError ? (
            <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
              <div className="font-bold">Could not load this tag</div>
              <p className="mt-1">{detailErr instanceof Error ? detailErr.message : 'Unknown error'}</p>
              <button
                type="button"
                className="mt-3 text-sm font-bold text-sw-primary-dark"
                onClick={() => refetchDetail()}
              >
                Try again
              </button>
            </div>
          ) : !focusedId || !detail ? (
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
                  ? 'Enough people already agree, so publishing it will show it on the traveler map.'
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
                <div className="text-[11px] font-bold uppercase text-sw-muted">Sent by</div>
                <div className="font-semibold mt-1">{detail.contributor_label || 'Traveler'}</div>
                {detail.contributor_id ? (
                  <button
                    type="button"
                    className="text-xs font-bold text-sw-primary-dark mt-1"
                    onClick={() => {
                      setContributorId(detail.contributor_id!)
                      setQueue('all')
                    }}
                  >
                    Other tags from this person
                  </button>
                ) : null}
              </div>
              <div
                className="rounded-xl p-3 text-xs font-semibold"
                style={{
                  backgroundColor: detail.cell_context.threshold_met ? '#DDF5E8' : '#FFF4CC',
                  color: detail.cell_context.threshold_met ? colors.primaryDark : '#A16207',
                }}
              >
                {detail.cell_context.threshold_met
                  ? 'Ready for the map — publish if this looks right.'
                  : 'Not enough matching tags yet. Publish only if you personally know this place.'}
              </div>
              <div className="flex gap-2 pt-2 flex-wrap">
                <Button className="flex-1 min-w-[6rem]" onClick={() => requestAction('approve', [detail.id])}>Publish</Button>
                <Button variant="warning" onClick={() => requestAction('flag', [detail.id])}>Hold</Button>
                <Button variant="danger" onClick={() => requestAction('reject', [detail.id])}>Wrong</Button>
              </div>
              <p className="text-[11px] text-sw-muted">
                Hold and Wrong ask why on the next step. That reason is stored in Activity.
              </p>
            </div>
          )}
        </Card>
      </div>

      {pendingAction ? (
        <ReasonDialog
          kind={pendingAction.kind}
          count={pendingAction.ids.length}
          reason={reason}
          busy={actionBusy}
          onReasonChange={setReason}
          onConfirm={confirmReasonedAction}
          onCancel={() => {
            setPendingAction(null)
            setActionError('')
          }}
        />
      ) : null}
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

function ReasonDialog({
  kind,
  count,
  reason,
  busy,
  onReasonChange,
  onConfirm,
  onCancel,
}: {
  kind: ActionKind
  count: number
  reason: (typeof MODERATION_REASONS)[number] | ''
  busy: boolean
  onReasonChange: (value: (typeof MODERATION_REASONS)[number]) => void
  onConfirm: () => void
  onCancel: () => void
}) {
  const isReject = kind === 'reject'
  const title = isReject ? 'Why is this tag wrong?' : 'Why put this on hold?'
  const confirmLabel = isReject
    ? count > 1
      ? `Mark ${count} wrong`
      : 'Mark wrong'
    : count > 1
      ? `Hold ${count}`
      : 'Hold'
  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="moderation-reason-title"
    >
      <button
        type="button"
        className="absolute inset-0 bg-black/40"
        aria-label="Cancel"
        onClick={onCancel}
      />
      <div className="relative w-full max-w-md rounded-2xl bg-white shadow-xl p-5 space-y-4">
        <div>
          <h2 id="moderation-reason-title" className="font-black text-sw-ink text-lg">
            {title}
          </h2>
          <p className="text-sm text-sw-muted mt-1">
            Pick one reason, then confirm. This is saved in Activity so the decision is not a silent delete.
          </p>
        </div>
        <fieldset className="space-y-2">
          <legend className="sr-only">Reason</legend>
          {MODERATION_REASONS.map((code) => (
            <label
              key={code}
              className={`flex gap-3 items-start rounded-xl border px-3 py-2.5 cursor-pointer ${
                reason === code
                  ? 'border-sw-primary bg-sw-primary/5'
                  : 'border-sw-border bg-sw-bg hover:border-sw-primary/40'
              }`}
            >
              <input
                type="radio"
                name="moderation-reason"
                className="mt-1"
                checked={reason === code}
                onChange={() => onReasonChange(code)}
              />
              <span>
                <span className="block font-semibold text-sm text-sw-ink">
                  {moderationReasonLabel(code)}
                </span>
                <span className="block text-xs text-sw-muted">{MODERATION_REASON_HINTS[code]}</span>
              </span>
            </label>
          ))}
        </fieldset>
        <div className="flex gap-2 pt-1">
          <Button
            variant={isReject ? 'danger' : 'warning'}
            className="flex-1"
            disabled={!reason || busy}
            onClick={onConfirm}
          >
            {confirmLabel}
          </Button>
          <Button variant="ghost" disabled={busy} onClick={onCancel}>
            Cancel
          </Button>
        </div>
      </div>
    </div>
  )
}

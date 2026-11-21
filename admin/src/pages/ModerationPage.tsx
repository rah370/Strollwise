/**
 * Review queue for pending/flagged tags.
 *
 * Approve publishes the cell (same rebuild path as auto-threshold).
 * Reject/remove keeps it off the traveler map. Reasons are audited.
 */
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import type { AdminReport, AdminReportDetail, AdminReportList } from '../api/types'
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
  compactStatusLabel,
  moderationReasonLabel,
} from '../lib/copy'
import {
  agreementBadgeClass,
  duplicateGroupKey,
  morePeopleNeededLabel,
  parseSmartSearch,
  personTaggedLabel,
  splitModerationTags,
} from '../lib/moderationUi'

const PAGE_SIZE = 20
const VISIBLE_TAG_LIMIT = 2

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

type DisplayRow = {
  key: string
  ids: string[]
  report: AdminReport
  contributors: string[]
}

export function ModerationPage() {
  const qc = useQueryClient()
  const [params] = useSearchParams()
  const [queue, setQueue] = useState<QueueId>('pending')
  const [selected, setSelected] = useState<string[]>([])
  const [focusedId, setFocusedId] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [category, setCategory] = useState('')
  const [contributorId, setContributorId] = useState('')
  const [groupDuplicates, setGroupDuplicates] = useState(true)
  const [page, setPage] = useState(1)
  const [actionError, setActionError] = useState('')
  const [pendingAction, setPendingAction] = useState<{ kind: ActionKind; ids: string[] } | null>(null)
  const [reason, setReason] = useState<(typeof MODERATION_REASONS)[number] | ''>('')

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  const parsedSearch = useMemo(() => parseSmartSearch(debounced), [debounced])

  useEffect(() => {
    setPage(1)
    setSelected([])
  }, [queue, debounced, category, contributorId])

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
  if (parsedSearch.search) query.set('search', parsedSearch.search)
  if (category) query.set('category', category)
  if (parsedSearch.tag) query.set('tag', parsedSearch.tag)
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
  const rows = useMemo(() => buildDisplayRows(items, groupDuplicates), [items, groupDuplicates])
  const visibleIds = useMemo(() => rows.flatMap((row) => row.ids), [rows])
  const allSelected = visibleIds.length > 0 && visibleIds.every((id) => selected.includes(id))
  const selectedRows = items.filter((r) => selected.includes(r.id))
  const canBulkPublish =
    selectedRows.length > 0 && selectedRows.every((r) => r.confidence_score >= 60)

  const tagHints = useMemo(() => uniqueSorted(items.flatMap((r) => splitModerationTags(r.tags).visible)), [items])
  const areaHints = useMemo(
    () => uniqueSorted(items.map((r) => r.area_name).filter((name): name is string => Boolean(name))),
    [items],
  )

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
    mutationFn: ({ kind, reasonCode, ids }: { kind: ActionKind; reasonCode?: string; ids: string[] }) =>
      api('/admin/moderation/reports/bulk', {
        method: 'POST',
        body: JSON.stringify({
          report_ids: ids,
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

  function toggleIds(ids: string[], checked: boolean) {
    setSelected((prev) => {
      if (checked) return [...new Set([...prev, ...ids])]
      const drop = new Set(ids)
      return prev.filter((id) => !drop.has(id))
    })
  }

  function requestAction(kind: ActionKind, ids: string[]) {
    if (ids.length === 0) return
    setActionError('')
    if (kind === 'approve') {
      if (ids.length === 1) action.mutate({ id: ids[0], kind })
      else bulk.mutate({ kind, ids })
      return
    }
    setFocusedId(ids[0])
    setReason('')
    setPendingAction({ kind, ids })
  }

  function confirmReasonedAction() {
    if (!pendingAction || !reason) return
    if (pendingAction.ids.length === 1) {
      action.mutate({ id: pendingAction.ids[0], kind: pendingAction.kind, reasonCode: reason })
    } else {
      bulk.mutate({ kind: pendingAction.kind, reasonCode: reason, ids: pendingAction.ids })
    }
  }

  const actionBusy = action.isPending || bulk.isPending
  const focusedIds = rows.find((row) => row.ids.includes(focusedId ?? ''))?.ids ?? (focusedId ? [focusedId] : [])

  const rowsRef = useRef(rows)
  rowsRef.current = rows
  const focusedRef = useRef(focusedId)
  focusedRef.current = focusedId
  const pendingRef = useRef(pendingAction)
  pendingRef.current = pendingAction
  const requestActionRef = useRef(requestAction)
  requestActionRef.current = requestAction

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      const target = event.target as HTMLElement | null
      if (target?.closest('input, textarea, select, [contenteditable="true"]')) return
      if (pendingRef.current) {
        if (event.key === 'Escape') {
          event.preventDefault()
          setPendingAction(null)
        }
        return
      }
      const list = rowsRef.current
      if (event.key === 'Escape') {
        setFocusedId(null)
        return
      }
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault()
        if (list.length === 0) return
        const current = focusedRef.current
        const idx = Math.max(0, list.findIndex((row) => row.ids.includes(current ?? '') || row.report.id === current))
        const nextIdx =
          event.key === 'ArrowDown'
            ? Math.min(idx + (current ? 1 : 0), list.length - 1)
            : Math.max(idx - 1, 0)
        setFocusedId(list[nextIdx].report.id)
        return
      }
      const ids = list.find((row) => row.ids.includes(focusedRef.current ?? ''))?.ids
      if (!ids?.length) return
      if (event.key === 'p' || event.key === 'P') {
        event.preventDefault()
        requestActionRef.current('approve', ids)
      } else if (event.key === 'h' || event.key === 'H') {
        event.preventDefault()
        requestActionRef.current('flag', ids)
      } else if (event.key === 'w' || event.key === 'W') {
        event.preventDefault()
        requestActionRef.current('reject', ids)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <div className={`space-y-4 ${selected.length > 0 ? 'pb-24' : ''}`}>
      <PageHeader
        title="Review tags"
        description="Publish what belongs on the map, mark wrong tags, or hold anything that still needs a look. Waiting tags open first."
        actions={
          <p className="text-[11px] font-semibold text-sw-muted bg-white border border-sw-border rounded-xl px-3 py-2">
            <span className="hidden sm:inline">Shortcuts: </span>
            <kbd className="font-black text-sw-ink">P</kbd> publish ·{' '}
            <kbd className="font-black text-sw-ink">H</kbd> hold ·{' '}
            <kbd className="font-black text-sw-ink">W</kbd> wrong ·{' '}
            <kbd className="font-black text-sw-ink">↑↓</kbd> move
          </p>
        }
      />

      {actionError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {actionError}
        </div>
      ) : null}

      <div className="flex flex-col lg:flex-row gap-2 lg:items-center">
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
        <label className="flex items-center gap-2 text-sm font-semibold text-sw-ink bg-white border border-sw-border rounded-xl px-3 py-2 shrink-0">
          <input
            type="checkbox"
            checked={groupDuplicates}
            onChange={(e) => setGroupDuplicates(e.target.checked)}
          />
          Group identical tags
        </label>
      </div>

      <Card className="p-4">
        <div className="grid grid-cols-1 md:grid-cols-[1fr_14rem] gap-3">
          <input
            placeholder="Search place, tag, or note — try tag:food or area:IT Park"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            list="moderation-search-hints"
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
          <datalist id="moderation-search-hints">
            {tagHints.map((tag) => (
              <option key={`tag-${tag}`} value={`tag:${tag}`} />
            ))}
            {areaHints.map((area) => (
              <option key={`area-${area}`} value={`area:${area}`} />
            ))}
          </datalist>
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
        </div>
        {parsedSearch.tag || parsedSearch.search ? (
          <div className="flex flex-wrap gap-2 mt-2">
            {parsedSearch.tag ? (
              <FilterChip label={`tag:${parsedSearch.tag}`} onClear={() => setSearch(stripToken(search, 'tag'))} />
            ) : null}
            {parsedSearch.search ? (
              <FilterChip
                label={parsedSearch.search}
                onClear={() => setSearch(parsedSearch.tag ? `tag:${parsedSearch.tag}` : '')}
              />
            ) : null}
          </div>
        ) : null}
        {contributorId ? (
          <p className="text-xs text-sw-muted mt-2">
            Showing tags from this person.{' '}
            <button type="button" className="font-bold text-sw-primary-dark" onClick={() => setContributorId('')}>
              Clear
            </button>
          </p>
        ) : (
          <p className="text-xs text-sw-muted mt-2">
            One search box. Prefixes become chips: <code className="text-[11px]">tag:food</code> or{' '}
            <code className="text-[11px]">area:IT Park</code>.
          </p>
        )}
      </Card>

      <Card className="p-0 overflow-hidden">
        <div className="overflow-auto max-h-[70vh]">
          <table className="w-full text-sm border-separate border-spacing-0">
            <thead className="bg-sw-bg-alt text-left">
              <tr>
                <th className="p-3 w-10 sticky left-0 top-0 z-20 bg-sw-bg-alt">
                  <input
                    type="checkbox"
                    aria-label="Select all on this page"
                    checked={allSelected}
                    onChange={(e) => toggleAll(e.target.checked)}
                  />
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt">
                  Place or area
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt hidden xl:table-cell">
                  Kind
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt">Tags</th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt hidden xl:table-cell">
                  Who
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt">
                  Agreement
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky top-0 bg-sw-bg-alt hidden md:table-cell">
                  Status
                </th>
                <th className="p-3 font-bold text-sw-muted text-[11px] uppercase sticky right-0 top-0 z-30 bg-sw-bg-alt shadow-[-8px_0_8px_-8px_rgba(15,23,42,0.18)]">
                  Actions
                </th>
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
              ) : rows.length === 0 ? (
                <tr><td colSpan={8} className="p-6 text-sw-muted">Nothing in this list. Try another filter.</td></tr>
              ) : (
                rows.map((row) => {
                  const r = row.report
                  const focused = focusedId !== null && row.ids.includes(focusedId)
                  const groupSelected = row.ids.every((id) => selected.includes(id))
                  const groupPartial = !groupSelected && row.ids.some((id) => selected.includes(id))
                  const stickyBg = focused ? 'bg-sw-primary/5' : 'bg-white group-hover:bg-sw-bg-alt/80'
                  return (
                    <tr
                      key={row.key}
                      className={`group border-t border-sw-border cursor-pointer hover:bg-sw-bg-alt/60 ${
                        focused ? 'bg-sw-primary/5' : ''
                      }`}
                      onClick={() => setFocusedId(focused ? null : r.id)}
                    >
                      <td className={`p-3 sticky left-0 z-10 ${stickyBg}`} onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={groupSelected}
                          ref={(el) => {
                            if (el) el.indeterminate = groupPartial
                          }}
                          onChange={(e) => toggleIds(row.ids, e.target.checked)}
                          aria-label={`Select ${r.area_name || 'unnamed area'}`}
                        />
                      </td>
                      <td className="p-3 min-w-[10rem]">
                        <div className="font-semibold">{r.area_name || 'Unnamed area'}</div>
                        <div className="text-[11px] text-sw-muted">
                          {personTaggedLabel(r.contributor_count)}
                          {row.ids.length > 1 ? ` · ${row.ids.length} matching submissions` : ''}
                        </div>
                      </td>
                      <td className="p-3 font-semibold hidden xl:table-cell">{categoryLabel(r.category)}</td>
                      <td className="p-3">
                        <TagPills tags={r.tags} />
                      </td>
                      <td className="p-3 text-sw-muted hidden xl:table-cell">
                        {whoLabel(row.contributors)}
                      </td>
                      <td className="p-3">
                        <span
                          className={`inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-black whitespace-nowrap ${agreementBadgeClass(r.confidence_score)}`}
                        >
                          {Math.round(r.confidence_score)}%
                        </span>
                      </td>
                      <td className="p-3 hidden md:table-cell">
                        <Badge
                          variant="status"
                          value={r.visibility_status}
                          label={compactStatusLabel(r.visibility_status)}
                        />
                      </td>
                      <td
                        className={`p-3 sticky right-0 z-10 whitespace-nowrap shadow-[-8px_0_8px_-8px_rgba(15,23,42,0.18)] ${stickyBg}`}
                        onClick={(e) => e.stopPropagation()}
                      >
                        <button type="button" className="text-sw-primary-dark font-bold text-xs" onClick={() => requestAction('approve', row.ids)}>Publish</button>
                        <button type="button" className="text-amber-700 font-bold text-xs ml-2" onClick={() => requestAction('flag', row.ids)}>Hold</button>
                        <button type="button" className="text-sw-alert font-bold text-xs ml-2" onClick={() => requestAction('reject', row.ids)}>Wrong</button>
                      </td>
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
          total={data?.total ?? 0}
          onPageChange={setPage}
          noun="tags"
        />
      </Card>

      {focusedId ? (
        <DetailDrawer
          detail={detail}
          detailError={detailError}
          detailErr={detailErr}
          onRetry={() => refetchDetail()}
          onClose={() => setFocusedId(null)}
          onFilterPerson={(id) => {
            setContributorId(id)
            setQueue('all')
          }}
          onAction={(kind) => requestAction(kind, focusedIds)}
        />
      ) : null}

      {selected.length > 0 ? (
        <div className="fixed bottom-4 left-4 right-4 md:left-60 md:right-8 z-30 flex flex-wrap items-center gap-2 rounded-2xl bg-sw-map-ink text-white px-4 py-3 shadow-2xl">
          <span className="text-sm font-bold">{selected.length} selected</span>
          <Button
            onClick={() => requestAction('approve', selected)}
            disabled={!canBulkPublish || actionBusy}
            title={canBulkPublish ? undefined : 'Bulk publish is only for areas where people already agree'}
          >
            Publish selected
          </Button>
          <Button variant="warning" disabled={actionBusy} onClick={() => requestAction('flag', selected)}>
            Hold selected
          </Button>
          <Button variant="danger" disabled={actionBusy} onClick={() => requestAction('reject', selected)}>
            Mark wrong
          </Button>
          <button type="button" className="text-sm font-bold text-white/70 ml-auto" onClick={() => setSelected([])}>
            Clear
          </button>
        </div>
      ) : null}

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

function buildDisplayRows(items: AdminReport[], grouped: boolean): DisplayRow[] {
  if (!grouped) {
    return items.map((report) => ({
      key: report.id,
      ids: [report.id],
      report,
      contributors: [report.contributor_label || 'Traveler'],
    }))
  }
  const map = new Map<string, DisplayRow>()
  for (const report of items) {
    const key = duplicateGroupKey(report)
    const existing = map.get(key)
    const who = report.contributor_label || 'Traveler'
    if (!existing) {
      map.set(key, { key, ids: [report.id], report, contributors: [who] })
      continue
    }
    existing.ids.push(report.id)
    existing.contributors.push(who)
  }
  return [...map.values()]
}

function uniqueSorted(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b))
}

function uniquePreserve(values: string[]): string[] {
  const seen = new Set<string>()
  const out: string[] = []
  for (const value of values) {
    const trimmed = value.trim()
    if (!trimmed || seen.has(trimmed)) continue
    seen.add(trimmed)
    out.push(trimmed)
  }
  return out
}

function whoLabel(contributors: string[]): string {
  const unique = uniquePreserve(contributors)
  if (unique.length === 0) return 'Traveler'
  if (unique.length === 1) return unique[0]
  return `${unique[0]} +${unique.length - 1}`
}

function stripToken(raw: string, kind: 'tag' | 'area'): string {
  return raw.replace(new RegExp(`(?:^|\\s)${kind}:(?:"[^"]+"|\\S+)`, 'gi'), ' ').replace(/\s+/g, ' ').trim()
}

function FilterChip({ label, onClear }: { label: string; onClear: () => void }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-sw-bg-alt border border-sw-border px-2.5 py-1 text-[11px] font-bold text-sw-ink">
      {label}
      <button type="button" className="text-sw-muted hover:text-sw-ink" onClick={onClear} aria-label={`Clear ${label}`}>
        ×
      </button>
    </span>
  )
}

function TagPills({ tags }: { tags: string[] }) {
  const { visible, metadata } = splitModerationTags(tags)
  const shown = visible.slice(0, VISIBLE_TAG_LIMIT)
  const extra = visible.length - shown.length
  return (
    <div className="flex flex-wrap items-center gap-1 max-w-[16rem]">
      {shown.map((tag) => (
        <span
          key={tag}
          className="inline-flex items-center rounded-full bg-sw-bg-alt px-2 py-0.5 text-[11px] font-semibold text-sw-ink whitespace-nowrap"
        >
          {tag}
        </span>
      ))}
      {extra > 0 ? (
        <span className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-[11px] font-bold text-slate-600">
          +{extra}
        </span>
      ) : null}
      {metadata.includes('anonymous') ? (
        <span title="Anonymous traveler" className="text-sw-muted" aria-label="Anonymous">
          <AnonIcon />
        </span>
      ) : null}
      {metadata.includes('exact_road_spot') ? (
        <span title="Exact road spot" className="text-sw-muted" aria-label="Exact road spot">
          <PinIcon />
        </span>
      ) : null}
      {shown.length === 0 && extra <= 0 && metadata.length === 0 ? (
        <span className="text-sw-muted">—</span>
      ) : null}
    </div>
  )
}

function AnonIcon() {
  return (
    <svg viewBox="0 0 16 16" className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden>
      <path d="M2 8s2.2-4 6-4 6 4 6 4-2.2 4-6 4-6-4-6-4Z" />
      <circle cx="8" cy="8" r="1.4" />
      <path d="M3 13 13 3" />
    </svg>
  )
}

function PinIcon() {
  return (
    <svg viewBox="0 0 16 16" className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden>
      <path d="M8 14s4.5-4.1 4.5-7.2A4.5 4.5 0 0 0 8 2.3a4.5 4.5 0 0 0-4.5 4.5C3.5 9.9 8 14 8 14Z" />
      <circle cx="8" cy="6.8" r="1.3" />
    </svg>
  )
}

function DetailDrawer({
  detail,
  detailError,
  detailErr,
  onRetry,
  onClose,
  onFilterPerson,
  onAction,
}: {
  detail?: AdminReportDetail
  detailError: boolean
  detailErr: unknown
  onRetry: () => void
  onClose: () => void
  onFilterPerson: (id: string) => void
  onAction: (kind: ActionKind) => void
}) {
  const { visible, metadata } = splitModerationTags(detail?.tags ?? [])
  const needed = detail
    ? Math.max(detail.cell_context.threshold - detail.cell_context.distinct_contributors, 0)
    : 0
  const lat = detail?.lat
  const lng = detail?.lng
  const hasPin = typeof lat === 'number' && typeof lng === 'number'
  const pad = 0.004
  const mapSrc = hasPin
    ? `https://www.openstreetmap.org/export/embed.html?bbox=${lng - pad}%2C${lat - pad}%2C${lng + pad}%2C${lat + pad}&layer=mapnik&marker=${lat}%2C${lng}`
    : null

  return (
    <div className="fixed inset-0 z-40">
      <button type="button" className="absolute inset-0 bg-black/35" aria-label="Close details" onClick={onClose} />
      <aside className="absolute right-0 top-0 h-full w-full max-w-md bg-white shadow-2xl overflow-y-auto">
        <div className="sticky top-0 bg-white/95 backdrop-blur border-b border-sw-border px-5 py-4 flex items-start justify-between gap-3 z-10">
          <div>
            <h2 className="font-black text-sw-ink">Should this go on the map?</h2>
            <p className="text-xs text-sw-muted mt-1">How many other people described this area the same way.</p>
          </div>
          <button type="button" className="text-sm font-bold text-sw-muted hover:text-sw-ink" onClick={onClose}>
            Close
          </button>
        </div>
        <div className="p-5 space-y-4 text-sm">
          {detailError ? (
            <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
              <div className="font-bold">Could not load this tag</div>
              <p className="mt-1">{detailErr instanceof Error ? detailErr.message : 'Unknown error'}</p>
              <button type="button" className="mt-3 text-sm font-bold text-sw-primary-dark" onClick={onRetry}>
                Try again
              </button>
            </div>
          ) : !detail ? (
            <p className="text-sw-muted">Loading this tag…</p>
          ) : (
            <>
              {hasPin ? (
                <div className="overflow-hidden rounded-xl border border-sw-border">
                  <div className="relative h-44 bg-[linear-gradient(180deg,#d7e7d2_0%,#c5d6c8_55%,#e7efe4_100%)]">
                    {mapSrc ? (
                      <iframe title="Exact road spot" src={mapSrc} className="absolute inset-0 w-full h-full border-0" />
                    ) : null}
                    <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                      <span className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-white shadow-md text-sw-alert">
                        <PinIcon />
                      </span>
                      <span className="mt-2 rounded-full bg-white/90 px-2 py-0.5 text-[11px] font-bold text-sw-ink">
                        {lat.toFixed(5)}, {lng.toFixed(5)}
                      </span>
                    </div>
                  </div>
                  <a
                    className="block px-3 py-2 text-[11px] font-bold text-sw-primary-dark bg-white"
                    href={`https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=17/${lat}/${lng}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    Open map
                  </a>
                </div>
              ) : null}
              <p className="text-sw-secondary leading-relaxed">
                {detail.area_name || 'This area'} was tagged as{' '}
                <strong>{categoryLabel(detail.category)}</strong>
                {visible.length ? ` (${visible.join(', ')})` : ''}.{' '}
                {detail.cell_context.threshold_met
                  ? 'Enough people already agree, so publishing it will show it on the traveler map.'
                  : morePeopleNeededLabel(needed)}
              </p>
              {metadata.length ? (
                <div className="flex flex-wrap gap-2">
                  {metadata.includes('anonymous') ? (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-sw-muted bg-sw-bg rounded-full px-2 py-1">
                      <AnonIcon /> Anonymous
                    </span>
                  ) : null}
                  {metadata.includes('exact_road_spot') ? (
                    <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-sw-muted bg-sw-bg rounded-full px-2 py-1">
                      <PinIcon /> Exact road spot
                    </span>
                  ) : null}
                </div>
              ) : null}
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
                <Metric
                  label="How much they agree"
                  value={`${Math.round(detail.cell_context.category_agreement * 100)}%`}
                />
              </div>
              <div>
                <div className="text-[11px] font-bold uppercase text-sw-muted">Sent by</div>
                <div className="font-semibold mt-1">{detail.contributor_label || 'Traveler'}</div>
                {detail.contributor_id ? (
                  <button
                    type="button"
                    className="text-xs font-bold text-sw-primary-dark mt-1"
                    onClick={() => onFilterPerson(detail.contributor_id!)}
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
                <Button className="flex-1 min-w-[6rem]" onClick={() => onAction('approve')}>Publish</Button>
                <Button variant="warning" onClick={() => onAction('flag')}>Hold</Button>
                <Button variant="danger" onClick={() => onAction('reject')}>Wrong</Button>
              </div>
              <p className="text-[11px] text-sw-muted">
                Hold and Wrong ask why on the next step. That reason is stored in Activity.
              </p>
            </>
          )}
        </div>
      </aside>
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

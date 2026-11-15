/**
 * Runtime validation knobs + map rebuild.
 *
 * `pending_min_reports_per_cell` counts distinct people, not rows.
 * Map tab rebuilds aggregates/places/zones without a deploy.
 */
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api/client'
import type { AdminPipelineResult, AdminSystemConfig } from '../api/types'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'

const fields = [
  [
    'pending_min_reports_per_cell',
    'How many different people must tag the same area',
    'Before a place can appear on the map by itself, this many people need to send a tag there.',
    1,
  ],
  [
    'pending_agreement_ratio',
    'How much those tags must agree (0–1)',
    '0.6 means 60% of tags in that area should describe the same kind of place.',
    0.05,
  ],
  [
    'report_cooldown_hours_per_cell',
    'Hours before the same person can tag the same area again',
    'Stops one person from flooding a place with tags.',
    1,
  ],
  [
    'report_max_per_user_per_hour',
    'Max tags one person can send per hour',
    'A simple spam limit for the traveler app.',
    1,
  ],
  [
    'h3_resolution',
    'Map cell size (advanced)',
    'Leave this unless a researcher asks you to change how large each map cell is.',
    1,
  ],
] as const

const jobs = [
  {
    id: 'rebuild-cells',
    label: 'Refresh map cells',
    desc: 'Recount tags in each small map area. Use after a large review session.',
  },
  {
    id: 'rebuild-places',
    label: 'Refresh places',
    desc: 'Rebuild named places from those map cells.',
  },
  {
    id: 'rebuild-zones',
    label: 'Refresh the public map',
    desc: 'Update what travelers see on Explore.',
  },
  {
    id: 'rebuild-all',
    label: 'Refresh everything',
    desc: 'Cells, then places, then the public map. Takes longer.',
  },
  {
    id: 'invalidate-cache',
    label: 'Clear saved map copies',
    desc: 'Force the app to load fresh numbers. Safe and fast.',
  },
] as const

const tabs = [
  { id: 'reports', label: 'Tag rules' },
  { id: 'map', label: 'Map refresh' },
] as const

export function SettingsPage() {
  const [params, setParams] = useSearchParams()
  const tab = tabs.some((t) => t.id === params.get('tab')) ? params.get('tab')! : 'reports'

  return (
    <div className="space-y-4 max-w-3xl">
      <PageHeader
        title="Settings"
        description="Split into short tabs so you only see the controls you need. Tag rules affect review. Map refresh is for occasional maintenance."
      />
      <div className="flex gap-2 flex-wrap">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setParams({ tab: t.id })}
            className={`px-4 py-2 rounded-xl text-sm font-bold border ${
              tab === t.id
                ? 'bg-sw-map-ink text-white border-sw-map-ink'
                : 'bg-white border-sw-border text-sw-muted'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>
      {tab === 'map' ? <MapRefreshTab /> : <ReportRulesTab />}
    </div>
  )
}

function ReportRulesTab() {
  const qc = useQueryClient()
  const { data } = useQuery({
    queryKey: ['config'],
    queryFn: () => api<AdminSystemConfig>('/admin/config'),
  })
  const [form, setForm] = useState<Partial<AdminSystemConfig>>({})
  const [saved, setSaved] = useState(false)
  const [saveError, setSaveError] = useState('')

  const save = useMutation({
    mutationFn: () =>
      api<AdminSystemConfig>('/admin/config', {
        method: 'PATCH',
        body: JSON.stringify(form),
      }),
    onSuccess: () => {
      setSaveError('')
      qc.invalidateQueries({ queryKey: ['config'] })
      setForm({})
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    },
    onError: (err: Error) => setSaveError(err.message),
  })

  if (!data) return <div className="text-sw-muted">Loading tag rules…</div>
  const values = { ...data, ...form }

  return (
    <>
      {saveError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {saveError}
        </div>
      ) : null}

      <Card className="space-y-5">
        <p className="text-sm text-sw-secondary">
          These numbers decide when a place can appear on the traveler map without an admin clicking
          Approve. Change them carefully — they apply to everyone.
        </p>
        {fields.map(([key, label, hint, step]) => (
          <label key={key} className="block">
            <span className="text-sm font-bold text-sw-ink">{label}</span>
            <p className="text-xs text-sw-muted mt-0.5 mb-1.5">{hint}</p>
            <input
              type="number"
              step={step}
              className="w-full border border-sw-border rounded-xl px-3 py-2.5 bg-sw-bg focus:outline-none focus:ring-2 focus:ring-sw-primary/30"
              value={values[key]}
              onChange={(e) =>
                setForm((f) => ({
                  ...f,
                  [key]:
                    key === 'pending_agreement_ratio'
                      ? parseFloat(e.target.value)
                      : parseInt(e.target.value, 10),
                }))
              }
            />
          </label>
        ))}

        <div className="flex items-center gap-3 pt-2">
          <Button
            disabled={save.isPending || Object.keys(form).length === 0}
            onClick={() => {
              if (
                !window.confirm(
                  'Save these tag rules for every traveler? Waiting times and auto-publish thresholds will change immediately.',
                )
              ) {
                return
              }
              save.mutate()
            }}
          >
            Save tag rules
          </Button>
          {saved ? <span className="text-sm font-bold text-sw-primary-dark">Saved</span> : null}
        </div>
      </Card>

      <Card className="bg-sw-bg-alt border-sw-secondary/30">
        <p className="text-sm text-sw-muted">
          Right now a place auto-publishes when <strong>{values.pending_min_reports_per_cell}</strong>{' '}
          different people tag it and at least{' '}
          <strong>{Math.round(values.pending_agreement_ratio * 100)}%</strong> of those tags agree.
        </p>
      </Card>
    </>
  )
}

function MapRefreshTab() {
  const qc = useQueryClient()
  const [lastResult, setLastResult] = useState<AdminPipelineResult | null>(null)
  const [runError, setRunError] = useState('')

  const run = useMutation({
    mutationFn: (job: (typeof jobs)[number]['id']) =>
      api<AdminPipelineResult>(`/admin/pipeline/${job}`, { method: 'POST' }),
    onSuccess: (data) => {
      setRunError('')
      setLastResult(data)
      qc.invalidateQueries({ queryKey: ['zones'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['analytics'] })
    },
    onError: (err: Error) => {
      setLastResult(null)
      setRunError(err.message)
    },
  })

  const resultLines = useMemo(() => {
    if (!lastResult) return []
    return Object.entries(lastResult.affected_counts).map(([key, value]) => {
      const labels: Record<string, string> = {
        h3_cells: 'Map cells updated',
        places: 'Places updated',
        zones: 'Public map places updated',
      }
      return `${labels[key] ?? key}: ${value}`
    })
  }, [lastResult])

  return (
    <>
      <Card>
        <p className="text-sm text-sw-secondary">
          Use this tab only when the map looks stale after a big review. You do not need it for
          day-to-day tag approval.
        </p>
      </Card>

      {runError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {runError}
        </div>
      ) : null}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {jobs.map((job) => (
          <Card key={job.id} padding="p-5">
            <h3 className="font-black text-sw-ink">{job.label}</h3>
            <p className="text-sm text-sw-muted mt-1 mb-4">{job.desc}</p>
            <Button
              variant="secondary"
              disabled={run.isPending}
              onClick={() => {
                const needsConfirm = job.id !== 'invalidate-cache'
                if (
                  needsConfirm &&
                  !window.confirm(
                    `Run “${job.label}”? This can change what travelers see on the map.`,
                  )
                ) {
                  return
                }
                run.mutate(job.id)
              }}
            >
              {run.isPending ? 'Working…' : 'Run'}
            </Button>
          </Card>
        ))}
      </div>

      {lastResult ? (
        <Card className="border-sw-primary/30 bg-sw-primary/5">
          <div className="font-bold text-sw-primary-dark">{lastResult.message}</div>
          {resultLines.length ? (
            <ul className="mt-2 text-sm text-sw-secondary list-disc pl-5">
              {resultLines.map((line) => (
                <li key={line}>{line}</li>
              ))}
            </ul>
          ) : null}
        </Card>
      ) : null}
    </>
  )
}

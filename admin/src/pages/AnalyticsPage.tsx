import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Bar, BarChart, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { api, downloadExport } from '../api/client'
import type { AdminAnalyticsOverview } from '../api/types'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { QueryState } from '../components/QueryState'
import { StatCard } from '../components/StatCard'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { colors } from '../theme/colors'

const barColors = [colors.travelerLocal, colors.travelerInternational, colors.secondary]

const exports = [
  {
    path: 'reports',
    fmt: 'csv' as const,
    file: 'strollwise-tags-by-place.csv',
    title: 'Tags by place',
    blurb:
      'A spreadsheet of each place, how many tags it received, the most common kind of tag, and the words people used. Safe to open in Excel or Google Sheets.',
  },
  {
    path: 'zones',
    fmt: 'csv' as const,
    file: 'strollwise-places.csv',
    title: 'Places on the map',
    blurb:
      'One row per place: its name, who visits, how sure we are, how many tags it has, and whether it is just starting, growing, or established.',
  },
  {
    path: 'audit',
    fmt: 'csv' as const,
    file: 'strollwise-activity.csv',
    title: 'What admins did',
    blurb:
      'A dated list of approvals, flags, and rejections. Useful for a thesis methods section. No traveler emails.',
  },
]

/** Aggregate charts + CSV/JSON export. No individual tag rows. */
export function AnalyticsPage() {
  const [exportError, setExportError] = useState('')

  const poll = useAdminPollInterval(LIVE_POLL_MS.analytics)
  const { data, isPending, isError, error } = useQuery({
    queryKey: ['analytics'],
    queryFn: () => api<AdminAnalyticsOverview>('/admin/analytics/overview'),
    refetchInterval: poll,
  })

  async function download(path: string, fmt: 'json' | 'csv', filename: string) {
    setExportError('')
    try {
      await downloadExport(`/admin/analytics/export/${path}?fmt=${fmt}`, filename)
    } catch (err) {
      setExportError(err instanceof Error ? err.message : 'Export failed')
    }
  }

  if (isPending || isError || !data) {
    return (
      <QueryState isLoading={isPending} isError={isError} error={error} loadingLabel="Loading analytics…">
        {null}
      </QueryState>
    )
  }

  const chartData = [
    { name: 'Live in Cebu', value: data.local_contributors, key: 'local' },
    { name: 'From abroad', value: data.international_contributors, key: 'intl' },
    { name: 'From elsewhere in PH', value: data.domestic_contributors, key: 'domestic' },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Export"
        description="Download spreadsheets with everyday column names. These files are anonymized — they do not include emails or exact GPS."
        actions={
          <Link to="/audit">
            <Button variant="ghost">View activity log</Button>
          </Link>
        }
      />

      {exportError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {exportError}
        </div>
      ) : null}

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard label="Tags on the map" value={data.visible_reports} hint="Already public" accent={colors.primary} />
        <StatCard label="Established places" value={data.zones_defined} hint="Strong agreement" accent={colors.travelerLocal} />
        <StatCard label="Growing places" value={data.zones_emerging} hint="Still collecting tags" accent={colors.accent} />
        <StatCard label="Places shown" value={data.active_zones} hint="On the traveler map" accent={colors.secondary} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {exports.map((item) => (
          <Card key={item.path}>
            <h2 className="font-black text-sw-ink">{item.title}</h2>
            <p className="text-sm text-sw-muted mt-2 mb-4 leading-relaxed">{item.blurb}</p>
            <Button onClick={() => download(item.path, item.fmt, item.file)}>
              Download spreadsheet
            </Button>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card className="h-72">
          <h2 className="font-black text-sw-ink mb-1">Who is tagging</h2>
          <p className="text-xs text-sw-muted mb-3">Counts of people, not tags.</p>
          <ResponsiveContainer width="100%" height="80%">
            <BarChart data={chartData}>
              <XAxis dataKey="name" tick={{ fontSize: 11 }} />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="value" name="People" radius={[8, 8, 0, 0]}>
                {chartData.map((_, i) => (
                  <Cell key={chartData[i].key} fill={barColors[i % barColors.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </Card>

        <Card>
          <h2 className="font-black text-sw-ink mb-4">How to read the files</h2>
          <ul className="space-y-3 text-sm text-sw-secondary">
            <li>
              <strong>Place or area</strong> is the neighborhood or named place, not a GPS point.
            </li>
            <li>
              <strong>How sure we are</strong> is 0–100%. Higher means more people described the place the same way.
            </li>
            <li>
              <strong>Stage</strong> is Just starting, Growing, or Established — the same language as the Places page.
            </li>
            <li>
              JSON downloads still exist for researchers who want the original field names. Ask if you need those.
            </li>
          </ul>
          <div className="mt-4 flex gap-2 flex-wrap">
            <Button variant="ghost" onClick={() => download('zones', 'json', 'strollwise-places.json')}>
              Places JSON
            </Button>
            <Button variant="ghost" onClick={() => download('reports', 'json', 'strollwise-tags.json')}>
              Tags JSON
            </Button>
          </div>
        </Card>
      </div>
    </div>
  )
}

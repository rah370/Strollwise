import { Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { api } from '../api/client'
import type { AdminAnalyticsOverview, AdminDashboardStats } from '../api/types'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { QueryState } from '../components/QueryState'
import { StatCard } from '../components/StatCard'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { colors } from '../theme/colors'

/** Home stats: pending tags, visible map tags, city pulse. Live-updates via SSE. */
export function DashboardPage() {
  const dashboardPoll = useAdminPollInterval(LIVE_POLL_MS.dashboard)
  const { data, isPending, isError, error } = useQuery({
    queryKey: ['dashboard'],
    queryFn: () => api<AdminDashboardStats>('/admin/dashboard/stats'),
    refetchInterval: dashboardPoll,
  })

  const { data: analytics, isError: analyticsError } = useQuery({
    queryKey: ['analytics-overview'],
    queryFn: () => api<AdminAnalyticsOverview>('/admin/analytics/overview'),
    refetchInterval: dashboardPoll,
  })

  const pulse = analytics?.city_pulse as { city_activity?: string; crowd_level_percent?: number } | undefined
  const chartData = data?.reports_last_30_days ?? []

  return (
    <QueryState isLoading={isPending} isError={isError} error={error} loadingLabel="Loading dashboard…">
      {!data ? null : (
    <div className="space-y-6">
      <PageHeader
        title="Validation dashboard"
        description="A plain-language snapshot of what needs your attention, how healthy the map is, and who is contributing."
        actions={
          <>
            <Link to="/moderation">
              <Button>Review waiting tags</Button>
            </Link>
            <Link to="/analytics">
              <Button variant="secondary">Download spreadsheets</Button>
            </Link>
          </>
        }
      />

      <Card className="border-l-4 border-l-sw-primary">
        <h2 className="font-black text-sw-ink">What to do now</h2>
        <p className="text-sm text-sw-secondary mt-2 leading-relaxed">
          {data.plain_summary || 'Nothing is waiting. The public map is up to date.'}
        </p>
      </Card>

      <div>
        <h2 className="font-black text-sw-ink mb-1">Tag review</h2>
        <p className="text-xs text-sw-muted mb-3">
          Tags are traveler reports. They stay off the public map until enough people agree, or an admin approves them.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          <StatCard
            label="Waiting for review"
            value={data.pending_reports}
            hint="Open Review tags to decide"
            accent={colors.accent}
          />
          <StatCard
            label="Needs a closer look"
            value={data.flagged_reports}
            hint="Someone marked these as a problem"
            accent={colors.alert}
          />
          <StatCard
            label="Almost ready"
            value={data.near_threshold_reports ?? 0}
            hint="A few more matching tags would publish these"
            accent={colors.secondary}
          />
          <StatCard
            label="Already on the map"
            value={data.visible_reports ?? analytics?.visible_reports ?? 0}
            hint="Approved and visible to travelers"
            accent={colors.primary}
          />
        </div>
      </div>

      <div>
        <h2 className="font-black text-sw-ink mb-1">Places on the map</h2>
        <p className="text-xs text-sw-muted mb-3">
          Established places have many agreeing tags. Growing places are still collecting evidence.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            label="Places shown"
            value={data.active_zones}
            hint="On the public traveler map"
            accent={colors.secondary}
          />
          <StatCard
            label="Established"
            value={data.defined_zones ?? analytics?.zones_defined ?? 0}
            hint="Strong agreement, safe to trust"
            accent={colors.travelerLocal}
          />
          <StatCard
            label="Still growing"
            value={data.emerging_zones ?? analytics?.zones_emerging ?? 0}
            hint="Need more matching tags"
            accent={colors.accent}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2 h-80 min-w-0 flex flex-col">
          <h2 className="font-black text-sw-ink mb-1 shrink-0">Tags sent in the last 30 days</h2>
          <p className="text-xs text-sw-muted mb-3">Each point is how many traveler tags arrived that day.</p>
          {chartData.length > 0 ? (
            <div className="min-h-0 min-w-0 flex-1">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
                  <XAxis dataKey="date" tick={{ fontSize: 11 }} stroke={colors.mutedText} />
                  <YAxis allowDecimals={false} stroke={colors.mutedText} />
                  <Tooltip />
                  <Line
                    type="monotone"
                    dataKey="count"
                    name="Tags"
                    stroke={colors.primary}
                    strokeWidth={3}
                    dot={{ fill: colors.primary, r: 3 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <p className="flex flex-1 items-center justify-center text-center text-sw-muted text-sm px-4">
              No tags in the last 30 days yet.
            </p>
          )}
        </Card>

        <Card>
          <h2 className="font-black text-sw-ink mb-1">Who is contributing</h2>
          <p className="text-xs text-sw-muted mb-4">
            Locals know daily patterns. Visitors add a traveler’s eye. Both matter for the thesis.
          </p>
          {pulse || data ? (
            <dl className="space-y-4 text-sm">
              <div>
                <dt className="text-sw-muted font-semibold uppercase text-[11px]">People in StrollWise</dt>
                <dd className="text-2xl font-black mt-1">{data.total_users}</dd>
              </div>
              <div>
                <dt className="text-sw-muted font-semibold uppercase text-[11px]">Live in Cebu</dt>
                <dd className="text-xl font-bold mt-1">
                  {Math.round(data.local_contributor_ratio * 100)}%
                  <span className="text-sm font-semibold text-sw-muted ml-2">
                    ({data.local_users ?? 0} people)
                  </span>
                </dd>
              </div>
              <div>
                <dt className="text-sw-muted font-semibold uppercase text-[11px]">City activity</dt>
                <dd className="text-xl font-black capitalize text-sw-primary-dark mt-1">
                  {(pulse?.city_activity ?? 'quiet').replace(/_/g, ' ')}
                </dd>
              </div>
            </dl>
          ) : analyticsError ? (
            <p className="text-sm text-red-700">Could not load city pulse.</p>
          ) : (
            <p className="text-sw-muted text-sm">Loading city pulse…</p>
          )}
        </Card>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="border-l-4 border-l-sw-primary">
          <h3 className="font-bold text-sw-ink">Review tags</h3>
          <p className="text-sm text-sw-muted mt-1 mb-3">
            Approve, flag, or reject waiting tags. Use search so you only look at one place at a time.
          </p>
          <Link to="/moderation" className="text-sm font-bold text-sw-primary-dark">
            Open review queue →
          </Link>
        </Card>
        <Card className="border-l-4 border-l-sw-secondary">
          <h3 className="font-bold text-sw-ink">Check a place</h3>
          <p className="text-sm text-sw-muted mt-1 mb-3">
            See whether a place is just starting, growing, or established, and why.
          </p>
          <Link to="/zones" className="text-sm font-bold text-sw-lagoon">
            Open places →
          </Link>
        </Card>
        <Card className="border-l-4 border-l-sw-accent">
          <h3 className="font-bold text-sw-ink">Download a spreadsheet</h3>
          <p className="text-sm text-sw-muted mt-1 mb-3">
            Human-readable CSV files for thesis tables — no technical map codes required.
          </p>
          <Link to="/analytics" className="text-sm font-bold text-amber-700">
            Export data →
          </Link>
        </Card>
      </div>
    </div>
      )}
    </QueryState>
  )
}

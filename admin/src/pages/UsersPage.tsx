import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { api } from '../api/client'
import type { AdminUser, AdminUserContributions, AdminUserList } from '../api/types'
import { Badge } from '../components/Badge'
import { Button } from '../components/Button'
import { Card } from '../components/Card'
import { PageHeader } from '../components/PageHeader'
import { Pagination } from '../components/Pagination'
import { StatCard } from '../components/StatCard'
import { LIVE_POLL_MS, useAdminPollInterval } from '../hooks/useAdminLiveUpdates'
import { travelerTypeLabel } from '../lib/copy'
import { colors } from '../theme/colors'

const PAGE_SIZE = 20

/** Traveler accounts: type, activity, promote/demote admin. Not a public directory. */
export function UsersPage() {
  const qc = useQueryClient()
  const [search, setSearch] = useState('')
  const [debounced, setDebounced] = useState('')
  const [userType, setUserType] = useState('')
  const [role, setRole] = useState('')
  const [status, setStatus] = useState('')
  const [page, setPage] = useState(1)
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [toggleError, setToggleError] = useState('')

  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(search.trim()), 250)
    return () => window.clearTimeout(t)
  }, [search])

  useEffect(() => {
    setPage(1)
  }, [debounced, userType, role, status])

  const poll = useAdminPollInterval(LIVE_POLL_MS.users)
  const params = new URLSearchParams({
    page: String(page),
    page_size: String(PAGE_SIZE),
  })
  if (debounced) params.set('search', debounced)
  if (userType) params.set('user_type', userType)
  if (role) params.set('role', role)
  if (status) params.set('status', status)

  const { data, isLoading } = useQuery({
    queryKey: ['users', params.toString()],
    queryFn: () => api<AdminUserList>(`/admin/users?${params}`),
    refetchInterval: poll,
  })

  const { data: contributions } = useQuery({
    queryKey: ['user-contributions', selectedId],
    queryFn: () => api<AdminUserContributions>(`/admin/users/${selectedId}/contributions`),
    enabled: Boolean(selectedId),
  })

  const selected = data?.items.find((u) => u.id === selectedId) ?? null
  const snapshot = data?.snapshot

  const toggle = useMutation({
    mutationFn: ({ id, is_admin }: { id: string; is_admin: boolean }) =>
      api(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ is_admin }),
      }),
    onSuccess: () => {
      setToggleError('')
      qc.invalidateQueries({ queryKey: ['users'] })
      qc.invalidateQueries({ queryKey: ['audit'] })
    },
    onError: (err: Error) => setToggleError(err.message),
  })

  const pause = useMutation({
    mutationFn: ({ id, is_active }: { id: string; is_active: boolean }) =>
      api(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ is_active }),
      }),
    onSuccess: () => {
      setToggleError('')
      qc.invalidateQueries({ queryKey: ['users'] })
      qc.invalidateQueries({ queryKey: ['audit'] })
    },
    onError: (err: Error) => setToggleError(err.message),
  })

  return (
    <div className="space-y-4">
      <PageHeader
        title="Users"
        description="People using the StrollWise traveler app. This list is a simple roster — who they are, where they are from, and how many tags they have sent."
      />

      {toggleError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
          {toggleError}
        </div>
      ) : null}

      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4">
        <StatCard
          label="People in StrollWise"
          value={snapshot?.total ?? '—'}
          hint={`${snapshot?.active ?? 0} can currently sign in`}
        />
        <StatCard
          label="Live in Cebu"
          value={snapshot?.local_residents ?? '—'}
          hint="Know the city day to day"
          accent={colors.travelerLocal}
        />
        <StatCard
          label="Visitors"
          value={(snapshot?.international_visitors ?? 0) + (snapshot?.domestic_travelers ?? 0)}
          hint={`${snapshot?.international_visitors ?? 0} from abroad · ${snapshot?.domestic_travelers ?? 0} from elsewhere in PH`}
          accent={colors.travelerInternational}
        />
        <StatCard
          label="Admins"
          value={snapshot?.admins ?? '—'}
          hint={`${snapshot?.contributors ?? 0} regular contributors`}
          accent={colors.accent}
        />
      </div>

      <Card className="p-4">
        <p className="text-sm text-sw-secondary">
          Search by name, email, or hometown, then filter so the table stays short. Click a row to
          read a plain-language summary of that person.
        </p>
        <div className="mt-3 grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, email, or hometown…"
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          />
          <select
            value={userType}
            onChange={(e) => setUserType(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          >
            <option value="">All traveler types</option>
            <option value="local_resident">Lives in Cebu</option>
            <option value="international_visitor">Visiting from abroad</option>
            <option value="domestic_traveler">Visiting from the Philippines</option>
          </select>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          >
            <option value="">All roles</option>
            <option value="contributor">Contributors</option>
            <option value="admin">Admins</option>
          </select>
          <select
            value={status}
            onChange={(e) => setStatus(e.target.value)}
            className="border border-sw-border rounded-xl px-3 py-2 text-sm bg-sw-surface"
          >
            <option value="">All statuses</option>
            <option value="active">Can sign in</option>
            <option value="inactive">Paused</option>
          </select>
        </div>
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        <Card className="xl:col-span-2 p-0 overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-sw-bg-alt text-left">
              <tr>
                <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Person</th>
                <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">From</th>
                <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Type</th>
                <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Tags sent</th>
                <th className="p-3 text-[11px] uppercase font-bold text-sw-muted">Role</th>
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                <tr><td colSpan={5} className="p-6 text-sw-muted">Loading people…</td></tr>
              ) : data?.items.length === 0 ? (
                <tr><td colSpan={5} className="p-6 text-sw-muted">No people match this search.</td></tr>
              ) : (
                data?.items.map((u) => (
                  <tr
                    key={u.id}
                    className={`border-t border-sw-border cursor-pointer hover:bg-sw-bg-alt/60 ${
                      selectedId === u.id ? 'bg-sw-primary/5' : ''
                    }`}
                    onClick={() => setSelectedId(u.id)}
                  >
                    <td className="p-3">
                      <div className="font-bold">{u.display_name || u.email}</div>
                      <div className="text-xs text-sw-muted">{u.email}</div>
                    </td>
                    <td className="p-3 text-sw-muted">
                      {u.city_of_origin || u.country_of_origin
                        ? [u.city_of_origin, u.country_of_origin].filter(Boolean).join(', ')
                        : '—'}
                    </td>
                    <td className="p-3 text-sw-muted">{travelerTypeLabel(u.user_type)}</td>
                    <td className="p-3 font-bold">{u.report_count}</td>
                    <td className="p-3">
                      {u.is_admin ? (
                        <Badge variant="default" value="admin" label="Admin" />
                      ) : (
                        <span className="text-sw-muted">Contributor</span>
                      )}
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
            noun="people"
          />
        </Card>

        <Card className="h-fit sticky top-6">
          <h2 className="font-black text-sw-ink mb-3">Person summary</h2>
          {!selected ? (
            <p className="text-sm text-sw-muted">Select someone to see a short, non-technical profile.</p>
          ) : (
            <UserSummary
              user={selected}
              contributions={contributions}
              onToggleAdmin={() => toggle.mutate({ id: selected.id, is_admin: !selected.is_admin })}
              onPause={() => {
                const next = !selected.is_active
                const ok = window.confirm(
                  next
                    ? `Resume ${selected.display_name || selected.email}? They will be able to sign in again.`
                    : `Pause ${selected.display_name || selected.email}? They will not be able to sign in until you resume the account.`,
                )
                if (!ok) return
                pause.mutate({ id: selected.id, is_active: next })
              }}
            />
          )}
        </Card>
      </div>
    </div>
  )
}

function UserSummary({
  user,
  contributions,
  onToggleAdmin,
  onPause,
}: {
  user: AdminUser
  contributions?: AdminUserContributions
  onToggleAdmin: () => void
  onPause: () => void
}) {
  const hometown = [user.city_of_origin, user.country_of_origin].filter(Boolean).join(', ')
  const visible = contributions?.visible_reports ?? user.visible_reports ?? 0
  const pending = contributions?.pending_reports ?? user.pending_reports ?? 0
  const flagged = contributions?.flagged_reports ?? user.flagged_reports ?? 0
  const name = user.display_name || user.email
  return (
    <div className="space-y-4 text-sm">
      <p className="text-sw-secondary leading-relaxed">
        <strong>{name}</strong>
        {hometown ? ` is from ${hometown}` : ''}. {travelerTypeLabel(user.user_type)}. They have
        sent {user.report_count} tag{user.report_count === 1 ? '' : 's'}
        {user.report_count
          ? `: ${visible} on the map, ${pending} waiting, ${flagged} flagged.`
          : '.'}
      </p>
      <dl className="grid grid-cols-2 gap-3">
        <div className="bg-sw-bg rounded-xl p-3">
          <dt className="text-[10px] font-bold uppercase text-sw-muted">Joined</dt>
          <dd className="font-bold mt-1">{new Date(user.created_at).toLocaleDateString()}</dd>
        </div>
        <div className="bg-sw-bg rounded-xl p-3">
          <dt className="text-[10px] font-bold uppercase text-sw-muted">Account</dt>
          <dd className="font-bold mt-1">{user.is_active ? 'Can sign in' : 'Paused'}</dd>
        </div>
      </dl>
      <Button variant="ghost" className="w-full" onClick={onToggleAdmin}>
        {user.is_admin ? 'Remove admin access' : 'Make this person an admin'}
      </Button>
      <Button variant={user.is_active ? 'warning' : 'secondary'} className="w-full" onClick={onPause}>
        {user.is_active ? 'Pause account' : 'Resume account'}
      </Button>
    </div>
  )
}

export function travelerTypeLabel(value?: string | null): string {
  switch (value) {
    case 'local_resident':
      return 'Lives in Cebu'
    case 'international_visitor':
      return 'Visiting from abroad'
    case 'domestic_traveler':
      return 'Visiting from elsewhere in the Philippines'
    default:
      return 'Not specified'
  }
}

export function lifecycleLabel(value?: string | null): string {
  switch (value) {
    case 'defined':
      return 'Established'
    case 'emerging':
      return 'Growing'
    case 'unthreshold':
      return 'Just starting'
    default:
      return (value ?? 'Unknown').replace(/_/g, ' ')
  }
}

export function statusLabel(value?: string | null): string {
  switch (value) {
    case 'pending':
      return 'Waiting for review'
    case 'visible':
      return 'On the map'
    case 'flagged':
      return 'Needs a closer look'
    case 'removed':
      return 'Not shown'
    case 'hidden':
      return 'Hidden'
    default:
      return (value ?? 'Unknown').replace(/_/g, ' ')
  }
}

export function categoryLabel(value?: string | null): string {
  if (!value) return 'Unspecified'
  const labels: Record<string, string> = {
    food: 'Food',
    activity: 'Activity',
    crowd: 'Crowd',
    safety: 'Safety',
    transport: 'Transport',
    school: 'School',
    issue: 'Issue',
    shopping: 'Shopping',
    nightlife: 'Nightlife',
    other: 'Other',
  }
  return labels[value.toLowerCase()] ?? value.replace(/_/g, ' ')
}

export function mixLabel(value?: string | null): string {
  switch (value) {
    case 'local':
      return 'Mostly locals'
    case 'international':
      return 'Mostly visitors'
    case 'mixed':
      return 'Locals and visitors'
    default:
      return 'Not sure yet'
  }
}

export function liveStatusLabel(value?: string | null): string {
  switch (value) {
    case 'quiet_now':
      return 'Quiet right now'
    case 'active_now':
      return 'Active right now'
    case 'busy_now':
      return 'Busy right now'
    case 'peak_now':
      return 'Peak activity'
    case 'caution_now':
      return 'Use extra caution'
    default:
      return (value ?? 'Unknown').replace(/_/g, ' ')
  }
}

export function auditLabel(value?: string | null): string {
  const labels: Record<string, string> = {
    'report.admin_approve': 'Approved a tag',
    'report.admin_reject': 'Rejected a tag',
    'report.admin_flag': 'Flagged a tag',
    'report.created': 'Someone sent a tag',
    'report.approved': 'A tag was approved',
    'report.rejected': 'A tag was rejected',
    'report.flagged': 'A tag was flagged',
  }
  if (!value) return 'Activity'
  return labels[value] ?? value.replace(/[._]/g, ' ')
}

export const REPORT_CATEGORIES = [
  'food',
  'activity',
  'crowd',
  'safety',
  'transport',
  'school',
  'issue',
  'shopping',
  'nightlife',
  'other',
] as const

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

/** One-word pill for dense tables. Full sentence stays on `statusLabel`. */
export function compactStatusLabel(value?: string | null): string {
  switch (value) {
    case 'pending':
      return 'Waiting'
    case 'visible':
      return 'On map'
    case 'flagged':
      return 'Hold'
    case 'removed':
    case 'hidden':
      return 'Hidden'
    default:
      return statusLabel(value)
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
    'report.admin_approve': 'Published a tag',
    'report.admin_reject': 'Marked a tag as wrong',
    'report.admin_flag': 'Put a tag on hold',
    'report.create': 'Someone sent a tag',
    'report.created': 'Someone sent a tag',
    'report.approved': 'A tag was published',
    'report.rejected': 'A tag was marked wrong',
    'report.flagged': 'A tag was put on hold',
    'user.make_admin': 'Made someone an admin',
    'user.remove_admin': 'Removed admin access',
    'user.pause': 'Paused an account',
    'user.resume': 'Resumed an account',
    'config.update': 'Saved tag rules',
    'pipeline.rebuild': 'Refreshed the map',
  }
  if (!value) return 'Activity'
  return labels[value] ?? value.replace(/[._]/g, ' ')
}

export function moderationReasonLabel(value?: string | null): string {
  switch (value) {
    case 'wrong_location':
      return 'Wrong location'
    case 'wrong_kind':
      return 'Wrong kind of place'
    case 'spam':
      return 'Spam'
    case 'sensitive':
      return 'Sensitive building'
    case 'other':
      return 'Other'
    default:
      return value ? value.replace(/_/g, ' ') : 'Choose a reason'
  }
}

export const MODERATION_REASONS = [
  'wrong_location',
  'wrong_kind',
  'spam',
  'sensitive',
  'other',
] as const

export const MODERATION_REASON_HINTS: Record<(typeof MODERATION_REASONS)[number], string> = {
  wrong_location: 'The pin is not this place.',
  wrong_kind: 'Food, school, safety — the kind does not match.',
  spam: 'Repeated, empty, or not a real observation.',
  sensitive: 'Hospital, school, military, or similar.',
  other: 'Something else — keep it off the map.',
}

export function manilaWhen(iso?: string | null): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('en-PH', {
    timeZone: 'Asia/Manila',
    dateStyle: 'medium',
    timeStyle: 'short',
  })
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

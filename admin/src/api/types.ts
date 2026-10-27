export type AdminReport = {
  id: string
  h3_index: string
  category: string
  tags: string[]
  note_text?: string | null
  visibility_status: string
  confidence_score: number
  contributor_count: number
  duplicate_count: number
  created_at: string
  area_name?: string | null
  contributor_id?: string | null
  contributor_label?: string | null
}

export type AdminReportList = {
  items: AdminReport[]
  total: number
  page: number
  page_size: number
}

export type AdminCellContext = {
  h3_index: string
  pending_count: number
  visible_count: number
  flagged_count: number
  distinct_contributors: number
  top_category: string | null
  category_agreement: number
  threshold: number
  threshold_met: boolean
}

export type AdminReportDetail = AdminReport & {
  cell_context: AdminCellContext
}

export type AdminZoneValidation = {
  zone_id: string
  display_name: string
  total_signals: number
  matching_signals: number
  confidence: number
  top_category: string | null
  last_updated: string | null
  lifecycle_state: string
  traveler_mix?: string | null
  function_type?: string | null
  live_status?: string
  matching_ratio?: number
  plain_summary?: string
  visible_signals?: number
  pending_signals?: number
  flagged_signals?: number
}

export type AdminDashboardStats = {
  pending_reports: number
  flagged_reports: number
  active_zones: number
  total_users: number
  local_contributor_ratio: number
  reports_last_30_days: { date: string; count: number }[]
  visible_reports?: number
  near_threshold_reports?: number
  defined_zones?: number
  emerging_zones?: number
  local_users?: number
  international_users?: number
  domestic_users?: number
  admin_users?: number
  plain_summary?: string
}

export type AdminZone = {
  zone_id: string
  display_name: string
  slug: string
  traveler_mix?: string | null
  function_type?: string | null
  live_status: string
  confidence_score: number
  report_count: number
  is_active: boolean
  lifecycle_state: string
}

export type AdminUser = {
  id: string
  email: string
  display_name?: string | null
  user_type?: string | null
  traveler_type?: string | null
  country_of_origin?: string | null
  city_of_origin?: string | null
  is_active: boolean
  is_admin: boolean
  report_count: number
  visible_reports?: number
  pending_reports?: number
  flagged_reports?: number
  created_at: string
}

export type AdminPeopleSnapshot = {
  total: number
  active: number
  admins: number
  contributors: number
  local_residents: number
  international_visitors: number
  domestic_travelers: number
}

export type AdminUserList = {
  items: AdminUser[]
  total: number
  page: number
  page_size: number
  snapshot?: AdminPeopleSnapshot
}

export type AdminUserContributions = {
  user_id: string
  total_reports: number
  visible_reports: number
  pending_reports: number
  flagged_reports: number
  badges: string[]
}

export type AdminCatalogEntry = {
  zone_id: string
  zone_name: string
  city: string
  zone_type: string
  radius_km: number
  center_lat: number
  center_lng: number
  characteristics: string[]
  default_local_ratio: number
  is_active: boolean
}

export type AdminSystemConfig = {
  pending_min_reports_per_cell: number
  pending_agreement_ratio: number
  report_cooldown_hours_per_cell: number
  report_max_per_user_per_hour: number
  h3_resolution: number
}

export type AdminAuditEntry = {
  id: string
  action_type: string
  entity_type: string
  entity_id?: string | null
  created_at: string
  actor_label?: string | null
  area_name?: string | null
  category?: string | null
  tags?: string[]
  result?: string | null
  reason?: string | null
  payload_json?: Record<string, unknown> | null
}

export type AdminAnalyticsOverview = {
  pending_reports: number
  flagged_reports: number
  visible_reports: number
  active_zones: number
  local_contributors: number
  international_contributors: number
  domestic_contributors: number
  zones_emerging: number
  zones_defined: number
  city_pulse: Record<string, unknown>
}

export type AdminPipelineResult = {
  job: string
  message: string
  affected_counts: Record<string, number>
}

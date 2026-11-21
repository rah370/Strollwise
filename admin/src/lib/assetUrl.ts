/** Public files in `admin/public/`, including when the SPA is served at `/console/`. */
export function assetUrl(path: string): string {
  const base = import.meta.env.BASE_URL || '/'
  const prefix = base.endsWith('/') ? base : `${base}/`
  return `${prefix}${path.replace(/^\//, '')}`
}

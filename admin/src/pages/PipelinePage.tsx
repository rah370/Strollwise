import { Navigate } from 'react-router-dom'

/** Map-refresh controls now live under Settings so the sidebar stays simple. */
export function PipelinePage() {
  return <Navigate to="/settings?tab=map" replace />
}

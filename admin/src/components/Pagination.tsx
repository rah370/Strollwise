export function Pagination({
  page,
  pageSize,
  total,
  onPageChange,
  noun = 'rows',
}: {
  page: number
  pageSize: number
  total: number
  onPageChange: (page: number) => void
  noun?: string
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1
  const to = Math.min(page * pageSize, total)
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 px-4 py-3 text-xs text-sw-muted border-t border-sw-border bg-sw-bg">
      <p>
        Showing {from}–{to} of {total} {noun}
      </p>
      <div className="flex items-center gap-2">
        <button
          type="button"
          className="px-3 py-1.5 rounded-lg border border-sw-border bg-white font-bold disabled:opacity-40"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
        >
          Previous
        </button>
        <span className="font-bold text-sw-ink">
          Page {page} of {pages}
        </span>
        <button
          type="button"
          className="px-3 py-1.5 rounded-lg border border-sw-border bg-white font-bold disabled:opacity-40"
          disabled={page >= pages}
          onClick={() => onPageChange(page + 1)}
        >
          Next
        </button>
      </div>
    </div>
  )
}

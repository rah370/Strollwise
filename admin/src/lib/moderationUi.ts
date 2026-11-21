/** Review-queue helpers: compact tags, grouping, and the smart search bar. */

export const METADATA_TAGS = new Set(['anonymous', 'exact_road_spot'])

export function splitModerationTags(tags: string[]): { visible: string[]; metadata: string[] } {
  const visible: string[] = []
  const metadata: string[] = []
  for (const raw of tags) {
    const tag = raw.trim()
    if (!tag) continue
    if (METADATA_TAGS.has(tag.toLowerCase())) metadata.push(tag.toLowerCase())
    else visible.push(tag)
  }
  return { visible, metadata }
}

export function personTaggedLabel(count: number): string {
  if (count === 1) return '1 person tagged this area'
  return `${count} people tagged this area`
}

export function morePeopleNeededLabel(needed: number): string {
  if (needed <= 0) {
    return 'Enough people already agree, so publishing it will show it on the traveler map.'
  }
  if (needed === 1) return '1 more person tagging the same thing would auto-publish this area.'
  return `${needed} more people tagging the same thing would auto-publish this area.`
}

export function agreementTone(score: number): 'high' | 'mid' | 'low' {
  if (score >= 80) return 'high'
  if (score >= 40) return 'mid'
  return 'low'
}

export function agreementBadgeClass(score: number): string {
  switch (agreementTone(score)) {
    case 'high':
      return 'bg-emerald-100 text-emerald-800'
    case 'mid':
      return 'bg-amber-100 text-amber-800'
    default:
      return 'bg-slate-100 text-slate-600'
  }
}

export function duplicateGroupKey(row: {
  area_name?: string | null
  category: string
  tags: string[]
  visibility_status: string
}): string {
  const { visible } = splitModerationTags(row.tags)
  return [
    (row.area_name || '').trim().toLowerCase(),
    row.category.toLowerCase(),
    row.visibility_status.toLowerCase(),
    visible.map((tag) => tag.toLowerCase()).sort().join('|'),
  ].join('::')
}

/** `tag:food area:"IT Park" lahug` → exact tag filter plus a place search. */
export function parseSmartSearch(raw: string): { search: string; tag: string } {
  const source = raw.trim()
  if (!source) return { search: '', tag: '' }

  const tokenRe = /(?:tag|area):(?:"([^"]+)"|(\S+))/gi
  const rest: string[] = []
  const areas: string[] = []
  let tag = ''
  let last = 0
  let match: RegExpExecArray | null
  while ((match = tokenRe.exec(source))) {
    const gap = source.slice(last, match.index).trim()
    if (gap) rest.push(gap)
    const value = (match[1] || match[2] || '').trim()
    const kind = match[0].slice(0, match[0].indexOf(':')).toLowerCase()
    if (kind === 'tag') tag = value
    else if (kind === 'area' && value) areas.push(value)
    last = match.index + match[0].length
  }
  const tail = source.slice(last).trim()
  if (tail) rest.push(tail)
  return {
    search: [...areas, ...rest].join(' ').trim(),
    tag,
  }
}

import { site } from '../site.config.js'

// Shared frame for the policy pages: title, effective date, readable column.
export default function LegalPage({ title, intro, children, dated = true }) {
  return (
    <article className="legal wrap">
      <h1>{title}</h1>
      {dated && <p className="muted small">Last updated {site.policiesUpdated}</p>}
      {intro && <p className="lede">{intro}</p>}
      {children}
    </article>
  )
}

export const Mail = ({ subject, children }) => (
  <a href={`mailto:${site.supportEmail}${subject ? `?subject=${encodeURIComponent(subject)}` : ''}`}>
    {children ?? site.supportEmail}
  </a>
)

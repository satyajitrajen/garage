import { site } from '../site.config.js'

const Apple = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true" width="22" height="22">
    <path
      fill="currentColor"
      d="M16.37 12.6c.02 2.3 2.03 3.07 2.05 3.08-.02.05-.32 1.1-1.06 2.18-.64.94-1.3 1.87-2.35 1.89-1.03.02-1.36-.61-2.53-.61-1.18 0-1.54.59-2.52.63-1.01.04-1.78-1.01-2.43-1.95-1.32-1.91-2.33-5.4-.97-7.75.67-1.17 1.88-1.91 3.19-1.93.99-.02 1.93.67 2.53.67.61 0 1.75-.83 2.95-.71.5.02 1.91.2 2.81 1.53-.07.05-1.68.98-1.67 2.97M14.43 6.95c.54-.65.9-1.56.8-2.46-.77.03-1.71.52-2.27 1.17-.5.58-.94 1.5-.82 2.39.86.07 1.75-.44 2.29-1.1"
    />
  </svg>
)

const Play = () => (
  <svg viewBox="0 0 24 24" aria-hidden="true" width="20" height="20">
    <path fill="currentColor" d="M4.2 2.4 13.6 12l-9.4 9.6c-.3-.2-.5-.6-.5-1.1V3.5c0-.5.2-.9.5-1.1Zm10.6 10.8 2.3 2.3-10.8 6.2 8.5-8.5Zm0-2.4L6.3 2.3l10.8 6.2-2.3 2.3Zm3.6-2 2.7 1.6c.8.5.8 1.8 0 2.2l-2.7 1.6-2.6-2.6 2.6-2.8Z" />
  </svg>
)

function Badge({ href, icon, small, big }) {
  const body = (
    <>
      {icon}
      <span>
        <span className="badge-small">{href ? small : 'Coming soon to'}</span>
        <span className="badge-big">{big}</span>
      </span>
    </>
  )
  return href ? (
    <a className="badge" href={href} rel="noopener">
      {body}
    </a>
  ) : (
    <span className="badge badge-soon" aria-disabled="true">
      {body}
    </span>
  )
}

export default function StoreBadges() {
  return (
    <div className="badges">
      <Badge href={site.stores.playStore} icon={<Play />} small="Get it on" big="Google Play" />
      <Badge href={site.stores.appStore} icon={<Apple />} small="Download on the" big="App Store" />
    </div>
  )
}

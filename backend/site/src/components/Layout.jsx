import { useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { site } from '../site.config.js'

const titles = {
  '/': `${site.appName} — workshop management for car garages`,
  '/privacy': `Privacy policy — ${site.appName}`,
  '/terms': `Terms of service — ${site.appName}`,
  '/refunds': `Cancellation and refunds — ${site.appName}`,
  '/support': `Support — ${site.appName}`,
  '/delete-account': `Delete your account — ${site.appName}`,
}

export default function Layout() {
  const { pathname } = useLocation()
  useEffect(() => {
    document.title = titles[pathname] ?? `Page not found — ${site.appName}`
  }, [pathname])

  return (
    <div className="shell">
      <a className="skip" href="#main">
        Skip to content
      </a>
      <header className={pathname === '/' ? 'topbar topbar-over' : 'topbar'}>
        <Link to="/" className="brand" aria-label={`${site.appName} home`}>
          <img src="/logo.png" alt="" width="54" height="33" />
          <span>{site.appName}</span>
        </Link>
        <nav aria-label="Main" className="nav-pill">
          <NavLink to="/" end>
            Home
          </NavLink>
          <Link to="/#features">Features</Link>
          <Link to="/#pricing">Pricing</Link>
          <NavLink to="/support">Support</NavLink>
        </nav>
        <Link to="/#download" className="btn btn-dark btn-sm">
          Download app
        </Link>
      </header>

      <main id="main">
        <Outlet />
      </main>

      <footer className="footer">
        <div className="footer-inner">
          <div>
            <p className="footer-brand">{site.appName}</p>
            <p className="muted">
              A {site.company} product. Made for independent workshops in India.
            </p>
            <p className="muted">
              <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>
            </p>
          </div>
          <nav aria-label="Legal" className="footer-links">
            <Link to="/privacy">Privacy policy</Link>
            <Link to="/terms">Terms of service</Link>
            <Link to="/refunds">Cancellation and refunds</Link>
            <Link to="/support">Support</Link>
            <Link to="/delete-account">Delete your account</Link>
          </nav>
        </div>
        <p className="muted small">
          © {new Date().getFullYear()} {site.company}. All rights reserved.
        </p>
      </footer>
    </div>
  )
}

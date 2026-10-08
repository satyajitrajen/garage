import { Link } from 'react-router-dom'

export default function NotFound() {
  return (
    <section className="wrap section notfound">
      <h1>This page doesn’t exist</h1>
      <p className="lede">The link may be old or mistyped.</p>
      <Link className="btn" to="/">
        Go to the home page
      </Link>
    </section>
  )
}

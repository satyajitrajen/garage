import { useState } from 'react'
import { Link } from 'react-router-dom'
import LegalPage from '../components/LegalPage.jsx'
import { site } from '../site.config.js'

// Google Play requires a web page where users can request account deletion
// without the app. Requests go to support by email and are handled manually.
export default function DeleteAccount() {
  const [email, setEmail] = useState('')
  const [garage, setGarage] = useState('')
  const [scope, setScope] = useState('account')
  const [error, setError] = useState('')

  const send = (e) => {
    e.preventDefault()
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
      setError('Enter the email address you sign in with.')
      return
    }
    setError('')
    const what =
      scope === 'garage'
        ? 'Delete my account and my whole garage, including all its records.'
        : 'Delete my login only. My garage and its records stay with the other owner.'
    const body = [
      `Please delete my ${site.appName} account.`,
      '',
      `Sign-in email: ${email.trim()}`,
      `Garage name: ${garage.trim() || '-'}`,
      `Request: ${what}`,
    ].join('\n')
    window.location.href = `mailto:${site.supportEmail}?subject=${encodeURIComponent(
      `Account deletion request: ${email.trim()}`,
    )}&body=${encodeURIComponent(body)}`
  }

  return (
    <LegalPage
      title={`Delete your ${site.appName} account`}
      intro={`You can ask ${site.company} to delete your ${site.appName} account and its data at any time, with or without the app installed.`}
    >
      <h2>How to request deletion</h2>
      <ol className="steps">
        <li>Fill in the form below and tap “Email deletion request”.</li>
        <li>Your email app opens with the request ready. Send it from the address you sign in with.</li>
        <li>We confirm by email and delete the account within 30 days.</li>
      </ol>

      <form className="delete-form" onSubmit={send} noValidate>
        <label>
          Sign-in email
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            aria-invalid={!!error}
            aria-describedby={error ? 'email-error' : undefined}
            required
          />
        </label>
        {error && (
          <p id="email-error" className="field-error" role="alert">
            {error}
          </p>
        )}
        <label>
          <span>
            Garage name <span className="muted">(optional)</span>
          </span>
          <input value={garage} onChange={(e) => setGarage(e.target.value)} />
        </label>
        <fieldset>
          <legend>What should be deleted?</legend>
          <label className="radio">
            <input
              type="radio"
              name="scope"
              checked={scope === 'account'}
              onChange={() => setScope('account')}
            />
            Only my login (I am a staff member, or another owner keeps the garage)
          </label>
          <label className="radio">
            <input
              type="radio"
              name="scope"
              checked={scope === 'garage'}
              onChange={() => setScope('garage')}
            />
            My login and my whole garage with all its records
          </label>
        </fieldset>
        <button type="submit" className="btn">
          Email deletion request
        </button>
        <p className="muted small">
          No email app? Write to {site.supportEmail} with the same details.
        </p>
      </form>

      <h2>What is deleted</h2>
      <ul>
        <li>Your name, email, password and sign-in sessions.</li>
        <li>
          If you delete the garage: its profile, customers, vehicles, job cards, estimates, bills,
          payments, expenses and receipt photos, price list, staff, attendance and payroll records,
          and team invites.
        </li>
      </ul>

      <h2>What is kept, and for how long</h2>
      <ul>
        <li>
          Records of your subscription payments to us, kept for the period Indian tax law requires
          (currently up to 8 years), then deleted.
        </li>
        <li>Copies in server backups, which are removed as those backups expire.</li>
      </ul>
      <p>
        Deletion cannot be undone. If you want a copy of your records first, ask for it in the same
        email. More in our <Link to="/privacy">privacy policy</Link>.
      </p>
    </LegalPage>
  )
}

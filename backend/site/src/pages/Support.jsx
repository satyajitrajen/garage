import { Link } from 'react-router-dom'
import LegalPage, { Mail } from '../components/LegalPage.jsx'
import { site } from '../site.config.js'

const faqs = [
  {
    q: 'I forgot my password.',
    a: 'On the sign-in screen, tap “Forgot password?” and enter your email. Open the link in the email to set a new password.',
  },
  {
    q: 'How do I add my service advisor or manager?',
    a: 'Go to More, then Team logins, then Invite. Enter their email, choose Staff or Owner, and tick what they may do. They get an email to join your garage.',
  },
  {
    q: 'Why does my bill say “Bill” and not “Tax invoice”?',
    a: 'A tax invoice needs your GSTIN. Add it in More, then Garage settings, and new bills will show as tax invoices with your GSTIN printed.',
  },
  {
    q: 'How is GST calculated?',
    a: 'Each item uses the GST rate saved on it (0%, 5%, 12%, 18% or 28%). The bill shows CGST and SGST for each rate separately. A discount on the whole bill is spread across the items before tax.',
  },
  {
    q: 'Can I use the app on more than one phone?',
    a: 'Yes. Sign in with the same account on any phone; your records stay in sync.',
  },
  {
    q: 'How do I cancel my subscription?',
    a: 'More, then Subscription, then Cancel subscription. You keep access until the paid period ends.',
  },
]

export default function Support() {
  return (
    <LegalPage
      title="Support"
      dated={false}
      intro={`Questions, problems or ideas for ${site.appName}? Email us and we usually reply within one working day.`}
    >
      <p className="contact-box">
        <Mail subject={`${site.appName} support`} />
        <span className="muted small block">
          Tell us your garage name, the phone you use and what happened. A screenshot helps.
        </span>
      </p>

      <h2>Common questions</h2>
      <div className="faqs">
        {faqs.map((f) => (
          <details key={f.q}>
            <summary>{f.q}</summary>
            <p>{f.a}</p>
          </details>
        ))}
      </div>

      <h2>Account and data</h2>
      <p>
        <Link to="/delete-account">Delete your account</Link>
        {' · '}
        <Link to="/privacy">Privacy policy</Link>
        {' · '}
        <Link to="/terms">Terms of service</Link>
      </p>
    </LegalPage>
  )
}

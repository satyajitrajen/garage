import { Link } from 'react-router-dom'
import LegalPage, { Mail } from '../components/LegalPage.jsx'
import { site } from '../site.config.js'

export default function Privacy() {
  const { appName, company } = site
  return (
    <LegalPage
      title="Privacy policy"
      intro={`This policy explains what ${appName} stores, why, who it is shared with and how to have it deleted. ${appName} is operated by ${company} ("we").`}
    >
      <h2>Who this applies to</h2>
      <p>
        {appName} is a business app for car workshops. It applies to garage owners and the team
        members they invite. Garages also enter details about their own customers and staff; for
        that information the garage decides what is entered and why, and we store and process it
        on the garage’s behalf.
      </p>

      <h2>What we store</h2>
      <h3>Your account</h3>
      <ul>
        <li>Name, email address and a password, stored only as a secure one-way hash.</li>
        <li>Which garages you belong to, your role and your permissions.</li>
        <li>Sign-in sessions, so you stay signed in on your phone.</li>
      </ul>
      <h3>Your garage</h3>
      <ul>
        <li>
          Garage profile: name, address, phone, email, GSTIN and UPI ID, as printed on bills and
          estimates.
        </li>
        <li>
          Workshop records you create: customers (name, phone, WhatsApp number, email, address,
          GSTIN), vehicles (registration number, make, model, KM), job cards, estimates, bills and
          payments.
        </li>
        <li>Expenses and the receipt photos you attach to them.</li>
        <li>Staff records: name, phone, salary, attendance and salary advances.</li>
        <li>Your subscription status and plan.</li>
      </ul>
      <h3>What we do not collect</h3>
      <p>
        No location, no contacts, no advertising IDs, no analytics or tracking SDKs and no ads. We
        never see your card or bank details: subscription payments are taken by Razorpay.
      </p>

      <h2>Phone permissions</h2>
      <ul>
        <li>
          <strong>Camera and photos</strong>: only when you choose to attach a receipt photo to an
          expense. The selected photo is uploaded to your garage’s records; nothing else is read.
        </li>
        <li>
          <strong>Sharing</strong>: when you share a bill or estimate, your phone’s share sheet
          sends it to the app you choose. We do not see those messages.
        </li>
      </ul>

      <h2>Why we use it</h2>
      <ul>
        <li>To run the app: show, save and sync your workshop records between devices.</li>
        <li>To secure your account and keep each garage’s data separate.</li>
        <li>To send account emails: verification, password reset and team invites.</li>
        <li>To manage your subscription and answer support requests.</li>
      </ul>
      <p>We do not sell your data or use it for advertising.</p>

      <h2>Who we share it with</h2>
      <p>Only service providers that we need to run {appName}, under contract:</p>
      <ul>
        <li>Cloud hosting and database providers, where the app’s data is stored.</li>
        <li>Razorpay, to take subscription payments.</li>
        <li>An email delivery provider, for account emails.</li>
        <li>
          Google Fonts: the app downloads its typeface files from Google, which can see your
          device’s IP address when it does.
        </li>
      </ul>
      <p>
        We may also disclose information when the law requires it, or to protect the rights and
        safety of users and the service.
      </p>

      <h2>Security</h2>
      <p>
        Data is encrypted in transit (HTTPS). Passwords are hashed, sign-in tokens expire after
        minutes and are rotated, and every request is checked against the garage and the
        permissions it belongs to.
      </p>

      <h2>How long we keep it</h2>
      <p>
        Workshop records are kept while your garage’s account is open. When an account is deleted,
        its data is removed within 30 days, except records we must keep by law (for example our
        own subscription invoices, kept for the period Indian tax law requires).
      </p>

      <h2>Your rights</h2>
      <p>
        You can see and correct your data in the app at any time. You can ask us for a copy of your
        data, or to delete your account, by writing to <Mail subject="Data request" />. See{' '}
        <Link to="/delete-account">how to delete your account</Link>. We handle requests in line
        with India’s Digital Personal Data Protection Act, 2023.
      </p>

      <h2>Children</h2>
      <p>{appName} is a business tool and is not meant for anyone under 18.</p>

      <h2>Changes</h2>
      <p>
        If this policy changes, we will update the date at the top and, for significant changes,
        tell account owners by email or in the app.
      </p>

      <h2>Contact</h2>
      <p>
        Questions or complaints about privacy: <Mail subject="Privacy" />.
      </p>
    </LegalPage>
  )
}

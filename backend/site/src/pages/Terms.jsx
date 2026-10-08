import { Link } from 'react-router-dom'
import LegalPage, { Mail } from '../components/LegalPage.jsx'
import { rupees, site } from '../site.config.js'

export default function Terms() {
  const { appName, company, trialDays, prices } = site
  return (
    <LegalPage
      title="Terms of service"
      intro={`These terms are an agreement between you and ${company} for the use of ${appName}. By creating an account or using the app you accept them.`}
    >
      <h2>The service</h2>
      <p>
        {appName} helps car workshops manage job cards, estimates, bills, payments, expenses, staff
        and payroll. We may improve or change features over time.
      </p>

      <h2>Accounts</h2>
      <ul>
        <li>You must be at least 18 and able to enter a contract on behalf of your garage.</li>
        <li>Keep your password private. You are responsible for activity under your account.</li>
        <li>
          The person who creates a garage is its owner and controls who else can sign in and what
          they can do.
        </li>
      </ul>

      <h2>Trial and subscription</h2>
      <ul>
        <li>New garages get a free {trialDays}-day trial with every feature.</li>
        <li>
          After the trial, a subscription is needed to keep adding records: {rupees(prices.monthly)}{' '}
          per month or {rupees(prices.yearly)} per year, unless a different price is shown when you
          subscribe.
        </li>
        <li>Subscriptions renew automatically through Razorpay until cancelled.</li>
        <li>
          If a subscription lapses, you can still sign in and view your records, but adding new
          records is paused until you renew.
        </li>
        <li>
          Cancellation and refunds are covered in our{' '}
          <Link to="/refunds">cancellation and refund policy</Link>.
        </li>
      </ul>

      <h2>Your data</h2>
      <p>
        You own the records you put into {appName}. You give us permission to store and process
        them only to provide the service, as described in the <Link to="/privacy">privacy policy</Link>.
        You confirm you have the right to enter your customers’ and staff’s details.
      </p>

      <h2>Bills and taxes</h2>
      <p>
        {appName} calculates GST from the rates you set, but you are responsible for the accuracy
        of your bills, your GSTIN and your tax filings. Check figures before relying on them.
      </p>

      <h2>Acceptable use</h2>
      <p>Do not use {appName} to:</p>
      <ul>
        <li>break any law or store data you have no right to hold;</li>
        <li>try to access another garage’s data, or test, probe or overload the service;</li>
        <li>copy, resell or reverse-engineer the app.</li>
      </ul>

      <h2>Availability</h2>
      <p>
        We work to keep {appName} available and your data safe, but the service is provided “as
        is”, without guarantees of uninterrupted operation. Keep your own copies of anything
        critical.
      </p>

      <h2>Liability</h2>
      <p>
        To the extent the law allows, {company} is not liable for indirect or consequential losses,
        such as lost profits or business. Our total liability for any claim is limited to the
        amount you paid us in the 12 months before the claim.
      </p>

      <h2>Ending the agreement</h2>
      <p>
        You can stop using {appName} and <Link to="/delete-account">delete your account</Link> at
        any time. We may suspend accounts that break these terms, after notice where reasonable.
      </p>

      <h2>Changes and law</h2>
      <p>
        We may update these terms; the date above shows the latest version, and significant changes
        will be notified to account owners. These terms are governed by the laws of India, and
        disputes are subject to the courts of India.
      </p>

      <h2>Contact</h2>
      <p>
        <Mail subject="Terms of service" />
      </p>
    </LegalPage>
  )
}

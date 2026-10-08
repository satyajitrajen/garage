import LegalPage, { Mail } from '../components/LegalPage.jsx'
import { site } from '../site.config.js'

export default function Refunds() {
  const { appName, trialDays } = site
  return (
    <LegalPage
      title="Cancellation and refunds"
      intro={`How cancelling a ${appName} subscription works, and when you can get money back.`}
    >
      <h2>Free trial</h2>
      <p>
        The first {trialDays} days are free and need no payment details. Nothing is charged unless
        you subscribe.
      </p>

      <h2>Cancelling</h2>
      <p>
        Garage owners can cancel any time in the app under More, then Subscription, then Cancel
        subscription. Cancelling stops the next renewal. You keep full access until the end of the
        period you have already paid for.
      </p>

      <h2>Refunds</h2>
      <ul>
        <li>
          Payments are for a monthly or yearly period and are not refunded for the unused part of
          that period.
        </li>
        <li>
          If you were charged twice, charged after cancelling, or charged the wrong amount, write
          to us within 7 days of the charge and we will refund the extra amount in full.
        </li>
        <li>
          Approved refunds go back to the original payment method through Razorpay, usually within
          5 to 7 working days.
        </li>
      </ul>

      <h2>Contact</h2>
      <p>
        Billing questions: <Mail subject="Billing" />. Include your garage name and the payment
        date.
      </p>
    </LegalPage>
  )
}

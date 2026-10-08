import { Link } from 'react-router-dom'
import { BillScreen, HomeScreen, JobScreen } from '../components/Phone.jsx'
import StoreBadges from '../components/StoreBadges.jsx'
import { rupees, site } from '../site.config.js'

const cards = [
  ['Job cards', 'Plate, KM, fuel, complaints and inspection in one place. Move the car through each stage with one tap.'],
  ['GST done right', 'Each item keeps its own GST rate. Bills show CGST and SGST per slab, ready to share.'],
  ['Payments and dues', 'Cash, UPI, card or part payments. Dues stay on the home screen until they are cleared.'],
  ['Staff and payroll', 'Attendance, salary advances and the monthly payout, with advances deducted for you.'],
]

const billing = [
  ['Estimates customers can approve', 'Share an estimate from your phone. Once approved it becomes the job card’s work list.'],
  ['Price list with GST', 'Save parts and labour once, with their rate, and add them to any job in a tap.'],
  ['Plain bill or tax invoice', 'Without a GSTIN it prints as a bill. Add your GSTIN and it becomes a tax invoice.'],
  ['Expenses with receipt photos', 'Record rent, parts stock and daily costs, and snap the receipt.'],
  ['Team logins', 'Invite your advisor or manager and choose what each person can do.'],
]

const faqs = [
  ['Do I need a card to start the trial?', `No. Create your garage and use everything free for ${site.trialDays} days.`],
  ['Can my staff use it too?', 'Yes. Invite them from Team logins and pick what each person may see and do. There is no extra charge per user.'],
  ['Does it work without a GSTIN?', 'Yes. Bills print as plain bills until you add your GSTIN in Garage settings.'],
  ['Can I use it on two phones?', 'Yes. Sign in with the same account and your records stay in sync.'],
]

export default function Home() {
  return (
    <>
      <section className="hero sky">
        <div className="hero-top wrap">
          <h1>
            Run your workshop
            <br />
            from your phone
          </h1>
          <div className="hero-side">
            <p>
              Job cards, estimates, GST bills, payments and payroll for independent car garages, in
              one simple app.
            </p>
            <a className="btn btn-light" href="#download">
              Get started
            </a>
          </div>
        </div>

        <div className="hero-stage">
          <div className="chip chip-left">
            <span className="chip-label">Collected today</span>
            <strong>₹56,750</strong>
            <svg className="chip-spark" viewBox="0 0 92 24" aria-hidden="true">
              <polyline
                points="0,20 12,16 24,18 36,10 48,13 60,7 72,9 84,3 92,5"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinejoin="round"
                strokeLinecap="round"
              />
            </svg>
          </div>
          <div className="chip chip-left2">
            <span className="chip-dot" aria-hidden="true" />
            <span>
              <strong>JC-1001</strong>
              <span className="chip-label block">Ready for delivery</span>
            </span>
          </div>
          <HomeScreen />
          <div className="chip chip-right">
            <span className="donut" aria-hidden="true" />
            <span>
              <span className="chip-label block">GST this month</span>
              <strong>18% · 28%</strong>
            </span>
          </div>
        </div>
      </section>

      <section className="statement wrap">
        <div className="orb" aria-hidden="true" />
        <p>
          From the first job card to the final payment, everything your garage does is now in one
          place, and simpler than the register.
        </p>
      </section>

      <section id="features" className="split wrap">
        <div className="split-media sky-soft">
          <JobScreen />
        </div>
        <div className="split-copy">
          <h2>
            Built for the workshop floor.
            <br />
            Ready for tax time.
          </h2>
          <p className="muted">
            {site.appName} follows the way a garage already works: the car comes in, the job is
            opened, the work is billed and the customer pays.
          </p>
          <div className="mini-cards">
            {cards.map(([t, d]) => (
              <div className="mini" key={t}>
                <span className="mini-icon" aria-hidden="true" />
                <h3>{t}</h3>
                <p className="muted">{d}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="split split-rev wrap">
        <div className="split-copy">
          <h2>Billing made simple for every garage</h2>
          <ul className="rows">
            {billing.map(([t, d]) => (
              <li key={t}>
                <strong>{t}</strong>
                <span className="muted">{d}</span>
              </li>
            ))}
          </ul>
        </div>
        <div className="split-media sky-soft">
          <BillScreen />
        </div>
      </section>

      <section id="pricing" className="pricing wrap">
        <h2 className="center">
          Simple pricing for
          <br />
          garages of every size
        </h2>
        <p className="center muted">Every plan includes every feature and all your staff.</p>
        <div className="tiers">
          <div className="tier">
            <p className="tier-name">Free trial</p>
            <p className="tier-price">₹0</p>
            <p className="muted">{site.trialDays} days, no card needed.</p>
            <a className="btn btn-outline" href="#download">
              Start free
            </a>
            <ul className="ticks">
              <li>All features</li>
              <li>Unlimited job cards and bills</li>
              <li>Invite your team</li>
            </ul>
          </div>
          <div className="tier tier-feature">
            <p className="tier-flag">Best value</p>
            <p className="tier-name">Yearly</p>
            <p className="tier-price">
              {rupees(site.prices.yearly)}
              <span>/year</span>
            </p>
            <p>Two months free compared with monthly.</p>
            <a className="btn btn-white" href="#download">
              Choose yearly
            </a>
            <ul className="ticks">
              <li>Everything in the trial</li>
              <li>GST bills and estimates</li>
              <li>Payroll and expenses</li>
              <li>Email support</li>
            </ul>
          </div>
          <div className="tier">
            <p className="tier-name">Monthly</p>
            <p className="tier-price">
              {rupees(site.prices.monthly)}
              <span>/month</span>
            </p>
            <p className="muted">Cancel any time from the app.</p>
            <a className="btn btn-outline" href="#download">
              Choose monthly
            </a>
            <ul className="ticks">
              <li>Everything in the trial</li>
              <li>Pay month by month</li>
              <li>Email support</li>
            </ul>
          </div>
        </div>
        <p className="center muted small">
          Billing by Razorpay. See <Link to="/refunds">cancellation and refunds</Link>.
        </p>
      </section>

      <section className="faq wrap">
        <h2 className="center">Questions garages ask</h2>
        <div className="faq-grid">
          {faqs.map(([q, a]) => (
            <div className="faq-card" key={q}>
              <h3>{q}</h3>
              <p className="muted">{a}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="download" className="final sky">
        <div className="wrap final-inner">
          <h2 className="center">
            Take full control
            <br />
            of your workshop
          </h2>
          <p className="center">
            Free for {site.trialDays} days. Set up your garage in two minutes.
          </p>
          <StoreBadges />
          <div className="final-phone">
            <JobScreen />
          </div>
        </div>
      </section>
    </>
  )
}

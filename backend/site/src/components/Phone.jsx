// Phone mockups showing real NT Garage screens, drawn in HTML so they stay
// sharp at any size and match the app's numbers.

export function Phone({ children, className = '' }) {
  return (
    <div className={`phone ${className}`}>
      <div className="phone-notch" />
      <div className="phone-screen">
        <div className="phone-status">
          <span>9:41</span>
          <span className="phone-status-icons" aria-hidden="true">●●● ▮</span>
        </div>
        {children}
      </div>
    </div>
  )
}

/** The app's home screen: today's money, cars in the workshop, recent bills. */
export function HomeScreen() {
  return (
    <Phone>
      <div className="ps">
        <p className="ps-garage">Demo Auto Works</p>
        <p className="ps-muted">Thu, 08 Oct</p>
        <div className="ps-trial">Trial: 14 days left</div>
        <div className="ps-row2">
          <span className="ps-btn ps-btn-red">+ New job card</span>
          <span className="ps-btn">Quick bill</span>
        </div>
        <div className="ps-card ps-money">
          <div>
            <span className="ps-muted">Collected</span>
            <strong>₹56,750</strong>
          </div>
          <div>
            <span className="ps-muted">Due</span>
            <strong className="ps-amber">₹9,322</strong>
          </div>
        </div>
        <p className="ps-h">In the workshop</p>
        <div className="ps-card ps-list">
          <div>
            <span>
              <b>MH12 AB 1234</b>
              <span className="ps-muted ps-block">Swift · Ravi Kumar</span>
            </span>
            <span className="ps-pill">Ready</span>
          </div>
          <div>
            <span>
              <b>MH14 XY 9999</b>
              <span className="ps-muted ps-block">i20 · Anita Desai</span>
            </span>
            <span className="ps-pill ps-pill-blue">In progress</span>
          </div>
        </div>
        <p className="ps-h">Recent bills</p>
        <div className="ps-card ps-list">
          <div>
            <span>
              <b>Ravi Kumar</b>
              <span className="ps-muted ps-block">INV-2026-1001</span>
            </span>
            <span className="ps-right">
              <b>₹6,980</b>
              <span className="ps-green ps-block">Paid</span>
            </span>
          </div>
        </div>
      </div>
      <TabBar active="Home" />
    </Phone>
  )
}

/** A job card mid-way: status bar, items with their own GST. */
export function JobScreen() {
  return (
    <Phone>
      <div className="ps">
        <p className="ps-title">JC-1001</p>
        <div className="ps-card">
          <div className="ps-between">
            <b>Ready for delivery</b>
            <span className="ps-link">Change</span>
          </div>
          <div className="ps-stages" aria-hidden="true">
            {[0, 1, 2, 3, 4].map((i) => (
              <span key={i} className={i < 4 ? 'on' : ''} />
            ))}
          </div>
          <span className="ps-muted">Step 4 of 5</span>
        </div>
        <div className="ps-card">
          <div className="ps-between">
            <b className="ps-plate">MH12 AB 1234</b>
            <span className="ps-pill">Petrol</span>
          </div>
          <span className="ps-muted ps-block">Maruti Swift · Ravi Kumar · 45,000 km</span>
        </div>
        <p className="ps-h">Parts & labour</p>
        <div className="ps-card ps-list">
          <div>
            <span>
              Tyre 185/65 R15
              <span className="ps-muted ps-block">1 × ₹4,400 · 10% off · GST 28%</span>
            </span>
            <b>₹5,069</b>
          </div>
          <div>
            <span>
              Front brake pads
              <span className="ps-muted ps-block">1 × ₹1,800 · 10% off · GST 18%</span>
            </span>
            <b>₹1,912</b>
          </div>
        </div>
        <span className="ps-btn ps-btn-green ps-wide">Create Bill</span>
      </div>
    </Phone>
  )
}

/** The bill: per-rate CGST/SGST and the total. */
export function BillScreen() {
  return (
    <Phone>
      <div className="ps">
        <p className="ps-title">INV-2026-1001</p>
        <div className="ps-card ps-bill">
          <div className="ps-between">
            <b>Demo Auto Works</b>
            <span className="ps-muted">Tax invoice</span>
          </div>
          <div className="ps-lines">
            <div>
              <span>Tyre 185/65 R15</span>
              <span>₹3,960.00</span>
            </div>
            <div>
              <span>Front brake pads</span>
              <span>₹1,620.00</span>
            </div>
            <div className="ps-muted">
              <span>CGST + SGST 9%</span>
              <span>₹291.60</span>
            </div>
            <div className="ps-muted">
              <span>CGST + SGST 14%</span>
              <span>₹1,108.80</span>
            </div>
          </div>
          <div className="ps-between ps-total">
            <span>Total</span>
            <span>₹6,980.40</span>
          </div>
        </div>
        <div className="ps-card ps-paid">
          <span className="ps-check" aria-hidden="true">✓</span>
          <span>
            <b>Payment received</b>
            <span className="ps-muted ps-block">₹6,980.40 by UPI</span>
          </span>
        </div>
      </div>
    </Phone>
  )
}

function TabBar({ active }) {
  return (
    <div className="ps-tabs" aria-hidden="true">
      {['Home', 'Jobs', 'Clients', 'Bills', 'More'].map((t) => (
        <span key={t} className={t === active ? 'on' : ''}>
          {t}
        </span>
      ))}
    </div>
  )
}

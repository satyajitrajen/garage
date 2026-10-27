# Reply to App Review — Guideline 2.1 Information Needed (iOS 1.0)

Paste the answers below into the App Review reply and into App Review
Information → Notes. Attach the screen recording (item 1) to the reply.

---

**1. Screen recording**
Attached: recorded on a physical iPhone running the latest iOS. It shows app
launch, sign up, sign in, the main workshop flow (job card → GST bill →
payment), the Subscription screen with both plans, prices, Terms of Use and
Privacy Policy links, and account deletion from More → Account.

**2. Purpose and audience**
NT Garage is workshop management software for independent car repair garages
in India. Garage owners and their staff use it to replace paper job cards,
bill books and salary registers: they record vehicles that come in, track the
work, issue GST tax invoices, record payments, log expenses, and run staff
attendance and payroll. It saves owners time on paperwork and shows what each
customer still owes.

**3. How to access the main features**
Sign in with the demo owner account in App Review Information:
appreview@nexorytechnologies.com (password in the Sign-In Information field).
The demo garage "Demo Auto Works" has sample data.
- Home: vehicles in the workshop, today's collections and dues
- New job card (Home) → add parts and labour → Create Bill → GST invoice
- Bills tab: invoices and payments; Clients tab: customers and vehicles
- More: price list, estimates, expenses, staff, attendance and payroll,
  garage settings
- More → Account: Profile, Subscription, Team logins, Sign out, Delete account
New users create an account with "Create an account" on the sign-in screen;
no sample files are needed.

**4. External services**
- Our own backend at https://garage.nexorytechnologies.com (account sign-in
  and all workshop data)
- Apple In-App Purchase and the App Store Server API (subscriptions on iOS)
- Firebase Cloud Messaging (subscription status notifications)
- Email delivery for password reset messages
No AI services and no third-party data providers. Android and web customers
pay through Razorpay; that is not used or linked in the iOS app.

**5. Regional differences**
The app is available in India only. Invoices follow Indian GST rules (CGST /
SGST, GSTIN) and use rupees and UPI payment QR codes. Features are the same
for every user.

**6. Regulated industry / third-party material**
Not applicable. The app is business record-keeping software; it does not
provide financial, medical or legal services and contains no protected
third-party content.

**7. In-App Purchase**
New garages get a 14-day free trial. After that, owners can subscribe to
"Garage Pro Monthly" (₹499 / month) or "Garage Pro Yearly" (₹4,999 / year),
auto-renewable subscriptions in the "Garage Pro" group that keep full access
to adding and editing records. Path: Home → trial banner, or More → Account →
Subscription. The screen shows each plan's title, length and price, Restore
purchases, the auto-renewal terms, and links to the Terms of Use and Privacy
Policy.

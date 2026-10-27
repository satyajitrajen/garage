# Google Play listing — NT Garage

Character limits are Google Play's. The App Store version is in [app-store-listing.md](app-store-listing.md).

## App details

| Field | Value |
|---|---|
| Package name | com.nexory.garage |
| App name (30) | NT Garage: Workshop Manager |
| Category | Business |
| Tags | Business management, Invoicing, Productivity |
| Contact email | support address for garage.nexorytechnologies.com |
| Website | https://garage.nexorytechnologies.com/ |
| Privacy policy | https://garage.nexorytechnologies.com/privacy |
| Content rating | Everyone (IARC questionnaire: business tool, no user-to-user content, no ads) |
| Target audience | 18+ (not designed for children) |
| Ads | No ads |

## Main store listing

**Short description (80)**

Job cards, GST bills, payments and staff payroll for your car garage.

**Full description (4000)**

NT Garage is workshop management built for independent car garages in India. Replace paper job cards, bill books and salary registers with one app your whole team can use.

🔧 JOB CARDS
• Create a job card in seconds: vehicle, owner, odometer, fuel level and complaints
• Run an inspection checklist and track every job from Received to Delivered
• Add parts and labour as you work and see the running total
• See every vehicle in the workshop and what is due today

🧾 GST BILLS AND PAYMENTS
• Turn a job card into a GST tax invoice with CGST/SGST, your GSTIN and the customer's
• Share bills on WhatsApp, SMS or any app
• Print a UPI QR code on every bill so customers can pay instantly
• Record full or partial payments and see what each customer still owes
• Quick bills for walk-in work, and estimates that convert to bills

🚗 CUSTOMERS AND VEHICLES
• Customer and vehicle history in one place
• Search by number plate, phone or name

🔩 SPARE PARTS AND PRICE LIST
• Keep your parts and labour rates ready to add to any job

💸 EXPENSES
• Log rent, electricity, parts purchases and daily spends by category
• See this month's and today's spending at a glance

👷 STAFF, ATTENDANCE AND PAYROLL
• Mark attendance for your mechanics
• Record salary advances and generate a monthly payslip
• Give each team member their own login with the right permissions

FREE 14-DAY TRIAL
Register your garage and use every feature free for 14 days. After the trial, continue with Garage Pro Monthly or Yearly.

Made in India by Nexory Technologies.

**Release notes (500)**

First release of NT Garage on Google Play.

## Graphics

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | Export from the launcher icon |
| Feature graphic | 1024×500 JPG/PNG | Not yet made |
| Phone screenshots | 2–8, 9:16, min 1080 px short side | Reuse the iPhone set in `docs/screenshots/app-store/iphone/` (crop or re-export to 9:16) |
| 7" / 10" tablet screenshots | Optional | Can reuse the iPad set |

## App content (policy declarations)

- **Privacy policy:** URL above.
- **App access:** login required. Give reviewers a demo owner account (email + password) with sample data, plus the note: "Sign in with the demo owner account. Subscriptions are on More → Subscription."
- **Ads:** none.
- **Account deletion:** in-app at More → Delete account. Google also requires a **web link** where users can request deletion without the app; add a page such as `garage.nexorytechnologies.com/delete-account` and enter it.
- **Government / financial / health features:** none. It issues invoices but is not a financial service.
- **News app:** no.

### Data safety

Collected, linked to the user, encrypted in transit, can be deleted on request, not shared, not used for ads:

| Data type | Purpose |
|---|---|
| Name, email address, phone number | App functionality, account management |
| User content: customer, vehicle, invoice and expense records; photos (if uploaded) | App functionality |
| User IDs | App functionality, account management |
| Device or other IDs (push token, via Firebase Cloud Messaging) | App functionality (subscription notifications) |
| Purchase history | App functionality |

No data is shared with third parties for advertising. Payment details are entered on the payment provider's page and are not collected by the app.

## Payments on Android

Garage Pro Monthly/Yearly are paid through Razorpay on Android. iOS uses Apple in-app purchase.

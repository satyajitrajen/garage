# UI/UX Guidelines & Validation Reference

Review guide for the NT Garage app (`lib/`). Any agent reviewing UI work should
check changes against **every** section below; the final section is a
copy-paste review checklist. Values are extracted from the code
(`lib/theme/`, `lib/utils/`, `lib/widgets/`) plus the backend contract
(`backend/README.md`) — not invented.

---

## 1. Design language in one paragraph

Workshop-first, low-noise Material app: flat white cards on a warm grey
background, 1px borders instead of shadows, Poppins everywhere, brand red
**reserved for actions only**, status communicated by muted colour-coded
badges, and every list has an actionable empty state. Screens are
single-column, thumb-reachable, with primary action pinned at the bottom.

---

## 2. Colour system (`lib/theme/app_palette.dart`)

All screens read colours from `context.palette` (a ThemeExtension) — **never
hard-code a colour** in a screen or widget.

### Base tokens

| Token | Value | Usage |
|---|---|---|
| `background` | `#F5F4F4` | Scaffold background |
| `card` / `surface` | `#FFFFFF` | Cards, sheets |
| `cardAlt` | `#F8F8F8` | Alt tiles, inputs |
| `textPrimary` | `#171717` | Headings, key figures |
| `textSecondary` | `#656565` | Body copy |
| `textMuted` | `#989898` | Placeholders, disabled |
| `border` / `divider` | `#E8E8E8` / `#EEEEEE` | Card outlines, separators |
| `primary` | `#F01018` | **Brand red — actions only** |
| `primaryLight` | `#FFF0F1` | Icon circles in empty states |
| `accent` | `#171717` | Near-black (chips, selected nav, info snackbars) |
| `onPrimary` | `#FFFFFF` | Text on red/black fills |

**Colour-usage ratio rule:** brand red is for buttons/tappable actions. Never
use red for informational banners, badges or snackbars — info is `accent`
(near-black), success is `paid` green, error is `absent` red `#DC2626` (only
for actual errors).

### Status colours (semantic, reused everywhere)

| Meaning | Token | Hex | Seen on |
|---|---|---|---|
| Success / paid / done | `paid`, `ready`, `delivered`, `present` | `#25A75B` | PAID badge, Delivered chip, attendance P |
| Warning / pending / half | `partial`, `pending`, `halfDay` | `#F59E0B` | PARTIAL badge, Waiting parts, Balance due |
| Info / active | `inProgress` | `#2563EB` | In Progress job status |
| Neutral | `received`, `leave`, `cancelled` | `#656565` / `#989898` | Received chip, Cancelled |
| Danger | `absent` | `#DC2626` | Absent, error snackbars |

Expense categories deliberately share one muted colour (`#656565`) — they are
differentiated by icon + label, not colour. Keep it that way.

---

## 3. Typography (`lib/theme/app_text.dart`)

Font: **Poppins** via `GoogleFonts.poppins` (all text, no exceptions).

| Token | px | Use for |
|---|---|---|
| `micro` | 10 | badges, overlines, flag chips |
| `label` | 12 | tile labels, list subtitles, captions |
| `caption` | 13 | secondary body |
| `body` | 14 | primary body |
| `subtitle` | 15.5 | emphasized subtitles, stat values |
| `title` | 17 | section/card titles, screen headlines |
| `headline` | 20 | big figures, screen headlines |
| `display` | 26 | hero figures only (money cards) |

Rules: every `fontSize:` must be an `AppText` token (10px floor on purpose).
Weights: w700 titles, w600 buttons/primary labels, w500 secondary emphasis,
w400 body. Amounts render at `subtitle`/`headline`/`display` in `textPrimary`
with `₹` from the formatter (never a bare number).

---

## 4. Spacing, radii, elevation (`lib/theme/app_dimens.dart`)

- Screen/card padding: **16** (`paddingScreen`, `paddingCard`).
- Radii: card/tile/input/button **12**, badge 8, FAB 16, sheet 24.
- **Cards are flat**: `cardShadow()`/`accentGlow()` return empty lists on
  purpose — separation comes from the 1px `border` colour. Do not add shadows
  back without a design decision.
- Sheets are rounded top 24; dialogs default Material shape.

---

## 5. Core component patterns (`lib/widgets/`)

### Status badges (`status_badge.dart`)
- One quiet style: colour at **10% alpha** fill, coloured sentence-case text,
  `AppText.label`, w500, radius 6, no icon/border.
- Factories exist per domain — reuse them: `fromInvoiceStatus` (PAID /
  PARTIAL / PENDING / CANCELLED), `fromJobStatus` (7 states),
  `fromQuotationStatus` (DRAFT / SENT / APPROVED / CONVERTED / DECLINED),
  `fromAttendanceStatus` (compact P / HD / A / L).
- Invoice/quotation labels display in **sentence case** ("In progress");
  attendance codes stay uppercase.

### Empty states (`empty_state_widget.dart`)
Circle `primaryLight` 24dp padding + 54px `primary` icon → w700 `title` →
`body` description (height 1.4) → optional red elevated CTA with a plus icon.
Every list screen (customers, jobs, bills, estimates, expenses, staff, price
list) must have one with an action. Search-miss reuses it with the term
interpolated: `No results found for "term"`.

### Snackbars (`app_snack_bar.dart`)
`showAppSnackBar(context, msg, type:)` — success `paid` green, error `absent`
red, info near-black. Floating, radius 12, **2s** for success/info, **4s +
close icon** for errors. Replaces the current snackbar instead of queueing.
All mutation feedback goes through this — no raw `ScaffoldMessenger` calls.

### Destructive confirmations
Pattern (see `customer_detail_screen.dart`): AlertDialog titled
`Delete Customer?`, body names the record **and the cascade** ("This will
also remove their registered fleet."), Cancel in red text + destructive
button in **amber/yellow** (not red). Same pattern for vehicles, expenses,
catalog items, staff.

### Buttons
- Primary: `primary` red fill, white text, radius 12, full-width at screen
  bottom (e.g. "Create & Issue Job Card", "Save & Start Job Card",
  "Generate Invoice & Bill Customer" — the last one is green `paid` because
  it is a money-positive action).
- Secondary: white fill, 1px border, dark text ("Quick bill",
  "Save Customer Only", "Create Estimate").
- Double-submit latch: forms use `_isSaving` to disable the button; keep it
  on any new create/edit form.

### Search
`search_bar_widget.dart`: rounded field, muted placeholder
("Search by name, phone, or vehicle plate..."), client-side filter across
name + phone + plate. Dashboard search covers plate/phone/name.

### Bottom navigation
5 tabs: Home / Jobs / Clients / Bills / More. Selected pill = `accent` black
with white icon+label; inactive = `textSecondary`. Wrapped in SafeArea —
never let content collide with the gesture bar.

### Permission gating (`permission_gate.dart`)
Every write action (buttons, menu items) must be wrapped so staff without the
permission never sees it: `customers.manage`, `vehicles.manage`,
`jobcards.manage`, `quotations.manage`, `invoices.manage`,
`payments.record`, `expenses.manage`, `staff.manage`, `attendance.manage`,
`advances.manage`, `settings.manage`. Owners bypass all checks; new staff get
everything except expenses/staff/advances/settings by default.

### Error-message fallback
Staff-only mutations surface the server's message via `errorMessage(e)`;
non-API failures (network/timeout) fall back to a screen-specific generic
retry line (e.g. add-staff: `Failed to save staff. Please try again.`).

### Subscription gate (`subscription_banner.dart` + 402)
Reads always work; writes return **402 payment_required** when trial expired
or garage suspended. UX: orange banner "Trial: N days left." on dashboard →
Subscription screen; API 402s must surface as an error snackbar, never a
crash.

---

## 6. Money, GST & date formatting (`lib/utils/`)

- **Currency:** `CurrencyFormatter.format` — `en_IN`, `₹` symbol, **0
  decimals** by default, `showDecimals: true` for 2 (payment entry, unit
  rates). `formatCompact` → `₹1.2L` (≥1,00,000), `₹1.5k` (≥1,000).
- **Invoice math** (`lib/models/invoice.dart`, mirrored by Go
  `models/money.go`):
  - `taxable = max(gross − discount, 0)`
  - per-item tax: `tax = Σ item taxable × item rate%`; document discount is
    spread **pro-rata** across lines.
  - legacy (non per-item): `tax = taxable × document rate%`.
  - `grandTotal = taxable + tax`; **CGST = SGST = tax / 2** (intra-state
    split, e.g. 18% → "CGST (9%)" + "SGST (9%)" via `gstLines`).
  - `balanceDue = max(grand − paid, 0)`; cancelled invoices show 0 due.
- **Status classification:** paid ≥ grand → PAID; 0 < paid < grand → PARTIAL;
  paid == 0 → PENDING (cancelled overrides).
- **Dates:** `AppDateFormatter` — `dd MMM yyyy` full, `dd MMM` short, weekday
  headings on dashboard ("Sat, 10 Oct"). Expense dates are `YYYY-MM-DD`
  strings; job-card promised times render "08 Oct 2026, 06:56 AM".
- **Quantity:** `quantity_formatter` renders integers bare ("2") and
  fractions without trailing zeros ("2.5", never "2.50" / "1.0").

---

## 7. Validation catalog

Client-side validators show the exact strings below (red error text under the
field, shown on submit). Server errors arrive as
`{"error":{"code","message"}}` and surface through `errorMessage()` as a
snackbar with the first letter capitalised.

### Auth
| Field | Rule | Message |
|---|---|---|
| Email | required | `Email is required` |
| Email | contains `@` (shared validator `auth_validators.dart`) | `Enter a valid email` |
| Password | ≥ 8 chars (server-enforced too) | `Minimum 8 characters` |
| GSTIN (settings) | 15 chars | `Enter a valid 15-character GSTIN` |

### Customer / vehicle (`add_customer_screen.dart`)
| Field | Rule | Message |
|---|---|---|
| Full name | required | `Mobile number is required`-style inline errors; name: required |
| Mobile | required | `Mobile number is required` |
| Vehicle reg. no. | required when "Add vehicle" toggle is ON | `Registration number is required` |
| KM reading | required, integer ≥ 0 | `KM is required` / `Enter a valid KM reading` |
| Make / Model | required when vehicle ON | inline required |
| Duplicate plate | server 409 | "a vehicle with this registration number already exists" |
| Delete customer | blocked by server 409 with dues/history | snackbar `Cannot delete X — customer still has outstanding dues` |

### Job card (`create_job_card_screen.dart`)
| Rule | Message |
|---|---|
| ≥ 1 complaint | `Please add at least one customer complaint or service requirement` |
| KM required, ≥ 0 | `KM is required` / `Enter a valid KM reading` |
| Item needs name + price | `Please enter item name and price` |
| Delivered/cancelled job | item edits locked (`Edit items` hidden/disabled) |
| Doc number collision | server 409 conflict |

### Quotation / estimate
| Rule | Message |
|---|---|
| ≥ 1 item to bill | `Please add at least one work item or spare part` |
| `converted` status | only reachable from `approved` (server 422) |
| Validity days | range picker `Enter $min–$max` (default options 7/15/30) |

### Invoice & payment (`create_invoice_screen.dart`, `payment_collection_screen.dart`)
| Rule | Message |
|---|---|
| Invoice from JC with no items | `Add at least one work item before invoicing this job card` |
| Quick bill with no items | `Please add at least one item or labour charge to generate bill` |
| Payment amount | > 0, ≤ balance due + 0.01 (server 422) |
| Payment modes | cash / upi / card / bankTransfer / cheque / other |
| Cancel invoice | only when **unpaid** and not cancelled (server 422) |
| Doc number | `INV-YYYY-####`, immutable after create |

### Expenses (`add_expense_screen.dart`)
| Rule | Message |
|---|---|
| Title | required (server: "title is required") |
| Amount | `Enter amount` / `Invalid amount` (> 0) |
| Category | fixed enum (rent, electricityUtilities, internetPhone, toolsEquipment, consumables, partsStock, staffFood, fuelGenerator, miscellaneous) |
| Date | `YYYY-MM-DD`, defaults today |

### Staff / attendance / advances
| Rule | Message |
|---|---|
| Name + phone | required (server: "name and phone are required") |
| Role enum | headMechanic, seniorTechnician, autoElectrician, denterPainter, helperTrainee, serviceAdvisor, manager |
| Salary | `Enter salary` / `Invalid salary amount` (> 0) |
| Attendance | upsert per (staff, day): present / halfDay / absent / leave |
| Advance | `Please enter a valid advance amount` (> 0) |

### Server error envelope (map to snackbar, never raw dump)
`invalid_request` 400 · `unauthorized` 401 · `forbidden` 403 · `not_found`
404 · `method_not_allowed` 405 · `conflict` 409 · `unprocessable` 422 ·
`internal` 500 · **`payment_required` 402** (subscription gate) · 429
rate-limit. Every mutation path must catch and show `errorMessage(e)`.

---

## 8. Flow & state conventions

1. **After any mutation:** success snackbar with the entity name/number
   ("Customer Ravi Kumar added successfully!", "Job Card JC-1001 created
   successfully!"), then navigate (pop or push detail). Failures keep the
   user on the form with an error snackbar.
2. **Doc numbers:** client-generated sequences JC-####, EST-####, INV-YYYY-####;
   the dashboard/preview show them verbatim; never editable after create.
3. **Status transitions** always go through dedicated endpoints/commands
   (job status chips, quotation status stepper) and stamp `completedAt` on
   `delivered`.
4. **Locked records:** delivered/cancelled job cards hide edit affordances;
   invoiced job cards show "View Invoice #INV-…" instead of "Generate".
5. **Trial/billing surface:** orange trial banner on dashboard links to the
   Subscription screen; manual (non-Razorpay) mode shows instructions instead
   of a checkout.
6. **Dual paths:** mock mode (`USE_MOCK=true`) must stay visually identical —
   no debug text, no layout differences.

---

## 9. Known quirks (do not "fix" silently — flag first)

These were observed during emulator testing and are intentional or accepted:

- **Keyboard overlays forms** on Add Customer / Job Card / Add Expense
  (`resizeToAvoidBottomInset` effectively unused there): the keyboard covers
  the lower half instead of resizing. The register/login screens DO resize.
  Any new screen should pick one behaviour deliberately; bottom action
  buttons must remain reachable (scroll).
- Item/custom-item dialogs are bottom sheets with their own scroll; field
  positions shift while typing — dialogs keep their own scroll controller.
- Go emits integral floats without a decimal point (`taxPercent: 18`); Dart
  `fromJson` must use `(x as num).toDouble()` — never `as double`.
- Expense-category colours are intentionally uniform grey.

---

## 10. Review checklist (run per screen)

- [ ] No hard-coded colours, font sizes, paddings, or radii — tokens only.
- [ ] Brand red used **only** for actions; info = black, success = green,
      warning = amber, error = `#DC2626`.
- [ ] All text via `GoogleFonts.poppins` + `AppText` token; no font < 10.
- [ ] Cards flat with `border`; no ad-hoc shadows.
- [ ] Statuses rendered via `StatusBadge` factories, sentence case.
- [ ] List screens have an `EmptyStateWidget` with a working CTA.
- [ ] Every mutation: loading latch (`_isSaving`), success/error snackbar,
      error text via `errorMessage()`.
- [ ] Destructive actions: confirm dialog naming the record + cascade,
      amber Delete button.
- [ ] Write actions permission-gated (`PermissionGate`) and 402-safe.
- [ ] Money via `CurrencyFormatter`; GST lines via `gstLines` (CGST/SGST
      split); totals match `Invoice` getters.
- [ ] Validators present with the exact messages from §7; numeric fields use
      `TextInputType.numberWithOptions(decimal: …)`.
- [ ] Keyboard behaviour deliberate; primary actions reachable while typing.
- [ ] Screen reachable from bottom nav / More menu; back behaviour sane.
- [ ] Works in both API and mock mode; no debug leftovers.

---

*Maintainer note: update this file when `AppPalette`, `AppText`,
`AppDimens`, or any validation message changes — the doc is the review
source of truth.*

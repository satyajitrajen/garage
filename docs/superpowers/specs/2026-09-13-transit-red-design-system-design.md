# Transit Red Design System — Design Spec

**Date:** 2026-09-13
**Status:** Approved (user confirmed light-only, re-skin + hero screens, amber pending)
**Reference:** Premium travel-booking design system (user-provided image + token document)

## 1. Goal

Re-skin the garage app from the sky-blue AppPalette system to the "Transit Red" system: red `#F01018` used only for brand and important actions, white surfaces on a light-gray background, near-black text, Inter typography, 8/12/16/24 radii, hairline borders, near-invisible shadows. Light-only. Plus two hero surfaces: a dashboard "Book a Service" card (travel-search-card analog) and an invoice preview restyled as an e-ticket with a real QR code.

## 2. Approach (approved)

Recolor `AppPalette` in place and strip dark mode (Approach A). The UI is palette-driven (69 `context.palette` sites + ThemeData), so screens recolor automatically. No layout changes outside the two hero surfaces. The reference's 22-component catalog is NOT built; its ideas are adopted selectively in the heroes.

## 3. Color tokens — `AppPalette` (single light instance)

AppPalette keeps its 42-slot API. New values (light only):

| Slot | New value | Note |
|---|---|---|
| background | `0xFFF5F4F4` | app background |
| surface | `0xFFFFFFFF` | nav, sheets, dialogs |
| card | `0xFFFFFFFF` | cards |
| cardAlt | `0xFFF8F8F8` | inputs, info blocks |
| textPrimary | `0xFF171717` | |
| textSecondary | `0xFF656565` | |
| textMuted | `0xFF989898` | labels, helpers |
| border | `0xFFE8E8E8` | |
| divider | `0xFFEEEEEE` | |
| primary | `0xFFF01018` | CTA, selected states, prices |
| primaryDark | `0xFFD90E16` | pressed/hover |
| primaryLight | `0xFFFFF0F1` | soft selected backgrounds |
| accent | `0xFFF01018` | same as primary in this system |
| onPrimary | `0xFFFFFFFF` | |
| paid | `0xFF25A75B` | success green per reference |
| partial | `0xFFF59E0B` | amber (money owed family) |
| pending | `0xFFF59E0B` | amber — user decision, avoids brand-red collision |
| inProgress | `0xFFF59E0B` | amber |
| received | `0xFF656565` | neutral gray (new job) |
| ready | `0xFF25A75B` | light green |
| delivered | `0xFF25A75B` | green |
| cancelled | `0xFF989898` | gray |
| present | `0xFF25A75B` | attendance |
| halfDay | `0xFFF59E0B` | |
| absent | `0xFFEF4444` | operational alert red (distinct from brand red by context) |
| leave | `0xFF989898` | |
| badgeRedBg / badgeRedIcon | `0xFFFFF0F1` / `0xFFF01018` | primarySoft + primary |
| badgeOrangeBg / badgeOrangeIcon | `0xFFFEF3E2` / `0xFFB45309` | amber soft / amber dark |
| badgePurpleBg / badgePurpleIcon | `0xFFF3E8FF` / `0xFF7E22CE` | muted purple kept for category variety |
| badgeGreenBg / badgeGreenIcon | `0xFFE7F6EE` / `0xFF1E7E46` | |
| badgeBlueBg / badgeBlueIcon | `0xFFE8F1FD` / `0xFF1D4ED8` | |
| paperBg | `0xFFFFFFFF` | invoice ticket body |
| paperHeaderBg | `0xFFF8F8F8` | ticket header band |
| bannerGradient | `0xFF1A1A1A → 0xFF111111` | BLACK banner, white text, red accents (approved) |
| cardGradient | `0xFFFFFFFF → 0xFFF8F8F8` | subtle white card wash |
| **blueGradient → renamed `brandGradient`** | `0xFFF01018 → 0xFFD90E16` | payment-collection highlight card; the "10% red" |
| categoryColors | remap onto the muted badge palette (red→primary, orange→amber, green→green, blue→blue, purple→purple) | same map shape |

Dark instance: **deleted**. `AppPalette.light` stays the single instance name; all references to `AppPalette.dark` are removed with it.

## 4. Shape & elevation — `AppDimens`

| Token | Old | New |
|---|---|---|
| radiusBadge | 12 | **8** |
| radiusInput | 14 | **12** |
| radiusButton | 16 | **12** |
| radiusTile | 16 | **12** |
| radiusCard | 20 | **16** |
| radiusFAB | 18 | **16** |
| radiusSheet | 24 | 24 (unchanged) |

Shadows: `cardShadow` → `0 2 8` blur 8, alpha **0.035**; `accentGlow` → blur 24, alpha 0.06 (large-panel spec). Nav glow switches to `accentGlow(palette.primary)`.

## 5. Typography

- **Inter** replaces Poppins at all ~405 `GoogleFonts.poppins` sites (mechanical sweep) and as ThemeData `fontFamily`.
- ThemeData textTheme adopts the reference scale where the app has counterparts: Display 28/700, H1 24/700, H2 20/700, H3 17/600, Body 14/400, Label 12/500, Caption 11/400.
- Per-site sizes stay as-is except: dashboard greeting/title moves to the Display/H1 scale.
- Prices and money accents render in `palette.primary` where the design calls for it (list-card price labels) — restrained: only standout amounts, not every number.

## 6. Dark-mode removal (light-only)

1. `app_theme.dart`: delete dark `ThemeData`; light theme becomes the only theme; component themes (buttons, chips, inputs, dialogs, bottom nav, tabs) updated to the new tokens (primary button: red bg/white text/12 radius; outlined: white bg, `#E2E2E2` border, `#252525` text; bottom nav active `#F01018`, inactive `#8B8B8B`, 10px/500 labels).
2. `main.dart`: drop `darkTheme` and any `ThemeMode` state; register light theme only.
3. More-menu: remove the theme-toggle row.
4. Baseline widgets (`search_bar_widget.dart`, `gradient_button.dart`, `empty_state_widget.dart`): strip remaining `isDark` branches, adopt palette tokens.
5. `lib/theme/app_colors.dart`: after (1)–(4) no references should remain — `git rm` it. If any survive, list them instead of deleting.
6. Stale "deliberate … both themes" literal comments (dashboard bolt chip, more-menu bolt chip) are resolved: bolt chips become `palette.primary` fills with white icons; comments removed. IND flag literal in vehicle_selection stays (comment retained).

## 7. Hero 1 — Dashboard "Book a Service" card

New widget `lib/widgets/book_service_card.dart`, placed on the dashboard beneath the profile banner (above quick actions):

- **Customer row** (`From` analog): label 'Customer' 11px gray, value 15px/600 dark, red dot indicator; tap → existing customer selection flow.
- **Vehicle row** (`To` analog): same styling; tap → `VehicleSelectionScreen` scoped to selected customer.
- **Two-column pill row** (`Date/Passengers` analog): date pill (label + value + calendar icon, tap → date picker) and odometer pill (label + km value + icon, numeric input).
- **Service-type chips** (class selector analog): Quick Service / Full Service / Repair — 36px, radius 8, selected red bg + white text, unselected white + `#DDDDDD` border + `#292929` text.
- **CTA**: full-width red button `Start Service` (48–52px, radius 12, 14/600) → opens Quick Service Wizard with the selected customer/vehicle/date pre-filled.
- State is card-local; rows open existing flows — **no new data paths**. Wizard gains optional `initialCustomer`/`initialVehicle` params (null-safe, default null = current behavior).

## 8. Hero 2 — Invoice preview as e-ticket

`invoice_preview_screen.dart` restyled (structure per reference §11–15):

1. Brand header band (`paperHeaderBg`): garage name + tagline from `GarageProfile`.
2. Confirmation indicator: 36px circle outline with red check; label 'Booking Confirmed' analog → invoice status ('Payment Settled' when paid, 'Awaiting Payment' otherwise, 'Cancelled' state keeps existing banner).
3. PNR analog: muted pill (`#F7F7F7` cardAlt, 34px, radius 8) showing invoice number.
4. **QR code** via new dependency `qr_flutter`: white container 140px, padding 12, radius 8. Content: **UPI intent string** `upi://pay?pa=<profile.upiId>&pn=<profile.name>&am=<balanceDue>&cu=INR` when balance due > 0; otherwise the invoice number string.
5. Three-column summary (journey-summary analog): Issue date | Invoice total | Due date — center column smaller.
6. Info row (passenger-row analog): Customer | Vehicle | Paid-so-far labels 10–11px gray, values 12–13px/600 dark.
7. Primary action row: red `Record Payment` (unpaid) / share button — existing logic untouched.

## 9. Out of scope (YAGNI)

Full 22-component catalog; per-site type-scale adoption; animations; dark-mode resurrection; layout changes to list/detail screens beyond token re-skin.

## 10. Testing & verification

- Existing 22 tests stay green; `flutter analyze` clean at every commit.
- New: widget smoke test — Book-a-Service card renders with chips + CTA; invoice preview renders QR container + PNR pill.
- Final grep sweep: zero `Color(0x` in screens/widgets except IND flag; zero `isDark`/`AppColors`/`GoogleFonts.poppins` in lib; `'Nexory'` only in main.dart title + seed.
- Manual Windows visual pass remains the user's step (run commands are classifier-blocked for the agent).

## 11. Dependencies

- ADD `qr_flutter` (pure-Dart QR renderer) — approved with the design.

## 12. Risks

- Palette revalue touches dark-instance consumers (theme toggle, `Theme.of(context)` dark lookups) — handled atomically in the theme-core task so every commit compiles.
- 405-site font sweep is mechanical but wide; verified by analyze + tests + grep for zero `poppins` remnants.

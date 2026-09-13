# Type Scale + Home Restructure Design

Date: 2026-09-13
Status: Approved (user chose "Token scale + bump" for fonts and "Full restructure, Approach A" for home)
Predecessor: 2026-09-13-transit-red-design-system-design.md (palette/radii/typography foundation — unchanged)

## 1. Problem

1. **Fonts read small.** The Poppins→Inter sweep kept the pixel sizes that were tuned for Poppins, which renders visibly larger than Inter at the same px. ~380 hardcoded `fontSize:` literals exist in `lib/screens/**` and `lib/widgets/**`: the bulk sits at 11–13.5px and a tail at 8–10.5px, so body text and labels feel cramped.
2. **Home is heavy and redundant.** The dashboard stacks a black bento island (status pill + 2×2 KPI grid + red Quick Service banner), a Book-a-Service card, a quick-actions chip carousel, a tall bay-activity list, 6 module tiles, a full revenue bar chart, and 3 recent bills. The black island dominates, KPIs/banners/quick-actions repeat each other's jobs, and the chart pushes real content below the fold.

## 2. Goals / Non-goals

Goals: one named type scale used everywhere with a raised floor (no size ever shrinks); a booking-first, glanceable home with no black block.
Non-goals: weight or line-height changes; new data/flows; changes to non-home screens beyond the mechanical size remap; the 6 module tiles' destinations; dark mode (deleted); per-site typography redesign.

## 3. Type scale (all screens)

New class in `lib/theme/app_text.dart`:

```dart
class AppText {
  static const double micro = 10;    // badges, overlines, flag chips
  static const double label = 12;    // tile labels, list subtitles, small captions
  static const double caption = 13;  // secondary body
  static const double body = 14;     // primary body
  static const double subtitle = 15.5;
  static const double title = 17;    // section/card titles
  static const double headline = 20; // screen headlines, big figures
  static const double display = 26;  // hero figures only
}
```

Remap rule (nearest token, monotonic — nothing shrinks):

| Old fontSize | New token |
|---|---|
| 8, 9, 10, 10.5 | micro (10) |
| 11, 11.5, 12 | label (12) |
| 12.5, 13 | caption (13) |
| 13.5, 14 | body (14) |
| 14.5, 15 | subtitle (15.5) |
| 16, 16.5, 17, 18 | title (17) |
| 19, 20, 22 | headline (20) |
| 24, 28, 32 | display (26) |

- Every `fontSize: <literal>` in `lib/` becomes `fontSize: AppText.<token>`. Weights, `letterSpacing`, and `height` stay exactly as they are.
- `app_theme.dart`'s `textTheme` slots realign to the same numbers: headlineLarge 26, headlineMedium 20, titleLarge 17, titleMedium 14, titleSmall 13, bodyLarge 14, bodyMedium 13, bodySmall 12, labelLarge 13, labelMedium 12, labelSmall 10 (colors/weights unchanged). AppBar `titleTextStyle` stays 17.
- Import added per touched file (`../theme/app_text.dart` or `../../theme/app_text.dart` matching the file's depth, mirroring its existing theme import).
- Deliberate exceptions (literals stay): `app_text.dart` itself and `app_theme.dart`'s textTheme copyWith sizes. Test files are outside `lib/` and untouched.
- Verification gate: `grep -rn "fontSize: [0-9]" lib/` → matches only in `app_text.dart` and `app_theme.dart`. Overflow regressions surface via `flutter test` (text-rendering overflow throws in widget tests).

## 4. Home restructure (dashboard_screen.dart)

AppBar (red car chip + garage name + date) stays. New body order:

1. **Book a Service** — the existing `BookServiceCard`, unchanged, first card under the AppBar.
2. **Today card** (new section, replaces bento island + KPI grid + quick-action chips + revenue chart): white surface card, `radiusCard`, border + `cardShadow`. Header row: 'Today' (title) + 'Collection' figure (paid green) and 'Expenses' figure (amber) side by side; a 7-day collections sparkline (fl_chart `LineChart`, reusing the weekly series computation from the deleted `_buildWeeklyRevenueExpenseChart`) spans the card's lower half; a tappable pending line at the bottom — '₹X due across N bills' in amber with a chevron → InvoicesListScreen. When the 7-day series is all zeros the sparkline area collapses (no empty-axis chart).
3. **Live floor** (replaces the bay-activity vertical list and the GARAGE STATUS pill): `SectionHeader` 'Live Floor' with count in the action slot; horizontal `SingleChildScrollView` of compact cards, one per active job card: registration number (bold), model, `StatusBadge.fromJobCardStatus`; card tap → that job card's detail screen. Empty state: one slim 'All clear — no vehicles in workshop' card.
4. **Workshop modules** — the 6 tiles keep their destinations and grid, restyled lighter (surface tiles + border, no per-tile shadows).
5. **Recent Collections & Bills** — unchanged behavior (3 items + 'All Invoices'); only font tokens change.

**Deleted entirely:** bento island container + status pill + 2×2 KPI grid, quick-actions carousel (`_buildQuickActionChip` and its five call sites), `_buildWeeklyRevenueExpenseChart` (logic moves into the Today card's sparkline), old bay-activity section. The dashboard file shrinks from ~1180 lines to roughly 700. Data comes only from existing provider getters (`todayCollection`, `todayExpenses`, `totalPendingPayments`, unpaid-invoice count, `activeJobCards`, `getVehicleById`/`getCustomerById`, weekly totals recomputation).

## 5. Testing

- `flutter analyze` clean and `flutter test` green (24/24 + additions) at every commit.
- Dashboard smoke test (`test/widget_test.dart`) boots the new home; assertions extended to pin: 'Today' card figures render, 'Live Floor' header renders, 'All clear' card when no active job cards (mock seed has active jobs — assert the strip instead).
- `test/hero_widgets_test.dart` stays green (BookServiceCard untouched).
- Final grep gates: type-scale gate (§3) plus the transit-red gates that must not regress (`poppins`/`isDark`/`AppColors`/`blueGradient` = 0).

## 6. Risks

- Size bumps overflow tight rows (many 11→12 changes). Mitigation: widget tests throw on render overflow; fix sites individually if any fail.
- 8→10 and 9→10 bumps inside tiny badge chips (IND flag at 8px). The chip has 4px/2px padding; 10px still fits — verified in review.
- Sparkline reuses real weekly data; if the computation in `_buildWeeklyRevenueExpenseChart` is month-based rather than 7-day, it is adapted (not invented) during planning against the actual code.

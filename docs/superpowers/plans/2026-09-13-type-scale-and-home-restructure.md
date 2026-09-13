# Type Scale + Home Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every hardcoded `fontSize:` literal with a named `AppText` token scale (monotonic remap, raised small-end floor) and restructure the dashboard home into: Book-a-Service → Today card → Live Floor strip → module tiles → recent bills.

**Architecture:** New `lib/theme/app_text.dart` exposes 8 static const doubles. A deterministic Node migration script rewrites literals to tokens (and inserts the per-depth import) across `lib/theme/app_theme.dart`, `lib/screens/**`, `lib/widgets/**`, `lib/utils/app_snack_bar.dart`. The dashboard deletes the bento island, quick-action carousel, bay-activity list, revenue chart, and their orphaned helpers, then adds two new builders (`_buildTodayCard`, `_buildLiveFloorStrip`) fed only by existing provider getters.

**Tech Stack:** Flutter (Material), provider, fl_chart 1.2 (`LineChart` sparkline), Node (one-shot migration script, deleted at the end).

**Spec:** `docs/superpowers/specs/2026-09-13-type-scale-and-home-restructure-design.md`

**Conventions for every task:**
- Run `flutter analyze` and `flutter test` as SEPARATE Bash calls and confirm both pass BEFORE committing (never chain them with `&&` after a pipe — `tail` masks failures).
- Commits add files explicitly by path. Never `git add -A` / `git add .`. Never amend. Never push.
- Current baseline: branch `main`, tree clean, `flutter analyze` clean, 24/24 tests green.

---

## File Structure

| File | Action |
|---|---|
| `lib/theme/app_text.dart` | Create — the 8-token scale |
| `test/theme/app_text_test.dart` | Create — pins the 8 values |
| `lib/theme/app_theme.dart` | Modify — all literals → tokens, import added |
| `lib/screens/**` (26 files with `fontSize:`) | Modify — literals → tokens, import added |
| `lib/widgets/**` (6 files) | Modify — literals → tokens, import added |
| `lib/utils/app_snack_bar.dart` | Modify — literals → tokens, import added |
| `sweep_font_sizes.mjs` (repo root) | Create in Task 1 as an untracked one-shot tool; used by Tasks 1–2; deleted in Task 5 |
| `lib/screens/dashboard/dashboard_screen.dart` | Modify — deletions + Today card + Live Floor strip |
| `test/widget_test.dart` | Modify — pin the new home structure |

Import depth rule: `lib/screens/**` → `import '../../theme/app_text.dart';`; `lib/widgets/**` and `lib/utils/**` → `import '../theme/app_text.dart';`; `lib/theme/app_theme.dart` → `import 'app_text.dart';`.

---

### Task 1: AppText token scale + theme realignment

**Files:**
- Create: `sweep_font_sizes.mjs`
- Create: `lib/theme/app_text.dart`
- Create: `test/theme/app_text_test.dart`
- Modify: `lib/theme/app_theme.dart` (via the script)

- [ ] **Step 1: Write the failing test**

Create `test/theme/app_text_test.dart` with exactly:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/theme/app_text.dart';

void main() {
  test('AppText token scale has the approved values', () {
    expect(AppText.micro, 10);
    expect(AppText.label, 12);
    expect(AppText.caption, 13);
    expect(AppText.body, 14);
    expect(AppText.subtitle, 15.5);
    expect(AppText.title, 17);
    expect(AppText.headline, 20);
    expect(AppText.display, 26);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/theme/app_text_test.dart`
Expected: FAIL — `Error: Couldn't resolve the file 'app_text.dart'` / `AppText` not found (compile error is the expected failure mode).

- [ ] **Step 3: Create the AppText class**

Create `lib/theme/app_text.dart` with exactly:

```dart
/// Named type scale for the whole app. Every `fontSize:` in lib/ must use one
/// of these tokens; values are tuned for Inter with a raised 10px floor so
/// nothing renders smaller than before.
class AppText {
  AppText._();

  static const double micro = 10; // badges, overlines, flag chips
  static const double label = 12; // tile labels, list subtitles, small captions
  static const double caption = 13; // secondary body
  static const double body = 14; // primary body
  static const double subtitle = 15.5;
  static const double title = 17; // section/card titles
  static const double headline = 20; // screen headlines, big figures
  static const double display = 26; // hero figures only
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/theme/app_text_test.dart`
Expected: PASS (1/1).

- [ ] **Step 5: Create the one-shot migration script**

Create `sweep_font_sizes.mjs` at the repo root with exactly:

```js
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

// Spec remap table (nearest token, monotonic — nothing shrinks).
const MAPPING = {
  '8': 'micro', '9': 'micro', '10': 'micro', '10.5': 'micro',
  '11': 'label', '11.5': 'label', '12': 'label',
  '12.5': 'caption', '13': 'caption',
  '13.5': 'body', '14': 'body',
  '14.5': 'subtitle', '15': 'subtitle',
  '16': 'title', '16.5': 'title', '17': 'title', '18': 'title',
  '19': 'headline', '20': 'headline', '22': 'headline',
  '24': 'display', '28': 'display', '32': 'display',
};

const [target, importStmt] = process.argv.slice(2);
if (!target || !importStmt) {
  console.error('usage: node sweep_font_sizes.mjs <file-or-dir> <import-stmt|NONE>');
  process.exit(1);
}

const s = statSync(target);
const files = s.isFile()
  ? [target]
  : readdirSync(target, { recursive: true })
      .filter((f) => f.endsWith('.dart'))
      .map((f) => join(target, f));

const pattern = /fontSize:\s*(\d+(?:\.\d+)?)/g;
let changed = 0;
for (const file of files) {
  const src = readFileSync(file, 'utf8');
  if (!src.includes('fontSize:')) continue;
  const unmapped = [...src.matchAll(pattern)].map((m) => m[1]).filter((v) => !(v in MAPPING));
  if (unmapped.length) {
    console.error(`UNMAPPED fontSize ${[...new Set(unmapped)]} in ${file} — aborting, extend MAPPING`);
    process.exit(1);
  }
  let out = src.replace(pattern, (_, v) => `fontSize: AppText.${MAPPING[v]}`);
  if (importStmt !== 'NONE' && !out.includes('app_text.dart')) {
    const lines = out.split('\n');
    let last = -1;
    for (let i = 0; i < lines.length; i++) if (lines[i].startsWith('import ')) last = i;
    lines.splice(last + 1, 0, importStmt);
    out = lines.join('\n');
  }
  writeFileSync(file, out);
  changed++;
  console.log('updated', file);
}
console.log(`done: ${changed} files`);
```

- [ ] **Step 6: Run the script on app_theme.dart**

Run: `node sweep_font_sizes.mjs lib/theme/app_theme.dart "import 'app_text.dart';"`
Expected output ends: `done: 1 files` and prints `updated lib/theme/app_theme.dart`.

Then verify the realignment matches the spec's textTheme slots by reading `lib/theme/app_theme.dart:25-46`:
- headlineLarge → `AppText.display` (26), headlineMedium → `AppText.headline` (20), titleLarge → `AppText.title` (17), titleMedium → `AppText.body` (14), titleSmall → `AppText.caption` (13), bodyLarge → `AppText.body` (14), bodyMedium → `AppText.caption` (13), bodySmall → `AppText.label` (12), labelLarge → `AppText.caption` (13), labelMedium → `AppText.label` (12), labelSmall → `AppText.micro` (10)
- AppBar `titleTextStyle` → `AppText.title`; hintStyle/label literals → `AppText.caption`/`AppText.body`; weights, letterSpacing, colors all unchanged.
- The `import 'app_text.dart';` line sits after the last existing import.

If any of these do not hold, stop and fix by hand before continuing.

- [ ] **Step 7: Gates**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!` (25/25 — 24 existing + the new AppText test).

- [ ] **Step 8: Commit**

```bash
git add lib/theme/app_text.dart lib/theme/app_theme.dart test/theme/app_text_test.dart
git commit -m "feat: add AppText token scale and realign theme text sizes"
```

(`sweep_font_sizes.mjs` stays untracked; it is deleted in Task 5.)

---

### Task 2: Sweep all remaining fontSize literals onto tokens

**Files:**
- Modify: 26 files under `lib/screens/`, 6 under `lib/widgets/`, 1 under `lib/utils/` (all files containing `fontSize:` — exactly the list from `grep -rln "fontSize:" lib/screens lib/widgets lib/utils`; 33 total, plus 2 conditional `fontSize:` expressions hand-fixed in Step 2b)

- [ ] **Step 1: Record the input file list**

Run: `grep -rln "fontSize:" lib/screens lib/widgets lib/utils | sort | tee /tmp/font-sweep-input.txt && wc -l < /tmp/font-sweep-input.txt`
Expected: 33 files.

- [ ] **Step 2: Run the script per depth**

Run each as its own Bash call:

```bash
node sweep_font_sizes.mjs lib/screens "import '../../theme/app_text.dart';"
```
Expected: `done: 26 files`.

```bash
node sweep_font_sizes.mjs lib/widgets "import '../theme/app_text.dart';"
```
Expected: `done: 6 files`.

```bash
node sweep_font_sizes.mjs lib/utils "import '../theme/app_text.dart';"
```
Expected: `done: 1 files` (only `app_snack_bar.dart` contains `fontSize:`).

- [ ] **Step 2b: Hand-fix the two conditional fontSize expressions**

The script's regex only matches plain numeric literals; these two ternary sites must be fixed by hand (both branches of each ternary map to the same token, so the conditional disappears):

- `lib/screens/invoices/invoice_preview_screen.dart` — `fontSize: highlight ? 13 : 12.5,` becomes `fontSize: AppText.caption,` (13→caption, 12.5→caption).
- `lib/widgets/status_badge.dart` — `fontSize: isCompact ? 9.5 : 10.5,` becomes `fontSize: AppText.micro,` (9.5 and 10.5 both nearest micro; nothing maps below micro). Both files already receive their import from the Step 2 script run (status_badge.dart is touched because it still contains the `fontSize:` string, so the script inserts its import even though it has no plain numeric to replace).

Verify afterward: `grep -rn "fontSize:" lib/ | grep -v "AppText\." | grep -v "app_text.dart"` → no output.

- [ ] **Step 3: Type-scale gate**

Run: `grep -rn "fontSize: [0-9]" lib/`
Expected: no output, exit code 1 (zero literal sizes anywhere in lib/).

- [ ] **Step 4: Gates**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!` (25/25).

**If a test fails with a RenderFlex overflow** (the only sanctioned contingency, spec §6): the bump (e.g. 11→12) overflowed that exact site. Fix the specific widget minimally — add `maxLines: 1, overflow: TextOverflow.ellipsis` to the offending Text, or wrap the tight Row child in `Flexible`. Do NOT lower token values and do NOT reflow unrelated screens. Re-run both gates after each fix and include fixed files in the commit below.

- [ ] **Step 5: Commit**

```bash
git add lib/screens lib/widgets lib/utils/app_snack_bar.dart
git commit -m "refactor: sweep all fontSize literals onto AppText tokens"
```

(`git add lib/screens lib/widgets` here is a plan-sanctioned full sweep — 33 files across 3 directories is exactly what this task changed. Verify with `git status` first that nothing unexpected is staged.)

---

### Task 3: Dashboard restructure — Today card + Live Floor + deletions

**Files:**
- Modify: `lib/screens/dashboard/dashboard_screen.dart`

Current structure (verified): `build()` spans :31–827 with body sections — bento island (comment `// 1. CORE BENTO ISLAND CARD`, ~:124–367), `BookServiceCard` (~:368–370), quick-actions carousel (`// 2. QUICK ACTIONS SHORTCUTS CAROUSEL`, ~:372–461), bay-activity list (`// 3. LIVE BAY ACTIVITY (ACTIVE FLOOR VEHICLES)`, ~:463–605), modules grid (`// 4. WORKSHOP MODULES SHORTCUTS (6 TILES)`), chart call (`// 5. FINANCIAL REVENUE BAR CHART` + `..._buildWeeklyRevenueExpenseChart(provider, palette),`), recent bills (`// 6. RECENT COLLECTIONS & BILLS`). Helpers: `_buildKpiTile` (~:829), `_buildModuleTile` (~:916, KEEP), `_buildQuickActionChip` (~:984), `_buildLegendItem` (~:1029), `_buildWeeklyRevenueExpenseChart` (~:1045), `_makeGroupData` (~:1157, last member before the class-closing `}`).

- [ ] **Step 1: Add the two new builders**

Insert the following two methods immediately ABOVE the line `  Widget _buildModuleTile(` (keep one blank line between them and around):

```dart
  Widget _buildTodayCard(BuildContext context, GarageProvider provider, AppPalette palette) {
    final pendingCount = provider.invoices
        .where((inv) => inv.status != InvoiceStatus.cancelled && inv.balanceDue > 0)
        .length;
    final pendingTotal = provider.totalPendingPayments;

    // 7-day collections series (Mon–Sun) — the same bucketing the deleted
    // revenue/expense chart used, now rendered as a sparkline.
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weeklyCollections = List<double>.filled(7, 0);
    for (final p in provider.payments) {
      final dayDiff = DateTime(p.paymentDate.year, p.paymentDate.month, p.paymentDate.day)
          .difference(DateTime(monday.year, monday.month, monday.day))
          .inDays;
      if (dayDiff >= 0 && dayDiff < 7) weeklyCollections[dayDiff] += p.amount;
    }
    final hasWeeklyData = weeklyCollections.any((v) => v > 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.paddingCard),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: palette.border),
        boxShadow: AppDimens.cardShadow(palette.textPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: GoogleFonts.inter(
              fontSize: AppText.subtitle,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection',
                      style: GoogleFonts.inter(
                        fontSize: AppText.label,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(provider.todayCollection),
                      style: GoogleFonts.inter(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w800,
                        color: palette.paid,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: GoogleFonts.inter(
                        fontSize: AppText.label,
                        fontWeight: FontWeight.w600,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(provider.todayExpenses),
                      style: GoogleFonts.inter(
                        fontSize: AppText.title,
                        fontWeight: FontWeight.w800,
                        color: palette.pending,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasWeeklyData) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), weeklyCollections[i]),
                      ],
                      isCurved: true,
                      barWidth: 2.5,
                      color: palette.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            palette.primary.withValues(alpha: 0.22),
                            palette.primary.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (pendingCount > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusTile),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16, color: palette.pending),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${CurrencyFormatter.format(pendingTotal)} due across $pendingCount bills',
                          style: GoogleFonts.inter(
                            fontSize: AppText.caption,
                            fontWeight: FontWeight.w700,
                            color: palette.pending,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: palette.pending),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                'No pending dues',
                style: GoogleFonts.inter(
                  fontSize: AppText.caption,
                  fontWeight: FontWeight.w600,
                  color: palette.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveFloorStrip(BuildContext context, GarageProvider provider, AppPalette palette) {
    final activeJobs = provider.activeJobCards;

    if (activeJobs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          border: Border.all(color: palette.border),
        ),
        child: Center(
          child: Text(
            'All clear — no vehicles in workshop',
            style: GoogleFonts.inter(
              fontSize: AppText.caption,
              fontWeight: FontWeight.w500,
              color: palette.textMuted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeJobs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final jc = activeJobs[index];
          final vehicle = provider.getVehicleById(jc.vehicleId);
          return Container(
            width: 190,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              border: Border.all(color: palette.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobCardDetailScreen(jobCardId: jc.id)),
                  );
                },
                borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle?.registrationNumber ?? 'Vehicle',
                              style: GoogleFonts.inter(
                                fontSize: AppText.body,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge.fromJobStatus(jc.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicle?.displayName ?? '',
                        style: GoogleFonts.inter(
                          fontSize: AppText.label,
                          fontWeight: FontWeight.w500,
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

```

- [ ] **Step 2: Replace body sections 1–3 with the new home stack**

In `build()`'s `Column(children: [...])`, replace the ENTIRE region starting at the dashes line directly above
`              // 1. CORE BENTO ISLAND CARD (BLACK BANNER)`
and ending at the `              const SizedBox(height: 24),` line that sits directly ABOVE the dashes line preceding
`              // 4. WORKSHOP MODULES SHORTCUTS (6 TILES)`
with EXACTLY:

```dart
              // -------------------------------------------------------------
              // 1. BOOK A SERVICE (HERO)
              // -------------------------------------------------------------
              const BookServiceCard(),
              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // 2. TODAY CARD (COLLECTION / EXPENSES / SPARKLINE / DUES)
              // -------------------------------------------------------------
              _buildTodayCard(context, provider, palette),
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 3. LIVE FLOOR (ACTIVE VEHICLES)
              // -------------------------------------------------------------
              SectionHeader(
                title: 'Live Floor',
                actionText: 'View All (${activeJobs.length})',
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JobCardsListScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildLiveFloorStrip(context, provider, palette),
```

(The old region's trailing `const SizedBox(height: 24),` is kept — it becomes the spacer above the modules header, so the new block intentionally ends after the strip.)

Practical way to do this edit: the region is ~490 lines, too big for a single Edit old_string. Use a marker-based Node deletion first, then Edit the new block in. The deletion anchor logic: start = the line containing `// 1. CORE BENTO ISLAND CARD` minus 1 (its dashes line); end = the line containing `// 4. WORKSHOP MODULES SHORTCUTS` minus 2 (its dashes line minus the retained `SizedBox(height: 24)`), exclusive. Run:

```bash
node -e "
const fs = require('fs');
const p = 'lib/screens/dashboard/dashboard_screen.dart';
const lines = fs.readFileSync(p, 'utf8').split('\n');
const i1 = lines.findIndex(l => l.includes('// 1. CORE BENTO ISLAND CARD'));
const i4 = lines.findIndex(l => l.includes('// 4. WORKSHOP MODULES SHORTCUTS'));
if (i1 < 1 || i4 < 0 || i4 <= i1) { console.error('markers not found', i1, i4); process.exit(1); }
const kept = lines.slice(0, i1 - 1).concat(lines.slice(i4 - 2));
fs.writeFileSync(p, kept.join('\n'));
console.log('removed lines', i1, '..', i4 - 3);
"
```

After it runs, `grep -n "CORE BENTO ISLAND\|QUICK ACTIONS SHORTCUTS\|LIVE BAY ACTIVITY" lib/screens/dashboard/dashboard_screen.dart` must return nothing, and the region between the opening `children: [` and `// 4. WORKSHOP MODULES` must read: `const BookServiceCard(),` → `const SizedBox(height: 16),` → (blank) → `const SizedBox(height: 24),` → (blank) → dashes → `// 4. WORKSHOP MODULES…`. Then Edit-insert the new block so it exactly matches the code above.

- [ ] **Step 3: Delete the chart section from the body**

This Edit is small enough to do directly. Replace:

```dart
              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // 5. FINANCIAL REVENUE BAR CHART (computed from real data)
              // -------------------------------------------------------------
              ..._buildWeeklyRevenueExpenseChart(provider, palette),
              const SizedBox(height: 24),
```

with:

```dart
              const SizedBox(height: 24),
```

(One spacer remains between the modules grid and the recent-bills `SectionHeader`.)

- [ ] **Step 4: Delete the orphaned helpers**

`_buildKpiTile` (between `build()` and `_buildModuleTile`), then everything from `_buildQuickActionChip` through `_makeGroupData` (the file tail). Run both Node truncations:

```bash
node -e "
const fs = require('fs');
const p = 'lib/screens/dashboard/dashboard_screen.dart';
const lines = fs.readFileSync(p, 'utf8').split('\n');
const s = lines.findIndex(l => l.includes('  Widget _buildKpiTile({'));
const e = lines.findIndex(l => l.includes('  Widget _buildModuleTile('));
if (s < 0 || e < 0 || e <= s) { console.error('markers not found', s, e); process.exit(1); }
fs.writeFileSync(p, lines.slice(0, s).concat(lines.slice(e)).join('\n'));
console.log('removed _buildKpiTile lines', s + 1, '..', e);
"
```

```bash
node -e "
const fs = require('fs');
const p = 'lib/screens/dashboard/dashboard_screen.dart';
const lines = fs.readFileSync(p, 'utf8').split('\n');
const s = lines.findIndex(l => l.includes('  Widget _buildQuickActionChip('));
if (s < 0) { console.error('marker not found'); process.exit(1); }
fs.writeFileSync(p, lines.slice(0, s).concat(['}']).join('\n'));
console.log('truncated helpers from line', s + 1);
"
```

(The second keeps only the class-closing `}` — `_buildQuickActionChip`, `_buildLegendItem`, `_buildWeeklyRevenueExpenseChart`, `_makeGroupData` are contiguous through end of file.)

Verify: `grep -n "_buildKpiTile\|_buildQuickActionChip\|_buildLegendItem\|_buildWeeklyRevenueExpenseChart\|_makeGroupData" lib/screens/dashboard/dashboard_screen.dart`
Expected: no output.

- [ ] **Step 5: Analyze + unused-import cleanup**

Run: `flutter analyze`
Expected: `No issues found!` — with one possible sanctioned exception: `unused_import` for `../../models/job_card.dart` (the `JobStatus`/`JobCard` type names are no longer referenced after the bay-activity list was removed; the strip only calls `StatusBadge.fromJobStatus(jc.status)`). If that warning appears, delete the `import '../../models/job_card.dart';` line and re-run analyze to `No issues found!`. Any OTHER issue: stop and fix it before continuing.

Run: `flutter test`
Expected: `All tests passed!` (25/25 — the smoke test still passes because the AppBar profile name is untouched; hero tests are untouched).

Run: `wc -l lib/screens/dashboard/dashboard_screen.dart`
Expected: roughly 650–750 lines (was 1183).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat: restructure dashboard home with Today card and Live Floor"
```

---

### Task 4: Pin the new home in the smoke test

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Extend the smoke test**

Replace the entire contents of `test/widget_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/main.dart';
import 'package:garage_manager/widgets/book_service_card.dart';

void main() {
  testWidgets('Nexory Garage App loads dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoryGarageApp());
    await tester.pumpAndSettle();

    expect(find.text('Nexory Garage & Body Shop'), findsWidgets);

    // New home structure (spec §5): booking-first stack.
    expect(find.byType(BookServiceCard), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Expenses'), findsWidgets); // Today card + module tile
    expect(find.textContaining('₹'), findsWidgets);
    expect(find.text('Live Floor'), findsOneWidget);
    // The mock seed has active job cards, so the strip renders — not the
    // empty card.
    expect(find.text('All clear — no vehicles in workshop'), findsNothing);
    expect(find.text('Workshop Modules'), findsOneWidget);

    // Deleted sections stay deleted.
    expect(find.text('Live Bay Activity'), findsNothing);
    expect(find.text('Weekly Revenue vs Expenses'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/widget_test.dart`
Expected: PASS (1/1). If `'All clear — no vehicles in workshop'` IS found, the seed has no active job cards — change that expectation to `findsOneWidget` and also expect `find.text('Live Floor'), findsOneWidget` still holds; note the seed state in the commit body.

- [ ] **Step 3: Full gates**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!` (25/25).

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: pin new dashboard home structure in smoke test"
```

---

### Task 5: Final verification

- [ ] **Step 1: Grep gates (all expected at the stated counts)**

```bash
grep -rn "fontSize: [0-9]" lib/ ; echo "exit=$?"
```
Expected: no matches, exit=1.

```bash
grep -rn "GoogleFonts.poppins\|isDark\|AppColors\|blueGradient" lib/ ; echo "exit=$?"
```
Expected: no matches, exit=1 (transit-red gates must not regress).

```bash
grep -rn "brandGradient" lib/ | wc -l
```
Expected: ≥ 2.

```bash
grep -rn "Live Bay Activity\|Weekly Revenue vs Expenses\|CORE BENTO\|QUICK ACTIONS SHORTCUTS\|_buildQuickActionChip\|_buildKpiTile" lib/
```
Expected: no matches, exit=1.

- [ ] **Step 2: Module tiles restyle check (spec §4.4)**

Run: `grep -n "boxShadow" lib/screens/dashboard/dashboard_screen.dart`
Expected: exactly one match — the Today card's `AppDimens.cardShadow(...)` line (module tiles and floor cards have none).

- [ ] **Step 3: Gates**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!` (25/25).

- [ ] **Step 4: Delete the one-shot migration tool**

Run: `rm sweep_font_sizes.mjs` (untracked scratch file created in Task 1).
Run: `git status`
Expected: working tree clean (no untracked `sweep_font_sizes.mjs`, nothing modified).

- [ ] **Step 5: Commit only if Task-2-style overflow fixes or gate fixes were needed**

If anything was fixed in this task:

```bash
git add <explicit fixed files>
git commit -m "fix: type-scale and home-restructure final sweep"
```

If nothing was fixed, no commit — tree is already clean at Task 4's commit.

- [ ] **Step 6: Manual visual pass is the USER's step** (desktop run is classifier-blocked for the agent): new font sizes across all screens, new home (Book-a-Service → Today card with sparkline → Live Floor strip → modules → recent bills), invoice ticket + QR still intact.

---

## Self-review notes (completed during plan writing)

- **Spec coverage:** §3 scale+remap → T1 (tokens+theme) + T2 (sweep+gate); §4.1 hero first → T3 step 2; §4.2 Today card → T3 step 1 (figures, sparkline reusing the exact Mon–Sun `provider.payments` bucketing from the deleted chart, all-zeros collapse, pending line → `InvoicesListScreen`); §4.3 Live Floor → T3 step 1 (`SectionHeader` with count, horizontal strip, tap → detail, empty card with the spec's exact copy); §4.4 modules → verified already light (surface+border, no shadows) — T5 step 2 pins it; §4.5 recent bills untouched; deletions list → T3 steps 2–4; §5 testing → T4 + T5 gates; §6 risks → T2 step 4 contingency. Gap fixed: spec names `StatusBadge.fromJobCardStatus`, the actual API (verified in code) is `StatusBadge.fromJobStatus` — plan uses the real name.
- **Placeholders:** none — every code step is complete; the only contingent instruction (overflow fixes in T2 step 4, unused `job_card.dart` import in T3 step 5) is sanctioned by the spec and bounded with exact expected outcomes.
- **Type consistency:** `AppText` token names match the spec table; `_buildTodayCard(BuildContext, GarageProvider, AppPalette)` / `_buildLiveFloorStrip(BuildContext, GarageProvider, AppPalette)` match their call sites; provider getters `todayCollection`, `todayExpenses`, `totalPendingPayments`, `invoices`, `activeJobCards`, `getVehicleById` all verified to exist in `lib/providers/garage_provider.dart`; `AppDimens.paddingCard/radiusCard/radiusTile/cardShadow` verified; `StatusBadge.fromJobStatus`, `CurrencyFormatter.format`, `InvoicesListScreen`, `JobCardDetailScreen(jobCardId:)` verified in current code; all imports needed by the new builders are already present in dashboard_screen.dart.

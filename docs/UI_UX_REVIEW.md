# UI/UX Review Findings — Full Audit (2026-10-10)

Source of truth for fixes: `docs/UI_UX_GUIDELINES.md`.
Findings below are the complete audit output across all screens and shared
layers, grouped by owning batch. Each item: [priority] file:line — issue —
guideline § — fix. **Every item must be fixed.**

---

## Batch A — auth + navigation

- [P1] lib/screens/auth/garage_switcher.dart:71 — `await auth.selectGarage(...)` has no try/catch after the sheet pops; failed switch (401/429/402/network) is an unhandled async error with no feedback and stale data — §7 — fix: try/catch with `showAppSnackBar(..., errorMessage(e), type: SnackBarType.error)` (mind `mounted` after await); wrap the uncaught `logout()` at :92 the same way.
- [P2] login_screen.dart:59 (also register:72, forgot:58, reset:69, verify:84) — hard-coded horizontal padding 24 instead of `AppDimens.paddingScreen` (16) — §4/§10 — fix: use `AppDimens.paddingScreen` (keep the 420 max-width if intended).
- [P2] login_screen.dart:87 (also register:95, forgot:75, verify:101, garage_switcher:41) — muted text colored with `Theme.of(context).hintColor` instead of palette token — §2 — fix: `palette.textSecondary` (or `textMuted`).
- [P2] reset_password_screen.dart:49 (also verify_email_screen.dart:64) — successful mutations ("Password updated", "Email verified") show default info snackbar instead of green — §8.1/§2 — fix: `type: SnackBarType.success`.
- [P2] verify_email_screen.dart:40-44 — resend validates email ad hoc with a non-catalog message ("Enter your account email first.") and the email field (:104-112) has no validator — §7 — fix: attach the standard email validator ("Email is required" / "Enter a valid email") to the field; drop the manual snackbar check.
- [P2] garage_switcher.dart:18 — sheet top radius hard-coded 20 instead of `AppDimens.radiusSheet` (24) — §4 — fix: `Radius.circular(AppDimens.radiusSheet)`.
- [P2] main_navigation_screen.dart:82 — floating nav bar radius 28 hard-coded (no token) and :143 splash radius 20 — §10 — fix: reuse token (24) or add a named nav radius to `AppDimens`.
- [P2] main_navigation_screen.dart:57-61 — load-error state renders unstyled default Icon/Text (no AppText token, no palette colors, no Poppins) — §3/§10 — fix: style with `GoogleFonts.poppins(fontSize: AppText.title, w700, palette.textPrimary)`; icon `palette.absent`.
- [P3] login_screen.dart:142 (also register:171, main_navigation:170,195) — `Colors.white` hard-coded instead of `onPrimary` — §2/§10 — fix: `context.palette.onPrimary`.
- [P3] main_navigation_screen.dart:160 — selected pill uses `palette.textPrimary` where §5 names `accent` — §5 — fix: `palette.accent`.
- [P3] register_screen.dart:98-159 — no `textInputAction` (next/done) and no `onFieldSubmitted` on password — §10 — fix: `TextInputAction.next` on first three fields; `done` + `onFieldSubmitted: (_) => _submit()` on password.
- [P3] forgot_password_screen.dart:89 — email validity only `contains('@')` while login/register also require '.', inconsistent — §7 — fix: extract one shared email validator and reuse it across auth screens (do NOT change register/reset password "Minimum 8 characters" message; doc will be updated instead).
- [P3] garage_switcher.dart:39 — "Signed in as ..." line lacks maxLines/ellipsis; long email stretches the sheet header — §10 — fix: `maxLines: 1, overflow: TextOverflow.ellipsis`.

## Batch B — dashboard + customers + vehicles

- [P1] dashboard_screen.dart:115 — "New job card" (115) and "Quick bill" (124) launch write flows with no `PermissionGate` (jobcards/invoices manage) — §5 — fix: wrap both in `PermissionGate`.
- [P2] dashboard_screen.dart:240 — "Late" promise-overdue label uses `palette.absent` red; lateness is a warning — §2 — fix: `palette.pending`.
- [P2] dashboard_screen.dart:176 — search-miss is custom plain text + bare OutlinedButton instead of `EmptyStateWidget` with `No results found for "term"` — §5 — fix: reuse EmptyStateWidget (search_off icon) with interpolated term.
- [P3] dashboard_screen.dart:302 — hard-coded `BorderRadius.circular(8)` (also paddings 14/12/4 at 86, 327, 404, 426) — §10 — fix: AppDimens tokens.
- [P3] dashboard_screen.dart:474 — `_Empty` sections ("No vehicles in the workshop." 214, "No bills yet." 252) plain text without token/CTA — §5 — fix: at minimum AppText token (CTA optional; links sit above).
- [P3] dashboard_screen.dart:317 — money-card figures use `AppText.title`; bill-row amounts use `AppText.body` (264) — §3 — fix: `AppText.headline` / `AppText.subtitle`.
- [P1] customers_list_screen.dart:142 — empty-state "Add New Customer" CTA (and search-miss CTA 141-147) not wrapped in `PermissionGate(customersManage)` — §5 — fix: wrap the CTA.
- [P1] add_customer_screen.dart:103 — `_handleSave` has no `_isSaving` latch; all five submit buttons (574, 587, 602, 613, 628) stay tappable → duplicate customers — §5/§10 — fix: add latch, guard re-entry, disable buttons.
- [P1] add_customer_screen.dart:128 — `updateCustomer` (128) and `addCustomer` (171) not in try/catch; API failure is unhandled — §7 — fix: wrap both like the addVehicle block (189-201) with `errorMessage(e)` error snackbar.
- [P1] add_customer_screen.dart:485 — KM validator only checks emptiness; non-digit junk passes, `parseGroupedInt` null → silently saves 0 — §7 — fix: `final km = parseGroupedInt(val!); if (km == null || km < 0) return 'Enter a valid KM reading';` (mirror add_vehicle_dialog 289-293).
- [P2] add_customer_screen.dart:357 — GSTIN field maxLength 15 but no validator; partial GSTIN saved — §7 — fix: when non-empty validate 15 chars, `Enter a valid 15-character GSTIN`.
- [P3] add_customer_screen.dart:414 — hard-coded `Colors.white` switch thumb (also decorative brand-red prefix icons 275, 289, 430, 483; green one at 317) — §2/§10 — fix: `palette.onPrimary` thumb; `textSecondary`/`textMuted` icons.
- [P3] add_customer_screen.dart:254 — form padding 20 + ad-hoc 14/28/32 gaps — §10 — fix: 16 / tokens.
- [P1] customer_detail_screen.dart:115 — successful deletions reported with `SnackBarType.error`: "Customer … deleted" (115), "Vehicle … deleted" (152) — §2/§5 — fix: `SnackBarType.success`.
- [P1] customer_detail_screen.dart:178 — all write actions ungated: Edit customer (178), Delete customer menu (193), Add Vehicle (407), New job card (484), vehicle Edit/Delete menu (500-513) — §5 — fix: `PermissionGate` per action with matching permission.
- [P2] customer_detail_screen.dart:280 — GSTIN chip (277-292) and fuel chip (442-456) informational but brand red — §2 — fix: `accent` or muted neutral.
- [P2] customer_detail_screen.dart:101 — `deleteCustomer` (101) / `deleteVehicle` (145) awaited with no try/catch and no latch — §7/§10 — fix: try/catch + error snackbar; disable while in flight.
- [P2] customer_detail_screen.dart:528 — tab lists use bare centred text for empty states (528, 564); Vehicles tab has none — §5 — fix: EmptyStateWidget (Vehicles reuses Add Vehicle action).
- [P3] customer_detail_screen.dart:133 — vehicle delete dialog names plate but no cascade — §5 — fix: append cascade wording.
- [P1] add_vehicle_dialog.dart:124 — failure shows raw `ScaffoldMessenger.showSnackBar` — §5 — fix: `showAppSnackBar(context, errorMessage(e), type: SnackBarType.error)`.
- [P3] add_vehicle_dialog.dart:315 — `_isSaving` guard exists but submit button not disabled — §5 — fix: `onPressed: _isSaving ? null : _saveVehicle`.
- [P1] vehicle_selection_screen.dart:112 — "Add Vehicle" app-bar action (112-122) and empty-state CTA (206-207) ungated — §5 — fix: `PermissionGate(vehiclesManage)` on both.
- [P3] vehicle_selection_screen.dart:261 — hard-coded `Color(0xFF003399)` "IND" band — §2/§10 — fix: hoist to AppPalette as a named token (keep value; deliberate per §9).
- [P3] vehicle_selection_screen.dart:320 — KM grouped via ad-hoc regex instead of `groupDigits` helper — consistency — fix: use `groupDigits`.
- [P3] vehicle_selection_screen.dart:136 — deprecated `withOpacity` (136, 248, 289) — fix: `withValues(alpha: …)`.
- [P3] vehicle_selection_screen.dart:138 — `customer.name.substring(0, 1)` RangeError if empty name — fix: guard with `isEmpty ? '?' : ...`.

## Batch C — job cards + quotations + maintenance + wizard

- [P1] create_job_card_screen.dart:216 — KM field has no validator; empty/invalid silently falls back (`_formKey` never validated) — §7 — fix: add validator blocking submit with "KM is required" / "Enter a valid KM reading" (allow the prefilled fallback only when the field is legitimately prefilled from vehicle — keep prefills, validate typed junk).
- [P2] create_job_card_screen.dart:622 — per-item totals in brand red — §2/§3 — fix: `palette.textPrimary`.
- [P2] create_job_card_screen.dart:617 — raw `'${item.quantity}'` renders "1.0 x" — §6 — fix: `formatQuantity(item.quantity)`.
- [P3] create_job_card_screen.dart:503 — complaint chips tinted brand red as informational rows — §2 — fix: `palette.cardAlt`/accent tint.
- [P1] job_cards_list_screen.dart:153 — empty-state CTA "Create New Job Card" bypasses `Permissions.jobcardsManage` (FAB 76-82 is gated) — §5 — fix: wrap empty state CTA in PermissionGate.
- [P3] job_cards_list_screen.dart:168 — local variable named `late` shadows Dart keyword — fix: rename `isLate`.
- [P1] job_card_detail_screen.dart:53 — `_removeItem` awaits with no try/catch; API/402 failure unhandled — §7 — fix: try/catch + error snackbar (like `_changeStatus`).
- [P1] job_card_detail_screen.dart:211 — write actions ungated: change status (:211), next-step (:250), edit AppBar (:333), Edit items (:654), Create/View Bill (:788/:767) — §5 — fix: PermissionGate/ensurePermission with jobcards/invoices manage.
- [P2] job_card_detail_screen.dart:264 — `_generateInvoice` no latch; double-tap can create two invoices — §10 — fix: latch + disable.
- [P2] job_card_detail_screen.dart:752 — grand total (also fuel chip :398, stage progress bars :227) brand red — §2/§3 — fix: `textPrimary` money; `accent`/`paid` progress.
- [P2] job_card_detail_screen.dart:713 — item removal has no confirmation — §10 — fix: confirm dialog naming the item, amber confirm.
- [P3] job_card_detail_screen.dart:304 — "Job card not found" default Text — §3/§10 — fix: EmptyStateWidget with back action.
- [P1] create_quotation_screen.dart:132 — empty-items message "Please add at least one service or spare part item" instead of §7 exact "Please add at least one work item or spare part" — §7 — fix: use documented string.
- [P2] create_quotation_screen.dart:576 — Save button stays enabled while `_isSaving` — §5/§10 — fix: `onPressed: _isSaving ? null : _saveQuotation`.
- [P2] create_quotation_screen.dart:561 — Estimated Total (and item lines :393) brand red — §2/§3 — fix: `textPrimary`.
- [P3] create_quotation_screen.dart:156 — KM silently falls back, no validator — §7 — fix: validate/flag.
- [P3] create_quotation_screen.dart:139 — non-numeric discount silently parses 0.0 — §7 — fix: inline "Invalid amount".
- [P1] quotations_list_screen.dart:144 — empty-state CTA bypasses `quotationsManage` (FAB gated) — §5 — fix: gate CTA.
- [P2] quotations_list_screen.dart:141 — search-miss shows "No estimates created yet" instead of interpolated `No results found for "term"` — §5 — fix: interpolate when query set.
- [P1] quotation_detail_screen.dart:203 — successful decline shown with `SnackBarType.error` — §2/§5 — fix: `SnackBarType.success`.
- [P1] quotation_detail_screen.dart:553 — write actions ungated: Convert (:556), Bill Now (:571), Edit (:587), Approve (:598), Decline (:611) — §5 — fix: PermissionGate per action.
- [P2] quotation_detail_screen.dart:284 — ad-hoc BoxShadow on estimate slip — §4/§10 — fix: drop shadow, keep border.
- [P2] quotation_detail_screen.dart:100 — `_convertInvoice` creates invoice BEFORE status transition; 422 then errors though invoice exists (retry double-bills) — §7/§8.3 — fix: transition first, create invoice on success (provider has convertQuotationToJobCard guard — reuse its order).
- [P2] quotation_detail_screen.dart:514 — "Net Estimated Total" (and letterhead name :312) brand red — §2/§3 — fix: `textPrimary` for the total.
- [P3] quotation_detail_screen.dart:598 — Approve/Decline have no busy latch — §10 — fix: reuse `_isConverting` to disable.
- [P3] quotation_detail_screen.dart:224 — "Estimate not found" default Text — §3/§10 — fix: styled empty state.
- [P1] add_maintenance_screen.dart:255 — price/qty/discount use plain `TextInputType.number` (no decimals) — §10 — fix: `TextInputType.numberWithOptions(decimal: true)` on 255, 266, 291.
- [P2] add_maintenance_screen.dart:158 — price-list save failure shows raw ScaffoldMessenger snackbar — §5 — fix: `showAppSnackBar(..., errorMessage(e), type: SnackBarType.error)`.
- [P2] add_maintenance_screen.dart:179 — destructive confirm button default red FilledButton — §5 — fix: amber `palette.pending`.
- [P2] add_maintenance_screen.dart:724 — pinned total (selected totals :579, catalog prices :838) brand red — §2/§3 — fix: `textPrimary`.
- [P3] add_maintenance_screen.dart:313 — selected choice chips (category :313, GST :349) and checkboxes (:366) brand red — §2 — fix: accent-selected chips, `palette.paid` checkbox.
- [P3] add_maintenance_screen.dart:765 — empty catalogue plain centred text — §10 — fix: EmptyStateWidget (CTA = Custom Item).
- [P3] add_maintenance_screen.dart:490 — "Clear All" wipes picked list with no confirmation — §10 — fix: confirm dialog.
- [P2] quick_service_wizard.dart:662 — "Generate Bill" not disabled while `_isGeneratingBill` — §5/§10 — fix: `onPressed: _isGeneratingBill ? null : _generateFinalBill`.
- [P2] quick_service_wizard.dart:450 — vehicle step renders blank when customer has no vehicles — §10 — fix: EmptyStateWidget with Add-vehicle CTA.
- [P2] quick_service_wizard.dart:146 — empty-items message "Please add at least one work item or spare part" instead of quick-bill string "Please add at least one item or labour charge to generate bill" — §7 — fix: use quick-bill string.
- [P2] quick_service_wizard.dart:343 — write actions ungated: New customer (:343), New vehicle (:435), Generate Bill (:662); only Record Payment checked (:737) — §5 — fix: ensurePermission on each.
- [P3] quick_service_wizard.dart:399 — `c.name.substring(0, 1)` RangeError on blank name — fix: guard.
- [P3] quick_service_wizard.dart:174 — KM silently falls back — §7 — fix: validate/flag.
- [P3] quick_service_wizard.dart:269 — step indicator circles/labels/connector lines brand red; bill number/total red (:655, :717) — §2/§3 — fix: accent stepper; `textPrimary` amounts.

## Batch D — invoices + payments + billing

- [P1] create_invoice_screen.dart:297 — per-item amounts and Net Payable hero (:400) in brand red — §2/§3 — fix: `palette.textPrimary`.
- [P2] create_invoice_screen.dart:414 — save button "Save & Preview Bill" red while §5 mandates green `paid` for bill-creation primary — §5 — fix: `backgroundColor: palette.paid, foregroundColor: palette.onPrimary`.
- [P2] create_invoice_screen.dart:308 — Discount (and KM :321) use bare `TextInputType.number` — §10 — fix: `numberWithOptions(decimal: true)` for discount.
- [P2] create_invoice_screen.dart:195 — hard-coded paddings 20/16/14/28 (195, 200, 342) — §4/§10 — fix: AppDimens.
- [P3] create_invoice_screen.dart:415 — `_saveInvoice` never checks `invoices.manage` (relies on route) — §5 — fix: `ensurePermission(context, Permissions.invoicesManage)` in `_saveInvoice`.
- [P3] create_invoice_screen.dart:38 — `_formKey` attached but never validated — §10 — fix: drop Form or run validators.
- [P1] invoices_list_screen.dart:200 — empty-state "Create Bill" CTA ungated (FAB :83 gated) — §5 — fix: wrap CTA or ensurePermission.
- [P2] invoices_list_screen.dart:193 — search miss shows "No bills yet…" + create CTA instead of `No results found for "term"` — §5 — fix: interpolate query; hide CTA while searching.
- [P2] invoices_list_screen.dart:75 — `totalCollected` sums payments including cancelled invoices while `totalInvoiced` excludes them (KPI can show Collected > Billed) — §6 — fix: exclude cancelled from collected too.
- [P1] invoice_preview_screen.dart:364 — paper Total hero in brand red — §2/§3 — fix: `palette.textPrimary` (keep Paid/Balance colors).
- [P2] invoice_preview_screen.dart:134 — paper card BoxShadow — §4/§10 — fix: remove shadow.
- [P2] invoice_preview_screen.dart:100 — Cancel-bill menu visible to staff lacking `invoices.manage` (enforced only on tap :617) — §5 — fix: wrap PopupMenuButton in PermissionGate.
- [P2] invoice_preview_screen.dart:624 — cancel confirm body generic — §5 — fix: name the invoice number.
- [P2] invoice_preview_screen.dart:644 — successful cancellation shown with `SnackBarType.error` — §2 — fix: `SnackBarType.info`.
- [P2] invoice_preview_screen.dart:574 — "Record Payment" entry button red; confirm button on collection screen is green — §5 — fix: `palette.paid`.
- [P2] invoice_preview_screen.dart:86 — Share flow no catch (only finally) — §7 — fix: catch + error snackbar.
- [P2] invoice_preview_screen.dart:205 — overdue due-date flagged red (:205) in header but amber (:406) in breakdown — §2 — fix: one token (amber pending) for both.
- [P3] invoice_preview_screen.dart:630 — cancel-dialog button no in-flight latch (double-tap → 422 error) — §10 — fix: disable while pending.
- [P1] payment_collection_screen.dart:267 — balance card hard-coded gradient `0xFF22262B`/`0xFF3B4148` — §2 — fix: `palette.bannerGradient`.
- [P1] payment_collection_screen.dart:395 — amount field bare `TextInputType.number` — §10 — fix: `numberWithOptions(decimal: true)`.
- [P2] payment_collection_screen.dart:274 — balance card BoxShadow — §4 — fix: remove.
- [P2] payment_collection_screen.dart:435 — selection UI brand red (toggle selected fill/border 351-355/372-374; mode ChoiceChip.selectedColor) — §2 — fix: `palette.accent`.
- [P3] payment_collection_screen.dart:61 — `_submitPayment` never re-checks `payments.record` — §5 — fix: ensurePermission at top.
- [P3] payment_collection_screen.dart:54 — Full/Partial toggle silently overwrites manually typed amount — §10 — fix: prefill only when field still holds previous preset.
- [P1] billing_screen.dart:248 — status dot hard-coded `Colors.green/orange/red` — §2 — fix: `palette.paid/partial/absent`.
- [P2] billing_screen.dart:143 — destructive Cancel confirm uses theme-red FilledButton — §5 — fix: amber confirm (`palette.pending`), red-text Keep.
- [P2] billing_screen.dart:275 — Subscribe button no latch; double-tap starts two checkouts — §10 — fix: `_isSaving` on both plan buttons.
- [P2] billing_screen.dart:155 — `_cancel` catches only ApiException — §7 — fix: generic catch + error snackbar.
- [P3] billing_screen.dart:110 — `_awaitingPayment` never reset if `launchUrl` throws — §10 — fix: reset in catch blocks.

## Batch E — more menu + settings + expenses + catalog + members

- [P1] more_menu_screen.dart:232 — "Sign out" no confirmation dialog — §5 — fix: AlertDialog "Sign out?" before `auth.logout`.
- [P2] more_menu_screen.dart:132 — "Workshop" group renders empty bordered card when all children gated off — §5 — fix: skip group when no child passes.
- [P3] more_menu_screen.dart:321 — `_Item` hard-coded paddings (14/14; header fromLTRB(16,4,16,32) :111) — §10 — fix: AppDimens tokens.
- [P3] garage_settings_screen.dart:200 — ListView `EdgeInsets.all(20)` (field bottom:14 :129) — §10 — fix: `AppDimens.paddingScreen`.
- [P3] garage_settings_screen.dart:111 — error path uses `e.userMessage` directly instead of `errorMessage(e)` — §7 — fix: use helper.
- [P3] garage_settings_screen.dart:173 — "Add GST rate" silently no-ops on invalid/duplicate — §7 — fix: inline error in dialog for out-of-range/duplicate.
- [P3] garage_settings_screen.dart:148 — section titles `AppText.body`/w600 instead of title/w700 — §3 — fix: `AppText.title`, w700.
- [P1] add_expense_screen.dart:254 — edit-mode `copyWith(vendorName:, notes:)` can never clear fields (model `?? this.vendorName` expense.dart:105-106); emptied vendor/notes revert on save — §8.1 — fix: explicit-null handling (clearReceipt-style) so cleared optional fields actually clear.
- [P1] add_expense_screen.dart:265 — receipt upload/delete failure snackbar immediately replaced by success snackbar (hideCurrentSnackBar) — §7 — fix: track sync failure; show combined message or skip success snackbar when sync failed (same at :288).
- [P1] add_expense_screen.dart:377 — amount field bare `TextInputType.number` — §10 — fix: `numberWithOptions(decimal: true)`.
- [P3] add_expense_screen.dart:368 — brand red on non-action decoration (prefix icons :368/:381, date-row icons :409/:432, chip avatars :338) — §2 — fix: `palette.textSecondary`.
- [P3] add_expense_screen.dart:322 — form padding 20 (+80 spacer :503) off-token — §10 — fix: tokens.
- [P3] add_expense_screen.dart:225 — `showDatePicker(firstDate: 2020, initialDate: _expenseDate)` asserts if expense predates 2020 — §10 — fix: clamp initialDate into range.
- [P1] expenses_list_screen.dart:66 — delete confirm styles Delete red and Cancel plain (inverted) — §5 — fix: amber (`palette.partial`) Delete, red-text Cancel.
- [P1] expenses_list_screen.dart:73 — `deleteExpense` no try/catch — §7/§10 — fix: try/catch + error snackbar; keep dialog open on failure.
- [P1] expenses_list_screen.dart:77 — successful deletion reported as `SnackBarType.error` — §2 — fix: `SnackBarType.success`.
- [P1] expenses_list_screen.dart:265 — "Add First Expense" CTA ungated (FAB :120 gated) — §5 — fix: gate CTA.
- [P3] expenses_list_screen.dart:264 — search-miss generic text instead of interpolated term — §5 — fix: interpolate `_searchQuery` when set.
- [P1] price_list_screen.dart:146 — empty state has no CTA at all — §5 — fix: add "Add item" CTA wired to `_openForm()`.
- [P2] price_list_screen.dart:73 — destructive "Remove" theme-default red FilledButton — §5 — fix: amber Remove, red-text Keep.
- [P2] price_list_screen.dart:183 — unit price in brand red on info row — §2/§3 — fix: `palette.textPrimary`.
- [P2] price_list_screen.dart:107 — FAB (:107), row-tap edit (:162), delete (:189) rely solely on More-menu gate — §10 — fix: PermissionGate on FAB + ensurePermission before writes.
- [P3] price_list_screen.dart:81 — successful delete shows no success snackbar — §8.1 — fix: add success snackbar.
- [P3] price_list_screen.dart:148 — search-miss doesn't interpolate term — §5 — fix: interpolate `_query`.
- [P2] members_screen.dart:177 — Invite FAB visible without `staff.manage` (errors only on tap) — §5 — fix: PermissionGate on FAB.
- [P2] members_screen.dart:87 — `_invite` (:87) and `_revoke` (:116) catch only ApiException — §7 — fix: trailing generic catch + errorMessage snackbar.
- [P2] members_screen.dart:104 — destructive "Revoke" theme-default red FilledButton — §5 — fix: amber Revoke, red-text Keep.
- [P3] members_screen.dart:146 — hard-coded `Colors.amber` owner star — §2/§10 — fix: `palette.partial`.
- [P3] members_screen.dart:198 — empty/error states plain Text — §10 — fix: EmptyStateWidget (invite CTA when permitted); styled error row with Retry.
- [P3] members_screen.dart:85 — success snackbars default `info` type — §5 — fix: `SnackBarType.success`.

## Batch F — staff screens

- [P1] staff_list_screen.dart:95 — `deleteStaff` no try/catch; dialog pops + success snackbar fire unconditionally — §7 — fix: try/catch, `errorMessage(e)` error snackbar, keep dialog on failure.
- [P1] staff_list_screen.dart:83 — delete confirm names record but not cascade (attendance, advances), Cancel not red — §5 — fix: append "This will also remove their attendance and salary records."; red-text Cancel.
- [P1] staff_list_screen.dart:180 — "Mark All Present" mutates everyone with no `PermissionGate(attendanceManage)` — §5 — fix: wrap in PermissionGate.
- [P1] staff_list_screen.dart:181 — `markAllPresentToday` await uncaught; success snackbar unconditional — §7/§10 — fix: try/catch + error snackbar.
- [P1] staff_list_screen.dart:209 — empty-state CTA "Add First Employee" bypasses staff.manage gate (FAB L135 enforces) — §5/§10 — fix: wrap CTA in PermissionGate.
- [P1] staff_list_screen.dart:50 — actions sheet exposes Edit/Remove/attendance to any staff — §5 — fix: gate sheet tiles with PermissionGate per action.
- [P2] staff_list_screen.dart:102 — successful deletion shown as `SnackBarType.error` — §2 — fix: success/info.
- [P2] staff_list_screen.dart:29 — actions bottom sheet no `shape:` (square corners vs rounded-24 elsewhere) — §4 — fix: rounded top `AppDimens.radiusSheet`.
- [P3] staff_list_screen.dart:147 — hard-coded `EdgeInsets.all(16)` — §10 — fix: tokens.
- [P3] staff_list_screen.dart:193 — `borderRadius: 14` off-token — §10 — fix: `AppDimens.radiusButton`.
- [P2] add_staff_screen.dart:114 — error path bypasses `errorMessage(e)` — §7 — fix: use helper with generic fallback.
- [P2] add_staff_screen.dart:193 — salary field integer keyboard though salaries round-trip 2dp — §10 — fix: `numberWithOptions(decimal: true)`.
- [P3] add_staff_screen.dart:144 — `EdgeInsets.all(20)` off-token — §10 — fix: `AppDimens.paddingScreen`.
- [P3] add_staff_screen.dart:36 — no joining-date field; new staff silently get today; edit cannot correct — fix: optional date picker defaulting today, serialized YYYY-MM-DD.
- [P1] staff_attendance_screen.dart:324 — four mark-attendance buttons unguarded; no `attendance.manage` check — §5/§10 — fix: wrap action pad in PermissionGate.
- [P1] staff_attendance_screen.dart:53 — `markAttendance` no try/catch and no latch; rapid taps fire concurrent upserts; unconditional success snackbar — §7/§10 — fix: latch + try/catch + errorMessage.
- [P2] staff_attendance_screen.dart:33 — month change leaves `_selectedDate` in old month (action pad shows date with no highlighted cell) — §10 — fix: on month change reset `_selectedDate` sensibly.
- [P2] staff_attendance_screen.dart:313 — "Status: Present" chip informational in brand red — §2 — fix: `StatusBadge.fromAttendanceStatus`.
- [P3] staff_attendance_screen.dart:178 — Sundays use `palette.pending` amber decoratively (header :178, cells :257) — §2 — fix: `textMuted`/`textSecondary`.
- [P3] staff_attendance_screen.dart:232 — hard-coded `BorderRadius.circular(10)` (:238 too) — §10 — fix: `AppDimens.radiusTile`.
- [P3] staff_attendance_screen.dart:236 — `withOpacity` (:305 too) where standard is `withValues` — fix: `withValues(alpha: …)`.
- [P1] staff_salary_screen.dart:147 — "Give Advance" submit no latch; double-tap records advance twice (also duplicate expense) — §10 — fix: `_isSaving` disable until done.
- [P1] staff_salary_screen.dart:57 — `addSalaryAdvance` (two server mutations incl. expense) uncaught; fields clear + success snackbar unconditional — §7 — fix: try/catch + errorMessage; clear fields only on success.
- [P1] staff_salary_screen.dart:348 — advance/disburse actions (app-bar :186, disburse button :410) no `advances.manage` gate — §5 — fix: PermissionGate on both.
- [P2] staff_salary_screen.dart:213 — "MONTHLY PAYSLIP" overline (:213) and role chip (:246-257) informational in brand red — §2 — fix: `accent`/`textSecondary`.
- [P3] staff_salary_screen.dart:123 — advance amount integer keyboard — §10 — fix: `numberWithOptions(decimal: true)`.
- [P3] staff_salary_screen.dart:196 — `EdgeInsets.all(20)` off-token; `withOpacity` (:249) deprecated — §10 — fix: `AppDimens.paddingCard`; `withValues`.

## Batch G — providers + shared utils

- [P1] garage_provider.dart:981 — `disburseSalary` does `_salaryAdvances..clear()..addAll(settled)`, replacing the whole cache with only settled rows → other staff's advances vanish from memory until next load — §8 — fix: merge settled rows back (replace-by-id) instead of clear+addAll.
- [P1] garage_provider.dart:973 — `disburseSalary` silently returns when staff id unknown; screen reports success while nothing recorded — §7/§8.1 — fix: `throw Exception('Staff not found')` like cancelInvoice's not-found path.
- [P2] garage_provider.dart:951 — `addSalaryAdvance` commits advance then calls `addExpense` unguarded; failed follow-up shows error though advance persisted; retry duplicates — §8.1 — fix: wrap follow-up in try/catch and surface a side-effect warning (mirror addInvoice pattern :625-643).
- [P2] garage_provider.dart:731 — `quickServiceCheckout` wraps only `createInvoiceFromJobCard`; a `recordPayment` failure propagates raw after JC AND invoice committed, breaking retry contract (comment :18-20) — §8.1 — fix: extend try/catch to include recordPayment, carrying the committed invoice for retry.
- [P2] garage_provider.dart:555 — `convertQuotationToJobCard`: if status update fails after addJobCard succeeded, cache stays `approved` and retry creates a second JC — §7/§8.3 — fix: duplicate backstop (reject if a job card already references the quote/quotation number; refresh quotation state after failure).
- [P2] garage_provider.dart:466 — `addOrUpdateItemInJobCard`/`removeItemFromJobCard` (466-481) never check cached job status; stale screen can edit items on delivered/cancelled job — §7 — fix: throw when status is delivered/cancelled before repo call.
- [P3] garage_provider.dart:596 — dead code `(t.hour == close && t.minute > 0)` after round-up block — fix: drop.
- [P3] garage_provider.dart:954 — comment says "staff salaries/refreshments" but expense is `ExpenseCategory.miscellaneous` — fix: align comment with code.
- [P1] auth_provider.dart:250 — `refresh()` catches everything and calls `logout()`: a network timeout while renewing signs the user out entirely — §7 — fix: logout only for HTTP failures (ApiException with statusCode != 0); on network/timeout return false and keep session.
- [P2] auth_provider.dart:211 — `register()` builds client from `ApiConfig.baseUrl` while `login()` (:185) and `_raw()` (:298) use `_client.baseUrl` — fix: use `_client.baseUrl`.
- [P3] quantity_formatter.dart:7 — fractional quantities render "2.50" (trailing zero) — §6 — fix: strip trailing zero for fractions ("2.5"), integers unchanged.

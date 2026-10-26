# NT Garage — Full Screen Walkthrough (2026-10-18)

Every app screen was run live and recorded on an Android emulator
(`Medium_Phone_API_37.0`, 1080x2400, debug build) against the local Go
backend (`:8080`) with PostgreSQL 17, using a seeded demo account
(`demo@garage.local`) with realistic garage data: 4 customers, 4 vehicles,
5 staff, 5 job cards across all statuses, 3 estimates, 3 bills (paid /
pending / partial), payments, expenses, attendance, salary advances and a
spare-parts price list.

43 screenshots, one per screen/state. [Overview grid](all_screens.png).

## Auth

| # | Screen | Source |
|---|--------|--------|
| 01 | [Login](01_login.png) | [login_screen.dart](../../../lib/screens/auth/login_screen.dart) |
| 02 | [Forgot password](02_forgot_password.png) | [forgot_password_screen.dart](../../../lib/screens/auth/forgot_password_screen.dart) |
| 03 | [Verify email](03_verify_email.png) | [verify_email_screen.dart](../../../lib/screens/auth/verify_email_screen.dart) |
| 04 | [Create workshop account](04_register.png) | [register_screen.dart](../../../lib/screens/auth/register_screen.dart) |

Not captured: `reset_password_screen.dart` — only reachable via a emailed
reset token; the request entry point is screen 02.

## Dashboard (Home tab)

| # | Screen | Source |
|---|--------|--------|
| 05 | [Dashboard](05_dashboard.png) — trial banner, quick actions, today stats, open jobs | [dashboard_screen.dart](../../../lib/screens/dashboard/dashboard_screen.dart) |
| 05b | [Dashboard scrolled](05b_dashboard_scrolled.png) — estimates / bills / staff sections | same |

## Job cards (Jobs tab)

| # | Screen | Source |
|---|--------|--------|
| 06–06d | [Quick service wizard](06_quick_service_wizard.png): [customer](06_quick_service_wizard.png) → [vehicle](06b_wizard_vehicle_step.png) → [services](06c_wizard_items.png) → [review](06d_wizard_review.png) | [quick_service_wizard.dart](../../../lib/screens/workflow/quick_service_wizard.dart) |
| 07 | [New job card form](07_new_job_card.png) — complaints, inspection checklist, items, labour split | [create_job_card_screen.dart](../../../lib/screens/job_cards/create_job_card_screen.dart) |
| 08 | [Jobs list](08_jobs.png) — status filter chips, badges | [job_cards_list_screen.dart](../../../lib/screens/job_cards/job_cards_list_screen.dart) |
| 09 | [Job card detail](09_job_detail.png) — status stepper, parts & labour, late flag | [job_card_detail_screen.dart](../../../lib/screens/job_cards/job_card_detail_screen.dart) |
| 09b | [Change-status dialog](09b_job_status_dialog.png) | same |

## Customers (Clients tab)

| # | Screen | Source |
|---|--------|--------|
| 10 | [Clients list](10_clients.png) | [customers_list_screen.dart](../../../lib/screens/customers/customers_list_screen.dart) |
| 11 | [New client form](11_add_customer.png) | [add_customer_screen.dart](../../../lib/screens/customers/add_customer_screen.dart) |
| 12 | [Client profile](12_client_detail.png) — vehicles, job history, bills | [customer_detail_screen.dart](../../../lib/screens/customers/customer_detail_screen.dart) |
| 12b | [Add vehicle dialog](12b_add_vehicle_dialog.png) | [add_vehicle_dialog.dart](../../../lib/screens/vehicles/add_vehicle_dialog.dart) |
| 12c | [Vehicle edit dialog](12c_vehicle_detail.png) (opened from a client's vehicle row) | same |
| 34 | [Vehicle selection](34_vehicle_selection.png) — search icon on Clients tab, entry to quick job/bill | [vehicle_selection_screen.dart](../../../lib/screens/vehicles/vehicle_selection_screen.dart) |

## Invoices & payments (Bills tab)

| # | Screen | Source |
|---|--------|--------|
| 13 | [Bills list](13_bills.png) — billed/collected/due totals, status tabs | [invoices_list_screen.dart](../../../lib/screens/invoices/invoices_list_screen.dart) |
| 14 | [New bill form](14_create_invoice.png) | [create_invoice_screen.dart](../../../lib/screens/invoices/create_invoice_screen.dart) |
| 15 / 15b | [Bill preview](15_bill_preview.png) — [print layout + payment history](15b_bill_preview_scrolled.png), settled state | [invoice_preview_screen.dart](../../../lib/screens/invoices/invoice_preview_screen.dart) |
| 16 | [Record payment](16_payment_collection.png) — mode chips, quick amounts, balance due | [payment_collection_screen.dart](../../../lib/screens/payments/payment_collection_screen.dart) |

## More tab

| # | Screen | Source |
|---|--------|--------|
| 17 | [More menu](17_more.png) — garage header, Workshop/Garage/Account groups | [more_menu_screen.dart](../../../lib/screens/more/more_menu_screen.dart) |
| 18 | [Switch garage sheet](18_garage_switcher.png) | [garage_switcher.dart](../../../lib/screens/auth/garage_switcher.dart) |
| 19 | [Spare parts & price list](19_price_list.png) | [price_list_screen.dart](../../../lib/screens/catalog/price_list_screen.dart) |
| 20 | [Add price-list item dialog](20_add_catalog_item.png) | same |
| 21 | [Estimates list](21_estimates.png) | [quotations_list_screen.dart](../../../lib/screens/quotations/quotations_list_screen.dart) |
| 22 | [New estimate](22_new_estimate.png) | [create_quotation_screen.dart](../../../lib/screens/quotations/create_quotation_screen.dart) |
| 23 | [Estimate detail](23_estimate_detail.png) — accept / convert actions | [quotation_detail_screen.dart](../../../lib/screens/quotations/quotation_detail_screen.dart) |
| 24 | [Expenses list](24_expenses.png) — monthly total, category chips | [expenses_list_screen.dart](../../../lib/screens/expenses/expenses_list_screen.dart) |
| 25 | [Add expense](25_add_expense.png) | [add_expense_screen.dart](../../../lib/screens/expenses/add_expense_screen.dart) |
| 26 | [Staff list](26_staff.png) — per-staff attendance/payroll/edit actions | [staff_list_screen.dart](../../../lib/screens/staff/staff_list_screen.dart) |
| 27 | [Edit staff form](27_staff_edit.png) | [add_staff_screen.dart](../../../lib/screens/staff/add_staff_screen.dart) |
| 28 | [Staff attendance](28_staff_attendance.png) | [staff_attendance_screen.dart](../../../lib/screens/staff/staff_attendance_screen.dart) |
| 29 | [Staff payroll / salary](29_staff_payroll.png) | [staff_salary_screen.dart](../../../lib/screens/staff/staff_salary_screen.dart) |
| 30 | [Attendance & payroll overview](30_attendance_payroll.png) | [staff_attendance_screen.dart](../../../lib/screens/staff/staff_attendance_screen.dart) |
| 31 | [Garage settings](31_garage_settings.png) — GST, address, invoice prefix | [garage_settings_screen.dart](../../../lib/screens/settings/garage_settings_screen.dart) |
| 32 | [Subscription (billing)](32_subscription.png) — trial state, plan | [billing_screen.dart](../../../lib/screens/billing/billing_screen.dart) |
| 33 | [Team logins](33_team_logins.png) — members, permissions, invites | [members_screen.dart](../../../lib/screens/team/members_screen.dart) |
| 35 | [Sign-out confirmation](35_signout_dialog.png) | [more_menu_screen.dart](../../../lib/screens/more/more_menu_screen.dart) |

## Notes

- The add-maintenance-item sheet ([add_maintenance_screen.dart](../../../lib/screens/maintenance/add_maintenance_screen.dart)) is a sub-step of the job-card / bill / estimate item editors and was exercised inside the wizard (screen 06c flow) rather than captured standalone.
- Environment: backend `go run ./cmd/server` with `DATABASE_URL` to local Postgres 17; app debug build reaches it via `10.0.2.2:8080` (see [api_config.dart](../../../lib/data/api/api_config.dart)).
- Session persists across app restarts (shared_preferences token store); sign-out was cancelled, the demo account remains usable.

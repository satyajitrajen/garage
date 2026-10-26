# Apple in-app purchase setup

On iPhone, NT Garage sells the Pro plan as an App Store auto-renewing
subscription (App Review rule 3.1.1). Android and web keep Razorpay.

## How it works

1. The app buys a product with StoreKit, passing the garage id as the
   purchase's app account token.
2. The app sends the transaction id to `POST /api/garages/{id}/billing/apple`.
3. The server looks the subscription up with the App Store Server API, checks
   the bundle id, product and that the token matches the garage, then marks
   the garage `active` with `provider = apple`.
4. Apple sends renewals, billing problems, expiry and refunds to
   `POST /api/billing/webhooks/apple`. The server uses the notification only
   to find the subscription and re-reads its state from Apple.

Apple subscriptions are cancelled by the user in their Apple ID settings, so
the app shows **Manage** instead of **Cancel subscription** for them.

## 1. App Store Connect: products

App Store Connect → your app → **Monetization → Subscriptions**:

1. Create a subscription group, e.g. `NT Garage Pro`.
2. Add two auto-renewable subscriptions with these product ids:

   | Product id | Duration |
   |---|---|
   | `com.nexory.garage.pro.monthly` | 1 month |
   | `com.nexory.garage.pro.yearly` | 1 year |

3. For each, set the price, a display name and description, and a review
   screenshot of the Subscription screen.
4. Accept the **Paid Apps Agreement** and fill in banking and tax under
   **Business**. Products don't load until it is active.

Different ids? Set `APPLE_PRODUCT_MONTHLY` / `APPLE_PRODUCT_YEARLY` on the
backend; the app reads them from the billing response.

## 2. App Store Connect: API key

Users and Access → **Integrations → In-App Purchase** → generate a key.
Download the `.p8` file (only offered once) and note the **Key ID** and the
**Issuer ID** shown on that page.

## 3. Backend environment

| Variable | Value |
|---|---|
| `APPLE_IAP_ISSUER_ID` | Issuer ID |
| `APPLE_IAP_KEY_ID` | Key ID |
| `APPLE_IAP_PRIVATE_KEY` | Contents of the `.p8` file. Newlines may be written as `\n`. |
| `APPLE_BUNDLE_ID` | Optional, defaults to `com.nexory.garage` |

Without `APPLE_IAP_PRIVATE_KEY` the verify endpoint and webhook return 503.

## 4. Server notifications

App Store Connect → your app → **App Information → App Store Server
Notifications**: set both the production and sandbox URL to

```
https://garage.nexorytechnologies.com/api/billing/webhooks/apple
```

and choose **Version 2**.

## 5. Xcode

Open `ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities** →
add **In-App Purchase**.

## 6. Testing

- Create a sandbox tester in Users and Access → Sandbox.
- On a real iPhone (or TestFlight build), sign in with the sandbox tester when
  the purchase sheet asks. Sandbox renewals are fast (a month ≈ 5 minutes).
- The server tries Apple's production API first and falls back to sandbox,
  so App Review purchases work against the production backend.

## App Review notes

- The Subscription screen shows Apple's localized prices, the auto-renew
  terms, and links to `/terms` and `/privacy`, which Apple requires.
- **Restore purchases** is on the same screen.
- Give the reviewer a demo owner account in the review notes; only owners can
  buy.

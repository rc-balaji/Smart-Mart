# Smark Mart — Flutter Customer App

Fresh Flutter customer application for the Smark Mart workflow.

## Production flow

1. App starts and Firebase signs the device in anonymously in the background.
2. Customer scans a trolley QR.
3. Customer scans products or enters a product code/barcode manually. Each scan appears in the cart immediately while the app serializes product writes to the backend in the background; failed scans can be retried or removed. The server remains authoritative for product details and prices.
4. Cart supports quantity + / - and removal by setting quantity to zero.
5. Customer confirms the cart, then chooses Cash / UPI / QR in a payment sheet that can be minimized and resumed.
6. Backend creates a payment-pending order.
7. Admin confirms payment on the separate Next.js web console.
8. Dispatch validates the paid order and releases the trolley after return.

## Firebase

Android application identity is:

`com.hh.smart_mart`

Firebase project configured in `lib/core/firebase_options.dart`:

`smart-mart-82a7a`

Anonymous Authentication must be enabled in Firebase Authentication.

This app intentionally initializes Firebase with explicit Android `FirebaseOptions`. It does not depend on the Google Services Gradle task, so the previous `processReleaseGoogleServices` package mismatch cannot block the build.

## Backend

The production API base URL defaults to `https://smart-mart-v1.vercel.app` and can be overridden with the `API_BASE_URL` Dart define. The app talks only to the Next.js backend route:

`POST /api/customer/action`

The backend verifies the Firebase ID token and performs Firestore transactions server-side. The mobile app never writes product prices, order totals, trolley state, or payments directly into Firestore.

### Trolley change and cancellation actions

The mobile API supports `STATE`, `CLAIM_TROLLEY`, `ADD_PRODUCT`, `CHANGE_QTY`, `CHECKOUT`, `CANCEL_SESSION`, `SWITCH_TROLLEY`, and `CANCEL_ORDER`. Every action verifies the Firebase user owns the affected active session/order and updates related records in one Firestore transaction.

| Action | Payload | Required behavior |
| --- | --- | --- |
| `CANCEL_SESSION` | `{ "reasonCode": "CUSTOMER_CANCELLED" }` | Accept reason codes `CUSTOMER_CANCELLED`, `TROLLEY_DAMAGED`, or `CUSTOMER_NEEDS_TO_LEAVE`. Cancel an active, not-yet-checked-out session and preserve its cart as an audit record. Create a `RETURN_PENDING` record for its trolley; do not make the trolley claimable until staff confirms physical return. |
| `SWITCH_TROLLEY` | `{ "newTrolleyCode": "...", "reasonCode": "TROLLEY_DAMAGED" }` | Accept reason codes `TROLLEY_DAMAGED` or `CUSTOMER_CHANGED_TROLLEY`. Atomically verify the old session and the new trolley, keep the existing cart, assign the session to the available new trolley, and mark the old trolley `RETURN_PENDING`. The app must ask the customer to transfer the physical items before confirming. On any validation/conflict failure, change neither trolley nor session. |
| `CANCEL_ORDER` | `{ "orderId": "...", "reasonCode": "CUSTOMER_CANCELLED" }` | Accept reason codes `CUSTOMER_CANCELLED`, `TROLLEY_DAMAGED`, or `CUSTOMER_NEEDS_TO_LEAVE`. Cancel only an order that is still unpaid and in a cancellable status. Mark its trolley `RETURN_PENDING`; never release it based only on the customer request. Reject paid/processing orders with a stable error code so the app can direct the customer to staff for refund/cancellation. |

The admin/dispatch side must provide a staff-only return confirmation that changes a returned, serviceable trolley from `RETURN_PENDING` to `AVAILABLE`, or a damaged trolley to `MAINTENANCE`. It must verify the trolley/session association and be idempotent. Customer actions must never be able to confirm their own trolley return.

All three customer actions should return the normal `data` shopping-state shape, with `session: null` and an empty cart after cancellation, or the active session/cart after a successful switch. Extend that shape with the customer's outstanding `trolleyReturn` (`trolleyId`, `status`, and `reasonCode`) so the app can continue showing “return trolley to staff” after a refresh. Use stable errors such as `SESSION_NOT_CANCELLABLE`, `TROLLEY_UNAVAILABLE`, `ORDER_NOT_CANCELLABLE`, and `PAYMENT_ALREADY_CONFIRMED`; never report a cancellation as successful unless the transaction committed.

The app displays cancellation and trolley-switch controls using these server actions. Showing success depends on the server confirming its transaction; trolley check-in remains staff-only.

## GitHub Actions APK build

The release build defaults to the production API URL. Optionally override it with this repository secret:

`API_BASE_URL`

Production value:

`https://smart-mart-v1.vercel.app`

Then open:

**GitHub → Actions → Build Flutter Android Release → Run workflow**

The workflow generates the Android project with package `com.hh.smart_mart`, adds release Internet/Camera permissions, runs analysis + tests, creates the launcher icon, builds the release APK, and uploads `Smark-Mart-Android-Release` as an artifact.

## Local build

With Flutter installed:

```bash
rm -rf android /tmp/smark_mart_flutter
flutter create /tmp/smark_mart_flutter --platforms=android --org com.hh --project-name smart_mart
cp -R /tmp/smark_mart_flutter/android ./android
python3 scripts/prepare_android.py
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://smart-mart-v1.vercel.app
```

## Important

Do not commit service-account JSON or Firebase Admin private keys into this mobile repository. Firebase Admin credentials belong only to the Vercel/Next.js backend.

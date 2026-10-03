# Smark Mart — Flutter Customer App

Fresh Flutter customer application for the Smark Mart workflow.

## Production flow

1. App starts and Firebase signs the device in anonymously in the background.
2. Customer scans a trolley QR.
3. Customer scans products or enters a product code/barcode manually.
4. Cart supports quantity + / - and removal by setting quantity to zero.
5. Checkout supports Cash / UPI / QR.
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

The app talks only to the Next.js backend route:

`POST /api/customer/action`

The backend verifies the Firebase ID token and performs Firestore transactions server-side. The mobile app never writes product prices, order totals, trolley state, or payments directly into Firestore.

## GitHub Actions APK build

Create one repository secret:

`API_BASE_URL`

Value example:

`https://your-smark-mart.vercel.app`

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
flutter build apk --release --dart-define=API_BASE_URL=https://your-domain.vercel.app
```

## Important

Do not commit service-account JSON or Firebase Admin private keys into this mobile repository. Firebase Admin credentials belong only to the Vercel/Next.js backend.

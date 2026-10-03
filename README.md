# Smark Mart Mobile

End-user Android app. No signup form. Firebase Anonymous Auth is created automatically in the background.

## Firebase setup later
1. Firebase Console -> Authentication -> Sign-in method -> enable Anonymous.
2. Create a Firebase Web App and copy its public config into `.env` (see `.env.example`).
3. Set `EXPO_PUBLIC_API_BASE_URL` to the deployed Next.js web/backend URL.

## Local run
```bash
npm install
cp .env.example .env
npm start
```

## GitHub Actions APK
Push this project to GitHub and add repository Actions secrets matching `.env.example`. Run **Build Android APK**. The workflow generates the Android project and uploads the release APK artifact.

## Customer flow
Scan trolley -> scan products -> adjust quantity -> checkout Cash/UPI/QR -> order status -> admin confirms -> dispatch.

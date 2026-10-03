# Firebase values to add later

Enable **Anonymous** provider in Firebase Authentication.

Create `.env` from `.env.example` and add the Firebase Web App public config plus your deployed Next.js backend URL.

For GitHub Actions, add the same names as repository secrets:
- EXPO_PUBLIC_API_BASE_URL
- EXPO_PUBLIC_FIREBASE_API_KEY
- EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN
- EXPO_PUBLIC_FIREBASE_PROJECT_ID
- EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET
- EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID
- EXPO_PUBLIC_FIREBASE_APP_ID

Then run the **Build Android APK** workflow.

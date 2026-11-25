# Sign in with Google

"Continue with Google" on the login page opens Google's own account picker
(Credential Manager on Android, the GoogleSignIn SDK on iOS, both through
`google_sign_in` 7.x). The app sends the resulting **ID token** to
`POST /api/auth/google`. The backend verifies it with `google-auth-library` and
answers with the same `{ ...user, token }` as an email login, so the session
is Kubo's own token, kept in flutter_secure_storage (Keychain or Keystore).

Which account a Google sign-in opens (`backend/src/services/google-auth.service.ts`):

1. The account already linked to that Google account, looked up by Google's
   `sub`, stored in `users.google_sub` separately from email.
2. Otherwise, a Google email that is **not verified** is refused (403).
3. An existing account with the same email gets linked and opened, but only
   when Google is authoritative for the address: a verified `@gmail.com`, or a
   Workspace account whose `hd` domain matches the email. For any other
   address (a Google account registered with a Yahoo email, say) the sign-in
   is refused (409) and the user logs in with their password instead. It is
   also refused if the account is already linked to a *different* Google
   account.
4. Otherwise, a new account is created. It has no password and no contact
   number or address; the user adds those in Edit Profile.

## 1. Google Cloud Console

Use one project for the app. All three OAuth clients below must be in the
**same project**.

1. **APIs & Services → OAuth consent screen**
   - User type: **External**
   - App name (Kubo), user support email, developer contact email
   - Scopes: the defaults only (`openid`, `email`, `profile`)
   - While the publishing status is *Testing*, only the listed **test users**
     can sign in. Add the Google accounts you test with, or **Publish app**.
     Non-sensitive scopes like these don't need Google's verification.
2. **Credentials → Create credentials → OAuth client ID**, three times:

| Client type | Fill in | Where its ID goes |
|---|---|---|
| **Web application** | Name only. No origins or redirect URIs needed | `backend/.env` → `GOOGLE_CLIENT_IDS`, **and** `frontend/dart_defines.json` → `GOOGLE_SERVER_CLIENT_ID` |
| **Android** | Package name `com.example.frontend` + one SHA-1 (see §2). Create **one Android client per SHA-1** | Nowhere in the code. Google matches the app by package name + signing certificate |
| **iOS** | Bundle ID `com.example.frontend` | `frontend/dart_defines.json` → `GOOGLE_IOS_CLIENT_ID`, and reversed in `ios/Flutter/GoogleSignIn.xcconfig` (see §3) |

Why the Web client matters: both phones ask Google for an ID token *for the
Web client* (`serverClientId`). So the token's `aud` is the Web client ID, and
that is the ID the backend has to accept. Putting the Android or iOS client ID
in `GOOGLE_CLIENT_IDS` makes every sign-in fail with an audience mismatch in
the backend log.

## 2. Android

- Package name: `com.example.frontend` (`android/app/build.gradle.kts`, `applicationId`).
- `minSdk`: 24, Flutter's default. No `google-services.json` is needed,
  because the Web client ID is passed in from Dart.
- Register an Android OAuth client for **every key that signs a build people
  run**. A missing one is the usual cause of a failed sign-in. With Credential
  Manager it often shows up as the picker closing by itself, or as
  `[28444] Developer console is not set up correctly` / `DEVELOPER_ERROR` (10)
  in the debug log.

| Key | How to get its SHA-1 | Needed for |
|---|---|---|
| **Debug keystore**, one per developer machine (`~/.android/debug.keystore`) | `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`, or `cd frontend/android && ./gradlew signingReport` | `flutter run` and every debug build on that machine |
| **Release (upload) keystore** | `keytool -list -v -keystore <your-upload-keystore.jks> -alias <alias>` | `flutter build apk/appbundle --release` installed directly |
| **Play App Signing key** | Play Console → your app → *Test and release → App integrity → App signing* → "App signing key certificate" SHA-1 | Installs from Google Play, which Google re-signs with this key |

Current state of this repo: `release` is signed with the **debug key**
(`signingConfig = signingConfigs.getByName("debug")`), so today a release build
on a given machine uses that machine's debug SHA-1. Before publishing:

1. Pick a real application ID. Play rejects `com.example.*`. Change
   `applicationId`/`namespace` and the iOS bundle ID, then create new Android
   and iOS OAuth clients for them. A new ID installs as a separate app, and
   existing installs lose their saved login.
2. Create an upload keystore, sign `release` with it, and register its SHA-1.
3. After the first Play upload, register the Play App Signing SHA-1 as well.

## 3. iOS

- Bundle ID: `com.example.frontend` (Runner target). It must match the iOS
  OAuth client.
- Deployment target 12.0 or later (already 12.0).
- The iOS client ID is passed to `initialize()` from `GOOGLE_IOS_CLIENT_ID`, so
  Info.plist needs no `GIDClientID`. Info.plist needs only the URL scheme,
  already added as `$(GOOGLE_REVERSED_CLIENT_ID)`:
  ```
  cp ios/Flutter/GoogleSignIn.xcconfig.example ios/Flutter/GoogleSignIn.xcconfig
  ```
  Then set `GOOGLE_REVERSED_CLIENT_ID` to the iOS client ID with its parts
  reversed. For example, `123-abc.apps.googleusercontent.com` becomes
  `com.googleusercontent.apps.123-abc`. That file is gitignored.
- Don't add `GoogleService-Info.plist` to the project.
- App Store: apps that offer Google sign-in must also offer **Sign in with
  Apple** (App Review Guideline 4.8). That isn't built yet.

## 4. Configuration values

| Where | Name | Value |
|---|---|---|
| `backend/.env` | `GOOGLE_CLIENT_IDS` | Web client ID. Comma-separate several (staging and production). Empty turns Google sign-in off (503) |
| `frontend/dart_defines.json` | `GOOGLE_SERVER_CLIENT_ID` | The same Web client ID |
| `frontend/dart_defines.json` | `GOOGLE_IOS_CLIENT_ID` | iOS client ID |
| `frontend/dart_defines.json` | `API_BASE_URL` | Optional, and not in the example. Leave it out to use each platform's default; add it only to point at another server (for example a phone using your LAN IP) |
| `frontend/ios/Flutter/GoogleSignIn.xcconfig` | `GOOGLE_REVERSED_CLIENT_ID` | Reversed iOS client ID |

Run and build with the file:

```
cp frontend/dart_defines.example.json frontend/dart_defines.json   # then edit
cd frontend
flutter run --dart-define-from-file=dart_defines.json
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

A build without `GOOGLE_SERVER_CLIENT_ID` still runs. The Google button then
says sign-in isn't set up.

Database: `npm run db:migrate` applies `009_google_sign_in.sql`. It adds
`users.google_sub` (with a partial unique index) and makes `anonymize_user()`
clear it, so a deleted account can't be signed back into.

## 5. Manual test plan (real devices)

Run each case on one Android phone and one iPhone, signed in to the backend
you're testing. Keep the backend log open: a rejected token is logged there
with the reason.

| # | Case | Steps | Expected |
|---|---|---|---|
| 1 | New user | Google account with no Kubo account → Continue with Google → pick it | Spinner on the button; lands on the app shell. Profile shows the Google name and email. `users` row has `google_sub` set, `password_hash = ''`, `contact_number = ''` |
| 2 | Returning user | Sign out → Continue with Google → same account | Same `user_id` as case 1. No new row |
| 3 | Existing email user | Register with email + password using a Gmail address → sign out → Continue with Google with that Gmail account | Opens the **same** account (same `user_id`, listings intact). `google_sub` now set. Email + password login still works |
| 4 | Linked to another Google account | In SQL, set case 3's `google_sub` to `'other'` → Continue with Google | Message: "already linked to a different Google account". Stays on login |
| 5 | Cancel | Continue with Google → back out of the picker (back button, or swipe down on iOS) | No message, back on login, button tappable again |
| 6 | Double tap | Tap the Google button twice quickly | One picker; the button is disabled with a spinner until it finishes |
| 7 | Sign out, then sign in | Profile → log out → Continue with Google | The account picker appears (it doesn't silently reuse the last account) |
| 8 | Expired session | Change `AUTH_SECRET` on the backend → reopen the app | "Your session has expired", then back to login. Continue with Google shows the picker |
| 9 | No network | Airplane mode → Continue with Google | A friendly message, no crash. Pick an account first, then go offline before the backend call: "Cannot reach the Kubo server..." |
| 10 | Backend off / not configured | Clear `GOOGLE_CLIENT_IDS`, restart → Continue with Google | "Google sign-in is not available right now" |
| 11 | No Google account (Android) | Phone with no Google account signed in → Continue with Google | "There is no Google account on this device..." or Android's own add-account prompt |
| 12 | Play Services (Android) | Emulator image without Google Play, or Play Services disabled | "Google sign-in needs an up-to-date Google Play services..." |
| 13 | Deleted account | Delete the account from case 1 → Continue with Google with the same Google account | A **new** account is created; the old one stays anonymized |
| 14 | **Release build** | `flutter build apk --release --dart-define-from-file=dart_defines.json` → install with `adb install` → cases 1, 2, 5, 7. Then the same from a Play internal-testing track (Play App Signing key) | Same as debug. If the picker closes by itself or you see 28444/10, that build's SHA-1 isn't registered (§2) |
| 15 | iOS release | Archive in Xcode (Release) → TestFlight → cases 1, 2, 5, 7 | Same as debug. A crash on tap means the URL scheme is missing (§3) |

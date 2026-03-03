# Firebase Configuration Setup

This app requires Firebase configuration files that contain sensitive API keys. These files are not included in the repository for security reasons.

## Required Files

### 1. Android - `android/app/google-services.json`

Download from Firebase Console:
1. Go to https://console.firebase.google.com/
2. Select your project
3. Go to Project Settings (gear icon)
4. Under "Your apps" section, select Android app
5. Download `google-services.json`
6. Place it in `android/app/google-services.json`

### 2. iOS - `ios/Runner/GoogleService-Info.plist`

Download from Firebase Console:
1. Go to https://console.firebase.google.com/
2. Select your project
3. Go to Project Settings (gear icon)
4. Under "Your apps" section, select iOS app
5. Download `GoogleService-Info.plist`
6. Place it in `ios/Runner/GoogleService-Info.plist`

### 3. macOS - `macos/Runner/GoogleService-Info.plist`

Use the same file as iOS or download separately:
1. Copy from iOS: `cp ios/Runner/GoogleService-Info.plist macos/Runner/`
2. Or download separately from Firebase Console for macOS app

### 4. Web - `web/firebase-config.js`

Create from example:
1. Copy the example file: `cp web/firebase-config.example.js web/firebase-config.js`
2. Get your web app config from Firebase Console:
   - Go to Project Settings → Your apps → Web app
   - Copy the config values
3. Replace the placeholder values in `web/firebase-config.js`

### 5. Firebase CLI - `.firebaserc`

Create this file in the project root:
```json
{
  "projects": {
    "default": "YOUR_PROJECT_ID"
  }
}
```

Replace `YOUR_PROJECT_ID` with your Firebase project ID.

## Google Sign-In Configuration

### Web Client ID

Update the following files with your Web Client ID from Google Cloud Console:

1. **web/index.html** - Update the meta tag:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```

2. **lib/services/auth_service.dart** - Update the clientId:
   ```dart
   final GoogleSignIn _googleSignIn = GoogleSignIn(
     clientId: kIsWeb
         ? 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
         : null,
   );
   ```

3. **lib/main.dart** - Firebase web configuration is already there, verify the values

### iOS URL Scheme

Update `ios/Runner/Info.plist` with your REVERSED_CLIENT_ID:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

### Android SHA-1 Certificate

Add your SHA-1 certificate fingerprint to Firebase Console:
1. Get SHA-1: `cd android && ./gradlew signingReport`
2. Copy the SHA-1 fingerprint
3. Add it in Firebase Console → Project Settings → Your apps → Android app

### OAuth Redirect URIs (for Web)

Add these to Google Cloud Console → Credentials → OAuth 2.0 Client IDs:
```
https://YOUR_PROJECT_ID.firebaseapp.com/__/auth/handler
https://YOUR_PROJECT_ID.web.app/__/auth/handler
```

## Security

⚠️ **Never commit these files to version control:**
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `web/firebase-config.js`
- `.firebaserc`

These files are already listed in `.gitignore` to prevent accidental commits.

## Firestore Security Rules

Update Firestore security rules in Firebase Console:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Build Commands

After setting up configuration:

```bash
# Web
flutter build web --release
firebase deploy --only hosting

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

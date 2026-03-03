# EasyExpense - Personal Expense Tracker

একটি Flutter-based personal expense tracking অ্যাপ যা Firebase cloud backup সহ local এবং online ডেটা storage সাপোর্ট করে।

## Features

✅ **Multiple Persons**: একাধিক ব্যক্তির জন্য আলাদা আলাদা expense track করুন
✅ **Deposit & Expense**: টাকা জমা এবং খরচ দুটোই ট্র্যাক করুন
✅ **Real-time Balance**: প্রতিটি ব্যক্তির real-time balance দেখুন
✅ **Transaction History**: সব লেনদেনের বিস্তারিত ইতিহাস
✅ **Local Storage**: Offline support এর জন্য local storage
✅ **Cloud Backup**: Firebase এর মাধ্যমে automatic cloud backup
✅ **Data Sync**: Multiple device এ data sync হয়

## Firebase Setup (Production এর জন্য)

### ১. Firebase Project তৈরি করুন

1. [Firebase Console](https://console.firebase.google.com/) এ যান
2. "Create a project" ক্লিক করুন
3. Project name দিন (যেমন: "easy-expense")
4. Google Analytics enable করুন (optional)

### ২. Web App যোগ করুন

1. Project overview থেকে "Web" icon ক্লিক করুন
2. App nickname দিন (যেমন: "EasyExpense Web")
3. Firebase config object copy করুন

### ৩. Firestore Database Setup

1. Firebase console এ "Firestore Database" যান
2. "Create database" ক্লিক করুন
3. Start in "test mode" select করুন
4. Location select করুন

### ৪. Authentication Setup

1. Firebase console এ "Authentication" যান
2. "Get started" ক্লিক করুন
3. "Sign-in method" tab এ যান
4. **"Google"** provider enable করুন
   - Enable toggle করুন
   - Project support email select করুন (আপনার email)
   - Save করুন
5. "Anonymous" enable করুন (optional, testing এর জন্য)

### ৫. Google Sign-In iOS Configuration (iOS এ চালাতে হলে)

1. Firebase Console → Project Settings → iOS app select করুন
2. Scroll down করে "OAuth client ID" খুঁজুন
3. এই ID copy করুন (এটা REVERSED_CLIENT_ID)
4. `ios/Runner/GoogleService-Info.plist` ফাইলে যান
5. `YOUR-CLIENT-ID` replace করুন actual client ID দিয়ে:
   ```xml
   <key>REVERSED_CLIENT_ID</key>
   <string>com.googleusercontent.apps.YOUR-ACTUAL-CLIENT-ID-HERE</string>
   ```
6. `ios/Runner/Info.plist` ফাইলেও same ID দিয়ে replace করুন:
   ```xml
   <string>com.googleusercontent.apps.YOUR-ACTUAL-CLIENT-ID-HERE</string>
   ```

### ৬. Google Sign-In Android Configuration

Android এর জন্য `android/app/google-services.json` ফাইল automatically configure হয়ে যায়।তবে SHA-1 certificate fingerprint add করতে হতে পারে:

1. Terminal এ run করুন:
   ```bash
   cd android
   ./gradlew signingReport
   ```
2. SHA-1 fingerprint copy করুন
3. Firebase Console → Project Settings → Your Android app
4. Scroll down করে "Add fingerprint" এ SHA-1 add করুন

### ৭. Config Update করুন

`web/firebase-config.js` ফাইলে আপনার Firebase config বসান:

\`\`\`javascript
const firebaseConfig = {
apiKey: "your-actual-api-key",
authDomain: "your-project.firebaseapp.com",
projectId: "your-actual-project-id",
storageBucket: "your-project.appspot.com",
messagingSenderId: "your-sender-id",
appId: "your-app-id"
};
\`\`\`

## Security Rules

Firestore security rules:

\`\`\`javascript
rules_version = '2';
service cloud.firestore {
match /databases/{database}/documents {
match /users/{userId} {
allow read, write: if request.auth != null && request.auth.uid == userId;
}
}
}
\`\`\`

## How It Works

### Data Flow

1. **App Start**: Local storage থেকে data load হয়
2. **Firebase Sync**: Background এ Firebase থেকে latest data fetch হয়
3. **Automatic Backup**: যেকোনো change automatic Firebase এ save হয়
4. **Offline Support**: Internet না থাকলে local storage ব্যবহার হয়

### Data Structure

\`\`\`json
{
"persons": [
{
"name": "John Doe",
"transactions": [
{
"amount": 1000,
"type": 0, // 0 = deposit, 1 = expense
"date": 1643723400000,
"note": "Salary"
}
]
}
],
"lastUpdated": "Firebase server timestamp"
}
\`\`\`

## Development

### Prerequisites

- Flutter SDK
- Chrome browser (for web development)
- Firebase account
- Xcode (for iOS development)
- Android Studio (for Android development)

### Running the App

\`\`\`bash
flutter pub get
flutter run -d chrome # For web
flutter run # For mobile (iOS/Android)
\`\`\`

### Testing Google Sign-In

1. **Web**: Chrome browser এ সরাসরি কাজ করবে
2. **Android**: Emulator বা real device এ test করুন
3. **iOS**: Real device এ test করতে হবে (Simulator এ Google Sign-in কাজ নাও করতে পারে)

### Troubleshooting

#### iOS এ Google Sign-in কাজ করছে না

- `ios/Runner/GoogleService-Info.plist` এ `REVERSED_CLIENT_ID` সঠিক আছে কিনা check করুন
- `ios/Runner/Info.plist` এ `CFBundleURLSchemes` সঠিক আছে কিনা check করুন
- Firebase Console এ iOS app properly configured আছে কিনা verify করুন

#### Android এ Google Sign-in কাজ করছে না

- SHA-1 certificate fingerprint Firebase এ add করেছেন কিনা check করুন
- `android/app/google-services.json` ফাইল latest version আছে কিনা check করুন

#### Web এ Google Sign-in কাজ করছে না

- Firebase Console এ authorized domains add করা আছে কিনা check করুন
- `lib/auth_service.dart` এ Web client ID সঠিক আছে কিনা verify করুন

### Building for Production

\`\`\`bash
flutter build web
\`\`\`

## Support

যেকোনো সমস্যার জন্য GitHub issue তৈরি করুন।

---

**Note**: এই অ্যাপ demo Firebase config দিয়ে চালু হবে, কিন্তু production এ নিজের Firebase project setup করতে হবে।

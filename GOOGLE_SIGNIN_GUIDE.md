# Google Sign-In Setup Guide / গুগল সাইন-ইন সেটআপ গাইড

## ✅ যা যা ইতিমধ্যে হয়ে গেছে (Already Done)

আপনার app এ Google Sign-in এর জন্য সব code implementation ইতিমধ্যে complete আছে:

1. ✅ `google_sign_in` package installed
2. ✅ `AuthService` class implemented with Google Sign-in
3. ✅ Login screen তৈরি হয়ে গেছে "Continue with Google" button সহ
4. ✅ Firebase authentication integrated
5. ✅ iOS configuration files updated
6. ✅ Android configuration present

## 🔧 এখন তোমার যা করতে হবে (What You Need To Do)

### ধাপ ১: Firebase Console এ Google Sign-in Enable করো

1. [Firebase Console](https://console.firebase.google.com) এ যাও
2. তোমার project **"easyexpens"** select করো
3. বাম sidebar থেকে **Authentication** এ ক্লিক করো
4. **Sign-in method** tab এ যাও
5. **Google** provider খুঁজে বের করো এবং click করো
6. **Enable** toggle করো
7. **Project support email** select করো (তোমার email)
8. **Save** করো

### ধাপ ২: iOS এর জন্য REVERSED_CLIENT_ID নাও (শুধু iOS এ চালাতে চাইলে)

1. Firebase Console এ থাকা অবস্থায়
2. **Project Settings** (gear icon) এ ক্লিক করো
3. নিচে scroll করে **Your apps** section এ যাও
4. iOS app select করো (bundle ID: com.example.expense)
5. **OAuth client ID** খুঁজে copy করো (এটা দেখতে এরকম: `950417547925-xxxxxxx.apps.googleusercontent.com`)

### ধাপ ৩: iOS Configuration Files Update করো

#### File 1: `ios/Runner/GoogleService-Info.plist`

এই line টা খুঁজে বের করো:

```xml
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
```

`YOUR-CLIENT-ID` replace করো Firebase থেকে copy করা client ID দিয়ে।

উদাহরণ:

```xml
<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.950417547925-abc123xyz456</string>
```

#### File 2: `ios/Runner/Info.plist`

এই line টা খুঁজে বের করো:

```xml
<string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
```

Same ID দিয়ে replace করো।

### ধাপ ৪: Android এর জন্য SHA-1 Certificate Add করো

1. Terminal open করো
2. Project directory তে যাও: `cd /Volumes/Volume1/Project/easy_expense`
3. এই command run করো:
   ```bash
   cd android
   ./gradlew signingReport
   ```
4. Output থেকে **SHA-1** fingerprint copy করো
5. Firebase Console → Project Settings → Your Android app
6. **Add fingerprint** এ click করে SHA-1 paste করো

### ধাপ ৫: Test করো

#### Web এ test করতে:

```bash
flutter run -d chrome
```

#### Android এ test করতে:

```bash
flutter run
```

(Android device বা emulator connected থাকতে হবে)

#### iOS এ test করতে:

```bash
flutter run
```

(iOS device connected থাকতে হবে - Simulator এ Google Sign-in কাজ নাও করতে পারে)

## 🎨 Optional: Google Logo Add করো

1. [Google Branding Guidelines](https://developers.google.com/identity/branding-guidelines) থেকে official logo download করো
2. `assets/` folder এ `google_logo.png` নামে save করো (24x24 বা 48x48 pixels)

## 📱 App এর Features

তোমার app তে এখন এই features আছে:

- ✅ **Google Sign-in**: "Continue with Google" button দিয়ে instant login
- ✅ **Anonymous Sign-in**: Guest হিসেবে login করার option
- ✅ **Auto Sign-in**: একবার login করলে পরের বার automatically login হবে
- ✅ **Sign-out**: User profile থেকে logout করার option
- ✅ **User Info**: User এর name, email, photo display হবে

## 🐛 Troubleshooting

### Problem: iOS এ "Sign in failed" error

**Solution**:

- `REVERSED_CLIENT_ID` সঠিকভাবে add করেছো কিনা check করো
- iOS app Firebase console এ properly registered আছে কিনা verify করো

### Problem: Android এ "Sign in failed" error

**Solution**:

- SHA-1 certificate fingerprint Firebase এ add করেছো কিনা check করো
- `android/app/google-services.json` file latest version আছে কিনা check করো

### Problem: Web এ "popup_closed_by_user" error

**Solution**: এটা normal - user popup close করে দিলে এই error আসে

## 📚 আরো তথ্যের জন্য

- বিস্তারিত setup guide: [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
- Code documentation: lib/ folder এর files গুলো দেখো
- Firebase documentation: https://firebase.google.com/docs/auth

---

**সব setup complete হলে তোমার app এ Google Sign-in পুরোপুরি কাজ করবে! 🎉**

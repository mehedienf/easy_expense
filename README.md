# easyexpense

# web release and hosting:

flutter build web --release
firebase deploy --only hosting

# set icon

flutter pub run flutter_launcher_icons

# for release:

flutter build apk --release --split-per-abi
flutter build apk --release

# Background Sync (Android only)

# To ensure background sync works properly:

# 1. Enable background sync in Settings tab

# 2. Grant notification permission when prompted

# 3. Disable battery optimization for this app:

# - Open Android Settings

# - Apps → DenaPaona → Battery → Unrestricted

# 4. Background sync runs:

# - First sync: 30 seconds after app is closed

# - Then every 15 minutes automatically

# - Requires internet connection

# Debug background sync logs:

adb logcat | grep BG_SYNC

# from project root

flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf android/.gradle
rm -rf build .dart_tool

# clear problematic caches

rm -rf ~/.gradle/caches/8.4/scripts
rm -rf ~/.gradle/caches/\*/scripts
rm -rf ~/.pub-cache/hosted/pub.dev/firebase_core-4.5.0
dart pub cache repair

# re-resolve deps

flutter pub get
cd android
./gradlew --stop
./gradlew clean
cd ..
flutter run

# library update

flutter pub upgrade --major-versions
flutter pub get

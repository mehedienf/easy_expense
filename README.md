# easyexpense

# web release and hosting:
flutter build web --release
firebase deploy --only hosting

# set icon
flutter pub run flutter_launcher_icons

# for release:
flutter build apk --release --split-per-abi
flutter build apk --release


# from project root
flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf android/.gradle
rm -rf build .dart_tool

# clear problematic caches
rm -rf ~/.gradle/caches/8.4/scripts
rm -rf ~/.gradle/caches/*/scripts
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

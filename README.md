# easyexpense

# web release and hosting:
flutter build web --release
firebase deploy --only hosting

# set icon
flutter pub run flutter_launcher_icons

# for release:
flutter build apk --release --split-per-abi
flutter build apk --release

## Checklist

- testing
  - [ ] I have tested the app on iOS and verified that the app works as expected.
  - [ ] I have tested the app on Android and verified that the app works as expected.
  - [ ] I have ensured there are no regressions in key features.
- bumping flutter version
  - [ ] I have updated `version` in [pubspec.yaml](/flutter/nativebrik_bridge/pubspec.yaml) and executed `flutter pub get` to update the lock file.
  - [ ] I have written [CHANGELOG.md](/flutter/nativebrik_bridge/CHANGELOG.md) entries.
- bumping ios version
  - [ ] I have updated `dependency` in [podspec](/flutter/nativebrik_bridge/ios/nativebrik_bridge.podspec).
  - [ ] I have updated `Podfile.lock` at [example](/flutter/nativebrik_bridge/example/ios/Podfile.lock) and [e2e](/flutter/nativebrik_bridge/e2e/ios/Podfile.lock).
- bumping android version
  - [ ] I have updated [build.gradle](/flutter/nativebrik_bridge/android/build.gradle)

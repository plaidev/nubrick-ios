# For developer

## update SDK

Run the make command corresponding to the semver you want to update to.

```
make patch
make minor
make major
```

These commands do the following:

- update pubspec.yaml version
- insert empty template for CHANGELOG.md
- update pubspec.lock of example and e2e

## for ios

```
cd ./flutter/nativebrik_bridge/example
flutter build ios --no-codesign
open ios/Runner.xcworkspace
flutter run
```

## for android

```
cd ./flutter/nativebrik_bridge/example
open -a Android\ Studio android ./android
```

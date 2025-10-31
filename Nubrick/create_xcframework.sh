#!/bin/bash
set -e

ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
OUT_DIR="$ROOT/output"
IOS_ARCHIVE="$BUILD_DIR/Nubrick-iOS.xcarchive"
SIM_ARCHIVE="$BUILD_DIR/Nubrick-iOS-Simulator.xcarchive"

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Build for iOS
xcodebuild archive \
  -scheme Nubrick \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$IOS_ARCHIVE" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES 

# Build for iOS Simulator
xcodebuild archive \
  -scheme Nubrick \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$SIM_ARCHIVE" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Create XCFramework
xcodebuild -create-xcframework \
  -framework "$IOS_ARCHIVE/Products/Library/Frameworks/Nubrick.framework" \
  -debug-symbols "$IOS_ARCHIVE/dSYMs/Nubrick.framework.dSYM" \
  -framework "$SIM_ARCHIVE/Products/Library/Frameworks/Nubrick.framework" \
  -debug-symbols "$SIM_ARCHIVE/dSYMs/Nubrick.framework.dSYM" \
  -output "$OUT_DIR/Nubrick.xcframework"

sentry-cli debug-files upload --project nativebrik-ios --include-sources  output/Nubrick.xcframework

echo "XCFramework created successfully!"
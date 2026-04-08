#!/bin/bash
set -e

ROOT="$(pwd)"
PROJECT_PATH="$ROOT/Nubrick.xcodeproj"
BUILD_DIR="$ROOT/build"
OUT_DIR="$ROOT/output"
IOS_ARCHIVE="$BUILD_DIR/Nubrick-iOS.xcarchive"
SIM_ARCHIVE="$BUILD_DIR/Nubrick-iOS-Simulator.xcarchive"

echo "DEVELOPER_DIR=${DEVELOPER_DIR:-<unset>}"
xcode-select -p
which xcodebuild
xcodebuild -version
xcodebuild -showsdks
xcodebuild -showdestinations -project "$PROJECT_PATH" -scheme Nubrick

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Build for iOS
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme Nubrick \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$IOS_ARCHIVE" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES 

# Build for iOS Simulator
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme Nubrick \
  -configuration Release \
  -sdk iphonesimulator \
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

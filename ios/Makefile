PODS_ROOT := ./PodBuilder/Pods
PODS_PROJECT := $(PODS_ROOT)/Pods.xcodeproj
SYMROOT := $(PODS_ROOT)/Build
IPHONEOS_DEPLOYMENT_TARGET = 13.4

build-cocoapods:
	@(cd ./PodBuilder && pod install)
	@xcodebuild -project "$(PODS_PROJECT)" \
			-sdk iphoneos \
			-configuration Release -target Yoga \
			ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
			CLANG_ENABLE_MODULE_DEBUGGING=NO \
			BITCODE_GENERATION_MODE=bitcode \
			IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" \
			BUILD_LIBRARY_FOR_DISTRIBUTION=YES
	@xcodebuild -project "$(PODS_PROJECT)" \
		-sdk iphonesimulator \
		-configuration Release -target Yoga \
		ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
		CLANG_ENABLE_MODULE_DEBUGGING=NO \
		BITCODE_GENERATION_MODE=bitcode \
		IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

	@xcodebuild -project "$(PODS_PROJECT)" \
		-sdk iphoneos \
		-configuration Release -target YogaKit \
		ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
		CLANG_ENABLE_MODULE_DEBUGGING=NO \
		BITCODE_GENERATION_MODE=bitcode \
		IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

	@xcodebuild -project "$(PODS_PROJECT)" \
		-sdk iphonesimulator \
		-configuration Release -target YogaKit \
		ONLY_ACTIVE_ARCH=NO ENABLE_TESTABILITY=NO SYMROOT="$(SYMROOT)" \
		CLANG_ENABLE_MODULE_DEBUGGING=NO \
		BITCODE_GENERATION_MODE=bitcode \
		IPHONEOS_DEPLOYMENT_TARGET="$(IPHONEOS_DEPLOYMENT_TARGET)" \
		BUILD_LIBRARY_FOR_DISTRIBUTION=YES

build-xcframeworks: build-cocoapods
	@rm -rf ./xcframeworks

	@xcodebuild -create-xcframework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphonesimulator/Yoga/yoga.framework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphoneos/Yoga/yoga.framework \
		-output ./xcframeworks/yoga.xcframework

	@xcodebuild -create-xcframework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphonesimulator/YogaKit/YogaKit.framework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphoneos/YogaKit/YogaKit.framework \
		-output ./xcframeworks/YogaKit.xcframework

build-xcframework-archives: build-xcframeworks
	@cd ./xcframeworks && zip -r yoga.xcframework.zip yoga.xcframework
	@cd ./xcframeworks && zip -r YogaKit.xcframework.zip YogaKit.xcframework
	@swift package compute-checksum ./xcframeworks/yoga.xcframework.zip > ./xcframeworks/yoga.xcframework.zip.checksum
	@swift package compute-checksum ./xcframeworks/YogaKit.xcframework.zip > ./xcframeworks/YogaKit.xcframework.zip.checksum

# install swift packages
.PHONY: install
install:
	xcodebuild -resolvePackageDependencies

.PHONY: open
open:
	xed Nativebrik.xcworkspace

.PHONY: app
app: \
  install \
  open

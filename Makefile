PODS_ROOT="./ios/Example/Pods"
PODS_PROJECT="$(PODS_ROOT)/Pods.xcodeproj"
SYMROOT="$(PODS_ROOT)/Build"
IPHONEOS_DEPLOYMENT_TARGET = 13.4

build-cocoapods:
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

build-xcframework: build-cocoapods
	@xcodebuild -create-xcframework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphonesimulator/Yoga/yoga.framework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphoneos/Yoga/yoga.framework \
		-output ./ios/xcframeworks/yoga.xcframework

	@xcodebuild -create-xcframework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphonesimulator/YogaKit/YogaKit.framework \
		-framework $(PODS_ROOT)/$(PODS_ROOT)/Build/Release-iphoneos/YogaKit/YogaKit.framework \
		-output ./ios/xcframeworks/YogaKit.xcframework

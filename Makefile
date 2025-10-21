# install swift packages
.PHONY: install
install:
	xcodebuild -resolvePackageDependencies

.PHONY: open
open:
	xed Nubrick.xcworkspace

.PHONY: app
app: \
  install \
  open

.PHONY: pod
pod: \
  cd Examples/Example-CocoaPods && pod deintegrate && pod install --repo-update
  xed Examples/Example-CocoaPods/Example-CocoaPods.xcworkspace

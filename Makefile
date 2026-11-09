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

.PHONY: xcframework
xcframework:
	cd Nubrick && sh ./create_xcframework.sh

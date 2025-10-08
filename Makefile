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

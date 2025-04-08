VERSION := $(shell sed -n 's/^version: //p' pubspec.yaml)

.PHONY: install
install:
	cd example && flutter pub get
	cd e2e && flutter pub get

.PHONY: reinstall
reinstall:
	cd example && flutter clean && rm -rf ./ios/Pods && rm ./ios/Podfile.lock && pod repo update && flutter build ios --simulator && flutter build apk --debug
	cd e2e && flutter clean && rm -rf ./ios/Pods && rm ./ios/Podfile.lock && pod repo update && flutter build ios --simulator && flutter build apk --debug

define bump_version
	@NEW_VERSION=$$(echo "$(VERSION)" | awk -F. '{print $(1)}') && \
	sed -i '' "s/^version: .*/version: $$NEW_VERSION/" pubspec.yaml && \
	echo "\n## $$NEW_VERSION\n\n- " >> CHANGELOG.md;
	make install
endef

.PHONY: patch
patch:
	$(call bump_version, $$1"."$$2"."$$3+1)

.PHONY: minor
minor:
	$(call bump_version, $$1"."$$2+1".0")

.PHONY: major
major:
	$(call bump_version, $$1+1".0.0")

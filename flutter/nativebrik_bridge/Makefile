VERSION := $(shell sed -n 's/^version: //p' pubspec.yaml)

.PHONY: install
install:
	cd example && flutter pub get
	cd e2e && flutter pub get

.PHONY: patch
patch:
	@NEW_VERSION=$$(echo "$(VERSION)" | awk -F. '{print $$1"."$$2"."$$3+1}') && \
	sed -i'' -E "s/^version: .*/version: $$NEW_VERSION/" pubspec.yaml && \
	echo "\n## $$NEW_VERSION\n\n- " >> CHANGELOG.md;
	make install

.PHONY: minor
minor:
	@NEW_VERSION=$$(echo "$(VERSION)" | awk -F. '{print $$1"."$$2+1"."$$3}') && \
	sed -i'' -E "s/^version: .*/version: $$NEW_VERSION/" pubspec.yaml && \
	echo "\n## $$NEW_VERSION\n\n- " >> CHANGELOG.md;
	make install

.PHONY: major
major:
	@NEW_VERSION=$$(echo "$(VERSION)" | awk -F. '{print $$1+1"."$$2"."$$3}') && \
	sed -i'' -E "s/^version: .*/version: $$NEW_VERSION/" pubspec.yaml && \
	echo "\n## $$NEW_VERSION\n\n- " >> CHANGELOG.md;
	make install
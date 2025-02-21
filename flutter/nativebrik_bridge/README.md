# Nativebrik Bridge SDK

documentations

https://nativebrik.com/intl/en/docs


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

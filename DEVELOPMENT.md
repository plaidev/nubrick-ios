# Development Guide

## Getting Started

```bash
make app
```

Or open `Nubrick.xcworkspace` in Xcode.

## Local xcframework Development

To test with Nubrick as a binary framework (required for MetricKit error attribution):

1. Build the xcframework locally:
   ```bash
   make xcframework
   ```

2. Modify `Package.swift` to use the local path:
   ```swift
   // Change this:
   .binaryTarget(
       name: "Nubrick",
       url: "https://github.com/plaidev/nubrick-ios/releases/download/...",
       checksum: "..."
   )

   // To this:
   .binaryTarget(
       name: "Nubrick",
       path: "Nubrick/output/Nubrick.xcframework"
   )
   ```

3. Open `Examples/Example` and build

> **Note:** Do not commit the Package.swift change. Revert before pushing.

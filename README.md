# Nubrick SDK for iOS

## Requirements

- iOS 15.0+
- Xcode 16.1+

## Installation

New versions are distributed through Swift Package Manager only. In Xcode, add `https://github.com/plaidev/nubrick-ios.git` under Package Dependencies and link the **Nubrick** product to your app target. Update the package version requirement in Xcode when upgrading.

## CocoaPods migration

Remove only Nubrick from your Podfile and run `pod install` to update the remaining dependencies. Remove any manually linked Nubrick framework before adding the Swift package to avoid linking it twice. Keep CocoaPods if other dependencies still need it.

If you need to stay on CocoaPods, pin `pod 'Nubrick', '0.19.21'`. Existing pod versions and their public release binaries remain available; new SDK versions are no longer published to CocoaPods trunk.

The next release's breaking changes are recorded in [RELEASE_NOTES.md](RELEASE_NOTES.md).

# Documentation

[https://docs.nativebrik.com](https://docs.nativebrik.com/)

## Development

run `make app` or open `Nativebrik.xcworkspace` in Xcode

## Structure

```
SDK
├── Overlay
│   ├── ModalComponentViewController: Manage Popup user story like showing navigation, webview, etc...
│   │   └── ModalPageViewController: Render PageView with custom navigation buttons
│   └── TriggerViewController: .dispatch an event, fetch data, and show popups
│       └── ModalRootViewController: Manage page transitions and Render PageView
│
└── Experiment
    ├── RemoteConfig
    │   └── RemoteConfigVariant
    │       ├── ComponentView
    │       └── ComponentSwiftView
    └── EmbeddingUIView extends ComponentUIView: Fetch experiment and component, and render
        └── RootView: Manage page transitions and use ModalComponentViewController to show popups (.presentPage)
            └── PageView: Fetch data and Render view
                └── UIViewBlock: Render view blocks
```

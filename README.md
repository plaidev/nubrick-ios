# Nubrick SDK for iOS

documentations

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

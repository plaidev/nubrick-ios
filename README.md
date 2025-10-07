# Nativebrik SDK for iOS

documentations

[https://docs.nativebrik.com](https://docs.nativebrik.com/)

## Development

run `make app` or open `Nativebrik.xcworkspace` in Xcode

## Structure

```
SDK
|_ Overlay
|   |_ ModalComponentViewController: Manage Popup user story like showing navigation, webview, etc...
|   |   |_ ModalPageViewController: Render PageView with custom navigation buttons
|   |_ TriggerViewController: .dispatch an event, fetch data, and show popups
|       |_ ModalRootViewController: Manage page transitions and Render PageView
|
|_ Experiment
    |_ RemoteConfig
    |   |_ RemoteConfigVariant
    |       |_ ComponentView
    |       |_ ComponentSwiftView
    |_ EmbeddingUIView extends ComponentUIView: Fetch experiment and component, and render
        |_ RootView: Manage page transitions and use ModalComponentViewController to show popups (.presentPage)
            |_ PageView: Fetch data and Render view
                |_ UIViewBlock: Render view blocks
```

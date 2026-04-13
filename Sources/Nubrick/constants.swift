import Foundation

private final class NubrickBundleToken {}

enum NubrickConstants {
    static let trackUrl = "https://track.nativebrik.com/track/v1"
    static let cdnUrl = "https://cdn.nativebrik.com"

    // Prefer the framework bundle version so release metadata comes from build settings.
    static var sdkVersion: String {
        let bundle = Bundle(identifier: "com.plaid.nubrick") ?? Bundle(for: NubrickBundleToken.self)
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

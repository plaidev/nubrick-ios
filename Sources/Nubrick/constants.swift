import Foundation

private final class NubrickBundleToken {}

enum NubrickConstants {
    static let trackBaseUrl = "https://track.nativebrik.com"
    static let trackEndpoint = "/track/v1"
    static let surveyResponsesEndpoint = "/track/v1/survey-responses"
    static let trackUrl = "\(trackBaseUrl)\(trackEndpoint)"
    static let surveyResponsesUrl = "\(trackBaseUrl)\(surveyResponsesEndpoint)"
    static let cdnUrl = "https://cdn.nativebrik.com"
    static let defaultCacheRetentionSeconds: TimeInterval = 24 * 60 * 60 // 1 day

    // Prefer the framework bundle version so release metadata comes from build settings.
    static var sdkVersion: String {
        let bundle = Bundle(identifier: "com.plaid.nubrick") ?? Bundle(for: NubrickBundleToken.self)
        return bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

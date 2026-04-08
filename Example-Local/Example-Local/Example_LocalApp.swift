import Nubrick
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}

@main
@MainActor
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        guard let projectId = Bundle.main.object(forInfoDictionaryKey: "PROJECT_ID") as? String else {
            fatalError("Missing or invalid PROJECT_ID in Info.plist")
        }

        let cdnUrl = (Bundle.main.object(forInfoDictionaryKey: "CDN_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trackUrl = (Bundle.main.object(forInfoDictionaryKey: "TRACK_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        NubrickSDK.initialize(
            projectId: projectId,
            trackUrl: (trackUrl?.isEmpty == false) ? trackUrl : nil,
            cdnUrl: (cdnUrl?.isEmpty == false) ? cdnUrl : nil,
            cachePolicy: NubrickCachePolicy(cacheTime: 10 * 60, staleTime: 0)
        )
    }

    var body: some Scene {
        WindowGroup {
            NubrickProvider {
                ContentView()
            }
        }
    }
}

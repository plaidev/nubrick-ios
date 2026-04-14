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

        NubrickSDK.initialize(
            projectId: projectId
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

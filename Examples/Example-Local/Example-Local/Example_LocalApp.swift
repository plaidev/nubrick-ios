import Nubrick
import SwiftUI

@main
@MainActor
struct ExampleApp: App {
    init() {
        guard let projectId = Bundle.main.object(forInfoDictionaryKey: "PROJECT_ID") as? String else {
            fatalError("Missing or invalid PROJECT_ID in Info.plist")
        }
        NubrickSDK.initialize(projectId: projectId)
    }

    var body: some Scene {
        WindowGroup {
            NubrickProvider {
                ContentView()
            }
        }
    }
}

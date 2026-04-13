//
//  ExampleApp.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

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
            projectId: projectId,
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

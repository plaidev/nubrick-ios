//
//  ExampleApp.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import Nubrick
import SwiftUI
import UIKit

let nubrick = {
    guard let projectId = Bundle.main.object(forInfoDictionaryKey: "PROJECT_ID") as? String else {
        fatalError("Missing or invalid PROJECT_ID in Info.plist")
    }

    if let cdnUrl = Bundle.main.object(forInfoDictionaryKey: "CDN_URL") as? String, !cdnUrl.isEmpty {
        nubrickCdnUrl = cdnUrl
    }
    if let trackUrl = Bundle.main.object(forInfoDictionaryKey: "TRACK_URL") as? String, !trackUrl.isEmpty {
        nubrickTrackUrl = trackUrl
    }

    return NubrickClient(
        projectId: projectId,
        cachePolicy: NubrickCachePolicy(cacheTime: 10 * 60, staleTime: 0)
    )
}()

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
}

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NubrickProvider(
                client: nubrick
            ) {
                ContentView()
            }
        }
    }
}

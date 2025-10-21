//
//  Example_CocoaPodsApp.swift
//  Example-CocoaPods
//
//  Created by Takuma Jimbo on 2025/10/21.
//

import Nubrick
import SwiftUI
import UIKit

let nubrick = {
    if let cdnUrl = Bundle.main.object(forInfoDictionaryKey: "CDN_URL") as? String, !cdnUrl.isEmpty {
        nubrickCdnUrl = cdnUrl
    }
    if let trackUrl = Bundle.main.object(forInfoDictionaryKey: "TRACK_URL") as? String, !trackUrl.isEmpty {
        nubrickTrackUrl = trackUrl
    }

    return NubrickClient(
        projectId: "cgv3p3223akg00fod19g",
        cachePolicy: NativebrikCachePolicy(cacheTime: 10 * 60, staleTime: 0)
    )
}()

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        NSSetUncaughtExceptionHandler { exception in
            nubrick.experiment.record(exception: exception)
        }
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

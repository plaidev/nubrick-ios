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
    let cdnUrl = (Bundle.main.object(forInfoDictionaryKey: "CDN_URL") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let trackUrl = (Bundle.main.object(forInfoDictionaryKey: "TRACK_URL") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return NubrickClient(
        projectId: "cgv3p3223akg00fod19g",
        trackUrl: (trackUrl?.isEmpty == false) ? trackUrl : nil,
        cdnUrl: (cdnUrl?.isEmpty == false) ? cdnUrl : nil,
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

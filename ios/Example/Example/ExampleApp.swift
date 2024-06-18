//
//  ExampleApp.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import SwiftUI
import Nativebrik
import UIKit

let nativebrik = NativebrikClient(projectId: "cgv3p3223akg00fod19g")

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSSetUncaughtExceptionHandler { exception in
            nativebrik.experiment.record(exception: exception)
        }
        return true
    }
}

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            NativebrikProvider(
                client: nativebrik
            ) {
                ContentView()
            }
        }
    }
}

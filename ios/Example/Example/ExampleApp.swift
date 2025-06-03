//
//  ExampleApp.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import Nativebrik
import SwiftUI
import UIKit

let nativebrik = {
	guard let projectId = Bundle.main.object(forInfoDictionaryKey: "PROJECT_ID") as? String else {
		fatalError("Missing or invalid PROJECT_ID in Info.plist")
	}

	if let cdnUrl = Bundle.main.object(forInfoDictionaryKey: "CDN_URL") as? String {
		nativebrikCdnUrl = cdnUrl
	}
	if let trackUrl = Bundle.main.object(forInfoDictionaryKey: "TRACK_URL") as? String {
		nativebrikTrackUrl = trackUrl
	}

	return NativebrikClient(
		projectId: projectId,
		cachePolicy: NativebrikCachePolicy(cacheTime: 10 * 60, staleTime: 0)
	)
}()

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
	) -> Bool {
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

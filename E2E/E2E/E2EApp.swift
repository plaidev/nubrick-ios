//
//  E2EApp.swift
//  E2E
//
//  Created by Ryosuke Suzuki on 2023/11/14.
//

import SwiftUI
import Nubrick

@main
@MainActor
struct E2EApp: App {
    init() {
        NubrickSDK.initialize(projectId: "ckto7v223akg00ag3jsg")
    }

    var body: some Scene {
        WindowGroup {
            NubrickProvider {
                ContentView()
            }
        }
    }
}

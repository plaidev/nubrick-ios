//
//  E2EApp.swift
//  E2E
//
//  Created by Ryosuke Suzuki on 2023/11/14.
//

import SwiftUI
import Nubrick

@main
struct E2EApp: App {
    var body: some Scene {
        WindowGroup {
            NubrickProvider(client: NubrickClient(projectId: "ckto7v223akg00ag3jsg")) {
                ContentView()
            }
        }
    }
}

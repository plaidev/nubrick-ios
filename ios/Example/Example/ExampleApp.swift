//
//  ExampleApp.swift
//  Example
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import SwiftUI
import Nativebrik

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            NativebrikProvider(
                client: NativebrikClient(projectId: "cgv3p3223akg00fod19g")
            ) {
                ContentView()
            }
        }
    }
}

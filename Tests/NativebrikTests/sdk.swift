//
//  sdk.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
import ViewInspector
import SwiftUI
@testable import Nativebrik


final class NativebrikClientTests: XCTestCase {
    func testInitializeNativebrikClientWithoutErrorThrows() throws {
        let client = NativebrikClient(projectId: "Nothing")
        let _ = client.experiment.overlayViewController()
    }
    
    func testDispatchWithoutErrorThrows() throws {
        let client = NativebrikClient(projectId: "Nothing")
        client.experiment.dispatch(NativebrikEvent("Hello"))
    }
}

final class NativebrikProviderTests: XCTestCase {
    struct AccessToClient: View {
        @EnvironmentObject var nativebrik: NativebrikClient
        var body: some View {
            nativebrik
                .experiment
                .embedding("Nothing", onEvent: nil) { phase in
                    switch phase {
                    default:
                        Text("EXPERIMENT")
                    }
                }
        }
    }
    struct ContentView: View {
        var body: some View {
            NativebrikProvider(client: NativebrikClient(projectId: "Nothing")) {
                Text("Hello")
                AccessToClient()
            }
        }
    }
    
    func testNativebrikProvider() throws {
        try XCTContext.runActivity(named: "find content") { _ in
            let view = ContentView()
            let _ = try view.inspect().find(text: "Hello")
        }
        
        try XCTContext.runActivity(named: "find overlay") { _ in
            let view = ContentView()
            let _ = try view.inspect().find(OverlayViewControllerRepresentable.self)
        }
        
        try XCTContext.runActivity(named: "find experiment") { _ in
            let view = ContentView()
            let _ = try view.inspect().find(text: "EXPERIMENT")
        }
    }
}

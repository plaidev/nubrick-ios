//
//  sdk.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
import ViewInspector
import SwiftUI
@testable import Nubrick


final class NubrickClientTests: XCTestCase {
    func testInitializeNubrickClientWithoutError() throws {
        let client = NubrickClient(projectId: "Nothing")

        XCTContext.runActivity(named: "initialize and create overlay") { _ in
            XCTAssertNoThrow(client.experiment.overlayViewController())
        }

        XCTContext.runActivity(named: "dispatch event") { _ in
            XCTAssertNoThrow(client.experiment.dispatch(NubrickEvent("Hello")))
        }
    }
}

final class NubrickProviderTests: XCTestCase {
    struct ClientConsumerView: View {
        @EnvironmentObject var nubrick: NubrickClient
        var body: some View {
            nubrick
                .experiment
                .embedding("Nothing", onEvent: nil) { phase in
                    switch phase {
                    default:
                        Text("EXPERIMENT")
                    }
                }
        }
    }
    struct TestView: View {
        var body: some View {
            NubrickProvider(client: NubrickClient(projectId: "Nothing")) {
                Text("Hello")
                ClientConsumerView()
            }
        }
    }
    
    @MainActor
    func testNubrickProvider() throws {
        let view = TestView()
        
        try XCTContext.runActivity(named: "renders content") { _ in
            XCTAssertNoThrow(try view.inspect().find(text: "Hello"))
        }
        
        try XCTContext.runActivity(named: "find overlay") { _ in
            XCTAssertNoThrow(try view.inspect().find(OverlayViewControllerRepresentable.self))
        }
        
        try XCTContext.runActivity(named: "renders experiment") { _ in
            XCTAssertNoThrow(try view.inspect().find(text: "EXPERIMENT"))
        }
    }
}

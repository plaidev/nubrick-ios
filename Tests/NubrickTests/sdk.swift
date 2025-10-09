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

final class NubrickProviderTests: XCTestCase {
    struct ClientConsumerView: View {
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
    struct TestView: View {
        var body: some View {
            NubrickProvider(client: NativebrikClient(projectId: "Nothing")) {
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

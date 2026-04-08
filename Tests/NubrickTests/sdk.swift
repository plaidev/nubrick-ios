//
//  sdk.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
import SwiftUI
@testable import NubrickLocal


final class NubrickClientTests: XCTestCase {
    @MainActor
    func testInitializeNubrickClientWithoutError() throws {
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)

        XCTContext.runActivity(named: "initialize and create overlay") { _ in
            XCTAssertNoThrow(NubrickSDK.overlayViewController())
        }

        XCTContext.runActivity(named: "dispatch event") { _ in
            XCTAssertNoThrow(NubrickSDK.dispatch(NubrickEvent("Hello")))
        }
    }
}

final class NubrickProviderTests: XCTestCase {
    struct NubrickConsumerView: View {
        var body: some View {
            NubrickSDK.embedding(UNKNOWN_EXPERIMENT_ID, onEvent: nil) { phase in
                switch phase {
                default:
                    Text("EXPERIMENT")
                }
            }
        }
    }

    struct TestView: View {
        var body: some View {
            NubrickProvider {
                Text("Hello")
                NubrickConsumerView()
            }
        }
    }

    @MainActor
    func testNubrickProvider() throws {
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        XCTAssertNoThrow(TestView().body)
    }
}

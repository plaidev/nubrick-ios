import XCTest
@testable import NubrickLocal
import SwiftUI

let EMBEDDING_ID_1_FOR_TEST = "EMBEDDING_1"

final class EmbeddingUIViewTests: XCTestCase {
    @MainActor
    private func makeContainer(arguments: NubrickArguments? = nil) throws -> Container {
        let db = try XCTUnwrap(createNativebrikCoreDataHelper(), "Could not init DB")
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let dependencies = NubrickDependencyContainer(
            config: config,
            user: user,
            actionHandler: { _, _ in },
            persistentContainer: db,
            httpRequestInterceptor: nil
        )
        return dependencies.makeContainer(arguments: arguments)
    }

    private func makeComponentRoot(
        pageId: String = "PAGE_1",
        frameWidth: Int?,
        frameHeight: Int?
    ) -> UIRootBlock {
        UIRootBlock(
            id: "ROOT_1",
            data: UIRootBlockData(
                pages: [
                    UIPageBlock(
                        id: pageId,
                        name: "Component",
                        data: UIPageBlockData(
                            kind: .COMPONENT,
                            modalPresentationStyle: nil,
                            modalScreenSize: nil,
                            modalNavigationBackButton: nil,
                            modalRespectSafeArea: nil,
                            webviewUrl: nil,
                            triggerSetting: nil,
                            renderAs: nil,
                            position: nil,
                            httpRequest: nil,
                            tooltipSize: nil,
                            tooltipAnchor: nil,
                            tooltipPlacement: nil,
                            tooltipTransitionTarget: nil,
                            props: nil,
                            frameWidth: frameWidth,
                            frameHeight: frameHeight,
                            query: nil
                        )
                    )
                ],
                currentPageId: pageId
            )
        )
    }

    private func assertSize(
        _ actual: NubrickSize,
        equals expected: NubrickSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch (actual, expected) {
        case (.fill, .fill):
            XCTAssertTrue(true, file: file, line: line)
        case let (.fixed(actualValue), .fixed(expectedValue)):
            XCTAssertEqual(actualValue, expectedValue, file: file, line: line)
        default:
            XCTFail("Expected \(expected), got \(actual)", file: file, line: line)
        }
    }

    @MainActor
    func testEmbeddingShouldFetch() {
        let expectation = expectation(description: "Fetch an embedding for test")

        var didLoadingPhaseCome = false
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        let view = NubrickSDK.embeddingUIView(EMBEDDING_ID_1_FOR_TEST, onEvent: nil) { phase in
            switch phase {
            case .completed:
                expectation.fulfill()
                return UIView()
            case .loading:
                didLoadingPhaseCome = true
                return UIView()
            default:
                XCTFail("should found the remote config")
                return UIView()
            }
        }
        // because internally we use [weak self] and if it is `let _ =`, weak self will be nil.
        print("it must be `let view = client` to pass the test.", view.frame)
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
            XCTAssertTrue(didLoadingPhaseCome)
        }
    }

    @MainActor
    func testEmbeddingOnSizeChange() {
        let expectation = expectation(description: "onSizeChange should be called")

        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        let view = NubrickSDK.embeddingUIView(
            EMBEDDING_ID_1_FOR_TEST,
            onEvent: nil,
            content: { phase in
                return UIView()
            },
            onSizeChange: { width, height in
                expectation.fulfill()
            }
        )
        withExtendedLifetime(view) {
            waitForExpectations(timeout: 30) { error in
                if let error = error {
                    XCTFail("waitForExpectations(timeout:) failed: \(error)")
                }
            }
        }
    }

    @MainActor
    func testSizeCoordinatorUsesLatestOnSizeChangeCallback() {
        var recordedWidth: NubrickSize = .fill
        var recordedHeight: NubrickSize = .fill
        let widthBinding = Binding<NubrickSize>(
            get: { recordedWidth },
            set: { recordedWidth = $0 }
        )
        let heightBinding = Binding<NubrickSize>(
            get: { recordedHeight },
            set: { recordedHeight = $0 }
        )

        var oldCallbackCalls = 0
        var latestCallbackCalls = 0
        let coordinator = RootViewRepresentable.SizeCoordinator(
            w: widthBinding,
            h: heightBinding,
            onSizeChange: { _, _ in
                oldCallbackCalls += 1
            }
        )
        coordinator.onSizeChange = { width, height in
            latestCallbackCalls += 1
            self.assertSize(width, equals: .fill)
            self.assertSize(height, equals: .fixed(240))
        }

        coordinator.report(width: .fill, height: .fixed(240))

        XCTAssertEqual(oldCallbackCalls, 0)
        XCTAssertEqual(latestCallbackCalls, 1)
        assertSize(recordedWidth, equals: .fill)
        assertSize(recordedHeight, equals: .fixed(240))
    }

    @MainActor
    func testSizeCoordinatorDoesNotReportAfterDeactivation() {
        var recordedWidth: NubrickSize = .fixed(120)
        var recordedHeight: NubrickSize = .fixed(80)
        let widthBinding = Binding<NubrickSize>(
            get: { recordedWidth },
            set: { recordedWidth = $0 }
        )
        let heightBinding = Binding<NubrickSize>(
            get: { recordedHeight },
            set: { recordedHeight = $0 }
        )

        var callbackCalls = 0
        let coordinator = RootViewRepresentable.SizeCoordinator(
            w: widthBinding,
            h: heightBinding,
            onSizeChange: { _, _ in
                callbackCalls += 1
            }
        )

        coordinator.deactivate()
        coordinator.report(width: .fill, height: .fill)

        XCTAssertEqual(callbackCalls, 0)
        assertSize(recordedWidth, equals: .fixed(120))
        assertSize(recordedHeight, equals: .fixed(80))
    }

    @MainActor
    func testRootViewMapsComponentFramesToSizesAndIntrinsicMetrics() throws {
        let expectation = expectation(description: "onSizeChange should be called")
        var reportedWidth: NubrickSize?
        var reportedHeight: NubrickSize?
        let pageId = "COMPONENT_PAGE"
        let rootView = RootView(
            root: makeComponentRoot(pageId: pageId, frameWidth: 0, frameHeight: 280),
            container: try makeContainer(),
            modalViewController: nil,
            onEvent: nil,
            onSizeChange: { width, height in
                reportedWidth = width
                reportedHeight = height
                expectation.fulfill()
            }
        )

        rootView.presentPage(pageId: pageId, props: nil)

        waitForExpectations(timeout: 1)
        assertSize(try XCTUnwrap(reportedWidth), equals: .fill)
        assertSize(try XCTUnwrap(reportedHeight), equals: .fixed(280))

        let intrinsicSize = rootView.intrinsicContentSize
        XCTAssertEqual(intrinsicSize.width, UIView.noIntrinsicMetric)
        XCTAssertEqual(intrinsicSize.height, 280)
    }

    @MainActor
    func testRootViewUsesIntrinsicMetricsForFixedComponentFrames() throws {
        let pageId = "COMPONENT_PAGE_FIXED"
        let rootView = RootView(
            root: makeComponentRoot(pageId: pageId, frameWidth: 120, frameHeight: 80),
            container: try makeContainer(),
            modalViewController: nil,
            onEvent: nil
        )

        rootView.presentPage(pageId: pageId, props: nil)

        let intrinsicSize = rootView.intrinsicContentSize
        XCTAssertEqual(intrinsicSize.width, 120)
        XCTAssertEqual(intrinsicSize.height, 80)
    }

    @MainActor
    func testEmbeddingShouldNotFetch() {
        let expectation = expectation(description: "Fetch an embedding for test")

        var didLoadingPhaseCome = false
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        let view = NubrickSDK.embeddingUIView(UNKNOWN_EXPERIMENT_ID, onEvent: nil) { phase in
            switch phase {
            case .completed:
                XCTFail("should found the remote config")
                return UIView()
            case .loading:
                didLoadingPhaseCome = true
                return UIView()
            default:
                expectation.fulfill()
                return UIView()
            }
        }
        // because internally we use [weak self] and if it is `let _ =`, weak self will be nil.
        print("it must be `let view = client` to pass the test.", view.frame)
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
            XCTAssertTrue(didLoadingPhaseCome)
        }
    }
}

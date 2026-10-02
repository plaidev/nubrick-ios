import Combine
import XCTest
import UIKit
import SafariServices
@testable import NubrickLocal

@MainActor
private final class TriggerModalSpy: ModalComponentViewController {
    var presentations = [UIViewController]()
    var onShown: (() -> Void)?
    var canPresent = true

    override func presentToTop(_ viewController: UIViewController, onPresented: (() -> Void)?) -> Bool {
        guard canPresent else { return false }
        self.presentations.append(viewController)
        self.onShown = onPresented
        return true
    }
}

private final class TriggerContainerSpy: Container, @unchecked Sendable {
    let experimentId: String? = nil
    let variantId: String? = nil

    @MainActor var onFetchTriggers: (([String]) -> Void)?
    @MainActor var onPopupFetchPaused: (() -> Void)?
    @MainActor var onDisplayRecordingPaused: (() -> Void)?
    @MainActor var onDisplayed: (() -> Void)?
    @MainActor var popupFetches = [String]()
    @MainActor var recordedTriggers = [String]()
    @MainActor var displayedExperiments = [String]()
    @MainActor var roots = [String: UIRootBlock]()
    @MainActor var firstFetchContinuation: CheckedContinuation<Void, Never>?
    @MainActor var displayRecordingContinuation: CheckedContinuation<Void, Never>?
    @MainActor var shouldPauseDisplayRecording = false

    @MainActor
    private func pauseFirstFetch() async {
        await withCheckedContinuation { continuation in
            self.firstFetchContinuation = continuation
            self.onPopupFetchPaused?()
        }
    }

    @MainActor
    init() {}

    @MainActor
    func handleEvent(_ it: UIBlockAction) {}

    @MainActor
    func makeContainer() -> Container { self }

    @MainActor
    func makeContainer(experimentId: String?, variantId: String?) -> Container { self }

    @MainActor
    func createVariableForTemplate(
        data: Any?,
        properties: [Property]?,
        arguments: NubrickArguments?
    ) -> Variable? { nil }

    @MainActor
    func getFormValue(key: String) -> Any? { nil }

    @MainActor
    func getFormValues() -> [String: Any] { [:] }

    @MainActor
    func setFormValue(key: String, value: Any, regex: String?) {}

    @MainActor
    func formRegexes() -> [String: String] { [:] }

    @MainActor
    func formDataPublisher() -> AnyPublisher<[String: Any], Never> {
        Just([:]).eraseToAnyPublisher()
    }

    @MainActor
    func userDataPublisher() -> AnyPublisher<[String: Any], Never> {
        Just([:]).eraseToAnyPublisher()
    }

    func sendHttpRequest(
        req: ApiHttpRequest,
        assertion: ApiHttpResponseAssertion?,
        variable: Variable?
    ) async -> Result<JSONData, NubrickError> {
        .failure(.notFound)
    }

    func fetchEmbedding(
        experimentId: String,
        componentId: String?
    ) async -> Result<FetchedEmbedding, NubrickError> {
        .failure(.notFound)
    }

    func fetchTriggerContent(
        trigger: String,
        kinds: [ExperimentKind],
        sourceExperimentId: String?
    ) async -> Result<FetchedTriggerContent, NubrickError> {
        if trigger.hasPrefix("popup-") {
            await MainActor.run { self.popupFetches.append(trigger) }
            if trigger == "popup-first" { await self.pauseFirstFetch() }
            let root = try! JSONDecoder().decode(UIRootBlock.self, from: Data("""
            {"id":"root","data":{"pages":[
              {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"modal"}}}},
              {"id":"modal","data":{"kind":"MODAL"}}
            ]}}
            """.utf8))
            return .success(FetchedTriggerContent(
                experimentId: trigger, variantId: "variant", kind: .POPUP,
                block: .EUIRootBlock(await MainActor.run { self.roots[trigger] ?? root })
            ))
        }
        guard trigger == "tooltip-trigger" else {
            return .failure(.notFound)
        }
        return .success(FetchedTriggerContent(
            experimentId: "tooltip-experiment-id",
            variantId: "tooltip-variant-id",
            kind: .TOOLTIP,
            block: .EUIRootBlock(UIRootBlock(id: "tooltip-root", data: nil))
        ))
    }

    func fetchTriggerContent(
        triggers: [String],
        kinds: [ExperimentKind],
        sourceExperimentId: String?
    ) async -> Result<FetchedTriggerContent, NubrickError> {
        await MainActor.run { onFetchTriggers?(triggers) }
        return .failure(.notFound)
    }

    func recordTriggerEvents(triggers: [String], sourceExperimentId: String?) async {
        await MainActor.run { self.recordedTriggers.append(contentsOf: triggers) }
    }

    func recordDisplayedTriggerContent(experimentId: String, variantId: String) async -> Bool {
        if await MainActor.run(body: { self.shouldPauseDisplayRecording }) {
            await withCheckedContinuation { continuation in
                Task { @MainActor in
                    self.displayRecordingContinuation = continuation
                    self.onDisplayRecordingPaused?()
                }
            }
        }
        await MainActor.run {
            self.displayedExperiments.append(experimentId)
            self.onDisplayed?()
        }
        return true
    }

    func fetchRemoteConfig(
        experimentId: String
    ) async -> Result<(String, ExperimentVariant), NubrickError> {
        .failure(.notFound)
    }
}

final class TriggerViewControllerTests: XCTestCase {
    @MainActor
    func testDismissalKeepsClaimUntilDisplayHistoryIsPersisted() async {
        let recordingPaused = expectation(description: "Display recording paused")
        let displayed = expectation(description: "Display history persisted")
        let container = TriggerContainerSpy()
        container.shouldPauseDisplayRecording = true
        container.onDisplayRecordingPaused = { recordingPaused.fulfill() }
        container.onDisplayed = { displayed.fulfill() }
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: modal
        )
        controller.initialLoad()

        await controller.performDispatch(event: NubrickEvent("popup-first-shown"))
        XCTAssertEqual(modal.presentations.count, 1)
        modal.onShown?()
        await fulfillment(of: [recordingPaused], timeout: 1)

        modal.presentations.last?.viewDidDisappear(false)
        await settleUIKit()
        XCTAssertTrue(modal.hasActiveTriggerExperiment)

        await controller.performDispatch(event: NubrickEvent("popup-before-history"))
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertEqual(container.popupFetches, ["popup-first-shown"])
        XCTAssertTrue(container.recordedTriggers.contains("popup-before-history"))

        container.displayRecordingContinuation?.resume()
        await fulfillment(of: [displayed], timeout: 1)
        await settleUIKit()
        XCTAssertFalse(modal.hasActiveTriggerExperiment)

        await controller.performDispatch(event: NubrickEvent("popup-after-history"))
        XCTAssertEqual(container.popupFetches, ["popup-first-shown", "popup-after-history"])
        XCTAssertEqual(modal.presentations.count, 2)
    }

    @MainActor
    func testPendingFetchDoesNotBlockReadyExperimentAndLateCompletionIsDiscarded() async {
        let startup = expectation(description: "Startup fetch completed")
        let paused = expectation(description: "First popup fetch paused")
        let displayed = expectation(description: "Ready popup displayed")
        let container = TriggerContainerSpy()
        container.onFetchTriggers = { _ in startup.fulfill() }
        container.onPopupFetchPaused = { paused.fulfill() }
        container.onDisplayed = { displayed.fulfill() }
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: modal
        )
        controller.initialLoad()
        await fulfillment(of: [startup], timeout: 1)

        let first = Task { await controller.performDispatch(event: NubrickEvent("popup-first")) }
        await fulfillment(of: [paused], timeout: 1)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        await controller.performDispatch(event: NubrickEvent("popup-second"))
        XCTAssertEqual(container.popupFetches, ["popup-first", "popup-second"])
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertTrue(container.displayedExperiments.isEmpty)

        container.firstFetchContinuation?.resume()
        await first.value
        XCTAssertEqual(modal.presentations.count, 1)
        await controller.performDispatch(event: NubrickEvent("popup-third"))
        XCTAssertEqual(container.popupFetches, ["popup-first", "popup-second"])
        XCTAssertTrue(container.recordedTriggers.contains("popup-third"))

        modal.onShown?()
        modal.onShown?()
        await fulfillment(of: [displayed], timeout: 1)
        XCTAssertEqual(container.displayedExperiments, ["popup-second"])

        modal.presentations.last?.viewDidDisappear(false)
        await settleUIKit()
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 1, "Skipped starts must not replay after dismissal")
        await controller.performDispatch(event: NubrickEvent("popup-fourth"))
        XCTAssertEqual(modal.presentations.count, 2)
    }

    @MainActor
    private func settleUIKit() async {
        // Let dismissal lifecycle callbacks and display-recording tasks finish.
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    @MainActor
    private func webRoot(url: String = "https://example.com", backDestination: String? = nil, startPage: String = "web") -> UIRootBlock {
        let back = backDestination.map { ",\"triggerSetting\":{\"onTrigger\":{\"destinationPageId\":\"\($0)\"}}" } ?? ""
        return try! JSONDecoder().decode(UIRootBlock.self, from: Data("""
        {"id":"root","data":{"pages":[
          {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"\(startPage)"}}}},
          {"id":"web","data":{"kind":"WEBVIEW_MODAL","webviewUrl":"\(url)"\(back)}},
          {"id":"modal","data":{"kind":"MODAL"}},
          {"id":"modal-two","data":{"kind":"MODAL"}},
          {"id":"done","data":{"kind":"DISMISSED"}}
        ]}}
        """.utf8))
    }

    @MainActor
    func testInvalidAndEmptyContentReleaseClaim() async {
        let container = TriggerContainerSpy()
        container.roots["popup-invalid-url"] = webRoot(url: "")
        container.roots["popup-external"] = webRoot(url: "unknown-test-scheme://example")
        container.roots["popup-empty"] = UIRootBlock(id: "empty", data: nil)
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        for trigger in ["popup-invalid-url", "popup-external", "popup-empty"] {
            await controller.performDispatch(event: NubrickEvent(trigger))
            XCTAssertFalse(modal.hasActiveTriggerExperiment, trigger)
        }
        modal.canPresent = false
        await controller.performDispatch(event: NubrickEvent("popup-unpresentable"))
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertTrue(container.displayedExperiments.isEmpty)
    }

    @MainActor
    func testStandaloneSafariBlocksCompetingStartsUntilItDisappears() async {
        let container = TriggerContainerSpy()
        container.roots["popup-web"] = webRoot()
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        await controller.performDispatch(event: NubrickEvent("popup-web"))
        XCTAssertTrue(modal.presentations.first is SFSafariViewController)
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        await controller.performDispatch(event: NubrickEvent("popup-next"))
        XCTAssertEqual(modal.presentations.count, 1)
        modal.onShown?()
        await settleUIKit()
        XCTAssertEqual(container.displayedExperiments, ["popup-web"])
        modal.presentations.first?.viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        await settleUIKit()
        await controller.performDispatch(event: NubrickEvent("popup-next"))
        XCTAssertEqual(modal.presentations.count, 2)
    }

    @MainActor
    func testStandaloneSafariBackActionContinuesSameExperimentAndRecordsOnlyOnce() async {
        let container = TriggerContainerSpy()
        container.roots["popup-web"] = webRoot(backDestination: "modal")
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        await controller.performDispatch(event: NubrickEvent("popup-web"))
        modal.onShown?()
        await settleUIKit()
        guard let safari = modal.presentations.first as? SFSafariViewController else {
            XCTFail("Expected Safari presentation")
            return
        }
        safari.loadViewIfNeeded()
        await settleUIKit()
        XCTAssertEqual(modal.presentations.count, 1, "The Back action must wait for disappearance")
        safari.viewDidDisappear(false)
        await settleUIKit()
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 2)
        XCTAssertTrue(modal.presentations.last is UINavigationController)
        modal.onShown?()
        await settleUIKit()
        XCTAssertEqual(container.displayedExperiments, ["popup-web"])
    }

    @MainActor
    func testNonTriggerSafariContinuesIntoNativeModalOnlyAfterDisappearance() async throws {
        let modal = TriggerModalSpy()
        let root = ModalRootViewController(
            root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
            modalViewController: modal
        )
        let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
        safari.loadViewIfNeeded()
        await settleUIKit()
        XCTAssertEqual(modal.presentations.count, 1)
        safari.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 2)
        XCTAssertTrue(modal.presentations.last is UINavigationController)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        safari.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 2, "The continuation runs only once")
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testNonTriggerSafariDismissalToDismissedPageDoesNotReopen() throws {
        let modal = TriggerModalSpy()
        let root = ModalRootViewController(
            root: webRoot(backDestination: "done"), container: TriggerContainerSpy(),
            modalViewController: modal
        )
        let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
        safari.loadViewIfNeeded()
        safari.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testStandaloneSafariDismissalToDismissedPageReleasesClaimWithoutReplay() async {
        let container = TriggerContainerSpy()
        container.roots["popup-web"] = webRoot(backDestination: "done")
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        await controller.performDispatch(event: NubrickEvent("popup-web"))
        XCTAssertEqual(modal.presentations.count, 1)

        modal.presentations.first?.viewDidDisappear(false)
        await settleUIKit()

        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 1)
        modal.presentations.first?.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 1)
    }

    @MainActor
    func testSDKDismissalSuppressesSafariBackActionWithAndWithoutSession() throws {
        for hasSession in [false, true] {
            let modal = TriggerModalSpy()
            let session = hasSession ? modal.startTriggerExperiment() : nil
            let root = ModalRootViewController(
                root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
                modalViewController: modal, triggerSession: session
            )
            let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
            safari.loadViewIfNeeded()
            modal.dismissModal()
            safari.viewDidDisappear(false)
            XCTAssertEqual(modal.presentations.count, 1, "SDK dismissal must not open the Back destination")
            XCTAssertFalse(modal.hasActiveTriggerExperiment)
            withExtendedLifetime(root) {}
        }
    }

    @MainActor
    func testEmbeddedReplacementSuppressesSafariBackAction() throws {
        let modal = TriggerModalSpy()
        let data = try JSONDecoder().decode(UIRootBlock.self, from: Data("""
        {"id":"root","data":{"pages":[
          {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"web"}}}},
          {"id":"web","data":{"kind":"WEBVIEW_MODAL","webviewUrl":"https://example.com","triggerSetting":{"onTrigger":{"destinationPageId":"modal"}}}},
          {"id":"modal","data":{"kind":"MODAL"}},
          {"id":"embedded","data":{"kind":"COMPONENT"}}
        ]}}
        """.utf8))
        let root = RootView(
            root: data, container: TriggerContainerSpy(), arguments: nil,
            modalViewController: modal, onEvent: nil
        )
        let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
        safari.loadViewIfNeeded()
        root.presentPage(pageId: "embedded")
        safari.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 1, "Replacing embedded content must not reopen a modal")
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testLaunchForegroundNotificationDoesNotRepeatStartupTriggers() async {
        let countKey = UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue
        let previousCount = UserDefaults.standard.object(forKey: countKey)
        defer { UserDefaults.standard.set(previousCount, forKey: countKey) }
        let startup = expectation(description: "Startup triggers fetched")
        let duplicate = expectation(description: "No duplicate trigger fetch at launch")
        duplicate.isInverted = true
        let container = TriggerContainerSpy()
        var batches = [[String]]()
        container.onFetchTriggers = { triggers in
            batches.append(triggers)
            if batches.count == 1 { startup.fulfill() }
            else { duplicate.fulfill() }
        }
        var dispatched = [String]()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: nil,
            onDispatch: { dispatched.append($0.name) }
        )

        controller.initialLoad()
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        await fulfillment(of: [startup, duplicate], timeout: 0.2)

        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue }.count, 1)
        XCTAssertFalse(dispatched.contains(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue))
        XCTAssertTrue(batches.first?.contains(TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue) == true)
    }

    @MainActor
    func testFirstAndSubsequentForegroundReturnsDispatchEvents() async {
        let countKey = UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue
        let previousCount = UserDefaults.standard.object(forKey: countKey)
        defer { UserDefaults.standard.set(previousCount, forKey: countKey) }
        // Initialization can happen after UIKit has already posted the launch notification.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        let startup = expectation(description: "Startup triggers fetched")
        let container = TriggerContainerSpy()
        container.onFetchTriggers = { _ in startup.fulfill() }
        var dispatched = [String]()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: nil,
            onDispatch: { dispatched.append($0.name) }
        )
        controller.initialLoad()
        await fulfillment(of: [startup], timeout: 1)

        for visit in 1...2 {
            let foreground = expectation(description: "Foreground return \(visit)")
            let duplicate = expectation(description: "No repeated fetch for return \(visit)")
            duplicate.isInverted = true
            var batches = [[String]]()
            container.onFetchTriggers = { triggers in
                batches.append(triggers)
                if batches.count == 1 {
                    foreground.fulfill()
                } else {
                    duplicate.fulfill()
                }
            }
            dispatched.removeAll()
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            await fulfillment(of: [foreground, duplicate], timeout: 0.2)
            XCTAssertEqual(batches.count, 1)
            XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue }.count, 1)
            XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue }.count, 1)
            XCTAssertTrue(batches.first?.contains(TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue) == true)
        }
    }

    @MainActor
    func testInitializationAfterBackgroundDispatchesStartupWithoutForegroundReturn() async {
        let countKey = UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue
        let previousCount = UserDefaults.standard.object(forKey: countKey)
        defer { UserDefaults.standard.set(previousCount, forKey: countKey) }
        UserDefaults.standard.set(0, forKey: countKey)

        // The controller did not exist when the app entered the background.
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        let container = TriggerContainerSpy()
        var batches = [[String]]()
        var dispatched = [String]()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: nil,
            onDispatch: { dispatched.append($0.name) }
        )
        let startup = expectation(description: "Startup triggers fetched before foreground entry")
        let duplicate = expectation(description: "No duplicate startup fetch")
        duplicate.isInverted = true
        container.onFetchTriggers = { triggers in
            batches.append(triggers)
            if batches.count == 1 { startup.fulfill() }
            else { duplicate.fulfill() }
        }
        controller.initialLoad()
        await fulfillment(of: [startup], timeout: 1)

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        await fulfillment(of: [duplicate], timeout: 0.2)

        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches.first, dispatched)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_BOOT_APP.rawValue }.count, 1)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY.rawValue }.count, 1)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue }.count, 1)
        XCTAssertFalse(dispatched.contains(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue))

        let foreground = expectation(description: "Subsequent foreground return")
        container.onFetchTriggers = { triggers in
            batches.append(triggers)
            foreground.fulfill()
        }
        dispatched.removeAll()
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        await fulfillment(of: [foreground], timeout: 1)

        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(batches.last, dispatched)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue }.count, 1)
        XCTAssertEqual(dispatched.filter { $0 == TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue }.count, 1)
        XCTAssertFalse(dispatched.contains(TriggerEventNameDefs.USER_BOOT_APP.rawValue))
        XCTAssertFalse(dispatched.contains(TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY.rawValue))
    }

    @MainActor
    func testTooltipCallbackIncludesExperimentAndVariantContext() async {
        var receivedData: String?
        var receivedExperimentId: String?
        var receivedVariantId: String?
        let controller = TriggerViewController(
            user: NubrickUser(),
            container: TriggerContainerSpy(),
            modalViewController: nil,
            onTooltip: { data, experimentId, variantId in
                receivedData = data
                receivedExperimentId = experimentId
                receivedVariantId = variantId
            }
        )

        controller.initialLoad()
        await controller.performDispatch(event: NubrickEvent("tooltip-trigger"))

        guard let receivedData,
              let jsonData = receivedData.data(using: .utf8),
              let block = try? JSONDecoder().decode(UIBlock.self, from: jsonData),
              case .EUIRootBlock(let root) = block else {
            XCTFail("Expected an encoded root block")
            return
        }
        XCTAssertEqual(root.id, "tooltip-root")
        XCTAssertEqual(receivedExperimentId, "tooltip-experiment-id")
        XCTAssertEqual(receivedVariantId, "tooltip-variant-id")
    }
}

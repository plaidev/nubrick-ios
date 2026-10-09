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
    @MainActor var onTriggerRecordingPaused: (() -> Void)?
    @MainActor var onDisplayRecordingPaused: (() -> Void)?
    @MainActor var onDisplayed: (() -> Void)?
    @MainActor var popupFetches = [String]()
    @MainActor var recordedTriggers = [String]()
    @MainActor var recordedSources = [String?]()
    @MainActor var failedTriggers = Set<String>()
    @MainActor var displayedExperiments = [String]()
    @MainActor var handledActions = [UIBlockAction]()
    @MainActor var roots = [String: UIRootBlock]()
    @MainActor var firstFetchContinuation: CheckedContinuation<Void, Never>?
    @MainActor var triggerRecordingContinuation: CheckedContinuation<Void, Never>?
    @MainActor var displayRecordingContinuation: CheckedContinuation<Void, Never>?
    @MainActor var shouldPauseDisplayRecording = false
    @MainActor var shouldPauseTriggerRecording = false

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
    func handleEvent(_ it: UIBlockAction) { self.handledActions.append(it) }

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
        kinds: [ExperimentKind]
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
        kinds: [ExperimentKind]
    ) async -> Result<FetchedTriggerContent, NubrickError> {
        await MainActor.run { onFetchTriggers?(triggers) }
        if let trigger = triggers.first(where: { $0.hasPrefix("popup-") || $0 == "tooltip-trigger" }) {
            return await self.fetchTriggerContent(trigger: trigger, kinds: kinds)
        }
        return .failure(.notFound)
    }

    func recordTriggerEvents(events: [NubrickEvent], sourceExperimentId: String?) async -> [String] {
        let triggers = events.map(\.name)
        await MainActor.run {
            self.recordedTriggers.append(contentsOf: triggers)
            self.recordedSources.append(sourceExperimentId)
        }
        if await MainActor.run(body: { self.shouldPauseTriggerRecording }) {
            await self.pauseTriggerRecording()
        }
        return await MainActor.run { triggers.filter { !self.failedTriggers.contains($0) } }
    }

    @MainActor
    private func pauseTriggerRecording() async {
        await withCheckedContinuation { continuation in
            self.triggerRecordingContinuation = continuation
            self.onTriggerRecordingPaused?()
        }
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
    func testTooltipAndPopupShareClaimAndIgnoreStaleCleanup() {
        let modal = TriggerModalSpy()
        XCTAssertNil(modal.startTriggerExperiment(""))
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertNotNil(modal.startTriggerExperiment("tooltip-one"))
        XCTAssertTrue(modal.ownsTriggerExperiment("tooltip-one"))
        XCTAssertFalse(modal.beginDisplayRecording("wrong-session"))
        XCTAssertNil(modal.startTriggerExperiment())
        XCTAssertNil(modal.startTriggerExperiment("tooltip-two"))
        modal.finishTriggerExperiment("wrong-session")
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        modal.finishTriggerExperiment("tooltip-one")
        let popup = modal.startTriggerExperiment()!
        XCTAssertNil(modal.startTriggerExperiment("tooltip-two"))
        modal.finishTriggerExperiment("tooltip-one")
        XCTAssertTrue(modal.ownsTriggerExperiment(popup))
        modal.finishTriggerExperiment(popup)
        XCTAssertNotNil(modal.startTriggerExperiment("tooltip-two"))
        modal.finishTriggerExperiment("tooltip-two")
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
    }

    @MainActor
    func testTooltipKeepsClaimUntilDismissalAndRecordingBothFinish() {
        let modal = TriggerModalSpy()
        XCTAssertNotNil(modal.startTriggerExperiment("one"))
        XCTAssertTrue(modal.beginDisplayRecording("one"))
        modal.finishDisplayRecording("one")
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertFalse(modal.beginDisplayRecording("one"))
        modal.finishTriggerExperiment("one")
        XCTAssertFalse(modal.hasActiveTriggerExperiment)

        XCTAssertNotNil(modal.startTriggerExperiment("two"))
        XCTAssertTrue(modal.beginDisplayRecording("two"))
        modal.finishTriggerExperiment("two")
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertNil(modal.startTriggerExperiment())
        modal.finishDisplayRecording("two")
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
    }

    @MainActor
    func testDisplayRecordingIsSharedByAllSessionTypes() throws {
        let modal = TriggerModalSpy()
        for tooltip in [false, true] {
            let session: String
            if tooltip {
                session = "tooltip-recording"
                XCTAssertNotNil(modal.startTriggerExperiment(session))
            } else {
                session = try XCTUnwrap(modal.startTriggerExperiment())
                modal.presentNavigation(pageView: PageView(page: nil, props: nil,
                    container: TriggerContainerSpy(), arguments: nil,
                    actionHandler: nil, modalViewController: modal),
                    modalPresentationStyle: nil, modalScreenSize: nil,
                    backButtonActionHandler: nil)
            }
            XCTAssertTrue(modal.beginDisplayRecording(session))
            XCTAssertFalse(modal.beginDisplayRecording(session))
            modal.finishDisplayRecording(session)
            XCTAssertFalse(modal.beginDisplayRecording(session), "Finished recording cannot start again in the same session")
            if !tooltip { modal.presentations.last?.viewDidDisappear(false) }
            modal.finishTriggerExperiment(session)
            XCTAssertFalse(modal.hasActiveTriggerExperiment)
            XCTAssertFalse(modal.beginDisplayRecording(session))
        }
    }

    @MainActor
    func testStopFinishesSessionAfterNativePresentationCloses() throws {
        let modal = TriggerModalSpy()
        XCTAssertNotNil(modal.startTriggerExperiment("session"))
        modal.presentWebview(url: "https://example.com", backButtonActionHandler: nil)
        XCTAssertTrue(modal.beginDisplayRecording("session"))
        modal.stopTriggerExperiment("session")
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        modal.finishDisplayRecording("session")
        XCTAssertTrue(modal.hasActiveTriggerExperiment, "Recording completion must still wait for native dismissal")
        XCTAssertNil(modal.startTriggerExperiment("next"))
        modal.presentations.last?.viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertFalse(modal.beginDisplayRecording("session"))
    }

    @MainActor
    func testTooltipResetMakesDelayedRecordingHarmless() {
        let modal = TriggerModalSpy()
        XCTAssertNotNil(modal.startTriggerExperiment("old"))
        XCTAssertTrue(modal.beginDisplayRecording("old"))
        modal.resetTriggerExperiment()
        XCTAssertNotNil(modal.startTriggerExperiment("new"))
        modal.finishDisplayRecording("old")
        modal.finishTriggerExperiment("old")
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        modal.finishTriggerExperiment("new")
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
    }

    @MainActor
    func testTooltipBlocksFetchesButStillRecordsDispatchedEvents() async {
        let container = TriggerContainerSpy()
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container,
            modalViewController: modal)
        controller.initialLoad()
        XCTAssertNotNil(modal.startTriggerExperiment("tooltip"))
        await controller.performDispatch(events: [NubrickEvent("popup-blocked")])
        XCTAssertTrue(container.recordedTriggers.contains("popup-blocked"))
        XCTAssertTrue(container.popupFetches.isEmpty)
        XCTAssertTrue(container.displayedExperiments.isEmpty)
        modal.finishTriggerExperiment("tooltip")
        await controller.performDispatch(events: [NubrickEvent("popup-next")])
        XCTAssertEqual(container.popupFetches, ["popup-next"])
    }

    @MainActor
    func testCustomDispatchCallbackWaitsForRecordingWhenFetchingIsSkipped() async throws {
        for reason in ["before-load", "active-popup", "recording-failed"] {
            let recordingPaused = expectation(description: "Trigger recording paused")
            let container = TriggerContainerSpy()
            let modal = TriggerModalSpy()
            let name = "popup-\(reason)"
            var dispatched = [String]()
            let controller = TriggerViewController(
                user: NubrickUser(), container: container, modalViewController: modal,
                onDispatch: { if $0.name == name { dispatched.append($0.name) } }
            )
            if reason != "before-load" {
                let startup = expectation(description: "Startup fetch completed")
                container.onFetchTriggers = { _ in startup.fulfill() }
                controller.initialLoad()
                await fulfillment(of: [startup], timeout: 1)
            }
            if reason == "active-popup" {
                _ = try XCTUnwrap(modal.startTriggerExperiment())
            }
            if reason == "recording-failed" {
                container.failedTriggers = [name]
            }
            container.onFetchTriggers = { _ in XCTFail("This dispatch must skip fetching") }
            container.shouldPauseTriggerRecording = true
            container.onTriggerRecordingPaused = { recordingPaused.fulfill() }

            let dispatch = Task { await controller.performDispatch(events: [NubrickEvent(name)]) }
            await fulfillment(of: [recordingPaused], timeout: 1)
            XCTAssertTrue(dispatched.isEmpty)
            container.triggerRecordingContinuation?.resume()
            await dispatch.value

            XCTAssertEqual(dispatched, [name])
            XCTAssertTrue(container.recordedTriggers.contains(name))
            XCTAssertTrue(modal.presentations.isEmpty)
        }
    }

    @MainActor
    func testLifecycleCallbacksFollowRecordingBeforeFetching() async {
        let countKey = UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue
        let previousCount = UserDefaults.standard.object(forKey: countKey)
        defer { UserDefaults.standard.set(previousCount, forKey: countKey) }
        let container = TriggerContainerSpy()
        container.shouldPauseTriggerRecording = true
        var dispatched = [String]()
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: nil,
            onDispatch: {
                XCTAssertTrue(container.recordedTriggers.contains($0.name))
                dispatched.append($0.name)
            }
        )

        for visit in 0...1 {
            let recordingPaused = expectation(description: "Lifecycle recording paused")
            let fetched = expectation(description: "Lifecycle fetch completed")
            container.recordedTriggers.removeAll()
            dispatched.removeAll()
            container.onTriggerRecordingPaused = { recordingPaused.fulfill() }
            container.onFetchTriggers = { triggers in
                XCTAssertEqual(dispatched, triggers)
                fetched.fulfill()
            }
            if visit == 0 {
                controller.initialLoad()
            } else {
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
                controller.willEnterForeground()
            }
            await fulfillment(of: [recordingPaused], timeout: 1)
            XCTAssertTrue(dispatched.isEmpty, "Lifecycle callbacks must wait for recording")
            container.triggerRecordingContinuation?.resume()
            await fulfillment(of: [fetched], timeout: 1)
            XCTAssertFalse(dispatched.isEmpty)
            XCTAssertEqual(dispatched, container.recordedTriggers)
        }
    }

    @MainActor
    func testSingleAndBatchedDispatchUseCurrentPopupStateAfterRecording() async throws {
        for names in [["popup-next"], ["unmatched", "popup-next"]] {
            let startup = expectation(description: "Startup fetch completed")
            let recordingPaused = expectation(description: "Trigger recording paused")
            let container = TriggerContainerSpy()
            container.onFetchTriggers = { _ in startup.fulfill() }
            let modal = TriggerModalSpy()
            var dispatched = [String]()
            let controller = TriggerViewController(
                user: NubrickUser(), container: container, modalViewController: modal,
                onDispatch: { dispatched.append($0.name) }
            )
            controller.initialLoad()
            await fulfillment(of: [startup], timeout: 1)
            dispatched.removeAll()
            var fetched = [[String]]()
            container.onFetchTriggers = { triggers in
                XCTAssertEqual(dispatched, names, "Callbacks must precede fetching")
                fetched.append(triggers)
            }
            container.shouldPauseTriggerRecording = true
            container.onTriggerRecordingPaused = { recordingPaused.fulfill() }
            let session = try XCTUnwrap(modal.startTriggerExperiment())

            let dispatch = Task {
                await controller.performDispatch(
                    events: names.map { NubrickEvent($0) }, sourceExperimentId: "source-experiment"
                )
            }
            await fulfillment(of: [recordingPaused], timeout: 1)
            XCTAssertTrue(dispatched.isEmpty, "Custom event callbacks must wait for recording")
            XCTAssertEqual(container.recordedSources.last, "source-experiment")
            XCTAssertTrue(fetched.isEmpty)

            modal.finishTriggerExperiment(session)
            XCTAssertFalse(modal.hasActiveTriggerExperiment)
            container.triggerRecordingContinuation?.resume()
            await dispatch.value

            XCTAssertEqual(fetched, [names])
            XCTAssertEqual(modal.presentations.count, 1)
            XCTAssertEqual(dispatched, names, "Each event is notified only once")
        }
    }

    @MainActor
    func testDispatchSelectsContentOnlyForSuccessfullyRecordedEvents() async {
        for names in [["popup-failed"], ["popup-failed", "popup-ready"]] {
            let startup = expectation(description: "Startup fetch completed")
            let container = TriggerContainerSpy()
            container.onFetchTriggers = { _ in startup.fulfill() }
            let modal = TriggerModalSpy()
            var dispatched = [String]()
            let controller = TriggerViewController(
                user: NubrickUser(), container: container, modalViewController: modal,
                onDispatch: { dispatched.append($0.name) }
            )
            controller.initialLoad()
            await fulfillment(of: [startup], timeout: 1)
            dispatched.removeAll()
            container.recordedTriggers.removeAll()
            container.failedTriggers = ["popup-failed"]
            var fetched = [[String]]()
            container.onFetchTriggers = { fetched.append($0) }

            await controller.performDispatch(events: names.map { NubrickEvent($0) })

            XCTAssertEqual(dispatched, names)
            XCTAssertEqual(container.recordedTriggers, names)
            let successful = names.filter { $0 != "popup-failed" }
            XCTAssertEqual(fetched, successful.isEmpty ? [] : [successful])
            XCTAssertEqual(container.popupFetches, successful)
            XCTAssertEqual(modal.presentations.count, successful.isEmpty ? 0 : 1)
        }
    }

    @MainActor
    func testDispatchBeforeInitialLoadRecordsAndNotifiesWithoutFetching() async {
        let container = TriggerContainerSpy()
        var dispatched = [String]()
        var fetched = [[String]]()
        container.onFetchTriggers = { fetched.append($0) }
        let controller = TriggerViewController(
            user: NubrickUser(), container: container, modalViewController: nil,
            onDispatch: { dispatched.append($0.name) }
        )

        await controller.performDispatch(events: [NubrickEvent("popup-before-load")])

        XCTAssertEqual(dispatched, ["popup-before-load"])
        XCTAssertEqual(container.recordedTriggers, ["popup-before-load"])
        XCTAssertTrue(fetched.isEmpty)
    }

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

        await controller.performDispatch(events: [NubrickEvent("popup-first-shown")])
        XCTAssertEqual(modal.presentations.count, 1)
        modal.onShown?()
        await fulfillment(of: [recordingPaused], timeout: 1)

        modal.presentations.last?.viewDidDisappear(false)
        await settleUIKit()
        XCTAssertTrue(modal.hasActiveTriggerExperiment)

        await controller.performDispatch(events: [NubrickEvent("popup-before-history")])
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertEqual(container.popupFetches, ["popup-first-shown"])
        XCTAssertTrue(container.recordedTriggers.contains("popup-before-history"))

        container.displayRecordingContinuation?.resume()
        await fulfillment(of: [displayed], timeout: 1)
        await settleUIKit()
        XCTAssertFalse(modal.hasActiveTriggerExperiment)

        await controller.performDispatch(events: [NubrickEvent("popup-after-history")])
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
        container.onFetchTriggers = nil

        let first = Task { await controller.performDispatch(events: [NubrickEvent("popup-first")]) }
        await fulfillment(of: [paused], timeout: 1)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        await controller.performDispatch(events: [NubrickEvent("popup-second")])
        XCTAssertEqual(container.popupFetches, ["popup-first", "popup-second"])
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertTrue(container.displayedExperiments.isEmpty)

        container.firstFetchContinuation?.resume()
        await first.value
        XCTAssertEqual(modal.presentations.count, 1)
        await controller.performDispatch(events: [NubrickEvent("popup-third")])
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
        await controller.performDispatch(events: [NubrickEvent("popup-fourth")])
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
    private func nativeRoot(backDestination: String = "modal-two", backButtonVisible: Bool = true) -> UIRootBlock {
        try! JSONDecoder().decode(UIRootBlock.self, from: Data("""
        {"id":"root","data":{"pages":[
          {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"modal"}}}},
          {"id":"modal","data":{"kind":"MODAL","modalNavigationBackButton":{"visible":\(backButtonVisible)},"triggerSetting":{"onTrigger":{"eventName":"native-back","destinationPageId":"\(backDestination)"}}}},
          {"id":"modal-two","data":{"kind":"MODAL","triggerSetting":{"onTrigger":{"eventName":"second-back","destinationPageId":"done"}}}},
          {"id":"done","data":{"kind":"DISMISSED"}}
        ]}}
        """.utf8))
    }

    @MainActor
    func testNativeDismissalContinuesSameExperimentAndRecordsOnlyOnce() async throws {
        let container = TriggerContainerSpy()
        container.roots["popup-native"] = nativeRoot()
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        await controller.performDispatch(events: [NubrickEvent("popup-native")])
        let first = try XCTUnwrap(modal.presentations.first as? NavigationViewControlller)
        modal.onShown?()
        await settleUIKit()
        XCTAssertEqual(container.displayedExperiments, ["popup-native"])

        first.viewDidDisappear(false)

        XCTAssertTrue(modal.hasActiveTriggerExperiment, "The dismissal action continues within the current experiment")
        XCTAssertEqual(modal.presentations.count, 2, "The continuation creates a new presentation after the old stack is cleared")
        let second = try XCTUnwrap(modal.presentations.last as? NavigationViewControlller)
        XCTAssertFalse(first === second)
        XCTAssertEqual((second.topViewController as? ModalPageViewController)?.pageId, "modal-two")
        XCTAssertEqual(container.handledActions.compactMap(\.eventName), ["native-back"])
        first.viewDidDisappear(false)
        XCTAssertEqual(modal.presentations.count, 2, "A repeated disappearance must not repeat the configured action")

        modal.onShown?()
        await settleUIKit()
        XCTAssertEqual(container.displayedExperiments, ["popup-native"])
        second.viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(container.handledActions.compactMap(\.eventName), ["native-back", "second-back"])
    }

    @MainActor
    func testNativeDismissalUsesVisiblePageActionInsteadOfFirstPageAction() throws {
        let container = TriggerContainerSpy()
        let modal = TriggerModalSpy()
        let session = try XCTUnwrap(modal.startTriggerExperiment())
        let root = ModalRootViewController(
            root: nativeRoot(), container: container, modalViewController: modal, triggerSession: session
        )
        let navigation = try XCTUnwrap(modal.presentations.first as? NavigationViewControlller)
        let page = try JSONDecoder().decode(UIPageBlock.self, from: Data("""
        {"id":"visible","data":{"kind":"MODAL","triggerSetting":{"onTrigger":{"eventName":"visible-back"}}}}
        """.utf8))
        let visible = ModalPageViewController(pageView: PageView(
            page: page, props: nil, container: container, arguments: nil,
            actionHandler: nil, modalViewController: modal
        ))
        visible.backButtonActionHandler = makeBackButtonAction(
            event: page.data?.triggerSetting?.onTrigger,
            context: UIBlockContext(UIBlockContextInit(container: container, actionHandler: { action, _ in
                XCTAssertTrue(modal.ownsTriggerExperiment(session), "The session remains owned while the configured action runs")
                container.handleEvent(action)
            }))
        )
        navigation.pushViewController(visible, animated: false)

        navigation.viewDidDisappear(false)
        navigation.viewDidDisappear(false)

        XCTAssertEqual(container.handledActions.compactMap(\.eventName), ["visible-back"])
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testSDKDismissalAndResetSuppressNativeBackActionWithAndWithoutSession() throws {
        for hasSession in [false, true] {
            for reset in [false, true] {
                let container = TriggerContainerSpy()
                let modal = TriggerModalSpy()
                let root: AnyObject
                let session = hasSession ? try XCTUnwrap(modal.startTriggerExperiment()) : nil
                if let session {
                    root = ModalRootViewController(
                        root: nativeRoot(), container: container, modalViewController: modal, triggerSession: session
                    )
                } else {
                    root = RootView(root: nativeRoot(), container: container, modalViewController: modal, onEvent: nil)
                }
                let navigation = try XCTUnwrap(modal.presentations.first as? NavigationViewControlller)

                if reset {
                    modal.resetTriggerExperiment()
                } else if let session {
                    modal.stopTriggerExperiment(session)
                } else {
                    modal.dismissModal()
                }
                navigation.viewDidDisappear(false)
                navigation.viewDidDisappear(false)

                XCTAssertEqual(modal.presentations.count, 1, "Programmatic dismissal must not reopen the configured destination")
                XCTAssertTrue(container.handledActions.compactMap(\.eventName).isEmpty)
                XCTAssertFalse(modal.hasActiveTriggerExperiment)
                withExtendedLifetime(root) {}
            }
        }
    }

    @MainActor
    func testConfiguredNativeCloseToDismissedPageDispatchesOnlyOnce() throws {
        let container = TriggerContainerSpy()
        let modal = TriggerModalSpy()
        let session = try XCTUnwrap(modal.startTriggerExperiment())
        let root = ModalRootViewController(
            root: nativeRoot(backDestination: "done"), container: container,
            modalViewController: modal, triggerSession: session
        )
        let navigation = try XCTUnwrap(modal.presentations.first as? NavigationViewControlller)
        let page = try XCTUnwrap(navigation.topViewController as? ModalPageViewController)
        page.loadViewIfNeeded()
        let button = try XCTUnwrap(page.navigationItem.leftBarButtonItem)
        let target = try XCTUnwrap(button.target as? NSObject)
        let action = try XCTUnwrap(button.action)

        _ = target.perform(action)
        navigation.viewDidDisappear(false)
        navigation.viewDidDisappear(false)

        XCTAssertEqual(container.handledActions.compactMap(\.eventName), ["native-back"])
        XCTAssertEqual(modal.presentations.count, 1)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testNativeGestureDismissalDispatchesActionWhenCloseButtonIsHidden() throws {
        let container = TriggerContainerSpy()
        let modal = TriggerModalSpy()
        let session = try XCTUnwrap(modal.startTriggerExperiment())
        let root = ModalRootViewController(
            root: nativeRoot(backDestination: "done", backButtonVisible: false), container: container,
            modalViewController: modal, triggerSession: session
        )
        let navigation = try XCTUnwrap(modal.presentations.first as? NavigationViewControlller)
        let page = try XCTUnwrap(navigation.topViewController as? ModalPageViewController)
        page.loadViewIfNeeded()
        XCTAssertTrue(page.navigationItem.hidesBackButton)
        XCTAssertNil(page.navigationItem.leftBarButtonItem)

        navigation.viewDidDisappear(false)
        navigation.viewDidDisappear(false)

        XCTAssertEqual(container.handledActions.compactMap(\.eventName), ["native-back"])
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        withExtendedLifetime(root) {}
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
            await controller.performDispatch(events: [NubrickEvent(trigger)])
            XCTAssertFalse(modal.hasActiveTriggerExperiment, trigger)
        }
        modal.canPresent = false
        await controller.performDispatch(events: [NubrickEvent("popup-unpresentable")])
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
        await controller.performDispatch(events: [NubrickEvent("popup-web")])
        XCTAssertTrue(modal.presentations.first is SFSafariViewController)
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        await controller.performDispatch(events: [NubrickEvent("popup-next")])
        XCTAssertEqual(modal.presentations.count, 1)
        modal.onShown?()
        await settleUIKit()
        XCTAssertEqual(container.displayedExperiments, ["popup-web"])
        modal.presentations.first?.viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        await settleUIKit()
        await controller.performDispatch(events: [NubrickEvent("popup-next")])
        XCTAssertEqual(modal.presentations.count, 2)
    }

    @MainActor
    func testStandaloneSafariBackActionContinuesSameExperimentAndRecordsOnlyOnce() async {
        let container = TriggerContainerSpy()
        container.roots["popup-web"] = webRoot(backDestination: "modal")
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(user: NubrickUser(), container: container, modalViewController: modal)
        controller.initialLoad()
        await controller.performDispatch(events: [NubrickEvent("popup-web")])
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
        let root = RootView(
            root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
            modalViewController: modal, onEvent: nil
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
        let root = RootView(
            root: webRoot(backDestination: "done"), container: TriggerContainerSpy(),
            modalViewController: modal, onEvent: nil
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
        await controller.performDispatch(events: [NubrickEvent("popup-web")])
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
            let root: AnyObject
            let session = hasSession ? try XCTUnwrap(modal.startTriggerExperiment()) : nil
            if let session {
                root = ModalRootViewController(
                    root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
                    modalViewController: modal, triggerSession: session
                )
            } else {
                root = RootView(
                    root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
                    modalViewController: modal, onEvent: nil
                )
            }
            let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
            safari.loadViewIfNeeded()
            if let session { modal.stopTriggerExperiment(session) }
            else { modal.dismissModal() }
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
        var receivedSessionId: String?
        let modal = TriggerModalSpy()
        let controller = TriggerViewController(
            user: NubrickUser(),
            container: TriggerContainerSpy(),
            modalViewController: modal,
            onTooltip: { data, experimentId, variantId, sessionId in
                XCTAssertTrue(modal.hasActiveTriggerExperiment)
                receivedData = data
                receivedExperimentId = experimentId
                receivedVariantId = variantId
                receivedSessionId = sessionId
            }
        )

        controller.initialLoad()
        await controller.performDispatch(events: [NubrickEvent("tooltip-trigger")])

        guard let receivedData,
              let jsonData = receivedData.data(using: .utf8),
              let block = try? JSONDecoder().decode(UIBlock.self, from: jsonData),
              case .EUIRootBlock(let root) = block else {
            XCTFail("Expected an encoded root block")
            return
        }
        XCTAssertEqual(root.id, "tooltip-root")
        guard let receivedSessionId else { return XCTFail("Expected a session ID") }
        XCTAssertNotEqual(receivedSessionId, root.id)
        XCTAssertTrue(modal.ownsTriggerExperiment(receivedSessionId))
        await controller.performDispatch(events: [NubrickEvent("popup-blocked")])
        XCTAssertTrue(modal.ownsTriggerExperiment(receivedSessionId))
        modal.stopTriggerExperiment(receivedSessionId)
        XCTAssertEqual(receivedExperimentId, "tooltip-experiment-id")
        XCTAssertEqual(receivedVariantId, "tooltip-variant-id")
    }
    @MainActor
    func testStaleTooltipDismissalCannotCloseTheNextExperiment() throws {
        let modal = TriggerModalSpy()
        let container = TriggerContainerSpy()
        XCTAssertNotNil(modal.startTriggerExperiment("old"))
        var dismissals = 0
        var events = [String]()
        let oldRoot = RootView(root: webRoot(backDestination: "done"), container: container,
            modalViewController: modal,
            onEvent: { action in if let name = action.eventName { events.append(name) } },
            onDismiss: { dismissals += 1 }, sessionId: "old")
        modal.stopTriggerExperiment("old")
        try XCTUnwrap(modal.presentations.first).viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertNotNil(modal.startTriggerExperiment("new"))
        let newRoot = RootView(root: webRoot(backDestination: "done"), container: TriggerContainerSpy(),
            modalViewController: modal, onEvent: nil, sessionId: "new")
        let dismissalsBeforeStaleCallback = dismissals
        oldRoot.dispatchAction(UIBlockAction(eventName: "delayed-tap",
            destinationPageId: "done", submitSurveyResponse: true))
        oldRoot.presentPage(pageId: "done")
        modal.stopTriggerExperiment("old")
        XCTAssertTrue(modal.hasPresentedContent)
        XCTAssertTrue(modal.ownsTriggerExperiment("new"))
        XCTAssertEqual(dismissals, dismissalsBeforeStaleCallback)
        XCTAssertEqual(events, ["delayed-tap"])
        XCTAssertEqual(container.handledActions.last?.eventName, "delayed-tap")
        XCTAssertEqual(container.handledActions.last?.submitSurveyResponse, true)
        withExtendedLifetime(newRoot) {}
    }

    @MainActor
    func testTooltipNativeModalReturnKeepsSessionAndNativeDismissalEndsIt() throws {
        let modal = TriggerModalSpy()
        let session = "native-tooltip"
        XCTAssertNotNil(modal.startTriggerExperiment(session))
        let data = Data("""
        {"id":"tooltip-root","data":{"pages":[
          {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"tooltip"}}}},
          {"id":"tooltip","data":{"kind":"TOOLTIP"}},
          {"id":"modal","data":{"kind":"MODAL","triggerSetting":{"onTrigger":{"destinationPageId":"tooltip"}}}},
          {"id":"done","data":{"kind":"DISMISSED"}}
        ]}}
        """.utf8)
        var tooltips = [String]()
        let root = RootView(root: try JSONDecoder().decode(UIRootBlock.self, from: data),
            container: TriggerContainerSpy(), modalViewController: modal, onEvent: nil,
            onNextTooltip: { tooltips.append($0) },
            onDismiss: { modal.finishTriggerExperiment(session) }, sessionId: session)
        root.presentPage(pageId: "modal")
        XCTAssertTrue(modal.ownsTriggerExperiment(session))
        XCTAssertNil(modal.startTriggerExperiment())
        let navigation = try XCTUnwrap(modal.presentations.last as? NavigationViewControlller)
        navigation.viewDidDisappear(false)
        XCTAssertEqual(tooltips, ["tooltip", "tooltip"])
        XCTAssertTrue(modal.ownsTriggerExperiment(session))
        root.presentPage(pageId: "done")
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
    }

    @MainActor
    func testFlutterStopWaitsForNativePresentationAndSuppressesItsReturnAction() throws {
        let modal = TriggerModalSpy()
        let session = "stopped-tooltip"
        XCTAssertNotNil(modal.startTriggerExperiment(session))
        let root = RootView(root: webRoot(backDestination: "modal"), container: TriggerContainerSpy(),
            modalViewController: modal, onEvent: nil,
            onDismiss: { modal.finishTriggerExperiment(session) }, sessionId: session)
        let safari = try XCTUnwrap(modal.presentations.first as? SFSafariViewController)
        modal.stopTriggerExperiment(session)
        XCTAssertTrue(modal.hasActiveTriggerExperiment)
        XCTAssertFalse(modal.ownsTriggerExperiment(session), "Stopped flows cannot navigate while native UI closes")
        safari.viewDidDisappear(false)
        XCTAssertFalse(modal.hasActiveTriggerExperiment)
        XCTAssertEqual(modal.presentations.count, 1)
        withExtendedLifetime(root) {}
    }

    @MainActor
    func testDefaultBackPreservesNavigationAndDismissalFinishesBothExperimentFlows() async throws {
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        for flutter in [false, true] {
            let host = UIViewController()
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let modal = ModalComponentViewController()
            host.addChild(modal)
            host.view.addSubview(modal.view)
            modal.didMove(toParent: host)
            let session = try XCTUnwrap(modal.startTriggerExperiment())
            let rootData = try JSONDecoder().decode(UIRootBlock.self, from: Data("""
            {"id":"root","data":{"pages":[
              {"id":"start","data":{"kind":"TRIGGER","triggerSetting":{"onTrigger":{"destinationPageId":"\(flutter ? "tooltip" : "first")"}}}},
              {"id":"tooltip","data":{"kind":"TOOLTIP"}},
              {"id":"first","data":{"kind":"MODAL"}},
              {"id":"second","data":{"kind":"MODAL"}}
            ]}}
            """.utf8))
            let root: AnyObject
            let navigate: (String) -> Void
            if flutter {
                let tooltipRoot = RootView(root: rootData, container: TriggerContainerSpy(),
                    modalViewController: modal, onEvent: nil, onNextTooltip: { _ in },
                    onDismiss: { modal.finishTriggerExperiment(session) }, sessionId: session)
                root = tooltipRoot
                navigate = tooltipRoot.presentPage
                navigate("first")
            } else {
                let modalRoot = ModalRootViewController(root: rootData, container: TriggerContainerSpy(),
                    modalViewController: modal, triggerSession: session)
                root = modalRoot
                navigate = modalRoot.presentPage
            }
            try await Task.sleep(nanoseconds: 800_000_000)
            let navigation = try XCTUnwrap(host.presentedViewController as? NavigationViewControlller)
            let first = try XCTUnwrap(navigation.topViewController as? ModalPageViewController)
            XCTAssertNil(first.backButtonActionHandler)

            navigate("second")
            try await Task.sleep(nanoseconds: 100_000_000)
            let second = try XCTUnwrap(navigation.topViewController as? ModalPageViewController)
            XCTAssertEqual(navigation.viewControllers.count, 2)
            XCTAssertNil(second.backButtonActionHandler)
            second.onClickBack()
            try await Task.sleep(nanoseconds: 600_000_000)
            XCTAssertTrue(navigation.topViewController === first)
            XCTAssertTrue(modal.ownsTriggerExperiment(session), "Popping a page keeps the experiment running")


            first.onClickBack()
            // Deliver UIKit's dismissal callback explicitly in this application-less test runner.
            navigation.onDismissed?(navigation)
            XCTAssertFalse(modal.hasActiveTriggerExperiment, "Final dismissal finishes the experiment")
            withExtendedLifetime(root) {}
        }
    }

}

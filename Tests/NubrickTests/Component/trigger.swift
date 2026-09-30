import Combine
import XCTest
import UIKit
@testable import NubrickLocal

private final class TriggerContainerSpy: Container, @unchecked Sendable {
    let experimentId: String? = nil
    let variantId: String? = nil

    @MainActor var onFetchTriggers: (([String]) -> Void)?

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

    func fetchRemoteConfig(
        experimentId: String
    ) async -> Result<(String, ExperimentVariant), NubrickError> {
        .failure(.notFound)
    }
}

final class TriggerViewControllerTests: XCTestCase {
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

import Combine
import XCTest
@testable import NubrickLocal

private final class TriggerContainerSpy: Container, @unchecked Sendable {
    let experimentId: String? = nil
    let variantId: String? = nil

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
    func setFormValue(key: String, value: Any) {}

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

    func fetchRemoteConfig(
        experimentId: String
    ) async -> Result<(String, ExperimentVariant), NubrickError> {
        .failure(.notFound)
    }
}

final class TriggerViewControllerTests: XCTestCase {
    @MainActor
    func testTooltipCallbackIncludesExperimentAndVariantContext() async {
        let callbackSemaphore = DispatchSemaphore(value: 0)
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
                callbackSemaphore.signal()
            }
        )

        controller.initialLoad()
        controller.dispatch(event: NubrickEvent("tooltip-trigger"))

        let waitResult = await Task.detached {
            callbackSemaphore.wait(timeout: .now() + 1)
        }.value
        guard waitResult == .success else {
            XCTFail("Tooltip callback was not invoked")
            return
        }
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

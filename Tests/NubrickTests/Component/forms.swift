import UIKit
import XCTest
@testable import NubrickLocal
import YogaKit

final class TextInputViewTests: XCTestCase {
    @MainActor
    func testAutoHeightIncludesBorderWidth() throws {
        let input = TextInputView(
            block: try makeTextInputBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )
        let textField = try XCTUnwrap(input.subviews.first as? UITextField)

        XCTAssertEqual(input.yoga.borderWidth, 2)
        XCTAssertEqual(
            input.yoga.height.value,
            Float(ceil(textField.intrinsicContentSize.height) + 12 + 4)
        )
    }

    private func makeTextInputBlock() throws -> UITextInputBlock {
        let json = """
        {
          "id": "input",
          "data": {
            "frame": {
              "paddingTop": 5,
              "paddingBottom": 7,
              "borderWidth": 2
            }
          }
        }
        """
        return try JSONDecoder().decode(UITextInputBlock.self, from: Data(json.utf8))
    }
}

final class TooltipViewControllerTests: XCTestCase {
    @MainActor
    func testPopoverUsesSourceViewBoundsAsSourceRect() {
        let source = UIView(frame: CGRect(x: 10, y: 20, width: 24, height: 16))
        let tooltip = TooltipViewController(message: "Invalid", source: source)
        let popover = tooltip.popoverPresentationController

        XCTAssertEqual(tooltip.modalPresentationStyle, .popover)
        XCTAssertEqual(popover?.sourceView, source)
        XCTAssertEqual(popover?.sourceRect, source.bounds)
    }

    @MainActor
    func testPopoverUsesANonEmptySourceRectWhenTheSourceHasNoSize() {
        let source = UIView(frame: .zero)
        let tooltip = TooltipViewController(message: "Invalid", source: source)

        XCTAssertEqual(
            tooltip.popoverPresentationController?.sourceRect,
            CGRect(x: 0, y: 0, width: 1, height: 1)
        )
    }
}

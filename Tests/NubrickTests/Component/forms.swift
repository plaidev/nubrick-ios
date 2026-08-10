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

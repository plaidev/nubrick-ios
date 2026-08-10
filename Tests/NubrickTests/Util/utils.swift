import UIKit
import XCTest
@testable import NubrickLocal

final class ImageUtilTests: XCTestCase {
    func testParseImageFallbackAspectRatioUsesBlurhashMetadata() {
        let src = "https://cdn.nativebrik.com/image?b=blurhash&h=23&w=44"

        XCTAssertEqual(parseImageFallbackAspectRatio(src), 44.0 / 23.0)
    }

    func testParseImageFallbackAspectRatioRequiresBlurhashAndPositiveDimensions() {
        XCTAssertNil(parseImageFallbackAspectRatio("https://cdn.nativebrik.com/image?b=blurhash&h=0&w=44"))
        XCTAssertNil(parseImageFallbackAspectRatio("https://cdn.nativebrik.com/image?h=23&w=44"))
    }

    func testImageAspectRatioRequiresPositiveDimensions() {
        XCTAssertEqual(imageAspectRatio(width: 1080, height: 566), 1080.0 / 566.0)
        XCTAssertNil(imageAspectRatio(width: 0, height: 566))
    }

    func testImageDimensionDerivationRequiresAnOmittedDimension() {
        XCTAssertTrue(hasMissingImageDimension(width: 200, height: nil))
        XCTAssertTrue(hasMissingImageDimension(width: nil, height: 200))
        XCTAssertFalse(hasMissingImageDimension(width: 200, height: 100))
    }
}

final class BorderUtilTests: XCTestCase {
    @MainActor
    func testAsymmetricBorderPathRemainsLocalWhenScrollViewScrolls() throws {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        scrollView.bounds.origin = CGPoint(x: 20, y: 30)
        let frame = try JSONDecoder().decode(
            FrameData.self,
            from: Data(
                """
                {
                  "borderWidth": 2,
                  "borderTopLeftRadius": 8,
                  "borderTopRightRadius": 4,
                  "borderBottomRightRadius": 2,
                  "borderBottomLeftRadius": 0
                }
                """.utf8
            )
        )

        configureBorder(view: scrollView, frame: frame)

        let borderLayer = try XCTUnwrap(
            scrollView.layer.sublayers?.first { $0.name == "border-layer" } as? CAShapeLayer
        )
        let path = try XCTUnwrap(borderLayer.path)
        XCTAssertEqual(borderLayer.frame, scrollView.bounds)
        XCTAssertEqual(path.boundingBoxOfPath, CGRect(x: 1, y: 1, width: 98, height: 98))
    }
}

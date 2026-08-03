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

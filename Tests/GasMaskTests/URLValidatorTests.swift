import XCTest
@testable import Gas_Mask

final class URLValidatorTests: XCTestCase {

    func testEmptyString_isFalse() {
        XCTAssertFalse(URLValidator.isValid(""))
    }

    func testHTTPURL_isFalse() {
        XCTAssertFalse(URLValidator.isValid("http://example.com/hosts"))
    }

    func testHTTPSURL_isTrue() {
        XCTAssertTrue(URLValidator.isValid("https://example.com/hosts"))
    }

    func testFTPURL_isFalse() {
        XCTAssertFalse(URLValidator.isValid("ftp://example.com"))
    }

    func testNoScheme_isFalse() {
        XCTAssertFalse(URLValidator.isValid("example.com"))
    }

    func testHTTPBareScheme_isFalse() {
        // A scheme alone is never a usable Remote source.
        XCTAssertFalse(URLValidator.isValid("http://"))
    }
}

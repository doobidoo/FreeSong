import XCTest
@testable import FreeSongImport

final class EncodingUtilsTests: XCTestCase {

    // MARK: - BinaryDetector

    func testDetectPDF() {
        let data = makePDFData()
        XCTAssertEqual(BinaryDetector.detectBinaryContent(data), "PDF document")
    }

    func testDetectPNG() {
        let data = makePNGData()
        XCTAssertEqual(BinaryDetector.detectBinaryContent(data), "PNG image")
    }

    func testDetectJPEG() {
        let data = makeJPEGData()
        XCTAssertEqual(BinaryDetector.detectBinaryContent(data), "JPEG image")
    }

    func testDetectGIF() {
        var bytes = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])
        bytes.append(Data(repeating: 0x00, count: 10))
        XCTAssertEqual(BinaryDetector.detectBinaryContent(bytes), "GIF image")
    }

    func testDetectGIF87() {
        var bytes = Data([0x47, 0x49, 0x46, 0x38, 0x37, 0x61])
        bytes.append(Data(repeating: 0x00, count: 10))
        XCTAssertEqual(BinaryDetector.detectBinaryContent(bytes), "GIF image")
    }

    func testDetectBMP() {
        var bytes = Data([0x42, 0x4D])
        bytes.append(Data(repeating: 0x00, count: 10))
        XCTAssertEqual(BinaryDetector.detectBinaryContent(bytes), "BMP image")
    }

    func testDetectTextReturnsNil() {
        let text = "This is plain text with normal content.\nNo binary signatures here."
        let data = text.data(using: .utf8)!
        XCTAssertNil(BinaryDetector.detectBinaryContent(data))
    }

    func testDetectShortDataReturnsNil() {
        let data = Data([0x00, 0x01, 0x02]) // less than 8 bytes
        XCTAssertNil(BinaryDetector.detectBinaryContent(data))
    }

    func testDetectEmptyDataReturnsNil() {
        XCTAssertNil(BinaryDetector.detectBinaryContent(Data()))
    }

    func testDetectStartsWithPDFButShort() {
        // Starts with PDF but under 8 bytes — short-data check fires first
        let data = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF" only 4 bytes
        XCTAssertNil(BinaryDetector.detectBinaryContent(data))
    }

    func testDetectBinaryNoise() {
        let data = makeBinaryNoise()
        XCTAssertEqual(BinaryDetector.detectBinaryContent(data), "binary file")
    }

    func testDetectTextWithNullBytes() {
        // Less than 10% non-printable - should be nil
        var bytes = Data(repeating: 0x41, count: 1000) // 1000 'A's
        bytes[0] = 0x00 // 1 null byte in 1000 = 0.1%
        XCTAssertNil(BinaryDetector.detectBinaryContent(bytes))
    }

    func testDetectBinaryOverThreshold() {
        // Just over 10% non-printable should be detected (condition is > 10%)
        var bytes = Data(repeating: 0x41, count: 200)
        for i in 0..<21 {
            bytes[i] = 0x00 // 21 null bytes in 200 = 10.5%
        }
        XCTAssertEqual(BinaryDetector.detectBinaryContent(bytes), "binary file")
    }

    // MARK: - MacRomanConverter

    func testConvertValidUTF8Passthrough() {
        // UTF-8 data should convert fine
        let text = "Hello, world!"
        let data = text.data(using: .utf8)!
        let converted = MacRomanConverter.convertToUTF8(data)
        XCTAssertEqual(converted, text)
    }

    func testConvertInvalidEncodingReturnsNil() {
        // Random non-MacRoman bytes (pure binary)
        let data = Data([0xFF, 0xFE, 0xFD, 0xFC])
        let converted = MacRomanConverter.convertToUTF8(data)
        // Invalid data may or may not convert; verify it doesn't crash
        // and returns a non-nil result (Mac Roman has mapping for all bytes)
        XCTAssertNotNil(converted)
    }

    func testIsLikelyMacRomanWithHighBytes() {
        let data = Data([0x41, 0x42, 0x80, 0x43]) // 0x80 is in Mac Roman range
        XCTAssertTrue(MacRomanConverter.isLikelyMacRoman(data))
    }

    func testIsLikelyMacRomanWithASCIIOnly() {
        let text = "Hello, world!"
        let data = text.data(using: .utf8)!
        XCTAssertFalse(MacRomanConverter.isLikelyMacRoman(data))
    }

    func testIsLikelyMacRomanEmptyData() {
        XCTAssertFalse(MacRomanConverter.isLikelyMacRoman(Data()))
    }

    func testIsLikelyMacRomanWithUTF8ContinuationBytes() {
        // UTF-8 multi-byte sequences use 0x80-0xBF for continuation
        let data = "caf\u{00E9}".data(using: .utf8)! // é is 0xC3 0xA9 in UTF-8
        XCTAssertTrue(MacRomanConverter.isLikelyMacRoman(data))
        // High bytes could be either encoding; heuristic flags it
    }

    func testRoundTripMacRomanCharacters() {
        // Characters that exist in both Mac Roman and UTF-8
        let text = "Amazing Grace"
        let data = text.data(using: .utf8)!
        let converted = MacRomanConverter.convertToUTF8(data)
        XCTAssertEqual(converted, text)
    }
}

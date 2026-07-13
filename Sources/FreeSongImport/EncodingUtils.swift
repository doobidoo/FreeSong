import Foundation
import ZIPFoundation
import FreeSongCore
import FreeSongStorage

// MARK: - Binary Detection

/// Detects binary content in files (PDF, images, etc.)
public struct BinaryDetector {

    /// Detect if content appears to be binary.
    /// - Parameter content: Raw bytes to check
    /// - Returns: Description of binary type, or nil if text
    public static func detectBinaryContent(_ content: Data) -> String? {
        guard content.count >= 8 else { return nil }

        let bytes = [UInt8](content.prefix(8))

        // PDF: starts with %PDF
        if bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46 {
            return "PDF document"
        }

        // PNG: starts with 0x89 PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "PNG image"
        }

        // JPEG: starts with 0xFF 0xD8 0xFF
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "JPEG image"
        }

        // GIF: starts with GIF87a or GIF89a
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
           bytes[3] == 0x38 && (bytes[4] == 0x37 || bytes[4] == 0x39) {
            return "GIF image"
        }

        // BMP: starts with BM
        if bytes[0] == 0x42 && bytes[1] == 0x4D {
            return "BMP image"
        }

        // Check for high proportion of non-printable characters
        let checkLength = min(content.count, 1024)
        var nonPrintable = 0

        for i in 0..<checkLength {
            let b = content[i]
            // Allow printable ASCII, tabs, newlines, carriage returns
            // and high UTF-8 bytes (>= 0x80)
            if b != 0x09 && b != 0x0A && b != 0x0D &&
               (b < 0x20 || b == 0x7F) && b < 0x80 {
                nonPrintable += 1
            }
        }

        // If more than 10% non-printable in first 1KB, likely binary
        if nonPrintable > checkLength / 10 {
            return "binary file"
        }

        return nil
    }
}

// MARK: - Mac Roman Encoding

/// Handles Mac Roman to UTF-8 conversion for OnSong files.
public struct MacRomanConverter {

    // kCFStringEncodingMacRoman = 0x00000000
    private static let macRomanEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x00000000)))

    /// Convert Mac Roman encoded data to UTF-8 string.
    /// - Parameter data: Raw bytes in Mac Roman encoding
    /// - Returns: UTF-8 string, or nil if conversion fails
    public static func convertToUTF8(_ data: Data) -> String? {
        return String(data: data, encoding: macRomanEncoding)
    }

    /// Check if data is likely Mac Roman encoded (has high bytes).
    /// - Parameter data: Raw bytes to check
    /// - Returns: True if data likely contains Mac Roman characters
    public static func isLikelyMacRoman(_ data: Data) -> Bool {
        // Check for bytes in Mac Roman range (0x80-0xFF) that aren't valid UTF-8
        for byte in data {
            if byte >= 0x80 && byte <= 0xFF {
                // Could be Mac Roman, but might also be UTF-8 continuation byte
                // This is a heuristic - we'll try both
                return true
            }
        }
        return false
    }
}
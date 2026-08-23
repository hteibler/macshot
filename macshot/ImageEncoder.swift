import AppKit

enum ImageFormat: String, CaseIterable, Identifiable, Codable {
    case png, jpg, gif

    var id: String { rawValue }
    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpg: return "JPG"
        case .gif: return "GIF"
        }
    }

    fileprivate var bitmapFileType: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpg: return .jpeg
        case .gif: return .gif
        }
    }
}

enum ImageEncodingError: Error {
    case encodingFailed
}

enum ImageEncoder {
    static func encode(_ image: CGImage, format: ImageFormat, jpegQuality: Double) throws -> Data {
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpg {
            properties[.compressionFactor] = jpegQuality
        }

        guard let data = NSBitmapImageRep(cgImage: image).representation(using: format.bitmapFileType, properties: properties) else {
            throw ImageEncodingError.encodingFailed
        }
        return data
    }
}

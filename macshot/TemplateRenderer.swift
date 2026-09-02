import CryptoKit
import Foundation

struct CaptureContext {
    let date: Date
    let title: String
    let appName: String
    let sequenceNumber: Int
}

enum TemplateRenderer {
    private static let randomCharacters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    private static let randomTokenPattern = try! NSRegularExpression(pattern: "\\{R+\\}")
    private static let hashTokenPattern = try! NSRegularExpression(pattern: "\\{hash(\\d+)\\}")
    private static let base62Alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")

    static func render(_ template: String, context: CaptureContext) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: context.date)

        var result = template
        result = result.replacingOccurrences(of: "{YYYY}", with: String(format: "%04d", c.year ?? 0))
        result = result.replacingOccurrences(of: "{MM}", with: String(format: "%02d", c.month ?? 0))
        result = result.replacingOccurrences(of: "{DD}", with: String(format: "%02d", c.day ?? 0))
        result = result.replacingOccurrences(of: "{hh}", with: String(format: "%02d", c.hour ?? 0))
        result = result.replacingOccurrences(of: "{mm}", with: String(format: "%02d", c.minute ?? 0))
        result = result.replacingOccurrences(of: "{ss}", with: String(format: "%02d", c.second ?? 0))
        result = result.replacingOccurrences(of: "{title}", with: sanitizePathComponent(context.title))
        result = result.replacingOccurrences(of: "{app}", with: sanitizePathComponent(context.appName))
        result = result.replacingOccurrences(of: "{NUM}", with: String(format: "%06d", context.sequenceNumber))
        result = substituteRandomTokens(result)
        return result
    }

    // "/" would otherwise be read as a path separator, silently creating
    // unintended subfolders instead of a literal character in the name.
    // A literal "/" typed directly into the template itself is left alone —
    // that's the intentional nested-subfolder syntax.
    private static func sanitizePathComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }

    // {R}, {RR}, {RRR}, ... -> that many random alphanumeric characters.
    // Variable-length, unlike every other token, so this needs a regex pass
    // instead of a plain replacingOccurrences.
    private static func substituteRandomTokens(_ template: String) -> String {
        let nsTemplate = template as NSString
        let matches = randomTokenPattern.matches(in: template, range: NSRange(location: 0, length: nsTemplate.length))
        guard !matches.isEmpty else { return template }

        var result = ""
        var lastEnd = 0
        for match in matches {
            result += nsTemplate.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            let length = match.range.length - 2 // minus the surrounding braces
            result += String((0..<length).map { _ in randomCharacters.randomElement()! })
            lastEnd = match.range.location + match.range.length
        }
        result += nsTemplate.substring(from: lastEnd)
        return result
    }

    // {hashN} -> the first N characters of a Base62-encoded MD5 hash.
    // Always derived from the *folder name*, whether the token appears in
    // the folder name template or the filename template — this makes the
    // same {hashN} value show up consistently for every file saved into a
    // given folder. Callers compute `hashSource` once per capture via
    // strippingHashTokens(_:) on the rendered folder name, then pass it to
    // applyHashTokens for both the folder name and the filename.

    /// Removes every {hashN} occurrence from `template` (rather than
    /// substituting it) so a {hashN} token used in the folder name doesn't
    /// end up hashing itself.
    static func strippingHashTokens(_ template: String) -> String {
        let nsTemplate = template as NSString
        return hashTokenPattern.stringByReplacingMatches(
            in: template,
            range: NSRange(location: 0, length: nsTemplate.length),
            withTemplate: ""
        )
    }

    static func applyHashTokens(to template: String, hashSource: String) -> String {
        let nsTemplate = template as NSString
        let matches = hashTokenPattern.matches(in: template, range: NSRange(location: 0, length: nsTemplate.length))
        guard !matches.isEmpty else { return template }

        let fullHash = base62Hash(of: hashSource)

        var result = ""
        var lastEnd = 0
        for match in matches {
            result += nsTemplate.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            let length = Int(nsTemplate.substring(with: match.range(at: 1))) ?? 0
            result += String(fullHash.prefix(length))
            lastEnd = match.range.location + match.range.length
        }
        result += nsTemplate.substring(from: lastEnd)
        return result
    }

    // MD5 -> big integer -> Base62, per SPEC.md's algorithm. MD5 is a
    // 128-bit digest, so this tops out around 22 Base62 characters —
    // {hashN} with N beyond that just returns everything it has.
    private static func base62Hash(of source: String) -> String {
        let digest = Array(Insecure.MD5.hash(data: Data(source.utf8)))
        return base62Encode(digest)
    }

    // Standard base-256 -> base62 conversion: repeatedly divide the
    // big-endian byte array (treated as one big integer) by 62, collecting
    // remainders as Base62 digits, until it's zero.
    private static func base62Encode(_ bytes: [UInt8]) -> String {
        var digits = bytes
        var result = ""

        while !digits.allSatisfy({ $0 == 0 }) {
            var remainder = 0
            var quotient: [UInt8] = []
            quotient.reserveCapacity(digits.count)
            for byte in digits {
                let acc = remainder * 256 + Int(byte)
                quotient.append(UInt8(acc / 62))
                remainder = acc % 62
            }
            result.append(base62Alphabet[remainder])
            digits = quotient
        }

        return result.isEmpty ? "0" : String(result.reversed())
    }
}

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
}

import Foundation

struct CaptureContext {
    let date: Date
    let title: String
    let appName: String
}

enum TemplateRenderer {
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
        return result
    }

    // "/" would otherwise be read as a path separator, silently creating
    // unintended subfolders instead of a literal character in the name.
    private static func sanitizePathComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }
}

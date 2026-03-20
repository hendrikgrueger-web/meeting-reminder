import Foundation

enum TeamsLinkExtractor {

    private static let patterns: [NSRegularExpression] = {
        let raw = [
            #"https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+"#,
            #"https://teams\.microsoft\.com/meet/[^\s"<>]+"#,
            #"https://teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
            #"https://dod\.teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
            #"https://teams\.live\.com/meet/[^\s"<>]+"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }
    }()

    private static let teamsHosts: Set<String> = [
        "teams.microsoft.com",
        "teams.microsoft.us",
        "dod.teams.microsoft.us",
        "teams.live.com",
    ]

    static func extractURL(location: String?, notes: String?, url: URL?) -> URL? {
        if let location, let found = matchTeamsURL(in: location) {
            return found
        }
        if let notes {
            let decoded = decodeHTMLEntities(notes)
            if let found = matchTeamsURL(in: decoded) {
                return found
            }
        }
        if let url, let host = url.host?.lowercased(), teamsHosts.contains(host) {
            return url
        }
        return nil
    }

    private static func matchTeamsURL(in text: String) -> URL? {
        let range = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            if let match = pattern.firstMatch(in: text, range: range) {
                let matchRange = Range(match.range, in: text)!
                let urlString = String(text[matchRange])
                return URL(string: urlString)
            }
        }
        return nil
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

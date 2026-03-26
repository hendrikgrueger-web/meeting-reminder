import Foundation
import AppKit

// MARK: - Meeting Link Extractor

/// Erkennt Meeting-Links aus 8 Providern in Kalender-Event-Feldern.
/// Suchpriorität: location → notes (HTML-decoded) → url
enum MeetingLinkExtractor {

    // MARK: - Provider Pattern Definition

    private struct ProviderPattern {
        let provider: MeetingProvider
        let patterns: [NSRegularExpression]
        let hostSuffixes: [String] // Wird per hasSuffix geprüft
    }

    private static let providerPatterns: [ProviderPattern] = {
        [
            // Microsoft Teams
            ProviderPattern(
                provider: .teams,
                patterns: compile([
                    #"https://teams\.microsoft\.com/l/meetup-join/[^\s"<>]+"#,
                    #"https://teams\.microsoft\.com/meet/[^\s"<>]+"#,
                    #"https://teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
                    #"https://dod\.teams\.microsoft\.us/l/meetup-join/[^\s"<>]+"#,
                    #"https://teams\.live\.com/meet/[^\s"<>]+"#,
                ]),
                hostSuffixes: [
                    "teams.microsoft.com", "teams.microsoft.us",
                    "dod.teams.microsoft.us", "teams.live.com",
                ]
            ),
            // Zoom
            ProviderPattern(
                provider: .zoom,
                patterns: compile([
                    #"https://(?:[a-z0-9]+\.)?zoom\.us/(?:j|my|s)/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["zoom.us"]
            ),
            // Google Meet
            ProviderPattern(
                provider: .googleMeet,
                patterns: compile([
                    #"https://meet\.google\.com/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["meet.google.com"]
            ),
            // WebEx / Cisco
            ProviderPattern(
                provider: .webex,
                patterns: compile([
                    #"https://(?:[a-z0-9.-]+\.)?webex\.com/(?:meet|join)/[^\s"<>]+"#,
                    #"https://(?:[a-z0-9.-]+\.)?webex\.com/[a-z0-9.-]+/j\.php[^\s"<>]*"#,
                ]),
                hostSuffixes: ["webex.com"]
            ),
            // GoTo Meeting
            ProviderPattern(
                provider: .gotoMeeting,
                patterns: compile([
                    #"https://gotomeet\.me/[^\s"<>]+"#,
                    #"https://(?:[a-z0-9.-]+\.)?gotomeeting\.com/join/[^\s"<>]+"#,
                    #"https://meet\.goto\.com/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["gotomeet.me", "gotomeeting.com", "goto.com"]
            ),
            // Slack Huddle
            ProviderPattern(
                provider: .slack,
                patterns: compile([
                    #"https://app\.slack\.com/huddle/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["app.slack.com"]
            ),
            // Whereby
            ProviderPattern(
                provider: .whereby,
                patterns: compile([
                    #"https://whereby\.com/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["whereby.com"]
            ),
            // Jitsi Meet
            ProviderPattern(
                provider: .jitsi,
                patterns: compile([
                    #"https://meet\.jit\.si/[^\s"<>]+"#,
                ]),
                hostSuffixes: ["meet.jit.si"]
            ),
        ]
    }()

    // MARK: - Public API

    /// Extrahiert den ersten Meeting-Link aus den Event-Feldern.
    /// Suchpriorität: location → notes (HTML-decoded) → url
    static func extractMeetingLink(location: String?, notes: String?, url: URL?) -> MeetingLink? {
        if let location, let found = matchMeetingURL(in: location) {
            return found
        }
        if let notes {
            let decoded = decodeHTMLEntities(notes)
            if let found = matchMeetingURL(in: decoded) {
                return found
            }
        }
        if let url, let host = url.host?.lowercased() {
            for provider in providerPatterns {
                if provider.hostSuffixes.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                    return MeetingLink(url: url, provider: provider.provider)
                }
            }
        }
        return nil
    }

    // MARK: - Meeting öffnen (Deep-Link mit Fallback)

    /// Öffnet einen Meeting-Link: versucht zuerst den nativen Deep-Link, dann HTTPS-Fallback.
    @MainActor
    static func open(_ meetingLink: MeetingLink) {
        let deepURL = deepLinkURL(for: meetingLink)

        if deepURL != meetingLink.url,
           NSWorkspace.shared.urlForApplication(toOpen: deepURL) != nil {
            NSWorkspace.shared.open(deepURL)
        } else {
            NSWorkspace.shared.open(meetingLink.url)
        }
    }

    // MARK: - Deep Links

    /// Erzeugt einen Deep-Link für den nativen App-Start (Teams, Zoom, WebEx, GoTo)
    static func deepLinkURL(for meetingLink: MeetingLink) -> URL {
        let url = meetingLink.url
        let urlString = url.absoluteString

        switch meetingLink.provider {
        case .teams:
            if urlString.contains("teams.microsoft.com/l/meetup-join/") {
                // Scheme auf "msteams" setzen, Host entfernen (msteams: verwendet nur Pfad)
                if let deepURL = substituteScheme(url, newScheme: "msteams", removeHost: true) {
                    return deepURL
                }
            }

        case .zoom:
            if let meetingID = extractZoomMeetingID(from: urlString) {
                var components = URLComponents()
                components.scheme = "zoommtg"
                components.host = "zoom.us"
                components.path = "/join"
                components.queryItems = [URLQueryItem(name: "confno", value: meetingID)]
                if let pwd = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "pwd" })?.value {
                    components.queryItems?.append(URLQueryItem(name: "pwd", value: pwd))
                }
                if let deepURL = components.url { return deepURL }
            }

        case .webex:
            if let deepURL = substituteScheme(url, newScheme: "webex") { return deepURL }

        case .gotoMeeting:
            if let deepURL = substituteScheme(url, newScheme: "gotomeeting") { return deepURL }

        case .googleMeet, .slack, .whereby, .jitsi:
            break // Kein Deep-Link verfügbar, Browser-Fallback
        }

        return meetingLink.url
    }

    /// Tauscht nur das URL-Scheme aus — Host, Path und Query bleiben unverändert.
    /// Verhindert Path-Injection aus manipulierten Kalender-Events.
    private static func substituteScheme(_ url: URL, newScheme: String, removeHost: Bool = false) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = newScheme
        if removeHost { components?.host = nil }
        return components?.url
    }

    // MARK: - Private

    private static func compile(_ rawPatterns: [String]) -> [NSRegularExpression] {
        rawPatterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }

    private static func matchMeetingURL(in text: String) -> MeetingLink? {
        let range = NSRange(text.startIndex..., in: text)
        for provider in providerPatterns {
            for pattern in provider.patterns {
                if let match = pattern.firstMatch(in: text, range: range) {
                    let matchRange = Range(match.range, in: text)!
                    let urlString = String(text[matchRange])
                    if let url = URL(string: urlString) {
                        return MeetingLink(url: url, provider: provider.provider)
                    }
                }
            }
        }
        return nil
    }

    private static func extractZoomMeetingID(from urlString: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"/(?:j|s)/(\d+)"#),
              let match = regex.firstMatch(
                  in: urlString,
                  range: NSRange(urlString.startIndex..., in: urlString)
              ),
              let idRange = Range(match.range(at: 1), in: urlString)
        else { return nil }
        return String(urlString[idRange])
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

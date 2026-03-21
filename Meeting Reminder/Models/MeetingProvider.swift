import Foundation

// MARK: - Meeting Provider

enum MeetingProvider: String, Sendable, CaseIterable, Equatable {
    case teams = "Microsoft Teams"
    case zoom = "Zoom"
    case googleMeet = "Google Meet"
    case webex = "WebEx"
    case gotoMeeting = "GoTo Meeting"
    case slack = "Slack Huddle"
    case whereby = "Whereby"
    case jitsi = "Jitsi Meet"

    /// SF Symbol für den Provider
    var iconName: String {
        switch self {
        case .teams: return "video.fill"
        case .zoom: return "video.circle.fill"
        case .googleMeet: return "person.3.fill"
        case .webex: return "phone.circle.fill"
        case .gotoMeeting: return "arrow.up.right.video.fill"
        case .slack: return "headphones.circle.fill"
        case .whereby: return "link.circle.fill"
        case .jitsi: return "video.badge.waveform.fill"
        }
    }

    /// Button-Label für "Beitreten"
    var joinLabel: String {
        switch self {
        case .teams: return "Teams beitreten"
        case .zoom: return "Zoom beitreten"
        case .googleMeet: return "Google Meet beitreten"
        case .webex: return "WebEx beitreten"
        case .gotoMeeting: return "GoTo beitreten"
        case .slack: return "Slack Huddle beitreten"
        case .whereby: return "Whereby beitreten"
        case .jitsi: return "Jitsi beitreten"
        }
    }

    /// VoiceOver-Label
    var accessibilityJoinLabel: String {
        "Beitreten via \(rawValue)"
    }

    /// Kurzname für UI
    var shortName: String {
        switch self {
        case .teams: return "Teams"
        case .zoom: return "Zoom"
        case .googleMeet: return "Meet"
        case .webex: return "WebEx"
        case .gotoMeeting: return "GoTo"
        case .slack: return "Slack"
        case .whereby: return "Whereby"
        case .jitsi: return "Jitsi"
        }
    }
}

// MARK: - Meeting Link

struct MeetingLink: Sendable, Equatable {
    let url: URL
    let provider: MeetingProvider
}

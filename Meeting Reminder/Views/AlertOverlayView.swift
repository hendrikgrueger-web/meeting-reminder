import SwiftUI

// MARK: - AlertOverlayView

struct AlertOverlayView: View {

    let event: MeetingEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var now: Date = .now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: Computed

    private var currentTime: String {
        now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
    }

    private var countdownText: String {
        let diff = event.startDate.timeIntervalSince(now)
        if diff > 0 {
            let secs = Int(diff)
            if secs < 60 {
                return "beginnt in \(secs) Sek."
            } else {
                let mins = secs / 60
                return "beginnt in \(mins) Min."
            }
        } else {
            let mins = Int(-diff / 60)
            if mins == 0 {
                return "läuft gerade"
            }
            return "läuft seit \(mins) Min."
        }
    }

    private var countdownIsUrgent: Bool {
        event.startDate.timeIntervalSince(now) <= 60
    }

    private var showLocation: Bool {
        guard let loc = event.location, !loc.isEmpty else { return false }
        return !event.hasTeamsLink
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Content card
            card
                .frame(maxWidth: 500)
                .padding(40)
        }
        .onReceive(timer) { date in
            now = date
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayDismiss)) { _ in
            onDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlayJoin)) { _ in
            if event.hasTeamsLink { onJoin() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySnooze)) { _ in
            onSnooze()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meeting-Erinnerung: \(event.title)")
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top row: clock
            HStack {
                Spacer()
                Text(currentTime)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Aktuelle Uhrzeit: \(currentTime)")
            }
            .padding(.bottom, 12)

            // Title row with calendar color bar
            HStack(alignment: .top, spacing: 12) {
                // Calendar color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor)
                    .frame(width: 4)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(event.calendarTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 16)

            // Time range
            Label(timeRange, systemImage: "clock")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Zeitraum: \(timeRange)")
                .padding(.bottom, 8)

            // Countdown
            countdownBadge
                .padding(.bottom, 16)

            // Location (only when no Teams link)
            if showLocation, let location = event.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityLabel("Ort: \(location)")
                    .padding(.bottom, 16)
            }

            // No Teams link warning
            if !event.hasTeamsLink {
                noTeamsLinkWarning
                    .padding(.bottom, 16)
            }

            Divider()
                .padding(.bottom, 16)

            // Action buttons
            actionButtons
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 32, x: 0, y: 8)
        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: Countdown Badge

    private var countdownBadge: some View {
        let diff = event.startDate.timeIntervalSince(now)
        let color: Color = diff <= 0 ? .green : (countdownIsUrgent ? .orange : .blue)

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(countdownText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .accessibilityLabel(countdownText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: No Teams Warning

    private var noTeamsLinkWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Kein Einwahllink gefunden")
                .font(.callout)
                .foregroundStyle(.orange)
        }
        .accessibilityLabel("Warnung: Kein Einwahllink gefunden")
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Join button (Teams)
            if event.hasTeamsLink {
                Button(action: onJoin) {
                    Label("Meeting beitreten", systemImage: "video.fill")
                        .frame(maxWidth: .infinity)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Meeting beitreten via Teams — Eingabetaste")
            }

            HStack(spacing: 10) {
                // Snooze button
                Button(action: onSnooze) {
                    Label("1 Minute", systemImage: "alarm")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("In 1 Minute erneut erinnern — Leertaste")
                .keyboardShortcut(" ", modifiers: [])

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Schließen")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Overlay schließen — Escape")
            }
        }
    }
}

// MARK: - Preview

#Preview("Bald startendes Meeting mit Teams-Link") {
    let event = MeetingEvent(
        eventIdentifier: "preview-1",
        title: "Weekly Team Sync — Engineering",
        startDate: Date().addingTimeInterval(45),
        endDate: Date().addingTimeInterval(3645),
        location: nil,
        calendarColor: .indigo,
        calendarTitle: "Arbeit",
        teamsURL: URL(string: "https://teams.microsoft.com/l/meetup-join/preview"),
        isAllDay: false
    )
    AlertOverlayView(
        event: event,
        onJoin: {},
        onDismiss: {},
        onSnooze: {}
    )
    .frame(width: 700, height: 500)
    .background(Color.gray.opacity(0.3))
}

#Preview("Laufendes Meeting ohne Teams-Link") {
    let event = MeetingEvent(
        eventIdentifier: "preview-2",
        title: "1:1 mit Hendrik",
        startDate: Date().addingTimeInterval(-300),
        endDate: Date().addingTimeInterval(900),
        location: "Konferenzraum 3, EG",
        calendarColor: .teal,
        calendarTitle: "Privat",
        teamsURL: nil,
        isAllDay: false
    )
    AlertOverlayView(
        event: event,
        onJoin: {},
        onDismiss: {},
        onSnooze: {}
    )
    .frame(width: 700, height: 500)
    .background(Color.gray.opacity(0.3))
}

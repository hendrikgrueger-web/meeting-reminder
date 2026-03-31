// Meeting Reminder/Views/TodayMeetingsView.swift
import SwiftUI

/// Tagesübersicht aller heutigen Meetings im Menüleisten-Popover.
/// 3-Stufen-Hierarchie: vergangen (gedimmt), aktuell (hervorgehoben), zukünftig (volle Farbe).
struct TodayMeetingsView: View {

    @ObservedObject var calendarService: CalendarService
    @State private var now: Date = .now

    /// Timer für die Aktualisierung der "aktuell/vergangen"-Zuordnung
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if calendarService.todayEvents.isEmpty {
                Text("Keine Meetings heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } else {
                ForEach(calendarService.todayEvents) { event in
                    meetingRow(event)
                        .id(event.id)
                }
            }
        }
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Meeting-Zeile

    @ViewBuilder
    private func meetingRow(_ event: MeetingEvent) -> some View {
        let status = eventStatus(event)
        let isClickable = event.meetingLink != nil && status != .past

        Button(action: { handleTap(event) }) {
            HStack(spacing: 8) {
                // Kalender-Farbbalken — 4px für bessere Sichtbarkeit im Dark Mode
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor)
                    .frame(width: 4, height: 22)
                    .opacity(status == .past ? 0.4 : 1.0)

                // Uhrzeit
                Text(event.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(status == .past ? .tertiary : .secondary)
                    .frame(width: 38, alignment: .leading)

                // "Jetzt"-Badge für laufendes Meeting
                if status == .current {
                    Text("Jetzt")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.green, in: Capsule())
                }

                // Titel
                Text(event.title)
                    .font(.system(size: 12, weight: status == .current ? .semibold : .regular))
                    .foregroundStyle(status == .past ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                // Provider-Icon — nur für aktuelle und zukünftige Events, 12pt für Lesbarkeit
                if status != .past, let provider = event.meetingProvider {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(status == .current ? .primary : .secondary)
                }
            }
            .frame(height: 30)
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
            .background(
                status == .current
                    ? event.calendarColor.opacity(0.12)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(status == .past ? 0.35 : 1.0)
        .disabled(!isClickable)
        .help(isClickable
            ? "Klicken zum Beitreten via \(event.meetingProvider?.shortName ?? "Link")"
            : event.title
        )
        .accessibilityLabel(accessibilityLabel(for: event, status: status))
    }

    // MARK: - Event-Status

    private enum EventStatus {
        case past, current, future
    }

    private func eventStatus(_ event: MeetingEvent) -> EventStatus {
        if event.endDate <= now {
            return .past
        } else if event.startDate <= now && event.endDate > now {
            return .current
        } else {
            return .future
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for event: MeetingEvent, status: EventStatus) -> String {
        let time = event.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let statusText: String
        switch status {
        case .past: statusText = "vergangen"
        case .current: statusText = "läuft jetzt"
        case .future: statusText = "zukünftig"
        }
        if let provider = event.meetingProvider {
            return "\(event.title), \(time) Uhr, \(statusText), \(provider.shortName) Meeting"
        }
        return "\(event.title), \(time) Uhr, \(statusText)"
    }

    // MARK: - Tap-Handler

    private func handleTap(_ event: MeetingEvent) {
        guard let meetingLink = event.meetingLink else { return }
        MeetingLinkExtractor.open(meetingLink)
    }
}

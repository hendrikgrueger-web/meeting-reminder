// Meeting Reminder/Views/TodayMeetingsView.swift
import SwiftUI

/// Tagesübersicht aller heutigen Meetings im Menüleisten-Popover.
/// Vergangene Meetings ausgegraut, aktuelles hervorgehoben, zukünftige normal.
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
                }
            }
        }
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Meeting-Zeile

    @ViewBuilder
    private func meetingRow(_ event: MeetingEvent) -> some View {
        let status = eventStatus(event)
        let isClickable = event.meetingLink != nil

        Button(action: { handleTap(event) }) {
            HStack(spacing: 8) {
                // Kalender-Farbbalken
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(event.calendarColor)
                    .frame(width: 3, height: 20)

                // Uhrzeit
                Text(event.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(status == .past ? .tertiary : .secondary)
                    .frame(width: 38, alignment: .leading)

                // Titel
                Text(event.title)
                    .font(.system(size: 12, weight: status == .current ? .semibold : .regular))
                    .foregroundStyle(status == .past ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                // Provider-Icon (wenn vorhanden)
                if let provider = event.meetingProvider {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 10))
                        .foregroundStyle(status == .past ? .quaternary : .secondary)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
            .background(
                status == .current
                    ? AnyShapeStyle(event.calendarColor.opacity(0.1))
                    : AnyShapeStyle(.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(status == .past ? 0.4 : 1.0)
        .disabled(!isClickable)
        .help(isClickable
            ? "Klicken zum Beitreten via \(event.meetingProvider?.shortName ?? "Link")"
            : event.title
        )
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

    // MARK: - Tap-Handler

    private func handleTap(_ event: MeetingEvent) {
        guard let meetingLink = event.meetingLink else { return }
        MeetingLinkExtractor.open(meetingLink)
    }
}

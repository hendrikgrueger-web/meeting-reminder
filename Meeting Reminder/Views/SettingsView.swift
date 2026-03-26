// Meeting Reminder/Views/SettingsView.swift
import SwiftUI
import ServiceManagement
import EventKit

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection

            Divider().padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Tagesübersicht
                    todaySection

                    Divider().padding(.vertical, 8)

                    calendarSection
                    generalSection
                }
            }
            .frame(maxHeight: 420)

            Divider().padding(.vertical, 8)

            aboutSection

            Divider().padding(.vertical, 8)

            HStack {
                Spacer()
                Button("Beenden") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 320)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !calendarService.accessGranted {
                Label("Kalender-Zugriff benötigt", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if calendarService.calendars.isEmpty {
                Label("Keine Kalender gefunden", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else if let next = calendarService.nextEvent {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(next.calendarColor)
                        .frame(width: 4, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            // Laufendes Meeting: "Jetzt"-Badge
                            if next.startDate <= Date() {
                                Text("Jetzt")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(.green, in: Capsule())
                            }
                            Text(statusTimeText(for: next))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Keine anstehenden Meetings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Heute-Übersicht

    @ViewBuilder
    private var todaySection: some View {
        if calendarService.accessGranted && !calendarService.calendars.isEmpty {
            sectionHeader(icon: "list.bullet.rectangle", title: "Heute")
            TodayMeetingsView(calendarService: calendarService)
        }
    }

    // MARK: - Kalender-Sektion (nach Account gruppiert)

    @ViewBuilder
    private var calendarSection: some View {
        if !calendarService.calendars.isEmpty {
            sectionHeader(icon: "calendar.badge.clock", title: "Kalender")

            // Kalender nach Account (Source) gruppieren
            let grouped = groupedCalendars()
            ForEach(grouped, id: \.accountName) { group in
                // Account-Sub-Header (nur wenn mehrere Accounts vorhanden)
                if grouped.count > 1 {
                    Text(group.accountName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }

                ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                    let isEnabled = calendarService.enabledCalendarIDs.contains(calendar.calendarIdentifier)
                    calendarRow(
                        title: calendar.title,
                        color: Color(cgColor: calendar.cgColor),
                        isEnabled: isEnabled,
                        onToggle: { enabled in
                            var ids = calendarService.enabledCalendarIDs
                            if enabled { ids.insert(calendar.calendarIdentifier) }
                            else { ids.remove(calendar.calendarIdentifier) }
                            calendarService.enabledCalendarIDs = ids
                        }
                    )
                }
            }

            Divider().padding(.vertical, 8)
        }
    }

    // MARK: - Allgemeine Einstellungen

    @ViewBuilder
    private var generalSection: some View {
        sectionHeader(icon: "gearshape.fill", title: "Einstellungen")

        // Vorlaufzeit als Stepper
        settingRow(
            "Vorlaufzeit",
            help: "Wie viele Minuten vor dem Meeting soll die Erinnerung erscheinen?"
        ) {
            HStack(spacing: 4) {
                Text("\(calendarService.leadTimeMinutes) Min")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, alignment: .trailing)
                Stepper(
                    "",
                    value: $calendarService.leadTimeMinutes,
                    in: 1...10
                )
                .labelsHidden()
                .controlSize(.small)
            }
        }

        settingToggle(
            "Nur Online-Meetings",
            help: "Nur an Meetings mit Einwahllink erinnern (Teams, Zoom, Google Meet, WebEx, etc.). Termine ohne Link werden ignoriert.",
            isOn: $calendarService.onlyOnlineMeetings
        )
        settingToggle(
            "Bildschirmfreigabe: Notification",
            help: "Bei aktiver Bildschirmfreigabe statt Vollbild-Overlay eine dezente Benachrichtigung anzeigen.",
            isOn: $calendarService.silentWhenScreenSharing
        )
        settingToggle(
            "Sound",
            help: "Einen kurzen Signalton abspielen, wenn die Erinnerung erscheint.",
            isOn: $calendarService.soundEnabled
        )
        settingToggle(
            "Globaler Shortcut (⌘⇧J)",
            help: "Mit Cmd+Shift+J das nächste Meeting sofort öffnen, ohne das Overlay zu verwenden.",
            isOn: $calendarService.globalShortcutEnabled
        )
        settingToggle(
            "Bei Anmeldung starten",
            help: "Nevr Late automatisch starten, wenn du dich am Mac anmeldest.",
            isOn: $launchAtLogin
        )
        .onChange(of: launchAtLogin) { _, newValue in
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }

        if SMAppService.mainApp.status == .requiresApproval {
            Label("In Systemeinstellungen aktivieren", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    // MARK: - Über-Sektion

    @ViewBuilder
    private var aboutSection: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"

        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Nevr Late")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Version \(version) (\(build))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text("© 2026 Grüpi GmbH")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Helper: Status-Zeittext

    private func statusTimeText(for event: MeetingEvent) -> String {
        let now = Date()
        if event.startDate <= now {
            return event.startDate.formatted(date: .omitted, time: .shortened)
        }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 1 {
            return "gleich"
        } else if minutes == 1 {
            return "in 1 Min."
        } else if minutes < 60 {
            return "in \(minutes) Min."
        } else {
            return event.startDate.formatted(date: .omitted, time: .shortened)
        }
    }

    // MARK: - Helper: Sektions-Header

    private func sectionHeader(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }

    // MARK: - Helper: Kalender nach Account gruppieren

    private struct CalendarGroup {
        let accountName: String
        let calendars: [EKCalendar]
    }

    private func groupedCalendars() -> [CalendarGroup] {
        // Kalender nach Source-Titel gruppieren
        var dict: [String: [EKCalendar]] = [:]
        for cal in calendarService.calendars {
            let account = cal.source?.title ?? "Lokal"
            dict[account, default: []].append(cal)
        }
        // Alphabetisch nach Account-Name sortieren, lokale Kalender zuletzt
        return dict
            .sorted { a, b in
                if a.key == "Lokal" { return false }
                if b.key == "Lokal" { return true }
                return a.key < b.key
            }
            .map { CalendarGroup(accountName: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
    }

    // MARK: - Reusable Rows

    private func calendarRow(title: String, color: Color, isEnabled: Bool, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Toggle("", isOn: Binding(get: { isEnabled }, set: onToggle))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .help("Events aus diesem Kalender einbeziehen")
    }

    private func settingRow(_ label: String, help: String, @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .help(help)
    }

    private func settingToggle(_ label: String, help: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .help(help)
    }
}

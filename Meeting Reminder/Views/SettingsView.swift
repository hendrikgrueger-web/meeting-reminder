// Meeting Reminder/Views/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status: Nächstes Meeting
            statusSection

            Divider().padding(.vertical, 8)

            // Settings
            settingsSection

            Divider().padding(.vertical, 8)

            // App-Info
            HStack {
                Text("Meeting Reminder")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Beenden") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
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
                        .frame(width: 3, height: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(next.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(next.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

    // MARK: - Settings

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kalender-Auswahl
            if !calendarService.calendars.isEmpty {
                Text("Kalender")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                    let isEnabled = calendarService.enabledCalendarIDs.contains(calendar.calendarIdentifier)
                    Toggle(isOn: Binding(
                        get: { isEnabled },
                        set: { enabled in
                            var ids = calendarService.enabledCalendarIDs
                            if enabled { ids.insert(calendar.calendarIdentifier) }
                            else { ids.remove(calendar.calendarIdentifier) }
                            calendarService.enabledCalendarIDs = ids
                        }
                    )) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 8, height: 8)
                            Text(calendar.title)
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                }
            }

            Divider().padding(.vertical, 4)

            // Vorlaufzeit
            Picker("Vorlaufzeit", selection: $calendarService.leadTimeMinutes) {
                Text("1 Min").tag(1)
                Text("2 Min").tag(2)
                Text("3 Min").tag(3)
                Text("5 Min").tag(5)
            }
            .pickerStyle(.menu)
            .font(.subheadline)
            .padding(.horizontal, 16)

            // Toggles
            Toggle("Nur Online-Meetings", isOn: $calendarService.onlyOnlineMeetings)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Bei Bildschirmfreigabe: nur Notification", isOn: $calendarService.silentWhenScreenSharing)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Sound", isOn: $calendarService.soundEnabled)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)

            Toggle("Bei Anmeldung starten", isOn: $launchAtLogin)
                .font(.subheadline)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 16)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if SMAppService.mainApp.status == .requiresApproval {
                Label("Login Item in Systemeinstellungen aktivieren", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
                    )
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, 16)
            }
        }
    }
}

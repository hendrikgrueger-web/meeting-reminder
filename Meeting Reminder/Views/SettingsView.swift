// Meeting Reminder/Views/SettingsView.swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection

            Divider().padding(.vertical, 8)

            ScrollView {
                settingsSection
            }
            .frame(maxHeight: 400)

            Divider().padding(.vertical, 8)

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
        VStack(alignment: .leading, spacing: 0) {
            // Kalender-Auswahl
            if !calendarService.calendars.isEmpty {
                Text("Kalender")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
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

            // Vorlaufzeit
            settingRow("Vorlaufzeit") {
                Picker("", selection: $calendarService.leadTimeMinutes) {
                    Text("1 Min").tag(1)
                    Text("2 Min").tag(2)
                    Text("3 Min").tag(3)
                    Text("5 Min").tag(5)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 80)
            }

            settingToggle("Nur Online-Meetings", isOn: $calendarService.onlyOnlineMeetings)
            settingToggle("Bildschirmfreigabe: Notification", isOn: $calendarService.silentWhenScreenSharing)
            settingToggle("Sound", isOn: $calendarService.soundEnabled)
            settingToggle("Bei Anmeldung starten", isOn: $launchAtLogin)
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
    }

    // MARK: - Reusable Rows

    private func calendarRow(title: String, color: Color, isEnabled: Bool, onToggle: @escaping (Bool) -> Void) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
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
    }

    private func settingRow(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func settingToggle(_ label: String, isOn: Binding<Bool>) -> some View {
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
    }
}

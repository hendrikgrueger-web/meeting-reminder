import SwiftUI

@main
struct MeetingReminderApp: App {
    var body: some Scene {
        MenuBarExtra("Meeting Reminder", systemImage: "bell") {
            Text("Meeting Reminder läuft")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}

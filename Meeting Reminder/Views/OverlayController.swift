import AppKit
import SwiftUI

@MainActor
final class OverlayController: NSObject, ObservableObject, NSWindowDelegate {

    static let shared = OverlayController()

    override init() {
        super.init()
    }

    private(set) var panel: OverlayPanel?

    func show(content: some View) {
        // Altes Panel vollständig abbauen BEVOR neues erstellt wird.
        // Entfernt zuerst die contentView, damit SwiftUI's .onReceive-Subscriber
        // (overlayDismiss/overlayJoin/overlaySnooze) sofort abgemeldet werden
        // und nicht auf Notifications des neuen Panels reagieren.
        dismiss()

        guard let screen = NSScreen.main else { return }

        // SwiftUI View muss den gesamten Bildschirm füllen
        let fullScreenContent = content
            .frame(width: screen.frame.width, height: screen.frame.height)

        let hostingView = NSHostingView(rootView: fullScreenContent)
        hostingView.frame = CGRect(origin: .zero, size: screen.frame.size)

        let newPanel = OverlayPanel(contentView: hostingView, screen: screen)
        newPanel.delegate = self
        newPanel.setFrame(screen.frame, display: true)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
    }

    func dismiss() {
        guard let panel else { return }
        // ContentView explizit entfernen → SwiftUI-View-Graph wird abgebaut,
        // .onReceive-Subscriber werden sofort deregistriert.
        panel.contentView = nil
        panel.close()
        self.panel = nil
    }

    // MARK: - NSWindowDelegate

    /// Sicherheitsnetz: Falls das Panel durch macOS geschlossen wird
    /// (z.B. Space-Wechsel), ebenfalls aufräumen.
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard let panel = notification.object as? OverlayPanel,
                  panel == self.panel else { return }
            panel.contentView = nil
            self.panel = nil
        }
    }

    nonisolated static func isScreenSharing() -> Bool {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let captureProcesses: Set<String> = [
            "CaptureAgent", "screensharingd", "Screen Sharing",
            "Bildschirmfreigabe",
        ]
        return windowList.contains { info in
            guard let name = info[kCGWindowOwnerName as String] as? String else { return false }
            return captureProcesses.contains(name)
        }
    }
}

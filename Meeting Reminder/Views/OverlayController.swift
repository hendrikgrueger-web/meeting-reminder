import AppKit
import SwiftUI

@MainActor
final class OverlayController: ObservableObject {

    static let shared = OverlayController()

    private(set) var panel: OverlayPanel?
    @Published var isVisible = false

    func show(content: some View) {
        guard let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = screen.frame

        let newPanel = OverlayPanel(contentView: hostingView, screen: screen)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
        self.isVisible = true
    }

    func dismiss() {
        panel?.close()
        panel = nil
        isVisible = false
    }

    /// Prüft ob Screen Sharing aktiv ist (bekannte Capture-Prozesse)
    static func isScreenSharing() -> Bool {
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

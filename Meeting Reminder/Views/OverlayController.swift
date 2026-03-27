import AppKit
import SwiftUI

@MainActor
final class OverlayController: ObservableObject {

    static let shared = OverlayController()

    private(set) var panel: OverlayPanel?

    func show(content: some View) {
        dismiss() // Vorheriges Panel schließen

        guard let screen = NSScreen.main else { return }

        // SwiftUI View muss den gesamten Bildschirm füllen
        let fullScreenContent = content
            .frame(width: screen.frame.width, height: screen.frame.height)

        let hostingView = NSHostingView(rootView: fullScreenContent)
        hostingView.frame = CGRect(origin: .zero, size: screen.frame.size)

        let newPanel = OverlayPanel(contentView: hostingView, screen: screen)
        newPanel.setFrame(screen.frame, display: true)
        newPanel.makeKeyAndOrderFront(nil)

        self.panel = newPanel
    }

    func dismiss() {
        panel?.close()
        panel = nil
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

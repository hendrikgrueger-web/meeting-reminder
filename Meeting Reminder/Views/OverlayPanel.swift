import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {

    init(contentView: NSView, screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // Escape
            NotificationCenter.default.post(name: .overlayDismiss, object: nil)
        case 36:  // Return/Enter
            NotificationCenter.default.post(name: .overlayJoin, object: nil)
        case 49:  // Space
            NotificationCenter.default.post(name: .overlaySnooze, object: nil)
        default:
            super.keyDown(with: event)
        }
    }
}

extension Notification.Name {
    static let overlayDismiss = Notification.Name("overlayDismiss")
    static let overlayJoin = Notification.Name("overlayJoin")
    static let overlaySnooze = Notification.Name("overlaySnooze")
}

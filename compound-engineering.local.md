---
review_agents:
  - compound-engineering:review:correctness-reviewer
  - compound-engineering:review:testing-reviewer
  - compound-engineering:review:maintainability-reviewer
  - compound-engineering:review:security-reviewer
  - compound-engineering:review:code-simplicity-reviewer
---

# Review Context — Nevr Late (macOS)

Swift 6 / SwiftUI / macOS 26+ menu bar app.
Key conventions:
- @MainActor auf Services (CalendarService, StoreKitService wurde entfernt)
- Swift Testing + XCTest für 153 Tests
- LSUIElement=true (kein Dock-Icon)
- Freemium-Modell wurde komplett entfernt (ReminderCounter, StoreKitService, PaywallView)
- Privacy Manifest (PrivacyInfo.xcprivacy) hinzugefügt
- App ist jetzt vollständig kostenlos

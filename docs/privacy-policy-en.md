# Privacy Policy — QuickJoin

**Last updated:** March 21, 2026

## Overview

QuickJoin is a macOS menu bar app that reminds you of upcoming calendar events and lets you join online meetings with a single click. Your privacy is important to us. This privacy policy explains what data the app accesses, how it is used, and your rights.

**Key principle: All your data stays on your device. We do not collect, transmit, or store any personal data.**

---

## 1. Data Controller

Hendrik Grueger
Germany
Email: hendrik@grueger.dev

---

## 2. Data Accessed by the App

### 2.1 Calendar Events (EventKit)

QuickJoin reads your local calendar events via Apple's EventKit framework to display upcoming meetings and detect meeting links. The following event data is accessed:

- Event title
- Start and end time
- Location
- Notes/description
- Calendar name and color
- Event URL
- All-day status

**This data is read locally on your device and is never transmitted to any server or third party.** The app does not modify, create, or delete any calendar events.

### 2.2 Meeting Link Detection

The app scans event location, notes, and URL fields to detect meeting links from the following providers:

- Microsoft Teams
- Zoom
- Google Meet
- Cisco WebEx
- GoTo Meeting
- Slack Huddles
- Whereby
- Jitsi Meet

Detected links are used solely to enable the "Join" button in the reminder overlay. **Meeting links are processed locally and are never transmitted or stored beyond the current app session.**

### 2.3 Local Settings (UserDefaults)

The app stores your preferences locally using macOS UserDefaults:

- Selected calendars
- Reminder lead time
- Sound preferences
- Screen sharing notification preference
- "Online meetings only" filter setting
- Launch at login preference

**UserDefaults data is stored exclusively on your device and is never transmitted.**

---

## 3. Data We Do NOT Collect

QuickJoin does **not**:

- Collect any personal information
- Transmit any data over the internet
- Use analytics or tracking tools
- Include any third-party SDKs or advertising frameworks
- Create user accounts or profiles
- Use cookies or similar tracking technologies
- Access contacts, photos, location, microphone, or camera
- Sync data to any cloud service

---

## 4. Network Communication

QuickJoin does **not** perform any network communication. The only network activity occurs when you click the "Join" button, which opens the meeting link in your default browser or the native meeting app (e.g., Microsoft Teams). This action is performed by macOS (`NSWorkspace.open`) and is not controlled by QuickJoin.

---

## 5. In-App Subscriptions

QuickJoin offers optional premium features via In-App Subscriptions managed entirely by Apple through StoreKit.

- **Subscription management and payment processing are handled exclusively by Apple.**
- The developer does not have access to your payment information, Apple ID, or billing details.
- For information about how Apple handles subscription data, please refer to [Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

---

## 6. Children's Privacy

QuickJoin does not collect any personal data from any user, including children under the age of 13 (or the applicable age in your jurisdiction). The app is safe for use by all age groups.

---

## 7. Data Security

Since QuickJoin does not collect or transmit any data, there is no risk of data breaches related to the app. All data accessed by the app remains on your device, protected by macOS security mechanisms including the App Sandbox.

---

## 8. Your Rights (GDPR)

Under the General Data Protection Regulation (GDPR), you have the following rights:

- **Right of Access** — Since no personal data is collected, there is no data to access.
- **Right to Erasure** — You can remove all locally stored preferences by deleting the app.
- **Right to Data Portability** — No personal data is collected or stored by the app.
- **Right to Object** — No data processing beyond local device operation takes place.
- **Right to Restriction of Processing** — Calendar access can be revoked at any time via macOS System Settings > Privacy & Security > Calendars.

To revoke calendar access: **System Settings > Privacy & Security > Calendars > QuickJoin**

---

## 9. Changes to This Privacy Policy

We may update this privacy policy from time to time. Any changes will be reflected by the "Last updated" date at the top of this document. Continued use of the app after changes constitutes acceptance of the updated policy.

---

## 10. Contact

If you have any questions about this privacy policy, please contact:

Hendrik Grueger
Email: hendrik@grueger.dev

---

*This privacy policy applies to QuickJoin for macOS, available on the Mac App Store.*

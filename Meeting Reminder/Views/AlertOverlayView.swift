import SwiftUI

struct AlertOverlayView: View {

    let event: MeetingEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var now: Date = .now
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Vollbild dimmed + blur Background
            Rectangle()
                .fill(.black.opacity(0.65))
                .overlay(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Zentrierte Content Card
            VStack(spacing: 0) {
                Spacer()
                cardContent
                    .scaleEffect(appeared ? 1.0 : 0.92)
                    .opacity(appeared ? 1.0 : 0.0)
                Spacer()
            }
        }
        .onReceive(timer) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .overlayDismiss)) { _ in onDismiss() }
        .onReceive(NotificationCenter.default.publisher(for: .overlayJoin)) { _ in if event.hasTeamsLink { onJoin() } }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySnooze)) { _ in onSnooze() }
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Uhrzeit
            Text(now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 28)

            // Kalenderfarbe-Akzent + Titel
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor)
                    .frame(width: 4, height: 32)
                    .padding(.trailing, 12)

                Text(event.title)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.bottom, 8)

            // Zeitraum
            Text(timeRange)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 6)

            // Countdown
            countdownPill
                .padding(.bottom, 24)

            // Ort (wenn vorhanden und kein Teams-Link)
            if let location = event.location, !location.isEmpty, !location.lowercased().contains("teams.microsoft") {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                    Text(location)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 24)
            }

            // Kein Einwahllink Warnung
            if !event.hasTeamsLink {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("Kein Einwahllink vorhanden")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.15), in: Capsule())
                .padding(.bottom, 24)
            }

            // Buttons
            actionButtons
                .padding(.bottom, 20)

            // Snooze
            snoozeSection
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 36)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 40, y: 12)
    }

    // MARK: - Countdown Pill

    private var countdownPill: some View {
        let diff = event.startDate.timeIntervalSince(now)
        let isRunning = diff <= 0
        let isUrgent = diff > 0 && diff <= 60
        let color: Color = isRunning ? .green : (isUrgent ? .orange : .cyan)

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.6), radius: 4)

            Text(countdownText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityLabel(countdownText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Beitreten Button
            if event.hasTeamsLink {
                Button(action: onJoin) {
                    HStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Beitreten")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.45, green: 0.4, blue: 0.85), Color(red: 0.35, green: 0.3, blue: 0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color(red: 0.4, green: 0.35, blue: 0.8).opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Beitreten via Microsoft Teams")
            }

            // Schließen Button
            Button(action: onDismiss) {
                Text("Schließen")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(.white.opacity(0.08))
                    .foregroundStyle(.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Erinnerung schließen")
        }
    }

    // MARK: - Snooze

    private var snoozeSection: some View {
        VStack(spacing: 6) {
            Text("Später erinnern")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))

            Button(action: onSnooze) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 10))
                    Text("1 Minute")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("In einer Minute erneut erinnern")
        }
    }

    // MARK: - Helpers

    private var timeRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var countdownText: String {
        let diff = event.startDate.timeIntervalSince(now)
        if diff > 0 {
            let secs = Int(diff)
            return secs < 60 ? "beginnt in \(secs) Sek." : "beginnt in \(secs / 60) Min."
        } else {
            let mins = Int(-diff / 60)
            return mins == 0 ? "läuft gerade" : "läuft seit \(mins) Min."
        }
    }
}

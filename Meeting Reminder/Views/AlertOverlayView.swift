import SwiftUI

struct AlertOverlayView: View {

    let event: MeetingEvent
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var now: Date = .now
    @State private var appeared = false
    @State private var livePulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Ob das Meeting bereits läuft
    private var isLive: Bool {
        event.startDate.timeIntervalSince(now) <= 0
    }

    /// Physische Adresse anzeigen — Meeting-URLs (alle 8 Provider) werden unterdrückt
    private var displayLocation: String? {
        guard let loc = event.location, !loc.isEmpty else { return nil }
        if let meetingURL = event.meetingURL, loc.contains(meetingURL.host ?? "") { return nil }
        if event.hasMeetingLink && loc.hasPrefix("http") { return nil }
        return loc
    }

    /// Sekunden bis zum Start (positiv = noch nicht gestartet)
    private var secondsUntilStart: Int {
        Int(event.startDate.timeIntervalSince(now))
    }

    var body: some View {
        ZStack {
            // Helles Frosted-Glass Hintergrund — Desktop scheint klar durch
            Rectangle()
                .fill(.black.opacity(0.4))
                .overlay(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Zentrierte Content Card mit Slide-Down Animation
            VStack(spacing: 0) {
                Spacer()
                cardContent
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : -60)
                Spacer()
            }
        }
        .onReceive(timer) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .overlayDismiss)) { _ in onDismiss() }
        .onReceive(NotificationCenter.default.publisher(for: .overlayJoin)) { _ in if event.hasMeetingLink { onJoin() } }
        .onReceive(NotificationCenter.default.publisher(for: .overlaySnooze)) { _ in onSnooze() }
        .onAppear {
            if !reduceMotion {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    appeared = true
                }
                if isLive {
                    startLivePulse()
                }
            } else {
                appeared = true
                if isLive { livePulse = true }
            }
        }
        .onChange(of: isLive) { _, newValue in
            if newValue && !reduceMotion {
                startLivePulse()
            }
        }
    }

    // MARK: - LIVE-Puls starten

    private func startLivePulse() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            livePulse = true
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Titel — full-width, dunkle Farbe (kein Farbbalken, keine Uhrzeit)
                Text(event.title)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 4)

                // Kalender-Titel
                Text(event.calendarTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                // Zeitraum mit Datum
                Text(timeRange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.bottom, 6)

                // Countdown
                countdownPill
                    .padding(.bottom, 16)

                // Provider-Info — zwischen Countdown und Join-Button
                if let meetingLink = event.meetingLink {
                    HStack(spacing: 6) {
                        Image(systemName: meetingLink.provider.iconName)
                            .font(.system(size: 13))
                        Text(meetingLink.provider.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                }

                // Ort (wenn vorhanden und nicht eine Meeting-URL)
                if let location = displayLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                        Text(location)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                }

                // Kein Einwahllink Warnung
                if !event.hasMeetingLink {
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
                    .padding(.bottom, 16)
                }

                // Buttons
                actionButtons
                    .padding(.bottom, 20)

                // Snooze
                snoozeSection
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)

            // LIVE Badge — pulsierender roter Dot + "LIVE" oben rechts
            if isLive {
                liveBadge
                    .padding(.top, 16)
                    .padding(.trailing, 16)
            }
        }
        .frame(width: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 40, y: 12)
        // Kein .environment(\.colorScheme, .dark) — helles Glassmorphic nach Stitch-Design
    }

    // MARK: - LIVE Badge

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .opacity(livePulse ? 1.0 : 0.5)
                .shadow(color: .white.opacity(livePulse ? 0.8 : 0.0), radius: 4)

            Text("LIVE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.red, in: Capsule())
        .accessibilityLabel("Meeting läuft bereits")
    }

    // MARK: - Countdown Pill

    private var countdownPill: some View {
        let diff = event.startDate.timeIntervalSince(now)
        let isRunning = diff <= 0
        let isUrgent = diff > 0 && diff <= 60
        let isCritical = diff > 0 && diff <= 10
        let color: Color = isRunning ? .green : (isCritical ? .red : (isUrgent ? .orange : .cyan))
        let fontSize: CGFloat = isCritical ? 20 : 13

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.6), radius: 4)

            Text(countdownText)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(color)
                .animation(.easeInOut(duration: 0.3), value: isCritical)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .animation(.easeInOut(duration: 0.3), value: isCritical)
        .accessibilityLabel(countdownText)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Join-Button — solid blau (#3B82F6), kein Glass
            if let meetingLink = event.meetingLink {
                Button(action: onJoin) {
                    HStack(spacing: 8) {
                        Image(systemName: meetingLink.provider.iconName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(meetingLink.provider.joinLabel)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(red: 0.23, green: 0.51, blue: 0.96), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(meetingLink.provider.accessibilityJoinLabel)
            }

            // Schließen-Button — Outline mit dunklem Text
            Button(action: onDismiss) {
                Text("Schließen")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Erinnerung schließen")
        }
    }

    // MARK: - Snooze (horizontal)

    private var snoozeSection: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("Später erinnern")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("|")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Button(action: onSnooze) {
                Text("In 1 Minute erneut erinnern")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("In einer Minute erneut erinnern")
        }
        .padding(.bottom, 4)
    }

    // MARK: - Hilfsfunktionen

    private var timeRange: String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "dd.MM."
        return "\(timeFmt.string(from: event.startDate)) – \(timeFmt.string(from: event.endDate)) (\(dateFmt.string(from: event.startDate)))"
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

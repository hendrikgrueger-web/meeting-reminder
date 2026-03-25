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
        // Wenn location eine Meeting-URL enthält → nicht als Adresse anzeigen
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
            // Vollbild dimmed + blur Hintergrund — Desktop scheint sanft durch
            Rectangle()
                .fill(.black.opacity(0.65))
                .overlay(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
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
                // Slide-Down Spring Animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    appeared = true
                }
                // LIVE-Puls starten wenn Meeting bereits läuft
                if isLive {
                    startLivePulse()
                }
            } else {
                appeared = true
                if isLive { livePulse = true }
            }
        }
        .onChange(of: isLive) { _, newValue in
            // Puls aktivieren sobald Meeting live geht
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
                // Uhrzeit — gut sichtbar (0.75 statt 0.4)
                Text(now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 28)

                // Kalenderfarbe-Akzent + Titel
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.calendarColor)
                        .frame(width: 4, height: 44)   // höher: 44pt statt 32pt
                        .padding(.trailing, 12)

                    Text(event.title)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.bottom, 4)

                // Kalender-Titel — besser sichtbar (0.75 statt 0.5)
                VStack(spacing: 2) {
                    Text(event.calendarTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.bottom, 8)

                // Zeitraum — klar lesbar (0.9 statt 0.6)
                Text(timeRange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.bottom, 6)

                // Countdown — wird bei < 10 Sek. größer und rot
                countdownPill
                    .padding(.bottom, 24)

                // Ort (wenn vorhanden und nicht eine Meeting-URL)
                if let location = displayLocation {
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
        .shadow(color: .black.opacity(0.5), radius: 40, y: 12)
        .environment(\.colorScheme, .dark)   // Erzwingt dunkles Glas — größter Kontrastgewinn
    }

    // MARK: - LIVE Badge

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.white)                          // weiß auf rotem Hintergrund
                .frame(width: 7, height: 7)
                .opacity(livePulse ? 1.0 : 0.5)
                .shadow(color: .white.opacity(livePulse ? 0.8 : 0.0), radius: 4)

            Text("LIVE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)               // weißer Text statt roter auf hellem Grund
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.red, in: Capsule())               // solider roter Hintergrund statt opacity(0.15)
        .accessibilityLabel("Meeting läuft bereits")
    }

    // MARK: - Countdown Pill

    private var countdownPill: some View {
        let diff = event.startDate.timeIntervalSince(now)
        let isRunning = diff <= 0
        let isUrgent = diff > 0 && diff <= 60
        // Countdown < 10 Sekunden: rot und größer
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
            // Beitreten Button — mit Provider-Icon, Label und "via Provider" Hinweis
            if let meetingLink = event.meetingLink {
                VStack(spacing: 4) {
                    Button(action: onJoin) {
                        HStack(spacing: 8) {
                            Image(systemName: meetingLink.provider.iconName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(meetingLink.provider.joinLabel)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.large)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(meetingLink.provider.accessibilityJoinLabel)

                    // Provider-Indikator unter dem Button — besser sichtbar (0.55 statt 0.3)
                    HStack(spacing: 4) {
                        Image(systemName: meetingLink.provider.iconName)
                            .font(.system(size: 9))
                        Text("via \(meetingLink.provider.shortName)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.55))
                    .accessibilityHidden(true)
                }
            }

            // Schließen Button — klar sichtbar mit Kontur und Plain-Style
            Button(action: onDismiss) {
                Text("Schließen")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Erinnerung schließen")
        }
    }

    // MARK: - Snooze

    private var snoozeSection: some View {
        VStack(spacing: 6) {
            // Label besser lesbar (0.6 statt 0.3)
            Text("Später erinnern")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Button(action: onSnooze) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge")
                        .font(.system(size: 10))
                    Text("In 1 Minute erneut erinnern")
                        .font(.system(size: 12, weight: .medium))
                }
                // Snooze-Text besser lesbar (0.8 statt 0.5)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("In einer Minute erneut erinnern")
        }
    }

    // MARK: - Hilfsfunktionen

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

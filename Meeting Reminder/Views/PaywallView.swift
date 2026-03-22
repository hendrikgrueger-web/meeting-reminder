// Meeting Reminder/Views/PaywallView.swift
import SwiftUI
import StoreKit

/// Vollbild-Paywall — erscheint anstelle des normalen Overlays wenn das Free-Tier-Limit erreicht ist.
struct PaywallView: View {

    let event: MeetingEvent
    let onDismiss: () -> Void

    @StateObject private var store = StoreKitService.shared
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            // Hintergrund — identisch zum normalen Overlay
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            paywallCard
                .transition(.move(edge: .top).combined(with: .opacity))
        }
        .onKeyboardShortcut(.escape) { onDismiss() }
    }

    // MARK: - Paywall-Karte

    private var paywallCard: some View {
        VStack(spacing: 0) {

            // Greyed-out Meeting-Info (zeigt was gerade verpasst wird)
            VStack(spacing: 6) {
                Text(event.startDate, style: .time)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.calendarColor)
                        .frame(width: 4, height: 20)
                    Text(event.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.bottom, 20)

            // Premium-Section
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 36))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            Text("Nevr Late Premium")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 6)

            Text("Du hast 50 kostenlose Meeting-Erinnerungen genutzt.\nMit Premium bleibst du unbegrenzt pünktlich.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            // Abonnement-Buttons
            VStack(spacing: 10) {
                // Jahresplan (primär)
                annualButton
                // Monatsplan (sekundär)
                monthlyButton
            }
            .padding(.bottom, 16)

            // Käufe wiederherstellen (App Review Pflicht)
            Button {
                Task {
                    isRestoring = true
                    await store.restorePurchases()
                    isRestoring = false
                    if store.hasActiveSubscription { onDismiss() }
                }
            } label: {
                Text(isRestoring ? "Wird wiederhergestellt…" : "Käufe wiederherstellen")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
        }
        .padding(32)
        .frame(width: 380)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Buttons

    @ViewBuilder
    private var annualButton: some View {
        if let annual = store.products.first(where: { $0.id == StoreKitService.annualID }) {
            Button {
                Task { await store.purchase(annual) ; if store.hasActiveSubscription { onDismiss() } }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jährlich")
                            .font(.system(size: 15, weight: .semibold))
                        Text(annual.displayPrice + " / Jahr")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Spare 33 %")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isPurchasing)
        }
    }

    @ViewBuilder
    private var monthlyButton: some View {
        if let monthly = store.products.first(where: { $0.id == StoreKitService.monthlyID }) {
            Button {
                Task { await store.purchase(monthly) ; if store.hasActiveSubscription { onDismiss() } }
            } label: {
                HStack {
                    Text("Monatlich")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(monthly.displayPrice + " / Monat")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(store.isPurchasing)
        }
    }
}

// MARK: - Keyboard Shortcut Helper

private extension View {
    func onKeyboardShortcut(_ key: KeyEquivalent, action: @escaping () -> Void) -> some View {
        overlay(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: [])
                .opacity(0)
        )
    }
}

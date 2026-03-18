//
//  SettingsView.swift
//  URAP Polar H10 V1
//
//  Modern settings with animated header and rich sections
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var apiBaseURL: String?
    @State private var deviceIP: String?
    @State private var appeared = false
    @State private var headerBreathing = false

    var body: some View {
        ZStack {
            AppTheme.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            if colorScheme == .dark {
                RadialGradient(
                    colors: [AppTheme.neonBlue.opacity(0.05), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: AppTheme.spacing.lg) {
                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.95)

                    apiSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    hrvSettingsSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    aboutSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                }
                .padding(AppTheme.spacing.md)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshAPIInfo()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                headerBreathing = true
            }
        }
    }

    private func refreshAPIInfo() {
        apiBaseURL = APIServer.shared.baseURLString()
        if let urlString = apiBaseURL, let url = URL(string: urlString) {
            deviceIP = url.host
        } else {
            deviceIP = nil
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        GlassCard(accentColor: AppTheme.neonBlue.opacity(0.3)) {
            VStack(spacing: AppTheme.spacing.md) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [AppTheme.neonBlue.opacity(headerBreathing ? 0.25 : 0.12), .clear],
                            center: .center, startRadius: 0, endRadius: 55
                        ))
                        .frame(width: 110, height: 110)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: headerBreathing)

                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(headerBreathing ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: headerBreathing)
                }

                VStack(spacing: 4) {
                    GradientText("Polar H10", gradient: AppTheme.primaryGradient, font: .title2)

                    Text("Research-Grade HRV Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacing.xl)
        }
        .shadow(color: AppTheme.neonBlue.opacity(0.12), radius: 24, x: 0, y: 12)
    }

    // MARK: - API Section

    private var apiSection: some View {
        GlassCard(accentColor: AppTheme.neonCyan.opacity(0.3)) {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                settingsSectionHeader(icon: "network", title: "API for Python", gradient: AppTheme.primaryGradient)

                Divider().opacity(0.3)

                if let ip = deviceIP, let url = apiBaseURL {
                    VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                        Text("Use these in your Python script when the app is open and on the same Wi-Fi.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        apiInfoRow(label: "Device IP", value: ip)
                        apiInfoRow(label: "Base URL", value: url)
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                        HStack(spacing: 8) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Not available")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            unavailableRow("The app is in the foreground")
                            unavailableRow("The device is connected to Wi-Fi")
                        }

                        Text("Then use the Base URL as base_url in Python: get_recording(id, base_url=...)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    private func unavailableRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle")
                .font(.system(size: 6))
                .foregroundColor(.secondary.opacity(0.5))
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func apiInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                Text(value)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button(action: { UIPasteboard.general.string = value }) {
                Image(systemName: "doc.on.doc")
                    .font(.body)
                    .foregroundStyle(AppTheme.primaryGradient)
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(AppTheme.spacing.md)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md))
    }

    // MARK: - HRV Settings

    private var hrvSettingsSection: some View {
        GlassCard(accentColor: AppTheme.neonPurple.opacity(0.3)) {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                settingsSectionHeader(icon: "heart.text.square.fill", title: "HRV Analysis", gradient: AppTheme.purpleGradient)

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                    Text("DEFAULT ANALYSIS WINDOW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    Picker("Default Window", selection: $settings.defaultHRVWindowEnum) {
                        ForEach(HRVWindow.allCases) { window in
                            Text(window.displayName).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(windowDescription(settings.defaultHRVWindowEnum))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, AppTheme.spacing.xs)
                        .animation(.easeInOut, value: settings.defaultHRVWindowEnum)
                }
            }
            .padding(AppTheme.spacing.lg)
        }
        .shadow(color: AppTheme.neonPurple.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                settingsSectionHeader(icon: "info.circle.fill", title: "About", gradient: AppTheme.primaryGradient)

                Divider().opacity(0.3)

                HStack {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settings.fullVersion)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }

                Divider().opacity(0.3)

                VStack(alignment: .leading, spacing: AppTheme.spacing.xs) {
                    Text("FEATURES")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                        .padding(.bottom, 4)

                    ModernFeatureRow(
                        icon: "waveform.path.ecg",
                        title: "Real-time HR & RR Monitoring",
                        description: "High-precision heart rate and RR interval tracking",
                        gradient: AppTheme.heartGradient
                    )
                    ModernFeatureRow(
                        icon: "clock.fill",
                        title: "Research-Grade Timing",
                        description: "Microsecond-precision monotonic timestamps",
                        gradient: AppTheme.primaryGradient
                    )
                    ModernFeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Time-Based HRV Analysis",
                        description: "SDNN and RMSSD over configurable windows",
                        gradient: AppTheme.purpleGradient
                    )
                    ModernFeatureRow(
                        icon: "record.circle",
                        title: "Manual Recording Control",
                        description: "Start, pause, and stop data collection",
                        gradient: AppTheme.emeraldGradient
                    )
                }

                Divider().opacity(0.3)

                Text("Built for advanced HRV research and analysis with the Polar H10 heart rate monitor.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - Helpers

    private func settingsSectionHeader(icon: String, title: String, gradient: LinearGradient) -> some View {
        HStack(spacing: AppTheme.spacing.sm) {
            NeonIconCircle(icon: icon, gradient: gradient, size: 36)

            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()
        }
    }

    private func windowDescription(_ window: HRVWindow) -> String {
        switch window {
        case .ultraShort1min:  return "Ultra-short analysis. Best for quick assessments."
        case .ultraShort2min:  return "Ultra-short analysis. Good balance of speed and accuracy."
        case .short5min:       return "Short-term analysis. Research standard for HRV measurement."
        case .extended10min:   return "Extended analysis. Maximum data for comprehensive assessment."
        }
    }
}

// MARK: - Modern Feature Row

struct ModernFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing.md) {
            NeonIconCircle(icon: icon, gradient: gradient, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - FeatureRow alias (for backward compat with any other reference)

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        ModernFeatureRow(icon: icon, title: title, description: description, gradient: AppTheme.primaryGradient)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { SettingsView() }
            .preferredColorScheme(.dark)
    }
}

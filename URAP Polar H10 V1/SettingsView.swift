//
//  SettingsView.swift
//  URAP Polar H10 V1
//
//  Modern settings page with beautiful UI
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var apiBaseURL: String?
    @State private var deviceIP: String?

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient - adapts to light/dark mode
                AppTheme.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.spacing.lg) {
                        // Header
                        headerSection

                        // API for Python (device IP & base URL)
                        apiSection

                        // HRV Settings
                        hrvSettingsSection

                        // About Section
                        aboutSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                refreshAPIInfo()
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

    // MARK: - Header Section

    private var headerSection: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.md) {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .symbolRenderingMode(.hierarchical)

                GradientText("Polar H10", gradient: AppTheme.primaryGradient, font: .title2)

                Text("Research-Grade HRV Analysis")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - API Section (Device IP & Base URL for Python)

    private var apiSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    Image(systemName: "network")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("API for Python")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                if let ip = deviceIP, let url = apiBaseURL {
                    VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                        Text("Use these in your Python script when the app is open and on the same Wi‑Fi as your computer.")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))

                        apiInfoRow(label: "Device IP", value: ip)
                        apiInfoRow(label: "Base URL", value: url)
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                        Text("Device IP and base URL appear here when:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• The app is in the foreground")
                            Text("• The device is connected to Wi‑Fi")
                        }
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))

                        Text("Then use the Base URL as base_url in Python: get_recording(id, base_url=...)")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.6))
                            .padding(.top, 4)
                    }
                }
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    private func apiInfoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button(action: {
                UIPasteboard.general.string = value
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.body)
                    .foregroundColor(AppTheme.accentBlue)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - HRV Settings Section

    private var hrvSettingsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("HRV Analysis")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                    Text("Default Analysis Window")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.7))

                    Picker("Default Window", selection: $settings.defaultHRVWindowEnum) {
                        ForEach(HRVWindow.allCases) { window in
                            Text(window.displayName).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .background(AppTheme.glassMaterial)
                    .cornerRadius(AppTheme.cornerRadius.sm)

                    Text(windowDescription(settings.defaultHRVWindowEnum))
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(.top, AppTheme.spacing.xs)
                }
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.primaryGradient)

                    Text("About")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                StatRow(label: "Version", value: settings.fullVersion, icon: "app.badge")

                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                    Text("Features")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    FeatureRow(icon: "waveform.path.ecg", title: "Real-time HR & RR Monitoring", description: "High-precision heart rate and RR interval tracking")

                    FeatureRow(icon: "clock.fill", title: "Research-Grade Timing", description: "Microsecond-precision monotonic timestamps")

                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Time-Based HRV Analysis", description: "SDNN and RMSSD calculated over configurable windows")

                    FeatureRow(icon: "record.circle", title: "Manual Recording Control", description: "Start, pause, and stop data collection independently")
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                Text("Built for advanced HRV research and analysis with the Polar H10 heart rate monitor.")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - Helper Functions

    private func windowDescription(_ window: HRVWindow) -> String {
        switch window {
        case .ultraShort1min:
            return "Ultra-short term analysis. Best for quick assessments."
        case .ultraShort2min:
            return "Ultra-short term analysis. Good balance of speed and accuracy."
        case .short5min:
            return "Short-term analysis. Research standard for HRV measurement."
        case .extended10min:
            return "Extended analysis. Maximum data for comprehensive assessment."
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppTheme.primaryGradient)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.dark)
    }
}

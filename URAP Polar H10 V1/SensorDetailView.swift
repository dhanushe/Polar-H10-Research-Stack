//
//  SensorDetailView.swift
//  URAP Polar H10 V1
//
//  Ultra-modern sensor detail view with live metrics and beautiful charts
//

import SwiftUI
import Combine
import Charts

struct SensorDetailView: View {
    @ObservedObject var sensor: ConnectedSensor
    @StateObject private var recordingCoordinator = RecordingCoordinator.shared
    @State private var selectedTimeRange: TimeRange = .twoMinutes
    @State private var currentTime = Date()
    @State private var selectedHRTimestamp: Date?
    @State private var selectedRRTimestamp: Date?
    @State private var sectionsAppeared = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            if colorScheme == .dark {
                RadialGradient(
                    colors: [AppTheme.neonRed.opacity(0.04), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: AppTheme.spacing.lg) {
                    heroBPMCard
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                    quickStatsGrid
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                    connectionStatusCard
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                    hrvMetricsCard
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                    chartsSection
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)
                }
                .padding(AppTheme.spacing.md)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(sensor.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                sectionsAppeared = true
            }
        }
        .onReceive(timer) { _ in
            if sensor.isActive { currentTime = Date() }
        }
    }

    // MARK: - Hero BPM Card

    private var heroBPMCard: some View {
        GlassCard(accentColor: sensor.isActive ? AppTheme.neonRed.opacity(0.6) : nil) {
            VStack(spacing: 0) {
                // Decorative gradient bar at top
                Rectangle()
                    .fill(sensor.isActive ? AppTheme.heartGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppTheme.cornerRadius.lg, topTrailingRadius: AppTheme.cornerRadius.lg))

                VStack(spacing: AppTheme.spacing.lg) {
                    // Status / recording badge
                    if recordingCoordinator.state.isActive {
                        HStack {
                            RecordingStatusBadge(state: recordingCoordinator.state)
                            Spacer()
                        }
                    }

                    // Large HR display with animated rings
                    ZStack {
                        if sensor.isActive {
                            ForEach([0, 1], id: \.self) { i in
                                PulsingRing(
                                    color: AppTheme.neonRed,
                                    baseSize: 100 + CGFloat(i) * 36
                                )
                                .opacity(0.08 - Double(i) * 0.03)
                            }
                        }

                        VStack(spacing: 6) {
                            if sensor.isActive {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppTheme.heartGradient)
                                    .symbolEffect(.pulse, options: .repeating, value: sensor.isActive)
                            } else {
                                Image(systemName: "heart")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }

                            Text("\(sensor.heartRate)")
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    sensor.isActive
                                        ? AnyShapeStyle(AppTheme.heartGradient)
                                        : AnyShapeStyle(Color.primary.opacity(0.2))
                                )
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: sensor.heartRate)

                            Text("BPM")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .tracking(3)
                        }
                    }
                    .frame(height: 160)

                    if !sensor.isActive {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(.secondary)
                            Text("Waiting for data…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(AppTheme.spacing.xl)
            }
        }
        .shadow(
            color: sensor.isActive ? AppTheme.neonRed.opacity(0.2) : .clear,
            radius: 28, x: 0, y: 14
        )
    }

    // MARK: - Quick Stats Grid

    private var quickStatsGrid: some View {
        HStack(spacing: AppTheme.spacing.sm) {
            QuickStatCard(label: "MIN", value: "\(sensor.minHeartRate)", unit: "BPM",
                          color: AppTheme.neonBlue, gradient: AppTheme.primaryGradient)
                .frame(maxWidth: .infinity)
            QuickStatCard(label: "AVG", value: "\(sensor.averageHeartRate)", unit: "BPM",
                          color: AppTheme.neonGreen, gradient: AppTheme.emeraldGradient)
                .frame(maxWidth: .infinity)
            QuickStatCard(label: "MAX", value: "\(sensor.maxHeartRate)", unit: "BPM",
                          color: AppTheme.neonRed, gradient: AppTheme.heartGradient)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        GlassCard {
            HStack(spacing: AppTheme.spacing.md) {
                NeonIconCircle(
                    icon: connectionIcon,
                    gradient: connectionGradient,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Device ID: \(sensor.displayId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(sensor.connectionState.displayText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Spacer()

                // Battery badge
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .font(.caption)
                        .foregroundColor(batteryColor)
                    Text("\(sensor.batteryLevel)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(batteryColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(batteryColor.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - HRV Metrics Card

    private var hrvMetricsCard: some View {
        GlassCard(accentColor: AppTheme.neonPurple.opacity(0.3)) {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    NeonIconCircle(icon: "brain.head.profile", gradient: AppTheme.purpleGradient, size: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HRV Analysis")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Heart Rate Variability")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Window Selector
                VStack(alignment: .leading, spacing: AppTheme.spacing.xs) {
                    Text("ANALYSIS WINDOW")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1.5)

                    Picker("Window", selection: $sensor.hrvWindow) {
                        ForEach(HRVWindow.allCases) { window in
                            Text(window.displayName).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sensor.hrvWindow) { _, _ in sensor.calculateHRVMetrics() }

                    if sensor.hrvSampleCount > 0 {
                        Text("\(sensor.hrvSampleCount) RR intervals analyzed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if sensor.sdnn > 0 {
                    Divider().opacity(0.3)

                    VStack(spacing: AppTheme.spacing.sm) {
                        HRVMetricDisplay(
                            name: "SDNN",
                            value: sensor.sdnn,
                            interpretation: interpretSDNN(sensor.sdnn),
                            description: "Standard deviation of RR intervals"
                        )
                        HRVMetricDisplay(
                            name: "RMSSD",
                            value: sensor.rmssd,
                            interpretation: interpretRMSSD(sensor.rmssd),
                            description: "Root mean square of successive differences"
                        )
                    }
                } else {
                    HStack(spacing: AppTheme.spacing.sm) {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(AppTheme.neonPurple)
                        Text("Collecting data for HRV analysis…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(AppTheme.spacing.lg)
        }
        .shadow(color: AppTheme.neonPurple.opacity(0.08), radius: 20, x: 0, y: 8)
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: AppTheme.spacing.md) {
            timeRangeSelector

            modernChartCard(
                title: "Heart Rate",
                icon: "heart.fill",
                gradient: AppTheme.heartGradient,
                accentColor: AppTheme.neonRed,
                data: filteredHeartRateData,
                emptyMsg: "No heart rate data yet",
                selectedTimestamp: $selectedHRTimestamp,
                nearestValue: { ts in
                    filteredHeartRateData
                        .min(by: { abs($0.timestamp.timeIntervalSince(ts)) < abs($1.timestamp.timeIntervalSince(ts)) })
                        .map { Double($0.value) }
                },
                unit: "BPM"
            )

            modernChartCard(
                title: "RR Interval",
                icon: "waveform.path.ecg",
                gradient: AppTheme.hrvGradient,
                accentColor: AppTheme.neonBlue,
                data: filteredRRIntervalData,
                emptyMsg: "No RR interval data yet",
                selectedTimestamp: $selectedRRTimestamp,
                nearestValue: { ts in
                    filteredRRIntervalData
                        .min(by: { abs($0.timestamp.timeIntervalSince(ts)) < abs($1.timestamp.timeIntervalSince(ts)) })
                        .map { Double($0.value) }
                },
                unit: "ms"
            )
        }
    }

    private func modernChartCard<T: Identifiable>(
        title: String,
        icon: String,
        gradient: LinearGradient,
        accentColor: Color,
        data: [T],
        emptyMsg: String,
        selectedTimestamp: Binding<Date?>,
        nearestValue: @escaping (Date) -> Double?,
        unit: String
    ) -> some View where T: HasTimestampAndValue {
        GlassCard(accentColor: accentColor.opacity(0.3)) {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack(spacing: AppTheme.spacing.sm) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(gradient)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    if !data.isEmpty {
                        Text("\(data.count) pts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                if data.isEmpty {
                    EmptyChartPlaceholder(message: emptyMsg)
                } else {
                    Chart(data) { dp in
                        LineMark(
                            x: .value("Time", dp.chartTimestamp),
                            y: .value(unit, dp.chartValue)
                        )
                        .foregroundStyle(gradient)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Time", dp.chartTimestamp),
                            y: .value(unit, dp.chartValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentColor.opacity(0.25), accentColor.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        if let sel = selectedTimestamp.wrappedValue,
                           let val = nearestValue(sel) {
                            RuleMark(x: .value("Selected", sel))
                                .foregroundStyle(accentColor.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            PointMark(
                                x: .value("Selected", sel),
                                y: .value(unit, val)
                            )
                            .foregroundStyle(accentColor)
                            .symbolSize(64)
                        }
                    }
                    .chartXSelection(value: selectedTimestamp)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .second, count: 30)) {
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                            AxisValueLabel(format: .dateTime.minute().second())
                                .font(.system(size: 9, design: .monospaced))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                            AxisValueLabel().font(.system(size: 9))
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { _ in
                            if let sel = selectedTimestamp.wrappedValue,
                               let val = nearestValue(sel),
                               let xPos = proxy.position(forX: sel) {
                                ChartTooltipBubble(
                                    value: String(Int(val)),
                                    unit: unit,
                                    timestamp: formatTooltipTime(sel),
                                    color: accentColor
                                )
                                .position(x: xPos, y: -30)
                            }
                        }
                    }
                    .frame(height: 180)
                    .animation(.easeInOut(duration: 0.2), value: data.count)
                }
            }
            .padding(AppTheme.spacing.lg)
        }
        .shadow(color: accentColor.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: AppTheme.spacing.xs) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let selected = selectedTimeRange == range
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                    }
                }) {
                    Text(range.displayName)
                        .font(.system(size: 13, weight: selected ? .bold : .regular))
                        .foregroundColor(selected ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if selected {
                                    AppTheme.primaryGradient
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selected ? .clear : Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(ScalePressStyle())
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch sensor.connectionState {
        case .connected:    return sensor.isActive ? AppTheme.neonGreen : .yellow
        case .connecting:   return AppTheme.neonOrange
        case .disconnected: return AppTheme.neonRed
        }
    }

    private var connectionIcon: String {
        switch sensor.connectionState {
        case .connected:    return sensor.isActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .disconnected: return "xmark.circle"
        }
    }

    private var connectionGradient: LinearGradient {
        switch sensor.connectionState {
        case .connected:    return sensor.isActive ? AppTheme.emeraldGradient : AppTheme.sunriseGradient
        case .connecting:   return AppTheme.sunriseGradient
        case .disconnected: return AppTheme.heartGradient
        }
    }

    private var batteryIcon: String {
        if sensor.batteryLevel > 75 { return "battery.100" }
        if sensor.batteryLevel > 50 { return "battery.75" }
        if sensor.batteryLevel > 25 { return "battery.50" }
        if sensor.batteryLevel > 10 { return "battery.25" }
        return "battery.0"
    }

    private var batteryColor: Color {
        sensor.batteryLevel > 20 ? AppTheme.neonGreen : AppTheme.neonRed
    }

    private var filteredHeartRateData: [HeartRateDataPoint] {
        guard !sensor.heartRateHistory.isEmpty else { return [] }
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return sensor.heartRateHistory.filter { $0.timestamp >= cutoff }
    }

    private var filteredRRIntervalData: [RRIntervalDataPoint] {
        guard !sensor.rrIntervalHistory.isEmpty else { return [] }
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return sensor.rrIntervalHistory.filter { $0.timestamp >= cutoff }
    }

    private func interpretSDNN(_ value: Double) -> (String, Color) {
        if value > 100 { return ("Excellent", AppTheme.neonGreen) }
        if value > 50  { return ("Good",      AppTheme.neonGreen) }
        if value > 25  { return ("Fair",      AppTheme.neonOrange) }
        return ("Low", AppTheme.neonRed)
    }

    private func interpretRMSSD(_ value: Double) -> (String, Color) {
        if value > 50 { return ("Excellent", AppTheme.neonGreen) }
        if value > 30 { return ("Good",      AppTheme.neonGreen) }
        if value > 15 { return ("Fair",      AppTheme.neonOrange) }
        return ("Low", AppTheme.neonRed)
    }

    private func formatTooltipTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

// MARK: - Protocol for generic chart

protocol HasTimestampAndValue {
    var chartTimestamp: Date { get }
    var chartValue: Double { get }
}

extension HeartRateDataPoint: HasTimestampAndValue {
    var chartTimestamp: Date { timestamp }
    var chartValue: Double { Double(value) }
}

extension RRIntervalDataPoint: HasTimestampAndValue {
    var chartTimestamp: Date { timestamp }
    var chartValue: Double { Double(value) }
}

// MARK: - Pulsing Ring

struct PulsingRing: View {
    let color: Color
    let baseSize: CGFloat
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: baseSize, height: baseSize)
            .scaleEffect(scale)
            .opacity(2.5 - scale * 1.5)
            .onAppear {
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    scale = 1.5
                }
            }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let gradient: LinearGradient

    var body: some View {
        GlassCard {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                    .tracking(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())

                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(gradient)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacing.lg)
            .padding(.horizontal, AppTheme.spacing.sm)
        }
        .shadow(color: color.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

// MARK: - HRV Metric Display

struct HRVMetricDisplay: View {
    let name: String
    let value: Double
    let interpretation: (String, Color)
    let description: String

    var body: some View {
        HStack(spacing: AppTheme.spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .tracking(1)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(interpretation.1)
                        .frame(width: 6, height: 6)
                        .shadow(color: interpretation.1.opacity(0.9), radius: 3)
                    Text(interpretation.0)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(interpretation.1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(interpretation.1.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.spacing.md)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md))
    }
}

// MARK: - Empty Chart Placeholder

struct EmptyChartPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.3))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Time Range Enum

enum TimeRange: CaseIterable {
    case thirtySeconds, oneMinute, twoMinutes, fiveMinutes

    var displayName: String {
        switch self {
        case .thirtySeconds: return "30s"
        case .oneMinute:     return "1m"
        case .twoMinutes:    return "2m"
        case .fiveMinutes:   return "5m"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .thirtySeconds: return 30
        case .oneMinute:     return 60
        case .twoMinutes:    return 120
        case .fiveMinutes:   return 300
        }
    }
}

// MARK: - Chart Tooltip Bubble

struct ChartTooltipBubble: View {
    let value: String
    let unit: String
    let timestamp: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color.opacity(0.8))
            }
            Text(timestamp)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

struct SensorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SensorDetailView(sensor: ConnectedSensor(deviceId: "12345", deviceName: "Polar H10"))
        }
        .preferredColorScheme(.dark)
    }
}

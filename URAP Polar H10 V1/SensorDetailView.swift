//
//  SensorDetailView.swift
//  URAP Polar H10 V1
//
//  Modern sensor detail view with fixed graphs and beautiful UI
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.spacing.lg) {
                    // Header Card
                    headerCard

                    // Primary Heart Rate Display
                    primaryHeartRateCard

                    // Quick Stats
                    quickStatsGrid

                    // HRV Metrics
                    hrvMetricsCard

                    // Charts Section
                    chartsSection
                }
                .padding()
            }
        }
        .navigationTitle(sensor.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            if sensor.isActive {
                currentTime = Date()
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device ID: \(sensor.displayId)")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(sensor.connectionState.displayText)
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.7))

                        if recordingCoordinator.state.isActive {
                            Text("•")
                                .foregroundColor(.primary.opacity(0.7))

                            RecordingStatusBadge(state: recordingCoordinator.state)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Primary Heart Rate Card

    private var primaryHeartRateCard: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.md) {
                AnimatedMetricView(
                    value: "\(sensor.heartRate)",
                    label: "Heart Rate (BPM)",
                    icon: "heart.fill",
                    color: .red,
                    showPulse: sensor.isActive
                )

                if !sensor.isActive {
                    Text("Waiting for data...")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - Quick Stats Grid

    private var quickStatsGrid: some View {
        HStack(spacing: AppTheme.spacing.sm) {
            QuickStatCard(label: "Min", value: "\(sensor.minHeartRate)", unit: "BPM", color: .blue)
                .frame(maxWidth: .infinity)
            QuickStatCard(label: "Avg", value: "\(sensor.averageHeartRate)", unit: "BPM", color: .green)
                .frame(maxWidth: .infinity)
            QuickStatCard(label: "Max", value: "\(sensor.maxHeartRate)", unit: "BPM", color: .red)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - HRV Metrics Card

    private var hrvMetricsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                GradientText("HRV Analysis", gradient: AppTheme.primaryGradient, font: .headline)

                // Window Selector
                VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                    Text("Analysis Window")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))

                    Picker("Window", selection: $sensor.hrvWindow) {
                        ForEach(HRVWindow.allCases) { window in
                            Text(window.displayName).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sensor.hrvWindow) { oldValue, newValue in
                        sensor.calculateHRVMetrics()
                    }

                    if sensor.hrvSampleCount > 0 {
                        Text("\(sensor.hrvSampleCount) RR intervals analyzed")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }

                if sensor.sdnn > 0 {
                    Divider()

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
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.primary.opacity(0.7))
                        Text("Collecting data for HRV analysis...")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.7))
                    }
                }
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: AppTheme.spacing.lg) {
            // Time Range Selector
            timeRangeSelector

            // Heart Rate Chart
            GlassCard {
                VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                    Text("Heart Rate")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if filteredHeartRateData.isEmpty {
                        EmptyChartPlaceholder(message: "No heart rate data")
                    } else {
                        Chart(filteredHeartRateData) { dataPoint in
                            LineMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("BPM", dataPoint.value)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("BPM", dataPoint.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .pink.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Selection indicator
                            if let selectedHRTimestamp, let selectedValue = findNearestHeartRateValue(for: selectedHRTimestamp) {
                                RuleMark(x: .value("Selected", selectedHRTimestamp))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                                PointMark(
                                    x: .value("Selected", selectedHRTimestamp),
                                    y: .value("BPM", selectedValue)
                                )
                                .foregroundStyle(.red)
                                .symbolSize(36)
                            }
                        }
                        .chartXSelection(value: $selectedHRTimestamp)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .second, count: 30)) {
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.minute().second(), centered: true)
                                    .font(.caption2)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) {
                                AxisGridLine()
                                AxisValueLabel()
                                    .font(.caption2)
                            }
                        }
                        .chartOverlay { chartProxy in
                            GeometryReader { geometry in
                                if let selectedHRTimestamp, let selectedValue = findNearestHeartRateValue(for: selectedHRTimestamp) {
                                    let dateInterval = chartProxy.plotAreaSize.width / CGFloat(filteredHeartRateData.count)
                                    if let xPosition = chartProxy.position(forX: selectedHRTimestamp) {
                                        ChartTooltipBubble(
                                            value: "\(selectedValue)",
                                            unit: "BPM",
                                            timestamp: formatTooltipTime(selectedHRTimestamp),
                                            color: .red
                                        )
                                        .position(
                                            x: xPosition,
                                            y: -30
                                        )
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .padding(AppTheme.spacing.lg)
            }

            // RR Interval Chart
            GlassCard {
                VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                    Text("RR Interval")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if filteredRRIntervalData.isEmpty {
                        EmptyChartPlaceholder(message: "No RR interval data")
                    } else {
                        Chart(filteredRRIntervalData) { dataPoint in
                            LineMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("ms", dataPoint.value)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                            )
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Time", dataPoint.timestamp),
                                y: .value("ms", dataPoint.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .cyan.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            // Selection indicator
                            if let selectedRRTimestamp, let selectedValue = findNearestRRIntervalValue(for: selectedRRTimestamp) {
                                RuleMark(x: .value("Selected", selectedRRTimestamp))
                                    .foregroundStyle(Color.primary.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                                PointMark(
                                    x: .value("Selected", selectedRRTimestamp),
                                    y: .value("ms", selectedValue)
                                )
                                .foregroundStyle(.blue)
                                .symbolSize(36)
                            }
                        }
                        .chartXSelection(value: $selectedRRTimestamp)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .second, count: 30)) {
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.minute().second(), centered: true)
                                    .font(.caption2)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) {
                                AxisGridLine()
                                AxisValueLabel()
                                    .font(.caption2)
                            }
                        }
                        .chartOverlay { chartProxy in
                            GeometryReader { geometry in
                                if let selectedRRTimestamp, let selectedValue = findNearestRRIntervalValue(for: selectedRRTimestamp) {
                                    let dateInterval = chartProxy.plotAreaSize.width / CGFloat(filteredRRIntervalData.count)
                                    if let xPosition = chartProxy.position(forX: selectedRRTimestamp) {
                                        ChartTooltipBubble(
                                            value: "\(selectedValue)",
                                            unit: "ms",
                                            timestamp: formatTooltipTime(selectedRRTimestamp),
                                            color: .blue
                                        )
                                        .position(
                                            x: xPosition,
                                            y: -30
                                        )
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .padding(AppTheme.spacing.lg)
            }
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: AppTheme.spacing.sm) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                }) {
                    Text(range.displayName)
                        .font(.caption)
                        .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(selectedTimeRange == range ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedTimeRange == range ?
                            AppTheme.primaryGradient :
                            LinearGradient(colors: [AppTheme.glassMaterial], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(AppTheme.cornerRadius.sm)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch sensor.connectionState {
        case .connected: return sensor.isActive ? .green : .yellow
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private var currentSessionDuration: TimeInterval {
        // Use currentTime to force SwiftUI to recalculate
        _ = currentTime
        return sensor.sessionDuration
    }

    private var filteredHeartRateData: [HeartRateDataPoint] {
        guard !sensor.heartRateHistory.isEmpty else { return [] }
        let cutoffTime = Date().addingTimeInterval(-selectedTimeRange.seconds)
        // Create a copy to avoid concurrent modification issues
        let historyCopy = sensor.heartRateHistory
        return historyCopy.filter { $0.timestamp >= cutoffTime }
    }

    private var filteredRRIntervalData: [RRIntervalDataPoint] {
        guard !sensor.rrIntervalHistory.isEmpty else { return [] }
        let cutoffTime = Date().addingTimeInterval(-selectedTimeRange.seconds)
        // Create a copy to avoid concurrent modification issues
        let historyCopy = sensor.rrIntervalHistory
        return historyCopy.filter { $0.timestamp >= cutoffTime }
    }

    // MARK: - Helper Functions

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func interpretSDNN(_ value: Double) -> (String, Color) {
        if value > 100 { return ("Excellent", .green) }
        if value > 50 { return ("Good", .green) }
        if value > 25 { return ("Fair", .orange) }
        return ("Low", .red)
    }

    private func interpretRMSSD(_ value: Double) -> (String, Color) {
        if value > 50 { return ("Excellent", .green) }
        if value > 30 { return ("Good", .green) }
        if value > 15 { return ("Fair", .orange) }
        return ("Low", .red)
    }

    // MARK: - Chart Interaction Helpers

    private func findNearestHeartRateValue(for timestamp: Date) -> UInt8? {
        guard !filteredHeartRateData.isEmpty else { return nil }
        return filteredHeartRateData.min(by: { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) })?.value
    }

    private func findNearestRRIntervalValue(for timestamp: Date) -> UInt16? {
        guard !filteredRRIntervalData.isEmpty else { return nil }
        return filteredRRIntervalData.min(by: { abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp)) })?.value
    }

    private func formatTooltipTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.7))

                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacing.lg)
            .padding(.horizontal, AppTheme.spacing.md)
        }
    }
}

// MARK: - HRV Metric Display

struct HRVMetricDisplay: View {
    let name: String
    let value: Double
    let interpretation: (String, Color)
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                Text(String(format: "%.1f ms", value))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(interpretation.0)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(interpretation.1)
                    .cornerRadius(6)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))
                .lineLimit(2)
        }
    }
}

// MARK: - Empty Chart Placeholder

struct EmptyChartPlaceholder: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Time Range Enum

enum TimeRange: CaseIterable {
    case thirtySeconds
    case oneMinute
    case twoMinutes
    case fiveMinutes

    var displayName: String {
        switch self {
        case .thirtySeconds: return "30s"
        case .oneMinute: return "1m"
        case .twoMinutes: return "2m"
        case .fiveMinutes: return "5m"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .thirtySeconds: return 30
        case .oneMinute: return 60
        case .twoMinutes: return 120
        case .fiveMinutes: return 300
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
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.7))
                .lineLimit(1)

            Text(timestamp)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.7))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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

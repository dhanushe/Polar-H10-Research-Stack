//
//  RawDataViewerSheet.swift
//  URAP Polar H10 V1
//
//  Full-screen raw data viewer with search and filtering
//

import SwiftUI

struct RawDataViewerSheet: View {
    let recording: RecordingSession

    @State private var selectedSensorIndex = 0
    @State private var selectedDataType: DataType = .heartRate
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    enum DataType: String, CaseIterable {
        case heartRate = "Heart Rate"
        case rrInterval = "RR Intervals"
        case accelerometer = "Accelerometer"
    }

    // Color palette for sensor distinction
    private let sensorColors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]

    var currentSensorColor: Color {
        sensorColors[selectedSensorIndex % sensorColors.count]
    }

    // Safe access to selected sensor with bounds checking
    var selectedSensor: SensorRecording? {
        guard selectedSensorIndex < recording.sensorRecordings.count else {
            return nil
        }
        return recording.sensorRecordings[selectedSensorIndex]
    }

    private var dataTypeUnit: String {
        switch selectedDataType {
        case .heartRate: return "BPM"
        case .rrInterval: return "ms"
        case .accelerometer: return "mG"
        }
    }

    // Computed property to check if current selection is valid
    private var isValidSelection: Bool {
        selectedSensorIndex < recording.sensorRecordings.count && !recording.sensorRecordings.isEmpty
    }

    var filteredData: [DataRow] {
        guard let sensor = selectedSensor else {
            return []
        }

        let rows: [DataRow]

        switch selectedDataType {
        case .heartRate:
            rows = sensor.heartRateData.enumerated().map { index, point in
                DataRow(
                    index: index + 1,
                    timestamp: point.timestamp,
                    value: "\(point.value)",
                    unit: "BPM",
                    monotonicTime: point.monotonicTimestamp
                )
            }
        case .rrInterval:
            rows = sensor.rrIntervalData.enumerated().map { index, point in
                DataRow(
                    index: index + 1,
                    timestamp: point.timestamp,
                    value: "\(point.value)",
                    unit: "ms",
                    monotonicTime: point.monotonicTimestamp
                )
            }
        case .accelerometer:
            rows = sensor.accelerometerData.enumerated().map { index, point in
                DataRow(
                    index: index + 1,
                    timestamp: point.timestamp,
                    value: "(\(point.x), \(point.y), \(point.z))",
                    unit: "mG",
                    monotonicTime: point.monotonicTimestamp
                )
            }
        }

        if searchText.isEmpty {
            return rows
        } else {
            return rows.filter { row in
                row.value.contains(searchText) ||
                row.formattedTime.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var dataStats: DataStats {
        guard let sensor = selectedSensor else {
            return DataStats(count: 0, min: 0, max: 0, average: 0)
        }

        switch selectedDataType {
        case .heartRate:
            let values = sensor.heartRateData.map { Double($0.value) }
            return DataStats(
                count: values.count,
                min: values.min() ?? 0,
                max: values.max() ?? 0,
                average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            )
        case .rrInterval:
            let values = sensor.rrIntervalData.map { Double($0.value) }
            return DataStats(
                count: values.count,
                min: values.min() ?? 0,
                max: values.max() ?? 0,
                average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            )
        case .accelerometer:
            let magnitudes = sensor.accelerometerData.map { $0.magnitude }
            return DataStats(
                count: magnitudes.count,
                min: magnitudes.min() ?? 0,
                max: magnitudes.max() ?? 0,
                average: magnitudes.isEmpty ? 0 : magnitudes.reduce(0, +) / Double(magnitudes.count)
            )
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()

                if recording.sensorRecordings.isEmpty {
                    // Error state: No sensors
                    VStack(spacing: AppTheme.spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No Sensor Data Available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("This recording has no sensor data to display.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if !isValidSelection {
                    // Error state: Invalid sensor index
                    VStack(spacing: AppTheme.spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Sensor Not Available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("The selected sensor is no longer available.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Sensor picker (if multiple sensors)
                        if recording.sensorRecordings.count > 1 {
                            sensorPicker
                                .padding(.horizontal)
                                .padding(.top, AppTheme.spacing.sm)
                        }

                        // Scrollable content with sticky header
                        ScrollView {
                            VStack(spacing: 0) {
                                // Data type tabs
                                dataTypePicker
                                    .padding(.horizontal)
                                    .padding(.vertical, AppTheme.spacing.sm)

                                // Stats header
                                statsHeader
                                    .padding(.horizontal)
                                    .padding(.bottom, AppTheme.spacing.sm)

                                // Search bar
                                searchBar
                                    .padding(.horizontal)
                                    .padding(.bottom, AppTheme.spacing.sm)

                                // Data table content
                                dataTableContent

                                // Action buttons
                                actionButtons
                                    .padding()
                            }
                        }
                        .safeAreaInset(edge: .top, spacing: 0) {
                            if recording.sensorRecordings.count > 1 {
                                stickyHeaderView
                            }
                        }
                    }
                }
            }
            .navigationTitle("Raw Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentBlue)
                }
            }
            .onAppear {
                // Validate and fix selectedSensorIndex if out of bounds
                if selectedSensorIndex >= recording.sensorRecordings.count {
                    selectedSensorIndex = max(0, recording.sensorRecordings.count - 1)
                }
            }
        }
    }

    // MARK: - Sticky Header

    private var stickyHeaderView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(currentSensorColor)
                .frame(width: 12, height: 12)
                .shadow(color: currentSensorColor.opacity(0.5), radius: 3, x: 0, y: 1)

            Text(selectedSensor?.sensorName ?? "Unknown Sensor")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("(\(selectedSensorIndex + 1) of \(recording.sensorRecordings.count))")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: selectedDataType == .heartRate ? "heart.fill" : selectedDataType == .rrInterval ? "waveform.path.ecg" : "move.3d")
                .font(.caption)
                .foregroundColor(currentSensorColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(currentSensorColor.opacity(0.08))
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(currentSensorColor)
                .frame(height: 2),
            alignment: .bottom
        )
    }

    // MARK: - Sensor Picker

    private var sensorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacing.sm) {
                ForEach(Array(recording.sensorRecordings.enumerated()), id: \.offset) { index, sensor in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSensorIndex = index
                        }
                    }) {
                        let isSelected = selectedSensorIndex == index
                        let sensorColor = sensorColors[index % sensorColors.count]

                        HStack(spacing: 8) {
                            Circle()
                                .fill(sensorColor)
                                .frame(width: 8, height: 8)

                            Text(sensor.sensorName)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(isSelected ? .white : .primary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if isSelected {
                                    sensorColor
                                } else {
                                    Color.secondary.opacity(0.2)
                                }
                            }
                        )
                        .cornerRadius(AppTheme.cornerRadius.full)
                        .shadow(color: isSelected ? sensorColor.opacity(0.4) : .clear, radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }

    // MARK: - Data Type Picker

    private var dataTypePicker: some View {
        GlassCard {
            HStack(spacing: 0) {
                ForEach(DataType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDataType = type
                        }
                    }) {
                        let isSelected = selectedDataType == type
                        Text(type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : .primary.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Group {
                                    if isSelected {
                                        currentSensorColor
                                    } else {
                                        Color.clear
                                    }
                                }
                            )
                            .cornerRadius(AppTheme.cornerRadius.md)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.sm) {
                HStack {
                    Text("\(dataStats.count) Data Points")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: selectedDataType == .heartRate ? "heart.fill" : selectedDataType == .rrInterval ? "waveform.path.ecg" : "move.3d")
                        .foregroundColor(currentSensorColor)
                }

                HStack(spacing: AppTheme.spacing.lg) {
                    StatItem(label: "Min", value: String(format: "%.0f", dataStats.min), unit: dataTypeUnit)
                    StatItem(label: "Avg", value: String(format: "%.0f", dataStats.average), unit: dataTypeUnit)
                    StatItem(label: "Max", value: String(format: "%.0f", dataStats.max), unit: dataTypeUnit)
                }
            }
            .padding(AppTheme.spacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                .stroke(currentSensorColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search by value or time...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .background(.ultraThinMaterial)
        .cornerRadius(AppTheme.cornerRadius.md)
    }

    // MARK: - Data Table

    private var dataTableContent: some View {
        HStack(spacing: 0) {
            // Single continuous accent bar for entire table
            Rectangle()
                .fill(currentSensorColor)
                .frame(width: 4)

            LazyVStack(spacing: 1) {
                // Header row
                HStack(spacing: 12) {
                    Text("#")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: 50, alignment: .leading)

                    Text("Time")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: 100, alignment: .leading)

                    Text("Value")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: 80, alignment: .trailing)

                    Spacer()
                }
                .padding(.horizontal, AppTheme.spacing.md)
                .padding(.vertical, AppTheme.spacing.sm)
                .background(Color.secondary.opacity(0.1))

                // Data rows
                ForEach(filteredData) { row in
                    dataRow(row)
                }

                if filteredData.isEmpty && !searchText.isEmpty {
                    VStack(spacing: AppTheme.spacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No results found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
        }
        .background(Color.primary.opacity(0.02))
        .cornerRadius(AppTheme.cornerRadius.md)
    }

    private func dataRow(_ row: DataRow) -> some View {
        HStack(spacing: 12) {
            Text("\(row.index)")
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.5))
                .frame(width: 50, alignment: .leading)

            Text(row.formattedTime)
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.primary.opacity(0.8))
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 4) {
                Text(row.value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(row.unit)
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.6))
            }
            .frame(width: 80, alignment: .trailing)

            Spacer()
        }
        .padding(.horizontal, AppTheme.spacing.md)
        .padding(.vertical, AppTheme.spacing.sm)
        .background(row.index % 2 == 0 ? currentSensorColor.opacity(0.03) : Color.clear)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppTheme.spacing.md) {
            Button(action: copyData) {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy All")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [currentSensorColor, currentSensorColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(AppTheme.cornerRadius.md)
                .shadow(color: currentSensorColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }

            ShareLink(item: generateCSV()) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.8), Color.gray.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(AppTheme.cornerRadius.md)
            }
        }
    }

    // MARK: - Actions

    private func copyData() {
        let csv = generateCSV()
        UIPasteboard.general.string = csv

        // Could add a toast notification here
        print("✅ Copied \(filteredData.count) data points to clipboard")
    }

    private func generateCSV() -> String {
        var csv: String
        if selectedDataType == .accelerometer {
            csv = "Index,Time,Value (X Y Z mG),Unix Timestamp,Monotonic Time\n"
        } else {
            csv = "Index,Time,Value (\(dataTypeUnit)),Unix Timestamp,Monotonic Time\n"
        }

        for row in filteredData {
            csv += "\(row.index),\(row.formattedTime),\(row.value),\(row.timestamp.timeIntervalSince1970),\(row.monotonicTime)\n"
        }

        return csv
    }
}

// MARK: - Supporting Types

struct DataRow: Identifiable {
    let id = UUID()
    let index: Int
    let timestamp: Date
    let value: String
    let unit: String
    let monotonicTime: TimeInterval

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

struct DataStats {
    let count: Int
    let min: Double
    let max: Double
    let average: Double
}

// MARK: - Preview

#if DEBUG
struct RawDataViewerSheet_Previews: PreviewProvider {
    static var previews: some View {
        RawDataViewerSheet(recording: RecordingSession.preview)
            .preferredColorScheme(.dark)
    }
}
#endif

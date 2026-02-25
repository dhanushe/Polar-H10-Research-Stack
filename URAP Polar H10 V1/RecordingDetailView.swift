//
//  RecordingDetailView.swift
//  URAP Polar H10 V1
//
//  Detailed view of a single recording with charts and metrics
//  Loads recording by ID to handle stale data gracefully
//

import SwiftUI
import Charts
import UniformTypeIdentifiers
import UIKit

// MARK: - Load State

/// Used to present the share sheet with a zip file URL.
struct ShareZipItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum RecordingLoadState: Equatable {
    case loading
    case loaded(RecordingSession)
    case notFound
    case error(String)

    static func == (lhs: RecordingLoadState, rhs: RecordingLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.loaded(let a), .loaded(let b)): return a.id == b.id
        case (.notFound, .notFound): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Recording Detail View

struct RecordingDetailView: View {
    let recordingId: String

    @StateObject private var recordingsManager = RecordingsManager.shared
    @State private var loadState: RecordingLoadState = .loading
    @State private var showRenameSheet = false
    @State private var exportDocument: ExportDocument?
    @State private var exportFilename: String = ""
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var shareZipItem: ShareZipItem?
    @State private var expandedSensors: Set<String> = []
    @State private var showRawDataSheet = false
    @State private var showPythonInfoSheet = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingView

            case .loaded(let recording):
                recordingContent(recording)

            case .notFound:
                notFoundView

            case .error(let message):
                errorView(message)
            }
        }
        .background(AppTheme.adaptiveBackground(for: colorScheme).ignoresSafeArea())
        .task {
            loadRecording()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading recording...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Recording")
    }

    // MARK: - Not Found View

    private var notFoundView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Recording Not Found")
                .font(.title2)
                .fontWeight(.bold)

            Text("This recording may have been deleted.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Go Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Not Found")
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Error Loading Recording")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                loadRecording()
            }
            .buttonStyle(.borderedProminent)

            Button("Go Back") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Error")
    }

    // MARK: - Recording Content

    private func recordingContent(_ recording: RecordingSession) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing.lg) {
                recordingIdHeader(recording.id)

                summarySection(recording)

                if recording.sensorRecordings.isEmpty {
                    noSensorDataView
                } else {
                    ForEach(recording.sensorRecordings) { sensor in
                        sensorSection(for: sensor)
                    }
                }

                rawDataButton(recording)
            }
            .padding()
        }
        .navigationTitle(recording.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showRenameSheet = true }) {
                        Label("Rename", systemImage: "pencil")
                    }

                    Menu {
                        Button(action: { exportCSV(recording) }) {
                            Label("Export as CSV", systemImage: "tablecells")
                        }

                        Button(action: { exportJSON(recording) }) {
                            Label("Export as JSON", systemImage: "doc.text")
                        }

                        Button(action: { shareZip(recording) }) {
                            Label("Share zip", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive, action: {
                        recordingsManager.deleteRecording(withId: recording.id)
                        dismiss()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.accentBlue)
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameRecordingSheet(recording: recording) { newName in
                recordingsManager.renameRecording(withId: recording.id, newName: newName)
                // Reload to get updated name
                loadRecording()
            }
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: exportDocument?.contentType ?? UTType.data,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success(let url):
                print("File exported to: \(url)")
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .sheet(item: $shareZipItem) { item in
            ShareSheetView(url: item.url) {
                shareZipItem = nil
            }
        }
        .sheet(isPresented: $showRawDataSheet) {
            RawDataViewerSheet(recording: recording)
        }
        .sheet(isPresented: $showPythonInfoSheet) {
            PythonRecordingIdInfoSheet(
                recordingId: recording.id,
                baseURL: APIServer.shared.baseURLString()
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Recording ID Header

    private func recordingIdHeader(_ id: String) -> some View {
        Button(action: { showPythonInfoSheet = true }) {
            GlassCard {
                HStack(alignment: .center, spacing: AppTheme.spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recording ID")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.6))

                        Text(id)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        UIPasteboard.general.string = id
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.accentBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(AppTheme.spacing.md)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                    .stroke(AppTheme.primaryGradient.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - No Sensor Data View

    private var noSensorDataView: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.md) {
                Image(systemName: "sensor.tag.radiowaves.forward.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)

                Text("No Sensor Data")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("This recording has no sensor data.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppTheme.spacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Load Recording

    private func loadRecording() {
        loadState = .loading

        DispatchQueue.global(qos: .userInitiated).async {
            let result = RecordingsStorageManager.shared.loadRecording(withId: recordingId)

            DispatchQueue.main.async {
                switch result {
                case .success(let recording):
                    if let recording = recording {
                        loadState = .loaded(recording)
                    } else {
                        loadState = .notFound
                    }
                case .failure(let error):
                    if case RecordingStorageError.recordingNotFound = error {
                        loadState = .notFound
                    } else {
                        loadState = .error(error.localizedDescription)
                    }
                }
            }
        }
    }

    // MARK: - Summary Section

    private func summarySection(_ recording: RecordingSession) -> some View {
        VStack(spacing: AppTheme.spacing.md) {
            Text("Session Summary")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppTheme.spacing.md) {
                SummaryCard(
                    icon: "clock.fill",
                    title: "Duration",
                    value: recording.formattedDuration,
                    color: .blue
                )

                SummaryCard(
                    icon: "sensor.tag.radiowaves.forward.fill",
                    title: "Sensors",
                    value: "\(recording.sensorCount)",
                    color: .purple
                )

                SummaryCard(
                    icon: "heart.fill",
                    title: "Avg HR",
                    value: recording.averageHeartRate > 0 ? "\(Int(recording.averageHeartRate)) BPM" : "N/A",
                    color: .red
                )

                SummaryCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Data Points",
                    value: "\(recording.totalDataPoints)",
                    color: .green
                )

                if recording.averageSDNN > 0 {
                    SummaryCard(
                        icon: "waveform.path.ecg",
                        title: "Avg SDNN",
                        value: String(format: "%.1f ms", recording.averageSDNN),
                        color: .orange
                    )
                }

                if recording.averageRMSSD > 0 {
                    SummaryCard(
                        icon: "waveform",
                        title: "Avg RMSSD",
                        value: String(format: "%.1f ms", recording.averageRMSSD),
                        color: .cyan
                    )
                }
            }
        }
    }

    // MARK: - Sensor Section

    private func sensorSection(for sensor: SensorRecording) -> some View {
        let isExpanded = expandedSensors.contains(sensor.id)

        return VStack(spacing: AppTheme.spacing.md) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    if isExpanded {
                        expandedSensors.remove(sensor.id)
                    } else {
                        expandedSensors.insert(sensor.id)
                    }
                }
            }) {
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sensor.sensorName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("\(sensor.dataPointCount) data points")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppTheme.accentBlue)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(AppTheme.spacing.md)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: AppTheme.spacing.md) {
                    sensorStatistics(for: sensor)

                    if !sensor.heartRateData.isEmpty {
                        heartRateChart(for: sensor)
                    }

                    if !sensor.rrIntervalData.isEmpty {
                        rrIntervalChart(for: sensor)
                    }

                    if sensor.statistics.sdnn > 0 || sensor.statistics.rmssd > 0 {
                        hrvMetrics(for: sensor)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Sensor Statistics

    private func sensorStatistics(for sensor: SensorRecording) -> some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.sm) {
                Text("Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppTheme.spacing.sm) {
                    StatItem(label: "Min HR", value: "\(sensor.statistics.minHeartRate)", unit: "BPM")
                    StatItem(label: "Avg HR", value: "\(sensor.statistics.averageHeartRate)", unit: "BPM")
                    StatItem(label: "Max HR", value: "\(sensor.statistics.maxHeartRate)", unit: "BPM")
                }
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - Heart Rate Chart

    private func heartRateChart(for sensor: SensorRecording) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Heart Rate")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Chart {
                    ForEach(Array(sensor.heartRateData.enumerated()), id: \.offset) { _, dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("HR", dataPoint.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.minute().second())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - RR Interval Chart

    private func rrIntervalChart(for sensor: SensorRecording) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.purple)
                    Text("RR Intervals")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                Chart {
                    ForEach(Array(sensor.rrIntervalData.enumerated()), id: \.offset) { _, dataPoint in
                        LineMark(
                            x: .value("Time", dataPoint.timestamp),
                            y: .value("RR", dataPoint.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.minute().second())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - HRV Metrics

    private func hrvMetrics(for sensor: SensorRecording) -> some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.sm) {
                Text("HRV Metrics (\(sensor.statistics.hrvWindow))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: AppTheme.spacing.lg) {
                    if sensor.statistics.sdnn > 0 {
                        VStack(spacing: 4) {
                            Text("SDNN")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                            Text(sensor.statistics.formattedSDNN)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.accentBlue)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if sensor.statistics.rmssd > 0 {
                        VStack(spacing: 4) {
                            Text("RMSSD")
                                .font(.caption)
                                .foregroundColor(.primary.opacity(0.6))
                            Text(sensor.statistics.formattedRMSSD)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.accentBlue)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 4) {
                        Text("Samples")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.6))
                        Text("\(sensor.statistics.hrvSampleCount)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - Raw Data Button

    private func rawDataButton(_ recording: RecordingSession) -> some View {
        Button(action: {
            showRawDataSheet = true
        }) {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Raw Data")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Explore all \(recording.totalDataPoints) data points")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "tablecells")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentBlue)
                }
                .padding(AppTheme.spacing.lg)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Export Functions

    private func exportCSV(_ recording: RecordingSession) {
        guard let url = recordingsManager.exportCSV(recordingId: recording.id) else {
            exportErrorMessage = "Failed to create CSV export"
            showExportError = true
            return
        }

        do {
            exportDocument = try ExportDocument.zip(from: url)
            exportFilename = "\(recording.name.replacingOccurrences(of: " ", with: "_"))_CSV.zip"
        } catch {
            exportErrorMessage = "Failed to prepare CSV export: \(error.localizedDescription)"
            showExportError = true
        }
    }

    private func exportJSON(_ recording: RecordingSession) {
        guard let url = recordingsManager.exportJSON(recordingId: recording.id) else {
            exportErrorMessage = "Failed to create JSON export"
            showExportError = true
            return
        }

        do {
            exportDocument = try ExportDocument.json(from: url)
            exportFilename = "\(recording.name.replacingOccurrences(of: " ", with: "_")).json"
        } catch {
            exportErrorMessage = "Failed to prepare JSON export: \(error.localizedDescription)"
            showExportError = true
        }
    }

    /// Build CSV zip and present the system share sheet (Mail, AirDrop, etc.).
    private func shareZip(_ recording: RecordingSession) {
        guard let url = recordingsManager.exportCSV(recordingId: recording.id) else {
            exportErrorMessage = "Failed to create CSV export"
            showExportError = true
            return
        }
        shareZipItem = ShareZipItem(url: url)
    }
}

// MARK: - Python Recording ID Info Sheet

struct PythonRecordingIdInfoSheet: View {
    let recordingId: String
    /// When non-nil, show this as the device base URL (from APIServer) so the user can copy it.
    var baseURL: String? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private let codeBlockFont = Font.system(.caption, design: .monospaced)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing.lg) {
                    Text("Use this Recording ID in a Python script to fetch the full session data (HR, RR intervals, etc.) from the app.")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.9))

                    if let url = baseURL {
                        yourBaseURLSection(url)
                    }

                    requirementSection

                    codeExampleSection

                    baseUrlSection
                }
                .padding()
            }
            .background(AppTheme.adaptiveBackground(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Use in Python")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accentBlue)
                }
            }
        }
    }

    private func yourBaseURLSection(_ url: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
            Label("Your base URL", systemImage: "network")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Use this in Python as base_url (phone and computer must be on the same Wi‑Fi).")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))

            HStack(alignment: .top) {
                Text(url)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = url
                }) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.body)
                        .foregroundColor(AppTheme.accentBlue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppTheme.spacing.sm)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(AppTheme.cornerRadius.sm)
        }
        .padding(AppTheme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.glassMaterial)
        .cornerRadius(AppTheme.cornerRadius.md)
    }

    private var requirementSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
            Label("Requirements", systemImage: "checklist")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 4) {
                requirementRow("App is open and in the foreground")
                requirementRow("Phone and computer on the same Wi‑Fi")
                requirementRow("Python package: pip install requests pandas")
            }
            .font(.caption)
            .foregroundColor(.primary.opacity(0.8))
        }
        .padding(AppTheme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.glassMaterial)
        .cornerRadius(AppTheme.cornerRadius.md)
    }

    private func requirementRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundColor(AppTheme.accentBlue)
            Text(text)
        }
    }

    private var codeExampleSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
            Text("Example code")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Replace the base_url with your device IP (see above or in Settings).")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))

            VStack(alignment: .leading, spacing: 6) {
                codeLine("from urap_polar import get_recording, to_dataframes")
                codeLine("")
                codeLine("base_url = \"\(baseURL ?? "http://YOUR_DEVICE_IP:8080")\"  # from Settings or above")
                codeLine("recording_id = \"\(recordingId)\"")
                codeLine("")
                codeLine("session = get_recording(recording_id, base_url=base_url)")
                codeLine("dfs = to_dataframes(session)")
                codeLine("")
                codeLine("# Each sensor has 'heart_rate' and 'rr_intervals' DataFrames")
                codeLine("for sensor_id, data in dfs.items():")
                codeLine("    hr_df = data[\"heart_rate\"]")
                codeLine("    rr_df = data[\"rr_intervals\"]")
            }
            .padding(AppTheme.spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(AppTheme.cornerRadius.sm)
        }
    }

    private func codeLine(_ text: String) -> some View {
        Text(text)
            .font(codeBlockFont)
            .foregroundColor(.primary)
    }

    private var baseUrlSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
            Label("Where to find base URL", systemImage: "info.circle")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("In the app: Settings → API for Python shows your Device IP and Base URL. Use that as base_url in Python.")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.8))

            Text("You can also export a recording as a CSV zip (Export → Share zip) and process it offline with the Python scripts; see the Python client README.")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.7))
        }
        .padding(AppTheme.spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.glassMaterial)
        .cornerRadius(AppTheme.cornerRadius.md)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))

                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(AppTheme.spacing.md)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.6))
            HStack(spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RecordingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecordingDetailView(recordingId: "preview-1")
        }
        .preferredColorScheme(.dark)
    }
}
#endif

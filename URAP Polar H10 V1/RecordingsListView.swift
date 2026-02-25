//
//  RecordingsListView.swift
//  URAP Polar H10 V1
//
//  List view of all recording sessions with search and filter
//

import SwiftUI

struct RecordingsListView: View {
    @StateObject private var recordingsManager = RecordingsManager.shared
    @State private var searchText = ""
    @State private var showRenameSheet = false
    @State private var recordingToRename: RecordingSession?
    @Environment(\.colorScheme) var colorScheme

    var filteredRecordings: [RecordingSession] {
        recordingsManager.filteredRecordings(searchText: searchText)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                AppTheme.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()

                if filteredRecordings.isEmpty {
                    if searchText.isEmpty {
                        emptyState
                    } else {
                        noResultsView
                    }
                } else {
                    recordingsList
                }

                // Success/Error Toast
                VStack {
                    Spacer()
                    if let successMessage = recordingsManager.successMessage {
                        successToast(successMessage)
                    }
                    if let errorMessage = recordingsManager.errorMessage {
                        errorToast(errorMessage)
                    }
                }
                .padding(.bottom, 100)
                .padding(.horizontal)
            }
            .navigationTitle("Recordings")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recordings")
            .refreshable {
                recordingsManager.loadRecordings()
            }
            .sheet(isPresented: $showRenameSheet) {
                if let recording = recordingToRename {
                    RenameRecordingSheet(recording: recording) { newName in
                        recordingsManager.renameRecording(withId: recording.id, newName: newName)
                    }
                }
            }
            .overlay {
                if recordingsManager.isLoading {
                    LoadingOverlay()
                }
            }
        }
    }

    // MARK: - Recordings List

    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacing.md) {
                // Storage info header
                storageInfoHeader

                // Recording cards
                ForEach(filteredRecordings) { recording in
                    NavigationLink(destination: RecordingDetailView(recordingId: recording.id)) {
                        RecordingCard(recording: recording)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(action: {
                            recordingToRename = recording
                            showRenameSheet = true
                        }) {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive, action: {
                            recordingsManager.deleteRecording(withId: recording.id)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            recordingsManager.deleteRecording(withId: recording.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            recordingToRename = recording
                            showRenameSheet = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Storage Info Header

    private var storageInfoHeader: some View {
        let storageInfo = recordingsManager.getStorageInfo()

        return GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(storageInfo.recordingCount) Recording\(storageInfo.recordingCount == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(storageInfo.formattedSize)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.6))
                }

                Spacer()

                Image(systemName: "folder.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.primaryGradient)
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 70))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: AppTheme.spacing.sm) {
                GradientText("No Recordings Yet", font: .title2)

                Text("Start recording in the Dashboard\nto save your heart rate sessions")
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: AppTheme.spacing.lg) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primaryGradient.opacity(0.5))

            Text("No recordings found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.6))

            Spacer()
        }
    }

    // MARK: - Toast Messages

    private func successToast(_ message: String) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(AppTheme.spacing.md)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: recordingsManager.successMessage != nil)
    }

    private func errorToast(_ message: String) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(AppTheme.spacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: recordingsManager.errorMessage != nil)
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: RecordingSession

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(recording.formattedShortDate)
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.6))

                        Text("ID: \(recording.id)")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.5))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.3))
                }

                // Metrics row
                HStack(spacing: AppTheme.spacing.lg) {
                    MetricBadge(
                        icon: "clock.fill",
                        value: recording.formattedDuration,
                        label: "Duration",
                        color: .blue
                    )

                    MetricBadge(
                        icon: "sensor.tag.radiowaves.forward.fill",
                        value: "\(recording.sensorCount)",
                        label: recording.sensorCount == 1 ? "Sensor" : "Sensors",
                        color: .purple
                    )

                    if recording.averageHeartRate > 0 {
                        MetricBadge(
                            icon: "heart.fill",
                            value: "\(Int(recording.averageHeartRate))",
                            label: "Avg BPM",
                            color: .red
                        )
                    }
                }

                // HRV preview (if available)
                if recording.averageSDNN > 0 {
                    HStack(spacing: AppTheme.spacing.sm) {
                        Text("HRV:")
                            .font(.caption2)
                            .foregroundColor(.primary.opacity(0.5))

                        Text("SDNN \(String(format: "%.1f", recording.averageSDNN))ms")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.7))

                        if recording.averageRMSSD > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.primary.opacity(0.3))

                            Text("RMSSD \(String(format: "%.1f", recording.averageRMSSD))ms")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary.opacity(0.7))
                        }
                    }
                }
            }
            .padding(AppTheme.spacing.lg)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                .stroke(AppTheme.primaryGradient.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            GlassCard {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(AppTheme.accentBlue)
                        .scaleEffect(1.2)

                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.7))
                }
                .padding(32)
            }
        }
    }
}

// MARK: - Rename Recording Sheet

struct RenameRecordingSheet: View {
    let recording: RecordingSession
    let onRename: (String) -> Void

    @State private var newName: String
    @Environment(\.dismiss) var dismiss

    init(recording: RecordingSession, onRename: @escaping (String) -> Void) {
        self.recording = recording
        self.onRename = onRename
        _newName = State(initialValue: recording.name)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recording Name")) {
                    TextField("Name", text: $newName)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !newName.isEmpty {
                            onRename(newName)
                        }
                        dismiss()
                    }
                    .disabled(newName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

struct RecordingsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingsListView()
            .preferredColorScheme(.dark)
    }
}

//
//  RecordingsListView.swift
//  URAP Polar H10 V1
//
//  Modern recordings list with rich cards and smooth interactions
//

import SwiftUI

struct RecordingsListView: View {
    @StateObject private var recordingsManager = RecordingsManager.shared
    @State private var searchText = ""
    @State private var showRenameSheet = false
    @State private var recordingToRename: RecordingSession?
    @State private var listAppeared = false
    @Environment(\.colorScheme) var colorScheme

    var filteredRecordings: [RecordingSession] {
        recordingsManager.filteredRecordings(searchText: searchText)
    }

    var body: some View {
        ZStack {
            AppTheme.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            if colorScheme == .dark {
                RadialGradient(
                    colors: [AppTheme.neonPurple.opacity(0.04), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
            }

            if filteredRecordings.isEmpty {
                if searchText.isEmpty { emptyState } else { noResultsView }
            } else {
                recordingsList
            }

            // Toast
            VStack {
                Spacer()
                if let msg = recordingsManager.successMessage {
                    toastView(msg, color: AppTheme.neonGreen, icon: "checkmark.circle.fill")
                        .padding(.horizontal, AppTheme.spacing.lg)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let msg = recordingsManager.errorMessage {
                    toastView(msg, color: AppTheme.neonOrange, icon: "exclamationmark.triangle.fill")
                        .padding(.horizontal, AppTheme.spacing.lg)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recordingsManager.successMessage)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: recordingsManager.errorMessage)
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search recordings")
        .refreshable { recordingsManager.loadRecordings() }
        .sheet(isPresented: $showRenameSheet) {
            if let recording = recordingToRename {
                RenameRecordingSheet(recording: recording) { newName in
                    recordingsManager.renameRecording(withId: recording.id, newName: newName)
                }
            }
        }
        .overlay {
            if recordingsManager.isLoading { LoadingOverlay() }
        }
    }

    // MARK: - List

    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacing.md) {
                storageInfoHeader
                    .padding(.horizontal, AppTheme.spacing.md)

                ForEach(Array(filteredRecordings.enumerated()), id: \.element.id) { index, recording in
                    NavigationLink(destination: RecordingDetailView(recordingId: recording.id)) {
                        RecordingCard(recording: recording)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, AppTheme.spacing.md)
                    .opacity(listAppeared ? 1 : 0)
                    .offset(y: listAppeared ? 0 : 16)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06),
                        value: listAppeared
                    )
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
                        .tint(AppTheme.neonOrange)
                    }
                }
            }
            .padding(.vertical, AppTheme.spacing.md)
            .padding(.bottom, 80)
        }
        .onAppear {
            withAnimation { listAppeared = true }
        }
    }

    // MARK: - Storage Header

    private var storageInfoHeader: some View {
        let info = recordingsManager.getStorageInfo()
        return GlassCard {
            HStack(spacing: AppTheme.spacing.md) {
                NeonIconCircle(icon: "folder.fill", gradient: AppTheme.purpleGradient, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(info.recordingCount) Recording\(info.recordingCount == 1 ? "" : "s")")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text(info.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .padding(AppTheme.spacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            ZStack {
                ForEach([0, 1], id: \.self) { i in
                    Circle()
                        .stroke(AppTheme.neonPurple.opacity(0.06 - Double(i) * 0.02), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 50), height: CGFloat(120 + i * 50))
                }

                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [AppTheme.neonPurple.opacity(0.18), .clear],
                            center: .center, startRadius: 0, endRadius: 55
                        ))
                        .frame(width: 110, height: 110)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(AppTheme.purpleGradient)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            VStack(spacing: AppTheme.spacing.sm) {
                GradientText("No Recordings Yet", gradient: AppTheme.purpleGradient, font: .title2)
                Text("Start a recording in the Dashboard\nto save your heart rate sessions")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.bottom, 80)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: AppTheme.spacing.lg) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.3))

            VStack(spacing: AppTheme.spacing.xs) {
                Text("No recordings found")
                    .font(.headline)
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Toast

    private func toastView(_ message: String, color: Color, icon: String) -> some View {
        GlassCard(accentColor: color.opacity(0.4)) {
            HStack(spacing: AppTheme.spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 4)

                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(AppTheme.spacing.md)
        }
        .shadow(color: color.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: RecordingSession
    @Environment(\.colorScheme) var colorScheme

    private var accentColor: Color { AppTheme.neonBlue }

    var body: some View {
        GlassCard {
            HStack(spacing: 0) {
                // Left accent bar
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: AppTheme.cornerRadius.lg,
                            bottomLeadingRadius: AppTheme.cornerRadius.lg
                        )
                    )

                VStack(alignment: .leading, spacing: AppTheme.spacing.md) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recording.name)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(recording.formattedShortDate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text(recording.id)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primaryGradient.opacity(0.4))
                    }

                    // Metric row
                    HStack(spacing: AppTheme.spacing.sm) {
                        RecordingMetricPill(
                            icon: "clock.fill",
                            value: recording.formattedDuration,
                            color: AppTheme.neonBlue
                        )
                        RecordingMetricPill(
                            icon: "sensor.tag.radiowaves.forward.fill",
                            value: "\(recording.sensorCount) sensor\(recording.sensorCount == 1 ? "" : "s")",
                            color: AppTheme.neonPurple
                        )
                        if recording.averageHeartRate > 0 {
                            RecordingMetricPill(
                                icon: "heart.fill",
                                value: "\(Int(recording.averageHeartRate)) BPM",
                                color: AppTheme.neonRed
                            )
                        }
                    }

                    // HRV preview
                    if recording.averageSDNN > 0 {
                        HStack(spacing: 6) {
                            Text("HRV")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.neonPurple)
                                .tracking(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.neonPurple.opacity(0.12))
                                .clipShape(Capsule())

                            Text("SDNN \(String(format: "%.1f", recording.averageSDNN))ms")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            if recording.averageRMSSD > 0 {
                                Text("·")
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text("RMSSD \(String(format: "%.1f", recording.averageRMSSD))ms")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(AppTheme.spacing.md)
            }
        }
        .shadow(color: accentColor.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Recording Metric Pill

struct RecordingMetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - MetricBadge (kept for RecordingDetailView compatibility)

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
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            GlassCard {
                VStack(spacing: AppTheme.spacing.md) {
                    ProgressView()
                        .tint(AppTheme.neonBlue)
                        .scaleEffect(1.3)
                    Text("Loading…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(AppTheme.spacing.xl)
            }
        }
    }
}

// MARK: - Rename Sheet

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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !newName.isEmpty { onRename(newName) }
                        dismiss()
                    }
                    .disabled(newName.isEmpty)
                    .fontWeight(.semibold)
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

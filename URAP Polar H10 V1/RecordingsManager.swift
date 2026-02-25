//
//  RecordingsManager.swift
//  URAP Polar H10 V1
//
//  Business logic layer for managing recordings
//

import Foundation
import Combine
import SwiftUI

/// Manages recording sessions and coordinates with storage layer
class RecordingsManager: ObservableObject {
    static let shared = RecordingsManager()

    @Published private(set) var recordings: [RecordingSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let storage = RecordingsStorageManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadRecordings()

        // Auto-clear messages after 3 seconds
        $successMessage
            .compactMap { $0 }
            .delay(for: 3, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.successMessage = nil
            }
            .store(in: &cancellables)

        $errorMessage
            .compactMap { $0 }
            .delay(for: 3, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Recordings

    /// Load all recordings from storage
    func loadRecordings() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.storage.loadAllRecordingMetadata()

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let loadedRecordings):
                    self.recordings = RecordingSession.sortedByDate(loadedRecordings, ascending: false)
                    print("✅ Loaded \(loadedRecordings.count) recordings")

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to load recordings: \(error)")
                }
            }
        }
    }

    // MARK: - Rename Recording

    /// Rename a recording
    func renameRecording(withId id: String, newName: String) {
        guard let recording = recordings.first(where: { $0.id == id }) else {
            errorMessage = "Recording not found"
            return
        }

        var updatedRecording = recording
        updatedRecording.name = newName

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.storage.updateRecording(updatedRecording)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success:
                    // Re-fetch index on main thread just before updating to avoid race condition
                    if let index = self.recordings.firstIndex(where: { $0.id == id }) {
                        self.recordings[index] = updatedRecording
                        self.successMessage = "Recording renamed"
                        print("✅ Renamed recording to: \(newName)")
                    } else {
                        print("⚠️ Recording no longer in list: \(id)")
                        self.errorMessage = "Recording not found"
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to rename recording: \(error)")
                }
            }
        }
    }

    // MARK: - Delete Recording

    /// Delete a recording
    func deleteRecording(withId id: String) {
        // Capture recording name before async work
        guard let recording = recordings.first(where: { $0.id == id }) else {
            errorMessage = "Recording not found"
            return
        }

        let recordingName = recording.name
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.storage.deleteRecording(withId: id)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success:
                    // Re-fetch index on main thread just before deletion to avoid race condition
                    if let index = self.recordings.firstIndex(where: { $0.id == id }) {
                        self.recordings.remove(at: index)
                        self.successMessage = "Recording deleted"
                        print("✅ Deleted recording: \(recordingName)")
                    } else {
                        print("⚠️ Recording already removed from list: \(recordingName)")
                    }

                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("❌ Failed to delete recording: \(error)")
                }
            }
        }
    }

    /// Delete multiple recordings
    func deleteRecordings(withIds ids: Set<String>) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var deletedCount = 0
            for id in ids {
                if case .success = self.storage.deleteRecording(withId: id) {
                    deletedCount += 1
                }
            }

            DispatchQueue.main.async {
                self.isLoading = false
                self.recordings.removeAll { ids.contains($0.id) }
                self.successMessage = "Deleted \(deletedCount) recording(s)"
                print("✅ Deleted \(deletedCount) recordings")
            }
        }
    }

    // MARK: - Export Recording

    /// Export recording as JSON
    func exportJSON(recordingId: String) -> URL? {
        guard let recording = recordings.first(where: { $0.id == recordingId }) else {
            errorMessage = "Recording not found"
            return nil
        }

        switch storage.exportJSON(recording) {
        case .success(let url):
            print("✅ Exported JSON: \(url.path)")
            return url
        case .failure(let error):
            errorMessage = error.localizedDescription
            print("❌ Export failed: \(error)")
            return nil
        }
    }

    /// Export recording as CSV (zipped)
    func exportCSV(recordingId: String) -> URL? {
        guard let recording = recordings.first(where: { $0.id == recordingId }) else {
            errorMessage = "Recording not found"
            return nil
        }

        switch storage.exportCSV(recording) {
        case .success(let url):
            print("✅ Exported CSV: \(url.path)")
            return url
        case .failure(let error):
            errorMessage = error.localizedDescription
            print("❌ Export failed: \(error)")
            return nil
        }
    }

    // MARK: - Search & Filter

    /// Filter recordings by search text
    func filteredRecordings(searchText: String) -> [RecordingSession] {
        guard !searchText.isEmpty else { return recordings }
        return RecordingSession.filtered(recordings, searchText: searchText)
    }

    /// Filter recordings by date range
    func filteredRecordings(from startDate: Date?, to endDate: Date?) -> [RecordingSession] {
        var filtered = recordings

        if let startDate = startDate {
            filtered = filtered.filter { $0.startDate >= startDate }
        }

        if let endDate = endDate {
            filtered = filtered.filter { $0.startDate <= endDate }
        }

        return filtered
    }

    /// Filter recordings by sensor count
    func filteredRecordings(sensorCount: Int?) -> [RecordingSession] {
        guard let sensorCount = sensorCount else { return recordings }
        return recordings.filter { $0.sensorCount == sensorCount }
    }

    /// Filter recordings by minimum duration
    func filteredRecordings(minDuration: TimeInterval?) -> [RecordingSession] {
        guard let minDuration = minDuration else { return recordings }
        return recordings.filter { $0.duration >= minDuration }
    }

    // MARK: - Storage Info

    /// Get storage statistics
    func getStorageInfo() -> StorageInfo {
        storage.getStorageInfo()
    }

    /// Get specific recording with full data
    func getFullRecording(withId id: String) -> RecordingSession? {
        switch storage.loadRecording(withId: id) {
        case .success(let recording):
            return recording
        case .failure(let error):
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

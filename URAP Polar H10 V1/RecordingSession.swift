//
//  RecordingSession.swift
//  URAP Polar H10 V1
//
//  Complete recording session model with full data persistence
//

import Foundation

/// Represents a complete recording session with all sensor data
struct RecordingSession: Identifiable, Codable {
    let id: String
    var name: String
    let startDate: Date
    let endDate: Date
    let sensorRecordings: [SensorRecording]

    // Computed properties for convenience
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var sensorCount: Int {
        sensorRecordings.count
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: startDate)
    }

    // Global summary statistics across all sensors
    var averageHeartRate: Double {
        let total = sensorRecordings.reduce(0.0) { $0 + Double($1.statistics.averageHeartRate) }
        return sensorRecordings.isEmpty ? 0 : total / Double(sensorRecordings.count)
    }

    var totalDataPoints: Int {
        sensorRecordings.reduce(0) { $0 + $1.heartRateData.count + $1.rrIntervalData.count + $1.accelerometerData.count }
    }

    var totalAccelerometerSamples: Int {
        sensorRecordings.reduce(0) { $0 + $1.accelerometerData.count }
    }

    var averageSDNN: Double {
        let validSDNN = sensorRecordings.compactMap { $0.statistics.sdnn > 0 ? $0.statistics.sdnn : nil }
        return validSDNN.isEmpty ? 0 : validSDNN.reduce(0, +) / Double(validSDNN.count)
    }

    var averageRMSSD: Double {
        let validRMSSD = sensorRecordings.compactMap { $0.statistics.rmssd > 0 ? $0.statistics.rmssd : nil }
        return validRMSSD.isEmpty ? 0 : validRMSSD.reduce(0, +) / Double(validRMSSD.count)
    }

    // File naming
    var fileName: String {
        let timestamp = ISO8601DateFormatter().string(from: startDate)
        return "recording_\(id)_\(timestamp).json"
    }

    // Default name generator
    static func defaultName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return "Recording - \(formatter.string(from: date))"
    }

    // Initialize from live sensor data
    init(id: String = UUID().uuidString,
         name: String? = nil,
         startDate: Date,
         endDate: Date,
         sensorRecordings: [SensorRecording]) {
        self.id = id
        self.name = name ?? Self.defaultName(for: startDate)
        self.startDate = startDate
        self.endDate = endDate
        self.sensorRecordings = sensorRecordings
    }
}

// MARK: - Sorting and Filtering

extension RecordingSession {
    static func sortedByDate(_ recordings: [RecordingSession], ascending: Bool = false) -> [RecordingSession] {
        recordings.sorted { ascending ? $0.startDate < $1.startDate : $0.startDate > $1.startDate }
    }

    static func filtered(_ recordings: [RecordingSession], searchText: String) -> [RecordingSession] {
        guard !searchText.isEmpty else { return recordings }
        let lowercased = searchText.lowercased()
        return recordings.filter { recording in
            recording.name.lowercased().contains(lowercased) ||
            recording.sensorRecordings.contains { $0.sensorName.lowercased().contains(lowercased) }
        }
    }
}

// MARK: - Preview Data

#if DEBUG
extension RecordingSession {
    static var preview: RecordingSession {
        RecordingSession(
            id: "preview-1",
            name: "Morning Workout",
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date().addingTimeInterval(-3300),
            sensorRecordings: [SensorRecording.preview]
        )
    }

    static var previewMultiple: [RecordingSession] {
        [
            RecordingSession(
                id: "preview-1",
                name: "Morning Workout",
                startDate: Date().addingTimeInterval(-86400),
                endDate: Date().addingTimeInterval(-85800),
                sensorRecordings: [SensorRecording.preview]
            ),
            RecordingSession(
                id: "preview-2",
                name: "Evening Run",
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(-3300),
                sensorRecordings: [SensorRecording.preview, SensorRecording.preview]
            )
        ]
    }
}
#endif

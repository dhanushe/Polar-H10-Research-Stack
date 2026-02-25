//
//  RecordingState.swift
//  URAP Polar H10 V1
//
//  State machine for recording lifecycle
//

import Foundation

/// Represents the current state of the recording system
enum RecordingLifecycleState: Equatable {
    case idle
    case recording(startTime: Date)
    case paused(startTime: Date, pausedAt: Date)
    case saving
    case error(String)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .recording, .paused, .saving:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .saving:
            return "Saving..."
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "circle"
        case .recording:
            return "record.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .saving:
            return "arrow.down.circle"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    // Get start time if available
    var startTime: Date? {
        switch self {
        case .recording(let startTime):
            return startTime
        case .paused(let startTime, _):
            return startTime
        default:
            return nil
        }
    }

    // Calculate duration based on state
    func duration(at now: Date = Date()) -> TimeInterval {
        switch self {
        case .recording(let startTime):
            return now.timeIntervalSince(startTime)
        case .paused(let startTime, let pausedAt):
            return pausedAt.timeIntervalSince(startTime)
        default:
            return 0
        }
    }
}

/// Errors that can occur during recording
enum RecordingError: Error, LocalizedError {
    case noSensorsConnected
    case noDataCaptured
    case invalidStateTransition(from: String, to: String)
    case saveFailed(Error)
    case storageFull

    var errorDescription: String? {
        switch self {
        case .noSensorsConnected:
            return "No sensors connected to record from"
        case .noDataCaptured:
            return "No data was captured during recording"
        case .invalidStateTransition(let from, let to):
            return "Cannot transition from \(from) to \(to)"
        case .saveFailed(let error):
            return "Failed to save recording: \(error.localizedDescription)"
        case .storageFull:
            return "Device storage is full"
        }
    }
}

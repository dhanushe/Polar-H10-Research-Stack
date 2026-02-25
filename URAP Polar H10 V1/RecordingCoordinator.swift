//
//  RecordingCoordinator.swift
//  URAP Polar H10 V1
//
//  Main coordinator for recording sessions using thread-safe actors
//

import Foundation
import Combine

/// Coordinates recording sessions across multiple sensors
/// All UI-related properties are on the main actor for thread safety
@MainActor
class RecordingCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = RecordingCoordinator()

    // MARK: - Published Properties

    @Published private(set) var state: RecordingLifecycleState = .idle
    @Published private(set) var error: RecordingError?
    @Published private(set) var activeSensorCount: Int = 0

    // Live data for UI display (updated from sensor streams)
    @Published var liveHeartRates: [String: UInt8] = [:]
    @Published var liveRRIntervals: [String: UInt16] = [:]

    // MARK: - Private Properties

    private var collectors: [String: SensorDataCollector] = [:]
    private let storage = RecordingsStorageManager.shared
    private var currentRecordingId: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Recording Lifecycle

    /// Start recording for the given sensors
    func startRecording(sensors: [(id: String, name: String)], recordingId: String) {
        guard case .idle = state else {
            error = .invalidStateTransition(from: state.displayText, to: "Recording")
            return
        }

        guard !sensors.isEmpty else {
            error = .noSensorsConnected
            return
        }

        // Create collectors for each sensor
        collectors.removeAll()
        for sensor in sensors {
            collectors[sensor.id] = SensorDataCollector(
                sensorId: sensor.id,
                sensorName: sensor.name
            )
        }

        currentRecordingId = recordingId
        activeSensorCount = sensors.count
        state = .recording(startTime: Date())
        error = nil

        print("Started recording with \(sensors.count) sensor(s)")
    }

    /// Pause the current recording
    func pauseRecording() {
        guard case .recording(let startTime) = state else {
            error = .invalidStateTransition(from: state.displayText, to: "Paused")
            return
        }

        state = .paused(startTime: startTime, pausedAt: Date())
        print("Paused recording")
    }

    /// Resume a paused recording
    func resumeRecording() {
        guard case .paused(let startTime, _) = state else {
            error = .invalidStateTransition(from: state.displayText, to: "Recording")
            return
        }

        state = .recording(startTime: startTime)
        print("Resumed recording")
    }

    /// Stop recording and save the data
    func stopRecording() async {
        guard state.isActive else {
            return
        }

        state = .saving

        do {
            let session = try await captureAndSaveSession()
            print("Recording saved: \(session.name)")

            // Reset state
            clearCollectors()
            state = .idle
        } catch {
            if let recordingError = error as? RecordingError {
                self.error = recordingError
            } else {
                self.error = .saveFailed(error)
            }
            state = .error(error.localizedDescription)

            // Allow retry by transitioning back to idle after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state = .idle
        }
    }

    /// Cancel recording without saving
    func cancelRecording() {
        clearCollectors()
        state = .idle
        error = nil
        print("Recording cancelled")
    }

    // MARK: - Data Routing

    /// Route heart rate data from PolarManager to the appropriate collector
    func routeHeartRateData(sensorId: String, value: UInt8) async {
        // Update live display
        liveHeartRates[sensorId] = value

        // Only collect if actively recording
        guard case .recording = state else { return }

        guard let collector = collectors[sensorId] else { return }
        await collector.addHeartRateDataPoint(value)
    }

    /// Route RR interval data from PolarManager to the appropriate collector
    func routeRRIntervalData(sensorId: String, value: UInt16) async {
        // Update live display
        liveRRIntervals[sensorId] = value

        // Only collect if actively recording
        guard case .recording = state else { return }

        guard let collector = collectors[sensorId] else { return }
        await collector.addRRIntervalDataPoint(value)
    }

    // MARK: - Session Info

    /// Get current session duration
    var sessionDuration: TimeInterval {
        return state.duration()
    }

    /// Get formatted session duration
    var formattedDuration: String {
        let duration = sessionDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Private Methods

    private func captureAndSaveSession() async throws -> RecordingSession {
        var sensorRecordings: [SensorRecording] = []

        for (_, collector) in collectors {
            if let recording = await collector.captureRecording() {
                sensorRecordings.append(recording)
            }
        }

        guard !sensorRecordings.isEmpty else {
            throw RecordingError.noDataCaptured
        }

        // Determine session timing
        let startDates = sensorRecordings.compactMap { $0.timingMetadata.startWallTime }
        let endDates = sensorRecordings.compactMap { $0.timingMetadata.endWallTime }

        guard let startDate = startDates.min(),
              let endDate = endDates.max() else {
            throw RecordingError.noDataCaptured
        }

        let sessionId = currentRecordingId ?? UUID().uuidString

        let session = RecordingSession(
            id: sessionId,
            startDate: startDate,
            endDate: endDate,
            sensorRecordings: sensorRecordings
        )

        // Save to storage (on background thread)
        let result = await Task.detached {
            return self.storage.saveRecording(session)
        }.value

        switch result {
        case .success:
            // Notify RecordingsManager to reload
            await MainActor.run {
                RecordingsManager.shared.loadRecordings()
            }
            return session

        case .failure(let error):
            throw RecordingError.saveFailed(error)
        }
    }

    private func clearCollectors() {
        for (_, collector) in collectors {
            Task {
                await collector.reset()
            }
        }
        collectors.removeAll()
        liveHeartRates.removeAll()
        liveRRIntervals.removeAll()
        activeSensorCount = 0
        currentRecordingId = nil
    }

    // MARK: - Sensor Management

    /// Add a new sensor to an active recording
    func addSensor(id: String, name: String) {
        guard state.isActive else { return }

        if collectors[id] == nil {
            collectors[id] = SensorDataCollector(sensorId: id, sensorName: name)
            activeSensorCount = collectors.count
            print("Added sensor \(id) to recording")
        }
    }

    /// Remove a sensor from recording (sensor disconnected)
    func removeSensor(id: String) {
        collectors.removeValue(forKey: id)
        liveHeartRates.removeValue(forKey: id)
        liveRRIntervals.removeValue(forKey: id)
        activeSensorCount = collectors.count
        print("Removed sensor \(id) from recording")
    }
}

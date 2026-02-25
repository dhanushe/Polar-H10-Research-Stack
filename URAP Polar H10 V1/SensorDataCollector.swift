//
//  SensorDataCollector.swift
//  URAP Polar H10 V1
//
//  Thread-safe actor for collecting sensor data during recording
//

import Foundation
import QuartzCore

/// Actor that provides thread-safe data collection for a single sensor
actor SensorDataCollector {

    // MARK: - Properties

    let sensorId: String
    let sensorName: String

    private var timingSession: TimingSession

    // Data buffers
    private var hrBuffer: [HeartRateDataPoint] = []
    private var rrBuffer: [RRIntervalDataPoint] = []

    // Statistics tracking
    private var hrSum: UInt64 = 0
    private var hrCount: Int = 0
    private var minHR: UInt8 = UInt8.max
    private var maxHR: UInt8 = 0

    // HRV calculation buffer
    private let hrvWindow: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(sensorId: String, sensorName: String) {
        self.sensorId = sensorId
        self.sensorName = sensorName
        self.timingSession = TimingSession(sessionId: sensorId)
    }

    // MARK: - Data Collection

    /// Add a heart rate data point (thread-safe)
    func addHeartRateDataPoint(_ value: UInt8) {
        let now = timingSession.now()
        let wallTime = timingSession.monotonicToDate(now)

        let dataPoint = HeartRateDataPoint(
            timestamp: wallTime,
            monotonicTimestamp: now,
            value: value
        )

        hrBuffer.append(dataPoint)

        // Update statistics
        hrSum += UInt64(value)
        hrCount += 1

        if value < minHR {
            minHR = value
        }
        if value > maxHR {
            maxHR = value
        }
    }

    /// Add an RR interval data point (thread-safe)
    func addRRIntervalDataPoint(_ value: UInt16) {
        let now = timingSession.now()
        let wallTime = timingSession.monotonicToDate(now)

        let dataPoint = RRIntervalDataPoint(
            timestamp: wallTime,
            monotonicTimestamp: now,
            value: value
        )

        rrBuffer.append(dataPoint)
    }

    // MARK: - Data Capture

    /// Capture all collected data as a SensorRecording
    func captureRecording() -> SensorRecording? {
        guard !hrBuffer.isEmpty else {
            print("Cannot create SensorRecording: no heart rate data for sensor \(sensorId)")
            return nil
        }

        let statistics = SensorStatistics(
            minHeartRate: minHR == UInt8.max ? 0 : minHR,
            maxHeartRate: maxHR,
            averageHeartRate: hrCount > 0 ? UInt8(hrSum / UInt64(hrCount)) : 0,
            totalHeartRateSamples: hrCount,
            sdnn: calculateSDNN(),
            rmssd: calculateRMSSD(),
            hrvWindow: "5 Minutes",
            hrvSampleCount: rrBuffer.count
        )

        let timing = TimingMetadata(
            sessionId: sensorId,
            startWallTime: timingSession.startWallTime,
            startMonotonicTime: timingSession.startMonotonicTime,
            endWallTime: Date()
        )

        return SensorRecording(
            id: UUID().uuidString,
            sensorId: sensorId,
            sensorName: sensorName,
            heartRateData: hrBuffer,
            rrIntervalData: rrBuffer,
            statistics: statistics,
            timingMetadata: timing
        )
    }

    // MARK: - Statistics

    /// Get current data point counts
    var dataPointCounts: (hr: Int, rr: Int) {
        return (hrBuffer.count, rrBuffer.count)
    }

    /// Get current statistics
    var currentStatistics: (min: UInt8, max: UInt8, avg: UInt8) {
        let avg = hrCount > 0 ? UInt8(hrSum / UInt64(hrCount)) : 0
        let min = minHR == UInt8.max ? 0 : minHR
        return (min, maxHR, avg)
    }

    /// Get timing session info
    var sessionStartTime: Date {
        return timingSession.startWallTime
    }

    /// Get elapsed time
    var elapsedTime: TimeInterval {
        return timingSession.elapsedTime()
    }

    // MARK: - HRV Calculations

    private func calculateSDNN() -> Double {
        guard rrBuffer.count >= 5 else { return 0 }

        // Use recent data within HRV window
        let currentTime = timingSession.now()
        let cutoffTime = currentTime - hrvWindow
        let windowedRR = rrBuffer.filter { $0.monotonicTimestamp >= cutoffTime }

        guard windowedRR.count >= 5 else { return 0 }

        let values = windowedRR.map { Double($0.value) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)

        return sqrt(variance)
    }

    private func calculateRMSSD() -> Double {
        guard rrBuffer.count >= 2 else { return 0 }

        // Use recent data within HRV window
        let currentTime = timingSession.now()
        let cutoffTime = currentTime - hrvWindow
        let windowedRR = rrBuffer.filter { $0.monotonicTimestamp >= cutoffTime }

        guard windowedRR.count >= 2 else { return 0 }

        let values = windowedRR.map { Double($0.value) }
        var sumSquaredDiffs: Double = 0

        for i in 1..<values.count {
            let diff = values[i] - values[i-1]
            sumSquaredDiffs += diff * diff
        }

        return sqrt(sumSquaredDiffs / Double(values.count - 1))
    }

    // MARK: - Reset

    /// Reset all collected data
    func reset() {
        hrBuffer.removeAll()
        rrBuffer.removeAll()
        hrSum = 0
        hrCount = 0
        minHR = UInt8.max
        maxHR = 0
        timingSession = TimingSession(sessionId: sensorId)
    }
}

//
//  SensorRecording.swift
//  URAP Polar H10 V1
//
//  Per-sensor recording data with full time series and statistics
//

import Foundation
import QuartzCore

/// Represents all data collected from a single sensor during a recording session
struct SensorRecording: Identifiable, Codable {
    let id: String
    let sensorId: String
    let sensorName: String
    let heartRateData: [HeartRateDataPoint]
    let rrIntervalData: [RRIntervalDataPoint]
    let statistics: SensorStatistics
    let timingMetadata: TimingMetadata

    // Computed properties
    var dataPointCount: Int {
        heartRateData.count + rrIntervalData.count
    }

    var duration: TimeInterval {
        guard let first = heartRateData.first?.timestamp,
              let last = heartRateData.last?.timestamp else {
            return 0
        }
        return last.timeIntervalSince(first)
    }
}

// MARK: - Supporting Data Structures

/// Statistics captured during recording
struct SensorStatistics: Codable {
    let minHeartRate: UInt8
    let maxHeartRate: UInt8
    let averageHeartRate: UInt8
    let totalHeartRateSamples: Int
    let sdnn: Double
    let rmssd: Double
    let hrvWindow: String
    let hrvSampleCount: Int

    var formattedSDNN: String {
        sdnn > 0 ? String(format: "%.1f ms", sdnn) : "N/A"
    }

    var formattedRMSSD: String {
        rmssd > 0 ? String(format: "%.1f ms", rmssd) : "N/A"
    }
}

/// High-precision timing information
struct TimingMetadata: Codable {
    let sessionId: String
    let startWallTime: Date
    let startMonotonicTime: TimeInterval
    let endWallTime: Date

    var duration: TimeInterval {
        endWallTime.timeIntervalSince(startWallTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - CSV Export Helpers

extension SensorRecording {
    /// Generate CSV string for heart rate data
    func heartRateCSV() -> String {
        var csv = "Timestamp,Unix Time,Monotonic Time,Heart Rate (BPM)\n"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for dataPoint in heartRateData {
            let timestampStr = formatter.string(from: dataPoint.timestamp)
            let unixTime = dataPoint.timestamp.timeIntervalSince1970
            csv += "\(timestampStr),\(unixTime),\(dataPoint.monotonicTimestamp),\(dataPoint.value)\n"
        }
        return csv
    }

    /// Generate CSV string for RR interval data
    func rrIntervalCSV() -> String {
        var csv = "Timestamp,Unix Time,Monotonic Time,RR Interval (ms)\n"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for dataPoint in rrIntervalData {
            let timestampStr = formatter.string(from: dataPoint.timestamp)
            let unixTime = dataPoint.timestamp.timeIntervalSince1970
            csv += "\(timestampStr),\(unixTime),\(dataPoint.monotonicTimestamp),\(dataPoint.value)\n"
        }
        return csv
    }

    /// Generate summary CSV
    func statisticsCSV() -> String {
        var csv = "Metric,Value\n"
        csv += "Sensor ID,\(sensorId)\n"
        csv += "Sensor Name,\(sensorName)\n"
        csv += "Duration (seconds),\(String(format: "%.1f", duration))\n"
        csv += "Heart Rate Samples,\(heartRateData.count)\n"
        csv += "RR Interval Samples,\(rrIntervalData.count)\n"
        csv += "Min Heart Rate (BPM),\(statistics.minHeartRate)\n"
        csv += "Max Heart Rate (BPM),\(statistics.maxHeartRate)\n"
        csv += "Average Heart Rate (BPM),\(statistics.averageHeartRate)\n"
        csv += "SDNN (ms),\(String(format: "%.2f", statistics.sdnn))\n"
        csv += "RMSSD (ms),\(String(format: "%.2f", statistics.rmssd))\n"
        csv += "HRV Window,\(statistics.hrvWindow)\n"
        csv += "HRV Sample Count,\(statistics.hrvSampleCount)\n"
        return csv
    }
}

// MARK: - Preview Data

#if DEBUG
extension SensorRecording {
    static var preview: SensorRecording {
        let now = Date()
        let baseMonotonicTime = CACurrentMediaTime()

        var hrData: [HeartRateDataPoint] = []
        for i in 0..<60 {
            let point = HeartRateDataPoint(
                timestamp: now.addingTimeInterval(Double(i)),
                monotonicTimestamp: baseMonotonicTime + Double(i),
                value: UInt8(65 + i % 20)
            )
            hrData.append(point)
        }

        var rrData: [RRIntervalDataPoint] = []
        for i in 0..<60 {
            let point = RRIntervalDataPoint(
                timestamp: now.addingTimeInterval(Double(i)),
                monotonicTimestamp: baseMonotonicTime + Double(i),
                value: UInt16(800 + i % 200)
            )
            rrData.append(point)
        }

        return SensorRecording(
            id: "preview-sensor-1",
            sensorId: "ABCD1234",
            sensorName: "Polar H10 ABCD1234",
            heartRateData: hrData,
            rrIntervalData: rrData,
            statistics: SensorStatistics(
                minHeartRate: 65,
                maxHeartRate: 85,
                averageHeartRate: 75,
                totalHeartRateSamples: 60,
                sdnn: 45.2,
                rmssd: 38.7,
                hrvWindow: "5 Minutes",
                hrvSampleCount: 60
            ),
            timingMetadata: TimingMetadata(
                sessionId: "preview-session",
                startWallTime: now.addingTimeInterval(-300),
                startMonotonicTime: CACurrentMediaTime() - 300,
                endWallTime: now
            )
        )
    }
}
#endif

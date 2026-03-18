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
    let accelerometerData: [AccelerometerDataPoint]
    let statistics: SensorStatistics
    let timingMetadata: TimingMetadata

    // Support decoding old recordings that don't have accelerometer data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sensorId = try container.decode(String.self, forKey: .sensorId)
        sensorName = try container.decode(String.self, forKey: .sensorName)
        heartRateData = try container.decode([HeartRateDataPoint].self, forKey: .heartRateData)
        rrIntervalData = try container.decode([RRIntervalDataPoint].self, forKey: .rrIntervalData)
        accelerometerData = try container.decodeIfPresent([AccelerometerDataPoint].self, forKey: .accelerometerData) ?? []
        statistics = try container.decode(SensorStatistics.self, forKey: .statistics)
        timingMetadata = try container.decode(TimingMetadata.self, forKey: .timingMetadata)
    }

    init(id: String, sensorId: String, sensorName: String,
         heartRateData: [HeartRateDataPoint], rrIntervalData: [RRIntervalDataPoint],
         accelerometerData: [AccelerometerDataPoint] = [],
         statistics: SensorStatistics, timingMetadata: TimingMetadata) {
        self.id = id
        self.sensorId = sensorId
        self.sensorName = sensorName
        self.heartRateData = heartRateData
        self.rrIntervalData = rrIntervalData
        self.accelerometerData = accelerometerData
        self.statistics = statistics
        self.timingMetadata = timingMetadata
    }

    // Computed properties
    var dataPointCount: Int {
        heartRateData.count + rrIntervalData.count + accelerometerData.count
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

    /// Generate CSV string for accelerometer data
    func accelerometerCSV() -> String {
        var csv = "Timestamp,Unix Time,Monotonic Time,X (mG),Y (mG),Z (mG),Magnitude (mG)\n"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for dataPoint in accelerometerData {
            let timestampStr = formatter.string(from: dataPoint.timestamp)
            let unixTime = dataPoint.timestamp.timeIntervalSince1970
            csv += "\(timestampStr),\(unixTime),\(dataPoint.monotonicTimestamp),\(dataPoint.x),\(dataPoint.y),\(dataPoint.z),\(String(format: "%.1f", dataPoint.magnitude))\n"
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
        csv += "Accelerometer Samples,\(accelerometerData.count)\n"
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

        var accData: [AccelerometerDataPoint] = []
        for i in 0..<120 {
            let point = AccelerometerDataPoint(
                timestamp: now.addingTimeInterval(Double(i) * 0.02), // 50Hz
                monotonicTimestamp: baseMonotonicTime + Double(i) * 0.02,
                x: Int32(50 + i % 100), y: Int32(-980 + i % 50), z: Int32(20 + i % 80)
            )
            accData.append(point)
        }

        return SensorRecording(
            id: "preview-sensor-1",
            sensorId: "ABCD1234",
            sensorName: "Polar H10 ABCD1234",
            heartRateData: hrData,
            rrIntervalData: rrData,
            accelerometerData: accData,
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

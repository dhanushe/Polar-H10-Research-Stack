//
//  PrecisionTimer.swift
//  URAP Polar H10 V1
//
//  High-precision timing utility for research-grade timestamp accuracy
//  Uses CACurrentMediaTime() for microsecond-precision monotonic timestamps
//

import Foundation
import QuartzCore

/// High-precision timer for research-grade timing accuracy
/// Uses CACurrentMediaTime() which provides monotonic, microsecond-precision timestamps
class PrecisionTimer {

    // MARK: - Singleton
    static let shared = PrecisionTimer()

    // MARK: - Properties

    /// Epoch reference: The Date when the monotonic clock reference was established
    private(set) var epochWallTime: Date?

    /// Epoch reference: The monotonic time when the epoch was established
    private(set) var epochMonotonicTime: TimeInterval?

    // MARK: - Initialization

    private init() {}

    // MARK: - Core Timing Functions

    /// Returns the current monotonic time in seconds since device boot
    /// This time is precise to microseconds and never jumps backward
    /// - Returns: TimeInterval (seconds) with microsecond precision
    func now() -> TimeInterval {
        return CACurrentMediaTime()
    }

    /// Establishes a reference point correlating monotonic time with wall-clock time
    /// Call this at the start of a measurement session
    /// - Returns: A tuple of (wall-clock time, monotonic time) for the reference point
    @discardableResult
    func establishEpoch() -> (wallTime: Date, monotonicTime: TimeInterval) {
        // Capture both timestamps as close together as possible
        let monotonic = CACurrentMediaTime()
        let wall = Date()

        // Store as epoch reference
        epochMonotonicTime = monotonic
        epochWallTime = wall

        return (wall, monotonic)
    }

    // MARK: - Conversion Functions

    /// Converts a monotonic timestamp to a wall-clock Date
    /// Requires that establishEpoch() has been called previously
    /// - Parameter monotonicTime: The monotonic timestamp to convert
    /// - Returns: The corresponding Date, or nil if epoch not established
    func monotonicToDate(_ monotonicTime: TimeInterval) -> Date? {
        guard let epochWall = epochWallTime,
              let epochMonotonic = epochMonotonicTime else {
            return nil
        }

        // Calculate elapsed time since epoch
        let elapsedSinceEpoch = monotonicTime - epochMonotonic

        // Add elapsed time to epoch wall time
        return epochWall.addingTimeInterval(elapsedSinceEpoch)
    }

    /// Converts a Date to an estimated monotonic timestamp
    /// Requires that establishEpoch() has been called previously
    /// Note: This is an estimate and should not be used for precise measurements
    /// - Parameter date: The Date to convert
    /// - Returns: The estimated monotonic timestamp, or nil if epoch not established
    func dateToMonotonic(_ date: Date) -> TimeInterval? {
        guard let epochWall = epochWallTime,
              let epochMonotonic = epochMonotonicTime else {
            return nil
        }

        // Calculate elapsed time since epoch
        let elapsedSinceEpoch = date.timeIntervalSince(epochWall)

        // Add elapsed time to epoch monotonic time
        return epochMonotonic + elapsedSinceEpoch
    }

    // MARK: - Utility Functions

    /// Calculates the duration between two monotonic timestamps
    /// - Parameters:
    ///   - start: The starting monotonic timestamp
    ///   - end: The ending monotonic timestamp
    /// - Returns: Duration in seconds with microsecond precision
    func duration(from start: TimeInterval, to end: TimeInterval) -> TimeInterval {
        return end - start
    }

    /// Returns metadata about the timing system
    /// - Returns: Dictionary containing timing information
    func metadata() -> [String: Any] {
        var info: [String: Any] = [
            "timingMethod": "CACurrentMediaTime",
            "precision": "microsecond",
            "monotonic": true,
            "epoch": "device boot time"
        ]

        if let epochWall = epochWallTime,
           let epochMonotonic = epochMonotonicTime {
            info["sessionEpochWallTime"] = ISO8601DateFormatter().string(from: epochWall)
            info["sessionEpochMonotonicTime"] = epochMonotonic
        }

        return info
    }

    // MARK: - Session Management

    /// Resets the epoch references
    /// Call this when starting a new independent session
    func resetEpoch() {
        epochWallTime = nil
        epochMonotonicTime = nil
    }
}

// MARK: - Session-Specific Timer

/// Represents a timing session with its own epoch reference
/// Useful when tracking multiple independent sensors or sessions
class TimingSession: Codable {

    // MARK: - Properties

    let sessionId: String
    private(set) var startWallTime: Date
    private(set) var startMonotonicTime: TimeInterval

    // MARK: - Initialization

    init(sessionId: String) {
        self.sessionId = sessionId
        self.startMonotonicTime = PrecisionTimer.shared.now()
        self.startWallTime = Date()
    }

    // MARK: - Codable Support

    /// Initialize from persisted state (for restoration from background)
    init(sessionId: String, startWallTime: Date, startMonotonicTime: TimeInterval) {
        self.sessionId = sessionId
        self.startWallTime = startWallTime
        self.startMonotonicTime = startMonotonicTime
    }

    // MARK: - Timing Functions

    /// Returns the current monotonic time
    func now() -> TimeInterval {
        return PrecisionTimer.shared.now()
    }

    /// Returns the elapsed time since session start
    func elapsedTime() -> TimeInterval {
        return PrecisionTimer.shared.duration(from: startMonotonicTime, to: PrecisionTimer.shared.now())
    }

    /// Converts a monotonic timestamp to a Date relative to this session
    func monotonicToDate(_ monotonicTime: TimeInterval) -> Date {
        let elapsedSinceStart = monotonicTime - startMonotonicTime
        return startWallTime.addingTimeInterval(elapsedSinceStart)
    }

    /// Returns metadata for this session
    func metadata() -> [String: Any] {
        return [
            "sessionId": sessionId,
            "startWallTime": ISO8601DateFormatter().string(from: startWallTime),
            "startMonotonicTime": startMonotonicTime,
            "elapsedTime": elapsedTime(),
            "timingMethod": "CACurrentMediaTime",
            "precision": "microsecond"
        ]
    }
}

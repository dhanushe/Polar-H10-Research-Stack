//
//  AccelerometerProcessor.swift
//  URAP Polar H10 V1
//
//  On-device DSP pipeline for Polar H10 accelerometer data.
//  Applies per-axis HPF (0.25 Hz) + LPF (5 Hz), computes vector magnitude,
//  and averages over 1-second windows (25 samples at 25 Hz).
//
//  All types are value types (structs with mutating methods) so they are
//  owned and isolated by SensorDataCollector's actor context — no Sendable
//  or locking concerns.
//

import Foundation

// MARK: - 2nd-Order Direct-Form II Biquad IIR Filter

/// Stateful 2nd-order IIR filter using the direct-form II transposed structure.
/// Difference equation: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
struct BiquadFilter {

    private let b0, b1, b2: Double
    private let a1, a2: Double

    // State registers
    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }

    mutating func reset() {
        x1 = 0; x2 = 0
        y1 = 0; y2 = 0
    }
}

// MARK: - Per-Axis Filter Cascade (HPF → LPF)

/// Cascades a high-pass filter (0.25 Hz) followed by a low-pass filter (5 Hz)
/// for a single accelerometer axis at fs = 25 Hz.
///
/// HPF removes the gravity component (near-DC).
/// LPF removes high-frequency sensor noise above 5 Hz.
struct AxisFilter {

    // 2nd-order Butterworth HPF at 0.25 Hz, fs = 25 Hz
    // K = tan(π × 0.25 / 25) = 0.031427
    // denom = K² + K√2 + 1 = 1.045431
    private var hpf = BiquadFilter(
        b0:  0.956543,
        b1: -1.913086,
        b2:  0.956543,
        a1: -1.911174,
        a2:  0.914998
    )

    // 2nd-order Butterworth LPF at 5 Hz, fs = 25 Hz
    // K = tan(π × 5 / 25) = 0.726543
    // denom = K² + K√2 + 1 = 2.555211
    private var lpf = BiquadFilter(
        b0:  0.206572,
        b1:  0.413144,
        b2:  0.206572,
        a1: -0.369527,
        a2:  0.195815
    )

    /// Filter one raw sample (in milliG). Returns filtered value in milliG.
    mutating func process(_ x: Double) -> Double {
        lpf.process(hpf.process(x))
    }

    mutating func reset() {
        hpf.reset()
        lpf.reset()
    }
}

// MARK: - Accelerometer Processor

/// Processes raw Polar H10 accelerometer samples (milliG, 25 Hz) through the full pipeline:
///   1. HPF 0.25 Hz per axis (removes gravity)
///   2. LPF 5 Hz per axis (removes noise)
///   3. Vector magnitude: sqrt(x² + y² + z²)
///   4. 1-second average (25 samples → 1 output value)
///
/// The returned magnitude values are suitable for metabolic rate estimation via
/// activity count metrics (ENMO / HPFVM approaches from the literature).
struct AccelerometerProcessor {

    private var filterX = AxisFilter()
    private var filterY = AxisFilter()
    private var filterZ = AxisFilter()

    private var magnitudeAccumulator: Double = 0
    private var sampleCount: Int = 0

    private let windowSize: Int = 25  // 25 Hz × 1 second

    /// Process one raw sample. Returns the completed 1-second average magnitude (mG)
    /// when the window is full (every 25 samples); otherwise returns nil.
    mutating func processSample(x: Int32, y: Int32, z: Int32) -> Double? {
        let fx = filterX.process(Double(x))
        let fy = filterY.process(Double(y))
        let fz = filterZ.process(Double(z))

        let magnitude = sqrt(fx * fx + fy * fy + fz * fz)
        magnitudeAccumulator += magnitude
        sampleCount += 1

        if sampleCount == windowSize {
            let avg = magnitudeAccumulator / Double(windowSize)
            magnitudeAccumulator = 0
            sampleCount = 0
            return avg
        }
        return nil
    }

    mutating func reset() {
        filterX.reset()
        filterY.reset()
        filterZ.reset()
        magnitudeAccumulator = 0
        sampleCount = 0
    }
}

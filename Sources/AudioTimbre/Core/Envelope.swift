//
//  Envelope.swift
//  AudioTimbre
//
//  Created by David Sherlock on 2026.
//
//  How a sound moves over time: how fast it arrives, how long it takes to leave.
//
//  THE WINDOW AND THE HOP ARE DIFFERENT SIZES, and that is the whole design. A short
//  window gives fine timing but a useless reading on bass material — 10 ms is 0.4 of a
//  cycle at 40 Hz, so the "envelope" of a sub oscillates with the waveform itself. A long
//  window is stable and smears a 4 ms transient into nothing. So the window is 20 ms
//  (one full cycle at 50 Hz) and it advances 1 ms at a time, giving millisecond attack
//  resolution off a level reading that is actually steady.
//
//  The overlap costs nothing: a prefix sum of squares makes any window's energy a single
//  subtraction, so the whole envelope is one pass over the signal regardless of how far
//  the windows overlap.
//

import Foundation

/// Attack, decay and sustain measurement.
public enum Envelope {

    /// The RMS window, in seconds. One cycle of 50 Hz.
    public static let windowSeconds = 0.020

    /// How far the window advances between readings, in seconds.
    public static let hopSeconds = 0.001

    /// How far below the peak still counts as "sustaining", in dB.
    public static let sustainThresholdDb = -12.0

    /// How far below the peak counts as decayed, in dB. The usual T60 convention.
    public static let decayThresholdDb = -60.0

    /// The measured shape of one signal.
    public struct Shape: Hashable, Sendable {
        /// Milliseconds from the start of the signal to its loudest window.
        public let attackMs: Double
        /// Milliseconds from the loudest window until the level drops 60 dB, or `nil`
        /// when the signal ends while still above that.
        public let decayMs: Double?
        /// Fraction of windows within 12 dB of the peak, 0…1.
        public let sustainRatio: Double
    }

    /// Measure a signal's envelope.
    ///
    /// - Parameters:
    ///   - samples: mono samples.
    ///   - sampleRate: samples per second; must be positive.
    /// - Returns: a zeroed shape when the signal is too short to hold two windows.
    public static func measure(_ samples: [Float], sampleRate: Double) -> Shape {
        guard sampleRate > 0, !samples.isEmpty else {
            return Shape(attackMs: 0, decayMs: nil, sustainRatio: 0)
        }

        let window = max(1, min(samples.count, Int(windowSeconds * sampleRate)))
        let hop = max(1, Int(hopSeconds * sampleRate))
        let readings = (samples.count - window) / hop + 1
        guard readings >= 2 else {
            return Shape(attackMs: 0, decayMs: nil, sustainRatio: 0)
        }

        // Prefix sums of squares: energy over any span is one subtraction.
        var prefix = [Double](repeating: 0, count: samples.count + 1)
        for i in 0..<samples.count {
            let value = Double(samples[i])
            prefix[i + 1] = prefix[i] + value * value
        }

        var levels = [Double](repeating: 0, count: readings)
        for r in 0..<readings {
            let start = r * hop
            levels[r] = ((prefix[start + window] - prefix[start]) / Double(window)).squareRoot()
        }

        guard let peak = levels.max(), peak > 0 else {
            return Shape(attackMs: 0, decayMs: nil, sustainRatio: 0)
        }
        let peakIndex = levels.firstIndex(of: peak) ?? 0

        let hopMs = hopSeconds * 1000
        let attackMs = Double(peakIndex) * hopMs

        let decayFloor = peak * pow(10, decayThresholdDb / 20)
        var decayMs: Double?
        if peakIndex < readings {
            for r in peakIndex..<readings where levels[r] <= decayFloor {
                decayMs = Double(r - peakIndex) * hopMs
                break
            }
        }

        let sustainFloor = peak * pow(10, sustainThresholdDb / 20)
        let sustaining = levels.reduce(into: 0) { count, level in
            if level > sustainFloor { count += 1 }
        }
        let sustainRatio = Double(sustaining) / Double(readings)

        return Shape(attackMs: attackMs, decayMs: decayMs, sustainRatio: sustainRatio)
    }
}

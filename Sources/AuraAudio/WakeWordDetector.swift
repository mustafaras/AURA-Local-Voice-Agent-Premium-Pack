import AuraCore
import Foundation

/// Result of a wake-word hypothesis produced by a detector.
public struct WakeHypothesis: Sendable, Equatable {
    public let detected: Bool
    public let confidence: Double
    public let matchedPhrase: String

    public init(detected: Bool, confidence: Double, matchedPhrase: String = "") {
        self.detected = detected
        self.confidence = confidence
        self.matchedPhrase = matchedPhrase
    }
}

/// Abstract wake-word detector. Concrete implementations may range from
/// deterministic phrase matchers for tests to on-device neural models.
public protocol WakeWordDetector: Sendable {
    /// Analyze a frame (and optionally prior VAD state) and return a hypothesis.
    @Sendable func analyze(_ frame: AudioFrame, vadResult: VADResult?) -> WakeHypothesis

    /// Reset any detector-specific state.
    @Sendable func reset()
}

/// Test-only configurable wake-word detector that "detects" the phrase when a
/// synthetic marker tone is present in the frame. It produces deterministic
/// confidence values so tests can measure thresholds, debounce, and anti-trigger
/// behavior without a real acoustic model.
public actor MarkerWakeWordDetector: WakeWordDetector {
    public let phrase: String
    public let confidenceThreshold: Double
    public let energyThresholdDB: Double

    /// Marker frequency in Hz. Detection occurs when the dominant spectral bin
    /// is within this window and the signal energy is above the threshold.
    public let markerFrequency: Double
    public let markerWindowHz: Double

    public init(
        phrase: String = "hey aura",
        confidenceThreshold: Double = 0.75,
        energyThresholdDB: Double = -40.0,
        markerFrequency: Double = 1000.0,
        markerWindowHz: Double = 100.0
    ) {
        self.phrase = phrase
        self.confidenceThreshold = confidenceThreshold
        self.energyThresholdDB = energyThresholdDB
        self.markerFrequency = markerFrequency
        self.markerWindowHz = markerWindowHz
    }

    public nonisolated func analyze(_ frame: AudioFrame, vadResult: VADResult?) -> WakeHypothesis {
        let energy = vadResult?.energyDB ?? Self.energyDB(of: frame.samples)
        guard energy >= energyThresholdDB else {
            return WakeHypothesis(detected: false, confidence: 0.0, matchedPhrase: "")
        }

        let sampleRate = 16000.0
        let dominantFrequency = Self.estimateDominantFrequency(
            samples: frame.samples,
            sampleRate: sampleRate
        )

        let inWindow = abs(dominantFrequency - markerFrequency) <= markerWindowHz
        let baseConfidence = inWindow ? 0.95 : 0.15
        let loudnessBoost = min(0.04, max(0.0, (energy - energyThresholdDB) / 100.0))
        let confidence = min(1.0, baseConfidence + loudnessBoost)

        let detected = confidence >= confidenceThreshold
        return WakeHypothesis(
            detected: detected,
            confidence: confidence,
            matchedPhrase: detected ? phrase : ""
        )
    }

    public nonisolated func reset() {
        // Stateless aside from configuration.
    }

    private static func energyDB(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return -120.0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let mean = sum / Float(samples.count)
        guard mean > 0 else { return -120.0 }
        return 10.0 * log10(Double(mean))
    }

    /// Very coarse zero-crossing-based pitch estimate. Good enough for
    /// deterministic synthetic tests; do not use for real speech detection.
    private static func estimateDominantFrequency(samples: [Float], sampleRate: Double) -> Double {
        guard samples.count >= 2 else { return 0 }
        var crossings = 0
        for index in 1..<samples.count {
            if (samples[index - 1] < 0 && samples[index] >= 0) ||
                (samples[index - 1] > 0 && samples[index] <= 0) {
                crossings += 1
            }
        }
        let duration = Double(samples.count) / sampleRate
        guard duration > 0 else { return 0 }
        return Double(crossings) / (2.0 * duration)
    }
}

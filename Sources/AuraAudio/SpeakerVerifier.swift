import AuraCore
import Foundation

/// Identity hint produced by a speaker verifier. It is never an authorization
/// decision; downstream policy must independently decide whether the speaker
/// is allowed to act.
public struct SpeakerIdentityHint: Sendable, Equatable {
    public let profileID: String?
    public let score: Double

    public init(profileID: String?, score: Double) {
        self.profileID = profileID
        self.score = score
    }
}

/// Abstract speaker verifier. Implementations may use simple embeddings, neural
/// models, or platform APIs. They must treat output as an identity hint only.
public protocol SpeakerVerifier: Sendable {
    /// Enroll a short speech sample under a profile.
    @Sendable func enroll(profileID: String, samples: [AudioFrame]) async

    /// Return the best-matching enrolled profile and a similarity score in [0, 1].
    @Sendable func verify(_ frame: AudioFrame) async -> SpeakerIdentityHint

    /// Remove an enrolled profile.
    @Sendable func removeProfile(_ profileID: String) async

    /// Reset all state.
    @Sendable func reset() async
}

/// Deterministic test-only speaker verifier that matches frames containing a
/// known enrollment marker frequency. It proves the enrollment/recognition
/// plumbing without relying on a real biometric model or storing raw speech.
public actor MarkerSpeakerVerifier: SpeakerVerifier {
    /// Marker frequency window used to identify an enrolled voice.
    public let markerFrequency: Double
    public let markerWindowHz: Double
    public let matchThreshold: Double

    public init(
        markerFrequency: Double = 1500.0,
        markerWindowHz: Double = 100.0,
        matchThreshold: Double = 0.80
    ) {
        self.markerFrequency = markerFrequency
        self.markerWindowHz = markerWindowHz
        self.matchThreshold = matchThreshold
    }

    public func enroll(profileID: String, samples: [AudioFrame]) async {
        guard !samples.isEmpty else { return }
        var totalEnergy: Double = 0
        for frame in samples {
            totalEnergy += markerEnergy(of: frame.samples)
        }
        let average = totalEnergy / Double(samples.count)
        setProfile(profileID, energy: average)
    }

    public func verify(_ frame: AudioFrame) async -> SpeakerIdentityHint {
        let energy = markerEnergy(of: frame.samples)
        let profiles = allProfiles()
        guard !profiles.isEmpty, energy >= -80.0 else {
            return SpeakerIdentityHint(profileID: nil, score: 0.0)
        }

        var bestID: String?
        var bestScore: Double = 0
        for (profileID, enrolledEnergy) in profiles {
            let delta = abs(energy - enrolledEnergy)
            let score = max(0, 1.0 - (delta / 40.0))
            if score > bestScore {
                bestScore = score
                bestID = profileID
            }
        }

        return SpeakerIdentityHint(
            profileID: bestScore >= matchThreshold ? bestID : nil,
            score: bestScore
        )
    }

    public func removeProfile(_ profileID: String) async {
        removeProfileValue(profileID)
    }

    public func reset() async {
        clearProfiles()
    }

    private var profiles: [String: Double] = [:]

    private func setProfile(_ profileID: String, energy: Double) {
        profiles[profileID] = energy
    }

    private func allProfiles() -> [String: Double] {
        profiles
    }

    private func removeProfileValue(_ profileID: String) {
        profiles.removeValue(forKey: profileID)
    }

    private func clearProfiles() {
        profiles.removeAll()
    }

    /// Energy within the configured marker band, estimated crudely from
    /// zero-crossing rate and overall frame energy. Used only for deterministic
    /// tests.
    private func markerEnergy(of samples: [Float]) -> Double {
        let energy = Self.rmsEnergyDB(of: samples)
        let sampleRate = 16000.0
        let dominantFrequency = Self.estimateDominantFrequency(samples: samples, sampleRate: sampleRate)
        let inWindow = abs(dominantFrequency - markerFrequency) <= markerWindowHz
        return inWindow ? energy : energy - 30.0
    }

    private static func rmsEnergyDB(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return -120.0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let mean = sum / Float(samples.count)
        guard mean > 0 else { return -120.0 }
        return 10.0 * log10(Double(mean))
    }

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

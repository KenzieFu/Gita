import Foundation

struct TuningJudge {
    private var stableSince: TimeInterval?

    mutating func ingest(_ reading: PitchReading?, target: Double, at time: TimeInterval) -> Bool {
        guard let reading,
              reading.clarity >= 0.84,
              abs(PitchDetector.cents(reading.frequency, target: target)) <= 10 else {
            stableSince = nil
            return false
        }
        if stableSince == nil { stableSince = time }
        return time - (stableSince ?? time) >= 0.5
    }

    mutating func reset() {
        stableSince = nil
    }
}

import Foundation

enum TuningZone: Equatable {
    case waiting
    case flat
    case closeFlat
    case inTune
    case closeSharp
    case sharp

    static let inTuneCents = 10.0
    static let closeCents = 20.0

    static func classify(_ cents: Double?) -> TuningZone {
        guard let cents, cents.isFinite else { return .waiting }
        if abs(cents) <= inTuneCents { return .inTune }
        if abs(cents) <= closeCents { return cents < 0 ? .closeFlat : .closeSharp }
        return cents < 0 ? .flat : .sharp
    }
}

struct TuningJudge {
    private var stableSince: TimeInterval?

    mutating func ingest(_ reading: PitchReading?, target: Double, at time: TimeInterval) -> Bool {
        guard let reading,
              reading.clarity >= 0.84,
              TuningZone.classify(PitchDetector.cents(reading.frequency, target: target)) == .inTune else {
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

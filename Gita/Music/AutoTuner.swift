import Foundation

struct AutoTuningFeedback {
    let stringIndex: Int?
    let cents: Double?
    let newlyTunedIndex: Int?
}

struct AutoTuner {
    private var activeIndex: Int?
    private var judge = TuningJudge()

    mutating func ingest(_ reading: PitchReading?, targets: [StringTarget], at time: TimeInterval) -> AutoTuningFeedback {
        guard let reading, reading.clarity >= 0.84, reading.frequency.isFinite, reading.frequency > 0,
              let nearest = targets.enumerated()
                .map({ (index: $0.offset, cents: PitchDetector.cents(reading.frequency, target: $0.element.frequency)) })
                .min(by: { abs($0.cents) < abs($1.cents) }),
              abs(nearest.cents) <= 80 else {
            activeIndex = nil
            judge.reset()
            return AutoTuningFeedback(stringIndex: nil, cents: nil, newlyTunedIndex: nil)
        }

        if activeIndex != nearest.index {
            activeIndex = nearest.index
            judge.reset()
        }
        let tuned = judge.ingest(reading, target: targets[nearest.index].frequency, at: time)
        if tuned { judge.reset() }
        return AutoTuningFeedback(
            stringIndex: nearest.index,
            cents: nearest.cents,
            newlyTunedIndex: tuned ? nearest.index : nil
        )
    }
}

import Foundation

struct SongPlaybackTimeline {
    let sourceStart: Double
    let rate: Double

    init(sourceStart: Double, rate: Double) {
        precondition(sourceStart.isFinite && sourceStart >= 0 && rate.isFinite && rate > 0)
        self.sourceStart = sourceStart
        self.rate = rate
    }

    func elapsed(forSourceSeconds sourceSeconds: Double) -> Double {
        (sourceSeconds - sourceStart) / rate
    }

    func sourceSeconds(forElapsed elapsed: Double) -> Double {
        sourceStart + elapsed * rate
    }
}

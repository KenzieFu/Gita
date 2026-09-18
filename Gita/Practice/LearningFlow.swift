import Foundation

enum LearningStage: String, Codable {
    case hear
    case learn
    case play
}

struct LearningFlow {
    private(set) var stage: LearningStage
    private(set) var rate: Double

    init(stage: LearningStage = .hear, rate: Double = 0.7) {
        self.stage = stage
        self.rate = Self.clamp(rate)
    }

    mutating func advance() {
        switch stage {
        case .hear: stage = .learn
        case .learn: stage = .play
        case .play: break
        }
    }

    mutating func slower() {
        rate = Self.clamp(rate - 0.1)
    }

    mutating func acceptFasterSuggestion() {
        rate = Self.clamp(rate + 0.1)
    }

    func shouldSuggestFaster(score: Double?, confidence: Double) -> Bool {
        guard let score, score.isFinite, confidence.isFinite else { return false }
        return score >= 0.85 && confidence >= 0.9 && rate < 1
    }

    private static func clamp(_ value: Double) -> Double {
        let safe = value.isFinite ? value : 0.7
        return (min(1, max(0.5, safe)) * 10).rounded() / 10
    }
}

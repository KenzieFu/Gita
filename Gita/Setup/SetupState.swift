import Foundation

enum SetupRoute: String, Codable {
    case welcome
    case signIn
    case instrumentChoice
    case tuning
    case tutorial
    case ready

    var usesMicrophone: Bool { self == .tuning || self == .tutorial }
}

struct SetupProgress: Codable {
    var instrument: Instrument?
    var tutorialComplete: Bool
    var completedTuning: Set<Int>
    var ukuleleTuning: UkuleleTuning?
    var lessonStep: Int

    init(instrument: Instrument? = nil, tutorialComplete: Bool = false, completedTuning: Set<Int> = [], ukuleleTuning: UkuleleTuning? = nil, lessonStep: Int = 0) {
        self.instrument = instrument
        self.tutorialComplete = tutorialComplete
        self.completedTuning = completedTuning
        self.ukuleleTuning = ukuleleTuning
        self.lessonStep = lessonStep
    }

    private enum CodingKeys: String, CodingKey {
        case instrument
        case tutorialComplete
        case completedTuning
        case ukuleleTuning
        case lessonStep
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrument = try container.decodeIfPresent(Instrument.self, forKey: .instrument)
        tutorialComplete = try container.decodeIfPresent(Bool.self, forKey: .tutorialComplete) ?? false
        completedTuning = try container.decodeIfPresent(Set<Int>.self, forKey: .completedTuning) ?? []
        lessonStep = try container.decodeIfPresent(Int.self, forKey: .lessonStep) ?? 0
        if !container.contains(.ukuleleTuning), instrument == .ukulele {
            if tutorialComplete || completedTuning.count == 4 {
                ukuleleTuning = .highG
            } else {
                ukuleleTuning = nil
                completedTuning = []
            }
        } else {
            ukuleleTuning = try container.decodeIfPresent(UkuleleTuning.self, forKey: .ukuleleTuning)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrument, forKey: .instrument)
        try container.encode(tutorialComplete, forKey: .tutorialComplete)
        try container.encode(completedTuning, forKey: .completedTuning)
        try container.encode(lessonStep, forKey: .lessonStep)
        if let ukuleleTuning {
            try container.encode(ukuleleTuning, forKey: .ukuleleTuning)
        } else {
            try container.encodeNil(forKey: .ukuleleTuning)
        }
    }

    var destination: SetupRoute {
        guard let instrument else { return .instrumentChoice }
        if tutorialComplete { return .ready }
        if completedTuning.count < instrument.stringCount { return .tuning }
        if instrument == .ukulele && ukuleleTuning == nil { return .tuning }
        return .tutorial
    }

    mutating func choose(_ newInstrument: Instrument) {
        instrument = newInstrument
        tutorialComplete = false
        completedTuning = []
        ukuleleTuning = nil
        lessonStep = 0
    }

    mutating func resetTuning() {
        completedTuning = []
        ukuleleTuning = nil
    }
}

enum SetupPolicy {
    static func route(userID: String?, progress: SetupProgress, started: Bool) -> SetupRoute {
        route(guestMode: false, userID: userID, progress: progress, started: started)
    }

    static func route(guestMode: Bool, userID: String?, progress: SetupProgress, started: Bool) -> SetupRoute {
        guard guestMode || userID != nil else { return started ? .signIn : .welcome }
        return progress.destination
    }
}

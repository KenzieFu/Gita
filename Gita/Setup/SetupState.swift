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
    var lessonStep: Int

    init(instrument: Instrument? = nil, tutorialComplete: Bool = false, completedTuning: Set<Int> = [], lessonStep: Int = 0) {
        self.instrument = instrument
        self.tutorialComplete = tutorialComplete
        self.completedTuning = completedTuning
        self.lessonStep = lessonStep
    }

    var destination: SetupRoute {
        guard let instrument else { return .instrumentChoice }
        if tutorialComplete { return .ready }
        if completedTuning.count < instrument.openStrings.count { return .tuning }
        return .tutorial
    }

    mutating func choose(_ newInstrument: Instrument) {
        instrument = newInstrument
        tutorialComplete = false
        completedTuning = []
        lessonStep = 0
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

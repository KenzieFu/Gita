import Foundation

struct StringTarget: Hashable, Codable {
    let label: String
    let frequency: Double

    var noteLabel: String { "\(label)\(Int((69 + 12 * log2(frequency / 440)).rounded()) / 12 - 1)" }
}

enum LessonKind: String, Codable {
    case openString
    case fret
    case chord
}

struct LessonTarget: Codable {
    let kind: LessonKind
    let title: String
    let instruction: String
    let stringLabel: String
    let fret: Int?
    let frequencies: [Double]
}

enum Instrument: String, Codable, CaseIterable, Identifiable {
    case ukulele
    case guitar

    var id: String { rawValue }
    var displayName: String { self == .ukulele ? "Ukulele" : "Guitar" }
    var subtitle: String { self == .ukulele ? "4 strings · high-G tuning" : "6 strings · standard tuning" }

    var stringCount: Int { self == .ukulele ? 4 : 6 }

    func tuningTargets(_ tuning: UkuleleTuning?) -> [StringTarget] {
        self == .ukulele ? (tuning?.openStrings ?? []) : openStrings
    }

    func lessonTargets(_ tuning: UkuleleTuning?) -> [LessonTarget] {
        self == .ukulele ? (tuning?.lessons ?? []) : lesson
    }

    var openStrings: [StringTarget] {
        switch self {
        case .ukulele:
            return [
                StringTarget(label: "G", frequency: 392.00),
                StringTarget(label: "C", frequency: 261.63),
                StringTarget(label: "E", frequency: 329.63),
                StringTarget(label: "A", frequency: 440.00)
            ]
        case .guitar:
            return [
                StringTarget(label: "E", frequency: 82.4069),
                StringTarget(label: "A", frequency: 110.00),
                StringTarget(label: "D", frequency: 146.83),
                StringTarget(label: "G", frequency: 196.00),
                StringTarget(label: "B", frequency: 246.94),
                StringTarget(label: "E", frequency: 329.63)
            ]
        }
    }

    var lesson: [LessonTarget] {
        switch self {
        case .ukulele:
            return [
                LessonTarget(kind: .openString, title: "Find the A string", instruction: "Pluck the open A string once.", stringLabel: "A", fret: 0, frequencies: [440]),
                LessonTarget(kind: .fret, title: "Press fret 3", instruction: "Press fret 3 on the A string and pluck.", stringLabel: "A", fret: 3, frequencies: [523.25]),
                LessonTarget(kind: .chord, title: "Play a C chord", instruction: "Press A-string fret 3, then strum all four strings on the beat.", stringLabel: "G C E A", fret: nil, frequencies: [261.63, 329.63, 392.00, 523.25])
            ]
        case .guitar:
            return [
                LessonTarget(kind: .openString, title: "Find the high E", instruction: "Pluck the thinnest, high E string once.", stringLabel: "e", fret: 0, frequencies: [329.63]),
                LessonTarget(kind: .fret, title: "Press fret 1", instruction: "Press fret 1 on the high E string and pluck.", stringLabel: "e", fret: 1, frequencies: [349.23]),
                LessonTarget(kind: .chord, title: "Play an E minor chord", instruction: "Press A-string fret 2 and D-string fret 2, then strum all six strings on the beat.", stringLabel: "E A D G B e", fret: nil, frequencies: [82.4069, 123.47, 164.81, 196, 246.94, 329.63])
            ]
        }
    }
}

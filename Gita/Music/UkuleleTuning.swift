import Foundation

enum UkuleleTuning: String, Codable, CaseIterable {
    case highG
    case lowG
    case baritone

    var displayName: String {
        switch self {
        case .highG: "High G · G C E A"
        case .lowG: "Low G · G C E A"
        case .baritone: "Baritone · D G B E"
        }
    }

    var openStrings: [StringTarget] {
        let pitches: [(String, Double)] = switch self {
        case .highG: [("G", 392), ("C", 261.63), ("E", 329.63), ("A", 440)]
        case .lowG: [("G", 196), ("C", 261.63), ("E", 329.63), ("A", 440)]
        case .baritone: [("D", 146.83), ("G", 196), ("B", 246.94), ("E", 329.63)]
        }
        return pitches.map { StringTarget(label: $0.0, frequency: $0.1) }
    }

    var lessons: [LessonTarget] {
        if self == .baritone {
            return [
                LessonTarget(kind: .openString, title: "Find the E string", instruction: "Pluck the open E string once.", stringLabel: "E", fret: 0, frequencies: [329.63]),
                LessonTarget(kind: .fret, title: "Press fret 3", instruction: "Press fret 3 on the E string and pluck.", stringLabel: "E", fret: 3, frequencies: [392]),
                LessonTarget(kind: .chord, title: "Play a G chord", instruction: "Press E-string fret 3, then strum all four strings on the beat.", stringLabel: "D G B E", fret: nil, frequencies: [146.83, 196, 246.94, 392])
            ]
        }
        return [
            LessonTarget(kind: .openString, title: "Find the A string", instruction: "Pluck the open A string once.", stringLabel: "A", fret: 0, frequencies: [440]),
            LessonTarget(kind: .fret, title: "Press fret 3", instruction: "Press fret 3 on the A string and pluck.", stringLabel: "A", fret: 3, frequencies: [523.25]),
            LessonTarget(kind: .chord, title: "Play a C chord", instruction: "Press A-string fret 3, then strum all four strings on the beat.", stringLabel: "G C E A", fret: nil, frequencies: [261.63, 329.63, openStrings[0].frequency, 523.25])
        ]
    }
}

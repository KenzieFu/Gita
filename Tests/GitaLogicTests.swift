import Foundation

@main
struct GitaLogicTests {
    static func main() {
        precondition(Instrument.ukulele.openStrings.map(\.label) == ["G", "C", "E", "A"], "Ukulele order must match the screen")
        precondition(abs(Instrument.guitar.openStrings[0].frequency - 82.4069) < 0.02, "Low E must be E2")
        precondition(Instrument.ukulele.lesson.count == 3, "Ukulele has three guided exercises")
        precondition(Instrument.guitar.lesson.count == 3, "Guitar has three guided exercises")
        precondition(SetupProgress(instrument: nil, tutorialComplete: false).destination == .instrumentChoice)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: false).destination == .tuning)
        precondition(SetupProgress(instrument: .ukulele, tutorialComplete: true).destination == .ready)
        print("Gita logic tests passed")
    }
}

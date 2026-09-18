import Foundation

struct FretPosition: Equatable {
    let stringIndex: Int
    let fret: Int
}

struct FretFinderGame {
    let stringCount: Int
    let maxFret: Int
    private(set) var correctCount = 0

    init(stringCount: Int, maxFret: Int) {
        precondition(stringCount > 0 && maxFret > 0)
        self.stringCount = stringCount
        self.maxFret = maxFret
    }

    var target: FretPosition {
        FretPosition(stringIndex: correctCount % stringCount, fret: (correctCount / stringCount + correctCount % stringCount) % (maxFret + 1))
    }

    @discardableResult mutating func select(stringIndex: Int, fret: Int) -> Bool {
        guard (0..<stringCount).contains(stringIndex), (0...maxFret).contains(fret),
              FretPosition(stringIndex: stringIndex, fret: fret) == target else { return false }
        correctCount += 1
        return true
    }
}

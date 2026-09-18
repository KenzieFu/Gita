import Foundation

struct SongPreviewInfo {
    let title: String
    let difficulty: SongDifficulty
    let playTypes: [String]
    let chordNames: [String]

    init(chart: SongChart) {
        title = chart.title
        difficulty = chart.difficulty
        playTypes = chart.style == .singleNote ? ["Single notes"] : ["Basic chords"]
        chordNames = chart.chordNames
    }

    static func starter(for instrument: Instrument) -> SongPreviewInfo {
        SongPreviewInfo(
            title: "First Light",
            difficulty: .easy,
            playTypes: ["Single notes", "Basic chord"],
            chordNames: instrument == .ukulele ? ["C"] : ["Em"]
        )
    }

    private init(title: String, difficulty: SongDifficulty, playTypes: [String], chordNames: [String]) {
        self.title = title
        self.difficulty = difficulty
        self.playTypes = playTypes
        self.chordNames = chordNames
    }
}

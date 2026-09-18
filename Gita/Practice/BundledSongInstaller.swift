import Foundation

enum BundledSongInstaller {
    static func install(chartData: Data, audioURL: URL, into library: LocalSongLibrary) throws -> SongChart {
        let chart = try SongChart.decodeValidated(chartData)
        if let existing = try? library.load(chartID: chart.id, version: chart.version) {
            return existing.0
        }
        do {
            return try library.importChart(data: chartData, audio: audioURL)
        } catch LocalSongLibraryError.alreadyExists {
            return try library.load(chartID: chart.id, version: chart.version).0
        }
    }
}

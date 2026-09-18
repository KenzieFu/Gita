import Foundation
import CryptoKit

enum LocalSongLibraryError: Error {
    case audioMismatch
    case alreadyExists
    case notFound
}

struct LocalSongLibrary {
    let root: URL

    func importChart(data: Data, audio: URL) throws -> SongChart {
        let chart = try SongChart.decodeValidated(data)
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        guard validID(chart.id), chart.version > 0 else { throw LocalSongLibraryError.notFound }
        let destination = directory(for: chart.id, version: chart.version)

        let staging = root.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }

        let extensionName = audio.pathExtension.lowercased()
        let copiedAudio = staging.appendingPathComponent("audio.\(extensionName.isEmpty ? "bin" : extensionName)")
        try manager.copyItem(at: audio, to: copiedAudio)
        let copiedData = try Data(contentsOf: copiedAudio)
        let digest = SHA256.hash(data: copiedData).map { String(format: "%02x", $0) }.joined()
        guard digest == chart.audioSHA256 else { throw LocalSongLibraryError.audioMismatch }
        try data.write(to: staging.appendingPathComponent("chart.json"), options: .atomic)

        let chartRoot = root.appendingPathComponent(chart.id, isDirectory: true)
        try manager.createDirectory(at: chartRoot, withIntermediateDirectories: true)
        if manager.fileExists(atPath: destination.path) {
            let backup = root.appendingPathComponent(".backup-\(UUID().uuidString)", isDirectory: true)
            try manager.moveItem(at: destination, to: backup)
            do {
                try manager.moveItem(at: staging, to: destination)
                try? manager.removeItem(at: backup)
            } catch {
                if manager.fileExists(atPath: destination.path) { try? manager.removeItem(at: destination) }
                try? manager.moveItem(at: backup, to: destination)
                throw error
            }
        } else {
            try manager.moveItem(at: staging, to: destination)
        }
        return chart
    }

    func load(chartID: String, version: Int) throws -> (SongChart, URL) {
        guard validID(chartID), version > 0 else { throw LocalSongLibraryError.notFound }
        let directory = directory(for: chartID, version: version)
        let chart = try SongChart.decodeValidated(Data(contentsOf: directory.appendingPathComponent("chart.json")))
        guard chart.id == chartID && chart.version == version else { throw LocalSongLibraryError.notFound }
        let audioFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        guard let audio = audioFiles.first(where: { $0.lastPathComponent.hasPrefix("audio.") }) else { throw LocalSongLibraryError.notFound }
        return (chart, audio)
    }

    func list() throws -> [SongChart] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let chartDirectories = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        return chartDirectories.flatMap { chartDirectory -> [SongChart] in
            guard !chartDirectory.lastPathComponent.hasPrefix(".staging-") && !chartDirectory.lastPathComponent.hasPrefix(".backup-") else { return [] }
            let versions = (try? FileManager.default.contentsOfDirectory(at: chartDirectory, includingPropertiesForKeys: nil)) ?? []
            return versions.compactMap { versionDirectory in
                try? SongChart.decodeValidated(Data(contentsOf: versionDirectory.appendingPathComponent("chart.json")))
            }
        }.sorted { ($0.title, $0.version) < ($1.title, $1.version) }
    }

    func delete(chartID: String, version: Int) throws {
        guard validID(chartID), version > 0 else { throw LocalSongLibraryError.notFound }
        let target = directory(for: chartID, version: version)
        guard FileManager.default.fileExists(atPath: target.path) else { throw LocalSongLibraryError.notFound }
        try FileManager.default.removeItem(at: target)
    }

    private func directory(for chartID: String, version: Int) -> URL {
        root.appendingPathComponent(chartID, isDirectory: true).appendingPathComponent(String(version), isDirectory: true)
    }

    private func validID(_ id: String) -> Bool {
        !id.isEmpty && id != "." && id != ".." && !id.contains("/") && !id.contains("\\")
    }
}

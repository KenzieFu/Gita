import Foundation

struct PlayerProgressStore {
    let root: URL

    func load(now: Date = Date(), timeZone: TimeZone = .current) -> PlayerProgressSnapshot {
        let file = root.appendingPathComponent("player-progress.json")
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode(PlayerProgressSnapshot.self, from: data) {
            var engine = PlayerProgressEngine(snapshot: decoded)
            engine.rollDailyPlanIfNeeded(at: now, timeZone: timeZone)
            return engine.snapshot
        }
        let profile = PlayerProfile()
        return PlayerProgressSnapshot(
            profile: profile,
            dailyPlan: DailyPlanEngine.makePlan(at: now, timeZone: timeZone, profile: profile),
            transactions: []
        )
    }

    func save(_ snapshot: PlayerProgressSnapshot) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: root.appendingPathComponent("player-progress.json"), options: .atomic)
    }
}

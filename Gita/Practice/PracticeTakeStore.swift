import CryptoKit
import Foundation

struct ChallengeEntry: Codable, Identifiable {
    var id: UUID { take.id }
    let day: Int
    let songTitle: String
    let take: PracticeTake
}

struct PracticeTakeStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(for userID: String?) -> [ChallengeEntry] {
        guard let data = defaults.data(forKey: key(for: userID)),
              let entries = try? JSONDecoder().decode([ChallengeEntry].self, from: data) else { return [] }
        return entries.sorted { left, right in
            left.day == right.day ? left.take.playedAt < right.take.playedAt : left.day < right.day
        }
    }

    @discardableResult func save(_ entry: ChallengeEntry, for userID: String?) -> Bool {
        guard (1...100).contains(entry.day), !entry.songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var entries = load(for: userID)
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        guard let data = try? JSONEncoder().encode(entries) else { return false }
        defaults.set(data, forKey: key(for: userID))
        return true
    }

    private func key(for userID: String?) -> String {
        guard let userID else { return "gita.challenge.guest" }
        let digest = SHA256.hash(data: Data(userID.utf8))
        return "gita.challenge.\(digest.compactMap { String(format: "%02x", $0) }.joined())"
    }
}

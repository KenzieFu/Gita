import CryptoKit
import Foundation

struct ProgressStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(for userID: String) -> SetupProgress {
        guard let data = defaults.data(forKey: key(for: userID)),
              let progress = try? JSONDecoder().decode(SetupProgress.self, from: data) else {
            return SetupProgress()
        }
        return progress
    }

    func save(_ progress: SetupProgress, for userID: String) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: key(for: userID))
    }

    private func key(for userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        return "gita.progress.\(digest.compactMap { String(format: "%02x", $0) }.joined())"
    }
}

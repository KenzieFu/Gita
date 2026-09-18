import Combine
import Foundation

@MainActor
final class PlayerProgressModel: ObservableObject {
    @Published private(set) var snapshot: PlayerProgressSnapshot
    @Published var message: String?

    private let store: PlayerProgressStore

    init(store: PlayerProgressStore) {
        self.store = store
        self.snapshot = store.load()
    }

    func reload() {
        snapshot = store.load()
    }

    func complete(_ task: DailyTask) {
        var engine = PlayerProgressEngine(snapshot: snapshot)
        do {
            let rewards = try engine.completeTask(id: task.id, at: Date(), timeZone: .current)
            snapshot = engine.snapshot
            try store.save(snapshot)
            message = rewards.isEmpty ? "Already completed today." : rewards.map { "+\($0.xp) XP · +\($0.gems) gems" }.joined(separator: "\n")
        } catch {
            message = "This task could not be completed."
        }
    }

    func purchase(_ item: CosmeticItem) {
        var engine = PlayerProgressEngine(snapshot: snapshot)
        do {
            let transaction = try engine.purchase(item, at: Date())
            snapshot = engine.snapshot
            try store.save(snapshot)
            message = transaction == nil ? "Already in your Backpack." : "\(item.name) added to your Backpack."
        } catch ProgressRewardError.insufficientGems {
            message = "You need more gems for \(item.name)."
        } catch ProgressRewardError.lockedItem {
            message = "Reach level \(item.requiredLevel) to unlock this item."
        } catch {
            message = "The purchase could not be saved."
        }
    }

    func equip(_ item: CosmeticItem) {
        var engine = PlayerProgressEngine(snapshot: snapshot)
        engine.equip(item)
        snapshot = engine.snapshot
        try? store.save(snapshot)
        message = "\(item.name) equipped."
    }
}

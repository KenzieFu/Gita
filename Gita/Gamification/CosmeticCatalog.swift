import Foundation

enum CosmeticCategory: String, Codable, CaseIterable {
    case mascot
    case accessory
    case keychain
    case sticker
    case frame

    var title: String {
        switch self {
        case .mascot: "Mascots"
        case .accessory: "Accessories"
        case .keychain: "Keychains"
        case .sticker: "Stickers"
        case .frame: "Frames"
        }
    }
}

struct CosmeticItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: CosmeticCategory
    let symbol: String
    let price: Int
    let requiredLevel: Int
}

enum CosmeticCatalog {
    static let items = [
        CosmeticItem(id: "mascot-gita", name: "Gita", category: .mascot, symbol: "music.note", price: 0, requiredLevel: 1),
        CosmeticItem(id: "sticker-first-chord", name: "First Chord", category: .sticker, symbol: "hands.clap.fill", price: 25, requiredLevel: 1),
        CosmeticItem(id: "keychain-uke", name: "Tiny Uke", category: .keychain, symbol: "guitars.fill", price: 45, requiredLevel: 2),
        CosmeticItem(id: "accessory-cap", name: "Stage Cap", category: .accessory, symbol: "graduationcap.fill", price: 70, requiredLevel: 4),
        CosmeticItem(id: "frame-neon", name: "Neon Frame", category: .frame, symbol: "sparkles.rectangle.stack.fill", price: 100, requiredLevel: 6),
        CosmeticItem(id: "mascot-star", name: "Star Player", category: .mascot, symbol: "star.fill", price: 180, requiredLevel: 10),
    ]
}

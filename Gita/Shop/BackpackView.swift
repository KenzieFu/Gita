import SwiftUI

struct BackpackView: View {
    @ObservedObject var model: PlayerProgressModel

    private var owned: [CosmeticItem] {
        CosmeticCatalog.items.filter { model.snapshot.profile.ownedItemIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                equippedPreview
                Text("YOUR ITEMS").font(.caption.monospaced().weight(.black)).tracking(2).foregroundStyle(ArcadeTheme.yellow)
                if owned.isEmpty {
                    ContentUnavailableView("Your Backpack is empty", systemImage: "backpack", description: Text("Complete daily tasks or visit the Shop."))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                        ForEach(owned) { item in
                            let equipped = model.snapshot.profile.equippedItemIDs.contains(item.id)
                            Button { model.equip(item) } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: item.symbol).font(.system(size: 36, weight: .black)).foregroundStyle(ArcadeTheme.cyan)
                                    Text(item.name).font(.headline.weight(.black)).multilineTextAlignment(.center)
                                    Text(equipped ? "EQUIPPED" : "TAP TO EQUIP")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(equipped ? ArcadeTheme.green : ArcadeTheme.muted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 145)
                                .padding(12)
                                .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(equipped ? ArcadeTheme.green : .clear, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
        .navigationTitle("Backpack")
    }

    private var equippedPreview: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(ArcadeTheme.cyan.opacity(0.12))
                Image(systemName: owned.first(where: { model.snapshot.profile.equippedItemIDs.contains($0.id) })?.symbol ?? "music.note")
                    .font(.system(size: 54, weight: .black)).foregroundStyle(ArcadeTheme.cyan)
            }.frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text("EQUIPPED LOOK").font(.caption.monospaced().weight(.black)).foregroundStyle(ArcadeTheme.yellow)
                Text("Your stage style").font(.title2.weight(.black))
                Text("Items are cosmetic and never change your score.").font(.caption).foregroundStyle(ArcadeTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 24))
    }
}

import SwiftUI

struct ShopView: View {
    @ObservedObject var model: PlayerProgressModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                ForEach(CosmeticCatalog.items) { item in
                    let owned = model.snapshot.profile.ownedItemIDs.contains(item.id)
                    let locked = model.snapshot.profile.level < item.requiredLevel
                    Button { model.purchase(item) } label: {
                        itemCard(item, owned: owned, locked: locked)
                    }
                    .buttonStyle(.plain)
                    .disabled(owned)
                }
            }
            .padding(22)
        }
        .background(ArcadeTheme.background.ignoresSafeArea())
        .navigationTitle("Shop")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label("\(model.snapshot.profile.gems)", systemImage: "diamond.fill").foregroundStyle(ArcadeTheme.cyan)
            }
        }
    }

    private func itemCard(_ item: CosmeticItem, owned: Bool, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(locked ? ArcadeTheme.muted : ArcadeTheme.cyan)
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(ArcadeTheme.cyan.opacity(locked ? 0.04 : 0.1), in: RoundedRectangle(cornerRadius: 15))
            Text(item.name).font(.headline.weight(.black))
            Text(item.category.title).font(.caption).foregroundStyle(ArcadeTheme.muted)
            Text(owned ? "OWNED" : locked ? "LEVEL \(item.requiredLevel)" : "\(item.price) GEMS")
                .font(.caption.monospaced().weight(.black))
                .foregroundStyle(owned ? ArcadeTheme.green : locked ? ArcadeTheme.muted : ArcadeTheme.yellow)
        }
        .padding(14)
        .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 20))
    }
}

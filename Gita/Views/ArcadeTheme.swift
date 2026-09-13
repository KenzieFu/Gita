import SwiftUI

enum ArcadeTheme {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.12)
    static let panel = Color(red: 0.08, green: 0.10, blue: 0.20)
    static let cyan = Color(red: 0.34, green: 0.94, blue: 0.98)
    static let green = Color(red: 0.34, green: 0.92, blue: 0.58)
    static let pink = Color(red: 1.00, green: 0.36, blue: 0.70)
    static let yellow = Color(red: 1.00, green: 0.83, blue: 0.37)
    static let muted = Color(red: 0.68, green: 0.74, blue: 0.84)
}

struct StageShell<Leading: View, Trailing: View>: View {
    let step: String
    let title: String
    let subtitle: String
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path")
                                .foregroundStyle(ArcadeTheme.cyan)
                            Text("GITA")
                                .tracking(5)
                                .fontWeight(.black)
                        }
                        .font(.title3)
                        Spacer()
                        Text(step.uppercased())
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(ArcadeTheme.yellow)
                    }

                    if geometry.size.width >= 720 {
                        HStack(alignment: .top, spacing: 25) {
                            introduction
                                .frame(maxWidth: .infinity, alignment: .leading)
                            trailing
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 22) {
                            introduction
                            trailing
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 22)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack {
                    ArcadeTheme.background
                    RadialGradient(colors: [ArcadeTheme.pink.opacity(0.17), .clear], center: .topTrailing, startRadius: 30, endRadius: 460)
                    RadialGradient(colors: [ArcadeTheme.cyan.opacity(0.11), .clear], center: .bottomLeading, startRadius: 20, endRadius: 480)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 46, weight: .black, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(ArcadeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            leading
        }
    }
}

struct StagePanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(ArcadeTheme.panel, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(ArcadeTheme.cyan.opacity(0.24), lineWidth: 1))
    }
}

struct StageButton: View {
    let title: String
    let symbol: String
    var secondary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                Image(systemName: symbol)
            }
            .font(.headline.weight(.bold))
            .frame(minHeight: 54)
            .frame(maxWidth: .infinity)
            .foregroundStyle(secondary ? ArcadeTheme.cyan : ArcadeTheme.background)
            .background(secondary ? ArcadeTheme.panel : ArcadeTheme.cyan, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ArcadeTheme.cyan, lineWidth: secondary ? 1 : 0))
        }
        .buttonStyle(.plain)
    }
}

struct NeonNote: View {
    let symbol: String
    let label: String
    var color: Color = ArcadeTheme.cyan

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 65, weight: .light))
            Text(label)
                .font(.title2.weight(.bold))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

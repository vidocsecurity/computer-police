import SwiftUI

/// Faux window title bar: pixel badge mark, "COMPUTER POLICE · <subtitle>" in
/// tracked small caps, and decorative right-aligned glyphs. Decorative only.
struct TitleStrip: View {
    let subtitle: String

    @Environment(\.retro) private var palette

    var body: some View {
        ZStack {
            palette.panelDeep
            Pinstripes()
                .stroke(palette.textTertiary.opacity(0.35), lineWidth: 1)

            HStack(spacing: 8) {
                BadgeMark(size: 14)
                Text("COMPUTER POLICE")
                    .font(.retroLabel)
                    .tracking(1.4)
                    .foregroundStyle(palette.textPrimary)
                Text("·")
                    .foregroundStyle(palette.textTertiary)
                Text(subtitle.uppercased())
                    .font(.retroLabel)
                    .tracking(1.0)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                glyph("─")
                glyph("⊠")
            }
            .padding(.horizontal, 10)
        }
        .frame(height: Retro.Metrics.titleStripHeight)
        .overlay(
            Rectangle()
                .fill(palette.bevelShadow)
                .frame(height: 1),
            alignment: .bottom)
    }

    private func glyph(_ s: String) -> some View {
        Text(s)
            .font(.retroLabel)
            .foregroundStyle(palette.textTertiary)
            .frame(width: 14, height: 12)
            .overlay(BevelOverlay(style: .raised))
    }
}

/// Subtle horizontal pinstripes, like Mac OS 8 title bars. We fill solid lines
/// every 2 px; the panel color shows through between them.
private struct Pinstripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y: CGFloat = 1
        while y < rect.height - 1 {
            p.move(to: CGPoint(x: rect.minX + 1, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - 1, y: y))
            y += 2
        }
        return p
    }
}

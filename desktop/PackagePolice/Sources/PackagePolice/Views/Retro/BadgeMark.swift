import SwiftUI

/// The "Department" mark: a sheriff star inside a shield. Used in the title
/// strip and as the basis for the menu-bar template image. Distinct from
/// `OfficerView` which is the mascot — this is the logo.
struct BadgeMark: View {
    var size: CGFloat = 14

    @Environment(\.retro) private var palette

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(palette.accent)
            ShieldShape()
                .stroke(palette.bevelShadow, lineWidth: 1)
            SheriffStar(points: 5)
                .fill(Color(red: 1.0, green: 0.84, blue: 0.30))
                .frame(width: size * 0.55, height: size * 0.55)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A simple shield silhouette: square shoulders, pointed bottom.
struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset: CGFloat = 0
        let topY = rect.minY + inset
        let midY = rect.minY + rect.height * 0.62
        let botY = rect.maxY - inset
        let leftX = rect.minX + inset
        let rightX = rect.maxX - inset
        let midX = rect.midX

        p.move(to: CGPoint(x: leftX, y: topY))
        p.addLine(to: CGPoint(x: rightX, y: topY))
        p.addLine(to: CGPoint(x: rightX, y: midY))
        p.addQuadCurve(
            to: CGPoint(x: midX, y: botY),
            control: CGPoint(x: rightX, y: botY))
        p.addQuadCurve(
            to: CGPoint(x: leftX, y: midY),
            control: CGPoint(x: leftX, y: botY))
        p.closeSubpath()
        return p
    }
}

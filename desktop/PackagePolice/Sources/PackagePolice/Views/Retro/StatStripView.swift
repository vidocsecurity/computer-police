import SwiftUI

/// "Beat report" strip: dense monospaced row with three labelled values
/// separated by sharp dividers. Replaces the three identical `StatCardView`s.
struct StatStripView: View {
    let installs: Int
    let caught: Int
    let blocked: Int

    @Environment(\.retro) private var palette

    var body: some View {
        HStack(spacing: 0) {
            cell(label: "Installs", value: installs, accent: palette.dataMono)
            divider
            cell(label: "Caught", value: caught, accent: caught > 0 ? palette.warning : palette.dataMono)
            divider
            cell(label: "Blocked", value: blocked, accent: palette.dataMono)
        }
        .frame(maxWidth: .infinity)
        .background(palette.inset)
        .overlay(BevelOverlay(style: .sunken))
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.bevelShadow.opacity(0.5))
            .frame(width: 1)
            .padding(.vertical, 6)
    }

    private func cell(label: String, value: Int, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label.uppercased())
                .font(.retroLabel)
                .tracking(0.8)
                .foregroundStyle(palette.textSecondary)
            Spacer(minLength: 2)
            Text(format(value))
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func format(_ n: Int) -> String {
        String(format: "%04d", min(n, 9999))
    }
}

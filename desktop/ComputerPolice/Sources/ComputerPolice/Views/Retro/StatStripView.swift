import SwiftUI

/// "Beat report" strip: dense monospaced row with three additive values.
///
/// The buckets are designed so the math is obvious to a developer reading
/// them at a glance: `clean + caught == scanned`. No overlap, no
/// double-counting, no warning color on counters that represent wins.
///
/// - `Scanned`: every package install attempt the proxy advisory-checked
///   this week. Neutral data color — it is just measurement.
/// - `Clean`: scanned attempts that were allowed through. Positive color,
///   because that is the developer's everyday outcome.
/// - `Caught`: known-malicious package versions stopped before install.
///   Accent color with a small star glyph — it is a win, not an alarm.
struct StatStripView: View {
    let scanned: Int
    let clean: Int
    let caught: Int

    @Environment(\.retro) private var palette

    var body: some View {
        HStack(spacing: 0) {
            cell(
                label: "Scanned",
                value: scanned,
                accent: palette.dataMono,
                tooltip: "Package install attempts checked this week.")
            divider
            cell(
                label: "Clean",
                value: clean,
                accent: palette.positive,
                tooltip: "Allowed through after a clean advisory check.")
            divider
            caughtCell
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

    private func cell(label: String, value: Int, accent: Color, tooltip: String) -> some View {
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
        .help(tooltip)
    }

    /// Caught gets its own renderer so we can inline a small star glyph,
    /// matching the WANTED poster's vocabulary and signalling this is the
    /// celebratory column. Star is dim when the count is zero so the strip
    /// stays calm on a quiet shift.
    private var caughtCell: some View {
        let active = caught > 0
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(spacing: 3) {
                Text("★")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(active ? palette.accent : palette.textTertiary)
                Text("CAUGHT")
                    .font(.retroLabel)
                    .tracking(0.8)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 2)
            Text(format(caught))
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(active ? palette.accent : palette.dataMono)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .help("Known-malicious package versions stopped before install.")
    }

    private func format(_ n: Int) -> String {
        String(format: "%04d", min(n, 9999))
    }
}

import SwiftUI

// MARK: - Bevels

enum BevelStyle {
    case raised
    case sunken
    case flat
}

/// 1-pixel bevel rectangle: light edge top/left, dark edge bottom/right.
/// Switch raised <-> sunken by inverting the highlight order.
struct BevelOverlay: View {
    let style: BevelStyle
    @Environment(\.retro) private var palette

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let stroke = Retro.Metrics.bevelWidth
            let light = palette.bevelLight
            let shadow = palette.bevelShadow
            let topLeft = style == .sunken ? shadow : light
            let bottomRight = style == .sunken ? light : shadow
            ZStack {
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: width, y: 0))
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: 0, y: height))
                }
                .stroke(topLeft, lineWidth: stroke)

                Path { p in
                    p.move(to: CGPoint(x: width - stroke / 2, y: 0))
                    p.addLine(to: CGPoint(x: width - stroke / 2, y: height))
                    p.move(to: CGPoint(x: 0, y: height - stroke / 2))
                    p.addLine(to: CGPoint(x: width, y: height - stroke / 2))
                }
                .stroke(bottomRight, lineWidth: stroke)

                if style != .flat {
                    Rectangle()
                        .stroke(palette.bevelShadow.opacity(style == .raised ? 0.0 : 0.0), lineWidth: 0)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A retro panel surface: square corners, optional bevel, optional inset fill.
struct BeveledPanel<Content: View>: View {
    let style: BevelStyle
    let fillsBackground: Bool
    let padding: CGFloat
    let content: () -> Content
    @Environment(\.retro) private var palette

    init(
        style: BevelStyle = .raised,
        fillsBackground: Bool = true,
        padding: CGFloat = Retro.Metrics.panelInset,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.style = style
        self.fillsBackground = fillsBackground
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if fillsBackground {
                        background
                    } else {
                        Color.clear
                    }
                })
            .overlay(BevelOverlay(style: style))
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .raised, .flat:
            palette.panel
        case .sunken:
            palette.inset
        }
    }
}

// MARK: - Buttons

/// Beveled rectangular button: raised by default, depressed on press.
struct BeveledButtonStyle: ButtonStyle {
    var emphasis: Emphasis = .secondary
    @Environment(\.retro) private var palette
    @Environment(\.isEnabled) private var isEnabled

    enum Emphasis {
        case primary
        case secondary
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.retroLabel)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(emphasis == .primary ? palette.accent : palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minWidth: 64)
            .background(palette.panel)
            .overlay(BevelOverlay(style: pressed ? .sunken : .raised))
            .opacity(isEnabled ? 1.0 : 0.45)
            .contentShape(Rectangle())
    }
}

/// Borderless bracketed text button: `[ Quit ]`.
struct BracketButtonStyle: ButtonStyle {
    @Environment(\.retro) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Text("[").foregroundStyle(palette.textTertiary)
            configuration.label
                .foregroundStyle(configuration.isPressed ? palette.accent : palette.textPrimary)
            Text("]").foregroundStyle(palette.textTertiary)
        }
        .font(.retroLabel)
        .tracking(0.5)
        .textCase(.uppercase)
        .opacity(isEnabled ? 1.0 : 0.45)
        .contentShape(Rectangle())
    }
}

// MARK: - Toggle (rocker switch)

/// Retro checkbox toggle style: small beveled square with an X glyph when on.
struct RetroCheckboxToggleStyle: ToggleStyle {
    @Environment(\.retro) private var palette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Rectangle()
                        .fill(palette.inset)
                        .frame(width: 14, height: 14)
                        .overlay(BevelOverlay(style: .sunken))
                    if configuration.isOn {
                        Text("✕")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(palette.accent)
                    }
                }
                configuration.label
                    .font(.retroBody)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
    }
}

struct RockerToggleStyle: ToggleStyle {
    @Environment(\.retro) private var palette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 0) {
                segment(label: "ON", active: configuration.isOn)
                segment(label: "OFF", active: !configuration.isOn)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }

    @ViewBuilder
    private func segment(label: String, active: Bool) -> some View {
        Text(label)
            .font(.retroLabel)
            .tracking(0.6)
            .foregroundStyle(active ? palette.textPrimary : palette.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minWidth: 40)
            .background(active ? palette.inset : palette.panelDeep)
            .overlay(BevelOverlay(style: active ? .sunken : .raised))
    }
}

// MARK: - LED indicator

enum LEDState { case ok, warn, fail, off }

struct LEDIndicator: View {
    let state: LEDState
    var blinking: Bool = false

    @Environment(\.retro) private var palette
    @SwiftUI.State private var phase = false

    var body: some View {
        Rectangle()
            .fill(color(for: state).opacity(blinking && phase ? 0.25 : 1.0))
            .frame(width: Retro.Metrics.ledSize, height: Retro.Metrics.ledSize)
            .overlay(
                Rectangle()
                    .stroke(palette.bevelShadow, lineWidth: 1))
            .onAppear {
                guard blinking else { return }
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    phase = !phase
                }
            }
    }

    private func color(for state: LEDState) -> Color {
        switch state {
        case .ok: return palette.positive
        case .warn: return palette.warning
        case .fail: return palette.critical
        case .off: return palette.textTertiary.opacity(0.6)
        }
    }
}

// MARK: - Dotted-leader row (KEY ............ VALUE)

struct DottedLeaderRow: View {
    let key: String
    let value: String
    var valueAccent: Color?

    @Environment(\.retro) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(key.uppercased())
                .font(.retroLabel)
                .tracking(0.4)
                .foregroundStyle(palette.textSecondary)
                .layoutPriority(1)
            Leader()
                .stroke(palette.textTertiary.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2]))
                .frame(height: 1)
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + 4 }
            Text(value)
                .font(.retroCaption)
                .foregroundStyle(valueAccent ?? palette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct Leader: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: y))
        p.addLine(to: CGPoint(x: rect.maxX, y: y))
        return p
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Int]
    var height: CGFloat = 18

    @Environment(\.retro) private var palette

    var body: some View {
        GeometryReader { geo in
            let peak = Swift.max(values.max() ?? 0, 1)
            let count = Swift.max(values.count, 1)
            let gap: CGFloat = 2
            let totalGap = gap * CGFloat(Swift.max(count - 1, 0))
            let barWidth = (geo.size.width - totalGap) / CGFloat(count)
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    Rectangle()
                        .fill(palette.dataMono)
                        .frame(
                            width: Swift.max(barWidth, 2),
                            height: Swift.max(2, geo.size.height * CGFloat(v) / CGFloat(peak)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
        }
        .frame(height: height)
    }
}

// MARK: - Section header (small caps tracked label)

struct SectionLabel: View {
    let text: String

    @Environment(\.retro) private var palette

    var body: some View {
        Text(text.uppercased())
            .font(.retroLabel)
            .tracking(1.2)
            .foregroundStyle(palette.textSecondary)
    }
}

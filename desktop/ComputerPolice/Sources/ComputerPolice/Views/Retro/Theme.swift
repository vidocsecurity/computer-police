import SwiftUI

/// Retro chrome palette and metrics. Two skins:
/// - Platinum: Mac OS 8/9 light grays, beveled chrome, used in light mode.
/// - Dispatch: black panels with phosphor green readouts, used in dark mode.
enum Retro {
    enum Metrics {
        static let popoverWidth: CGFloat = 440
        static let popoverHeight: CGFloat = 560
        static let cornerRadius: CGFloat = 0
        static let panelInset: CGFloat = 10
        static let bevelWidth: CGFloat = 1
        static let dividerWidth: CGFloat = 1
        static let titleStripHeight: CGFloat = 22
        static let ledSize: CGFloat = 8
    }

    struct Palette {
        let panel: Color
        let panelDeep: Color
        let inset: Color
        let bevelLight: Color
        let bevelShadow: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let dataMono: Color
        let accent: Color
        let positive: Color
        let warning: Color
        let critical: Color
        let stripeAlt: Color

        init(
            panel: Color,
            panelDeep: Color,
            inset: Color,
            bevelLight: Color,
            bevelShadow: Color,
            textPrimary: Color,
            textSecondary: Color,
            textTertiary: Color,
            dataMono: Color,
            accent: Color,
            positive: Color,
            warning: Color,
            critical: Color,
            stripeAlt: Color)
        {
            self.panel = panel
            self.panelDeep = panelDeep
            self.inset = inset
            self.bevelLight = bevelLight
            self.bevelShadow = bevelShadow
            self.textPrimary = textPrimary
            self.textSecondary = textSecondary
            self.textTertiary = textTertiary
            self.dataMono = dataMono
            self.accent = accent
            self.positive = positive
            self.warning = warning
            self.critical = critical
            self.stripeAlt = stripeAlt
        }

        static let platinum = Palette(
            panel: Color(red: 0.86, green: 0.86, blue: 0.86),
            panelDeep: Color(red: 0.78, green: 0.78, blue: 0.78),
            inset: Color(red: 0.99, green: 0.99, blue: 0.98),
            bevelLight: Color(red: 1.00, green: 1.00, blue: 1.00),
            bevelShadow: Color(red: 0.42, green: 0.42, blue: 0.44),
            textPrimary: Color(red: 0.10, green: 0.10, blue: 0.12),
            textSecondary: Color(red: 0.36, green: 0.36, blue: 0.40),
            textTertiary: Color(red: 0.55, green: 0.55, blue: 0.58),
            dataMono: Color(red: 0.10, green: 0.10, blue: 0.12),
            accent: Color(red: 0.11, green: 0.24, blue: 0.55),
            positive: Color(red: 0.18, green: 0.45, blue: 0.22),
            warning: Color(red: 0.72, green: 0.47, blue: 0.10),
            critical: Color(red: 0.69, green: 0.19, blue: 0.16),
            stripeAlt: Color(red: 0.93, green: 0.93, blue: 0.93))

        static let dispatch = Palette(
            panel: Color(red: 0.07, green: 0.08, blue: 0.10),
            panelDeep: Color(red: 0.04, green: 0.04, blue: 0.05),
            inset: Color(red: 0.10, green: 0.11, blue: 0.13),
            bevelLight: Color(red: 0.30, green: 0.31, blue: 0.34),
            bevelShadow: Color(red: 0.00, green: 0.00, blue: 0.00),
            textPrimary: Color(red: 0.92, green: 0.94, blue: 0.95),
            textSecondary: Color(red: 0.65, green: 0.68, blue: 0.72),
            textTertiary: Color(red: 0.45, green: 0.48, blue: 0.52),
            dataMono: Color(red: 0.49, green: 0.99, blue: 0.61),
            accent: Color(red: 0.36, green: 0.63, blue: 1.00),
            positive: Color(red: 0.49, green: 0.99, blue: 0.61),
            warning: Color(red: 1.00, green: 0.70, blue: 0.28),
            critical: Color(red: 1.00, green: 0.42, blue: 0.36),
            stripeAlt: Color(red: 0.10, green: 0.11, blue: 0.13))
    }
}

private struct RetroPaletteKey: EnvironmentKey {
    static let defaultValue: Retro.Palette = .platinum
}

extension EnvironmentValues {
    var retro: Retro.Palette {
        get { self[RetroPaletteKey.self] }
        set { self[RetroPaletteKey.self] = newValue }
    }
}

struct RetroPaletteModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette: Retro.Palette = colorScheme == .dark ? .dispatch : .platinum
        content
            .environment(\.retro, palette)
            .background(palette.panel.ignoresSafeArea())
            .foregroundStyle(palette.textPrimary)
    }
}

extension View {
    /// Installs the active retro palette into the environment and paints the
    /// surface to match. Apply once at the popover/window root.
    func retroSurface() -> some View {
        modifier(RetroPaletteModifier())
    }
}

extension Font {
    static let retroDisplay = Font.system(size: 14, weight: .heavy, design: .monospaced)
    static let retroHeadline = Font.system(size: 13, weight: .bold, design: .monospaced)
    static let retroLabel = Font.system(size: 10, weight: .semibold, design: .monospaced)
    static let retroBody = Font.system(size: 12, weight: .regular)
    static let retroBodyBold = Font.system(size: 12, weight: .semibold)
    static let retroData = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let retroDataLarge = Font.system(size: 22, weight: .heavy, design: .monospaced)
    static let retroCaption = Font.system(size: 10, weight: .regular, design: .monospaced)
}

import SwiftUI

/// Six face presets for our chibi computer mascot.
enum OfficerExpression: Equatable {
    case patrol      // calm dot eyes, slow blink
    case sleepy      // closed eyes, tiny "z"
    case alert       // wide eyes
    case proud       // ^_^
    case concerned   // furrowed eyes
    case hurt        // x_x
}

/// Officer Mac (light/Platinum) and Officer Term (dark/Dispatch) drawn as
/// vector SwiftUI primitives. Same character, two skins. The case is sharp
/// and pixel-aligned; the face inside the screen is round — the contrast
/// principle, embodied in the mascot itself.
struct OfficerView: View {
    let expression: OfficerExpression
    var size: CGFloat = 64
    var showsBadge: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.retro) private var palette
    @State private var blinking = false

    var body: some View {
        ZStack {
            switch colorScheme {
            case .dark:
                terminalSkin
            default:
                macintoshSkin
            }
        }
        .frame(width: size, height: size * 1.05)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            startBlinkLoop()
        }
        .onChange(of: expression) { _, newValue in
            if newValue != .patrol { blinking = false }
        }
    }

    private func startBlinkLoop() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(5500))
                if Task.isCancelled { return }
                if expression != .patrol { return }
                withAnimation(.easeInOut(duration: 0.08)) { blinking = true }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeInOut(duration: 0.10)) { blinking = false }
            }
        }
    }

    private var accessibilityLabel: Text {
        switch expression {
        case .patrol: return Text("Officer Mac on patrol")
        case .sleepy: return Text("Officer Mac is off duty")
        case .alert: return Text("Officer Mac is starting up")
        case .proud: return Text("Officer Mac caught one")
        case .concerned: return Text("Officer Mac is concerned")
        case .hurt: return Text("Officer Mac is down")
        }
    }

    // MARK: - M1 Officer Mac (compact Macintosh)

    @ViewBuilder
    private var macintoshSkin: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let caseColor = Color(red: 0.92, green: 0.88, blue: 0.78)
            let caseDark = Color(red: 0.62, green: 0.58, blue: 0.48)
            let screenBg = Color(red: 0.86, green: 0.91, blue: 0.83)
            let outline = Color(red: 0.18, green: 0.16, blue: 0.12)

            ZStack {
                // Case body
                Rectangle()
                    .fill(caseColor)
                    .frame(width: w * 0.86, height: h * 0.86)
                    .overlay(
                        Rectangle()
                            .stroke(outline, lineWidth: 1.5))
                    // Bevel highlights to give depth without rounding
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            .padding(2))
                    .offset(y: -h * 0.02)

                // CRT screen
                let screenFrame = CGRect(
                    x: w * 0.18,
                    y: h * 0.10,
                    width: w * 0.50,
                    height: h * 0.34)
                Rectangle()
                    .fill(screenBg)
                    .frame(width: screenFrame.width, height: screenFrame.height)
                    .overlay(
                        Rectangle()
                            .stroke(outline, lineWidth: 1))
                    .position(x: screenFrame.midX, y: screenFrame.midY)

                // Face on screen
                FaceView(expression: expression, blinking: blinking)
                    .frame(width: screenFrame.width * 0.85, height: screenFrame.height * 0.85)
                    .position(x: screenFrame.midX, y: screenFrame.midY)

                // "Hello" Apple-rainbow stripe sticker (right of screen)
                rainbowStripe()
                    .frame(width: w * 0.10, height: h * 0.02)
                    .position(x: w * 0.78, y: h * 0.16)

                // Floppy slot
                Rectangle()
                    .fill(caseDark)
                    .frame(width: w * 0.30, height: h * 0.025)
                    .position(x: w * 0.43, y: h * 0.50)

                // Sheriff star sticker
                if showsBadge {
                    SheriffStar(points: 5)
                        .fill(Color(red: 1.00, green: 0.78, blue: 0.18))
                        .overlay(
                            SheriffStar(points: 5)
                                .stroke(outline, lineWidth: 1))
                        .frame(width: w * 0.16, height: w * 0.16)
                        .position(x: w * 0.43, y: h * 0.66)
                }

                // Base ridge
                Rectangle()
                    .fill(caseDark.opacity(0.55))
                    .frame(width: w * 0.86, height: 1)
                    .position(x: w * 0.50, y: h * 0.79)

                // Two tiny feet
                HStack(spacing: w * 0.55) {
                    foot()
                    foot()
                }
                .position(x: w * 0.50, y: h * 0.86)
            }
        }
        .drawingGroup()
    }

    private func foot() -> some View {
        Rectangle()
            .fill(Color(red: 0.62, green: 0.58, blue: 0.48))
            .frame(width: 6, height: 4)
    }

    private func rainbowStripe() -> some View {
        HStack(spacing: 0) {
            ForEach(rainbowColors, id: \.self) { c in
                Rectangle().fill(c)
            }
        }
    }

    private var rainbowColors: [Color] {
        [
            Color(red: 0.36, green: 0.72, blue: 0.40),
            Color(red: 0.95, green: 0.78, blue: 0.20),
            Color(red: 0.92, green: 0.45, blue: 0.20),
            Color(red: 0.85, green: 0.20, blue: 0.30),
            Color(red: 0.50, green: 0.30, blue: 0.65),
            Color(red: 0.20, green: 0.50, blue: 0.85),
        ]
    }

    // MARK: - M3 Officer Term (terminal CRT)

    @ViewBuilder
    private var terminalSkin: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let caseColor = Color(red: 0.10, green: 0.10, blue: 0.12)
            let caseEdge = Color(red: 0.32, green: 0.34, blue: 0.38)
            let screenBg = Color(red: 0.02, green: 0.05, blue: 0.03)
            let phosphor = Color(red: 0.49, green: 0.99, blue: 0.61)

            ZStack {
                // Case body
                Rectangle()
                    .fill(caseColor)
                    .frame(width: w * 0.92, height: h * 0.74)
                    .overlay(
                        Rectangle()
                            .stroke(caseEdge, lineWidth: 1))
                    .offset(y: -h * 0.06)

                // Top vent (3 tiny slits)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(caseEdge).frame(width: 6, height: 2)
                    }
                }
                .position(x: w * 0.50, y: h * 0.06)

                // Screen
                let screenFrame = CGRect(
                    x: w * 0.10,
                    y: h * 0.13,
                    width: w * 0.80,
                    height: h * 0.50)
                Rectangle()
                    .fill(screenBg)
                    .frame(width: screenFrame.width, height: screenFrame.height)
                    .overlay(
                        Rectangle()
                            .stroke(phosphor.opacity(0.35), lineWidth: 1))
                    .position(x: screenFrame.midX, y: screenFrame.midY)

                // Scanlines (subtle)
                ScanlinesShape()
                    .stroke(phosphor.opacity(0.06), lineWidth: 0.5)
                    .frame(width: screenFrame.width, height: screenFrame.height)
                    .position(x: screenFrame.midX, y: screenFrame.midY)

                // Face
                FaceView(expression: expression, blinking: blinking, color: phosphor)
                    .frame(width: screenFrame.width * 0.85, height: screenFrame.height * 0.85)
                    .position(x: screenFrame.midX, y: screenFrame.midY)

                // Power LED
                Rectangle()
                    .fill(phosphor)
                    .frame(width: 4, height: 4)
                    .position(x: w * 0.84, y: h * 0.66)

                // Sheriff star sticker
                if showsBadge {
                    SheriffStar(points: 5)
                        .fill(Color(red: 1.00, green: 0.78, blue: 0.18))
                        .overlay(
                            SheriffStar(points: 5)
                                .stroke(caseColor, lineWidth: 1))
                        .frame(width: w * 0.14, height: w * 0.14)
                        .position(x: w * 0.16, y: h * 0.66)
                }

                // Stand neck
                Rectangle()
                    .fill(caseColor)
                    .overlay(Rectangle().stroke(caseEdge, lineWidth: 1))
                    .frame(width: w * 0.18, height: h * 0.08)
                    .position(x: w * 0.50, y: h * 0.79)

                // Base
                Rectangle()
                    .fill(caseColor)
                    .overlay(Rectangle().stroke(caseEdge, lineWidth: 1))
                    .frame(width: w * 0.62, height: h * 0.05)
                    .position(x: w * 0.50, y: h * 0.86)
            }
        }
        .drawingGroup()
    }
}

// MARK: - Face

private struct FaceView: View {
    let expression: OfficerExpression
    let blinking: Bool
    var color: Color = Color(red: 0.10, green: 0.10, blue: 0.12)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let eyeY = h * 0.45
            let leftX = w * 0.30
            let rightX = w * 0.70
            let eyeWidth = w * 0.14

            ZStack {
                eye(at: CGPoint(x: leftX, y: eyeY), eyeWidth: eyeWidth)
                eye(at: CGPoint(x: rightX, y: eyeY), eyeWidth: eyeWidth)
                mouth(in: CGRect(x: 0, y: 0, width: w, height: h))
                cheeks(at: w, h: h, eyeY: eyeY)
            }
        }
    }

    @ViewBuilder
    private func eye(at p: CGPoint, eyeWidth: CGFloat) -> some View {
        let strokeWidth: CGFloat = max(1.5, eyeWidth * 0.20)

        switch expression {
        case .patrol:
            if blinking {
                Capsule()
                    .stroke(color, lineWidth: strokeWidth)
                    .frame(width: eyeWidth, height: 2)
                    .position(p)
            } else {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: eyeWidth * 0.62, height: eyeWidth * 0.62)
                    // Tiny "shine" highlight on the upper-right of the eye for liveliness.
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: eyeWidth * 0.18, height: eyeWidth * 0.18)
                        .offset(x: eyeWidth * 0.10, y: -eyeWidth * 0.10)
                }
                .position(p)
            }
        case .sleepy:
            ArcShape(opening: .down)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: eyeWidth, height: eyeWidth * 0.7)
                .position(p)
        case .alert:
            ZStack {
                Circle().stroke(color, lineWidth: strokeWidth)
                    .frame(width: eyeWidth, height: eyeWidth)
                Circle().fill(color)
                    .frame(width: eyeWidth * 0.4, height: eyeWidth * 0.4)
            }
            .position(p)
        case .proud:
            ArcShape(opening: .up)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: eyeWidth, height: eyeWidth * 0.7)
                .position(p)
        case .concerned:
            Path { path in
                path.move(to: CGPoint(x: 0, y: eyeWidth * 0.65))
                path.addLine(to: CGPoint(x: eyeWidth, y: eyeWidth * 0.35))
            }
            .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: eyeWidth, height: eyeWidth)
            .position(p)
        case .hurt:
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: eyeWidth, y: eyeWidth))
                    p.move(to: CGPoint(x: eyeWidth, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: eyeWidth))
                }
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            }
            .frame(width: eyeWidth, height: eyeWidth)
            .position(p)
        }
    }

    @ViewBuilder
    private func mouth(in rect: CGRect) -> some View {
        let centerX = rect.midX
        let mouthY = rect.height * 0.72
        let strokeWidth: CGFloat = max(1.2, rect.width * 0.030)

        switch expression {
        case .patrol:
            // Subtle smile so the steady on-state reads as cheerful, not neutral.
            ArcShape(opening: .up)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: rect.width * 0.26, height: rect.width * 0.09)
                .position(x: centerX, y: mouthY)
        case .alert:
            // Small "o" mouth: alert/curious, not anxious.
            Circle()
                .stroke(color, lineWidth: strokeWidth)
                .frame(width: rect.width * 0.10, height: rect.width * 0.10)
                .position(x: centerX, y: mouthY)
        case .sleepy:
            // small "z" hint above-right
            Text("z")
                .font(.system(size: rect.width * 0.16, weight: .heavy, design: .monospaced))
                .foregroundStyle(color)
                .position(x: rect.width * 0.85, y: rect.height * 0.20)
        case .proud:
            // Big grin for the "just caught one" moment.
            ArcShape(opening: .up)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: rect.width * 0.36, height: rect.width * 0.16)
                .position(x: centerX, y: mouthY)
        case .concerned:
            ArcShape(opening: .down)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: rect.width * 0.25, height: rect.width * 0.10)
                .position(x: centerX, y: mouthY + 2)
        case .hurt:
            Rectangle()
                .fill(color)
                .frame(width: rect.width * 0.18, height: strokeWidth)
                .position(x: centerX, y: mouthY)
        }
    }

    @ViewBuilder
    private func cheeks(at w: CGFloat, h: CGFloat, eyeY: CGFloat) -> some View {
        let showCheeks: Bool = {
            switch expression {
            case .patrol, .proud, .alert: return true
            default: return false
            }
        }()
        if showCheeks {
            let cheekColor = Color(red: 1.0, green: 0.50, blue: 0.50).opacity(0.70)
            let cheekY = eyeY + h * 0.12
            Group {
                Capsule()
                    .fill(cheekColor)
                    .frame(width: w * 0.14, height: w * 0.06)
                    .position(x: w * 0.16, y: cheekY)
                Capsule()
                    .fill(cheekColor)
                    .frame(width: w * 0.14, height: w * 0.06)
                    .position(x: w * 0.84, y: cheekY)
            }
        }
    }
}

// MARK: - Shapes

struct SheriffStar: Shape {
    let points: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        var path = Path()
        let total = points * 2
        for i in 0..<total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

private struct ArcShape: Shape {
    enum Opening { case up, down }
    let opening: Opening

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch opening {
        case .up:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        case .down:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6))
        }
        return p
    }
}

private struct ScanlinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y: CGFloat = 0
        while y < rect.height {
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 2
        }
        return p
    }
}

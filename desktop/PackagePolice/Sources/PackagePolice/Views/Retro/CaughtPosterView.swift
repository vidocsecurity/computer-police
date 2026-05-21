import SwiftUI

/// A small "WANTED" poster that appears for ~10 seconds when Officer Mac
/// catches a suspect. Pixel-styled chrome, sharp edges, with an explicit
/// dismiss button. Disappears completely when nothing is being celebrated
/// so it doesn't take up vertical space in the popover the rest of the time.
struct CaughtPosterView: View {
    @ObservedObject var store: SecurityStore

    @Environment(\.retro) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var package: String?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            if visible, let package {
                posterBody(package: package)
                    .transition(.opacity)
            }
        }
        .onChange(of: store.malwareBlinkSignal) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            present(packageHint: newValue)
        }
    }

    @ViewBuilder
    private func posterBody(package: String) -> some View {
        VStack(spacing: 0) {
            // Top brass strip
            HStack(spacing: 6) {
                Text("★")
                    .font(.retroData)
                    .foregroundStyle(palette.warning)
                Text("WANTED")
                    .font(.retroDisplay)
                    .tracking(2.0)
                    .foregroundStyle(palette.textPrimary)
                Text("★")
                    .font(.retroData)
                    .foregroundStyle(palette.warning)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                }
                .buttonStyle(BracketButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(palette.panel)
            .overlay(
                Rectangle()
                    .fill(palette.bevelShadow.opacity(0.6))
                    .frame(height: 1),
                alignment: .bottom)

            HStack(alignment: .center, spacing: 12) {
                OfficerView(expression: .proud, size: 44, showsBadge: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caught a suspect")
                        .font(.retroLabel)
                        .tracking(1.0)
                        .foregroundStyle(palette.textSecondary)
                    Text(package)
                        .font(.retroData)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Officer Mac stopped this install before it ran.")
                        .font(.retroCaption)
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(palette.inset)
        .overlay(BevelOverlay(style: .raised))
    }

    private func present(packageHint: String) {
        dismissTask?.cancel()
        package = packageHint
        if reduceMotion {
            visible = true
        } else {
            withAnimation(.easeOut(duration: 0.18)) { visible = true }
        }
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            if Task.isCancelled { return }
            dismiss()
        }
        dismissTask = task
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        if reduceMotion {
            visible = false
            package = nil
        } else {
            withAnimation(.easeIn(duration: 0.18)) { visible = false }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                package = nil
            }
        }
    }
}

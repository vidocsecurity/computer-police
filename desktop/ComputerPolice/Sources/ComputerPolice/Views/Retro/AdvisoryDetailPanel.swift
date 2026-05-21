import AppKit
import ComputerPoliceCore
import SwiftUI

/// Shared inline detail panel used by both the WANTED list and the patrol log
/// when a user clicks a row. It carries reassurance ("Officer Mac stopped
/// this — the package never ran.") plus the OSV advisory metadata, with two
/// affordances: open the advisory in the browser, and copy the advisory ID.
struct AdvisoryDetailPanel: View {
    let coordinate: String
    let advisoryID: String?
    let severity: String?
    let summary: String?
    let recommendation: String?
    let manager: String?
    let timestamp: Date?
    let outcome: Outcome
    var onOpenURL: ((URL) -> Void)? = nil

    @Environment(\.retro) private var palette
    @State private var copyConfirmation: String?

    enum Outcome {
        case caught       // proxy 403 from MAL advisory
        case review       // matched local blocklist or has advisory but not blocked
        case observed     // ordinary install, no advisory

        var headline: String {
            switch self {
            case .caught: return "Officer Mac stopped this install"
            case .review: return "Package matches an advisory"
            case .observed: return "Package install observed"
            }
        }

        var reassurance: String {
            switch self {
            case .caught: return "The package never ran — the proxy returned a 403 before npm/bun could touch it."
            case .review: return "We saw this on the registry. The proxy did not block it; review and decide."
            case .observed: return "Routine package install. No advisory matched."
            }
        }

        func headlineColor(_ palette: Retro.Palette) -> Color {
            switch self {
            case .caught: return palette.warning
            case .review: return palette.warning
            case .observed: return palette.positive
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            reassuranceHeader
            if let summary, !summary.isEmpty {
                advisoryParagraph(label: "Summary", text: summary)
            }
            if let recommendation, !recommendation.isEmpty {
                advisoryParagraph(label: "Action", text: recommendation)
            }
            metadataGrid
            actionButtons
        }
        .padding(10)
        .background(palette.inset)
        .overlay(BevelOverlay(style: .sunken))
    }

    private var reassuranceHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: outcome == .caught ? "checkmark.shield.fill" : "info.circle.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(outcome.headlineColor(palette))
                Text(outcome.headline.uppercased())
                    .font(.retroLabel)
                    .tracking(1.0)
                    .foregroundStyle(outcome.headlineColor(palette))
                Spacer()
                if let severity, !severity.isEmpty {
                    Text(OSVAdvisory.severityTag(severity))
                        .font(.retroLabel)
                        .tracking(0.6)
                        .foregroundStyle(OSVAdvisory.severityColor(severity, palette: palette))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(OSVAdvisory.severityColor(severity, palette: palette).opacity(0.16))
                        .overlay(
                            Rectangle()
                                .stroke(OSVAdvisory.severityColor(severity, palette: palette).opacity(0.55), lineWidth: 1))
                }
            }
            Text(outcome.reassurance)
                .font(.retroBody)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func advisoryParagraph(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.retroLabel)
                .tracking(0.8)
                .foregroundStyle(palette.textTertiary)
            Text(text)
                .font(.retroBody)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !coordinate.isEmpty {
                metadataRow(key: "Package", value: coordinate, mono: true, accent: nil)
            }
            if let advisoryID, !advisoryID.isEmpty {
                metadataRow(
                    key: "Advisory",
                    value: "\(advisoryID) · \(OSVAdvisory.sourceLabel(for: advisoryID))",
                    mono: true,
                    accent: nil)
            }
            if let manager, !manager.isEmpty {
                metadataRow(key: "Manager", value: manager, mono: true, accent: nil)
            }
            if let formattedTime {
                metadataRow(key: "Time", value: formattedTime, mono: true, accent: nil)
            }
        }
    }

    private var formattedTime: String? {
        guard let timestamp else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    private func metadataRow(key: String, value: String, mono: Bool, accent: Color?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(key.uppercased())
                .font(.retroLabel)
                .tracking(0.6)
                .foregroundStyle(palette.textTertiary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(mono ? .retroData : .retroBody)
                .foregroundStyle(accent ?? palette.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if let advisoryID, let url = OSVAdvisory.detailURL(for: advisoryID) {
                Button("Open advisory ↗") {
                    if let onOpenURL {
                        onOpenURL(url)
                    } else {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(BeveledButtonStyle(emphasis: .primary))
            }
            if let advisoryID {
                Button(copyConfirmation == "id" ? "Copied" : "Copy ID") {
                    copyToPasteboard(advisoryID)
                    confirm("id")
                }
                .buttonStyle(BeveledButtonStyle())
            }
            if !coordinate.isEmpty {
                Button(copyConfirmation == "coord" ? "Copied" : "Copy coordinate") {
                    copyToPasteboard(coordinate)
                    confirm("coord")
                }
                .buttonStyle(BeveledButtonStyle())
            }
            Spacer()
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    private func confirm(_ tag: String) {
        copyConfirmation = tag
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if copyConfirmation == tag { copyConfirmation = nil }
        }
    }
}

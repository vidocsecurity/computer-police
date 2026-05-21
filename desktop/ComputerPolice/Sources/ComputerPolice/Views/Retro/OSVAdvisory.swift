import Foundation
import SwiftUI

/// Helpers for advisory-related URLs, copy strings, and severity styling.
enum OSVAdvisory {
    /// Returns the canonical detail page for an advisory ID. Handles OSV's
    /// own IDs (MAL-, OSV-) plus GHSA and CVE.
    static func detailURL(for advisoryID: String) -> URL? {
        let trimmed = advisoryID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        if upper.hasPrefix("CVE-") {
            return URL(string: "https://nvd.nist.gov/vuln/detail/\(trimmed)")
        }
        if upper.hasPrefix("GHSA-") {
            return URL(string: "https://github.com/advisories/\(trimmed)")
        }
        // MAL-, OSV-, RUSTSEC-, PYSEC-, etc. all live on osv.dev.
        return URL(string: "https://osv.dev/vulnerability/\(trimmed)")
    }

    static func sourceLabel(for advisoryID: String) -> String {
        let upper = advisoryID.uppercased()
        if upper.hasPrefix("MAL-") { return "OSV · Malicious Package" }
        if upper.hasPrefix("CVE-") { return "NVD" }
        if upper.hasPrefix("GHSA-") { return "GitHub Security Advisory" }
        return "OSV.dev"
    }

    /// A short, human-friendly tag like "CRITICAL" or "HIGH" for the inline
    /// severity chip. Defaults to the raw severity string uppercased.
    static func severityTag(_ severity: String) -> String {
        let normalized = severity.lowercased()
        switch normalized {
        case "critical": return "CRITICAL"
        case "high": return "HIGH"
        case "medium", "moderate": return "MEDIUM"
        case "low": return "LOW"
        default: return severity.isEmpty ? "ADVISORY" : severity.uppercased()
        }
    }

    static func severityColor(_ severity: String, palette: Retro.Palette) -> Color {
        switch severity.lowercased() {
        case "critical", "high": return palette.critical
        case "medium", "moderate": return palette.warning
        case "low": return palette.textSecondary
        default: return palette.warning
        }
    }
}

extension View {
    /// Ergonomic accent text styling for advisory chips.
    func advisoryChip(label: String, color: Color, palette: Retro.Palette) -> some View {
        Text(label)
            .font(.retroLabel)
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.16))
            .overlay(Rectangle().stroke(color.opacity(0.5), lineWidth: 1))
    }
}

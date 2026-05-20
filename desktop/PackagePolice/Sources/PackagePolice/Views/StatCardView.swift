import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.28), lineWidth: 1))
    }
}

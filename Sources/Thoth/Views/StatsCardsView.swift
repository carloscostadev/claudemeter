import SwiftUI

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let titleColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(titleColor)
            }
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatsCardsView: View {
    let burnRate: String
    let totalTokens: String
    let totalCost: String

    var body: some View {
        HStack(spacing: 8) {
            StatCard(icon: "🔥", title: "BURN RATE", value: burnRate, titleColor: .orange)
            StatCard(icon: "#", title: "TOKENS", value: totalTokens, titleColor: .blue)
            StatCard(icon: "💰", title: "COST", value: totalCost, titleColor: .green)
        }
        .padding(.horizontal, 16)
    }
}

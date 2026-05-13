import SwiftUI

struct SummaryRowsView: View {
    let todayCost: String
    let todayCalls: Int
    let todayTokens: Int
    let weekCost: String
    let weekCalls: Int
    let weekTokens: Int
    let fifteenDaysCost: String
    let fifteenDaysCalls: Int
    let fifteenDaysTokens: Int
    let monthCost: String
    let monthCalls: Int
    let monthTokens: Int
    let allTimeCost: String
    let allTimeCalls: Int
    let allTimeTokens: Int

    var body: some View {
        VStack(spacing: 0) {
            summaryRow(label: "Today", cost: todayCost, calls: todayCalls, tokens: todayTokens)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "7 Days", cost: weekCost, calls: weekCalls, tokens: weekTokens)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "15 Days", cost: fifteenDaysCost, calls: fifteenDaysCalls, tokens: fifteenDaysTokens)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "30 Days", cost: monthCost, calls: monthCalls, tokens: monthTokens)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "All Time", cost: allTimeCost, calls: allTimeCalls, tokens: allTimeTokens)
        }
    }

    private func summaryRow(label: String, cost: String, calls: Int, tokens: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(cost)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.orange)
                Text("\(ClaudeDataService.formatTokens(tokens)) tok · \(ClaudeDataService.formatCalls(calls)) calls")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

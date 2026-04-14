import SwiftUI

struct SummaryRowsView: View {
    let weekCost: String
    let weekCalls: Int
    let fifteenDaysCost: String
    let fifteenDaysCalls: Int
    let monthCost: String
    let monthCalls: Int

    var body: some View {
        VStack(spacing: 0) {
            summaryRow(label: "7 Days", cost: weekCost, calls: weekCalls)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "15 Days", cost: fifteenDaysCost, calls: fifteenDaysCalls)
            Divider().padding(.horizontal, 16)
            summaryRow(label: "Month", cost: monthCost, calls: monthCalls)
        }
    }

    private func summaryRow(label: String, cost: String, calls: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)

            Spacer()

            Text(cost)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.orange)

            Text(ClaudeDataService.formatCalls(calls) + " calls")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

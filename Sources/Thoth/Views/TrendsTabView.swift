import SwiftUI

struct TrendsTabView: View {
    let service: ClaudeDataService

    var body: some View {
        VStack(spacing: 0) {
            DailyCostChartView(series: service.dailyCostSeries)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 10) {
                MetricCardView(
                    title: "Projeção Mês",
                    value: String(format: "$%.2f", service.projectedMonthCost),
                    subtitle: "Mtd + 7d avg"
                )
                MetricCardView(
                    title: "Cost Saved",
                    value: String(format: "%.0f%%", savedPct(service) * 100),
                    subtitle: "cache / (cache + paid)"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Poupança Cache")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", service.cacheSavings))
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundStyle(.green)
                    Text("vs pricing sem cache (all time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
        }
    }
}

private func savedPct(_ service: ClaudeDataService) -> Double {
    let denom = service.cacheSavings + service.allTimeCost
    return denom > 0 ? service.cacheSavings / denom : 0
}

struct DailyCostChartView: View {
    let series: [(date: Date, cost: Double, tokens: Int)]
    @State private var selectedIndex: Int? = nil

    private var maxCost: Double {
        max(series.map { $0.cost }.max() ?? 0, 1)
    }

    private var total: Double {
        series.map { $0.cost }.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Custo diário · 30d")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if let idx = selectedIndex, idx < series.count {
                    let point = series[idx]
                    Text("\(longDate(point.date))  ·  \(String(format: "$%.2f", point.cost))  ·  \(ClaudeDataService.formatTokens(point.tokens)) tok")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.orange)
                } else {
                    Text(String(format: "Σ $%.2f", total))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                let barWidth = max(2, (geo.size.width - CGFloat(series.count - 1) * 2) / CGFloat(max(series.count, 1)))
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(series.enumerated()), id: \.offset) { index, point in
                        let h = CGFloat(point.cost / maxCost) * geo.size.height
                        let isSelected = selectedIndex == index
                        Button {
                            selectedIndex = (selectedIndex == index) ? nil : index
                        } label: {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(point.cost > 0
                                      ? (isSelected ? Color.white : Color.orange)
                                      : Color.white.opacity(0.06))
                                .frame(width: barWidth, height: max(h, 1))
                        }
                        .buttonStyle(.plain)
                        .help("\(longDate(point.date)) — \(String(format: "$%.2f", point.cost)) — \(ClaudeDataService.formatTokens(point.tokens)) tok")
                    }
                }
            }
            .frame(height: 80)

            HStack {
                Text(shortDate(series.first?.date))
                Spacer()
                Text(shortDate(series.last?.date))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func shortDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }
}

struct MetricCardView: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(.orange)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

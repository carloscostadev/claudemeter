import SwiftUI

struct ProjectsTabView: View {
    let service: ClaudeDataService

    var body: some View {
        VStack(spacing: 0) {
            ProjectRankingView(ranking: service.projectRanking)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 16)

            HeatmapView(matrix: service.heatmap, maxValue: service.heatmapMax)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}

struct ProjectRankingView: View {
    let ranking: [(name: String, cost: Double)]

    private var total: Double {
        ranking.reduce(0) { $0 + $1.cost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top Projetos · All Time")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if ranking.isEmpty {
                Text("Sem dados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(ranking.prefix(8).enumerated()), id: \.offset) { _, item in
                    projectRow(name: item.name, cost: item.cost)
                }
            }
        }
    }

    private func projectRow(name: String, cost: Double) -> some View {
        let pct = total > 0 ? cost / total : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "$%.2f", cost))
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(.orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.08))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(pct), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 3)
    }
}

struct HeatmapView: View {
    let matrix: [[Double]] // [weekday 0..6][hour 0..23]
    let maxValue: Double

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Heatmap · hora × dia (all time)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                let labelWidth: CGFloat = 14
                let gap: CGFloat = 1
                let cellW = max(4, (geo.size.width - labelWidth - gap * 23) / 24)
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(0..<7, id: \.self) { day in
                        HStack(spacing: gap) {
                            Text(weekdays[day])
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: labelWidth, alignment: .leading)
                            ForEach(0..<24, id: \.self) { hour in
                                let v = matrix[day][hour]
                                let intensity = maxValue > 0 ? v / maxValue : 0
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(intensity))
                                    .frame(width: cellW, height: cellW)
                            }
                        }
                    }
                    HStack(spacing: gap) {
                        Spacer().frame(width: labelWidth)
                        ForEach([0, 6, 12, 18], id: \.self) { hour in
                            Text("\(hour)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: cellW * 6 + gap * 5, alignment: .leading)
                        }
                    }
                }
            }
            .frame(height: 7 * 14 + 18)
        }
    }

    private func cellColor(_ intensity: Double) -> Color {
        if intensity <= 0 { return Color.white.opacity(0.04) }
        return Color.orange.opacity(0.2 + min(intensity, 1) * 0.8)
    }
}

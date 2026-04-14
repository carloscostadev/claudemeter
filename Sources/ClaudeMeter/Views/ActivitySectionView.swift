import SwiftUI

struct ActivitySectionView: View {
    let entries: [ActivityEntry]

    private var maxCost: Double {
        entries.map(\.cost).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Activity - Today")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(entries) { entry in
                activityRow(entry)
            }
        }
        .padding(.horizontal, 16)
    }

    private func activityRow(_ entry: ActivityEntry) -> some View {
        HStack(spacing: 8) {
            // Color bar proportional to cost
            GeometryReader { geo in
                let fraction = maxCost > 0 ? entry.cost / maxCost : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(entry.category.color)
                    .frame(width: max(geo.size.width * fraction, 4))
            }
            .frame(width: 60, height: 12)

            Text(entry.category.rawValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 90, alignment: .leading)

            Spacer()

            Text(String(format: "$%.2f", entry.cost))
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)

            Text("\(entry.turns) turns")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

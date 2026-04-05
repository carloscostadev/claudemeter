import SwiftUI

struct StatusHeaderView: View {
    let activityState: ActivityState
    let burnRate: String
    let isConnected: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ClaudeMeter")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Connected" : "No Sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            HStack(spacing: 12) {
                Text(activityState.emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 2) {
                    Text(activityState.rawValue)
                        .font(.title3.bold())
                        .foregroundStyle(activityStateColor)
                    Text("\(burnRate) - \(activityState.description)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var activityStateColor: Color {
        switch activityState {
        case .sleep: return .gray
        case .idle: return .blue
        case .active: return .orange
        case .sprint: return .yellow
        }
    }
}

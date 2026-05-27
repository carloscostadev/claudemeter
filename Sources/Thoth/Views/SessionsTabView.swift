import SwiftUI

struct SessionsTabView: View {
    let sessions: [SessionData]

    var body: some View {
        VStack(spacing: 6) {
            if sessions.isEmpty {
                Text("No active sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            } else {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func sessionRow(_ session: SessionData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                Text(session.projectGroup)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PID \(session.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatDuration(session.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

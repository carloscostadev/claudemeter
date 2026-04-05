import SwiftUI

struct PopoverView: View {
    @State var service: ClaudeDataService
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView(
                activityState: service.burnRateTracker.activityState,
                burnRate: service.formattedBurnRate,
                isConnected: service.isConnected
            )

            StatsCardsView(
                burnRate: service.formattedBurnRate,
                totalTokens: service.formattedTotalTokens,
                totalCost: service.formattedCost
            )
            .padding(.bottom, 12)

            ProjectFilterView(
                groups: service.projectGroups,
                selectedGroup: Binding(
                    get: { service.selectedGroup },
                    set: { service.applyFilter($0) }
                )
            )
            .padding(.bottom, 8)

            Picker("", selection: $selectedTab) {
                Text("Models").tag(0)
                Text("Sessions").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ScrollView {
                if selectedTab == 0 {
                    ModelsTabView(entries: service.modelUsage.entries)
                } else {
                    SessionsTabView(sessions: service.activeSessions)
                }
            }
            .frame(maxHeight: 250)

            Divider()
                .padding(.top, 8)

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

import SwiftUI

struct PopoverView: View {
    @State var service: ClaudeDataService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            StatusHeaderView(
                activityState: service.activityState,
                burnRate: service.formattedBurnRate,
                isConnected: service.isConnected,
                todayCost: service.formattedTodayCost
            )

            Divider()
                .padding(.horizontal, 16)

            // Activity - Today
            if !service.todayActivity.sortedEntries.isEmpty {
                ActivitySectionView(entries: service.todayActivity.sortedEntries)
                    .padding(.vertical, 8)

                Divider()
                    .padding(.horizontal, 16)
            }

            // Models - Today
            VStack(alignment: .leading, spacing: 4) {
                Text("Models - Today")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                ModelsTabView(entries: service.modelUsage.entries)
                    .padding(.bottom, 4)
            }

            Divider()
                .padding(.horizontal, 16)

            // Period summaries (7 Days / Month)
            SummaryRowsView(
                weekCost: service.formattedWeekCost,
                weekCalls: service.weekCalls,
                fifteenDaysCost: service.formattedFifteenDaysCost,
                fifteenDaysCalls: service.fifteenDaysCalls,
                monthCost: service.formattedMonthCost,
                monthCalls: service.monthCalls
            )

            Divider()
                .padding(.horizontal, 16)

            // Footer
            HStack {
                Toggle("Abrir ao iniciar", isOn: Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.isEnabled = $0 }
                ))
                .toggleStyle(.checkbox)
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

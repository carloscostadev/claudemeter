import SwiftUI

enum PopoverTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case trends = "Trends"
    case projects = "Projects"
    var id: String { rawValue }
}

struct PopoverView: View {
    @State var service: ClaudeDataService
    @State private var selectedTab: PopoverTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView(
                activityState: service.activityState,
                burnRate: service.formattedBurnRate,
                isConnected: service.isConnected,
                todayCost: service.formattedTodayCost
            )

            TabBarView(selected: $selectedTab)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Divider().padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .overview:
                        OverviewTabView(service: service)
                    case .trends:
                        TrendsTabView(service: service)
                    case .projects:
                        ProjectsTabView(service: service)
                    }
                }
            }
            .frame(maxHeight: 560)

            Divider().padding(.horizontal, 16)

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
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct TabBarView: View {
    @Binding var selected: PopoverTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PopoverTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(selected == tab ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selected == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

struct OverviewTabView: View {
    let service: ClaudeDataService

    var body: some View {
        VStack(spacing: 0) {
            if !service.todayActivity.sortedEntries.isEmpty {
                ActivitySectionView(entries: service.todayActivity.sortedEntries)
                    .padding(.vertical, 8)
                Divider().padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Models - All Time")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                ModelsTabView(entries: service.modelUsage.entries)
                    .padding(.bottom, 4)
            }

            Divider().padding(.horizontal, 16)

            SummaryRowsView(
                todayCost: service.formattedTodayCost,
                todayCalls: service.todayCalls,
                todayTokens: service.todayTokens,
                weekCost: service.formattedWeekCost,
                weekCalls: service.weekCalls,
                weekTokens: service.weekTokens,
                fifteenDaysCost: service.formattedFifteenDaysCost,
                fifteenDaysCalls: service.fifteenDaysCalls,
                fifteenDaysTokens: service.fifteenDaysTokens,
                monthCost: service.formattedMonthCost,
                monthCalls: service.monthCalls,
                monthTokens: service.monthTokens,
                allTimeCost: service.formattedAllTimeCost,
                allTimeCalls: service.allTimeCalls,
                allTimeTokens: service.allTimeTokens
            )
        }
    }
}

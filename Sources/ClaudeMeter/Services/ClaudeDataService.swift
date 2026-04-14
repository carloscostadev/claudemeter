// Sources/ClaudeMeter/Services/ClaudeDataService.swift
import Foundation
import SwiftUI

enum DateFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case allTime = "All Time"

    var id: String { rawValue }

    var startDate: Date? {
        let cal = Calendar.current
        switch self {
        case .today: return cal.startOfDay(for: Date())
        case .last7Days: return cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))
        case .last30Days: return cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date()))
        case .allTime: return nil
        }
    }
}

@Observable
final class ClaudeDataService {
    // Published state
    var activeSessions: [SessionData] = []
    var modelUsage = ModelUsageAggregator()
    var burnRateTracker = BurnRateTracker()
    var projectGroups: [ProjectGroup] = []
    var selectedGroup: String? = nil // nil = All Projects
    var dateFilter: DateFilter = .allTime
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var todayCost: Double = 0
    var isConnected: Bool = false
    var todayActivity = ActivityAggregator()
    var weekCost: Double = 0
    var weekCalls: Int = 0
    var fifteenDaysCost: Double = 0
    var fifteenDaysCalls: Int = 0
    var monthCost: Double = 0
    var monthCalls: Int = 0

    // Internal state
    private var fileOffsets: [String: UInt64] = [:] // JSONL file -> last read position
    private var pollTimer: Timer?
    private var sessionTimer: Timer?

    private let claudeDir: String

    init(claudeDir: String = NSHomeDirectory() + "/.claude") {
        self.claudeDir = claudeDir
    }

    func start() {
        loadSessions()
        loadProjectGroups()
        scanAllSessionData()
        computeTodayCost()
        computePeriodSummaries()
        computeTodayActivity()

        // Poll active session JSONLs every 2s
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollActiveSessions()
        }
        // Scan for new/removed sessions every 10s
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.loadSessions()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        sessionTimer?.invalidate()
    }

    // MARK: - Sessions

    private func loadSessions() {
        let sessionsDir = claudeDir + "/sessions"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) else { return }

        var sessions: [SessionData] = []
        for file in files where file.hasSuffix(".json") {
            let path = sessionsDir + "/" + file
            guard let data = FileManager.default.contents(atPath: path),
                  let session = try? JSONDecoder().decode(SessionData.self, from: data) else { continue }
            if session.isAlive {
                sessions.append(session)
            }
        }
        activeSessions = sessions
        isConnected = !sessions.isEmpty
    }

    // MARK: - Project Groups

    private func loadProjectGroups() {
        let projectsDir = claudeDir + "/projects"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }
        projectGroups = ProjectGroup.groupDirectories(dirs)
    }

    // MARK: - JSONL Scanning

    private func scanAllSessionData() {
        let projectsDir = claudeDir + "/projects"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }

        var aggregator = ModelUsageAggregator()
        var cost = 0.0
        var tokens = 0

        for dir in dirs {
            // Apply project filter
            if let group = selectedGroup {
                let decoded = ProjectGroup.decodePath(dir)
                let dirGroup = ProjectGroup.groupName(from: decoded)
                if dirGroup != group { continue }
            }

            let dirPath = projectsDir + "/" + dir
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = dirPath + "/" + file
                let (usages, _) = parseJSONL(at: filePath, fromOffset: 0)
                var sessionModels: Set<String> = []
                for (usage, model) in usages {
                    aggregator.add(usage: usage, model: model)
                    cost += usage.cost(for: model)
                    tokens += usage.totalTokens
                    sessionModels.insert(model)
                }
                for model in sessionModels {
                    aggregator.incrementSessionCount(for: model)
                }
            }
        }

        modelUsage = aggregator
        totalCost = cost
        totalTokens = tokens
    }

    private func pollActiveSessions() {
        for session in activeSessions {
            let encodedCwd = session.cwd
                .replacingOccurrences(of: "/", with: "-")
            let dirPath = claudeDir + "/projects/" + encodedCwd

            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }

            for file in files where file.hasSuffix(".jsonl") && file.contains(session.sessionId) {
                let filePath = dirPath + "/" + file
                let offset = fileOffsets[filePath] ?? 0
                let (usages, newOffset) = parseJSONL(at: filePath, fromOffset: offset)
                fileOffsets[filePath] = newOffset

                for (usage, model) in usages {
                    modelUsage.add(usage: usage, model: model)
                    totalCost += usage.cost(for: model)
                    totalTokens += usage.totalTokens
                    burnRateTracker.addSample(tokens: usage.totalTokens, at: Date())
                }
            }
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func computeTodayCost() {
        let projectsDir = claudeDir + "/projects"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())
        var cost = 0.0

        for dir in dirs {
            if let group = selectedGroup {
                let decoded = ProjectGroup.decodePath(dir)
                let dirGroup = ProjectGroup.groupName(from: decoded)
                if dirGroup != group { continue }
            }

            let dirPath = projectsDir + "/" + dir
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = dirPath + "/" + file
                let (usages, _) = parseJSONLWithDate(at: filePath, after: todayStart)
                for (usage, model) in usages {
                    cost += usage.cost(for: model)
                }
            }
        }
        todayCost = cost
    }

    private func parseJSONLWithDate(at path: String, after startDate: Date) -> ([(TokenUsage, String)], UInt64) {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return ([], 0) }
        defer { try? fileHandle.close() }

        guard let data = try? fileHandle.readToEnd(), !data.isEmpty else {
            return ([], 0)
        }

        var results: [(TokenUsage, String)] = []
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let model = message["model"] as? String,
                  let usageDict = message["usage"] as? [String: Any],
                  ModelPricing.forModel(model) != nil else { continue }

            if let timestamp = json["timestamp"] as? String,
               let date = Self.isoFormatter.date(from: timestamp),
               date < startDate {
                continue
            }

            let inputTokens = usageDict["input_tokens"] as? Int ?? 0
            let outputTokens = usageDict["output_tokens"] as? Int ?? 0
            let cacheWrite = usageDict["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usageDict["cache_read_input_tokens"] as? Int ?? 0

            results.append((TokenUsage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheWriteTokens: cacheWrite,
                cacheReadTokens: cacheRead
            ), model))
        }
        return (results, 0)
    }

    private func parseJSONL(at path: String, fromOffset: UInt64) -> ([(TokenUsage, String)], UInt64) {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return ([], fromOffset) }
        defer { try? fileHandle.close() }

        fileHandle.seek(toFileOffset: fromOffset)
        guard let data = try? fileHandle.readToEnd(), !data.isEmpty else {
            return ([], fromOffset)
        }

        let newOffset = fromOffset + UInt64(data.count)
        var results: [(TokenUsage, String)] = []
        let filterStart = dateFilter.startDate

        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let model = message["model"] as? String,
                  let usageDict = message["usage"] as? [String: Any] else { continue }

            // Skip synthetic/unknown models
            guard ModelPricing.forModel(model) != nil else { continue }

            // Apply date filter
            if let filterStart = filterStart,
               let timestamp = json["timestamp"] as? String,
               let date = Self.isoFormatter.date(from: timestamp),
               date < filterStart {
                continue
            }

            let inputTokens = usageDict["input_tokens"] as? Int ?? 0
            let outputTokens = usageDict["output_tokens"] as? Int ?? 0
            let cacheWrite = usageDict["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usageDict["cache_read_input_tokens"] as? Int ?? 0

            let usage = TokenUsage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheWriteTokens: cacheWrite,
                cacheReadTokens: cacheRead
            )
            results.append((usage, model))
        }

        return (results, newOffset)
    }

    // MARK: - Activity Tracking

    private func computeTodayActivity() {
        let projectsDir = claudeDir + "/projects"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }

        let todayStart = Calendar.current.startOfDay(for: Date())
        var aggregator = ActivityAggregator()

        for dir in dirs {
            if let group = selectedGroup {
                let decoded = ProjectGroup.decodePath(dir)
                let dirGroup = ProjectGroup.groupName(from: decoded)
                if dirGroup != group { continue }
            }

            let dirPath = projectsDir + "/" + dir
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = dirPath + "/" + file
                parseActivityFromJSONL(at: filePath, after: todayStart, into: &aggregator)
            }
        }
        todayActivity = aggregator
    }

    private func computePeriodSummaries() {
        let projectsDir = claudeDir + "/projects"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: projectsDir) else { return }

        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        let fifteenStart = cal.date(byAdding: .day, value: -15, to: cal.startOfDay(for: Date()))!
        let monthStart = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date()))!

        var wCost = 0.0, wCalls = 0
        var fCost = 0.0, fCalls = 0
        var mCost = 0.0, mCalls = 0

        for dir in dirs {
            let dirPath = projectsDir + "/" + dir
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let filePath = dirPath + "/" + file
                // Parse once for the longest period and bucket into all three
                let (monthUsages, _) = parseJSONLWithDate(at: filePath, after: monthStart)
                for (usage, model) in monthUsages {
                    let cost = usage.cost(for: model)
                    mCost += cost
                    mCalls += 1
                    // Check if also within 15 days / 7 days
                    // Since parseJSONLWithDate doesn't return dates, we re-parse for shorter periods
                }
                let (fifteenUsages, _) = parseJSONLWithDate(at: filePath, after: fifteenStart)
                for (usage, model) in fifteenUsages {
                    fCost += usage.cost(for: model)
                    fCalls += 1
                }
                let (weekUsages, _) = parseJSONLWithDate(at: filePath, after: weekStart)
                for (usage, model) in weekUsages {
                    wCost += usage.cost(for: model)
                    wCalls += 1
                }
            }
        }
        weekCost = wCost
        weekCalls = wCalls
        fifteenDaysCost = fCost
        fifteenDaysCalls = fCalls
        monthCost = mCost
        monthCalls = mCalls
    }

    private func parseActivityFromJSONL(at path: String, after startDate: Date, into aggregator: inout ActivityAggregator) {
        guard let data = FileManager.default.contents(atPath: path) else { return }
        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            // Only process assistant messages
            guard let type = json["type"] as? String, type == "assistant" else { continue }

            // Check timestamp
            if let timestamp = json["timestamp"] as? String,
               let date = Self.isoFormatter.date(from: timestamp),
               date < startDate {
                continue
            }

            guard let message = json["message"] as? [String: Any],
                  let model = message["model"] as? String,
                  let usageDict = message["usage"] as? [String: Any],
                  ModelPricing.forModel(model) != nil else { continue }

            // Extract tool names
            var toolNames: [String] = []
            if let content = message["content"] as? [[String: Any]] {
                for block in content {
                    if let blockType = block["type"] as? String, blockType == "tool_use",
                       let name = block["name"] as? String {
                        toolNames.append(name)
                    }
                }
            }

            let inputTokens = usageDict["input_tokens"] as? Int ?? 0
            let outputTokens = usageDict["output_tokens"] as? Int ?? 0
            let cacheWrite = usageDict["cache_creation_input_tokens"] as? Int ?? 0
            let cacheRead = usageDict["cache_read_input_tokens"] as? Int ?? 0

            let usage = TokenUsage(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheWriteTokens: cacheWrite,
                cacheReadTokens: cacheRead
            )
            let cost = usage.cost(for: model)
            let category = ActivityCategory.classify(tools: toolNames)
            aggregator.add(category: category, cost: cost, tokens: usage.totalTokens)
        }
    }

    func applyFilter(_ group: String?) {
        selectedGroup = group
        fileOffsets.removeAll()
        burnRateTracker = BurnRateTracker()
        scanAllSessionData()
    }

    func applyDateFilter(_ filter: DateFilter) {
        dateFilter = filter
        fileOffsets.removeAll()
        burnRateTracker = BurnRateTracker()
        scanAllSessionData()
    }

    // MARK: - Formatting Helpers

    var activityState: ActivityState {
        ActivityState.from(burnRate: burnRateTracker.currentRate, hasActiveSessions: isConnected)
    }

    var formattedBurnRate: String {
        let rate = burnRateTracker.currentRate
        if rate >= 1000 {
            return String(format: "%.1fk t/s", rate / 1000)
        }
        return String(format: "%.0f t/s", rate)
    }

    var formattedTotalTokens: String {
        if totalTokens >= 1_000_000 {
            return String(format: "%.2fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fk", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var formattedTodayCost: String {
        String(format: "$%.2f", todayCost)
    }

    var formattedWeekCost: String {
        String(format: "$%.2f", weekCost)
    }

    var formattedFifteenDaysCost: String {
        String(format: "$%.2f", fifteenDaysCost)
    }

    var formattedMonthCost: String {
        String(format: "$%.2f", monthCost)
    }

    static func formatCalls(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

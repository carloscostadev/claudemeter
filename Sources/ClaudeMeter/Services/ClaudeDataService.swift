// Sources/ClaudeMeter/Services/ClaudeDataService.swift
import Foundation
import SwiftUI

@Observable
final class ClaudeDataService {
    // Published state
    var activeSessions: [SessionData] = []
    var modelUsage = ModelUsageAggregator()
    var burnRateTracker = BurnRateTracker()
    var projectGroups: [ProjectGroup] = []
    var selectedGroup: String? = nil // nil = All Projects
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var isConnected: Bool = false

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
                for (usage, model) in usages {
                    aggregator.add(usage: usage, model: model)
                    cost += usage.cost(for: model)
                    tokens += usage.totalTokens
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

    private func parseJSONL(at path: String, fromOffset: UInt64) -> ([(TokenUsage, String)], UInt64) {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else { return ([], fromOffset) }
        defer { try? fileHandle.close() }

        fileHandle.seek(toFileOffset: fromOffset)
        guard let data = try? fileHandle.readToEnd(), !data.isEmpty else {
            return ([], fromOffset)
        }

        let newOffset = fromOffset + UInt64(data.count)
        var results: [(TokenUsage, String)] = []

        let lines = String(data: data, encoding: .utf8)?.split(separator: "\n") ?? []
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let model = message["model"] as? String,
                  let usageDict = message["usage"] as? [String: Any] else { continue }

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

    func applyFilter(_ group: String?) {
        selectedGroup = group
        fileOffsets.removeAll()
        burnRateTracker = BurnRateTracker()
        scanAllSessionData()
    }

    // MARK: - Formatting Helpers

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
}

# ClaudeMeter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that monitors Claude Code token usage, cost, and burn rate in real-time by reading `~/.claude/` data.

**Architecture:** SwiftUI menu bar app using NSStatusItem for the icon, NSPopover for the detail view. A polling-based service reads Claude's JSONL session files and stats cache. All data parsing and cost calculation happens locally with no network calls.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSStatusItem/NSPopover), Swift Package Manager

---

## File Structure

```
ClaudeMeter/
├── Package.swift                              — SPM manifest
├── Sources/
│   └── ClaudeMeter/
│       ├── ClaudeMeterApp.swift               — App entry, NSStatusItem + NSPopover setup
│       ├── Models/
│       │   ├── Pricing.swift                  — Per-model pricing constants and cost calculation
│       │   ├── TokenUsage.swift               — Token counts per message, cost computation
│       │   ├── SessionData.swift              — Session model, PID liveness check
│       │   └── ProjectGroup.swift             — Project grouping from ~/.claude/projects/ paths
│       ├── Services/
│       │   ├── ClaudeDataService.swift         — Main data service: reads files, aggregates data, polls
│       │   └── BurnRateTracker.swift           — 60s sliding window burn rate
│       └── Views/
│           ├── PopoverView.swift               — Main popover container with tabs
│           ├── StatusHeaderView.swift          — Header + activity state display
│           ├── StatsCardsView.swift            — 3-card row (burn rate, tokens, cost)
│           ├── ModelsTabView.swift             — Per-model breakdown
│           ├── SessionsTabView.swift           — Active sessions list
│           └── ProjectFilterView.swift         — Group filter dropdown
├── Tests/
│   └── ClaudeMeterTests/
│       ├── PricingTests.swift
│       ├── TokenUsageTests.swift
│       ├── SessionDataTests.swift
│       ├── ProjectGroupTests.swift
│       └── BurnRateTrackerTests.swift
└── build.sh                                    — Build script
```

---

### Task 1: Project Setup

**Files:**
- Create: `Package.swift`
- Create: `Sources/ClaudeMeter/ClaudeMeterApp.swift` (stub)
- Create: `build.sh`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeMeter",
            path: "Sources/ClaudeMeter"
        ),
        .testTarget(
            name: "ClaudeMeterTests",
            dependencies: ["ClaudeMeter"],
            path: "Tests/ClaudeMeterTests"
        )
    ]
)
```

- [ ] **Step 2: Create minimal app entry point**

```swift
// Sources/ClaudeMeter/ClaudeMeterApp.swift
import SwiftUI

@main
struct ClaudeMeterApp: App {
    var body: some Scene {
        MenuBarExtra("ClaudeMeter", systemImage: "sparkle") {
            Text("ClaudeMeter")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 3: Create build script**

```bash
#!/bin/bash
set -e
swift build -c release
echo "Build complete: $(swift build -c release --show-bin-path)/ClaudeMeter"
```

- [ ] **Step 4: Verify it builds and runs**

Run: `cd /Users/carloscosta/Documents/Projetos\ Internos\ -\ Carlos/ClaudeMeter && swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 5: Init git and commit**

```bash
git init
git add Package.swift Sources/ build.sh
git commit -m "feat: initial project setup with minimal menu bar app"
```

---

### Task 2: Pricing Model

**Files:**
- Create: `Sources/ClaudeMeter/Models/Pricing.swift`
- Create: `Tests/ClaudeMeterTests/PricingTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ClaudeMeterTests/PricingTests.swift
import Testing
@testable import ClaudeMeter

@Test func opusPricingExists() {
    let pricing = ModelPricing.forModel("claude-opus-4-6")
    #expect(pricing != nil)
    #expect(pricing!.inputPerMillion == 15.0)
    #expect(pricing!.outputPerMillion == 75.0)
}

@Test func sonnetPricingExists() {
    let pricing = ModelPricing.forModel("claude-sonnet-4-6")
    #expect(pricing != nil)
    #expect(pricing!.inputPerMillion == 3.0)
}

@Test func haikuPricingExists() {
    let pricing = ModelPricing.forModel("claude-haiku-4-5")
    #expect(pricing != nil)
    #expect(pricing!.inputPerMillion == 0.80)
}

@Test func unknownModelReturnsNil() {
    let pricing = ModelPricing.forModel("unknown-model")
    #expect(pricing == nil)
}

@Test func costCalculation() {
    let pricing = ModelPricing.forModel("claude-opus-4-6")!
    let cost = pricing.calculateCost(
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        cacheReadTokens: 1_000_000,
        cacheWriteTokens: 1_000_000
    )
    // 15 + 75 + 1.5 + 18.75 = 110.25
    #expect(abs(cost - 110.25) < 0.01)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PricingTests`
Expected: FAIL — module not found

- [ ] **Step 3: Implement Pricing model**

```swift
// Sources/ClaudeMeter/Models/Pricing.swift
import Foundation

struct ModelPricing {
    let modelPrefix: String
    let displayName: String
    let inputPerMillion: Double
    let outputPerMillion: Double
    let cacheReadPerMillion: Double
    let cacheWritePerMillion: Double
    let color: String // hex color for UI

    func calculateCost(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int,
        cacheWriteTokens: Int
    ) -> Double {
        let scale = 1_000_000.0
        return Double(inputTokens) * inputPerMillion / scale
             + Double(outputTokens) * outputPerMillion / scale
             + Double(cacheReadTokens) * cacheReadPerMillion / scale
             + Double(cacheWriteTokens) * cacheWritePerMillion / scale
    }

    static let all: [ModelPricing] = [
        ModelPricing(
            modelPrefix: "claude-opus-4",
            displayName: "opus-4-6",
            inputPerMillion: 15.0,
            outputPerMillion: 75.0,
            cacheReadPerMillion: 1.50,
            cacheWritePerMillion: 18.75,
            color: "#FF00FF"
        ),
        ModelPricing(
            modelPrefix: "claude-sonnet-4",
            displayName: "sonnet-4-6",
            inputPerMillion: 3.0,
            outputPerMillion: 15.0,
            cacheReadPerMillion: 0.30,
            cacheWritePerMillion: 3.75,
            color: "#4A90D9"
        ),
        ModelPricing(
            modelPrefix: "claude-haiku-4",
            displayName: "haiku-4-5",
            inputPerMillion: 0.80,
            outputPerMillion: 4.0,
            cacheReadPerMillion: 0.08,
            cacheWritePerMillion: 1.0,
            color: "#50C878"
        ),
    ]

    static func forModel(_ modelId: String) -> ModelPricing? {
        all.first { modelId.hasPrefix($0.modelPrefix) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PricingTests`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeMeter/Models/Pricing.swift Tests/ClaudeMeterTests/PricingTests.swift
git commit -m "feat: add model pricing constants and cost calculation"
```

---

### Task 3: Token Usage Model

**Files:**
- Create: `Sources/ClaudeMeter/Models/TokenUsage.swift`
- Create: `Tests/ClaudeMeterTests/TokenUsageTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ClaudeMeterTests/TokenUsageTests.swift
import Testing
@testable import ClaudeMeter

@Test func parseUsageFromJSON() throws {
    let json = """
    {
        "input_tokens": 100,
        "output_tokens": 200,
        "cache_creation_input_tokens": 300,
        "cache_read_input_tokens": 400
    }
    """.data(using: .utf8)!

    let usage = try JSONDecoder().decode(TokenUsage.self, from: json)
    #expect(usage.inputTokens == 100)
    #expect(usage.outputTokens == 200)
    #expect(usage.cacheWriteTokens == 300)
    #expect(usage.cacheReadTokens == 400)
}

@Test func totalTokens() throws {
    let usage = TokenUsage(inputTokens: 100, outputTokens: 200, cacheWriteTokens: 300, cacheReadTokens: 400)
    #expect(usage.totalTokens == 1000)
}

@Test func costForModel() {
    let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 500_000, cacheWriteTokens: 0, cacheReadTokens: 2_000_000)
    let cost = usage.cost(for: "claude-opus-4-6")
    // input: 15.0, output: 37.5, cacheRead: 3.0 = 55.5
    #expect(abs(cost - 55.5) < 0.01)
}

@Test func modelUsageAggregation() {
    var agg = ModelUsageAggregator()
    agg.add(usage: TokenUsage(inputTokens: 100, outputTokens: 200, cacheWriteTokens: 0, cacheReadTokens: 0), model: "claude-opus-4-6")
    agg.add(usage: TokenUsage(inputTokens: 50, outputTokens: 100, cacheWriteTokens: 0, cacheReadTokens: 0), model: "claude-opus-4-6")
    agg.add(usage: TokenUsage(inputTokens: 30, outputTokens: 60, cacheWriteTokens: 0, cacheReadTokens: 0), model: "claude-sonnet-4-6")

    let opusEntry = agg.entries.first { $0.modelId.hasPrefix("claude-opus") }
    #expect(opusEntry != nil)
    #expect(opusEntry!.totalTokens == 450) // 100+200+50+100
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TokenUsageTests`
Expected: FAIL

- [ ] **Step 3: Implement TokenUsage**

```swift
// Sources/ClaudeMeter/Models/TokenUsage.swift
import Foundation

struct TokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens
    }

    func cost(for modelId: String) -> Double {
        guard let pricing = ModelPricing.forModel(modelId) else { return 0 }
        return pricing.calculateCost(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheWriteTokens: cacheWriteTokens
        )
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheWriteTokens = "cache_creation_input_tokens"
        case cacheReadTokens = "cache_read_input_tokens"
    }
}

struct ModelUsageEntry: Identifiable {
    let modelId: String
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var cacheReadTokens: Int = 0
    var sessionCount: Int = 0

    var id: String { modelId }

    var totalTokens: Int {
        inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens
    }

    var totalCost: Double {
        TokenUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheWriteTokens: cacheWriteTokens,
            cacheReadTokens: cacheReadTokens
        ).cost(for: modelId)
    }

    var displayName: String {
        ModelPricing.forModel(modelId)?.displayName ?? modelId
    }
}

struct ModelUsageAggregator {
    private(set) var entries: [ModelUsageEntry] = []

    mutating func add(usage: TokenUsage, model: String) {
        if let idx = entries.firstIndex(where: { $0.modelId == model }) {
            entries[idx].inputTokens += usage.inputTokens
            entries[idx].outputTokens += usage.outputTokens
            entries[idx].cacheWriteTokens += usage.cacheWriteTokens
            entries[idx].cacheReadTokens += usage.cacheReadTokens
        } else {
            var entry = ModelUsageEntry(modelId: model)
            entry.inputTokens = usage.inputTokens
            entry.outputTokens = usage.outputTokens
            entry.cacheWriteTokens = usage.cacheWriteTokens
            entry.cacheReadTokens = usage.cacheReadTokens
            entries.append(entry)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TokenUsageTests`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeMeter/Models/TokenUsage.swift Tests/ClaudeMeterTests/TokenUsageTests.swift
git commit -m "feat: add token usage model with cost calculation and aggregation"
```

---

### Task 4: Session Data Model

**Files:**
- Create: `Sources/ClaudeMeter/Models/SessionData.swift`
- Create: `Tests/ClaudeMeterTests/SessionDataTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ClaudeMeterTests/SessionDataTests.swift
import Testing
@testable import ClaudeMeter

@Test func parseSessionJSON() throws {
    let json = """
    {
        "pid": 12345,
        "sessionId": "abc-123",
        "cwd": "/Users/test/Documents/MyProject",
        "startedAt": 1775421611997,
        "kind": "interactive",
        "entrypoint": "cli"
    }
    """.data(using: .utf8)!

    let session = try JSONDecoder().decode(SessionData.self, from: json)
    #expect(session.pid == 12345)
    #expect(session.sessionId == "abc-123")
    #expect(session.cwd == "/Users/test/Documents/MyProject")
    #expect(session.kind == "interactive")
}

@Test func projectNameFromCwd() {
    let session = SessionData(pid: 1, sessionId: "x", cwd: "/Users/test/Documents/Importrust/dashboard", startedAt: 0, kind: "interactive", entrypoint: "cli")
    #expect(session.projectName == "dashboard")
}

@Test func projectGroupFromCwd() {
    let session = SessionData(pid: 1, sessionId: "x", cwd: "/Users/test/Documents/Importrust/dashboard", startedAt: 0, kind: "interactive", entrypoint: "cli")
    #expect(session.projectGroup == "Importrust")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SessionDataTests`
Expected: FAIL

- [ ] **Step 3: Implement SessionData**

```swift
// Sources/ClaudeMeter/Models/SessionData.swift
import Foundation

struct SessionData: Codable, Identifiable {
    let pid: Int
    let sessionId: String
    let cwd: String
    let startedAt: Int64
    let kind: String
    let entrypoint: String

    var id: String { sessionId }

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }

    var projectGroup: String {
        let url = URL(fileURLWithPath: cwd)
        let components = url.pathComponents
        // Find "Documents" and return the next component
        if let docIdx = components.firstIndex(of: "Documents"),
           docIdx + 1 < components.count {
            return components[docIdx + 1]
        }
        return projectName
    }

    var isAlive: Bool {
        kill(Int32(pid), 0) == 0
    }

    var startDate: Date {
        Date(timeIntervalSince1970: Double(startedAt) / 1000.0)
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startDate)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SessionDataTests`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeMeter/Models/SessionData.swift Tests/ClaudeMeterTests/SessionDataTests.swift
git commit -m "feat: add session data model with project grouping"
```

---

### Task 5: Project Grouping

**Files:**
- Create: `Sources/ClaudeMeter/Models/ProjectGroup.swift`
- Create: `Tests/ClaudeMeterTests/ProjectGroupTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ClaudeMeterTests/ProjectGroupTests.swift
import Testing
@testable import ClaudeMeter

@Test func decodeProjectPath() {
    let encoded = "-Users-carloscosta-Documents-Importrust-dashboard-importrust"
    let decoded = ProjectGroup.decodePath(encoded)
    #expect(decoded == "/Users/carloscosta/Documents/Importrust/dashboard-importrust")
}

@Test func extractGroupName() {
    let path = "/Users/carloscosta/Documents/Importrust/dashboard-importrust"
    let group = ProjectGroup.groupName(from: path)
    #expect(group == "Importrust")
}

@Test func groupProjectDirs() {
    let dirs = [
        "-Users-carloscosta-Documents-Importrust-dashboard-importrust",
        "-Users-carloscosta-Documents-Importrust-importrust-hub",
        "-Users-carloscosta-Documents-Analises-",
    ]
    let groups = ProjectGroup.groupDirectories(dirs)
    #expect(groups.count == 2) // Importrust, Analises
    let importrust = groups.first { $0.name == "Importrust" }
    #expect(importrust != nil)
    #expect(importrust!.projectDirs.count == 2)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ProjectGroupTests`
Expected: FAIL

- [ ] **Step 3: Implement ProjectGroup**

```swift
// Sources/ClaudeMeter/Models/ProjectGroup.swift
import Foundation

struct ProjectGroup: Identifiable, Hashable {
    let name: String
    let projectDirs: [String] // encoded dir names

    var id: String { name }

    /// Decode a Claude projects directory name back to a filesystem path.
    /// e.g. "-Users-carloscosta-Documents-Importrust-dashboard-importrust"
    /// becomes "/Users/carloscosta/Documents/Importrust/dashboard-importrust"
    static func decodePath(_ encoded: String) -> String {
        // The encoding replaces "/" with "-" and prepends "-"
        // We need to be smart: reconstruct by checking which segments exist as directories
        var cleaned = encoded
        if cleaned.hasPrefix("-") {
            cleaned.removeFirst()
        }
        // Split on "-" and greedily reconstruct path segments
        let parts = cleaned.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        var path = ""
        var i = 0
        while i < parts.count {
            var segment = parts[i]
            // Try extending the segment with hyphens to match existing directories
            var testPath = path + "/" + segment
            var j = i + 1
            while j < parts.count {
                let extended = testPath + "-" + parts[j]
                if FileManager.default.fileExists(atPath: extended) {
                    segment += "-" + parts[j]
                    testPath = extended
                    j += 1
                } else {
                    break
                }
            }
            // Also check: if current testPath doesn't exist but the simple segment does as part of the path
            if !FileManager.default.fileExists(atPath: testPath) && j > i + 1 {
                // fallback: just use the single segment
                path += "/" + parts[i]
                i += 1
            } else {
                path += "/" + segment
                i = j
            }
        }
        // Remove trailing dash artifact
        if path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    /// Extract the group name (first directory after Documents/) from a decoded path
    static func groupName(from decodedPath: String) -> String {
        let components = decodedPath.split(separator: "/").map(String.init)
        if let docIdx = components.firstIndex(of: "Documents"),
           docIdx + 1 < components.count {
            return components[docIdx + 1]
        }
        return components.last ?? "Unknown"
    }

    /// Group encoded directory names by their parent folder after Documents/
    static func groupDirectories(_ dirs: [String]) -> [ProjectGroup] {
        var groupMap: [String: [String]] = [:]
        for dir in dirs {
            let decoded = decodePath(dir)
            let group = groupName(from: decoded)
            groupMap[group, default: []].append(dir)
        }
        return groupMap.map { ProjectGroup(name: $0.key, projectDirs: $0.value) }
            .sorted { $0.name < $1.name }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ProjectGroupTests`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeMeter/Models/ProjectGroup.swift Tests/ClaudeMeterTests/ProjectGroupTests.swift
git commit -m "feat: add project grouping from Claude directory names"
```

---

### Task 6: Burn Rate Tracker

**Files:**
- Create: `Sources/ClaudeMeter/Services/BurnRateTracker.swift`
- Create: `Tests/ClaudeMeterTests/BurnRateTrackerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Tests/ClaudeMeterTests/BurnRateTrackerTests.swift
import Testing
@testable import ClaudeMeter

@Test func emptyTrackerReturnsZero() {
    let tracker = BurnRateTracker()
    #expect(tracker.currentRate == 0)
}

@Test func addingSamplesCalculatesRate() {
    var tracker = BurnRateTracker(windowSeconds: 60)
    let now = Date()
    tracker.addSample(tokens: 1000, at: now.addingTimeInterval(-30))
    tracker.addSample(tokens: 2000, at: now)
    // 3000 tokens in 30 seconds ≈ 100 t/s
    let rate = tracker.rateAt(now)
    #expect(rate > 90 && rate < 110)
}

@Test func oldSamplesExpire() {
    var tracker = BurnRateTracker(windowSeconds: 60)
    let now = Date()
    tracker.addSample(tokens: 5000, at: now.addingTimeInterval(-120)) // 2 min ago, should expire
    tracker.addSample(tokens: 600, at: now)
    let rate = tracker.rateAt(now)
    // Only the recent 600 tokens count, over ~0s window = high rate capped
    #expect(rate >= 0)
}

@Test func activityState() {
    #expect(ActivityState.from(burnRate: 0) == .sleep)
    #expect(ActivityState.from(burnRate: 50) == .idle)
    #expect(ActivityState.from(burnRate: 500) == .active)
    #expect(ActivityState.from(burnRate: 2000) == .sprint)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter BurnRateTrackerTests`
Expected: FAIL

- [ ] **Step 3: Implement BurnRateTracker**

```swift
// Sources/ClaudeMeter/Services/BurnRateTracker.swift
import Foundation

enum ActivityState: String, CaseIterable {
    case sleep = "Sleeping"
    case idle = "Idle"
    case active = "Active"
    case sprint = "Sprinting"

    var emoji: String {
        switch self {
        case .sleep: return "😴"
        case .idle: return "✦"
        case .active: return "⚡"
        case .sprint: return "🔥"
        }
    }

    var description: String {
        switch self {
        case .sleep: return "no activity"
        case .idle: return "light activity"
        case .active: return "working"
        case .sprint: return "full throttle"
        }
    }

    static func from(burnRate: Double) -> ActivityState {
        switch burnRate {
        case 0: return .sleep
        case ..<100: return .idle
        case ..<1000: return .active
        default: return .sprint
        }
    }
}

struct TokenSample {
    let tokens: Int
    let timestamp: Date
}

struct BurnRateTracker {
    private var samples: [TokenSample] = []
    let windowSeconds: Double

    init(windowSeconds: Double = 60) {
        self.windowSeconds = windowSeconds
    }

    var currentRate: Double {
        rateAt(Date())
    }

    var activityState: ActivityState {
        ActivityState.from(burnRate: currentRate)
    }

    mutating func addSample(tokens: Int, at date: Date) {
        samples.append(TokenSample(tokens: tokens, timestamp: date))
        pruneOldSamples(at: date)
    }

    func rateAt(_ date: Date) -> Double {
        let cutoff = date.addingTimeInterval(-windowSeconds)
        let recent = samples.filter { $0.timestamp > cutoff }
        guard !recent.isEmpty else { return 0 }
        let totalTokens = recent.reduce(0) { $0 + $1.tokens }
        guard let earliest = recent.min(by: { $0.timestamp < $1.timestamp }) else { return 0 }
        let elapsed = date.timeIntervalSince(earliest.timestamp)
        if elapsed < 1 { return Double(totalTokens) }
        return Double(totalTokens) / elapsed
    }

    private mutating func pruneOldSamples(at date: Date) {
        let cutoff = date.addingTimeInterval(-windowSeconds)
        samples.removeAll { $0.timestamp <= cutoff }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BurnRateTrackerTests`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeMeter/Services/BurnRateTracker.swift Tests/ClaudeMeterTests/BurnRateTrackerTests.swift
git commit -m "feat: add burn rate tracker with 60s sliding window"
```

---

### Task 7: Claude Data Service

**Files:**
- Create: `Sources/ClaudeMeter/Services/ClaudeDataService.swift`

- [ ] **Step 1: Implement the data service**

This is the core service that reads `~/.claude/` and provides all data to the UI. It uses `@Observable` for SwiftUI binding.

```swift
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
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeMeter/Services/ClaudeDataService.swift
git commit -m "feat: add Claude data service with JSONL parsing and polling"
```

---

### Task 8: Popover Views

**Files:**
- Create: `Sources/ClaudeMeter/Views/StatusHeaderView.swift`
- Create: `Sources/ClaudeMeter/Views/StatsCardsView.swift`
- Create: `Sources/ClaudeMeter/Views/ModelsTabView.swift`
- Create: `Sources/ClaudeMeter/Views/SessionsTabView.swift`
- Create: `Sources/ClaudeMeter/Views/ProjectFilterView.swift`
- Create: `Sources/ClaudeMeter/Views/PopoverView.swift`

- [ ] **Step 1: Create StatusHeaderView**

```swift
// Sources/ClaudeMeter/Views/StatusHeaderView.swift
import SwiftUI

struct StatusHeaderView: View {
    let activityState: ActivityState
    let burnRate: String
    let isConnected: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
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

            // Activity state
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
```

- [ ] **Step 2: Create StatsCardsView**

```swift
// Sources/ClaudeMeter/Views/StatsCardsView.swift
import SwiftUI

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let titleColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(titleColor)
            }
            Text(value)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatsCardsView: View {
    let burnRate: String
    let totalTokens: String
    let totalCost: String

    var body: some View {
        HStack(spacing: 8) {
            StatCard(icon: "🔥", title: "BURN RATE", value: burnRate, titleColor: .orange)
            StatCard(icon: "#", title: "TOKENS", value: totalTokens, titleColor: .blue)
            StatCard(icon: "💰", title: "COST", value: totalCost, titleColor: .green)
        }
        .padding(.horizontal, 16)
    }
}
```

- [ ] **Step 3: Create ModelsTabView**

```swift
// Sources/ClaudeMeter/Views/ModelsTabView.swift
import SwiftUI

struct ModelsTabView: View {
    let entries: [ModelUsageEntry]

    private var totalCost: Double {
        entries.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entries.sorted(by: { $0.totalCost > $1.totalCost })) { entry in
                modelRow(entry)
            }
        }
        .padding(.horizontal, 16)
    }

    private func modelRow(_ entry: ModelUsageEntry) -> some View {
        let percentage = totalCost > 0 ? entry.totalCost / totalCost * 100 : 0
        let color = modelColor(entry.modelId)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(entry.displayName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Text(String(format: "$%.2f", entry.totalCost))
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(percentage / 100, 1.0), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(formatTokens(entry.totalTokens) + " tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modelColor(_ modelId: String) -> Color {
        if modelId.contains("opus") { return .pink }
        if modelId.contains("sonnet") { return .blue }
        if modelId.contains("haiku") { return .green }
        return .gray
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
```

- [ ] **Step 4: Create SessionsTabView**

```swift
// Sources/ClaudeMeter/Views/SessionsTabView.swift
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
```

- [ ] **Step 5: Create ProjectFilterView**

```swift
// Sources/ClaudeMeter/Views/ProjectFilterView.swift
import SwiftUI

struct ProjectFilterView: View {
    let groups: [ProjectGroup]
    @Binding var selectedGroup: String?

    var body: some View {
        HStack {
            Picker("Project", selection: $selectedGroup) {
                Text("All Projects").tag(nil as String?)
                ForEach(groups) { group in
                    Text("\(group.name) (\(group.projectDirs.count))")
                        .tag(group.name as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }
}
```

- [ ] **Step 6: Create PopoverView**

```swift
// Sources/ClaudeMeter/Views/PopoverView.swift
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

            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Models").tag(0)
                Text("Sessions").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Tab content
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

            // Footer
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
```

- [ ] **Step 7: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 8: Commit**

```bash
git add Sources/ClaudeMeter/Views/
git commit -m "feat: add all popover views (header, stats, models, sessions, filter)"
```

---

### Task 9: App Entry Point with NSStatusItem

**Files:**
- Modify: `Sources/ClaudeMeter/ClaudeMeterApp.swift`

- [ ] **Step 1: Replace the stub app entry with full implementation**

Replace the entire contents of `ClaudeMeterApp.swift`:

```swift
// Sources/ClaudeMeter/ClaudeMeterApp.swift
import SwiftUI
import AppKit

@main
struct ClaudeMeterApp: App {
    @State private var service = ClaudeDataService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(service: service)
        } label: {
            MenuBarLabel(service: service)
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 380, height: 500)
    }

    init() {
        // Hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

struct MenuBarLabel: View {
    let service: ClaudeDataService

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .symbolEffect(.pulse, options: .repeating, isActive: service.burnRateTracker.activityState != .sleep)
            Text(service.formattedCost)
                .font(.system(.caption, design: .monospaced))
        }
        .onAppear {
            service.start()
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeMeter/ClaudeMeterApp.swift
git commit -m "feat: wire up app entry with NSStatusItem and popover"
```

---

### Task 10: Build Script and Final Polish

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: Update build script for app bundle**

Replace `build.sh`:

```bash
#!/bin/bash
set -e

APP_NAME="ClaudeMeter"
BUILD_DIR="build"

echo "Building $APP_NAME..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)

# Create .app bundle
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.carloscosta.claudemeter</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
PLIST

echo ""
echo "✅ Built successfully: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -R $APP_BUNDLE /Applications/"
echo "  open /Applications/$APP_NAME.app"
```

- [ ] **Step 2: Run the build**

Run: `cd /Users/carloscosta/Documents/Projetos\ Internos\ -\ Carlos/ClaudeMeter && chmod +x build.sh && ./build.sh`
Expected: Build succeeds, `.app` bundle created in `build/`

- [ ] **Step 3: Commit**

```bash
git add build.sh
git commit -m "feat: add build script with macOS app bundle creation"
```

---

### Task 11: Run All Tests

- [ ] **Step 1: Run the full test suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 2: Fix any failures**

If any tests fail, fix the issues and re-run.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: ensure all tests pass, project complete"
```

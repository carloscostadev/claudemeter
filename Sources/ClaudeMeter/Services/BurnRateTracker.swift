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

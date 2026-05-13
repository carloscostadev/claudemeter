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
        if modelId.hasPrefix("claude-") {
            return String(modelId.dropFirst("claude-".count))
        }
        return modelId
    }
}

struct ModelUsageAggregator {
    private(set) var entries: [ModelUsageEntry] = []

    mutating func incrementSessionCount(for model: String) {
        if let idx = entries.firstIndex(where: { $0.modelId == model }) {
            entries[idx].sessionCount += 1
        }
    }

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

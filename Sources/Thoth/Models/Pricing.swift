// Sources/Thoth/Models/Pricing.swift
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
        // Opus pricing is identical across 4-6 and 4-7 per Anthropic's current rate card.
        // Listed explicitly so that a future price change for one version won't affect the other.
        ModelPricing(
            modelPrefix: "claude-opus-4-7",
            displayName: "opus-4-7",
            inputPerMillion: 15.0,
            outputPerMillion: 75.0,
            cacheReadPerMillion: 1.50,
            cacheWritePerMillion: 18.75,
            color: "#FF00FF"
        ),
        ModelPricing(
            modelPrefix: "claude-opus-4-6",
            displayName: "opus-4-6",
            inputPerMillion: 15.0,
            outputPerMillion: 75.0,
            cacheReadPerMillion: 1.50,
            cacheWritePerMillion: 18.75,
            color: "#FF00FF"
        ),
        ModelPricing(
            modelPrefix: "claude-opus-4",
            displayName: "opus-4",
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
        // Specific prefixes (e.g. claude-opus-4-7) come before generic (claude-opus-4).
        all.first { modelId.hasPrefix($0.modelPrefix) }
    }
}

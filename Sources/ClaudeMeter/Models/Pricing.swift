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

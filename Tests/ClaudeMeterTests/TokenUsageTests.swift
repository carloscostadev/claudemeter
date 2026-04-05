// Tests/ClaudeMeterTests/TokenUsageTests.swift
import Testing
import Foundation
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

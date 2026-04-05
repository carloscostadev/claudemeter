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

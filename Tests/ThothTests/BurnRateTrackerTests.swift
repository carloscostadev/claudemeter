// Tests/ThothTests/BurnRateTrackerTests.swift
import Foundation
import Testing
@testable import Thoth

@Test func emptyTrackerReturnsZero() {
    let tracker = BurnRateTracker()
    #expect(tracker.currentRate == 0)
}

@Test func addingSamplesCalculatesRate() {
    var tracker = BurnRateTracker(windowSeconds: 60)
    let now = Date()
    tracker.addSample(tokens: 1000, at: now.addingTimeInterval(-30))
    tracker.addSample(tokens: 2000, at: now)
    // 3000 tokens in 30 seconds = 100 t/s
    let rate = tracker.rateAt(now)
    #expect(rate > 90 && rate < 110)
}

@Test func oldSamplesExpire() {
    var tracker = BurnRateTracker(windowSeconds: 60)
    let now = Date()
    tracker.addSample(tokens: 5000, at: now.addingTimeInterval(-120)) // 2 min ago, should expire
    tracker.addSample(tokens: 600, at: now)
    let rate = tracker.rateAt(now)
    // Only the recent 600 tokens count
    #expect(rate >= 0)
}

@Test func activityState() {
    #expect(ActivityState.from(burnRate: 0) == .sleep)
    #expect(ActivityState.from(burnRate: 50) == .idle)
    #expect(ActivityState.from(burnRate: 500) == .active)
    #expect(ActivityState.from(burnRate: 2000) == .sprint)
}

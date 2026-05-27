// Tests/ThothTests/SessionDataTests.swift
import Testing
import Foundation
@testable import Thoth

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
    let session = SessionData(pid: 1, sessionId: "x", cwd: "/Users/test/Documents/Acme/dashboard", startedAt: 0, kind: "interactive", entrypoint: "cli")
    #expect(session.projectName == "dashboard")
}

@Test func projectGroupFromCwd() {
    let session = SessionData(pid: 1, sessionId: "x", cwd: "/Users/test/Documents/Acme/dashboard", startedAt: 0, kind: "interactive", entrypoint: "cli")
    #expect(session.projectGroup == "Acme")
}

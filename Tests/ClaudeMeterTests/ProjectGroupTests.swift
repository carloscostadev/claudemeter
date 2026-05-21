// Tests/ClaudeMeterTests/ProjectGroupTests.swift
import Testing
@testable import ClaudeMeter

@Test func decodeProjectPath() {
    let encoded = "-Users-alice-Documents-Acme-dashboard-frontend"
    let decoded = ProjectGroup.decodePath(encoded)
    #expect(decoded == "/Users/alice/Documents/Acme/dashboard-frontend")
}

@Test func extractGroupName() {
    let path = "/Users/alice/Documents/Acme/dashboard-frontend"
    let group = ProjectGroup.groupName(from: path)
    #expect(group == "Acme")
}

@Test func groupProjectDirs() {
    let dirs = [
        "-Users-alice-Documents-Acme-dashboard-frontend",
        "-Users-alice-Documents-Acme-acme-hub",
        "-Users-alice-Documents-Personal-",
    ]
    let groups = ProjectGroup.groupDirectories(dirs)
    #expect(groups.count == 2) // Acme, Personal
    let acme = groups.first { $0.name == "Acme" }
    #expect(acme != nil)
    #expect(acme!.projectDirs.count == 2)
}

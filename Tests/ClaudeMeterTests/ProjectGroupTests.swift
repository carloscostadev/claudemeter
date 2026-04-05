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

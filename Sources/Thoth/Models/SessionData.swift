// Sources/Thoth/Models/SessionData.swift
import Foundation

struct SessionData: Codable, Identifiable {
    let pid: Int
    let sessionId: String
    let cwd: String
    let startedAt: Int64
    let kind: String
    let entrypoint: String

    var id: String { sessionId }

    var projectName: String {
        URL(fileURLWithPath: cwd).lastPathComponent
    }

    var projectGroup: String {
        let url = URL(fileURLWithPath: cwd)
        let components = url.pathComponents
        // Find "Documents" and return the next component
        if let docIdx = components.firstIndex(of: "Documents"),
           docIdx + 1 < components.count {
            return components[docIdx + 1]
        }
        return projectName
    }

    var isAlive: Bool {
        kill(Int32(pid), 0) == 0
    }

    var startDate: Date {
        Date(timeIntervalSince1970: Double(startedAt) / 1000.0)
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startDate)
    }
}

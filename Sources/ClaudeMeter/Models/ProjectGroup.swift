// Sources/ClaudeMeter/Models/ProjectGroup.swift
import Foundation

struct ProjectGroup: Identifiable, Hashable {
    let name: String
    let projectDirs: [String] // encoded dir names

    var id: String { name }

    /// Decode a Claude projects directory name back to a filesystem path.
    ///
    /// The encoding replaces "/" with "-" and prepends "-", so
    /// "/Users/carloscosta/Documents/Importrust/dashboard-importrust"
    /// becomes "-Users-carloscosta-Documents-Importrust-dashboard-importrust".
    ///
    /// This implementation uses a heuristic for the common path structure
    /// `/Users/<username>/Documents/<group>/<project>`:
    ///   - The first 3 segments (Users, username, Documents) never contain hyphens.
    ///   - The 4th segment is the group name (assumed to have no hyphens in its real name).
    ///   - Everything after the 4th segment is the project name (may contain hyphens).
    ///
    /// Falls back to the greedy filesystem-based approach for unrecognised structures.
    static func decodePath(_ encoded: String) -> String {
        var cleaned = encoded
        if cleaned.hasPrefix("-") { cleaned.removeFirst() }
        if cleaned.hasSuffix("-") { cleaned.removeLast() }

        // Fast path for the standard ~/Documents structure:
        // parts[0] = "Users", parts[1] = username, parts[2] = "Documents",
        // parts[3] = group (no hyphens assumed), parts[4...] = project segments
        let parts = cleaned.split(separator: "-", omittingEmptySubsequences: false).map(String.init)

        if parts.count >= 3,
           parts[0] == "Users",
           parts[2] == "Documents" {
            let prefix = "/\(parts[0])/\(parts[1])/\(parts[2])"
            guard parts.count >= 4 else { return prefix }
            let group = parts[3]
            guard parts.count >= 5 else { return "\(prefix)/\(group)" }
            let project = parts[4...].joined(separator: "-")
            return "\(prefix)/\(group)/\(project)"
        }

        // Fallback: greedy filesystem-based reconstruction
        var path = ""
        var i = 0
        while i < parts.count {
            var segment = parts[i]
            var testPath = path + "/" + segment
            var j = i + 1
            while j < parts.count {
                let extended = testPath + "-" + parts[j]
                if FileManager.default.fileExists(atPath: extended) {
                    segment += "-" + parts[j]
                    testPath = extended
                    j += 1
                } else {
                    break
                }
            }
            if !FileManager.default.fileExists(atPath: testPath) && j > i + 1 {
                path += "/" + parts[i]
                i += 1
            } else {
                path += "/" + segment
                i = j
            }
        }
        return path
    }

    /// Extract the group name (first directory after Documents/) from a decoded path.
    static func groupName(from decodedPath: String) -> String {
        let components = decodedPath.split(separator: "/").map(String.init)
        if let docIdx = components.firstIndex(of: "Documents"),
           docIdx + 1 < components.count {
            return components[docIdx + 1]
        }
        return components.last ?? "Unknown"
    }

    /// Group encoded directory names by their parent folder after Documents/.
    static func groupDirectories(_ dirs: [String]) -> [ProjectGroup] {
        var groupMap: [String: [String]] = [:]
        for dir in dirs {
            let decoded = decodePath(dir)
            let group = groupName(from: decoded)
            groupMap[group, default: []].append(dir)
        }
        return groupMap.map { ProjectGroup(name: $0.key, projectDirs: $0.value) }
            .sorted { $0.name < $1.name }
    }
}

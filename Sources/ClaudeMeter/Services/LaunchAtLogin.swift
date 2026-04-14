import Foundation

enum LaunchAtLogin {
    private static let plistName = "com.carloscosta.claudemeter.plist"

    private static var plistPath: String {
        let home = NSHomeDirectory()
        return home + "/Library/LaunchAgents/" + plistName
    }

    private static var appPath: String {
        Bundle.main.bundlePath
    }

    static var isEnabled: Bool {
        get {
            FileManager.default.fileExists(atPath: plistPath)
        }
        set {
            if newValue {
                install()
            } else {
                uninstall()
            }
        }
    }

    private static func install() {
        let launchAgentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
        try? FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": "com.carloscosta.claudemeter",
            "ProgramArguments": [appPath + "/Contents/MacOS/ClaudeMeter"],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]

        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        FileManager.default.createFile(atPath: plistPath, contents: data)
    }

    private static func uninstall() {
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}

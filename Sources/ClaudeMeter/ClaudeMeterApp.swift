// Sources/ClaudeMeter/ClaudeMeterApp.swift
import SwiftUI

@main
struct ClaudeMeterApp: App {
    var body: some Scene {
        MenuBarExtra("ClaudeMeter", systemImage: "sparkle") {
            Text("ClaudeMeter")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

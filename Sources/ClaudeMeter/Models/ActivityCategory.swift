// Sources/ClaudeMeter/Models/ActivityCategory.swift
import Foundation
import SwiftUI

enum ActivityCategory: String, CaseIterable, Identifiable {
    case conversation = "Conversation"
    case coding = "Coding"
    case exploration = "Exploration"
    case terminal = "Terminal"
    case planning = "Planning"
    case design = "Design"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .conversation: return .blue
        case .coding: return .green
        case .exploration: return .purple
        case .terminal: return .orange
        case .planning: return .yellow
        case .design: return .pink
        }
    }

    /// Classify a set of tool names from an assistant message into a category.
    /// If no tools are used, it's a conversation turn.
    static func classify(tools: [String]) -> ActivityCategory {
        if tools.isEmpty { return .conversation }

        // Priority-based classification
        let toolSet = Set(tools)

        // Coding: Edit, Write, NotebookEdit
        let codingTools: Set<String> = ["Edit", "Write", "NotebookEdit"]
        if !toolSet.isDisjoint(with: codingTools) { return .coding }

        // Design: MCP figma tools, frontend-design skill
        if tools.contains(where: { $0.contains("figma") || $0.contains("design") }) { return .design }

        // Terminal: Bash
        if toolSet.contains("Bash") { return .terminal }

        // Planning: EnterPlanMode, ExitPlanMode, TaskCreate, TaskUpdate, TaskList, Task, TodoWrite
        let planningTools: Set<String> = ["EnterPlanMode", "ExitPlanMode", "TaskCreate", "TaskUpdate", "TaskList", "TaskOutput", "Task", "TodoWrite"]
        if !toolSet.isDisjoint(with: planningTools) { return .planning }

        // Exploration: Read, Grep, Glob, Agent, WebSearch, WebFetch
        let explorationTools: Set<String> = ["Read", "Grep", "Glob", "Agent", "WebSearch", "WebFetch", "ToolSearch"]
        if !toolSet.isDisjoint(with: explorationTools) { return .exploration }

        // Default: anything else (Skill, AskUserQuestion, etc.)
        return .conversation
    }
}

struct ActivityEntry: Identifiable {
    let category: ActivityCategory
    var cost: Double = 0
    var turns: Int = 0
    var tokens: Int = 0

    var id: String { category.id }
}

struct ActivityAggregator {
    private(set) var entries: [ActivityCategory: ActivityEntry] = [:]

    mutating func add(category: ActivityCategory, cost: Double, tokens: Int) {
        if var existing = entries[category] {
            existing.cost += cost
            existing.turns += 1
            existing.tokens += tokens
            entries[category] = existing
        } else {
            entries[category] = ActivityEntry(category: category, cost: cost, turns: 1, tokens: tokens)
        }
    }

    mutating func merge(_ other: ActivityAggregator) {
        for (category, entry) in other.entries {
            if var existing = entries[category] {
                existing.cost += entry.cost
                existing.turns += entry.turns
                existing.tokens += entry.tokens
                entries[category] = existing
            } else {
                entries[category] = entry
            }
        }
    }

    var sortedEntries: [ActivityEntry] {
        entries.values.sorted { $0.cost > $1.cost }
    }

    var totalCost: Double {
        entries.values.reduce(0) { $0 + $1.cost }
    }

    var totalTurns: Int {
        entries.values.reduce(0) { $0 + $1.turns }
    }
}

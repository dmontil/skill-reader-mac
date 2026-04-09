import Foundation

enum EntryType: String, Codable {
    case skill, rule
}

struct SkillEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var tools: [String]
    var scope: String            // "global" | "project" | "global+project"
    var project: String?
    var paths: [URL]             // one per tool occurrence
    var description: String
    var inode: UInt64
    var isHardlinked: Bool
    var isSymlink: Bool
    var sizeKB: Double
    var entryType: EntryType
    var modificationDate: Date   // mtime of the SKILL.md / rule file
    var source: String?
    var risk: String?
    var dateAdded: String?

    var primaryPath: URL { paths[0] }

    /// The file to read/edit: SKILL.md inside the dir (skill) or the file itself (rule)
    var contentURL: URL? {
        switch entryType {
        case .skill: return primaryPath.appendingPathComponent("SKILL.md")
        case .rule:  return primaryPath
        }
    }

    var toolsDisplay: String { tools.joined(separator: ", ") }
    var projectDisplay: String { project ?? "—" }
    var scopeIcon: String { scope.contains("global") ? "globe" : "folder" }

    static func == (lhs: SkillEntry, rhs: SkillEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Tool metadata

struct ToolInfo {
    let id: String
    let displayName: String
    let icon: String   // SF Symbol
    let color: String  // SwiftUI Color name
}

let allTools: [ToolInfo] = [
    ToolInfo(id: "claude",   displayName: "Claude",        icon: "c.circle.fill",       color: "blue"),
    ToolInfo(id: "windsurf", displayName: "Windsurf",      icon: "wind",                color: "green"),
    ToolInfo(id: "kiro",     displayName: "Kiro",          icon: "k.circle.fill",       color: "yellow"),
    ToolInfo(id: "codex",    displayName: "Codex",         icon: "x.circle.fill",       color: "purple"),
    ToolInfo(id: "cursor",   displayName: "Cursor",        icon: "cursorarrow",         color: "cyan"),
    ToolInfo(id: "opencode", displayName: "Open Code",     icon: "o.circle.fill",       color: "white"),
    ToolInfo(id: "cline",    displayName: "Cline",         icon: "terminal",            color: "cyan"),
    ToolInfo(id: "zed",      displayName: "Zed",           icon: "z.circle.fill",       color: "green"),
    ToolInfo(id: "amp",      displayName: "Amp",           icon: "bolt.fill",           color: "yellow"),
    ToolInfo(id: "copilot",  displayName: "GitHub Copilot",icon: "g.circle.fill",       color: "blue"),
    ToolInfo(id: "amazonq",  displayName: "Amazon Q",      icon: "q.circle.fill",       color: "orange"),
    ToolInfo(id: "aider",    displayName: "Aider",         icon: "d.circle.fill",       color: "purple"),
]

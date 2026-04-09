import Foundation
import SwiftUI

@Observable
class SkillStore {
    var entries: [SkillEntry] = []
    var isScanning = false
    var searchText = ""
    var filterTool: String? = nil       // nil = all tools
    var filterScope: String? = nil      // nil = all scopes
    var filterType: EntryType? = nil    // nil = skill + rule

    // UserDefaults key for recently viewed skill names
    private let recentKey = "recentlyViewed"

    init() {
        scan()
    }

    // MARK: - Scan

    func scan(cwd: URL? = nil) {
        isScanning = true
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                SkillScanner.scan(cwd: cwd)
            }.value
            self?.entries = result
            self?.isScanning = false
        }
    }

    // MARK: - Filtered entries

    var filtered: [SkillEntry] {
        entries.filter { entry in
            if let tool = filterTool, !entry.tools.contains(tool) { return false }
            if let scope = filterScope, !entry.scope.contains(scope) { return false }
            if let type = filterType, entry.entryType != type { return false }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                return entry.name.lowercased().contains(q) ||
                       entry.description.lowercased().contains(q) ||
                       entry.tools.joined().lowercased().contains(q)
            }
            return true
        }
    }

    // MARK: - Recent skills (by modification date)

    var recentEntries: [SkillEntry] {
        Array(
            entries
                .filter { $0.entryType == .skill }
                .sorted { $0.modificationDate > $1.modificationDate }
                .prefix(7)
        )
    }

    // MARK: - Recently viewed in this app (UserDefaults)

    private(set) var recentlyViewedNames: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentKey) }
    }

    func markViewed(_ entry: SkillEntry) {
        var names = recentlyViewedNames.filter { $0 != entry.name }
        names.insert(entry.name, at: 0)
        recentlyViewedNames = Array(names.prefix(7))
    }

    var recentlyViewed: [SkillEntry] {
        recentlyViewedNames.compactMap { name in
            entries.first { $0.name == name }
        }
    }

    // MARK: - Stats

    var totalSkills: Int { entries.filter { $0.entryType == .skill }.count }
    var totalRules: Int  { entries.filter { $0.entryType == .rule  }.count }
    var hardlinked: Int  { entries.filter { $0.isHardlinked }.count }

    var countsByTool: [String: Int] {
        var result: [String: Int] = [:]
        for entry in entries {
            for tool in entry.tools { result[tool, default: 0] += 1 }
        }
        return result
    }

    // MARK: - Delete

    func delete(_ entry: SkillEntry, from toolsToDelete: [String]) throws {
        for (tool, path) in zip(entry.tools, entry.paths) where toolsToDelete.contains(tool) {
            if entry.entryType == .skill {
                try FileManager.default.removeItem(at: path)
            } else {
                try FileManager.default.removeItem(at: path)
            }
        }
        entries.removeAll { $0.id == entry.id }
    }
}

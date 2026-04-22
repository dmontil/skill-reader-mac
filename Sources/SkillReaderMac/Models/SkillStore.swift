import Foundation
import SwiftUI

struct ActivityEntry: Identifiable {
    let id = UUID()
    let date: Date
    let message: String
}

private struct TrashedItem {
    let originalURL: URL
    let trashURL: URL
}

@Observable
class SkillStore {
    var entries: [SkillEntry] = []
    var profiles: [ProfileEntry] = []
    var isScanning = false
    var searchText = ""
    var browserMode: BrowserMode = .skills
    var filterTool: String? = nil       // nil = all tools
    var filterScope: String? = nil      // nil = all scopes
    var filterType: EntryType? = nil    // nil = skill + rule
    var isCompactMode = false
    var showDescriptionInList = true
    var activities: [ActivityEntry] = []
    var toastMessage: String? = nil
    var toastPrimaryPath: URL? = nil

    // UserDefaults key for recently viewed skill names
    private let recentKey = "recentlyViewed"
    private var trashedItems: [TrashedItem] = []

    init() {
        scan()
    }

    // MARK: - Scan

    func scan(cwd: URL? = nil) {
        isScanning = true
        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                (
                    SkillScanner.scan(cwd: cwd),
                    ProfileManager.loadProfiles()
                )
            }.value
            self?.entries = result.0
            self?.profiles = result.1
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

    var filteredProfiles: [ProfileEntry] {
        profiles.filter { profile in
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return profile.name.lowercased().contains(q) ||
                   profile.description.lowercased().contains(q) ||
                   profile.assets.contains(where: { $0.assetID.lowercased().contains(q) })
        }
    }

    var recentActivities: [ActivityEntry] {
        Array(activities.prefix(20))
    }

    var canUndoDelete: Bool { !trashedItems.isEmpty }

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
    var totalProfiles: Int { profiles.count }

    var countsByTool: [String: Int] {
        var result: [String: Int] = [:]
        for entry in entries {
            for tool in entry.tools { result[tool, default: 0] += 1 }
        }
        return result
    }

    // MARK: - Delete

    func delete(_ entry: SkillEntry, from toolsToDelete: [String]) throws {
        var deletedCount = 0
        toastPrimaryPath = nil
        for (tool, path) in zip(entry.tools, entry.paths) where toolsToDelete.contains(tool) {
            var trashedURL: NSURL?
            try FileManager.default.trashItem(at: path, resultingItemURL: &trashedURL)
            if let trashedURL = trashedURL as URL? {
                trashedItems.insert(TrashedItem(originalURL: path, trashURL: trashedURL), at: 0)
            }
            deletedCount += 1
            addActivity("Moved '\(entry.name)' to Trash (\(tool)).")
        }
        scan()
        showToast("Moved \(deletedCount) item(s) to Trash. You can undo.")
    }

    func restoreLastDeleted() {
        guard let item = trashedItems.first else { return }
        do {
            toastPrimaryPath = nil
            let parent = item.originalURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: item.trashURL, to: item.originalURL)
            trashedItems.removeFirst()
            addActivity("Restored '\(item.originalURL.lastPathComponent)' from Trash.")
            showToast("Restored last deleted item.")
            scan()
        } catch {
            showToast("Undo failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Add / install

    @discardableResult
    func addSkill(
        name: String,
        tools: [String],
        scope: String,
        description: String,
        content: String,
        source: String? = nil,
        risk: String? = nil,
        dateAdded: String? = nil,
        overwrite: Bool = false,
        mode: SkillInstallMode = .hardlink
    ) throws -> [URL] {
        let created = try SkillScanner.installSkill(
            name: name,
            tools: tools,
            scope: scope,
            description: description,
            content: content,
            source: source,
            risk: risk,
            dateAdded: dateAdded,
            overwrite: overwrite,
            mode: mode
        )
        if let first = created.first {
            toastPrimaryPath = first
        }
        addActivity("Added skill '\(name)' to \(created.count) location(s).")
        showToast("Skill '\(name)' created in \(created.count) location(s).")
        scan()
        return created
    }

    // MARK: - Activity / toast

    func addActivity(_ message: String) {
        activities.insert(ActivityEntry(date: Date(), message: message), at: 0)
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    // MARK: - Profiles

    @discardableResult
    func createProfile(name: String, description: String) throws -> ProfileEntry {
        let profile = try ProfileManager.createProfile(name: name, description: description)
        addActivity("Created profile '\(profile.name)'.")
        showToast("Profile '\(profile.name)' created.")
        scan()
        return profile
    }

    @discardableResult
    func addAssetToProfile(name: String, kind: ProfileAssetKind, assetID: String) throws -> ProfileEntry {
        let profile = try ProfileManager.addAsset(profileName: name, kind: kind, assetID: assetID)
        addActivity("Added \(kind.rawValue) asset '\(assetID)' to profile '\(name)'.")
        showToast("Profile '\(name)' updated.")
        scan()
        return profile
    }

    @discardableResult
    func removeAssetFromProfile(name: String, kind: ProfileAssetKind, assetID: String) throws -> ProfileEntry {
        let profile = try ProfileManager.removeAsset(profileName: name, kind: kind, assetID: assetID)
        addActivity("Removed \(kind.rawValue) asset '\(assetID)' from profile '\(name)'.")
        showToast("Profile '\(name)' updated.")
        scan()
        return profile
    }

    func applyProfile(name: String, tool: String, cwd: URL) throws {
        try ProfileManager.applyProfile(name: name, tool: tool, cwd: cwd)
        addActivity("Applied profile '\(name)' to \(tool) in \(cwd.lastPathComponent).")
        showToast("Applied profile '\(name)' to \(tool).")
        scan(cwd: cwd)
    }

    func deleteProfile(name: String) throws {
        try ProfileManager.deleteProfile(named: name)
        addActivity("Deleted profile '\(name)'.")
        showToast("Deleted profile '\(name)'.")
        scan()
    }
}

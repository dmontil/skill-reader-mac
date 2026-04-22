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
    private let viewCountsKey = "skillViewCounts"
    private let appliedCountsKey = "profileAppliedCounts"
    private let lastAppliedProjectKey = "profileLastAppliedProject"
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
        entries.filter(matchesFilters)
    }

    var filteredProfiles: [ProfileEntry] {
        profiles.filter(matchesProfileSearch)
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

    private var viewCounts: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: viewCountsKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: viewCountsKey) }
    }

    private var profileAppliedCounts: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: appliedCountsKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: appliedCountsKey) }
    }

    private var profileLastAppliedProject: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: lastAppliedProjectKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: lastAppliedProjectKey) }
    }

    func markViewed(_ entry: SkillEntry) {
        var names = recentlyViewedNames.filter { $0 != entry.name }
        names.insert(entry.name, at: 0)
        recentlyViewedNames = Array(names.prefix(7))
        var counts = viewCounts
        counts[entry.assetID, default: 0] += 1
        viewCounts = counts
    }

    var recentlyViewed: [SkillEntry] {
        recentlyViewedNames.compactMap { name in
            entries.first { $0.name == name }
        }
    }

    func viewCount(for entry: SkillEntry) -> Int {
        viewCounts[entry.assetID, default: 0]
    }

    var mostViewedEntries: [SkillEntry] {
        entries
            .sorted {
                let lhsCount = viewCounts[$0.assetID, default: 0]
                let rhsCount = viewCounts[$1.assetID, default: 0]
                if lhsCount == rhsCount {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhsCount > rhsCount
            }
            .filter { viewCounts[$0.assetID, default: 0] > 0 }
    }

    // MARK: - Stats

    var totalSkills: Int { entries.filter { $0.entryType == .skill }.count }
    var totalRules: Int  { entries.filter { $0.entryType == .rule  }.count }
    var hardlinked: Int  { entries.filter { $0.isHardlinked }.count }
    var totalProfiles: Int { profiles.count }
    var emptyProfiles: [ProfileEntry] { profiles.filter { $0.assets.isEmpty } }
    var orphanedEntries: [SkillEntry] {
        entries.filter { entry in
            switch entry.entryType {
            case .skill, .rule:
                return profilesUsing(entry).isEmpty
            }
        }
    }
    var unviewedEntries: [SkillEntry] {
        entries.filter { viewCount(for: $0) == 0 }
    }
    var highLeverageEntries: [SkillEntry] {
        entries
            .filter { profilesUsing($0).count >= 2 || viewCount(for: $0) >= 3 }
            .sorted {
                let lhsScore = profilesUsing($0).count * 10 + viewCount(for: $0)
                let rhsScore = profilesUsing($1).count * 10 + viewCount(for: $1)
                if lhsScore == rhsScore {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return lhsScore > rhsScore
            }
    }

    var countsByTool: [String: Int] {
        var result: [String: Int] = [:]
        for entry in entries {
            for tool in entry.tools { result[tool, default: 0] += 1 }
        }
        return result
    }

    var healthSummary: [(label: String, value: Int, systemImage: String)] {
        [
            ("Orphaned assets", orphanedEntries.count, "tray.full"),
            ("Empty profiles", emptyProfiles.count, "square.stack.3d.up.slash"),
            ("Never viewed", unviewedEntries.count, "eye.slash"),
            ("High leverage", highLeverageEntries.count, "bolt.fill"),
        ]
    }

    func matchingEntries(for query: String, limit: Int? = nil) -> [SkillEntry] {
        let results = entries.filter { matchesEntrySearch($0, query: query) }
        if let limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    func profilesUsing(_ entry: SkillEntry) -> [ProfileEntry] {
        let expectedKind: ProfileAssetKind = entry.entryType == .skill ? .skill : .rule
        return profiles.filter { profile in
            profile.assets.contains { $0.kind == expectedKind && $0.assetID == entry.assetID }
        }
    }

    func recommendedAssets(for profileName: String, description: String, limit: Int = 6) -> [LibraryAssetEntry] {
        let tokens = [profileName, description]
            .joined(separator: " ")
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" }
            .map(String.init)
            .filter { $0.count >= 3 }

        guard !tokens.isEmpty else { return [] }

        let assets = ProfileManager.loadLibraryAssets()
        let scored = assets.compactMap { asset -> (LibraryAssetEntry, Int)? in
            let haystack = [asset.assetID, asset.title, asset.detail].joined(separator: " ").lowercased()
            let score = tokens.reduce(0) { partial, token in
                partial + (haystack.contains(token) ? 1 : 0)
            }
            return score > 0 ? (asset, score) : nil
        }
        .sorted {
            if $0.1 == $1.1 {
                return $0.0.title.localizedCaseInsensitiveCompare($1.0.title) == .orderedAscending
            }
            return $0.1 > $1.1
        }
        .map(\.0)

        return Array(scored.prefix(limit))
    }

    func suggestedProfiles(limit: Int = 3) -> [ProfileEntry] {
        Array(
            profiles
                .sorted {
                    let lhsCount = applyCount(for: $0)
                    let rhsCount = applyCount(for: $1)
                    if lhsCount == rhsCount, $0.assets.count == $1.assets.count {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    if lhsCount != rhsCount {
                        return lhsCount > rhsCount
                    }
                    return $0.assets.count > $1.assets.count
                }
                .prefix(limit)
        )
    }

    func applyCount(for profile: ProfileEntry) -> Int {
        profileAppliedCounts[profile.name, default: 0]
    }

    func lastAppliedProject(for profile: ProfileEntry) -> String? {
        profileLastAppliedProject[profile.name]
    }

    func applyProfile(name: String, tools: [String], cwd: URL) throws {
        for tool in tools {
            try ProfileManager.applyProfile(name: name, tool: tool, cwd: cwd)
        }
        recordProfileApplied(name: name, project: cwd.lastPathComponent)
        addActivity("Applied profile '\(name)' to \(tools.count) tool(s) in \(cwd.lastPathComponent).")
        showToast("Applied profile '\(name)' to \(tools.count) tool(s).")
        scan(cwd: cwd)
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
        recordProfileApplied(name: name, project: cwd.lastPathComponent)
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

    func updateMetadata(for entry: SkillEntry, description: String, source: String?, risk: String?, dateAdded: String?) throws {
        try SkillScanner.updateMetadata(
            for: entry,
            description: description,
            source: source,
            risk: risk,
            dateAdded: dateAdded
        )
        addActivity("Updated metadata for '\(entry.name)'.")
        showToast("Updated metadata for '\(entry.name)'.")
        scan()
    }

    private func matchesFilters(_ entry: SkillEntry) -> Bool {
        if let tool = filterTool, !entry.tools.contains(tool) { return false }
        if let scope = filterScope, !entry.scope.contains(scope) { return false }
        if let type = filterType, entry.entryType != type { return false }
        return searchText.isEmpty || matchesEntrySearch(entry, query: searchText)
    }

    private func matchesEntrySearch(_ entry: SkillEntry, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        let haystack = [
            entry.name,
            entry.assetID,
            entry.description,
            entry.tools.joined(separator: " "),
            entry.scope,
            entry.project ?? "",
            entry.source ?? "",
            entry.risk ?? "",
            entry.dateAdded ?? "",
            entry.useCaseHints.joined(separator: " "),
        ]
        .joined(separator: " ")
        .lowercased()

        return haystack.contains(q)
    }

    private func matchesProfileSearch(_ profile: ProfileEntry) -> Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        let haystack = [
            profile.name,
            profile.description,
            profile.targetsDisplay,
            profile.assetSummary,
            profile.assets.map(\.assetID).joined(separator: " "),
        ]
        .joined(separator: " ")
        .lowercased()

        return haystack.contains(q)
    }

    private func recordProfileApplied(name: String, project: String) {
        var counts = profileAppliedCounts
        counts[name, default: 0] += 1
        profileAppliedCounts = counts

        var projects = profileLastAppliedProject
        projects[name] = project
        profileLastAppliedProject = projects
    }
}

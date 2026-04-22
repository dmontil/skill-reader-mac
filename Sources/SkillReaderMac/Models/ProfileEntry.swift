import Foundation

enum BrowserMode: String, CaseIterable, Identifiable {
    case skills
    case profiles

    var id: String { rawValue }
    var title: String {
        switch self {
        case .skills: "Skills"
        case .profiles: "Profiles"
        }
    }
}

enum ProfileAssetKind: String, CaseIterable, Identifiable, Codable {
    case skill
    case rule
    case agents

    var id: String { rawValue }
}

struct ProfileAsset: Identifiable, Hashable, Codable {
    var kind: ProfileAssetKind
    var assetID: String

    var id: String { "\(kind.rawValue):\(assetID)" }
}

struct ProfileTarget: Hashable, Codable {
    var mode: String = "project"
}

struct ProfileEntry: Identifiable, Hashable {
    var name: String
    var description: String
    var assets: [ProfileAsset]
    var targets: [String: ProfileTarget]
    var profileURL: URL

    var id: String { name }
    var targetsDisplay: String {
        let keys = targets.isEmpty ? ["codex", "claude", "cursor", "windsurf", "opencode"] : targets.keys.sorted()
        return keys.joined(separator: ", ")
    }

    var assetSummary: String {
        let grouped = Dictionary(grouping: assets, by: \.kind)
        let skills = grouped[.skill]?.count ?? 0
        let rules = grouped[.rule]?.count ?? 0
        let guides = grouped[.agents]?.count ?? 0
        return [
            skills > 0 ? "\(skills) skill\(skills == 1 ? "" : "s")" : nil,
            rules > 0 ? "\(rules) rule\(rules == 1 ? "" : "s")" : nil,
            guides > 0 ? "\(guides) guide\(guides == 1 ? "" : "s")" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

struct ProfilePreviewAsset: Identifiable, Hashable {
    let kind: ProfileAssetKind
    let assetID: String
    let title: String
    let description: String

    var id: String { "\(kind.rawValue):\(assetID)" }
}

struct ProfileApplicationPreview: Identifiable, Hashable {
    let profileName: String
    let tool: String
    let cwd: URL
    let assets: [ProfilePreviewAsset]
    let generatedPaths: [URL]
    let managedFiles: [URL]

    var id: String { "\(profileName)::\(tool)::\(cwd.path)" }
    var totalWrites: Int { generatedPaths.count + managedFiles.count }
}

struct MultiProfileApplicationPreview: Identifiable, Hashable {
    let profileName: String
    let cwd: URL
    let previews: [ProfileApplicationPreview]

    var id: String { "\(profileName)::all::\(cwd.path)" }
    var totalWrites: Int { previews.reduce(0) { $0 + $1.totalWrites } }
    var tools: [String] { previews.map(\.tool) }
}
